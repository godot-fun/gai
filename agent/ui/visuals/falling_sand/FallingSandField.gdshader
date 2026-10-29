shader_type canvas_item;
render_mode blend_disabled;

// Falling sand on a Margolus neighborhood: each pass splits the field into 2x2 blocks, offset by
// one cell on odd passes, and only moves grains inside a block, so sand is conserved without write
// conflicts. R = grain, G = color tag, B = wetness (wet grains fall but never slide), A = grain shade.
// ceiling_uv allows a future lower simulation boundary; Falling Sand sets it to zero so the field
// includes the toolbar. Pass 0 also dries grains, drains the floor
// row with probability `drain`, and stamps impulses: payload = (stamp, tag, wetness, 0) where
// stamp 0 pours a vertically stretched disk of radius shape.z, 1 sprinkles a full-width band of half-height shape.z, and 2 wets existing
// grains in a column of half-width shape.z below shape.y.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

uniform bool gravity_up = false;
uniform float ceiling_uv = 0.0;
uniform float dry_step = 0.0;
uniform float drain = 0.0;
uniform float slide_chance : hint_range(0.0, 1.0) = 0.85;
// Chance that a grain in free fall drifts one cell sideways, so a falling stream sprays.
uniform float fall_jitter : hint_range(0.0, 1.0) = 0.12;
// Pour disks are stretched vertically by 1 / pour_squash to bridge the cells a grain falls per frame.
uniform float pour_squash = 0.4;

bool cell_valid(ivec2 c, ivec2 size) {
	return c.x >= 0 && c.y >= 0 && c.x < size.x && c.y < size.y && (float(c.y) + 0.5) / float(size.y) >= ceiling_uv;
}

vec4 cell_value(ivec2 c, ivec2 size) {
	return cell_valid(c, size) ? texelFetch(state_tex, c, 0) : vec4(0.0);
}

void fragment() {
	ivec2 size = textureSize(state_tex, 0);
	ivec2 cell = ivec2(floor(UV * vec2(size)));
	vec4 mine = vec4(0.0);
	if (!reset && cell_valid(cell, size)) {
		int off = pass_kind % 2;
		ivec2 origin = ivec2(floor(vec2(cell - ivec2(off)) * 0.5)) * 2 + ivec2(off);
		int upper_y = gravity_up ? origin.y + 1 : origin.y;
		int lower_y = gravity_up ? origin.y : origin.y + 1;
		ivec2 pa = ivec2(origin.x, upper_y);
		ivec2 pb = ivec2(origin.x + 1, upper_y);
		ivec2 pc = ivec2(origin.x, lower_y);
		ivec2 pd = ivec2(origin.x + 1, lower_y);
		bool vc = cell_valid(pc, size);
		bool vd = cell_valid(pd, size);
		vec4 a = cell_value(pa, size);
		vec4 b = cell_value(pb, size);
		vec4 c = cell_value(pc, size);
		vec4 d = cell_value(pd, size);
		float spray = field_hash(vec2(origin) * 1.31 + vec2(field_time * 29.3 + float(pass_kind) * 5.7, 3.1));
		if (a.r > 0.5 && vc && c.r < 0.5) {
			if (vd && d.r < 0.5 && b.r < 0.5 && spray < fall_jitter) {
				d = a;
			} else {
				c = a;
			}
			a = vec4(0.0);
		}
		if (b.r > 0.5 && vd && d.r < 0.5) {
			if (vc && c.r < 0.5 && fract(spray * 3.7) < fall_jitter) {
				c = b;
			} else {
				d = b;
			}
			b = vec4(0.0);
		}
		bool solid_c = !vc || c.r > 0.5;
		bool solid_d = !vd || d.r > 0.5;
		bool slide_a = a.r > 0.5 && a.b < 0.5 && vd && d.r < 0.5 && solid_c;
		bool slide_b = b.r > 0.5 && b.b < 0.5 && vc && c.r < 0.5 && solid_d;
		float roll = field_hash(vec2(origin) + vec2(field_time * 61.7 + float(pass_kind) * 13.1, field_time * 17.3));
		if (slide_a && slide_b) {
			slide_a = roll < 0.5;
			slide_b = !slide_a;
		}
		if (fract(roll * 7.13) < slide_chance) {
			if (slide_a) {
				d = a;
				a = vec4(0.0);
			} else if (slide_b) {
				c = b;
				b = vec4(0.0);
			}
		}
		if (all(equal(cell, pa))) {
			mine = a;
		} else if (all(equal(cell, pb))) {
			mine = b;
		} else if (all(equal(cell, pc))) {
			mine = c;
		} else {
			mine = d;
		}
		if (pass_kind == 0) {
			vec2 cell_f = vec2(cell);
			if (mine.r > 0.5) {
				mine.b = max(mine.b - dry_step, 0.0);
				if (!gravity_up && cell.y == size.y - 1 && field_hash(cell_f + field_time * vec2(3.7, 9.1)) < drain) {
					mine = vec4(0.0);
				}
			}
			for (int index = 0; index < impulse_count; index++) {
				vec4 shape = impulse_shapes[index];
				vec4 payload = impulse_vectors[index];
				int stamp = int(payload.x + 0.5);
				float noise = field_hash(cell_f + vec2(field_time * 13.17 + float(index) * 3.1, field_time * 7.31));
				vec4 grain = vec4(1.0, payload.y, payload.z, field_hash(cell_f * 1.7 + vec2(field_time * 5.3, float(index))));
				if (stamp == 0) {
					vec2 delta = impulse_delta(UV, shape) * vec2(1.0, pour_squash);
					if (mine.r < 0.5 && dot(delta, delta) < shape.z * shape.z && noise < shape.w) {
						mine = grain;
					}
				} else if (stamp == 1) {
					if (mine.r < 0.5 && abs(UV.y - shape.y) < shape.z && noise < shape.w) {
						mine = grain;
					}
				} else if (stamp == 2) {
					if (mine.r > 0.5 && abs(UV.x - shape.x) < shape.z && UV.y >= shape.y) {
						mine.b = max(mine.b, payload.z);
					}
				}
			}
		}
	}
	COLOR = mine;
}
