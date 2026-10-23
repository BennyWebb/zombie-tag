class_name HeroBody
extends Node3D
## A hero's whole body, with her hair style, colours, outfits and name above her head
## (makeHeroBody in src/hero.js). You only see your own hand, so this is what your sister sees in
## 2-player mode. It walks, swings its arm when she attacks, and her cape flaps.

var look: Dictionary # name, skin, hairStyle, hair, outfit, trousers, tagColour
var model: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var cape: Node3D
var name_tag := Label3D.new()


## layer: the visual layer it's drawn on, so only the other player's camera sees it.
func _init(hero_look: Dictionary, wearing: Array, layer: int) -> void:
	look = hero_look
	model = load("res://models/heroes/hair-%s.glb" % look.hairStyle).instantiate()
	add_child(model)
	Data.remove_extra_shadows(model)
	var head: Node3D = model.find_child("head", true, false)
	var torso: Node3D = model.find_child("torso", true, false)
	for side in ["L", "R"]:
		arms.append(model.find_child("arm" + side, true, false))
		legs.append(model.find_child("leg" + side, true, false))

	# her colours (the clothes change with some outfits)
	var clothes := clothes_colour(look, wearing)
	var covered := "unicornOnesie" in wearing or "astronautSuit" in wearing
	Data.own_material(model, "skin").albedo_color = Data.colour(look.skin)
	Data.own_material(model, "clothes").albedo_color = Data.colour(clothes)
	Data.own_material(model, "trousers").albedo_color = Data.colour(clothes if covered else look.trousers)
	Data.own_material(model, "hair").albedo_color = Data.colour(look.hair)
	if "unicornOnesie" in wearing:
		for use in Data.find_material_uses(model, "hair"):
			use[0].visible = false # the hood covers it

	# each outfit's pieces go on her head, body or back (the outfit files have them in "head",
	# "torso" and the rest straight in the outfit, like the cape)
	for id in wearing:
		var outfit: Node3D = load("res://models/heroes/outfit-%s.glb" % id).instantiate()
		var pieces: Node3D = outfit.get_child(0)
		for group in [["head", head], ["torso", torso]]:
			for piece in pieces.get_node(group[0]).get_children():
				piece.owner = null # (it's leaving the outfit's scene for ours)
				piece.reparent(group[1], false)
		for piece in pieces.get_children():
			if piece.name not in ["head", "torso"]:
				piece.owner = null
				piece.reparent(head.get_parent(), false)
				if piece.name == "cape":
					cape = piece
		outfit.free()
	Data.remove_extra_shadows(model)

	name_tag.text = look.name
	name_tag.font = load("res://fonts/fredoka_bold.tres")
	name_tag.font_size = 64
	name_tag.pixel_size = 0.0035
	name_tag.modulate = Color.WHITE
	name_tag.outline_modulate = Color(look.tagColour)
	name_tag.outline_size = 24
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position.y = 2.45
	add_child(name_tag)

	for node in find_children("*", "VisualInstance3D", true, false):
		node.layers = layer


## The colour of her clothes: her favourite colour, unless an outfit covers her body
## (clothesColour in src/hero.js).
static func clothes_colour(hero_look: Dictionary, wearing: Array) -> int:
	if "unicornOnesie" in wearing:
		return 0xffffff
	if "dancerOutfit" in wearing:
		return 0xd36bff
	if "astronautSuit" in wearing:
		return 0xf2f2f2
	return int(hero_look.outfit)


## Walks and swings like the hero. moved: how fast she's going; attacking: her weapon arm chops
## down.
func animate(walk_phase: float, moved: float, attacking: bool, time: float) -> void:
	var swing := sin(walk_phase) * 0.6 if moved > 0.5 else 0.0
	legs[0].rotation.x = swing
	legs[1].rotation.x = -swing
	arms[0].rotation.x = -swing * 0.7
	arms[1].rotation.x = -1.4 if attacking else swing * 0.7
	if cape:
		cape.rotation.x = -0.12 - minf(0.6, moved * 0.08) - sin(time * 1000 / 150.0) * 0.05
