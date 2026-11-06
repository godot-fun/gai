class_name EditorDiscovery
extends RefCounted

## Finds workspace editors from the host OS and the user-configured executable path.

const BUILTIN_ID := "builtin"
const CODE_ICON_PATH := "res://icon.svg"

static var cached_editors: Array[EditorApplication] = []


# ---------------------------------------------------------------------------
# Builtin editor and discovery cache
# ---------------------------------------------------------------------------

static func discover() -> Array[EditorApplication]:
	if not cached_editors.is_empty():
		return copy_cached_editors()
	var builtin_label := I18n.t("editor.builtin")
	var custom_path := AgentSetting.get_custom_editor_path()
	var editors: Array[EditorApplication] = [EditorApplication.new(BUILTIN_ID, builtin_label, "", CODE_ICON_PATH)]
	if OSUtils.is_windows():
		add_windows_editor(editors, "visual_studio", "Visual Studio", ["devenv.exe"], [], "res://agent/asset/image/file/visualstudio.svg")
		add_windows_editor(editors, "vscode", "Visual Studio Code", ["code.exe", "code.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Microsoft VS Code/Code.exe")], "res://agent/asset/image/file/vscode.svg")
		add_windows_editor(editors, "vscode_insiders", "Visual Studio Code Insiders", ["code-insiders.exe", "code-insiders.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Microsoft VS Code Insiders/Code - Insiders.exe")], "res://agent/asset/image/file/vscode.svg")
		add_windows_editor(editors, "cursor", "Cursor", ["cursor.exe", "cursor.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/cursor/Cursor.exe")], "res://agent/asset/image/file/cursor.svg")
		add_windows_editor(editors, "windsurf", "Windsurf", ["windsurf.exe", "windsurf.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Windsurf/Windsurf.exe")])
		add_windows_editor(editors, "zed", "Zed", ["zed.exe"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Zed/zed.exe"), OS.get_environment("LOCALAPPDATA").path_join("Programs/Zed/Zed.exe")])
		add_windows_editor(editors, "vscodium", "VSCodium", ["codium.exe", "codium.cmd", "VSCodium.exe"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/VSCodium/VSCodium.exe")], "res://agent/asset/image/file/vscode.svg")
		add_windows_editor(editors, "sublime", "Sublime Text", ["subl.exe", "sublime_text.exe"], [OS.get_environment("PROGRAMFILES").path_join("Sublime Text/subl.exe"), OS.get_environment("PROGRAMFILES(X86)").path_join("Sublime Text/subl.exe")], "res://agent/asset/image/file/sublime.svg")
		add_windows_editor(editors, "notepad_plus_plus", "Notepad++", ["notepad++.exe"], [OS.get_environment("PROGRAMFILES").path_join("Notepad++/notepad++.exe"), OS.get_environment("PROGRAMFILES(X86)").path_join("Notepad++/notepad++.exe")])
		add_windows_editor(editors, "pulsar", "Pulsar", ["pulsar.exe", "pulsar.cmd"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Pulsar/Pulsar.exe")])
		add_windows_editor(editors, "lapce", "Lapce", ["lapce.exe"], [OS.get_environment("LOCALAPPDATA").path_join("Programs/Lapce/lapce.exe")])
		add_windows_editor(editors, "gvim", "GVim", ["gvim.exe"], [], "res://agent/asset/image/file/vim.svg")
		add_windows_editor(editors, "emacs", "Emacs", ["runemacs.exe", "emacs.exe"])
		add_windows_editor(editors, "idea", "IntelliJ IDEA", ["idea64.exe", "idea.exe"],
			jetbrains_paths(["IntelliJ IDEA", "IntelliJ IDEA Ultimate", "IntelliJ IDEA Community Edition"], ["idea64.exe", "idea.exe"]))
		add_windows_editor(editors, "rider", "Rider", ["rider64.exe", "rider.exe"],
			jetbrains_paths(["Rider"], ["rider64.exe", "rider.exe"]))
		add_windows_editor(editors, "pycharm", "PyCharm", ["pycharm64.exe", "pycharm.exe"],
			jetbrains_paths(["PyCharm", "PyCharm Professional", "PyCharm Community Edition"], ["pycharm64.exe", "pycharm.exe"]))
		add_windows_editor(editors, "clion", "CLion", ["clion64.exe", "clion.exe"],
			jetbrains_paths(["CLion"], ["clion64.exe", "clion.exe"]))
		add_windows_editor(editors, "webstorm", "WebStorm", ["webstorm64.exe", "webstorm.exe"], jetbrains_paths(["WebStorm"], ["webstorm64.exe", "webstorm.exe"]))
		add_windows_editor(editors, "goland", "GoLand", ["goland64.exe", "goland.exe"], jetbrains_paths(["GoLand"], ["goland64.exe", "goland.exe"]), "res://agent/asset/image/file/go.svg")
		add_windows_editor(editors, "phpstorm", "PhpStorm", ["phpstorm64.exe", "phpstorm.exe"], jetbrains_paths(["PhpStorm"], ["phpstorm64.exe", "phpstorm.exe"]), "res://agent/asset/image/file/php.svg")
		add_windows_editor(editors, "rubymine", "RubyMine", ["rubymine64.exe", "rubymine.exe"], jetbrains_paths(["RubyMine"], ["rubymine64.exe", "rubymine.exe"]), "res://agent/asset/image/file/ruby.svg")
		add_windows_editor(editors, "datagrip", "DataGrip", ["datagrip64.exe", "datagrip.exe"], jetbrains_paths(["DataGrip"], ["datagrip64.exe", "datagrip.exe"]), "res://agent/asset/image/file/database.svg")
		add_windows_editor(editors, "android_studio", "Android Studio", ["studio64.exe", "studio.exe"], jetbrains_paths(["Android Studio"], ["studio64.exe", "studio.exe"]), "res://agent/asset/image/file/android.svg")
	else:
		add_path_editor(editors, "vscode", "Visual Studio Code", ["code"])
		add_path_editor(editors, "vscode_insiders", "Visual Studio Code Insiders", ["code-insiders"])
		add_path_editor(editors, "cursor", "Cursor", ["cursor"])
		add_path_editor(editors, "windsurf", "Windsurf", ["windsurf"])
		add_path_editor(editors, "zed", "Zed", ["zed", "zeditor"])
		add_path_editor(editors, "vscodium", "VSCodium", ["codium"])
		add_path_editor(editors, "sublime", "Sublime Text", ["subl"])
		add_path_editor(editors, "pulsar", "Pulsar", ["pulsar"])
		add_path_editor(editors, "lapce", "Lapce", ["lapce"])
		add_path_editor(editors, "gvim", "GVim", ["gvim"])
		add_path_editor(editors, "emacs", "Emacs", ["emacs"])
		add_path_editor(editors, "idea", "IntelliJ IDEA", ["idea"])
		add_path_editor(editors, "rider", "Rider", ["rider"])
		add_path_editor(editors, "pycharm", "PyCharm", ["pycharm"])
		add_path_editor(editors, "clion", "CLion", ["clion"])
		add_path_editor(editors, "webstorm", "WebStorm", ["webstorm"])
		add_path_editor(editors, "goland", "GoLand", ["goland"])
		add_path_editor(editors, "phpstorm", "PhpStorm", ["phpstorm"])
		add_path_editor(editors, "rubymine", "RubyMine", ["rubymine"])
		add_path_editor(editors, "datagrip", "DataGrip", ["datagrip"])
		add_path_editor(editors, "android_studio", "Android Studio", ["studio", "android-studio"])
	add_custom_editor(editors, custom_path)
	cached_editors = editors
	return copy_cached_editors()


static func invalidate_cache() -> void:
	cached_editors.clear()
	pass


static func copy_cached_editors() -> Array[EditorApplication]:
	var result: Array[EditorApplication] = []
	result.assign(cached_editors)
	return result


# ---------------------------------------------------------------------------
# Open a workspace file
# ---------------------------------------------------------------------------

## Opens a file with the workspace editor selected in settings.
## Returns false when no configured editor handled the path, allowing the caller to use the OS default.
static func async_open_file(path: String) -> bool:
	var normalized := FileUtils.normalize_path(ProjectSettings.globalize_path(path))
	if normalized.is_empty() or not FileAccess.file_exists(normalized):
		return false
	var discovered: Variant = await ExecutorHelper.async_execute_pooled(discover)
	var editors := discovered as Array[EditorApplication]
	var selected := find_editor(editors, AgentSetting.get_workspace_editor())
	if selected == null or selected.id == BUILTIN_ID:
		return EditorWindow.show_file(normalized)
	var executable := selected.executable
	var arguments := selected.arguments.duplicate()
	arguments.append(normalized)
	if executable.get_extension().to_lower() == "cmd":
		arguments = PackedStringArray(["/c", executable]) + arguments
		executable = "cmd.exe"
	return OS.create_process(executable, arguments, false) >= 0


# ---------------------------------------------------------------------------
# Editor lookup
# ---------------------------------------------------------------------------

static func find_editor(editors: Array[EditorApplication], editor_id: String) -> EditorApplication:
	for editor in editors:
		if editor.id == editor_id:
			return editor
	return null


# ---------------------------------------------------------------------------
# Platform probe
# ---------------------------------------------------------------------------

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


static func jetbrains_paths(product_names: Array[String], executable_names: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	var roots: Array[String] = [OS.get_environment("LOCALAPPDATA").path_join("Programs"), OS.get_environment("PROGRAMFILES").path_join("JetBrains")]
	for root in roots:
		for product_name in product_names:
			for executable_name in executable_names:
				paths.append(root.path_join(product_name).path_join("bin").path_join(executable_name))
		if DirAccess.dir_exists_absolute(root):
			for installed_name in DirAccess.get_directories_at(root):
				for product_name in product_names:
					if not installed_name.to_lower().begins_with(product_name.to_lower()):
						continue
					for executable_name in executable_names:
						paths.append(root.path_join(installed_name).path_join("bin").path_join(executable_name))
	var toolbox_root := OS.get_environment("LOCALAPPDATA").path_join("JetBrains/Toolbox/apps")
	if DirAccess.dir_exists_absolute(toolbox_root):
		for executable_name in executable_names:
			paths.append_array(GlobUtils.glob(toolbox_root, "**/bin/" + executable_name, true, 0, [], false, 64))
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
