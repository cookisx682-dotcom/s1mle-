shader_type canvas_item;
// Procedural cork texture for the evidence board.

uniform vec4 base_color : source_color = vec4(0.55, 0.37, 0.2, 1.0);
uniform vec2 cells = vec2(320.0, 180.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * cells);
	float n = hash(p);
	float n2 = hash(floor(UV * cells * 0.25) + 17.0);
	vec3 c = base_color.rgb * (0.78 + 0.3 * n) * (0.9 + 0.15 * n2);
	if (n > 0.94) {
		c *= 0.55;
	}
	vec2 v = UV - 0.5;
	c *= 1.0 - dot(v, v) * 0.6;
	COLOR = vec4(c, 1.0);
}
