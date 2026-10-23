class_name MenuScreen
extends Control
## The screen you see inside the shop or the gym (the .shop styles in src/style.css): a coloured
## background, a title with your Tag Bux, a list to choose from (or a mini-game), a message and
## some help. ShopMenu and GymMenu fill it in.

const YELLOW := Color("ffe066")
const PURPLE := Color("4b1e8a")
const ROW := Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.5)

var hero: Hero
var border: Color # the chosen row's border
var arrow: Color # the arrow by the chosen row
var chosen_price: Color # the chosen row's price
var title := Label.new()
var top_right := HBoxContainer.new() # hearts, Tag Bux or stats, next to the title
var body := VBoxContainer.new() # the list, or a mini-game
var message := Label.new()
var help := RichTextLabel.new() # (so it can show the leave button's picture: see set_help)
var wait := 0.0 # ignores the button you were holding as you walked in


## inner and outer: the background's colours. The chosen row has a border, an arrow by it and its
## price in their own colours.
func _init(inner: Color, outer: Color, border_colour: Color, arrow_colour: Color, chosen_price_colour: Color) -> void:
	border = border_colour
	arrow = arrow_colour
	chosen_price = chosen_price_colour
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var g := Gradient.new()
	g.colors = PackedColorArray([inner, outer])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.3)
	tex.fill_to = Vector2(1.1, 0.9)
	var background := TextureRect.new()
	background.texture = tex
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 40)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", YELLOW)
	shadow(title, 5)
	top.add_child(title)
	top_right.add_theme_constant_override("separation", 24)
	top.add_child(top_right)
	column.add_child(top)
	body.add_theme_constant_override("separation", 8)
	body.custom_minimum_size.x = 900
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(body)
	message.custom_minimum_size.y = 42
	message.add_theme_font_size_override("font_size", 30)
	shadow(message, 3)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # long ones go onto two lines (on half a screen)
	column.add_child(message)
	help.add_theme_font_size_override("normal_font_size", 26)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.fit_content = true
	help.scroll_active = false
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(help)


func _process(delta: float) -> void:
	wait -= delta
	message.pivot_offset = message.size / 2
	# a push of the stick works like a press of the d-pad (see Controls.nav); the stick's own
	# wobbly events are left out in handle_input
	if visible and hero:
		for pair in [["up", "walk_forward"], ["down", "walk_back"], ["left", "turn_left"], ["right", "turn_right"]]:
			if Controls.stick_pushed(pair[0], Controls.pads[hero.index]):
				var press := InputEventAction.new()
				press.action = hero.act(pair[1])
				press.pressed = true
				handle_input(press)


## What a key or button press does (ShopMenu and GymMenu say). Returns true for "Leave".
func handle_input(_event: InputEvent) -> bool:
	return false


## The help at the bottom, with pictures of the buttons for "{go}" and "{leave}" (see ButtonText).
func set_help(text: String) -> void:
	ButtonText.fill(help, text)


static func shadow(label: Label, offset: int) -> void:
	label.add_theme_color_override("font_shadow_color", PURPLE)
	label.add_theme_constant_override("shadow_offset_x", offset)
	label.add_theme_constant_override("shadow_offset_y", offset)


## A rounded box, like the browser game's pills.
static func pill(content: Control, colour := Color(40 / 255.0, 20 / 255.0, 80 / 255.0, 0.6)) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(999)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(content)
	return panel


## Tag Bux, as a coin and a number.
static func bux(amount: int, font_size: int, colour := YELLOW) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(HudIcon.new(HudIcon.Kind.COIN, font_size * 0.85))
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)
	return row


func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Shows a message: "good" ones are green, "bad" ones pink (and give a little shake).
func say(text: String, kind := "") -> void:
	message.text = text
	message.add_theme_color_override("font_color",
		Color("9cff57") if kind == "good" else Color("ffb3b3") if kind == "bad" else Color.WHITE)
	message.scale = Vector2.ONE * 0.6
	var t := create_tween()
	t.tween_property(message, "scale", Vector2.ONE * 1.1, 0.25)
	t.tween_property(message, "scale", Vector2.ONE, 0.1)
	if kind == "bad":
		var shake := create_tween()
		for angle in [-2.0, 2.0, -1.0, 0.0]:
			shake.tween_property(message, "rotation_degrees", angle, 0.1)


## Shows a list of rows. Each row: { icon, name, about (smaller, underneath), label (on the right)
## or price (Tag Bux, on the right), kind }. first: the first row shown (the list scrolls), count:
## how many show at once.
func show_rows(rows: Array, chosen: int, first := 0, count := 99) -> void:
	clear(body)
	var scrolls := rows.size() > count
	if scrolls:
		body.add_child(more("▲ more" if first > 0 else ""))
	for i in range(first, mini(rows.size(), first + count)):
		body.add_child(make_row(rows[i], i == chosen))
	if scrolls:
		body.add_child(more("▼ more" if first + count < rows.size() else ""))


## The "▲ more" or "▼ more" above or below a list that scrolls (empty at the top or bottom).
func more(text: String) -> Label:
	var l := label(text, 20, YELLOW)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = 20
	return l


func make_row(r: Dictionary, chosen: bool) -> Control:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE if chosen else ROW
	box.set_corner_radius_all(22)
	box.set_border_width_all(4)
	box.border_color = border if chosen else Color(0, 0, 0, 0)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	panel.add_child(line)
	var text_colour := PURPLE if chosen else Color.WHITE
	if chosen:
		line.add_child(label("▶", 30, arrow))
	var icon := label(r.icon, 40, Color.WHITE)
	icon.custom_minimum_size.x = 56
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -4)
	words.add_child(label(r.name, 32, text_colour))
	if r.get("about", "") != "":
		var about := label(r.about, 20, text_colour)
		about.modulate.a = 0.85
		words.add_child(about)
	line.add_child(words)
	line.add_child(price(r, chosen))
	panel.scale = Vector2.ONE * (1.04 if chosen else 1.0)
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2)
	return panel


## The right-hand side of a row: a price in Tag Bux, or a word like "Hold it", coloured by kind.
func price(r: Dictionary, chosen: bool) -> Control:
	var colour := chosen_price if chosen else YELLOW
	var kind: String = r.get("kind", "")
	if kind == "dear":
		colour = Color("d0304a") if chosen else Color("ff9a9a")
	elif kind == "holding" or kind == "wearing":
		colour = Color("4caf50")
	if r.has("price"):
		return bux(r.price, 32, colour)
	var small := kind in ["locked", "leave", "full"]
	var l := label(r.get("label", ""), 22 if small else 32, colour)
	if small:
		l.modulate.a = 0.8
	return l


static func label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
