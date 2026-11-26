extends Node3D
## Kazeta 13 - main scene: builds modules, title menu, gallery, settings and saves.

var house: Node3D
var rects: Array = []
var env: Environment
var moon: DirectionalLight3D
var post: ShaderMaterial
var ui := {}
var f_osd: Font
var f_type: Font
var f_mark: Font
var f_ui: Font
var f_title: Font
var f_title_ui: Font
var world
var game
var uix
var audio
var SET := {"gfx": 1, "fps": false, "vol": 0.85, "sens": 1.0, "bright": 1.0, "diff": 1, "voices": false, "mic": false, "fullscreen": false, "name": ""}
var save_data := {}
var _models := {}
var game_us := 0.0
var lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	randomize()
	f_osd = load("res://fonts/VT323-Regular.ttf")
	f_type = load("res://fonts/SpecialElite-Regular.ttf")
	f_mark = load("res://fonts/PermanentMarker-Regular.ttf")
	f_ui = load("res://fonts/Inter.ttf")
	f_title = load("res://fonts/Creepster-Regular.ttf")
	f_title_ui = load("res://fonts/Anton-Regular.ttf")
	load_settings()
	load_game()
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 20000
	AudioServer.add_bus_effect(0, lowpass)
	audio = load("res://scripts/audio.gd").new()
	audio.M = self
	add_child(audio)
	audio.build()
	_build_env()
	house = Node3D.new()
	add_child(house)
	world = load("res://scripts/world.gd").new()
	world.M = self
	add_child(world)
	house = world
	world.build()
	house = world.G.house
	game = load("res://scripts/game.gd").new()
	game.M = self
	game.W = world
	game.A = audio
	add_child(game)
	uix = load("res://scripts/ui.gd").new()
	uix.M = self
	uix.A = audio
	add_child(uix)
	game.U = uix
	uix.G = game
	_build_post()
	game.build()
	uix.build()
	_build_menu_scene()
	_build_title_layer()
	_build_gallery()
	envs = [env, menu_cam.environment, gal_cam.environment]
	apply_settings()
	game.tp(6.5, 6.8, 0.6)
	_show_menu()
	if "--shots" in OS.get_cmdline_user_args():
		_shots()
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()
	if "--autotest2" in OS.get_cmdline_user_args():
		_autotest2()
	if "--bench" in OS.get_cmdline_user_args():
		_bench()


func _build_post() -> void:
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	var pr := ColorRect.new()
	pr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/vhs.gdshader")
	pr.material = post
	pl.add_child(pr)


func _build_title_layer() -> void:
	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	_build_title(top)


# ---------------------------------------------------------------- settings & saves
func load_settings() -> void:
	var f := FileAccess.open("user://k13_settings.json", FileAccess.READ)
	if not f:
		# first start: pick graphics quality from the GPU
		var gpu := RenderingServer.get_video_adapter_name().to_lower()
		var weak := false
		for w in ["intel", "llvmpipe", "vangogh", "custom gpu 0405", "radeon(tm) graphics", "vega", "mali", "adreno", "uhd", "iris"]:
			if gpu.contains(w):
				weak = true
		SET.gfx = 0 if weak else 1
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				SET[k] = d[k]


func save_settings() -> void:
	var f := FileAccess.open("user://k13_settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(SET))


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(SET.vol))))
	post.set_shader_parameter("bright", float(SET.bright))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if SET.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	audio.set_mic(bool(SET.mic))
	apply_quality()
	save_settings()


var envs: Array = []


## Graphics quality: 0 low, 1 medium, 2 high.
func apply_quality() -> void:
	var q := int(SET.get("gfx", 1))
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if q == 2 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q < 2 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.7 if q == 0 else 1.0
	RenderingServer.environment_set_volumetric_fog_volume_size(48 if q == 0 else (64 if q == 1 else 96), 32 if q == 0 else (48 if q == 1 else 96))
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if q < 2 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
	RenderingServer.directional_shadow_atlas_set_size(1024 if q == 0 else 2048, true)
	vp.positional_shadow_atlas_size = 1024 if q == 0 else (2048 if q == 1 else 4096)
	for e in envs:
		e.ssao_enabled = q >= 1
		e.ssil_enabled = q == 2
		e.volumetric_fog_enabled = q >= 1
		e.fog_enabled = q == 0
		e.fog_density = 0.035
		e.fog_light_color = Color(0.05, 0.05, 0.06)
		e.glow_enabled = true
	if world:
		for i in world.pool.size():
			world.pool[i].shadow_enabled = i < (0 if q == 0 else (1 if q == 1 else 3))
	if game and game.flash:
		game.flash.shadow_enabled = true


## Merge all static meshes under root into one mesh per material: far fewer draw calls.
func merge_static(root: Node3D) -> int:
	var groups := {}
	var mats := {}
	var victims: Array = []
	var inv := root.global_transform.affine_inverse()
	var mask := Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var skip := false
		var p: Node = mi
		while p != null and p != root:
			if p is AnimatableBody3D or p.has_meta("dynamic"):
				skip = true
				break
			p = p.get_parent()
		if skip:
			continue
		var xf := inv * mi.global_transform
		var am: bool = mi.mesh is ArrayMesh
		var ok := true
		if am:
			for s in mi.mesh.get_surface_count():
				if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					ok = false
		if not ok:
			continue
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			var fmt: int = (mi.mesh.surface_get_format(s) & mask) if am else -1
			var ctr: Vector3 = xf * mi.get_aabb().get_center()
			var key := "%d_%d_%d_%d_%d" % [mat.get_instance_id() if mat else 0, fmt, int(mi.cast_shadow), int(floorf(ctr.x / 9.0)), int(floorf(ctr.z / 8.0))]
			if not groups.has(key):
				groups[key] = [SurfaceTool.new(), 0]
				mats[key] = [mat, mi.cast_shadow]
			groups[key][0].append_from(mi.mesh, s, xf)
		victims.append(mi)
	for mi in victims:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in groups:
		var st: SurfaceTool = groups[key][0]
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, mats[key][0])
		var n := MeshInstance3D.new()
		n.mesh = mesh
		n.cast_shadow = mats[key][1]
		root.add_child(n)
	return victims.size()


func set_lowpass(hz: float) -> void:
	lowpass.cutoff_hz = hz


func load_game() -> void:
	var f := FileAccess.open("user://k13_save.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			save_data = d


func save_game() -> void:
	save_data = {"snap": game.SNAP, "cp": game.CP}
	var f := FileAccess.open("user://k13_save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))


# ---------------------------------------------------------------- menu flow
var menu_root: Node3D
var menu_cam: Camera3D
var menu_moon: DirectionalLight3D
var menu_tv_light: OmniLight3D
var menu_screen_mat: ShaderMaterial
var menu_static: AudioStreamPlayer
var menu_on := false
var menu_glitch := 0.0
const MENU_AT := Vector3(200, 0, 200)
const GAL_AT := Vector3(-200, 0, -200)
const MONSTERS := [
	["m_host", "HOSŤ", "Hýbe sa, len keď sa nepozeráš.\nNikdy naň nesvieť baterkou."],
	["m_butcher", "MÄSIAR", "Vidí aj počuje. Keď ťa zbadá, beží.\nUtekaj do rozsvietenej izby."],
	["m_mother", "MATKA", "Je slepá. Loví podľa zvuku.\nKeď je blízko, nedýchaj."],
	["m_sister", "SESTRA", "Nepozeraj sa jej do očí.\nČím dlhšie hľadíš, tým viac to bolí."],
	["m_double", "DVOJNÍK", "Vyzerá ako ty a opakuje tvoje kroky.\nKeď sa na seba pozriete, rozbehne sa."],
	["m_announcer", "HLÁSATEĽ", "Objaví sa iba v páskach.\nKeď začne vysielať, nepočúvaj."],
]
var gal_root: Node3D
var gal_cam: Camera3D
var gal_models: Array = []
var gal_idx := 0
var gal_on := false
var gal_spin := 0.0


func _show_menu() -> void:
	menu_on = true
	menu_root.visible = true
	menu_moon.visible = true
	moon.visible = false
	menu_cam.make_current()
	ui.title.visible = true
	ui.menu.visible = true
	uix.hud_show(false)
	post.set_shader_parameter("vhs", 0.0)
	post.set_shader_parameter("anom", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.set_loop("drone", 0.25, 1.0)
	menu_static.play()


func _hide_menu() -> void:
	menu_on = false
	menu_root.visible = false
	menu_moon.visible = false
	moon.visible = true
	game.cam.make_current()
	ui.title.visible = false
	menu_static.stop()


func _new_game() -> void:
	_hide_menu()
	game.new_game()
	post.set_shader_parameter("fade", 0.0)
	uix.show_howto(func(): game.begin_game(1, false))


func _continue_game() -> void:
	_hide_menu()
	var snap = save_data.get("snap")
	game.SNAP = snap
	game.F = snap.F.duplicate(true)
	game.S.batt = float(snap.batt)
	game.S.knife = int(snap.knife)
	var cp = save_data.get("cp")
	if cp != null and int(cp.day) == int(snap.day):
		game.CP = cp
	game.begin_game(int(snap.day), true)


func _unhandled_input(e: InputEvent) -> void:
	if menu_on:
		if e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE and gal_on:
			_gallery_show(false)
		return
	game.handle_input(e)


func _physics_process(dt: float) -> void:
	if not menu_on:
		game.physics(dt)


var fps_label: Label


func _process(dt: float) -> void:
	if fps_label == null:
		var cl := CanvasLayer.new()
		cl.layer = 10
		add_child(cl)
		fps_label = Label.new()
		fps_label.position = Vector2(8, 4)
		fps_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
		cl.add_child(fps_label)
	fps_label.visible = bool(SET.get("fps", false))
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if menu_on:
		_menu_process(dt)
		return
	var t0 := Time.get_ticks_usec()
	game.process(dt)
	game_us = lerpf(game_us, float(Time.get_ticks_usec() - t0), 0.1)


# ---------------------------------------------------------------- screenshots (testing)
func _snap(name: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_jpg("user://" + name + ".jpg", 0.9)
	print("SHOT ", ProjectSettings.globalize_path("user://" + name + ".jpg"))


func _shots() -> void:
	await _snap("0-menu")
	_hide_menu()
	var G = game
	G.S.running = true
	G.S.lethal = false
	G.S.invuln = 1e9
	uix.hud_show(true)
	G.S.day = 3
	G.set_world("real")
	G.S.lit = {"living": true}
	G.apply_world("real")
	G.tp(6.8, 6.6, deg_to_rad(40), -0.15)
	await _snap("1-obyvacka")
	G.S.lit = {}
	G.apply_world("real")
	G.S.flash = false
	G.set_mon("butcher", {"x": 18.0, "z": 7.5, "state": "patrol", "worlds": ["real"], "rot": -PI / 2})
	G.tp(10.0, 7.5, deg_to_rad(-90))
	await _snap("2-chodba")
	G.mons_off()
	G.tp(43.0, 2.0, deg_to_rad(200), -0.1)
	G.S.zone = "base"
	G.set_mon("butcher", {"x": 48.2, "z": 8.8, "state": "idle", "idle_t": 1e9, "worlds": ["real"], "rot": PI / 2})
	G.apply_world("real")
	await _snap("3-pivnica")
	G.mons_off()
	G.S.zone = "house"
	G.apply_world("real")
	G.tp(4.5, 2.6, 0.0, -0.12)
	G.F.got_tape1 = true
	await G.insert_tape("1")
	await _snap("3b-tv")
	G.S.inserted = null
	G.start_tape("2")
	G.S.angel_on = true
	G.tp(14.6, 5.2, deg_to_rad(35), -0.2)
	await _snap("4-kazeta2")
	G.start_tape("3")
	G.tp(12.0, 7.5, deg_to_rad(-90))
	G.MON.tv.delay = 0.0
	G.MON.tv.x = 17.0
	G.MON.tv.z = 7.5
	await _snap("5-anomalia")
	G.mons_off()
	G.start_tape("13")
	await _snap("6-nemocnica")
	G.set_world("real")
	G.tp(14.0, 13.8, deg_to_rad(60), -0.2)
	G.S.flash = true
	await _snap("7-detska")
	G.U.open_map()
	await _snap("8-mapa")
	G.U.close_panel()
	G.U.open_bag()
	await _snap("9-taska")
	get_tree().quit()
func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.06
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.fog_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.75, 0.75, 0.78)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 32.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.85)
	moon.light_energy = 0.12
	moon.rotation_degrees = Vector3(-35, -60, 0)
	moon.shadow_enabled = false
	add_child(moon)


func box(size: Vector3, pos: Vector3, m: Material, collide := true, parent: Node = null, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if m:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
		mi.rotation.y = rot_y
		(parent if parent else house).add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.rotation.y = rot_y
		(parent if parent else house).add_child(sb)
		if absf(rot_y) < 0.01:
			rects.append(Rect2(pos.x - size.x / 2, pos.z - size.z / 2, size.x, size.z))
	return mi


func model(name: String, pos: Vector3, ry := 0.0, parent: Node = null) -> Node3D:
	if not _models.has(name):
		_models[name] = load("res://models/%s.glb" % name)
	var n: Node3D = _models[name].instantiate()
	n.position = pos
	n.rotation.y = ry
	(parent if parent else house).add_child(n)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and Tex.has(m.resource_name):
				mi.set_surface_override_material(i, Tex.mat_local(m.resource_name))
	return n


func set_mat(n: Node, mat_name: String, m: Material) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		for i in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(i)
			if sm and sm.resource_name == mat_name:
				mi.set_surface_override_material(i, m)


func no_shadow(n: Node) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func solid(size: Vector3, pos: Vector3) -> void:
	box(size, pos, null, true)


func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	(parent if parent else house).add_child(mi)
	return mi


func quad(size: Vector2, pos: Vector3, rot: Vector3, m: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.orientation = PlaneMesh.FACE_Z
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	(parent if parent else house).add_child(mi)
	return mi


func scrawl(text: String, pos: Vector3, rot_y: float, size := 64, parent: Node = null, col := Color(0.42, 0.02, 0.01)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = f_mark
	l.font_size = size
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation.y = rot_y
	l.shaded = true
	l.double_sided = false
	l.pixel_size = 0.004
	(parent if parent else world.G.real).add_child(l)
	return l


func _ls(font: Font, size: int, col := Color(0.92, 0.9, 0.86)) -> LabelSettings:
	var l := LabelSettings.new()
	l.font = font
	l.font_size = size
	l.font_color = col
	l.shadow_color = Color(0, 0, 0, 0.8)
	l.shadow_size = 6
	return l


func _label(parent: Control, text: String, ls: LabelSettings, anchor: Vector4, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.anchor_left = anchor.x
	l.anchor_top = anchor.y
	l.anchor_right = anchor.z
	l.anchor_bottom = anchor.w
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_menu_scene() -> void:
	menu_root = Node3D.new()
	menu_root.position = MENU_AT
	add_child(menu_root)
	var sc := model("menu_scene", Vector3.ZERO, 0.0, menu_root)
	# camera with its own darker, foggier environment
	menu_cam = Camera3D.new()
	menu_cam.fov = 52
	menu_cam.near = 0.05
	var me: Environment = env.duplicate()
	me.background_color = Color(0.005, 0.008, 0.015)
	me.ambient_light_color = Color(0.35, 0.45, 0.7)
	me.ambient_light_energy = 0.12
	me.volumetric_fog_density = 0.06
	me.volumetric_fog_albedo = Color(0.55, 0.62, 0.75)
	me.volumetric_fog_length = 40.0
	me.glow_intensity = 1.0
	me.glow_bloom = 0.15
	me.tonemap_exposure = 1.25
	menu_cam.environment = me
	menu_root.add_child(menu_cam)
	menu_cam.position = Vector3(-0.15, 1.15, 3.5)
	menu_cam.look_at(MENU_AT + Vector3(1.0, 0.78, 0.0))
	menu_moon = DirectionalLight3D.new()
	menu_moon.light_color = Color(0.5, 0.62, 0.95)
	menu_moon.light_energy = 0.35
	menu_moon.light_volumetric_fog_energy = 1.6
	menu_moon.rotation_degrees = Vector3(-50, 25, 0)
	menu_moon.shadow_enabled = true
	menu_moon.directional_shadow_max_distance = 30.0
	menu_moon.visible = false
	add_child(menu_moon)
	# light from the TV screen
	var tvp: Node3D = sc.find_child("screen", true, false)
	var scr_pos := tvp.global_position
	var fwd := tvp.global_transform.basis.z.normalized()
	menu_tv_light = OmniLight3D.new()
	menu_tv_light.light_color = Color(0.7, 0.82, 1.0)
	menu_tv_light.light_energy = 2.2
	menu_tv_light.omni_range = 5.0
	menu_tv_light.shadow_enabled = true
	menu_tv_light.light_volumetric_fog_energy = 3.0
	add_child(menu_tv_light)
	menu_tv_light.global_position = scr_pos + fwd * 0.35
	menu_tv_light.reparent(menu_root)
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.7, 0.82, 1.0)
	spot.light_energy = 5.0
	spot.spot_range = 7.0
	spot.spot_angle = 55.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 2.5
	menu_tv_light.add_child(spot)
	spot.look_at(scr_pos + fwd * 3.0 + Vector3(0, -0.6, 0))
	# blood-red haze deep in the forest
	for rp in [Vector3(-1.5, 2.2, -7.0), Vector3(4.5, 1.5, -9.0)]:
		var red := OmniLight3D.new()
		red.position = rp
		red.light_color = Color(0.9, 0.08, 0.05)
		red.light_energy = 2.0
		red.omni_range = 9.0
		red.light_volumetric_fog_energy = 5.0
		menu_root.add_child(red)
	# "GOOD LUCK" on the TV, rendered in a SubViewport
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 384)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.size = Vector2(512, 384)
	vp.add_child(bg)
	var gl := Label.new()
	gl.text = "GOOD\nLUCK"
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.size = Vector2(512, 384)
	var ls := LabelSettings.new()
	ls.font = f_osd
	ls.font_size = 170
	ls.line_spacing = -40
	ls.font_color = Color(0.92, 0.95, 1.0)
	ls.shadow_color = Color(0.9, 0.1, 0.1, 0.55)
	ls.shadow_offset = Vector2(5, 0)
	ls.shadow_size = 0
	gl.label_settings = ls
	vp.add_child(gl)
	menu_screen_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
uniform sampler2D txt : source_color, filter_linear;
uniform float glitch = 0.0;
float h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
	vec2 uv = UV;
	float line = floor(uv.y * 240.0);
	uv.x += (h(vec2(line, floor(TIME * 20.0))) - 0.5) * 0.006 + glitch * (h(vec2(line, floor(TIME * 40.0))) - 0.5) * 0.25;
	uv.y += glitch * (h(vec2(floor(TIME * 25.0), 3.0)) - 0.5) * 0.1;
	vec3 col = vec3(texture(txt, uv + vec2(0.005, 0.0)).r, texture(txt, uv).g, texture(txt, uv - vec2(0.005, 0.0)).b);
	float n = h(floor(UV * vec2(220.0, 165.0)) + floor(TIME * 30.0) * 1.3);
	col = mix(col, vec3(n), 0.16 + glitch * 0.75);
	col *= 0.78 + 0.22 * sin(UV.y * 700.0 + TIME * 8.0);
	col *= smoothstep(0.82, 0.3, length((UV - 0.5) * vec2(1.0, 1.15)));
	ALBEDO = col * 1.7;
}"""
	menu_screen_mat.shader = sh
	menu_screen_mat.set_shader_parameter("txt", vp.get_texture())
	(tvp as MeshInstance3D).material_override = menu_screen_mat
	# fireflies
	var ff := GPUParticles3D.new()
	ff.amount = 70
	ff.lifetime = 7.0
	ff.preprocess = 7.0
	ff.visibility_aabb = AABB(Vector3(-6, -1, -8), Vector3(14, 6, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.0, 1.0, 3.5)
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3(0, 0.3, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.12
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed_random = 0.3
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.25, Color(1, 1, 1, 1))
	grad.add_point(0.75, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	ff.process_material = pm
	var fm := SphereMesh.new()
	fm.radius = 0.008
	fm.height = 0.016
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.85, 0.35)
	fmat.vertex_color_use_as_albedo = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.8, 0.3)
	fmat.emission_energy_multiplier = 6.0
	fm.material = fmat
	ff.draw_pass_1 = fm
	ff.position = Vector3(1.0, 1.0, -1.0)
	menu_root.add_child(ff)
	menu_static = AudioStreamPlayer.new()
	menu_static.stream = audio.sfx.static
	menu_static.volume_db = -26
	add_child(menu_static)
	menu_root.visible = false


func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", f_title_ui)
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	b.add_theme_color_override("font_hover_color", Color(0.85, 0.12, 0.1))
	b.add_theme_color_override("font_focus_color", Color(0.9, 0.88, 0.84))
	b.add_theme_color_override("font_pressed_color", Color(0.6, 0.05, 0.05))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_entered.connect(func(): audio.play("click", -18.0, 0.7))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_title(top: CanvasLayer) -> void:
	f_title = load("res://fonts/Creepster-Regular.ttf")
	f_title_ui = load("res://fonts/Anton-Regular.ttf")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(root)
	ui.title = root
	# darken the left side so the text reads well
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.85))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.4, Color(0, 0, 0, 0.55))
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.7
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	# bloody title: rendered once, then tinted red towards the drips
	var vp := SubViewport.new()
	vp.size = Vector2i(1100, 330)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var tl := Label.new()
	tl.text = "KAZETA 13"
	tl.size = Vector2(1100, 330)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = f_title
	ls.font_size = 190
	ls.font_color = Color.WHITE
	tl.label_settings = ls
	vp.add_child(tl)
	var tsh := Shader.new()
	tsh.code = """shader_type canvas_item;
uniform bool shadow = false;
void fragment(){
	vec4 c = texture(TEXTURE, UV);
	float drip = smoothstep(0.5, 0.82, UV.y);
	vec3 col = mix(vec3(0.95, 0.93, 0.89), vec3(0.55, 0.02, 0.02), drip);
	col = mix(col, vec3(0.4, 0.0, 0.0), smoothstep(0.08, 0.0, UV.y) * 0.0);
	float flick = 0.94 + 0.06 * sin(TIME * 23.0) * step(0.97, fract(TIME * 0.37));
	if (shadow) { COLOR = vec4(0.0, 0.0, 0.0, c.a * 0.8); } else { COLOR = vec4(col * flick, c.a); }
}"""
	for sh_pass in [true, false]:
		var tr := TextureRect.new()
		tr.texture = vp.get_texture()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.anchor_left = 0.035
		tr.anchor_top = 0.05
		tr.anchor_right = 0.66
		tr.anchor_bottom = 0.42
		if sh_pass:
			tr.offset_left = 6; tr.offset_top = 8; tr.offset_right = 6; tr.offset_bottom = 8
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tm := ShaderMaterial.new()
		tm.shader = tsh
		tm.set_shader_parameter("shadow", sh_pass)
		tr.material = tm
		root.add_child(tr)
	ui.title_art = Control.new()
	ui.title_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui.title_art)
	for c in root.get_children():
		if c is TextureRect and c != shade:
			c.reparent(ui.title_art)
	var sub := _label(ui.title_art, "Niektoré spomienky mali zostať na páske.", _ls(f_type, 22, Color(0.78, 0.74, 0.67)), Vector4(0.06, 0.4, 0.6, 0.46), HORIZONTAL_ALIGNMENT_LEFT)
	var menu := VBoxContainer.new()
	menu.anchor_left = 0.06
	menu.anchor_top = 0.5
	menu.anchor_right = 0.4
	menu.anchor_bottom = 0.86
	menu.add_theme_constant_override("separation", 2)
	root.add_child(menu)
	ui.menu = menu
	_menu_button(menu, "NOVÁ HRA", _new_game)
	if save_data.get("snap") != null and int(save_data.snap.get("day", 1)) > 1:
		_menu_button(menu, "POKRAČOVAŤ · DEŇ %d" % int(save_data.snap.day), _continue_game)
	_menu_button(menu, "PRÍŠERY", func(): _gallery_show(true))
	_menu_button(menu, "NASTAVENIA", func(): uix.open_settings())
	_menu_button(menu, "KONIEC", func(): get_tree().quit())
	_label(root, "7 DNÍ · ASI HODINA · HRAJ SO SLÚCHADLAMI", _ls(f_ui, 12, Color(0.55, 0.52, 0.47)), Vector4(0.06, 0.9, 0.5, 0.94), HORIZONTAL_ALIGNMENT_LEFT)
	_label(root, "WASD pohyb · myš · E použiť · F baterka · Shift beh · Esc pauza", _ls(f_ui, 12, Color(0.45, 0.43, 0.4)), Vector4(0.55, 0.9, 0.97, 0.94), HORIZONTAL_ALIGNMENT_RIGHT)


func static_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;render_mode unshaded;float h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}void fragment(){vec2 c=UV-.5;float n=h(floor(UV*vec2(160.,120.))+floor(TIME*30.)*1.7);vec3 col=vec3(n)*.9+.05;col*=.8+.2*sin(UV.y*500.+TIME*6.);col*=smoothstep(.8,.3,length(c));ALBEDO=col*1.4;}"
	sm.shader = sh
	return sm


func _build_gallery() -> void:
	gal_root = Node3D.new()
	gal_root.position = GAL_AT
	add_child(gal_root)
	box(Vector3(12, 0.1, 12), Vector3(0, -0.05, 0), Tex.mat("concrete"), false, gal_root)
	box(Vector3(12, 6, 0.2), Vector3(0, 3, -3.0), Tex.mat("concrete"), false, gal_root)
	for m in MONSTERS:
		var n := model(m[0], Vector3.ZERO, 0.0, gal_root)
		n.visible = false
		var scr = n.find_child("screen", true, false)
		if scr:
			(scr as MeshInstance3D).material_override = static_material()
		gal_models.append(n)
	var key := SpotLight3D.new()
	key.position = Vector3(1.4, 3.6, 2.2)
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 9.0
	key.spot_range = 9.0
	key.spot_angle = 32.0
	key.shadow_enabled = true
	key.light_volumetric_fog_energy = 1.5
	gal_root.add_child(key)
	key.look_at(GAL_AT + Vector3(0, 1.0, 0))
	var rim := SpotLight3D.new()
	rim.position = Vector3(-1.6, 2.6, -2.2)
	rim.light_color = Color(0.95, 0.15, 0.1)
	rim.light_energy = 7.0
	rim.spot_range = 8.0
	rim.spot_angle = 40.0
	gal_root.add_child(rim)
	rim.look_at(GAL_AT + Vector3(0, 1.3, 0))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 1.4, 2.5)
	fill.light_color = Color(0.5, 0.6, 0.9)
	fill.light_energy = 0.5
	fill.omni_range = 7.0
	gal_root.add_child(fill)
	gal_cam = Camera3D.new()
	gal_cam.fov = 42
	var ge: Environment = env.duplicate()
	ge.background_color = Color(0.0, 0.0, 0.0)
	ge.ambient_light_color = Color(0.5, 0.5, 0.6)
	ge.ambient_light_energy = 0.05
	ge.volumetric_fog_density = 0.045
	ge.volumetric_fog_albedo = Color(0.6, 0.6, 0.65)
	gal_cam.environment = ge
	gal_root.add_child(gal_cam)
	gal_cam.position = Vector3(0, 1.25, 4.6)
	gal_cam.look_at(GAL_AT + Vector3(0, 1.15, 0))
	gal_root.visible = false
	# ui
	var g := Control.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.visible = false
	ui.title.add_child(g)
	ui.gallery = g
	var nl := _label(g, "", _ls(f_title, 96, Color(0.95, 0.93, 0.89)), Vector4(0.05, 0.08, 0.5, 0.3), HORIZONTAL_ALIGNMENT_LEFT)
	nl.label_settings.font_color = Color(0.88, 0.85, 0.8)
	ui.gal_name = nl
	ui.gal_desc = _label(g, "", _ls(f_type, 22, Color(0.8, 0.76, 0.7)), Vector4(0.05, 0.3, 0.45, 0.48), HORIZONTAL_ALIGNMENT_LEFT)
	ui.gal_count = _label(g, "", _ls(f_ui, 13, Color(0.55, 0.52, 0.47)), Vector4(0.05, 0.48, 0.45, 0.52), HORIZONTAL_ALIGNMENT_LEFT)
	var row := HBoxContainer.new()
	row.anchor_left = 0.05
	row.anchor_top = 0.62
	row.anchor_right = 0.45
	row.anchor_bottom = 0.86
	row.add_theme_constant_override("separation", 26)
	g.add_child(row)
	var col := VBoxContainer.new()
	row.add_child(col)
	_menu_button(col, "◀  PREDOŠLÁ", func(): _gal_set(gal_idx - 1))
	_menu_button(col, "ĎALŠIA  ▶", func(): _gal_set(gal_idx + 1))
	_menu_button(col, "SPÄŤ", func(): _gallery_show(false))


func _gal_set(i: int) -> void:
	gal_idx = posmod(i, MONSTERS.size())
	for k in gal_models.size():
		gal_models[k].visible = k == gal_idx
	gal_spin = 0.5
	var aabb := AABB()
	var first := true
	for c in gal_models[gal_idx].find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var bb: AABB = mi.global_transform * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var h := aabb.size.y
	var ctr := aabb.get_center()
	var dist := h * 0.5 / tan(deg_to_rad(gal_cam.fov * 0.5)) * 1.18
	gal_cam.global_position = Vector3(ctr.x - dist * 0.28, ctr.y + h * 0.04, ctr.z + dist)
	gal_cam.look_at(Vector3(ctr.x - h * 0.22, ctr.y, ctr.z))
	ui.gal_name.text = MONSTERS[gal_idx][1]
	ui.gal_desc.text = MONSTERS[gal_idx][2]
	ui.gal_count.text = "%d / %d" % [gal_idx + 1, MONSTERS.size()]
	audio.play("stinger", -22.0, 1.6)


func _gallery_show(on: bool) -> void:
	gal_on = on
	gal_root.visible = on
	menu_root.visible = not on
	ui.gallery.visible = on
	ui.menu.visible = not on
	ui.title_art.visible = not on
	if on:
		gal_cam.make_current()
		_gal_set(gal_idx)
	else:
		menu_cam.make_current()


func _menu_process(dt: float) -> void:
	if gal_on:
		gal_spin += dt * 0.32
		gal_models[gal_idx].rotation.y = sin(gal_spin) * 0.9
		return
	var t := Time.get_ticks_msec() / 1000.0
	menu_cam.position = Vector3(-0.15 + sin(t * 0.13) * 0.12, 1.15 + sin(t * 0.21) * 0.04, 3.5 + sin(t * 0.09) * 0.08)
	menu_cam.look_at(MENU_AT + Vector3(1.0 + sin(t * 0.11) * 0.05, 0.78, 0.0))
	menu_glitch = maxf(0.0, menu_glitch - dt * 3.0)
	if randf() < dt * 0.25:
		menu_glitch = 1.0
		audio.play("stinger", -30.0, 2.4)
	menu_screen_mat.set_shader_parameter("glitch", menu_glitch)
	menu_tv_light.light_energy = (2.0 + randf() * 0.5) * (0.25 if menu_glitch > 0.5 and randf() < 0.5 else 1.0)


# ---------------------------------------------------------------- automated playthrough (testing)
func _t(msg: String) -> void:
	print("AUTOTEST ", msg, "  day=", game.S.day, " world=", game.S.world)


func _w(cond: Callable, limit := 60.0) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > limit:
			_t("TIMEOUT")
			return false
	return true


func _tape(id: String) -> void:
	var G = game
	G.F["got_tape" + id] = true
	await G.insert_tape(id)
	await _w(func(): return G.S.can_enter or G.S.world == "fake" or G.S.live_stage > 0, 30)
	if G.S.can_enter:
		await G.enter_tape()
	_t("in tape " + id)


func _autotest() -> void:
	var G = game
	_hide_menu()
	G.S.running = true
	uix.hud_show(true)
	G.start_day(1)
	await _w(func(): return not G.S.busy)
	G.S.invuln = 1e9
	# ---- day 1
	G.tp(4.0, 4.0, 0)
	await _w(func(): return G.S.obj_text.begins_with("Na stolíku"))
	G.take("tape1")
	await _tape("1")
	G.take("keyKid")
	await G.exit_tape()
	G.tp(12.0, 7.5, 0)
	await get_tree().create_timer(1.0).timeout
	G.door_use("kid")
	G.take("tape2")
	await _tape("2")
	await G.blow_candles()
	await _w(func(): return G.isRealW(G.S.world) and not G.S.busy)
	G.take("knife")
	await _w(func(): return G.S.can_sleep == 1, 30)
	G.F.slept1 = true
	await _w(func(): return G.S.day == 2 and not G.S.busy, 30)
	G.S.invuln = 1e9
	_t("day 2")
	# ---- day 2
	G.F.sawKeypad = true
	await get_tree().create_timer(0.5).timeout
	G.F.studyOpen = true
	G.take("tape3")
	await _tape("3")
	for r in ["reel1", "reel2", "reel3"]:
		G.take(r)
	await G.exit_tape()
	await _w(func(): return G.S.can_sleep == 2, 30)
	G.F.slept2 = true
	await _w(func(): return G.S.day == 3 and not G.S.busy, 30)
	G.S.invuln = 1e9
	_t("day 3")
	# ---- day 3
	G.take("tape4")
	await _tape("4")
	G.clock_use()
	await G.exit_tape()
	await _w(func(): return G.S.obj_text == "Veľké hodiny.", 20)
	G.F.clockOk = true
	G.take("keyBase")
	await G.base_door()
	await G.base_door()
	await _w(func(): return G.S.zone == "base", 10)
	G.take("tape5")
	await get_tree().create_timer(1.0).timeout
	await G.stairs("house")
	await _w(func(): return G.S.obj_text == "Pusti kazetu 5.", 20)
	await _tape("5")
	await G.kid_talk()
	await G.exit_tape()
	await _w(func(): return G.S.can_sleep == 3, 30)
	G.F.slept3 = true
	await _w(func(): return G.S.day == 4 and not G.S.busy, 30)
	G.S.invuln = 1e9
	_t("day 4")
	# ---- day 4
	G.tp(21.0, 12.0, 0)
	await get_tree().create_timer(0.5).timeout
	G.F.photosOk = true
	G.take("tape6")
	await _tape("6")
	for r in ["toy1", "toy2", "toy3", "toy4"]:
		G.take(r)
	await G.exit_tape()
	await _w(func(): return G.S.can_sleep == 4, 30)
	G.F.slept4 = true
	await _w(func(): return G.S.day == 5 and not G.S.busy, 30)
	G.S.invuln = 1e9
	_t("day 5")
	# ---- day 5
	G.tp(47.5, 1.5, 0)
	G.S.zone = "base"
	await get_tree().create_timer(0.5).timeout
	G.F.powerOn = true
	G.S.power = true
	G.take("tape7")
	G.tp(4.0, 3.0, 0)
	G.S.zone = "house"
	await _tape("7")
	await G.kid_talk()
	await G.exit_tape()
	await _w(func(): return G.S.can_sleep == 5, 30)
	G.F.slept5 = true
	await _w(func(): return G.S.day == 6 and not G.S.busy, 30)
	G.S.invuln = 1e9
	_t("day 6")
	# ---- day 6
	G.take("tapeX")
	await _tape("X")
	await _w(func(): return G.S.live_stage >= 1, 20)
	G.S.yaw += PI
	await _w(func(): return G.F.get("revealed", false) and not G.S.busy, 20)
	await G.base_door()
	await _w(func(): return G.S.zone == "base", 10)
	G.take("tape13")
	await _w(func(): return G.S.can_sleep == 6, 40)
	G.F.slept6 = true
	await _w(func(): return G.S.day == 7 and not G.S.busy, 30)
	G.S.invuln = 1e9
	_t("day 7")
	# ---- day 7
	G.take("spool")
	G.take("roll")
	G.F.t13fixed = true
	await _w(func(): return G.S.obj_text.begins_with("Pusti kazetu 13"), 20)
	await _tape("13")
	await _w(func(): return G.S.world == "hosp" and not G.S.busy, 20)
	await get_tree().create_timer(3.0).timeout
	await G.ending_wake()
	await get_tree().create_timer(8.0).timeout
	_t("DONE ending=" + str(G.S.ending))
	get_tree().quit()


func _autotest2() -> void:
	var G = game
	_hide_menu()
	G.S.running = true
	uix.hud_show(true)
	# death + retry from checkpoint
	G.start_day(2)
	await _w(func(): return not G.S.busy)
	await get_tree().create_timer(2.0).timeout
	G.F.sawKeypad = true
	await get_tree().create_timer(1.0).timeout
	_t("cp=" + str(G.CP != null))
	G.S.knife = 1
	G.mon_attack(G.MON.mother)
	await get_tree().create_timer(0.3).timeout
	G.act()
	_t("knife left " + str(G.S.knife))
	G.damage(200, "Matka")
	await _w(func(): return G.S.dead)
	await get_tree().create_timer(2.0).timeout
	_t("dead, retry_cp=" + str(G.S.retry_cp))
	G.retry()
	await _w(func(): return not G.S.busy and not G.S.dead, 20)
	await get_tree().create_timer(2.0).timeout
	_t("after retry obj=" + G.S.obj_text + " step=" + str(G.S.step_n) + " replay=" + str(G.S.replay_n) + " cp_step=" + str(G.CP.step_n) + " fast=" + str(G.S.fast))
	# hide + mic
	G.hide(G.HIDES[0])
	await get_tree().create_timer(0.5).timeout
	G.mic_heard()
	await get_tree().create_timer(0.5).timeout
	G.unhide()
	# bag, map, puzzles
	G.U.open_bag(); await get_tree().create_timer(0.3).timeout; G.U.close_panel()
	G.U.open_map(); await get_tree().create_timer(0.3).timeout; G.U.close_panel()
	G.study_keypad(); await get_tree().create_timer(0.3).timeout; G.U.close_panel()
	G.do_scare("behind"); await get_tree().create_timer(1.0).timeout
	G.do_scare("slam"); G.do_scare("run"); G.do_scare("face")
	await G.do_scare("dark")
	# ending C
	G.start_day(7)
	await _w(func(): return not G.S.busy)
	for k in C.NOTES:
		G.F["read_" + k] = true
	G.take("tape0")
	await _tape("0")
	await get_tree().create_timer(2.0).timeout
	G.S.t0done = true
	await G.ending_c()
	_t("ending C=" + str(G.S.ending))
	await get_tree().create_timer(2.0).timeout
	# ending B
	G.S.running = true
	G.start_hosp()
	await get_tree().create_timer(1.0).timeout
	await G.ending_stay()
	_t("ending B=" + str(G.S.ending))
	await get_tree().create_timer(7.0).timeout
	_t("DONE2")
	get_tree().quit()


func _bench() -> void:
	var G = game
	_hide_menu()
	G.S.running = true
	G.S.invuln = 1e9
	uix.hud_show(true)
	G.set_world("real")
	G.S.flash = true
	G.S.lit = {"living": true}
	G.apply_world("real")
	var cnt := {}
	for c in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if c.is_visible_in_tree():
			var path := str(c.get_path())
			var key := path.split("/").slice(0, 6)
			var k := "/".join(key)
			cnt[k] = cnt.get(k, 0) + 1
	var mats := {}
	for c in world.G.house.get_children():
		if c is MeshInstance3D and c.mesh:
			var mm = c.mesh.surface_get_material(0)
			mats[mm] = mats.get(mm, 0) + 1
	print("MERGED children in house: ", world.G.house.get_child_count(), " unique materials: ", mats.size())
	G.start_day(7)
	await get_tree().create_timer(4.0).timeout
	G.S.invuln = 1e9
	for q in [2, 1, 0]:
		SET.gfx = q
		apply_quality()
		await _bench_spots()
	get_tree().quit()


func _bench_spots() -> void:
	var G = game
	for spot in [[6.8, 6.6, 0.7], [10.0, 7.5, -1.57], [21.0, 12.0, 0.0]]:
		G.tp(spot[0], spot[1], spot[2])
		for i in 30:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for i in 30:
			await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - t0) / 30000.0
		G.S.flash = true
		print("BENCH gfx=%d %s draw=%d prims=%d frame_ms=%.1f game_logic_ms=%.2f script_ms=%.2f physics_ms=%.2f" % [int(SET.gfx), str(spot), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), ms, game_us / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
