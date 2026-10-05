class_name JarvisOrbRings3D
extends Node3D

## Rotating holographic rings around the neural core.

const RING_PATH_SEGMENTS := 160
const RING_BAND_HALF_WIDTH := 0.0035

var ring_nodes: Array[MeshInstance3D] = []
var ring_materials: Array[StandardMaterial3D] = []
var spin_speeds: PackedFloat32Array = PackedFloat32Array([0.35, -0.55, 0.22])
var target_scale: float = 1.0


func _ready() -> void:
	build_rings()
	pass


func _process(delta: float) -> void:
	for i in ring_nodes.size():
		var ring := ring_nodes[i]
		var speed: float = spin_speeds[i] if i < spin_speeds.size() else 0.3
		ring.rotate_y(speed * delta)
		ring.rotate_x(speed * 0.35 * delta)
	var current: float = scale.x
	scale = Vector3.ONE * lerpf(current, target_scale, delta * 3.0)
	pass


func set_tool_mode(enabled: bool) -> void:
	target_scale = 0.82 if enabled else 1.0
	pass


func apply_display_color(color: Color) -> void:
	var theme_strength := 1.0 if ThemeColor.is_dark_theme() else 0.82
	for i in ring_materials.size():
		var mat := ring_materials[i]
		var fade := 1.0 - float(i) * 0.14
		mat.albedo_color = Color(color.r, color.g, color.b, (0.26 - i * 0.05) * fade)
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = (0.62 - i * 0.1) * theme_strength
	pass


func build_rings() -> void:
	var radii := OrbVisualScale.ring_radii()
	for i in radii.size():
		var radius: float = radii[i]
		var ring_mesh := build_circle_ribbon_mesh(radius, RING_BAND_HALF_WIDTH, RING_PATH_SEGMENTS)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_materials.append(mat)

		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation_degrees = Vector3(72.0 + i * 14.0, 0.0, 18.0 + i * 8.0)
		add_child(ring)
		ring_nodes.append(ring)
	pass


func build_circle_ribbon_mesh(radius: float, band_half: float, segments: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var radial0 := Vector3(cos(a0), 0.0, sin(a0))
		var radial1 := Vector3(cos(a1), 0.0, sin(a1))
		var mid0 := radial0 * radius
		var mid1 := radial1 * radius
		var base: int = verts.size()
		verts.append(mid0 - radial0 * band_half)
		verts.append(mid0 + radial0 * band_half)
		verts.append(mid1 + radial1 * band_half)
		verts.append(mid1 - radial1 * band_half)
		for _j in 4:
			normals.append(Vector3.UP)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
