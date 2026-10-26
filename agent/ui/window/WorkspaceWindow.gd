## Lazy workspace-folder picker shared by the toolbar and future workspace entry points.
class_name WorkspaceWindow
extends FileDialog

static var instance: WorkspaceWindow


func _init() -> void:
	title = I18n.t("agent.workspace.dialog_title")
	file_mode = FileDialog.FILE_MODE_OPEN_DIR
	access = FileDialog.ACCESS_FILESYSTEM
	ok_button_text = I18n.t("common.select")
	get_cancel_button().text = I18n.t("common.cancel")
	dir_selected.connect(on_dir_selected)
	gdf.events.locale_changed.connect(apply_locale)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	pass


func open() -> void:
	var workspace_root := AgentWorkspace.get_root()
	if DirAccess.dir_exists_absolute(workspace_root):
		current_dir = workspace_root
	FileDialogStyle.present_centered(self, 60, 70, I18nHelper.file_dialog_label_texts())
	pass


func apply_locale() -> void:
	title = I18n.t("agent.workspace.dialog_title")
	ok_button_text = I18n.t("common.select")
	get_cancel_button().text = I18n.t("common.cancel")
	FileDialogStyle.apply(self, I18nHelper.file_dialog_label_texts())
	pass


func apply_theme() -> void:
	FileDialogStyle.apply(self, I18nHelper.file_dialog_label_texts())
	pass


func on_dir_selected(path: String) -> void:
	AgentWorkspace.set_root(path)
	pass


####################################################################################################
# Static methods


static func show_workspace() -> void:
	if instance == null or not is_instance_valid(instance):
		instance = WorkspaceWindow.new()
		gdf.gdf_node.add_child(instance)
	instance.open()
	pass
