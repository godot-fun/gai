class_name SettingSection
extends RefCounted

var ui: AgentSettingWindow
var heading_label: Label


func set_up(p_ui: AgentSettingWindow, _parent: VBoxContainer, _window: Window) -> void:
	ui = p_ui
	pass


func refresh() -> void:
	pass


func save() -> void:
	pass


func apply_locale() -> void:
	pass


func apply_theme() -> void:
	if heading_label != null:
		ui.style_heading(heading_label)
	pass
