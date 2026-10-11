shader_type canvas_item;

uniform vec4 wave_color : source_color = vec4(1.0);
uniform float amplitude : hint_range(0.02, 0.3) = 0.23;
uniform float frequency : hint_range(0.5, 4.0) = 1.45;
uniform float thickness : hint_range(0.005, 0.1) = 0.025;
uniform float speed = 1.3;

void fragment() {
	float phase = (UV.x * frequency - TIME * speed) * 6.28318530718;
	float wave_y = 0.5 + sin(phase) * amplitude;
	float distance_to_wave = abs(UV.y - wave_y);
	float edge = fwidth(distance_to_wave);
	float core = 1.0 - smoothstep(thickness, thickness + edge, distance_to_wave);
	float glow = 1.0 - smoothstep(thickness + 0.075,
		thickness + 0.075 + edge, distance_to_wave);
	float edge_fade = smoothstep(0.01, 0.08, UV.x)
		* (1.0 - smoothstep(0.92, 0.99, UV.x));
	float circle_distance = length(UV - vec2(0.5));
	float circle_edge = fwidth(circle_distance);
	float circle_mask = 1.0 - smoothstep(0.44, 0.44 + circle_edge, circle_distance);
	float energy = 0.72 + 0.28 * (sin(phase - 0.8) * 0.5 + 0.5);
	float alpha = max(core * energy, glow * 0.12) * edge_fade * circle_mask;
	COLOR = vec4(wave_color.rgb, wave_color.a * alpha);
}
