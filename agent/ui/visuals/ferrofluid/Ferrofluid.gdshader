shader_type canvas_item;

// Ferrofluid: a glossy black pool along the bottom edge, raised into Rosensweig spikes that lean
// toward the magnet. A tapered tendril reaches up toward a tool and droplets fly free on failure;
// every shape blends into the pool through a smooth union. The surface mirrors the interface
// above it. Zero pool, tendril and droplets is an identity pass.

const int MAX_DROPLETS = 8;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float field_time = 0.0;
uniform float pool_px = 0.0;
uniform float spike_px = 0.0;
uniform float spike_spacing_px = 32.0;
uniform float magnet_x = 0.5;
uniform float magnet_width = 0.16;
uniform float magnet_strength = 0.0;
uniform float lean_px = 12.0;
uniform float chaos : hint_range(0.0, 1.0) = 0.0;
// xy = base UV, zw = tip UV.
uniform vec4 tendril = vec4(0.5, 1.0, 0.5, 1.0);
uniform float tendril_width_px = 26.0;
uniform int droplet_count = 0;
// xy = UV, z = radius px.
uniform vec4 droplets[8];
uniform vec4 fluid_color : source_color = vec4(0.015, 0.016, 0.02, 1.0);
uniform vec4 rim_color : source_color = vec4(0.35, 0.55, 1.0, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float reflection_gain : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_gain : hint_range(0.0, 1.0) = 0.35;
// Accent glow behind the silhouette; black fluid on a dark interface needs it to read at all.
uniform float backlight_gain : hint_range(0.0, 1.0) = 0.0;

float hash11(float n) {
	return fract(sin(n * 127.1 + 11.7) * 43758.5453);
}

float smooth_min(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float magnet_pull(float x_px, float width_px) {
	float delta = (x_px / width_px - magnet_x) / magnet_width;
	return exp(-delta * delta);
}

// Height of the pool surface above the bottom edge, in px.
float surface_height(float x, float width_px) {
	float base = pool_px * (1.0 + 0.9 * magnet_pull(x, width_px) * magnet_strength);
	float cell = floor(x / spike_spacing_px);
	float spikes = 0.0;
	for (int offset = -1; offset <= 1; offset++) {
		float k = cell + float(offset);
		float h = hash11(k * 1.7 + 3.0);
		float center = (k + 0.5 + (h - 0.5) * 0.3) * spike_spacing_px;
		float pull = magnet_pull(center, width_px);
		float wobble = 1.0 + 0.1 * sin(field_time * 5.0 + k * 1.9) + chaos * 0.7 * sin(field_time * 23.0 + k * 7.3);
		float amplitude = spike_px * (0.22 + 0.78 * pull) * (0.8 + 0.4 * h) * max(wobble, 0.0);
		float t = clamp(1.0 - abs(x - center) / (spike_spacing_px * 0.62), 0.0, 1.0);
		spikes = max(spikes, amplitude * pow(t, 2.2));
	}
	return base + spikes;
}

// Signed distance to the fluid in px, negative inside.
float fluid_distance(vec2 p, vec2 viewport_px) {
	float above_bottom = viewport_px.y - p.y;
	float lean = clamp((magnet_x * viewport_px.x - p.x) / (viewport_px.x * 0.3), -1.0, 1.0) * lean_px * magnet_strength;
	float sheared_x = p.x - lean * above_bottom / max(spike_px + pool_px, 1.0);
	float distance_px = above_bottom - surface_height(sheared_x, viewport_px.x);
	if (pool_px <= 0.01) {
		distance_px = 1e4;
	}

	vec2 base = tendril.xy * viewport_px;
	vec2 tip = tendril.zw * viewport_px;
	vec2 along = tip - base;
	float reach = length(along);
	if (reach > 1.0) {
		float t = clamp(dot(p - base, along) / (reach * reach), 0.0, 1.0);
		vec2 side = vec2(-along.y, along.x) / reach;
		vec2 spine = base + along * t + side * sin(t * 9.0 - field_time * 6.0) * 5.0 * t;
		float radius = mix(tendril_width_px, tendril_width_px * 0.2, t);
		distance_px = smooth_min(distance_px, length(p - spine) - radius, 16.0);
	}
	for (int index = 0; index < MAX_DROPLETS; index++) {
		if (index >= droplet_count) {
			break;
		}
		vec4 drop = droplets[index];
		distance_px = smooth_min(distance_px, length(p - drop.xy * viewport_px) - drop.z, 9.0);
	}
	return distance_px;
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * viewport_px;
	vec3 result = source;
	float reach_px = viewport_px.y - p.y;
	bool near_pool = reach_px < pool_px * 2.0 + spike_px + lean_px + 40.0;
	bool near_tendril = length(tendril.zw - tendril.xy) > 0.001;
	if (near_pool || near_tendril || droplet_count > 0) {
		float d = fluid_distance(p, viewport_px);
		if (d < 40.0) {
			float shadow = exp(-max(d, 0.0) / 10.0) * shadow_gain;
			result *= 1.0 - shadow;
			result += rim_color.rgb * exp(-max(d, 0.0) / 9.0) * backlight_gain;
			if (d < 2.0) {
				vec2 gradient = vec2(fluid_distance(p + vec2(1.0, 0.0), viewport_px) - d, fluid_distance(p + vec2(0.0, 1.0), viewport_px) - d);
				vec2 outward = gradient / max(length(gradient), 0.0001);
				float depth = clamp(-d / 22.0, 0.0, 1.0);
				vec3 normal = normalize(vec3(outward * (1.0 - depth * 0.85), 0.18 + depth));
				vec3 mirrored = reflect(vec3(0.0, 0.0, -1.0), normal);
				float key = pow(max(dot(mirrored, normalize(vec3(-0.4, -0.7, 0.6))), 0.0), 60.0);
				float fill = pow(max(dot(mirrored, normalize(vec3(0.6, -0.5, 0.62))), 0.0), 14.0);
				float fresnel = pow(1.0 - normal.z, 2.4);
				// Chrome reads as a horizon: facets facing up mirror the lit room, facets facing down stay black.
				float sky = smoothstep(0.25, -0.85, mirrored.y);
				vec2 reflect_uv = clamp(SCREEN_UV + vec2(normal.x * 0.06, -0.05 - abs(normal.y) * 0.16), vec2(0.0), vec2(1.0));
				vec3 mirror = texture(screen_texture, reflect_uv).rgb;
				vec3 fluid = fluid_color.rgb + mirror * reflection_gain * (0.2 + 0.8 * fresnel) * (0.4 + 0.6 * sky);
				fluid += mix(vec3(0.16, 0.17, 0.2), rim_color.rgb * 0.55, 0.5) * sky * fresnel * 0.9;
				fluid += rim_color.rgb * fill * 0.55;
				fluid += rim_color.rgb * exp(d / 1.6) * (0.25 + backlight_gain);
				fluid += highlight_color.rgb * key;
				float coverage = 1.0 - smoothstep(-0.75, 0.75, d);
				result = mix(result, fluid, coverage);
			}
		}
	}
	COLOR = vec4(result, 1.0);
}
