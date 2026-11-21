shader_type canvas_item;
// Post-process for the low-resolution 3D render (480x270 SubViewport, nearest-filtered).
// Reduces the colour count, adds ordered (Bayer) dithering, optional film noise and a vignette.

uniform bool effect_enabled = true;
uniform float color_levels : hint_range(2.0, 64.0) = 12.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.75;
uniform float noise_strength : hint_range(0.0, 0.3) = 0.035;
uniform vec2 resolution = vec2(480.0, 270.0);
uniform float vignette : hint_range(0.0, 2.0) = 0.55;
uniform vec4 shadow_tint : source_color = vec4(0.043, 0.078, 0.157, 1.0);

// 2x2 Bayer value (0..3) built from bit operations, then combined into a 4x4 matrix.
float bayer2(int x, int y) {
	return float(((x ^ y) & 1) * 2 + (y & 1));
}

float bayer4(ivec2 p) {
	int x = p.x;
	int y = p.y;
	return (4.0 * bayer2(x & 1, y & 1) + bayer2((x >> 1) & 1, (y >> 1) & 1)) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb;
	if (effect_enabled) {
		ivec2 px = ivec2(floor(UV * resolution));
		float d = bayer4(px) - 0.5;
		col += d * dither_strength / color_levels;
		col = floor(col * color_levels + 0.5) / color_levels;
		// lift the deepest blacks into the night-blue of the palette
		col = max(col, shadow_tint.rgb * 0.55);
		float n = hash(vec2(px) + vec2(fract(TIME * 7.13) * 311.0, fract(TIME * 3.7) * 173.0)) - 0.5;
		col += n * noise_strength;
	}
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
