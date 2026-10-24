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
## Each joypad remembers its own, so a two-stick joypad and a tiny one can play together.
##
## The menus have their own actions ("menu_up", "menu_go" and so on) that anyone's keys or joypad
## work, and each player has "nav_up" and so on for her own menus (the shop, gym and character
## creator). Menus ask nav() whether to move: a key or d-pad press, or a push of a stick. A stick
## counts as pushed once it's well over, and not again until it's back near the middle (an analogue
## stick wobbles as it moves, which would otherwise count as many pushes); held over, it repeats.

const DEADZONE := 0.2 # joypad sticks ignore tiny wobbles below this
const PLAYER_ACTIONS := ["walk_forward", "walk_back", "turn_left", "turn_right", "step_left", "step_right", "attack",
	"nav_up", "nav_down", "nav_left", "nav_right", "leave"]
# the menu moves use the same keys as walking and turning
const NAV_KEYS := { nav_up = "walk_forward", nav_down = "walk_back", nav_left = "turn_left", nav_right = "turn_right" }
const STICK_PUSHED := 0.6 # a stick counts as pushed past this...
const STICK_BACK := 0.3 # ...and as let go again below this
const STICK_REPEAT := [0.45, 0.15] # held over: the first repeat, and the ones after (seconds)
# the keys for each action: the whole keyboard, or each half when two players share it
const KEYS := {
	all = {
		walk_forward = [KEY_W, KEY_UP], walk_back = [KEY_S, KEY_DOWN], turn_left = [KEY_A, KEY_LEFT],
		turn_right = [KEY_D, KEY_RIGHT], attack = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		leave = [KEY_BACKSPACE, KEY_Q],
	},
	left = {
		walk_forward = [KEY_W], walk_back = [KEY_S], turn_left = [KEY_A], turn_right = [KEY_D],
		attack = [KEY_SPACE, KEY_SHIFT], leave = [KEY_Q],
	},
	right = {
		walk_forward = [KEY_UP], walk_back = [KEY_DOWN], turn_left = [KEY_LEFT], turn_right = [KEY_RIGHT],
		attack = [KEY_ENTER, KEY_KP_ENTER], leave = [KEY_BACKSPACE],
	},
}
# the joypad buttons for each action (the sticks are in pad_sticks); any face button (A B X Y, or
# cross circle square triangle) or the right trigger bonks
const PAD := {
	walk_forward = [JOY_BUTTON_DPAD_UP], walk_back = [JOY_BUTTON_DPAD_DOWN],
	turn_left = [JOY_BUTTON_DPAD_LEFT], turn_right = [JOY_BUTTON_DPAD_RIGHT],
	step_left = [], step_right = [],
	nav_up = [JOY_BUTTON_DPAD_UP], nav_down = [JOY_BUTTON_DPAD_DOWN],
	nav_left = [JOY_BUTTON_DPAD_LEFT], nav_right = [JOY_BUTTON_DPAD_RIGHT],
	attack = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y],
	# leaving the shop or gym: the right-hand button (B on an Xbox pad, A on a Nintendo-style one;
	# Godot names the buttons by where they are). In the game it still bonks, like the others.
	leave = [JOY_BUTTON_B],
}
const ANY_PAD := -1
const NO_PAD := -2

var players := 1
var pads := [ANY_PAD, NO_PAD] # each player's joypad (a device number), ANY_PAD or NO_PAD
var keys := ["all", ""] # each player's keys: "all", "left", "right" or "" for none
var using_joypad := [false, false] # whether each player last used a joypad (they turn a bit slower)
var pad_modes := {} # the joypads set to "Two sticks": { joypad's id: true } (save.gd keeps it)
var last_pad := -1 # the joypad that last pressed something (the pause menu's setting is for it)
var stick_at := {} # where each joypad's left stick is: { device: Vector2 }
var sticks := {} # each joypad's left stick, for the menus: { device: { "up": [held, time to repeat], ... } }
var stick_pushes := {} # this frame's pushes: { device: ["up", ...] }
var pictures := {} # the buttons' pictures, made the first time each is needed (see glyph)
var pads_sending_b := {} # the joypads that have sent a B (the right-hand button), see sends_b


func _ready() -> void:
	for i in 2:
		for a in PLAYER_ACTIONS:
			InputMap.add_action(action(a, i), DEADZONE)
	update_actions()
	add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	# for checking speed: shows the frame rate (Back / View / Select on a joypad)
	add_action("show_speed", [KEY_F3], [JOY_BUTTON_BACK])
	# (the sticks move round the menus too, in nav)
	add_action("menu_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	add_action("menu_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	add_action("menu_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	add_action("menu_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
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


## A joypad's id, the same each time it's plugged in (its number can change).
static func pad_id(device: int) -> String:
	if device not in Input.get_connected_joypads():
		return "joypad %d" % device # (not plugged in just now)
	var guid := Input.get_joy_guid(device)
	return guid if guid != "" else Input.get_joy_name(device)


func two_sticks(device: int) -> bool:
	return device >= 0 and pad_modes.get(pad_id(device), false)


func set_two_sticks(device: int, on: bool) -> void:
	if on:
		pad_modes[pad_id(device)] = true
	else:
		pad_modes.erase(pad_id(device))
	update_actions()


## The sticks that work an action, each [which stick axis, which way]. The right stick always turns
## too, so a joypad with two sticks can turn with either in "Simple". both: "Two sticks".
func pad_sticks(a: String, both: bool) -> Array:
	match a:
		"walk_forward": return [[JOY_AXIS_LEFT_Y, -1.0]]
		"walk_back": return [[JOY_AXIS_LEFT_Y, 1.0]]
		"turn_left": return [[JOY_AXIS_RIGHT_X, -1.0]] + ([] if both else [[JOY_AXIS_LEFT_X, -1.0]])
		"turn_right": return [[JOY_AXIS_RIGHT_X, 1.0]] + ([] if both else [[JOY_AXIS_LEFT_X, 1.0]])
		"step_left": return [[JOY_AXIS_LEFT_X, -1.0]] if both else []
		"step_right": return [[JOY_AXIS_LEFT_X, 1.0]] if both else []
		"attack": return [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]
	return []


## A little picture of a joypad's four face buttons in a diamond, with some lit up: "go" (all
## four: any of them does it) or "leave" (the right-hand one, which is B on an Xbox pad but A on a
## Nintendo-style one, so a picture of where it is says it better than a letter).
func glyph(kind: String) -> ImageTexture:
	if pictures.has(kind):
		return pictures[kind]
	const SIZE := 72
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var lit := Color("ffe066")
	var dim := Color(1, 1, 1, 0.35)
	var ring := Color("4b1e8a")
	# top, right, bottom, left
	var centres := [Vector2(36, 15), Vector2(57, 36), Vector2(36, 57), Vector2(15, 36)]
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var colour := Color(0, 0, 0, 0)
			for i in centres.size():
				# each button: a purple ring round it, filled yellow (lit) or see-through white
				var on := kind == "go" or i == 1
				var d: float = p.distance_to(centres[i])
				var edge := clampf(14.5 - d, 0, 1)
				if edge > 0:
					var inside := clampf(11.5 - d, 0, 1)
					colour = Color(ring, 0.9).lerp(lit, inside) if on or inside < 1 else dim
					colour.a *= edge
			img.set_pixel(x, y, colour)
	pictures[kind] = ImageTexture.create_from_image(img)
	return pictures[kind]


## Sets each player's actions to their keys and joypad.
func update_actions() -> void:
	for i in 2:
		for a in PLAYER_ACTIONS:
			var name := action(a, i)
			InputMap.action_erase_events(name)
			if keys[i] != "":
				for key in KEYS[keys[i]].get(NAV_KEYS.get(a, a), []): # (stepping sideways is joypad only)
					var e := InputEventKey.new()
					e.physical_keycode = key
					InputMap.action_add_event(name, e)
			if pads[i] != NO_PAD:
				for button_index in PAD[a]:
					var e := InputEventJoypadButton.new()
					e.button_index = button_index
					e.device = pads[i]
					InputMap.action_add_event(name, e)
				# each joypad's sticks the way it's set ("any joypad" lists them all, as they can differ)
				var devices: Array = [pads[i]] if pads[i] != ANY_PAD else Input.get_connected_joypads()
				for device in devices if devices else [ANY_PAD]:
					for stick in pad_sticks(a, two_sticks(device)):
						var m := InputEventJoypadMotion.new()
						m.axis = stick[0]
						m.axis_value = stick[1]
						m.device = device
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


## Whether to move in a menu this frame: "up", "down", "left" or "right". player: whose menu
## (her keys, d-pad and stick), or -1 for anyone's.
func nav(direction: String, player := -1) -> bool:
	if player < 0:
		return Input.is_action_just_pressed("menu_" + direction) or stick_pushed(direction, ANY_PAD)
	return Input.is_action_just_pressed(action("nav_" + direction, player)) or stick_pushed(direction, pads[player])


## Whether a joypad's left stick was pushed this way this frame. pad: a joypad, ANY_PAD or NO_PAD.
func stick_pushed(direction: String, pad: int) -> bool:
	if pad == NO_PAD:
		return false
	for device in stick_pushes:
		if (pad == ANY_PAD or pad == device) and direction in stick_pushes[device]:
			return true
	return false


# The sticks are read once a frame, before the menus look (autoloads come first).
func _process(delta: float) -> void:
	stick_pushes.clear()
	for device in stick_at:
		var at: Vector2 = stick_at[device]
		var amounts := { up = -at.y, down = at.y, left = -at.x, right = at.x }
		if not sticks.has(device):
			sticks[device] = {}
		for direction in amounts:
			var state: Array = sticks[device].get(direction, [false, 0.0])
			var amount: float = amounts[direction]
			var pushed := false
			if not state[0] and amount > STICK_PUSHED:
				state = [true, STICK_REPEAT[0]]
				pushed = true
			elif state[0] and amount < STICK_BACK:
				state = [false, 0.0]
			elif state[0]:
				state[1] -= delta
				if state[1] <= 0:
					state[1] = STICK_REPEAT[1]
					pushed = true
			sticks[device][direction] = state
			if pushed:
				if not stick_pushes.has(device):
					stick_pushes[device] = []
				stick_pushes[device].append(direction)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for i in players:
			if keys[i] != "":
				using_joypad[i] = false
	elif event is InputEventJoypadButton and event.pressed:
		last_pad = event.device
		if event.button_index == JOY_BUTTON_B:
			pads_sending_b[event.device] = true
		for i in players:
			if pads[i] == ANY_PAD or pads[i] == event.device:
				using_joypad[i] = true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var at: Vector2 = stick_at.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_LEFT_X:
			at.x = event.axis_value
		else:
			at.y = event.axis_value
		stick_at[event.device] = at
	if event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		last_pad = event.device
		for i in players:
			if pads[i] == ANY_PAD or pads[i] == event.device:
				using_joypad[i] = true


## Whether a player's joypad sends B for its right-hand button. Some joypads on Android send
## "go back" instead, which main.gd then turns into her leave button.
func sends_b(player: int) -> bool:
	if pads[player] == ANY_PAD:
		return not pads_sending_b.is_empty()
	return pads_sending_b.has(pads[player])


## A joypad was plugged in or taken out. If Player 1's goes, any joypad works her again, or with
## two players, the next one plugged in that isn't Player 2's. (Player 2 keeps hers, in case it
## comes back.)
func joypad_plugged(device: int, connected: bool) -> void:
	if not connected and pads[0] == device:
		pads[0] = ANY_PAD if players == 1 else NO_PAD
	elif connected and players == 2 and pads[0] == NO_PAD and device != pads[1]:
		pads[0] = device
	if not connected and last_pad == device:
		last_pad = -1
	update_actions() # (a joypad's sticks are set up for it as it arrives)
