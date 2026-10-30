class_name Abacus
extends VisualEffect

## 算盘 (abacus): a nine-rod suanpan floats in the middle of the interface and counts the run in
## beads. Every streamed answer unit flicks one lower bead up to the beam; a full rod carries into
## the rod beside it with a pulse of light running along the beam, so long answers visibly climb the
## columns. Reasoning only previews the next flick as hollow ghost beads, and a new turn commits
## them. Each tool call brackets a rod: success commits a beat with a carry clack, failure throws
## the beads back to the snapshot taken when the tool started and shakes the rod. The run ends by
## clearing the whole frame back to zero.

const RODS := 9
const UPPER_BEADS := 2
const LOWER_BEADS := 5
const FRAME_WIDTH_RATIO := 0.34
const FRAME_HEIGHT_RATIO := 0.75
const FRAME_MAX_HEIGHT_RATIO := 0.56
const UPPER_DECK_RATIO := 0.32
const BEAM_RATIO := 0.055
const BEAD_GAP := 2.05
## Rod spacing measured in bead radii, so the beads keep a suanpan's proportions at any size.
const BEAD_SPACING_RATIO := 3.2
const UNIT_COST := 0.12
const CONTENT_GAIN := 2.6
const REASONING_GAIN := 2.0
const SPRING_STIFFNESS := 240.0
const SPRING_DAMPING := 19.0
const FLASH_DECAY := 2.6
const SHAKE_DECAY := 1.6
const CARRY_SECONDS := 0.55
const CLACK_SECONDS := 0.4
const MAX_CLACKS := 24
const END_MSEC := 1200


class Rod extends RefCounted:
	## Continuous bead positions, spring-animated toward the integer targets below.
	var upper_pos: float = 0.0
	var lower_pos: float = 0.0
	var upper_velocity: float = 0.0
	var lower_velocity: float = 0.0
	var target_upper: int = 0
	var target_lower: int = 0
	var flash: float = 0.0
	var shake: float = 0.0


class Carry extends RefCounted:
	var from_rod: int = 0
	var to_rod: int = 0
	var age: float = 0.0


class Clack extends RefCounted:
	var rod: int = 0
	var age: float = 0.0
	var upper: bool = false


var rods: Array[Rod] = []
## tool_call_id -> number of committed units when the tool started.
var tools: Dictionary[String, int] = {}
var carries: Array[Carry] = []
var clacks: Array[Clack] = []
var value: int = 0
var preview_value: int = 0
var content_charge: float = 0.0
var reasoning_charge: float = 0.0
var active_rod: int = -1
var clearing: bool = false
var clock: float = 0.0
var bead_color: Color = Color(0.5, 0.72, 1.0)
var bead_core: Color = Color(0.06, 0.08, 0.14)
var frame_color: Color = Color(0.72, 0.58, 0.36)
var rod_color: Color = Color(0.7, 0.78, 0.86)
var accent_color: Color = Color(0.55, 0.75, 1.0)
var error_color: Color = Color(1.0, 0.35, 0.35)
var seal_color: Color = Color(0.8, 0.18, 0.16)
var paper_color: Color = Color(1.0, 0.96, 0.92)


func _ready() -> void:
	super._ready()
	sync_palette()
	ensure_rods()
	pass


func fade_in_seconds() -> float:
	return 0.32


func fade_out_seconds() -> float:
	return 0.4


func on_agent_start(_session_id: int) -> void:
	tools.clear()
	carries.clear()
	clacks.clear()
	value = 0
	preview_value = 0
	content_charge = 0.0
	reasoning_charge = 0.0
	active_rod = -1
	clearing = false
	clock = 0.0
	sync_palette()
	ensure_rods()
	for rod: Rod in rods:
		rod.upper_pos = 0.0
		rod.lower_pos = 0.0
		rod.upper_velocity = 0.0
		rod.lower_velocity = 0.0
		rod.target_upper = 0
		rod.target_lower = 0
		rod.flash = 0.0
		rod.shake = 0.0
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	clearing = true
	preview_value = 0
	active_rod = -1
	if StringUtils.is_not_blank(error_message):
		for rod: Rod in rods:
			rod.shake = 1.0
	set_value(0)
	if not is_inside_tree():
		return
	await get_tree().create_timer(END_MSEC / 1000.0).timeout
	pass


func on_turn_start(_session_id: int) -> void:
	# A turn boundary commits whatever the reasoning previewed.
	set_value(maxi(value, preview_value))
	preview_value = value
	pass


func on_turn_end(_session_id: int) -> void:
	content_charge = 0.0
	reasoning_charge = 0.0
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or clearing:
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_charge += energy * REASONING_GAIN
		# The preview always starts from what is already committed, then leads it by a few units.
		preview_value = maxi(preview_value, value)
		while reasoning_charge >= UNIT_COST:
			reasoning_charge -= UNIT_COST
			preview_value = mini(preview_value + 1, max_value())
		return
	content_charge += energy * CONTENT_GAIN
	while content_charge >= UNIT_COST:
		content_charge -= UNIT_COST
		set_value(value + 1)
		preview_value = maxi(preview_value, value)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if clearing:
		return
	tools[tool_call_id] = value
	active_rod = carry_rod(value + 1) if not rods.is_empty() else -1
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not tools.has(tool_call_id):
		return
	var snapshot: int = tools[tool_call_id]
	tools.erase(tool_call_id)
	active_rod = -1
	if result.is_error:
		var previous := value
		set_value(snapshot)
		if value != previous:
			for index in range(rods.size()):
				rods[index].shake = 1.0
		return
	set_value(maxi(value + 1, preview_value))
	preview_value = value
	pass


## Commits a new count, clacking on the rods whose digits changed and pulsing the beam on a carry.
func set_value(new_value: int) -> void:
	var clamped := clampi(new_value, 0, max_value())
	if clamped == value:
		return
	var old_digits := digits_of(value, rods.size())
	var new_digits := digits_of(clamped, rods.size())
	value = clamped
	for index in range(rods.size()):
		if old_digits[index] == new_digits[index]:
			continue
		var targets := bead_targets(new_digits[index])
		if rods[index].target_upper != targets.x:
			add_clack(index, true)
		if rods[index].target_lower != targets.y:
			add_clack(index, false)
		rods[index].target_upper = targets.x
		rods[index].target_lower = targets.y
		rods[index].flash = 1.0
		if old_digits[index] == 9 and new_digits[index] == 0 and index + 1 < rods.size():
			add_carry(index)
	pass


func max_value() -> int:
	var result := 1
	for _index in range(rods.size()):
		result *= 10
	return result - 1


func ensure_rods() -> void:
	if rods.size() == RODS:
		return
	rods.clear()
	for _index in range(RODS):
		rods.append(Rod.new())
	pass


func add_carry(from_rod: int) -> void:
	var carry := Carry.new()
	carry.from_rod = from_rod
	carry.to_rod = from_rod + 1
	carries.append(carry)
	pass


func add_clack(rod: int, upper: bool) -> void:
	if clacks.size() >= MAX_CLACKS:
		clacks.remove_at(0)
	var clack := Clack.new()
	clack.rod = rod
	clack.upper = upper
	clacks.append(clack)
	pass


## Digits of [param count], units first.
static func digits_of(count: int, rod_count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(rod_count)
	var remaining := maxi(count, 0)
	for index in range(rod_count):
		var digit := remaining % 10
		result[index] = digit
		remaining = int(float(remaining - digit) / 10.0)
	return result


## Rod a +1 lands on: the lowest rod whose digit is not already full.
static func carry_rod(count: int, rod_count: int = RODS) -> int:
	var digits := digits_of(count, rod_count)
	for index in range(rod_count):
		if digits[index] != 9:
			return index
	return maxi(rod_count - 1, 0)


## Active beads for a rod digit: one upper bead per five, the rest on the lower deck.
static func bead_targets(digit: int) -> Vector2i:
	var clamped := clampi(digit, 0, UPPER_BEADS * 5 + LOWER_BEADS)
	var upper := int(float(clamped) / 5.0)
	var lower := clamped - upper * 5
	return Vector2i(mini(upper, UPPER_BEADS), lower)


static func rod_value(upper: int, lower: int) -> int:
	return upper * 5 + lower


func step_abacus(delta: float) -> void:
	clock += delta
	for rod: Rod in rods:
		var upper := spring_step(rod.upper_pos, float(rod.target_upper), rod.upper_velocity, delta)
		rod.upper_pos = upper.x
		rod.upper_velocity = upper.y
		var lower := spring_step(rod.lower_pos, float(rod.target_lower), rod.lower_velocity, delta)
		rod.lower_pos = lower.x
		rod.lower_velocity = lower.y
		rod.flash = maxf(rod.flash - FLASH_DECAY * delta, 0.0)
		rod.shake = maxf(rod.shake - SHAKE_DECAY * delta, 0.0)
	for index in range(carries.size() - 1, -1, -1):
		carries[index].age += delta
		if carries[index].age >= CARRY_SECONDS:
			carries.remove_at(index)
	for index in range(clacks.size() - 1, -1, -1):
		clacks[index].age += delta
		if clacks[index].age >= CLACK_SECONDS:
			clacks.remove_at(index)
	pass


## Overdamped spring; returns (position, velocity) so a bead clacks slightly before it settles.
static func spring_step(current: float, target: float, velocity: float, delta: float) -> Vector2:
	var next_velocity := velocity + (target - current) * SPRING_STIFFNESS * delta
	next_velocity *= exp(-SPRING_DAMPING * delta)
	var next := current + next_velocity * delta
	if absf(target - next) < 0.001 and absf(next_velocity) < 0.01:
		return Vector2(target, 0.0)
	return Vector2(next, next_velocity)


func sync_palette() -> void:
	var accent := ThemeColor.accent_theme_color()
	bead_color = VisualColor.appearance_color(accent, 0.0, 0.9)
	accent_color = VisualColor.appearance_color(accent, 0.0, 0.8)
	# Warm lacquered wood for the frame, independent of the accent so it reads as furniture.
	frame_color = VisualColor.appearance_color(Color(0.66, 0.45, 0.26), 0.0, 0.85, 1.0)
	rod_color = VisualColor.appearance_color(accent, 0.5, 0.4)
	bead_core = Color(0.05, 0.06, 0.09) if ThemeColor.is_dark_theme() else Color(0.26, 0.27, 0.3)
	seal_color = VisualColor.appearance_color(Color(0.82, 0.16, 0.14), 0.0, 0.9, 1.0)
	error_color = Colors.error
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


## Centered in the window: the abacus is the instrument the run is measured on, not a footer.
func frame_rect() -> Rect2:
	var view := view_size()
	var width := minf(view.x * FRAME_WIDTH_RATIO, view.y * FRAME_MAX_HEIGHT_RATIO / FRAME_HEIGHT_RATIO)
	var height := width * FRAME_HEIGHT_RATIO
	var origin := (view - Vector2(width, height)) * 0.5
	return Rect2(origin, Vector2(width, height))


func frame_padding() -> float:
	return frame_rect().size.x * 0.02


func rod_spacing() -> float:
	return (frame_rect().size.x - frame_padding() * 2.0) / float(RODS)


## Rod index 0 is the units column on the right, matching how a suanpan is read.
func rod_x(index: int) -> float:
	var rect := frame_rect()
	return rect.position.x + frame_padding() + rod_spacing() * (float(RODS - 1 - index) + 0.5)


func beam_top() -> float:
	return frame_rect().position.y + frame_rect().size.y * UPPER_DECK_RATIO


func beam_bottom() -> float:
	return beam_top() + frame_rect().size.y * BEAM_RATIO


func bead_radius() -> float:
	return rod_spacing() / BEAD_SPACING_RATIO


func upper_rest_y(index: int) -> float:
	return frame_rect().position.y + frame_padding() + bead_radius() + float(index) * bead_radius() * BEAD_GAP


func upper_active_y(index: int) -> float:
	return beam_top() - bead_radius() - float(UPPER_BEADS - 1 - index) * bead_radius() * BEAD_GAP


func lower_rest_y(index: int) -> float:
	return frame_rect().end.y - frame_padding() - bead_radius() - float(index) * bead_radius() * BEAD_GAP


func lower_active_y(index: int) -> float:
	return beam_bottom() + bead_radius() + float(index) * bead_radius() * BEAD_GAP


func _process(delta: float) -> void:
	if not visible:
		return
	step_abacus(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func _draw() -> void:
	if rods.is_empty():
		return
	draw_frame()
	for index in range(rods.size()):
		draw_rod(index, rods[index])
	draw_carries()
	draw_clacks()
	draw_value()
	draw_seal()
	pass


func draw_frame() -> void:
	var rect := frame_rect()
	# A slow glint travels along the rails; modulating the highlight avoids painting a wash.
	var glint := exp(-pow((fposmod(clock / 6.0, 1.0) - 0.5) * 3.2, 2.0))
	var post := maxf(3.0, rect.size.y * 0.03)
	var rail := maxf(2.0, rect.size.y * 0.016)
	var hairline := maxf(1.0, rail * 0.4)
	# Four lacquered rails with a lit top edge and a shadowed underside give the frame weight.
	for bar: Rect2 in [
			Rect2(rect.position, Vector2(rect.size.x, rail)),
			Rect2(Vector2(rect.position.x, rect.end.y - rail), Vector2(rect.size.x, rail)),
			Rect2(rect.position, Vector2(rail, rect.size.y)),
			Rect2(Vector2(rect.end.x - rail, rect.position.y), Vector2(rail, rect.size.y))]:
		draw_rect(bar, VisualColor.stroke(frame_color, 0.3))
		draw_line(bar.position, bar.position + Vector2(bar.size.x, 0.0),
			VisualColor.stroke(frame_color.lightened(0.45), 0.45 + 0.35 * glint), hairline, true)
		draw_line(bar.end - Vector2(bar.size.x, 0.0), bar.end,
			VisualColor.stroke(frame_color.darkened(0.4), 0.45), hairline, true)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x - post, rect.position.y),
			Vector2(rect.position.x, rect.end.y - post), rect.end - Vector2(post, post)]:
		draw_rect(Rect2(corner, Vector2(post, post)), VisualColor.stroke(frame_color.lightened(0.15), 0.55))
	# A soft cast shadow keeps the frame from looking pasted flat on the chat.
	var shadow := Rect2(Vector2(rect.position.x + post, rect.end.y + post * 0.4),
		Vector2(rect.size.x - post * 2.0, post * 1.4))
	draw_rect(shadow.grow(post * 0.5), VisualColor.stroke(frame_color.darkened(0.75), 0.05 / VisualColor.ink_alpha()))
	draw_rect(shadow, VisualColor.stroke(frame_color.darkened(0.75), 0.09 / VisualColor.ink_alpha()))
	var inner := Rect2(rect.position + Vector2(rail, rail), rect.size - Vector2(rail, rail) * 2.0)
	draw_rect(inner, VisualColor.stroke(frame_color, 0.14), false, hairline)
	var beam := Rect2(Vector2(inner.position.x, beam_top()), Vector2(inner.size.x, beam_bottom() - beam_top()))
	draw_rect(beam, VisualColor.stroke(frame_color, 0.26))
	draw_line(Vector2(beam.position.x, beam_top()), Vector2(beam.end.x, beam_top()),
		VisualColor.stroke(frame_color.lightened(0.5), 0.58 + 0.3 * glint), maxf(1.0, hairline * 2.4), true)
	draw_line(Vector2(beam.position.x, beam_bottom()), Vector2(beam.end.x, beam_bottom()),
		VisualColor.stroke(frame_color.darkened(0.45), 0.5), maxf(1.0, hairline * 1.6), true)
	# Brass pins where each rod meets the rails.
	var pin := maxf(1.2, bead_radius() * 0.1)
	for index in range(RODS):
		var x := rod_x(index)
		draw_circle(Vector2(x, inner.position.y + rail * 0.4), pin, VisualColor.stroke(frame_color.lightened(0.55), 0.55))
		draw_circle(Vector2(x, inner.end.y - rail * 0.4), pin, VisualColor.stroke(frame_color.lightened(0.55), 0.55))
	pass


func draw_rod(index: int, rod: Rod) -> void:
	var rect := frame_rect()
	var rail := maxf(2.0, rect.size.y * 0.016)
	var radius := bead_radius()
	var x := rod_x(index) + sin(clock * 42.0) * rod.shake * radius * 0.25
	var top := rect.position.y + rail
	var bottom := rect.end.y - rail
	draw_line(Vector2(x, top), Vector2(x, bottom), VisualColor.stroke(rod_color, 0.24), maxf(1.0, radius * 0.14), true)
	draw_line(Vector2(x, top), Vector2(x, bottom), VisualColor.stroke(rod_color.lightened(0.5), 0.16), maxf(1.0, radius * 0.05), true)
	if index == active_rod:
		var pulse := 0.45 + 0.35 * sin(clock * 8.0)
		var bracket := radius * 1.5
		var top_y := beam_top() - bracket * 1.6
		var bottom_y := beam_bottom() + bracket * 1.6
		var color := VisualColor.stroke(accent_color, 0.55 * pulse)
		draw_line(Vector2(x - bracket, top_y), Vector2(x - bracket, top_y + bracket * 0.6), color, maxf(1.0, radius * 0.12), true)
		draw_line(Vector2(x - bracket, top_y), Vector2(x - bracket * 0.3, top_y), color, maxf(1.0, radius * 0.12), true)
		draw_line(Vector2(x + bracket, bottom_y), Vector2(x + bracket, bottom_y - bracket * 0.6), color, maxf(1.0, radius * 0.12), true)
		draw_line(Vector2(x + bracket, bottom_y), Vector2(x + bracket * 0.3, bottom_y), color, maxf(1.0, radius * 0.12), true)
	draw_active_glow(x, rod, radius)
	draw_upper_beads(x, rod, radius)
	draw_lower_beads(x, rod, radius)
	draw_ghost_beads(x, index, radius)
	pass


## One soft column of light behind the beads that left their rest stack, so the moved beads read
## as a single cluster instead of a pile of glowing dots.
func draw_active_glow(x: float, rod: Rod, radius: float) -> void:
	var half := radius * 1.5
	if rod.lower_pos > 0.05:
		var height := rod.lower_pos * radius * BEAD_GAP + radius * 0.6
		draw_rect(Rect2(Vector2(x - half, beam_bottom()), Vector2(half * 2.0, height)), VisualColor.stroke(accent_color, 0.045))
	if rod.upper_pos > 0.05:
		var height := rod.upper_pos * radius * BEAD_GAP + radius * 0.6
		draw_rect(Rect2(Vector2(x - half, beam_top() - height), Vector2(half * 2.0, height)), VisualColor.stroke(accent_color, 0.045))
	pass


func draw_upper_beads(x: float, rod: Rod, radius: float) -> void:
	# The bead resting closest to the beam travels first, so the upper deck fills from below.
	for index in range(UPPER_BEADS):
		var slide := clampf(rod.upper_pos - float(UPPER_BEADS - 1 - index), 0.0, 1.0)
		draw_sliding_bead(Vector2(x, lerpf(upper_rest_y(index), upper_active_y(index), slide)), radius, slide, rod)
	pass


func draw_lower_beads(x: float, rod: Rod, radius: float) -> void:
	for index in range(LOWER_BEADS):
		var slide := clampf(rod.lower_pos - float(index), 0.0, 1.0)
		draw_sliding_bead(Vector2(x, lerpf(lower_rest_y(index), lower_active_y(index), slide)), radius, slide, rod)
	pass


## A bead that travelled to the beam is the bead that counts, so it burns brighter.
func draw_sliding_bead(center: Vector2, radius: float, slide: float, rod: Rod) -> void:
	var heat := 0.5 + 0.5 * rod.flash
	var color := bead_color if rod.shake <= 0.0 else bead_color.lerp(error_color, rod.shake)
	var alpha := 0.34 + 0.22 * heat + 0.22 * slide
	if slide > 0.05:
		draw_circle(center, radius * 1.7, VisualColor.stroke(accent_color, 0.06 * slide))
	draw_bead(center, radius, color, alpha)
	pass


## Reasoning previews the next flicks as hollow ghost beads until a turn or tool commits them.
func draw_ghost_beads(x: float, index: int, radius: float) -> void:
	if preview_value <= value or clearing:
		return
	var ghost := digits_of(preview_value, rods.size())
	var committed := digits_of(value, rods.size())
	var target := bead_targets(ghost[index])
	var current := bead_targets(committed[index])
	var pulse := 0.4 + 0.35 * sin(clock * 6.0)
	if target.x > current.x:
		draw_ghost(Vector2(x, upper_active_y(UPPER_BEADS - 1 - current.x)), radius, pulse)
	if target.y > current.y:
		draw_ghost(Vector2(x, lower_active_y(current.y)), radius, pulse)
	pass


func draw_ghost(center: Vector2, radius: float, alpha: float) -> void:
	draw_arc(center, radius * 1.28, 0.0, TAU, 18, VisualColor.stroke(accent_color, 0.5 * alpha), maxf(1.0, radius * 0.14), true)
	draw_circle(center, radius * 0.2, VisualColor.stroke(accent_color, 0.34 * alpha))
	pass


## A carry throws a pulse of light along the beam into the next rod.
func draw_carries() -> void:
	var beam_middle := (beam_top() + beam_bottom()) * 0.5
	for carry: Carry in carries:
		var t := clampf(carry.age / CARRY_SECONDS, 0.0, 1.0)
		var from := Vector2(rod_x(carry.from_rod), beam_middle)
		var to := Vector2(rod_x(carry.to_rod), beam_middle)
		var head := from.lerp(to, clampf(t * 1.5, 0.0, 1.0))
		var tail := from.lerp(to, clampf(t * 1.5 - 0.45, 0.0, 1.0))
		var fade := 1.0 - t
		var width := maxf(1.0, bead_radius() * 0.5)
		draw_line(tail, head, VisualColor.stroke(accent_color, 0.5 * fade), width, true)
		draw_circle(head, bead_radius() * 0.42, VisualColor.stroke(accent_color.lightened(0.5), 0.75 * fade))
	pass


func draw_clacks() -> void:
	for clack: Clack in clacks:
		var t := clampf(clack.age / CLACK_SECONDS, 0.0, 1.0)
		var radius := bead_radius()
		var x := rod_x(clack.rod)
		var y := beam_top() - radius if clack.upper else beam_bottom() + radius
		draw_arc(Vector2(x, y), radius * (0.7 + 1.5 * t), 0.0, TAU, 20, VisualColor.stroke(accent_color, 0.42 * (1.0 - t)),
			maxf(1.0, radius * 0.12), true)
	pass


## A suanpan bead: lacquered lens with a dark rim, a specular cap and a drilled hole.
func draw_bead(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var shape := PackedVector2Array()
	var body := PackedVector2Array()
	var gloss := PackedVector2Array()
	for index in range(20):
		var heading := TAU * float(index) / 20.0
		shape.append(center + Vector2(cos(heading) * radius * 1.34, sin(heading) * radius * 0.74))
		body.append(center + Vector2(cos(heading) * radius * 1.22, sin(heading) * radius * 0.63))
	for index in range(16):
		var heading := TAU * float(index) / 16.0
		gloss.append(center + Vector2(0.0, -radius * 0.24) + Vector2(cos(heading) * radius * 0.82, sin(heading) * radius * 0.26))
	draw_colored_polygon(shape, VisualColor.stroke(color.darkened(0.5), alpha))
	draw_colored_polygon(body, VisualColor.stroke(color, alpha))
	draw_colored_polygon(gloss, VisualColor.stroke(color.lightened(0.55), alpha * 0.45))
	draw_circle(center, radius * 0.2, VisualColor.stroke(bead_core, minf(alpha * 2.0, 0.95)))
	pass


## A cinnabar maker's seal on the frame corner, the one mark that says this is a suanpan.
func draw_seal() -> void:
	var rect := frame_rect()
	var radius := bead_radius()
	var size := radius * 2.7
	var center := Vector2(rect.position.x - size * 0.15, rect.position.y + size * 0.25)
	var points := PackedVector2Array()
	for index in range(4):
		var heading := -0.07 + TAU * float(index) / 4.0 + PI * 0.25
		points.append(center + Vector2.from_angle(heading) * size * 0.66)
	draw_colored_polygon(points, VisualColor.stroke(seal_color, 0.4 / VisualColor.ink_alpha()))
	points.append(points[0])
	draw_polyline(points, VisualColor.stroke(seal_color, 0.72), maxf(1.0, radius * 0.1), true)
	var glyph_size := int(size * 0.74)
	draw_centered_text(center + Vector2(0.0, glyph_size * 0.36), "算", Fonts.bold(), glyph_size,
		VisualColor.stroke(paper_color, 0.88))
	pass


## The count rides on a riveted plate above the frame, like a maker's tag on the instrument.
func draw_value() -> void:
	var rect := frame_rect()
	var size := clampi(int(bead_radius() * 0.95), Typography.label_medium_size, Typography.headline_small_size)
	var text := str(value)
	var font := Fonts.bold()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var plate_width := maxf(text_width + bead_radius() * 3.4, rect.size.x * 0.12)
	var plate_height := size * 1.95
	var plate := Rect2(Vector2(rect.position.x + rect.size.x * 0.5 - plate_width * 0.5,
		rect.position.y - plate_height - bead_radius() * 0.5), Vector2(plate_width, plate_height))
	draw_rect(plate, VisualColor.stroke(frame_color, 0.16 / VisualColor.ink_alpha()))
	draw_rect(plate, VisualColor.stroke(frame_color.lightened(0.4), 0.42), false, maxf(1.0, bead_radius() * 0.06))
	var rivet := maxf(1.0, bead_radius() * 0.08)
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(plate.get_center().x + side * (plate_width * 0.5 - plate_height * 0.3), plate.get_center().y), rivet,
			VisualColor.stroke(frame_color.lightened(0.55), 0.5))
	draw_centered_text(Vector2(plate.get_center().x, plate.get_center().y + size * 0.37), text, font, size,
		VisualColor.stroke(accent_color, 0.88))
	if preview_value <= value or clearing:
		return
	var ghost := StringUtils.format(I18n.t("agent.visuals.abacus_preview"), preview_value - value)
	draw_centered_text(Vector2(plate.get_center().x, plate.position.y - size * 0.5), ghost, Fonts.regular(), size - 2,
		VisualColor.stroke(accent_color, 0.42))
	pass
