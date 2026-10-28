shader_type canvas_item;

// One continuous optical zoom of the live application. At zoom_scale 1 the pass is
// pixel-identical to the source; nothing is drawn over the interface.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float zoom_scale : hint_range(1.0, 8.0) = 1.0;
uniform vec2 focus_uv = vec2(0.5, 0.5);
uniform vec2 lateral_uv = vec2(0.0);
uniform float defocus : hint_range(0.0, 1.0) = 0.0;

vec3 sample_source(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void fragment() {
	vec3 source = sample_source(SCREEN_UV);
	float zoom = max(zoom_scale, 1.0);
	if (zoom <= 1.0005 && abs(lateral_uv.x) + abs(lateral_uv.y) <= 0.00001 && defocus <= 0.0008) {
		COLOR = vec4(source, 1.0);
	} else {
		vec2 half_span = vec2(0.5) / zoom;
		vec2 center = clamp(focus_uv + lateral_uv, half_span, vec2(1.0) - half_span);
		vec2 zoom_uv = center + (SCREEN_UV - vec2(0.5)) / zoom;
		vec3 sharp = sample_source(zoom_uv);
		vec2 blur_px = SCREEN_PIXEL_SIZE * (1.8 + defocus * 7.4) * zoom;
		vec3 blurred = sharp;
		blurred += sample_source(zoom_uv + vec2(blur_px.x, 0.0));
		blurred += sample_source(zoom_uv - vec2(blur_px.x, 0.0));
		blurred += sample_source(zoom_uv + vec2(0.0, blur_px.y));
		blurred += sample_source(zoom_uv - vec2(0.0, blur_px.y));
		blurred *= 0.2;
		COLOR = vec4(mix(sharp, blurred, defocus), 1.0);
	}
}
