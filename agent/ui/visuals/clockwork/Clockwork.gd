class_name Clockwork
extends VisualEffect

## 机械表机芯 (watch movement): a whole watch movement runs centred over the interface — jewelled
## bridge plates, barrel with its mainspring, centre and third wheels, escape wheel, pallet fork, a
## balance wheel with its hairspring, a winding ratchet, a chiming gong with hammers, and a small
## seconds sub-dial. Reasoning winds the mainspring and clicks the ratchet; streamed answers release
## energy one beat at a time, so the escape wheel steps tooth by tooth, sparks at the released tooth
## and the seconds hand sweeps in eighth-of-a-second steps. Every tool call lifts a hammer over the
## gong: success strikes a chime and hands the train one beat, failure jams the escapement so the
## wheels chatter backwards. When the run ends the mainspring unwinds, the balance settles and the
## movement stops with the seconds hand frozen where it stopped.

const BASE_SPEED := 0.85
const WIND_PER_ENERGY := 2.4
const UNWIND_PER_SECOND := 0.06
const RATE_FOLLOW := 3.2
const JAM_DECAY_PER_SECOND := 0.45
const BEAT_COST := 0.12
const BEAT_FLASH_DECAY := 3.2
const BALANCE_HZ := 2.4
const PALLET_SWING := 0.34
const CHIME_SECONDS := 0.8
const SPARK_SECONDS := 0.32
const END_MSEC := 1400
const MAX_HAMMERS := 6
const BARREL_TEETH := 48
const CENTRE_TEETH := 40
const THIRD_TEETH := 30
const ESCAPE_TEETH := 15
const RATCHET_TEETH := 12
const BALANCE_RADIUS := 52.0
const DIAL_RADIUS := 38.0
const RATCHET_RADIUS := 18.0
const GONG_RADIUS := 32.0
const HAMMER_REACH := 52.0
const BRIDGE_WIDTH := 34.0
## An 8-beat movement sweeps 480 times a minute, so the seconds hand advances in eighth steps.
const SECONDS_STEPS := 480.0
const GEAR_RADII: Array[float] = [86.0, 58.0, 40.0, 24.0]
const GEAR_HEADINGS: Array[float] = [-0.45, 0.62, -0.32]


class Gear extends RefCounted:
	var center: Vector2 = Vector2.ZERO
	var radius: float = 40.0
	var teeth: int = 30
	var ratio: float = 1.0
	var angle: float = 0.0
	var phase: float = 0.0
	var glowing: float = 0.0


class Hammer extends RefCounted:
	var slot: int = 0
	var lift: float = 0.0


var gears: Array[Gear] = []
## tool_call_id -> hammer lifted over the gong while the tool runs.
var hammers: Dictionary[String, Hammer] = {}
var balance_center: Vector2 = Vector2.ZERO
var gong_center: Vector2 = Vector2.ZERO
var dial_center: Vector2 = Vector2.ZERO
var ratchet_center: Vector2 = Vector2.ZERO
var layout_size: Vector2 = Vector2.ZERO
var design_scale: float = 1.0
var barrel_angle: float = 0.0
var tension: float = 0.0
var rate: float = 0.0
var beat_charge: float = 0.0
var beat_flash: float = 0.0
var beat_count: int = 0
var escape_index: int = 0
var pallet_angle: float = 0.0
var balance_phase: float = 0.0
var seconds_angle: float = 0.0
## Raw sweep accumulating behind [member seconds_angle], which is snapped to eighth steps.
var seconds_raw: float = 0.0
var ratchet_steps: int = 0
var ratchet_angle: float = 0.0
var pawl_flick: float = 0.0
var spark_age: float = SPARK_SECONDS
var jam: float = 0.0
var chime: float = 0.0
var clock: float = 0.0
var unwinding: bool = false
var assembly: float = 1.0
var brass_color: Color = Color(0.85, 0.72, 0.42)
var steel_color: Color = Color(0.7, 0.78, 0.86)
var jewel_color: Color = Color(0.42, 0.72, 1.0)
var core_color: Color = Color(0.98, 0.99, 1.0)
var error_color: Color = Color(1.0, 0.35, 0.35)


func _ready() -> void:
	super._ready()
	rebuild_movement()
	pass


func fade_in_seconds() -> float:
	return 0.4


func fade_out_seconds() -> float:
	return 0.5


func on_agent_start(_session_id: int) -> void:
	hammers.clear()
	barrel_angle = 0.0
	tension = 0.0
	rate = 0.0
	beat_charge = 0.0
	beat_flash = 0.0
	beat_count = 0
	escape_index = 0
	pallet_angle = 0.0
	balance_phase = 0.0
	seconds_angle = 0.0
	seconds_raw = 0.0
	ratchet_steps = 0
	ratchet_angle = 0.0
	pawl_flick = 0.0
	spark_age = SPARK_SECONDS
	jam = 0.0
	chime = 0.0
	clock = 0.0
	unwinding = false
	assembly = 0.0
	sync_palette()
	rebuild_movement()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	unwinding = true
	beat_charge = 0.0
	if StringUtils.is_not_blank(error_message):
		jam = 1.0
	if not is_inside_tree():
		tension = 0.0
		rate = 0.0
		return
	await get_tree().create_timer(END_MSEC / 1000.0).timeout
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or unwinding:
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		# Reasoning coils the mainspring: stored energy rises without driving the train yet.
		tension = minf(tension + energy * WIND_PER_ENERGY, 1.0)
		return
	beat_charge += energy * 2.6
	while beat_charge >= BEAT_COST:
		beat_charge -= BEAT_COST
		beat()
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if hammers.has(tool_call_id) or hammers.size() >= MAX_HAMMERS or unwinding:
		return
	var hammer := Hammer.new()
	hammer.slot = next_hammer_slot()
	hammers[tool_call_id] = hammer
	if not gears.is_empty():
		gears[hammer.slot % gears.size()].glowing = 1.0
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not hammers.has(tool_call_id):
		return
	var hammer: Hammer = hammers[tool_call_id]
	hammers.erase(tool_call_id)
	hammer.lift = 0.0
	if result.is_error:
		# A failed tool jams the escapement: the train loses its beat and chatters backwards.
		jam = 1.0
		tension = maxf(tension - 0.18, 0.0)
		return
	chime = 1.0
	tension = minf(tension + 0.24, 1.0)
	if not gears.is_empty():
		gears[hammer.slot % gears.size()].glowing = 1.0
	beat()
	pass


func next_hammer_slot() -> int:
	for slot in range(MAX_HAMMERS):
		var taken := false
		for hammer: Hammer in hammers.values():
			if hammer.slot == slot:
				taken = true
				break
		if not taken:
			return slot
	return 0


## One escapement release: the escape wheel advances a single tooth and sparks there.
func beat() -> void:
	beat_count += 1
	escape_index += 1
	beat_flash = 1.0
	spark_age = 0.0
	pallet_angle = PALLET_SWING if escape_index % 2 == 0 else -PALLET_SWING
	pass


func step_clock(delta: float) -> void:
	clock += delta
	beat_flash = maxf(beat_flash - BEAT_FLASH_DECAY * delta, 0.0)
	chime = maxf(chime - delta / CHIME_SECONDS, 0.0)
	spark_age = minf(spark_age + delta, SPARK_SECONDS)
	jam = maxf(jam - JAM_DECAY_PER_SECOND * delta, 0.0)
	if unwinding:
		tension = maxf(tension - UNWIND_PER_SECOND * 6.0 * delta, 0.0)
	else:
		tension = maxf(tension - UNWIND_PER_SECOND * delta, 0.0)
	for hammer: Hammer in hammers.values():
		hammer.lift = minf(hammer.lift + delta * 3.4, 1.0)
	var target_rate := tension * (0.55 + 0.45 * beat_flash)
	if jam > 0.0:
		target_rate *= 1.0 - jam
	if unwinding and tension <= 0.001:
		target_rate = 0.0
	rate = lerpf(rate, target_rate, clampf(delta * RATE_FOLLOW, 0.0, 1.0))
	var chatter := sin(clock * 34.0) * 0.22 * jam
	barrel_angle += delta * BASE_SPEED * rate
	var driven := barrel_angle * (1.0 + chatter)
	for gear: Gear in gears:
		if gear.teeth == ESCAPE_TEETH:
			# The escape wheel only ever sits on a tooth, so the train visibly ticks.
			gear.angle = snappedf(driven * gear.ratio, TAU / float(ESCAPE_TEETH))
			continue
		gear.angle = driven * gear.ratio
		gear.glowing = maxf(gear.glowing - delta * 1.8, 0.0)
	pallet_angle = lerpf(pallet_angle, PALLET_SWING if escape_index % 2 == 0 else -PALLET_SWING, clampf(delta * 20.0, 0.0, 1.0))
	balance_phase += delta * BALANCE_HZ * TAU * (0.35 + 0.65 * rate)
	assembly = minf(assembly + delta * 2.4, 1.0)
	seconds_raw = fposmod(seconds_raw + delta * rate * TAU * 8.0 / 60.0, TAU)
	seconds_angle = fposmod(snappedf(seconds_raw, TAU / SECONDS_STEPS), TAU)
	update_ratchet(delta)
	pass


## The ratchet clicks one tooth each time the mainspring winds far enough.
func update_ratchet(delta: float) -> void:
	pawl_flick = maxf(pawl_flick - delta * 4.0, 0.0)
	var steps := int(floorf(tension * float(RATCHET_TEETH)))
	if steps == ratchet_steps:
		return
	ratchet_steps = steps
	ratchet_angle = -float(steps) * TAU / float(RATCHET_TEETH)
	pawl_flick = 1.0
	pass


func sync_palette() -> void:
	# Warm brass against cool steel, both remapped so the movement stays readable on light chat.
	brass_color = VisualColor.appearance_color(Color(0.95, 0.76, 0.38), 0.0, 0.95, 1.0)
	steel_color = VisualColor.appearance_color(ThemeColor.accent_theme_color(), 0.0, 0.5)
	jewel_color = VisualColor.appearance_color(Color(0.95, 0.3, 0.42), 0.0, 1.0, 0.85)
	core_color = Color(0.98, 0.99, 1.0) if ThemeColor.is_dark_theme() else VisualColor.ink_color(brass_color, 0.0, 1.0, 0.4)
	error_color = Colors.error
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


## Lays out a tangentially meshing chain, then centres the whole movement in the window.
func rebuild_movement() -> void:
	var view := view_size()
	if view == layout_size and not gears.is_empty():
		return
	layout_size = view
	design_scale = minf(view.x / 1280.0, view.y / 720.0)
	gears.clear()
	var teeth: Array[int] = [BARREL_TEETH, CENTRE_TEETH, THIRD_TEETH, ESCAPE_TEETH]
	for index in range(GEAR_RADII.size()):
		var gear := Gear.new()
		gear.radius = GEAR_RADII[index] * design_scale
		gear.teeth = teeth[index]
		gear.phase = TAU / float(gear.teeth) * (0.5 if index % 2 == 1 else 0.0)
		if index == 0:
			gear.center = Vector2.ZERO
		else:
			var previous := gears[index - 1]
			var gap := (previous.radius + gear.radius) * 0.985
			gear.center = previous.center + Vector2.from_angle(GEAR_HEADINGS[index - 1]) * gap
		gear.ratio = 1.0 if index == 0 else gears[index - 1].ratio * gear_ratio(gears[index - 1].teeth, gear.teeth)
		gears.append(gear)
	var last := gears[gears.size() - 1]
	balance_center = last.center + Vector2.from_angle(-0.1) * (last.radius + BALANCE_RADIUS * design_scale * 0.92)
	gong_center = gears[0].center + Vector2.from_angle(PI * 0.64) * (gears[0].radius + GONG_RADIUS * design_scale + 24.0 * design_scale)
	dial_center = balance_center + Vector2(0.0, BALANCE_RADIUS * design_scale + DIAL_RADIUS * design_scale + 14.0 * design_scale)
	ratchet_center = gears[0].center + Vector2.from_angle(-PI * 0.7) * (gears[0].radius + RATCHET_RADIUS * design_scale + 6.0 * design_scale)
	center_composition(view)
	pass


## Bounding box of every part of the movement, used to centre it in the window.
func composition_bounds() -> Rect2:
	if gears.is_empty():
		return Rect2()
	var bounds := Rect2(gears[0].center, Vector2.ZERO)
	for gear: Gear in gears:
		bounds = bounds.expand(gear.center - Vector2.ONE * gear.radius)
		bounds = bounds.expand(gear.center + Vector2.ONE * gear.radius)
	var balance_radius := (BALANCE_RADIUS + 6.0) * design_scale
	bounds = bounds.expand(balance_center - Vector2.ONE * balance_radius)
	bounds = bounds.expand(balance_center + Vector2.ONE * balance_radius)
	var gong_radius := (GONG_RADIUS + HAMMER_REACH * 0.6 + 10.0) * design_scale
	bounds = bounds.expand(gong_center - Vector2.ONE * gong_radius)
	bounds = bounds.expand(gong_center + Vector2.ONE * gong_radius)
	var dial_radius := (DIAL_RADIUS + 5.0) * design_scale
	bounds = bounds.expand(dial_center - Vector2.ONE * dial_radius)
	bounds = bounds.expand(dial_center + Vector2.ONE * dial_radius)
	var ratchet_radius := (RATCHET_RADIUS + 8.0) * design_scale
	bounds = bounds.expand(ratchet_center - Vector2.ONE * ratchet_radius)
	bounds = bounds.expand(ratchet_center + Vector2.ONE * ratchet_radius)
	var gauge := gears[0].center + Vector2(0.0, -gears[0].radius - 48.0 * design_scale)
	bounds = bounds.expand(gauge - Vector2.ONE * 30.0 * design_scale)
	bounds = bounds.expand(gauge + Vector2.ONE * 30.0 * design_scale)
	return bounds


func center_composition(view: Vector2) -> void:
	if gears.is_empty():
		return
	var offset := view * 0.5 - composition_bounds().get_center()
	for gear: Gear in gears:
		gear.center += offset
	balance_center += offset
	gong_center += offset
	dial_center += offset
	ratchet_center += offset
	pass


static func gear_ratio(driver_teeth: int, driven_teeth: int) -> float:
	if driven_teeth <= 0:
		return 0.0
	return -float(driver_teeth) / float(driven_teeth)


func _process(delta: float) -> void:
	if not visible:
		return
	rebuild_movement()
	step_clock(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func _draw() -> void:
	if gears.is_empty():
		return
	draw_bridges()
	for gear: Gear in gears:
		draw_gear(gear)
	draw_mainspring()
	draw_pallet()
	draw_balance()
	draw_dial()
	draw_ratchet()
	draw_gong()
	draw_hammers()
	draw_power_reserve()
	draw_spark()
	pass


## Jewelled bridge plates: a wide steel band with a lit top edge and screwed-down joints.
func draw_bridges() -> void:
	var points := PackedVector2Array()
	for gear: Gear in gears:
		points.append(gear.center)
	points.append(balance_center)
	var width := BRIDGE_WIDTH * design_scale
	var ink := VisualColor.ink_alpha()
	draw_polyline(points, VisualColor.stroke(steel_color, 0.03 * assembly / ink), width * 1.45, true)
	draw_polyline(points, VisualColor.stroke(steel_color, 0.05 * assembly / ink), width, true)
	for point: Vector2 in points:
		draw_circle(point, width * 0.46, VisualColor.stroke(steel_color, 0.05 * assembly / ink))
	var edge := PackedVector2Array()
	var underside := PackedVector2Array()
	for point: Vector2 in points:
		edge.append(point - Vector2(0.0, width * 0.44))
		underside.append(point + Vector2(0.0, width * 0.44))
	draw_polyline(edge, VisualColor.stroke(steel_color, 0.14 * assembly), maxf(1.0, 1.4 * design_scale), true)
	draw_polyline(underside, VisualColor.stroke(steel_color, 0.07 * assembly), maxf(1.0, 1.2 * design_scale), true)
	for index in range(points.size() - 1):
		draw_screw((points[index] + points[index + 1]) * 0.5 - Vector2(0.0, width * 0.08))
	pass


func draw_screw(center: Vector2) -> void:
	var radius := 7.0 * design_scale
	draw_circle(center, radius, VisualColor.stroke(steel_color, 0.16 * assembly))
	draw_arc(center, radius, 0.0, TAU, 18, VisualColor.stroke(steel_color, 0.4 * assembly), maxf(1.0, 1.2 * design_scale), true)
	var slot := Vector2.from_angle(0.7 + barrel_angle * 0.05) * radius * 0.72
	draw_line(center - slot, center + slot, VisualColor.stroke(steel_color, 0.45 * assembly), maxf(1.0, 1.1 * design_scale), true)
	pass


## Gold chaton around a ruby: every wheel pivots in one of these.
func draw_jewel(center: Vector2, radius: float) -> void:
	var flash := 0.25 * beat_flash
	draw_circle(center, radius * 1.9, VisualColor.stroke(brass_color, (0.14 + flash * 0.2) * assembly))
	draw_arc(center, radius * 1.9, 0.0, TAU, 20, VisualColor.stroke(brass_color, (0.45 + flash) * assembly),
		maxf(1.0, radius * 0.22), true)
	draw_circle(center, radius, VisualColor.stroke(jewel_color, (0.5 + flash) * assembly))
	draw_circle(center, radius * 0.38, VisualColor.stroke(jewel_color.lightened(0.55), (0.72 + flash) * assembly))
	pass


func draw_gear(gear: Gear) -> void:
	var root := gear.radius * 0.78
	var points := PackedVector2Array()
	var step := TAU / float(gear.teeth)
	for index in range(gear.teeth):
		var base := gear.angle + gear.phase + step * float(index)
		points.append(gear.center + Vector2.from_angle(base - step * 0.24) * gear.radius)
		points.append(gear.center + Vector2.from_angle(base + step * 0.24) * gear.radius)
		points.append(gear.center + Vector2.from_angle(base + step * 0.36) * root)
		points.append(gear.center + Vector2.from_angle(base + step * 0.48) * root)
	points.append(points[0])
	var glow := 0.32 + 0.55 * gear.glowing
	var ink := VisualColor.ink_alpha()
	# A faint gilt body so the wheels read as metal discs rather than wireframes.
	draw_circle(gear.center, root, VisualColor.stroke(brass_color, (0.05 + 0.04 * gear.glowing) * assembly / ink))
	draw_polyline(points, VisualColor.stroke(brass_color, 0.08 + 0.2 * gear.glowing), maxf(3.0, 5.0 * design_scale), true)
	draw_polyline(points, VisualColor.stroke(brass_color, glow), maxf(1.0, 1.7 * design_scale), true)
	draw_arc(gear.center, root * 0.94, 0.0, TAU, 48, VisualColor.stroke(brass_color, 0.3), maxf(1.0, 1.3 * design_scale), true)
	draw_arc(gear.center, root * 0.62, 0.0, TAU, 32, VisualColor.stroke(brass_color, 0.14), maxf(1.0, 1.0 * design_scale), true)
	for spoke in range(4):
		var heading := gear.angle * 0.5 + TAU * float(spoke) / 4.0
		draw_line(gear.center + Vector2.from_angle(heading) * root * 0.2, gear.center + Vector2.from_angle(heading) * root * 0.86,
			VisualColor.stroke(brass_color, 0.22), maxf(1.0, 1.9 * design_scale), true)
	draw_circle(gear.center, root * 0.2, VisualColor.stroke(brass_color, 0.34))
	draw_jewel(gear.center, maxf(2.0, 3.6 * design_scale))
	pass


## Archimedean spiral: coils tighten as the mainspring winds up.
func draw_mainspring() -> void:
	if gears.is_empty():
		return
	var barrel := gears[0]
	var coils := 2.4 + 3.2 * tension
	var points := PackedVector2Array()
	var steps := 96
	var inner := barrel.radius * 0.2
	var outer := barrel.radius * 0.76
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var radius := lerpf(inner, outer, t)
		var heading := barrel_angle * 0.3 + t * coils * TAU
		points.append(barrel.center + Vector2.from_angle(heading) * radius)
	draw_polyline(points, VisualColor.stroke(steel_color, 0.2 + 0.24 * tension), maxf(1.0, 1.6 * design_scale), true)
	pass


func draw_pallet() -> void:
	if gears.size() < 4:
		return
	var escape := gears[3]
	var pivot := escape.center + Vector2.from_angle(-0.5) * escape.radius * 1.9
	var arm := escape.radius * 1.15
	var heading := pallet_angle - 0.6
	var reach_color := VisualColor.stroke(steel_color, 0.34 + 0.3 * beat_flash)
	draw_line(pivot, pivot + Vector2.from_angle(heading) * arm, reach_color, maxf(1.2, 1.8 * design_scale), true)
	draw_line(pivot, pivot + Vector2.from_angle(heading + 1.05) * arm * 0.86, reach_color, maxf(1.2, 1.6 * design_scale), true)
	draw_jewel(pivot, maxf(1.6, 2.6 * design_scale))
	pass


func draw_balance() -> void:
	var radius := BALANCE_RADIUS * design_scale
	var amplitude := (0.25 + 0.75 * rate) * 2.1
	var heading := sin(balance_phase) * amplitude
	var center := balance_center
	draw_arc(center, radius, 0.0, TAU, 48, VisualColor.stroke(steel_color, 0.44), maxf(1.2, 2.0 * design_scale), true)
	draw_arc(center, radius * 0.72, 0.0, TAU, 36, VisualColor.stroke(steel_color, 0.2), maxf(1.0, 1.1 * design_scale), true)
	for arm_index in range(2):
		var arm_heading := heading + PI * float(arm_index)
		draw_line(center + Vector2.from_angle(arm_heading) * radius * 0.2, center + Vector2.from_angle(arm_heading) * radius * 0.92,
			VisualColor.stroke(steel_color, 0.36), maxf(1.0, 2.0 * design_scale), true)
	var spring := PackedVector2Array()
	for index in range(64):
		var t := float(index) / 63.0
		var spring_radius := radius * (0.12 + 0.6 * t)
		spring.append(center + Vector2.from_angle(heading * (1.0 - t * 0.6) + t * 5.0 * TAU) * spring_radius)
	draw_polyline(spring, VisualColor.stroke(steel_color, 0.22 + 0.16 * rate), maxf(1.0, 1.1 * design_scale), true)
	draw_jewel(center, maxf(2.0, 3.4 * design_scale))
	pass


## Small seconds sub-dial; the hand advances in eighth-of-a-second steps while the train runs.
func draw_dial() -> void:
	var radius := DIAL_RADIUS * design_scale
	var center := dial_center
	draw_circle(center, radius * 1.08, VisualColor.stroke(steel_color, 0.04 * assembly))
	draw_arc(center, radius, 0.0, TAU, 56, VisualColor.stroke(steel_color, 0.4 * assembly), maxf(1.2, 1.8 * design_scale), true)
	draw_arc(center, radius * 0.9, 0.0, TAU, 48, VisualColor.stroke(steel_color, 0.14 * assembly), maxf(1.0, 1.0 * design_scale), true)
	for index in range(60):
		var heading := TAU * float(index) / 60.0 - PI * 0.5
		var major := index % 5 == 0
		var length := radius * (0.3 if major else 0.16)
		draw_line(center + Vector2.from_angle(heading) * (radius * 0.88 - length), center + Vector2.from_angle(heading) * radius * 0.88,
			VisualColor.stroke(steel_color, (0.5 if major else 0.28) * assembly), maxf(1.0, (1.7 if major else 1.0) * design_scale), true)
	var heading := seconds_angle - PI * 0.5
	draw_line(center - Vector2.from_angle(heading) * radius * 0.18, center + Vector2.from_angle(heading) * radius * 0.82,
		VisualColor.stroke(brass_color, 0.85), maxf(1.0, 2.0 * design_scale), true)
	draw_circle(center, maxf(1.6, 3.4 * design_scale), VisualColor.stroke(brass_color, 0.5))
	pass


## Winding ratchet beside the barrel: reasoning clicks it tooth by tooth.
func draw_ratchet() -> void:
	var radius := RATCHET_RADIUS * design_scale
	draw_arc(ratchet_center, radius, 0.0, TAU, 30, VisualColor.stroke(steel_color, 0.2), maxf(1.0, 1.2 * design_scale), true)
	var points := PackedVector2Array()
	var step := TAU / float(RATCHET_TEETH)
	for index in range(RATCHET_TEETH):
		var base := ratchet_angle + step * float(index)
		points.append(ratchet_center + Vector2.from_angle(base) * radius)
		points.append(ratchet_center + Vector2.from_angle(base + step * 0.35) * radius * 0.74)
	points.append(points[0])
	draw_polyline(points, VisualColor.stroke(steel_color, (0.34 + 0.3 * pawl_flick) * assembly), maxf(1.0, 1.4 * design_scale), true)
	draw_circle(ratchet_center, radius * 0.2, VisualColor.stroke(brass_color, 0.3))
	# Click pawl springing against the teeth.
	var base_heading := PI * 0.86 + 0.16 * pawl_flick
	var pivot := ratchet_center + Vector2.from_angle(base_heading) * radius * 2.1
	var tip := ratchet_center + Vector2.from_angle(base_heading) * radius * 0.92
	draw_line(pivot, tip, VisualColor.stroke(steel_color, 0.4 + 0.3 * pawl_flick), maxf(1.0, 1.5 * design_scale), true)
	draw_circle(pivot, maxf(1.2, 2.2 * design_scale), VisualColor.stroke(steel_color, 0.35))
	pass


func draw_gong() -> void:
	var radius := GONG_RADIUS * design_scale
	var ring := 0.4 + 0.5 * chime
	draw_arc(gong_center, radius, 0.0, TAU, 44, VisualColor.stroke(brass_color, ring), maxf(1.4, 2.4 * design_scale), true)
	draw_arc(gong_center, radius * 0.86, 0.0, TAU, 36, VisualColor.stroke(brass_color, ring * 0.5), maxf(1.0, 1.2 * design_scale), true)
	var clamp_point := gong_center + Vector2(0.0, -radius - 15.0 * design_scale)
	draw_line(gong_center + Vector2(0.0, -radius), clamp_point, VisualColor.stroke(steel_color, 0.32), maxf(1.0, 1.4 * design_scale), true)
	draw_circle(clamp_point, maxf(1.4, 3.2 * design_scale), VisualColor.stroke(steel_color, 0.4))
	if chime > 0.01:
		draw_arc(gong_center, radius * (1.2 + 1.4 * (1.0 - chime)), 0.0, TAU, 32, VisualColor.stroke(brass_color, 0.45 * chime), 1.6, true)
	pass


func draw_hammers() -> void:
	var radius := GONG_RADIUS * design_scale
	for hammer: Hammer in hammers.values():
		var base := -PI * 0.5 + TAU * float(hammer.slot) / float(MAX_HAMMERS)
		var pivot := gong_center + Vector2.from_angle(base) * (radius + HAMMER_REACH * 0.6 * design_scale)
		var swing := -0.55 * hammer.lift
		var heading := base + PI + swing
		var tip := pivot + Vector2.from_angle(heading) * HAMMER_REACH * 0.5 * design_scale
		draw_line(pivot, tip, VisualColor.stroke(steel_color, 0.36), maxf(1.0, 1.8 * design_scale), true)
		draw_circle(tip, maxf(2.0, 5.0 * design_scale), VisualColor.stroke(brass_color, 0.5))
		draw_circle(pivot, maxf(1.2, 2.4 * design_scale), VisualColor.stroke(jewel_color, 0.4))
	pass


## Power-reserve gauge above the barrel: a 90 degree arc of ticks and a needle at tension.
func draw_power_reserve() -> void:
	if gears.is_empty():
		return
	var barrel := gears[0]
	var center := barrel.center + Vector2(0.0, -barrel.radius - 30.0 * design_scale)
	var radius := 26.0 * design_scale
	var start := -PI * 0.75
	var end := -PI * 0.25
	draw_arc(center, radius, start, end, 24, VisualColor.stroke(steel_color, 0.16), maxf(1.0, 1.2 * design_scale), true)
	for index in range(9):
		var heading := lerpf(start, end, float(index) / 8.0)
		var outer := center + Vector2.from_angle(heading) * radius
		var inner := center + Vector2.from_angle(heading) * radius * 0.82
		draw_line(inner, outer, VisualColor.stroke(steel_color, 0.24), 1.0, true)
	var needle := center + Vector2.from_angle(lerpf(start, end, clampf(tension, 0.0, 1.0))) * radius * 1.05
	var needle_color := error_color if jam > 0.05 else brass_color
	draw_line(center, needle, VisualColor.stroke(needle_color, 0.7), maxf(1.2, 1.8 * design_scale), true)
	draw_circle(center, maxf(1.4, 2.6 * design_scale), VisualColor.stroke(needle_color, 0.5))
	pass


## The released escape tooth flashes: this is the movement's heartbeat.
func draw_spark() -> void:
	if gears.size() < 4 or spark_age >= SPARK_SECONDS:
		return
	var escape := gears[3]
	var t := clampf(spark_age / SPARK_SECONDS, 0.0, 1.0)
	var heading := escape.angle + TAU / float(ESCAPE_TEETH) * 0.5
	var point := escape.center + Vector2.from_angle(heading) * escape.radius
	draw_arc(point, escape.radius * (0.3 + 1.5 * t), 0.0, TAU, 18, VisualColor.stroke(brass_color, 0.55 * (1.0 - t)),
		maxf(1.0, 1.4 * design_scale), true)
	draw_circle(point, maxf(1.4, 3.4 * design_scale) * (1.0 - t), VisualColor.stroke(core_color, 0.7 * (1.0 - t)))
	pass
