extends Node
## The game's numbers and notes about the models, exported from the browser game (see README.md).
## It's an autoload, so any script can use it as Data, e.g. Data.config.player.baseSpeed.

var config: Dictionary # data/config.json: everything in the browser game's src/config.js
var models: Dictionary # data/models.json: part names, recolourable materials, hidden parts
var joined_before := {} # meshes already joined up, to use again (see merge_meshes)


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


## Joins up the parts of a model that never move into as few meshes as possible, since drawing each
## mesh costs the processor time, however small it is. Parts with plain colours (no picture on them)
## that are otherwise alike share one material, with each part's colour kept in its corners
## ("vertex colours"), so a whole level of differently coloured things can be drawn in a few goes.
## Parts under `keep` (things that move, spin or get hidden) and hidden parts stay as they are, and
## materials in `changing` (like a zombie's, which flash when bonked) keep their own surfaces.
## The joined-up parts keep their nodes, with no mesh, so anything inside them stays too.
## same_as: models made the same way (like every zombie of a kind) give the same name here, and
## after the first, they use its joined-up meshes, with their own `changing` materials (by name).
func merge_meshes(model: Node3D, keep: Array, changing: Array = [], same_as := "") -> void:
	if same_as != "" and joined_before.has(same_as):
		for m in mergeable(model, keep):
			m.mesh = null
		for made in joined_before[same_as]:
			var joined := MeshInstance3D.new()
			joined.name = "joined"
			joined.mesh = made.mesh
			joined.cast_shadow = made.shadow
			for i in made.changing:
				var own: Array = changing.filter(func(c): return c.resource_name == made.changing[i])
				if own:
					joined.set_surface_override_material(i, own[0])
			model.add_child(joined)
		return
	# [the look, whether it casts a shadow, the mesh's layout] -> [SurfaceTool, material, coloured]
	var groups := {}
	for m in mergeable(model, keep):
		var place := place_in(m, model)
		for i in m.mesh.get_surface_count():
			var material := m.get_active_material(i)
			var layout: int = m.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_INDEX - 1
			var coloured: bool = material not in changing and plain(material) and not layout & Mesh.ARRAY_FORMAT_COLOR
			var key := [[material] if material in changing else look(material, coloured), m.cast_shadow, layout, coloured]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var shared := material
				if coloured:
					shared = material.duplicate()
					shared.albedo_color = Color.WHITE
					shared.vertex_color_use_as_albedo = true
					shared.vertex_color_is_srgb = true # (like the colours picked for materials)
				groups[key] = [st, shared]
			var surface: Mesh = m.mesh
			var at := i
			if coloured:
				# a copy of the surface with its colour in every corner
				var arrays := m.mesh.surface_get_arrays(i)
				var colours := PackedColorArray()
				colours.resize(arrays[Mesh.ARRAY_VERTEX].size())
				colours.fill(material.albedo_color)
				arrays[Mesh.ARRAY_COLOR] = colours
				surface = ArrayMesh.new()
				surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				at = 0
			groups[key][0].append_from(surface, at, place)
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
	if same_as != "":
		# kept for the next one: each mesh, and which of its surfaces have `changing` materials
		joined_before[same_as] = by_shadow.values().map(func(j):
			var names := {}
			for i in j.mesh.get_surface_count():
				if j.mesh.surface_get_material(i) in changing:
					names[i] = j.mesh.surface_get_material(i).resource_name
			return { mesh = j.mesh, shadow = j.cast_shadow, changing = names })


## The meshes in a model that can be joined up: shown, not under `keep`, and made of triangles.
static func mergeable(model: Node3D, keep: Array) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = node
		if m.mesh == null or keep.any(func(k): return k and (k == m or k.is_ancestor_of(m))):
			continue
		var shown := true
		var part: Node = m
		while part != model:
			shown = shown and part.visible
			part = part.get_parent()
		if shown and range(m.mesh.get_surface_count()).all(func(i): return m.mesh.surface_get_primitive_type(i) == Mesh.PRIMITIVE_TRIANGLES):
			found.append(m)
	return found


## Where a part is in a model, from its own place in each part it's in.
static func place_in(part: Node3D, model: Node3D) -> Transform3D:
	var place := Transform3D.IDENTITY
	var n: Node = part
	while n != model:
		place = n.transform * place
		n = n.get_parent()
	return place


## Whether a material is just a colour (no picture on it), so the colour can go in the mesh instead.
static func plain(material: Material) -> bool:
	return material is BaseMaterial3D and material.albedo_texture == null and not material.vertex_color_use_as_albedo


## What a material looks like, as a list of its settings, so two materials that look the same (but
## are separate copies) can share a mesh. without_colour: leaves its colour out.
static func look(material: Material, without_colour := false) -> Array:
	if not material is BaseMaterial3D:
		return [material]
	var settings := []
	for p in material.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and not p.name.begins_with("resource_") and p.name != "script" \
				and not (without_colour and p.name == "albedo_color"):
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
