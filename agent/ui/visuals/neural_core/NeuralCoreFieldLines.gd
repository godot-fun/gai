class_name NeuralCoreFieldLines
extends Control

## Sparse mesh + tendril strokes drawn additively into the field viewport (pre-bloom).

var anatomy: NeuralCoreAnatomy
var host: NeuralCore
var ink_pale := Color8(120, 132, 168)
var white_dot := Color8(235, 240, 255)
var red_alert := Color8(255, 52, 52)


func _draw() -> void:
	if anatomy == null or host == null:
		return
	var breath: float = host.breath_scale
	var env: float = host.envelope
	var alert: bool = host.alert_mode
	var t: float = host.clock_seconds
	var warp: float = host.warp_clock
	for edge: Vector3i in anatomy.mesh_edges:
		var cluster_index := edge.z
		var hue := NeuralCoreAnatomy.cluster_defs[cluster_index].hue
		var heat := anatomy.heat[cluster_index] if cluster_index < anatomy.heat.size() else 0.0
		var flicker := pow(sin(t * 0.6 + float(cluster_index)), 2.0)
		var strength := minf(0.48, 0.16 + 0.08 * flicker + 0.24 * heat + 0.10 * env)
		var stroke := dim_color(red_alert if alert else hue, strength)
		var a3: Vector3 = host.project_brain(host.live_point(edge.x, breath), warp)
		var b3: Vector3 = host.project_brain(host.live_point(edge.y, breath), warp)
		draw_line(Vector2(a3.x, a3.y), Vector2(b3.x, b3.y), stroke, 1.0, true)
	for tendril in anatomy.tendrils:
		var off := tendril.sway * sin(t * tendril.sway_freq + tendril.sway_phase)
		var stroke := dim_color(red_alert if alert else ink_pale, 0.42 + 0.15 * env)
		var projected: PackedVector2Array = PackedVector2Array()
		projected.resize(tendril.points.size())
		for step in range(tendril.points.size()):
			var point := tendril.points[step]
			var swayed := Vector3(
				(point.x + off * pow(float(step) / 8.0, 2.0)) * breath,
				point.y * breath,
				0.0
			)
			var p3: Vector3 = host.project_brain(swayed, warp)
			projected[step] = Vector2(p3.x, p3.y)
		for step in range(projected.size() - 1):
			draw_line(projected[step], projected[step + 1], stroke, 1.0, true)
		var dot_fill := dim_color(red_alert if alert else white_dot, 0.75 + 0.25 * env)
		for dot_index: int in tendril.dot_indices:
			if dot_index < projected.size():
				draw_circle(projected[dot_index], 2.0, dot_fill)
		tendril.projected = projected
	for traveler: NeuralCoreTraveler in host.travelers:
		if traveler.tendril_index < 0 or traveler.tendril_index >= anatomy.tendrils.size():
			continue
		var proj := anatomy.tendrils[traveler.tendril_index].projected
		if proj.is_empty():
			continue
		var seg := traveler.progress * 8.0
		var kk := mini(7, int(seg))
		var frac := seg - float(kk)
		var pos := proj[kk].lerp(proj[kk + 1], frac)
		draw_circle(pos, 3.0, dim_color(red_alert if alert else white_dot, 1.0))
	pass


static func dim_color(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, factor)
