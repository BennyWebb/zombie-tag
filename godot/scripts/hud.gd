class_name Hud
extends CanvasLayer
## What's drawn over the game (src/hud.js and the HUD part of src/style.css): hearts and armour
## shields, Speed and Strength, how many zombies are left, Tag Bux, the weapon you're holding,
## messages, the screen edges flashing when you're hurt, a warning when a zombie's close behind you,
## the TAGGED! screen and the Level done! screen.
## F3 (or Back / View / Select) shows the frame rate and how many things are drawn, for checking
## speed on the TV.
## With two players each has her own, on her half of the screen, shrunk a bit to fit, with her name
## at the top right.
## It's drawn into a picture of its own (a SubViewport), which is only drawn again when something on
## it changes or moves: most of the time nothing does, and showing the picture is much quicker than
## drawing every label, box and heart again each frame.

const YELLOW := Color("ffe066")
const PURPLE := Color("4b1e8a")
const PILL := Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.55)

var player := 0 # 0 for Player 1, 1 for Player 2
var root := Control.new() # everything goes in here, filling the screen (or your half of it)
var canvas := SubViewport.new() # root is drawn into this, when something changes (see redraw)
var picture := TextureRect.new() # and this shows it
var moving_until := 0.0 # something's moving (like a heart jumping) until then, in seconds
var who := Label.new() # your name, with two players
var hearts_row := HBoxContainer.new()
var hearts: Array[HudIcon] = []
var shields: Array[HudIcon] = []
var speed_badge := Label.new()
var strength_badge := Label.new()
var zombies_left := Label.new()
var zombies_pill: PanelContainer
var boss_box := VBoxContainer.new() # the Zombie King's health, while he's about
var boss_fill := BossFill.new()
var bux := Label.new()
var bux_pill: PanelContainer
var weapon := Label.new()
var weapon_pill: PanelContainer
var toast_label := Label.new()
var behind_glow := TextureRect.new() # red along the bottom when a zombie's close behind you
var behind_label := Label.new()
var behind_shown := -1.0
var toast_time := 0.0
var hurt := TextureRect.new()
var tagged := ColorRect.new()
var tagged_count := Label.new()
var tagged_title := Label.new()
var tagged_keep := Label.new()
var level_done := ColorRect.new()
var level_done_place := Label.new()
var level_done_bux := Label.new()
var level_done_go := RichTextLabel.new() # (with a picture of the buttons: see ButtonText)
var speed := Label.new()
var views: Array[RID] = [] # the screens being drawn (main.gd sets them), for timing them
# Asking Godot to time the drawing once crashed the Shield, and its graphics chip can't time itself
# anyway, so on Android the overlay leaves those out
var can_time_drawing := not OS.has_feature("android")
var game_time := 0.0 # how long the game's own code took this frame, in ms (main.gd sets it)
var drawn_at := Vector2i() # how many dots each hero's view of the world has (main.gd sets it)
var test_hidden: Array[CanvasItem] = [] # what the graphics test hid
var frame_times := PackedFloat32Array() # the last 120 frames (2 seconds at 60 fps), in ms, to find the slow ones
var hearts_shown := -1
var blink_time := 0.0


func _init(for_player := 0) -> void:
	player = for_player


func _ready() -> void:
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.size_2d_override_stretch = true
	add_child(canvas)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	picture.texture = canvas.get_texture()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(picture)
	fit()
	get_tree().root.size_changed.connect(fit)
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

	# under it, the Zombie King's health
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_box.position.y = 84
	boss_box.custom_minimum_size.x = 460
	boss_box.visible = false
	root.add_child(boss_box)
	var king := style(Label.new(), 26)
	king.text = "👑 Zombie King"
	king.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	king.add_theme_color_override("font_shadow_color", PURPLE)
	boss_box.add_child(king)
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = PILL
	bar_box.set_border_width_all(3)
	bar_box.border_color = Color.WHITE
	bar_box.set_corner_radius_all(11)
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", bar_box)
	bar.custom_minimum_size.y = 22
	boss_box.add_child(bar)
	boss_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(boss_fill)

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
	# under it, your name (with two players)
	var who_pill := pill(style(who, 22), 999, Vector2(16, 4))
	who_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	who_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	who_pill.position = Vector2(-18, 92)
	who_pill.get_theme_stylebox("panel").bg_color = Color(Data.config.heroes[player].tagColour)
	who_pill.visible = false
	root.add_child(who_pill)

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

	# a zombie close behind you: the bottom of the screen glows red, more as it gets closer
	var g_behind := Gradient.new()
	g_behind.colors = PackedColorArray([Color(1, 0.1, 0.25, 0), Color(1, 0.1, 0.25, 0.75)])
	var behind_tex := GradientTexture2D.new()
	behind_tex.gradient = g_behind
	behind_tex.fill_from = Vector2(0, 0)
	behind_tex.fill_to = Vector2(0, 1)
	behind_glow.texture = behind_tex
	behind_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	behind_glow.stretch_mode = TextureRect.STRETCH_SCALE
	behind_glow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	behind_glow.offset_top = -170
	behind_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	behind_glow.visible = false
	root.add_child(behind_glow)
	style(behind_label, 30)
	behind_label.add_theme_color_override("font_color", Color.WHITE)
	behind_label.add_theme_color_override("font_outline_color", Color("b0103a"))
	behind_label.add_theme_constant_override("outline_size", 8)
	behind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	behind_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	behind_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	behind_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	behind_label.offset_bottom = -92 # (above the weapon you're holding)
	behind_label.visible = false
	root.add_child(behind_label)

	# messages, a bit above the middle
	toast_label.add_theme_font_size_override("font_size", 40)
	toast_label.add_theme_color_override("font_color", YELLOW)
	toast_label.add_theme_color_override("font_shadow_color", PURPLE)
	toast_label.add_theme_constant_override("shadow_offset_x", 3)
	toast_label.add_theme_constant_override("shadow_offset_y", 3)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # (long ones wrap on half a screen)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_label.anchor_top = 0.28
	toast_label.offset_left = 30
	toast_label.offset_right = -30
	toast_label.modulate.a = 0
	root.add_child(toast_label)

	make_tagged_screen()
	make_level_done_screen()

	speed.add_theme_font_size_override("font_size", 24) # (big enough to read on the TV from the sofa)
	speed.add_theme_color_override("font_shadow_color", PURPLE)
	speed.add_theme_constant_override("outline_size", 6)
	speed.add_theme_color_override("font_outline_color", PURPLE)
	speed.position = Vector2(12, 120)
	speed.visible = false
	add_child(speed) # (on top of the picture: it changes every frame)

	# anything in the HUD that changes (its words, its size or place, or showing or hiding) has it
	# drawn again; things added later too, like the shop and gym
	for node in [root] + root.find_children("*", "", true, false):
		watch(node)
	get_tree().node_added.connect(watch)
	visibility_changed.connect(redraw)
	warm_up_emoji()


## The first time an emoji is drawn it's made into a picture, which made the gym stop for a moment
## when its big faces first showed. So every emoji the shop and gym show is drawn once here, too
## faint to see, as the game starts.
func warm_up_emoji() -> void:
	var text := "🏃🏋😐😣😤💪😅💦⏱✔⭐🚪↩➜👑💀🎉🛍👋🪵💥🔒"
	var icons := []
	find_icons(Data.config, icons)
	text += "".join(icons)
	var warm := Label.new()
	warm.text = text
	warm.add_theme_font_size_override("font_size", 64)
	warm.modulate.a = 0.01
	warm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	warm.size = Vector2(600, 0)
	root.add_child(warm)
	get_tree().create_timer(1.0).timeout.connect(warm.queue_free)
	# and the same for the letters, at each size the HUD, shop and gym use (each size's letters are
	# made into pictures the first time they're drawn, which stopped the game for a moment when the
	# shop or gym first opened). They're shared, so the first HUD does it for everyone.
	if player > 0:
		return
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?.,'’…:·+-%()➜✔⭐◀▶▮▯"
	for size in [18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 44, 48, 54, 60, 110, 120]:
		var line := Label.new()
		line.text = letters
		line.add_theme_font_size_override("font_size", size)
		line.modulate.a = 0.01
		root.add_child(line)
		get_tree().create_timer(1.0).timeout.connect(line.queue_free)
	# (letters with an outline are made into pictures of their own)
	for outlined in [[behind_label, 30, 8], [speed, 24, 6]]:
		var line := Label.new()
		line.text = letters
		line.add_theme_font_size_override("font_size", outlined[1])
		line.add_theme_constant_override("outline_size", outlined[2])
		line.modulate.a = 0.01
		root.add_child(line)
		get_tree().create_timer(1.0).timeout.connect(line.queue_free)


## Every "icon" in the game's settings (the weapons', outfits' and so on).
static func find_icons(value, found: Array) -> void:
	if value is Dictionary:
		for key in value:
			if key == "icon" and value[key] is String:
				found.append(value[key])
			else:
				find_icons(value[key], found)
	elif value is Array:
		for v in value:
			find_icons(v, found)


## The picture is as big as the screen, in dots, with the HUD laid out on it as on the screen.
func fit() -> void:
	var screen := get_viewport()
	canvas.size_2d_override = Vector2i(screen.get_visible_rect().size)
	canvas.size = Vector2i(screen.get_visible_rect().size * screen.get_final_transform().get_scale())
	redraw()


func watch(node: Node) -> void:
	# (by name: the shop and gym have a draw() of their own)
	if node is CanvasItem and (node == root or root.is_ancestor_of(node)) and not node.is_connected("draw", redraw):
		for change in ["draw", "item_rect_changed", "visibility_changed"]:
			node.connect(change, redraw)


## Draws the HUD's picture again this frame.
func redraw() -> void:
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE


## Something's moving for this long, so the picture's drawn every frame till then.
func moving(seconds: float) -> void:
	moving_until = maxf(moving_until, Time.get_ticks_msec() / 1000.0 + seconds + 0.05)


## Puts the HUD on part of the screen: all of it with one player, or her half with two. zoom: how
## big things are (the browser game shrinks them to 0.7 on half a screen).
func set_full_screen() -> void:
	root.scale = Vector2.ONE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	who.get_parent().visible = false


func set_view(rect: Rect2, zoom: float, show_name: bool) -> void:
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = rect.position
	root.scale = Vector2.ONE * zoom
	root.size = rect.size / zoom
	who.get_parent().visible = show_name


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
	var title := tagged_title
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", YELLOW)
	title.add_theme_color_override("font_shadow_color", PURPLE)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	for label in [title, tagged_count, tagged_keep]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(label)
	for label in [tagged_count, tagged_keep]:
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
	level_done_go = ButtonText.make("", 38, YELLOW)
	var pick := Label.new()
	pick.text = "%s: pick a level" % Screens.back_name()
	pick.add_theme_font_size_override("font_size", 24)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for line in [title, level_done_place, bux_row, level_done_go, pick]:
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


## next: what pressing the button does, like "for level 2: School and Playground 🏫".
func show_level_done(place: String, tag_bux: int, next: String) -> void:
	level_done_place.text = "%s is safe again!" % place
	level_done_bux.text = "%d Tag Bux to spend" % tag_bux
	ButtonText.fill(level_done_go, "Press {go} %s" % next)
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
	moving(0.5)


## difficulty: how hard it is (see config.json), which decides what you lose.
func show_tagged(on: bool, difficulty := {}) -> void:
	tagged.visible = on
	if not on:
		return
	toast_time = 0
	var one_life: bool = difficulty.get("oneLife", false)
	tagged_title.text = "GAME OVER!" if one_life else "TAGGED!"
	tagged_count.visible = not one_life
	tagged_keep.text = "You keep your Tag Bux and weapons"
	if difficulty.get("loseItems", false):
		tagged_keep.text = "Your weapons and armour are gone! You keep your Tag Bux"
	if one_life:
		tagged_keep.text = "Your Hardcore game starts again from level 1! 💀"


func show_tagged_countdown(seconds_left: float) -> void:
	tagged_count.text = "Back to the start in %d…" % maxi(1, ceili(seconds_left))


## A zombie close behind you: danger 0 (none) to 1 (right behind you), and which side it's on
## (-1 left, 1 right, 0 straight behind). Only changes what's shown when it changes enough to see,
## so the HUD's picture isn't drawn again every frame.
func show_behind(danger: float, side: int) -> void:
	var shown := snappedf(danger, 0.1)
	var text := "%s🧟 Behind you!%s" % ["◀ " if side < 0 else "", " ▶" if side > 0 else ""]
	if shown == behind_shown and text == behind_label.text:
		return
	behind_shown = shown
	behind_glow.visible = shown > 0
	behind_glow.modulate.a = shown
	behind_label.visible = shown > 0
	behind_label.text = text
	redraw()


## Makes the Tag Bux counter jump when coins go in.
func bump_bux() -> void:
	bump(bux_pill, 1.25, 0.3)


func bump(node: Control, scale_to: float, seconds: float) -> void:
	node.pivot_offset = node.size / 2
	moving(seconds)
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * scale_to, seconds * 0.4)
	t.tween_property(node, "scale", Vector2.ONE, seconds * 0.6)


## The Zombie King's health bar, while he's about (boss: him, or null).
func show_boss(boss: Zombie) -> void:
	boss_box.visible = boss != null
	if boss:
		boss_fill.set_amount(maxf(0.0, boss.health / boss.max_health))


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
	var blink := 0.3 if blinking and fmod(blink_time, 0.25) < 0.125 else 1.0
	if blink != hearts_row.modulate.a:
		hearts_row.modulate.a = blink
		redraw()

	who.text = hero.look.name
	speed_badge.text = "Speed %d" % hero.speed_level
	strength_badge.text = "Strength %d" % hero.strength_level
	bux.text = str(hero.tag_bux)
	# the weapon you're holding (and how many hits a Spiky Stick has left), or a red warning
	var w = hero.weapon
	var text := "No weapon! Get a free Spiky Stick at the 🛍️ shop"
	if w:
		text = "%s %s" % [w.icon, w.name]
		if w.has("hitsLeft"):
			text += " · %d %s left" % [w.hitsLeft, "hit" if w.hitsLeft == 1 else "hits"]
		if w.has("battery"):
			# the laser's battery: a bar for each zap left
			var full := mini(int(hero.battery), int(w.battery))
			text += " · %s%s" % ["recharging " if hero.battery_flat else "", "▮".repeat(full) + "▯".repeat(int(w.battery) - full)]
	if text != weapon.text:
		weapon.text = text
		var box: StyleBoxFlat = weapon_pill.get_theme_stylebox("panel")
		box.bg_color = PILL if w and not hero.battery_flat else Color(200 / 255.0, 60 / 255.0, 40 / 255.0, 0.75)
	weapon_pill.visible = hero.tagged <= 0
	# the badge for the stat you just trained does a little jump
	if hero.stat_up != "" and not hero.inside:
		var badge := speed_badge if hero.stat_up == "speed" else strength_badge
		for i in 3:
			get_tree().create_timer(i * 0.4).timeout.connect(bump.bind(badge.get_parent(), 1.25, 0.4))
		hero.stat_up = ""
	if hero.tagged > 0 and not hero.out:
		show_tagged_countdown(hero.tagged)


func jump(icon: Control) -> void:
	moving(0.6)
	icon.scale = Vector2.ONE * 1.8
	icon.rotation = deg_to_rad(-15)
	var t := create_tween().set_parallel()
	t.tween_property(icon, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "rotation", 0.0, 0.6).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_speed") and player == 0:
		speed.visible = not speed.visible
		time_views()


## For the graphics test: everything but the F3 numbers hidden (and back as it was after).
func hide_for_test(hide: bool) -> void:
	if hide and test_hidden.is_empty():
		for child in root.get_children():
			if child != speed and child.visible:
				child.visible = false
				test_hidden.append(child)
	elif not hide:
		for child in test_hidden:
			child.visible = true
		test_hidden.clear()


## Starts (or stops) timing how long the screens take to draw, for the F3 numbers.
func time_views() -> void:
	if not can_time_drawing:
		return
	for rid in views:
		RenderingServer.viewport_set_measure_render_time(rid, speed.visible)


func _process(delta: float) -> void:
	level_done_go.pivot_offset = level_done_go.size / 2 # it grows from its middle
	# messages fade in and out
	toast_time -= delta
	var fade := move_toward(toast_label.modulate.a, 1.0 if toast_time > 0 else 0.0, delta / 0.3)
	if fade != toast_label.modulate.a:
		toast_label.modulate.a = fade
		redraw()
	# the picture's drawn every frame while things move, the Level done! screen pulses, or
	# something moves in the shop or gym
	if Time.get_ticks_msec() / 1000.0 < moving_until or level_done.visible \
			or root.get_children().any(func(c): return c is MenuScreen and c.visible and c.busy()):
		redraw()
	# for 60 fps every frame has to be quick, not just most of them, so the slowest ones are kept too
	frame_times.append(delta * 1000)
	if frame_times.size() > 120:
		frame_times.remove_at(0)
	if speed.visible:
		var slow := frame_times.duplicate()
		slow.sort()
		var late := 0 # frames that missed the TV's 60 a second
		for t in frame_times:
			if t > 18.0:
				late += 1
		# how long things take, in milliseconds (for 60 fps a whole frame has 16.7 ms): the whole
		# frame, the game's own code, and the drawing: the processor getting it ready and the
		# graphics chip doing it (or on Android, everything that isn't the game's code, which
		# includes waiting for the TV to be ready for the next picture: at 60 fps the frame is
		# always about 16.7 ms, however quickly it was drawn)
		var frame := Performance.get_monitor(Performance.TIME_PROCESS) * 1000
		var drawing := "drawing and waiting for the screen %.1f ms" % (frame - game_time)
		if can_time_drawing:
			var cpu := RenderingServer.get_frame_setup_time_cpu()
			var gpu := 0.0
			for rid in views:
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			drawing = "drawing: processor %.1f ms, graphics chip %.1f ms" % [cpu, gpu]
		speed.text = ("%d fps · %d draw calls · %d objects · world drawn at %d x %d\nframe %.1f ms · game code %.1f ms · %s"
			+ "\nlast 120 frames: slowest %.1f ms · 1 in 20 slower than %.1f ms · %d late") % [
			Performance.get_monitor(Performance.TIME_FPS),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			drawn_at.x, drawn_at.y, frame, game_time, drawing,
			slow[-1], slow[int(slow.size() * 0.95)], late,
		]


## The Zombie King's health: pink to yellow, rounded at both ends, inside the bar's white border.
class BossFill extends Control:
	const BORDER := 3.0
	var amount := 1.0

	func set_amount(a: float) -> void:
		if a != amount:
			amount = a
			queue_redraw()

	func _draw() -> void:
		var full := size.x - BORDER * 2
		var w := full * amount
		var h := size.y - BORDER * 2
		if w <= 0.5:
			return
		var r := minf(h / 2, w / 2)
		# round the corners: a quarter circle at each, going round clockwise from the top left
		var points := PackedVector2Array()
		var colours := PackedColorArray()
		for corner in [[r, r, PI], [w - r, r, PI * 1.5], [w - r, h - r, 0.0], [r, h - r, PI * 0.5]]:
			for step in 7:
				var a: float = corner[2] + step * PI / 12
				var p := Vector2(corner[0] + cos(a) * r, corner[1] + sin(a) * r)
				points.append(p + Vector2(BORDER, BORDER))
				colours.append(Color("ff4f8b").lerp(Color("ffd23f"), p.x / full))
		draw_polygon(points, colours)
