extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.CYBER_COMMAND_DECK))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.CYBER_COMMAND_DECK)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.CYBER_COMMAND_DECK)
	effect.free()
	control.free()
	pass


func concurrent_tool_pods_test() -> void:
	var effect := CyberCommandDeck.new()
	effect.visible = true
	effect.on_tool_execution_start("read-1", "read", {"path": "res://a.gd"})
	effect.on_tool_execution_start("write-1", "write", {"path": "res://b.gd"})
	assert(effect.pods.size() == 2)
	assert(effect.active_pod_count() == 2)
	effect._process(CyberCommandDeck.CONNECT_SECONDS)
	assert(int(effect.pods[0]["state"]) == CyberCommandDeck.PodState.EXECUTING)
	assert(int(effect.pods[1]["state"]) == CyberCommandDeck.PodState.EXECUTING)
	effect.on_tool_execution_end("read-1", "read", AgentToolResult.ok("done"))
	assert(int(effect.pods[0]["state"]) == CyberCommandDeck.PodState.EXECUTING)
	effect._process(CyberCommandDeck.MIN_EXECUTION_SECONDS)
	assert(CyberCommandDeck.pod_status(effect.pods[0]["state"]) == "COMPLETE")
	assert(effect.active_pod_count() == 1)
	effect.free()
	pass


func completion_sequence_test() -> void:
	var effect := CyberCommandDeck.new()
	effect.on_agent_start(7)
	assert(effect.phase == CyberCommandDeck.DeckPhase.ACTIVE)
	assert(effect.on_agent_end("") == 0.0)
	assert(effect.end_requested)
	assert(effect.phase == CyberCommandDeck.DeckPhase.ACTIVE)
	effect.free()
	pass


func radar_angle_stays_continuous_across_phase_changes_test() -> void:
	var effect := CyberCommandDeck.new()
	effect.visible = true
	effect.phase = CyberCommandDeck.DeckPhase.REASONING
	effect._process(0.1)
	var reasoning_angle := effect.radar_angle
	effect.phase = CyberCommandDeck.DeckPhase.RESPONDING
	effect._process(0.1)
	assert(is_equal_approx(reasoning_angle, 0.15))
	assert(is_equal_approx(effect.radar_angle, reasoning_angle + 0.055))
	effect.free()
	pass


func palette_follows_accent_theme_color_test() -> void:
	var original: Color = ThemeColor.theme_color
	ThemeColor.theme_color = Color(0.2, 0.45, 1.0)
	ThemeColor.refresh_derived_colors()
	assert(CyberCommandDeck.neon_cyan() == ThemeColor.accent_theme_color())
	assert(CyberCommandDeck.neon_blue() != CyberCommandDeck.neon_cyan())
	assert(CyberCommandDeck.neon_magenta() != CyberCommandDeck.neon_cyan())
	assert(CyberCommandDeck.pod_color(CyberCommandDeck.PodState.EXECUTING) == ThemeColor.accent_theme_color())
	assert(CyberCommandDeck.pod_color(CyberCommandDeck.PodState.CONNECTING) == CyberCommandDeck.neon_magenta())
	ThemeColor.theme_color = Color(1.0, 0.35, 0.05)
	ThemeColor.refresh_derived_colors()
	assert(CyberCommandDeck.neon_cyan() == ThemeColor.accent_theme_color())
	assert(CyberCommandDeck.pod_color(CyberCommandDeck.PodState.EXECUTING) == ThemeColor.accent_theme_color())
	ThemeColor.theme_color = original
	ThemeColor.refresh_derived_colors()
	pass


func full_deck_replaces_head_without_reflow_test() -> void:
	var effect := CyberCommandDeck.new()
	for index in range(CyberCommandDeck.MAX_PODS):
		effect.on_tool_execution_start("call-%d" % index, "read", {})
	var stable_second: Dictionary = effect.pods[1]
	var stable_last: Dictionary = effect.pods[CyberCommandDeck.MAX_PODS - 1]
	effect.on_tool_execution_start("replacement", "write", {})
	assert(effect.pods.size() == CyberCommandDeck.MAX_PODS)
	assert(String(effect.pods[0]["id"]) == "replacement")
	assert(int(effect.pods[0]["slot"]) == 0)
	assert(effect.pods[1] == stable_second)
	assert(effect.pods[CyberCommandDeck.MAX_PODS - 1] == stable_last)
	assert(not effect.pod_by_id.has("call-0"))
	assert(effect.pod_by_id.has("replacement"))
	effect.on_tool_execution_start("replacement-2", "edit", {})
	assert(effect.pods.size() == CyberCommandDeck.MAX_PODS)
	assert(String(effect.pods[0]["id"]) == "replacement")
	assert(String(effect.pods[1]["id"]) == "replacement-2")
	assert(int(effect.pods[1]["slot"]) == 1)
	assert(not effect.pod_by_id.has("call-1"))
	for index in range(2, CyberCommandDeck.MAX_PODS):
		assert(String(effect.pods[index]["id"]) == "call-%d" % index)
	effect.free()
	pass
