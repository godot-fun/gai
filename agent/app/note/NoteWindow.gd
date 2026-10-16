## Editable note popup built on [PopupWindow]. Content is loaded on open and saved when the window closes.
class_name NoteWindow
extends PopupWindow

const NOTE_FILE := "user://note.txt"


func _init() -> void:
	super()
	text_edit.editable = true
	text_edit.caret_blink = true
	gdf.events.locale_changed.connect(apply_locale)
	apply_locale()
	pass


func apply_locale() -> void:
	title = I18n.t("note.title")
	text_edit.placeholder_text = I18n.t("note.placeholder")
	pass


func style_text_edit() -> void:
	super.style_text_edit()
	text_edit.add_theme_color_override("font_placeholder_color", ThemeColor.body_color)
	pass


## Open a centered note editor. Width/height are percent of the screen (1–100).
static func show_note(width_percent: int = 60, height_percent: int = 80) -> void:
	close_open_notes()
	var window := NoteWindow.new()
	gdf.gdf_node.add_child(window)
	window.text_edit.text = FileUtils.read_file_to_string(NOTE_FILE)
	window.present_centered(width_percent, height_percent)
	pass


func on_close_requested() -> void:
	var content := text_edit.text
	if content != FileUtils.read_file_to_string(NOTE_FILE):
		if not FileUtils.write_string_to_file(NOTE_FILE, content):
			Alert.alert(I18n.t("note.save_failed"), Colors.error)
	super.on_close_requested()
	pass


static func close_open_notes() -> void:
	var open: Array[NoteWindow] = []
	for child in gdf.gdf_node.get_children():
		if child is NoteWindow:
			open.push_back(child)
	for window in open:
		window.on_close_requested()
	pass
