class_name Level
extends Node3D
## One of the ten places: its scenery, sky, fog and sun, the shop and gym, the exit gate, and the
## colliders that stop heroes and zombies walking through things (like src/world.js). Some have
## more: lamps and torches that light up the dark, snow or fireflies drifting about, and the
## Funfair's carousel and Ferris wheel going round.

# The browser game's light strengths, turned into Godot's. Measured by drawing the same view in both
# and matching the colours: about 1 / (2 pi).
const LIGHT_SCALE := 1.0 / TAU
const SUN_DISTANCE := 200.0 # the sun and moon are 140 m from the middle, so up to 190 m from you

var info: Dictionary # the level's settings and layout (see Data.level)
var colliders: Array = [] # circles { x, z, r } and boxes { x, z, hw, hd }
# each collider's box (a circle's too) as plain numbers, x, z, half width and half depth, which are
# much quicker to look at than the dictionaries: things far from a collider skip it straight away
var collider_boxes := PackedFloat32Array()
var bounds: float # how far from the middle you can go
var gate: Node3D
var gate_open := false
var signs: Array[Node3D] = [] # the shop's and gym's spinning signs
var doors := {} # "shop" and "gym": { door = Vector2 (x, z), outside = where you come back out }
var time := 0.0
var sun := DirectionalLight3D.new()
var env := Environment.new()
var lamps: Array[OmniLight3D] = []
var floaters: Array[Floaters] = []
var carousel: Node3D # (the Funfair's rides, or null)
var ferris_wheel: Node3D
var solid: Array[Node3D] = [] # the scenery and the buildings (for the graphics test)
var buildings: Array[Node3D] = [] # the shop and the gym


func _init(number: int) -> void:
	info = Data.level(number)
	name = "Level%d" % number
	colliders = info.colliders.duplicate()
	bounds = info.bounds


func _ready() -> void:
	var scenery: Node3D = load("res://" + info.model).instantiate()
	add_child(scenery)
	solid.append(scenery)
	Data.remove_extra_shadows(scenery)
	# the sun or moon shines through the fog, like the browser game's
	for mesh in scenery.find_children("*no fog*", "MeshInstance3D", true, false):
		no_fog(mesh)
	gate = scenery.find_child("gate", true, false)
	gate.find_child("open", true, false).visible = false
	carousel = scenery.find_child("carousel", true, false)
	ferris_wheel = scenery.find_child("ferrisWheel", true, false)
	# (the scenery comes already joined up in squares of the level, which is best left as it is: the
	# squares behind you aren't drawn, and nearer ones are drawn first, so the things behind them
	# don't need colouring in)
	# The ground, which stretches far past the walls, is drawn after everything else, so the parts
	# hidden behind trees and buildings are skipped instead of coloured in and then covered.
	for mesh in scenery.find_children("big*", "MeshInstance3D", true, false):
		if not "see-through" in String(mesh.name):
			mesh.sorting_offset = -1000.0
	add_sky_and_light()
	add_lamps()
	for settings in info.floaters:
		var f := Floaters.new(settings)
		add_child(f)
		floaters.append(f)
	add_buildings()


func add_sky_and_light() -> void:
	var light: Dictionary = info.light
	var sky := Data.colour(info.sky)
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	# The browser game lights things with a "hemisphere" light (sky colour from above, ground colour
	# from below). Godot's nearest thing is an even ambient light, mostly the sky's colour since most
	# things face up or sideways.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Data.colour(light.sky).lerp(Data.colour(light.ground), 0.25)
	env.ambient_light_energy = light.amount * LIGHT_SCALE
	# fog that starts and ends at set distances, like the browser game's
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = sky
	env.fog_depth_begin = info.fog.start
	env.fog_depth_end = info.fog.end
	env.fog_density = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun.light_color = Data.colour(light.sun)
	sun.light_energy = light.sunAmount * LIGHT_SCALE
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	sun.look_at_from_position(Vector3(info.sunPosition.x, info.sunPosition.y, info.sunPosition.z), Vector3.ZERO)


## Lamps and torches that light up the ground round them (each one lights what's within its range).
func add_lamps() -> void:
	for l in info.pointLights:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(l.x, l.y, l.z)
		lamp.light_color = Data.colour(l.colour)
		lamp.light_energy = l.intensity * LIGHT_SCALE
		lamp.omni_range = l.range
		lamp.omni_attenuation = 2.0 # fading like the browser game's (which fades with distance squared)
		add_child(lamp)
		lamps.append(lamp)


## Uses the graphics settings (see graphics.gd) for the shadows, how far you can see, and the
## extras. Returns how far the cameras should draw.
func set_graphics(g: Dictionary) -> float:
	# the sun's shadows: each layer draws everything that casts a shadow again, so fewer layers
	# (reaching less far) take less time; the shadows close to you stay sharp
	sun.shadow_enabled = g.shadows < 3
	sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_ORTHOGONAL][g.shadows]
	sun.directional_shadow_max_distance = [60.0, 40.0, 30.0, 30.0][g.shadows]
	# the shadow map: bigger is sharper. (Godot's usual on Android is half the size of a computer's,
	# with hard edges, which made big jagged steps along the shadows' edges, so it's set here.)
	RenderingServer.directional_shadow_atlas_set_size(2048 if g.shadows >= 2 else 4096, true)
	# softening the edges, which hides the steps: a few more looks into the shadow map for each dot
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if g.shadows == 0 else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	# how far: nothing past the end of the fog is drawn, so bringing the fog in draws less (things
	# far away, like the sun, the moon and far clouds, go too)
	var fog_end: float = [info.fog.end, minf(info.fog.end, 70.0), minf(info.fog.end, 45.0)][g.distance]
	env.fog_depth_end = fog_end
	env.fog_depth_begin = minf(info.fog.start, fog_end * 0.4)
	# the extras
	for f in floaters:
		f.visible = g.extras == 0
	for lamp in lamps:
		lamp.visible = g.extras == 0
	var leave_out: String = Graphics.OPTIONS.test.choices[g.test]
	for part in solid:
		part.visible = leave_out != "Scenery" and not (leave_out == "Shop and gym" and part in buildings)
	for s in signs:
		s.visible = leave_out != "Their signs"
	# (past the fog everything is the sky's colour anyway, but the sun or moon is a little further)
	return maxf(fog_end + 5, SUN_DISTANCE) if g.distance == 0 else fog_end + 5


## The shop and the gym go at two of the six spots, at least 30 m apart, different every time.
func add_buildings() -> void:
	var spots: Array = info.buildingSpots.duplicate()
	spots.shuffle()
	var shop_spot: Dictionary = spots[0]
	var gym_spot: Dictionary = spots[1]
	for s in spots.slice(1):
		if Vector2(s.x - shop_spot.x, s.z - shop_spot.z).length() > 30:
			gym_spot = s
			break
	for pair in [["shop", shop_spot], ["gym", gym_spot]]:
		var building: Node3D = load("res://models/%s.glb" % pair[0]).instantiate()
		building.position = Vector3(pair[1].x, 0, pair[1].z)
		add_child(building)
		solid.append(building)
		buildings.append(building)
		Data.remove_extra_shadows(building)
		var sign: Node3D = building.find_child("sign", true, false)
		signs.append(sign)
		# the glowing sign shows above the trees from anywhere, so it isn't fogged
		for mesh in sign.find_children("*", "MeshInstance3D", true, false):
			no_fog(mesh)
		Data.merge_meshes(building, [sign])
		var size: Dictionary = info.buildingSize
		colliders.append({ x = pair[1].x, z = pair[1].z, hw = size.halfWidth, hd = size.halfDepth })
		# the door is on the +z side; you come back out a little way in front of it, facing away
		var door := Vector2(pair[1].x, pair[1].z + size.halfDepth)
		doors[pair[0]] = { door = door, outside = { x = door.x, z = door.y + 2.4, yaw = PI } }


func no_fog(mesh: MeshInstance3D) -> void:
	for i in mesh.mesh.get_surface_count():
		mesh.mesh.surface_get_material(i).disable_fog = true


func _process(delta: float) -> void:
	time += delta
	for s in signs:
		s.rotate_y(delta * 1.2)
	if gate_open:
		gate.find_child("beam", true, false).rotate_y(delta)
	if carousel:
		# it goes round, and the horses go up and down
		carousel.rotate_y(delta * 0.6)
		for i in 8:
			carousel.get_child(i).get_child(1).position.y = 1.5 + sin(time * 2 + i) * 0.3
	if ferris_wheel:
		ferris_wheel.rotate_z(delta * 0.15)
		# the little cars (every other part after the rim) hang the right way up
		for i in range(2, ferris_wheel.get_child_count(), 2):
			ferris_wheel.get_child(i).rotation.z = -ferris_wheel.rotation.z


func open_gate() -> void:
	gate_open = true
	gate.find_child("bars", true, false).visible = false
	gate.find_child("open", true, false).visible = true


## Whether a hero standing here is walking through the open gate.
func at_gate(pos: Vector3) -> bool:
	return gate_open and absf(pos.x - info.gate.x) < 2.2 and absf(pos.z - info.gate.z) < 2.0


## Pushes a circle out of anything solid and keeps it inside the walls (resolveCollisions in
## src/world.js). hopper: Bouncy Bob, who jumps over small things like fences and benches.
func resolve_collisions(pos: Vector3, radius: float, hopper := false) -> Vector3:
	if collider_boxes.size() != colliders.size() * 4:
		make_collider_boxes()
	for i in colliders.size():
		var k := i * 4
		if absf(pos.x - collider_boxes[k]) >= collider_boxes[k + 2] + radius \
				or absf(pos.z - collider_boxes[k + 1]) >= collider_boxes[k + 3] + radius:
			continue # nowhere near it
		var c: Dictionary = colliders[i]
		if hopper and c.get("small", false):
			continue
		if c.has("r"):
			var d := Vector2(pos.x - c.x, pos.z - c.z)
			var min_dist: float = c.r + radius
			if d.length() < min_dist and d.length() > 0.0001:
				d = d.normalized() * min_dist
				pos.x = c.x + d.x
				pos.z = c.z + d.y
		else:
			pos = push_out_of_box(pos, radius, c)
	var b := bounds - radius
	pos.x = clampf(pos.x, -b, b)
	pos.z = clampf(pos.z, -b, b)
	return pos


func make_collider_boxes() -> void:
	collider_boxes.clear()
	for c in colliders:
		collider_boxes.append_array([c.x, c.z, c.get("r", c.get("hw", 0.0)), c.get("r", c.get("hd", 0.0))])


func push_out_of_box(pos: Vector3, radius: float, c: Dictionary) -> Vector3:
	var nearest := Vector2(clampf(pos.x, c.x - c.hw, c.x + c.hw), clampf(pos.z, c.z - c.hd, c.z + c.hd))
	var d := Vector2(pos.x, pos.z) - nearest
	if d.length() > 0.0001:
		if d.length() < radius:
			d = d.normalized() * radius
			pos.x = nearest.x + d.x
			pos.z = nearest.y + d.y
		return pos
	# the middle is inside the box: push out through the nearest side
	var px: float = c.hw - absf(pos.x - c.x)
	var pz: float = c.hd - absf(pos.z - c.z)
	if px < pz:
		pos.x = c.x + signf(pos.x - c.x if pos.x != c.x else 1.0) * (c.hw + radius)
	else:
		pos.z = c.z + signf(pos.z - c.z if pos.z != c.z else 1.0) * (c.hd + radius)
	return pos


## Whether a spot is clear of the walls and everything solid (isClear in src/world.js).
func is_clear(x: float, z: float, r: float) -> bool:
	var half: float = Data.config.arena.size / 2.0
	if absf(x) >= half - 2 or absf(z) >= half - 2:
		return false
	for c in colliders:
		if distance_to(c, x, z) < r:
			return false
	return true


## How far a point is from the edge of a collider (negative when inside it).
static func distance_to(c: Dictionary, x: float, z: float) -> float:
	if c.has("r"):
		return Vector2(c.x - x, c.z - z).length() - c.r
	var dx := maxf(absf(x - c.x) - c.hw, 0.0)
	var dz := maxf(absf(z - c.z) - c.hd, 0.0)
	return Vector2(dx, dz).length()
