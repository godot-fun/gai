shader_type canvas_item;

// Screen-space overlay for the solar system: orbit rings plus the tool lock-on reticles.
// Every orbit is a circle lying in its own world plane; each pixel casts a ray, intersects that
// plane, and measures the radial error in screen pixels. The analytic coverage stays continuous
// below one pixel, where an antialiased polyline breaks into dots. Reticles use the same
// subpixel stroke, so a locked planet gets a crisp hairline bracket instead of a blurred sprite.

const int MAX_ORBITS = 8;
const int MAX_RETICLES = 4;

uniform vec3 camera_position = vec3(0.0, 6.4, 13.0);
uniform mat3 camera_basis = mat3(1.0);
// Inverse of the projection's diagonal: turns a normalized device coordinate into a view ray.
uniform vec2 ndc_scale = vec2(1.0, 1.0);
uniform vec4 line_color : source_color = vec4(0.45, 0.62, 1.0, 0.35);
// Stroke width in screen pixels; below 1 the coverage dims instead of breaking up.
uniform float line_width = 0.35;
uniform int orbit_count = 0;
uniform vec3 orbit_normals[MAX_ORBITS];
uniform float orbit_radii[MAX_ORBITS];
// Per-orbit screen bounding box in normalized window coordinates (xy = min, zw = max) for early out.
uniform vec4 orbit_bounds[MAX_ORBITS];
// xy = centre in normalized window coordinates, z = ring radius in pixels, w = opacity.
uniform vec4 reticles[MAX_RETICLES];
uniform vec3 reticle_colors[MAX_RETICLES];
uniform int reticle_count = 0;
// Slow spin of the bracket set, in radians.
uniform float reticle_rotation = 0.0;

// Reticles are read as a lock-on, not as a hairline, so their stroke is a little heavier.
const float RETICLE_STROKE_SCALE = 1.8;

// Antialiased hairline coverage for a radial distance measured in screen pixels.
float stroke_coverage(float distance_pixels, float radius_pixels, float width_pixels) {
	return clamp(width_pixels * 0.5 + 0.5 - abs(distance_pixels - radius_pixels), 0.0, 1.0);
}

// Four bracket arcs plus four short radial ticks, rotated by the shader so the lock-on breathes.
float reticle_coverage(vec2 offset_pixels, float radius_pixels) {
	float distance_pixels = length(offset_pixels);
	float angle = degrees(atan(offset_pixels.y, offset_pixels.x) - reticle_rotation);
	float band = stroke_coverage(distance_pixels, radius_pixels, line_width * RETICLE_STROKE_SCALE);
	// Bracket arcs straddle the diagonals; the radial ticks sit on the axes, between them.
	float to_bracket = abs(mod(angle, 90.0) - 45.0);
	float brackets = 1.0 - smoothstep(23.0, 25.0, to_bracket);
	float ticks = (1.0 - smoothstep(0.9, 2.0, abs(mod(angle + 45.0, 90.0) - 45.0)))
			* step(distance_pixels, radius_pixels - 1.5) * step(radius_pixels - 8.0, distance_pixels);
	return max(band * brackets, ticks);
}

void fragment() {
	vec2 uv = FRAGCOORD.xy * SCREEN_PIXEL_SIZE;
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	vec3 view_dir = normalize(vec3(ndc.x * ndc_scale.x, ndc.y * ndc_scale.y, -1.0));
	vec3 ray_dir = normalize(camera_basis * view_dir);
	float coverage = 0.0;
	for (int index = 0; index < MAX_ORBITS; index++) {
		if (index >= orbit_count) {
			break;
		}
		vec4 bounds = orbit_bounds[index];
		if (uv.x < bounds.x || uv.y < bounds.y || uv.x > bounds.z || uv.y > bounds.w) {
			continue;
		}
		vec3 normal = orbit_normals[index];
		float denominator = dot(normal, ray_dir);
		if (abs(denominator) < 0.0001) {
			continue;
		}
		// Orbit planes pass through the system origin.
		float travel = -dot(normal, camera_position) / denominator;
		if (travel <= 0.0) {
			continue;
		}
		vec3 hit = camera_position + ray_dir * travel;
		vec3 axis_u = normalize(cross(normal, vec3(0.0, 0.0, 1.0)));
		vec3 axis_v = cross(normal, axis_u);
		float radius = length(vec2(dot(hit, axis_u), dot(hit, axis_v)));
		float error_world = abs(radius - orbit_radii[index]);
		float error_pixels = error_world / max(fwidth(radius), 0.00001);
		coverage = max(coverage, stroke_coverage(error_pixels, 0.0, line_width));
	}
	vec3 out_color = line_color.rgb;
	float out_alpha = line_color.a * coverage;
	// Neighbouring reticles never overlap, so the brightest one wins without extra blending.
	for (int index = 0; index < MAX_RETICLES; index++) {
		if (index >= reticle_count) {
			break;
		}
		vec4 reticle = reticles[index];
		vec2 offset_pixels = (uv - reticle.xy) / SCREEN_PIXEL_SIZE;
		if (length(offset_pixels) < reticle.z - 9.0) {
			continue;
		}
		float ring_alpha = reticle_coverage(offset_pixels, reticle.z) * reticle.w;
		if (ring_alpha > out_alpha) {
			out_alpha = ring_alpha;
			out_color = reticle_colors[index];
		}
	}
	if (out_alpha <= 0.002) {
		discard;
	}
	COLOR = vec4(out_color, out_alpha);
}
