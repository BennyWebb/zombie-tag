class_name Effects
extends Node3D
## Bursts of confetti and words that float up, like "POP!" (src/effects.js).
## Each burst is a CPUParticles3D: one node draws all its bits at once, which is much quicker than
## a node for every bit.

const CONFETTI_COLOURS := [0xff4f8b, 0xffe066, 0x4fc3f7, 0x9cff57, 0xb28dff, 0xff8a3d]

var confetti_mesh := QuadMesh.new()
var confetti_colours := Gradient.new()
var texts: Array = [] # [Label3D, life left]


func _ready() -> void:
	confetti_mesh.size = Vector2(0.14, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED # both sides of each bit show as it spins
	m.vertex_color_use_as_albedo = true # each bit's colour comes from the particles
	confetti_mesh.material = m
	# each bit picks one of the colours (no blending between them)
	confetti_colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for i in CONFETTI_COLOURS.size():
		offsets.append(float(i) / CONFETTI_COLOURS.size())
		colours.append(Data.colour(CONFETTI_COLOURS[i]))
	confetti_colours.offsets = offsets
	confetti_colours.colors = colours


## A burst of confetti when a zombie pops.
func confetti(pos: Vector3, count := 70) -> void:
	var p := CPUParticles3D.new()
	p.mesh = confetti_mesh
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 2.4
	p.lifetime_randomness = 0.33
	p.direction = Vector3.UP
	p.spread = 70
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -9, 0)
	p.damping_min = 1.5 # air drag, so it flutters
	p.damping_max = 3.0
	p.angular_velocity_min = -600
	p.angular_velocity_max = 600
	p.particle_flag_rotate_y = true
	p.color_initial_ramp = confetti_colours
	p.position = pos
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A word that floats up and fades away, like "POP!".
func float_text(pos: Vector3, text: String, colour: Color, size := 1.6) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = colour
	label.outline_modulate = Color("4b1e8a")
	label.outline_size = 24
	label.font_size = 96
	label.pixel_size = size / 300.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true # it shows in front of everything, like the browser game's
	label.position = pos
	add_child(label)
	texts.append([label, 1.0])


func _process(delta: float) -> void:
	for t in texts.duplicate():
		var label: Label3D = t[0]
		t[1] -= delta
		label.position.y += 1.5 * delta
		label.scale = Vector3.ONE * (1.0 + (1.0 - t[1]) * 0.5)
		label.modulate.a = minf(1.0, t[1] * 2.0)
		label.outline_modulate.a = label.modulate.a
		if t[1] <= 0:
			label.queue_free()
			texts.erase(t)
