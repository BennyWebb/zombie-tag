extends Node
## The controls, set up in code so they're easy to read and change: each action is a list of keys
## and joypad buttons or sticks. Scripts ask Input about the actions, e.g.
## Input.is_action_pressed("walk_forward").
##
## For now every joypad and the whole keyboard work the one hero. Two players, each with their own
## joypad or half of the keyboard, come in phase 5.

const DEADZONE := 0.2 # joypad sticks ignore tiny wobbles below this

var using_joypad := false # whether the last thing pressed was on a joypad (they turn a bit slower)


func _ready() -> void:
	add_action("walk_forward", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0])
	add_action("walk_back", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0])
	add_action("turn_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0])
	add_action("turn_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0])
	# any face button (A B X Y, or cross circle square triangle) or the right trigger bonks
	add_action("attack", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		[JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y], [JOY_AXIS_TRIGGER_RIGHT, 1.0])
	add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])
	# for checking speed: shows the frame rate (Back / View / Select on a joypad)
	add_action("show_speed", [KEY_F3], [JOY_BUTTON_BACK], [])


## keys: Key codes. buttons: joypad buttons. axis: [which stick axis, which way], or [] for none.
func add_action(action: String, keys: Array, buttons: Array, axis: Array) -> void:
	InputMap.add_action(action, DEADZONE)
	for key in keys:
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(action, e)
	for button in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.device = -1 # any joypad
		InputMap.action_add_event(action, e)
	if axis:
		var e := InputEventJoypadMotion.new()
		e.axis = axis[0]
		e.axis_value = axis[1]
		e.device = -1
		InputMap.action_add_event(action, e)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		using_joypad = false
	elif event is InputEventJoypadButton and event.pressed:
		using_joypad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > DEADZONE:
		using_joypad = true
