shader_type canvas_item;

// Lava lamp metaballs over the live interface. The field sum r^2/d^2 crosses 1 at the wax
// surface; its gradient gives a fake normal used to refract the screen like a liquid lens, add a
// specular glint, and brighten the fresnel rim. Colors blend between nearby blobs by influence.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float presence : hint_range(0.0, 1.0) = 0.0;
uniform int blob_count = 0;
// (uv.x, uv.y, radius in viewport-height units, hue tag)
uniform vec4 blobs[12];
// (error, glow, 0, 0)
uniform vec4 blob_fx[12];
uniform float light_mode : hint_range(0.0, 1.0) = 0.0;
uniform float hue_spread = 0.5;
uniform float refraction_px = 26.0;
uniform float wax_opacity : hint_range(0.0, 1.0) = 0.62;
uniform vec4 accent_color : source_color = vec4(1.0, 0.45, 0.25, 1.0);
uniform vec4 error_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * viewport_px;
	vec3 result = source;
	if (presence > 0.001 && blob_count > 0) {
		float field = 0.0;
		vec2 grad = vec2(0.0);
		float weight_sum = 0.0;
		vec3 color_sum = vec3(0.0);
		float glow_sum = 0.0;
		vec3 accent_hsv = rgb_to_hsv(accent_color.rgb);
		for (int index = 0; index < blob_count; index++) {
			vec4 blob = blobs[index];
			vec2 delta = p - blob.xy * viewport_px;
			float d2 = dot(delta, delta) + 1.0;
			float radius_px = blob.z * viewport_px.y;
			float r2 = radius_px * radius_px;
			float influence = r2 / d2;
			field += influence;
			grad += -2.0 * r2 * delta / (d2 * d2);
			float weight = influence * influence;
			vec3 hsv = accent_hsv;
			hsv.x = fract(hsv.x + (blob.w - 0.5) * hue_spread);
			hsv.y = clamp(max(hsv.y, 0.55), 0.0, 1.0);
			vec3 wax = mix(hsv_to_rgb(hsv), error_color.rgb, blob_fx[index].x);
			color_sum += wax * weight;
			glow_sum += blob_fx[index].y * weight;
			weight_sum += weight;
		}
		vec3 wax = color_sum / max(weight_sum, 1e-6);
		float glow = glow_sum / max(weight_sum, 1e-6);
		float aa = max(fwidth(field), 1e-4);
		float inside = clamp((field - 1.0) / aa + 0.5, 0.0, 1.0);
		vec3 normal = normalize(vec3(-grad * 46.0, 1.0));
		float thickness = clamp((field - 1.0) * 0.7, 0.0, 1.0);
		vec2 offset = normal.xy * refraction_px * inside;
		vec3 refracted = texture(screen_texture, clamp(SCREEN_UV - offset * SCREEN_PIXEL_SIZE, vec2(0.0), vec2(1.0))).rgb;
		vec3 light_dir = normalize(vec3(-0.45, -0.65, 0.62));
		float spec = pow(max(dot(normal, light_dir), 0.0), 36.0);
		float fresnel = pow(1.0 - normal.z, 2.0);
		vec3 core = mix(wax * 0.72, wax, thickness);
		vec3 blob_color;
		if (light_mode > 0.5) {
			blob_color = mix(refracted, core, wax_opacity + thickness * 0.2);
			blob_color = mix(blob_color, wax * 0.6, fresnel * 0.5);
			blob_color += vec3(spec * 0.7);
		} else {
			blob_color = mix(refracted, core, wax_opacity + thickness * 0.2);
			blob_color += wax * fresnel * 0.55 + vec3(spec * 0.9) + wax * glow * 0.5;
		}
		result = mix(source, blob_color, inside);
		if (light_mode < 0.5) {
			float halo = smoothstep(0.35, 1.0, field) * (1.0 - inside);
			result += wax * halo * (0.16 + glow * 0.3);
		}
		result = mix(source, result, presence);
	}
	COLOR = vec4(result, 1.0);
}
