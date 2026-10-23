class_name Hero
extends Node3D
## You! Seen from your own eyes: you walk and turn, and your hand swings, shoots, throws or zaps
## your weapon at the nearest zombie in front of you (like src/player.js). Zombie touches cost
## hearts; lose them all and you're tagged, and after a countdown you're back at the start. You keep
## your Tag Bux, weapons, armour, outfits and training from level to level.

const FIRE_SOUNDS := { # each shot's sound: [name, volume, pitch]
	water = ["squirt", 0.6, 1.0], slime = ["splat", 0.4, 0.6], bubble = ["bloop", 0.7, 0.8],
	snowball = ["whoosh", 0.7, 1.0], pumpkin = ["thump", 1.0, 1.0],
}

signal bonked(zombie: Zombie, weapon: Dictionary, push: Vector3, at) # a swing or the laser hit a zombie
signal stick_broke # your Spiky Stick broke (main.gd says so)

const HAND_REST := Vector3(0.38, -0.42, -0.65) # where the hand sits, from the camera

var level: Level # the level you're in (main.gd sets it)
var radius: float = Data.config.player.radius
var yaw := 0.0 # which way you face: 0 is towards -z, the middle of the level from the start
var speed_level: int = Data.config.player.startSpeed
var strength_level: int = Data.config.player.startStrength
var walk_phase := 0.0
var weapons: Array[Dictionary] = [] # every weapon you own, newest last: its numbers plus id (and hitsLeft)
var weapon = null # the one in your hand (one of weapons), or null if you have none
var swing := 0.0 # counts down while swinging
var swing_hit := false
var attack_queued := false # a press during a swing is remembered, so mashing never feels ignored
var cooldown := 0.0 # time until a shooting weapon can fire again
var recoil := 0.0 # the gun kicks back when it fires
var shots: Shots # where shots fly (main.gd sets it)
var thrown = null # the boomerang banana while it's flying (one of shots.list)
var beam: Beam # the Sparkle Star Laser Gun's beam

var tag_bux := 0
var hearts: int = Data.config.player.hearts
var shields := 0 # hits your armour can still block this level
var shields_max := 0 # how many your best armour blocks
var armour: Array[String] = [] # armour you own; only the best one counts
var outfits: Array[String] = [] # cool outfits you own
var wearing: Array[String] = [] # the ones you have on
var trained := {} # gym upgrades on each level: { level number: { speed = 1, strength = 1 } }
var bests := {} # fastest gym times, for "PERSONAL BEST!"
var inside = null # the shop or gym you're in, or null when you're outside
var stat_up := "" # "speed" or "strength" just after training, so the HUD's badge jumps
var safe := 0.0 # counts down while you can't be hurt, after a zombie touch
var tagged := 0.0 # counts down while you're tagged, before going back to the start
var shake := 0.0 # the camera wobbles for a moment when you're hurt

var camera := Camera3D.new()
var hand: Node3D
var sleeve: StandardMaterial3D # the hand's sleeve material, which outfits recolour


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
	var look: Dictionary = Data.config.heroes[0]
	Data.own_material(hand, "skin").albedo_color = Data.colour(look.skin)
	sleeve = Data.own_material(hand, "clothes")
	update_sleeve()
	beam = Beam.new(camera)
	add_child(beam)
	give_stick()


# ---------- weapons, armour, outfits and training ----------

func owns(id: String) -> bool:
	return weapons.any(func(w): return w.id == id)


## A new weapon goes straight into your hand.
func add_weapon(id: String) -> void:
	var w: Dictionary = Data.config.weapons[id].duplicate()
	w.id = id
	if w.has("maxHits"):
		w.hitsLeft = w.maxHits
	weapons.append(w)
	hold(id)


func give_stick() -> void:
	add_weapon("spikyStick")


func hold(id) -> void:
	weapon = null
	for w in weapons:
		if w.id == id:
			weapon = w
	attack_queued = false
	swing = 0
	hand.rotation = Vector3.ZERO
	hand.position = HAND_REST
	for model_id in Data.models.models.hand.weapons:
		hand.find_child(model_id, true, false).visible = weapon != null and model_id == weapon.id


## Your best armour's id, or "" if you have none.
func best_armour() -> String:
	var best := ""
	for id in armour:
		if best == "" or Data.config.armour[id].blocks > Data.config.armour[best].blocks:
			best = id
	return best


func add_armour(id: String) -> void:
	armour.append(id)
	refill_shields()


func refill_shields() -> void:
	var best := best_armour()
	shields_max = Data.config.armour[best].blocks if best != "" else 0
	shields = shields_max


## Put on an outfit you own, taking off anything it covers.
func wear(id: String) -> void:
	var covers: Array = Data.config.outfits[id].covers
	wearing = wearing.filter(func(w): return not Data.config.outfits[w].covers.any(func(c): return c in covers))
	wearing.append(id)
	update_sleeve()


func take_off(id: String) -> void:
	wearing.erase(id)
	update_sleeve()


## Your sleeve is your favourite colour, unless an outfit covers your body (clothesColour in
## src/hero.js). The rest of an outfit shows on your body, which your sister sees (phase 5).
func update_sleeve() -> void:
	var colour: int = Data.config.heroes[0].outfit
	if "unicornOnesie" in wearing:
		colour = 0xffffff
	elif "dancerOutfit" in wearing:
		colour = 0xd36bff
	elif "astronautSuit" in wearing:
		colour = 0xf2f2f2
	sleeve.albedo_color = Data.colour(colour)


func trained_on(level_number: int, stat: String) -> int:
	return trained.get(level_number, {}).get(stat, 0)


func add_training(level_number: int, stat: String) -> void:
	if not trained.has(level_number):
		trained[level_number] = {}
	trained[level_number][stat] = trained_on(level_number, stat) + 1


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
	if safe > 0 or tagged > 0 or inside:
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
		beam.hide_beam()
	return "heart"


## Back at the start with full hearts, after being tagged.
func respawn(spot: Dictionary) -> void:
	start_at(spot)
	hearts = Data.config.player.hearts
	refill_shields()
	tagged = 0
	safe = Data.config.player.safeTime
	swing = 0
	attack_queued = false
	cooldown = 0
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

	update_attack(delta, zombies, walk != 0)


# Presses are caught as they happen, so even a tap quicker than a frame isn't missed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and tagged <= 0 and not inside:
		attack_queued = true


func update_attack(delta: float, zombies: Array, moving: bool) -> void:
	cooldown -= delta
	recoil = maxf(0.0, recoil - delta * 8)
	var kind: String = weapon.kind if weapon else ""
	if kind != "beam":
		beam.hide_beam()
	beam.update(delta, weapon.starsPerSecond if kind == "beam" else 0.0)
	if kind != "swing":
		hand.position = HAND_REST
	match kind:
		"": attack_queued = false # (no weapon: get a free stick at the shop)
		"swing": update_swing(delta, zombies, moving)
		"shoot", "throw", "beam":
			update_aim(delta, zombies, kind)
			# holding a gun: a kick back when it fires, and a little sway as you walk
			hand.rotation = Vector3(recoil * 0.15 + (sin(walk_phase * 0.5) * 0.03 if moving else 0.0), 0, 0)
			hand.position = HAND_REST + Vector3(0, 0, recoil * 0.06)


## Shooting, throwing and zapping.
func update_aim(_delta: float, zombies: Array, kind: String) -> void:
	# where shots and the laser come out: just in front of the gun in your hand
	var fwd := forward()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var muzzle := position + fwd * 0.9 + right * 0.3
	muzzle.y = 1.2
	var holding := Input.is_action_pressed("attack") # hold the button to keep shooting
	var target := find_target(zombies)
	match kind:
		"beam":
			# a laser that hits whatever it's pointing at, again and again
			if holding or attack_queued:
				attack_queued = false
				beam.show_beam(muzzle, target.centre() if target else muzzle + fwd * weapon.range)
				if cooldown <= 0:
					cooldown = weapon.fireInterval
					Sound.play("pew")
					if target:
						bonked.emit(target, weapon, fwd, target.centre())
				recoil = 0.4
			else:
				beam.hide_beam()
		"throw":
			# the banana leaves your hand until it comes back
			hand.find_child(weapon.id, true, false).visible = thrown == null
			if attack_queued and thrown == null: # (a press while it's flying throws it again when it's back)
				var dir := fwd
				if target:
					dir = target.centre() - muzzle
					dir.y = 0
					dir = dir.normalized()
				shots.fire(muzzle, dir, weapon, self)
				Sound.play("whoosh")
				attack_queued = false
		"shoot":
			if (attack_queued or holding) and cooldown <= 0:
				attack_queued = false
				cooldown = weapon.fireInterval
				recoil = 1
				var dir := (target.centre() - muzzle).normalized() if target else fwd
				shots.fire(muzzle, dir, weapon, self, target.centre() if target else null)
				var sound: Array = FIRE_SOUNDS[weapon.shot]
				Sound.play(sound[0], sound[2], sound[1])


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
		# the Rubber Chicken Hammer bonks every zombie in front of you; the rest just the nearest
		var targets := find_targets(zombies) if weapon.get("hitsAll", false) else []
		if targets.is_empty() and not weapon.get("hitsAll", false):
			var target := find_target(zombies)
			if target:
				targets = [target]
		for target in targets:
			bonked.emit(target, weapon, forward(), null)
		if targets and weapon.has("maxHits"):
			weapon.hitsLeft -= 1
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
	if swing <= 0 and weapon.has("maxHits") and weapon.hitsLeft <= 0:
		# it broke: hold your newest other weapon, if you have one
		weapons.erase(weapon)
		hold(weapons.back().id if weapons else null)
		Sound.play("crack")
		stick_broke.emit()


## Every zombie roughly in front of you and in reach (for the Rubber Chicken Hammer).
func find_targets(zombies: Array) -> Array:
	var cos_limit := cos(deg_to_rad(weapon.aimAngle))
	var found := []
	for z in zombies:
		if not z.alive:
			continue
		var to := Vector3(z.position.x - position.x, 0, z.position.z - position.z)
		if to.length() - z.radius > weapon.range:
			continue
		if to.length() < 0.001 or to.normalized().dot(forward()) >= cos_limit:
			found.append(z)
	return found


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
