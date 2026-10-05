class_name ProcedureTokenNode
extends Control

## One independently animated tokenizer piece and its numeric vocabulary ID.

const PANEL_HORIZONTAL_BLEED := 6.0
const PANEL_VERTICAL_BLEED := 5.0
const TEXT_EFFECT_SHADER := """
shader_type canvas_item;

uniform vec4 effect_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float glow_strength = 1.15;
uniform float scanline_strength = 0.10;
uniform float grain_strength = 0.035;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float center = texture(TEXTURE, UV).a;
	float close_glow = 0.0;
	float wide_glow = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float sample_alpha = texture(TEXTURE, UV + vec2(float(x), float(y)) * pixel).a;
			close_glow = max(close_glow, sample_alpha);
		}
	}
	for (int x = -4; x <= 4; x += 2) {
		for (int y = -4; y <= 4; y += 2) {
			wide_glow += texture(TEXTURE, UV + vec2(float(x), float(y)) * pixel).a;
		}
	}
	wide_glow /= 25.0;
	float red_trail = texture(TEXTURE, UV + vec2(pixel.x * 1.5, 0.0)).a;
	float cyan_trail = texture(TEXTURE, UV - vec2(pixel.x * 1.1, 0.0)).a;
	float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	float grain = (hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0)) - 0.5) * grain_strength;
	float flicker = 0.985 + 0.015 * sin(TIME * 17.0);
	float halo = max(close_glow - center, wide_glow * 0.72) * glow_strength;
	vec3 white_core = mix(effect_color.rgb, vec3(1.0), smoothstep(0.12, 0.82, center));
	vec3 color = white_core * center * scanline;
	color += effect_color.rgb * halo;
	color += vec3(red_trail * 0.055, cyan_trail * 0.018, cyan_trail * 0.035);
	color = max(color * flicker + grain * center, vec3(0.0));
	float alpha = max(center, halo * 0.78);
	COLOR = vec4(color, alpha);
}
"""

var token_id: int = -1
var piece: String = ""
var revealed: bool = false
var panel: PanelContainer
var piece_label: Label
var id_label: Label


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
	# Bleed outside the tightly measured token node. This gives the revealed frame breathing
	# room without reintroducing gaps while the original sentence is still joined together.
	panel.offset_left = -PANEL_HORIZONTAL_BLEED
	panel.offset_top = -PANEL_VERTICAL_BLEED
	panel.offset_right = PANEL_HORIZONTAL_BLEED
	panel.offset_bottom = -28.0 + PANEL_VERTICAL_BLEED
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	piece_label = Label.new()
	piece_label.text = piece
	piece_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	piece_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	piece_label.add_theme_font_override("font", Fonts.bold())
	piece_label.add_theme_font_size_override("font_size", 34)
	piece_label.material = create_text_effect_material()
	panel.add_child(piece_label)

	id_label = Label.new()
	id_label.text = str(token_id)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	id_label.offset_top = -24.0
	id_label.offset_bottom = 0.0
	id_label.add_theme_font_override("font", Fonts.regular())
	id_label.add_theme_font_size_override("font_size", Typography.label_small_size)
	add_child(id_label)
	pass


func set_revealed(revealed: bool) -> void:
	self.revealed = revealed
	var color := color_from_token_id(token_id) if revealed else ThemeColor.accent_theme_color()
	piece_label.add_theme_color_override("font_color", Color.WHITE)
	(piece_label.material as ShaderMaterial).set_shader_parameter("effect_color", color)
	id_label.add_theme_color_override("font_color", Color(color, 0.82))
	id_label.modulate.a = 1.0 if revealed else 0.0
	var background := Color(color, 0.13) if revealed else Color.TRANSPARENT
	var border := Color(color, 0.72) if revealed else Color.TRANSPARENT
	var border_width := ControlSize.border_xs if revealed else 0
	panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(background, ControlSize.radius_md, Margin.ma_0, Margin.ma_0, border, border_width))
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
	# The golden-ratio multiplier spreads adjacent IDs around the hue wheel.
	var hue := fposmod(float(value) * 0.61803398875, 1.0)
	return Color.from_hsv(hue, 0.58, 1.0)
