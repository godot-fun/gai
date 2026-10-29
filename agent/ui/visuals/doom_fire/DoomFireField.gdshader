shader_type canvas_item;
render_mode blend_disabled;

// PSX Doom fire. R = heat. Every pass is one step: a cell takes the heat of a random neighbor in
// the row below and loses a random fraction of [param decay], so flames climb, flicker and drift.
// The bottom row is the fuel line; flares lower the decay around their column so a running tool
// burns taller. Pass 0 also injects impulses as balls of heat that rise and burn out.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

uniform float decay = 0.05;
uniform float fuel = 1.0;
uniform float wind = 0.15;
uniform int flare_count = 0;
// (uv.x, half width in uv, strength, 0)
uniform vec4 flares[8];

void fragment() {
	if (reset) {
		COLOR = vec4(0.0);
	} else {
		vec2 cell = floor(UV / texel);
		vec2 seed = vec2(fract(field_time * 7.31) * 97.0 + float(pass_kind) * 13.7, fract(field_time * 3.17) * 61.0);
		float drift = field_hash(cell + seed);
		float burn = field_hash(cell.yx + seed.yx + 11.3);
		float shift = floor(drift * 3.0 - wind) - 1.0;
		float local_decay = decay;
		for (int index = 0; index < flare_count; index++) {
			float dx = (UV.x - flares[index].x) / max(flares[index].y, 0.001);
			local_decay *= 1.0 - flares[index].z * 0.7 * exp(-dx * dx);
		}
		float heat;
		if (UV.y > 1.0 - texel.y) {
			float tongue = field_hash(vec2(floor(cell.x / 3.0), floor(field_time * 9.0)));
			heat = fuel * (0.82 + 0.18 * tongue);
		} else {
			heat = texture(state_tex, UV + vec2(shift * texel.x, texel.y)).r - burn * local_decay;
		}
		if (pass_kind == 0) {
			for (int index = 0; index < impulse_count; index++) {
				heat = max(heat, impulse_shapes[index].w * smoothstep(0.35, 0.9, impulse_falloff(UV, impulse_shapes[index])));
			}
		}
		COLOR = vec4(clamp(heat, 0.0, 1.0), 0.0, 0.0, 1.0);
	}
}
