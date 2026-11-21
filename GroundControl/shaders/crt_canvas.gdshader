shader_type canvas_item;
// CRT look for 2D screens (station overlays rendered through a SubViewportContainer).
// Light curvature so the mouse still lines up with buttons.

uniform bool crt_enabled = true;
uniform float curvature = 0.035;
uniform float scanline_count = 360.0;
uniform float scan_strength = 0.22;
uniform float flicker = 0.02;
uniform float glow = 0.3;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	if (crt_enabled) {
		vec2 cc = uv - 0.5;
		uv = 0.5 + cc * (1.0 + dot(cc, cc) * curvature);
	}
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = texture(TEXTURE, uv);
		if (crt_enabled) {
			vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
			vec4 g = (texture(TEXTURE, uv + vec2(px.x, 0.0))
				+ texture(TEXTURE, uv - vec2(px.x, 0.0))
				+ texture(TEXTURE, uv + vec2(0.0, px.y))
				+ texture(TEXTURE, uv - vec2(0.0, px.y))) * 0.25;
			c.rgb += g.rgb * glow * g.a;
			float s = 0.5 + 0.5 * sin(uv.y * scanline_count * 3.14159);
			c.rgb *= 1.0 - scan_strength * s;
			c.rgb *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 53.0));
			vec2 v = uv - 0.5;
			c.rgb *= 1.0 - dot(v, v) * 0.7;
		}
		COLOR = vec4(c.rgb * tint.rgb, c.a);
	}
}
