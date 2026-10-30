shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_front, shadows_disabled, fog_disabled;

// Procedural starfield drawn on a large sphere the camera sits inside. Stars live in a 3D lattice
// projected onto the view directions, so the field keeps a natural spread without any texture.

uniform vec3 star_color : source_color = vec3(0.90, 0.95, 1.0);
uniform float density = 26.0;
uniform float star_size = 0.10;
uniform float brightness : hint_range(0.0, 4.0) = 1.6;
uniform float coverage : hint_range(0.0, 1.0) = 0.40;
uniform float twinkle_speed = 0.7;

varying vec3 star_direction;

float hash13(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

void vertex() {
	star_direction = normalize(VERTEX);
}

void fragment() {
	vec3 point = star_direction * density;
	vec3 cell = floor(point);
	float star_seed = hash13(cell);
	if (star_seed > coverage) {
		discard;
	}
	vec3 offset = vec3(hash13(cell + 7.13), hash13(cell + 17.31), hash13(cell + 29.07)) - 0.5;
	vec3 local = fract(point) - 0.5 - offset * 0.7;
	float size = star_size * (0.45 + hash13(cell + 41.7));
	float core = smoothstep(size, 0.0, length(local));
	if (core <= 0.002) {
		discard;
	}
	float twinkle = 0.62 + 0.38 * sin(TIME * twinkle_speed * (1.0 + star_seed * 3.0) + star_seed * 47.0);
	float peak = 0.35 + 0.65 * hash13(cell + 53.9);
	ALBEDO = star_color;
	ALPHA = clamp(core * twinkle * peak * brightness, 0.0, 1.0);
}
