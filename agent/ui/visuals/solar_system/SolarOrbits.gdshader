shader_type canvas_item;

// Screen-space orbit rings. Every orbit is a circle lying in its own world plane; each pixel casts
// a ray, intersects that plane, and measures the radial error in screen pixels. The analytic
// coverage stays continuous below one pixel, where an antialiased polyline breaks into dots.

const int MAX_ORBITS = 8;

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
		coverage = max(coverage, clamp(line_width * 0.5 + 0.5 - error_pixels, 0.0, 1.0));
	}
	if (coverage <= 0.002) {
		discard;
	}
	COLOR = vec4(line_color.rgb, line_color.a * coverage);
}
