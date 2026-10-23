class_name Shots
extends Node3D
## Everything that flies: squirts, goo, bubbles, snowballs, pumpkins and the boomerang banana
## (the Shots class in src/weapons.js).

var looks := {} # shot name -> PackedScene, from models/shots
var list: Array = [] # each shot: { node, vel, weapon, by, travelled, hit (zombies it's hit), returning }


func _init() -> void:
	for shot in ["water", "slime", "bubble", "snowball", "banana", "pumpkin"]:
		looks[shot] = load("res://models/shots/%s.glb" % shot)


## A shot leaves `from` along `dir`. target: a point to aim at, so a pumpkin can be thrown up just
## enough to land on it (or null to go as far as it can).
func fire(from: Vector3, dir: Vector3, weapon: Dictionary, by: Hero, target = null) -> void:
	var node: Node3D = looks[weapon.shot].instantiate()
	Data.remove_extra_shadows(node)
	node.position = from
	add_child(node)
	var vel: Vector3 = dir * weapon.shotSpeed
	if weapon.has("gravity"):
		# throw it up enough to land on the target (or at the end of its range)
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		var dist: float = Vector2(target.x - from.x, target.z - from.z).length() if target != null else weapon.range
		var t: float = dist / weapon.shotSpeed
		var dy: float = (target.y if target != null else 0.3) - from.y
		vel = flat * weapon.shotSpeed
		vel.y = (dy + 0.5 * weapon.gravity * t * t) / t
	if weapon.shot == "water":
		# a stretched drop, pointing the way it's going
		node.look_at_from_position(from, from + dir)
		node.scale = Vector3(1, 1, 1.8)
	var shot := { node = node, vel = vel, weapon = weapon, by = by, travelled = 0.0, hit = [], returning = false }
	if weapon.kind == "throw":
		by.thrown = shot
	list.append(shot)


func clear() -> void:
	for s in list:
		s.node.queue_free()
		if is_same(s.by.thrown, s):
			s.by.thrown = null
	list.clear()


## Moves every shot. Returns the hits this frame, each { zombie, weapon, by, push, at }, or for a
## pumpkin landing { splat = true, weapon, by, at } as well as a hit for each zombie it splats.
func update(delta: float, zombies: Array) -> Array:
	var hits := []
	for i in range(list.size() - 1, -1, -1):
		var s: Dictionary = list[i]
		var w: Dictionary = s.weapon
		var node: Node3D = s.node
		var done := false

		if w.kind == "throw":
			# the banana spins out, then turns round and flies back to whoever threw it
			node.rotate_y(delta * 18)
			if s.returning:
				var back := Vector3(s.by.position.x, 1.2, s.by.position.z) - node.position
				if back.length() < 0.8:
					done = true
				s.vel = back.normalized() * w.shotSpeed * 1.1
			elif s.travelled > w.range:
				s.returning = true
				s.hit.clear() # it can hit the same zombies again on the way back
		if w.has("gravity"):
			s.vel.y -= w.gravity * delta
		node.position += s.vel * delta
		s.travelled += s.vel.length() * delta
		var p := node.position
		if w.shot == "bubble":
			node.scale = Vector3.ONE * (1 + sin(s.travelled * 3) * 0.08)
		elif w.shot == "pumpkin":
			node.rotate_x(delta * 5)

		var hit: Zombie = null
		for z in zombies:
			if not z.alive or z in s.hit:
				continue
			if p.y < maxf(2.5, 2.2 * z.type.size + z.lift) and Vector2(p.x - z.position.x, p.z - z.position.z).length() < z.radius + 0.3:
				hit = z
				break
		var push := Vector3(s.vel.x, 0, s.vel.z).normalized()
		if w.has("splashRadius") and (hit or p.y < 0.2):
			# the pumpkin splats every zombie close by
			for z in zombies:
				if z.alive and Vector2(p.x - z.position.x, p.z - z.position.z).length() < w.splashRadius + z.radius:
					var away := Vector3(z.position.x - p.x, 0, z.position.z - p.z).normalized()
					hits.append({ zombie = z, weapon = w, by = s.by, push = away, at = null })
			hits.append({ splat = true, weapon = w, by = s.by, at = Vector3(p.x, maxf(0.3, p.y), p.z) })
			done = true
		elif hit:
			hits.append({ zombie = hit, weapon = w, by = s.by, push = push, at = p })
			if w.kind == "throw":
				s.hit.append(hit) # the banana keeps going
			else:
				done = true
		if w.kind != "throw" and (s.travelled > w.range + 4 or p.y < 0):
			done = true
		if done:
			node.queue_free()
			list.remove_at(i)
			if is_same(s.by.thrown, s):
				s.by.thrown = null
	return hits
