shader_type spatial;
render_mode unshaded, cull_back;
// CRT screen for the 3D monitors in the room. `screen_tex` is a live SubViewport texture.
// Barrel curvature, scanlines, soft glow and a gentle flicker.

uniform sampler2D screen_tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float brightness = 1.5;
uniform float curvature = 0.18;
uniform float scanlines = 60.0;
uniform float scan_strength = 0.35;
uniform float flicker = 0.035;
uniform float glow = 0.35;
uniform bool crt_enabled = true;
uniform float power_on = 1.0;

void fragment() {
	vec2 uv = UV;
	if (crt_enabled) {
		vec2 cc = uv - 0.5;
		uv = 0.5 + cc * (1.0 + dot(cc, cc) * curvature);
	}
	vec3 col = vec3(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		col = texture(screen_tex, uv).rgb;
		if (crt_enabled) {
			vec3 g = texture(screen_tex, uv + vec2(0.012, 0.0)).rgb
				+ texture(screen_tex, uv - vec2(0.012, 0.0)).rgb
				+ texture(screen_tex, uv + vec2(0.0, 0.016)).rgb
				+ texture(screen_tex, uv - vec2(0.0, 0.016)).rgb;
			col += g * 0.25 * glow;
			float s = 0.5 + 0.5 * sin(uv.y * scanlines * 6.28318);
			col *= 1.0 - scan_strength * s;
			col *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 47.0 + sin(TIME * 3.0) * 4.0));
			vec2 vg = uv - 0.5;
			col *= 1.0 - dot(vg, vg) * 1.4;
		}
		col *= tint.rgb;
		col += tint.rgb * 0.03;
	}
	ALBEDO = col * brightness * power_on;
}
