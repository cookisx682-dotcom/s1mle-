shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
// Highlight for interactive objects. Used as `material_overlay`: the mesh is drawn a second
// time slightly inflated with front faces culled, which leaves a glowing silhouette.

uniform vec4 outline_color : source_color = vec4(0.247, 0.878, 1.0, 1.0);
uniform float width = 0.012;
uniform float pulse_speed = 5.0;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	float p = 0.75 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = outline_color.rgb * (1.4 * p);
}
