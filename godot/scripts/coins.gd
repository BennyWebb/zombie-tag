class_name Coins
extends Node3D
## Spinning Tag Bux coins that burst out of popped zombies; walk over them to collect them
## (src/coins.js). Close by, they fly to you, and once every zombie is popped they all do.

var coin_scene: PackedScene = load("res://models/coin.glb")
var list: Array = [] # each coin: { node, vel, value, age, landed }


## Scatters enough coins to add up to `value` Tag Bux.
func burst(pos: Vector3, value: int) -> void:
	var coin_value: int = Data.config.tagBux.coinValue
	var count := maxi(1, roundi(float(value) / coin_value))
	for i in count:
		var spinner := Node3D.new() # spins round; the coin inside stands on its edge
		var coin: Node3D = coin_scene.instantiate()
		coin.rotation.x = PI / 2
		spinner.add_child(coin)
		Data.remove_extra_shadows(coin)
		spinner.position = pos
		spinner.rotation.y = randf() * TAU
		add_child(spinner)
		var a := TAU * i / count + randf() * 0.5
		var s := randf_range(1.5, 3.0)
		list.append({
			node = spinner,
			vel = Vector3(cos(a) * s, randf_range(4, 6), sin(a) * s),
			value = value if count == 1 else coin_value,
			age = 0.0,
			landed = false,
		})


## How many Tag Bux are still lying about (or flying to you).
func total() -> int:
	var sum := 0
	for c in list:
		sum += c.value
	return sum


func clear() -> void:
	for c in list:
		c.node.queue_free()
	list.clear()


## Moves the coins and gives them to whoever touches them first. pull_all: every coin flies to
## the nearest hero (once the level is cleared). Returns how many Tag Bux each hero got this frame,
## as [[hero, value], ...].
func update(delta: float, heroes: Array, level: Level, pull_all: bool) -> Array:
	var t: Dictionary = Data.config.tagBux
	var collected := []
	for i in range(list.size() - 1, -1, -1):
		var c: Dictionary = list[i]
		var pos: Vector3 = c.node.position
		c.age += delta
		c.node.rotate_y(delta * 4)

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
		c.node.position = pos

		if nearest and ready and Vector2(nearest.position.x - pos.x, nearest.position.z - pos.z).length() < nearest.radius + t.pickupDistance:
			collected.append([nearest, c.value])
			c.node.queue_free()
			list.remove_at(i)
	return collected
