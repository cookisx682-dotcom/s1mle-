extends Node3D
## Builds the whole world: house, basement, hospital, tape worlds and their props.

const H := 2.8
const TW := 0.16
const HX := 70.0

var M
var G := {}                 # world groups
var doors := {}
var door_list: Array = []
var lamp_fix: Array = []    # emissive materials of lamp shades (index matches LAMPS)
var bulb_mat: StandardMaterial3D
var win_mats: Array = []
var pool: Array = []        # reusable omni lights
var tv_light: OmniLight3D
var tv_screen: MeshInstance3D
var tv_mat: ShaderMaterial
var frames: Array = []      # picture frames [paint1..4, family, granny]
var fam_mat: StandardMaterial3D
var tex := {}
var gS: Node3D
var gM: Node3D
var gH: Node3D
var pend: Node3D
var compart: MeshInstance3D
var hosp_hands: Array = []
var cake_flames: Array = []
var chg := {}               # change id -> node
var fuse_lamp: StandardMaterial3D
var keypad_mat: StandardMaterial3D
var static_mats: Array = []
var people := {}

const LAMPS := [[4.5, 3.8], [12.5, 3.4], [20, 3], [12.5, 7.5], [19.5, 7.5], [4.5, 11.5], [12, 12], [17, 11], [17, 14], [21.5, 12]]


func build() -> void:
	for k in ["house", "real", "fake", "mem", "t1", "t2", "t4", "t5", "t7", "t0", "anom", "a3", "a6", "hosp", "endB"]:
		var n := Node3D.new()
		n.name = k
		add_child(n)
		G[k] = n
	for k in ["paint1", "paint2", "paint3", "paint4", "family", "family_fake", "granny", "drawing", "blood1", "blood2", "hands",
			"photo0", "photo1", "photo2", "photo3", "face"]:
		tex[k] = load("res://art/%s.png" % k)
	_walls()
	_doors()
	_windows()
	_lamps()
	_frames()
	_furniture()
	_basement()
	_decals()
	_mem_props()
	_anom_props()
	_hospital()
	_changes()
	_people()
	for i in 6:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.shadow_enabled = i < 4
		l.light_volumetric_fog_energy = 0.7
		add_child(l)
		pool.append(l)


# =====================================================================
# walls, floors
# =====================================================================
func add_wall(cx: float, cz: float, sx: float, sz: float, base := false) -> void:
	M.box(Vector3(sx, H, sz), Vector3(cx, H / 2, cz), Tex.mat("concrete" if base else "wall"), true, G.house)
	if base:
		return
	var hz := sx > sz
	M.box(Vector3(sx + (0.0 if hz else 0.03), 1.0, sz + (0.03 if hz else 0.0)), Vector3(cx, 0.5, cz), Tex.mat("wainscot"), false, G.house)
	M.box(Vector3(sx + (0.0 if hz else 0.05), 0.05, sz + (0.05 if hz else 0.0)), Vector3(cx, 1.0, cz), Tex.mat("wood_dark"), false, G.house)
	M.box(Vector3(sx + (0.0 if hz else 0.07), 0.09, sz + (0.07 if hz else 0.0)), Vector3(cx, H - 0.045, cz), Tex.flat(Color(0.6, 0.57, 0.5), 0.8), false, G.house)


func wall_seg(x0: float, z0: float, x1: float, z1: float, gaps := [], base := false) -> void:
	var hz := z0 == z1
	var a1 := x1 if hz else z1
	var cur_a := x0 if hz else z0
	var cur_end := true
	var gs: Array = gaps.duplicate()
	gs.sort_custom(func(a, b): return a[0] < b[0])
	var seg := func(p0: float, p1: float, e0: bool, e1: bool) -> void:
		p0 -= TW / 2 if e0 else 0.0
		p1 += TW / 2 if e1 else 0.0
		if p1 - p0 < 0.02:
			return
		if hz:
			add_wall((p0 + p1) / 2, z0, p1 - p0, TW, base)
		else:
			add_wall(x0, (p0 + p1) / 2, TW, p1 - p0, base)
	for g in gs:
		var c: float = g[0]
		var w: float = g[1]
		seg.call(cur_a, c - w / 2, cur_end, false)
		M.box(Vector3(w if hz else TW, H - 2.15, TW if hz else w), Vector3(c if hz else x0, (H + 2.15) / 2, z0 if hz else c), Tex.mat("concrete" if base else "wall"), false, G.house)
		var fm := Tex.mat("wood_dark")
		for s in [-1, 1]:
			M.box(Vector3(0.07 if hz else TW + 0.05, 2.15, TW + 0.05 if hz else 0.07), Vector3(c + s * w / 2 if hz else x0, 1.075, z0 if hz else c + s * w / 2), fm, false, G.house)
		M.box(Vector3(w + 0.14 if hz else TW + 0.05, 0.08, TW + 0.05 if hz else w + 0.14), Vector3(c if hz else x0, 2.17, z0 if hz else c), fm, false, G.house)
		cur_a = c + w / 2
		cur_end = false
	seg.call(cur_a, a1, cur_end, true)


func floor_room(x0: float, z0: float, x1: float, z1: float, key: String, parent: Node = null) -> void:
	M.box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2, -0.05, (z0 + z1) / 2), Tex.mat(key), false, parent if parent else G.house)


func _walls() -> void:
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
	# basement
	wall_seg(40, 0, 54, 0, [], true)
	wall_seg(40, 12, 54, 12, [], true)
	wall_seg(40, 0, 40, 12, [], true)
	wall_seg(54, 0, 54, 12, [], true)
	wall_seg(44, 0, 44, 12, [[2, 1.2], [9, 1.2]], true)
	wall_seg(44, 5, 54, 5, [[47, 1.2]], true)
	floor_room(0, 0, 9, 8, "floor"); floor_room(0, 8, 9, 15, "floor"); floor_room(9, 0, 16, 6, "tile")
	floor_room(16, 0, 24, 6, "floor"); floor_room(9, 6, 24, 9, "floor"); floor_room(9, 9, 15, 15, "carpet")
	floor_room(15, 9, 19, 13, "tile2"); floor_room(15, 13, 19, 15, "concrete"); floor_room(19, 9, 24, 15, "carpet2")
	floor_room(40, 0, 54, 12, "concrete")
	M.box(Vector3(24, 0.1, 15), Vector3(12, H + 0.05, 7.5), Tex.mat("ceiling"), false, G.house)
	M.box(Vector3(14, 0.1, 12), Vector3(47, H + 0.05, 6), Tex.mat("concrete"), false, G.house)
	M.box(Vector3(26, 0.2, 17), Vector3(12, -0.2, 7.5), Tex.mat("black"), false, G.house)
	M.box(Vector3(16, 0.2, 14), Vector3(47, -0.2, 6), Tex.mat("black"), false, G.house)


# =====================================================================
# doors and windows
# =====================================================================
func make_door(id: String, x: float, z: float, axis: String, w: float, swing: float, locked := false) -> void:
	var pv := Node3D.new()
	pv.position = Vector3(x - w / 2, 0, z) if axis == "x" else Vector3(x, 0, z - w / 2)
	G.house.add_child(pv)
	var pw := w - 0.04
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	pv.add_child(body)
	var size := Vector3(pw, 2.1, 0.05) if axis == "x" else Vector3(0.05, 2.1, pw)
	var off := Vector3(pw / 2, 1.05, 0) if axis == "x" else Vector3(0, 1.05, pw / 2)
	var dm: Node3D = M.model("door", Vector3.ZERO, 0.0 if axis == "x" else -PI / 2, body)
	dm.scale.x = pw / 0.94
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = off
	body.add_child(cs)
	var d := {"id": id, "pv": pv, "x": x, "z": z, "axis": axis, "w": w, "open": false, "locked": locked,
		"ang": (-1.0 if axis == "x" else 1.0) * swing * 1.45, "cur": 0.0, "target": 0.0}
	doors[id] = d
	door_list.append(d)


func set_door(id: String, open: bool, locked = null, instant := false) -> void:
	var d = doors[id]
	d.open = open
	if locked != null:
		d.locked = locked
	d.target = d.ang if open else 0.0
	if instant:
		d.cur = d.target
		d.pv.rotation.y = d.cur


func _doors() -> void:
	make_door("lk", 9, 3, "z", 0.98, 1)
	make_door("kh", 12.5, 6, "x", 0.98, 1)
	make_door("kid", 12, 9, "x", 0.98, 1, true)
	make_door("bath", 17, 9, "x", 0.98, 1)
	make_door("bed", 21.5, 9, "x", 0.98, 1, true)
	make_door("study", 16, 3, "z", 0.98, 1, true)
	make_door("stor", 19, 14, "z", 0.88, -1)
	make_door("front", 0, 11.5, "z", 0.98, 1, true)
	make_door("base", 6.5, 15, "x", 0.98, -1, true)


func _windows() -> void:
	for wdef in [[Vector3(0.09, 1.6, 5.8), PI / 2], [Vector3(11.5, 1.6, 0.09), 0.0], [Vector3(20, 1.6, 0.09), 0.0], [Vector3(12, 1.6, 14.91), PI], [Vector3(23.91, 1.6, 10.3), -PI / 2]]:
		var g := Node3D.new()
		g.position = wdef[0]
		g.rotation.y = wdef[1]
		G.house.add_child(g)
		var glass := Tex.emissive(Color(0.1, 0.13, 0.22), 0.6)
		win_mats.append(glass)
		M.quad(Vector2(1.1, 1.25), Vector3.ZERO, Vector3.ZERO, glass, g)
		for d in [[Vector3(1.22, 0.06, 0.06), Vector3(0, 0.64, 0.02)], [Vector3(1.22, 0.06, 0.06), Vector3(0, -0.64, 0.02)], [Vector3(0.06, 1.3, 0.06), Vector3(-0.58, 0, 0.02)],
				[Vector3(0.06, 1.3, 0.06), Vector3(0.58, 0, 0.02)], [Vector3(1.1, 0.035, 0.04), Vector3(0, 0, 0.02)], [Vector3(0.035, 1.25, 0.04), Vector3(0, 0, 0.02)],
				[Vector3(1.4, 0.04, 0.16), Vector3(0, -0.68, 0.06)]]:
			M.box(d[0], d[1], Tex.mat("wood"), false, g)
		for s in [-1, 1]:
			M.box(Vector3(0.42, 2.1, 0.05), Vector3(s * 0.85, -0.25, 0.1), Tex.flat(Color(0.25, 0.06, 0.06), 0.98), false, g)
		# boarded up in reality
		var rb := Node3D.new()
		G.real.add_child(rb)
		rb.global_transform = g.global_transform if g.is_inside_tree() else Transform3D(Basis(Vector3.UP, wdef[1]), wdef[0])
		for i in 3:
			var b: MeshInstance3D = M.box(Vector3(1.5, 0.12, 0.03), Vector3(0, -0.4 + i * 0.4, 0.12), Tex.mat("wood_dark"), false, rb)
			b.rotation.z = (i - 1) * 0.08


# =====================================================================
# lamps, switches, frames
# =====================================================================
func _lamps() -> void:
	for p in LAMPS:
		var m := Tex.emissive(Color(1.0, 0.8, 0.55), 0.0)
		lamp_fix.append(m)
		var shade: Node3D = M.model("shade", Vector3(p[0], 2.35, p[1]), 0.0, G.house)
		M.set_mat(shade, "lampshade", m)
		M.no_shadow(shade)
		M.cyl(0.006, 0.006, H - 2.35, Vector3(p[0], (H + 2.35) / 2 + 0.05, p[1]), Tex.mat("black"), G.house)
	# floor lamp in the living room (fixture index 10)
	M.model("floor_lamp", Vector3(7.7, 0, 1.6), 0.0, G.house)
	var fl := Tex.emissive(Color(1.0, 0.8, 0.55), 0.0)
	lamp_fix.append(fl)
	var fs: Node3D = M.model("shade", Vector3(7.7, 1.5, 1.6), 0.0, G.house)
	M.set_mat(fs, "lampshade", fl)
	M.no_shadow(fs)
	bulb_mat = Tex.emissive(Color(1.0, 0.8, 0.55), 0.0)
	for p in [[42, 2.5], [48, 2.5], [49, 8.8]]:
		M.cyl(0.004, 0.004, 0.5, Vector3(p[0], 2.55, p[1]), Tex.mat("black"), G.house)
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.05; sm.height = 0.1
		b.mesh = sm
		b.material_override = bulb_mat
		b.position = Vector3(p[0], 2.27, p[1])
		G.house.add_child(b)
	tv_light = OmniLight3D.new()
	tv_light.position = Vector3(4.5, 0.95, 1.3)
	tv_light.light_color = Color(0.62, 0.71, 1.0)
	tv_light.omni_range = 6.0
	tv_light.shadow_enabled = true
	G.house.add_child(tv_light)


func switch_plate(pos: Vector3, ry: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = ry
	G.house.add_child(g)
	M.box(Vector3(0.09, 0.13, 0.015), Vector3.ZERO, Tex.mat("cream"), false, g)
	M.box(Vector3(0.022, 0.04, 0.02), Vector3(0, 0, 0.012), Tex.flat(Color(0.6, 0.58, 0.52), 0.5), false, g)


func picture(pos: Vector3, ry: float, w: float, h: float, t: Texture2D, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = ry
	(parent if parent else G.house).add_child(g)
	M.box(Vector3(w + 0.08, h + 0.08, 0.035), Vector3.ZERO, Tex.mat("wood_dark"), false, g)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.roughness = 0.55
	M.quad(Vector2(w, h), Vector3(0, 0, 0.019), Vector3.ZERO, m, g)
	g.set_meta("mat", m)
	return g


const PAINT_POS := [[7.2, 1.65, 7.91, PI], [15.91, 1.65, 5.0, -PI / 2], [19.5, 1.65, 6.09, 0.0], [14.91, 1.65, 12.8, -PI / 2]]


func _frames() -> void:
	for i in 4:
		var p = PAINT_POS[i]
		frames.append(picture(Vector3(p[0], p[1], p[2]), p[3], 0.56, 0.7, tex["paint%d" % (i + 1)]))
	var f := picture(Vector3(10.6, 1.6, 6.09), 0.0, 0.5, 0.39, tex.family)
	fam_mat = f.get_meta("mat")
	frames.append(f)
	frames.append(picture(Vector3(0.09, 1.7, 9.6), PI / 2, 0.5, 0.65, tex.granny))
	for k in ["living", "kitchen", "kid", "bed"]:
		pass
	for sw in [[Vector3(5.7, 1.3, 7.9), PI], [Vector3(9.1, 1.3, 2.1), PI / 2], [Vector3(11.15, 1.3, 9.1), 0.0], [Vector3(20.65, 1.3, 9.1), 0.0],
			[Vector3(10.2, 1.3, 6.1), 0.0], [Vector3(3.0, 1.3, 8.1), 0.0], [Vector3(16.1, 1.3, 9.1), 0.0], [Vector3(17.2, 1.3, 0.1), 0.0]]:
		switch_plate(sw[0], sw[1])


# =====================================================================
# furniture
# =====================================================================
func chair(x: float, z: float, ry: float, parent: Node = null) -> Node3D:
	return M.model("chair", Vector3(x, 0, z), ry, parent if parent else G.house)


func books(x: float, z0: float, z1: float, shelves: int, y0: float, step: float) -> void:
	for s in shelves:
		var z := z0
		while z < z1:
			var w := randf_range(0.03, 0.07)
			var hh := randf_range(0.22, 0.36)
			M.box(Vector3(0.26, hh, w), Vector3(x, y0 + s * step + hh / 2, z + w / 2), Tex.flat(Color.from_hsv(randf(), 0.35, randf_range(0.12, 0.28)), 0.8), false, G.house)
			z += w + 0.004


func _furniture() -> void:
	var hs: Node = G.house
	# ---- living
	var tv: Node3D = M.model("tv", Vector3(4.5, 0, 0.62), 0.0, hs)
	M.rects.append(Rect2(3.75, 0.34, 1.5, 0.56))
	tv_mat = ShaderMaterial.new()
	tv_mat.shader = load("res://shaders/tv.gdshader")
	tv_screen = tv.find_child("screen", true, false)
	tv_screen.material_override = tv_mat
	M.box(Vector3(1.2, 0.05, 0.66), Vector3(4.5, 0.42, 3.2), Tex.mat("wood"), true, hs)
	for a in [-1, 1]:
		for b in [-1, 1]:
			M.box(Vector3(0.05, 0.4, 0.05), Vector3(4.5 + a * 0.54, 0.2, 3.2 + b * 0.28), Tex.mat("wood"), false, hs)
	M.box(Vector3(3, 0.01, 3.6), Vector3(4.5, 0.006, 3.8), Tex.mat("rug"), false, hs)
	M.model("sofa", Vector3(4.5, 0, 5.0), 0.0, hs)
	M.solid(Vector3(2.2, 0.9, 0.86), Vector3(4.5, 0.45, 5.0))
	M.model("sofa_sheet", Vector3(4.5, 0, 5.0), 0.0, G.real)
	M.model("armchair", Vector3(1.4, 0, 3.4), -PI / 2, hs)
	M.solid(Vector3(0.9, 0.9, 0.9), Vector3(1.4, 0.45, 3.4))
	M.model("armchair_sheet", Vector3(1.4, 0, 3.4), -PI / 2, G.real)
	M.model("shelf", Vector3(0.24, 0, 1.4), PI / 2, hs)
	M.solid(Vector3(0.42, 2.0, 1.3), Vector3(0.3, 1.0, 1.4))
	# grandfather clock with moving hands and pendulum
	M.model("clock", Vector3(8.45, 0, 0.45), 0.0, hs)
	M.solid(Vector3(0.56, 2.1, 0.42), Vector3(8.45, 1.05, 0.45))
	var face := Node3D.new()
	face.position = Vector3(8.45, 1.75, 0.68)
	hs.add_child(face)
	gH = _hand(face, 0.1, 0.014, Tex.mat("black"))
	gM = _hand(face, 0.15, 0.01, Tex.mat("black"))
	gS = _hand(face, 0.16, 0.004, Tex.flat(Color(0.6, 0.1, 0.07), 0.5))
	pend = Node3D.new()
	pend.position = Vector3(8.45, 1.3, 0.64)
	hs.add_child(pend)
	M.cyl(0.004, 0.004, 0.55, Vector3(0, -0.28, 0), Tex.mat("brass"), pend)
	var bob: MeshInstance3D = M.cyl(0.06, 0.06, 0.012, Vector3(0, -0.58, 0), Tex.mat("brass"), pend)
	bob.rotation.x = PI / 2
	compart = M.box(Vector3(0.3, 0.18, 0.02), Vector3(8.45, 0.25, 0.63), Tex.mat("wood"), false, hs)
	M.model("dresser", Vector3(2.2, 0, 7.72), PI, hs)
	M.solid(Vector3(1.4, 0.9, 0.5), Vector3(2.2, 0.45, 7.72))
	# ---- foyer
	for i in 8:
		M.box(Vector3(0.32, 0.22 * (i + 1), 1.4), Vector3(3.0 - i * 0.32, 0.11 * (i + 1), 14.2), Tex.mat("wood"), false, hs)
	M.solid(Vector3(2.75, 2.0, 1.5), Vector3(1.82, 1.0, 14.2))
	for i in 4:
		var bb: MeshInstance3D = M.box(Vector3(0.05, 0.16, 1.6), Vector3(3.3, 0.4 + i * 0.42, 14.2), Tex.mat("wood"), false, hs)
		bb.rotation.x = 0.12 if i % 2 else -0.1
	M.cyl(0.03, 0.03, 1.9, Vector3(8.5, 0.95, 8.7), Tex.mat("wood_dark"), hs)
	for i in 3:
		var c: MeshInstance3D = M.cyl(0.14, 0.2, 1.0, Vector3(8.5 + cos(i * 2) * 0.14, 1.2, 8.7 + sin(i * 2) * 0.14), Tex.mat("fabric"), hs)
		c.scale.z = 0.6
	M.solid(Vector3(0.5, 1.9, 0.5), Vector3(8.5, 0.95, 8.7))
	M.model("dresser", Vector3(6.2, 0, 8.33), 0.0, hs)
	M.solid(Vector3(1.4, 0.9, 0.5), Vector3(6.2, 0.45, 8.33))
	M.box(Vector3(0.04, 1.0, 0.6), Vector3(8.92, 1.55, 12), Tex.mat("wood_dark"), false, hs)
	var mirror := StandardMaterial3D.new(); mirror.albedo_color = Color(0.05, 0.06, 0.07); mirror.metallic = 1.0; mirror.roughness = 0.03
	M.quad(Vector2(0.5, 0.9), Vector3(8.895, 1.55, 12), Vector3(0, -PI / 2, 0), mirror, hs)
	M.box(Vector3(6, 0.01, 1.3), Vector3(4.5, 0.006, 11.5), Tex.mat("rug"), false, hs)
	# ---- kitchen
	M.model("counter", Vector3(11.6, 0, 0.42), 0.0, hs)
	M.solid(Vector3(4.8, 0.9, 0.6), Vector3(11.6, 0.45, 0.42))
	M.model("stove", Vector3(14.6, 0, 0.42), 0.0, hs)
	M.solid(Vector3(0.76, 0.9, 0.62), Vector3(14.6, 0.45, 0.42))
	M.model("fridge", Vector3(15.5, 0, 0.5), 0.0, hs)
	M.solid(Vector3(0.72, 1.8, 0.66), Vector3(15.5, 0.9, 0.5))
	M.model("table", Vector3(12.5, 0, 3.6), 0.0, hs)
	M.solid(Vector3(1.6, 0.78, 0.9), Vector3(12.5, 0.39, 3.6))
	chair(12.5, 2.98, 0.0); chair(11.5, 3.6, PI / 2); chair(13.5, 3.6, -PI / 2, G.mem); chair(12.5, 4.25, PI, G.mem)
	var fallen := chair(14.2, 4.9, 0.8, G.real)
	fallen.rotation = Vector3(PI / 2.1, 0.6, 0)
	fallen.position.y = 0.22
	M.box(Vector3(0.14, 0.22, 0.1), Vector3(13.45, 1.03, 0.32), Tex.mat("wood"), false, hs)
	var cl := Node3D.new()
	cl.position = Vector3(13.0, 0.935, 0.42)
	cl.rotation.y = 0.5
	G.real.add_child(cl)
	M.box(Vector3(0.2, 0.006, 0.1), Vector3.ZERO, Tex.mat("metal"), false, cl)
	M.box(Vector3(0.12, 0.022, 0.028), Vector3(0.16, 0.004, -0.03), Tex.mat("wood_dark"), false, cl)
	# ---- study
	M.box(Vector3(1.6, 0.05, 0.8), Vector3(21, 0.75, 1.0), Tex.mat("wood"), false, hs)
	for x in [20.42, 21.58]:
		M.box(Vector3(0.45, 0.72, 0.75), Vector3(x, 0.36, 1.0), Tex.mat("wood_dark"), false, hs)
	M.solid(Vector3(1.6, 0.78, 0.8), Vector3(21, 0.39, 1.0))
	M.box(Vector3(0.42, 0.14, 0.34), Vector3(21.2, 0.85, 1.05), Tex.mat("plastic"), false, hs)
	M.box(Vector3(0.3, 0.01, 0.22), Vector3(21.2, 0.93, 0.95), Tex.mat("sheet"), false, hs)
	M.cyl(0.08, 0.1, 0.02, Vector3(20.5, 0.785, 0.8), Tex.mat("brass"), hs)
	M.cyl(0.01, 0.01, 0.35, Vector3(20.5, 0.95, 0.8), Tex.mat("brass"), hs)
	chair(21, 1.8, PI)
	for z in [1.5, 4.0]:
		M.box(Vector3(0.42, 2.2, 1.6), Vector3(23.7, 1.1, z), Tex.mat("wood_dark"), true, hs)
		books(23.55, z - 0.7, z + 0.7, 4, 0.3, 0.5)
	M.box(Vector3(0.5, 1.3, 0.6), Vector3(16.5, 0.65, 0.45), Tex.mat("metal"), true, hs)
	M.box(Vector3(0.9, 0.5, 0.85), Vector3(18.6, 0.25, 4.6), Tex.flat(Color(0.23, 0.13, 0.09), 0.7), false, hs)
	M.box(Vector3(0.9, 0.6, 0.2), Vector3(18.6, 0.55, 4.95), Tex.flat(Color(0.23, 0.13, 0.09), 0.7), false, hs)
	M.solid(Vector3(0.9, 0.9, 0.85), Vector3(18.6, 0.45, 4.6))
	keypad_mat = Tex.emissive(Color(0.1, 0.3, 0.16), 1.0)
	M.box(Vector3(0.04, 0.28, 0.2), Vector3(15.9, 1.3, 2.25), Tex.mat("metal"), false, hs)
	M.quad(Vector2(0.12, 0.08), Vector3(15.875, 1.36, 2.25), Vector3(0, -PI / 2, 0), keypad_mat, hs)
	# ---- hall
	M.box(Vector3(0.9, 0.05, 0.34), Vector3(14.5, 0.78, 6.3), Tex.mat("wood"), true, hs)
	for a in [-1, 1]:
		M.box(Vector3(0.04, 0.76, 0.3), Vector3(14.5 + a * 0.42, 0.38, 6.3), Tex.mat("wood"), false, hs)
	M.cyl(0.05, 0.08, 0.24, Vector3(14.3, 0.92, 6.3), Tex.flat(Color(0.23, 0.3, 0.35), 0.3), hs)
	M.model("wardrobe", Vector3(23.6, 0, 7.5), -PI / 2, hs)
	M.solid(Vector3(0.7, 2.0, 1.1), Vector3(23.6, 1.0, 7.5))
	M.box(Vector3(1.0, 0.6, 0.1), Vector3(17, 0.4, 6.15), Tex.mat("metal"), false, hs)
	M.box(Vector3(13, 0.01, 1.1), Vector3(16.5, 0.006, 7.5), Tex.mat("rug"), false, hs)
	# ---- kid room
	M.model("bed_kid", Vector3(9.72, 0, 12.5), 0.0, hs)
	M.solid(Vector3(1.06, 0.5, 2.06), Vector3(9.72, 0.25, 12.5))
	M.model("wardrobe", Vector3(14.6, 0, 10.1), -PI / 2, hs)
	M.solid(Vector3(0.7, 2.0, 1.1), Vector3(14.6, 1.0, 10.1))
	M.box(Vector3(0.9, 0.04, 0.5), Vector3(13.4, 0.62, 14.6), Tex.flat(Color(0.48, 0.35, 0.24), 0.6), false, hs)
	for a in [-1, 1]:
		M.box(Vector3(0.04, 0.6, 0.46), Vector3(13.4 + a * 0.43, 0.3, 14.6), Tex.flat(Color(0.48, 0.35, 0.24), 0.6), false, hs)
	M.solid(Vector3(0.9, 0.64, 0.5), Vector3(13.4, 0.32, 14.6))
	var dm := StandardMaterial3D.new(); dm.albedo_texture = tex.drawing; dm.roughness = 0.9
	M.quad(Vector2(0.32, 0.24), Vector3(13.25, 0.645, 14.6), Vector3(-PI / 2, 0, 0), dm, hs)
	M.box(Vector3(0.8, 0.5, 0.45), Vector3(10.6, 0.25, 14.55), Tex.flat(Color(0.42, 0.29, 0.16), 0.7), true, hs)
	var bear := Node3D.new()
	bear.position = Vector3(11.4, 0, 13.8)
	hs.add_child(bear)
	var bm := Tex.flat(Color(0.48, 0.32, 0.2), 1.0)
	_sphere(0.13, Vector3(0, 0.13, 0), bm, bear)
	_sphere(0.09, Vector3(0, 0.3, 0), bm, bear)
	for s in [-1, 1]:
		_sphere(0.035, Vector3(s * 0.065, 0.37, 0), bm, bear)
	for i in 5:
		M.box(Vector3(0.1, 0.1, 0.1), Vector3(11 + randf() * 1.6, 0.05, 10 + randf() * 1.2), Tex.flat(Color.from_hsv(randf(), 0.6, 0.6), 0.6), false, G.mem)
	# ---- bath
	M.model("bathtub", Vector3(17.5, 0, 12.55), 0.0, hs)
	M.solid(Vector3(2.0, 0.6, 0.76), Vector3(17.5, 0.3, 12.55))
	M.model("sink", Vector3(18.72, 0, 10.2), -PI / 2, hs)
	M.solid(Vector3(0.44, 0.9, 0.5), Vector3(18.72, 0.45, 10.2))
	M.box(Vector3(0.04, 0.78, 0.58), Vector3(18.95, 1.55, 10.2), Tex.mat("wood_dark"), false, hs)
	M.quad(Vector2(0.5, 0.7), Vector3(18.92, 1.55, 10.2), Vector3(0, -PI / 2, 0), mirror, hs)
	M.cyl(0.2, 0.18, 0.4, Vector3(15.45, 0.2, 11.2), Tex.mat("ceramic"), hs)
	M.box(Vector3(0.18, 0.4, 0.4), Vector3(15.18, 0.55, 11.2), Tex.mat("ceramic"), false, hs)
	M.solid(Vector3(0.6, 0.6, 0.5), Vector3(15.4, 0.3, 11.2))
	# ---- storage
	M.box(Vector3(0.42, 1.9, 1.8), Vector3(15.3, 0.95, 14), Tex.mat("wood_dark"), true, hs)
	for i in 4:
		M.box(Vector3(0.38, 0.03, 1.76), Vector3(15.32, 0.3 + i * 0.5, 14), Tex.mat("wood"), false, hs)
	for i in 6:
		M.box(Vector3(0.3 + randf() * 0.2, 0.25, 0.3), Vector3(15.3, 0.45 + (i % 3) * 0.5, 13.4 + floorf(i / 3.0) * 0.9), Tex.flat(Color(0.54, 0.42, 0.27), 0.95), false, hs)
	M.box(Vector3(0.6, 0.5, 0.5), Vector3(17.6, 0.25, 14.6), Tex.flat(Color(0.54, 0.42, 0.27), 0.95), true, hs)
	M.box(Vector3(0.5, 0.4, 0.5), Vector3(18.3, 0.2, 13.5), Tex.flat(Color(0.48, 0.35, 0.22), 0.95), true, hs)
	# ---- bedroom
	M.model("bed_double", Vector3(22.75, 0, 12.9), -PI / 2, hs)
	M.solid(Vector3(2.2, 0.5, 1.8), Vector3(22.6, 0.25, 12.9))
	M.model("wardrobe", Vector3(19.4, 0, 10.6), PI / 2, hs)
	M.solid(Vector3(0.7, 2.0, 1.1), Vector3(19.4, 1.0, 10.6))
	M.model("dresser", Vector3(21.2, 0, 14.7), PI, hs)
	M.solid(Vector3(1.4, 0.9, 0.5), Vector3(21.2, 0.45, 14.7))
	for i in 4:
		M.box(Vector3(0.16, 0.2, 0.02), Vector3(20.7 + i * 0.33, 1.0, 14.6), Tex.mat("brass"), false, hs)
	M.box(Vector3(0.45, 0.6, 0.45), Vector3(23.7, 0.3, 11.5), Tex.mat("wood_dark"), true, hs)


func _hand(par: Node3D, length: float, w: float, m: Material) -> Node3D:
	var pv := Node3D.new()
	par.add_child(pv)
	M.box(Vector3(w, length, 0.006), Vector3(0, length / 2 - 0.02, 0.01), m, false, pv)
	return pv


func _sphere(r: float, pos: Vector3, m: Material, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _basement() -> void:
	var hs: Node = G.house
	var dk := Tex.flat(Color(0.29, 0.25, 0.22), 0.9)
	for i in 6:
		M.box(Vector3(0.25, 0.25 * (i + 1), 1.2), Vector3(41.6 - i * 0.25, 0.125 * (i + 1), 0.7), dk, false, hs)
	M.solid(Vector3(1.67, 2.0, 1.24), Vector3(40.9, 1.0, 0.7))
	for sp in [[40.35, 6.2], [42.4, 8.4]]:
		M.box(Vector3(0.45, 2.0, 2.4), Vector3(sp[0], 1.0, sp[1]), Tex.flat(Color(0.35, 0.29, 0.23), 0.8), true, hs)
		for i in 4:
			M.box(Vector3(0.42, 0.03, 2.36), Vector3(sp[0], 0.3 + i * 0.5, sp[1]), Tex.mat("wood"), false, hs)
			for k in 3:
				M.box(Vector3(0.2, 0.18, 0.18), Vector3(sp[0], 0.4 + i * 0.5, sp[1] - 0.8 + k * 0.8), Tex.flat([Color(0.42, 0.35, 0.23), Color(0.23, 0.29, 0.23), Color(0.35, 0.16, 0.1)][k], 0.8), false, hs)
	M.box(Vector3(0.6, 2.0, 0.7), Vector3(40.42, 1.0, 11.3), Tex.mat("metal"), true, hs)
	for i in 4:
		M.box(Vector3(0.005, 0.02, 0.4), Vector3(40.73, 1.6 - i * 0.06, 11.3), Tex.mat("black"), false, hs)
	var rustm := Tex.flat(Color(0.35, 0.16, 0.07), 0.8, 0.4)
	M.cyl(0.6, 0.6, 2.2, Vector3(52.5, 1.1, 1.6), rustm, hs)
	M.solid(Vector3(1.2, 2.2, 1.2), Vector3(52.5, 1.1, 1.6))
	for i in 3:
		var p: MeshInstance3D = M.cyl(0.06, 0.06, 8, Vector3(48 + i * 0.1, 2.55 - i * 0.12, 0.4 + i * 0.25), rustm, hs)
		p.rotation.z = PI / 2
	M.box(Vector3(0.62, 0.8, 0.15), Vector3(48, 1.5, 0.09), Tex.mat("metal"), false, hs)
	fuse_lamp = Tex.emissive(Color(0.35, 0.0, 0.0), 1.0)
	M.box(Vector3(0.06, 0.06, 0.02), Vector3(48.2, 1.82, 0.17), fuse_lamp, false, hs)
	M.box(Vector3(1.6, 0.9, 0.6), Vector3(46, 0.45, 4.4), Tex.mat("wood_dark"), true, hs)
	M.cyl(0.42, 0.46, 0.9, Vector3(49, 0.45, 8.8), Tex.flat(Color(0.35, 0.22, 0.13), 0.8), hs)
	M.solid(Vector3(0.9, 0.9, 0.9), Vector3(49, 0.45, 8.8))
	var meat := Tex.flat(Color(0.45, 0.12, 0.1), 0.35)
	for i in 7:
		var x := 46.5 + (i % 4) * 1.6
		var z := 6.4 + floorf(i / 4.0) * 3.6 + (i % 2) * 0.6
		M.cyl(0.006, 0.006, 1.2, Vector3(x, 2.2, z), Tex.mat("metal"), hs)
		var mm: MeshInstance3D = M.cyl(0.12 + randf() * 0.06, 0.09, 0.6 + randf() * 0.3, Vector3(x, 1.35, z), meat, hs)
		mm.rotation.z = (randf() - 0.5) * 0.3
	M.box(Vector3(1.4, 0.9, 0.7), Vector3(52.6, 0.45, 11.2), Tex.mat("cream"), true, hs)
	M.box(Vector3(1.6, 0.9, 0.8), Vector3(46.2, 0.45, 11.2), Tex.mat("wood_dark"), true, hs)


func decal(t: Texture2D, size: Vector2, pos: Vector3, rot: Vector3, parent: Node) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.4
	return M.quad(size, pos, rot, m, parent)


func _decals() -> void:
	M.scrawl("VRÁŤ SA", Vector3(16.2, 1.6, 6.09), 0.0, 96, G.real)
	M.scrawl("ON JE TU", Vector3(13.8, 1.55, 9.09), 0.0, 80, G.real)
	M.scrawl("NESVIEŤ", Vector3(0.09, 1.55, 2.9), PI / 2, 80, G.real)
	M.scrawl("PRE HOSŤA", Vector3(49, 1.7, 11.91), PI, 80, G.house)
	decal(tex.hands, Vector2(0.5, 0.7), Vector3(18.905, 1.55, 10.2), Vector3(0, -PI / 2, 0), G.real)
	decal(tex.blood1, Vector2(0.6, 0.45), Vector3(13.2, 0.924, 0.42), Vector3(-PI / 2, 0, 0), G.real)
	decal(tex.blood2, Vector2(1.6, 1.6), Vector3(49, 0.01, 8.8), Vector3(-PI / 2, 0, 0), G.house)
	decal(tex.blood1, Vector2(1.2, 1.2), Vector3(47.4, 0.01, 10.4), Vector3(-PI / 2, 0, 0), G.house)
	decal(tex.blood2, Vector2(1.0, 1.0), Vector3(45.2, 0.01, 3.6), Vector3(-PI / 2, 0, 0), G.house)
	decal(tex.blood1, Vector2(0.7, 2.6), Vector3(6.5, 0.012, 12.6), Vector3(-PI / 2, 0, 0), G.real)


func _mem_props() -> void:
	# dinner plates (tape 1 and endings)
	for p in [Vector3(12.5, 0.785, 3.25), Vector3(12.0, 0.785, 3.6), Vector3(13.0, 0.785, 3.6), Vector3(12.5, 0.785, 3.95), Vector3(12.15, 0.785, 3.3)]:
		M.cyl(0.13, 0.1, 0.02, p, Tex.mat("ceramic"), G.t1)
	# birthday cake and balloons (tape 2)
	var cake := Node3D.new()
	cake.position = Vector3(12.5, 0.775, 3.6)
	G.t2.add_child(cake)
	M.cyl(0.17, 0.17, 0.13, Vector3.ZERO, Tex.flat(Color(0.91, 0.85, 0.78), 0.6), cake)
	M.cyl(0.172, 0.172, 0.02, Vector3(0, 0.07, 0), Tex.flat(Color(0.83, 0.35, 0.48), 0.5), cake)
	var flame_m := Tex.emissive(Color(1.0, 0.75, 0.38), 4.0)
	for i in 9:
		var a := i / 9.0 * TAU
		M.cyl(0.006, 0.006, 0.07, Vector3(cos(a) * 0.11, 0.11, sin(a) * 0.11), Tex.flat([Color(0.4, 0.67, 0.87), Color(0.87, 0.4, 0.4), Color(0.87, 0.87, 0.4)][i % 3], 0.5), cake)
		var f := _sphere(0.01, Vector3(cos(a) * 0.11, 0.158, sin(a) * 0.11), flame_m, cake)
		f.scale = Vector3(0.8, 1.8, 0.8)
		cake_flames.append(f)
	var cl := OmniLight3D.new()
	cl.position = Vector3(0, 0.3, 0)
	cl.light_color = Color(1, 0.7, 0.4)
	cl.light_energy = 0.8
	cl.omni_range = 2.5
	cake.add_child(cl)
	cake_flames.append(cl)
	for bdef in [[9.6, 1.0, Color(0.69, 0.14, 0.14)], [9.8, 5.4, Color(0.82, 0.65, 0.16)], [15.4, 5.3, Color(0.16, 0.36, 0.69)], [7.5, 2.4, Color(0.69, 0.14, 0.14)], [2, 6.8, Color(0.16, 0.36, 0.69)]]:
		var b := _sphere(0.16, Vector3(bdef[0], 2.3, bdef[1]), Tex.flat(bdef[2], 0.25), G.t2)
		b.scale.y = 1.2
		M.cyl(0.002, 0.002, 1.5, Vector3(bdef[0], 1.5, bdef[1]), Tex.flat(Color.WHITE, 0.5), G.t2)
	# kazeta 0: socket and cable
	M.box(Vector3(0.08, 0.1, 0.02), Vector3(5.6, 0.32, 0.09), Tex.mat("cream"), false, G.t0)
	var cab: MeshInstance3D = M.cyl(0.006, 0.006, 1.2, Vector3(5.1, 0.33, 0.25), Tex.mat("black"), G.t0)
	cab.rotation = Vector3(0, 0.4, PI / 2)


func _anom_props() -> void:
	var A: Node = G.anom
	for i in 6:
		var c := chair(2 + randf() * 6, 1.5 + randf() * 5, randf() * 6, A)
		c.position.y = 0.6 + randf() * 1.3
		c.rotation.x = randf() * 2
		c.rotation.z = randf() * 2
	var sofa: Node3D = M.model("sofa", Vector3(4.5, H - 0.02, 6.8), 0.0, A)
	sofa.rotation.z = PI
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/tv.gdshader")
	sm.set_shader_parameter("mode", 1.0)
	static_mats.append(sm)
	for i in 7:
		var tv := Node3D.new()
		tv.position = Vector3(22.3 + (i % 2) * 0.5, 0.33 + floorf(i / 2.0) * 0.62, 7.2 + (i % 3) * 0.3)
		tv.rotation.y = -PI / 2 + (randf() - 0.5) * 0.6
		A.add_child(tv)
		M.box(Vector3(0.6, 0.55, 0.5), Vector3.ZERO, Tex.mat("plastic"), false, tv)
		M.quad(Vector2(0.44, 0.34), Vector3(0, 0, 0.251), Vector3.ZERO, sm, tv)
	for i in 5:
		var x := 10 + randf() * 4
		var z := 10 + randf() * 4
		M.cyl(0.003, 0.003, 1.2, Vector3(x, 2.2, z), Tex.mat("black"), A)
		var d := Node3D.new()
		d.position = Vector3(x, 1.3, z)
		A.add_child(d)
		M.cyl(0.05, 0.07, 0.25, Vector3.ZERO, Tex.flat(Color(0.88, 0.78, 0.82), 0.8), d)
		_sphere(0.07, Vector3(0, 0.17, 0), Tex.flat(Color(0.91, 0.86, 0.8), 0.6), d)
		d.rotation.z = PI
	M.scrawl("NIE JE TO SKUTOČNÉ", Vector3(4.5, 1.8, 7.9), PI, 64, A, Color(0.8, 0.08, 0.04))
	M.scrawl("POZRI SA ZA SEBA", Vector3(16.5, 1.6, 8.9), PI, 64, A, Color(0.8, 0.08, 0.04))
	for i in 4:
		var t: MeshInstance3D = M.box(Vector3(1.2, 0.05, 0.7), Vector3(10 + i * 3.5, 1.6 + randf(), 7.5), Tex.mat("wood"), false, A)
		t.rotation = Vector3(randf(), randf() * 3, randf())


func _hospital() -> void:
	var Hh: Node = G.hosp
	var X := HX
	var green := Tex.flat(Color(0.55, 0.65, 0.6), 0.85)
	M.box(Vector3(5, 0.1, 6), Vector3(X + 2.5, -0.05, 3), Tex.mat("tile2"), false, Hh)
	M.box(Vector3(5, 0.1, 6), Vector3(X + 2.5, 2.65, 3), Tex.flat(Color(0.85, 0.87, 0.86), 0.9), false, Hh)
	M.box(Vector3(5.4, 2.6, 0.2), Vector3(X + 2.5, 1.3, -0.1), green, true, Hh)
	M.box(Vector3(5.4, 2.6, 0.2), Vector3(X + 2.5, 1.3, 6.1), green, true, Hh)
	M.box(Vector3(0.2, 2.6, 6), Vector3(X - 0.1, 1.3, 3), green, true, Hh)
	M.box(Vector3(0.2, 2.6, 6), Vector3(X + 5.1, 1.3, 3), green, true, Hh)
	M.box(Vector3(1.2, 0.05, 0.25), Vector3(X + 2.5, 2.57, 3), Tex.emissive(Color(0.93, 0.96, 1.0), 2.0), false, Hh)
	M.box(Vector3(1.0, 0.5, 2.05), Vector3(X + 2.5, 0.3, 2.55), Tex.mat("metal"), true, Hh)
	M.box(Vector3(0.94, 0.16, 1.98), Vector3(X + 2.5, 0.62, 2.55), Tex.mat("sheet"), false, Hh)
	M.box(Vector3(0.6, 0.1, 0.32), Vector3(X + 2.5, 0.74, 1.75), Tex.mat("sheet"), false, Hh)
	M.box(Vector3(0.98, 0.24, 1.3), Vector3(X + 2.5, 0.8, 3.0), Tex.flat(Color(0.37, 0.55, 0.54), 0.95), false, Hh)
	M.box(Vector3(1.0, 0.9, 0.05), Vector3(X + 2.5, 0.75, 1.52), Tex.mat("metal"), false, Hh)
	var win := Tex.emissive(Color(0.86, 0.9, 0.93), 1.4)
	M.quad(Vector2(1.4, 1.3), Vector3(X + 4.99, 1.5, 3.2), Vector3(0, -PI / 2, 0), win, Hh)
	for i in 10:
		M.box(Vector3(0.02, 0.03, 1.4), Vector3(X + 4.97, 0.9 + i * 0.13, 3.2), Tex.flat(Color(0.78, 0.8, 0.78), 0.5), false, Hh)
	M.box(Vector3(0.4, 0.3, 0.25), Vector3(X + 3.5, 1.35, 1.7), Tex.mat("plastic"), false, Hh)
	M.cyl(0.02, 0.02, 1.2, Vector3(X + 3.5, 0.6, 1.7), Tex.mat("metal"), Hh)
	var ecg := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;render_mode unshaded;void fragment(){float x=fract(UV.x-TIME*.25);float p=fract(x*2.);float y=.45+.32*exp(-pow((p-.5)*30.,2.))-.08*exp(-pow((p-.56)*24.,2.));float d=abs((1.-UV.y)-y);vec3 c=vec3(.0,.05,.03)+vec3(.2,1.,.45)*smoothstep(.025,.0,d)*smoothstep(.0,.25,1.-fract(UV.x-TIME*.25+.02));ALBEDO=c*1.5;}"
	ecg.shader = sh
	M.quad(Vector2(0.34, 0.24), Vector3(X + 3.5, 1.35, 1.83), Vector3.ZERO, ecg, Hh)
	chair(X + 1.35, 2.6, PI / 2, Hh)
	var tvh := Node3D.new()
	tvh.position = Vector3(X + 4.55, 2.05, 5.55)
	tvh.rotation.y = -PI * 0.75
	Hh.add_child(tvh)
	M.box(Vector3(0.5, 0.4, 0.4), Vector3.ZERO, Tex.mat("plastic"), false, tvh)
	M.quad(Vector2(0.38, 0.29), Vector3(0, 0, 0.201), Vector3.ZERO, static_mats[0], tvh)
	var hc := Node3D.new()
	hc.position = Vector3(X + 2.5, 2.12, 0.02)
	Hh.add_child(hc)
	var face: MeshInstance3D = M.cyl(0.17, 0.17, 0.03, Vector3.ZERO, Tex.flat(Color(0.93, 0.93, 0.93), 0.4), hc)
	face.rotation.x = PI / 2
	hosp_hands = [_hand(hc, 0.09, 0.013, Tex.mat("black")), _hand(hc, 0.13, 0.009, Tex.mat("black")), _hand(hc, 0.14, 0.004, Tex.mat("black"))]
	for h in hosp_hands:
		h.position.z = 0.02


# =====================================================================
# night changes ("something is different")
# =====================================================================
func _changes() -> void:
	var R: Node = G.real
	var mk := func(id: String) -> Node3D:
		var n := Node3D.new()
		n.visible = false
		R.add_child(n)
		chg[id] = n
		return n
	var c1: Node3D = mk.call("chair")
	var ch := chair(12.5, 3.6, 0, c1)
	ch.position.y = 1.72
	ch.rotation.z = PI
	var c2: Node3D = mk.call("shoes")
	for s in [-1, 1]:
		M.box(Vector3(0.09, 0.06, 0.18), Vector3(1.15, 0.03, 12.1 + s * 0.07), Tex.flat(Color(0.54, 0.11, 0.11), 0.6), false, c2)
	var c3: Node3D = mk.call("doll")
	M.cyl(0.05, 0.08, 0.22, Vector3(2.4, 0.77, 14.2), Tex.flat(Color(0.85, 0.69, 0.75), 0.8), c3)
	_sphere(0.06, Vector3(2.4, 0.93, 14.2), Tex.flat(Color(0.91, 0.86, 0.8), 0.6), c3)
	var c4: Node3D = mk.call("tub")
	var water := StandardMaterial3D.new(); water.albedo_color = Color(0.02, 0.01, 0.01); water.metallic = 0.6; water.roughness = 0.02
	M.quad(Vector2(1.78, 0.56), Vector3(17.5, 0.5, 12.55), Vector3(-PI / 2, 0, 0), water, c4)
	var c5: Node3D = mk.call("mirror")
	M.box(Vector3(0.06, 1.1, 0.75), Vector3(8.86, 1.5, 12), Tex.mat("sheet"), false, c5)
	var c6: Node3D = mk.call("rocker")
	chair(20.2, 7.8, -2.2, c6)
	var c7: Node3D = mk.call("hand")
	decal(tex.hands, Vector2(0.4, 0.5), Vector3(0.12, 1.6, 5.8), Vector3(0, PI / 2, 0), c7)
	var c8: Node3D = mk.call("ball")
	_sphere(0.11, Vector3(4.5, 0.11, 6.6), Tex.flat(Color(0.75, 0.22, 0.17), 0.4), c8)
	var c9: Node3D = mk.call("clock2")
	var f: MeshInstance3D = M.cyl(0.16, 0.16, 0.03, Vector3(13.2, 1.8, 6.1), Tex.flat(Color(0.86, 0.83, 0.74), 0.5), c9)
	f.rotation.x = PI / 2
	var hz := Node3D.new()
	hz.position = Vector3(13.2, 1.8, 6.13)
	c9.add_child(hz)
	var hh := _hand(hz, 0.08, 0.012, Tex.mat("black"))
	hh.rotation.z = -(3.25 / 12.0) * TAU
	var mmh := _hand(hz, 0.12, 0.008, Tex.mat("black"))
	mmh.rotation.z = -PI / 2


# =====================================================================
# people (family, the child, the hospital)
# =====================================================================
func _people() -> void:
	people.mama = M.model("mama", Vector3.ZERO, 0.0, G.t1)
	people.otec = M.model("otec", Vector3.ZERO, 0.0, G.t1)
	people.lucia = M.model("lucia", Vector3.ZERO, 0.0, G.t1)
	people.kid_sit = M.model("kid_sit", Vector3.ZERO, 0.0, G.t5)
	people.kid_lie = M.model("kid_stand", Vector3.ZERO, 0.0, G.t7)
	people.kidH = M.model("kid_stand", Vector3(HX + 2.5, 0.8, 2.95), 0.0, G.hosp)
	people.kidH.rotation.x = -PI / 2
	people.mamaH = M.model("mama_hosp", Vector3(HX + 1.35, 0, 2.6), PI / 2, G.hosp)


func place(n: Node3D, x: float, z: float, ry: float, parent: Node = null, y := 0.0) -> void:
	if parent and n.get_parent() != parent:
		n.reparent(parent, false)
	n.position = Vector3(x, y, z)
	n.rotation = Vector3(0, ry, 0)


func family_seat(kind: String, grp: Node = null) -> void:
	var m: Node3D = people.mama
	var o: Node3D = people.otec
	var l: Node3D = people.lucia
	m.visible = true; o.visible = true; l.visible = true
	match kind:
		"dinner":
			place(m, 12.5, 2.86, 0, G.t1); place(o, 11.4, 3.6, PI / 2, G.t1); place(l, 13.6, 3.6, -PI / 2, G.t1)
		"party":
			place(m, 12.5, 2.4, 0, G.t2); place(o, 11.1, 3.6, PI / 2, G.t2); place(l, 13.9, 3.6, -PI / 2, G.t2)
		"tv":
			var g: Node = grp if grp else G.t4
			place(m, 4.1, 5.0, PI, g); place(o, 4.9, 5.0, PI, g); place(l, 1.45, 3.4, PI / 2, g)
