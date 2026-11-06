class_name EditorDiscovery
extends RefCounted

## Finds workspace editors from the host OS and the user-configured executable path.

const BUILTIN_ID := "builtin"
const CODE_ICON_PATH := "res://agent/asset/image/ui/code.svg"
const FOLDER_ICON_PATH := "res://agent/asset/image/ui/folder_open.svg"
const GIT_ICON_PATH := "res://agent/asset/image/file/git.svg"

static var cached_editors: Array[EditorApplication] = []


static func discover() -> Array[EditorApplication]:
	if not cached_editors.is_empty():
		return copy_cached_editors()
	var builtin_label := I18n.t("editor.builtin")
	var explorer_label := I18n.t("editor.file_explorer")
	var custom_path := AgentSetting.get_custom_editor_path()
	var editors: Array[EditorApplication] = [EditorApplication.new(BUILTIN_ID, builtin_label, "", CODE_ICON_PATH)]
	if OSUtils.is_windows():
		add_windows_editor(editors, "visual_studio", "Visual Studio", ["devenv.exe"], [], "res://agent/asset/image/file/visualstudio.svg")
		add_windows_editor(editors, "vscode", "Visual Studio Code", ["code.exe", "code.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Microsoft VS Code/Code.exe")], "res://agent/asset/image/file/vscode.svg")
		add_windows_editor(editors, "cursor", "Cursor", ["cursor.exe", "cursor.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/cursor/Cursor.exe")], "res://agent/asset/image/file/cursor.svg")
		editors.append(EditorApplication.new("explorer", explorer_label, "explorer.exe", FOLDER_ICON_PATH))
		add_git_bash(editors)
		add_windows_editor(editors, "idea", "IntelliJ IDEA", ["idea64.exe", "idea.exe"],
			jetbrains_paths("IntelliJ IDEA", ["idea64.exe", "idea.exe"]))
		add_windows_editor(editors, "rider", "Rider", ["rider64.exe", "rider.exe"],
			jetbrains_paths("Rider", ["rider64.exe", "rider.exe"]))
		add_windows_editor(editors, "pycharm", "PyCharm", ["pycharm64.exe", "pycharm.exe"],
			jetbrains_paths("PyCharm", ["pycharm64.exe", "pycharm.exe"]))
		add_windows_editor(editors, "clion", "CLion", ["clion64.exe", "clion.exe"],
			jetbrains_paths("CLion", ["clion64.exe", "clion.exe"]))
	else:
		add_path_editor(editors, "vscode", "Visual Studio Code", ["code"])
		add_path_editor(editors, "cursor", "Cursor", ["cursor"])
		add_path_editor(editors, "idea", "IntelliJ IDEA", ["idea"])
		add_path_editor(editors, "rider", "Rider", ["rider"])
		add_path_editor(editors, "pycharm", "PyCharm", ["pycharm"])
		add_path_editor(editors, "clion", "CLion", ["clion"])
	add_custom_editor(editors, custom_path)
	cached_editors = editors
	return copy_cached_editors()


static func invalidate_cache() -> void:
	cached_editors.clear()
	pass


static func add_git_bash(editors: Array[EditorApplication]) -> void:
	var common_paths: Array[String] = [OS.get_environment("PROGRAMFILES").path_join("Git/git-bash.exe")]
	var executable := find_windows_executable(["git-bash.exe"], common_paths)
	if executable.is_empty():
		return
	var installed_icon := executable.get_base_dir().path_join("mingw64/share/git/git-for-windows.ico")
	var icon_path := installed_icon if FileAccess.file_exists(installed_icon) else GIT_ICON_PATH
	editors.append(EditorApplication.new("git_bash", "Git Bash", executable, icon_path))
	pass


static func copy_cached_editors() -> Array[EditorApplication]:
	var result: Array[EditorApplication] = []
	result.assign(cached_editors)
	return result


static func add_custom_editor(editors: Array[EditorApplication], custom_path: String) -> void:
	if not custom_path.is_empty() and FileAccess.file_exists(custom_path):
		editors.append(EditorApplication.new("custom", custom_path.get_file().get_basename(), custom_path, CODE_ICON_PATH))
	pass


static func add_windows_editor(editors: Array[EditorApplication], id: String, label: String, executable_names: Array[String],
		common_paths: Array[String] = [], icon_path: String = CODE_ICON_PATH) -> void:
	var executable := find_windows_executable(executable_names, common_paths)
	if not executable.is_empty():
		editors.append(EditorApplication.new(id, label, executable, find_installed_icon(executable, icon_path)))
	pass


static func find_installed_icon(executable: String, fallback_path: String) -> String:
	if fallback_path != CODE_ICON_PATH:
		return fallback_path
	var executable_name := executable.get_file().get_basename().trim_suffix("64")
	var svg_path := executable.get_base_dir().path_join(executable_name + ".svg")
	if FileAccess.file_exists(svg_path):
		return svg_path
	var ico_path := executable.get_base_dir().path_join(executable_name + ".ico")
	return ico_path if FileAccess.file_exists(ico_path) else fallback_path


static func jetbrains_paths(product_name: String, executable_names: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	var programs_directory := OS.get_environment("LOCALAPPDATA").path_join("Programs")
	var bin_directory := programs_directory.path_join(product_name).path_join("bin")
	for executable_name: String in executable_names:
		paths.append(bin_directory.path_join(executable_name))
	return paths


static func add_path_editor(editors: Array[EditorApplication], id: String, label: String,
		executable_names: Array[String]) -> void:
	for executable_name: String in executable_names:
		var result := OSUtils.execute(PackedStringArray(["which", executable_name]), false)
		var output := result.output.build_string().strip_edges()
		if result.exit_code == 0 and not output.is_empty():
			editors.append(EditorApplication.new(id, label, output, CODE_ICON_PATH))
			return
	pass


static func find_windows_executable(executable_names: Array[String], common_paths: Array[String] = []) -> String:
	for common_path: String in common_paths:
		if FileAccess.file_exists(common_path):
			return common_path
	for executable_name: String in executable_names:
		var result := OSUtils.execute(PackedStringArray(["where.exe", executable_name]), false)
		if result.exit_code == 0:
			var paths := result.output.build_string().strip_edges().split("\n", false)
			if not paths.is_empty():
				return paths[0].strip_edges()
		var app_path := find_windows_app_path(executable_name)
		if not app_path.is_empty():
			return app_path
	return ""


static func find_windows_app_path(executable_name: String) -> String:
	var registry_keys: Array[String] = [
		"HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\" + executable_name,
		"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\" + executable_name,
		"HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\App Paths\\" + executable_name,
	]
	for key in registry_keys:
		var result := OSUtils.execute(PackedStringArray(["reg.exe", "query", key, "/ve"]), false)
		if result.exit_code != 0:
			continue
		for line in result.output.build_string().split("\n", false):
			var marker_index := line.find("REG_SZ")
			if marker_index < 0:
				continue
			var path := line.substr(marker_index + 6).strip_edges().trim_prefix("\"").trim_suffix("\"")
			if FileAccess.file_exists(path):
				return FileUtils.normalize_path(path)
	return ""
