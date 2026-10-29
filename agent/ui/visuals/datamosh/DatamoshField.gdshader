shader_type canvas_item;
render_mode blend_disabled;

// Datamosh field: the last displayed frame dragged along per-macroblock motion vectors, as a
// video decoder would when P-frames keep arriving without a keyframe. Pass 0 drags the previous
// root frame; later passes copy. Motion vectors are whole pixels so dragged text stays crisp.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"

const int PASS_DRAG = 0;
const int MAX_SOURCES = 4;

uniform sampler2D previous_frame_tex : repeat_disable, filter_nearest;
uniform vec2 viewport_px = vec2(1280.0, 720.0);
uniform float block_px = 16.0;
uniform float drift_px = 0.0;
uniform float jitter_px = 0.0;
uniform float block_seed = 0.0;
uniform int source_count = 0;
// xy = UV, z = radius in viewport-height units, w = stuck-block boost.
uniform vec4 source_shapes[4];
// x = swirl px per frame (signed), y = outward burst px per frame.
uniform vec4 source_motion[4];

vec2 block_motion(vec2 uv) {
	vec2 block = floor(uv * viewport_px / block_px);
	vec2 center = (block + 0.5) * block_px / viewport_px;
	float h1 = field_hash(block + vec2(block_seed * 13.0, 0.0));
	float h2 = field_hash(block.yx + vec2(5.3, block_seed * 7.0));
	vec2 motion = vec2((h2 - 0.5) * 0.6 * drift_px, drift_px * (0.55 + 0.9 * h1));
	motion += (vec2(h1, h2) - 0.5) * 2.0 * jitter_px;
	float view_aspect = viewport_px.x / max(viewport_px.y, 1.0);
	for (int index = 0; index < MAX_SOURCES; index++) {
		if (index >= source_count) {
			break;
		}
		vec2 delta = (center - source_shapes[index].xy) * vec2(view_aspect, 1.0);
		float radius = max(source_shapes[index].z, 0.001);
		float falloff = exp(-dot(delta, delta) / (radius * radius));
		vec2 outward = delta / max(length(delta), 0.0001);
		motion += (vec2(-outward.y, outward.x) * source_motion[index].x + outward * source_motion[index].y) * falloff;
	}
	return motion;
}

void fragment() {
	if (pass_kind == PASS_DRAG) {
		vec2 motion = round(block_motion(UV));
		vec2 from = clamp(UV - motion / viewport_px, vec2(0.0), vec2(1.0));
		COLOR = vec4(texture(previous_frame_tex, from).rgb, 1.0);
	} else {
		COLOR = vec4(state_at(UV).rgb, 1.0);
	}
}
