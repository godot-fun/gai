shader_type canvas_item;
render_mode blend_disabled;

// One texel per slime-mold agent: RG = position in screen UV, B = heading in radians.
// Each step an agent senses the trail ahead and to both sides, steers toward the strongest
// reading, and moves on. Food in the trail's G channel attracts; spoiled (negative) food repels.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

uniform sampler2D trail_tex : repeat_disable, filter_linear;
uniform vec2 trail_texel = vec2(0.001);
uniform float trail_aspect = 1.777;
uniform float speed_px = 1.0;
uniform float sensor_px = 9.0;
uniform float sensor_angle = 0.45;
uniform float turn_angle = 0.4;
uniform float wander = 0.1;
uniform float food_weight = 6.0;
uniform float pass_seed = 0.0;

float sense(vec2 position, float heading) {
	vec2 probe = position + vec2(cos(heading), sin(heading)) * sensor_px * trail_texel;
	vec4 trail = texture(trail_tex, probe);
	return trail.r + trail.g * food_weight;
}

void fragment() {
	vec4 agent = state_at(UV);
	vec2 seed = UV * vec2(311.7, 127.1) + vec2(field_time * 13.17, pass_seed * 7.3);
	if (reset) {
		float radius = sqrt(field_hash(seed)) * 0.2;
		float angle = field_hash(seed + 1.7) * TAU;
		vec2 position = vec2(0.5, 0.56) + vec2(cos(angle) / trail_aspect, sin(angle)) * radius;
		COLOR = vec4(position, angle, 1.0);
	} else {
		vec2 position = agent.xy;
		float heading = agent.z;
		float forward = sense(position, heading);
		float left = sense(position, heading - sensor_angle);
		float right = sense(position, heading + sensor_angle);
		float roll = field_hash(seed + 3.1);
		if (forward < left && forward < right) {
			heading += (roll < 0.5 ? -1.0 : 1.0) * turn_angle;
		} else if (left > right) {
			heading -= turn_angle * roll;
		} else if (right > left) {
			heading += turn_angle * roll;
		}
		heading += (field_hash(seed + 5.9) - 0.5) * wander;
		position += vec2(cos(heading), sin(heading)) * speed_px * trail_texel;
		if (any(lessThan(position, vec2(0.0))) || any(greaterThan(position, vec2(1.0)))) {
			position = clamp(position, vec2(0.0), vec2(1.0));
			heading = field_hash(seed + 8.3) * TAU;
		}
		COLOR = vec4(position, mod(heading, TAU), 1.0);
	}
}
