class_name Floaters
extends MeshInstance3D
## Little dots drifting about: snow, sparkles or fireflies (addFloaters in src/themes.js). Each dot
## is a tiny square that turns to face the camera, and they all move in the shader (floaters.gdshader)
## rather than here, so hundreds of them cost the processor nothing.

const SHADER := preload("res://scripts/floaters.gdshader")


## settings: { count, colour, size, area, fall, wander, low, high } from the level's file.
func _init(settings: Dictionary) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var where := PackedVector3Array() # each corner starts at its dot's middle
	var corner := PackedVector2Array() # which corner it is
	var number := PackedVector2Array() # which dot it is (so each moves its own way)
	var area: float = settings.area
	for i in int(settings.count):
		var start := Vector3(randf_range(-0.5, 0.5) * area, randf_range(settings.low, settings.high), randf_range(-0.5, 0.5) * area)
		for c in corners:
			where.append(start)
			corner.append(c)
			number.append(Vector2(i, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = where
	arrays[Mesh.ARRAY_TEX_UV] = corner
	arrays[Mesh.ARRAY_TEX_UV2] = number
	var dots := ArrayMesh.new()
	dots.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# (the dots move, so Godot is told they can be anywhere in the level, or it might skip drawing them)
	dots.custom_aabb = AABB(Vector3(-area, -1, -area), Vector3(area * 2, settings.high + 2, area * 2))
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("colour", Data.colour(settings.colour))
	m.set_shader_parameter("size", settings.size)
	m.set_shader_parameter("fall", settings.fall)
	m.set_shader_parameter("wander", settings.wander)
	m.set_shader_parameter("low", settings.low)
	m.set_shader_parameter("high", settings.high)
	dots.surface_set_material(0, m)
	mesh = dots
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
