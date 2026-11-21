extends Node3D
## Builds the whole control room from primitives at runtime (no external assets):
## walls, lighting, the five stations, live CRT monitors, the cork board with 3D cards and
## strings, the hall window (with a visitor figure) and the phone/fax table.
## `era` restyles the room ("1970s", "1980s") so later decades can reuse it.
##
## Coordinates: the player's eyes are at EYE, yaw 0 looks down -Z. Station anchors are placed
## around the player with their local +Z pointing back at the player.

const Interactable = preload("res://scripts/world/interactable.gd")
const LifeSupportScreen = preload("res://scripts/ui/screens/life_support_screen.gd")
const TerrainMapScreen = preload("res://scripts/ui/screens/terrain_map_screen.gd")
const HelmetCamScreen = preload("res://scripts/ui/screens/helmet_cam_screen.gd")
const PlotScreen = preload("res://scripts/ui/screens/plot_screen.gd")
const CRT_SHADER = preload("res://shaders/crt.gdshader")

const EYE := Vector3(0.0, 1.25, 0.0)
const WALL_R := 3.6
const BOARD_SIZE_2D := Vector2(620.0, 262.0)   # board coordinates used by BoardManager
const BOARD_SIZE_3D := Vector2(1.72, 1.02)
const CARD_COLORS := {
	"report": Color("e8e2cf"), "measurement": Color("d6ecd2"), "photo": Color("c9c9c9"),
	"fax": Color("efe6b8"), "sample": Color("e3cfb8"), "deduction": Color("ff8a8a"),
}

var era := "1970s"
var menu_mode := false
var stations: Array = []
var interactables: Dictionary = {}
var attention_lamps: Dictionary = {}
var attention: Dictionary = {}
var levers: Dictionary = {}
var lever_target: Dictionary = {}
var screen_materials: Array = []
var board_root: Node3D
var visitor: Node3D
var visitor_body: MeshInstance3D
var clock_hour: Node3D
var clock_min: Node3D
var handset: Node3D
var _pal: Dictionary = {}
var _t := 0.0
var _visitor_tween: Tween
var _mats: Dictionary = {}


func _ready() -> void:
	_build()
	if not menu_mode:
		refresh_board()


## Rebuilds the room for another decade.
func set_era(new_era: String) -> void:
	if new_era == era and get_child_count() > 0:
		return
	era = new_era
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()
	refresh_board()


func get_station(station_id: String) -> Dictionary:
	for s in stations:
		if s["id"] == station_id:
			return s
	return {}


# ---------------------------------------------------------------- build

func _build() -> void:
	stations = []
	interactables = {}
	attention_lamps = {}
	levers = {}
	lever_target = {}
	screen_materials = []
	_mats = {}
	_pal = _palette(era)
	_build_environment()
	_build_shell()
	_build_console()
	_build_monitors()
	_build_board()
	_build_window()
	_build_phone()
	_build_props()
	set_crt_enabled(bool(SaveSystem.get_setting("crt_enabled", true)))


func _palette(e: String) -> Dictionary:
	if e == "1980s":
		return {
			"wall": Color("1b2233"), "wainscot": Color("2c3140"), "trim": Color("9b7bff"),
			"floor": Color("22262f"), "ceiling": Color("10141d"), "desk": Color("6a6d73"),
			"equip": Color("b9b4a3"), "panel": Color("2a2f3a"), "phone": Color("c4c0b5"),
			"lamp": Color("dff1ff"), "hall": Color("33405a"),
		}
	return {
		"wall": Color("16203a"), "wainscot": Color("3b2a1e"), "trim": Color("3fe0ff"),
		"floor": Color("1a2236"), "ceiling": Color("0d1424"), "desk": Color("454b59"),
		"equip": Color("8c8670"), "panel": Color("23293a"), "phone": Color("8a2c24"),
		"lamp": Color("ffcf8a"), "hall": Color("2a3550"),
	}


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("04070d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1e2c4d")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("0b1428")
	env.fog_density = 0.025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# dim violet room light from the ceiling
	var amb := OmniLight3D.new()
	amb.position = Vector3(0.0, 2.8, 0.3)
	amb.light_color = Color("9b7bff")
	amb.light_energy = 0.55
	amb.omni_range = 7.0
	add_child(amb)


func _build_shell() -> void:
	# floor & ceiling
	_box(self, Vector3(10, 0.1, 10), Vector3(0, -0.05, 0), _mat(_pal["floor"], 0.95))
	_box(self, Vector3(10, 0.1, 10), Vector3(0, 3.05, 0), _mat(_pal["ceiling"]))
	# 12 wall panels around the player; the panel at -60° is the hall window
	for k in 12:
		var a := float(k) * 30.0
		if k == 10:
			continue
		var n := _anchor(a, WALL_R)
		var w := 2.0 * WALL_R * tan(deg_to_rad(15.0)) + 0.06
		_box(n, Vector3(w, 1.0, 0.1), Vector3(0, 0.5, 0), _mat(_pal["wainscot"], 0.7))
		_box(n, Vector3(w, 2.0, 0.1), Vector3(0, 2.0, 0), _mat(_pal["wall"]))
		_box(n, Vector3(w, 0.04, 0.13), Vector3(0, 1.0, 0), _mat(Color(_pal["trim"]).darkened(0.6)))
	# ceiling light strips (soft emissive)
	for x in [-1.2, 1.2]:
		_box(self, Vector3(0.12, 0.02, 3.0), Vector3(x, 2.99, -0.5), _emit_mat(Color("9b7bff"), 0.4))


# ---------------------------------------------------------------- station 1: console + radio

func _build_console() -> void:
	var n := _anchor(0.0, 0.95)
	var meshes: Array = []
	_box(n, Vector3(2.4, 0.74, 0.6), Vector3(0, 0.37, -0.05), _mat(_pal["desk"], 0.6, 0.3))
	var top := _box(n, Vector3(2.5, 0.06, 0.78), Vector3(0, 0.77, 0), _mat(Color(_pal["desk"]).darkened(0.3), 0.5))
	var panel := _box(n, Vector3(2.2, 0.46, 0.06), Vector3(0, 1.02, -0.27), _mat(_pal["panel"], 0.5, 0.2), Vector3(-25, 0, 0))
	meshes.append_array([top, panel])
	# rows of lit buttons on the slanted panel
	var r := RandomNumberGenerator.new()
	r.seed = 42
	var btn_cols := [UiTheme_amber(), Color("5cffb0"), Color("ff5a5f"), Color("3fe0ff"), Color("e8e2cf")]
	for row in 3:
		for i in 14:
			var c: Color = btn_cols[r.randi_range(0, btn_cols.size() - 1)]
			var lit := r.randf() > 0.35
			var m := _emit_mat(c, 1.6) if lit else _mat(c.darkened(0.6))
			_box(panel, Vector3(0.05, 0.035, 0.02), Vector3(-0.95 + i * 0.145, 0.13 - row * 0.09, 0.035), m)
	# levers: heat / lights / rover / cam
	var lever_cols := {"heat": Color("ff5a5f"), "lights": Color("ffb547"), "rover": Color("3fe0ff"), "cam": Color("5cffb0")}
	var i_lever := 0
	for key in ["heat", "lights", "rover", "cam"]:
		var x := 0.42 + i_lever * 0.17
		_box(n, Vector3(0.1, 0.02, 0.12), Vector3(x, 0.81, 0.18), _mat(Color("222630"), 0.4, 0.6))
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0.82, 0.18)
		n.add_child(pivot)
		_cyl(pivot, 0.011, 0.011, 0.15, Vector3(0, 0.075, 0), _mat(Color("b0b4bb"), 0.3, 0.8))
		var knob := _sphere(pivot, 0.026, Vector3(0, 0.155, 0), _emit_mat(lever_cols[key], 0.6))
		meshes.append(knob)
		levers[key] = pivot
		lever_target[key] = -28.0
		i_lever += 1
	# radio unit
	var radio := _box(n, Vector3(0.56, 0.28, 0.32), Vector3(-0.78, 0.94, -0.12), _mat(_pal["equip"], 0.6, 0.2))
	meshes.append(radio)
	_box(n, Vector3(0.2, 0.16, 0.01), Vector3(-0.66, 0.95, 0.045), _mat(Color("15171c")))
	_cyl(n, 0.055, 0.055, 0.03, Vector3(-0.92, 0.95, 0.05), _mat(Color("1c1c1c"), 0.4), Vector3(90, 0, 0))
	_box(n, Vector3(0.1, 0.04, 0.01), Vector3(-0.92, 1.04, 0.045), _emit_mat(Color("ffb547"), 1.4))
	# microphone
	_cyl(n, 0.06, 0.07, 0.03, Vector3(-0.25, 0.815, 0.12), _mat(Color("2b2b2b"), 0.4, 0.5))
	_cyl(n, 0.008, 0.008, 0.22, Vector3(-0.25, 0.93, 0.1), _mat(Color("8a8f96"), 0.3, 0.8), Vector3(-15, 0, 0))
	var mic := _sphere(n, 0.035, Vector3(-0.25, 1.04, 0.07), _mat(Color("3a3a3a"), 0.5, 0.4))
	meshes.append(mic)
	# coffee mug + paperwork
	_cyl(n, 0.04, 0.04, 0.1, Vector3(1.05, 0.85, 0.22), _mat(Color("d9d2c0")))
	_box(n, Vector3(0.3, 0.02, 0.22), Vector3(-0.15, 0.81, 0.24), _mat(Color("e8e2cf")), Vector3(0, 8, 0))
	# hanging desk lamp
	_cyl(n, 0.006, 0.006, 0.85, Vector3(0, 2.6, 0.05), _mat(Color("111111")))
	_cyl(n, 0.04, 0.24, 0.18, Vector3(0, 2.1, 0.05), _mat(Color("1f3a33"), 0.5, 0.5))
	_sphere(n, 0.05, Vector3(0, 2.03, 0.05), _emit_mat(_pal["lamp"], 3.0))
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 2.0, 0.1)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = _pal["lamp"]
	spot.light_energy = 3.2
	spot.spot_range = 3.2
	spot.spot_angle = 46.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = true
	n.add_child(spot)
	_attention_lamp("console", n, Vector3(-0.6, 1.1, -0.12))
	_register_station("console", "RADIO CONSOLE — talk to Mia, systems, repairs", n,
		Vector3(0, 0.95, -0.1), 0.9, 0.3, Vector3(2.4, 0.7, 0.8), Vector3(0, 0.95, 0), meshes)


# ---------------------------------------------------------------- station 2: monitors

func _build_monitors() -> void:
	var n := _anchor(42.0, 1.35)
	var meshes: Array = []
	_box(n, Vector3(1.7, 0.74, 0.6), Vector3(0, 0.37, 0), _mat(_pal["desk"], 0.6, 0.3))
	_box(n, Vector3(1.8, 0.05, 0.66), Vector3(0, 0.765, 0), _mat(Color(_pal["desk"]).darkened(0.3), 0.5))
	var screens := [LifeSupportScreen, TerrainMapScreen, HelmetCamScreen]
	for i in 3:
		var unit := Node3D.new()
		unit.position = Vector3((i - 1) * 0.58, 0.79, -0.02)
		unit.rotation_degrees = Vector3(0, -(i - 1) * 12.0, 0)
		n.add_child(unit)
		var body := _box(unit, Vector3(0.52, 0.44, 0.46), Vector3(0, 0.22, -0.05), _mat(_pal["equip"], 0.6, 0.15))
		_box(unit, Vector3(0.36, 0.3, 0.22), Vector3(0, 0.22, -0.36), _mat(Color(_pal["equip"]).darkened(0.2)))
		meshes.append(body)
		_box(unit, Vector3(0.46, 0.36, 0.01), Vector3(0, 0.23, 0.176), _mat(Color("0c0f0d")))
		var tint := Color("ffb547") if i == 1 else Color("5cffb0")
		_add_screen(unit, screens[i], Vector2i(160, 120), Vector2(0.42, 0.32), Vector3(0, 0.23, 0.183), tint)
		_cyl(unit, 0.02, 0.02, 0.02, Vector3(0.17, 0.03, 0.18), _mat(Color("222222")), Vector3(90, 0, 0))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.1, 0.6)
	glow.light_color = Color("5cffb0")
	glow.light_energy = 0.7
	glow.omni_range = 2.4
	n.add_child(glow)
	_attention_lamp("monitors", n, Vector3(0.82, 0.81, 0.22))
	_register_station("monitors", "MONITORS — life support, terrain map, helmet cam, manual", n,
		Vector3(0, 1.02, -0.05), 1.1, 0.05, Vector3(1.8, 0.6, 0.6), Vector3(0, 1.02, 0), meshes)


func _add_screen(parent: Node3D, screen_script: GDScript, res: Vector2i, quad_size: Vector2, pos: Vector3, tint: Color) -> void:
	var vp := SubViewport.new()
	vp.size = res
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var ctrl: Control = screen_script.new()
	ctrl.size = Vector2(res)
	vp.add_child(ctrl)
	var mat := ShaderMaterial.new()
	mat.shader = CRT_SHADER
	mat.set_shader_parameter("screen_tex", vp.get_texture())
	mat.set_shader_parameter("tint", Color(1, 1, 1, 1))
	mat.set_shader_parameter("scanlines", float(res.y) * 0.5)
	screen_materials.append(mat)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = quad_size
	q.mesh = qm
	q.material_override = mat
	q.position = pos
	parent.add_child(q)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 0, 0.25)
	l.light_color = tint
	l.light_energy = 0.25
	l.omni_range = 1.2
	parent.add_child(l)


# ---------------------------------------------------------------- station 3: cork board

func _build_board() -> void:
	var n := _anchor(100.0, 3.0)
	var meshes: Array = []
	var frame := _box(n, Vector3(1.95, 1.25, 0.05), Vector3(0, 1.55, 0), _mat(Color("2a1c12"), 0.7))
	var cork := _box(n, Vector3(1.85, 1.15, 0.03), Vector3(0, 1.55, 0.02), _mat(Color("8a5a32"), 1.0))
	meshes.append_array([frame, cork])
	board_root = Node3D.new()
	board_root.position = Vector3(0, 1.55, 0.04)
	n.add_child(board_root)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 2.7, 0.9)
	spot.rotation_degrees = Vector3(-50, 0, 0)
	spot.light_color = Color("ffd9a8")
	spot.light_energy = 1.6
	spot.spot_range = 3.0
	spot.spot_angle = 40.0
	n.add_child(spot)
	_attention_lamp("board", n, Vector3(0.9, 2.22, 0.05))
	_register_station("board", "EVIDENCE BOARD — pin cards, tie red string", n,
		Vector3(0, 1.55, 0), 1.35, 0.0, Vector3(1.95, 1.25, 0.2), Vector3(0, 1.55, 0.05), meshes)


## Mirrors the 2D board (BoardManager) onto the 3D cork board: small cards + red strings.
func refresh_board() -> void:
	if board_root == null or not is_instance_valid(board_root):
		return
	for c in board_root.get_children():
		c.queue_free()
	var r := RandomNumberGenerator.new()
	for id in BoardManager.pinned.keys():
		var card := BoardManager.get_card(str(id))
		var p := _board_to_3d(BoardManager.get_pin_pos(str(id)) + Vector2(42, 27))
		r.seed = hash(str(id))
		var col: Color = CARD_COLORS.get(str(card.get("type", "report")), Color.WHITE)
		_box(board_root, Vector3(0.14, 0.09, 0.004), Vector3(p.x, p.y, 0.0), _mat(col, 0.9), Vector3(0, 0, r.randf_range(-6, 6)))
		_sphere(board_root, 0.008, Vector3(p.x, p.y + 0.035, 0.008), _mat(Color("c0392b"), 0.4))
	var red := _emit_mat(Color("d42a2a"), 0.6)
	for l in BoardManager.links:
		for end_id in [l[0], l[1]]:
			if not (BoardManager.pinned.has(end_id) and BoardManager.pinned.has(l[2])):
				continue
			var a := _board_to_3d(BoardManager.get_pin_pos(str(end_id)) + Vector2(42, 4))
			var b := _board_to_3d(BoardManager.get_pin_pos(str(l[2])) + Vector2(42, 4))
			var d := b - a
			var s := _box(board_root, Vector3(d.length(), 0.005, 0.004), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0.01), red)
			s.rotation.z = atan2(d.y, d.x)


func _board_to_3d(p: Vector2) -> Vector2:
	return Vector2((p.x / BOARD_SIZE_2D.x - 0.5) * BOARD_SIZE_3D.x, -(p.y / BOARD_SIZE_2D.y - 0.5) * BOARD_SIZE_3D.y)


# ---------------------------------------------------------------- station 4: hall window

func _build_window() -> void:
	var n := _anchor(-60.0, WALL_R)
	var meshes: Array = []
	var w := 2.0 * WALL_R * tan(deg_to_rad(15.0)) + 0.06
	_box(n, Vector3(w, 1.0, 0.12), Vector3(0, 0.5, 0), _mat(_pal["wainscot"], 0.7))
	_box(n, Vector3(w, 0.75, 0.12), Vector3(0, 2.625, 0), _mat(_pal["wall"]))
	for sx in [-1.0, 1.0]:
		_box(n, Vector3(0.3, 1.25, 0.12), Vector3(sx * (w * 0.5 - 0.15), 1.625, 0), _mat(_pal["wall"]))
	var metal := _mat(Color("6d7480"), 0.4, 0.7)
	var sill := _box(n, Vector3(1.5, 0.05, 0.2), Vector3(0, 1.0, 0.03), metal)
	var head := _box(n, Vector3(1.5, 0.05, 0.16), Vector3(0, 2.25, 0.02), metal)
	var post_l := _box(n, Vector3(0.05, 1.25, 0.16), Vector3(-0.72, 1.625, 0.02), metal)
	var post_r := _box(n, Vector3(0.05, 1.25, 0.16), Vector3(0.72, 1.625, 0.02), metal)
	meshes.append_array([sill, head, post_l, post_r])
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.1)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.metallic_specular = 0.9
	_box(n, Vector3(1.4, 1.2, 0.01), Vector3(0, 1.625, 0), glass_mat)
	# the hall behind the glass
	var hall := _mat(_pal["hall"], 0.8)
	_box(n, Vector3(6, 0.05, 3.2), Vector3(0, 0.0, -1.7), _mat(Color("1c2233"), 0.9))
	_box(n, Vector3(6, 3.0, 0.1), Vector3(0, 1.5, -3.2), hall)
	_box(n, Vector3(6, 0.05, 3.2), Vector3(0, 2.9, -1.7), _mat(Color("151a26")))
	_box(n, Vector3(0.1, 3.0, 3.2), Vector3(-3.0, 1.5, -1.7), hall)
	_box(n, Vector3(0.1, 3.0, 3.2), Vector3(3.0, 1.5, -1.7), hall)
	_box(n, Vector3(1.0, 2.1, 0.05), Vector3(1.6, 1.05, -3.13), _mat(Color("3d2c22")))
	_box(n, Vector3(0.6, 0.25, 0.02), Vector3(1.6, 2.35, -3.12), _emit_mat(Color("ff5a5f"), 1.2))
	_box(n, Vector3(1.4, 0.9, 0.02), Vector3(-1.2, 1.6, -3.12), _mat(Color("c9c0a8")))
	_box(n, Vector3(1.4, 0.04, 0.1), Vector3(0, 2.85, -1.6), _emit_mat(Color("cfefff"), 2.5))
	var hl := OmniLight3D.new()
	hl.position = Vector3(0, 2.4, -1.6)
	hl.light_color = Color("bfe9ff")
	hl.light_energy = 1.3
	hl.omni_range = 4.5
	n.add_child(hl)
	# the visitor (hidden until someone comes by)
	visitor = Node3D.new()
	visitor.position = Vector3(-2.6, 0, -1.1)
	visitor.visible = false
	n.add_child(visitor)
	_box(visitor, Vector3(0.32, 0.8, 0.2), Vector3(0, 0.4, 0), _mat(Color("252a33")))
	visitor_body = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 0.85
	visitor_body.mesh = cap
	visitor_body.position = Vector3(0, 1.18, 0)
	visitor_body.material_override = _mat(Color("d9d4c7"))
	visitor.add_child(visitor_body)
	_box(visitor, Vector3(0.05, 0.3, 0.02), Vector3(0, 1.25, 0.21), _mat(Color("1f2e4a")))
	_sphere(visitor, 0.13, Vector3(0, 1.75, 0), _mat(Color("c8a68a")))
	_box(visitor, Vector3(0.27, 0.07, 0.27), Vector3(0, 1.85, -0.01), _mat(Color("2b211b")))
	_attention_lamp("window", n, Vector3(0, 2.38, 0.08))
	_register_station("window", "HALL WINDOW — messages from colleagues", n,
		Vector3(0, 1.5, -0.6), 1.9, 0.05, Vector3(1.5, 1.4, 0.3), Vector3(0, 1.62, 0.08), meshes)


func show_visitor(v: Dictionary) -> void:
	if visitor == null:
		return
	visitor_body.material_override = _mat(Color(str(v.get("color", "#d9d4c7"))))
	visitor.visible = true
	visitor.position.x = -2.6
	if _visitor_tween and _visitor_tween.is_valid():
		_visitor_tween.kill()
	_visitor_tween = create_tween()
	_visitor_tween.tween_property(visitor, "position:x", 0.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hide_visitor() -> void:
	if visitor == null or not visitor.visible:
		return
	if _visitor_tween and _visitor_tween.is_valid():
		_visitor_tween.kill()
	_visitor_tween = create_tween()
	_visitor_tween.tween_property(visitor, "position:x", 2.8, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_visitor_tween.tween_callback(func(): visitor.visible = false)


# ---------------------------------------------------------------- station 5: phone / fax

func _build_phone() -> void:
	var n := _anchor(-112.0, 1.3)
	var meshes: Array = []
	_box(n, Vector3(0.9, 0.7, 0.55), Vector3(0, 0.35, 0), _mat(Color("3a2a20"), 0.7))
	var base := _box(n, Vector3(0.24, 0.08, 0.2), Vector3(-0.2, 0.74, 0.05), _mat(_pal["phone"], 0.5))
	_cyl(n, 0.065, 0.065, 0.01, Vector3(-0.2, 0.785, 0.07), _mat(Color("d8d2c2")))
	handset = Node3D.new()
	handset.position = Vector3(-0.2, 0.81, -0.01)
	n.add_child(handset)
	var hs := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.035
	cap.height = 0.27
	hs.mesh = cap
	hs.rotation_degrees = Vector3(0, 0, 90)
	hs.material_override = _mat(_pal["phone"], 0.5)
	handset.add_child(hs)
	var fax := _box(n, Vector3(0.38, 0.14, 0.32), Vector3(0.18, 0.77, 0.0), _mat(Color("9a968a"), 0.6))
	_box(n, Vector3(0.26, 0.004, 0.2), Vector3(0.18, 0.87, -0.13), _mat(Color("f2efe6")), Vector3(25, 0, 0))
	_box(n, Vector3(0.22, 0.003, 0.16), Vector3(0.18, 0.842, 0.2), _mat(Color("f2efe6")))
	meshes.append_array([base, hs, fax])
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.2, 0.3)
	l.light_color = Color("ffb547")
	l.light_energy = 0.35
	l.omni_range = 1.6
	n.add_child(l)
	_attention_lamp("phone", n, Vector3(0.33, 0.85, 0.12))
	_register_station("phone", "PHONE / FAX — orders from HQ", n,
		Vector3(0, 0.82, 0), 0.75, 0.38, Vector3(0.9, 0.35, 0.55), Vector3(0, 0.85, 0), meshes)


# ---------------------------------------------------------------- props / era details

func _build_props() -> void:
	# big plot screen + wall clock above the console
	var front := _anchor(0.0, WALL_R - 0.08)
	_box(front, Vector3(2.5, 1.05, 0.06), Vector3(-0.35, 2.15, 0), _mat(Color("111621")))
	_add_screen(front, PlotScreen, Vector2i(240, 96), Vector2(2.36, 0.94), Vector3(-0.35, 2.15, 0.035), Color("ffb547"))
	_cyl(front, 0.22, 0.22, 0.04, Vector3(1.45, 2.3, 0.0), _mat(Color("e8e2cf")), Vector3(90, 0, 0))
	_cyl(front, 0.235, 0.235, 0.03, Vector3(1.45, 2.3, -0.01), _mat(Color("222222")), Vector3(90, 0, 0))
	clock_hour = Node3D.new()
	clock_hour.position = Vector3(1.45, 2.3, 0.03)
	front.add_child(clock_hour)
	_box(clock_hour, Vector3(0.02, 0.12, 0.01), Vector3(0, 0.05, 0), _mat(Color("111111")))
	clock_min = Node3D.new()
	clock_min.position = Vector3(1.45, 2.3, 0.035)
	front.add_child(clock_min)
	_box(clock_min, Vector3(0.012, 0.18, 0.01), Vector3(0, 0.08, 0), _mat(Color("111111")))

	# filing cabinet & moon poster behind the player-left
	var cab := _anchor(140.0, 2.9)
	_box(cab, Vector3(0.55, 1.35, 0.6), Vector3(0, 0.675, 0), _mat(Color("4b5563"), 0.5, 0.5))
	for i in 4:
		_box(cab, Vector3(0.45, 0.02, 0.01), Vector3(0, 0.25 + i * 0.32, 0.3), _mat(Color("2a2f38")))
	var poster := _anchor(165.0, WALL_R - 0.07)
	_box(poster, Vector3(0.8, 1.05, 0.01), Vector3(0, 1.7, 0), _mat(Color("0d1220")))
	_cyl(poster, 0.26, 0.26, 0.01, Vector3(0, 1.78, 0.01), _emit_mat(Color("cfd6e0"), 0.35), Vector3(90, 0, 0))
	# door at the back-right
	var door := _anchor(-150.0, WALL_R - 0.06)
	_box(door, Vector3(1.0, 2.1, 0.05), Vector3(0, 1.05, 0), _mat(Color("2e241d"), 0.7))
	_box(door, Vector3(0.5, 0.16, 0.02), Vector3(0, 2.3, 0.02), _emit_mat(Color("5cffb0"), 1.0))

	if era == "1980s":
		# a beige computer terminal arrives on the console
		var desk := _anchor(0.0, 0.95)
		_box(desk, Vector3(0.42, 0.34, 0.36), Vector3(0.95, 0.97, -0.12), _mat(Color("cbc4ad")))
		_box(desk, Vector3(0.32, 0.22, 0.01), Vector3(0.95, 1.0, 0.065), _emit_mat(Color("5cffb0"), 0.9))
		_box(desk, Vector3(0.46, 0.03, 0.16), Vector3(0.95, 0.815, 0.15), _mat(Color("cbc4ad")))


# ---------------------------------------------------------------- runtime updates

func _process(delta: float) -> void:
	_t += delta
	# attention lamps blink
	for id in attention_lamps.keys():
		var lamp: MeshInstance3D = attention_lamps[id]
		lamp.visible = bool(attention.get(id, false)) and fmod(_t * 2.0, 1.0) < 0.6
	# levers ease toward their target angle
	for key in levers.keys():
		var pivot: Node3D = levers[key]
		pivot.rotation_degrees.x = lerpf(pivot.rotation_degrees.x, float(lever_target[key]), 1.0 - exp(-12.0 * delta))
	# ringing handset
	if handset != null:
		var ring := bool(attention.get("phone", false)) and fmod(_t, 2.0) < 0.8
		handset.position.y = 0.81 + (sin(_t * 60.0) * 0.004 if ring else 0.0)
	# wall clock
	if clock_hour != null:
		var minutes := float(TimeManager.clock_minutes()) if GameState.in_game else float(Time.get_time_dict_from_system()["hour"] * 60 + Time.get_time_dict_from_system()["minute"])
		clock_min.rotation.z = -fmod(minutes, 60.0) / 60.0 * TAU
		clock_hour.rotation.z = -fmod(minutes / 60.0, 12.0) / 12.0 * TAU


func set_attention(station_id: String, on: bool) -> void:
	attention[station_id] = on


func set_lever(system_name: String, on: bool) -> void:
	if lever_target.has(system_name):
		lever_target[system_name] = -28.0 if on else 28.0


func set_crt_enabled(on: bool) -> void:
	for m in screen_materials:
		(m as ShaderMaterial).set_shader_parameter("crt_enabled", on)


# ---------------------------------------------------------------- helpers

func _register_station(id: String, label: String, anchor: Node3D, center_local: Vector3, focus_dist: float,
		focus_up: float, body_size: Vector3, body_center: Vector3, meshes: Array) -> void:
	var center := anchor.transform * center_local
	var flat := Vector3(EYE.x - center.x, 0.0, EYE.z - center.z).normalized()
	var cam_pos := center + flat * focus_dist + Vector3(0, focus_up, 0)
	var focus := Transform3D(Basis(), cam_pos).looking_at(center, Vector3.UP)
	var horiz := Vector2(center.x - EYE.x, center.z - EYE.z).length()
	var pitch := rad_to_deg(atan2(center.y - EYE.y, horiz))
	var yaw := rad_to_deg(atan2(-(center.x - EYE.x), -(center.z - EYE.z)))
	stations.append({"id": id, "name": label, "yaw": yaw, "pitch": pitch, "focus": focus})
	var body: StaticBody3D = Interactable.new()
	body.set("station_id", id)
	body.set("label_text", label)
	body.set("meshes", meshes)
	body.position = body_center
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = body_size
	shape.shape = bs
	body.add_child(shape)
	anchor.add_child(body)
	interactables[id] = body


func _attention_lamp(id: String, parent: Node3D, pos: Vector3) -> void:
	var lamp := _sphere(parent, 0.025, pos, _emit_mat(Color("ff5a5f"), 4.0))
	lamp.visible = false
	attention_lamps[id] = lamp


## Node placed around the player at `yaw_deg` / `dist`, facing the player.
func _anchor(yaw_deg: float, dist: float) -> Node3D:
	var n := Node3D.new()
	var a := deg_to_rad(yaw_deg)
	n.position = Vector3(-sin(a) * dist, 0.0, -cos(a) * dist)
	n.rotation.y = a
	add_child(n)
	return n


func _mat(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key := "m%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mats[key] = m
	return m


func _emit_mat(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "e%s_%.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


func _box(parent: Node3D, box_size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, top_r: float, bottom_r: float, h: float, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func UiTheme_amber() -> Color:
	return Color("ffb547")
