class_name GymMenu
extends MenuScreen
## The gym (src/gym.js): a treadmill for Speed and weights for Strength. Training is free, but each
## place only lets you raise Speed once and Strength once.
##   Treadmill: press left, right, left, right... as fast as you can to fill the bar in time.
##   Weights: pick a dumbbell, then tap fire as fast as you can to lift it to the top. It sinks
##   if you stop!

const G_BLUE := Color("1e6fd6")

var g: Dictionary = Data.config.gym
var level_number := 1 # main.gd sets this: each level only lets you train so much
var mode := "menu" # menu, pick (a dumbbell), treadmill, lift or result
var cursor := 0
var last_row := 0 # the row to go back to after a mini-game

# the mini-games
var need := 0 # treadmill presses needed
var fill := 0.0 # how full the bar is (1 is full)
var time_left := 0.0
var started := false
var last_key := "" # the treadmill's last good press: "L" or "R"
var since_good := 0.0
var tempo := 0.0 # good presses a second, smoothed (how fast your hero runs)
var belt_offset := 0.0
var run_phase := 0.0
var weight_id := ""

# what the mini-games draw
var meter_fill: Panel
var timer_pill: PanelContainer
var timer_label: Label
var trainee: Label # 🏃, or the lifter's face
var sweat: Label
var belt: Control
var bell: Control
var key_left: PanelContainer
var key_right: PanelContainer


func _init() -> void:
	super(Color("4fc3f7"), Color("1e3a8a"), Color("4fc3f7"), G_BLUE, G_BLUE)


func open(the_hero: Hero) -> void:
	hero = the_hero
	menu("Welcome to the gym! 💪 Training is free. Train Speed and Strength once in each place.")
	cursor = 0 if hero.speed_level <= hero.strength_level else 1
	wait = 0.25
	visible = true
	draw_list()


func menu(text: String, kind := "") -> void:
	mode = "menu"
	cursor = 0
	say(text, kind)


# ---------- the menus ----------

## True once you've used up this level's training for Speed or Strength.
func done_here(stat: String) -> bool:
	return hero.trained_on(level_number, stat) >= g.upgradesPerLevel


func rows() -> Array:
	var p := hero
	if mode == "menu":
		# each stat shows MAX, done for this level, or what it goes up to
		var row := func(id: String, icon: String, row_name: String, about: String, stat: String, level: int) -> Dictionary:
			var r := { id = id, icon = icon, name = row_name, about = about, kind = "buy" }
			if level >= g.maxLevel:
				r.label = "MAX ⭐"
				r.kind = "locked"
			elif done_here(stat):
				r.label = "Done here ✔"
				r.kind = "locked"
			else:
				r.label = "%s %d ➜ %d" % [stat.capitalize(), level, level + 1]
			return r
		return [
			row.call("treadmill", "🏃", "Treadmill", "Makes you faster", "speed", p.speed_level),
			row.call("weights", "🏋️", "Weights", "Makes your weapons hit harder", "strength", p.strength_level),
			{ id = "leave", icon = "🚪", name = "Leave", label = "Back outside", kind = "leave" },
		]
	var list := []
	for id in g.weights.dumbbells:
		var w: Dictionary = g.weights.dumbbells[id]
		var ok: bool = p.strength_level < w.maxLevel
		list.append({ id = id, icon = w.icon, name = "%s dumbbell" % w.name, about = "Strength up to %d" % w.maxLevel,
			label = "Lift it!" if ok else "Too easy now!", kind = "buy" if ok else "locked" })
	list.append({ id = "back", icon = "↩️", name = "Back", label = "", kind = "leave" })
	return list


## Returns true when you chose "Leave".
func handle_input(event: InputEvent) -> bool:
	if wait > 0 or event is InputEventJoypadMotion:
		return false # (sticks come through as pushes instead: see MenuScreen._process)
	match mode:
		"menu", "pick":
			var list := rows()
			if event.is_action_pressed(hero.act("leave")):
				if mode == "menu":
					return true # straight out
				menu("") # (picking a dumbbell: back to the gym's list)
				cursor = 1
				Sound.play("select")
				draw_list()
				return false
			if event.is_action_pressed(hero.act("walk_forward")):
				cursor = (cursor + list.size() - 1) % list.size()
				Sound.play("tick")
			elif event.is_action_pressed(hero.act("walk_back")):
				cursor = (cursor + 1) % list.size()
				Sound.play("tick")
			elif event.is_action_pressed(hero.act("go")):
				if choose(list[cursor]):
					return true
			else:
				return false
			if mode == "menu" or mode == "pick": # (unless a mini-game just started)
				draw_list()
		"treadmill":
			# only a different key from last time counts
			var key := "L" if event.is_action_pressed(hero.act("turn_left")) else "R" if event.is_action_pressed(hero.act("turn_right")) else ""
			if key != "" and key != last_key:
				last_key = key
				started = true
				since_good = 0
				fill += 1.0 / need
				tempo += 2
				Sound.play("step", 1.0 if key == "L" else 1.25) # left, right, left, right...
		"lift":
			if event.is_action_pressed(hero.act("go")):
				started = true
				fill += g.weights.dumbbells[weight_id].rise
				Sound.play("lift", 1 + minf(1, fill)) # higher as it goes up
				key_left.scale = Vector2.ONE * 1.25
				create_tween().tween_property(key_left, "scale", Vector2.ONE, 0.2)
				moving(0.2)
		"result":
			if event.is_action_pressed(hero.act("go")):
				menu("Want to train some more?")
				cursor = last_row
				draw_list()
	return false


func choose(row: Dictionary) -> bool:
	var p := hero
	Sound.play("nope" if row.kind == "locked" else "select")
	if row.id == "leave":
		return true
	if row.id == "back":
		menu("")
		cursor = 1
		return false
	if row.kind == "locked":
		if mode != "menu":
			say("You're too strong for this one! Try a heavier dumbbell", "bad")
		elif (p.speed_level if row.id == "treadmill" else p.strength_level) >= g.maxLevel:
			say("That one is as high as it goes! ⭐", "bad")
		else:
			say("You've trained that here already! Train again on the next level 💪", "bad")
		return false
	if row.id == "treadmill":
		start_treadmill()
	elif row.id == "weights":
		mode = "pick"
		say("Heavier ones are harder to lift, but go higher")
		# start on the lightest dumbbell that still helps
		var ids: Array = g.weights.dumbbells.keys()
		cursor = maxi(0, ids.find_custom(func(id): return p.strength_level < g.weights.dumbbells[id].maxLevel))
	else:
		start_lift(row.id)
	return false


func draw_list() -> void:
	title.text = "💪 The Gym"
	clear(top_right)
	top_right.add_child(pill(label("🏃 %d   🏋️ %d" % [hero.speed_level, hero.strength_level], 40, YELLOW)))
	show_rows(rows(), cursor)
	set_help("🡑 🡓 choose  ·  {go} go  ·  {leave} %s" % ("leave" if mode == "menu" else "back"))


# ---------- the mini-games ----------

## The treadmill or the dumbbell on the left, and the bar that fills up on the right.
func make_training(seconds: float) -> Control:
	clear(top_right)
	timer_label = label("⏱ %d" % seconds, 40, YELLOW)
	timer_pill = pill(timer_label)
	top_right.add_child(timer_pill)
	clear(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.custom_minimum_size = Vector2(760, 340)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(row)
	var scene_box := StyleBoxFlat.new()
	scene_box.bg_color = Color("d4f0ff")
	scene_box.set_corner_radius_all(26)
	scene_box.set_border_width_all(5)
	scene_box.border_color = Color.WHITE
	var scene := Panel.new()
	scene.add_theme_stylebox_override("panel", scene_box)
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.clip_contents = true
	row.add_child(scene)
	# the bar
	var meter_box := StyleBoxFlat.new()
	meter_box.bg_color = Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.6)
	meter_box.set_corner_radius_all(35)
	meter_box.set_border_width_all(5)
	meter_box.border_color = Color.WHITE
	var meter := Panel.new()
	meter.add_theme_stylebox_override("panel", meter_box)
	meter.custom_minimum_size.x = 70
	meter.clip_contents = true
	row.add_child(meter)
	# the fill is rounded too, so it fits inside the bar's rounded ends
	var fill_box := StyleBoxFlat.new()
	fill_box.set_corner_radius_all(30)
	meter_fill = Panel.new()
	meter_fill.add_theme_stylebox_override("panel", fill_box)
	meter_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	meter_fill.anchor_top = 1.0
	meter.add_child(meter_fill)
	# the face or runner, and sweat when you're going for it
	trainee = label("", 130, Color.WHITE)
	sweat = label("💦", 44, Color.WHITE)
	sweat.modulate.a = 0
	return scene


## A key to press, as a little box (it grows when it's the one to press next).
func key_badge(text: String) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(10)
	box.content_margin_left = 14
	box.content_margin_right = 14
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", box)
	badge.add_child(ButtonText.make(text, 30, PURPLE)) # (it can show the buttons: see ButtonText)
	badge.resized.connect(func(): badge.pivot_offset = badge.size / 2)
	return badge


func keys_row(badges: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for b in badges:
		row.add_child(b)
	body.add_child(row)
	return row


func start_treadmill() -> void:
	var t: Dictionary = g.treadmill
	mode = "treadmill"
	last_row = 0
	need = int(t.presses + t.morePressesPerLevel * (hero.speed_level - 1))
	fill = 0
	time_left = t.time
	started = false
	last_key = ""
	since_good = 0
	tempo = 0
	belt_offset = 0
	run_phase = 0
	wait = 0.2
	title.text = "🏃 Treadmill"
	var scene := make_training(t.time)
	belt = Belt.new()
	scene.add_child(belt)
	trainee.text = "🏃"
	scene.add_child(trainee)
	scene.add_child(sweat)
	key_left = key_badge("◀")
	key_right = key_badge("▶")
	keys_row([key_left, label("then", 26, Color.WHITE), key_right, label("then", 26, Color.WHITE), key_badge("◀"), label("…", 26, Color.WHITE)])
	say("Press left, then right, then left… as fast as you can!")
	set_help("Fill the bar before the time runs out")


func start_lift(id: String) -> void:
	mode = "lift"
	last_row = 1
	weight_id = id
	fill = 0
	time_left = g.weights.time
	started = false
	wait = 0.2
	var w: Dictionary = g.weights.dumbbells[id]
	title.text = "🏋️ %s dumbbell" % w.name
	var scene := make_training(g.weights.time)
	bell = Dumbbell.new(id)
	scene.add_child(bell)
	trainee.text = "😐"
	trainee.add_theme_font_size_override("font_size", 110)
	scene.add_child(trainee)
	scene.add_child(sweat)
	key_left = key_badge("{go}") # (white, so the lit buttons show up)
	keys_row([label("Tap", 26, Color.WHITE), key_left, label("super fast to lift it!", 26, Color.WHITE)])
	say("")
	set_help("Get it to the top before the time runs out. It sinks if you stop!")


## (the mini-games move all the time, and so does the result: the arm flexing)
func busy() -> bool:
	return super() or mode in ["treadmill", "lift", "result"]


func _process(delta: float) -> void:
	super(delta)
	if not visible or not hero:
		return
	match mode:
		"treadmill": update_treadmill(delta)
		"lift": update_lift(delta)


func update_treadmill(delta: float) -> void:
	var t: Dictionary = g.treadmill
	if started:
		time_left -= delta
		since_good += delta
		if since_good > t.drainAfter:
			fill = maxf(0, fill - t.drainPerSecond * delta)
	tempo *= exp(-delta / 0.5)
	# the faster you press, the faster your hero runs
	belt_offset += tempo * delta * 60
	run_phase += tempo * delta * PI
	belt.offset = belt_offset
	belt.queue_redraw()
	var scene: Control = belt.get_parent()
	# feet on the belt, bobbing as you run
	trainee.position = Vector2((scene.size.x - trainee.size.x) / 2, scene.size.y * 0.88 - 12 - trainee.size.y - absf(sin(run_phase)) * 22)
	sweat.position = trainee.position + Vector2(trainee.size.x - 34, -10)
	sweat.modulate.a = 1.0 if tempo > 4 else 0.0
	# the key to press next grows
	key_left.scale = Vector2.ONE * (1.25 if last_key != "L" else 1.0)
	key_right.scale = Vector2.ONE * (1.25 if last_key == "L" else 1.0)
	key_left.get_theme_stylebox("panel").bg_color = YELLOW if last_key != "L" else Color.WHITE
	key_right.get_theme_stylebox("panel").bg_color = YELLOW if last_key == "L" else Color.WHITE
	show_progress()
	if fill >= 1:
		finish(true, "speed", "treadmill", t.time - time_left)
	elif time_left <= 0:
		finish(false, "speed")


func update_lift(delta: float) -> void:
	var w: Dictionary = g.weights.dumbbells[weight_id]
	if started:
		time_left -= delta
		fill = maxf(0, fill - w.sink * delta)
	var scene: Control = bell.get_parent()
	# from just above your head up high
	bell.position = Vector2(scene.size.x / 2, scene.size.y * (1 - 0.42 - minf(1, fill) * 0.4))
	trainee.text = "😐" if fill < 0.3 else "😣" if fill < 0.7 else "😤"
	trainee.position = Vector2((scene.size.x - trainee.size.x) / 2, scene.size.y * 0.96 - trainee.size.y)
	sweat.position = trainee.position + Vector2(trainee.size.x - 34, -10)
	sweat.modulate.a = 1.0 if fill > 0.5 else 0.0
	show_progress()
	if fill >= 1:
		finish(true, "strength", weight_id, g.weights.time - time_left)
	elif time_left <= 0:
		finish(false, "strength")


func show_progress() -> void:
	var f := minf(1, fill)
	meter_fill.anchor_top = 1.0 - f
	meter_fill.get_theme_stylebox("panel").bg_color = Color("9cff57") if f > 0.75 else Color("ffb347")
	timer_label.text = "⏱ %d" % maxi(0, ceili(time_left))
	# the timer goes red when time's nearly up
	var hurry := started and time_left < 4
	timer_pill.get_theme_stylebox("panel").bg_color = Color("d0304a") if hurry else Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.6)


func finish(won: bool, stat: String, what := "", seconds := 0.0) -> void:
	var p := hero
	mode = "result"
	wait = 0.8 # so a last frantic tap doesn't skip the result
	Sound.play("levelUp" if won else "aww")
	clear(top_right)
	clear(body)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	body.add_child(lines)
	var add := func(l: Label) -> void:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.add_child(l)
	set_help("")
	say("")
	if not won:
		title.text = ""
		add.call(label("😅", 130, Color.WHITE))
		var oh := label("So close!", 60, YELLOW)
		shadow(oh, 5)
		add.call(oh)
		add.call(label("Try again? It's free!", 34, Color.WHITE))
		lines.add_child(ButtonText.make("Press {go}", 34, YELLOW))
		return
	var stat_name := stat.capitalize()
	var level: int
	if stat == "speed":
		p.speed_level += 1
		level = p.speed_level
	else:
		p.strength_level += 1
		level = p.strength_level
	p.add_training(level_number, stat)
	p.stat_up = stat # lets the HUD badge do a little jump
	# a personal best is beating your own fastest time on this one
	var is_best: bool = p.bests.has(what) and seconds < p.bests[what]
	if not p.bests.has(what) or seconds < p.bests[what]:
		p.bests[what] = seconds
	title.text = ""
	if is_best:
		# (up by the title, so the result still fits on half a screen)
		var best := label("PERSONAL BEST!", 40, Color.WHITE)
		var badge := pill(best, Color("ff4f8b"))
		top_right.add_child(badge)
		var blink := badge.create_tween().set_loops()
		blink.tween_property(badge, "modulate:a", 0.3, 0.3)
		blink.tween_property(badge, "modulate:a", 1.0, 0.3)
	var arm := label("💪", 130, Color.WHITE)
	add.call(arm)
	arm.resized.connect(func(): arm.pivot_offset = arm.size / 2)
	var flex := arm.create_tween().set_loops()
	flex.tween_property(arm, "rotation_degrees", 12.0, 0.5)
	flex.tween_property(arm, "rotation_degrees", -12.0, 0.5)
	var up := label("⭐ %s UP! ⭐" % stat_name.to_upper(), 60, Color("9cff57"))
	shadow(up, 5)
	add.call(up)
	add.call(label("%s %d ➜ %d" % [stat_name, level - 1, level], 48, YELLOW))
	add.call(label("You'll run faster now!" if stat == "speed" else "Your weapons hit harder now!", 34, Color.WHITE))
	lines.add_child(ButtonText.make("Press {go}", 34, YELLOW))


## The treadmill's belt: grey stripes sliding along.
class Belt extends Control:
	var offset := 0.0

	func _draw() -> void:
		var area: Vector2 = get_parent().size
		var rect := Rect2(area.x * 0.08, area.y * 0.88 - 34, area.x * 0.84, 34)
		draw_rect(rect.grow(5), Color("333333"))
		draw_rect(rect, Color("555555"))
		var x := fmod(offset, 48.0) - 48
		while x < rect.size.x:
			var left := maxf(0, x)
			var right := minf(rect.size.x, x + 24)
			if right > left:
				draw_rect(Rect2(rect.position.x + left, rect.position.y, right - left, rect.size.y), Color("777777"))
			x += 48


## The dumbbell: a bar with a weight on each end, bigger for heavier ones.
class Dumbbell extends Control:
	var plate_size: Vector2
	var colour: Color

	func _init(id: String) -> void:
		plate_size = { small = Vector2(34, 60), medium = Vector2(44, 90), heavy = Vector2(56, 120) }[id]
		colour = { small = Color("4fc3f7"), medium = Color("ff8a3d"), heavy = Color("ff4f6b") }[id]

	func _draw() -> void:
		# drawn around this control's position (its middle, at the bottom of the plates)
		var bar := Rect2(-75, -plate_size.y / 2 - 8, 150, 16)
		draw_rect(bar.grow(3), Color("555555"))
		draw_rect(bar, Color("cccccc"))
		for side in [-1, 1]:
			var plate := Rect2(side * (75 + plate_size.x / 2) - plate_size.x / 2, -plate_size.y, plate_size.x, plate_size.y)
			draw_rect(plate.grow(4), Color("333333"))
			draw_rect(plate, colour)
