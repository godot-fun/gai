shader_type canvas_item;
render_mode unshaded;

uniform float pixel_size : hint_range(1.0, 12.0) = 4.0;
uniform float wave_strength : hint_range(0.0, 4.0) = 1.0;
uniform float daylight : hint_range(0.0, 1.0) = 0.0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float row = floor(VERTEX.y / max(pixel_size, 1.0));
	float wave = sin(row * 0.73 + TIME * (0.58 + rain_intensity * 0.52));
	VERTEX.x += wave * wave_strength;
}

void fragment() {
	float row_height = max(SCREEN_PIXEL_SIZE.y * pixel_size, 0.00001);
	float row = floor(SCREEN_UV.y / row_height);
	float shimmer = 0.5 + 0.5 * sin(row * 0.83 + TIME * (0.72 + rain_intensity * 0.55));
	float strength = mix(0.055, 0.025, daylight) + rain_intensity * 0.025;
	COLOR.rgb *= 0.97 + shimmer * strength;
}
