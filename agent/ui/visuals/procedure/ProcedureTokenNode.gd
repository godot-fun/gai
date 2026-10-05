class_name ProcedureTokenNode
extends Control

## One independently animated tokenizer piece and its numeric vocabulary ID.
## Cinematic neon look: soft theme-colored bloom haze + hot white glyph core.

const PANEL_HORIZONTAL_BLEED := 34.0
const PANEL_VERTICAL_BLEED := 28.0
const ID_RESERVE := 28.0
const PANEL_ID_GAP := 6.0
const CORE_OUTLINE_SIZE := 5
const MID_OUTLINE_SIZE := 12
const FAR_OUTLINE_SIZE := 22
const TEXT_EFFECT_SHADER := """
shader_type canvas_item;

uniform vec4 effect_color : source_color = vec4(0.0, 0.84, 0.68, 1.0);
uniform float glow_strength = 1.05;
uniform float scanline_strength = 0.11;
uniform float grain_strength = 0.035;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float center = texture(TEXTURE, UV).a;
	float edge = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			edge = max(edge, texture(TEXTURE, UV + vec2(float(x), float(y)) * pixel).a);
		}
	}
	float rim = max(edge - center, 0.0);
	float scanline = 1.0 - scanline_strength * (0.55 + 0.45 * sin(FRAGCOORD.y * 3.1));
	float grain = (hash(floor(FRAGCOORD.xy) + floor(TIME * 22.0)) - 0.5) * grain_strength;
	float flicker = 0.98 + 0.02 * sin(TIME * 18.5 + FRAGCOORD.x * 0.02);
	// Preserve theme-colored outline draws (COLOR) while pushing filled glyphs toward a hot white core.
	vec3 lit = mix(COLOR.rgb, vec3(1.0), smoothstep(0.18, 0.88, center) * 0.55);
	lit = mix(effect_color.rgb, lit, clamp(center * 1.35, 0.0, 1.0));
	vec3 color = lit * center * scanline * flicker;
	color += effect_color.rgb * rim * glow_strength;
	color += grain * max(center, rim);
	float alpha = max(center, rim * 0.78) * COLOR.a;
	COLOR = vec4(max(color, vec3(0.0)), alpha);
}
"""

var token_id: int = -1
var piece: String = ""
var revealed: bool = false
var panel: PanelContainer
var bloom_far: Label
var bloom_mid: Label
var piece_label: Label
var id_label: Label
var reveal_tween: Tween


func setup(value: LlamaHelper.Token, node_size: Vector2) -> void:
	token_id = value.id
	piece = display_piece(value.piece)
	custom_minimum_size = node_size
	size = node_size
	build_ui()
	set_revealed(false)
	pass


func build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bleed outside the tightly measured token node. This gives the revealed frame and bloom
	# haze breathing room without reintroducing gaps while the sentence is still joined.
	# Keep the bottom clear of the ID band so the frame never covers the vocabulary number.
	panel.offset_left = -PANEL_HORIZONTAL_BLEED * 0.35
	panel.offset_top = -PANEL_VERTICAL_BLEED * 0.35
	panel.offset_right = PANEL_HORIZONTAL_BLEED * 0.35
	panel.offset_bottom = -(ID_RESERVE + PANEL_ID_GAP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	bloom_far = make_bloom_label(FAR_OUTLINE_SIZE)
	bloom_mid = make_bloom_label(MID_OUTLINE_SIZE)
	add_child(bloom_far)
	add_child(bloom_mid)

	piece_label = Label.new()
	piece_label.text = piece
	piece_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	piece_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_text_label_layout(piece_label)
	piece_label.add_theme_font_override("font", Fonts.regular())
	piece_label.add_theme_font_size_override("font_size", 34)
	piece_label.add_theme_constant_override("outline_size", CORE_OUTLINE_SIZE)
	piece_label.material = create_text_effect_material()
	add_child(piece_label)

	id_label = Label.new()
	id_label.text = str(token_id)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	id_label.offset_top = -ID_RESERVE
	id_label.offset_bottom = 0.0
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	id_label.add_theme_font_override("font", Fonts.regular())
	id_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	id_label.modulate.a = 0.0
	add_child(id_label)
	pass


func make_bloom_label(outline_size: int) -> Label:
	var label := Label.new()
	label.text = piece
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_text_label_layout(label)
	label.add_theme_font_override("font", Fonts.regular())
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func apply_text_label_layout(label: Label) -> void:
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = -PANEL_HORIZONTAL_BLEED
	label.offset_top = -PANEL_VERTICAL_BLEED
	label.offset_right = PANEL_HORIZONTAL_BLEED
	label.offset_bottom = -ID_RESERVE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pass


func set_revealed(revealed: bool) -> void:
	stop_reveal_tween()
	self.revealed = revealed
	if not revealed:
		apply_neon_colors(ThemeColor.accent_theme_color())
		id_label.text = str(token_id)
		id_label.modulate.a = 0.0
		panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_md, Margin.ma_0, Margin.ma_0, Color.TRANSPARENT, 0))
		return
	apply_reveal_visuals(token_id)
	pass


## Counts the vocabulary ID up from 0 while applying the final token color immediately.
func play_reveal(duration: float) -> void:
	stop_reveal_tween()
	revealed = true
	apply_reveal_visuals(0)
	id_label.modulate.a = 1.0
	scale = Vector2(0.92, 0.92)
	reveal_tween = create_tween().set_parallel(true)
	reveal_tween.tween_method(func(value: float) -> void: apply_reveal_visuals(int(round(value))), 0.0, float(token_id), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pass


func apply_reveal_visuals(display_id: int) -> void:
	var color := neon_display_color(color_from_token_id(token_id))
	apply_neon_colors(color)
	id_label.text = str(mini(maxi(display_id, 0), token_id))
	id_label.add_theme_color_override("font_color", Color(color, 0.82))
	panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Color(color, 0.10), ControlSize.radius_md, Margin.ma_0, Margin.ma_0, Color(color, 0.55), ControlSize.border_xs))
	pass


func stop_reveal_tween() -> void:
	if reveal_tween != null and reveal_tween.is_valid():
		reveal_tween.kill()
	reveal_tween = null
	pass


func apply_neon_colors(color: Color) -> void:
	# Far haze: soft atmospheric bloom that follows glyph shapes via large outlines.
	bloom_far.add_theme_color_override("font_color", Color(color, 0.11))
	bloom_far.add_theme_color_override("font_outline_color", Color(color, 0.16))
	bloom_mid.add_theme_color_override("font_color", Color(color, 0.18))
	bloom_mid.add_theme_color_override("font_outline_color", Color(color, 0.28))
	# Core: hot near-white fill; theme outline becomes the tight neon rim.
	piece_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	piece_label.add_theme_color_override("font_outline_color", Color(color, 0.68))
	(piece_label.material as ShaderMaterial).set_shader_parameter("effect_color", color)
	(piece_label.material as ShaderMaterial).set_shader_parameter("glow_strength", 1.15 if not revealed else 0.85)
	pass


func refresh_theme() -> void:
	if not revealed:
		set_revealed(false)
	pass


static func create_text_effect_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = TEXT_EFFECT_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	return shader_material


static func display_piece(raw_piece: String) -> String:
	var result := raw_piece.replace("▁", " ").replace("Ġ", " ").replace("Ċ", "↵")
	if result == "\n":
		return "↵"
	return result


static func color_from_token_id(value: int) -> Color:
	# Low-discrepancy map into the full RGB cube [0,1]³ (not a fixed-S/V hue ring),
	# so EmbeddingEffect positions from RGB can occupy the whole 3D volume.
	var r := fposmod(float(value) * 0.618033988749895, 1.0)
	var g := fposmod(float(value) * 0.414213562373095, 1.0)
	var b := fposmod(float(value) * 0.732050807568877, 1.0)
	return Color(r, g, b)


## Brightens dark cube colors for neon UI while keeping hue/channel ratios.
static func neon_display_color(color: Color, min_luminance: float = 0.42) -> Color:
	var luminance := color.get_luminance()
	if luminance >= min_luminance:
		return color
	return color.lightened(min_luminance - luminance)
