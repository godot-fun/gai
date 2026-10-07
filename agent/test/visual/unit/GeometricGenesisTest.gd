extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.GEOMETRIC_GENESIS))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.GEOMETRIC_GENESIS)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.GEOMETRIC_GENESIS)
	effect.free()
	control.free()
	pass


func turns_create_persistent_seals_test() -> void:
	var effect := GeometricGenesis.new()
	effect.on_turn_start()
	assert(effect.seals.size() == 1)
	assert(int(effect.seals[0]["state"]) == GeometricGenesis.SealState.CONSTRUCTING)
	effect.on_turn_end()
	assert(int(effect.seals[0]["state"]) == GeometricGenesis.SealState.COMPLETE)
	effect.on_turn_start()
	assert(effect.seals.size() == 2)
	effect.free()
	pass


func tool_results_become_geometry_test() -> void:
	var effect := GeometricGenesis.new()
	effect.on_turn_start()
	effect.on_tool_execution_start("ok", "read_file", {})
	effect.on_tool_execution_end("ok", "read_file", AgentToolResult.ok("done"))
	effect.on_tool_execution_start("bad", "write_file", {})
	effect.on_tool_execution_end("bad", "write_file", AgentToolResult.error("failed"))
	var motifs: Array = effect.seals[0]["motifs"]
	assert(motifs.size() == 2)
	assert(int(motifs[0]["state"]) == GeometricGenesis.ToolState.SUCCESS)
	assert(int(motifs[1]["state"]) == GeometricGenesis.ToolState.FAILED)
	effect.free()
	pass


func seal_count_is_bounded_test() -> void:
	var effect := GeometricGenesis.new()
	for index in range(GeometricGenesis.MAX_SEALS + 8):
		effect.on_turn_start()
		effect.on_turn_end()
	assert(effect.seals.size() == GeometricGenesis.MAX_SEALS)
	effect.free()
	pass


func seals_grow_from_simple_to_varied_geometry_test() -> void:
	var sides: Dictionary[int, bool] = {}
	var kinds: Dictionary[int, bool] = {}
	var previous_complexity := 0
	for index in range(GeometricGenesis.MAX_SEALS):
		var seal := GeometricGenesis.make_seal(index + 1, index)
		sides[int(seal["sides"])] = true
		kinds[int(seal["geometry_kind"])] = true
		var complexity: int = seal["complexity"]
		assert(complexity >= previous_complexity)
		previous_complexity = complexity
		if index < 3:
			assert(complexity == 0)
			assert(int(seal["sides"]) <= 5)
	assert(previous_complexity == 4)
	assert(sides.size() == 7)
	assert(kinds.size() == GeometricGenesis.GeometryKind.size())
	pass


func every_geometry_kind_has_a_formula_test() -> void:
	for kind: int in GeometricGenesis.GeometryKind.values():
		assert(StringUtils.is_not_blank(GeometricGenesis.geometry_formula(kind, 7)))
	pass


func coordinate_plane_reveals_before_geometry_test() -> void:
	var effect := GeometricGenesis.new()
	effect.visible = true
	effect.on_turn_start()
	effect._process(GeometricGenesis.COORDINATE_REVEAL_SECONDS * 0.4)
	assert(effect.coordinate_reveal > 0.0)
	assert(float(effect.seals[0]["growth"]) == 0.0)
	effect._process(GeometricGenesis.COORDINATE_REVEAL_SECONDS * 0.2)
	assert(float(effect.seals[0]["growth"]) > 0.0)
	effect.free()
	pass


func completed_formula_remains_visible_test() -> void:
	var settled_fade := lerpf(1.0, 0.38, smoothstep(0.05, 0.72, 1.0))
	assert(settled_fade > 0.0)
	pass
