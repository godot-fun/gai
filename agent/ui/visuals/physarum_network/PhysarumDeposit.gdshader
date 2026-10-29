shader_type canvas_item;
render_mode blend_add;

// One point per agent. The vertex reads the agent's position from the agent texture; the mesh
// node is scaled to the trail size, so VERTEX stays in unit space.
uniform sampler2D agent_tex : repeat_disable, filter_nearest;
uniform float deposit = 0.5;

void vertex() {
	VERTEX = textureLod(agent_tex, UV, 0.0).xy;
}

void fragment() {
	COLOR = vec4(deposit, 0.0, 0.0, 1.0);
}
