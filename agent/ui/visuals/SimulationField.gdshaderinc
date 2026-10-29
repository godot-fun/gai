// Shared uniforms for SimulationChain passes. Only pass 0 receives impulses each frame.
// shape = (uv.x, uv.y, radius in field-height units, amount); vector = effect-defined payload.
uniform sampler2D state_tex : repeat_disable, filter_linear;
uniform vec2 texel = vec2(0.004);
uniform int pass_kind = 0;
uniform bool reset = false;
uniform float aspect = 1.0;
uniform float field_time = 0.0;
uniform int impulse_count = 0;
uniform vec4 impulse_shapes[16];
uniform vec4 impulse_vectors[16];

vec4 state_at(vec2 uv) {
	return texture(state_tex, clamp(uv, texel * 0.5, vec2(1.0) - texel * 0.5));
}

vec4 state_offset(vec2 uv, vec2 cells) {
	return state_at(uv + cells * texel);
}

vec2 impulse_delta(vec2 uv, vec4 shape) {
	return (uv - shape.xy) * vec2(aspect, 1.0);
}

float impulse_falloff(vec2 uv, vec4 shape) {
	vec2 delta = impulse_delta(uv, shape);
	float radius = max(shape.z, 0.0001);
	return exp(-dot(delta, delta) / (radius * radius));
}

float field_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
