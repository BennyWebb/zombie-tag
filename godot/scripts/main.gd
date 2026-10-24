extends Node3D
## Runs a level (like src/main.js): zombies arrive a few at a time, bonking them pops them into
## confetti and Tag Bux, a zombie touch costs a heart (lose them all and you're tagged), and once
## every zombie is popped the exit gate opens. Walk through it to finish.
##
## Walk in through the shop's or gym's door to spend Tag Bux or train.
##
## It starts on the title screen (screens.gd), over the level slowly turning: 1 or 2 players, who's
## playing, the character creator, how hard, and which level. With two players the screen splits
## in two, each sister with her own half, and there are half as many zombies again.
##
## The ten levels come one after another. In the last, the Zombie King's castle, he arrives with his
## guards once every other zombie is popped, and beating him starts a party.
##
## How hard: on Easy, getting tagged costs nothing; on Hard you lose your weapons and armour; on
## Hardcore there are twice the zombies and one life (get tagged and your Hardcore game starts
## again). The King is tougher on Hard and Hardcore, and tags you in one go.
##
## Progress is saved (save.gd) at the start of each level, after shopping or training, when you're
## tagged and when a level's done.
const BEHIND_WARNING := 6.0 # a zombie this close behind you (in metres) makes the HUD warn you
const HUD_ZOOM_TWO_PLAYERS := 0.7 # with two players, everything on the HUD shrinks to fit half the screen
const HUD_ZOOM_FOUR_PLAYERS := 0.5 # and with three or four, to fit a quarter
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
var fly_layer := CanvasLayer.new() # Tag Bux flying from one player to the other (see fly_coins)
var view_layer := CanvasLayer.new()
var sub_views: Array[SubViewport] = []
var view_rects: Array[TextureRect] = []
var divider := ColorRect.new() # the white line between the views (down the middle)
var divider_across := ColorRect.new() # (and across, with three or four players)
var spare_corner := PanelContainer.new() # the fourth quarter of the screen, with three players
var spare_left := Label.new() # (it says how many zombies are left)
var zombies: Array[Zombie] = []
var zombie_holder := Node3D.new() # all the zombies go in here
var boss: Zombie = null # the Zombie King, once he arrives
var boss_came := false # (once he's popped, boss reads as null again, so this remembers he came)
var party: Party = null # the party after beating him
var screens: Screens # the start screens and menus
var in_game := false # false while the menus are up, with the level turning behind them
var menu_camera := Camera3D.new() # the camera going slowly round the level behind the menus
var left_building_at := -9999 # when someone last left the shop or gym (ms), see _notification
var game_over_in := 0.0 # Hardcore: counts down to the GAME OVER! screen once everyone's out
var zombie_scenes := [] # this level's kinds of zombie, loaded at the start (see warm_up)
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
	fly_layer.layer = 5 # (above the HUDs)
	add_child(fly_layer)
	menu_camera.fov = 70
	add_child(menu_camera)
	add_hero()
	make_views()
	Controls.set_one_player()
	get_viewport().size_changed.connect(arrange_views)
	screens = Screens.new(self)
	add_child(screens)
	screens.to_title()


## A new hero, with her own HUD, shop and gym.
func add_hero() -> Hero:
	var hero := Hero.new(heroes.size())
	hero.bonked.connect(hit_zombie.bind(hero))
	hero.stick_broke.connect(stick_broke.bind(hero))
	hero.shots = shots
	add_child(hero)
	heroes.append(hero)
	var hud := Hud.new(hero.index)
	hud.visible = in_game
	add_child(hud)
	huds.append(hud)
	var shop := ShopMenu.new()
	shop.gave.connect(fly_coins)
	var gym := GymMenu.new()
	hud.root.add_child(shop)
	hud.root.add_child(gym)
	shops.append(shop)
	gyms.append(gym)
	return hero


## More than one player: the screen's split, and everyone sees everyone else.
func two_players() -> bool:
	return heroes.size() >= 2


## A hero leaves, with her HUD, shop and gym (going back to 1 player).
func remove_hero() -> void:
	var hero: Hero = heroes.pop_back()
	hero.queue_free()
	huds.pop_back().queue_free()
	shops.pop_back()
	gyms.pop_back()


## 1 to 4 players, chosen on the title screen: with two the screen splits in two, and with three or
## four into quarters.
func set_player_count(count: int) -> void:
	while heroes.size() > count:
		remove_hero()
	while heroes.size() < count:
		add_hero()
	for hero in heroes:
		# with more players you wait longer, while the others carry on
		hero.tagged_time = Data.config.player.taggedTimeTwoPlayers if count >= 2 else Data.config.player.taggedTime
		# each can give the others Tag Bux in the shop
		shops[hero.index].partners.assign(heroes.filter(func(other): return other != hero))
	# with three or four, the game goes at 30 frames a second (drawing four views at 60 is too much
	# for the TV box), steadily rather than jumping between 30 and 60
	Engine.max_fps = 30 if count >= 3 else 0
	make_views()


## Each hero's view of the world is drawn by its own SubViewport (with her camera in it), at the
## size the graphics settings say ("Sharpness"), and shown on view_layer under the HUDs, stretched
## to fill her part of the screen: all of it, or half with two players. (Drawing into a smaller
## picture like this is steadier on the Shield than Godot's own 3D scaling, which crashed it.)
func make_views() -> void:
	for hero in heroes:
		if hero.camera.get_parent() != hero:
			hero.camera.reparent(hero)
	for sub in sub_views:
		sub.queue_free()
	for rect in view_rects:
		rect.queue_free()
	sub_views.clear()
	view_rects.clear()
	for line in [divider, divider_across, spare_corner]:
		if line.get_parent():
			view_layer.remove_child(line)
	for hero in heroes:
		var sub := SubViewport.new()
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if view_layer.visible else SubViewport.UPDATE_DISABLED
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
	if two_players():
		divider.color = Color.WHITE
		view_layer.add_child(divider)
	if heroes.size() >= 3:
		divider_across.color = Color.WHITE
		view_layer.add_child(divider_across)
	if heroes.size() == 3:
		make_spare_corner()
		view_layer.add_child(spare_corner)
	apply_graphics()
	huds[0].views.assign(sub_views.map(func(v): return v.get_viewport_rid()) + [get_viewport().get_viewport_rid()])
	huds[0].time_views()


## Sizes each view to fit the window (drawn at the window's real size times "Sharpness", so it's sharp
## on a big TV unless that's turned down), with each hero's HUD on top of her part.
func arrange_views() -> void:
	var g: Dictionary = Save.graphics[str(heroes.size())]
	var sharpness := Graphics.resolution_scale(g)
	var screen := get_viewport().get_visible_rect().size # (in the HUD's units, 1280 x 720 or so)
	var pixels := Vector2(get_window().size)
	var n := heroes.size()
	# side by side with one or two players, and in quarters with three or four (Player 1 top left,
	# 2 top right, 3 bottom left, 4 bottom right)
	var across := 1 if n == 1 else 2
	var down := 2 if n >= 3 else 1
	var part := Vector2(screen.x / across, screen.y / down)
	for i in n:
		var corner := Vector2(i % across, i / across)
		sub_views[i].size = Vector2i(maxi(1, roundi(pixels.x / across * sharpness)), maxi(1, roundi(pixels.y / down * sharpness)))
		view_rects[i].position = corner * part
		view_rects[i].size = part
		if n >= 2:
			huds[i].set_view(Rect2(view_rects[i].position, part), HUD_ZOOM_TWO_PLAYERS if n == 2 else HUD_ZOOM_FOUR_PLAYERS, true)
	if n == 1:
		huds[0].set_full_screen()
	divider.size = Vector2(3, screen.y)
	divider.position = Vector2(screen.x / 2 - 1.5, 0)
	divider_across.size = Vector2(screen.x, 3)
	divider_across.position = Vector2(0, screen.y / 2 - 1.5)
	spare_corner.position = part
	spare_corner.size = part
	huds[0].drawn_at = sub_views[0].size # (for the F3 numbers)


## The fourth quarter of the screen with three players: the game's name, and the zombies left.
func make_spare_corner() -> void:
	if spare_corner.get_child_count() > 0:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(40 / 255.0, 15 / 255.0, 80 / 255.0)
	spare_corner.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	spare_corner.add_child(column)
	var title := Screens.heading("ZOMBIE TAG", 60)
	column.add_child(title)
	spare_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spare_left.add_theme_font_size_override("font_size", 30)
	column.add_child(spare_left)


## Where each hero begins: side by side, 3 m apart.
func start_for(hero: Hero) -> Dictionary:
	var s: Dictionary = level.info.playerStart
	var side := (hero.index - (heroes.size() - 1) / 2.0) * 3.0
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
	boss = null
	boss_came = false
	coins.clear()
	shots.clear()
	game_over_in = 0
	level = Level.new(number)
	add_child(level)
	apply_graphics()
	for i in heroes.size():
		heroes[i].level = level
		gyms[i].level_number = number
		heroes[i].respawn(start_for(heroes[i])) # full hearts, and armour shields filled up
		huds[i].show_tagged(false)
		if heroes[i].weapon == null:
			heroes[i].give_stick()
	warm_up()
	# more zombies with more players: half as many again for each extra player (twoPlayerZombies)
	var more: float = (1.0 + (Data.config.twoPlayerZombies - 1.0) * (heroes.size() - 1)) * Save.current_difficulty().get("zombies", 1)
	to_spawn = roundi(level.info.zombies * more)
	popped = 0
	finished = false
	Sound.music(level.info.theme)
	save_game() # progress saves at the start of each level
	var d := Save.current_difficulty()
	toast_all("Level %d: %s %s   %s %s\nPop all the zombies, then find the exit gate!" % [number, level.info.name, level.info.icon, d.icon, d.name], 4)


## Uses the graphics settings for 1 or 2 players (see graphics.gd): with two, each half of the
## screen has them; with one, the whole screen.
func apply_graphics() -> void:
	var g: Dictionary = Save.graphics[str(heroes.size())]
	if sub_views.size() == heroes.size():
		# Once a view's had smooth edges, it stays slow after they're changed or turned off (on the
		# Shield, anyway), so it's made again instead. (A new one starts without them, so this only
		# happens once.)
		var msaa := Graphics.msaa(g)
		if sub_views.any(func(sub): return sub.msaa_3d != msaa and sub.msaa_3d != Viewport.MSAA_DISABLED):
			make_views()
			return
		arrange_views()
		for sub in sub_views:
			sub.msaa_3d = msaa
	var far := level.set_graphics(g) if level else 300.0
	for hero in heroes:
		hero.camera.far = far
	menu_camera.far = far
	# the test: leaves a part of the game out, to see how much quicker it goes without it
	var leave_out: String = Graphics.OPTIONS.test.choices[g.test]
	for hud in huds:
		hud.hide_for_test(leave_out == "HUD")
	zombie_holder.visible = leave_out != "Zombies"
	for hero in heroes:
		hero.camera.cull_mask = 0 if leave_out == "World" else hero.camera_layers() # (draws nothing)
	if in_game:
		draw_views()


## Each hero's view is drawn every frame, except while she's in the shop or gym (which covers it),
## or while the graphics test leaves all 3D out.
func draw_views() -> void:
	var g: Dictionary = Save.graphics[str(heroes.size())]
	var all_3d_out: bool = Graphics.OPTIONS.test.choices[g.test] == "All 3D"
	for i in sub_views.size():
		var off: bool = all_3d_out or (i < heroes.size() and heroes[i].inside != null)
		sub_views[i].render_target_update_mode = SubViewport.UPDATE_DISABLED if off else SubViewport.UPDATE_ALWAYS


## Starts playing a level (from "Pick a level").
func play(number: int) -> void:
	in_game = true
	paused = false
	for hud in huds:
		hud.visible = true
		hud.hide_level_done()
	view_layer.visible = true
	for sub in sub_views:
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# while playing, the heroes' views draw the world, so the main screen doesn't (it only shows
	# them, and the HUDs); otherwise it would draw the world again from the menus' camera, unseen
	get_viewport().disable_3d = true
	start_level(number)


## The menus: the level slowly turning behind them, with no zombies, heroes or HUDs.
func show_background() -> void:
	in_game = false
	paused = false
	finished = false
	if party:
		party.finish()
		party.queue_free()
		party = null
	for hero in heroes:
		if hero.inside:
			leave_building(hero)
		hero.hand.visible = false
		hero.body.visible = false
		hero.beam.hide_beam()
	for z in zombies:
		z.queue_free()
	zombies.clear()
	coins.clear()
	shots.clear()
	for hud in huds:
		hud.visible = false
	for sub in sub_views:
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view_layer.visible = false
	get_viewport().disable_3d = false # (the menus' camera draws the level behind them)
	if level == null:
		var furthest := 1
		var d := Save.profile(Save.chosen[0] if Save.chosen else null)
		if d:
			furthest = int(d.get("unlocked", 1))
		level = Level.new(furthest)
		add_child(level)
	apply_graphics()
	menu_camera.make_current()
	Sound.music("title")


## From the pause menu: saves, then back to the title screen.
func quit_to_title() -> void:
	save_game()
	screens.to_title()


func unpause() -> void:
	paused = false
	for hud in huds:
		hud.visible = true


## Each hero playing is saved into her own profile.
func save_game() -> void:
	for hero in heroes:
		Save.keep(hero)
	Save.chosen = heroes.map(func(h): return h.profile_id)
	Save.player_count = heroes.size()
	Save.write()


## The levels the heroes playing can pick: with two players, the furthest either has reached.
func unlocked_now() -> int:
	var most := 1
	for hero in heroes:
		most = maxi(most, hero.unlocked)
	return most


func finished_now(number: int) -> bool:
	return heroes.any(func(h): return number in h.finished)


func toast_all(text: String, seconds := 2.5) -> void:
	for hud in huds:
		hud.toast(text, seconds)


## Draws everything that only shows up later once, too small to see, so the game doesn't stop for a
## moment the first time it appears (see Effects.warm_up).
func warm_up() -> void:
	# load this level's kinds of zombie now, rather than when the first of each arrives
	var kinds: Array = level.info.mix.keys()
	if level.info.has("boss"):
		kinds.append(level.info.boss)
	for kind in kinds.duplicate():
		if Data.config.zombies[kind].has("splitsInto"):
			kinds.append(Data.config.zombies[kind].splitsInto)
	zombie_scenes = kinds.map(func(kind): return load("res://models/zombies/%s.glb" % kind))
	# and make one of each (far away, and gone straight after), so their parts are joined up now too
	for kind in kinds:
		var spare := Zombie.new(kind, level, 1, 0, -1000)
		add_child(spare)
		spare.free()
	var camera := heroes[0].camera
	var zombie: Node3D = load("res://models/zombies/shuffler.glb").instantiate()
	var hidden: Array[Node3D] = [level.gate.find_child("open", true, false), Zombie.make_health_bar(1)]
	for part in ["stars", "bubble", "ice"]:
		hidden.append(zombie.find_child(part, true, false))
	var flying := []
	for shot in shots.looks:
		flying.append(shots.looks[shot].instantiate())
	hidden.append_array(flying)
	hidden.append(heroes[0].beam.tube)
	effects.warm_up(camera, hidden)
	coins.warm_up(camera.global_position - camera.global_basis.z * 2.0)
	# the shop and gym are drawn once too, too faint to see, so they open straight away later
	for i in heroes.size():
		for menu: MenuScreen in [shops[i], gyms[i]]:
			if heroes[i].inside:
				continue
			menu.hero = heroes[i]
			if menu is ShopMenu:
				(menu as ShopMenu).draw()
			else:
				(menu as GymMenu).draw_list()
			menu.modulate.a = 0.01
			menu.visible = true
			get_tree().create_timer(0.5).timeout.connect(func():
				if not is_instance_valid(menu):
					return # (gone back to the start screen meanwhile)
				menu.modulate.a = 1.0
				if i >= heroes.size() or heroes[i].inside != menu:
					menu.visible = false)
	heroes[0].beam.warm_up(camera.global_position - camera.global_basis.z * 2.0)
	zombie.free()
	hidden[1].free()
	for node in flying:
		node.free()


# The TV remote's Back button (Android's "go back") pauses too, or goes back in the menus, instead
# of closing the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screens.active():
			screens.remote_back = true
		elif heroes.any(func(h): return h.inside) or Time.get_ticks_msec() - left_building_at < 500:
			# On some joypads Android sends "go back" for B (the right-hand button) as well, and on
			# others only "go back"; a moment later (once any B has arrived), it's the right-hand
			# button of whoever's inside with a joypad that's never sent a B.
			get_tree().create_timer(0.1).timeout.connect(back_in_building)
		else:
			pause()


func back_in_building() -> void:
	var who := heroes.filter(func(h): return h.inside and not Controls.sends_b(h.index))
	if who.size() == 1:
		# (whatever the right-hand button does: yes, or leave if the buttons are swapped)
		var leave := InputEventAction.new()
		leave.action = who[0].act("leave" if Controls.swap_buttons else "go")
		leave.pressed = true
		building_input(who[0], leave)


func pause() -> void:
	if finished or party or not in_game:
		return
	paused = true
	for hud in huds:
		hud.visible = false # (so the game behind the menu is easier to see)
	screens.choice = 0
	screens.show_screen("paused")


func _unhandled_input(event: InputEvent) -> void:
	if screens.active() or not in_game:
		return # (the menus are up)
	if party:
		if Controls.is_anyones(event, "attack") or event.is_action_pressed("pause"):
			screens.to_levels()
	elif finished:
		if Controls.is_anyones(event, "attack"):
			next_level()
		elif event.is_action_pressed("pause"):
			screens.to_levels()
	elif event.is_action_pressed("pause"):
		pause()
	elif not paused:
		# a hero in the shop or gym uses it (each with her own buttons)
		for hero in heroes:
			if hero.inside:
				building_input(hero, event)


## A button for the shop or gym a hero's in.
func building_input(hero: Hero, event: InputEvent) -> void:
	if hero.inside.handle_input(event):
		Sound.play("select")
		leave_building(hero)
		huds[hero.index].toast("See you soon! 👋", 1.5)


## From the Level done! screen. The next level is made behind the screen, which goes a moment later,
## so any stop while it's made isn't seen.
func next_level() -> void:
	start_level(level.info.number + 1)
	for hud in huds:
		get_tree().create_timer(0.2).timeout.connect(hud.hide_level_done)


func _process(delta: float) -> void:
	if not in_game:
		# the camera goes slowly round the level, behind the menus
		var t := Time.get_ticks_msec() / 1000.0 * 0.05
		menu_camera.position = Vector3(sin(t) * 30, 8, cos(t) * 30)
		menu_camera.look_at(Vector3(0, 2, 0))
		return
	if game_over_in > 0:
		game_over_in -= delta
		if game_over_in <= 0:
			Sound.play("tagged")
			show_background()
			screens.show_screen("gameover")
			return
	if paused or finished or party:
		return
	var started := Time.get_ticks_usec() # (for the F3 numbers)
	update(delta)
	huds[0].game_time = lerpf(huds[0].game_time, (Time.get_ticks_usec() - started) / 1000.0, 0.1)


## Everything that happens in a frame of the game.
func update(delta: float) -> void:
	time += delta

	# (popped zombies leave the list straight away, so it only holds ones still standing)
	if to_spawn > 0 and zombies.size() <= Data.config.arena.nextWaveWhenLeft:
		spawn_wave()
	if boss_coming() and to_spawn == 0 and zombies.is_empty():
		spawn_boss()
	for hero in heroes:
		update_hero(hero, delta)
	keep_players_apart()
	for hit in shots.update(delta, zombies):
		if hit.has("landed"):
			effects.splash(hit.at, hit.weapon.shot, 5, 0.6) # water landing on the ground
		elif hit.has("splat"):
			# a pumpkin landed: a big orange splat
			effects.splash(hit.at, "pumpkin", 60, 2.5)
			Sound.play("splat", 2)
			effects.float_text(hit.at + Vector3(0, 1.2, 0), hit.weapon.word, Color("ff8a1f"), 1.8)
		else:
			hit_zombie(hit.zombie, hit.weapon, hit.push, hit.at, hit.by)

	# every zombie popped: the exit gate opens, and all the coins fly to you
	var cleared := to_spawn == 0 and zombies.is_empty() and not boss_coming()
	for got in coins.update(delta, heroes, level, cleared):
		got[0].tag_bux += got[1]
		huds[got[0].index].bump_bux()
		# ka-ching, a little higher for each coin in a row
		coin_streak = coin_streak + 1 if time - last_coin < 0.6 else 0
		if time - last_coin > 0.05:
			Sound.play("coin", 1 + mini(coin_streak, 8) * 0.06)
		last_coin = time

	for z in zombies.duplicate(): # (the King's helpers join the list as it goes)
		z.update(delta, heroes, zombies)
		if z.calling_help:
			call_helpers(z)
		groan_now_and_then(z, delta)
		for hero in heroes:
			var d := Vector2(z.position.x - hero.position.x, z.position.z - hero.position.z).length()
			if z.can_tag() and d < z.radius + hero.radius + Data.config.player.touchDistance:
				zombie_touch(z, hero)

	if cleared and not level.gate_open:
		level.open_gate()
		Sound.play("gate")
		toast_all("All the zombies are popped!\nWalk through the glowing exit gate", 4)
	# each hero walking through the open gate waits there; once everyone has (except anyone out on
	# Hardcore), the level's done
	for hero in heroes:
		if not hero.through_gate and level.at_gate(hero.position) and hero.tagged <= 0 and not hero.inside and not hero.out:
			go_through_gate(hero)
	if heroes.any(func(h): return h.through_gate) and heroes.all(func(h): return h.through_gate or h.out):
		level_done()
		return # (the rest is for while playing: it would hide everyone at the party, for one)
	var left := to_spawn + zombies.size() + (1 if boss_coming() else 0)
	if heroes.size() == 3:
		var text := "Go to the exit gate!" if level.gate_open else "🧟 %d left" % left
		if spare_left.text != text:
			spare_left.text = text
	for i in heroes.size():
		huds[i].show_zombies_left(left, level.gate_open)
		huds[i].show_boss(boss if is_instance_valid(boss) and boss.alive else null)
		huds[i].update(heroes[i])
		var behind := zombie_behind(heroes[i])
		huds[i].show_behind(behind[0], behind[1])
		heroes[i].update_body(delta, two_players())


## The nearest zombie close behind a hero (out of sight), as [danger, side] for Hud.show_behind:
## danger 0 (none, or far enough) to 1 (right there), side -1 left, 1 right or 0 straight behind.
func zombie_behind(hero: Hero) -> Array:
	if hero.tagged > 0 or hero.inside or hero.through_gate:
		return [0.0, 0]
	var fwd := hero.forward()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var nearest := BEHIND_WARNING
	var side := 0
	for z in zombies:
		if not z.alive or z.spawn_pop < 1 or z.stuck():
			continue
		var to := Vector3(z.position.x - hero.position.x, 0, z.position.z - hero.position.z)
		var d := to.length() - z.radius
		if d >= nearest or to.length() < 0.001:
			continue
		var dir := to.normalized()
		if dir.dot(fwd) > 0.2:
			continue # in front, where you can see it
		nearest = d
		var across := dir.dot(right)
		side = 0 if absf(across) < 0.5 else (1 if across > 0 else -1)
	return [clampf(1.0 - nearest / BEHIND_WARNING, 0.0, 1.0), side]


## Through the gate: the player waits there (out of sight, and zombies leave them be) for the others.
func go_through_gate(hero: Hero) -> void:
	hero.through_gate = true
	hero.body.visible = false
	hero.hand.visible = false
	hero.beam.hide_beam()
	var waiting_for := heroes.filter(func(h): return not h.through_gate and not h.out)
	if waiting_for:
		Sound.play("select")
		huds[hero.index].toast("You're through! 🚪\nWaiting for %s…" % waiting_for[0].look.name, 9999)
		for h in waiting_for:
			huds[h.index].toast("%s is through the gate!\nCome and join %s 🚪" % [hero.look.name, hero.look.name], 3)


## Once every player is through the gate, the level's done. After the Zombie King's
## castle, there's a party.
func level_done() -> void:
	# coins still on their way count too, shared out
	var share := coins.total() / heroes.size()
	for hero in heroes:
		hero.tag_bux += share
	heroes[0].tag_bux += coins.total() - share * heroes.size()
	coins.clear()
	var number: int = level.info.number
	for hero in heroes:
		if hero.out:
			continue # tagged on Hardcore: her game has already started again
		if number not in hero.finished:
			hero.finished.append(number)
		hero.unlocked = maxi(hero.unlocked, mini(Data.config.levels.size(), number + 1))
	# beating the King finishes a Hardcore game: the next one starts fresh (outfits are kept)
	var hardcore_won: bool = level.info.has("boss") and Save.current_difficulty().get("fresh", false)
	if hardcore_won:
		for hero in heroes:
			hero.fresh_run()
	save_game()
	if level.info.has("boss"):
		start_party(hardcore_won)
		return
	finished = true
	Sound.play("fanfare")
	var next: Dictionary = Data.config.levels[level.info.number]
	for i in heroes.size():
		huds[i].show_level_done("%s %s" % [level.info.name, level.info.icon], heroes[i].tag_bux,
			"for level %d: %s %s" % [level.info.number + 1, next.name, next.icon])


## You beat the Zombie King: all the zombies become your friends and there's a big party. It's
## seen from one camera going round, over the whole screen.
func start_party(hardcore_won: bool) -> void:
	Sound.play("fanfare")
	Sound.music("party")
	for z in zombies:
		z.queue_free()
	zombies.clear()
	coins.clear()
	shots.clear()
	for hero in heroes:
		hero.beam.hide_beam()
	for hud in huds:
		hud.visible = false
	for sub in sub_views:
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view_layer.visible = false
	get_viewport().disable_3d = false # (the party's camera draws it)
	party = Party.new(level, heroes, effects, hardcore_won)
	add_child(party)


func update_hero(hero: Hero, delta: float) -> void:
	var hud := huds[hero.index]
	if hero.through_gate:
		return # waiting at the gate
	if hero.tagged > 0:
		hero.update(delta, zombies) # (just the camera)
		if hero.out:
			return # Hardcore: out until the level ends
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


## Players can't walk through each other.
func keep_players_apart() -> void:
	var here := heroes.filter(func(h): return not (h.inside or h.tagged > 0 or h.through_gate))
	for i in here.size():
		for j in range(i + 1, here.size()):
			var a: Hero = here[i]
			var b: Hero = here[j]
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
	draw_views()


## Given Tag Bux fly across the screen from the giver's total in the shop to the other player's
## (on their HUD, or in the shop if they're in there too), and it jumps as each coin lands.
func fly_coins(giver: Hero, receiver: Hero) -> void:
	var from: Vector2 = shops[giver.index].bux_pill.get_global_rect().get_center()
	var receiver_shop = receiver.inside if receiver.inside is ShopMenu else null
	var target: Control = receiver_shop.bux_pill if receiver_shop else huds[receiver.index].bux_pill
	var to: Vector2 = target.get_global_rect().get_center()
	for i in 5:
		var coin := HudIcon.new(HudIcon.Kind.COIN, 40)
		coin.position = from - Vector2(20, 20)
		coin.visible = false
		fly_layer.add_child(coin)
		var t := coin.create_tween()
		t.tween_interval(0.03 + i * 0.09)
		t.tween_callback(coin.show)
		t.tween_property(coin, "position", to - Vector2(20, 20), 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_callback(func():
			coin.queue_free()
			Sound.play("coin", 1 + i * 0.06)
			huds[receiver.index].bump_bux()
			if i == 4 and receiver.inside is ShopMenu:
				receiver.inside.draw()) # (their total goes up as the last one lands)


func leave_building(hero: Hero) -> void:
	left_building_at = Time.get_ticks_msec()
	var menu: MenuScreen = hero.inside
	menu.visible = false
	hero.inside = null
	draw_views()
	hero.hand.visible = true
	hero.start_at(level.doors["shop" if menu is ShopMenu else "gym"].outside)
	hero.safe = Data.config.player.leaveShopSafeTime # a moment to get past zombies waiting at the door
	if in_game:
		save_game() # keep what you bought or trained


func stick_broke(hero: Hero) -> void:
	if hero.weapon:
		huds[hero.index].toast("Your stick broke! 🪵💥\nNow holding the %s" % hero.weapon.name)
	else:
		huds[hero.index].toast("Your stick broke! 🪵💥\nGet a free one at the 🛍️ shop")


## A zombie touched a hero: it costs a heart (or armour takes it), and the zombie bounces off and
## goes dizzy for a moment, so she can get away.
func zombie_touch(zombie: Zombie, hero: Hero) -> void:
	var instant: bool = zombie.type.get("instantTag", false) # the Zombie King on Hard and Hardcore
	var hurt := hero.hurt(Data.config.player.hearts if instant else int(zombie.type.touchHearts), instant)
	if hurt == "":
		return
	var hud := huds[hero.index]
	var away := Vector3(zombie.position.x - hero.position.x, 0, zombie.position.z - hero.position.z).normalized()
	zombie.knock(away, zombie.type.bounceBack)
	zombie.dizzy = zombie.type.dizzyTime
	hud.flash(hurt)
	if hero.tagged > 0:
		Sound.play("tagged")
		got_tagged(hero)
	elif hurt == "shield":
		Sound.play("clang")
		hud.toast("Your armour blocked it!\nRun away!", 1.5)
	else:
		Sound.play("ouch")
		if zombie.type.touchHearts > 1:
			hud.toast("%s took %d hearts!\nRun away!" % [zombie.type.name, zombie.type.touchHearts], 1.5)
		else:
			hud.toast("Ouch! Last heart!\nRun away!" if hero.hearts == 1 else "Ouch! Run away!", 1.5)


## Out of hearts. Easy keeps everything; Hard takes your weapons and armour; Hardcore is game over
## (your Hardcore game starts again, and you're out until the level ends). Saved straight away.
func got_tagged(hero: Hero) -> void:
	var d := Save.current_difficulty()
	if d.get("oneLife", false):
		hero.out = true
		hero.tagged = INF # out until the level ends; zombies leave her alone
		hero.fresh_run() # (outfits are kept)
		if heroes.all(func(h): return h.out):
			game_over_in = 3
	elif d.get("loseItems", false):
		hero.lose_items()
	huds[hero.index].show_tagged(true, d)
	save_game()


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
	for i in mini(roundi(Data.config.arena.waveSize * Save.current_difficulty().get("zombies", 1)), to_spawn):
		var kind := pick_kind()
		var spot = spawn_spot(Data.config.zombies[kind].radius + 0.5)
		if spot == null:
			break
		add_zombie(kind, spot.x, spot.y)
		to_spawn -= 1


func add_zombie(kind: String, x: float, z: float) -> Zombie:
	var zombie := Zombie.new(kind, level, level.info.healthMultiplier, x, z)
	zombie_holder.add_child(zombie)
	zombies.append(zombie)
	return zombie


## Whether this level's Zombie King is still to come.
func boss_coming() -> bool:
	return level.info.has("boss") and not boss_came


## The final battle: once every other zombie is popped, the Zombie King arrives at the exit gate
## end of his castle, with his guards in a ring round him.
func spawn_boss() -> void:
	boss = add_zombie(level.info.boss, level.info.gate.x, level.info.gate.z + 8)
	boss_came = true
	# on Hard and Hardcore he's tougher, faster and tags you in one go
	var d := Save.current_difficulty()
	if d.has("king"):
		boss.type = boss.type.duplicate()
		boss.type.merge(d.king, true)
		boss.max_health = d.king.health * level.info.healthMultiplier
		boss.health = boss.max_health
	var guards: int = roundi(boss.type.guards * d.get("zombies", 1))
	for i in guards:
		var a := TAU * i / guards
		var x := boss.position.x + cos(a) * 4
		var z := boss.position.z + sin(a) * 4
		if level.is_clear(x, z, 0.8):
			add_zombie(pick_kind(), x, z)
	Sound.play("king")
	if boss.type.get("instantTag", false):
		toast_all("👑 THE ZOMBIE KING IS HERE! 👑\nDon't let him touch you, he tags you in one go!", 4)
	else:
		toast_all("👑 The Zombie King is here! The final battle!\nHe keeps calling Shufflers to help him!", 4)


## The King calls in a few Shufflers (only so many at once).
func call_helpers(king: Zombie) -> void:
	king.calling_help = false
	var t: Dictionary = king.type
	var helping := zombies.filter(func(z): return z.helper).size()
	var n := mini(t.helpers, t.maxHelpers - helping)
	for i in n:
		var a := randf() * TAU
		var x := king.position.x + cos(a) * 3
		var z := king.position.z + sin(a) * 3
		if level.is_clear(x, z, 0.6):
			add_zombie("shuffler", x, z).helper = true
	if n > 0:
		Sound.play("help")
		effects.float_text(king.centre() + Vector3(0, 2.5, 0), "HELP!", Color("ff8ad8"), 2)


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
	var t: Dictionary = zombie.type
	var size: float = t.size
	effects.confetti(zombie.centre(), 300 if t.get("boss", false) else 70)
	effects.float_text(zombie.centre() + Vector3(0, size, 0), "POP!", Color("9cff57"), 1.4 * size)
	coins.burst(zombie.centre(), t.tagBux)
	Sound.play("pop", randf_range(0.95, 1.15) / size)
	zombies.erase(zombie)
	zombie.queue_free()
	popped += 1
	if t.has("splitsInto"):
		# a Slime Zombie splits into two little Shufflers
		for side in [-1, 1]:
			var x: float = zombie.position.x + side * cos(zombie.yaw) * 0.9
			var z: float = zombie.position.z - side * sin(zombie.yaw) * 0.9
			add_zombie(t.splitsInto, x, z)
		effects.float_text(zombie.centre() + Vector3(0, 2, 0), "SPLIT!", Color("7dff4f"), 1.4)
		Sound.play("split")
	if t.get("boss", false):
		Sound.play("fanfare")
		toast_all("👑 You popped the Zombie King! 👑", 4)
