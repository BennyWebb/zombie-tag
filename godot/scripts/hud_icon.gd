class_name HudIcon
extends Control
## A heart, an armour shield or a Tag Bux coin for the HUD, drawn as shapes (the browser game uses
## emoji, which Godot's fonts don't have, and shapes stay sharp on a big TV).

enum Kind { HEART, SHIELD, COIN }

const RED := Color("ff3d5c")
const EMPTY_HEART := Color(1, 1, 1, 0.45)
const EMPTY_SHIELD := Color(1, 1, 1, 0.35)
const SHADOW := Color(75 / 255.0, 30 / 255.0, 138 / 255.0, 0.6)

var kind: Kind
var full := true:
	set(value):
		full = value
		queue_redraw()


func _init(icon_kind: Kind, size_px: float) -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(size_px * (0.8 if kind == Kind.SHIELD else 1.0), size_px)
	pivot_offset = custom_minimum_size / 2 # so it grows and spins round its middle
	size_flags_vertical = Control.SIZE_SHRINK_CENTER # (a row taller than the icon would stretch it)


func _draw() -> void:
	match kind:
		Kind.HEART: draw_heart()
		Kind.SHIELD: draw_shield()
		Kind.COIN: draw_coin()


func draw_heart() -> void:
	# the classic heart curve, scaled to fit
	var points := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16 * pow(sin(t), 3)
		var y := -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
		points.append(size / 2 + Vector2(x, y + 1.5) * size.x / 36.0)
	if full:
		draw_colored_polygon(offset(points, Vector2(2, 3)), SHADOW)
	draw_colored_polygon(points, RED if full else EMPTY_HEART)
	if full: # a little shine
		draw_circle(size * Vector2(0.32, 0.32), size.x * 0.08, Color(1, 1, 1, 0.55))


func draw_shield() -> void:
	var w := size.x
	var h := size.y
	var points := PackedVector2Array([Vector2(0.5 * w, 0), Vector2(w, 0.15 * h), Vector2(0.92 * w, 0.62 * h),
		Vector2(0.5 * w, h), Vector2(0.08 * w, 0.62 * h), Vector2(0, 0.15 * h)])
	if not full:
		draw_colored_polygon(points, EMPTY_SHIELD)
		return
	draw_colored_polygon(offset(points, Vector2(2, 3)), SHADOW)
	# light blue at the top left to darker blue at the bottom right
	var colours := PackedColorArray()
	for p in points:
		colours.append(Color("8fd8ff").lerp(Color("1e6fd6"), (p.x / w + p.y / h) / 2))
	draw_polygon(points, colours)


func draw_coin() -> void:
	var r := size.x / 2
	draw_circle(size / 2, r, Color("e09b00"))
	draw_circle(size / 2, r * 0.8, Color("ffd23f"))
	var font := get_theme_default_font()
	var font_size := int(size.x * 0.7)
	var text_size := font.get_string_size("T", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2((size.x - text_size.x) / 2, size.y / 2 + font_size * 0.36), "T",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("e09b00"))


static func offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for p in points:
		moved.append(p + by)
	return moved
