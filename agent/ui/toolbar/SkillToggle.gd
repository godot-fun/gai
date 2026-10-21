class_name SkillToggle
extends RefCounted

## Toolbar toggle for the skill index prompt (session append/remove).

var button: Button


func setup(p_button: Button) -> void:
	button = p_button
	button.toggled.connect(on_toggled)
	gdf.events.theme_changed.connect(refresh_toggle_button)
	gdf.events.theme_color_changed.connect(refresh_toggle_button)
	gdf.events.locale_changed.connect(refresh_toggle_button)
	refresh_toggle_button()
	pass


func refresh_toggle_button() -> void:
	var enabled := AgentSetting.get_skill_in_prompt_enabled()
	var tooltip := I18n.t("agent.toolbar.add_skills") if not enabled else I18n.t("agent.toolbar.remove_skills")
	AgentToolbarButton.style(button, tooltip)
	button.set_block_signals(true)
	button.button_pressed = enabled
	button.set_block_signals(false)
	pass


func on_toggled(enabled: bool) -> void:
	AgentSetting.set_skill_in_prompt_enabled(enabled)

	refresh_toggle_button()
	
	var session_id := AgentSessionManager.active_session_id
	if AgentSessionManager.has_chat_history(session_id):
		return
	
	if enabled:
		ContextInjectionManager.append_skill(session_id)
	else:
		ContextInjectionManager.remove_skill(session_id)
	AgentSessionManager.persist_session(session_id)
	AgentEvents.events.skill_context_changed.emit(session_id)
	pass
