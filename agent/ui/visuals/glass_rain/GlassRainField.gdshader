shader_type canvas_item;
render_mode blend_disabled;

// Water on a window pane. R = water mass, G = fog, B = wet trail. Beads below the stick mass
// cling; heavier cells pour all but a thin film into one cell below, chosen by a banded hash so
// rivulets wander. The move is decided by the giving cell, so mass is conserved.
// Wet trails wipe the fog, and fog creeps back as they evaporate.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

uniform float stick_mass = 0.4;
uniform float film_mass = 0.015;
uniform float evaporation = 0.0006;
uniform float trail_decay : hint_range(0.9, 1.0) = 0.996;
uniform float fog_target : hint_range(0.0, 1.0) = 0.25;
uniform float fog_rate : hint_range(0.0, 1.0) = 0.01;

float slide_direction(vec2 cell) {
	float h = field_hash(vec2(cell.x, floor(cell.y / 5.0)) + floor(field_time * 0.7) * vec2(17.0, 3.0));
	return h < 0.18 ? -1.0 : (h > 0.82 ? 1.0 : 0.0);
}

void fragment() {
	vec4 s = state_at(UV);
	if (reset) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 cell = floor(UV / texel);
		float water = s.r > stick_mass ? film_mass : s.r;
		if (cell.y >= 1.0) {
			for (int column = -1; column <= 1; column++) {
				float dx = float(column);
				vec2 giver = cell + vec2(-dx, -1.0);
				float given = texture(state_tex, (giver + 0.5) * texel).r;
				if (given > stick_mass && slide_direction(giver) == dx) {
					water += given - film_mass;
				}
			}
		}
		if (water < stick_mass) {
			water = max(water - evaporation, 0.0);
		}
		float wet = max(water, max(state_offset(UV, vec2(-1.0, 0.0)).r, state_offset(UV, vec2(1.0, 0.0)).r) * 0.8);
		float trail = max(s.b * trail_decay, smoothstep(0.03, 0.2, wet));
		for (int index = 0; index < impulse_count; index++) {
			float falloff = impulse_falloff(UV, impulse_shapes[index]);
			water += impulse_shapes[index].w * falloff;
			trail = max(trail, impulse_vectors[index].x * falloff);
		}
		float fog = s.g + (fog_target * (1.0 - trail) - s.g) * fog_rate;
		fog = min(fog, 1.0 - trail * 0.92);
		COLOR = vec4(water, clamp(fog, 0.0, 1.0), clamp(trail, 0.0, 1.0), 1.0);
	}
}
