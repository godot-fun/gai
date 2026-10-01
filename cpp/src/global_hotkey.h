#pragma once

#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <atomic>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

using namespace godot;

/// Global OS hotkeys that still fire when the Godot window is unfocused.
///
/// Why not Godot Input?
/// --------------------
/// `Input` / `_input` only see keys while the engine window has focus. Background
/// shortcuts need an OS API. On Windows that is `RegisterHotKey`, which posts
/// `WM_HOTKEY` to a window on the thread that registered the hotkey.
///
/// Architecture (Windows)
/// ----------------------
/// 1. Engine singleton `GlobalHotkey` (created in `register_types.cpp`).
/// 2. A dedicated worker thread owns a message-only HWND (`HWND_MESSAGE`).
///    `RegisterHotKey` / `UnregisterHotKey` run only on that thread, because Win32
///    requires the registering thread to be the one that created the HWND.
/// 3. GDScript calls (`register_hotkey`, `unregister_hotkey`, …) run on Godot's
///    main thread. They post a `Command` to the worker via `PostMessage`, then
///    wait on an event so the call stays synchronous and can return success/failure.
/// 4. When the OS delivers `WM_HOTKEY`, the worker pushes the hotkey `id` into
///    `pressed_queue` (mutex-protected). It must not touch Godot APIs there.
/// 5. The singleton is hooked to `SceneTree.process_frame`. Each frame,
///    `flush_pressed` drains the queue on the main thread and emits
///    `hotkey_pressed(id)`. Held combos are then polled with `GetAsyncKeyState`;
///    when the primary key or a required modifier is up, `hotkey_released(id)` fires.
///    (`RegisterHotKey` itself has no key-up notification.)
///
/// Dynamic register / cancel
/// -------------------------
/// - `register_hotkey(id, key, modifiers)` — add or replace binding for `id`.
/// - `unregister_hotkey(id)` — cancel one binding.
/// - `unregister_all()` — cancel every binding.
/// Re-registering the same `id` unregisters the old combo first, then registers
/// the new one.
///
/// Key mapping
/// -----------
/// Godot `Key` + `KEY_MASK_*` are converted to Win32 VK + `MOD_*` using the inverse
/// of Godot's own `KeyMappingWindows::vk_map` (see `map_key` / `map_modifiers`).
/// Keys with no physical VK (e.g. shifted punctuation like `KEY_EXCLAM`) are
/// unsupported; check `is_key_supported`.
///
/// Lifetime
/// --------
/// `create_singleton` / `destroy_singleton` run from the GDExtension init/terminate
/// hooks. `shutdown` stops the worker, unregisters OS hotkeys, and disconnects the
/// frame hook.
///
/// GDScript example
/// ----------------
/// ```gdscript
/// GlobalHotkey.hotkey_pressed.connect(func(id: int): print("down", id))
/// GlobalHotkey.hotkey_released.connect(func(id: int): print("up", id))
/// GlobalHotkey.register_hotkey(1, KEY_Z, KEY_MASK_CTRL | KEY_MASK_ALT)
/// ```
class GlobalHotkey : public Object {
	GDCLASS(GlobalHotkey, Object)

public:
	static GlobalHotkey *get_singleton();
	/// Allocate the singleton and register it with `Engine` as `"GlobalHotkey"`.
	static void create_singleton();
	/// Unregister from `Engine`, shut down the worker, and free the singleton.
	static void destroy_singleton();

	/// Register or replace a hotkey.
	/// @param p_id Caller-chosen id (must be >= 0); delivered again in `hotkey_pressed` / `hotkey_released`.
	/// @param p_key Godot `Key` enum value.
	/// @param p_modifiers Bitwise OR of `KEY_MASK_CTRL` / `SHIFT` / `ALT` / `META`.
	/// @return false if the key cannot be mapped or the OS rejects the combo (often already taken).
	bool register_hotkey(int32_t p_id, Key p_key, int64_t p_modifiers);
	/// Cancel one hotkey. Returns false if `p_id` was not registered.
	bool unregister_hotkey(int32_t p_id);
	/// Cancel every hotkey registered through this singleton.
	void unregister_all();
	bool is_registered(int32_t p_id) const;
	PackedInt32Array get_registered_ids() const;
	/// True when `p_key` has a Windows VK mapping (same set as Godot's KeyMappingWindows).
	bool is_key_supported(Key p_key) const;
	/// True while this id is between `hotkey_pressed` and `hotkey_released` (combo still held).
	bool is_hotkey_held(int32_t p_id) const;

	/// Tear down worker thread, OS registrations, and the process_frame connection.
	void shutdown();

protected:
	static void _bind_methods();

private:
	static GlobalHotkey *singleton;

#ifdef _WIN32
	struct Binding {
		uint32_t modifiers = 0;
		uint32_t vk = 0;
	};
#endif

	/// Start the Win32 worker (once) and attach the main-thread frame flush hook.
	void ensure_runtime();
	/// Connect `flush_pressed` to `SceneTree.process_frame` when the tree exists.
	void ensure_frame_hook();
	/// Main thread: drain press queue, emit pressed, poll held combos, emit released.
	void flush_pressed();
	/// Worker thread: enqueue a pressed id for the next frame flush.
	void push_pressed(int32_t p_id);

	/// Godot Key -> Win32 virtual-key (inverse of engine KeyMappingWindows::vk_map).
	bool map_key(Key p_key, uint32_t &r_vk) const;
	/// Godot KEY_MASK_* -> Win32 MOD_* (always includes MOD_NOREPEAT).
	uint32_t map_modifiers(int64_t p_modifiers) const;
#ifdef _WIN32
	/// True while the primary VK and every required modifier are down (`GetAsyncKeyState`).
	bool is_binding_down(const Binding &binding) const;
#endif

	/// Protects `pressed_queue` between worker and main threads.
	std::mutex pressed_mutex;
	/// Hotkey ids received via WM_HOTKEY, waiting to be emitted on the main thread.
	std::vector<int32_t> pressed_queue;
	/// Ids currently registered from the GDScript / main-thread API perspective.
	std::unordered_set<int32_t> registered_ids;
#ifdef _WIN32
	/// Main-thread copy of each id's Win32 combo (for hold / release polling).
	std::unordered_map<int32_t, Binding> bindings;
#endif
	/// Ids that have emitted pressed and are waiting for release.
	std::unordered_set<int32_t> held_ids;
	/// Whether we already connected to SceneTree.process_frame.
	bool frame_hooked = false;

#ifdef _WIN32
	/// Work item posted from the main thread to the worker's message window.
	struct Command {
		enum class Type : uint32_t {
			REGISTER = 1,
			UNREGISTER = 2,
			UNREGISTER_ALL = 3,
			SHUTDOWN = 4,
		};
		Type type = Type::REGISTER;
		int32_t id = 0;
		uint32_t modifiers = 0;
		uint32_t vk = 0;
		/// Written by the worker before signaling `done` (main thread waits).
		bool *result = nullptr;
		HANDLE done = nullptr;
	};

	static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
	static DWORD WINAPI thread_main(LPVOID param);

	bool post_command(Command *cmd);
	/// Post a command and block until the worker finishes it.
	bool run_command_sync(Command::Type type, int32_t id = 0, uint32_t modifiers = 0, uint32_t vk = 0);

	std::atomic<bool> worker_ready{ false };
	std::atomic<bool> worker_stop{ false };
	HANDLE worker_thread = nullptr;
	/// Message-only window; target of RegisterHotKey and WM_HOTKEY.
	HWND message_hwnd = nullptr;
	DWORD worker_thread_id = 0;
	/// OS-level registrations tracked only on the worker thread (no cross-thread reads).
	std::unordered_set<int32_t> worker_registered;
#endif
};
