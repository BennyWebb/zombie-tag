extends Node
## Sound effects and music, recorded from the browser game (sounds/sfx and sounds/music).
## It's an autoload, so any script can call Sound.play("pop") or Sound.music("park").

const VOICES := 12 # how many sound effects can play at once

var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music_player := AudioStreamPlayer.new()
var streams := {} # sound name -> AudioStream, loaded the first time it's played
var song := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the music keeps going while the game is paused
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	add_child(music_player)
	# the browser game's volume settings go from 0 to 10
	set_volumes(Data.config.sound.music, Data.config.sound.sounds)
	# load every sound now, so the first pop or bonk doesn't wait while one loads
	for file in ResourceLoader.list_directory("res://sounds/sfx"):
		if file.ends_with(".wav"):
			streams[file.get_basename()] = load("res://sounds/sfx/" + file)


func set_volumes(music_volume: float, sounds_volume: float) -> void:
	music_player.volume_db = linear_to_db(music_volume / 10.0)
	for p in players:
		p.volume_db = linear_to_db(sounds_volume / 10.0)


## Plays a sound effect. pitch: 1 is normal, higher is squeakier (and a little shorter).
func play(sound: String, pitch := 1.0) -> void:
	if not streams.has(sound):
		streams[sound] = load("res://sounds/sfx/%s.wav" % sound)
	# use the voices in turn, so a new sound only cuts off the oldest one
	var p := players[next_player]
	next_player = (next_player + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = pitch
	p.play()


## Switches to a tune (the level's theme, or "title" or "party"). Each one loops by itself.
func music(id: String) -> void:
	if id == song:
		return
	song = id
	music_player.stream = load("res://sounds/music/%s.wav" % id)
	music_player.play()
