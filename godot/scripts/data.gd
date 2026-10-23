extends Node
## The game's numbers and notes about the models, exported from the browser game (see README.md).
## It's an autoload, so any script can use it as Data, e.g. Data.config.player.baseSpeed.

var config: Dictionary # data/config.json: everything in the browser game's src/config.js
var models: Dictionary # data/models.json: part names, recolourable materials, hidden parts


# (loaded straight away, rather than in _ready, so other scripts' variables can use it as they're
# made)
func _init() -> void:
	config = load_json("res://data/config.json")
	models = load_json("res://data/models.json")


func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Couldn't read " + path)
	return parsed


## A colour from the JSON files, where they're numbers like 16731019 (0xff4f8b).
static func colour(c) -> Color:
	return Color.hex((int(c) << 8) | 0xff)


## A level's settings from config.json plus its layout from data/levels/ (number starts at 1).
func level(number: int) -> Dictionary:
	var settings: Dictionary = config.levels[number - 1].duplicate()
	var layout := load_json("res://data/levels/%02d-%s.json" % [number, settings.theme])
	settings.merge(layout)
	return settings


## Hides the parts of a model that start hidden in the game (a .glb can't say that itself).
func hide_parts(model: Node, key: String) -> void:
	for part_name in models.models[key].get("hidden", []):
		var part := model.find_child(part_name, true, false)
		if part:
			part.visible = false


## Turns off the shadows of things that have none in the game, like clouds and the gate's beam.
## The export marks them with noShadow in their extras.
func remove_extra_shadows(node: Node) -> void:
	if node is GeometryInstance3D and node.get_meta("extras", {}).get("noShadow", false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		remove_extra_shadows(child)


## Every mesh in a model whose material has this name (like "skin"), with the surface it's on.
func find_material_uses(model: Node, material_name: String) -> Array:
	var found := []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name == material_name:
				found.append([node, i])
	return found


## Gives a model its own copy of a named material (so it can be recoloured or flash on its own)
## and returns that copy.
func own_material(model: Node, material_name: String) -> StandardMaterial3D:
	var uses := find_material_uses(model, material_name)
	if uses.is_empty():
		return null
	var copy: StandardMaterial3D = uses[0][0].mesh.surface_get_material(uses[0][1]).duplicate()
	for use in uses:
		use[0].set_surface_override_material(use[1], copy)
	return copy
