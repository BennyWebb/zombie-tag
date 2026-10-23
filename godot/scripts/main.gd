extends Node3D
## Runs a level (like src/main.js): zombies arrive a few at a time, bonking them pops them into
## confetti and Tag Bux, a zombie touch costs a heart (lose them all and you're tagged), and once
## every zombie is popped the exit gate opens. Walk through it to finish.
##
## Walk in through the shop's or gym's door to spend Tag Bux or train.
##
## So far it's Sunny Park with one hero, on Easy (getting tagged costs nothing). The other weapons,
## two players, the other levels and the menus come in the later phases (see the plan in README.md).

const START_LEVEL := 1

var level: Level
var hero := Hero.new() # the same hero all the way through, so she keeps her Tag Bux
var effects := Effects.new()
var coins := Coins.new()
var hud := Hud.new()
var shop := ShopMenu.new()
var gym := GymMenu.new()
var zombies: Array[Zombie] = []
var zombie_holder := Node3D.new() # all the zombies go in here
var to_spawn := 0 # zombies still to arrive this level
var popped := 0
var finished := false
var paused := false
var coin_streak := 0 # coins picked up one after another go up in pitch
var last_coin := -1.0
var last_groan := -9.0
var time := 0.0


func _ready() -> void:
	add_child(effects)
	add_child(coins)
	add_child(hud)
	zombie_holder.name = "Zombies"
	add_child(zombie_holder)
	hud.root.add_child(shop)
	hud.root.add_child(gym)
	hero.bonked.connect(hit_zombie)
	hero.stick_broke.connect(stick_broke)
	add_child(hero)
	hero.camera.make_current()
	start_level(START_LEVEL)


func start_level(number: int) -> void:
	if level:
		level.queue_free()
	for z in zombies:
		z.queue_free()
	zombies.clear()
	coins.clear()
	if hero.inside:
		leave_building()
	level = Level.new(number)
	add_child(level)
	hero.level = level
	gym.level_number = number
	hero.respawn(level.info.playerStart) # full hearts, and armour shields filled up
	warm_up()
	to_spawn = int(level.info.zombies)
	popped = 0
	finished = false
	Sound.music(level.info.theme)
	hud.toast("Level %d: %s\nPop all the zombies, then find the exit gate!" % [number, level.info.name], 4)


## Draws everything that only shows up later once, too small to see, so the game doesn't stop for a
## moment the first time it appears (see Effects.warm_up).
func warm_up() -> void:
	var coin: Node3D = coins.coin_scene.instantiate()
	var zombie: Node3D = load("res://models/zombies/shuffler.glb").instantiate()
	effects.warm_up(hero.camera, [
		level.gate.find_child("open", true, false),
		coin,
		zombie.find_child("stars", true, false),
	])
	coin.free()
	zombie.free()


# The TV remote's Back button (Android's "go back") pauses too, instead of closing the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()


func toggle_pause() -> void:
	if finished:
		return # the Level done! screen is up
	paused = not paused
	hud.toast("Paused" if paused else "", 9999 if paused else 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif hero.inside and not paused:
		if hero.inside.handle_input(event):
			Sound.play("select")
			leave_building()
			hud.toast("See you soon! 👋", 1.5)
	elif event.is_action_pressed("attack") and finished:
		play_again()


## From the Level done! screen. The next level is made behind the screen, which goes a moment later,
## so any stop while it's made isn't seen. (The other levels come in phase 6.)
func play_again() -> void:
	start_level(level.info.number)
	get_tree().create_timer(0.2).timeout.connect(hud.hide_level_done)


func _process(delta: float) -> void:
	if paused or finished:
		return
	time += delta

	# (popped zombies leave the list straight away, so it only holds ones still standing)
	if to_spawn > 0 and zombies.size() <= Data.config.arena.nextWaveWhenLeft:
		spawn_wave()
	update_hero(delta)

	# every zombie popped: the exit gate opens, and all the coins fly to you
	var cleared := to_spawn == 0 and zombies.is_empty()
	for got in coins.update(delta, [hero], level, cleared):
		got[0].tag_bux += got[1]
		hud.bump_bux()
		# ka-ching, a little higher for each coin in a row
		coin_streak = coin_streak + 1 if time - last_coin < 0.6 else 0
		if time - last_coin > 0.05:
			Sound.play("coin", 1 + mini(coin_streak, 8) * 0.06)
		last_coin = time

	for z in zombies:
		z.update(delta, [hero], zombies)
		groan_now_and_then(z, delta)
		var d := Vector2(z.position.x - hero.position.x, z.position.z - hero.position.z).length()
		if z.can_tag() and d < z.radius + hero.radius + Data.config.player.touchDistance:
			zombie_touch(z)

	if cleared and not level.gate_open:
		level.open_gate()
		Sound.play("gate")
		hud.toast("All the zombies are popped!\nWalk through the glowing exit gate", 4)
	if level.at_gate(hero.position) and hero.tagged <= 0:
		finished = true
		# coins still on their way to you count too
		hero.tag_bux += coins.total()
		coins.clear()
		Sound.play("fanfare")
		hud.show_level_done(level.info.name, hero.tag_bux)
	hud.show_zombies_left(to_spawn + zombies.size(), level.gate_open)
	hud.update(hero)


func update_hero(delta: float) -> void:
	if hero.tagged > 0:
		hero.tagged -= delta
		if hero.tagged <= 0:
			hero.respawn(level.info.playerStart)
			hud.show_tagged(false)
			hud.toast("Back at the start with 3 hearts!", 2)
		return
	if hero.inside:
		return # the shop or gym has it (see _unhandled_input)
	hero.update(delta, zombies)
	# walk in through the shop's or gym's door
	for kind in level.doors:
		var door: Vector2 = level.doors[kind].door
		if Vector2(hero.position.x, hero.position.z).distance_to(door) < hero.radius + Data.config.shop.enterDistance:
			enter_building(shop if kind == "shop" else gym)


func enter_building(menu: MenuScreen) -> void:
	hero.inside = menu
	hero.hand.visible = false
	hud.toast_time = 0
	menu.open(hero)


func leave_building() -> void:
	var menu: MenuScreen = hero.inside
	menu.visible = false
	hero.inside = null
	hero.hand.visible = true
	hero.start_at(level.doors["shop" if menu == shop else "gym"].outside)
	hero.safe = Data.config.player.leaveShopSafeTime # a moment to get past zombies waiting at the door


func stick_broke() -> void:
	if hero.weapon:
		hud.toast("Your stick broke! 🪵💥\nNow holding the %s" % hero.weapon.name)
	else:
		hud.toast("Your stick broke! 🪵💥\nGet a free one at the 🛍️ shop")


## A zombie touched you: it costs a heart (or armour takes it), and the zombie bounces off and
## goes dizzy for a moment, so you can get away.
func zombie_touch(zombie: Zombie) -> void:
	var hurt := hero.hurt(zombie.type.touchHearts)
	if hurt == "":
		return
	var away := Vector3(zombie.position.x - hero.position.x, 0, zombie.position.z - hero.position.z).normalized()
	zombie.knock(away, zombie.type.bounceBack)
	zombie.dizzy = zombie.type.dizzyTime
	hud.flash(hurt)
	if hero.tagged > 0:
		Sound.play("tagged")
		hud.show_tagged(true) # on Easy you keep everything
	elif hurt == "shield":
		Sound.play("clang")
		hud.toast("Your armour blocked it!\nRun away!", 1.5)
	else:
		Sound.play("ouch")
		if zombie.type.touchHearts > 1:
			hud.toast("%s took %d hearts!\nRun away!" % [zombie.type.name, zombie.type.touchHearts], 1.5)
		else:
			hud.toast("Ouch! Last heart!\nRun away!" if hero.hearts == 1 else "Ouch! Run away!", 1.5)


## Zombies groan now and then, louder when they're close.
func groan_now_and_then(z: Zombie, delta: float) -> void:
	z.groan_in -= delta
	if z.groan_in > 0:
		return
	z.groan_in = randf_range(6, 14)
	var d := Vector2(z.position.x - hero.position.x, z.position.z - hero.position.z).length()
	if d < 18 and time - last_groan > 1.2:
		last_groan = time
		Sound.play("groan", randf_range(0.9, 1.15) / z.type.size, (1 - d / 18) * 0.9)


## A few zombies arrive, away from the hero.
func spawn_wave() -> void:
	for i in mini(Data.config.arena.waveSize, to_spawn):
		var kind := pick_kind()
		var spot = spawn_spot(Data.config.zombies[kind].radius + 0.5)
		if spot == null:
			break
		var z := Zombie.new(kind, level, level.info.healthMultiplier, spot.x, spot.y)
		zombie_holder.add_child(z)
		zombies.append(z)
		to_spawn -= 1


## Picks a kind of zombie for this level, more often the ones with a bigger number in its mix.
func pick_kind() -> String:
	var mix: Dictionary = level.info.mix
	var roll: float = randf() * mix.values().reduce(func(a, b): return a + b, 0.0)
	for kind in mix:
		roll -= mix[kind]
		if roll < 0:
			return kind
	return mix.keys()[0]


## A clear spot at least spawnAway from the hero, as a Vector2 (x, z), or null if there isn't one.
func spawn_spot(radius: float):
	var a: Dictionary = Data.config.arena
	for tries in 100:
		var x: float = randf_range(-0.5, 0.5) * (a.size - 6)
		var z: float = randf_range(-0.5, 0.5) * (a.size - 6)
		if Vector2(x - hero.position.x, z - hero.position.z).length() < a.spawnAway:
			continue
		if level.is_clear(x, z, radius):
			return Vector2(x, z)
	return null


func hit_zombie(zombie: Zombie, weapon: Dictionary, push: Vector3) -> void:
	if not zombie.alive:
		return
	if weapon.has("knockback"):
		zombie.knock(push, weapon.knockback)
	var wobble := randf_range(0.9, 1.15) # a little different every time, so it's not robotic
	var chicken: bool = weapon.id == "chickenHammer"
	Sound.play("squawk" if chicken else "bonk", wobble)
	var popping := zombie.hit(weapon.damage * hero.damage_multiplier())
	var word: String = weapon.get("word", "BONK!")
	# the chicken squawks on every hit, even ones that pop
	if chicken:
		effects.float_text(zombie.centre() + Vector3(0, 2.0 if popping else 0.8, 0), word, Color("ffe066"), 1.3)
	if popping:
		pop_zombie(zombie)
	elif not chicken:
		effects.float_text(zombie.centre() + Vector3(0, 0.8, 0), word, Color("ffe066"), 1.1)


func pop_zombie(zombie: Zombie) -> void:
	var size: float = zombie.type.size
	effects.confetti(zombie.centre())
	effects.float_text(zombie.centre() + Vector3(0, size, 0), "POP!", Color("9cff57"), 1.4 * size)
	coins.burst(zombie.centre(), zombie.type.tagBux)
	Sound.play("pop", randf_range(0.95, 1.15) / size)
	zombies.erase(zombie)
	zombie.queue_free()
	popped += 1
