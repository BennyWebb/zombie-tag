class_name Creator
extends Control
## The character creator (src/creator.js): type a name, then pick skin, hair and clothes while your
## hero turns round on the right. With two players, Player 1 goes first, then Player 2.
## On a keyboard you type your name; on a joypad (and on the TV) you pick its letters from a grid.

const ROWS := [
	{ key = "skin", label = "Skin" },
	{ key = "hairStyle", label = "Hair" },
	{ key = "hair", label = "Hair colour" },
	{ key = "outfit", label = "Clothes" },
	{ key = "done", label = "" },
]
const LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R",
	"S", "T", "U", "V", "W", "X", "Y", "Z", "⌫", "✔"]
const GRID_WIDTH := 7

var queue: Array # the heroes still to make
var on_done: Callable
var hero: Hero
var step := "" # "name" (typing), "letters" (the joypad grid) or "look"
var typed := ""
var cell := 0 # the letter chosen on the grid
var row := 0 # the look row chosen
var wait := 0.0 # ignores the button that brought this step up
var panel := VBoxContainer.new() # the left side, made again whenever it changes
var name_box: LineEdit
# your hero, turning round, in a little world of her own on the right
var preview := SubViewport.new()
var preview_body: HeroBody
var turn := 0.0


func _init(heroes: Array, done: Callable) -> void:
	queue = heroes.duplicate()
	on_done = done
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var wash := ColorRect.new()
	wash.color = Color(40 / 255.0, 15 / 255.0, 80 / 255.0, 0.7)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	panel.position = Vector2(50, 20)
	panel.size = Vector2(700, 680)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	make_preview()
	next()


func make_preview() -> void:
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.size = Vector2i(600, 800)
	preview.msaa_3d = Viewport.MSAA_4X
	add_child(preview)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.45
	preview.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.6
	sun.rotation = Vector3(-0.6, 0.5, 0)
	preview.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40
	camera.position = Vector3(0, 1.4, 5.2)
	camera.rotation.x = -0.06
	preview.add_child(camera)
	var picture := TextureRect.new()
	picture.texture = preview.get_texture()
	picture.position = Vector2(760, 0)
	picture.size = Vector2(450, 600)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(picture)


func update_preview() -> void:
	if preview_body:
		preview_body.queue_free()
	preview_body = HeroBody.new(hero.look, hero.wearing, 1)
	preview_body.rotation.y = turn
	preview.add_child(preview_body)


## On to the next hero, or done.
func next() -> void:
	if queue.is_empty():
		on_done.call()
		return
	hero = queue.pop_front()
	typed = hero.look.name if hero.created else ""
	cell = 0
	wait = 0.3 # so the button that picked the hero doesn't also pick a letter
	# typing needs a keyboard: someone who picked her hero with a joypad (and everyone on the TV)
	# spells her name on the letter grid
	step = "letters" if hero.picked_with_pad or OS.has_feature("android") else "name"
	update_preview()
	draw()


## A joypad button while the typing box is up: no keyboard, then, so over to the letter grid.
func _input(event: InputEvent) -> void:
	if step == "name" and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled() # (so the typing box doesn't get it too)
		typed = name_box.text if name_box else typed
		step = "letters"
		wait = 0.3
		draw()


func finish_name(text: String) -> void:
	hero.set_look({ name = text if text != "" else "Player %d" % (hero.index + 1) })
	step = "look"
	row = 0
	wait = 0.3 # so the Enter that finished the name doesn't also press a button
	update_preview()
	draw()


func _process(delta: float) -> void:
	turn += delta * 0.8
	if preview_body:
		preview_body.rotation.y = turn
	wait -= delta
	if wait > 0 or step == "name":
		return
	var up := Controls.nav("up", hero.index)
	var down := Controls.nav("down", hero.index)
	var left := Controls.nav("left", hero.index)
	var right := Controls.nav("right", hero.index)
	var go := Input.is_action_just_pressed(hero.act("go"))
	if step == "letters":
		update_letters(up, down, left, right, go)
	else:
		update_look(up, down, left, right, go)


## Picking a name with a joypad: move round the letters, fire adds one.
func update_letters(up: bool, down: bool, left: bool, right: bool, go: bool) -> void:
	var before := cell
	var n := LETTERS.size()
	if left:
		cell = maxi(0, cell - 1)
	if right:
		cell = mini(n - 1, cell + 1)
	if up and cell >= GRID_WIDTH:
		cell -= GRID_WIDTH
	if down:
		cell = mini(n - 1, cell + GRID_WIDTH)
	if cell != before:
		Sound.play("tick")
	if go:
		var letter: String = LETTERS[cell]
		if letter == "✔":
			Sound.play("select")
			finish_name(typed)
			return
		if letter == "⌫":
			Sound.play("tick" if typed else "nope")
			typed = typed.left(-1)
		elif typed.length() < Data.config.creator.maxNameLength:
			Sound.play("tick")
			typed += letter if typed == "" else letter.to_lower()
		else:
			Sound.play("nope")
	if go or cell != before:
		draw()


func update_look(up: bool, down: bool, left: bool, right: bool, go: bool) -> void:
	var before := row
	if up:
		row = maxi(0, row - 1)
	if down:
		row = mini(ROWS.size() - 1, row + 1)
	var step_by := (1 if right else 0) - (1 if left else 0)
	if row != before or step_by:
		Sound.play("tick")
	var key: String = ROWS[row].key
	if step_by and key != "done":
		var options := choices(key)
		var i := maxi(0, options.find(hero.look[key]))
		hero.set_look({ key: options[(i + step_by + options.size()) % options.size()] })
		update_preview()
	if go:
		Sound.play("select")
		if key == "done":
			hero.created = true
			next()
			return
		row += 1 # on to the next choice
	if go or row != before or step_by:
		draw()


## What a look row can be: colours, or the hair styles' ids.
static func choices(key: String) -> Array:
	var c: Dictionary = Data.config.creator
	match key:
		"skin": return c.skins
		"hairStyle": return c.hairStyles.map(func(h): return h.id)
		"hair": return c.hairColours
		_: return c.outfitColours


# ---------- drawing ----------

func draw() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	name_box = null
	var b := Screens.badge(hero.index)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(b)
	if step == "look":
		draw_look()
	else:
		draw_name()


func draw_name() -> void:
	panel.add_child(left(Screens.heading("What's your name?", 56)))
	if step == "name":
		# typing on a keyboard
		name_box = LineEdit.new()
		name_box.text = typed
		name_box.max_length = Data.config.creator.maxNameLength
		name_box.add_theme_font_size_override("font_size", 44)
		name_box.custom_minimum_size = Vector2(520, 80)
		name_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_box.text_changed.connect(tidy_name)
		name_box.text_submitted.connect(finish_name)
		panel.add_child(name_box)
		name_box.grab_focus.call_deferred()
		panel.add_child(left(MenuScreen.label("Type your name, then press Enter", 28, Color.WHITE)))
		return
	# picking letters with a joypad
	var shown := MenuScreen.label(typed if typed != "" else " ", 40, Screens.PURPLE)
	panel.add_child(Screens.card(shown, true))
	var grid := GridContainer.new()
	grid.columns = GRID_WIDTH
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in LETTERS.size():
		var l := MenuScreen.label(LETTERS[i], 30, Screens.PURPLE if i == cell else Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(40, 0)
		var box := Screens.card(l, i == cell)
		box.get_theme_stylebox("panel").content_margin_top = 2
		box.get_theme_stylebox("panel").content_margin_bottom = 2
		if LETTERS[i] == "✔" and i != cell:
			box.get_theme_stylebox("panel").bg_color = Color("2e9e4f")
		grid.add_child(box)
	panel.add_child(grid)
	panel.add_child(ButtonText.make("🡐 🡑 🡒 🡓 choose  ·  {go} picks a letter  ·  ✔ when done", 24, Color.WHITE, false))


## Typed names are letters only, starting with a capital.
func tidy_name(text: String) -> void:
	var tidy := ""
	for ch in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
			tidy += ch
	tidy = tidy.left(Data.config.creator.maxNameLength)
	if tidy != "":
		tidy = tidy[0].to_upper() + tidy.substr(1)
	if tidy != text:
		name_box.text = tidy
		name_box.caret_column = tidy.length()
	typed = tidy


func draw_look() -> void:
	panel.add_child(left(Screens.heading("Hi %s!" % hero.look.name, 64)))
	for i in ROWS.size():
		var r: Dictionary = ROWS[i]
		var chosen := i == row
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		if r.key == "done":
			line.add_child(MenuScreen.label("✔ Done!", 34, Screens.PURPLE if chosen else Color.WHITE))
		else:
			var name_label := MenuScreen.label(r.label, 28, Screens.PURPLE if chosen else Color.WHITE)
			name_label.custom_minimum_size.x = 170
			line.add_child(name_label)
			var options := choices(r.key)
			for o in options:
				var on: bool = hero.look[r.key] == o
				if r.key == "hairStyle":
					var style_name: String = Data.config.creator.hairStyles.filter(func(h): return h.id == o)[0].name
					var t := MenuScreen.label(style_name, 20, Screens.PINK if on else (Screens.PURPLE if chosen else Color.WHITE))
					line.add_child(t)
				else:
					var swatch := Panel.new()
					var box := StyleBoxFlat.new()
					box.bg_color = Data.colour(o)
					box.set_corner_radius_all(8)
					box.set_border_width_all(4 if on else 0)
					box.border_color = Screens.PINK
					swatch.add_theme_stylebox_override("panel", box)
					swatch.custom_minimum_size = Vector2(34, 34)
					line.add_child(swatch)
		panel.add_child(Screens.card(line, chosen))
	panel.add_child(ButtonText.make("🡑 🡓 choose  ·  🡐 🡒 change  ·  {go} next", 24, Color.WHITE, false))


static func left(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l
