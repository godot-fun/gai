class_name GoBoard
extends VisualEffect

## 围棋 (Go): the run becomes a game on a faint goban laid over the interface. Every streamed
## reasoning chunk tries a shadow stone where the search is looking, and a streamed answer promotes
## the oldest shadow into a real stone with a click. Each tool call opens a local fight: success
## captures the neighbouring group (the tool wins the fight), failure loses the local stones to a
## white counter-capture and leaves a dead-move mark. Turns alternate hands. The run ends with
## scoring: empty regions flood-fill into outlined territory that adds up with the stones, the
## token usage becomes white's komi, and a run that ended badly loses its last move to an error
## ring, so a run always ends on a visible final score.

enum Stone { BLACK, WHITE }

const BOARD_SIZE := 19
const BOARD_HEIGHT_RATIO := 0.74
const BOARD_WIDTH_RATIO := 0.52
const BOARD_DROP_RATIO := 0.04
const GRID_ALPHA := 0.16
const INNER_GRID_ALPHA := 0.085
const STONE_ALPHA := 0.74
const WHITE_STONE_ALPHA := 0.42
const MAX_CANDIDATES := 12
const CANDIDATE_LIFE := 1.5
const CANDIDATE_COST := 0.05
const MOVE_COST := 0.16
const GROW_SECONDS := 0.16
const CAPTURE_FADE_SECONDS := 0.5
const FLASH_SECONDS := 0.6
const MARK_LIFE := 2.4
const KOMI_PER_TOKEN := 0.002
const MAX_KOMI := 20.0
const SCORE_SECONDS := 1.5
const SCORE_LINE_GAP := 18.0
const NEIGHBOR_STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Star points of a 19 x 19 board.
const STAR_POINTS: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(9, 3), Vector2i(15, 3),
	Vector2i(3, 9), Vector2i(9, 9), Vector2i(15, 9),
	Vector2i(3, 15), Vector2i(9, 15), Vector2i(15, 15),
]


class Cell extends RefCounted:
	var side: int = Stone.BLACK
	var grow: float = 0.0


class Shadow extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var age: float = 0.0


class FadingStone extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var side: int = Stone.BLACK
	var age: float = 0.0


class Mark extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var age: float = 0.0


class Flash extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var color: Color = Color.WHITE
	var scale: float = 1.0
	var age: float = 0.0


class TerritoryRegion extends RefCounted:
	var cells: Array[Vector2i] = []
	var owner: int = Stone.BLACK
	var center: Vector2i = Vector2i.ZERO


var stones: Dictionary[Vector2i, Cell] = {}
var shadows: Array[Shadow] = []
var fading: Array[FadingStone] = []
var marks: Array[Mark] = []
var flashes: Array[Flash] = []
## tool_call_id -> representative stone of the group the tool is fighting.
var fights: Dictionary[String, Vector2i] = {}
## Cell -> true while a tool fight is highlighting the group's liberties.
var liberties: Dictionary[Vector2i, bool] = {}
var territory: Dictionary[Vector2i, int] = {}
var regions: Array[TerritoryRegion] = []
var hand: int = Stone.BLACK
var move_number: int = 0
var captures: PackedInt32Array = PackedInt32Array([0, 0])
var last_move: Vector2i = Vector2i(-1, -1)
var content_charge: float = 0.0
var reasoning_charge: float = 0.0
var komi: float = 0.0
var black_score: int = 0
var white_score: float = 0.0
var scoring: bool = false
var score_reveal: float = 0.0
var turn_index: int = 0
var clock: float = 0.0
var light_theme: bool = false
var black_fill: Color = Color(0.07, 0.09, 0.13)
var black_rim: Color = Color(0.55, 0.62, 0.75)
var white_fill: Color = Color(0.95, 0.96, 0.99)
var white_rim: Color = Color(0.98, 0.99, 1.0)
var grid_color: Color = Color(0.6, 0.8, 1.0)
var accent_color: Color = Color(0.55, 0.75, 1.0)
var error_color: Color = Color(1.0, 0.35, 0.35)
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	gdf.events.theme_changed.connect(sync_palette)
	gdf.events.theme_color_changed.connect(sync_palette)
	sync_palette()
	pass


func fade_out_seconds() -> float:
	return 0.45


func on_agent_start(_session_id: int) -> void:
	stones.clear()
	shadows.clear()
	fading.clear()
	marks.clear()
	flashes.clear()
	fights.clear()
	liberties.clear()
	territory.clear()
	regions.clear()
	hand = Stone.BLACK
	move_number = 0
	captures = PackedInt32Array([0, 0])
	last_move = Vector2i(-1, -1)
	content_charge = 0.0
	reasoning_charge = 0.0
	komi = 0.0
	black_score = 0
	white_score = 0.0
	scoring = false
	score_reveal = 0.0
	turn_index = 0
	clock = 0.0
	sync_palette()
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	if StringUtils.is_not_blank(error_message) and in_bounds(last_move):
		# A run that ended badly loses its last move: an error ring and a dead-move mark.
		add_flash(last_move, Colors.error, 1.3)
		var mark := Mark.new()
		mark.cell = last_move
		marks.append(mark)
	start_scoring()
	if not is_inside_tree():
		score_reveal = 1.0
		return
	await get_tree().create_timer(SCORE_SECONDS).timeout
	pass


func on_turn_start(_session_id: int) -> void:
	# A new turn swaps hands and clears the shadows the previous answer left behind.
	hand = Stone.BLACK if turn_index % 2 == 0 else Stone.WHITE
	turn_index += 1
	shadows.clear()
	pass


func on_turn_end(_session_id: int) -> void:
	shadows.clear()
	content_charge = 0.0
	reasoning_charge = 0.0
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty() or scoring:
		return
	var energy := SimulationEffect.stream_energy_for_length(chunk.length())
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		reasoning_charge += energy * 1.4
		while reasoning_charge >= CANDIDATE_COST:
			reasoning_charge -= CANDIDATE_COST
			add_shadow()
		return
	content_charge += energy * 2.0
	while content_charge >= MOVE_COST:
		content_charge -= MOVE_COST
		play_move()
	pass


func on_message_complete(_session_id: int, usage: OpenAiUsage) -> void:
	if usage == null:
		return
	komi = minf(komi + float(maxi(usage.total_tokens, 0)) * KOMI_PER_TOKEN, MAX_KOMI)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	if scoring:
		return
	var cell := pick_fight_cell()
	if not in_bounds(cell):
		return
	fights[tool_call_id] = cell
	liberties.clear()
	for liberty: Vector2i in liberties_of(group_cells(cell)):
		liberties[liberty] = true
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	liberties.clear()
	if not fights.has(tool_call_id):
		return
	var cell: Vector2i = fights[tool_call_id]
	fights.erase(tool_call_id)
	if not stones.has(cell) or scoring:
		return
	if result.is_error:
		lose_fight(cell)
		return
	win_fight(cell)
	pass


## The tool wins the local fight: enemy groups without liberties come off the board.
func win_fight(cell: Vector2i) -> void:
	var side := stones[cell].side
	var captured := capture_adjacent_enemy(cell, side)
	captures[side] += captured
	add_flash(cell, accent_color, 1.0 + 0.22 * float(captured))
	pass


## The tool failed: the white counter-capture takes our local stones and answers on the spot.
func lose_fight(cell: Vector2i) -> void:
	var lost := capture_group(cell)
	var mark := Mark.new()
	mark.cell = cell
	marks.append(mark)
	if lost > 0:
		captures[Stone.WHITE] += lost
		add_flash(cell, error_color, 1.0 + 0.2 * float(lost))
	else:
		add_flash(cell, error_color, 1.0)
	if not stones.has(cell):
		place_stone(cell, Stone.WHITE, false)
	pass


func step_board(delta: float) -> void:
	clock += delta
	for stone_cell: Cell in stones.values():
		stone_cell.grow = minf(stone_cell.grow + delta / GROW_SECONDS, 1.0)
	for index in range(shadows.size() - 1, -1, -1):
		shadows[index].age += delta
		if shadows[index].age >= CANDIDATE_LIFE:
			shadows.remove_at(index)
	for index in range(fading.size() - 1, -1, -1):
		fading[index].age += delta
		if fading[index].age >= CAPTURE_FADE_SECONDS:
			fading.remove_at(index)
	for index in range(marks.size() - 1, -1, -1):
		marks[index].age += delta
		if marks[index].age >= MARK_LIFE:
			marks.remove_at(index)
	for index in range(flashes.size() - 1, -1, -1):
		flashes[index].age += delta
		if flashes[index].age >= FLASH_SECONDS:
			flashes.remove_at(index)
	if scoring:
		score_reveal = minf(score_reveal + delta / SCORE_SECONDS, 1.0)
	pass


## Moves a shadow stone; shadows are pure reading, so they never capture anything.
func add_shadow() -> void:
	if shadows.size() >= MAX_CANDIDATES:
		shadows.remove_at(0)
	var cell := pick_move_cell()
	if not in_bounds(cell):
		return
	var shadow := Shadow.new()
	shadow.cell = cell
	shadows.append(shadow)
	pass


## Plays the oldest shadow when one exists, so the answer visibly settles a reading branch.
func play_move() -> void:
	var cell := pick_move_cell()
	if not in_bounds(cell):
		return
	if not shadows.is_empty():
		var shadow: Shadow = shadows.pop_front()
		if can_place(shadow.cell):
			cell = shadow.cell
	place_stone(cell, hand, true)
	pass


func place_stone(cell: Vector2i, side: int, counts_as_move: bool) -> bool:
	if not can_place(cell):
		return false
	var stone_cell := Cell.new()
	stone_cell.side = side
	stones[cell] = stone_cell
	if counts_as_move:
		move_number += 1
		last_move = cell
	return true


func can_place(cell: Vector2i) -> bool:
	return in_bounds(cell) and not stones.has(cell) and not shadowed(cell)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE and cell.y < BOARD_SIZE


func shadowed(cell: Vector2i) -> bool:
	for shadow: Shadow in shadows:
		if shadow.cell == cell:
			return true
	return false


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if cell.x > 0:
		result.append(Vector2i(cell.x - 1, cell.y))
	if cell.x < BOARD_SIZE - 1:
		result.append(Vector2i(cell.x + 1, cell.y))
	if cell.y > 0:
		result.append(Vector2i(cell.x, cell.y - 1))
	if cell.y < BOARD_SIZE - 1:
		result.append(Vector2i(cell.x, cell.y + 1))
	return result


func group_cells(start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not stones.has(start):
		return result
	var side := stones[start].side
	var stack: Array[Vector2i] = [start]
	var seen: Dictionary[Vector2i, bool] = {start: true}
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		result.append(cell)
		for next_cell: Vector2i in neighbors(cell):
			if seen.has(next_cell) or not stones.has(next_cell):
				continue
			if stones[next_cell].side != side:
				continue
			seen[next_cell] = true
			stack.append(next_cell)
	return result


func liberties_of(group: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in group:
		for next_cell: Vector2i in neighbors(cell):
			if stones.has(next_cell) or seen.has(next_cell):
				continue
			seen[next_cell] = true
			result.append(next_cell)
	return result


## Removes a group from the board and returns how many stones came off.
func capture_group(cell: Vector2i) -> int:
	var group := group_cells(cell)
	if group.is_empty():
		return 0
	var side := stones[cell].side
	for member: Vector2i in group:
		stones.erase(member)
		var fading_stone := FadingStone.new()
		fading_stone.cell = member
		fading_stone.side = side
		fading.append(fading_stone)
	return group.size()


## Captures every adjacent enemy group that lost its last liberty.
func capture_adjacent_enemy(cell: Vector2i, side: int) -> int:
	var captured := 0
	for next_cell: Vector2i in neighbors(cell):
		if not stones.has(next_cell) or stones[next_cell].side == side:
			continue
		if liberties_of(group_cells(next_cell)).is_empty():
			captured += capture_group(next_cell)
	return captured


## Picks, for a tool fight, our group with the fewest liberties that touches an enemy stone.
func pick_fight_cell() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_liberties := BOARD_SIZE * BOARD_SIZE
	for cell: Vector2i in stones.keys():
		if stones[cell].side != hand:
			continue
		var touching_enemy := false
		for next_cell: Vector2i in neighbors(cell):
			if stones.has(next_cell) and stones[next_cell].side != hand:
				touching_enemy = true
				break
		if not touching_enemy:
			continue
		var count := liberties_of(group_cells(cell)).size()
		if count < best_liberties:
			best_liberties = count
			best = cell
	if in_bounds(best):
		return best
	return pick_move_cell()


## Picks an empty intersection near the last move, occasionally somewhere else on the board.
func pick_move_cell() -> Vector2i:
	var anchor := last_move
	if anchor.x < 0 or anchor.y < 0 or rng.randf() < 0.3:
		anchor = Vector2i(rng.randi_range(0, BOARD_SIZE - 1), rng.randi_range(0, BOARD_SIZE - 1))
	for radius in range(BOARD_SIZE):
		var options: Array[Vector2i] = []
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell := anchor + Vector2i(dx, dy)
				if can_place(cell):
					options.append(cell)
		if not options.is_empty():
			return options[rng.randi_range(0, options.size() - 1)]
	return Vector2i(-1, -1)


## Empty regions that touch a single color become that color's territory.
func compute_territory() -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	var visited: Dictionary[Vector2i, bool] = {}
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var start := Vector2i(x, y)
			if stones.has(start) or visited.has(start):
				continue
			visited[start] = true
			var region: Array[Vector2i] = [start]
			var border_black := false
			var border_white := false
			var cursor := 0
			while cursor < region.size():
				var cell: Vector2i = region[cursor]
				cursor += 1
				for next_cell: Vector2i in neighbors(cell):
					if stones.has(next_cell):
						if stones[next_cell].side == Stone.BLACK:
							border_black = true
						else:
							border_white = true
						continue
					if visited.has(next_cell):
						continue
					visited[next_cell] = true
					region.append(next_cell)
			if border_black == border_white:
				continue
			var owner := Stone.BLACK if border_black else Stone.WHITE
			for member: Vector2i in region:
				result[member] = owner
	return result


func count_side(side: int) -> int:
	var total := 0
	for cell: Cell in stones.values():
		if cell.side == side:
			total += 1
	return total


## Groups the scored empty points into connected regions so the end screen can outline them
## instead of stippling hundreds of loose dots.
func build_territory_regions() -> Array[TerritoryRegion]:
	var result: Array[TerritoryRegion] = []
	var visited: Dictionary[Vector2i, bool] = {}
	var keys: Array[Vector2i] = []
	for cell: Vector2i in territory.keys():
		keys.append(cell)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for start: Vector2i in keys:
		if visited.has(start):
			continue
		var region := TerritoryRegion.new()
		region.owner = territory[start]
		var cursor := 0
		visited[start] = true
		region.cells.append(start)
		var sum := Vector2i.ZERO
		while cursor < region.cells.size():
			var cell: Vector2i = region.cells[cursor]
			cursor += 1
			sum += cell
			for next_cell: Vector2i in neighbors(cell):
				if visited.has(next_cell) or not territory.has(next_cell):
					continue
				if territory[next_cell] != region.owner:
					continue
				visited[next_cell] = true
				region.cells.append(next_cell)
		var cell_count := float(maxi(region.cells.size(), 1))
		region.center = Vector2i(int(float(sum.x) / cell_count), int(float(sum.y) / cell_count))
		result.append(region)
	result.sort_custom(func(a: TerritoryRegion, b: TerritoryRegion) -> bool: return a.cells.size() > b.cells.size())
	return result


func start_scoring() -> void:
	if scoring:
		return
	scoring = true
	score_reveal = 0.0
	liberties.clear()
	territory = compute_territory()
	regions = build_territory_regions()
	black_score = count_side(Stone.BLACK)
	white_score = float(count_side(Stone.WHITE)) + komi
	for owner: int in territory.values():
		if owner == Stone.BLACK:
			black_score += 1
		else:
			white_score += 1.0
	pass


func add_flash(cell: Vector2i, color: Color, scale: float) -> void:
	var flash := Flash.new()
	flash.cell = cell
	flash.color = color
	flash.scale = scale
	flashes.append(flash)
	pass


func sync_palette() -> void:
	var dark := ThemeColor.is_dark_theme()
	var accent := ThemeColor.accent_theme_color()
	accent_color = VisualColor.appearance_color(accent, 0.0, 0.8)
	grid_color = VisualColor.appearance_color(accent, 0.5, 0.55)
	error_color = Colors.error
	light_theme = not dark
	if dark:
		black_fill = Color(0.03, 0.04, 0.06)
		black_rim = Color(0.7, 0.78, 0.92)
		white_fill = Color(0.96, 0.97, 1.0)
		white_rim = Color(1.0, 1.0, 1.0)
		return
	black_fill = Color(0.12, 0.13, 0.18)
	black_rim = Color(0.34, 0.38, 0.46)
	white_fill = Color(0.84, 0.85, 0.85)
	white_rim = Color(0.28, 0.31, 0.38)
	pass


func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(1280.0, 720.0)


func board_rect() -> Rect2:
	var view := view_size()
	var side := minf(view.y * BOARD_HEIGHT_RATIO, view.x * BOARD_WIDTH_RATIO)
	var origin := Vector2((view.x - side) * 0.5, (view.y - side) * 0.5 + view.y * BOARD_DROP_RATIO)
	return Rect2(origin, Vector2(side, side))


func board_spacing() -> float:
	return board_rect().size.x / float(BOARD_SIZE + 1)


func cell_center(cell: Vector2i) -> Vector2:
	var rect := board_rect()
	var spacing := rect.size.x / float(BOARD_SIZE + 1)
	return rect.position + Vector2.ONE * spacing + Vector2(cell) * spacing


func stone_radius() -> float:
	return board_spacing() * 0.46


func _process(delta: float) -> void:
	if not visible:
		return
	step_board(minf(delta, 1.0 / 20.0))
	queue_redraw()
	pass


func _draw() -> void:
	var rect := board_rect()
	if rect.size.x < 1.0:
		return
	draw_grid(rect)
	draw_shadows()
	for cell: Vector2i in stones.keys():
		draw_stone(cell_center(cell), stones[cell].side, stones[cell].grow, 1.0)
	for stone: FadingStone in fading:
		var fade := 1.0 - stone.age / CAPTURE_FADE_SECONDS
		draw_stone(cell_center(stone.cell), stone.side, fade, fade)
	draw_last_move()
	for mark: Mark in marks:
		draw_mark(mark)
	for flash: Flash in flashes:
		draw_flash(flash)
	draw_liberties()
	draw_territory()
	draw_hud(rect)
	pass


func draw_grid(rect: Rect2) -> void:
	var spacing := rect.size.x / float(BOARD_SIZE + 1)
	var origin := rect.position + Vector2.ONE * spacing
	var span := spacing * float(BOARD_SIZE - 1)
	for index in range(BOARD_SIZE):
		var offset := spacing * float(index)
		var edge := index == 0 or index == BOARD_SIZE - 1
		var color := VisualColor.stroke(grid_color, GRID_ALPHA if edge else INNER_GRID_ALPHA)
		draw_line(origin + Vector2(0.0, offset), origin + Vector2(span, offset), color, 1.0, true)
		draw_line(origin + Vector2(offset, 0.0), origin + Vector2(offset, span), color, 1.0, true)
	for star: Vector2i in STAR_POINTS:
		draw_circle(cell_center(star), maxf(1.3, spacing * 0.085), VisualColor.stroke(grid_color, 0.28))
	pass


func draw_shadows() -> void:
	var radius := stone_radius()
	for shadow: Shadow in shadows:
		var age_ratio := shadow.age / CANDIDATE_LIFE
		var pulse := 0.55 + 0.45 * sin(shadow.age * 6.0)
		var alpha := (1.0 - age_ratio) * pulse
		var center := cell_center(shadow.cell)
		draw_circle(center, radius * 0.82, VisualColor.stroke(accent_color, 0.1 * alpha))
		draw_arc(center, radius, 0.0, TAU, 22, VisualColor.stroke(accent_color, 0.5 * alpha), 1.2, true)
		draw_circle(center, maxf(0.8, radius * 0.12), VisualColor.stroke(accent_color, 0.62 * alpha))
	pass


func draw_stone(center: Vector2, side: int, grow: float, fade: float) -> void:
	var radius := stone_radius() * (0.72 + 0.28 * clampf(grow, 0.0, 1.0))
	var alpha := clampf(grow, 0.0, 1.0) * fade
	if alpha <= 0.01:
		return
	var fill := black_fill if side == Stone.BLACK else white_fill
	var rim := black_rim if side == Stone.BLACK else white_rim
	var fill_alpha := STONE_ALPHA if side == Stone.BLACK else WHITE_STONE_ALPHA
	draw_circle(center, radius * 1.25, VisualColor.stroke(rim, 0.06 * alpha))
	draw_circle(center, radius, VisualColor.stroke(fill, fill_alpha * alpha))
	draw_arc(center, radius - 0.5, 0.0, TAU, 22, VisualColor.stroke(rim, 0.72 * alpha), 1.5, true)
	if side == Stone.BLACK:
		draw_arc(center, radius * 0.66, PI * 1.1, PI * 1.7, 10, VisualColor.stroke(rim, 0.4 * alpha), 1.2, true)
	else:
		draw_arc(center, radius * 0.62, 0.0, TAU, 16, VisualColor.stroke(rim, 0.22 * alpha), 1.0, true)
	pass


## A small dot marks the newest stone so the eye can follow the game.
func draw_last_move() -> void:
	if scoring or not stones.has(last_move):
		return
	var stone_cell: Cell = stones[last_move]
	var color := black_rim if stone_cell.side == Stone.BLACK else black_fill
	draw_circle(cell_center(last_move), maxf(1.2, stone_radius() * 0.16), VisualColor.stroke(color, 0.9))
	pass


func draw_mark(mark: Mark) -> void:
	var fade := 1.0 - mark.age / MARK_LIFE
	var center := cell_center(mark.cell)
	var reach := stone_radius() * 0.9
	var color := VisualColor.stroke(error_color, 0.8 * fade)
	draw_line(center + Vector2(-reach, -reach), center + Vector2(reach, reach), color, 1.7, true)
	draw_line(center + Vector2(reach, -reach), center + Vector2(-reach, reach), color, 1.7, true)
	pass


func draw_flash(flash: Flash) -> void:
	var fade := 1.0 - flash.age / FLASH_SECONDS
	var center := cell_center(flash.cell)
	var base := stone_radius() * (1.4 + 1.6 * fade) * flash.scale
	draw_circle(center, base, VisualColor.stroke(flash.color, 0.07 * fade))
	draw_arc(center, base, 0.0, TAU, 26, VisualColor.stroke(flash.color, 0.5 * fade), 1.6, true)
	draw_arc(center, base * 0.6, 0.0, TAU, 22, VisualColor.stroke(flash.color, 0.26 * fade), 1.0, true)
	pass


func draw_liberties() -> void:
	var pulse := 0.5 + 0.5 * sin(clock * 7.0)
	var half := maxf(1.6, stone_radius() * 0.3)
	for cell: Vector2i in liberties.keys():
		var center := cell_center(cell)
		var points := PackedVector2Array([
			center + Vector2(-half, -half),
			center + Vector2(half, -half),
			center + Vector2(half, half),
			center + Vector2(-half, half),
			center + Vector2(-half, -half),
		])
		draw_polyline(points, VisualColor.stroke(accent_color, 0.35 + 0.45 * pulse), 1.2, true)
	pass


func draw_territory() -> void:
	if not scoring or regions.is_empty():
		return
	var half := board_spacing() * 0.46
	var line_half := board_spacing() * 0.5
	var count := float(regions.size())
	for index in range(regions.size()):
		var region: TerritoryRegion = regions[index]
		var delay := 0.55 * float(index) / count
		var local := clampf((score_reveal - delay) / 0.25, 0.0, 1.0)
		if local <= 0.0:
			continue
		var color := black_rim if region.owner == Stone.BLACK else white_rim
		# Territory tint stays pale on white so the scored board never becomes a solid wash.
		var fill_alpha := 0.05 if light_theme else 0.11
		var edge_alpha := 0.34 if light_theme else 0.5
		for cell: Vector2i in region.cells:
			var center := cell_center(cell)
			draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), VisualColor.stroke(color, fill_alpha * local))
			for step: Vector2i in NEIGHBOR_STEPS:
				if territory.get(cell + step, -1) == region.owner:
					continue
				var normal := Vector2(step) * line_half
				var tangent := Vector2(step).orthogonal() * line_half
				draw_line(center + normal - tangent, center + normal + tangent,
					VisualColor.stroke(color, edge_alpha * local), maxf(1.0, half * 0.16), true)
		if region.cells.size() >= 4:
			var label := str(region.cells.size())
			draw_centered_text(cell_center(region.center), label, Fonts.medium(), Typography.label_small_size,
				VisualColor.stroke(color, 0.62 * local))
	pass


func draw_hud(rect: Rect2) -> void:
	var font := Fonts.medium()
	var font_size := Typography.label_large_size
	var baseline := rect.position.y + rect.size.y + SCORE_LINE_GAP
	var center_x := rect.position.x + rect.size.x * 0.5
	if scoring:
		var black_text := StringUtils.format(I18n.t("agent.visuals.go_black"), black_score)
		var white_text := StringUtils.format(I18n.t("agent.visuals.go_white"), snappedf(white_score, 0.5))
		draw_centered_text(Vector2(center_x, baseline), "%s   %s" % [black_text, white_text], font, font_size,
			VisualColor.stroke(accent_color, 0.72))
		var komi_text := StringUtils.format(I18n.t("agent.visuals.go_komi"), snappedf(komi, 0.1))
		draw_centered_text(Vector2(center_x, baseline + SCORE_LINE_GAP), komi_text, Fonts.regular(), font_size - 1,
			VisualColor.stroke(accent_color, 0.42))
		return
	var move_text := StringUtils.format(I18n.t("agent.visuals.go_move"), move_number)
	var capture_text := StringUtils.format(I18n.t("agent.visuals.go_captures"), captures[Stone.BLACK], captures[Stone.WHITE])
	draw_centered_text(Vector2(center_x, baseline), "%s   %s" % [move_text, capture_text], font, font_size,
		VisualColor.stroke(accent_color, 0.56))
	pass
