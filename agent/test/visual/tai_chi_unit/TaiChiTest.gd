extends RefCounted

const OPENING_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiOpeningFlow.gd")
const DUALITY_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiDualityFlow.gd")
const TOOL_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiToolFlow.gd")
const COMPLETION_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiCompletionFlow.gd")


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.TAI_CHI))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.TAI_CHI)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.TAI_CHI)
	effect.free()
	control.free()
	pass


func opening_reveals_line_and_title_together_test() -> void:
	var flow := OPENING_FLOW_SCRIPT.new()
	assert(flow.line_progress() == 0.0)
	assert(flow.title_progress() == 0.0)
	flow.advance(OPENING_FLOW_SCRIPT.REVEAL_SECONDS * 0.25)
	assert(flow.line_progress() > 0.0)
	assert(flow.title_progress() > 0.0)
	assert(is_equal_approx(flow.line_progress(), flow.title_progress()))
	flow.advance(OPENING_FLOW_SCRIPT.REVEAL_SECONDS)
	assert(flow.line_progress() == 1.0)
	assert(flow.title_progress() == 1.0)
	pass


func tools_travel_from_center_test() -> void:
	var flow := TOOL_FLOW_SCRIPT.new()
	flow.begin("one")
	flow.advance(0.5)
	assert(float(flow.tools["one"]["progress"]) > 0.0)
	flow.finish("one", false)
	assert(bool(flow.tools["one"]["done"]))
	assert(not bool(flow.tools["one"]["failed"]))
	pass


func duality_opens_a_center_gap_test() -> void:
	var flow := DUALITY_FLOW_SCRIPT.new()
	assert(flow.BOTTOM_TITLE == "一阴一阳之谓道")
	assert(not flow.active)
	flow.begin()
	flow.advance(DUALITY_FLOW_SCRIPT.TRANSITION_SECONDS * 0.5)
	assert(flow.active)
	assert(flow.progress() > 0.0 and flow.progress() < 1.0)
	assert(flow.title_opacity() < 1.0)
	flow.advance(DUALITY_FLOW_SCRIPT.TRANSITION_SECONDS)
	assert(flow.progress() == 1.0)
	assert(flow.title_opacity() == 0.0)
	pass


func completion_records_error_state_test() -> void:
	var flow := COMPLETION_FLOW_SCRIPT.new()
	flow.begin(true)
	flow.advance(COMPLETION_FLOW_SCRIPT.DURATION)
	assert(flow.active)
	assert(flow.failed)
	assert(flow.progress == 1.0)
	pass
