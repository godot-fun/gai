shader_type canvas_item;

// The ring texture itself is a cached mesh. This layer draws the frequently changing,
// procedural marks in one GPU pass: rails, ribs, the dense beam field, and the end scan.
uniform vec2 stage_size = vec2(1280.0, 720.0);
uniform vec2 hub = vec2(384.0, 360.0);
uniform float inner_radius = 300.0;
uniform float outer_radius = 500.0;
uniform float rail_width = 20.0;
uniform float outer_angle = 0.0;
uniform float draw_alpha = 1.0;
uniform float error_flash = 0.0;
uniform float turn_pulse = 0.0;
uniform float end_progress = 0.0;
uniform vec4 ink_color : source_color = vec4(0.92, 0.93, 0.95, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.35, 0.35, 1.0);
uniform vec4 back_color : source_color = vec4(0.02, 0.022, 0.028, 1.0);

const float TAU_VALUE = 6.28318530718;
const float RIB_COUNT = 240.0;
const float FINE_BEAM_COUNT = 900.0;

float hash11(float value) {
	return fract(sin(value * 91.731) * 43758.5453123);
}

float stroke(float distance_to_line, float width) {
	return 1.0 - smoothstep(width, width + 1.25, distance_to_line);
}

void fragment() {
	vec2 pixel = UV * stage_size;
	vec2 offset = pixel - hub;
	float radius = length(offset);
	float angle = atan(offset.y, offset.x) - outer_angle;
	vec2 direction = radius > 0.001 ? offset / radius : vec2(1.0, 0.0);
	vec3 result = vec3(0.0);
	float alpha = 0.0;

	vec3 rail_color = mix(ink_color.rgb, error_color.rgb, clamp(error_flash, 0.0, 1.0));
	float rail_alpha = (0.55 + 0.4 * turn_pulse) * draw_alpha;
	alpha = max(alpha, stroke(abs(radius - inner_radius), 0.55) * rail_alpha);
	alpha = max(alpha, stroke(abs(radius - outer_radius), 0.55) * rail_alpha);
	alpha = max(alpha, stroke(abs(radius - (inner_radius - rail_width)), 0.55) * 0.2 * draw_alpha);
	alpha = max(alpha, stroke(abs(radius - (outer_radius + rail_width * 1.4)), 0.55) * 0.25 * draw_alpha);
	result = rail_color;

	// Fine radial marks replace 720 CPU ribs. Major marks retain the original stronger reach.
	float rib_phase = fract(angle / TAU_VALUE * RIB_COUNT);
	float rib = 1.0 - smoothstep(0.055, 0.085, abs(rib_phase - 0.5));
	float major = step(0.82, hash11(floor(angle / TAU_VALUE * RIB_COUNT)));
	float inner_rib = step(inner_radius - rail_width * mix(0.55, 1.0, major), radius) * step(radius, inner_radius + 0.7);
	float outer_rib = step(outer_radius - 0.7, radius) * step(radius, outer_radius + rail_width * mix(0.7, 1.3, major));
	float rib_alpha = rib * max(inner_rib, outer_rib) * step(-0.3, direction.x) * 0.4 * draw_alpha;
	alpha = max(alpha, rib_alpha);

	// A deterministic sparse field matches the original decorative beam density without generating
	// 900 pairs of CPU vertices every frame.
	float beam_index = floor(angle / TAU_VALUE * FINE_BEAM_COUNT);
	float beam_phase = abs(fract(angle / TAU_VALUE * FINE_BEAM_COUNT) - 0.5);
	float fine_beam = (1.0 - smoothstep(0.035, 0.075, beam_phase)) * step(0.28, hash11(beam_index));
	float beam_start = outer_radius + rail_width * 1.6;
	float beam_alpha = fine_beam * step(beam_start, radius) * step(-0.2, direction.x) * (0.1 + 0.12 * hash11(beam_index + 19.0)) * draw_alpha;
	alpha = max(alpha, beam_alpha);

	// The closing scan is another full-stage procedural mark, avoiding a CPU rect and line draw.
	float scan_y = stage_size.y * end_progress;
	float scan_fill = step(pixel.y, scan_y) * 0.55 * end_progress;
	float scan_line = stroke(abs(pixel.y - scan_y), 1.0) * 0.8 * (1.0 - end_progress);
	if (scan_fill > alpha) {
		result = back_color.rgb;
		alpha = scan_fill;
	}
	if (scan_line > alpha) {
		result = ink_color.rgb;
		alpha = scan_line;
	}
	COLOR = vec4(result, alpha);
}
