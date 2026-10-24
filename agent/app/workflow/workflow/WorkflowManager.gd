class_name WorkflowManager
extends RefCounted

const WORKFLOW_EXT := ".workflow.json"
const USER_WORKFLOWS_DIR := "user://workflows/"

static var current_path: String = ""
static var workflow_name: String = "Untitled"


static func workflow_name_from_path(path: String) -> String:
	var file_name := path.get_file()
	if file_name.ends_with(WORKFLOW_EXT):
		return file_name.trim_suffix(WORKFLOW_EXT)
	return file_name.get_basename()


static func globalized_workflows_dir() -> String:
	return ProjectSettings.globalize_path(USER_WORKFLOWS_DIR)


static func list_saved_workflows() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(USER_WORKFLOWS_DIR)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.ends_with(WORKFLOW_EXT):
			result.append(USER_WORKFLOWS_DIR.path_join(file_name))
	result.sort()
	return result


static func new_workflow() -> void:
	current_path = ""
	workflow_name = "Untitled"
	pass


static func normalize_save_path(path: String) -> String:
	if path.ends_with(WORKFLOW_EXT):
		return path
	return path + WORKFLOW_EXT


static func save(path: String, doc: WorkflowDocument) -> void:
	current_path = normalize_save_path(path)
	workflow_name = workflow_name_from_path(current_path)
	doc.name = workflow_name
	var json := JsonUtils.object_to_json(doc)
	var write_error := FileUtils.write_string_to_file(current_path, json)
	if write_error != OK:
		Log.error("workflow save failed path:[{}] error:[{}]", current_path, error_string(write_error))
		return
	Log.info("Saved: [{}]", current_path)
	pass


static func load(path: String) -> WorkflowDocument:
	var text := FileAccess.get_file_as_string(path)
	var doc: WorkflowDocument = JsonUtils.json_to_object(text, WorkflowDocument)
	if doc == null:
		Log.error("Failed to load: [{}]", path)
		return null
	current_path = path
	workflow_name = workflow_name_from_path(path)
	Log.info("Loaded: [{}]", path)
	return doc
