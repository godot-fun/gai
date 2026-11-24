class_name ChatModelSelector
extends RefCounted

## Owns the model and reasoning-effort controls shown in the expanded chat composer.

var model_button: MenuButton
var reasoning_effort_button: MenuButton
var expanded: bool = false


func setup(parent: Control) -> void:
	model_button = MenuButton.new()
	model_button.name = "ModelSelector"
	model_button.focus_mode = Control.FOCUS_NONE
	model_button.clip_text = false
	model_button.get_popup().id_pressed.connect(on_model_selected)
	parent.add_child(model_button)

	reasoning_effort_button = MenuButton.new()
	reasoning_effort_button.name = "ReasoningEffortSelector"
	reasoning_effort_button.focus_mode = Control.FOCUS_NONE
	reasoning_effort_button.clip_text = false
	reasoning_effort_button.get_popup().id_pressed.connect(on_reasoning_effort_selected)
	parent.add_child(reasoning_effort_button)

	AgentEvents.events.api_models_changed.connect(refresh)
	refresh()
	layout(false)
	pass


func refresh() -> void:
	if model_button == null or reasoning_effort_button == null:
		return
	refresh_model()
	refresh_reasoning_effort()
	apply_theme()
	if expanded:
		layout(true)
	pass


func refresh_model() -> void:
	var models := ApiSetting.get_models()
	var session_model := get_session_model()
	model_button.text = session_model + "  ▾"
	model_button.tooltip_text = I18n.t("agent.input.select_model") + ": " + session_model
	var popup := model_button.get_popup()
	popup.clear()
	for index in range(models.size()):
		popup.add_radio_check_item(models[index], index)
		popup.set_item_checked(index, models[index] == session_model)
	pass


func refresh_reasoning_effort() -> void:
	var effort := get_session_reasoning_effort()
	var effort_text := I18n.t("agent.reasoning_effort." + effort)
	reasoning_effort_button.text = effort_text + "  ▾"
	reasoning_effort_button.tooltip_text = I18n.t("agent.input.reasoning_effort") + ": " + effort_text
	var popup := reasoning_effort_button.get_popup()
	popup.clear()
	for index in range(ApiSetting.REASONING_EFFORTS.size()):
		var item_effort := ApiSetting.REASONING_EFFORTS[index]
		popup.add_radio_check_item(I18n.t("agent.reasoning_effort." + item_effort), index)
		popup.set_item_checked(index, item_effort == effort)
	pass


func on_model_selected(index: int) -> void:
	var models := ApiSetting.get_models()
	if index < 0 or index >= models.size():
		return
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null or session.model == models[index]:
		return
	session.model = models[index]
	AgentSessionManager.persist_session(session.id)
	refresh()
	pass


func on_reasoning_effort_selected(index: int) -> void:
	if index < 0 or index >= ApiSetting.REASONING_EFFORTS.size():
		return
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null or session.reasoning_effort == ApiSetting.REASONING_EFFORTS[index]:
		return
	session.reasoning_effort = ApiSetting.REASONING_EFFORTS[index]
	AgentSessionManager.persist_session(session.id)
	refresh()
	pass


func get_session_model() -> String:
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	var models := ApiSetting.get_models()
	if session == null:
		return ApiSetting.get_active_profile().model
	if session.model in models:
		return session.model
	session.model = ApiSetting.get_active_profile().model
	AgentSessionManager.persist_session(session.id)
	return session.model


func get_session_reasoning_effort() -> String:
	var session := AgentSessionStore.load_session(AgentSessionManager.active_session_id)
	if session == null:
		return ApiSetting.get_reasoning_effort()
	if session.reasoning_effort not in ApiSetting.REASONING_EFFORTS:
		session.reasoning_effort = ApiSetting.get_reasoning_effort()
		AgentSessionManager.persist_session(session.id)
	return session.reasoning_effort


func apply_theme() -> void:
	if model_button == null or reasoning_effort_button == null:
		return
	apply_button_theme(model_button)
	apply_button_theme(reasoning_effort_button)
	pass


func apply_button_theme(button: MenuButton) -> void:
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.surface_container_high,
		ControlSize.radius_md, Margin.ma_2, Margin.ma_1)
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, Colors.hover(Colors.surface_container_high))
	ButtonStyle.apply_style(button, normal, hover, normal.duplicate() as StyleBoxFlat)
	PopupMenuStyle.apply(button.get_popup())
	pass


func layout(is_expanded: bool) -> void:
	expanded = is_expanded
	model_button.visible = expanded
	reasoning_effort_button.visible = expanded
	if not expanded:
		return
	var inset := float(Margin.ma_1)
	place_button(reasoning_effort_button, ControlSize.md + Margin.ma_1 + inset)
	var effort_width := reasoning_effort_button.get_combined_minimum_size().x
	place_button(model_button, effort_width + ControlSize.md + Margin.ma_2 + inset)
	pass


func place_button(button: MenuButton, right_offset: float) -> void:
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BOTH
	button.custom_minimum_size = Vector2(0, ControlSize.md)
	var button_width := button.get_combined_minimum_size().x
	button.offset_left = -button_width - right_offset
	button.offset_top = -ControlSize.md - Margin.ma_1
	button.offset_right = -right_offset
	button.offset_bottom = -Margin.ma_1
	button.z_index = 2
	pass


func is_popup_visible() -> bool:
	return model_button.get_popup().visible or reasoning_effort_button.get_popup().visible
