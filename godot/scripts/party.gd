class_name Party
extends Node3D
## You beat the Zombie King! All the zombies are your friends now, and there's a big party in his
## castle (startParty and updateParty in src/main.js): a ring of zombies in party hats dancing round
## the King, the heroes jumping with their arms in the air, confetti, and a camera going slowly
## round it all.

const KINDS := ["shuffler", "speedySid", "bouncyBob", "bigBertha", "slimeZombie", "smallShuffler"]
const HAT_COLOURS := [0xff4f8b, 0xffd23f, 0x4fc3f7, 0x7dff4f, 0xb28dff]

var level: Level
var heroes: Array
var effects: Effects
var friends: Array[Zombie] = []
var camera := Camera3D.new()
var screen := CanvasLayer.new() # the words on top
var time := 0.0
var hardcore_won := false # (it says your next Hardcore game starts fresh)


func _init(the_level: Level, the_heroes: Array, the_effects: Effects, won_hardcore := false) -> void:
	level = the_level
	heroes = the_heroes
	effects = the_effects
	hardcore_won = won_hardcore


func _ready() -> void:
	for i in 18:
		var a := TAU * i / 18
		var f := Zombie.new(KINDS[i % KINDS.size()], level, 1, cos(a) * 11, sin(a) * 11)
		add_child(f)
		var hat := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = 0.22
		cone.height = 0.5
		var colour := StandardMaterial3D.new()
		colour.albedo_color = Data.colour(HAT_COLOURS[i % HAT_COLOURS.size()])
		cone.material = colour
		hat.mesh = cone
		hat.position.y = 2.35
		f.body.add_child(hat)
		f.yaw = -a - PI / 2
		f.spawn_pop = 1
		friends.append(f)
	var king := Zombie.new("zombieKing", level, 1, 0, -2)
	add_child(king)
	king.spawn_pop = 1
	friends.append(king)
	for i in heroes.size():
		var h: Hero = heroes[i]
		h.start_at({ x = -1.5 + i * 3, z = 7, yaw = 0 })
		h.body.visible = true
		h.hand.visible = false
	camera.fov = 70
	camera.cull_mask = 0xfffff # everything, both heroes' bodies too
	add_child(camera)
	camera.make_current()
	make_screen()


func make_screen() -> void:
	add_child(screen)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 30
	column.offset_bottom = -30
	screen.add_child(column)
	var title := line("You beat the Zombie King!", 80, Color("ffe066"))
	column.add_child(title)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	column.add_child(line("All the zombies are your friends now. 🎉 PARTY TIME! 🎉", 36, Color.WHITE))
	if hardcore_won:
		column.add_child(line("💀 You beat Hardcore! Your next Hardcore game starts fresh from level 1.", 26, Color.WHITE))
	column.add_child(line("Press %s when you've finished partying" % Controls.button(), 36, Color("ffe066")))


static func line(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color("4b1e8a"))
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


func _process(delta: float) -> void:
	time += delta
	var t := time
	for i in friends.size():
		var f := friends[i]
		# jumping, turning this way and that, and waving their arms
		f.model.position.y = absf(sin(t * 5 + i)) * 0.6
		f.rotation.y = f.yaw + sin(t * 2 + i) * 0.8
		f.arms[0].rotation.x = 0.2 + sin(t * 8 + i) * 0.5
		f.arms[1].rotation.x = 0.2 - sin(t * 8 + i) * 0.5
		f.body.rotation.z = sin(t * 4 + i) * 0.2
	for h in heroes:
		# jumping with her arms in the air
		h.body.position.y = absf(sin(t * 6 + h.index)) * 0.5
		h.body.arms[0].rotation.x = PI
		h.body.arms[1].rotation.x = PI
	if randf() < delta * 3:
		var f: Zombie = friends.pick_random()
		effects.confetti(f.centre() + Vector3(0, 2, 0), 40)
		if randf() < 0.4:
			Sound.play("yay", randf_range(0.8, 1.4), 0.5)
	camera.position = Vector3(sin(t * 0.15) * 20, 8, cos(t * 0.15) * 20)
	camera.look_at(Vector3(0, 1.5, 0))


## Back to normal: the heroes' bodies down on the ground again.
func finish() -> void:
	for h in heroes:
		h.body.position.y = 0
		h.hand.visible = true
