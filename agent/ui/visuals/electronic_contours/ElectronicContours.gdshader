shader_type canvas_item;

// The live image becomes an event-driven field of broken electronic contours.
// Local contrast, rather than raw brightness, drives height so both light and dark themes produce
// peaks around glyphs, borders, icons, and controls.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float relief_amount : hint_range(0.0, 1.0) = 0.0;
uniform float raster_phase = 0.0;
uniform float quake_energy : hint_range(0.0, 1.0) = 0.0;
uniform float quake_progress : hint_range(-0.1, 1.25) = 1.2;
uniform float line_count : hint_range(72.0, 260.0) = 127.0;
uniform float max_deflection_px : hint_range(0.0, 80.0) = 54.0;
uniform float toolbar_height_px = 0.0;
uniform vec4 accent_color : source_color = vec4(0.0, 0.85, 0.70, 1.0);
uniform vec4 background_color : source_color = vec4(0.04, 0.05, 0.07, 1.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float height_signal(vec2 uv, vec2 pixel_size) {
	vec2 near_step = pixel_size * 2.0;
	vec2 far_step = pixel_size * 7.0;
	float left = luminance(texture(screen_texture, clamp(uv - vec2(near_step.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
	float right = luminance(texture(screen_texture, clamp(uv + vec2(near_step.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
	float above = luminance(texture(screen_texture, clamp(uv - vec2(0.0, near_step.y), vec2(0.0), vec2(1.0))).rgb);
	float below = luminance(texture(screen_texture, clamp(uv + vec2(0.0, near_step.y), vec2(0.0), vec2(1.0))).rgb);
	float center = luminance(texture(screen_texture, uv).rgb);
	float far_average = (
		luminance(texture(screen_texture, clamp(uv - vec2(far_step.x, 0.0), vec2(0.0), vec2(1.0))).rgb)
		+ luminance(texture(screen_texture, clamp(uv + vec2(far_step.x, 0.0), vec2(0.0), vec2(1.0))).rgb)
		+ luminance(texture(screen_texture, clamp(uv - vec2(0.0, far_step.y), vec2(0.0), vec2(1.0))).rgb)
		+ luminance(texture(screen_texture, clamp(uv + vec2(0.0, far_step.y), vec2(0.0), vec2(1.0))).rgb)
	) * 0.25;
	float edge = length(vec2(right - left, below - above));
	float local_detail = abs(center - far_average);
	return pow(clamp(edge * 3.7 + local_detail * 2.2, 0.0, 1.0), 0.68);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 original = texture(screen_texture, uv).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, uv.y);
	float amount = smoothstep(0.0, 0.045, relief_amount) * relief_amount * body_mask;

	if (amount <= 0.0001) {
		COLOR = vec4(original, 1.0);
	} else {
		float terrain_height = height_signal(uv, SCREEN_PIXEL_SIZE);
		float quake_distance = uv.y - quake_progress;
		float quake_compression = exp(-pow((quake_distance + 0.038) / 0.020, 2.0));
		float quake_crest = exp(-pow(quake_distance / 0.033, 2.0));
		float quake_wake = exp(-pow((quake_distance - 0.072) / 0.052, 2.0));
		float quake_band = quake_crest * quake_energy;
		float quake_shape = (-quake_compression * 0.34 + quake_crest - quake_wake * 0.20) * quake_energy;
		float body_depth = clamp((uv.y - toolbar_uv) / max(1.0 - toolbar_uv, 0.001), 0.0, 1.0);
		float depth_scale = mix(0.58, 1.22, body_depth);
		float height_displacement = terrain_height * max_deflection_px * SCREEN_PIXEL_SIZE.y * amount * depth_scale;
		float quake_displacement = quake_shape * max_deflection_px * 0.34 * SCREEN_PIXEL_SIZE.y * (0.32 + terrain_height * 0.90);

		// Using the displaced coordinate as the raster phase bends each horizontal scan line around
		// live UI detail. A second lookup lets color travel with the raised electronic surface.
		float displaced_y = uv.y + height_displacement + quake_displacement;
		float perspective_y = pow(body_depth, 0.82);
		float perspective_offset = (perspective_y - body_depth) * (1.0 - toolbar_uv);
		float raster_coordinate = (displaced_y + perspective_offset) * line_count + sin(uv.x * 4.0 + raster_phase) * 0.018 * amount;
		float line_distance = abs(fract(raster_coordinate) - 0.5);
		float line_core = 1.0 - smoothstep(0.070, 0.23, line_distance);

		float horizontal_expansion = terrain_height * amount * depth_scale * 0.048;
		float relief_x = 0.5 + (uv.x - 0.5) / max(1.0 + horizontal_expansion, 1.0);
		vec2 relief_uv = clamp(vec2(relief_x, uv.y + height_displacement * 0.72 + quake_displacement), vec2(0.0), vec2(1.0));
		vec3 carried_color = texture(screen_texture, relief_uv).rgb;
		float ridge_light = clamp(terrain_height * 0.82 + quake_band * 0.34, 0.0, 1.0);
		vec3 phosphor = mix(carried_color, accent_color.rgb, 0.05 + ridge_light * 0.28);
		phosphor *= 0.52 + ridge_light * 0.86;
		vec3 field_background = mix(background_color.rgb, vec3(0.006, 0.009, 0.013), 0.72);

		// Flat areas carry no periodic raster. Height itself is quantized into irregular terraces,
		// so live UI edges generate topographic contours instead of a continuous CRT grille.
		float terrain_presence = smoothstep(0.025, 0.17, terrain_height);
		float contour_coordinate = terrain_height * 7.5 - body_depth * 1.35 + quake_shape * 0.42;
		float contour_distance = abs(fract(contour_coordinate) - 0.5);
		float contour_core = 1.0 - smoothstep(0.30, 0.47, contour_distance);
		float contour_fragment = smoothstep(-0.48, 0.20, sin(uv.x * 96.0 + terrain_height * 19.0 + raster_phase * 0.18));
		float topographic_contours = contour_core * terrain_presence * mix(0.58, 1.0, contour_fragment);
		float deflection_trace = line_core * smoothstep(0.10, 0.48, terrain_height) * 0.34;
		float visible_surface = clamp(max(topographic_contours, deflection_trace) + quake_band * contour_core * 0.16, 0.0, 1.0);
		vec3 low_surface = mix(field_background, carried_color * 0.28 + accent_color.rgb * 0.035, terrain_presence * 0.22);
		vec3 raster_field = mix(low_surface, phosphor, visible_surface);

		// A thin displaced duplicate below steep ridges makes height readable without drawing a
		// conventional shadow or glow around the original controls.
		float underside_phase = abs(fract(raster_coordinate + terrain_height * 0.23) - 0.5);
		float underside = (1.0 - smoothstep(0.08, 0.22, underside_phase)) * terrain_height * visible_surface;
		raster_field = mix(raster_field, field_background * 0.34, underside * amount * 0.68);
		vec3 result = mix(original, raster_field, clamp(amount * 0.82, 0.0, 0.82));
		COLOR = vec4(result, 1.0);
	}
}
