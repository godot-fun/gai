class_name TaiChiCarouselFlow
extends RefCounted

## Final, looping presentation stage. The taiji and compass begin rotating, the
## taiji dissolves, and its center is reused for one trigram explanation at a time.

const INTRO_SECONDS := 4.2
const ITEM_SECONDS := 4.8
const BACKGROUND_COLORS := [
	Color("b99d62"), Color("93aabb"), Color("d7543f"), Color("716ad1"),
	Color("4f9873"), Color("376eae"), Color("526b9b"), Color("b88945"),
]
# Cloud, water, fire, mountain, wind, earth, lightning, and marsh shader families.
const BACKGROUND_EFFECTS := [0, 7, 2, 6, 4, 1, 3, 5]
const NAMES := ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
const ELEMENTS := ["天", "泽", "火", "雷", "风", "水", "山", "地"]
const STATEMENTS := ["乾为天", "兑为泽", "离为火", "震为雷", "巽为风", "坎为水", "艮为山", "坤为地"]
# Indices into the canonical name/data arrays, following the compass clockwise
# from the top: 乾 → 巽 → 坎 → 艮 → 坤 → 震 → 离 → 兑.
const PLAY_ORDER := [0, 4, 5, 6, 7, 3, 2, 1]
const FEATURES := [
	"刚健 · 自强 · 创造",
	"喜悦 · 交流 · 润泽",
	"光明 · 依附 · 文明",
	"发动 · 奋起 · 警醒",
	"渗透 · 谦逊 · 顺入",
	"险陷 · 流动 · 智慧",
	"静止 · 界限 · 笃实",
	"柔顺 · 承载 · 包容",
]
const XIANG_QUOTES := [
	"天行健，君子以自强不息。",
	"丽泽，兑；君子以朋友讲习。",
	"明两作，离；大人以继明照于四方。",
	"洊雷，震；君子以恐惧修省。",
	"随风，巽；君子以申命行事。",
	"水洊至，习坎；君子以常德行，习教事。",
	"兼山，艮；君子以思不出其位。",
	"地势坤，君子以厚德载物。",
]

var elapsed: float = 0.0
var active: bool = false


func reset() -> void:
	elapsed = 0.0
	active = false
	pass


func begin() -> void:
	elapsed = 0.0
	active = true
	pass


func advance(delta: float) -> bool:
	if not active:
		return false
	elapsed += delta
	return true


func intro_progress() -> float:
	return smoothstep(0.0, 1.0, clampf(elapsed / INTRO_SECONDS, 0.0, 1.0))


func taiji_opacity() -> float:
	return 1.0 - smoothstep(0.12, 0.88, intro_progress())


func taiji_rotation() -> float:
	return ease(intro_progress(), -1.2) * TAU * 1.5


func ring_rotation() -> float:
	return elapsed * 0.095


func carousel_time() -> float:
	return maxf(0.0, elapsed - INTRO_SECONDS)


func selected_index() -> int:
	var order_index := int(floor(carousel_time() / ITEM_SECONDS)) % PLAY_ORDER.size()
	return PLAY_ORDER[order_index]


func item_phase() -> float:
	return fmod(carousel_time(), ITEM_SECONDS) / ITEM_SECONDS


func item_opacity() -> float:
	if elapsed < INTRO_SECONDS:
		return 0.0
	var phase := item_phase()
	return smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.82, 1.0, phase))


func background_color(index: int) -> Color:
	return Color(BACKGROUND_COLORS[index])


func background_effect(index: int) -> int:
	return int(BACKGROUND_EFFECTS[index])


func background_seed(index: int) -> float:
	var item_serial := int(floor(carousel_time() / ITEM_SECONDS))
	return float(index) * 7.13 + float(item_serial) * 11.47 + 1.0


func draw(canvas: Control, bagua: TaiChiBaguaFlow) -> void:
	if not active:
		return
	var center := canvas.size * 0.5
	var orbit_radius := minf(canvas.size.x, canvas.size.y) * 0.34
	draw_rotating_frame(canvas, center, orbit_radius)
	draw_trigrams(canvas, bagua, center, orbit_radius)
	draw_explanation(canvas, center)
	pass


func draw_rotating_frame(canvas: Control, center: Vector2, orbit_radius: float) -> void:
	# The circles themselves are rotationally symmetric; rotating their start angle
	# and all tick positions makes the motion visible without rotating the labels.
	var rotation := ring_rotation()
	var ring_color := ThemeColor.alpha_theme_color(0.16)
	canvas.draw_arc(center, orbit_radius * 1.27, rotation, rotation + TAU, 160, ring_color, 1.4, true)
	canvas.draw_arc(center, orbit_radius * 1.31, -rotation, -rotation + TAU, 160, ThemeColor.alpha_theme_color(0.09), 1.0, true)
	canvas.draw_arc(center, orbit_radius * 0.63, -rotation, -rotation + TAU, 120, ring_color, 1.2, true)
	for tick in 64:
		var angle := rotation + TAU * float(tick) / 64.0
		var length := 11.0 if tick % 8 == 0 else 5.0
		var outer := center + Vector2.from_angle(angle) * orbit_radius * 1.29
		var inner := center + Vector2.from_angle(angle) * (orbit_radius * 1.29 - length)
		canvas.draw_line(inner, outer, ThemeColor.alpha_theme_color(0.2), 1.2, true)
	pass


func draw_trigrams(canvas: Control, bagua: TaiChiBaguaFlow, center: Vector2, orbit_radius: float) -> void:
	var selected := selected_index()
	var explanation_alpha := item_opacity()
	for index in 8:
		var angle: float = TaiChiBaguaFlow.TARGET_ANGLES[index]
		var position := center + Vector2.from_angle(angle) * orbit_radius
		var highlighted := index == selected and explanation_alpha > 0.0
		var pulse := 0.5 + 0.5 * sin(elapsed * 2.2)
		var width := minf(76.0, canvas.size.y * 0.085) * (1.0 + (0.1 * pulse if highlighted else 0.0))
		var alpha := TaiChiTrigramDrawing.HIGHLIGHT_ALPHA if highlighted else TaiChiTrigramDrawing.BASE_ALPHA
		bagua.draw_trigram(canvas, position, angle + PI * 0.5, TaiChiEvolutionFlow.TRIGRAM_VALUES[index], width, 13.0, 5.0, alpha)
		var label_position := center + Vector2.from_angle(angle) * (orbit_radius + minf(72.0, canvas.size.y * 0.085))
		var label_alpha := TaiChiTrigramDrawing.LABEL_HIGHLIGHT_ALPHA if highlighted else TaiChiTrigramDrawing.LABEL_BASE_ALPHA
		draw_centered_text(canvas, NAMES[index], label_position, clampi(int(canvas.size.y * 0.035), 20, 36), label_alpha)
	pass


func draw_explanation(canvas: Control, center: Vector2) -> void:
	var alpha := item_opacity()
	if alpha <= 0.0:
		return
	var index := selected_index()
	var phase := item_phase()
	var lift := (1.0 - ease(minf(phase / 0.25, 1.0), -1.6)) * 24.0
	draw_centered_text(canvas, ELEMENTS[index], center - Vector2(0.0, 20.0 + lift), clampi(int(canvas.size.y * 0.14), 76, 142), alpha * 0.9)
	draw_centered_text(canvas, STATEMENTS[index], center + Vector2(0.0, canvas.size.y * 0.105), clampi(int(canvas.size.y * 0.035), 20, 36), alpha * 0.76)
	draw_centered_text(canvas, FEATURES[index], center + Vector2(0.0, canvas.size.y * 0.155), clampi(int(canvas.size.y * 0.022), 15, 23), alpha * 0.58)
	# Keep the source sentence near the bottom of the inner circle: visually tied
	# to the current explanation, but clear of the lower 坤 trigram and its label.
	draw_centered_text(canvas, XIANG_QUOTES[index], center + Vector2(0.0, canvas.size.y * 0.225), clampi(int(canvas.size.y * 0.019), 14, 20), alpha * 0.52)
	pass


func draw_centered_text(canvas: Control, text: String, position: Vector2, font_size: int, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var font := Fonts.light()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 7, ThemeColor.alpha_theme_color(alpha * 0.08))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(ColorBase.primary_text, alpha))
	pass
