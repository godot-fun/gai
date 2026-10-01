# C++ (godot-cpp)

GAI supports [godot-cpp](https://github.com/godotengine/godot-cpp) GDExtensions for Godot 4.6. Native classes live under `cpp/` and are loaded through `gai_cpp.gdextension`.

## Layout

```
cpp/
├── SConstruct
├── gai_cpp.gdextension
├── src/                 # C++ sources
└── bin/<platform>/      # built shared libraries
```

Upstream godot-cpp is installed at `.dependency/godot-cpp/` (see `.dependency/manifest.json`).

## Prerequisites

- Visual Studio C++ toolset (Windows), or clang / gcc on other platforms
- Default Python at `.dependency/python/` (manifest entry `python`)
- SCons at `.dependency/scons/` — its `.venv` is created from `.dependency/python/`, not host Python
- godot-cpp under `.dependency/godot-cpp/`

Always invoke the SCons binary under `.dependency/scons/.venv/` (see Build). Do not use a system `scons` or a venv based on host `python` / `py`.

```powershell
# If scons is missing: create the venv with default python, then install scons
.dependency\python\python.exe -m venv .dependency\scons\.venv
.dependency\scons\.venv\Scripts\python.exe -m pip install scons

git clone --depth 1 https://github.com/godotengine/godot-cpp.git .dependency/godot-cpp
```

## Build

From `cpp/`, in a Visual Studio Developer shell (or after `vcvars64.bat`):

```powershell
cd cpp
..\.dependency\scons\.venv\Scripts\scons.exe api_version=4.6 target=template_debug
```

Release:

```powershell
..\.dependency\scons\.venv\Scripts\scons.exe api_version=4.6 target=template_release
```

## Usage

Native classes registered by the extension are available to GDScript like any other Godot type.

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

```gdscript
func _ready() -> void:
	GlobalHotkey.hotkey_pressed.connect(on_hotkey)
	# id, key, modifiers (KEY_MASK_* OR-ed together)
	GlobalHotkey.register_hotkey(1, KEY_F8, KEY_MASK_CTRL)
	pass

func on_hotkey(id: int) -> void:
	if id == 1:
		print("Ctrl+F8")
	pass

func _exit_tree() -> void:
	GlobalHotkey.unregister_hotkey(1)
	# or: GlobalHotkey.unregister_all()
	pass
```

`register_hotkey` with an existing `id` replaces that binding. Returns `false` if the key has no Windows VK (same gaps as Godot's `KeyMappingWindows::vk_map`, e.g. shifted punctuation like `KEY_EXCLAM`) or the OS rejects the combo.

`is_key_supported(key)` reports whether a Godot `Key` can be used as a hotkey on this platform.

`.godot/extension_list.cfg` must list `res://cpp/gai_cpp.gdextension` so the extension loads in the editor and in headless runs. Opening the project in the editor regenerates that file when needed.

## Test

```powershell
godot --headless --path . res://test/cpp/CppTest.tscn
```
