shader_type canvas_item;
// Full-screen post effect: film grain, vignette, chromatic aberration,
// VHS tracking noise, glitch and fade.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vhs : hint_range(0.0, 1.0) = 0.0;
uniform float anom : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float stat : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float tired : hint_range(0.0, 1.0) = 0.0;
uniform float dmg : hint_range(0.0, 1.0) = 0.0;
uniform float grain = 0.06;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	if (anom > 0.0) {
		uv.x += sin(uv.y * 13.0 + t * 2.1) * 0.005 * anom;
		uv.y += sin(uv.x * 9.0 + t * 1.6) * 0.003 * anom;
	}
	float ln = floor(uv.y * res.y / 3.0);
	float jit = h(vec2(ln, floor(t * 24.0))) - 0.5;
	float tp = fract(t * 0.055 + 0.3);
	float band = smoothstep(0.05, 0.0, abs(uv.y - tp));
	uv.x += vhs * (jit * 0.002 + band * 0.02 * (h(vec2(uv.y * 90.0, t)) - 0.5));
	uv.x += glitch * (h(vec2(floor(uv.y * 22.0), floor(t * 30.0))) - 0.5) * 0.14;
	float ca = 0.001 + vhs * 0.003 + glitch * 0.012 + tired * 0.003 + dmg * 0.005;
	vec3 c = vec3(texture(screen_tex, uv + vec2(ca, 0.0)).r, texture(screen_tex, uv).g, texture(screen_tex, uv - vec2(ca, 0.0)).b);
	if (tired > 0.0) {
		vec3 b2 = textureLod(screen_tex, uv, 2.5 * tired).rgb;
		c = mix(c, b2, tired * 0.7);
	}
	if (vhs > 0.0) {
		vec3 b = textureLod(screen_tex, uv + vec2(0.004, 0.0), 1.5).rgb;
		c = mix(c, (c + b) * 0.5, vhs * 0.5);
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, mix(vec3(l), c, 0.72) * vec3(1.07, 1.0, 0.86), vhs);
		c += band * vhs * 0.15 * h(vec2(uv.x * 400.0, t));
		c *= 1.0 - vhs * 0.08 * (0.5 + 0.5 * sin(SCREEN_UV.y * res.y * 2.1));
		c = mix(c, c * 1.1 + 0.015, vhs * 0.6);
	}
	if (anom > 0.0) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(l * 1.7, l * 0.32, l * 0.28) + vec3(0.03, 0.0, 0.0), anom * 0.78);
	}
	float n = h(SCREEN_UV * res + fract(t * 7.0) * 91.0);
	c += (n - 0.5) * (grain + vhs * 0.05);
	float v = smoothstep(0.88 - tired * 0.2, 0.2, length((SCREEN_UV - 0.5) * vec2(1.0, 0.86)));
	c *= mix(0.25, 1.0, v);
	c = mix(c, vec3(0.5, 0.0, 0.0), dmg * (1.0 - v) * 0.85);
	c = mix(c, vec3(n * 0.85), clamp(stat, 0.0, 1.0));
	c *= 1.0 - fade;
	COLOR = vec4(c, 1.0);
}
