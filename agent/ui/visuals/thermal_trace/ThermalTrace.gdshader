shader_type canvas_item;

// Thermal-camera view of the live interface. Heat picks an ironbow color, but only its chroma
// is added, scaled to stay inside the RGB gamut: every pixel keeps its exact luminance, so the
// next frame's heat sensing never sees the effect itself. White paper has no room for chroma, so
// light themes first darken hot pixels by heat_shade(); the field divides it back out.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D field_tex : repeat_disable, filter_linear;
uniform float activity : hint_range(0.0, 1.0) = 0.0;
uniform float failure_tint : hint_range(0.0, 1.0) = 0.0;
uniform float heat_gain : hint_range(0.0, 2.0) = 1.0;
uniform float cold_gain : hint_range(0.0, 1.0) = 0.6;
uniform float toolbar_height_px = 48.0;

#include "res://agent/ui/visuals/thermal_trace/ThermalShade.gdshaderinc"

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec3 ironbow(float t) {
	vec3 cold = vec3(0.08, 0.1, 0.55);
	vec3 violet = vec3(0.55, 0.08, 0.7);
	vec3 red = vec3(0.95, 0.12, 0.12);
	vec3 orange = vec3(1.0, 0.55, 0.05);
	vec3 white = vec3(1.0, 0.95, 0.6);
	if (t < 0.25) {
		return mix(cold, violet, t / 0.25);
	} else if (t < 0.5) {
		return mix(violet, red, (t - 0.25) / 0.25);
	} else if (t < 0.75) {
		return mix(red, orange, (t - 0.5) / 0.25);
	}
	return mix(orange, white, clamp((t - 0.75) / 0.25, 0.0, 1.0));
}

// Largest k such that source + k * chroma stays inside [0, 1] on every channel.
float gamut_limit(vec3 source, vec3 chroma) {
	float limit = 1.0;
	for (int channel = 0; channel < 3; channel++) {
		float c = chroma[channel];
		if (c > 0.0001) {
			limit = min(limit, (1.0 - source[channel]) / c);
		} else if (c < -0.0001) {
			limit = min(limit, source[channel] / -c);
		}
	}
	return max(limit, 0.0);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);
	float live = smoothstep(0.0, 0.02, activity) * body_mask;
	vec3 result = source;
	if (live > 0.001) {
		float raw_heat = texture(field_tex, SCREEN_UV).r;
		float heat = clamp(raw_heat * heat_gain + failure_tint * 0.35, 0.0, 1.0);
		vec3 base = source * (1.0 - heat_shade(raw_heat) * live);
		vec3 palette = ironbow(heat);
		vec3 chroma = palette - vec3(dot(palette, LUMA));
		float strength = mix(cold_gain, 1.6, smoothstep(0.02, 0.3, heat)) * live;
		result = base + chroma * min(strength, gamut_limit(base, chroma));
	}
	COLOR = vec4(result, 1.0);
}
