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
	settings.number = number # (a whole number: numbers read from JSON files are decimals)
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


## Joins up the parts of a model that never move into as few meshes as possible: one for each
## look (colour, shine, glow...), since drawing each mesh costs the processor time, however small it
## is. Parts under `keep` (things that move, spin or get hidden) and hidden parts stay as they are.
## The joined-up parts keep their nodes, with no mesh, so anything inside them stays too.
func merge_meshes(model: Node3D, keep: Array) -> void:
	var groups := {} # [the look, whether it casts a shadow, the mesh's layout] -> [SurfaceTool, material]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = node
		if m.mesh == null or keep.any(func(k): return k and (k == m or k.is_ancestor_of(m))):
			continue
		# where it is in the model (and whether it's hidden), from its own place in each part it's in
		var place := Transform3D.IDENTITY
		var shown := true
		var part: Node = m
		while part != model:
			place = part.transform * place
			shown = shown and part.visible
			part = part.get_parent()
		if not shown:
			continue
		if range(m.mesh.get_surface_count()).any(func(i): return m.mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES):
			continue # (something unusual: left as it is)
		for i in m.mesh.get_surface_count():
			var material := m.get_active_material(i)
			var key := [look(material), m.cast_shadow, m.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_INDEX - 1]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = [st, material]
			groups[key][0].append_from(m.mesh, i, place)
		m.mesh = null
	var by_shadow := {} # one mesh for the parts with shadows, and one for the ones without
	for key in groups:
		if not by_shadow.has(key[1]):
			var joined := MeshInstance3D.new()
			joined.name = "joined"
			joined.mesh = ArrayMesh.new()
			joined.cast_shadow = key[1]
			model.add_child(joined)
			by_shadow[key[1]] = joined
		var mesh: ArrayMesh = by_shadow[key[1]].mesh
		groups[key][0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, groups[key][1])


## What a material looks like, as a list of its settings, so two materials that look the same (but
## are separate copies) can share a mesh.
static func look(material: Material) -> Array:
	if not material is BaseMaterial3D:
		return [material]
	var settings := []
	for p in material.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and not p.name.begins_with("resource_") and p.name != "script":
			settings.append(material.get(p.name))
	return settings


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
