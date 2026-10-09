shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float half_width_uv = 0.38;
uniform float opening_y_uv = 0.67;
uniform float yang_y_uv = 0.43;
uniform float yin_y_uv = 0.57;
uniform float yin_gap_uv = 0.0;
uniform float opening_progress : hint_range(0.0, 1.0) = 0.0;
uniform float duality_progress : hint_range(0.0, 1.0) = 0.0;
uniform bool duality_active = false;
uniform bool formation_active = false;
uniform vec4 aura_color : source_color = vec4(1.0);
uniform vec2 formation_center_uv = vec2(0.5);
uniform float formation_radius_px = 260.0;
uniform float formation_source_y_uv = 0.57;
uniform float outer_progress = 0.0;
uniform float upper_dot_progress = 0.0;
uniform float lower_dot_progress = 0.0;
uniform float divider_progress = 0.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float flowing_aura(vec2 uv, float line_y, float extent, float gap, float seed) {
	float x_from_center = abs(uv.x - 0.5);
	float inside_extent = 1.0 - smoothstep(extent - 0.008, extent, x_from_center);
	float outside_gap = smoothstep(gap, gap + 0.008, x_from_center);
	float distance_px = abs(uv.y - line_y) * viewport_size.y;
	float soft_band = smoothstep(18.0, 2.0, distance_px) * smoothstep(0.6, 3.4, distance_px);
	float cell_noise = hash(floor(vec2(uv.x * viewport_size.x * 0.035 - TIME * 4.0, seed + uv.y * 23.0)));
	float current = 0.55 + 0.45 * sin(uv.x * viewport_size.x * 0.045 - TIME * 1.35 + seed);
	return inside_extent * outside_gap * soft_band * mix(current, cell_noise, 0.22);
}

float segment_distance(vec2 point, vec2 start, vec2 finish) {
	vec2 segment = finish - start;
	float ratio = clamp(dot(point - start, segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
	return length(point - (start + segment * ratio));
}

vec2 outer_point(float ratio) {
	vec2 center = formation_center_uv * viewport_size;
	vec2 source = vec2(center.x + mix(-half_width_uv, half_width_uv, ratio) * viewport_size.x, formation_source_y_uv * viewport_size.y);
	float angle = 1.5707963 + 6.2831853 * ratio;
	vec2 target = center + vec2(cos(angle), sin(angle)) * formation_radius_px;
	return mix(source, target, outer_progress);
}

vec2 dot_point(float ratio, bool upper) {
	vec2 center = formation_center_uv * viewport_size;
	float gap = half_width_uv * 0.13;
	float start_x = upper ? -half_width_uv : gap;
	float end_x = upper ? -gap : half_width_uv;
	vec2 source = vec2(center.x + mix(start_x, end_x, ratio) * viewport_size.x, formation_source_y_uv * viewport_size.y);
	vec2 dot_center = center + vec2(0.0, formation_radius_px * (upper ? -0.5 : 0.5));
	float angle = (upper ? 1.5707963 : -1.5707963) + 6.2831853 * ratio;
	vec2 target = dot_center + vec2(cos(angle), sin(angle)) * formation_radius_px * 0.105;
	return mix(source, target, upper ? upper_dot_progress : lower_dot_progress);
}

float formation_distance(vec2 point) {
	float distance_px = 100000.0;
	vec2 previous = outer_point(0.0);
	for (int index = 1; index <= 48; index++) {
		float ratio = float(index) / 48.0;
		vec2 current = outer_point(ratio);
		distance_px = min(distance_px, segment_distance(point, previous, current));
		previous = current;
	}
	for (int side = 0; side < 2; side++) {
		bool upper = side == 0;
		previous = dot_point(0.0, upper);
		for (int index = 1; index <= 32; index++) {
			float ratio = float(index) / 32.0;
			vec2 current = dot_point(ratio, upper);
			distance_px = min(distance_px, segment_distance(point, previous, current));
			previous = current;
		}
	}
	if (divider_progress > 0.0) {
		vec2 center = formation_center_uv * viewport_size;
		float upper_reveal = min(divider_progress * 2.0, 1.0);
		float lower_reveal = clamp(divider_progress * 2.0 - 1.0, 0.0, 1.0);
		vec2 upper_center = center - vec2(0.0, formation_radius_px * 0.5);
		previous = upper_center + vec2(0.0, -formation_radius_px * 0.5);
		for (int index = 1; index <= 20; index++) {
			float ratio = float(index) / 20.0 * upper_reveal;
			float angle = -1.5707963 + 3.1415927 * ratio;
			vec2 current = upper_center + vec2(cos(angle), sin(angle)) * formation_radius_px * 0.5;
			distance_px = min(distance_px, segment_distance(point, previous, current));
			previous = current;
		}
		if (lower_reveal > 0.0) {
			vec2 lower_center = center + vec2(0.0, formation_radius_px * 0.5);
			previous = lower_center + vec2(0.0, -formation_radius_px * 0.5);
			for (int index = 1; index <= 20; index++) {
				float ratio = float(index) / 20.0 * lower_reveal;
				float angle = -1.5707963 - 3.1415927 * ratio;
				vec2 current = lower_center + vec2(cos(angle), sin(angle)) * formation_radius_px * 0.5;
				distance_px = min(distance_px, segment_distance(point, previous, current));
				previous = current;
			}
		}
	}
	return distance_px;
}

void fragment() {
	float aura = 0.0;
	if (formation_active) {
		float distance_px = formation_distance(UV * viewport_size);
		float pulse = 0.72 + 0.28 * sin(TIME * 1.35 + UV.x * viewport_size.x * 0.045);
		aura = smoothstep(15.0, 1.5, distance_px) * pulse;
	} else if (duality_active) {
		aura += flowing_aura(UV, yang_y_uv, half_width_uv, 0.0, 2.0);
		aura += flowing_aura(UV, yin_y_uv, half_width_uv, yin_gap_uv, 7.0);
		aura *= smoothstep(0.0, 0.34, duality_progress);
	} else {
		aura = flowing_aura(UV, opening_y_uv, half_width_uv * opening_progress, 0.0, 4.0);
		aura *= opening_progress;
	}
	COLOR = vec4(aura_color.rgb, aura * aura_color.a * 0.12);
}
