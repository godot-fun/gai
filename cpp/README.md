# C++ (godot-cpp)

GAI supports [godot-cpp](https://github.com/godotengine/godot-cpp) GDExtensions for Godot 4.6. Native classes live under `cpp/` and are loaded through `gai_cpp.gdextension`.

## Layout

```
cpp/
├── SConstruct              # Build entry (SCons)
├── methods.py              # SCons helpers
├── gai_cpp.gdextension     # Godot loader (not under addons/)
├── src/                    # C++ sources (ignored by Godot via .gdignore)
│   ├── summator.*
│   ├── global_hotkey.*
│   ├── native_os.*
│   └── register_types.*
└── bin/<platform>/         # Built shared libraries
```

Upstream godot-cpp is cloned to `.dependency/godot-cpp/` (same isolation model as other toolchains under `.dependency/`). That directory is gitignored; each machine clones it locally.

## Key files

These are the pieces that wire godot-cpp into this Godot project. Business classes (`Summator`, `GlobalHotkey`, `NativeOS`) sit under `src/` and are secondary to this bootstrap chain.

| File | Role |
| --- | --- |
| [`.godot/extension_list.cfg`](../.godot/extension_list.cfg) | Tells Godot **which** `.gdextension` files to load at startup. One line: `res://cpp/gai_cpp.gdextension`. Committed so headless/CI work without opening the editor first. |
| [`cpp/gai_cpp.gdextension`](gai_cpp.gdextension) | GDExtension manifest: `entry_symbol`, Godot version, and **per-platform library paths** under `bin/`. Godot reads this; it does not compile anything. |
| [`cpp/SConstruct`](SConstruct) | SCons build entry. Points at `../.dependency/godot-cpp`, sets `api_version=4.6`, compiles `src/*.cpp`, writes `bin/<platform>/gai_cpp.*.dll\|so\|dylib`. |
| [`cpp/src/register_types.cpp`](src/register_types.cpp) | C++ entry matching `entry_symbol` (`gai_cpp_library_init`). Registers classes with `ClassDB`, creates/destroys the `GlobalHotkey` and `NativeOS` Engine singletons on init/terminate. |
| [`.dependency/godot-cpp/`](../.dependency/godot-cpp/) | Upstream bindings (not in git). Headers + static lib your extension links against. Clone once per machine. |
| [`cpp/bin/<platform>/…`](bin/) | Built shared library that `[libraries]` in the `.gdextension` file points to. Without a matching binary, native classes never appear in GDScript. |

Load order at runtime:

```text
extension_list.cfg
  → gai_cpp.gdextension
    → bin/.../gai_cpp.*.dll (entry: gai_cpp_library_init)
      → register_types.cpp registers Summator / GlobalHotkey / NativeOS
```

Build order when developing C++:

```text
.dependency/godot-cpp  (+ VS / clang)
  → scons in cpp/ (SConstruct)
    → updates bin/
      → restart Godot (or rely on reloadable) to pick up the new library
```

## Prerequisites

- Godot **4.6+** (matches `compatibility_minimum` and `api_version=4.6`)
- Visual Studio C++ toolset (Windows), or clang / gcc on other platforms
- Default Python at `.dependency/python/` (manifest entry `python`)
- SCons at `.dependency/scons/` — its `.venv` is created from `.dependency/python/`, not host Python
- godot-cpp under `.dependency/godot-cpp/`

Always invoke the SCons binary under `.dependency/scons/.venv/` (see Build). Do not use a system `scons` or a venv based on host `python` / `py`.

```bash
# If scons is missing: create the venv with default python, then install scons
.dependency\python\python.exe -m venv .dependency\scons\.venv
.dependency\scons\.venv\Scripts\python.exe -m pip install scons

# godot-cpp: master + api_version=4.6 (see Build). Depth-1 clone is enough to compile.
git clone --depth 1 https://github.com/godotengine/godot-cpp.git .dependency/godot-cpp
```

## Build

From `cpp/`, in a Visual Studio Developer shell (or after `vcvars64.bat`):

```bash
cd cpp
..\.dependency\scons\.venv\Scripts\scons.exe api_version=4.6 target=template_debug
```

Release (needed for exported games; debug DLL alone is not enough):

```bash
..\.dependency\scons\.venv\Scripts\scons.exe api_version=4.6 target=template_release
```

The Windows **debug** DLL under `cpp/bin/windows/` is committed so a fresh clone can run/tests without compiling. After changing C++ sources, rebuild and commit the updated DLL when you want others to pick it up without building.

## Loading the extension

`.godot/extension_list.cfg` lists `res://cpp/gai_cpp.gdextension` and **is committed**. Headless runs and CI need that file; opening the project in the editor also regenerates it.

Without a matching binary for the current platform/target, Godot logs a GDExtension load error and native classes are missing.

## Usage

Native types are registered by the extension. `GlobalHotkey` and `NativeOS` are **Engine singletons** (use `GlobalHotkey.method(...)` / `NativeOS.method(...)`, do not `.new()`). `Summator` is a normal `RefCounted` class.

### Summator

```gdscript
var s := Summator.new()
s.add(10)
s.add(20)
print(s.get_total())  # 30
s.reset()
```

### GlobalHotkey (Windows)

OS-level hotkeys that fire even when the Godot window is in the background. Register and cancel at any time:

| Method / signal | Role |
| --- | --- |
| `register_hotkey(id, key, modifiers) -> bool` | Add or **replace** binding for `id` |
| `unregister_hotkey(id) -> bool` | Cancel one binding |
| `unregister_all()` | Cancel every binding |
| `is_registered(id) -> bool` | Query one id |
| `get_registered_ids() -> PackedInt32Array` | All registered ids |
| `is_key_supported(key) -> bool` | Whether `key` maps to a Windows VK |
| `hotkey_pressed(id)` | Signal on the main thread when the combo is pressed |
| `hotkey_released(id)` | Signal when the primary key or a required modifier is released (`GetAsyncKeyState` poll) |
| `is_hotkey_held(id)` | True between pressed and released |

```gdscript
func _ready() -> void:
	GlobalHotkey.hotkey_pressed.connect(on_hotkey_pressed)
	GlobalHotkey.hotkey_released.connect(on_hotkey_released)
	# id, key, modifiers (KEY_MASK_* OR-ed together)
	if not GlobalHotkey.is_key_supported(KEY_Z):
		return
	GlobalHotkey.register_hotkey(1, KEY_Z, KEY_MASK_CTRL | KEY_MASK_ALT)
	pass

func on_hotkey_pressed(id: int) -> void:
	if id == 1:
		print("hold start")
	pass

func on_hotkey_released(id: int) -> void:
	if id == 1:
		print("hold end")
	pass

func _exit_tree() -> void:
	GlobalHotkey.unregister_hotkey(1)
	# or: GlobalHotkey.unregister_all()
	pass
```

Notes:

- `register_hotkey` with an existing `id` replaces that binding.
- Returns `false` if the key has no Windows VK (same gaps as Godot's `KeyMappingWindows::vk_map`, e.g. shifted punctuation like `KEY_EXCLAM`) or the OS rejects the combo (often already taken).
- Auto-repeat is suppressed (`MOD_NOREPEAT`). Press is from `RegisterHotKey`; release is detected each frame with `GetAsyncKeyState` (Win32 has no hotkey key-up message).
- **Linux / macOS:** not implemented yet; `register_hotkey` returns false.

### NativeOS (Windows)

Native OS helpers for the foreground app while Godot is unfocused:

| Method | Role |
| --- | --- |
| `paste_clipboard()` | Synthesize Ctrl+V into the foreground window (after clipboard set) |
| `remember_foreground_window()` | Store the current foreground HWND; returns `bool` |
| `restore_foreground_window()` | Activate the remembered HWND and clear it; returns `bool` |
| `get_caret_screen_position()` | Foreground text caret in DisplayServer space, or `null` if unavailable |
| `capture_screen(path)` | Capture the full physical monitor under the mouse to a PNG file; returns `bool` |

```gdscript
NativeOS.remember_foreground_window()
# … briefly focus a Godot Window for keyboard input …
NativeOS.restore_foreground_window()
DisplayServer.clipboard_set("hello")
NativeOS.paste_clipboard()
var caret: Variant = NativeOS.get_caret_screen_position()
var ok: bool = NativeOS.capture_screen("user://sense/screen.png")
```

Notes:

- `remember_foreground_window` / `restore_foreground_window` pair a brief Godot focus steal (e.g. sense candidate picker) with returning activation to the typing target before `paste_clipboard`. Restore uses `AttachThreadInput` + `SetForegroundWindow`.
- `get_caret_screen_position` tries Win32 `GetGUIThreadInfo` first, then UI Automation (`TextPattern2.GetCaretRange` / text selection). Classic desktop controls usually hit the first path; Chrome/Electron/WPF often need UIA. Some apps never expose a caret.
- `paste_clipboard` uses Win32 `SendInput` (Ctrl+V). Put text on the clipboard first (`DisplayServer.clipboard_set`).
- `capture_screen` uses GDI `BitBlt` of `MonitorFromPoint` / `rcMonitor` (full physical screen under the cursor, including taskbar). Does not hide Godot overlays (beacon / toast may appear). Path is written via Godot `Image.save_png` (`user://`, absolute, etc.).
- **Linux / macOS:** not implemented yet; `paste_clipboard` / remember-restore / caret query / `capture_screen` return no-op / `false` / `null` / `false`.

## Test

From the repository root:

```bash
godot --headless --path . res://test/cpp/CppTest.tscn
```

Covers `Summator`, `GlobalHotkey` register / replace / unregister / key-mapping checks, and `NativeOS` caret / foreground remember-restore / screen-capture smoke. Does not simulate real keypresses in headless mode.
