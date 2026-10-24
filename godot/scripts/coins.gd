class_name Coins
extends Node3D
## Spinning Tag Bux coins that burst out of popped zombies; walk over them to collect them
## (src/coins.js). Close by, they fly to you, and once every zombie is popped they all do.
## All the coins are drawn together, as one "MultiMesh": a list of where each one is, drawn in one
## go, which is much quicker than a node for every coin (a popped zombie can drop 25).

const STAND_UP := Basis(Vector3.RIGHT, PI / 2) # the coin model lies flat; coins stand on their edge

var coin_scene: PackedScene = load("res://models/coin.glb")
var list: Array = [] # each coin: { pos, spin, vel, value, age, landed }
var drawers: Array[MultiMeshInstance3D] = [] # (one, or two if some of the coin casts no shadow)
var warm_at := Vector3.ZERO # see warm_up
var warm_frames := 0


func _ready() -> void:
	var model: Node3D = coin_scene.instantiate()
	Data.remove_extra_shadows(model)
	Data.merge_meshes(model, [])
	for joined in model.get_children():
		if joined.name.begins_with("joined"):
			var drawer := MultiMeshInstance3D.new()
			drawer.multimesh = MultiMesh.new()
			drawer.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			drawer.multimesh.mesh = joined.mesh
			drawer.multimesh.instance_count = 128 # (room for plenty, so it never has to grow mid-fight)
			drawer.cast_shadow = joined.cast_shadow
			add_child(drawer)
			drawers.append(drawer)
	model.free()


## The first time the coins are drawn takes the graphics chip a moment to get ready for, which
## made the first zombie pop stutter. (A copy drawn instead didn't help: it has to be these.) So at
## the start of a level, one coin too small to see is drawn here for a few frames.
func warm_up(at: Vector3) -> void:
	warm_at = at
	warm_frames = 10
	draw()


## Scatters enough coins to add up to `value` Tag Bux.
func burst(pos: Vector3, value: int) -> void:
	var coin_value: int = Data.config.tagBux.coinValue
	var count := maxi(1, roundi(float(value) / coin_value))
	for i in count:
		var a := TAU * i / count + randf() * 0.5
		var s := randf_range(1.5, 3.0)
		list.append({
			pos = pos,
			spin = randf() * TAU,
			vel = Vector3(cos(a) * s, randf_range(4, 6), sin(a) * s),
			value = value if count == 1 else coin_value,
			age = 0.0,
			landed = false,
		})
	draw()


## How many Tag Bux are still lying about (or flying to you).
func total() -> int:
	var sum := 0
	for c in list:
		sum += c.value
	return sum


func clear() -> void:
	list.clear()
	draw()


## Tells the MultiMesh where every coin is now.
func draw() -> void:
	for drawer in drawers:
		var mm := drawer.multimesh
		if mm.instance_count < list.size():
			mm.instance_count = list.size() + 32 # (room for a few more)
		mm.visible_instance_count = list.size()
		for i in list.size():
			var c: Dictionary = list[i]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, c.spin) * STAND_UP, c.pos))
		if warm_frames > 0 and list.size() < mm.instance_count:
			mm.visible_instance_count += 1
			mm.set_instance_transform(list.size(), Transform3D(STAND_UP.scaled(Vector3.ONE * 0.001), warm_at))
	warm_frames -= 1


## Moves the coins and gives them to whoever touches them first. pull_all: every coin flies to
## the nearest hero (once the level is cleared). Returns how many Tag Bux each hero got this frame,
## as [[hero, value], ...].
func update(delta: float, heroes: Array, level: Level, pull_all: bool) -> Array:
	var t: Dictionary = Data.config.tagBux
	var collected := []
	for i in range(list.size() - 1, -1, -1):
		var c: Dictionary = list[i]
		var pos: Vector3 = c.pos
		c.age += delta
		c.spin += delta * 4

		var nearest = null
		var nearest_dist := INF
		for h in heroes:
			if h.tagged > 0 or h.inside:
				continue
			var d := Vector2(h.position.x - pos.x, h.position.z - pos.z).length()
			if d < nearest_dist:
				nearest = h
				nearest_dist = d

		# it flies out of the zombie for a moment before it can be grabbed
		var ready: bool = c.age > 0.4
		if nearest and ready and (pull_all or nearest_dist < t.magnetDistance):
			var to := Vector3(nearest.position.x - pos.x, 1.0 - pos.y, nearest.position.z - pos.z)
			var step := minf(to.length(), t.magnetSpeed * (1.6 if pull_all else 1.0) * delta)
			pos += to.normalized() * step
			c.vel = Vector3.ZERO
			c.landed = true
		elif not c.landed:
			c.vel.y -= 14 * delta
			pos += c.vel * delta
			pos = level.resolve_collisions(pos, 0.3) # never land in the pond or a tree
			if pos.y < 0.5:
				pos.y = 0.5
				c.vel *= 0.4
				c.vel.y = -c.vel.y if absf(c.vel.y) > 1 else 0.0
				if c.vel.length() < 0.3:
					c.landed = true
		else:
			pos.y = 0.5 + sin(c.age * 3 + i) * 0.08 # a gentle bob
		c.pos = pos

		if nearest and ready and Vector2(nearest.position.x - pos.x, nearest.position.z - pos.z).length() < nearest.radius + t.pickupDistance:
			collected.append([nearest, c.value])
			list.remove_at(i)
	draw()
	return collected
