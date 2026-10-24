class_name Hero
extends Node3D
## You! Seen from your own eyes: you walk and turn, and your hand swings, shoots, throws or zaps
## your weapon at the nearest zombie in front of you (like src/player.js). Zombie touches cost
## hearts; lose them all and you're tagged, and after a countdown you're back at the start. You keep
## your Tag Bux, weapons, armour, outfits and training from level to level.
## In 2-player mode your sister sees your whole body (HeroBody), with your name over your head.

const FIRE_SOUNDS := { # each shot's sound: [name, volume, pitch]
	water = ["squirt", 0.6, 1.0], slime = ["splat", 0.4, 0.6], bubble = ["bloop", 0.7, 0.8],
	snowball = ["whoosh", 0.7, 1.0], pumpkin = ["thump", 1.0, 1.0],
}

signal bonked(zombie: Zombie, weapon: Dictionary, push: Vector3, at) # a swing or the laser hit a zombie
signal stick_broke # your Spiky Stick broke (main.gd says so)

const HAND_REST := Vector3(0.38, -0.42, -0.65) # where the hand sits, from the camera
# what each camera draws (its visual layers): the world on layer 1, each player's hand on layer 2
# or 3 (only she sees it) and each player's body on layer 4 or 5 (only her sister sees it)
const WORLD_LAYER := 1

var index: int # 0 for Player 1, 1 for Player 2
var look: Dictionary # name, skin, hairStyle, hair, outfit, trousers, tagColour
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
var battery := 99.0 # the laser's zaps left (it fills up to its battery size: see update_attack)
var battery_flat := false # it's run out, so it won't zap till it's full again
var zapping := false # the laser zapped this frame (so its battery doesn't refill)
var recoil := 0.0 # the gun kicks back when it fires
var shots: Shots # where shots fly (main.gd sets it)
var thrown = null # the boomerang banana while it's flying (one of shots.list)
var beam: Beam # the Sparkle Star Laser Gun's beam

var profile_id := "" # which saved hero this is (see save.gd), or "" for none
var created := false # true once she's been through the character creator
var unlocked := 1 # how many levels she can play
var finished: Array[int] = [] # the levels she's finished (their numbers)
var run := "normal" # which game is loaded: "normal" (Easy and Hard) or "hardcore"
var other_run = null # the other game, put aside (see use_run), or null if she's never played it
var out := false # Hardcore: tagged, so out until the level ends
var through_gate := false # through the open exit gate, waiting for the other player
var picked_with_pad := false # whether she picked her hero with a joypad (so she spells her name with one)

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
var tagged_time: float = Data.config.player.taggedTime # how long that is (main.gd sets it)
var shake := 0.0 # the camera wobbles for a moment when you're hurt

var camera := Camera3D.new() # your eyes (main.gd moves it to your half of the screen with 2 players)
var eye := Vector3.ZERO # where the camera is, from your feet (with a bob and a wobble)
var hand: Node3D
var skin: StandardMaterial3D # the hand's skin and sleeve materials
var sleeve: StandardMaterial3D
var body: HeroBody # your whole body, which only your sister sees
var last_position := Vector3.ZERO # for how fast your body walks
var time := 0.0


## player: 0 for Player 1, 1 for Player 2.
func _init(player: int) -> void:
	index = player
	look = Data.config.heroes[player].duplicate()


## The name of one of your actions, like "p1_attack" (see controls.gd).
func act(action_name: String) -> String:
	return Controls.action(action_name, index)


func _ready() -> void:
	camera.fov = 70 # like the browser game (both measure it top to bottom)
	camera.near = 0.05
	camera.far = 300
	camera.top_level = true # it follows you (see place_camera), wherever it is
	camera.cull_mask = camera_layers()
	add_child(camera)
	eye.y = Data.config.player.eyeHeight
	# the first-person hand, holding every weapon; only the one you're holding shows
	hand = load("res://models/hand.glb").instantiate()
	camera.add_child(hand)
	Data.remove_extra_shadows(hand) # your hand doesn't cast a shadow, like in the browser game
	for node in hand.find_children("*", "VisualInstance3D", true, false):
		node.layers = hand_layer(index)
	hand.position = HAND_REST
	skin = Data.own_material(hand, "skin")
	sleeve = Data.own_material(hand, "clothes")
	rebuild_body()
	beam = Beam.new()
	add_child(beam)
	give_stick()


# ---------- saving, and the normal and Hardcore games ----------

## Everything worth keeping between days: her looks and outfits, and both her games (the one
## she's not playing is kept in "hardcore", or the other way round).
func to_save() -> Dictionary:
	var current := run_to_save()
	var d := { id = profile_id, look = look, created = created, outfits = outfits, wearing = wearing }
	d.merge(other_run if run == "hardcore" else current)
	d.hardcore = current if run == "hardcore" else other_run
	return d


## Loads a saved hero in her normal game (main.gd switches to Hardcore if that's chosen).
func from_save(d: Dictionary) -> void:
	profile_id = d.id
	# the name tag colour belongs to the slot, so a hero can play as Player 1 or Player 2
	look = Data.config.heroes[index].duplicate()
	look.merge(d.look, true)
	look.tagColour = Data.config.heroes[index].tagColour
	created = d.get("created", false)
	outfits.assign(d.get("outfits", []).filter(func(id): return Data.config.outfits.has(id)))
	wearing.assign(d.get("wearing", []).filter(func(id): return id in outfits))
	run_from_save(d)
	run = "normal"
	other_run = d.get("hardcore")
	# a Hardcore game saved after beating the King starts fresh too
	if other_run and 10 in other_run.get("finished", []):
		other_run = null
	rebuild_body()


## A brand-new hero, before the character creator.
func blank(id: String) -> void:
	from_save({ id = id, look = { name = "Player %d" % (index + 1) }, created = false })


func set_look(changes: Dictionary) -> void:
	look.merge(changes, true)
	rebuild_body()


## One game's progress: Tag Bux, weapons, armour, training and levels.
func run_to_save() -> Dictionary:
	return {
		tagBux = tag_bux,
		weapons = weapons.map(func(w): return { id = w.id, hitsLeft = w.get("hitsLeft") }),
		holding = weapon.id if weapon else null,
		armour = armour,
		speedLevel = speed_level,
		strengthLevel = strength_level,
		bests = bests,
		unlocked = unlocked,
		finished = finished,
		trained = trained,
	}


## (A missing part starts fresh, so a new hero, or one saved before something was added, works.)
func run_from_save(d: Dictionary) -> void:
	var c: Dictionary = Data.config
	tag_bux = int(d.get("tagBux", 0))
	weapons.clear()
	# only things that still exist in config.json, in case the numbers have changed
	for saved in d.get("weapons", [{ id = "spikyStick" }]):
		if c.weapons.has(saved.id):
			var w: Dictionary = c.weapons[saved.id].duplicate()
			w.id = saved.id
			if w.has("maxHits"):
				w.hitsLeft = int(saved.hitsLeft) if saved.get("hitsLeft") != null else int(w.maxHits)
			weapons.append(w)
	var holding = d.get("holding", "spikyStick")
	hold(holding if holding is String and owns(holding) else null)
	armour.assign(d.get("armour", []).filter(func(id): return c.armour.has(id)))
	speed_level = int(d.get("speedLevel", c.player.startSpeed))
	strength_level = int(d.get("strengthLevel", c.player.startStrength))
	bests = d.get("bests", {})
	unlocked = mini(c.levels.size(), int(d.get("unlocked", 1)))
	finished.assign(d.get("finished", []).map(func(n): return int(n)))
	# (JSON keeps the level numbers as text, so they're turned back into numbers)
	trained = {}
	for key in d.get("trained", {}):
		trained[int(key)] = d.trained[key]
	refill_shields()


## Starting from nothing: a Spiky Stick, no Tag Bux, Speed and Strength 1, level 1.
func fresh_run() -> void:
	run_from_save({})


## Swaps to the normal or the Hardcore game, putting the other one aside.
func use_run(kind: String) -> void:
	if kind == run:
		return
	var aside = other_run
	other_run = run_to_save()
	run = kind
	if aside:
		run_from_save(aside)
	else:
		fresh_run()


## Hard: getting tagged takes your weapons and armour (you get a Spiky Stick back).
func lose_items() -> void:
	weapons.clear()
	armour.clear()
	refill_shields()
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
	rebuild_body()


func take_off(id: String) -> void:
	wearing.erase(id)
	rebuild_body()


## The visual layers for each player's hand and body (see WORLD_LAYER).
static func hand_layer(player: int) -> int:
	return 1 << (1 + player)


static func body_layer(player: int) -> int:
	return 1 << (3 + player)


## Makes your body (and the hand you see) match your look and outfits.
func rebuild_body() -> void:
	var was_visible := body != null and body.visible
	if body:
		body.queue_free()
	body = HeroBody.new(look, wearing, body_layer(index))
	body.visible = was_visible
	add_child(body)
	skin.albedo_color = Data.colour(look.skin)
	# your sleeve is your favourite colour, unless an outfit covers your body
	sleeve.albedo_color = Data.colour(HeroBody.clothes_colour(look, wearing))


## Moves and animates your body for your sister to see. show: whether there's a sister to see it.
func update_body(delta: float, show: bool) -> void:
	time += delta
	body.visible = show and not inside and tagged <= 0 and not through_gate
	if not body.visible:
		return
	var moved := Vector2(position.x - last_position.x, position.z - last_position.z).length() / maxf(delta, 0.001)
	last_position = position
	body.animate(walk_phase, moved, swing > 0 or recoil > 0.3, time)


func trained_on(level_number: int, stat: String) -> int:
	return trained.get(level_number, {}).get(stat, 0)


func add_training(level_number: int, stat: String) -> void:
	if not trained.has(level_number):
		trained[level_number] = {}
	trained[level_number][stat] = trained_on(level_number, stat) + 1


func start_at(spot: Dictionary) -> void:
	position = Vector3(spot.x, 0, spot.z)
	last_position = position
	yaw = spot.yaw
	rotation.y = yaw
	place_camera()


## The camera goes where your eyes are. (It isn't simply a child of yours, because with two players
## it has to be inside your half of the screen.)
## What her camera draws: the world, her own hand, and the other hero's body.
func camera_layers() -> int:
	return WORLD_LAYER | hand_layer(index) | body_layer(1 - index)


func place_camera() -> void:
	camera.global_transform = Transform3D(Basis(Vector3.UP, yaw), position + Basis(Vector3.UP, yaw) * eye)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func move_speed() -> float:
	var p: Dictionary = Data.config.player
	return p.baseSpeed * (1 + (speed_level - 1) * p.speedPerLevel)


func damage_multiplier() -> float:
	return 1 + (strength_level - 1) * Data.config.player.strengthPerLevel


## A zombie touch. Returns "" if you couldn't be hurt just now, "shield" if your armour blocked it,
## or "heart" if it cost you hearts (and then `tagged` says whether that was your last).
## ignore_armour: the Zombie King on Hard and Hardcore, who tags you in one go.
func hurt(amount: int, ignore_armour := false) -> String:
	if safe > 0 or tagged > 0 or inside or through_gate:
		return ""
	safe = Data.config.player.safeTime
	shake = 0.3
	if shields > 0 and not ignore_armour:
		shields -= 1
		return "shield"
	hearts = maxi(0, hearts - amount)
	if hearts == 0:
		tagged = tagged_time
		hand.visible = false
		beam.hide_beam()
	return "heart"


## Back at the start with full hearts, after being tagged.
func respawn(spot: Dictionary) -> void:
	out = false
	through_gate = false
	body.visible = true
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
	eye.x = randf_range(-0.25, 0.25) * shake
	safe = maxf(0.0, safe - delta)
	if tagged > 0:
		place_camera()
		return # main.gd counts down and brings you back
	hand.visible = safe <= 0 or int(safe * 8) % 2 == 0

	# turning: keys turn a little faster than a joypad, which is easy to overshoot with
	var turn := Input.get_axis(act("turn_right"), act("turn_left"))
	var turn_speed: float = Data.config.controls.padTurnSpeed if Controls.using_joypad[index] else Data.config.player.turnSpeed
	yaw += turn * turn_speed * delta
	# walking: a bit slower backwards
	var walk := Input.get_axis(act("walk_back"), act("walk_forward"))
	if walk < 0:
		walk *= 0.7
	# stepping sideways (the left stick, with "Two sticks" joypads)
	var side := Input.get_axis(act("step_left"), act("step_right")) * 0.8
	if walk != 0 or side != 0:
		var fwd := forward()
		position += fwd * walk * move_speed() * delta
		position += Vector3(-fwd.z, 0, fwd.x) * side * move_speed() * delta
		walk_phase += delta * move_speed() * 2.2 * maxf(absf(walk), absf(side))
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
	eye.y = Data.config.player.eyeHeight + (sin(walk_phase) * 0.05 if walk != 0 or side != 0 else 0.0)
	eye.y += randf_range(-0.25, 0.25) * shake
	place_camera()

	update_attack(delta, zombies, walk != 0 or side != 0)


# Presses are caught as they happen, so even a tap quicker than a frame isn't missed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(act("attack")) and tagged <= 0 and not inside:
		attack_queued = true


func update_attack(delta: float, zombies: Array, moving: bool) -> void:
	cooldown -= delta
	recoil = maxf(0.0, recoil - delta * 8)
	# the laser's battery refills while it isn't zapping
	if weapon and weapon.has("battery") and not zapping:
		battery = minf(weapon.battery, battery + weapon.battery / weapon.rechargeTime * delta)
		if battery >= weapon.battery:
			battery_flat = false
	zapping = false
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
	var holding := Input.is_action_pressed(act("attack")) # hold the button to keep shooting
	var target := find_target(zombies)
	match kind:
		"beam":
			# a laser that hits whatever it's pointing at, again and again, while its battery lasts
			# (each zap uses one; once it's run out, it can't zap again till it's full)
			if (holding or attack_queued) and not battery_flat:
				attack_queued = false
				zapping = true
				beam.show_beam(muzzle, target.centre() if target else muzzle + fwd * weapon.range)
				if cooldown <= 0:
					cooldown = weapon.fireInterval
					Sound.play("pew")
					if target:
						bonked.emit(target, weapon, fwd, target.centre())
					battery -= 1
					if battery < 1:
						battery_flat = true
						Sound.play("nope")
				recoil = 0.4
			else:
				attack_queued = false
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
			# a press long before the gun's ready again doesn't count (it fired a second pumpkin after
			# the first had splatted), and only the quick guns keep firing while the button's held
			if attack_queued and cooldown > 0.25:
				attack_queued = false
			var repeat: bool = holding and weapon.fireInterval < 1.0
			if (attack_queued or repeat) and cooldown <= 0:
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
