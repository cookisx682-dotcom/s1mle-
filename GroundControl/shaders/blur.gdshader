shader_type canvas_item;
// Blurred + darkened background for the main menu (the control room behind the title).

uniform float radius = 1.5;
uniform float darken = 0.6;
uniform vec4 tint : source_color = vec4(0.75, 0.85, 1.0, 1.0);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	vec3 c = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * px).rgb;
		}
	}
	c /= 25.0;
	vec2 v = UV - 0.5;
	c *= 1.0 - dot(v, v) * 1.2;
	COLOR = vec4(c * darken * tint.rgb, 1.0);
}
