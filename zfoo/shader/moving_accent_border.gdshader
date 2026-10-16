shader_type canvas_item;
render_mode blend_mix;

uniform vec4 accent_color : source_color = vec4(0.35, 0.55, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float corner_radius : hint_range(0.0, 256.0) = 16.0;
uniform float beam_speed : hint_range(0.0, 2.0) = 0.42;
uniform float beam_span : hint_range(0.05, 0.5) = 0.2;
uniform vec2 rect_size = vec2(400.0, 88.0);
uniform float edge_pad : hint_range(0.0, 24.0) = 4.0;

const float BORDER_W = 2.0;
const float GLOW_W = 5.0;
const float HALF_PI = 1.5707963267948966;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float rounded_perimeter(vec2 size, float radius) {
	float r = min(radius, min(size.x, size.y) * 0.5);
	return 2.0 * (size.x + size.y - 4.0 * r) + TAU * r;
}

// Top-left origin, clockwise from (r, 0).
float perimeter_at_circle(vec2 pt, vec2 size, float r) {
	vec2 center = size * 0.5;
	float ang = atan(pt.y - center.y, pt.x - center.x);
	float theta = ang + HALF_PI;
	if (theta < 0.0) {
		theta += TAU;
	}
	return theta * r;
}

float perimeter_at(vec2 pt, vec2 size, float rad) {
	float w = size.x;
	float h = size.y;
	float r = min(rad, min(w, h) * 0.5);
	float top = w - 2.0 * r;
	float side = h - 2.0 * r;
	float arc = HALF_PI * r;
	float x = pt.x;
	float y = pt.y;
	float edge = max(1.0, min(w, h) * 0.004);

	if (top <= edge && side <= edge) {
		return perimeter_at_circle(pt, size, r);
	}

	if (y <= edge && x >= r - edge && x <= w - r + edge) {
		return x - r;
	}
	if (y <= edge && x > w - r + edge) {
		vec2 d = pt - vec2(w - r, r);
		float ang = atan(d.y, d.x);
		ang = clamp(ang, -HALF_PI, 0.0);
		return top + (ang + HALF_PI) / HALF_PI * arc;
	}
	if (y <= edge && x < r - edge) {
		vec2 d = pt - vec2(r, r);
		float ang = atan(d.y, d.x);
		ang = clamp(ang, 3.141592653589793, 3.141592653589793 + HALF_PI);
		return top + arc + side + arc + top + arc + side + (ang - 3.141592653589793) * r;
	}
	if (x >= w - r - edge && y >= edge && y <= r + edge) {
		vec2 d = pt - vec2(w - r, r);
		if (dot(d, d) <= (r + edge * 2.0) * (r + edge * 2.0)) {
			float ang = atan(d.y, d.x);
			ang = clamp(ang, -HALF_PI, 0.0);
			return top + (ang + HALF_PI) / HALF_PI * arc;
		}
	}
	if (x >= w - edge && y >= r - edge && y <= h - r + edge) {
		return top + arc + (y - r);
	}
	if (x >= w - r - edge && y >= h - r - edge && y <= h + edge) {
		vec2 d = pt - vec2(w - r, h - r);
		if (dot(d, d) <= (r + edge * 2.0) * (r + edge * 2.0)) {
			float ang = atan(d.y, d.x);
			ang = clamp(ang, 0.0, HALF_PI);
			return top + arc + side + ang * r;
		}
	}
	if (y >= h - edge && x >= r - edge && x <= w - r + edge) {
		return top + arc + side + arc + (w - r - x);
	}
	if (x <= r + edge && y >= h - r - edge && y <= h + edge) {
		vec2 d = pt - vec2(r, h - r);
		if (dot(d, d) <= (r + edge * 2.0) * (r + edge * 2.0)) {
			float ang = atan(d.y, d.x);
			ang = clamp(ang, HALF_PI, 3.141592653589793);
			return top + arc + side + arc + top + (ang - HALF_PI) * r;
		}
	}
	if (x <= edge && y >= r - edge && y <= h - r + edge) {
		return top + arc + side + arc + top + arc + (h - r - y);
	}
	if (x <= r + edge && y <= r + edge && y > edge) {
		vec2 d = pt - vec2(r, r);
		if (dot(d, d) <= (r + edge * 2.0) * (r + edge * 2.0)) {
			float ang = atan(d.y, d.x);
			ang = clamp(ang, 3.141592653589793, 3.141592653589793 + HALF_PI);
			return top + arc + side + arc + top + arc + side + (ang - 3.141592653589793) * r;
		}
	}
	return top + arc + side + arc + top + arc + side;
}

void fragment() {
	vec2 wrap_size = max(rect_size - vec2(edge_pad * 2.0), vec2(2.0));
	vec2 half_size = wrap_size * 0.5;
	float r = min(corner_radius, min(wrap_size.x, wrap_size.y) * 0.5);
	vec2 p = (UV - 0.5) * rect_size;

	float d = sd_rounded_box(p, half_size, r);
	float abs_d = abs(d);
	COLOR = vec4(0.0);

	if (abs_d <= GLOW_W * 0.5 + 1.0) {
		vec2 grad = normalize(vec2(dFdx(d), dFdy(d)));
		vec2 on_edge_tl = p - grad * d + half_size;

		float perim = rounded_perimeter(wrap_size, r);
		float along = perimeter_at(on_edge_tl, wrap_size, r);
		float head = fract(TIME * beam_speed);
		// Distance backward along perimeter from the moving head (tail behind, head at u=0).
		float u = fract(head - along / perim + 1.0);

		float beam_alpha = 0.0;
		if (u <= beam_span) {
			float t = 1.0 - u / beam_span;
			beam_alpha = pow(t, 1.6) * strength;
		}

		float edge_alpha = smoothstep(GLOW_W * 0.5, BORDER_W * 0.5, abs_d);
		float glow_alpha = (1.0 - smoothstep(BORDER_W * 0.5, GLOW_W * 0.5, abs_d)) * beam_alpha * 0.35;
		float core_alpha = edge_alpha * beam_alpha * 0.95;

		vec3 core_rgb = accent_color.rgb * 1.08;
		vec3 glow_rgb = accent_color.rgb;
		float alpha = max(core_alpha, glow_alpha);
		COLOR = vec4(mix(glow_rgb, core_rgb, core_alpha / max(alpha, 0.001)), alpha);
	}
}
