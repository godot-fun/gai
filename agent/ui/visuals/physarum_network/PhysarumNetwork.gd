class_name PhysarumNetwork
extends SimulationEffect

## Physarum (黏菌网络): tens of thousands of slime-mold agents crawl over the interface, following
## and reinforcing each other's trails until they self-organize into a vein network. Every tool
## call drops food at its own spot and the mold grows toward it, so a run draws a transit map
## between the tools it used. Streamed answers speed the mold up, reasoning makes it wander, and
## a failed tool spoils its food so the network recoils. The end of the run freezes the map.

const TRAIL_SHADER: Shader = preload("res://agent/ui/visuals/physarum_network/PhysarumTrail.gdshader")
const DISPLAY_SHADER: Shader = preload("res://agent/ui/visuals/physarum_network/PhysarumNetwork.gdshader")
const AGENT_SHADER: Shader = preload("res://agent/ui/visuals/physarum_network/PhysarumAgents.gdshader")
const DEPOSIT_SHADER: Shader = preload("res://agent/ui/visuals/physarum_network/PhysarumDeposit.gdshader")
const TRAIL_PASS_KINDS: PackedInt32Array = [0, 1]
const AGENT_PASS_KINDS: PackedInt32Array = [0, 0]
const AGENT_SIDE := 256
const MAX_FOOD := 8
const FOOD_RADIUS := 0.022
const FOOD_EMIT := 0.08
const SPOILED_EMIT := -0.14
const FOOD_MERGE_DISTANCE := 0.02
const FOOD_SUCCESS_BOOST := 1.5
const FOOD_DECAY_PER_SECOND := 0.04
const MIN_FOOD := 0.3
const RUN_SPEED := 1.0
const STREAM_SPEED := 1.8
const RUN_WANDER := 0.12
const REASONING_WANDER := 0.5
const DRIVE_DECAY_PER_SECOND := 0.5
const RUN_DEPOSIT := 0.6
const RUN_DECAY := 0.9
const SETTLE_DECAY := 0.97
const DARK_VEIN_OPACITY := 0.8
const LIGHT_VEIN_OPACITY := 0.62
## Amber, kept clear of the accent and the error red so food never reads as a failure.
const FOOD_HUE := Color(1.0, 0.72, 0.25)


## A tool's food source: emits food (or spoilage) into the trail every frame while it lasts.
class FoodSource extends RefCounted:
	var position: Vector2
	var strength: float = 1.0
	var spoiled: bool = false
	var key: String = ""


var agent_chain: SimulationChain
var deposit_mesh: MeshInstance2D
var deposit_material: ShaderMaterial
var food_sources: Array[FoodSource] = []
var speed: float = 0.0
var speed_floor: float = 0.0
var wander_drive: float = 0.0
var deposit: float = 0.0
var decay: float = RUN_DECAY


func field_shader() -> Shader:
	return TRAIL_SHADER


func display_shader() -> Shader:
	return DISPLAY_SHADER


func pass_kinds() -> PackedInt32Array:
	return TRAIL_PASS_KINDS


func field_downscale() -> float:
	return 3.0


func activity_decay_per_second() -> float:
	return 0.4


## The agent chain nests inside trail pass 0 so agents step before the deposit reads them, and
## the deposit points draw over pass 0's diffuse rect in that same viewport.
func _ready() -> void:
	super._ready()
	agent_chain = SimulationChain.new()
	agent_chain.name = "AgentChain"
	agent_chain.setup(AGENT_SHADER, AGENT_PASS_KINDS, Vector2i(AGENT_SIDE, AGENT_SIDE))
	agent_chain.set_param("trail_tex", chain.get_texture())
	for index in range(agent_chain.pass_count()):
		agent_chain.set_pass_param(index, "pass_seed", float(index))
	chain.viewports[0].add_child(agent_chain)
	deposit_material = ShaderMaterial.new()
	deposit_material.shader = DEPOSIT_SHADER
	deposit_material.set_shader_parameter("agent_tex", agent_chain.get_texture())
	deposit_mesh = MeshInstance2D.new()
	deposit_mesh.name = "AgentDeposit"
	deposit_mesh.mesh = build_point_mesh(AGENT_SIDE)
	deposit_mesh.material = deposit_material
	chain.viewports[0].add_child(deposit_mesh)
	sync_field_size()
	pass


func _process(delta: float) -> void:
	var resetting := reset_frames > 0
	super._process(delta)
	if agent_chain == null:
		return
	agent_chain.set_running(chain.running)
	if chain.running:
		agent_chain.set_param("reset", resetting)
		agent_chain.set_param("field_time", field_time)
	pass


func on_viewport_size_changed() -> void:
	super.on_viewport_size_changed()
	sync_field_size()
	pass


func sync_field_size() -> void:
	var field_size := compute_field_size()
	deposit_mesh.scale = Vector2(field_size)
	agent_chain.set_param("trail_texel", Vector2.ONE / Vector2(field_size))
	agent_chain.set_param("trail_aspect", float(field_size.x) / float(maxi(field_size.y, 1)))
	pass


func on_agent_start(session_id: int) -> void:
	super.on_agent_start(session_id)
	food_sources.clear()
	speed_floor = RUN_SPEED
	speed = RUN_SPEED
	wander_drive = 0.0
	deposit = RUN_DEPOSIT
	decay = RUN_DECAY
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	speed_floor = 0.0
	speed = 0.0
	deposit = 0.0
	decay = SETTLE_DECAY
	if StringUtils.is_not_blank(error_message):
		for source: FoodSource in food_sources:
			source.spoiled = true
	await super.on_agent_end(session_id, error_message)
	food_sources.clear()
	pass


func on_turn_start(_session_id: int) -> void:
	wander_drive = combine_energy(wander_drive, 0.5)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	var energy := stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		wander_drive = combine_energy(wander_drive, energy * 6.0)
	else:
		speed = minf(speed + energy * 2.0, STREAM_SPEED)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	place_food(tool_call_id, tool_anchor(tool_name))
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var source := find_food(tool_call_id)
	if source == null:
		source = place_food(tool_call_id, tool_anchor(tool_name))
	if result.is_error:
		source.spoiled = true
		failure_tint = 1.0
	else:
		source.strength = FOOD_SUCCESS_BOOST
	pass


## Places food at [param position]; food already at that spot is refreshed in place.
func place_food(key: String, position: Vector2) -> FoodSource:
	for source: FoodSource in food_sources:
		if source.position.distance_to(position) < FOOD_MERGE_DISTANCE:
			source.key = key
			source.strength = 1.0
			source.spoiled = false
			return source
	if food_sources.size() >= MAX_FOOD:
		food_sources.pop_front()
	var source := FoodSource.new()
	source.position = position
	source.key = key
	food_sources.append(source)
	return source


func find_food(key: String) -> FoodSource:
	for source: FoodSource in food_sources:
		if source.key == key:
			return source
	return null


func step_field(delta: float) -> void:
	speed = maxf(move_toward(speed, speed_floor, DRIVE_DECAY_PER_SECOND * delta), speed_floor)
	wander_drive = move_toward(wander_drive, 0.0, DRIVE_DECAY_PER_SECOND * delta)
	for source: FoodSource in food_sources:
		source.strength = maxf(source.strength - FOOD_DECAY_PER_SECOND * delta, MIN_FOOD)
		if activity_floor > 0.0 or source.spoiled:
			queue_impulse(source.position, FOOD_RADIUS, (SPOILED_EMIT if source.spoiled else FOOD_EMIT) * source.strength)
	pass


func apply_field_state() -> void:
	chain.set_param("decay", decay)
	agent_chain.set_param("speed_px", speed)
	agent_chain.set_param("wander", lerpf(RUN_WANDER, REASONING_WANDER, wander_drive))
	deposit_material.set_shader_parameter("deposit", deposit)
	pass


func update_theme_presentation() -> void:
	if display_material == null:
		return
	var accent := ThemeColor.accent_theme_color()
	var dark := ThemeColor.is_dark_theme()
	var vein := VisualColor.appearance_color(accent)
	display_material.set_shader_parameter("vein_color", vein)
	display_material.set_shader_parameter("core_color", vein.lerp(Color(1.0, 1.0, 0.92), 0.65) if dark else vein.darkened(0.45))
	display_material.set_shader_parameter("food_color", VisualColor.appearance_color(FOOD_HUE))
	display_material.set_shader_parameter("error_color", Colors.error)
	display_material.set_shader_parameter("vein_opacity", DARK_VEIN_OPACITY if dark else LIGHT_VEIN_OPACITY)
	display_material.set_shader_parameter("light_mode", 0.0 if dark else 1.0)
	pass


## One point per agent; UV addresses the agent's texel and positions span the unit square so the
## mesh bounds cover the whole trail.
static func build_point_mesh(side: int) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	vertices.resize(side * side)
	uvs.resize(side * side)
	for y in range(side):
		for x in range(side):
			var uv := Vector2((float(x) + 0.5) / float(side), (float(y) + 0.5) / float(side))
			vertices[y * side + x] = uv
			uvs[y * side + x] = uv
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	return mesh
