class_name Screens
extends CanvasLayer
## The start screens and menus (the screens in index.html, run by src/main.js), over the level
## slowly turning behind them:
##   title       ZOMBIE TAG: 1 or 2 players
##   who         Who's playing? Each player picks her saved hero, or makes a new one. With two
##               players, what she picks with is what she plays with: her joypad, or the keyboard.
##   remove      Delete a hero?
##   creator     The character creator (creator.gd), for new heroes
##   difficulty  How hard? Easy, Hard or Hardcore
##   levels      Pick a level
##   paused      Music and sound volumes, joypads, graphics, and back to the start screen
##   graphics    The graphics settings, which change straight away so you can see what they do
##   gameover    Hardcore: everyone's out
## main.gd runs the game itself; this tells it what to play.

const YELLOW := Color("ffe066")
const PURPLE := Color("4b1e8a")
const PINK := Color("ff4f8b")
const BLUE := Color("1e6fd6")
const CARD := Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.6)

var main # main.gd
var screen := "" # which screen is up ("" while playing)
var root := Control.new() # the screen's things (made again whenever it changes)
var wait := 0.0 # ignores the button that brought this screen up
var choice := 0 # the chosen row, card or level on this screen
var player_count := 1
var edit_looks := false # the title screen's Back / Select: heroes who already exist change how they look
var slot := 0 # who's choosing on "Who's playing?": 0 for Player 1, 1 for Player 2
var devices: Array = [] # what each player picked her hero with (see Controls.set_devices)
var removing := {} # the profile "Delete?" is asking about
var creator: Creator
var remote_back := false # the TV remote's Back button (main.gd sets it)
var speed_line := Label.new() # the frame rate, on the graphics screen
var speed_time := 0.0


func _init(the_main) -> void:
	main = the_main
	layer = 5 # over the HUDs
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	speed_line.add_theme_font_size_override("font_size", 24)
	speed_line.add_theme_color_override("font_color", Color("9cff57"))
	speed_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func active() -> bool:
	return screen != ""


## Shows a screen (or none, for playing).
func show_screen(which: String) -> void:
	screen = which
	wait = 0.2
	visible = which != ""
	if creator and which != "creator":
		creator.queue_free()
		creator = null
	draw()


# ---------- moving between screens ----------

func to_title() -> void:
	choice = Save.player_count - 1
	main.show_background()
	show_screen("title")


## 1 or 2 players chosen: each picks her hero in turn.
func begin(count: int, looks: bool) -> void:
	player_count = count
	edit_looks = looks
	main.set_player_count(count)
	devices = []
	start_who(0)


func start_who(who: int) -> void:
	slot = who
	devices.resize(who)
	var rows := who_rows()
	# start on the hero who played in this slot last time
	choice = 0
	for i in rows.size():
		if rows[i].has("profile") and not rows[i].taken and rows[i].profile.id == (Save.chosen[who] if who < Save.chosen.size() else null):
			choice = i
	if rows[choice].get("taken", false):
		choice = maxi(0, rows.find_custom(func(r): return not r.get("taken", false)))
	show_screen("who")


## Every saved hero, then "New hero" if there's room.
func who_rows() -> Array:
	var taken := []
	for i in slot:
		taken.append(main.heroes[i].profile_id)
	var rows := []
	for d in Save.profiles:
		rows.append({ profile = d, taken = d.id in taken })
	if Save.profiles.size() + slot < Data.config.maxProfiles:
		rows.append({ new_hero = true })
	return rows


## A hero picked. device: what she picked with (see Controls.set_devices).
func choose_who(device: Dictionary) -> void:
	var r: Dictionary = who_rows()[choice]
	if r.get("taken", false):
		Sound.play("nope")
		return
	Sound.play("select")
	devices.append(device)
	var hero: Hero = main.heroes[slot]
	hero.picked_with_pad = device.pad != Controls.NO_PAD
	if r.has("new_hero"):
		hero.blank("hero%s%d" % [String.num_int64(int(Time.get_unix_time_from_system() * 1000), 36), slot])
	else:
		hero.from_save(r.profile)
	if slot + 1 < player_count:
		start_who(slot + 1)
		return
	Controls.set_devices(devices if player_count == 2 else [{ keys = "all", pad = Controls.ANY_PAD }])
	# make any new heroes (or let everyone change how they look), then pick how hard
	var making: Array = main.heroes.filter(func(h): return edit_looks or not h.created)
	if making.is_empty():
		to_difficulty()
		return
	show_screen("creator")
	creator = Creator.new(making, to_difficulty)
	root.add_child(creator)


func to_difficulty() -> void:
	main.save_game()
	choice = Data.config.difficulties.keys().find(Save.difficulty)
	show_screen("difficulty")


func to_levels() -> void:
	main.show_background()
	choice = mini(main.unlocked_now(), Data.config.levels.size()) - 1
	show_screen("levels")


# ---------- each frame ----------

func _process(delta: float) -> void:
	if screen == "":
		return
	if screen == "graphics":
		# how fast it's going now (twice a second)
		speed_time -= delta
		if speed_time <= 0:
			speed_time = 0.5
			speed_line.text = "Now: %d fps (%.1f ms a frame; 60 fps needs 16.7)" % [
				Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000]
	wait -= delta
	if wait > 0 or screen == "creator":
		return
	var up := Controls.nav("up")
	var down := Controls.nav("down")
	var left := Controls.nav("left")
	var right := Controls.nav("right")
	var go := Input.is_action_just_pressed("menu_go")
	var back := Input.is_action_just_pressed("menu_back") or remote_back
	remote_back = false
	var extra := Input.is_action_just_pressed("menu_extra")
	var before := choice
	match screen:
		"title":
			if up or left:
				choice = 0
			if down or right:
				choice = 1
			if go or extra:
				Sound.play("select")
				begin(choice + 1, extra)
				return
		"who":
			var n := who_rows().size()
			if up or left:
				choice = (choice + n - 1) % n
			if down or right:
				choice = (choice + 1) % n
			if extra:
				var r: Dictionary = who_rows()[choice]
				if r.has("profile") and not r.taken:
					removing = r.profile
					show_screen("remove")
				else:
					Sound.play("nope")
				return
			if back:
				if slot > 0:
					start_who(0) # Player 1 chooses again
				else:
					to_title()
				return
			# (picking is in _input, which can tell which joypad or key it was)
		"remove":
			if go:
				Sound.play("select")
				Save.remove(removing.id)
				start_who(slot)
			elif back:
				start_who(slot)
			return
		"difficulty":
			var n: int = Data.config.difficulties.size()
			if up or left:
				choice = maxi(0, choice - 1)
			if down or right:
				choice = mini(n - 1, choice + 1)
			if go:
				Sound.play("select")
				Save.difficulty = Data.config.difficulties.keys()[choice]
				# Hardcore is a separate game that starts fresh; Easy and Hard share the normal one
				for hero in main.heroes:
					hero.use_run("hardcore" if Save.current_difficulty().get("fresh", false) else "normal")
				main.save_game()
				to_levels()
				return
			if back:
				to_title()
				return
		"levels":
			var n: int = Data.config.levels.size()
			if left:
				choice = maxi(0, choice - 1)
			if right:
				choice = mini(n - 1, choice + 1)
			if up:
				choice = maxi(0, choice - 5)
			if down:
				choice = mini(n - 1, choice + 5)
			if go:
				if choice < main.unlocked_now():
					Sound.play("select")
					show_screen("")
					main.play(choice + 1)
				else:
					Sound.play("nope")
				return
			if back:
				to_difficulty()
				return
		"paused":
			# music, sounds, joypads, graphics, start screen
			if up:
				choice = maxi(0, choice - 1)
			if down:
				choice = mini(4, choice + 1)
			var change := (1 if right else 0) - (1 if left else 0)
			if change and choice < 2:
				Sound.play("tick")
				Save.set_volumes(Save.music + (change if choice == 0 else 0), Save.sounds + (change if choice == 1 else 0))
				draw()
			if (change or go) and choice == 2:
				# (for the joypad that pressed it)
				if Controls.last_pad >= 0:
					Sound.play("tick")
					Controls.set_two_sticks(Controls.last_pad, not Controls.two_sticks(Controls.last_pad))
					Save.write()
				else:
					Sound.play("nope")
				draw()
			if go and choice == 3:
				Sound.play("select")
				choice = 0
				show_screen("graphics")
				return
			if go and choice == 4:
				Sound.play("select")
				main.quit_to_title()
				return
			if back:
				show_screen("")
				main.unpause()
				return
		"graphics":
			var keys: Array = Graphics.OPTIONS.keys()
			if up:
				choice = maxi(0, choice - 1)
			if down:
				choice = mini(keys.size(), choice + 1)
			var change := (1 if right else 0) - (1 if left else 0)
			if choice < keys.size() and (change or go):
				# go steps on through the choices too, round to the first again
				var g: Dictionary = Save.graphics[str(main.heroes.size())]
				var n: int = Graphics.OPTIONS[keys[choice]].choices.size()
				g[keys[choice]] = clampi(g[keys[choice]] + change, 0, n - 1) if change else (g[keys[choice]] + 1) % n
				Sound.play("tick")
				Save.try_out()
				main.apply_graphics()
				draw()
			if back or (go and choice == keys.size()):
				Sound.play("select")
				choice = 3
				show_screen("paused")
				return
		"gameover":
			if go or back:
				to_levels()
				return
	if choice != before:
		Sound.play("tick")
		draw()


## On "Who's playing?", the button you pick with decides what you play with (with two players).
func _input(event: InputEvent) -> void:
	if screen != "who" or wait > 0 or not event.is_pressed() or event.is_echo():
		return
	var mine: Dictionary = devices[0] if slot == 1 else {}
	if event is InputEventJoypadButton and event.button_index in Controls.PAD.attack:
		if mine.get("pad") == event.device:
			Sound.play("nope") # that's Player 1's joypad
		else:
			choose_who({ keys = "", pad = event.device })
	elif event is InputEventKey and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if mine.get("keys", "") == "":
			choose_who({ keys = "all", pad = Controls.NO_PAD })
		elif event.physical_keycode == KEY_SPACE:
			Sound.play("nope") # Player 1 has the keyboard; Player 2 can share it with Enter
		else:
			# sharing: Player 1 moves over to W A S D, Player 2 has the arrows
			devices[0] = { keys = "left", pad = Controls.NO_PAD }
			choose_who({ keys = "right", pad = Controls.NO_PAD })


# ---------- drawing ----------

func draw() -> void:
	if speed_line.get_parent():
		speed_line.get_parent().remove_child(speed_line) # (kept, not freed)
	for child in root.get_children():
		if child != creator:
			root.remove_child(child)
			child.queue_free()
	if screen == "" or screen == "creator":
		return
	# a see-through purple wash, so the level behind still shows
	var wash := ColorRect.new()
	wash.color = Color(40 / 255.0, 15 / 255.0, 80 / 255.0, 0.55)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	root.add_child(column)
	call("draw_" + screen, column)


func draw_title(column: VBoxContainer) -> void:
	column.add_child(heading("ZOMBIE TAG", 120))
	var names := []
	for id in Save.chosen.slice(0, Save.player_count):
		var d := Save.profile(id)
		if d:
			names.append(d.look.name)
	column.add_child(line("Welcome back, %s!" % " and ".join(names) if names else "10 levels of silly zombies", 34, Color.WHITE))
	column.add_child(gap(10))
	column.add_child(cards(["🧒 1 Player", "🧒🧒 2 Players"], choice, 300))
	column.add_child(gap(10))
	column.add_child(ButtonText.make("%s choose  ·  {go} to play" % arrows("across"), 30, YELLOW))
	if Save.graphics_were_reset:
		column.add_child(line("The game stopped last time, so the graphics settings are back to normal", 24, Color("ffb3b3")))
	column.add_child(line("%s: change how your hero looks" % ("Back / Select" if OS.has_feature("android") else "C (🎮 Back / Select)"), 24, Color.WHITE))


func draw_who(column: VBoxContainer) -> void:
	if player_count == 2:
		column.add_child(badge(slot))
	column.add_child(heading("Who's playing?", 80))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size.x = 560
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(list)
	var rows := who_rows()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var chosen := i == choice
		var text_colour := PURPLE if chosen else Color.WHITE
		if r.has("new_hero"):
			row.add_child(MenuScreen.label("➕", 32, Color.WHITE))
			row.add_child(MenuScreen.label("New hero", 32, text_colour))
		else:
			var d: Dictionary = r.profile
			var dot := Panel.new()
			var round_box := StyleBoxFlat.new()
			round_box.bg_color = Data.colour(d.look.outfit)
			round_box.set_corner_radius_all(16)
			dot.add_theme_stylebox_override("panel", round_box)
			dot.custom_minimum_size = Vector2(32, 32)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var name_label := MenuScreen.label(d.look.name, 32, text_colour)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			if r.taken:
				row.add_child(MenuScreen.label("Playing as Player 1", 22, text_colour))
			else:
				row.add_child(MenuScreen.label("⭐ %d" % d.get("finished", []).size(), 24, text_colour))
				row.add_child(MenuScreen.bux(int(d.get("tagBux", 0)), 24, PURPLE if chosen else YELLOW))
			if r.taken:
				row.modulate.a = 0.5
		list.add_child(card(row, chosen))
	# the button you pick with decides what you play with
	var how := "%s choose  ·  {go} to play" % arrows()
	if player_count == 2 and not OS.has_feature("android"):
		var keyboard_free: bool = slot == 0 or devices[0].keys == ""
		how = "%s choose  ·  Space to play on the ⌨️ keyboard, or {*go} on your joypad" % arrows() if keyboard_free \
			else "%s choose  ·  {*go} on your joypad, or Enter to share the ⌨️ keyboard (arrows and Enter)" % arrows()
	elif player_count == 2:
		how = "%s choose  ·  {go} on your own controller to play" % arrows()
	column.add_child(gap(6))
	column.add_child(ButtonText.make(how, 26, YELLOW))
	column.add_child(line("%s delete a hero  ·  %s back" % [extra_name(), back_name()], 22, Color.WHITE))


func draw_remove(column: VBoxContainer) -> void:
	column.add_child(heading("Delete %s?" % removing.look.name, 80))
	column.add_child(line("Their Tag Bux, weapons, outfits, training and levels will all be gone!", 30, Color.WHITE))
	column.add_child(gap(10))
	column.add_child(ButtonText.make("Press {go} for yes, or %s to keep them" % back_name(), 30, YELLOW))


func draw_difficulty(column: VBoxContainer) -> void:
	column.add_child(heading("How hard?", 90))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var d: Dictionary = Data.config.difficulties
	var ids: Array = d.keys()
	for i in ids.size():
		var words := VBoxContainer.new()
		words.custom_minimum_size.x = 300
		var chosen := i == choice
		var title := MenuScreen.label("%s %s" % [d[ids[i]].icon, d[ids[i]].name], 38, PURPLE if chosen else Color.WHITE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(title)
		var about := MenuScreen.label(d[ids[i]].about, 22, PURPLE if chosen else Color.WHITE)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size.x = 300
		words.add_child(about)
		row.add_child(card(words, chosen))
	column.add_child(row)
	column.add_child(line("The Zombie King is tougher and faster on Hard and Hardcore, and tags you in one go!", 24, Color.WHITE))
	column.add_child(ButtonText.make("%s choose  ·  {go} to go" % arrows("across"), 30, YELLOW))


func draw_levels(column: VBoxContainer) -> void:
	column.add_child(heading("Pick a level", 80))
	var d := Save.current_difficulty()
	column.add_child(line("%s %s" % [d.icon, d.name], 30, Color.WHITE))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	var levels: Array = Data.config.levels
	for i in levels.size():
		var locked: bool = i >= main.unlocked_now()
		var chosen := i == choice
		var tile := VBoxContainer.new()
		tile.custom_minimum_size = Vector2(196, 0)
		for bit in [
			[("🔒" if locked else levels[i].icon) + (" ⭐" if main.finished_now(i + 1) else ""), 46],
			["Level %d" % (i + 1), 22],
			[levels[i].name, 20],
		]:
			var l := MenuScreen.label(bit[0], bit[1], PURPLE if chosen else Color.WHITE)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tile.add_child(l)
		if locked:
			tile.modulate.a = 0.5
		grid.add_child(card(tile, chosen))
	column.add_child(ButtonText.make("%s choose  ·  {go} to play  ·  %s back" % [arrows("all"), back_name()], 28, YELLOW))


func draw_paused(column: VBoxContainer) -> void:
	column.add_child(heading("Paused", 100))
	var bar := func(n: int) -> String: return "▮".repeat(n) + "▯".repeat(10 - n)
	var rows := [
		["🎵 Music", bar.call(Save.music)],
		["🔊 Sounds", bar.call(Save.sounds)],
		["🎮 This joypad", "Two sticks" if Controls.two_sticks(Controls.last_pad) else "Simple" if Controls.last_pad >= 0 else "–"],
		["✨ Graphics", "➜"],
		["🏠 Start screen", "{go}"],
	]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size.x = 600
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(list)
	for i in rows.size():
		var row := HBoxContainer.new()
		var name_label := MenuScreen.label(rows[i][0], 32, PURPLE if i == choice else Color.WHITE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(ButtonText.make(rows[i][1], 30, PINK if i == choice else YELLOW))
		list.add_child(card(row, i == choice))
	column.add_child(line("%s choose  ·  %s change" % ["🡑 🡓", "🡐 🡒"], 26, Color.WHITE))
	if Controls.last_pad >= 0:
		column.add_child(line("🎮 This joypad: %s. Each joypad remembers its own." % Input.get_joy_name(Controls.last_pad), 20, Color.WHITE))
	column.add_child(line("Simple: the left stick walks and turns.  Two sticks: the left stick walks and steps sideways, the right one turns.", 20, Color.WHITE))
	column.add_child(line("Press %s to keep playing" % back_name(), 30, YELLOW))


## The graphics settings: a panel on the left, without the purple wash, so you can see the game
## change behind it.
func draw_graphics(column: VBoxContainer) -> void:
	root.get_child(0).color.a = 0.0
	column.anchor_right = 0
	column.offset_left = 30
	column.offset_right = 650
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var count: int = main.heroes.size()
	box.add_child(heading("Graphics", 52))
	box.add_child(line("For %s · they change straight away" % ("1 player" if count == 1 else "2 players"), 24, Color.WHITE))
	box.add_child(speed_line)
	var g: Dictionary = Save.graphics[str(count)]
	var keys: Array = Graphics.OPTIONS.keys()
	for i in keys.size() + 1:
		var row := HBoxContainer.new()
		var chosen := i == choice
		var name_text: String = Graphics.OPTIONS[keys[i]].label if i < keys.size() else "↩ Back"
		var name_label := MenuScreen.label(name_text, 26, PURPLE if chosen else Color.WHITE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if i < keys.size():
			var value: String = Graphics.OPTIONS[keys[i]].choices[g[keys[i]]]
			row.add_child(MenuScreen.label("◀ %s ▶" % value, 26, PINK if chosen else YELLOW))
		var c := card(row, chosen)
		c.get_theme_stylebox("panel").content_margin_top = 4
		c.get_theme_stylebox("panel").content_margin_bottom = 4
		box.add_child(c)
	box.add_child(line("Further down the choices is quicker, but not as nice", 22, Color.WHITE))
	box.add_child(line("%s choose  ·  🡐 🡒 change  ·  %s back" % ["🡑 🡓", back_name()], 24, YELLOW))
	var panel := card(box, false)
	panel.get_theme_stylebox("panel").bg_color = Color(40 / 255.0, 15 / 255.0, 80 / 255.0, 0.8)
	column.add_child(panel)


func draw_gameover(column: VBoxContainer) -> void:
	column.add_child(heading("GAME OVER!", 110))
	column.add_child(line("Hardcore is tough! Your Hardcore game starts again from level 1.", 30, Color.WHITE))
	column.add_child(line("Your Easy and Hard game and your outfits are safe.", 30, Color.WHITE))
	column.add_child(ButtonText.make("Press {go} to pick a level", 32, YELLOW))


# ---------- bits the screens are made of ----------

static func heading(text: String, font_size: int) -> Label:
	var l := line(text, font_size, YELLOW)
	MenuScreen.shadow(l, maxi(4, font_size / 18))
	return l


static func line(text: String, font_size: int, colour: Color) -> Label:
	var l := MenuScreen.label(text, font_size, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c


## A rounded box: white with a yellow border when it's the chosen one.
static func card(content: Control, chosen: bool) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE if chosen else CARD
	box.set_corner_radius_all(22)
	box.set_border_width_all(5)
	box.border_color = YELLOW if chosen else Color(0, 0, 0, 0)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(content)
	return panel


## A row of cards to choose from, side by side.
static func cards(texts: Array, chosen: int, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for i in texts.size():
		var l := MenuScreen.label(texts[i], 44, PURPLE if i == chosen else Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = width
		row.add_child(card(l, i == chosen))
	return row


## "Player 1" or "Player 2", in her colour.
static func badge(player: int) -> Control:
	var l := MenuScreen.label("Player %d" % (player + 1), 28, Color.WHITE)
	var p := MenuScreen.pill(l, PINK if player == 0 else BLUE)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


## The arrows that choose on a screen: "down" for a list, "across" for a row, "all" for a grid.
static func arrows(way := "down") -> String:
	return { down = "🡑 🡓", across = "🡐 🡒", all = "🡐 🡑 🡒 🡓" }[way]


static func back_name() -> String:
	return "Start" if OS.has_feature("android") else "Esc (🎮 Start)"


static func extra_name() -> String:
	return "Back / Select" if OS.has_feature("android") else "X (🎮 Back / Select)"
