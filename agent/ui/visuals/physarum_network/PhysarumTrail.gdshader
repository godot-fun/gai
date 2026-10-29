shader_type canvas_item;
render_mode blend_disabled;

// Trail map: R = slime trail, G = food (negative = spoiled). Pass 0 diffuses and evaporates the
// previous frame and adds food sources; the agent deposit is drawn on top of it in the same
// viewport. Pass 1 copies so the deposit is not blurred twice.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

const int PASS_DIFFUSE = 0;

uniform float decay : hint_range(0.0, 1.0) = 0.9;
uniform float diffuse : hint_range(0.0, 1.0) = 0.6;
uniform float food_decay : hint_range(0.9, 1.0) = 0.985;
uniform float food_spread : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 s = state_at(UV);
	if (pass_kind != PASS_DIFFUSE) {
		COLOR = s;
	} else if (reset) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 sum = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				sum += state_offset(UV, vec2(float(x), float(y))).rg;
			}
		}
		vec2 blur = sum / 9.0;
		float trail = mix(s.r, blur.x, diffuse) * decay;
		float food = mix(s.g, blur.y, food_spread) * food_decay;
		for (int index = 0; index < impulse_count; index++) {
			food += impulse_shapes[index].w * impulse_falloff(UV, impulse_shapes[index]);
		}
		COLOR = vec4(min(trail, 40.0), clamp(food, -2.0, 2.0), 0.0, 1.0);
	}
}
