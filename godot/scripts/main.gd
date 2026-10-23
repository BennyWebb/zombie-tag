extends Node3D
## Runs a level (like src/main.js): zombies arrive a few at a time, bonking them pops them into
## confetti and Tag Bux, a zombie touch costs a heart (lose them all and you're tagged), and once
## every zombie is popped the exit gate opens. Walk through it to finish.
##
## Walk in through the shop's or gym's door to spend Tag Bux or train.
##
## Player 2 joins by pressing a button on a second joypad (see controls.gd): the screen splits in
## two, each sister with her own half, and there are half as many zombies again.
##
## So far it's Sunny Park, on Easy (getting tagged costs nothing). The other levels and the menus
## come in the later phases (see the plan in README.md).

const START_LEVEL := 1
const HUD_ZOOM_TWO_PLAYERS := 0.7 # with two players, everything on the HUD shrinks to fit half the screen
# the sound a shot makes when it hits (swinging weapons go "bonk")
const HIT_SOUNDS := { slime = "splat", bubble = "bloop", snowball = "poof", banana = "bonk" }

var level: Level
var heroes: Array[Hero] = [] # Player 1, and Player 2 once she joins; each keeps her Tag Bux all game
var huds: Array[Hud] = [] # each hero's HUD, shop and gym (in the same order)
var shops: Array[ShopMenu] = []
var gyms: Array[GymMenu] = []
var effects := Effects.new()
var coins := Coins.new()
var shots := Shots.new()
# with two players, each half of the screen is drawn by its own SubViewport (with that hero's
# camera in it), and shown by a TextureRect on view_layer, under the HUDs
var view_layer := CanvasLayer.new()
var sub_views: Array[SubViewport] = []
var view_rects: Array[TextureRect] = []
var divider := ColorRect.new()
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
	add_child(shots)
	zombie_holder.name = "Zombies"
	add_child(zombie_holder)
	view_layer.layer = -1
	add_child(view_layer)
	add_hero()
	heroes[0].camera.make_current()
	Controls.player_two_joined.connect(player_two_joined)
	get_viewport().size_changed.connect(arrange_views)
	start_level(START_LEVEL)


## A new hero, with her own HUD, shop and gym.
func add_hero() -> Hero:
	var hero := Hero.new(heroes.size())
	hero.bonked.connect(hit_zombie.bind(hero))
	hero.stick_broke.connect(stick_broke.bind(hero))
	hero.shots = shots
	add_child(hero)
	heroes.append(hero)
	var hud := Hud.new(hero.index)
	add_child(hud)
	huds.append(hud)
	var shop := ShopMenu.new()
	var gym := GymMenu.new()
	hud.root.add_child(shop)
	hud.root.add_child(gym)
	shops.append(shop)
	gyms.append(gym)
	return hero


func two_players() -> bool:
	return heroes.size() == 2


## Player 2 pressed a button on her joypad: she starts at the beginning of this level, with a
## Spiky Stick, and the screen splits in two.
func player_two_joined() -> void:
	var hero := add_hero()
	hero.level = level
	gyms[1].level_number = level.info.number
	for h in heroes:
		h.tagged_time = Data.config.player.taggedTimeTwoPlayers # you wait longer, while your sister carries on
	hero.respawn(start_for(hero))
	# each can give the other Tag Bux in the shop
	shops[0].partner = heroes[1]
	shops[1].partner = heroes[0]
	if not level.gate_open:
		to_spawn += roundi(level.info.zombies * (Data.config.twoPlayerZombies - 1)) # more zombies for two
	split_screen()
	Sound.play("yay")
	toast_all("%s is here! 👋" % hero.look.name, 2.5)


## Gives each hero her own half of the screen.
func split_screen() -> void:
	for hero in heroes:
		var sub := SubViewport.new()
		sub.msaa_3d = get_viewport().msaa_3d
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sub) # (it draws the same world as the main screen)
		hero.camera.reparent(sub)
		hero.camera.make_current()
		sub_views.append(sub)
		var rect := TextureRect.new()
		rect.texture = sub.get_texture()
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		view_layer.add_child(rect)
		view_rects.append(rect)
	divider.color = Color.WHITE
	view_layer.add_child(divider)
	arrange_views()


## Sizes the halves of the screen to fit the window (each draws at the window's real size, so it's
## sharp on a big TV), with each hero's HUD on top of her half.
func arrange_views() -> void:
	if not two_players():
		return
	var screen := get_viewport().get_visible_rect().size # (in the HUD's units, 1280 x 720 or so)
	var pixels := Vector2(get_window().size)
	for i in 2:
		sub_views[i].size = Vector2i(roundi(pixels.x / 2), roundi(pixels.y))
		view_rects[i].position = Vector2(screen.x / 2 * i, 0)
		view_rects[i].size = Vector2(screen.x / 2, screen.y)
		huds[i].set_view(Rect2(view_rects[i].position, view_rects[i].size), HUD_ZOOM_TWO_PLAYERS, true)
	divider.size = Vector2(3, screen.y)
	divider.position = Vector2(screen.x / 2 - 1.5, 0)


## Where each hero begins: side by side with two players.
func start_for(hero: Hero) -> Dictionary:
	var s: Dictionary = level.info.playerStart
	var side := 0.0 if not two_players() else -1.5 if hero.index == 0 else 1.5
	return { x = s.x + side, z = s.z, yaw = s.yaw }


func start_level(number: int) -> void:
	for hero in heroes:
		if hero.inside:
			leave_building(hero)
	if level:
		level.queue_free()
	for z in zombies:
		z.queue_free()
	zombies.clear()
	coins.clear()
	shots.clear()
	level = Level.new(number)
	add_child(level)
	for i in heroes.size():
		heroes[i].level = level
		gyms[i].level_number = number
		heroes[i].respawn(start_for(heroes[i])) # full hearts, and armour shields filled up
	warm_up()
	to_spawn = roundi(level.info.zombies * (Data.config.twoPlayerZombies if two_players() else 1.0))
	popped = 0
	finished = false
	Sound.music(level.info.theme)
	var text := "Level %d: %s\nPop all the zombies, then find the exit gate!" % [number, level.info.name]
	if not two_players():
		text += "\nPlayer 2? Press %s on another controller to join" % Controls.button()
	toast_all(text, 4)


func toast_all(text: String, seconds := 2.5) -> void:
	for hud in huds:
		hud.toast(text, seconds)


## Draws everything that only shows up later once, too small to see, so the game doesn't stop for a
## moment the first time it appears (see Effects.warm_up).
func warm_up() -> void:
	var camera := heroes[0].camera
	var coin: Node3D = coins.coin_scene.instantiate()
	var zombie: Node3D = load("res://models/zombies/shuffler.glb").instantiate()
	var hidden: Array[Node3D] = [level.gate.find_child("open", true, false), coin, Zombie.make_health_bar(1)]
	for part in ["stars", "bubble", "ice"]:
		hidden.append(zombie.find_child(part, true, false))
	var flying := []
	for shot in shots.looks:
		flying.append(shots.looks[shot].instantiate())
	hidden.append_array(flying)
	hidden.append(heroes[0].beam.tube)
	effects.warm_up(camera, hidden)
	heroes[0].beam.warm_up(camera.global_position - camera.global_basis.z * 2.0)
	coin.free()
	zombie.free()
	hidden[2].free()
	for node in flying:
		node.free()


# The TV remote's Back button (Android's "go back") pauses too, instead of closing the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()


func toggle_pause() -> void:
	if finished:
		return # the Level done! screen is up
	paused = not paused
	toast_all("Paused" if paused else "", 9999 if paused else 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif finished:
		if Controls.is_anyones(event, "attack"):
			play_again()
	elif not paused:
		# a hero in the shop or gym uses it (each with her own buttons)
		for hero in heroes:
			if hero.inside and hero.inside.handle_input(event):
				Sound.play("select")
				leave_building(hero)
				huds[hero.index].toast("See you soon! 👋", 1.5)


## From the Level done! screen. The next level is made behind the screen, which goes a moment later,
## so any stop while it's made isn't seen. (The other levels come in phase 6.)
func play_again() -> void:
	start_level(level.info.number)
	for hud in huds:
		get_tree().create_timer(0.2).timeout.connect(hud.hide_level_done)


func _process(delta: float) -> void:
	if paused or finished:
		return
	time += delta

	# (popped zombies leave the list straight away, so it only holds ones still standing)
	if to_spawn > 0 and zombies.size() <= Data.config.arena.nextWaveWhenLeft:
		spawn_wave()
	for hero in heroes:
		update_hero(hero, delta)
	keep_sisters_apart()
	for hit in shots.update(delta, zombies):
		if hit.has("splat"):
			# a pumpkin landed: a big orange splat
			effects.splash(hit.at, "pumpkin", 60, 2.5)
			Sound.play("splat", 2)
			effects.float_text(hit.at + Vector3(0, 1.2, 0), hit.weapon.word, Color("ff8a1f"), 1.8)
		else:
			hit_zombie(hit.zombie, hit.weapon, hit.push, hit.at, hit.by)

	# every zombie popped: the exit gate opens, and all the coins fly to you
	var cleared := to_spawn == 0 and zombies.is_empty()
	for got in coins.update(delta, heroes, level, cleared):
		got[0].tag_bux += got[1]
		huds[got[0].index].bump_bux()
		# ka-ching, a little higher for each coin in a row
		coin_streak = coin_streak + 1 if time - last_coin < 0.6 else 0
		if time - last_coin > 0.05:
			Sound.play("coin", 1 + mini(coin_streak, 8) * 0.06)
		last_coin = time

	for z in zombies:
		z.update(delta, heroes, zombies)
		groan_now_and_then(z, delta)
		for hero in heroes:
			var d := Vector2(z.position.x - hero.position.x, z.position.z - hero.position.z).length()
			if z.can_tag() and d < z.radius + hero.radius + Data.config.player.touchDistance:
				zombie_touch(z, hero)

	if cleared and not level.gate_open:
		level.open_gate()
		Sound.play("gate")
		toast_all("All the zombies are popped!\nWalk through the glowing exit gate", 4)
	for hero in heroes:
		if level.at_gate(hero.position) and hero.tagged <= 0 and not hero.inside:
			level_done()
			break
	for i in heroes.size():
		huds[i].show_zombies_left(to_spawn + zombies.size(), level.gate_open)
		huds[i].update(heroes[i])
		heroes[i].update_body(delta, two_players())


## Either sister walking through the gate finishes the level for both.
func level_done() -> void:
	finished = true
	# coins still on their way count too, shared out
	var share := coins.total() / heroes.size()
	for hero in heroes:
		hero.tag_bux += share
	heroes[0].tag_bux += coins.total() - share * heroes.size()
	coins.clear()
	Sound.play("fanfare")
	for i in heroes.size():
		huds[i].show_level_done(level.info.name, heroes[i].tag_bux)


func update_hero(hero: Hero, delta: float) -> void:
	var hud := huds[hero.index]
	if hero.tagged > 0:
		hero.update(delta, zombies) # (just the camera)
		hero.tagged -= delta
		if hero.tagged <= 0:
			hero.respawn(start_for(hero))
			hud.show_tagged(false)
			hud.toast("Back at the start with 3 hearts!", 2)
		return
	if hero.inside:
		return # the shop or gym has her (see _unhandled_input)
	hero.update(delta, zombies)
	# walk in through the shop's or gym's door
	for kind in level.doors:
		var door: Vector2 = level.doors[kind].door
		if Vector2(hero.position.x, hero.position.z).distance_to(door) < hero.radius + Data.config.shop.enterDistance:
			enter_building(hero, shops[hero.index] if kind == "shop" else gyms[hero.index])


## Sisters can't walk through each other.
func keep_sisters_apart() -> void:
	if not two_players() or heroes.any(func(h): return h.inside or h.tagged > 0):
		return
	var a := heroes[0]
	var b := heroes[1]
	var d := Vector2(b.position.x - a.position.x, b.position.z - a.position.z)
	var min_dist := a.radius + b.radius
	if d.length() < min_dist and d.length() > 0.0001:
		var push := d.normalized() * (min_dist - d.length()) / 2
		a.position -= Vector3(push.x, 0, push.y)
		b.position += Vector3(push.x, 0, push.y)


func enter_building(hero: Hero, menu: MenuScreen) -> void:
	hero.inside = menu
	hero.hand.visible = false
	hero.beam.hide_beam()
	huds[hero.index].toast_time = 0
	menu.open(hero)


func leave_building(hero: Hero) -> void:
	var menu: MenuScreen = hero.inside
	menu.visible = false
	hero.inside = null
	hero.hand.visible = true
	hero.start_at(level.doors["shop" if menu is ShopMenu else "gym"].outside)
	hero.safe = Data.config.player.leaveShopSafeTime # a moment to get past zombies waiting at the door


func stick_broke(hero: Hero) -> void:
	if hero.weapon:
		huds[hero.index].toast("Your stick broke! 🪵💥\nNow holding the %s" % hero.weapon.name)
	else:
		huds[hero.index].toast("Your stick broke! 🪵💥\nGet a free one at the 🛍️ shop")


## A zombie touched a hero: it costs a heart (or armour takes it), and the zombie bounces off and
## goes dizzy for a moment, so she can get away.
func zombie_touch(zombie: Zombie, hero: Hero) -> void:
	var hurt := hero.hurt(zombie.type.touchHearts)
	if hurt == "":
		return
	var hud := huds[hero.index]
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


## How far the nearest hero is from a spot on the ground.
func nearest_hero_distance(x: float, z: float) -> float:
	var nearest := INF
	for hero in heroes:
		nearest = minf(nearest, Vector2(x - hero.position.x, z - hero.position.z).length())
	return nearest


## Zombies groan now and then, louder when they're close.
func groan_now_and_then(z: Zombie, delta: float) -> void:
	z.groan_in -= delta
	if z.groan_in > 0:
		return
	z.groan_in = randf_range(6, 14)
	var d := nearest_hero_distance(z.position.x, z.position.z)
	if d < 18 and time - last_groan > 1.2:
		last_groan = time
		Sound.play("groan", randf_range(0.9, 1.15) / z.type.size, (1 - d / 18) * 0.9)


## A few zombies arrive, away from the heroes.
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


## A clear spot at least spawnAway from every hero, as a Vector2 (x, z), or null if there isn't one.
func spawn_spot(radius: float):
	var a: Dictionary = Data.config.arena
	for tries in 100:
		var x: float = randf_range(-0.5, 0.5) * (a.size - 6)
		var z: float = randf_range(-0.5, 0.5) * (a.size - 6)
		if nearest_hero_distance(x, z) < a.spawnAway:
			continue
		if level.is_clear(x, z, radius):
			return Vector2(x, z)
	return null


## A weapon hit a zombie. push: which way it's knocked; at: where a shot landed, for a splash
## (or null); by: the hero whose weapon it was (her Strength counts).
func hit_zombie(zombie: Zombie, weapon: Dictionary, push: Vector3, at, by: Hero) -> void:
	if not zombie.alive:
		return
	if weapon.has("shot") and at != null:
		effects.splash(at, weapon.shot)
	zombie.weapon_effects(weapon)
	if weapon.has("knockback"):
		zombie.knock(push, weapon.knockback)
	var wobble := randf_range(0.9, 1.15) # a little different every time, so it's not robotic
	var chicken: bool = weapon.id == "chickenHammer"
	if chicken:
		Sound.play("squawk", wobble)
	elif weapon.kind == "swing":
		Sound.play("bonk", wobble)
	elif HIT_SOUNDS.has(weapon.get("shot", "")):
		Sound.play(HIT_SOUNDS[weapon.shot], wobble * (1.3 if weapon.shot == "banana" else 1.0))
	var popping := zombie.hit(weapon.damage * by.damage_multiplier())
	var word: String = weapon.get("word", "BONK!")
	# the chicken squawks on every hit, even ones that pop
	if chicken:
		effects.float_text(zombie.centre() + Vector3(0, 2.0 if popping else 0.8, 0), word, Color("ffe066"), 1.3)
	if popping:
		pop_zombie(zombie)
	elif not chicken and time - zombie.word_time > 0.6:
		# fast weapons hit so often that they only say their word now and then
		zombie.word_time = time
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
