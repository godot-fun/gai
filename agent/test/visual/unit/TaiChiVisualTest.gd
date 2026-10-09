extends Node


func complete_animation_switch_is_global_test() -> void:
	TaiChi.complete_animation_on_agent_end = true
	var first := TaiChi.new()
	var second := TaiChi.new()
	assert(first.complete_animation_on_agent_end)
	assert(second.complete_animation_on_agent_end)
	TaiChi.complete_animation_on_agent_end = false
	first.free()
	second.free()
	pass
