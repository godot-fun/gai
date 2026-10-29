shader_type canvas_item;
render_mode blend_disabled;

// Conway's Game of Life on a torus. R = alive, G = afterglow trail, B = species tag (palette).
// Pass 0 runs one generation when step_now is set, decays trails, and stamps impulses: a
// pattern index of 0 sprinkles random soup, higher indices stamp a rotated pattern from the atlas.
// Later passes copy, so generation speed stays independent of the frame rate.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

uniform bool step_now = false;
uniform float trail_decay : hint_range(0.0, 1.0) = 0.94;
uniform sampler2D pattern_atlas : repeat_disable, filter_nearest;
// (x, y, width, height) in atlas texels; index 0 is unused (soup).
uniform vec4 pattern_rects[8];

vec4 cell_at(vec2 uv, vec2 cells) {
	return texture(state_tex, fract(uv + cells * texel));
}

bool pattern_alive(int pattern, ivec2 offset, int rotation, bool mirror) {
	vec4 rect = pattern_rects[pattern];
	ivec2 dims = ivec2(rect.zw);
	ivec2 local = offset;
	if (rotation == 1) {
		local = ivec2(offset.y, -offset.x);
	} else if (rotation == 2) {
		local = -offset;
	} else if (rotation == 3) {
		local = ivec2(-offset.y, offset.x);
	}
	if (mirror) {
		local.x = -local.x;
	}
	local += dims / 2;
	if (local.x < 0 || local.y < 0 || local.x >= dims.x || local.y >= dims.y) {
		return false;
	}
	return texelFetch(pattern_atlas, ivec2(rect.xy) + local, 0).r > 0.5;
}

void fragment() {
	if (reset) {
		COLOR = vec4(0.0);
	} else {
		vec4 s = texture(state_tex, UV);
		float alive = step(0.5, s.r);
		float tag = s.b;
		if (pass_kind == 0 && step_now) {
			int neighbors = 0;
			float tag_sum = 0.0;
			for (int dy = -1; dy <= 1; dy++) {
				for (int dx = -1; dx <= 1; dx++) {
					if (dx == 0 && dy == 0) {
						continue;
					}
					vec4 c = cell_at(UV, vec2(float(dx), float(dy)));
					if (c.r > 0.5) {
						neighbors += 1;
						tag_sum += c.b;
					}
				}
			}
			if (alive > 0.5) {
				alive = (neighbors == 2 || neighbors == 3) ? 1.0 : 0.0;
			} else if (neighbors == 3) {
				alive = 1.0;
				tag = tag_sum / 3.0;
			}
		}
		float trail = alive > 0.5 ? 1.0 : s.g * (pass_kind == 0 ? trail_decay : 1.0);
		if (pass_kind == 0) {
			vec2 cell = floor(UV / texel);
			for (int index = 0; index < impulse_count; index++) {
				vec4 shape = impulse_shapes[index];
				vec4 payload = impulse_vectors[index];
				int pattern = int(payload.x + 0.5);
				bool hit = false;
				if (pattern == 0) {
					float falloff = impulse_falloff(UV, shape);
					if (shape.w < 0.0) {
						if (falloff > 0.5) {
							alive = 0.0;
						}
						continue;
					}
					hit = field_hash(cell + vec2(field_time * 13.17, field_time * 7.31)) < shape.w * falloff;
				} else {
					ivec2 offset = ivec2(round((UV - shape.xy) / texel));
					hit = pattern_alive(pattern, offset, int(payload.y + 0.5) % 4, payload.w > 0.5);
				}
				if (hit) {
					alive = 1.0;
					trail = 1.0;
					tag = payload.z;
				}
			}
		}
		COLOR = vec4(alive, trail, tag, 1.0);
	}
}
