extends SceneTree
# Renders the app's icon and TV banner from the game's own models.
var font = load("res://fonts/fredoka_bold.tres")

func view(size: Vector2i, transparent: bool) -> SubViewport:
	var v := SubViewport.new()
	v.size = size
	v.transparent_bg = transparent
	v.own_world_3d = true
	v.msaa_3d = Viewport.MSAA_8X
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR
	env.environment.background_color = Color("6a2fb0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	v.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.7
	sun.rotation = Vector3(-0.5, 0.6, 0)
	v.add_child(sun)
	return v

func zombie(v: SubViewport, kind: String, pos: Vector3, yaw: float, skin: Color, shirt: Color) -> Node3D:
	var z: Node3D = load("res://models/zombies/%s.glb" % kind).instantiate()
	z.position = pos
	z.rotation.y = yaw
	v.add_child(z)
	for n in ["healthBar", "stars", "bubble", "ice", "tongue"]:
		var p = z.find_child(n, true, false)
		if p: p.visible = false
	for m in z.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var mat = m.mesh.surface_get_material(i)
			if mat and mat.resource_name in ["skin", "shirt"]:
				var c: StandardMaterial3D = mat.duplicate()
				c.albedo_color = skin if mat.resource_name == "skin" else shirt
				m.set_surface_override_material(i, c)
	var arm_l = z.find_child("armL", true, false)
	var arm_r = z.find_child("armR", true, false)
	arm_l.rotation.x = PI / 2
	arm_r.rotation.x = PI / 2
	return z

func camera(v: SubViewport, pos: Vector3, look: Vector3, fov: float) -> void:
	var c := Camera3D.new()
	c.fov = fov
	v.add_child(c)
	c.position = pos
	c.look_at(look)
	c.make_current()

func save(v: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	v.get_texture().get_image().save_png(path)

func gradient(size: Vector2i, path: String) -> void:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var d := Vector2(x - size.x * 0.5, y - size.y * 0.35).length() / size.length()
			img.set_pixel(x, y, Color("ff6fae").lerp(Color("4b1e8a"), clampf(d * 1.6, 0, 1)))
	img.save_png(path)

func _init():
	await process_frame
	var out := "res://icons/"
	# the adaptive icon: a background, and a Shuffler waving in the middle (Android crops the
	# corners off as it likes, so he's kept in the middle two thirds)
	gradient(Vector2i(432, 432), out + "icon_background.png")
	var fg := view(Vector2i(432, 432), true)
	zombie(fg, "shuffler", Vector3.ZERO, 0.35, Color("8fd16a"), Color("ff4f8b"))
	camera(fg, Vector3(0, 1.6, 6.4), Vector3(0, 1.2, 0), 30)
	await save(fg, out + "icon_foreground.png")
	# the plain icon (older Androids): the two together
	var bg := Image.load_from_file(out + "icon_background.png")
	var front := Image.load_from_file(out + "icon_foreground.png")
	bg.blend_rect(front, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
	bg.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	bg.save_png(out + "icon.png")
	# the TV banner: zombies, and the name
	var tv := view(Vector2i(640, 360), false)
	tv.get_child(0).environment.background_mode = Environment.BG_CANVAS
	var sky := ColorRect.new()
	camera(tv, Vector3(0, 1.6, 7.5), Vector3(0.0, 1.3, 0), 34)
	zombie(tv, "shuffler", Vector3(-2.6, 0, 0), 0.5, Color("8fd16a"), Color("ff4f8b"))
	zombie(tv, "speedySid", Vector3(2.7, 0, -0.5), -0.5, Color("6fd0e0"), Color("ffffff"))
	zombie(tv, "bouncyBob", Vector3(0, 0, -2.5), 0.0, Color("c8a2ff"), Color("ffd23f"))
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("ff8ac8"), Color("6a2fb0")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	var back := TextureRect.new()
	back.texture = gt
	back.size = Vector2(640, 360)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.z_index = -10
	tv.add_child(back)
	var title := Label.new()
	title.text = "ZOMBIE TAG"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color("ffe066"))
	title.add_theme_color_override("font_outline_color", Color("4b1e8a"))
	title.add_theme_constant_override("outline_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(640, 120)
	title.position = Vector2(0, 230)
	tv.add_child(title)
	await save(tv, out + "banner_big.png")
	var banner := Image.load_from_file(out + "banner_big.png")
	banner.resize(320, 180, Image.INTERPOLATE_LANCZOS)
	banner.save_png(out + "banner.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out + "banner_big.png"))
	quit()
