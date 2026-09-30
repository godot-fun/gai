## Unit test runner — attach this script to a scene root to run `.gd` tests in the same folder.
##
## Setup
## -----
## 1. Create a scene (e.g. `test/utils/UtilsTest.tscn`) and attach `UnitTest.gd` to its root node.
## 2. Place test scripts beside the scene (e.g. `test/utils/StringUtilsTest.gd`).
## 3. Run the scene from the editor or CLI; all matching tests in the folder are executed, then the app quits.
##
## Test discovery
## --------------
## - Scans every `.gd` file in the scene's folder (see [member include_subfolders]).
## - A method is a test when its name **starts or ends with `test`** (case-insensitive).
## - Test methods must take **no arguments**; otherwise the run fails immediately.
##
## Writing tests
## -------------
## - Use `assert(...)` for expectations. Any failed assertion logs an error and stops the run.
## - **Instance methods** — the script must be instantiable (`script.new()`); run on a fresh instance.
## - **Static methods** — run on the script directly; static tests run before instance tests.
##
## Example
## -------
## ```gdscript
## func substring_before_test() -> void:
## 	assert(StringUtils.substring_before("a/b/c", "/") == "a")
## 	pass
##
## static func OSUtils_is_windows_test() -> void:
## 	assert(OSUtils.is_windows() == (OS.get_name() == "Windows"))
## 	pass
## ```
##
## IntegrationTest
## ---------------
## When this scene is loaded by [IntegrationTest], it emits [code]gdf.events.test_passed[/code]
## instead of quitting so the runner can advance to the next test scene.
extends Node

# Include files in subfolders
@export var include_subfolders: bool = false

@export var enable_test_logging: bool = true

var error_occurred: bool = false

func _ready() -> void:
	var current_scene_path := NodeUtils.scene_file_path_from_node(self)
	var scan_path := current_scene_path.get_base_dir()
	var files: Array[String] = FileUtils.get_all_files_in_folder(scan_path, include_subfolders)
	gdf.events.log_error.connect(func() -> void: error_occurred = true)
	for file in files:
		if !file.ends_with(".gd"):
			continue
		var res: Resource = ResourceLoader.load(file)
		if res is Script:
			await unit_test(res)
	# IntegrationTest advances to the next scene only after this signal.
	if IntegrationTest.is_integration_test:
		gdf.events.test_passed.emit()
	else:
		gdf.shutdown()
	pass


func unit_test(script: Script) -> void:
	var stop_watch: StopWatch = StopWatch.new()
	var static_test_methods: Array[String] = []
	var test_methods: Array[String] = []
	for method in script.get_script_method_list():
		var method_name: String = method.name
		var method_name_lower: String= method_name.to_lower()
		if !(method_name_lower.ends_with("test") || method_name_lower.begins_with("test")):
			continue
		if !method.args.is_empty():
			Log.error("❌ FAIL | [{}] | method:[{}] args is not empty", script.resource_path, method_name)
			gdf.shutdown(1)
			return
		var is_static: int = method.flags & METHOD_FLAG_STATIC
		if is_static:
			static_test_methods.push_back(method_name)
		else:
			test_methods.push_back(method_name)
	
	for method in static_test_methods:
		await script.call(method)
		await check_unit(script, method)
	
	if ArrayUtils.is_not_empty(test_methods):
		if !script.can_instantiate():
			Log.error("❌ FAIL | [{}] | can not instantiate this script", script.resource_path)
			gdf.shutdown(1)
			return
		var obj: Object= script.new()
		for method in test_methods:
			await obj.call(method)
			await check_unit(script, method)
	var test_unit := static_test_methods.size() + test_methods.size()
	Log.info("✅ PASS | [{}] | Run test unit:[{}] | {} seconds", script.resource_path, test_unit, stop_watch.cost_seconds())
	pass


func check_unit(script: Script, method: String) -> void:
	if error_occurred:
		Log.error("❌ FAIL | [{}] | {}", script.resource_path, method)
		await gdf.shutdown(1)
		return
	if enable_test_logging:
		Log.info("🟢 PASS | [{}] | {}", script.resource_path, method)
	pass