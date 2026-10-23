extends Node3D
## Runs a level (like src/main.js): zombies arrive a few at a time, bonking them pops them into
## confetti, and once they're all popped the exit gate opens. Walk through it to finish.
##
## Phase 1 is Sunny Park with one hero. Coins, hearts, the shop and gym, the other weapons, two
## players, the other levels and the menus come in the later phases (see the plan in README.md).

const START_LEVEL := 1

var level: Level
var hero: Hero
var effects := Effects.new()
var hud := Hud.new()
var zombies: Array[Zombie] = []
var zombie_holder := Node3D.new() # all the zombies go in here
var to_spawn := 0 # zombies still to arrive this level
var popped := 0
var finished := false
var paused := false


func _ready() -> void:
	add_child(effects)
	add_child(hud)
	zombie_holder.name = "Zombies"
	add_child(zombie_holder)
	start_level(START_LEVEL)


func start_level(number: int) -> void:
	if level:
		level.queue_free()
		hero.queue_free()
	for z in zombies:
		z.queue_free()
	zombies.clear()
	level = Level.new(number)
	add_child(level)
	hero = Hero.new(level)
	hero.bonked.connect(hit_zombie)
	add_child(hero)
	hero.start_at(level.info.playerStart)
	hero.camera.make_current()
	effects.warm_up(hero.camera, [level.gate.find_child("open", true, false)])
	to_spawn = int(level.info.zombies)
	popped = 0
	finished = false
	Sound.music(level.info.theme)
	hud.say("Level %d: %s\nPop all the zombies, then find the exit gate!" % [number, level.info.name], 4)


# The TV remote's Back button (Android's "go back") pauses too, instead of closing the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()


func toggle_pause() -> void:
	paused = not paused
	hud.say("Paused" if paused else "", 9999 if paused else 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func _process(delta: float) -> void:
	if paused:
		return

	var alive := zombies.filter(func(z): return z.alive)
	if to_spawn > 0 and alive.size() <= Data.config.arena.nextWaveWhenLeft:
		spawn_wave()
	hero.update(delta, zombies)
	for z in zombies:
		z.update(delta, [hero], zombies)

	# every zombie popped: the exit gate opens, and walking through it finishes the level
	var cleared := to_spawn == 0 and alive.is_empty()
	if cleared and not level.gate_open:
		level.open_gate()
		Sound.play("gate")
		hud.say("All the zombies are popped!\nWalk through the glowing exit gate", 4)
	if level.at_gate(hero.position) and not finished:
		finished = true
		Sound.play("fanfare")
		hud.say("Level done!", 3)
		get_tree().create_timer(3.0).timeout.connect(func(): start_level(level.info.number))
	hud.show_zombies_left(to_spawn + alive.size(), level.gate_open)


## A few zombies arrive, away from the hero.
func spawn_wave() -> void:
	for i in mini(Data.config.arena.waveSize, to_spawn):
		var kind := pick_kind()
		var spot = spawn_spot(Data.config.zombies[kind].radius + 0.5)
		if spot == null:
			break
		var z := Zombie.new(kind, level, level.info.healthMultiplier, spot.x, spot.y)
		zombie_holder.add_child(z)
		zombies.append(z)
		to_spawn -= 1


## Picks a kind of zombie for this level, more often the ones with a bigger number in its mix.
func pick_kind() -> String:
	var mix: Dictionary = level.info.mix
	var roll: float = randf() * mix.values().reduce(func(a, b): return a + b, 0.0)
	for kind in mix:
		roll -= mix[kind]
		if roll < 0:
			return kind
	return mix.keys()[0]


## A clear spot at least spawnAway from the hero, as a Vector2 (x, z), or null if there isn't one.
func spawn_spot(radius: float):
	var a: Dictionary = Data.config.arena
	for tries in 100:
		var x: float = randf_range(-0.5, 0.5) * (a.size - 6)
		var z: float = randf_range(-0.5, 0.5) * (a.size - 6)
		if Vector2(x - hero.position.x, z - hero.position.z).length() < a.spawnAway:
			continue
		if level.is_clear(x, z, radius):
			return Vector2(x, z)
	return null


func hit_zombie(zombie: Zombie, weapon: Dictionary, push: Vector3) -> void:
	if not zombie.alive:
		return
	if weapon.has("knockback"):
		zombie.knock(push, weapon.knockback)
	Sound.play("bonk", randf_range(0.9, 1.15)) # a little different every time, so it's not robotic
	if zombie.hit(weapon.damage * hero.damage_multiplier()):
		pop_zombie(zombie)
	else:
		effects.float_text(zombie.centre() + Vector3(0, 0.8, 0), "BONK!", Color("ffe066"), 1.1)


func pop_zombie(zombie: Zombie) -> void:
	var size: float = zombie.type.size
	effects.confetti(zombie.centre())
	effects.float_text(zombie.centre() + Vector3(0, size, 0), "POP!", Color("9cff57"), 1.4 * size)
	Sound.play("pop", randf_range(0.95, 1.15) / size)
	zombies.erase(zombie)
	zombie.queue_free()
	popped += 1
