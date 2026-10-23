// A zombie's health bar (see Zombie.make_health_bar): a dark box with a green bar inside, always
// facing the camera that's drawing it.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float fill = 1.0; // how much health is left, 0 to 1
uniform vec4 box_colour : source_color = vec4(0.133, 0.133, 0.133, 1.0);
uniform vec4 bar_colour : source_color = vec4(0.612, 1.0, 0.341, 1.0);

void vertex() {
	// keep its place, but turn it to face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	// the bar fills the middle of the box (0.94 by 0.09 of its 1 by 0.14), from the left
	vec2 inside = (UV - vec2(0.03, 0.18)) / vec2(0.94, 0.64);
	bool in_bar = inside.x >= 0.0 && inside.x <= fill && inside.y >= 0.0 && inside.y <= 1.0;
	ALBEDO = in_bar ? bar_colour.rgb : box_colour.rgb;
}
