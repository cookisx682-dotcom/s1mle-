extends Node3D
## Kazeta 13 - Godot demo (day 1). Builds the house procedurally and runs the game.

const H := 2.8
const TW := 0.16
const NS := 0.5
const NW := 48
const NH := 30

# ---------- scene parts ----------
var house: Node3D
var real_g: Node3D
var mem_g: Node3D
var env: Environment
var moon: DirectionalLight3D
var player: CharacterBody3D
var head: Node3D
var cam: Camera3D
var flash: SpotLight3D
var torch: Node3D
var hand_light: OmniLight3D
const TORCH_REST := Vector3(0.17, -0.2, -0.33)
var torch_sway := Vector2.ZERO
var tv_light: OmniLight3D
var room_lights := {}
var lamp_mats := {}
var mem_lights: Array = []
var post: ShaderMaterial
var host: Node3D
var angel: Node3D
var family: Array = []
var doors := {}
var rects: Array = []      # nav obstacles (Rect2 in xz)
var nav := PackedByteArray()
var inter: Array = []
var items := {}

# ---------- audio ----------
var sfx := {}
var a_drone: AudioStreamPlayer
var a_music: AudioStreamPlayer
var a_breath: AudioStreamPlayer
var a_tv: AudioStreamPlayer3D
var a_host: AudioStreamPlayer3D

# ---------- ui ----------
var ui := {}
var f_osd: Font
var f_type: Font
var f_mark: Font
var f_ui: Font

# ---------- state ----------
var S := {
	"running": false, "paused": false, "busy": false, "dead": false, "world": "real",
	"yaw": -PI / 2, "pitch": 0.0, "flash": false, "batt": 90.0, "stam": 100.0, "tired": false,
	"hp": 100.0, "hurt_t": 9.0, "bob": 0.0, "step_acc": 0.0, "shake": 0.0, "flick": 0.0,
	"inserted": false, "can_enter": false, "can_exit": false, "lit": {}, "flags": {}, "time": 0.0,
}
var cur = null
var sens := 1.0
var sub_q: Array = []
var sub_t := 0.0
var msg_t := 0.0
var host_s := {"active": false, "cool": 0.0, "lit": 0.0, "warned": false, "path": [], "path_t": 0.0, "far_t": 0.0, "walk": 0.0}
var ang_s := {"on": false, "idx": 0, "away": 0.0}


func _ready() -> void:
	randomize()
	f_osd = load("res://fonts/VT323-Regular.ttf")
	f_type = load("res://fonts/SpecialElite-Regular.ttf")
	f_mark = load("res://fonts/PermanentMarker-Regular.ttf")
	f_ui = load("res://fonts/Inter.ttf")
	_build_audio()
	_build_env()
	house = Node3D.new(); add_child(house)
	real_g = Node3D.new(); add_child(real_g)
	mem_g = Node3D.new(); add_child(mem_g)
	_build_house()
	_build_furniture()
	_build_people()
	_build_player()
	_build_nav()
	_build_ui()
	_build_menu_scene()
	_build_gallery()
	_set_world("real")
	_show_title()
	if "--shots" in OS.get_cmdline_user_args():
		_shots()


func _snap(name: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_jpg("user://" + name + ".jpg", 0.9)
	print("SHOT ", ProjectSettings.globalize_path("user://" + name + ".jpg"))


func _shots() -> void:
	await _snap("0-menu")
	_gallery_show(true)
	for i in MONSTERS.size():
		_gal_set(i)
		gal_spin = 0.15
		await _snap("g%d-%s" % [i, MONSTERS[i][0]])
	_gallery_show(false)
	_hide_menu()
	ui.hud.visible = true
	S.running = true
	S.lit = {"living": true}
	_set_world("real")
	spawn(Vector3(6.8, 0, 6.6), deg_to_rad(40))
	S.pitch = -0.15
	await _snap("1-obyvacka")
	S.lit = {}
	_set_world("real")
	S.flash = true
	spawn(Vector3(10.0, 0, 7.5), deg_to_rad(-90))
	S.pitch = 0.0
	host.position = Vector3(19.5, 0, 7.5)
	host.visible = true
	S.running = false
	torch.visible = true
	await _snap("2-chodba")
	S.running = true
	host.visible = false
	spawn(Vector3(11.0, 0, 5.4), deg_to_rad(150))
	S.flash = true
	S.pitch = -0.25
	await _snap("3-kuchyna")
	S.flash = false
	_set_world("t1")
	angel.visible = false
	spawn(Vector3(14.6, 0, 5.2), deg_to_rad(35))
	S.pitch = -0.2
	await _snap("4-kazeta")
	_set_world("real")
	S.flash = true
	spawn(Vector3(14.0, 0, 13.8), deg_to_rad(60))
	S.pitch = -0.2
	set_door("kid", true)
	await _snap("5-detska")
	get_tree().quit()


# =====================================================================
# Environment & lights
# =====================================================================
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
	moon.shadow_enabled = true
	add_child(moon)


func _set_world(w: String) -> void:
	S.world = w
	var mem := w == "t1"
	real_g.visible = not mem
	mem_g.visible = mem
	for l in mem_lights:
		l.visible = mem
	for k in lamp_mats:
		lamp_mats[k].emission_energy_multiplier = 3.0 if (mem or S.lit.get(k, false)) else 0.0
	for k in room_lights:
		room_lights[k].visible = (not mem) and S.lit.get(k, false)
	tv_light.visible = not mem
	moon.light_energy = 0.0 if mem else 0.12
	env.ambient_light_color = Color(1.0, 0.85, 0.65) if mem else Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.35 if mem else 0.06
	env.volumetric_fog_albedo = Color(1.0, 0.85, 0.65) if mem else Color(0.75, 0.75, 0.78)
	env.volumetric_fog_density = 0.02 if mem else 0.035
	post.set_shader_parameter("vhs", 1.0 if mem else 0.0)
	ui.osd.visible = mem
	if mem:
		a_music.play()
	else:
		a_music.stop()
	angel.visible = ang_s.on and mem


# =====================================================================
# Geometry helpers
# =====================================================================
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


var _models := {}
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
	(parent if parent else real_g).add_child(l)
	return l


# =====================================================================
# House
# =====================================================================
func add_wall(cx: float, cz: float, sx: float, sz: float) -> void:
	box(Vector3(sx, H, sz), Vector3(cx, H / 2, cz), Tex.mat("wall"))
	var hz := sx > sz
	box(Vector3(sx + (0.0 if hz else 0.03), 1.0, sz + (0.03 if hz else 0.0)), Vector3(cx, 0.5, cz), Tex.mat("wainscot"), false)
	box(Vector3(sx + (0.0 if hz else 0.05), 0.05, sz + (0.05 if hz else 0.0)), Vector3(cx, 1.0, cz), Tex.mat("wood_dark"), false)
	box(Vector3(sx + (0.0 if hz else 0.07), 0.09, sz + (0.07 if hz else 0.0)), Vector3(cx, H - 0.045, cz), Tex.flat(Color(0.6, 0.57, 0.5), 0.8), false)


func wall_seg(x0: float, z0: float, x1: float, z1: float, gaps := []) -> void:
	var hz := z0 == z1
	var a0 := x0 if hz else z0
	var a1 := x1 if hz else z1
	var cur_a := a0
	var cur_end := true
	var gs: Array = gaps.duplicate()
	gs.sort_custom(func(a, b): return a[0] < b[0])
	var seg := func(p0: float, p1: float, e0: bool, e1: bool) -> void:
		p0 -= TW / 2 if e0 else 0.0
		p1 += TW / 2 if e1 else 0.0
		if p1 - p0 < 0.02:
			return
		var L := p1 - p0
		var m := (p0 + p1) / 2
		if hz:
			add_wall(m, z0, L, TW)
		else:
			add_wall(x0, m, TW, L)
	for g in gs:
		var c: float = g[0]
		var w: float = g[1]
		seg.call(cur_a, c - w / 2, cur_end, false)
		box(Vector3(w if hz else TW, H - 2.15, TW if hz else w), Vector3(c if hz else x0, (H + 2.15) / 2, z0 if hz else c), Tex.mat("wall"), false)
		for s in [-1, 1]:
			box(Vector3(0.07 if hz else TW + 0.05, 2.15, TW + 0.05 if hz else 0.07), Vector3(c + s * w / 2 if hz else x0, 1.075, z0 if hz else c + s * w / 2), Tex.mat("wood_dark"), false)
		box(Vector3(w + 0.14 if hz else TW + 0.05, 0.08, TW + 0.05 if hz else w + 0.14), Vector3(c if hz else x0, 2.17, z0 if hz else c), Tex.mat("wood_dark"), false)
		cur_a = c + w / 2
		cur_end = false
	seg.call(cur_a, a1, cur_end, true)


func floor_room(x0: float, z0: float, x1: float, z1: float, key: String) -> void:
	box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2, -0.05, (z0 + z1) / 2), Tex.mat(key), false)


func make_door(id: String, x: float, z: float, axis: String, w: float, locked := false) -> void:
	var pv := Node3D.new()
	pv.position = Vector3(x - w / 2, 0, z) if axis == "x" else Vector3(x, 0, z - w / 2)
	house.add_child(pv)
	var pw := w - 0.04
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	pv.add_child(body)
	var size := Vector3(pw, 2.1, 0.05) if axis == "x" else Vector3(0.05, 2.1, pw)
	var off := Vector3(pw / 2, 1.05, 0) if axis == "x" else Vector3(0, 1.05, pw / 2)
	var dm := model("door", Vector3.ZERO, 0.0 if axis == "x" else -PI / 2, body)
	dm.scale.x = pw / 0.94
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; cs.position = off
	body.add_child(cs)
	doors[id] = {"pv": pv, "open": false, "locked": locked, "ang": (-1.45 if axis == "x" else 1.45), "cur": 0.0, "x": x, "z": z, "axis": axis, "w": w}


func set_door(id: String, open: bool, locked = null) -> void:
	var d = doors[id]
	d.open = open
	if locked != null:
		d.locked = locked


func lamp_fixture(key: String, pos: Vector3) -> void:
	var m := Tex.emissive(Color(1.0, 0.8, 0.55), 0.0)
	lamp_mats[key + str(lamp_mats.size())] = m
	var shade := cyl(0.13, 0.28, 0.22, pos, m)
	shade.material_override = m
	cyl(0.006, 0.006, H - pos.y, Vector3(pos.x, (H + pos.y) / 2, pos.z), Tex.mat("black"))


func _build_house() -> void:
	wall_seg(0, 0, 24, 0)
	wall_seg(0, 15, 24, 15, [[6.5, 1.0]])
	wall_seg(0, 0, 0, 15, [[11.5, 1.0]])
	wall_seg(24, 0, 24, 15)
	wall_seg(0, 8, 9, 8, [[4.5, 1.6]])
	wall_seg(9, 0, 9, 15, [[3, 1.0], [7.5, 1.2]])
	wall_seg(16, 0, 16, 6, [[3, 1.0]])
	wall_seg(9, 6, 24, 6, [[12.5, 1.0]])
	wall_seg(9, 9, 24, 9, [[12, 1.0], [17, 1.0], [21.5, 1.0]])
	wall_seg(15, 9, 15, 15)
	wall_seg(19, 9, 19, 15, [[14, 0.9]])
	wall_seg(15, 13, 19, 13)
	floor_room(0, 0, 9, 8, "floor"); floor_room(0, 8, 9, 15, "floor"); floor_room(9, 0, 16, 6, "tile")
	floor_room(16, 0, 24, 6, "floor"); floor_room(9, 6, 24, 9, "floor"); floor_room(9, 9, 15, 15, "carpet")
	floor_room(15, 9, 19, 13, "tile2"); floor_room(15, 13, 19, 15, "concrete"); floor_room(19, 9, 24, 15, "carpet2")
	var ceil := box(Vector3(24, 0.1, 15), Vector3(12, H + 0.05, 7.5), Tex.mat("ceiling"), false)
	ceil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# outer slab so light never leaks
	box(Vector3(26, 0.2, 17), Vector3(12, -0.2, 7.5), Tex.mat("black"), true)
	make_door("lk", 9, 3, "z", 0.98)
	make_door("kh", 12.5, 6, "x", 0.98)
	make_door("kid", 12, 9, "x", 0.98, true)
	make_door("bath", 17, 9, "x", 0.98)
	make_door("bed", 21.5, 9, "x", 0.98, true)
	make_door("study", 16, 3, "z", 0.98, true)
	make_door("stor", 19, 14, "z", 0.88)
	make_door("front", 0, 11.5, "z", 0.98, true)
	make_door("base", 6.5, 15, "x", 0.98, true)
	set_door("kh", true)
	# windows
	for wdef in [[Vector3(0.09, 1.6, 5.8), PI / 2], [Vector3(11.5, 1.6, 0.09), 0.0], [Vector3(20, 1.6, 0.09), 0.0], [Vector3(12, 1.6, 14.91), PI], [Vector3(23.91, 1.6, 10.3), -PI / 2]]:
		_window(wdef[0], wdef[1])
	# lamps and their lights (switchable rooms)
	var rooms := {"living": Vector3(4.5, 2.3, 3.8), "kitchen": Vector3(12.5, 2.3, 3.4), "kid": Vector3(12, 2.3, 12)}
	for k in rooms:
		var p: Vector3 = rooms[k]
		var m := Tex.emissive(Color(1.0, 0.8, 0.55), 0.0)
		lamp_mats[k] = m
		var shade := model("shade", p + Vector3(0, 0.05, 0))
		set_mat(shade, "lampshade", m)
		no_shadow(shade)
		cyl(0.006, 0.006, H - p.y, Vector3(p.x, (H + p.y) / 2 + 0.05, p.z), Tex.mat("black"))
		var l := OmniLight3D.new()
		l.position = p - Vector3(0, 0.2, 0)
		l.light_color = Color(1.0, 0.78, 0.55)
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.shadow_enabled = true
		l.light_volumetric_fog_energy = 0.6
		house.add_child(l)
		room_lights[k] = l
	# memory-world lights (everything lit, warm)
	for p in [Vector3(4.5, 2.2, 3.8), Vector3(12.5, 2.2, 3.4), Vector3(14, 2.2, 7.5), Vector3(4.5, 2.2, 11.5), Vector3(20, 2.2, 7.5)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.75, 0.5)
		l.light_energy = 1.8
		l.omni_range = 9.0
		l.shadow_enabled = p.x < 13
		house.add_child(l)
		mem_lights.append(l)
	# switches
	_switch("living", Vector3(5.7, 1.3, 7.9), PI)
	_switch("kitchen", Vector3(9.1, 1.3, 2.1), PI / 2)
	_switch("kid", Vector3(11.15, 1.3, 9.1), 0.0)
	# blood writing
	scrawl("VRÁŤ SA", Vector3(16.2, 1.6, 6.09), 0.0, 96)
	scrawl("ON JE TU", Vector3(13.8, 1.55, 9.09), 0.0, 80)
	scrawl("NESVIEŤ", Vector3(0.09, 1.55, 3.6), PI / 2, 80)


func _window(pos: Vector3, ry: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = ry
	house.add_child(g)
	var glass := Tex.emissive(Color(0.12, 0.16, 0.3), 0.6)
	quad(Vector2(1.1, 1.25), Vector3.ZERO, Vector3.ZERO, glass, g)
	for d in [[Vector3(1.22, 0.06, 0.06), Vector3(0, 0.64, 0.02)], [Vector3(1.22, 0.06, 0.06), Vector3(0, -0.64, 0.02)], [Vector3(0.06, 1.3, 0.06), Vector3(-0.58, 0, 0.02)], [Vector3(0.06, 1.3, 0.06), Vector3(0.58, 0, 0.02)], [Vector3(1.1, 0.035, 0.04), Vector3(0, 0, 0.02)], [Vector3(0.035, 1.25, 0.04), Vector3(0, 0, 0.02)]]:
		box(d[0], d[1], Tex.mat("wood"), false, g)
	for s in [-1, 1]:
		box(Vector3(0.42, 2.1, 0.05), Vector3(s * 0.85, -0.25, 0.1), Tex.flat(Color(0.25, 0.06, 0.06), 0.98), false, g)
	for i in 3:
		var b := box(Vector3(1.5, 0.12, 0.03), Vector3(0, -0.4 + i * 0.4, 0.12), Tex.mat("wood_dark"), false, g)
		b.rotation.z = (i - 1) * 0.08
		b.reparent(real_g)


func _switch(key: String, pos: Vector3, ry: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = ry
	house.add_child(g)
	box(Vector3(0.09, 0.13, 0.015), Vector3.ZERO, Tex.mat("cream"), false, g)
	box(Vector3(0.022, 0.04, 0.02), Vector3(0, 0, 0.012), Tex.flat(Color(0.6, 0.58, 0.52), 0.5), false, g)
	add_inter(pos, 2.0, func(): return S.world == "real",
		func(): return "Zhasnúť svetlo" if S.lit.get(key, false) else "Rozsvietiť",
		func():
			S.lit[key] = not S.lit.get(key, false)
			play("click")
			_set_world(S.world))


# =====================================================================
# Furniture
# =====================================================================
func chair(x: float, z: float, ry: float, parent: Node = null) -> Node3D:
	return model("chair", Vector3(x, 0, z), ry, parent)


var tv_screen: MeshInstance3D
func _build_furniture() -> void:
	# --- living: TV (Blender model)
	var tv := model("tv", Vector3(4.5, 0, 0.62))
	rects.append(Rect2(3.75, 0.34, 1.5, 0.56))
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;render_mode unshaded;uniform float on=1.0;float h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}void fragment(){vec2 c=UV-.5;float n=h(floor(UV*vec2(170.,128.))+floor(TIME*30.)*1.7);vec3 col=vec3(n)*.8+.05;col*=.82+.18*sin(UV.y*520.);col*=smoothstep(.78,.3,length(c));ALBEDO=col*on;}"
	sm.shader = sh
	tv_screen = tv.find_child("screen", true, false)
	tv_screen.material_override = sm
	tv_light = OmniLight3D.new()
	tv_light.position = Vector3(4.5, 0.95, 1.4)
	tv_light.light_color = Color(0.62, 0.71, 1.0)
	tv_light.light_energy = 0.9
	tv_light.omni_range = 5.5
	tv_light.shadow_enabled = true
	house.add_child(tv_light)
	add_inter(Vector3(4.5, 0.85, 0.95), 2.4, func(): return true, _tv_label, _tv_use)
	# coffee table, rug
	box(Vector3(1.2, 0.05, 0.66), Vector3(4.5, 0.42, 3.2), Tex.mat("wood"), true)
	for a in [-1, 1]:
		for b in [-1, 1]:
			box(Vector3(0.05, 0.4, 0.05), Vector3(4.5 + a * 0.54, 0.2, 3.2 + b * 0.28), Tex.mat("wood"), false)
	box(Vector3(3, 0.01, 3.6), Vector3(4.5, 0.006, 3.8), Tex.mat("rug"), false)
	# sofa + armchair, covered with sheets in reality (cloth-simulated in Blender)
	model("sofa", Vector3(4.5, 0, 5.0), 0.0, mem_g)
	solid(Vector3(2.2, 0.9, 0.86), Vector3(4.5, 0.45, 5.0))
	model("sofa_sheet", Vector3(4.5, 0, 5.0), 0.0, real_g)
	model("armchair", Vector3(1.4, 0, 3.4), -PI / 2, mem_g)
	solid(Vector3(0.9, 0.9, 0.9), Vector3(1.4, 0.45, 3.4))
	model("armchair_sheet", Vector3(1.4, 0, 3.4), -PI / 2, real_g)
	model("shelf", Vector3(0.24, 0, 1.4), PI / 2)
	solid(Vector3(0.42, 2.0, 1.3), Vector3(0.3, 1.0, 1.4))
	model("clock", Vector3(8.45, 0, 0.45))
	solid(Vector3(0.56, 2.1, 0.42), Vector3(8.45, 1.05, 0.45))
	model("floor_lamp", Vector3(7.7, 0, 1.6))
	var fl := Tex.emissive(Color(1.0, 0.8, 0.55), 0.0)
	lamp_mats["living_floor"] = fl
	var fs := model("shade", Vector3(7.7, 1.5, 1.6))
	set_mat(fs, "lampshade", fl)
	no_shadow(fs)
	model("dresser", Vector3(2.2, 0, 7.72), PI)
	solid(Vector3(1.4, 0.9, 0.5), Vector3(2.2, 0.45, 7.72))
	# --- kitchen
	model("counter", Vector3(11.6, 0, 0.42))
	solid(Vector3(4.8, 0.9, 0.6), Vector3(11.6, 0.45, 0.42))
	model("stove", Vector3(14.6, 0, 0.42))
	solid(Vector3(0.76, 0.9, 0.62), Vector3(14.6, 0.45, 0.42))
	model("fridge", Vector3(15.5, 0, 0.5))
	solid(Vector3(0.72, 1.8, 0.66), Vector3(15.5, 0.9, 0.5))
	model("table", Vector3(12.5, 0, 3.6))
	solid(Vector3(1.6, 0.78, 0.9), Vector3(12.5, 0.39, 3.6))
	chair(12.5, 2.98, 0.0); chair(11.5, 3.6, PI / 2); chair(13.5, 3.6, -PI / 2, mem_g); chair(12.5, 4.25, PI, mem_g)
	var fallen := chair(14.2, 4.9, 0.8, real_g)
	fallen.rotation = Vector3(PI / 2.1, 0.6, 0)
	fallen.position.y = 0.22
	# --- hall
	box(Vector3(0.9, 0.05, 0.34), Vector3(14.5, 0.78, 6.3), Tex.mat("wood"), true)
	for a in [-1, 1]:
		box(Vector3(0.04, 0.76, 0.04), Vector3(14.5 + a * 0.4, 0.38, 6.3), Tex.mat("wood"), false)
	model("wardrobe", Vector3(23.6, 0, 7.5), -PI / 2)
	solid(Vector3(0.7, 2.0, 1.1), Vector3(23.6, 1.0, 7.5))
	box(Vector3(13, 0.01, 1.1), Vector3(16.5, 0.006, 7.5), Tex.mat("rug"), false)
	box(Vector3(0.56, 0.45, 0.03), Vector3(10.6, 1.6, 6.1), Tex.mat("wood_dark"), false)
	box(Vector3(0.5, 0.39, 0.005), Vector3(10.6, 1.6, 6.12), Tex.flat(Color(0.45, 0.38, 0.27), 0.6), false)
	# --- kid room
	model("bed_kid", Vector3(9.72, 0, 12.5))
	solid(Vector3(1.06, 0.5, 2.06), Vector3(9.72, 0.25, 12.5))
	model("wardrobe", Vector3(14.6, 0, 10.1), -PI / 2)
	solid(Vector3(0.7, 2.0, 1.1), Vector3(14.6, 1.0, 10.1))
	box(Vector3(0.9, 0.04, 0.5), Vector3(13.4, 0.62, 14.6), Tex.flat(Color(0.48, 0.35, 0.24), 0.6), true)
	box(Vector3(0.8, 0.5, 0.45), Vector3(10.6, 0.25, 14.55), Tex.flat(Color(0.42, 0.29, 0.16), 0.7), true)
	# --- bath, bedroom, foyer
	model("bathtub", Vector3(17.5, 0, 12.55))
	solid(Vector3(2.0, 0.6, 0.76), Vector3(17.5, 0.3, 12.55))
	model("sink", Vector3(18.72, 0, 10.2), -PI / 2)
	solid(Vector3(0.44, 0.9, 0.5), Vector3(18.72, 0.45, 10.2))
	var mirror := StandardMaterial3D.new(); mirror.albedo_color = Color(0.05, 0.06, 0.07); mirror.metallic = 1.0; mirror.roughness = 0.02
	quad(Vector2(0.5, 0.7), Vector3(18.92, 1.55, 10.2), Vector3(0, -PI / 2, 0), mirror)
	model("bed_double", Vector3(22.75, 0, 12.9), -PI / 2)
	solid(Vector3(2.2, 0.5, 1.8), Vector3(22.75, 0.25, 12.9))
	model("wardrobe", Vector3(19.4, 0, 10.6), PI / 2)
	solid(Vector3(0.7, 2.0, 1.1), Vector3(19.4, 1.0, 10.6))
	model("dresser", Vector3(21.2, 0, 14.7), PI)
	solid(Vector3(1.4, 0.9, 0.5), Vector3(21.2, 0.45, 14.7))
	for i in 8:
		box(Vector3(0.32, 0.22 * (i + 1), 1.4), Vector3(3.0 - i * 0.32, 0.11 * (i + 1), 14.2), Tex.mat("wood"), i == 0)
	rects.append(Rect2(0.45, 13.45, 2.75, 1.5))
	model("dresser", Vector3(6.2, 0, 8.33))
	solid(Vector3(1.4, 0.9, 0.5), Vector3(6.2, 0.45, 8.33))
	# tapes and pickups
	items["tape1"] = _tape("1", "VEČERA", Vector3(4.35, 0.457, 3.15), real_g)
	add_inter(Vector3(4.35, 0.46, 3.15), 2.0, func(): return S.world == "real" and items["tape1"].visible, func(): return "Vziať kazetu 1 · VEČERA",
		func():
			items["tape1"].visible = false
			S.flags.tape1 = true
			play("click"))
	items["tape2"] = _tape("2", "NARODENINY", Vector3(9.85, 0.53, 12.3), real_g)
	add_inter(Vector3(9.85, 0.53, 12.3), 2.0, func(): return S.world == "real" and items["tape2"].visible, func(): return "Vziať kazetu 2 · NARODENINY",
		func():
			items["tape2"].visible = false
			S.flags.tape2 = true
			play("click"))
	for bp in [Vector3(12.0, 0.957, 0.35), Vector3(14.5, 0.82, 6.3)]:
		var bat := box(Vector3(0.06, 0.035, 0.08), bp, Tex.flat(Color(0.75, 0.38, 0.1), 0.4), false, real_g)
		add_inter(bp, 2.0, func(): return S.world == "real" and bat.visible, func(): return "Vziať batérie",
			func():
				bat.visible = false
				S.batt = minf(100.0, S.batt + 40.0)
				play("click"))
	# doors as interactables
	for id in ["lk", "kh", "kid", "bath", "bed", "study", "stor", "front"]:
		var d = doors[id]
		add_inter(Vector3(d.x, 1.0, d.z), 1.9, func(): return true, func(): return _door_label(id), func(): _door_use(id))
	# memory world: dinner and the key
	for p in [Vector3(12.5, 0.785, 3.25), Vector3(12.0, 0.785, 3.6), Vector3(13.0, 0.785, 3.6), Vector3(12.5, 0.785, 3.95)]:
		cyl(0.13, 0.1, 0.02, p, Tex.mat("ceramic"), mem_g)
	var key := box(Vector3(0.06, 0.008, 0.02), Vector3(10.2, 0.93, 0.4), Tex.mat("brass"), false, mem_g)
	items["key"] = key
	add_inter(Vector3(10.2, 0.93, 0.4), 2.0, func(): return S.world == "t1" and key.visible, func(): return "Vziať kľúč od detskej izby",
		func():
			key.visible = false
			S.flags.key = true
			play("click")
			objective("Vráť sa k televízoru.")
			S.can_exit = true
			say("MAMA", "Ešte jeden tanier. Pre hosťa.", 2.8))


func _tape(big: String, small: String, pos: Vector3, parent: Node) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	box(Vector3(0.19, 0.026, 0.105), Vector3.ZERO, Tex.flat(Color(0.06, 0.06, 0.06), 0.4), false, g)
	box(Vector3(0.16, 0.002, 0.06), Vector3(0, 0.014, 0), Tex.flat(Color(0.9, 0.86, 0.77), 0.85), false, g)
	var l := Label3D.new()
	l.text = big + "  " + small
	l.font = f_mark
	l.font_size = 22
	l.pixel_size = 0.0012
	l.modulate = Color(0.1, 0.08, 0.06)
	l.rotation.x = -PI / 2
	l.position = Vector3(0, 0.0156, 0)
	l.shaded = true
	g.add_child(l)
	return g


# =====================================================================
# People
# =====================================================================


var host_head: Node3D
var lucia_head: Node3D
func _build_people() -> void:
	var mama := model("mama", Vector3(12.5, 0, 2.86), 0.0, mem_g)
	var otec := model("otec", Vector3(11.4, 0, 3.6), PI / 2, mem_g)
	var lucia := model("lucia", Vector3(13.6, 0, 3.6), -PI / 2, mem_g)
	family = [mama, otec, lucia]
	lucia_head = lucia.find_child("head", true, false)
	host = model("m_host", Vector3.ZERO, 0.0, self)
	host_head = host.find_child("head", true, false)
	host.visible = false
	angel = model("m_host", Vector3.ZERO, 0.0, self)
	angel.visible = false
	a_host = AudioStreamPlayer3D.new()
	a_host.stream = sfx.drone
	a_host.volume_db = -6
	a_host.unit_size = 3.0
	host.add_child(a_host)


# =====================================================================
# Player
# =====================================================================
func _build_player() -> void:
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.25
	sh.height = 1.6
	cs.shape = sh
	cs.position.y = 0.9
	player.add_child(cs)
	add_child(player)
	head = Node3D.new()
	head.position.y = 1.6
	player.add_child(head)
	cam = Camera3D.new()
	cam.fov = 72
	cam.near = 0.04
	head.add_child(cam)
	flash = SpotLight3D.new()
	flash.light_color = Color(1.0, 0.94, 0.84)
	flash.light_energy = 0.0
	flash.spot_range = 18.0
	flash.spot_angle = 26.0
	flash.spot_angle_attenuation = 1.6
	flash.shadow_enabled = true
	flash.light_cull_mask = 1
	flash.light_volumetric_fog_energy = 2.2
	flash.position = Vector3(0.15, -0.15, -0.1)
	cam.add_child(flash)
	torch = Node3D.new()
	torch.position = TORCH_REST
	torch.rotation = Vector3(0.05, 0.1, 0)
	torch.scale = Vector3.ONE * 1.25
	cam.add_child(torch)
	no_shadow(model("hand_flashlight", Vector3.ZERO, 0.0, torch))
	# soft fill so the hand is readable in the dark
	hand_light = OmniLight3D.new()
	hand_light.position = Vector3(-0.08, 0.12, 0.05)
	hand_light.light_color = Color(0.9, 0.85, 0.8)
	hand_light.light_energy = 0.25
	hand_light.omni_range = 0.6
	hand_light.light_cull_mask = 1 << 1
	torch.add_child(hand_light)
	for c in torch.find_children("*", "GeometryInstance3D", true, false):
		c.layers = 1 << 1
	torch.visible = false
	# dust in the flashlight beam
	var dust := GPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 4, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3, 1.5, 3)
	pm.gravity = Vector3(0, -0.01, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.05
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	dust.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.012)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.9, 0.88, 0.8)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color.a = 0.6
	qm.material = dm
	dust.draw_pass_1 = qm
	dust.local_coords = false
	head.add_child(dust)
	a_breath = AudioStreamPlayer.new()
	a_breath.stream = sfx.whisper
	a_breath.volume_db = -80
	add_child(a_breath)


func spawn(p: Vector3, yaw: float) -> void:
	player.position = Vector3(p.x, 0, p.z)
	S.yaw = yaw
	S.pitch = 0.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and S.running and not S.busy:
		S.yaw -= e.relative.x * 0.0022 * sens
		torch_sway += e.relative * 0.00012
		S.pitch = clampf(S.pitch - e.relative.y * 0.0022 * sens, -1.35, 1.35)
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_ESCAPE and S.running and not S.dead:
			_toggle_pause()
		elif not S.running or S.paused:
			return
		elif e.physical_keycode == KEY_E:
			_act()
		elif e.physical_keycode == KEY_F:
			_toggle_flash()
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and S.running and not S.paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_act()


func _toggle_flash() -> void:
	if S.busy:
		return
	if not S.flash and S.batt <= 0.0:
		say("", "Baterka je vybitá.", 2.0)
		return
	S.flash = not S.flash
	play("click")


func _move_player(dt: float) -> void:
	var f := 0.0
	var s := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): f += 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): f -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): s += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): s -= 1
	var mag := Vector2(f, s).length()
	if mag > 1.0:
		f /= mag; s /= mag
	var want_run := Input.is_physical_key_pressed(KEY_SHIFT) and mag > 0.1
	if S.tired and S.stam > 45.0:
		S.tired = false
	var run: bool = want_run and not S.tired and S.stam > 0.0
	if run:
		S.stam -= dt * 19.0
		if S.stam <= 0.0:
			S.stam = 0.0
			S.tired = true
	else:
		S.stam = minf(100.0, S.stam + dt * (11.0 if mag > 0.1 else 20.0))
	var sp: float = (3.5 if run else (1.4 if S.tired else 1.9)) * minf(1.0, mag)
	var fw := Vector3(-sin(S.yaw), 0, -cos(S.yaw))
	var rt := Vector3(cos(S.yaw), 0, -sin(S.yaw))
	player.velocity = (fw * f + rt * s) * sp
	var before := player.position
	player.move_and_slide()
	player.position.y = 0
	var moved := (player.position - before).length()
	S.bob += moved * (3.2 if run else 3.6)
	S.step_acc += moved
	if S.step_acc > (0.85 if run else 0.7):
		S.step_acc = 0.0
		play("step", -4.0 if run else -9.0, randf_range(0.85, 1.15))


# =====================================================================
# Interactions
# =====================================================================
func add_inter(pos: Vector3, r: float, cond: Callable, label: Callable, use: Callable) -> void:
	inter.append({"pos": pos, "r": r, "cond": cond, "label": label, "use": use})


func _pick() -> void:
	cur = null
	if S.busy:
		return
	var cp := cam.global_position
	var fw := -cam.global_transform.basis.z
	var best = null
	var bs := 1e9
	var space := get_world_3d().direct_space_state
	for o in inter:
		if not o.cond.call():
			continue
		var v: Vector3 = o.pos - cp
		var d := v.length()
		if d > o.r:
			continue
		var a := acos(clampf(v.normalized().dot(fw), -1.0, 1.0))
		if a > atan(0.3 / maxf(0.3, d)) + 0.1:
			continue
		var q := PhysicsRayQueryParameters3D.create(cp, o.pos - v.normalized() * 0.15)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			continue
		if a < bs:
			bs = a
			best = o
	if best:
		var lbl = best.label.call()
		if lbl:
			cur = {"o": best, "lbl": lbl}


func _act() -> void:
	if S.busy or S.dead or not cur:
		return
	cur.o.use.call()


func _door_label(id: String) -> String:
	var d = doors[id]
	if d.locked:
		if id == "kid" and S.flags.get("key", false) and S.world == "real":
			return "Odomknúť kľúčom"
		return "Zamknuté"
	return "Zavrieť" if d.open else "Otvoriť"


func _door_use(id: String) -> void:
	var d = doors[id]
	if d.locked:
		if id == "kid" and S.flags.get("key", false) and S.world == "real":
			d.locked = false
			S.flags.kid_open = true
			play("click")
			await get_tree().create_timer(0.45).timeout
			set_door(id, true)
			play("creak", -6.0)
			return
		play("click")
		say("", "Zamknuté. Zvonka." if id == "front" else "Zamknuté.", 2.0)
		return
	set_door(id, not d.open)
	play("creak", -6.0)


func _tv_label():
	if S.world == "real":
		if S.inserted and S.can_enter:
			return "Vojsť do televízora"
		if S.inserted:
			return null
		if S.flags.get("tape1", false) and not S.flags.get("used1", false):
			return "Vložiť kazetu do videa"
		return null
	return "Vystúpiť z kazety" if S.can_exit else "Ešte nemôžeš odísť"


func _tv_use() -> void:
	if S.world == "real":
		if S.inserted and S.can_enter:
			_enter_tape()
		elif S.flags.get("tape1", false) and not S.flags.get("used1", false):
			S.flags.used1 = true
			S.inserted = true
			play("click")
			objective("")
			say("MAMA", "Sadni si, jedlo vychladne.", 2.6)
			say("OTEC", "Kto zase nechal otvorenú pivnicu?", 2.8)
			say("LUCIA", "To nebol on. To bol ten pán.", 3.0)
			await get_tree().create_timer(8.0).timeout
			S.can_enter = true
			objective("Obraz ťa ťahá dnu.")
	elif S.can_exit:
		_exit_tape()


# =====================================================================
# Tape worlds
# =====================================================================
func static_to(fn: Callable, ms := 900) -> void:
	S.busy = true
	play("stinger", -14.0, 2.0)
	var tw := create_tween()
	tw.tween_method(func(v): post.set_shader_parameter("stat", v), 0.0, 1.0, ms / 1000.0 * 0.6)
	await tw.finished
	fn.call()
	await get_tree().create_timer(0.25).timeout
	var tw2 := create_tween()
	tw2.tween_method(func(v): post.set_shader_parameter("stat", v), 1.0, 0.0, ms / 1000.0)
	await tw2.finished
	S.busy = false


func _enter_tape() -> void:
	await static_to(func():
		S.inserted = false
		S.can_enter = false
		S.can_exit = false
		_set_world("t1")
		spawn(Vector3(4.5, 0, 1.7), PI)
		ang_s.on = true
		ang_s.idx = 0
		angel.visible = true
		angel.position = Vector3(22.5, 0, 7.5)
		set_door("kid", false, true)
		objective("Rodina večeria v kuchyni."))


func _exit_tape() -> void:
	await static_to(func():
		ang_s.on = false
		angel.visible = false
		_set_world("real")
		spawn(Vector3(4.5, 0, 1.7), PI)
		S.flags.done_t1 = true)


func _update_angel(dt: float) -> void:
	if not ang_s.on or S.world != "t1":
		return
	angel.look_at(Vector3(player.position.x, angel.position.y, player.position.z), Vector3.UP, true)
	if not S.flags.get("t1_kitchen", false) and player.position.x > 9 and player.position.z < 6:
		S.flags.t1_kitchen = true
		objective("Nájdi kľúč od detskej izby.")
		say("LUCIA", "On ťa vidí.", 2.6)
	if S.flags.get("t1_kitchen", false):
		var sh: Node3D = lucia_head
		var to: Vector3 = player.position - family[2].position
		var target: float = atan2(to.x, to.z) - family[2].rotation.y
		sh.rotation.y = lerp_angle(sh.rotation.y, clampf(wrapf(target, -PI, PI), -1.3, 1.3), dt * 2.0)
	if S.flags.get("key", false):
		var v := (angel.position - player.position)
		v.y = 0
		var fw := Vector3(-sin(S.yaw), 0, -cos(S.yaw))
		var in_view := v.normalized().dot(fw) > 0.45
		var P := [Vector3(22.5, 0, 7.5), Vector3(19.7, 0, 7.45), Vector3(16.5, 0, 7.3), Vector3(13.6, 0, 7.3), Vector3(10.2, 0, 7.3)]
		ang_s.away = 0.0 if in_view else ang_s.away + dt
		if ang_s.away > 1.1 and ang_s.idx < P.size() - 1:
			ang_s.idx += 1
			ang_s.away = 0.0
			angel.position = P[ang_s.idx]
			play("step", -2.0, 0.6)


# =====================================================================
# Host (stalker): moves only when unseen
# =====================================================================
func _build_nav() -> void:
	nav.resize(NW * NH)
	for j in NH:
		for i in NW:
			var x := (i + 0.5) * NS
			var z := (j + 0.5) * NS
			var solid := 0
			for r in rects:
				var rr: Rect2 = r
				var thin := rr.size.x < 0.3 or rr.size.y < 0.3
				if thin:
					if x - 0.25 < rr.end.x and x + 0.25 > rr.position.x and z - 0.25 < rr.end.y and z + 0.25 > rr.position.y:
						solid = 1
						break
				elif x > rr.position.x - 0.12 and x < rr.end.x + 0.12 and z > rr.position.y - 0.12 and z < rr.end.y + 0.12:
					solid = 1
					break
			for id in doors:
				var d = doors[id]
				if absf(x - d.x) < 0.6 and absf(z - d.z) < 0.6:
					solid = 0
			nav[i + j * NW] = solid


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(p.x / NS), 0, NW - 1), clampi(int(p.z / NS), 0, NH - 1))


func _nav_solid(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= NW or j >= NH:
		return true
	if nav[i + j * NW] == 1:
		return true
	var x := (i + 0.5) * NS
	var z := (j + 0.5) * NS
	for id in doors:
		var d = doors[id]
		if d.locked and not d.open and absf(x - d.x) < 0.6 and absf(z - d.z) < 0.6:
			return true
	for k in S.lit:
		if S.lit[k] and _room_rect(k).grow(0.3).has_point(Vector2(x, z)):
			return true
	return false


func _room_rect(k: String) -> Rect2:
	match k:
		"living": return Rect2(0, 0, 9, 8)
		"kitchen": return Rect2(9, 0, 7, 6)
		"kid": return Rect2(9, 9, 6, 6)
	return Rect2()


func _bfs(from: Vector3, to: Vector3) -> Array:
	var s := _cell(from)
	var t := _cell(to)
	var prev := {}
	var q := [s]
	prev[s] = s
	var head_i := 0
	while head_i < q.size():
		var c: Vector2i = q[head_i]
		head_i += 1
		if c == t:
			break
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if prev.has(n) or _nav_solid(n.x, n.y):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(t):
		return []
	var path := []
	var c2: Vector2i = t
	while c2 != s:
		path.push_front(Vector3((c2.x + 0.5) * NS, 0, (c2.y + 0.5) * NS))
		c2 = prev[c2]
	return path


func _seen_by_player(p: Vector3) -> bool:
	var v := p - player.position
	v.y = 0
	var d := v.length()
	if d > 22:
		return false
	var fw := Vector3(-sin(S.yaw), 0, -cos(S.yaw))
	if v.normalized().dot(fw) < cos(0.62):
		return false
	return _los(cam.global_position, p + Vector3(0, 1.6, 0))


func _los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _safe() -> bool:
	if S.world != "real":
		return false
	for k in S.lit:
		if S.lit[k] and _room_rect(k).grow(-0.15).has_point(Vector2(player.position.x, player.position.z)):
			return true
	return false


func _update_host(dt: float) -> void:
	if not host_s.active or S.world != "real":
		host.visible = false
		return
	host_s.cool = maxf(0.0, host_s.cool - dt)
	if host_s.cool > 0.0:
		host.visible = false
		return
	host.visible = true
	var hp: Vector3 = host.position
	var d := Vector2(hp.x - player.position.x, hp.z - player.position.z).length()
	host.look_at(Vector3(player.position.x, hp.y, player.position.z), Vector3.UP, true)
	# flashlight rule: light him and he kills you
	if S.flash and flash.light_energy > 1.0 and not _safe():
		var v := (hp + Vector3(0, 1.5, 0) - cam.global_position)
		var fw := -cam.global_transform.basis.z
		if v.length() < 13 and v.normalized().dot(fw) > cos(0.38) and _los(cam.global_position, hp + Vector3(0, 1.5, 0)):
			host_s.lit += dt
			if host_s.lit > 0.2 and not host_s.warned:
				host_s.warned = true
				S.flick = 0.7
				play("heart", 0.0)
			if host_s.lit > 1.0:
				_die("Hosť nesmie vidieť svetlo.")
				return
		else:
			host_s.lit = maxf(0.0, host_s.lit - dt * 2.0)
	if _seen_by_player(hp):
		host_head.rotation.z = 0.28 + sin(S.time * 2.0) * 0.08
	else:
		host_s.path_t -= dt
		if host_s.path_t <= 0.0:
			host_s.path_t = 0.45
			host_s.path = _bfs(hp, player.position)
		if host_s.path.size() > 0:
			var n: Vector3 = host_s.path[0]
			if Vector2(n.x - hp.x, n.z - hp.z).length() < 0.3:
				host_s.path.pop_front()
			else:
				var dir := Vector3(n.x - hp.x, 0, n.z - hp.z).normalized()
				host.position += dir * 2.35 * dt
				host_s.walk += dt * 6.0
		for id in doors:
			var dd = doors[id]
			if not dd.open and not dd.locked and Vector2(dd.x - hp.x, dd.z - hp.z).length() < 0.95:
				set_door(id, true)
				play("creak", -8.0)
	if d > 15.0:
		host_s.far_t += dt
		if host_s.far_t > 4.0:
			host_s.far_t = 0.0
			_teleport_host_near()
	else:
		host_s.far_t = 0.0
	a_host.volume_db = linear_to_db(clampf(0.25 - d * 0.02, 0.001, 1.0))
	if d < 0.85 and not _safe():
		_damage(40, "Hosť")
		host_s.cool = 14.0
		_teleport_host_far()


func _teleport_host_near() -> void:
	for k in 40:
		var p := Vector3(randf_range(1, 23), 0, randf_range(1, 14))
		var c := _cell(p)
		if _nav_solid(c.x, c.y):
			continue
		var d := Vector2(p.x - player.position.x, p.z - player.position.z).length()
		if d > 7 and d < 11 and not _seen_by_player(p):
			host.position = p
			return


func _teleport_host_far() -> void:
	var best := Vector3(22.5, 0, 7.5)
	var bd := 0.0
	for p in [Vector3(22.5, 0, 7.5), Vector3(2, 0, 1.8), Vector3(20.5, 0, 13.5), Vector3(13.5, 0, 13.2), Vector3(2, 0, 10.5)]:
		var d := Vector2(p.x - player.position.x, p.z - player.position.z).length()
		if d > bd:
			bd = d
			best = p
	host.position = best


func _damage(n: float, who: String) -> void:
	if S.dead:
		return
	S.hp = maxf(0.0, S.hp - n)
	S.hurt_t = 0.0
	S.shake = 0.9
	play("stinger", -6.0, 1.4)
	S.dmg = 1.0
	if S.hp <= 0.0:
		_die(who + " ťa dostal.")


func _die(text: String) -> void:
	if S.dead:
		return
	S.dead = true
	S.busy = true
	play("stinger", 0.0)
	post.set_shader_parameter("glitch", 1.0)
	S.shake = 1.2
	await get_tree().create_timer(1.3).timeout
	post.set_shader_parameter("glitch", 0.0)
	ui.death_text.text = text
	ui.death.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _retry() -> void:
	ui.death.visible = false
	S.dead = false
	S.busy = false
	S.hp = 100.0
	S.flash = false
	spawn(Vector3(4.5, 0, 6.3), 0.0)
	host_s.cool = 10.0
	_teleport_host_far()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# =====================================================================
# Audio
# =====================================================================
func _build_audio() -> void:
	sfx.step = Synth.step()
	sfx.heart = Synth.heart()
	sfx.click = Synth.click()
	sfx.creak = Synth.creak()
	sfx.stinger = Synth.stinger()
	sfx.shriek = Synth.shriek()
	sfx.whisper = Synth.whisper()
	sfx.moan = Synth.moan()
	sfx.drone = Synth.drone()
	sfx.static = Synth.static_noise()
	sfx.music = Synth.music_box()
	a_drone = AudioStreamPlayer.new()
	a_drone.stream = sfx.drone
	a_drone.volume_db = -14
	add_child(a_drone)
	a_music = AudioStreamPlayer.new()
	a_music.stream = sfx.music
	a_music.volume_db = -16
	add_child(a_music)
	a_tv = AudioStreamPlayer3D.new()
	a_tv.stream = sfx.static
	a_tv.volume_db = -10
	a_tv.unit_size = 2.0
	a_tv.position = Vector3(4.5, 0.9, 1.0)
	add_child(a_tv)


func play(name: String, db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sfx[name]
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# =====================================================================
# UI
# =====================================================================
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


func _build_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	var pr := ColorRect.new()
	pr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/vhs.gdshader")
	pr.material = post
	post_layer.add_child(pr)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)
	ui.hud = hud
	ui.day = _label(hud, "DEŇ 1", _ls(f_osd, 34), Vector4(0.015, 0.02, 0.4, 0.08), HORIZONTAL_ALIGNMENT_LEFT)
	ui.hp = _label(hud, "ŽIVOT 100", _ls(f_ui, 12, Color(0.8, 0.35, 0.3)), Vector4(0.015, 0.08, 0.4, 0.11), HORIZONTAL_ALIGNMENT_LEFT)
	ui.batt = _label(hud, "BATERKA 90 %", _ls(f_ui, 12, Color(0.6, 0.58, 0.54)), Vector4(0.6, 0.93, 0.985, 0.97), HORIZONTAL_ALIGNMENT_RIGHT)
	ui.hp.visible = false
	ui.batt.visible = false
	var bars := Control.new()
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_hud.bind(bars))
	hud.add_child(bars)
	ui.bars = bars
	ui.obj = _label(hud, "", _ls(f_ui, 15), Vector4(0.25, 0.02, 0.75, 0.09))
	ui.prompt = _label(hud, "", _ls(f_ui, 17), Vector4(0.3, 0.53, 0.7, 0.58))
	ui.sub = _label(hud, "", _ls(f_ui, 21), Vector4(0.15, 0.78, 0.85, 0.9))
	ui.msg = _label(hud, "", _ls(f_ui, 32), Vector4(0.1, 0.3, 0.9, 0.42))
	ui.safe = _label(hud, "", _ls(f_ui, 12, Color(1.0, 0.84, 0.47)), Vector4(0.015, 0.11, 0.4, 0.14), HORIZONTAL_ALIGNMENT_LEFT)
	var dot := ColorRect.new()
	dot.color = Color(0.92, 0.9, 0.86, 0.5)
	dot.size = Vector2(4, 4)
	dot.anchor_left = 0.5; dot.anchor_top = 0.5; dot.anchor_right = 0.5; dot.anchor_bottom = 0.5
	dot.offset_left = -2; dot.offset_top = -2; dot.offset_right = 2; dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	ui.dot = dot
	var osd := Control.new()
	osd.set_anchors_preset(Control.PRESET_FULL_RECT)
	osd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(osd)
	_label(osd, "PLAY ▶", _ls(f_osd, 40), Vector4(0.7, 0.03, 0.97, 0.1), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(osd, "PM 7:42\nOKT. 14 1998", _ls(f_osd, 40), Vector4(0.02, 0.8, 0.5, 0.97), HORIZONTAL_ALIGNMENT_LEFT)
	ui.osd = osd
	hud.visible = false
	# overlays
	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	_build_title(top)
	ui.pause = _panel(top, Color(0, 0, 0, 0.8))
	_label(ui.pause, "PAUZA", _ls(f_osd, 64), Vector4(0.1, 0.3, 0.9, 0.45))
	_button(ui.pause, "▶  POKRAČOVAŤ", Vector4(0.38, 0.5, 0.62, 0.58), _toggle_pause)
	_button(ui.pause, "UKONČIŤ", Vector4(0.42, 0.61, 0.58, 0.68), func(): get_tree().quit())
	ui.pause.visible = false
	ui.death = _panel(top, Color(0.02, 0, 0, 0.92))
	_label(ui.death, "KONIEC", _ls(f_osd, 72, Color(1, 0.3, 0.22)), Vector4(0.1, 0.28, 0.9, 0.42))
	ui.death_text = _label(ui.death, "", _ls(f_ui, 18, Color(0.7, 0.66, 0.6)), Vector4(0.1, 0.43, 0.9, 0.5))
	_button(ui.death, "↻  SKÚSIŤ ZNOVA", Vector4(0.38, 0.56, 0.62, 0.64), _retry)
	ui.death.visible = false
	ui.end = _panel(top, Color(0.02, 0.02, 0.025, 0.96))
	_label(ui.end, "KONIEC DEMA", _ls(f_osd, 80), Vector4(0.1, 0.22, 0.9, 0.38))
	_label(ui.end, "Kazeta 2 leží v tvojej ruke. Na páske je narodeninová oslava.\nV plnej hre ťa čaká ešte 6 nocí, 6 príšer a 3 konce.", _ls(f_type, 20, Color(0.75, 0.71, 0.64)), Vector4(0.12, 0.4, 0.88, 0.56))
	_button(ui.end, "UKONČIŤ", Vector4(0.42, 0.66, 0.58, 0.74), func(): get_tree().quit())
	ui.end.visible = false
	ui.card = _panel(top, Color(0, 0, 0, 1))
	_label(ui.card, "DEŇ 1", _ls(f_osd, 110), Vector4(0.1, 0.35, 0.9, 0.5))
	_label(ui.card, "N Á V R A T", _ls(f_ui, 14, Color(0.55, 0.52, 0.47)), Vector4(0.1, 0.5, 0.9, 0.55))
	ui.card.visible = false


# =====================================================================
# Title screen: Blender-modelled forest clearing with an old TV
# =====================================================================
var menu_root: Node3D
var menu_cam: Camera3D
var menu_moon: DirectionalLight3D
var menu_tv_light: OmniLight3D
var menu_screen_mat: ShaderMaterial
var menu_static: AudioStreamPlayer
var menu_on := false
var menu_glitch := 0.0
const MENU_AT := Vector3(200, 0, 200)


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
	menu_static.stream = sfx.static
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
	b.mouse_entered.connect(func(): play("click", -18.0, 0.7))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


var f_title: Font
var f_title_ui: Font
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
	_menu_button(menu, "NOVÁ HRA", _start)
	_menu_button(menu, "PRÍŠERY", func(): _gallery_show(true))
	_menu_button(menu, "NASTAVENIA", func(): ui.menu.visible = false; ui.settings.visible = true)
	_menu_button(menu, "KONIEC", func(): get_tree().quit())
	_label(root, "DEMO  ·  DEŇ 1", _ls(f_ui, 12, Color(0.55, 0.52, 0.47)), Vector4(0.06, 0.9, 0.5, 0.94), HORIZONTAL_ALIGNMENT_LEFT)
	_label(root, "WASD pohyb · myš · E použiť · F baterka · Shift beh · Esc pauza", _ls(f_ui, 12, Color(0.45, 0.43, 0.4)), Vector4(0.55, 0.9, 0.97, 0.94), HORIZONTAL_ALIGNMENT_RIGHT)
	# settings
	var st := VBoxContainer.new()
	st.anchor_left = 0.06
	st.anchor_top = 0.48
	st.anchor_right = 0.36
	st.anchor_bottom = 0.9
	st.add_theme_constant_override("separation", 8)
	st.visible = false
	root.add_child(st)
	ui.settings = st
	var add_slider := func(title: String, v: float, cb: Callable) -> void:
		var l := Label.new()
		l.text = title
		l.label_settings = _ls(f_title_ui, 20, Color(0.8, 0.78, 0.74))
		st.add_child(l)
		var hs := HSlider.new()
		hs.min_value = 0.0
		hs.max_value = 1.0
		hs.step = 0.01
		hs.value = v
		hs.custom_minimum_size = Vector2(0, 22)
		hs.value_changed.connect(cb)
		st.add_child(hs)
	add_slider.call("HLASITOSŤ", 0.8, func(v): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001))))
	add_slider.call("CITLIVOSŤ MYŠI", 0.5, func(v): sens = 0.3 + v * 1.4)
	var fs := CheckButton.new()
	fs.text = "Celá obrazovka"
	fs.add_theme_font_override("font", f_title_ui)
	fs.add_theme_font_size_override("font_size", 20)
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	st.add_child(fs)
	_menu_button(st, "SPÄŤ", func(): ui.settings.visible = false; ui.menu.visible = true)
	AudioServer.set_bus_volume_db(0, linear_to_db(0.8))


func _show_menu() -> void:
	menu_on = true
	menu_root.visible = true
	menu_moon.visible = true
	moon.visible = false
	menu_cam.make_current()
	ui.title.visible = true
	ui.menu.visible = true
	ui.settings.visible = false
	ui.hud.visible = false
	post.set_shader_parameter("vhs", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	a_drone.play()
	menu_static.play()


func _hide_menu() -> void:
	menu_on = false
	menu_root.visible = false
	menu_moon.visible = false
	moon.visible = true
	cam.make_current()
	ui.title.visible = false
	menu_static.stop()


# =====================================================================
# Gallery of monsters (models from blender/build_monsters.py)
# =====================================================================
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
	play("stinger", -22.0, 1.6)


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
		play("stinger", -30.0, 2.4)
	menu_screen_mat.set_shader_parameter("glitch", menu_glitch)
	menu_tv_light.light_energy = (2.0 + randf() * 0.5) * (0.25 if menu_glitch > 0.5 and randf() < 0.5 else 1.0)


var hud_hp := 100.0
var hud_batt := 90.0
var hud_flash_hp := 0.0


func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI / 6.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_hud(c: Control) -> void:
	var white := Color(0.95, 0.94, 0.9, 0.92)
	var dim := Color(0.95, 0.94, 0.9, 0.35)
	var base := Vector2(46, c.size.y - 118)
	var font: Font = f_title_ui if f_title_ui else f_ui
	var rows := [["hp", hud_hp / 100.0, str(int(round(hud_hp)))], ["batt", hud_batt / 100.0, "%d %%" % int(round(hud_batt))]]
	for i in rows.size():
		var kind: String = rows[i][0]
		var v: float = clampf(rows[i][1], 0.0, 1.0)
		var ctr := base + Vector2(i * 22, i * 60)
		var low := v < 0.25
		var accent := Color(0.95, 0.25, 0.2, 0.95) if low else white
		if kind == "hp" and hud_flash_hp > 0.0:
			accent = Color(1, 0.2, 0.15, 0.95).lerp(white, 1.0 - hud_flash_hp)
		# hexagon badge
		var hx := _hex(ctr, 25)
		c.draw_colored_polygon(hx, Color(0.03, 0.03, 0.04, 0.6))
		c.draw_polyline(hx, accent, 2.5, true)
		c.draw_polyline(_hex(ctr, 30), Color(accent.r, accent.g, accent.b, 0.25), 1.5, true)
		# icon
		if kind == "hp":
			var heart := PackedVector2Array()
			for k in 40:
				var t := k / 40.0 * TAU
				heart.append(ctr + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 0.82 + Vector2(0, -1))
			c.draw_colored_polygon(heart, accent)
		else:
			var r := Rect2(ctr + Vector2(-13, -8), Vector2(23, 16))
			c.draw_rect(r, accent, false, 2.0, true)
			c.draw_rect(Rect2(ctr + Vector2(10, -4), Vector2(4, 8)), accent, true, -1.0, true)
			c.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * v, r.size.y - 6)), accent, true, -1.0, true)
		# bar with a slanted end, like a gauge
		var bp := ctr + Vector2(38, -12)
		var bw := 230.0
		var bh := 24.0
		var frame := PackedVector2Array([bp, bp + Vector2(bw, 0), bp + Vector2(bw - 8, bh), bp + Vector2(0, bh), bp])
		c.draw_colored_polygon(frame, Color(0.03, 0.03, 0.04, 0.45))
		c.draw_polyline(frame, dim, 1.5, true)
		var fw := maxf(0.0, (bw - 10) * v)
		if fw > 1.0:
			var fill := PackedVector2Array([bp + Vector2(3, 3), bp + Vector2(3 + fw, 3), bp + Vector2(3 + fw - 6 * minf(1.0, fw / 10.0), bh - 3), bp + Vector2(3, bh - 3)])
			c.draw_colored_polygon(fill, Color(accent.r, accent.g, accent.b, 0.85))
			# tick marks
			var x := 20.0
			while x < fw:
				c.draw_line(bp + Vector2(3 + x, 5), bp + Vector2(3 + x - 3, bh - 5), Color(0, 0, 0, 0.18), 2.0, true)
				x += 20.0
		var txt: String = rows[i][2]
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 20)
		var tp := bp + Vector2(bw - 16 - ts.x, bh - 4)
		c.draw_string(font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.6))
		c.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.08, 0.08, 0.09) if fw > bw - 60 else white)


func _panel(parent: Node, col: Color) -> ColorRect:
	var p := ColorRect.new()
	p.color = col
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)
	return p


func _button(parent: Control, text: String, anchor: Vector4, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", f_osd)
	b.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.105, 0.1)
	sb.border_color = Color(0.3, 0.28, 0.26)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.border_color = Color(1, 0.3, 0.23)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.anchor_left = anchor.x; b.anchor_top = anchor.y; b.anchor_right = anchor.z; b.anchor_bottom = anchor.w
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func objective(t: String) -> void:
	ui.obj.text = t.to_upper()


func say(who: String, text: String, d := 2.6) -> void:
	sub_q.append([who, text, d])


func show_msg(t: String, d := 3.0) -> void:
	ui.msg.text = t
	msg_t = d


func _toggle_pause() -> void:
	if not S.running or S.dead:
		return
	S.paused = not S.paused
	ui.pause.visible = S.paused
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if S.paused else Input.MOUSE_MODE_CAPTURED


# =====================================================================
# Flow
# =====================================================================
func _show_title() -> void:
	spawn(Vector3(6.5, 0, 6.8), 0.6)
	S.lit = {"living": true}
	_set_world("real")
	_show_menu()

func _start() -> void:
	_hide_menu()
	S.lit = {}
	_set_world("real")
	ui.card.visible = true
	post.set_shader_parameter("fade", 1.0)
	spawn(Vector3(1.4, 0, 11.5), -PI / 2)
	await get_tree().create_timer(2.4).timeout
	ui.card.visible = false
	ui.hud.visible = true
	S.running = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	a_tv.play()
	var tw := create_tween()
	tw.tween_method(func(v): post.set_shader_parameter("fade", v), 1.0, 0.0, 1.8)
	_day1()


func _wait_until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame


func _day1() -> void:
	await get_tree().create_timer(1.5).timeout
	objective("Choď do obývačky.")
	await _wait_until(func(): return player.position.x < 9 and player.position.z < 8)
	objective("Na stolíku leží kazeta.")
	await _wait_until(func(): return S.flags.get("tape1", false))
	objective("Vlož kazetu do televízora.")
	await _wait_until(func(): return S.flags.get("done_t1", false) and S.world == "real" and not S.busy)
	show_msg("Kľúč z kazety máš stále v ruke.", 3.5)
	objective("Odomkni detskú izbu.")
	await _wait_until(func(): return player.position.x > 11 and player.position.z > 6 and player.position.z < 9)
	# the Host appears at the end of the hall
	show_msg("Na konci chodby niekto stojí.", 3.0)
	host.position = Vector3(22.5, 0, 7.5)
	host_s.active = true
	a_host.play()
	play("moan", -6.0)
	await _wait_until(func(): return S.flags.get("kid_open", false))
	objective("Prehľadaj detskú izbu.")
	await _wait_until(func(): return S.flags.get("tape2", false))
	await get_tree().create_timer(1.0).timeout
	S.running = false
	host_s.active = false
	ui.hud.visible = false
	ui.end.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# =====================================================================
# Main loop
# =====================================================================
func _physics_process(dt: float) -> void:
	if S.running and not S.paused and not S.busy and not S.dead:
		_move_player(dt)


func _process(dt: float) -> void:
	if menu_on:
		_menu_process(dt)
	# subtitles
	if sub_t > 0.0:
		sub_t -= dt
	elif sub_q.size() > 0:
		var l: Array = sub_q.pop_front()
		ui.sub.text = (l[0] + "   " if l[0] != "" else "") + l[1]
		sub_t = l[2]
	else:
		ui.sub.text = ""
	if msg_t > 0.0:
		msg_t -= dt
		if msg_t <= 0.0:
			ui.msg.text = ""
	# doors
	for id in doors:
		var d = doors[id]
		var target: float = d.ang if d.open else 0.0
		d.cur = lerpf(d.cur, target, minf(1.0, dt * 4.0))
		d.pv.rotation.y = d.cur
	# camera
	S.shake = maxf(0.0, S.shake - dt * 1.4)
	var sh: float = S.shake * S.shake
	var bob: float = sin(S.bob) * 0.035
	head.position = Vector3(cos(S.bob * 0.5) * 0.02, 1.6 + bob, 0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * sh * 0.06
	player.rotation.y = S.yaw
	head.rotation.x = S.pitch + randf_range(-1, 1) * sh * 0.03
	# flashlight
	S.flick = maxf(0.0, S.flick - dt)
	var fe := 0.0
	if S.flash and S.world == "real":
		fe = 9.0
		if S.batt < 25.0:
			fe *= 0.3 + 0.7 * S.batt / 25.0
		if S.flick > 0.0 and randf() < 0.5:
			fe *= 0.05
	elif S.flash:
		fe = 6.0
	flash.light_energy = fe
	torch.visible = S.running and not S.busy
	torch_sway = torch_sway.lerp(Vector2.ZERO, minf(1.0, dt * 6.0))
	torch_sway = torch_sway.clamp(Vector2(-0.04, -0.04), Vector2(0.04, 0.04))
	var tb := Vector3(sin(S.bob * 0.5) * 0.012, absf(cos(S.bob * 0.5)) * 0.01, 0)
	torch.position = torch.position.lerp(TORCH_REST + tb + Vector3(-torch_sway.x, torch_sway.y, 0), minf(1.0, dt * 12.0))
	hand_light.light_energy = 0.18 if S.flash else 0.06
	tv_light.light_energy = 0.7 + randf() * 0.4
	if not S.running or S.paused:
		return
	S.time += dt
	if S.flash and S.world == "real":
		S.batt = maxf(0.0, S.batt - dt * 0.4)
		if S.batt <= 0.0:
			S.flash = false
			show_msg("Baterka je vybitá.", 3.0)
	S.hurt_t += dt
	if S.hurt_t > 8.0 and S.hp < 100.0:
		S.hp = minf(100.0, S.hp + dt * 2.0)
	S.dmg = maxf(0.35 if S.hp < 35 else 0.0, S.get("dmg", 0.0) - dt * 1.4)
	post.set_shader_parameter("dmg", S.dmg)
	var tired_v: float = 0.85 if S.tired else pow(1.0 - S.stam / 100.0, 2.0) * 0.6
	post.set_shader_parameter("tired", tired_v)
	a_breath.volume_db = linear_to_db(maxf(0.001, (0.5 if S.tired else 0.0) + (1.0 - S.stam / 100.0) * 0.25))
	if not a_breath.playing:
		a_breath.play()
	if S.hp < hud_hp - 0.5:
		hud_flash_hp = 1.0
	hud_flash_hp = maxf(0.0, hud_flash_hp - dt * 1.5)
	hud_hp = lerpf(hud_hp, S.hp, minf(1.0, dt * 6.0))
	hud_batt = lerpf(hud_batt, S.batt, minf(1.0, dt * 6.0))
	ui.bars.queue_redraw()
	ui.hp.text = "ŽIVOT  %d" % int(S.hp)
	ui.batt.text = "BATERKA  %d %%" % int(S.batt)
	ui.safe.text = "☀ SVETLO ŤA CHRÁNI" if _safe() else ""
	if not S.busy and not S.dead:
		_update_angel(dt)
		_update_host(dt)
	_pick()
	ui.prompt.text = ("[E]  " + str(cur.lbl)) if cur else ""
	ui.dot.color.a = 0.95 if cur else 0.45
