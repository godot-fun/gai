## Integration test runner — attach this script to a scene root to run test scenes one by one.
##
## Setup
## -----
## 1. Create a scene (e.g. `test/TestIntegrationTest.tscn`) and attach `IntegrationTest.gd` to its root node.
## 2. Place test scenes in the same folder (or subfolders when [member include_subfolders] is enabled).
## 3. Run the integration scene; matching `.tscn` files are instantiated sequentially, then the app quits.
##
## Test discovery
## --------------
## - Scans `.tscn` files in the scene's folder whose basename **starts or ends with `test`**
##   (case-insensitive), e.g. `UtilsTest.tscn`, `Animation2DTest.tscn`.
## - Skips the integration scene itself and any scene whose basename starts`.
##
## Test scene contract
## -------------------
## Each test scene runs in isolation. When it finishes, it **must** emit
## [code]gdf.events.test_passed[/code] so the runner loads the next scene.
##
## - Scenes that use [UnitTest] emit the signal automatically after all unit tests pass.
## - Custom scenes must emit it themselves, e.g. after animations or async work complete:
##
## ```gdscript
## func _ready() -> void:
## 	await do_something()
## 	gdf.events.test_passed.emit()
## 	pass
## ```
##
## Failure handling
## ----------------
## Any [code]gdf.events.log_error[/code] during a test scene fails the run and exits with code 1.
extends Node
class_name IntegrationTest

static var is_integration_test: bool = false

# Include files in subfolders
@export var include_subfolders: bool = false

@export var enable_test_logging: bool = true

var error_occurred: bool = false
var test_scenes: Array[String] = []


func _ready() -> void:
	if is_integration_test:
		return
	is_integration_test = true
	gdf.events.log_error.connect(func() -> void: error_occurred = true)
	gdf.events.test_passed.connect(on_integration_test_passed)
	scan_test_scenes()
	gdf.callable_deferred(next_integration_test)
	pass


func _process(_delta: float) -> void:
	if !error_occurred:
		return
	var scene_path := test_scenes[0] if !test_scenes.is_empty() else ""
	Log.error("❌ FAIL | IntegrationTest | scene:[{}]", scene_path)
	error_occurred = false
	gdf.shutdown(1)
	pass


func scan_test_scenes() -> void:
	var current_scene_path := NodeUtils.scene_file_path_from_node(self)
	var scan_path := current_scene_path.get_base_dir()
	var files: Array[String] = FileUtils.get_all_files_in_folder(scan_path, include_subfolders)
	for file in files:
		if !file.ends_with(".tscn"):
			continue
		var scene_name := file.get_file().get_basename().to_lower()
		if !(scene_name.begins_with("test") || scene_name.ends_with("test")):
			continue
		if file == current_scene_path:
			continue
		test_scenes.push_back(file)
	if enable_test_logging:
		Log.info("🔎 SCAN | IntegrationTest | scenes:[{}] | scan_path:[{}]", test_scenes.size(), scan_path)
	pass


func on_integration_test_passed() -> void:
	test_scenes.pop_front()
	# Defer so the scene that emitted test_passed can finish _ready before we free it.
	gdf.callable_deferred(next_integration_test)
	pass


func next_integration_test() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	if test_scenes.is_empty():
		Log.info("🎉 DONE | IntegrationTest")
		await gdf.shutdown()
		return
	var scene_path := test_scenes[0]
	Log.info("🧪 TEST | IntegrationTest | remaining:[{}] | scene:[{}]", test_scenes.size() - 1, scene_path)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		Log.error("❌ FAIL | IntegrationTest | scene:[{}]", scene_path)
		await gdf.shutdown(1)
		return
	add_child(packed.instantiate())
	pass
