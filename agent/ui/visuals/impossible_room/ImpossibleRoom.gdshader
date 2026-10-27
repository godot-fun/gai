shader_type canvas_item;

// Re-sample the rendered application as an impossible moving set. The toolbar and central
// "performer" area remain visually anchored while the surrounding interface slides past them.
// At rest this pass is pixel-identical to the source; the set is only revealed through movement.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float displacement_px = 0.0;
uniform float velocity = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float toolbar_height_px = 48.0;
uniform vec4 accent_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float toolbar_uv = toolbar_height_px / max(viewport_px.y, 1.0);
	float body_y = clamp((SCREEN_UV.y - toolbar_uv) / max(1.0 - toolbar_uv, 0.001), 0.0, 1.0);
	float body_mask = smoothstep(toolbar_uv, toolbar_uv + SCREEN_PIXEL_SIZE.y * 8.0, SCREEN_UV.y);

	float motion_energy = clamp(abs(displacement_px) / 148.0 + abs(velocity) * 0.42, 0.0, 1.0);

	// The center acts as the camera-locked performer. Its broad rectangular mask follows the usual
	// chat reading column, while the surrounding chrome behaves like the moving room around it.
	float anchor_x = smoothstep(0.16, 0.24, SCREEN_UV.x) * (1.0 - smoothstep(0.76, 0.84, SCREEN_UV.x));
	float anchor_y = smoothstep(toolbar_uv + 0.035, toolbar_uv + 0.10, SCREEN_UV.y) * (1.0 - smoothstep(0.82, 0.94, SCREEN_UV.y));
	float anchor_mask = anchor_x * anchor_y * body_mask;

	// The lower part travels slightly farther, as if it were a floor sliding beneath a fixed camera.
	// Edge locking bends the displacement into the frame instead of exposing unrendered pixels.
	float floor_mask = smoothstep(0.63, 0.94, body_y);
	float depth = mix(0.86, 1.24, floor_mask);
	float travel_factor = mix(depth, 0.10, anchor_mask);
	float edge_lock = smoothstep(0.0, 0.095, SCREEN_UV.x) * (1.0 - smoothstep(0.905, 1.0, SCREEN_UV.x));
	float shift_uv = displacement_px / max(viewport_px.x, 1.0);
	float inertia_bend = velocity * sin(body_y * 3.14159265) * 0.0065;
	vec2 travel = vec2(shift_uv * travel_factor * edge_lock * body_mask, inertia_bend * (1.0 - anchor_mask) * body_mask);
	vec2 moving_uv = SCREEN_UV - travel;
	moving_uv = clamp(moving_uv, vec2(0.0), vec2(1.0));

	// Three short exposure taps give the moving set weight. The locked center receives almost no
	// blur, so the eye reads it as the subject while everything around it moves.
	vec2 blur_step = vec2(velocity * SCREEN_PIXEL_SIZE.x * 8.0, 0.0) * (1.0 - anchor_mask) * body_mask;
	vec3 room = texture(screen_texture, moving_uv).rgb * 0.62;
	room += texture(screen_texture, clamp(moving_uv + blur_step, vec2(0.0), vec2(1.0))).rgb * 0.23;
	room += texture(screen_texture, clamp(moving_uv + blur_step * 2.0, vec2(0.0), vec2(1.0))).rgb * 0.15;

	// Contact shadows appear only along the boundary between the fixed performer and the moving
	// set. Source-difference highlights borrow the theme accent from real UI edges, not a fake grid.
	float anchor_edge = clamp(length(vec2(dFdx(anchor_mask), dFdy(anchor_mask))) * 8.0, 0.0, 1.0);
	room *= 1.0 - anchor_edge * motion_energy * 0.30;
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float displaced_edge = clamp(abs(luminance(source) - luminance(room)) * 2.2, 0.0, 1.0);
	room = mix(room, accent_color.rgb, displaced_edge * motion_energy * impact * 0.12);

	// Suppress all residual decoration at rest: the application must look completely normal until
	// an event physically kicks the room.
	room = mix(source, room, smoothstep(0.0, 0.035, motion_energy));

	COLOR = vec4(room, 1.0);
}
