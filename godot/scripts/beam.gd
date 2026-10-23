class_name Beam
extends Node3D
## The Sparkle Star Laser Gun's beam, with stars swirling round it (the Beam class in
## src/weapons.js). All the stars are one MultiMesh, so however many there are, they draw at once.

const STAR_COLOURS := [0xffe066, 0xff6fd8, 0xb28dff, 0x9cfff0, 0xffffff]
const MAX_STARS := 64

var camera: Camera3D # the stars turn to face it
var glow := MeshInstance3D.new()
var tube := Node3D.new() # the glow and the white core, stretched from the gun to what it's hitting
var stars_mesh := MultiMeshInstance3D.new()
var stars: Array = [] # each: { along, angle, radius, life, axis, from, side, up, size, colour }
var from := Vector3.ZERO
var to := Vector3.ZERO
var to_spawn := 0.0
var time := 0.0


func _init(the_camera: Camera3D) -> void:
	camera = the_camera
	top_level = true # it stays where it's put in the world, not following the hero about
	add_child(tube)
	tube.visible = false
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.06
	glow_mesh.bottom_radius = 0.06
	glow_mesh.height = 1
	glow_mesh.cap_top = false
	glow_mesh.cap_bottom = false
	glow_mesh.material = glowing(Color("ff6fd8", 0.55))
	glow.mesh = glow_mesh
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.018
	core_mesh.bottom_radius = 0.018
	core_mesh.height = 1
	core_mesh.radial_segments = 8
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mesh.material = white
	core.mesh = core_mesh
	for part in [glow, core]:
		part.rotation.x = PI / 2 # the cylinders point along the beam
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tube.add_child(part)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = star_shape()
	mm.instance_count = MAX_STARS
	mm.visible_instance_count = 0
	stars_mesh.multimesh = mm
	stars_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars_mesh)


## See-through and glowing: its colour adds to whatever's behind it.
## stars: each star brings its own colour.
static func glowing(colour: Color, stars := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.vertex_color_use_as_albedo = stars
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A flat five-pointed star, 1 m across.
static func star_shape() -> ArrayMesh:
	var points := PackedVector3Array([Vector3.ZERO])
	for i in 11:
		var r := 0.5 if i % 2 == 0 else 0.21
		var a := TAU * i / 10.0 + PI / 2
		points.append(Vector3(cos(a) * r, sin(a) * r, 0))
	var triangles := PackedVector3Array()
	for i in 10:
		triangles.append_array([points[0], points[i + 2], points[i + 1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = triangles
	var white := PackedColorArray()
	white.resize(triangles.size())
	white.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = white
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, glowing(Color.WHITE, true))
	return mesh


## Draws one tiny star at `pos` for a frame, so the stars are ready to draw (see Effects.warm_up).
func warm_up(pos: Vector3) -> void:
	stars_mesh.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), pos))
	stars_mesh.multimesh.visible_instance_count = 1


## Shows the beam from `start` to `end`; call hide_beam() when it stops.
func show_beam(start: Vector3, end: Vector3) -> void:
	from = start
	to = end
	tube.position = start.lerp(end, 0.5)
	if not start.is_equal_approx(end):
		tube.look_at(end, Vector3.UP if absf((end - start).normalized().y) < 0.99 else Vector3.RIGHT)
	tube.scale = Vector3(1, 1, start.distance_to(end))
	tube.visible = true


func hide_beam() -> void:
	tube.visible = false


## stars_per_second: how many new stars appear along the beam while it's showing.
func update(delta: float, stars_per_second: float) -> void:
	time += delta
	var pulse := 1 + sin(time * 30) * 0.25
	glow.scale = Vector3(pulse, 1, pulse)
	if tube.visible:
		# new stars appear along the beam and swirl round it
		to_spawn += stars_per_second * delta
		var axis := to - from
		var side := Vector3.UP.cross(axis).normalized()
		var up := axis.cross(side).normalized()
		while to_spawn >= 1:
			to_spawn -= 1
			if stars.size() < MAX_STARS:
				stars.append({
					along = randf_range(0.15, 1.0), angle = randf() * TAU, radius = 0.08, life = 0.7,
					axis = axis, from = from, side = side, up = up, size = randf_range(0.12, 0.28),
					colour = Data.colour(STAR_COLOURS.pick_random()),
				})
	var mm := stars_mesh.multimesh
	var facing := camera.global_basis # each star turns to face you
	for i in range(stars.size() - 1, -1, -1):
		var s: Dictionary = stars[i]
		s.life -= delta
		s.angle += delta * 9
		s.radius += delta * 0.6
		if s.life <= 0:
			stars.remove_at(i)
	for i in stars.size():
		var s: Dictionary = stars[i]
		var p: Vector3 = s.from + s.axis * s.along + s.side * cos(s.angle) * s.radius + s.up * sin(s.angle) * s.radius
		var k := maxf(0.0, s.life / 0.7)
		mm.set_instance_transform(i, Transform3D(facing.scaled(Vector3.ONE * s.size * (0.5 + k)), p))
		mm.set_instance_color(i, s.colour)
	mm.visible_instance_count = stars.size()
