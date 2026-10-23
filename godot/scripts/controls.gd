extends Node
## The controls, set up in code so they're easy to read and change. Each player has their own
## actions, like "p1_attack" and "p2_walk_forward", made from the keys and joypad buttons or sticks
## they use. Scripts ask Input about them through action(), e.g.
## Input.is_action_pressed(Controls.action("attack", 0)).
##
## With one player, the whole keyboard and every joypad work Player 1, until a joypad is used: then
## that one is hers. Pressing a button on a different joypad brings in Player 2 with it, and the
## screen splits in two. (On a computer, the 2 key brings in Player 2 on the arrow keys instead,
## with Player 1 on W A S D.)

signal player_two_joined # (main.gd splits the screen)

const DEADZONE := 0.2 # joypad sticks ignore tiny wobbles below this
const PLAYER_ACTIONS := ["walk_forward", "walk_back", "turn_left", "turn_right", "attack"]
# the keys for each action: the whole keyboard, or each half when two players share it
const KEYS := {
	all = {
		walk_forward = [KEY_W, KEY_UP], walk_back = [KEY_S, KEY_DOWN], turn_left = [KEY_A, KEY_LEFT],
		turn_right = [KEY_D, KEY_RIGHT], attack = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	},
	left = {
		walk_forward = [KEY_W], walk_back = [KEY_S], turn_left = [KEY_A], turn_right = [KEY_D],
		attack = [KEY_SPACE, KEY_SHIFT],
	},
	right = {
		walk_forward = [KEY_UP], walk_back = [KEY_DOWN], turn_left = [KEY_LEFT], turn_right = [KEY_RIGHT],
		attack = [KEY_ENTER, KEY_KP_ENTER],
	},
}
# the joypad buttons and sticks for each action; any face button (A B X Y, or cross circle square
# triangle) or the right trigger bonks
const PAD := {
	walk_forward = [[JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0]],
	walk_back = [[JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0]],
	turn_left = [[JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0]],
	turn_right = [[JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0]],
	attack = [[JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y], [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
}
const ANY_PAD := -1
const NO_PAD := -2

var players := 1
var pads := [ANY_PAD, NO_PAD] # each player's joypad (a device number), ANY_PAD or NO_PAD
var keys := ["all", ""] # each player's keys: "all", "left", "right" or "" for none
var using_joypad := [false, false] # whether each player last used a joypad (they turn a bit slower)


func _ready() -> void:
	for i in 2:
		for a in PLAYER_ACTIONS:
			InputMap.add_action(action(a, i), DEADZONE)
	update_actions()
	add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	# for checking speed: shows the frame rate (Back / View / Select on a joypad)
	add_action("show_speed", [KEY_F3], [JOY_BUTTON_BACK])
	Input.joy_connection_changed.connect(joypad_plugged)


## The name of a player's action. player: 0 for Player 1, 1 for Player 2.
static func action(name: String, player: int) -> String:
	return "p%d_%s" % [player + 1, name]


## Whether an event is this action for any player (like "attack" on the Level done! screen).
func is_anyones(event: InputEvent, name: String) -> bool:
	for i in players:
		if event.is_action_pressed(action(name, i)):
			return true
	return false


## What to call the attack button in messages: the TV has only joypads, so no keys there.
static func button() -> String:
	return "A" if OS.has_feature("android") else "Space or fire"


## Sets each player's actions to their keys and joypad.
func update_actions() -> void:
	for i in 2:
		for a in PLAYER_ACTIONS:
			var name := action(a, i)
			InputMap.action_erase_events(name)
			if keys[i] != "":
				for key in KEYS[keys[i]][a]:
					var e := InputEventKey.new()
					e.physical_keycode = key
					InputMap.action_add_event(name, e)
			if pads[i] != NO_PAD:
				for button_index in PAD[a][0]:
					var e := InputEventJoypadButton.new()
					e.button_index = button_index
					e.device = pads[i]
					InputMap.action_add_event(name, e)
				var m := InputEventJoypadMotion.new()
				m.axis = PAD[a][1][0]
				m.axis_value = PAD[a][1][1]
				m.device = pads[i]
				InputMap.action_add_event(name, m)


## An action that's the same for everyone (any key or joypad).
func add_action(action_name: String, key_list: Array, buttons: Array) -> void:
	InputMap.add_action(action_name, DEADZONE)
	for key in key_list:
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(action_name, e)
	for button_index in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = button_index
		e.device = ANY_PAD
		InputMap.action_add_event(action_name, e)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for i in players:
			if keys[i] != "":
				using_joypad[i] = false
		if players == 1 and event.physical_keycode == KEY_2 and not OS.has_feature("android"):
			# Player 2 on the arrow keys, Player 1 on W A S D
			keys = ["left", "right"]
			add_player_two(NO_PAD)
	elif event is InputEventJoypadButton and event.pressed:
		var menu_button: bool = event.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]
		if players == 1 and pads[0] != ANY_PAD and event.device != pads[0] and not menu_button:
			add_player_two(event.device) # a second joypad: Player 2 is here!
		elif players == 1 and pads[0] == ANY_PAD:
			pads[0] = event.device # the first joypad used is Player 1's
			update_actions()
		for i in players:
			if pads[i] == ANY_PAD or pads[i] == event.device:
				using_joypad[i] = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		for i in players:
			if pads[i] == ANY_PAD or pads[i] == event.device:
				using_joypad[i] = true


func add_player_two(pad: int) -> void:
	players = 2
	pads[1] = pad
	if pad != NO_PAD and keys[0] == "all":
		keys = ["all", ""]
	using_joypad[1] = pad != NO_PAD
	update_actions()
	player_two_joined.emit()


## A joypad was plugged in or taken out. If Player 1's goes, any joypad works her again, or with
## two players, the next one plugged in that isn't Player 2's. (Player 2 keeps hers, in case it
## comes back.)
func joypad_plugged(device: int, connected: bool) -> void:
	if not connected and pads[0] == device:
		pads[0] = ANY_PAD if players == 1 else NO_PAD
		update_actions()
	elif connected and players == 2 and pads[0] == NO_PAD and device != pads[1]:
		pads[0] = device
		update_actions()
