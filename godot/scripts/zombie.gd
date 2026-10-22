class_name Zombie
extends Node3D
## A goofy zombie: it wanders about, chases the nearest hero it notices, wobbles as it walks and
## squashes and flashes white when it's bonked (like src/zombie.js).
## For now this is everything a Shuffler does; the other kinds' tricks come in phase 6.

const GLOW_WHITE := Color(1, 1, 1)
const GLOW_NONE := Color(0, 0, 0)

var kind: String
var type: Dictionary # this kind's numbers from config.json
var level: Level
var health: float
var max_health: float
var radius: float
var yaw := randf() * TAU
var alive := true
var time := randf() * 10.0
var spawn_pop := 0.0 # grows out of the ground when it arrives
var flash := 0.0 # flashes white for a moment when it's hit
var squash := 0.0
var knock_vel := Vector3.ZERO # set when a weapon bonks it backwards
var wander_target = null # a Vector3, or null when it needs a new one
var wander_timer := 0.0

# parts of the model, moved to make it wobble and walk
var body: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var pupils: Array[Node3D] = []
var flash_materials: Array[StandardMaterial3D] = []


func _init(zombie_kind: String, the_level: Level, health_multiplier: float, x: float, z: float) -> void:
	kind = zombie_kind
	level = the_level
	type = Data.config.zombies[kind]
	max_health = type.health * health_multiplier
	health = max_health
	radius = type.radius
	position = Vector3(x, 0, z)


func _ready() -> void:
	var model: Node3D = load("res://models/zombies/%s.glb" % kind).instantiate()
	add_child(model)
	Data.hide_parts(model, "zombies/" + kind)
	body = model.find_child("body", true, false)
	for side in ["L", "R"]:
		arms.append(model.find_child("arm" + side, true, false))
		legs.append(model.find_child("leg" + side, true, false))
		pupils.append(model.find_child("pupil" + side, true, false))
	# its own colours, picked from its kind's (and its own copies, so it can flash on its own)
	var colours: Dictionary = Data.models.zombieColours.get(kind, Data.models.zombieColours.default)
	var picks := { skin = colours.skins.pick_random(), shirt = colours.shirts.pick_random() }
	for material_name in ["skin", "shirt", "trousers"]:
		var m := Data.own_material(model, material_name)
		if m:
			if picks.has(material_name):
				m.albedo_color = Data.colour(picks[material_name])
			m.emission_enabled = true
			m.emission = GLOW_NONE
			flash_materials.append(m)


## Bonked: returns true if that popped it.
func hit(damage: float) -> bool:
	health -= damage
	flash = 0.15
	squash = 1.0
	if health <= 0.0001:
		alive = false
	return not alive


func knock(direction: Vector3, amount: float) -> void:
	knock_vel += direction * amount


## Moves it for one frame. heroes: everyone it could chase. others: the other zombies.
func update(delta: float, heroes: Array, others: Array) -> void:
	time += delta
	spawn_pop = minf(1.0, spawn_pop + delta * 2.0)

	# go for the nearest hero
	var hero = null
	for h in heroes:
		if hero == null or position.distance_to(h.position) < position.distance_to(hero.position):
			hero = h
	var to_hero := Vector3.ZERO
	if hero:
		to_hero = Vector3(hero.position.x - position.x, 0, hero.position.z - position.z)
	var speed := 0.0
	var dir := Vector3.ZERO

	if hero and to_hero.length() < type.noticeDistance:
		# chase, and stop once touching the hero
		var touching: float = radius + hero.radius + 0.15
		if to_hero.length() > touching:
			dir = to_hero.normalized()
			speed = type.chaseSpeed
		else:
			yaw = atan2(to_hero.x, to_hero.z)
		wander_target = null
	else:
		wander_timer -= delta
		if wander_target == null or wander_timer <= 0:
			wander_target = position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			wander_timer = randf_range(3, 7)
		var to_target: Vector3 = wander_target - position
		to_target.y = 0
		if to_target.length() > 0.5:
			dir = to_target.normalized()
			speed = type.wanderSpeed

	# being knocked back slides it away and stops it walking for a moment
	var knocked := knock_vel.length()
	if knocked > 0.05:
		position += knock_vel * delta
		knock_vel *= exp(-6.0 * delta)
		speed *= maxf(0.0, 1.0 - knocked / 3.0)

	if dir != Vector3.ZERO:
		position += dir * speed * delta
		# turn smoothly towards where it's going
		yaw += wrapf(atan2(dir.x, dir.z) - yaw, -PI, PI) * minf(1.0, delta * 5.0)

	# don't stand inside each other
	for o in others:
		if o == self or not o.alive:
			continue
		var d := Vector2(position.x - o.position.x, position.z - o.position.z)
		var min_dist: float = radius + o.radius
		if d.length() < min_dist and d.length() > 0.0001:
			var push := d.normalized() * (min_dist - d.length()) * 0.5
			position.x += push.x
			position.z += push.y
	position = level.resolve_collisions(position, radius)
	position.y = 0
	rotation.y = yaw
	animate(delta, speed)


## The silly walk: a wobble, swinging legs, waving arms and googly eyes.
func animate(delta: float, speed: float) -> void:
	var walk := time * (7.0 if speed > 2 else 4.0) if speed > 0 else 0.0
	body.rotation.z = sin(time * 2.3) * 0.12
	body.position.y = absf(sin(walk)) * 0.08
	legs[0].rotation.x = sin(walk) * 0.5
	legs[1].rotation.x = -sin(walk) * 0.5
	arms[0].rotation.x = PI / 2 + sin(time * 3) * 0.15
	arms[1].rotation.x = PI / 2 - sin(time * 3) * 0.15
	for i in pupils.size():
		pupils[i].position.x = sin(time * (3 + i * 1.7)) * 0.05
		pupils[i].position.y = cos(time * (2.2 + i)) * 0.04

	# squash and flash white when bonked
	squash = maxf(0.0, squash - delta * 4.0)
	var s := spawn_pop * (1.0 + sin(squash * PI * 3) * 0.15 * squash)
	body.scale = Vector3(s, spawn_pop * (1.0 - squash * 0.2), s)
	flash = maxf(0.0, flash - delta)
	for m in flash_materials:
		m.emission = GLOW_WHITE if flash > 0 else GLOW_NONE


## Where it gets hit: the middle of its body.
func centre() -> Vector3:
	return position + Vector3(0, 1.2 * type.size, 0)
