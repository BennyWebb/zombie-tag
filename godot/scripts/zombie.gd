class_name Zombie
extends Node3D
## A goofy zombie: it wanders about, chases the nearest hero it notices, wobbles as it walks and
## squashes and flashes white when it's bonked (like src/zombie.js). Goo slows it down, a bubble
## floats it up and a snowball freezes it solid.
## Each kind has its own tricks: Speedy Sid sprints then stops to pant (tongue out), Bouncy Bob hops
## along and jumps over small things like fences and benches, and the Zombie King keeps calling
## Shufflers to help him (main.gd brings them in). A Slime Zombie splits in two when it pops
## (main.gd does that too).

# the colour it glows: white when hit, blue when frozen, green when slimed
const GLOW_WHITE := Color(1, 1, 1)
const GLOW_ICE := Color("3a78b0")
const GLOW_SLIME := Color("2f7a10")
const GLOW_NONE := Color(0, 0, 0)
const HEALTH_BAR_SHADER := preload("res://scripts/health_bar.gdshader")

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
var knock_vel := Vector3.ZERO # set when a weapon bonks it backwards, or it bounces off you
var dizzy := 0.0 # counts down after it tags you; it stands still, seeing stars
var groan_in := randf_range(2, 10) # time until it groans (main.gd plays it)
var word_time := -9.0 # when it last showed a word like "SPLOSH!" (main.gd)
# weapon effects, each counting down: slimed (slow), trapped in a bubble, frozen solid
var slow_time := 0.0
var slow_speed := 1.0
var bubble_time := 0.0
var frozen_time := 0.0
var lift := 0.0 # how high its bubble has floated
var wander_target = null # a Vector3, or null when it needs a new one
var wander_timer := 0.0
var sprint := 0.0 # Speedy Sid: time left in this sprint (or panting, when below 0)
var hop := randf() * PI # Bouncy Bob: where he is in his hop
var help_timer := 0.0 # Zombie King: time until he calls for help
var calling_help := false # (main.gd brings the helpers, and sets it back)
var helper := false # one of the King's helpers

# parts of the model, moved to make it wobble and walk
var body: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var pupils: Array[Node3D] = []
var model: Node3D
var stars: Node3D
var bubble: Node3D
var ice: Node3D
var health_bar: MeshInstance3D
var tongue: Node3D # (Speedy Sid's)
var flash_materials: Array[StandardMaterial3D] = []


func _init(zombie_kind: String, the_level: Level, health_multiplier: float, x: float, z: float) -> void:
	kind = zombie_kind
	level = the_level
	type = Data.config.zombies[kind]
	max_health = type.health * health_multiplier
	health = max_health
	radius = type.radius
	position = Vector3(x, 0, z)
	sprint = type.get("sprintTime", 0.0)
	help_timer = type.get("callHelpEvery", 0.0)


func _ready() -> void:
	model = load("res://models/zombies/%s.glb" % kind).instantiate()
	add_child(model)
	Data.hide_parts(model, "zombies/" + kind)
	Data.remove_extra_shadows(model)
	# its eyes and mouth are too small for their shadows to show, but each shadow would be drawn
	# again for every layer of the sun's shadows, so they have none
	for part in model.find_child("head", true, false).find_children("*", "GeometryInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body = model.find_child("body", true, false)
	for side in ["L", "R"]:
		arms.append(model.find_child("arm" + side, true, false))
		legs.append(model.find_child("leg" + side, true, false))
		pupils.append(model.find_child("pupil" + side, true, false))
	stars = model.find_child("stars", true, false)
	tongue = model.find_child("tongue", true, false)
	bubble = model.find_child("bubble", true, false)
	ice = model.find_child("ice", true, false)
	# its health bar floats over its head (the one in the model is left hidden: this one turns to
	# face each player's camera by itself, which matters with two players looking at once)
	health_bar = make_health_bar(type.size)
	health_bar.position.y = 2.5 * type.size
	health_bar.visible = false
	model.add_child(health_bar)
	for part in [bubble, ice]: # (see-through)
		for mesh in part.find_children("*", "GeometryInstance3D", true, false) + [part]:
			if mesh is GeometryInstance3D:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	# its health bar shows once it's been hit
	health_bar.visible = true
	health_bar.material_override.set_shader_parameter("fill", maxf(0.0, health / max_health))
	if health <= 0.0001:
		alive = false
	return not alive


func knock(direction: Vector3, amount: float) -> void:
	if bubble_time > 0 or frozen_time > 0:
		return # bubbles and ice blocks don't get pushed
	knock_vel += direction * amount


## What a weapon does besides damage.
func weapon_effects(w: Dictionary) -> void:
	if w.has("slowTime"):
		slow_time = w.slowTime
		slow_speed = w.slowSpeed
	if w.has("bubbleTime"):
		bubble_time = w.bubbleTime
	if w.has("freezeTime"):
		frozen_time = w.freezeTime


## Standing still: dizzy, trapped in a bubble or frozen.
func stuck() -> bool:
	return dizzy > 0 or bubble_time > 0 or frozen_time > 0


## Only a zombie that's fully arrived and not stuck can tag you.
func can_tag() -> bool:
	return spawn_pop >= 1 and not stuck()


## Moves it for one frame. heroes: everyone it could chase. others: the other zombies.
func update(delta: float, heroes: Array, others: Array) -> void:
	time += delta
	spawn_pop = minf(1.0, spawn_pop + delta * 2.0)
	dizzy = maxf(0.0, dizzy - delta)
	slow_time = maxf(0.0, slow_time - delta)
	bubble_time = maxf(0.0, bubble_time - delta)
	frozen_time = maxf(0.0, frozen_time - delta)

	# go for the nearest hero who isn't tagged
	var hero = null
	for h in heroes:
		if h.tagged > 0:
			continue
		if hero == null or position.distance_to(h.position) < position.distance_to(hero.position):
			hero = h
	var to_hero := Vector3.ZERO
	if hero:
		to_hero = Vector3(hero.position.x - position.x, 0, hero.position.z - position.z)
	var speed := 0.0
	var dir := Vector3.ZERO

	if stuck():
		pass # seeing stars, bubbled or frozen: stay put
	elif hero and to_hero.length() < type.noticeDistance:
		# chase, and stop once touching the hero
		var touching: float = radius + hero.radius + 0.15
		if type.has("sprintTime"):
			# Speedy Sid sprints, then stops to pant
			sprint -= delta
			if sprint < -type.pantTime:
				sprint = type.sprintTime
		if type.has("callHelpEvery"):
			help_timer -= delta
			if help_timer <= 0:
				help_timer = type.callHelpEvery
				calling_help = true
		if to_hero.length() > touching and sprint >= 0:
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

	if slow_time > 0:
		speed *= slow_speed
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
	# Bouncy Bob only moves while he's in the air, and hops over small things
	var hop_up := 0.0
	if type.has("hopHeight"):
		hop += delta * type.hopsPerSecond * PI * (1.0 if speed > 0 else 0.5)
		hop_up = absf(sin(hop)) * type.hopHeight
	position = level.resolve_collisions(position, radius, type.get("jumpsSmallThings", false) and hop_up > 0.3)
	position.y = 0
	rotation.y = yaw
	animate(delta, speed, hop_up)


## The silly walk: a wobble, swinging legs, waving arms and googly eyes.
func animate(delta: float, speed: float, hop_up: float) -> void:
	if tongue:
		tongue.visible = sprint < 0 # panting
	bubble.visible = bubble_time > 0
	ice.visible = frozen_time > 0
	# a bubble floats it up, then it drops back down when the bubble pops
	lift += ((1.3 if bubble_time > 0 else 0.0) - lift) * minf(1.0, delta * (2.0 if bubble_time > 0 else 8.0))
	if bubble_time > 0:
		bubble.scale = Vector3.ONE * (1 + sin(time * 4) * 0.04)
	model.position.y = lift + hop_up
	flash = maxf(0.0, flash - delta)
	if frozen_time > 0:
		# frozen solid: no wobbling at all
		stars.visible = false
		for m in flash_materials:
			m.emission = GLOW_WHITE if flash > 0 else GLOW_ICE
		return

	var walk := time * (7.0 if speed > 2 else 4.0) if speed > 0 else 0.0
	# a wobble, much more when dizzy, with stars going round its head
	body.rotation.z = sin(time * 6) * 0.25 if dizzy > 0 else sin(time * 2.3) * 0.12
	stars.visible = dizzy > 0
	if dizzy > 0:
		stars.rotate_y(delta * 6)
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
	for m in flash_materials:
		m.emission = GLOW_WHITE if flash > 0 else GLOW_SLIME if slow_time > 0 else GLOW_NONE


## A health bar: a dark box with a green bar inside, as long as how much health is left ("fill",
## 0 to 1). Its shader turns it to face whichever camera is drawing it.
static func make_health_bar(size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.14) * size
	var m := ShaderMaterial.new()
	m.shader = HEALTH_BAR_SHADER
	var bar := MeshInstance3D.new()
	bar.mesh = quad
	bar.material_override = m
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bar


## Where it gets hit: the middle of its body (up in its bubble, if it's in one).
func centre() -> Vector3:
	return position + Vector3(0, 1.2 * type.size + lift, 0)
