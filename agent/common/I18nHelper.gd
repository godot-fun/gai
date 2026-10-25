class_name I18nHelper
extends Object


class LocaleConfig:
	var locale_path: String
	var language: String

	func _init(path: String, locale_language: String) -> void:
		locale_path = path
		language = locale_language
		pass


static var LOCALE_PATHS: Dictionary[String, LocaleConfig] = {
	I18n.ZH: LocaleConfig.new("res://agent/config/locale/zh.json", "简体中文"),
	I18n.EN: LocaleConfig.new("res://agent/config/locale/en.json", "English"),
}

static func init_i18n() -> void:
	if I18n.is_initialized():
		return
	var locale := I18n.get_locale().get_slice("_", 0).get_slice("-", 0).to_lower()
	if not LOCALE_PATHS.has(locale):
		locale = I18n.EN
	var locale_config: LocaleConfig = LOCALE_PATHS.get(locale, LOCALE_PATHS[I18n.EN])
	I18n.set_locale(locale_config.locale_path)
	pass


## Resolved captions for Godot's internal FileDialog labels. UI callers pass this map to the
## reusable style helper, which intentionally has no dependency on the translation system.
static func file_dialog_label_texts() -> Dictionary[String, String]:
	return {
		"Path:": I18n.t("file_dialog.path"),
		"Favorites:": I18n.t("file_dialog.favorites"),
		"Recent:": I18n.t("file_dialog.recent"),
		"Directories & Files:": I18n.t("file_dialog.directories_and_files"),
		"Go to previous folder.": I18n.t("file_dialog.tooltip_previous_folder"),
		"Go to next folder.": I18n.t("file_dialog.tooltip_next_folder"),
		"Go to parent folder.": I18n.t("file_dialog.tooltip_parent_folder"),
		"Refresh files.": I18n.t("file_dialog.tooltip_refresh_files"),
		"(Un)favorite current folder.": I18n.t("file_dialog.tooltip_toggle_favorite"),
		"Create a new folder.": I18n.t("file_dialog.tooltip_create_folder"),
		"Toggle the visibility of hidden files.": I18n.t("file_dialog.tooltip_toggle_hidden_files"),
		"View items as a grid of thumbnails.": I18n.t("file_dialog.tooltip_thumbnail_grid"),
		"View items as a list.": I18n.t("file_dialog.tooltip_list"),
		"Toggle the visibility of the filter for file names.": I18n.t("file_dialog.tooltip_toggle_filename_filter"),
		"Sort files": I18n.t("file_dialog.tooltip_sort_files"),
		"Sort by Name (Ascending)": I18n.t("file_dialog.sort_name_ascending"),
		"Sort by Name (Descending)": I18n.t("file_dialog.sort_name_descending"),
		"Sort by Type (Ascending)": I18n.t("file_dialog.sort_type_ascending"),
		"Sort by Type (Descending)": I18n.t("file_dialog.sort_type_descending"),
		"Sort by Modified Time (Newest First)": I18n.t("file_dialog.sort_modified_newest"),
		"Sort by Modified Time (Oldest First)": I18n.t("file_dialog.sort_modified_oldest"),
	}
