class_name Hud
extends CanvasLayer
## What's drawn over the game (src/hud.js and the HUD part of src/style.css): hearts and armour
## shields, Speed and Strength, how many zombies are left, Tag Bux, the weapon you're holding,
## messages, the screen edges flashing when you're hurt, the TAGGED! screen and the Level done! screen.
## F3 (or Back / View / Select) shows the frame rate and how many things are drawn, for checking
## speed on the TV.

const YELLOW := Color("ffe066")
const PURPLE := Color("4b1e8a")
const PILL := Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.55)

var root := Control.new() # everything goes in here, filling the screen
var hearts_row := HBoxContainer.new()
var hearts: Array[HudIcon] = []
var shields: Array[HudIcon] = []
var speed_badge := Label.new()
var strength_badge := Label.new()
var zombies_left := Label.new()
var zombies_pill: PanelContainer
var bux := Label.new()
var bux_pill: PanelContainer
var weapon := Label.new()
var weapon_pill: PanelContainer
var toast_label := Label.new()
var toast_time := 0.0
var hurt := TextureRect.new()
var tagged := ColorRect.new()
var tagged_count := Label.new()
var level_done := ColorRect.new()
var level_done_place := Label.new()
var level_done_bux := Label.new()
var level_done_go := Label.new()
var speed := Label.new()
var hearts_shown := -1
var blink_time := 0.0


func _ready() -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	make_hurt_flash()

	# top left: hearts (and armour shields), and Speed and Strength underneath
	var top_left := VBoxContainer.new()
	top_left.position = Vector2(18, 14)
	top_left.add_theme_constant_override("separation", 8)
	root.add_child(top_left)
	hearts_row.add_theme_constant_override("separation", 6)
	top_left.add_child(hearts_row)
	for i in Data.config.player.hearts:
		var h := HudIcon.new(HudIcon.Kind.HEART, 46)
		hearts_row.add_child(h)
		hearts.append(h)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	top_left.add_child(stats)
	for badge in [speed_badge, strength_badge]:
		stats.add_child(pill(style(badge, 20), 14, Vector2(14, 6)))

	# top middle: zombies left
	zombies_pill = pill(style(zombies_left, 30))
	zombies_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	zombies_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zombies_pill.position.y = 18
	root.add_child(zombies_pill)

	# top right: Tag Bux
	var bux_row := HBoxContainer.new()
	bux_row.add_theme_constant_override("separation", 10)
	bux_row.add_child(HudIcon.new(HudIcon.Kind.COIN, 34))
	bux_row.add_child(style(bux, 36))
	bux.add_theme_color_override("font_color", YELLOW)
	bux_pill = pill(bux_row)
	# (in a row across the top, pushed to the right, so it stays on screen however big it gets)
	var top_right := HBoxContainer.new()
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.offset_top = 18
	top_right.offset_right = -18
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(bux_pill)
	root.add_child(top_right)

	# bottom middle: the weapon you're holding
	weapon_pill = pill(style(weapon, 30))
	weapon_pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	weapon_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	weapon_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weapon_pill.position.y -= 22
	root.add_child(weapon_pill)

	# a little ring in the middle of the screen
	var crosshair := Panel.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(3)
	ring.border_color = Color(1, 1, 1, 0.8)
	ring.set_corner_radius_all(7)
	crosshair.add_theme_stylebox_override("panel", ring)
	crosshair.size = Vector2(14, 14)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(7, 7)
	root.add_child(crosshair)

	# messages, a bit above the middle
	toast_label.add_theme_font_size_override("font_size", 40)
	toast_label.add_theme_color_override("font_color", YELLOW)
	toast_label.add_theme_color_override("font_shadow_color", PURPLE)
	toast_label.add_theme_constant_override("shadow_offset_x", 3)
	toast_label.add_theme_constant_override("shadow_offset_y", 3)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.anchor_top = 0.28
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.modulate.a = 0
	root.add_child(toast_label)

	make_tagged_screen()
	make_level_done_screen()

	speed.add_theme_font_size_override("font_size", 18)
	speed.add_theme_color_override("font_shadow_color", PURPLE)
	speed.position = Vector2(12, 120)
	speed.visible = false
	root.add_child(speed)


## Sets a label's size, with a soft shadow like the browser game's text.
func style(label: Label, font_size: int) -> Label:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


## A rounded see-through box around something, like the browser game's "pills".
func pill(content: Control, radius := 999, padding := Vector2(22, 10)) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = PILL
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(content)
	return panel


## The screen edges flash pink when you lose a heart, or blue when armour blocks a hit.
func make_hurt_flash() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 0.16, 0.4, 0), Color(1, 0.16, 0.4, 0.65)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	hurt.texture = tex
	hurt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hurt.stretch_mode = TextureRect.STRETCH_SCALE # stretched to the screen, so it's an oval
	hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt.modulate.a = 0
	root.add_child(hurt)


func make_tagged_screen() -> void:
	tagged.color = Color(150 / 255.0, 30 / 255.0, 90 / 255.0, 0.6)
	tagged.set_anchors_preset(Control.PRESET_FULL_RECT)
	tagged.visible = false
	root.add_child(tagged)
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 10)
	tagged.add_child(lines)
	var title := Label.new()
	title.text = "TAGGED!"
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", YELLOW)
	title.add_theme_color_override("font_shadow_color", PURPLE)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	var keep := Label.new()
	keep.text = "You keep your Tag Bux and weapons"
	for label in [title, tagged_count, keep]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.add_child(label)
	for label in [tagged_count, keep]:
		label.add_theme_font_size_override("font_size", 34)


## "Level done!", like the browser game's screen between levels.
func make_level_done_screen() -> void:
	level_done.color = Color(60 / 255.0, 20 / 255.0, 110 / 255.0, 0.55)
	level_done.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_done.visible = false
	root.add_child(level_done)
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 14)
	level_done.add_child(lines)
	var title := Label.new()
	title.text = "Level done!"
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color("9cff57"))
	title.add_theme_color_override("font_shadow_color", PURPLE)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	var bux_row := HBoxContainer.new()
	bux_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bux_row.add_theme_constant_override("separation", 10)
	var you_have := Label.new()
	you_have.text = "You've got"
	bux_row.add_child(you_have)
	bux_row.add_child(HudIcon.new(HudIcon.Kind.COIN, 32))
	bux_row.add_child(level_done_bux)
	level_done_go.add_theme_font_size_override("font_size", 38)
	level_done_go.add_theme_color_override("font_color", YELLOW)
	for line in [title, level_done_place, bux_row, level_done_go]:
		if line is Label:
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.add_child(line)
	for label in [level_done_place, you_have, level_done_bux]:
		label.add_theme_font_size_override("font_size", 34)
	# "press fire" gently grows and shrinks, so it's clear what to do next (growing, rather than
	# moving, because the column decides where each line goes)
	var pulse := create_tween().set_loops()
	pulse.tween_property(level_done_go, "scale", Vector2.ONE * 1.08, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(level_done_go, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func show_level_done(place: String, tag_bux: int) -> void:
	level_done_place.text = "%s is safe again!" % place
	level_done_bux.text = "%d Tag Bux to spend" % tag_bux
	level_done_go.text = "Press Space or fire to play again"
	toast_time = 0
	level_done.visible = true


func hide_level_done() -> void:
	level_done.visible = false


func toast(text: String, seconds := 2.5) -> void:
	toast_label.text = text
	toast_time = seconds


func flash(kind: String) -> void:
	var colour := Color(0.24, 0.6, 1.0) if kind == "shield" else Color(1, 0.16, 0.4)
	var g: Gradient = hurt.texture.gradient
	g.colors = PackedColorArray([Color(colour, 0), Color(colour, 0.65)])
	hurt.modulate.a = 1
	create_tween().tween_property(hurt, "modulate:a", 0.0, 0.5)


func show_tagged(on: bool) -> void:
	tagged.visible = on
	if on:
		toast_time = 0


func show_tagged_countdown(seconds_left: float) -> void:
	tagged_count.text = "Back to the start in %d…" % maxi(1, ceili(seconds_left))


## Makes the Tag Bux counter jump when coins go in.
func bump_bux() -> void:
	bump(bux_pill, 1.25, 0.3)


func bump(node: Control, scale_to: float, seconds: float) -> void:
	node.pivot_offset = node.size / 2
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * scale_to, seconds * 0.4)
	t.tween_property(node, "scale", Vector2.ONE, seconds * 0.6)


func show_zombies_left(n: int, gate_open: bool) -> void:
	var text := "1 zombie left" if n == 1 else "%d zombies left" % n
	if gate_open:
		text = "Go to the exit gate!"
	if text != zombies_left.text:
		zombies_left.text = text
		var box: StyleBoxFlat = zombies_pill.get_theme_stylebox("panel")
		box.bg_color = Color("ffb300") if gate_open else PILL


## Brings everything up to date with the hero, once a frame.
func update(hero: Hero) -> void:
	# the heart you just lost (or got back) does a little jump
	if hero.hearts != hearts_shown:
		for i in hearts.size():
			hearts[i].full = i < hero.hearts
		if hearts_shown >= 0:
			var changed := mini(hero.hearts, hearts_shown)
			if changed < hearts.size():
				jump(hearts[changed])
		hearts_shown = hero.hearts
	# blue armour shields go after the hearts (you can buy armour in the shop, in phase 3)
	while shields.size() < hero.shields_max:
		var s := HudIcon.new(HudIcon.Kind.SHIELD, 42)
		hearts_row.add_child(s)
		shields.append(s)
	for i in shields.size():
		shields[i].visible = i < hero.shields_max
		shields[i].full = i < hero.shields
	# hearts blink while you can't be hurt
	blink_time += get_process_delta_time()
	var blinking := hero.safe > 0 and hero.tagged <= 0
	hearts_row.modulate.a = 0.3 if blinking and fmod(blink_time, 0.25) < 0.125 else 1.0

	speed_badge.text = "Speed %d" % hero.speed_level
	strength_badge.text = "Strength %d" % hero.strength_level
	bux.text = str(hero.tag_bux)
	weapon.text = hero.weapon.name
	weapon_pill.visible = hero.tagged <= 0
	if hero.tagged > 0:
		show_tagged_countdown(hero.tagged)


func jump(icon: Control) -> void:
	icon.scale = Vector2.ONE * 1.8
	icon.rotation = deg_to_rad(-15)
	var t := create_tween().set_parallel()
	t.tween_property(icon, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "rotation", 0.0, 0.6).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_speed"):
		speed.visible = not speed.visible


func _process(delta: float) -> void:
	level_done_go.pivot_offset = level_done_go.size / 2 # it grows from its middle
	# messages fade in and out
	toast_time -= delta
	toast_label.modulate.a = move_toward(toast_label.modulate.a, 1.0 if toast_time > 0 else 0.0, delta / 0.3)
	if speed.visible:
		var size := get_viewport().get_visible_rect().size * get_viewport().get_final_transform().get_scale()
		speed.text = "%d fps · %d draw calls · %d objects · drawn at %d x %d" % [
			Performance.get_monitor(Performance.TIME_FPS),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			size.x, size.y,
		]
