class_name Hud
extends CanvasLayer
## What's drawn over the game: how many zombies are left, messages, and (for checking speed on the
## TV) the frame rate and how many things are drawn each frame. F3 or Select shows or hides that.

var zombies_left := Label.new()
var message := Label.new()
var message_time := 0.0
var speed := Label.new()


func _ready() -> void:
	for label in [zombies_left, message, speed]:
		label.add_theme_color_override("font_outline_color", Color("4b1e8a"))
		label.add_theme_constant_override("outline_size", 10)
		add_child(label)
	zombies_left.add_theme_font_size_override("font_size", 34)
	zombies_left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zombies_left.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zombies_left.position.y = 16

	message.add_theme_font_size_override("font_size", 44)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message.grow_vertical = Control.GROW_DIRECTION_BOTH

	speed.add_theme_font_size_override("font_size", 20)
	speed.position = Vector2(12, 8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_speed"):
		speed.visible = not speed.visible


func show_zombies_left(n: int, gate_open: bool) -> void:
	zombies_left.text = "Walk through the exit gate!" if gate_open else "%d zombies left" % n


func say(text: String, seconds := 3.0) -> void:
	message.text = text
	message_time = seconds


func _process(delta: float) -> void:
	message_time -= delta
	message.visible = message_time > 0
	if speed.visible:
		speed.text = "%d fps · %d draw calls · %d objects" % [
			Performance.get_monitor(Performance.TIME_FPS),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		]
