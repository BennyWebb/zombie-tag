// Drifting dots (see floaters.gd). Each corner of each little square starts at its dot's middle;
// this moves the dot along, then puts the corner beside it, facing the camera.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;

uniform vec4 colour : source_color = vec4(1.0);
uniform float size = 0.2;
uniform float fall = 0.0; // how fast it falls (metres a second)
uniform float wander = 0.5; // how far it drifts from side to side
uniform float low = 0.0; // it falls from high to low, then starts at the top again
uniform float high = 20.0;

void vertex() {
	float i = UV2.x; // which dot
	vec3 middle = VERTEX;
	// a gentle drift from side to side (the browser game adds sin(...) * wander every frame, which
	// comes to this)
	middle.x -= cos(TIME * 0.7 + i) * wander / 0.7;
	middle.z += sin(TIME * 0.6 + i * 1.3) * wander / 0.6;
	// falling, and going back to the top at the bottom
	middle.y = low + mod(middle.y - low - fall * TIME, high - low);
	// the corner, beside the middle and facing the camera (a PointsMaterial dot is a square
	// `size` across)
	VERTEX = middle + (INV_VIEW_MATRIX[0].xyz * UV.x + INV_VIEW_MATRIX[1].xyz * UV.y) * size * 0.5;
}

void fragment() {
	ALBEDO = colour.rgb;
	ALPHA = 0.9;
}
