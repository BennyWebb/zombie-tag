class_name Level
extends Node3D
## One of the ten places: its scenery, sky, fog and sun, the shop and gym, the exit gate, and the
## colliders that stop heroes and zombies walking through things (like src/world.js).

# The browser game's light strengths, turned into Godot's. Measured by drawing the same view in both
# and matching the colours: about 1 / (2 pi).
const LIGHT_SCALE := 1.0 / TAU

var info: Dictionary # the level's settings and layout (see Data.level)
var colliders: Array = [] # circles { x, z, r } and boxes { x, z, hw, hd }
var bounds: float # how far from the middle you can go
var gate: Node3D
var gate_open := false
var signs: Array[Node3D] = [] # the shop's and gym's spinning signs
var time := 0.0


func _init(number: int) -> void:
	info = Data.level(number)
	name = "Level%d" % number
	colliders = info.colliders.duplicate()
	bounds = info.bounds


func _ready() -> void:
	var scenery: Node3D = load("res://" + info.model).instantiate()
	add_child(scenery)
	Data.remove_extra_shadows(scenery)
	# the sun or moon shines through the fog, like the browser game's
	for mesh in scenery.find_children("*no fog*", "MeshInstance3D", true, false):
		no_fog(mesh)
	gate = scenery.find_child("gate", true, false)
	gate.find_child("open", true, false).visible = false
	add_sky_and_light()
	add_buildings()


func add_sky_and_light() -> void:
	var light: Dictionary = info.light
	var sky := Data.colour(info.sky)
	var env := Environment.new()
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

	var sun := DirectionalLight3D.new()
	sun.light_color = Data.colour(light.sun)
	sun.light_energy = light.sunAmount * LIGHT_SCALE
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	sun.look_at_from_position(Vector3(info.sunPosition.x, info.sunPosition.y, info.sunPosition.z), Vector3.ZERO)


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
		Data.remove_extra_shadows(building)
		var sign: Node3D = building.find_child("sign", true, false)
		signs.append(sign)
		# the glowing sign shows above the trees from anywhere, so it isn't fogged
		for mesh in sign.find_children("*", "MeshInstance3D", true, false):
			no_fog(mesh)
		var size: Dictionary = info.buildingSize
		colliders.append({ x = pair[1].x, z = pair[1].z, hw = size.halfWidth, hd = size.halfDepth })


func no_fog(mesh: MeshInstance3D) -> void:
	for i in mesh.mesh.get_surface_count():
		mesh.mesh.surface_get_material(i).disable_fog = true


func _process(delta: float) -> void:
	time += delta
	for s in signs:
		s.rotate_y(delta * 1.2)
	if gate_open:
		gate.find_child("beam", true, false).rotate_y(delta)


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
	for c in colliders:
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
