shader_type canvas_item;

// Re-sample the already rendered application so its content behaves like a room whose surfaces
// move independently of the camera. The top toolbar is the fixed visual reference; displacement
// gains depth toward the bottom and eases to zero at screen edges to avoid exposed texture gaps.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float displacement_px = 0.0;
uniform float velocity = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);

float thin_line(float distance, float width) {
	return 1.0 - smoothstep(width, width + fwidth(distance), abs(distance));
}

void fragment() {
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_y = clamp((SCREEN_UV.y - toolbar_uv) / max(1.0 - toolbar_uv, 0.001), 0.0, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);

	// The plane accelerates with depth, while the soft edge compression lets the screen remain
	// sealed instead of revealing empty pixels when the room travels sideways.
	float depth = mix(0.66, 1.34, pow(body_y, 1.35));
	float edge_lock = smoothstep(0.0, 0.095, SCREEN_UV.x) * (1.0 - smoothstep(0.905, 1.0, SCREEN_UV.x));
	float shift_uv = displacement_px / max(viewport_px.x, 1.0);
	float inertia_bend = velocity * sin(body_y * 3.14159265) * 0.012;
	vec2 moving_uv = SCREEN_UV - vec2(shift_uv * depth * edge_lock * body_mask, inertia_bend * body_mask);
	moving_uv = clamp(moving_uv, vec2(0.0), vec2(1.0));

	vec3 room = texture(screen_texture, moving_uv).rgb;

	// A narrow horizon behaves like the contact seam between wall and floor. Its offset follows
	// perspective rather than screen coordinates, making the movement read as a physical set.
	float horizon_body_y = 0.68;
	float horizon_y = toolbar_uv + (1.0 - toolbar_uv) * horizon_body_y + velocity * 0.012;
	float horizon = 1.0 - smoothstep(0.0, SCREEN_PIXEL_SIZE.y * 3.0, abs(SCREEN_UV.y - horizon_y));
	float motion_energy = clamp(abs(displacement_px) / 148.0 + abs(velocity) * 0.35, 0.0, 1.0);
	room = mix(room, accent_color.rgb, horizon * motion_energy * 0.14);

	// Architectural guides make the illusion legible even over an empty chat. Wall panels move at
	// a shallower rate than the floor, and floor seams converge at the horizon like a practical set.
	float wall_mask = smoothstep(0.0, 0.035, body_y) * (1.0 - smoothstep(horizon_body_y - 0.025, horizon_body_y, body_y));
	float wall_coordinate = fract((SCREEN_UV.x - shift_uv * 0.62) * 6.0);
	float wall_seams = thin_line(min(wall_coordinate, 1.0 - wall_coordinate), 0.0045) * wall_mask;
	float floor_t = clamp((body_y - horizon_body_y) / max(1.0 - horizon_body_y, 0.001), 0.0, 1.0);
	float floor_mask = smoothstep(0.045, 0.16, floor_t);
	float projected_x = (SCREEN_UV.x - 0.5) / max(floor_t, 0.045) + 0.5 - shift_uv * 3.4;
	float floor_coordinate = fract(projected_x * 5.0);
	float floor_rays = thin_line(min(floor_coordinate, 1.0 - floor_coordinate), 0.012) * floor_mask;
	float depth_coordinate = fract((1.0 / max(floor_t, 0.055) + impact * 0.32) * 0.72);
	float floor_cross_seams = thin_line(min(depth_coordinate, 1.0 - depth_coordinate), 0.025) * floor_mask * 0.62;
	float architecture_alpha = 0.022 + motion_energy * 0.15 + impact * 0.045;
	room = mix(room, accent_color.rgb, clamp(wall_seams + floor_rays + floor_cross_seams, 0.0, 1.0) * architecture_alpha);

	// Dark trapezoids at both sides read as walls moving past a fixed camera rather than a flat
	// image translation. They strengthen only during movement and disappear almost completely idle.
	float side_distance = min(SCREEN_UV.x, 1.0 - SCREEN_UV.x);
	float side_wall_width = mix(0.035, 0.15, body_y);
	float side_walls = 1.0 - smoothstep(side_wall_width - 0.018, side_wall_width, side_distance);
	room *= 1.0 - side_walls * body_mask * (0.035 + motion_energy * 0.19);

	// Short-lived contact shadows and opposing highlights sell the moving-set illusion without
	// turning the effect into a generic RGB glitch.
	float edge_shadow = smoothstep(0.0, 0.018, SCREEN_UV.x) * (1.0 - smoothstep(0.018, 0.055, SCREEN_UV.x));
	edge_shadow += smoothstep(0.0, 0.018, 1.0 - SCREEN_UV.x) * (1.0 - smoothstep(0.018, 0.055, 1.0 - SCREEN_UV.x));
	room *= 1.0 - edge_shadow * motion_energy * 0.16;
	float flash = impact * exp(-abs(SCREEN_UV.y - horizon_y) * 95.0) * 0.11;
	room += accent_color.rgb * flash;

	COLOR = vec4(room, 1.0);
}
