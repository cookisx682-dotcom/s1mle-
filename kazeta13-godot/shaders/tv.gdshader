shader_type spatial;
render_mode unshaded;
// CRT screen: 0 = off, 1 = static, 2 = feed texture
uniform sampler2D feed : source_color, filter_linear;
uniform float mode = 1.0;
uniform float on = 1.0;
uniform float gain = 1.4;
uniform float pan = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 cc = UV - 0.5;
	vec2 uv = 0.5 + cc * (1.0 + dot(cc, cc) * 0.3);
	vec3 c = vec3(0.0);
	float n = h(floor(uv * vec2(170.0, 128.0)) + floor(TIME * 30.0) * 1.7);
	if (mode > 0.5 && mode < 1.5) {
		c = vec3(n) * 0.75 + 0.04;
		float r = fract(TIME * 0.25);
		c *= 0.75 + 0.25 * smoothstep(0.12, 0.0, abs(uv.y - r));
	} else if (mode > 1.5) {
		float j = (h(vec2(floor(uv.y * 120.0), floor(TIME * 20.0))) - 0.5) * 0.006;
		vec2 fu = vec2(uv.x + j, uv.y);
		fu = 0.5 + (fu - 0.5) * (0.92 - pan * 0.08) + vec2(pan * 0.03, 0.0);
		c = texture(feed, fu).rgb * gain + 0.035 + (n - 0.5) * 0.14;
		float l = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(vec3(l), c, 0.8);
	}
	c *= 0.82 + 0.18 * sin(uv.y * 520.0);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) c = vec3(0.0);
	c *= smoothstep(0.78, 0.32, length(cc));
	ALBEDO = c * on * 1.4;
}
