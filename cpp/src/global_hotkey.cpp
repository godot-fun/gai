#include "global_hotkey.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/main_loop.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

GlobalHotkey *GlobalHotkey::singleton = nullptr;

namespace {
#ifdef _WIN32
constexpr UINT WM_GAI_HOTKEY_CMD = WM_USER + 0x471;
#endif
} // namespace

GlobalHotkey *GlobalHotkey::get_singleton() {
	return singleton;
}

void GlobalHotkey::create_singleton() {
	if (singleton != nullptr) {
		return;
	}
	singleton = memnew(GlobalHotkey);
	Engine::get_singleton()->register_singleton("GlobalHotkey", singleton);
}

void GlobalHotkey::destroy_singleton() {
	if (singleton == nullptr) {
		return;
	}
	singleton->shutdown();
	Engine::get_singleton()->unregister_singleton("GlobalHotkey");
	memdelete(singleton);
	singleton = nullptr;
}

void GlobalHotkey::_bind_methods() {
	ClassDB::bind_method(D_METHOD("register_hotkey", "id", "key", "modifiers"), &GlobalHotkey::register_hotkey);
	ClassDB::bind_method(D_METHOD("unregister_hotkey", "id"), &GlobalHotkey::unregister_hotkey);
	ClassDB::bind_method(D_METHOD("unregister_all"), &GlobalHotkey::unregister_all);
	ClassDB::bind_method(D_METHOD("is_registered", "id"), &GlobalHotkey::is_registered);
	ClassDB::bind_method(D_METHOD("get_registered_ids"), &GlobalHotkey::get_registered_ids);
	ClassDB::bind_method(D_METHOD("is_key_supported", "key"), &GlobalHotkey::is_key_supported);
	ClassDB::bind_method(D_METHOD("is_hotkey_held", "id"), &GlobalHotkey::is_hotkey_held);

	ADD_SIGNAL(MethodInfo("hotkey_pressed", PropertyInfo(Variant::INT, "id")));
	ADD_SIGNAL(MethodInfo("hotkey_released", PropertyInfo(Variant::INT, "id")));
}

bool GlobalHotkey::is_key_supported(Key p_key) const {
	uint32_t vk = 0;
	return map_key(p_key, vk);
}

bool GlobalHotkey::map_key(Key p_key, uint32_t &r_vk) const {
#ifdef _WIN32
	// Inverse of Godot `platform/windows/key_mapping_windows.cpp` vk_map.
	// When several VKs map to one Key, prefer the modern / generic VK Godot would report.
	switch (p_key) {
		case KEY_BACKSPACE:
			r_vk = VK_BACK;
			return true;
		case KEY_TAB:
			r_vk = VK_TAB;
			return true;
		case KEY_CLEAR:
			r_vk = VK_CLEAR;
			return true;
		case KEY_ENTER:
			r_vk = VK_RETURN;
			return true;
		case KEY_KP_ENTER:
			// Windows has no separate VK for numpad Enter; same as Godot's VK_RETURN path.
			r_vk = VK_RETURN;
			return true;
		case KEY_SHIFT:
			r_vk = VK_SHIFT;
			return true;
		case KEY_CTRL:
			r_vk = VK_CONTROL;
			return true;
		case KEY_ALT:
			r_vk = VK_MENU;
			return true;
		case KEY_PAUSE:
			r_vk = VK_PAUSE;
			return true;
		case KEY_CAPSLOCK:
			r_vk = VK_CAPITAL;
			return true;
		case KEY_ESCAPE:
			r_vk = VK_ESCAPE;
			return true;
		case KEY_SPACE:
			r_vk = VK_SPACE;
			return true;
		case KEY_PAGEUP:
			r_vk = VK_PRIOR;
			return true;
		case KEY_PAGEDOWN:
			r_vk = VK_NEXT;
			return true;
		case KEY_END:
			r_vk = VK_END;
			return true;
		case KEY_HOME:
			r_vk = VK_HOME;
			return true;
		case KEY_LEFT:
			r_vk = VK_LEFT;
			return true;
		case KEY_UP:
			r_vk = VK_UP;
			return true;
		case KEY_RIGHT:
			r_vk = VK_RIGHT;
			return true;
		case KEY_DOWN:
			r_vk = VK_DOWN;
			return true;
		case KEY_PRINT:
			r_vk = VK_SNAPSHOT;
			return true;
		case KEY_INSERT:
			r_vk = VK_INSERT;
			return true;
		case KEY_DELETE:
			r_vk = VK_DELETE;
			return true;
		case KEY_HELP:
			r_vk = VK_HELP;
			return true;
		case KEY_META:
			r_vk = VK_LWIN;
			return true;
		case KEY_MENU:
			r_vk = VK_APPS;
			return true;
		case KEY_STANDBY:
			r_vk = VK_SLEEP;
			return true;
		case KEY_KP_0:
			r_vk = VK_NUMPAD0;
			return true;
		case KEY_KP_1:
			r_vk = VK_NUMPAD1;
			return true;
		case KEY_KP_2:
			r_vk = VK_NUMPAD2;
			return true;
		case KEY_KP_3:
			r_vk = VK_NUMPAD3;
			return true;
		case KEY_KP_4:
			r_vk = VK_NUMPAD4;
			return true;
		case KEY_KP_5:
			r_vk = VK_NUMPAD5;
			return true;
		case KEY_KP_6:
			r_vk = VK_NUMPAD6;
			return true;
		case KEY_KP_7:
			r_vk = VK_NUMPAD7;
			return true;
		case KEY_KP_8:
			r_vk = VK_NUMPAD8;
			return true;
		case KEY_KP_9:
			r_vk = VK_NUMPAD9;
			return true;
		case KEY_KP_MULTIPLY:
			r_vk = VK_MULTIPLY;
			return true;
		case KEY_KP_ADD:
			r_vk = VK_ADD;
			return true;
		case KEY_KP_SUBTRACT:
			r_vk = VK_SUBTRACT;
			return true;
		case KEY_KP_PERIOD:
			r_vk = VK_DECIMAL;
			return true;
		case KEY_KP_DIVIDE:
			r_vk = VK_DIVIDE;
			return true;
		case KEY_F1:
			r_vk = VK_F1;
			return true;
		case KEY_F2:
			r_vk = VK_F2;
			return true;
		case KEY_F3:
			r_vk = VK_F3;
			return true;
		case KEY_F4:
			r_vk = VK_F4;
			return true;
		case KEY_F5:
			r_vk = VK_F5;
			return true;
		case KEY_F6:
			r_vk = VK_F6;
			return true;
		case KEY_F7:
			r_vk = VK_F7;
			return true;
		case KEY_F8:
			r_vk = VK_F8;
			return true;
		case KEY_F9:
			r_vk = VK_F9;
			return true;
		case KEY_F10:
			r_vk = VK_F10;
			return true;
		case KEY_F11:
			r_vk = VK_F11;
			return true;
		case KEY_F12:
			r_vk = VK_F12;
			return true;
		case KEY_F13:
			r_vk = VK_F13;
			return true;
		case KEY_F14:
			r_vk = VK_F14;
			return true;
		case KEY_F15:
			r_vk = VK_F15;
			return true;
		case KEY_F16:
			r_vk = VK_F16;
			return true;
		case KEY_F17:
			r_vk = VK_F17;
			return true;
		case KEY_F18:
			r_vk = VK_F18;
			return true;
		case KEY_F19:
			r_vk = VK_F19;
			return true;
		case KEY_F20:
			r_vk = VK_F20;
			return true;
		case KEY_F21:
			r_vk = VK_F21;
			return true;
		case KEY_F22:
			r_vk = VK_F22;
			return true;
		case KEY_F23:
			r_vk = VK_F23;
			return true;
		case KEY_F24:
			r_vk = VK_F24;
			return true;
		case KEY_NUMLOCK:
			r_vk = VK_NUMLOCK;
			return true;
		case KEY_SCROLLLOCK:
			r_vk = VK_SCROLL;
			return true;
		case KEY_BACK:
			r_vk = VK_BROWSER_BACK;
			return true;
		case KEY_FORWARD:
			r_vk = VK_BROWSER_FORWARD;
			return true;
		case KEY_REFRESH:
			r_vk = VK_BROWSER_REFRESH;
			return true;
		case KEY_STOP:
			r_vk = VK_BROWSER_STOP;
			return true;
		case KEY_SEARCH:
			r_vk = VK_BROWSER_SEARCH;
			return true;
		case KEY_FAVORITES:
			r_vk = VK_BROWSER_FAVORITES;
			return true;
		case KEY_HOMEPAGE:
			r_vk = VK_BROWSER_HOME;
			return true;
		case KEY_VOLUMEMUTE:
			r_vk = VK_VOLUME_MUTE;
			return true;
		case KEY_VOLUMEDOWN:
			r_vk = VK_VOLUME_DOWN;
			return true;
		case KEY_VOLUMEUP:
			r_vk = VK_VOLUME_UP;
			return true;
		case KEY_MEDIANEXT:
			r_vk = VK_MEDIA_NEXT_TRACK;
			return true;
		case KEY_MEDIAPREVIOUS:
			r_vk = VK_MEDIA_PREV_TRACK;
			return true;
		case KEY_MEDIASTOP:
			r_vk = VK_MEDIA_STOP;
			return true;
		case KEY_MEDIAPLAY:
			r_vk = VK_MEDIA_PLAY_PAUSE;
			return true;
		case KEY_LAUNCHMAIL:
			r_vk = VK_LAUNCH_MAIL;
			return true;
		case KEY_LAUNCHMEDIA:
			r_vk = VK_LAUNCH_MEDIA_SELECT;
			return true;
		case KEY_LAUNCH0:
			r_vk = VK_LAUNCH_APP1;
			return true;
		case KEY_LAUNCH1:
			r_vk = VK_LAUNCH_APP2;
			return true;
		case KEY_SEMICOLON:
			r_vk = VK_OEM_1;
			return true;
		case KEY_EQUAL:
			r_vk = VK_OEM_PLUS;
			return true;
		case KEY_COMMA:
			r_vk = VK_OEM_COMMA;
			return true;
		case KEY_MINUS:
			r_vk = VK_OEM_MINUS;
			return true;
		case KEY_PERIOD:
			r_vk = VK_OEM_PERIOD;
			return true;
		case KEY_SLASH:
			r_vk = VK_OEM_2;
			return true;
		case KEY_QUOTELEFT:
			r_vk = VK_OEM_3;
			return true;
		case KEY_BRACKETLEFT:
			r_vk = VK_OEM_4;
			return true;
		case KEY_BACKSLASH:
			r_vk = VK_OEM_5;
			return true;
		case KEY_BRACKETRIGHT:
			r_vk = VK_OEM_6;
			return true;
		case KEY_APOSTROPHE:
			r_vk = VK_OEM_7;
			return true;
		case KEY_BAR:
			r_vk = VK_OEM_102;
			return true;
		case KEY_0:
		case KEY_1:
		case KEY_2:
		case KEY_3:
		case KEY_4:
		case KEY_5:
		case KEY_6:
		case KEY_7:
		case KEY_8:
		case KEY_9:
		case KEY_A:
		case KEY_B:
		case KEY_C:
		case KEY_D:
		case KEY_E:
		case KEY_F:
		case KEY_G:
		case KEY_H:
		case KEY_I:
		case KEY_J:
		case KEY_K:
		case KEY_L:
		case KEY_M:
		case KEY_N:
		case KEY_O:
		case KEY_P:
		case KEY_Q:
		case KEY_R:
		case KEY_S:
		case KEY_T:
		case KEY_U:
		case KEY_V:
		case KEY_W:
		case KEY_X:
		case KEY_Y:
		case KEY_Z:
			// Same numeric values as Windows VK codes (Godot vk_map[0x30..0x39 / 0x41..0x5A]).
			r_vk = static_cast<uint32_t>(p_key);
			return true;
		// No dedicated Windows VK in Godot's vk_map (shifted punctuation, JIS/mac-only, etc.).
		default:
			return false;
	}
#else
	(void)p_key;
	(void)r_vk;
	return false;
#endif
}

uint32_t GlobalHotkey::map_modifiers(int64_t p_modifiers) const {
#ifdef _WIN32
	uint32_t mods = MOD_NOREPEAT;
	if (p_modifiers & KEY_MASK_CTRL) {
		mods |= MOD_CONTROL;
	}
	if (p_modifiers & KEY_MASK_SHIFT) {
		mods |= MOD_SHIFT;
	}
	if (p_modifiers & KEY_MASK_ALT) {
		mods |= MOD_ALT;
	}
	if (p_modifiers & KEY_MASK_META) {
		mods |= MOD_WIN;
	}
	return mods;
#else
	(void)p_modifiers;
	return 0;
#endif
}

#ifdef _WIN32
bool GlobalHotkey::is_binding_down(const Binding &binding) const {
	auto vk_down = [](uint32_t vk) -> bool {
		return (GetAsyncKeyState(static_cast<int>(vk)) & 0x8000) != 0;
	};
	if (!vk_down(binding.vk)) {
		return false;
	}
	const uint32_t mods = binding.modifiers & ~static_cast<uint32_t>(MOD_NOREPEAT);
	if ((mods & MOD_CONTROL) && !vk_down(VK_CONTROL)) {
		return false;
	}
	if ((mods & MOD_SHIFT) && !vk_down(VK_SHIFT)) {
		return false;
	}
	if ((mods & MOD_ALT) && !vk_down(VK_MENU)) {
		return false;
	}
	if ((mods & MOD_WIN) && !vk_down(VK_LWIN) && !vk_down(VK_RWIN)) {
		return false;
	}
	return true;
}
#endif

void GlobalHotkey::ensure_frame_hook() {
	if (frame_hooked) {
		return;
	}
	MainLoop *main_loop = Engine::get_singleton()->get_main_loop();
	SceneTree *tree = Object::cast_to<SceneTree>(main_loop);
	if (tree == nullptr) {
		return;
	}
	tree->connect("process_frame", callable_mp(this, &GlobalHotkey::flush_pressed));
	frame_hooked = true;
}

void GlobalHotkey::push_pressed(int32_t p_id) {
	std::lock_guard<std::mutex> lock(pressed_mutex);
	pressed_queue.push_back(p_id);
}

void GlobalHotkey::flush_pressed() {
	ensure_frame_hook();
	std::vector<int32_t> pending;
	{
		std::lock_guard<std::mutex> lock(pressed_mutex);
		pending.swap(pressed_queue);
	}
	for (const int32_t id : pending) {
		held_ids.insert(id);
		emit_signal("hotkey_pressed", id);
	}
	std::vector<int32_t> released;
	for (const int32_t id : held_ids) {
#ifdef _WIN32
		const auto it = bindings.find(id);
		if (it == bindings.end() || !is_binding_down(it->second)) {
			released.push_back(id);
		}
#else
		released.push_back(id);
#endif
	}
	for (const int32_t id : released) {
		held_ids.erase(id);
		emit_signal("hotkey_released", id);
	}
}

void GlobalHotkey::ensure_runtime() {
#ifdef _WIN32
	if (worker_thread != nullptr) {
		ensure_frame_hook();
		return;
	}
	worker_stop = false;
	worker_ready = false;
	worker_thread = CreateThread(nullptr, 0, &GlobalHotkey::thread_main, this, 0, &worker_thread_id);
	if (worker_thread == nullptr) {
		UtilityFunctions::printerr("GlobalHotkey: failed to start worker thread");
		return;
	}
	while (!worker_ready.load()) {
		Sleep(1);
	}
	ensure_frame_hook();
#else
	ensure_frame_hook();
#endif
}

bool GlobalHotkey::register_hotkey(int32_t p_id, Key p_key, int64_t p_modifiers) {
	if (p_id < 0) {
		UtilityFunctions::printerr("GlobalHotkey.register_hotkey: id must be >= 0");
		return false;
	}
	uint32_t vk = 0;
	if (!map_key(p_key, vk)) {
		UtilityFunctions::printerr("GlobalHotkey.register_hotkey: unsupported key");
		return false;
	}
	ensure_runtime();
	if (is_registered(p_id)) {
		unregister_hotkey(p_id);
	}
#ifdef _WIN32
	const uint32_t mods = map_modifiers(p_modifiers);
	if (!run_command_sync(Command::Type::REGISTER, p_id, mods, vk)) {
		return false;
	}
	registered_ids.insert(p_id);
	bindings[p_id] = Binding{ mods, vk };
	return true;
#else
	(void)p_modifiers;
	UtilityFunctions::printerr("GlobalHotkey: only implemented on Windows");
	return false;
#endif
}

bool GlobalHotkey::unregister_hotkey(int32_t p_id) {
	if (!is_registered(p_id)) {
		return false;
	}
#ifdef _WIN32
	ensure_runtime();
	if (!run_command_sync(Command::Type::UNREGISTER, p_id)) {
		return false;
	}
	bindings.erase(p_id);
#endif
	registered_ids.erase(p_id);
	held_ids.erase(p_id);
	return true;
}

void GlobalHotkey::unregister_all() {
#ifdef _WIN32
	if (worker_thread != nullptr) {
		run_command_sync(Command::Type::UNREGISTER_ALL);
	}
	bindings.clear();
#endif
	registered_ids.clear();
	held_ids.clear();
}

bool GlobalHotkey::is_registered(int32_t p_id) const {
	return registered_ids.find(p_id) != registered_ids.end();
}

bool GlobalHotkey::is_hotkey_held(int32_t p_id) const {
	return held_ids.find(p_id) != held_ids.end();
}

PackedInt32Array GlobalHotkey::get_registered_ids() const {
	PackedInt32Array ids;
	ids.resize(static_cast<int64_t>(registered_ids.size()));
	int64_t i = 0;
	for (const int32_t id : registered_ids) {
		ids[i++] = id;
	}
	return ids;
}

void GlobalHotkey::shutdown() {
	unregister_all();
#ifdef _WIN32
	if (worker_thread != nullptr) {
		run_command_sync(Command::Type::SHUTDOWN);
		WaitForSingleObject(worker_thread, 5000);
		CloseHandle(worker_thread);
		worker_thread = nullptr;
		message_hwnd = nullptr;
		worker_thread_id = 0;
		worker_ready = false;
	}
#endif
	if (frame_hooked) {
		MainLoop *main_loop = Engine::get_singleton()->get_main_loop();
		SceneTree *tree = Object::cast_to<SceneTree>(main_loop);
		if (tree != nullptr && tree->is_connected("process_frame", callable_mp(this, &GlobalHotkey::flush_pressed))) {
			tree->disconnect("process_frame", callable_mp(this, &GlobalHotkey::flush_pressed));
		}
		frame_hooked = false;
	}
	std::lock_guard<std::mutex> lock(pressed_mutex);
	pressed_queue.clear();
	held_ids.clear();
}

#ifdef _WIN32

bool GlobalHotkey::post_command(Command *cmd) {
	if (message_hwnd == nullptr) {
		return false;
	}
	return PostMessageW(message_hwnd, WM_GAI_HOTKEY_CMD, 0, reinterpret_cast<LPARAM>(cmd)) != 0;
}

bool GlobalHotkey::run_command_sync(Command::Type type, int32_t id, uint32_t modifiers, uint32_t vk) {
	if (message_hwnd == nullptr) {
		return false;
	}
	bool result = false;
	HANDLE done = CreateEventW(nullptr, TRUE, FALSE, nullptr);
	if (done == nullptr) {
		return false;
	}
	Command *cmd = new Command();
	cmd->type = type;
	cmd->id = id;
	cmd->modifiers = modifiers;
	cmd->vk = vk;
	cmd->result = &result;
	cmd->done = done;
	if (!post_command(cmd)) {
		delete cmd;
		CloseHandle(done);
		return false;
	}
	WaitForSingleObject(done, INFINITE);
	CloseHandle(done);
	return result;
}

LRESULT CALLBACK GlobalHotkey::window_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
	GlobalHotkey *self = reinterpret_cast<GlobalHotkey *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
	if (msg == WM_NCCREATE) {
		auto *cs = reinterpret_cast<CREATESTRUCTW *>(lparam);
		self = static_cast<GlobalHotkey *>(cs->lpCreateParams);
		SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
		return DefWindowProcW(hwnd, msg, wparam, lparam);
	}
	if (self == nullptr) {
		return DefWindowProcW(hwnd, msg, wparam, lparam);
	}
	if (msg == WM_HOTKEY) {
		self->push_pressed(static_cast<int32_t>(wparam));
		return 0;
	}
	if (msg == WM_GAI_HOTKEY_CMD) {
		Command *cmd = reinterpret_cast<Command *>(lparam);
		bool ok = false;
		switch (cmd->type) {
			case Command::Type::REGISTER:
				UnregisterHotKey(hwnd, cmd->id);
				ok = RegisterHotKey(hwnd, cmd->id, cmd->modifiers, cmd->vk) != 0;
				if (ok) {
					self->worker_registered.insert(cmd->id);
				}
				break;
			case Command::Type::UNREGISTER:
				ok = UnregisterHotKey(hwnd, cmd->id) != 0;
				self->worker_registered.erase(cmd->id);
				break;
			case Command::Type::UNREGISTER_ALL:
				for (const int32_t id : self->worker_registered) {
					UnregisterHotKey(hwnd, id);
				}
				self->worker_registered.clear();
				ok = true;
				break;
			case Command::Type::SHUTDOWN:
				for (const int32_t id : self->worker_registered) {
					UnregisterHotKey(hwnd, id);
				}
				self->worker_registered.clear();
				ok = true;
				self->worker_stop = true;
				PostQuitMessage(0);
				break;
		}
		if (cmd->result != nullptr) {
			*cmd->result = ok;
		}
		HANDLE done = cmd->done;
		delete cmd;
		if (done != nullptr) {
			SetEvent(done);
		}
		return 0;
	}
	return DefWindowProcW(hwnd, msg, wparam, lparam);
}

DWORD WINAPI GlobalHotkey::thread_main(LPVOID param) {
	GlobalHotkey *self = static_cast<GlobalHotkey *>(param);
	const wchar_t *class_name = L"GaiGlobalHotkeyMessageOnly";
	WNDCLASSEXW wc = {};
	wc.cbSize = sizeof(wc);
	wc.lpfnWndProc = &GlobalHotkey::window_proc;
	wc.hInstance = GetModuleHandleW(nullptr);
	wc.lpszClassName = class_name;
	if (RegisterClassExW(&wc) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
		self->worker_ready = true;
		return 1;
	}

	HWND hwnd = CreateWindowExW(0, class_name, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, self);
	self->message_hwnd = hwnd;
	self->worker_ready = true;
	if (hwnd == nullptr) {
		return 1;
	}

	MSG msg = {};
	while (!self->worker_stop.load() && GetMessageW(&msg, nullptr, 0, 0) > 0) {
		TranslateMessage(&msg);
		DispatchMessageW(&msg);
	}

	if (hwnd != nullptr) {
		DestroyWindow(hwnd);
	}
	UnregisterClassW(class_name, wc.hInstance);
	self->message_hwnd = nullptr;
	return 0;
}

#endif
