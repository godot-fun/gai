extends RefCounted


static func context_usage_test() -> void:
	var effect := ContextMemoryRiver.new()
	var usage := OpenAiUsage.new()
	usage.prompt_tokens = 64_000
	usage.completion_tokens = 2_000
	effect.on_message_complete(1, usage)
	assert(is_equal_approx(effect.context_ratio(), 0.5))
	effect.free()
	pass


static func delivered_item_expires_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.size = Vector2(1000.0, 600.0)
	effect.add_item(ContextMemoryRiver.StreamType.USER, "USER")
	effect.visible = true
	effect._process(10.0)
	assert(effect.items.is_empty())
	effect.free()
	pass


static func saturated_stream_preserves_in_flight_items_test() -> void:
	var effect := ContextMemoryRiver.new()
	for index in range(ContextMemoryRiver.MAX_ITEMS):
		effect.add_item(ContextMemoryRiver.StreamType.USER, "USER")
	var oldest := effect.items[0]
	effect.add_item(ContextMemoryRiver.StreamType.USER, "NEW")
	assert(effect.items.size() == ContextMemoryRiver.MAX_ITEMS)
	assert(effect.items[0] == oldest)
	effect.free()
	pass


static func absorption_ripple_spread_follows_label_width_test() -> void:
	assert(is_equal_approx(ContextMemoryRiver.absorption_ripple_spread(0.0), ContextMemoryRiver.ABSORPTION_RIPPLE_SPREAD_MIN))
	assert(ContextMemoryRiver.absorption_ripple_spread(80.0) > ContextMemoryRiver.absorption_ripple_spread(20.0))
	assert(is_equal_approx(ContextMemoryRiver.absorption_ripple_spread(400.0), ContextMemoryRiver.ABSORPTION_RIPPLE_SPREAD_MAX))
	pass


static func absorption_spawns_one_output_mote_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.add_item(ContextMemoryRiver.StreamType.TOOL, "READ")
	var item: ContextMemoryRiver.StreamItem = effect.items.pop_front()
	effect.pending_output_widths.append(40.0)
	effect.add_absorption_effect(item)
	effect.visible = true
	effect._process(ContextMemoryRiver.ABSORPTION_DURATION * 0.51)
	assert(effect.output_motes.size() == 1)
	assert(effect.absorption_effects[0].output_released)
	effect.free()
	pass


static func text_fades_only_after_lens_center_test() -> void:
	assert(is_equal_approx(ContextMemoryRiver.center_fade_alpha(499.0, 500.0), 1.0))
	assert(is_equal_approx(ContextMemoryRiver.center_fade_alpha(500.0, 500.0), 1.0))
	assert(ContextMemoryRiver.center_fade_alpha(527.0, 500.0) < 1.0)
	assert(is_zero_approx(ContextMemoryRiver.center_fade_alpha(554.0, 500.0)))
	pass


static func output_starts_at_ring_right_edge_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.size = Vector2(1000.0, 600.0)
	var center := effect.size * 0.5
	var start := effect.output_spiral_position(0.0, 0.0, center)
	assert(is_equal_approx(start.x, center.x + ContextMemoryRiver.CONTEXT_RING_RADIUS))
	assert(is_equal_approx(start.y, center.y))
	effect.free()
	pass


static func output_trail_length_follows_input_width_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.size = Vector2(1000.0, 600.0)
	effect.spawn_output_mote(40.0, 0.84)
	effect.spawn_output_mote(180.0, 1.16)
	assert(is_equal_approx(effect.output_motes[0].trail_length, 40.0))
	assert(is_equal_approx(effect.output_motes[1].trail_length, 180.0))
	assert(is_equal_approx(effect.output_motes[0].speed, 0.84))
	assert(is_equal_approx(effect.output_motes[1].speed, 1.16))
	effect.spawn_output_mote(1000.0)
	assert(is_equal_approx(effect.output_motes[2].trail_length, 498.0))
	effect.free()
	pass


static func long_text_crosses_center_before_expiring_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.size = Vector2(1000.0, 600.0)
	effect.visible = true
	effect.add_item(ContextMemoryRiver.StreamType.USER, "This deliberately long sentence must keep moving until every glyph crosses the center.")
	var item: ContextMemoryRiver.StreamItem = effect.items[0]
	for _frame in range(400):
		if item.absorption_triggered:
			break
		effect._process(0.05)
	assert(item.absorption_triggered)
	assert(effect.items.has(item))
	assert(item_position_x(item, effect) >= effect.size.x * 0.5)
	assert(effect.absorption_effects.size() == 1)
	for _frame in range(400):
		if not effect.items.has(item):
			break
		effect._process(0.05)
	assert(not effect.items.has(item))
	assert(item.absorption_triggered)
	effect.free()
	pass


## The straight pass spends much less progress per screen pixel than the approach, so a
## step estimated on the approach side used to fling wide phrases across the lens and make
## the visible text collapse in a single frame.
static func long_text_keeps_constant_speed_through_lens_test() -> void:
	var effect := ContextMemoryRiver.new()
	effect.size = Vector2(1000.0, 600.0)
	effect.visible = true
	effect.add_item(ContextMemoryRiver.StreamType.USER, "This deliberately long sentence keeps every glyph evenly spaced while it slides through the lens and dissolves past the center.")
	var item: ContextMemoryRiver.StreamItem = effect.items[0]
	var center := effect.size * 0.5
	var delta := 1.0 / 60.0
	var frame_budget := delta * ContextMemoryRiver.INPUT_TRAVEL_SPEED * item.speed * 1.05
	var previous := effect.item_position(item.progress, item, center)
	var max_move := 0.0
	for _frame in range(2000):
		effect._process(delta)
		if not effect.items.has(item):
			break
		var position := effect.item_position(item.progress, item, center)
		max_move = maxf(max_move, previous.distance_to(position))
		previous = position
	assert(item.absorption_triggered)
	assert(max_move <= frame_budget)
	effect.free()
	pass


static func item_position_x(item: ContextMemoryRiver.StreamItem, effect: ContextMemoryRiver) -> float:
	return effect.item_position(item.progress, item, effect.size * 0.5).x
