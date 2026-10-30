shader_type spatial;

uniform vec3 color_1 : source_color = vec3(0, 0.12, 0.27);
uniform vec3 color_2 : source_color = vec3(0.63, 0.78, 1);
uniform float alpha : hint_range(0, 1) = 0.3;
uniform float amount : hint_range(0, 10) = 4.5;
uniform float intensity : hint_range(0, 10) = 4.0;
uniform bool emit = false;

vec3 fresnel_glow(vec3 normal, vec3 view) {
	return pow((1.0 - dot(normalize(normal), normalize(view))), amount) * color_2 * intensity;
}

void fragment() {
	vec3 fresnel = fresnel_glow(NORMAL, VIEW);
	if(emit) {
		EMISSION = fresnel.rgb;
	}
	ALBEDO = color_1 + fresnel;
	ALPHA = alpha;
}