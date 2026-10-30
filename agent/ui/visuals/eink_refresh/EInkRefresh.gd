class_name EInkRefresh
extends VisualEffect

## E-ink refresh (墨水屏刷新): the interface turns into an e-paper panel. Streamed answers update
## line by line through partial refreshes that flash inverted, black, then white before the new
## text settles, while reasoning flickers through fast 1-bit updates. Every partial refresh leaves
## a little ghosting until a full-panel refresh wipes it clean. A running tool holds a pulsing busy
## region at its spot; success clears it, failure leaves stuck pixels behind.

const EINK_SHADER: Shader = preload("res://agent/ui/visuals/eink_refresh/EInkRefresh.gdshader")
const MAX_REFRESHES := 16
const MODE_PARTIAL := 0.0
const MODE_FAST := 1.0
const MODE_BUSY := 2.0
const MODE_STUCK := 3.0
const PARTIAL_SECONDS := 0.55
const FAST_SECONDS := 0.22
const FULL_SECONDS := 0.9
const STUCK_SECONDS := 2.6
const LINE_LEFT := 0.06
const LINE_RIGHT := 0.94
const LINE_TOP := 0.12
const LINE_BOTTOM := 0.9
const LINE_HEIGHT := 0.042
const MIN_STRIP_WIDTH := 0.05
const STRIP_WIDTH_PER_CHAR := 0.0045
const FLUSH_INTERVAL := 0.07
const FAST_INTERVAL := 0.11
const TOOL_SIZE := Vector2(0.2, 0.12)
const GHOST_PER_REFRESH := 0.06
const MAX_GHOST := 0.6
const PRESENCE_PER_SECOND := 4.0
const END_SETTLE_MSEC := 1600


class Refresh extends RefCounted:
	## Screen UV rect.
	var rect: Rect2
	var mode: float = 0.0
	var progress: float = 0.0
	var duration: float = 0.5
	var error: float = 0.0
	var noise_seed: float = 0.0
	var key: String = ""


var screen_rect: ColorRect
var eink_material: ShaderMaterial
var refreshes: Array[Refresh] = []
var full_refresh: Refresh
var presence: float = 0.0
var presence_target: float = 0.0
var ghost: float = 0.0
var caret: Vector2 = Vector2(LINE_LEFT, LINE_TOP)
var pending_width: float = 0.0
var flush_timer: float = 0.0
var fast_timer: float = 0.0
var pending_fast: bool = false
var panel_time: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	screen_rect = ColorRect.new()
	screen_rect.name = "EInkPanel"
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eink_material = ShaderMaterial.new()
	eink_material.shader = EINK_SHADER
	screen_rect.material = eink_material
	add_child(screen_rect)
	update_theme_presentation()
	apply_shader_state()
	pass


func fade_in_seconds() -> float:
	return 0.05


func fade_out_seconds() -> float:
	return 0.35


func on_agent_start(_session_id: int) -> void:
	refreshes.clear()
	presence_target = 1.0
	ghost = 0.0
	caret = Vector2(LINE_LEFT, LINE_TOP)
	pending_width = 0.0
	pending_fast = false
	start_full_refresh(0.0)
	pass


func on_agent_end(_session_id: int, error_message: String) -> void:
	flush_strip()
	start_full_refresh(1.0 if StringUtils.is_not_blank(error_message) else 0.0)
	if not is_inside_tree():
		presence_target = 0.0
		return
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < END_SETTLE_MSEC and full_refresh != null:
		await get_tree().process_frame
	presence_target = 0.0
	pass


func on_turn_start(_session_id: int) -> void:
	add_refresh(Rect2(0.0, 0.0, 1.0, 1.0), MODE_FAST, FAST_SECONDS)
	pass


func on_message_update(_session_id: int, chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		pending_fast = true
		return
	pending_width += maxf(float(chunk.length()) * STRIP_WIDTH_PER_CHAR, 0.004)
	pass


func on_message_complete(_session_id: int, _usage: OpenAiUsage) -> void:
	flush_strip()
	var top := maxf(caret.y - LINE_HEIGHT * 6.0, LINE_TOP)
	add_refresh(Rect2(LINE_LEFT - 0.02, top, LINE_RIGHT - LINE_LEFT + 0.04, caret.y + LINE_HEIGHT - top), MODE_PARTIAL, PARTIAL_SECONDS * 1.3)
	pass


func on_tool_execution_start(_session_id: int, tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	var refresh := add_refresh(tool_rect(tool_name), MODE_BUSY, 1.0)
	refresh.key = tool_call_id
	pass


func on_tool_execution_end(_session_id: int, tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	var refresh := find_refresh(tool_call_id)
	if refresh == null:
		refresh = add_refresh(tool_rect(tool_name), MODE_PARTIAL, PARTIAL_SECONDS)
		refresh.key = tool_call_id
	refresh.progress = 0.0
	refresh.key = ""
	if result.is_error:
		refresh.mode = MODE_STUCK
		refresh.duration = STUCK_SECONDS
		refresh.error = 1.0
	else:
		refresh.mode = MODE_PARTIAL
		refresh.duration = PARTIAL_SECONDS
	pass


static func tool_rect(tool_name: String) -> Rect2:
	var anchor := SimulationEffect.tool_anchor(tool_name)
	return Rect2(anchor - TOOL_SIZE * 0.5, TOOL_SIZE)


## A full-panel refresh flashes the whole screen and wipes the accumulated ghosting.
func start_full_refresh(error: float) -> void:
	full_refresh = Refresh.new()
	full_refresh.rect = Rect2(0.0, 0.0, 1.0, 1.0)
	full_refresh.mode = MODE_PARTIAL
	full_refresh.duration = FULL_SECONDS
	full_refresh.error = error
	full_refresh.noise_seed = rng.randf()
	pass


## Adds a refresh region, dropping the oldest finished-or-not region when every slot is taken.
func add_refresh(rect: Rect2, mode: float, duration: float) -> Refresh:
	if refreshes.size() >= MAX_REFRESHES - 1:
		var drop := 0
		for index in range(refreshes.size()):
			if refreshes[index].mode != MODE_BUSY:
				drop = index
				break
		refreshes.remove_at(drop)
	var refresh := Refresh.new()
	refresh.rect = rect
	refresh.mode = mode
	refresh.duration = duration
	refresh.noise_seed = rng.randf()
	refreshes.append(refresh)
	if mode == MODE_PARTIAL:
		ghost = minf(ghost + GHOST_PER_REFRESH, MAX_GHOST)
	return refresh


func find_refresh(key: String) -> Refresh:
	for refresh: Refresh in refreshes:
		if refresh.key == key:
			return refresh
	return null


## Turns the streamed width gathered since the last flush into one strip refresh on the caret line.
func flush_strip() -> void:
	while pending_width > 0.0:
		var room := LINE_RIGHT - caret.x
		var width := minf(maxf(pending_width, MIN_STRIP_WIDTH), room)
		add_refresh(Rect2(caret.x, caret.y, width, LINE_HEIGHT), MODE_PARTIAL, PARTIAL_SECONDS)
		pending_width = maxf(pending_width - width, 0.0)
		caret.x += width
		if caret.x >= LINE_RIGHT - 0.01:
			caret = Vector2(LINE_LEFT, caret.y + LINE_HEIGHT)
			if caret.y > LINE_BOTTOM:
				caret.y = LINE_TOP
		if refreshes.size() >= MAX_REFRESHES - 1:
			pending_width = 0.0
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	step_panel(minf(delta, 1.0 / 20.0))
	apply_shader_state()
	pass


func step_panel(delta: float) -> void:
	panel_time += delta
	presence = move_toward(presence, presence_target, PRESENCE_PER_SECOND * delta)
	flush_timer += delta
	if flush_timer >= FLUSH_INTERVAL and pending_width > 0.0:
		flush_timer = 0.0
		flush_strip()
	fast_timer += delta
	if fast_timer >= FAST_INTERVAL and pending_fast:
		fast_timer = 0.0
		pending_fast = false
		var size := Vector2(rng.randf_range(0.08, 0.22), LINE_HEIGHT * rng.randf_range(1.0, 2.5))
		var origin := Vector2(rng.randf_range(LINE_LEFT, LINE_RIGHT - size.x), clampf(caret.y + rng.randf_range(-0.12, 0.12), LINE_TOP, LINE_BOTTOM))
		add_refresh(Rect2(origin, size), MODE_FAST, FAST_SECONDS)
	for index in range(refreshes.size() - 1, -1, -1):
		var refresh := refreshes[index]
		refresh.progress += delta / refresh.duration
		if refresh.mode == MODE_BUSY:
			refresh.progress = fmod(refresh.progress, 1.0)
		elif refresh.progress >= 1.0:
			refreshes.remove_at(index)
	if full_refresh != null:
		full_refresh.progress += delta / full_refresh.duration
		if full_refresh.progress >= 0.5:
			ghost = 0.0
		if full_refresh.progress >= 1.0:
			full_refresh = null
	pass


func apply_shader_state() -> void:
	if eink_material == null:
		return
	var rects := PackedVector4Array()
	var states := PackedVector4Array()
	rects.resize(MAX_REFRESHES)
	states.resize(MAX_REFRESHES)
	var count := 0
	for refresh: Refresh in refreshes:
		rects[count] = Vector4(refresh.rect.position.x, refresh.rect.position.y, refresh.rect.end.x, refresh.rect.end.y)
		states[count] = Vector4(refresh.progress, refresh.mode, refresh.error, refresh.noise_seed)
		count += 1
	if full_refresh != null:
		rects[count] = Vector4(0.0, 0.0, 1.0, 1.0)
		states[count] = Vector4(full_refresh.progress, MODE_PARTIAL, full_refresh.error, full_refresh.noise_seed)
		count += 1
	eink_material.set_shader_parameter("refresh_count", count)
	eink_material.set_shader_parameter("refresh_rect", rects)
	eink_material.set_shader_parameter("refresh_state", states)
	eink_material.set_shader_parameter("presence", presence)
	eink_material.set_shader_parameter("ghost", ghost)
	eink_material.set_shader_parameter("panel_time", panel_time)
	pass


func update_theme_presentation() -> void:
	if eink_material == null:
		return
	var dark := ThemeColor.is_dark_theme()
	eink_material.set_shader_parameter("paper_color", Color(0.86, 0.85, 0.81) if dark else Color(0.93, 0.92, 0.88))
	eink_material.set_shader_parameter("ink_color", Color(0.1, 0.1, 0.11) if dark else Color(0.13, 0.13, 0.14))
	eink_material.set_shader_parameter("error_color", Colors.error)
	pass
