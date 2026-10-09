shader_type canvas_item;
render_mode unshaded;

uniform float opacity : hint_range(0.0, 1.0) = 0.58;


void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	if (length(point) > 1.0) {
		COLOR = vec4(0.0);
	} else {
		bool light = point.x < 0.0;
		if (length(point - vec2(0.0, -0.5)) < 0.5) {
			light = true;
		}
		if (length(point - vec2(0.0, 0.5)) < 0.5) {
			light = false;
		}
		if (length(point - vec2(0.0, -0.5)) < 0.105) {
			light = false;
		}
		if (length(point - vec2(0.0, 0.5)) < 0.105) {
			light = true;
		}
		COLOR = vec4(light ? vec3(1.0) : vec3(0.0), opacity);
	}
}
