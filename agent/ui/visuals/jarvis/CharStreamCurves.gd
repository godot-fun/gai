class_name CharStreamCurves
extends RefCounted

## 3D path templates for orb text particles.


static func build(style: OrbPhase.PathStyle, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> Curve3D:
	var curve := Curve3D.new()
	if neurons.is_empty():
		_build_fallback(curve, style, rng)
		return curve
	match style:
		OrbPhase.PathStyle.SPIRAL_IN:
			_build_spiral_in(curve, neurons, rng)
		OrbPhase.PathStyle.ORBIT:
			_build_orbit(curve, neurons, rng)
		OrbPhase.PathStyle.CHAOTIC:
			_build_chaotic(curve, neurons, rng)
		_:
			_build_transverse(curve, neurons, rng)
	curve.bake_interval = 0.05
	curve.get_baked_length()
	return curve


static func pick_neuron(neurons: PackedVector3Array, rng: RandomNumberGenerator) -> Vector3:
	if neurons.is_empty():
		return Vector3.ZERO
	return neurons[rng.randi_range(0, neurons.size() - 1)]


static func _build_fallback(curve: Curve3D, style: OrbPhase.PathStyle, rng: RandomNumberGenerator) -> void:
	var extent: float = OrbVisualScale.PATH_EXTENT
	var start := Vector3(-extent, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
	var end := Vector3(extent, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
	if style == OrbPhase.PathStyle.SPIRAL_IN:
		start = Vector3(rng.randf_range(1.0, extent), rng.randf_range(-0.65, 0.65), rng.randf_range(-0.65, 0.65))
		end = Vector3.ZERO
	curve.add_point(start)
	curve.add_point(start.lerp(end, 0.35) + Vector3(0, rng.randf_range(-0.35, 0.35), rng.randf_range(-0.45, 0.45)))
	curve.add_point(end)
	pass


static func _build_transverse(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var extent: float = OrbVisualScale.PATH_EXTENT
	var side := 1.0 if rng.randf() > 0.5 else -1.0
	var start := Vector3(-extent * side, rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
	var end := Vector3(extent * -side, rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
	var mid := pick_neuron(neurons, rng)
	curve.add_point(start)
	curve.add_point(start.lerp(mid, 0.45) + Vector3(0, rng.randf_range(-0.2, 0.2), 0))
	curve.add_point(mid)
	curve.add_point(mid.lerp(end, 0.55) + Vector3(0, rng.randf_range(-0.2, 0.2), 0))
	curve.add_point(end)
	pass


static func _build_spiral_in(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var extent: float = OrbVisualScale.PATH_EXTENT
	var start := Vector3(
		rng.randf_range(-extent, extent),
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)
	curve.add_point(start)
	for step in 3:
		var t := float(step + 1) / 4.0
		var ring := start.lerp(Vector3.ZERO, t)
		ring += Vector3(
			sin(t * TAU * 1.5 + rng.randf()) * (1.0 - t) * 0.42,
			cos(t * TAU * 1.2) * (1.0 - t) * 0.3,
			sin(t * TAU * 0.9) * (1.0 - t) * 0.36
		)
		curve.add_point(ring)
	curve.add_point(pick_neuron(neurons, rng) * 0.35)
	pass


static func _build_orbit(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var radius := rng.randf_range(1.15, 1.55)
	var tilt := rng.randf_range(-0.45, 0.45)
	for step in 5:
		var angle: float = float(step) / 4.0 * TAU * 0.85
		curve.add_point(Vector3(cos(angle) * radius, sin(angle) * 0.3 + tilt, sin(angle) * radius * 0.55))
	curve.add_point(pick_neuron(neurons, rng) * 0.5)
	pass


static func _build_chaotic(curve: Curve3D, neurons: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var pos := pick_neuron(neurons, rng) * 1.25
	curve.add_point(pos)
	for _step in 4:
		pos += Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.55, 0.55))
		curve.add_point(pos)
	pass
