shader_type canvas_item;
render_mode blend_disabled;

// Sand on a vibrating plate. R = sand density, G = local agitation.
// Sand slides down the gradient of the squared amplitude toward the nodal lines and is kicked
// around where the plate shakes. Every face carries one upwind flux shared by both cells, so the
// flow moves sand without creating or losing it. The window edges are walls.
#include "res://agent/ui/visuals/simulation/SimulationField.gdshaderinc"
#include "res://agent/ui/visuals/chladni_plate/ChladniMode.gdshaderinc"

uniform float drive : hint_range(0.0, 1.0) = 0.0;
uniform float scatter : hint_range(0.0, 1.0) = 0.0;
uniform float mobility = 6.0;
uniform float kick = 0.12;
uniform float agitation_decay : hint_range(0.9, 1.0) = 0.992;

// Outflow through four faces stays at most 4 * (speed + diffusion) <= 1, keeping sand positive.
const float MAX_FACE_SPEED = 0.2;
const float MAX_FACE_DIFFUSION = 0.05;
const float MAX_SAND = 14.0;
// Low modes have gentle slopes; scaling the pull by this over the wave number lets every figure
// gather in about the same time.
const float REFERENCE_FREQUENCY = 6.0;

bool is_wall(vec2 uv) {
	return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

float face_noise(vec2 face) {
	return field_hash(face + vec2(fract(field_time * 7.31) * 97.0, fract(field_time * 3.17) * 61.0)) * 2.0 - 1.0;
}

// Sand leaving the cell through one face; negative when sand arrives.
float face_outflow(vec2 uv, vec4 here, vec2 cells, float here_amplitude, vec2 face, float axis_sign) {
	vec2 there_uv = uv + cells * texel;
	if (is_wall(there_uv)) {
		return 0.0;
	}
	vec4 there = state_at(there_uv);
	float there_amplitude = plate_amplitude(there_uv, aspect);
	float shake = 0.5 * (abs(here_amplitude) + abs(there_amplitude)) * drive;
	float agitation = 0.5 * (here.g + there.g);
	float slope = there_amplitude * there_amplitude - here_amplitude * here_amplitude;
	float jolt = face_noise(face) * axis_sign * (kick * shake + agitation * 0.15 + scatter * 0.12);
	float pull = mobility * REFERENCE_FREQUENCY / plate_frequency();
	float speed = clamp(-pull * drive * slope + jolt, -MAX_FACE_SPEED, MAX_FACE_SPEED);
	float diffusion = min(0.01 * drive + agitation * 0.04 + scatter * 0.04, MAX_FACE_DIFFUSION);
	float advected = speed > 0.0 ? speed * here.r : speed * there.r;
	return advected + diffusion * (here.r - there.r);
}

void fragment() {
	vec2 cell = floor(UV / texel);
	if (reset) {
		COLOR = vec4(0.8 + field_hash(cell) * 0.3, 0.0, 0.0, 1.0);
	} else {
		vec4 here = state_at(UV);
		float amplitude = plate_amplitude(UV, aspect);
		float outflow = face_outflow(UV, here, vec2(1.0, 0.0), amplitude, cell + vec2(0.5, 0.0), 1.0)
			+ face_outflow(UV, here, vec2(-1.0, 0.0), amplitude, cell + vec2(-0.5, 0.0), -1.0)
			+ face_outflow(UV, here, vec2(0.0, 1.0), amplitude, cell + vec2(0.0, 0.5), 1.0)
			+ face_outflow(UV, here, vec2(0.0, -1.0), amplitude, cell + vec2(0.0, -0.5), -1.0);
		float sand = here.r - outflow;
		float agitation = here.g * agitation_decay;
		for (int index = 0; index < impulse_count; index++) {
			float falloff = impulse_falloff(UV, impulse_shapes[index]);
			agitation += impulse_shapes[index].w * falloff;
			sand += impulse_vectors[index].x * falloff;
		}
		COLOR = vec4(clamp(sand, 0.0, MAX_SAND), clamp(agitation, 0.0, 1.0), 0.0, 1.0);
	}
}
