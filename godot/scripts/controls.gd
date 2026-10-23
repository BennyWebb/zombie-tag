extends Node
## The controls, set up in code so they're easy to read and change. Each player has their own
## actions, like "p1_attack" and "p2_walk_forward", made from the keys and joypad buttons or sticks
## they use. Scripts ask Input about them through action(), e.g.
## Input.is_action_pressed(Controls.action("attack", 0)).
##
## With one player, the whole keyboard and every joypad work Player 1. With two, each plays with
## what she picked her hero with on "Who's playing?" (see screens.gd): her own joypad, the
## keyboard, or half of it each (Player 1 on W A S D and Space, Player 2 on the arrows and Enter).
##
## Joypads have two ways to play (a setting in the pause menu): "Simple", where the left stick (or
## d-pad) walks and turns, for joypads with one stick or none; and "Two sticks", where the left
## stick walks and steps sideways and the right stick turns, like most games on a joypad with two.
##
## The menus have their own actions ("menu_up", "menu_go" and so on) that anyone's keys or joypad
## work. Menus check them once a frame with Input.is_action_just_pressed, so a stick pushed once
## moves the choice once.

const DEADZONE := 0.2 # joypad sticks ignore tiny wobbles below this
const PLAYER_ACTIONS := ["walk_forward", "walk_back", "turn_left", "turn_right", "step_left", "step_right", "attack"]
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
# the joypad buttons for each action (the sticks are in pad_sticks); any face button (A B X Y, or
# cross circle square triangle) or the right trigger bonks
const PAD := {
	walk_forward = [JOY_BUTTON_DPAD_UP], walk_back = [JOY_BUTTON_DPAD_DOWN],
	turn_left = [JOY_BUTTON_DPAD_LEFT], turn_right = [JOY_BUTTON_DPAD_RIGHT],
	step_left = [], step_right = [],
	attack = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y],
}
const ANY_PAD := -1
const NO_PAD := -2

var players := 1
var pads := [ANY_PAD, NO_PAD] # each player's joypad (a device number), ANY_PAD or NO_PAD
var keys := ["all", ""] # each player's keys: "all", "left", "right" or "" for none
var using_joypad := [false, false] # whether each player last used a joypad (they turn a bit slower)
var two_sticks := false # see above (save.gd sets it)


func _ready() -> void:
	for i in 2:
		for a in PLAYER_ACTIONS:
			InputMap.add_action(action(a, i), DEADZONE)
	update_actions()
	add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	# for checking speed: shows the frame rate (Back / View / Select on a joypad)
	add_action("show_speed", [KEY_F3], [JOY_BUTTON_BACK])
	add_action("menu_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0])
	add_action("menu_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0])
	add_action("menu_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0])
	add_action("menu_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0])
	add_action("menu_go", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], PAD.attack)
	add_action("menu_back", [KEY_ESCAPE], [JOY_BUTTON_START])
	# changing how your hero looks, or deleting one (Back / View / Select)
	add_action("menu_extra", [KEY_C, KEY_X, KEY_DELETE], [JOY_BUTTON_BACK])
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


## Who plays with what: for each player, { keys = "all", "left", "right" or "", pad = a joypad's
## number, ANY_PAD or NO_PAD }.
func set_devices(devices: Array) -> void:
	players = devices.size()
	for i in 2:
		keys[i] = devices[i].keys if i < players else ""
		pads[i] = devices[i].pad if i < players else NO_PAD
		if keys[i] == "":
			using_joypad[i] = true # (otherwise it stays as it was: what she last used)
	update_actions()


## One player, with everything.
func set_one_player() -> void:
	set_devices([{ keys = "all", pad = ANY_PAD }])


func set_two_sticks(on: bool) -> void:
	two_sticks = on
	update_actions()


## The sticks that work an action, each [which stick axis, which way]. The right stick always turns
## too, so a joypad with two sticks can turn with either in "Simple".
func pad_sticks(a: String) -> Array:
	match a:
		"walk_forward": return [[JOY_AXIS_LEFT_Y, -1.0]]
		"walk_back": return [[JOY_AXIS_LEFT_Y, 1.0]]
		"turn_left": return [[JOY_AXIS_RIGHT_X, -1.0]] + ([] if two_sticks else [[JOY_AXIS_LEFT_X, -1.0]])
		"turn_right": return [[JOY_AXIS_RIGHT_X, 1.0]] + ([] if two_sticks else [[JOY_AXIS_LEFT_X, 1.0]])
		"step_left": return [[JOY_AXIS_LEFT_X, -1.0]] if two_sticks else []
		"step_right": return [[JOY_AXIS_LEFT_X, 1.0]] if two_sticks else []
		"attack": return [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]
	return []


## Sets each player's actions to their keys and joypad.
func update_actions() -> void:
	for i in 2:
		for a in PLAYER_ACTIONS:
			var name := action(a, i)
			InputMap.action_erase_events(name)
			if keys[i] != "":
				for key in KEYS[keys[i]].get(a, []): # (stepping sideways is joypad only)
					var e := InputEventKey.new()
					e.physical_keycode = key
					InputMap.action_add_event(name, e)
			if pads[i] != NO_PAD:
				for button_index in PAD[a]:
					var e := InputEventJoypadButton.new()
					e.button_index = button_index
					e.device = pads[i]
					InputMap.action_add_event(name, e)
				for stick in pad_sticks(a):
					var m := InputEventJoypadMotion.new()
					m.axis = stick[0]
					m.axis_value = stick[1]
					m.device = pads[i]
					InputMap.action_add_event(name, m)


## An action that's the same for everyone (any key or joypad). axis: [which stick axis, which way],
## if a stick works it too.
func add_action(action_name: String, key_list: Array, buttons: Array, axis := []) -> void:
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
	if axis:
		var m := InputEventJoypadMotion.new()
		m.axis = axis[0]
		m.axis_value = axis[1]
		m.device = ANY_PAD
		InputMap.action_add_event(action_name, m)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for i in players:
			if keys[i] != "":
				using_joypad[i] = false
	elif event is InputEventJoypadButton and event.pressed:
		for i in players:
			if pads[i] == ANY_PAD or pads[i] == event.device:
				using_joypad[i] = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		for i in players:
			if pads[i] == ANY_PAD or pads[i] == event.device:
				using_joypad[i] = true


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
