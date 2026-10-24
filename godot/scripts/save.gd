extends Node
## Saves progress, so the girls can stop and carry on another day (like src/save.js). Every hero has
## her own saved profile: her looks, Tag Bux, weapons, outfits, training and the levels she's
## reached. It's an autoload, so any script can use Save.
##
## The save is a JSON file in Godot's "user://" folder (on the Shield that's the app's own storage).
## It's written at the start of each level, after shopping or training, when you're tagged, when a
## level's done, and when the sound settings change.

const FILE := "user://save.json"
const GRAPHICS_VERSION := 2 # (see read)

var profiles: Array = [] # every saved hero (see Hero.to_save)
var chosen: Array = [] # the profile ids who played as Player 1 and Player 2 last time
var player_count := 1
var difficulty := "easy"
var music := 6 # the volumes, 0 to 10
var sounds := 8
var pad_modes := {} # how each joypad plays (see Controls.pad_modes)
var swap_buttons := false # which button says yes in menus (see Controls.swap_buttons)
# The graphics settings (see Graphics.OPTIONS), a set for each number of players, since more
# players draw the world more times and may need simpler settings.
var graphics := { "1": Graphics.defaults(1), "2": Graphics.defaults(2), "3": Graphics.defaults(3), "4": Graphics.defaults(4) }
# A safety net for the graphics settings: "trying" is saved as true while the game starts and just
# after a setting changes, and false once it's run for a few seconds. If it's still true when the
# game starts, the game stopped (crashed) while trying, so the graphics go back to normal.
var trying := false
var graphics_were_reset := false # (the title screen says so)


func _ready() -> void:
	music = Data.config.sound.music
	sounds = Data.config.sound.sounds
	read()
	Sound.set_volumes(music, sounds)
	Controls.pad_modes = pad_modes
	Controls.set_swap_buttons(swap_buttons)
	Controls.update_actions()
	try_out()


func read() -> void:
	if not FileAccess.file_exists(FILE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not data is Dictionary or data.get("version") != 1:
		return # (a broken save is ignored, rather than stopping the game)
	profiles = data.get("profiles", []).filter(func(d): return d is Dictionary and d.get("id") and d.get("created"))
	chosen = data.get("chosen", [])
	player_count = int(data.get("playerCount", 1))
	if Data.config.difficulties.has(data.get("difficulty")):
		difficulty = data.difficulty
	music = int(data.get("music", music))
	sounds = int(data.get("sounds", sounds))
	var modes = data.get("padModes", {})
	pad_modes = modes if modes is Dictionary else {}
	swap_buttons = data.get("swapButtons", false) == true
	if data.get("trying", false):
		graphics_were_reset = true
		return # (the graphics stay at their usual settings)
	if data.get("graphicsVersion") != GRAPHICS_VERSION:
		return # (settings saved before "Sharpness" changed how it works start at their usual choices)
	for count in graphics:
		# (only settings that still exist, and any new ones at their usual choice)
		var saved: Dictionary = data.get("graphics", {}).get(count, {})
		for key in graphics[count]:
			if saved.has(str(key)) and int(saved[str(key)]) < Graphics.OPTIONS[key].choices.size():
				graphics[count][key] = int(saved[str(key)])
		graphics[count].test = 0 # (the test always starts off)


func write() -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file == null:
		return # can't save here; the game still works
	file.store_string(JSON.stringify({
		version = 1, profiles = profiles, chosen = chosen, playerCount = player_count,
		difficulty = difficulty, music = music, sounds = sounds, padModes = pad_modes, swapButtons = swap_buttons, graphics = graphics,
		trying = trying, graphicsVersion = GRAPHICS_VERSION,
	}, "\t"))


## Puts a hero's profile into the save (a new one, or in place of her old one), then writes it.
func keep(hero: Hero) -> void:
	if not hero.created or hero.profile_id == "":
		return
	var data := hero.to_save()
	var i := profiles.find_custom(func(d): return d.id == hero.profile_id)
	if i >= 0:
		profiles[i] = data
	else:
		profiles.append(data)


func profile(id) -> Dictionary:
	for d in profiles:
		if d.id == id:
			return d
	return {}


func remove(id: String) -> void:
	profiles = profiles.filter(func(d): return d.id != id)
	chosen = chosen.map(func(c): return null if c == id else c)
	write()


func set_volumes(new_music: int, new_sounds: int) -> void:
	music = clampi(new_music, 0, 10)
	sounds = clampi(new_sounds, 0, 10)
	Sound.set_volumes(music, sounds)
	write()


## Starting the game, or a graphics setting just changed: if the game's still going in a few
## seconds, all's well.
func try_out() -> void:
	trying = true
	write()
	get_tree().create_timer(4.0).timeout.connect(all_well)


func all_well() -> void:
	trying = false
	write()


func current_difficulty() -> Dictionary:
	return Data.config.difficulties[difficulty]
