class_name JarvisOrbNeuronNet
extends Node3D

## Two-layer neuron net — dense inner core + outer shell, synapse filaments, stream-driven growth.

const LAYER_INNER := 0
const LAYER_OUTER := 1
const INNER_LAYER_RATIO := 0.36
const INNER_CORE_RADIUS := 0.34
## Outer shell band — center/spread live on OrbVisualScale (shared with HUD rings).

const NEIGHBORS := 3
const INNER_NEIGHBORS := 4
const OUTER_MAX_EDGE_DIST := 0.68
const INNER_MAX_EDGE_DIST := 0.26
const FILAMENT_SAMPLE_STRIDE := 2
## Screen-space synapse width (expanded in jarvis_filament.gdshader vertex).
const FILAMENT_LINE_WIDTH_PX := 0.85
const FILAMENT_LINE_AA_PX := 0.3
var neuron_anchors: PackedVector3Array = PackedVector3Array()
var neuron_positions: PackedVector3Array = PackedVector3Array()
var neuron_phases: PackedFloat32Array = PackedFloat32Array()
var neuron_speeds: PackedFloat32Array = PackedFloat32Array()
var neuron_amps: PackedFloat32Array = PackedFloat32Array()
var neuron_tangent_a: PackedVector3Array = PackedVector3Array()
var neuron_tangent_b: PackedVector3Array = PackedVector3Array()
var neuron_layers: PackedByteArray = PackedByteArray()
var synapse_pairs_inner: Array[Vector2i] = []
var synapse_pairs_outer: Array[Vector2i] = []
var motion_time: float = 0.0
var wander_speed_scale: float = 0.75
var pulse_levels: PackedFloat32Array = PackedFloat32Array()
var active_pulse_indices: Array[int] = []
var pulse_sum: float = 0.0

var current_neuron_count: int = 0
var pending_neuron_target: int = 0
var rebuild_cooldown: float = 0.0
var filament_dirty: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var sphere_mesh_inner: SphereMesh
var sphere_mesh_outer: SphereMesh

var multimesh_inner: MultiMeshInstance3D
var multimesh_outer: MultiMeshInstance3D
var filament_mesh_inner: MeshInstance3D
var filament_mesh_outer: MeshInstance3D
var filament_surface_inner: ArrayMesh
var filament_surface_outer: ArrayMesh
var neuron_shader_inner: ShaderMaterial
var neuron_shader_outer: ShaderMaterial
var filament_shader_inner: ShaderMaterial
var filament_shader_outer: ShaderMaterial


func _ready() -> void:
	rng.randomize()
	sphere_mesh_inner = SphereMesh.new()
	sphere_mesh_inner.radius = 0.011
	sphere_mesh_inner.height = 0.022
	sphere_mesh_inner.radial_segments = 6
	sphere_mesh_inner.rings = 3
	sphere_mesh_outer = SphereMesh.new()
	sphere_mesh_outer.radius = 0.018
	sphere_mesh_outer.height = 0.036
	sphere_mesh_outer.radial_segments = 6
	sphere_mesh_outer.rings = 4
	ThemeColor.load_theme_color()
	rebuild_neurons(OrbGrowth.NEURON_MIN)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(sync_filament_viewport_uniform):
		vp.size_changed.connect(sync_filament_viewport_uniform)
	if not gdf.events.theme_color_changed.is_connected(sync_filament_theme):
		gdf.events.theme_color_changed.connect(sync_filament_theme)
	if not gdf.events.theme_changed.is_connected(sync_filament_theme):
		gdf.events.theme_changed.connect(sync_filament_theme)
	pass


func _process(delta: float) -> void:
	rebuild_cooldown = maxf(0.0, rebuild_cooldown - delta)
	try_flush_neuron_growth()
	if filament_dirty and rebuild_cooldown <= 0.0:
		build_filaments()
		filament_dirty = false
		rebuild_cooldown = OrbGrowth.NEURON_REBUILD_COOLDOWN_S

	var pulse_index := 0
	while pulse_index < active_pulse_indices.size():
		var neuron_index: int = active_pulse_indices[pulse_index]
		if neuron_index >= pulse_levels.size():
			active_pulse_indices.remove_at(pulse_index)
			continue
		var level: float = pulse_levels[neuron_index]
		if level <= 0.0:
			active_pulse_indices.remove_at(pulse_index)
			continue
		var decayed: float = maxf(0.0, level - delta * 1.8)
		pulse_sum += decayed - level
		pulse_levels[neuron_index] = decayed
		if decayed <= 0.0:
			active_pulse_indices.remove_at(pulse_index)
			continue
		pulse_index += 1

	var avg_pulse: float = 0.65 + _average_pulse() * 0.55
	if neuron_shader_inner != null:
		neuron_shader_inner.set_shader_parameter("pulse", avg_pulse * 1.12)
	if neuron_shader_outer != null:
		neuron_shader_outer.set_shader_parameter("pulse", avg_pulse)

	motion_time += delta * wander_speed_scale
	update_neuron_motion()
	refresh_multimesh_transforms()
	refresh_filament_vertices()
	pass


func get_positions() -> PackedVector3Array:
	return neuron_positions


func apply_growth(char_count: int) -> void:
	var target := OrbGrowth.neuron_count(char_count)
	if target <= current_neuron_count:
		return
	pending_neuron_target = maxi(pending_neuron_target, target)
	try_flush_neuron_growth()
	pass


func try_flush_neuron_growth() -> void:
	if pending_neuron_target <= current_neuron_count:
		return
	if rebuild_cooldown > 0.0:
		return
	if current_neuron_count > 0 and pending_neuron_target < current_neuron_count + OrbGrowth.NEURON_REBUILD_STEP:
		return
	append_neurons(pending_neuron_target)
	pending_neuron_target = 0
	rebuild_cooldown = OrbGrowth.NEURON_REBUILD_COOLDOWN_S
	pass


func reset_growth() -> void:
	pending_neuron_target = 0
	rebuild_cooldown = 0.0
	filament_dirty = false
	motion_time = 0.0
	active_pulse_indices.clear()
	pulse_sum = 0.0
	rebuild_neurons(OrbGrowth.NEURON_MIN)
	pass


func pulse_neuron(index: int, strength: float = 1.0) -> void:
	if index < 0 or index >= pulse_levels.size():
		return
	var old_level: float = pulse_levels[index]
	var new_level: float = clampf(old_level + strength, 0.0, 1.0)
	if is_equal_approx(old_level, new_level):
		return
	pulse_levels[index] = new_level
	pulse_sum += new_level - old_level
	if old_level <= 0.0 and new_level > 0.0:
		active_pulse_indices.append(index)
	pass


func pulse_random(strength: float = 0.8) -> void:
	if neuron_positions.is_empty():
		return
	var inner_indices := collect_layer_indices(LAYER_INNER)
	if not inner_indices.is_empty() and rng.randf() < 0.58:
		pulse_neuron(inner_indices[rng.randi_range(0, inner_indices.size() - 1)], strength * 1.05)
		return
	var outer_indices := collect_layer_indices(LAYER_OUTER)
	if outer_indices.is_empty():
		return
	pulse_neuron(outer_indices[rng.randi_range(0, outer_indices.size() - 1)], strength)
	pass


func apply_display_color(color: Color) -> void:
	if neuron_shader_inner != null:
		neuron_shader_inner.set_shader_parameter("base_color", Color(color.r, color.g, color.b, 0.92))
	if neuron_shader_outer != null:
		neuron_shader_outer.set_shader_parameter("base_color", Color(color.r, color.g, color.b, 0.72))
	apply_filament_theme_color()
	pass


func apply_filament_theme_color() -> void:
	var line_color := ThemeColor.theme_color
	if filament_shader_inner != null:
		filament_shader_inner.set_shader_parameter("line_color", line_color)
	if filament_shader_outer != null:
		filament_shader_outer.set_shader_parameter("line_color", line_color)
	pass


func sync_filament_theme() -> void:
	var inner_strength := 0.88 if ThemeColor.is_dark_theme() else 0.62
	var outer_strength := 0.72 if ThemeColor.is_dark_theme() else 0.48
	apply_filament_theme_color()
	if filament_shader_inner != null:
		filament_shader_inner.set_shader_parameter("line_strength", inner_strength)
		filament_shader_inner.set_shader_parameter("line_width_px", FILAMENT_LINE_WIDTH_PX * 0.95)
		filament_shader_inner.set_shader_parameter("line_aa_px", FILAMENT_LINE_AA_PX)
	if filament_shader_outer != null:
		filament_shader_outer.set_shader_parameter("line_strength", outer_strength)
		filament_shader_outer.set_shader_parameter("line_width_px", FILAMENT_LINE_WIDTH_PX)
		filament_shader_outer.set_shader_parameter("line_aa_px", FILAMENT_LINE_AA_PX)
	sync_filament_viewport_uniform()
	pass


func sync_filament_viewport_uniform() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var size := Vector2(vp.size)
	if size.x < 1.0 or size.y < 1.0:
		size = vp.get_visible_rect().size
	if filament_shader_inner != null:
		filament_shader_inner.set_shader_parameter("viewport_size", size)
	if filament_shader_outer != null:
		filament_shader_outer.set_shader_parameter("viewport_size", size)
	pass


func rebuild_neurons(count: int) -> void:
	clear_meshes()
	current_neuron_count = count
	var inner_n := target_inner_count(count)
	assign_layer_points(inner_n, count - inner_n)
	init_motion_params(0, current_neuron_count)
	pulse_levels.resize(neuron_positions.size())
	pulse_levels.fill(0.0)
	pulse_sum = 0.0
	active_pulse_indices.clear()
	build_neurons()
	build_filaments()
	filament_dirty = false
	pass


func append_neurons(target_count: int) -> void:
	var add_count := target_count - current_neuron_count
	if add_count <= 0:
		return
	var inner_before := inner_neuron_count()
	var inner_after := target_inner_count(target_count)
	var inner_add := maxi(0, inner_after - inner_before)
	var outer_add := maxi(0, add_count - inner_add)
	append_layer_points(inner_add, outer_add)
	current_neuron_count = neuron_anchors.size()
	var start_index := current_neuron_count - add_count
	init_motion_params(start_index, current_neuron_count)
	pulse_levels.resize(current_neuron_count)
	for i in range(start_index, current_neuron_count):
		pulse_levels[i] = 0.0
	rebuild_multimesh()
	filament_dirty = true
	pass


func clear_meshes() -> void:
	if multimesh_inner != null:
		multimesh_inner.queue_free()
		multimesh_inner = null
	if multimesh_outer != null:
		multimesh_outer.queue_free()
		multimesh_outer = null
	if filament_mesh_inner != null:
		filament_mesh_inner.queue_free()
		filament_mesh_inner = null
	if filament_mesh_outer != null:
		filament_mesh_outer.queue_free()
		filament_mesh_outer = null
	filament_surface_inner = null
	filament_surface_outer = null
	synapse_pairs_inner.clear()
	synapse_pairs_outer.clear()
	pass


func rebuild_multimesh() -> void:
	var neuron_shader_res := load("res://agent/ui/shaders/jarvis_neuron.gdshader") as Shader
	if neuron_shader_inner == null:
		neuron_shader_inner = ShaderMaterial.new()
		neuron_shader_inner.shader = neuron_shader_res
	if neuron_shader_outer == null:
		neuron_shader_outer = ShaderMaterial.new()
		neuron_shader_outer.shader = neuron_shader_res
	neuron_shader_inner.set_shader_parameter("base_color", Color(0.0, 0.9, 1.0, 0.92))
	neuron_shader_outer.set_shader_parameter("base_color", Color(0.0, 0.9, 1.0, 0.72))
	rebuild_layer_multimesh(LAYER_OUTER, multimesh_outer, sphere_mesh_outer, neuron_shader_outer)
	rebuild_layer_multimesh(LAYER_INNER, multimesh_inner, sphere_mesh_inner, neuron_shader_inner)
	pass


func rebuild_layer_multimesh(
	layer: int,
	instance_ref: MultiMeshInstance3D,
	mesh: SphereMesh,
	shader_mat: ShaderMaterial
) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = false
	multi.mesh = mesh
	var layer_indices := collect_layer_indices(layer)
	multi.instance_count = layer_indices.size()
	for slot in layer_indices.size():
		multi.set_instance_transform(slot, neuron_instance_transform(layer_indices[slot]))
	var instance := instance_ref
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.material_override = shader_mat
		add_child(instance)
		if layer == LAYER_INNER:
			multimesh_inner = instance
		else:
			multimesh_outer = instance
	instance.multimesh = multi
	pass


func build_neurons() -> void:
	rebuild_multimesh()
	pass


func build_filaments() -> void:
	synapse_pairs_inner = build_synapse_pairs_for_layer(LAYER_INNER, INNER_MAX_EDGE_DIST, INNER_NEIGHBORS)
	synapse_pairs_outer = build_synapse_pairs_for_layer(LAYER_OUTER, OUTER_MAX_EDGE_DIST, NEIGHBORS)
	build_layer_filament_mesh(
		synapse_pairs_outer,
		filament_mesh_outer,
		filament_surface_outer,
		filament_shader_outer,
		false
	)
	build_layer_filament_mesh(
		synapse_pairs_inner,
		filament_mesh_inner,
		filament_surface_inner,
		filament_shader_inner,
		true
	)
	pass


func build_layer_filament_mesh(
	pairs: Array[Vector2i],
	mesh_instance_ref: MeshInstance3D,
	surface_ref: ArrayMesh,
	shader_ref: ShaderMaterial,
	is_inner: bool
) -> void:
	var arrays := build_filament_arrays_from_pairs(pairs)
	if arrays.is_empty():
		return
	var surface := surface_ref
	if surface == null:
		surface = ArrayMesh.new()
	surface.clear_surfaces()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if shader_ref == null:
		shader_ref = ShaderMaterial.new()
		shader_ref.shader = load("res://agent/ui/shaders/jarvis_filament.gdshader") as Shader
		shader_ref.render_priority = 9 if is_inner else 8
		if is_inner:
			filament_shader_inner = shader_ref
		else:
			filament_shader_outer = shader_ref
	sync_filament_theme()
	var mesh_instance := mesh_instance_ref
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.material_override = shader_ref
		add_child(mesh_instance)
		if is_inner:
			filament_mesh_inner = mesh_instance
			filament_surface_inner = surface
		else:
			filament_mesh_outer = mesh_instance
			filament_surface_outer = surface
	mesh_instance.mesh = surface
	pass


func init_motion_params(from_index: int, to_index: int) -> void:
	neuron_phases.resize(to_index)
	neuron_speeds.resize(to_index)
	neuron_amps.resize(to_index)
	neuron_tangent_a.resize(to_index)
	neuron_tangent_b.resize(to_index)
	for i in range(from_index, to_index):
		var anchor := neuron_anchors[i]
		var normal := anchor.normalized() if anchor.length_squared() > 0.0001 else Vector3.UP
		var ref := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var tangent_a := normal.cross(ref).normalized()
		var tangent_b := normal.cross(tangent_a).normalized()
		neuron_tangent_a[i] = tangent_a
		neuron_tangent_b[i] = tangent_b
		neuron_phases[i] = rng.randf_range(0.0, TAU)
		neuron_speeds[i] = rng.randf_range(0.4, 1.05)
		var is_inner := neuron_layers[i] == LAYER_INNER
		neuron_amps[i] = rng.randf_range(0.012, 0.028) if is_inner else rng.randf_range(0.022, 0.052)
	pass


func update_neuron_motion() -> void:
	for i in neuron_anchors.size():
		var anchor := neuron_anchors[i]
		var phase := neuron_phases[i]
		var speed := neuron_speeds[i]
		var amp := neuron_amps[i]
		var t := motion_time * speed + phase
		var offset := neuron_tangent_a[i] * (sin(t) * amp)
		offset += neuron_tangent_b[i] * (cos(t * 0.71) * amp * 0.88)
		offset += neuron_tangent_a[i].cross(neuron_tangent_b[i]).normalized() * (sin(t * 1.37 + phase) * amp * 0.35)
		neuron_positions[i] = anchor + offset
	pass


func neuron_instance_transform(index: int) -> Transform3D:
	var is_inner := neuron_layers[index] == LAYER_INNER
	var scale_factor := 0.78 + float(index % 5) * 0.035 if is_inner else 0.85 + float(index % 5) * 0.04
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * scale_factor)
	return Transform3D(basis, neuron_positions[index])


func refresh_multimesh_transforms() -> void:
	refresh_layer_multimesh_transforms(LAYER_INNER, multimesh_inner)
	refresh_layer_multimesh_transforms(LAYER_OUTER, multimesh_outer)
	pass


func refresh_layer_multimesh_transforms(layer: int, instance: MultiMeshInstance3D) -> void:
	if instance == null or instance.multimesh == null:
		return
	var multi := instance.multimesh
	var layer_indices := collect_layer_indices(layer)
	for slot in layer_indices.size():
		multi.set_instance_transform(slot, neuron_instance_transform(layer_indices[slot]))
	pass


func build_filament_arrays_from_pairs(pairs: Array[Vector2i]) -> Array:
	if pairs.is_empty():
		return []
	sync_filament_viewport_uniform()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for pair in pairs:
		append_filament_quad(
			verts,
			colors,
			uvs,
			uvs2,
			normals,
			indices,
			neuron_positions[pair.x],
			neuron_positions[pair.y]
		)
	if verts.is_empty():
		return []
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func refresh_filament_vertices() -> void:
	refresh_layer_filament_vertices(filament_mesh_inner, filament_surface_inner, synapse_pairs_inner)
	refresh_layer_filament_vertices(filament_mesh_outer, filament_surface_outer, synapse_pairs_outer)
	pass


func refresh_layer_filament_vertices(
	mesh_instance: MeshInstance3D,
	surface: ArrayMesh,
	pairs: Array[Vector2i]
) -> void:
	if mesh_instance == null or surface == null or pairs.is_empty():
		return
	var arrays := build_filament_arrays_from_pairs(pairs)
	if arrays.is_empty():
		return
	surface.clear_surfaces()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	pass


func append_filament_quad(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	uvs2: PackedVector2Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3
) -> void:
	if a.distance_squared_to(b) < 0.00000001:
		return
	var ab := b - a
	var ba := -ab
	var base: int = verts.size()
	verts.append(a)
	verts.append(a)
	verts.append(b)
	verts.append(b)
	# COLOR.r + UV2.xy = offset to the other endpoint (avoid negative vertex alpha).
	colors.append(Color(ab.z, 0.0, 0.0, 1.0))
	colors.append(Color(ab.z, 0.0, 0.0, 1.0))
	colors.append(Color(ba.z, 0.0, 0.0, 1.0))
	colors.append(Color(ba.z, 0.0, 0.0, 1.0))
	uvs2.append(Vector2(ab.x, ab.y))
	uvs2.append(Vector2(ab.x, ab.y))
	uvs2.append(Vector2(ba.x, ba.y))
	uvs2.append(Vector2(ba.x, ba.y))
	for _i in 4:
		normals.append(Vector3.UP)
	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(0.0, 1.0))
	uvs.append(Vector2(1.0, 1.0))
	uvs.append(Vector2(1.0, 0.0))
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	pass


func target_inner_count(total: int) -> int:
	if total <= 0:
		return 0
	return clampi(maxi(1, int(round(float(total) * INNER_LAYER_RATIO))), 1, total)


func inner_neuron_count() -> int:
	var count := 0
	for i in neuron_layers.size():
		if neuron_layers[i] == LAYER_INNER:
			count += 1
	return count


func assign_layer_points(inner_count: int, outer_count: int) -> void:
	neuron_anchors = PackedVector3Array()
	neuron_positions = PackedVector3Array()
	neuron_layers = PackedByteArray()
	append_layer_points(inner_count, outer_count)
	pass


func append_layer_points(inner_add: int, outer_add: int) -> void:
	if inner_add > 0:
		for point in generate_inner_core_points(inner_add):
			neuron_anchors.append(point)
			neuron_positions.append(point)
			neuron_layers.append(LAYER_INNER)
	if outer_add > 0:
		for point in generate_outer_shell_points(outer_add):
			neuron_anchors.append(point)
			neuron_positions.append(point)
			neuron_layers.append(LAYER_OUTER)
	pass


func collect_layer_indices(layer: int) -> Array[int]:
	var indices: Array[int] = []
	for i in neuron_layers.size():
		if neuron_layers[i] == layer:
			indices.append(i)
	return indices


func random_unit_direction() -> Vector3:
	var u := rng.randf()
	var v := rng.randf()
	var theta := TAU * u
	var phi := acos(2.0 * v - 1.0)
	return Vector3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi)).normalized()


func generate_inner_core_points(count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for _i in count:
		var dir := random_unit_direction()
		var radius := INNER_CORE_RADIUS * pow(rng.randf(), 0.42)
		var point := dir * radius
		point += dir * rng.randf_range(-0.012, 0.012)
		points.append(point)
	return points


func generate_outer_shell_points(count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for _i in count:
		var dir := random_unit_direction()
		var x := dir.x
		var y := dir.y * 0.92
		var z := dir.z * 0.78
		if x >= 0.0:
			x += 0.07
		else:
			x -= 0.07
		x *= 0.88
		y *= 1.05
		z *= 0.82
		var shell_dir := Vector3(x, y, z).normalized()
		var radial_jitter := (rng.randf() - 0.5) * 2.0 * OrbVisualScale.OUTER_SHELL_RADIUS_SPREAD
		radial_jitter *= pow(rng.randf(), 0.55)
		var radius := OrbVisualScale.OUTER_SHELL_RADIUS_CENTER + radial_jitter
		var point := shell_dir * radius
		point += shell_dir * rng.randf_range(-0.012, 0.012)
		point.x += rng.randf_range(-0.01, 0.01)
		point.y += rng.randf_range(-0.01, 0.01)
		point.z += rng.randf_range(-0.01, 0.01)
		points.append(point)
	return points


func build_synapse_pairs_for_layer(layer: int, max_edge: float, neighbor_count: int) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	var grid := build_spatial_grid_for_layer(layer, max_edge)
	var layer_indices := collect_layer_indices(layer)
	var stride := 1 if layer_indices.size() <= 420 else FILAMENT_SAMPLE_STRIDE
	for slot in range(0, layer_indices.size(), stride):
		var index := layer_indices[slot]
		var neighbors := find_neighbors_spatial(index, grid, max_edge, neighbor_count, layer)
		for neighbor_index in neighbors:
			if neighbor_index <= index:
				continue
			pairs.append(Vector2i(index, neighbor_index))
	return pairs


func build_spatial_grid_for_layer(layer: int, cell_size: float) -> Dictionary:
	var grid: Dictionary = {}
	for i in neuron_anchors.size():
		if neuron_layers[i] != layer:
			continue
		var cell := cell_key(neuron_anchors[i], cell_size)
		if not grid.has(cell):
			grid[cell] = [] as Array[int]
		(grid[cell] as Array[int]).append(i)
	return grid


func cell_key(point: Vector3, cell_size: float) -> Vector3i:
	return Vector3i(
		int(floor(point.x / cell_size)),
		int(floor(point.y / cell_size)),
		int(floor(point.z / cell_size))
	)


func find_neighbors_spatial(
	index: int,
	grid: Dictionary,
	max_edge: float,
	neighbor_count: int,
	layer: int
) -> Array[int]:
	var origin := neuron_anchors[index]
	var result: Array[int] = []
	var dists: Array[float] = []
	var origin_cell := cell_key(origin, max_edge)
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			for oz in range(-1, 2):
				var bucket: Variant = grid.get(origin_cell + Vector3i(ox, oy, oz))
				if bucket == null:
					continue
				for j: int in bucket as Array[int]:
					if j == index or neuron_layers[j] != layer:
						continue
					var dist := origin.distance_to(neuron_anchors[j])
					if dist > max_edge:
						continue
					var insert_at := result.size()
					for k in result.size():
						if dist < dists[k]:
							insert_at = k
							break
					result.insert(insert_at, j)
					dists.insert(insert_at, dist)
					if result.size() > neighbor_count:
						result.pop_back()
						dists.pop_back()
	return result


func _average_pulse() -> float:
	if pulse_levels.is_empty():
		return 0.0
	return pulse_sum / float(pulse_levels.size())
