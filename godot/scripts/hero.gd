class_name Hero
extends Node3D
## You! Seen from your own eyes: you walk and turn, and your hand swings your weapon at the nearest
## zombie in front of you (like src/player.js). Zombie touches cost hearts; lose them all and you're
## tagged, and after a countdown you're back at the start.
## For now it's always the Spiky Stick, and it never breaks; the shop and the other weapons come in
## phases 3 and 4.

signal bonked(zombie: Zombie, weapon: Dictionary, push: Vector3) # a swing landed on a zombie

const HAND_REST := Vector3(0.38, -0.42, -0.65) # where the hand sits, from the camera

var level: Level # the level you're in (main.gd sets it)
var radius: float = Data.config.player.radius
var yaw := 0.0 # which way you face: 0 is towards -z, the middle of the level from the start
var speed_level: int = Data.config.player.startSpeed
var strength_level: int = Data.config.player.startStrength
var walk_phase := 0.0
var weapon_id := "spikyStick"
var weapon: Dictionary = Data.config.weapons[weapon_id]
var swing := 0.0 # counts down while swinging
var swing_hit := false
var attack_queued := false # a press during a swing is remembered, so mashing never feels ignored

var tag_bux := 0
var hearts: int = Data.config.player.hearts
var shields := 0 # hits your armour can still block this level
var shields_max := 0 # how many your best armour blocks (armour comes with the shop, in phase 3)
var safe := 0.0 # counts down while you can't be hurt, after a zombie touch
var tagged := 0.0 # counts down while you're tagged, before going back to the start
var shake := 0.0 # the camera wobbles for a moment when you're hurt

var camera := Camera3D.new()
var hand: Node3D


func _ready() -> void:
	camera.fov = 70 # like the browser game (both measure it top to bottom)
	camera.near = 0.05
	camera.far = 300
	add_child(camera)
	camera.position.y = Data.config.player.eyeHeight
	# the first-person hand, holding every weapon; only the one you're holding shows
	hand = load("res://models/hand.glb").instantiate()
	camera.add_child(hand)
	Data.remove_extra_shadows(hand) # your hand doesn't cast a shadow, like in the browser game
	hand.position = HAND_REST
	for id in Data.models.models.hand.weapons:
		hand.find_child(id, true, false).visible = id == weapon_id
	var look: Dictionary = Data.config.heroes[0]
	Data.own_material(hand, "skin").albedo_color = Data.colour(look.skin)
	Data.own_material(hand, "clothes").albedo_color = Data.colour(look.outfit)


func start_at(spot: Dictionary) -> void:
	position = Vector3(spot.x, 0, spot.z)
	yaw = spot.yaw
	rotation.y = yaw


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func move_speed() -> float:
	var p: Dictionary = Data.config.player
	return p.baseSpeed * (1 + (speed_level - 1) * p.speedPerLevel)


func damage_multiplier() -> float:
	return 1 + (strength_level - 1) * Data.config.player.strengthPerLevel


## A zombie touch. Returns "" if you couldn't be hurt just now, "shield" if your armour blocked it,
## or "heart" if it cost you hearts (and then `tagged` says whether that was your last).
func hurt(amount: int) -> String:
	if safe > 0 or tagged > 0:
		return ""
	safe = Data.config.player.safeTime
	shake = 0.3
	if shields > 0:
		shields -= 1
		return "shield"
	hearts = maxi(0, hearts - amount)
	if hearts == 0:
		tagged = Data.config.player.taggedTime
		hand.visible = false
	return "heart"


## Back at the start with full hearts, after being tagged.
func respawn(spot: Dictionary) -> void:
	start_at(spot)
	hearts = Data.config.player.hearts
	shields = shields_max
	tagged = 0
	safe = Data.config.player.safeTime
	swing = 0
	attack_queued = false
	hand.rotation = Vector3.ZERO
	hand.visible = true


## Moves you for one frame (main.gd calls this, so everything moves in a set order).
## zombies: the ones you could bump into or bonk.
func update(delta: float, zombies: Array) -> void:
	# a little wobble when a zombie touches you, and your hand blinks while you can't be hurt
	shake = maxf(0.0, shake - delta)
	camera.position.x = randf_range(-0.25, 0.25) * shake
	safe = maxf(0.0, safe - delta)
	if tagged > 0:
		return # main.gd counts down and brings you back
	hand.visible = safe <= 0 or int(safe * 8) % 2 == 0

	# turning: keys turn a little faster than a joypad, which is easy to overshoot with
	var turn := Input.get_axis("turn_right", "turn_left")
	var turn_speed: float = Data.config.controls.padTurnSpeed if Controls.using_joypad else Data.config.player.turnSpeed
	yaw += turn * turn_speed * delta
	# walking: a bit slower backwards
	var walk := Input.get_axis("walk_back", "walk_forward")
	if walk < 0:
		walk *= 0.7
	if walk != 0:
		position += forward() * walk * move_speed() * delta
		walk_phase += delta * move_speed() * 2.2 * absf(walk)
	position = level.resolve_collisions(position, radius)
	# don't walk through zombies
	for z in zombies:
		if not z.alive:
			continue
		var d := Vector2(position.x - z.position.x, position.z - z.position.z)
		var min_dist: float = radius + z.radius
		if d.length() < min_dist and d.length() > 0.0001:
			d = d.normalized() * min_dist
			position.x = z.position.x + d.x
			position.z = z.position.z + d.y
	rotation.y = yaw
	# a little head bob
	camera.position.y = Data.config.player.eyeHeight + (sin(walk_phase) * 0.05 if walk != 0 else 0.0)
	camera.position.y += randf_range(-0.25, 0.25) * shake

	update_swing(delta, zombies, walk != 0)


# Presses are caught as they happen, so even a tap quicker than a frame isn't missed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and tagged <= 0:
		attack_queued = true


func update_swing(delta: float, zombies: Array, moving: bool) -> void:
	if attack_queued and swing <= 0:
		attack_queued = false
		swing = weapon.swingTime
		swing_hit = false
		Sound.play("swing")
	if swing <= 0:
		# a little sway as you walk
		hand.rotation = Vector3(sin(walk_phase * 0.5) * 0.04 if moving else 0.0, 0, 0)
		return
	swing -= delta
	var t: float = 1.0 - maxf(0.0, swing) / weapon.swingTime # 0 → 1 through the swing
	if not swing_hit and t >= 0.45:
		swing_hit = true
		var target := find_target(zombies)
		if target:
			bonked.emit(target, weapon, forward())
	# wind up, chop down towards the middle of the screen, then come back up
	var x: float
	var z: float
	if t < 0.25:
		var u: float = t / 0.25
		x = 0.5 * u
		z = -0.2 * u
	elif t < 0.55:
		var u: float = (t - 0.25) / 0.3
		x = 0.5 - 1.9 * u
		z = -0.2 + 0.9 * u
	else:
		var u: float = 1.0 - (t - 0.55) / 0.45
		x = -1.4 * u
		z = 0.7 * u
	hand.rotation = Vector3(x, 0, z) if swing > 0 else Vector3.ZERO


## Aim help: the nearest zombie roughly in front of you and in reach.
func find_target(zombies: Array) -> Zombie:
	var cos_limit := cos(deg_to_rad(weapon.aimAngle))
	var best: Zombie = null
	var best_dist := INF
	for z in zombies:
		if not z.alive:
			continue
		var to := Vector3(z.position.x - position.x, 0, z.position.z - position.z)
		var d: float = to.length() - z.radius
		if d > weapon.range or d >= best_dist:
			continue
		if to.length() > 0.001 and to.normalized().dot(forward()) < cos_limit:
			continue
		best = z
		best_dist = d
	return best
