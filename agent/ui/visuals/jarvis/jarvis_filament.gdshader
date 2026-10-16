shader_type spatial;
render_mode blend_add, depth_test_disabled, depth_draw_never, cull_disabled, unshaded;

uniform vec4 line_color : source_color = vec4(0.0, 0.84, 0.68, 0.58);
uniform float line_strength : hint_range(0.0, 1.5) = 0.52;
uniform float line_width_px : hint_range(0.5, 8.0) = 0.85;
uniform float line_aa_px : hint_range(0.0, 3.0) = 0.3;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

void vertex() {
	vec3 other_local = VERTEX + vec3(UV2.x, UV2.y, COLOR.r);
	vec4 clip_self = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_other = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(other_local, 1.0);

	vec2 ndc_self = clip_self.xy / clip_self.w;
	vec2 ndc_other = clip_other.xy / clip_other.w;

	vec2 dir = ndc_other - ndc_self;
	float dir_len = length(dir);
	if (dir_len < 1e-6) {
		dir = vec2(1.0, 0.0);
	} else {
		dir /= dir_len;
	}

	vec2 normal = vec2(-dir.y, dir.x);
	float side = UV.y * 2.0 - 1.0;
	float half_w = line_width_px * 0.5 + line_aa_px;
	float px_to_ndc = 2.0 / max(viewport_size.y, 1.0);
	vec2 offset = normal * side * half_w * px_to_ndc;

	clip_self.xy += offset * clip_self.w;
	POSITION = clip_self;
}

void fragment() {
	float half_total = line_width_px * 0.5 + line_aa_px;
	float dist_px = abs(UV.y - 0.5) * 2.0 * half_total;
	float half_core = line_width_px * 0.5;
	float cover = 1.0 - smoothstep(half_core, half_core + line_aa_px, dist_px);
	float alpha = line_color.a * line_strength * cover;
	vec3 col = line_color.rgb * line_strength * cover;
	ALBEDO = col;
	EMISSION = col * 1.65;
	ALPHA = alpha;
}
