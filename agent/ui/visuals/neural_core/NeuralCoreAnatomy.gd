class_name NeuralCoreAnatomy
extends RefCounted

## Procedural brain layout ported from ai-visualizer faces/neural (seed-stable build).

const N_REGIONS := 9
const N_TENDRILS := 46
const CRESCENT_CENTER := Vector2(-0.16, -0.03)
const CRESCENT_RADIUS := 0.30
const BRIGHT_CAP := 1.18

class Tendril:
	var points: PackedVector3Array = PackedVector3Array()
	var cluster_index: int = 0
	var sway: float = 0.0
	var sway_freq: float = 0.0
	var sway_phase: float = 0.0
	var dot_indices: PackedInt32Array = PackedInt32Array()
	var projected: PackedVector2Array = PackedVector2Array()


class ClusterDef:
	var label: String
	var center: Vector2
	var spread: float
	var hue: Color
	var count: int

	func _init(p_label: String, p_center: Vector2, p_spread: float, p_hue: Color, p_count: int) -> void:
		label = p_label
		center = p_center
		spread = p_spread
		hue = p_hue
		count = p_count
		pass


static var cluster_defs: Array[ClusterDef] = []


static func ensure_cluster_defs() -> void:
	if not cluster_defs.is_empty():
		return
	var specs: Array = [
		["PREFRONTAL", Vector2(0.74, -0.16), 0.11, Color8(96, 165, 250), 180],
		["MOTOR", Vector2(0.30, -0.44), 0.10, Color8(52, 211, 153), 165],
		["SENSORY", Vector2(-0.06, -0.50), 0.11, Color8(255, 150, 60), 180],
		["ASSOCIATION", Vector2(0.38, 0.04), 0.13, Color8(150, 110, 250), 205],
		["LANGUAGE", Vector2(0.10, 0.32), 0.10, Color8(56, 200, 255), 165],
		["VISUAL", Vector2(-0.78, -0.06), 0.11, Color8(240, 80, 120), 180],
		["HIPPOCAMPUS", Vector2(-0.32, 0.26), 0.10, Color8(250, 200, 70), 150],
		["CEREBELLUM", Vector2(-0.62, 0.36), 0.10, Color8(110, 230, 90), 165],
		["BRAINSTEM", Vector2(-0.16, 0.52), 0.08, Color8(190, 120, 255), 125],
		["", Vector2(0.58, -0.52), 0.07, Color8(200, 230, 90), 60],
		["", Vector2(-0.46, -0.38), 0.07, Color8(255, 90, 80), 60],
		["", Vector2(0.90, 0.24), 0.07, Color8(255, 140, 70), 55],
		["", Vector2(-1.00, 0.14), 0.07, Color8(80, 220, 230), 55],
		["", Vector2(0.02, -0.14), 0.08, Color8(120, 170, 255), 70],
		["", Vector2(0.52, 0.40), 0.06, Color8(255, 120, 190), 50],
		["", Vector2(-0.40, -0.58), 0.06, Color8(140, 240, 200), 50],
		["", Vector2(0.94, -0.40), 0.06, Color8(170, 200, 100), 45],
		["", Vector2(-0.86, 0.42), 0.06, Color8(255, 190, 120), 45],
		["", Vector2(0.14, 0.00), 0.30, Color8(60, 90, 170), 430],
	]
	for spec: Array in specs:
		cluster_defs.append(ClusterDef.new(String(spec[0]), spec[1], float(spec[2]), Color(spec[3]), int(spec[4])))
	pass

var point_positions: PackedVector3Array = PackedVector3Array()
var point_colors: PackedColorArray = PackedColorArray()
var point_cluster: PackedInt32Array = PackedInt32Array()
var twinkle_phase: PackedFloat32Array = PackedFloat32Array()
var twinkle_speed: PackedFloat32Array = PackedFloat32Array()
var shimmer_amp: Array[Vector3] = []
var shimmer_freq: PackedFloat32Array = PackedFloat32Array()
var shimmer_phase: Array[Vector3] = []
var mesh_edges: Array[Vector3i] = []
var arc_points: PackedVector3Array = PackedVector3Array()
var arc_weight: PackedFloat32Array = PackedFloat32Array()
var arc_twinkle: PackedFloat32Array = PackedFloat32Array()
var tendrils: Array[Tendril] = []
var heat: PackedFloat32Array = PackedFloat32Array()
var cascade_index: int = 0
var cascade_timer: float = 0.0


static func build(seed: int = 7) -> NeuralCoreAnatomy:
	ensure_cluster_defs()
	var anatomy := NeuralCoreAnatomy.new()
	anatomy.heat.resize(cluster_defs.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for cluster_index in range(cluster_defs.size()):
		var cluster := cluster_defs[cluster_index]
		var core_count := int(cluster.count * 0.7)
		for point_index in range(cluster.count):
			var spread := cluster.spread * (0.55 if point_index < core_count else 1.25)
			var px := cluster.center.x + gauss(rng) * spread
			var py := cluster.center.y + gauss(rng) * spread
			var pz := gauss(rng) * 0.10
			anatomy.point_positions.append(Vector3(px, py, pz))
			var jitter := 0.6 + rng.randf() * 0.4
			anatomy.point_colors.append(Color(cluster.hue.r / 255.0 * jitter, cluster.hue.g / 255.0 * jitter, cluster.hue.b / 255.0 * jitter))
			anatomy.point_cluster.append(cluster_index)
	var point_count := anatomy.point_positions.size()
	anatomy.twinkle_phase.resize(point_count)
	anatomy.twinkle_speed.resize(point_count)
	anatomy.shimmer_freq.resize(point_count)
	for point_index in range(point_count):
		anatomy.twinkle_phase[point_index] = rng.randf() * TAU
		anatomy.twinkle_speed[point_index] = 0.8 + rng.randf() * 1.4
		anatomy.shimmer_amp.append(Vector3(0.003 + rng.randf() * 0.006, 0.003 + rng.randf() * 0.006, 0.003 + rng.randf() * 0.006))
		anatomy.shimmer_freq[point_index] = 0.5 + rng.randf() * 1.1
		anatomy.shimmer_phase.append(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
	for cluster_index in range(cluster_defs.size()):
		if cluster_defs[cluster_index].count > 300:
			continue
		var indices: Array[int] = []
		for point_index in range(point_count):
			if anatomy.point_cluster[point_index] == cluster_index:
				indices.append(point_index)
		var max_len := cluster_defs[cluster_index].spread * 0.85
		for point_index: int in indices:
			var best := -1
			var best_dist := 1e9
			for other: int in indices:
				if other == point_index:
					continue
				var delta := anatomy.point_positions[point_index] - anatomy.point_positions[other]
				var dist := Vector2(delta.x, delta.y).length()
				if dist < best_dist:
					best_dist = dist
					best = other
			if best >= 0 and best_dist <= max_len and point_index < best:
				anatomy.mesh_edges.append(Vector3i(point_index, best, cluster_index))
	var arc_count := 620
	var mid := 185.0 * PI / 180.0
	anatomy.arc_weight.resize(arc_count)
	anatomy.arc_twinkle.resize(arc_count)
	for _arc_index in range(arc_count):
		var angle := deg_to_rad(115.0 + rng.randf() * 140.0)
		var radius := CRESCENT_RADIUS + gauss(rng) * 0.012
		anatomy.arc_points.append(Vector3(
			CRESCENT_CENTER.x + cos(angle) * radius,
			CRESCENT_CENTER.y + sin(angle) * radius * 0.92,
			gauss(rng) * 0.02
		))
		anatomy.arc_weight[anatomy.arc_points.size() - 1] = exp(-pow((angle - mid) / 0.9, 2.0))
		anatomy.arc_twinkle[anatomy.arc_points.size() - 1] = rng.randf() * TAU
	for _tendril_index in range(N_TENDRILS):
		var tendril := Tendril.new()
		var cluster_index := int(rng.randf() * (cluster_defs.size() - 1))
		tendril.cluster_index = cluster_index
		var cluster := cluster_defs[cluster_index]
		var anchor := Vector2(cluster.center.x + gauss(rng) * cluster.spread, cluster.center.y + gauss(rng) * cluster.spread)
		var outward := anchor - CRESCENT_CENTER
		outward = outward.normalized()
		var up := Vector2(0.0, -0.6) if anchor.y < 0.1 else Vector2(0.0, 0.3)
		var reach := 0.35 + rng.randf() * 0.5
		var tip := anchor + (outward + up) * reach + Vector2(gauss(rng) * 0.12, gauss(rng) * 0.12)
		var control := (anchor + tip) * 0.5 + Vector2(gauss(rng) * 0.10, gauss(rng) * 0.10)
		for step in range(9):
			var tt := float(step) / 8.0
			var u := 1.0 - tt
			tendril.points.append(Vector3(
				u * u * anchor.x + 2.0 * u * tt * control.x + tt * tt * tip.x,
				u * u * anchor.y + 2.0 * u * tt * control.y + tt * tt * tip.y,
				0.0
			))
		tendril.sway = 0.006 + rng.randf() * 0.012
		tendril.sway_freq = 0.15 + rng.randf() * 0.25
		tendril.sway_phase = rng.randf() * TAU
		var dot_list: Array[int] = []
		while dot_list.size() < 2:
			var pick := 3 + int(rng.randf() * 6)
			if pick not in dot_list:
				dot_list.append(pick)
		dot_list.sort()
		dot_list.append(8)
		for dot_index: int in dot_list:
			tendril.dot_indices.append(dot_index)
		anatomy.tendrils.append(tendril)
	return anatomy


static func gauss(rng: RandomNumberGenerator) -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0:
		u = rng.randf()
	while v == 0.0:
		v = rng.randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)
