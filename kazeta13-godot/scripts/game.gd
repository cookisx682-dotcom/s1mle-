extends Node
## Game logic: player, interactables, items, tapes, monsters, days, scares, flux, saves, endings.

const HX := 70.0
const NS := 0.5
const NW := 112
const NH := 32

var M
var W
var U
var A

# ---------------------------------------------------------------- player nodes
var player: CharacterBody3D
var head: Node3D
var cam: Camera3D
var flash: SpotLight3D
var torch: Node3D
var torch_lens: StandardMaterial3D
var knife_v: Node3D
var hand_light: OmniLight3D
var torch_sway := Vector2.ZERO
const TORCH_REST := Vector3(0.17, -0.2, -0.33)

# ---------------------------------------------------------------- feed (TV)
var feed_vp: SubViewport
var feed_cam: Camera3D
var feed_tex: Texture2D
var me_fig: Node3D
var host_feed: Node3D
var angel: Node3D

# ---------------------------------------------------------------- state
var S := {}
var F := {}
var SNAP = null
var CP = null
var ST := {"time": 0.0, "deaths": 0, "chg": 0}
var run_id := 0
var inter: Array = []
var ITEMS := {}
var MON := {}
var cur = null
var nav := PackedByteArray()
var nav_door := []
var SC := {}
var tick_acc := 0.0
var beep_acc := 0.0
var mic_loud := 0.0
var mic_heard_t := -10.0
var room_t := 0.0

const LIT := {
	"living": {"r": [0, 0, 9, 8], "fix": [0, 10], "lamps": [[4.5, 2.3, 3.8], [7.7, 1.45, 1.6]], "sw": [5.7, 1.3, 7.9], "name": "obývačke"},
	"kitchen": {"r": [9, 0, 16, 6], "fix": [1], "lamps": [[12.5, 2.3, 3.4]], "sw": [9.1, 1.3, 2.1], "name": "kuchyni"},
	"kid": {"r": [9, 9, 15, 15], "fix": [6], "lamps": [[12, 2.3, 12]], "sw": [11.15, 1.3, 9.1], "name": "detskej izbe"},
	"bed": {"r": [19, 9, 24, 15], "fix": [9], "lamps": [[21.5, 2.3, 12]], "sw": [20.65, 1.3, 9.1], "name": "spálni"},
}
const POOLS := {
	"mem": [[4.5, 2.3, 3.8], [12.5, 2.3, 3.4], [12.5, 2.3, 7.5], [19.5, 2.3, 7.5], [12, 2.3, 12], [21.5, 2.3, 12]],
	"anom": [[4.5, 1.2, 4], [12.5, 1.2, 3], [16.5, 1.2, 7.5], [12, 1.2, 12], [21.5, 1.2, 12], [17, 1.2, 11]],
	"night": [[16.7, 0.35, 8.85], [11.5, 2.1, 12.5], [4.5, 2.1, 3.5]],
	"base": [[42, 2.2, 2.5], [48, 2.2, 2.5], [49, 2.2, 8.8]],
	"hosp": [[72.5, 2.35, 3]],
}
const WKIND := {"real": "real", "fake": "real", "t0": "mem", "t1": "mem", "t2": "mem", "t4": "mem", "endB": "mem", "t5": "night", "t7": "night", "a3": "anom", "a6": "anom", "hosp": "hosp"}
const HIDES := [{"x": 14.55, "z": 10.1, "yaw": PI / 2, "out": [13.75, 10.1]}, {"x": 9.72, "z": 12.5, "yaw": -PI / 2, "out": [10.7, 12.5], "bed": true},
	{"x": 19.55, "z": 10.6, "yaw": -PI / 2, "out": [20.4, 10.6]}, {"x": 23.55, "z": 7.5, "yaw": PI / 2, "out": [22.7, 7.5]}, {"x": 40.42, "z": 11.3, "yaw": -PI / 2, "out": [41.25, 11.3]}]
const WP := {"house": [[4.5, 6.5], [7.5, 2], [2, 1.8], [2, 6.8], [6, 10.5], [2, 10.5], [7.5, 13.8], [8.5, 7.5], [12.5, 7.5], [17, 7.5], [22.5, 7.5], [12.5, 2], [14.5, 4.8], [11.5, 11.5], [13.5, 13.2], [17, 10.8], [21.5, 10.8], [20.5, 13.5], [19, 3], [22, 4.5]],
	"base": [[42.5, 2.5], [41.3, 4.2], [41.3, 9.5], [43, 11], [46.5, 2.5], [51, 3.8], [46.5, 7.5], [51, 8.5], [47.5, 10.8], [52, 6.5]]}
const ARRIVE := {"house": [6.5, 13.9], "base": [42.4, 1.9]}
const HEADY := {"host": 2.05, "butcher": 1.85, "mother": 1.55, "sister": 1.12, "tv": 1.75, "mimic": 1.65}
const DOORLBL := {"lk": "Dvere", "kh": "Dvere", "kid": "Detská izba", "bath": "Kúpeľňa", "bed": "Spálňa rodičov", "study": "Pracovňa", "stor": "Komora", "front": "Vchodové dvere"}
const BATS := [[12.0, 0.957, 0.35], [14.5, 0.817, 6.3], [2.7, 0.017, 6.2], [17.3, 0.577, 12.2], [21.8, 0.917, 14.68], [6.2, 0.917, 8.33], [46, 0.917, 4.4], [20.5, 0.792, 1.0], [1.7, 0.917, 7.7], [15.32, 0.817, 14.2], [23.7, 0.617, 11.5], [42.4, 0.817, 8.4]]
const CHG := [
	{"id": "paint", "txt": "Obraz I visí hore nohami.", "pos": [7.2, 1.65, 7.88]},
	{"id": "photo", "txt": "Rodinná fotka je otočená k stene.", "pos": [10.6, 1.6, 6.12]},
	{"id": "granny", "txt": "Babičkin portrét zmizol.", "pos": [0.15, 1.7, 9.6]},
	{"id": "chair", "txt": "Na kuchynskom stole stojí stolička.", "pos": [12.5, 1.2, 3.6]},
	{"id": "shoes", "txt": "Pri vchodových dverách stoja malé topánky.", "pos": [1.15, 0.06, 12.1]},
	{"id": "doll", "txt": "Na schodoch sedí bábika.", "pos": [2.4, 0.8, 14.2]},
	{"id": "tub", "txt": "Vaňa je plná čiernej vody.", "pos": [17.5, 0.55, 12.55]},
	{"id": "mirror", "txt": "Zrkadlo v hale niekto zakryl plachtou.", "pos": [8.85, 1.55, 12]},
	{"id": "rocker", "txt": "Na chodbe stojí stolička, ktorá tu nebola.", "pos": [20.2, 0.5, 7.8]},
	{"id": "hand", "txt": "Na okne v obývačke je odtlačok ruky.", "pos": [0.12, 1.6, 5.8]},
	{"id": "ball", "txt": "Uprostred obývačky leží detská lopta.", "pos": [4.5, 0.12, 6.4]},
	{"id": "clock2", "txt": "Na chodbe visia hodiny, ktoré tu neboli. Ukazujú 3:15.", "pos": [13.2, 1.8, 6.12]},
]


func _reset_state() -> void:
	SC = {"t": 40.0, "amb": 10.0, "chop": null, "first": true}
	S = {"world": "real", "zone": "house", "day": 1, "running": false, "paused": false, "ui": false, "busy": false, "dead": false, "time": 0.0, "dayT": 0.0,
		"x": 1.4, "z": 11.5, "yaw": -PI / 2, "pitch": 0.0, "bob": 0.0, "step_acc": 0.0, "shake": 0.0, "clock": 0.0, "flash": false, "batt": 90.0, "stam": 100.0,
		"tired": false, "hp": 100.0, "hurt_t": 9.0, "knife": 0, "hidden": null, "hide_yaw": 0.0, "lit": {}, "inserted": null, "feed": null, "can_enter": false,
		"can_exit": false, "can_sleep": 0, "power": true, "lethal": true, "flick": 0.0, "flash_kill": 0.0, "force_flash": false, "qte": null, "noises": [],
		"blackout": false, "candles_out": false, "angel_on": false, "lock_cam": false, "cam_y": 0.0, "behind": null, "room_flick": null, "flux": null,
		"decoy": 0.0, "live_stage": 0, "ending": null, "t0done": false, "t0T": 0.0, "changes": [], "deaths_today": 0, "retry_cp": false, "step_n": 0,
		"replay_n": 0, "fast": false, "resume_cp": null, "invuln": 0.0, "run": false, "moving": false, "obj_text": "", "obj_text2": "", "cine": false,
		"skip": false, "sing_t": 0.0, "ang_idx": 0, "ang_away": 0.0, "fix_scare": false, "dmg": 0.0, "anom_v": 0.0, "stat_v": 0.0}


# =====================================================================
# setup
# =====================================================================
func build() -> void:
	_reset_state()
	_load_stats()
	_build_player()
	_build_feed()
	_build_monsters()
	_build_items()
	_build_inter()
	_build_nav()
	apply_world("real")


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.24
	sh.height = 1.6
	cs.shape = sh
	cs.position.y = 0.9
	player.add_child(cs)
	M.add_child(player)
	head = Node3D.new()
	head.position.y = 1.6
	player.add_child(head)
	cam = Camera3D.new()
	cam.fov = 72
	cam.near = 0.04
	cam.cull_mask = 1 | 4
	head.add_child(cam)
	flash = SpotLight3D.new()
	flash.light_color = Color(1.0, 0.94, 0.84)
	flash.light_energy = 0.0
	flash.spot_range = 18.0
	flash.spot_angle = 26.0
	flash.spot_angle_attenuation = 1.6
	flash.shadow_enabled = true
	flash.light_volumetric_fog_energy = 2.2
	flash.light_cull_mask = 1 | 2
	flash.position = Vector3(0.15, -0.15, -0.1)
	cam.add_child(flash)
	torch = Node3D.new()
	torch.position = TORCH_REST
	torch.rotation = Vector3(0.05, 0.1, 0)
	torch.scale = Vector3.ONE * 1.25
	cam.add_child(torch)
	var tm: Node3D = M.model("hand_flashlight", Vector3.ZERO, 0.0, torch)
	M.no_shadow(tm)
	torch_lens = Tex.emissive(Color(1.0, 0.95, 0.85), 0.0)
	M.set_mat(tm, "lens", torch_lens)
	hand_light = OmniLight3D.new()
	hand_light.position = Vector3(-0.08, 0.12, 0.05)
	hand_light.light_color = Color(0.9, 0.85, 0.8)
	hand_light.light_energy = 0.1
	hand_light.omni_range = 0.6
	hand_light.light_cull_mask = 4
	torch.add_child(hand_light)
	M.merge_static(torch)
	for c in torch.find_children("*", "GeometryInstance3D", true, false):
		c.layers = 4
	knife_v = Node3D.new()
	knife_v.position = Vector3(-0.24, -0.26, -0.45)
	knife_v.rotation = Vector3(-0.3, 0.2, 0.1)
	cam.add_child(knife_v)
	M.box(Vector3(0.006, 0.03, 0.16), Vector3(0, 0, -0.1), Tex.mat("metal"), false, knife_v)
	M.box(Vector3(0.018, 0.026, 0.1), Vector3.ZERO, Tex.mat("wood_dark"), false, knife_v)
	for c in knife_v.find_children("*", "GeometryInstance3D", true, false):
		c.layers = 4
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var kl := OmniLight3D.new()
	kl.light_energy = 0.08
	kl.omni_range = 0.5
	kl.light_cull_mask = 4
	knife_v.add_child(kl)
	knife_v.visible = false


func _build_feed() -> void:
	feed_vp = SubViewport.new()
	feed_vp.size = Vector2i(512, 384)
	feed_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	M.add_child(feed_vp)
	feed_cam = Camera3D.new()
	feed_cam.fov = 62
	feed_cam.cull_mask = 1 | 2
	feed_vp.add_child(feed_cam)
	me_fig = M.model("m_double", Vector3.ZERO, 0.0, M)
	host_feed = M.model("m_host", Vector3.ZERO, 0.0, M)
	for n in [me_fig, host_feed]:
		_merge_model(n)
		for c in n.find_children("*", "GeometryInstance3D", true, false):
			c.layers = 2
		n.visible = false
	angel = M.model("m_host", Vector3.ZERO, 0.0, M)
	_merge_model(angel)
	angel.visible = false


func _merge_model(n: Node3D) -> void:
	for k in ["head", "screen", "cleaver", "tv"]:
		var c = n.find_child(k, true, false)
		if c:
			c.set_meta("dynamic", true)
	M.merge_static(n)


# =====================================================================
# helpers
# =====================================================================
func has(id: String) -> bool:
	return F.get("got_" + id, false)


func isRealW(w: String) -> bool:
	return w == "real" or w == "fake"


func isMem(w: String) -> bool:
	return WKIND.get(w, "") == "mem" or WKIND.get(w, "") == "night"


func isAnom(w: String) -> bool:
	return WKIND.get(w, "") == "anom"


func zone_of(x: float) -> String:
	return "hosp" if x > 60 else ("base" if x > 35 else "house")


func fwd() -> Vector3:
	return Vector3(-sin(S.yaw), 0, -cos(S.yaw))


func dif() -> Dictionary:
	return C.DIFF[clampi(int(M.SET.diff), 0, 2)]


func nm():
	var n: String = str(M.SET.get("name", "")).strip_edges()
	return n if n != "" else null


func fmt_n(t: String) -> String:
	var re := RegEx.new()
	re.compile("\\{N(?:\\|([^}]*))?\\}")
	var out := t
	for mm in re.search_all(t):
		var d = mm.get_string(1) if mm.get_group_count() >= 1 and mm.get_start(1) >= 0 else "zlatko"
		out = out.replace(mm.get_string(0), nm() if nm() else d)
	return out


func live() -> bool:
	return S.running and not S.paused and not S.ui


func tp(x: float, z: float, yaw: float, pitch := 0.0) -> void:
	S.x = x
	S.z = z
	S.yaw = yaw
	S.pitch = pitch
	S.zone = zone_of(x)
	player.position = Vector3(x, 0, z)


func los(ax: float, az: float, bx: float, bz: float, y := 1.5) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(ax, y, az), Vector3(bx, y, bz))
	q.exclude = [player.get_rid()]
	return M.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func tween_val(setter: Callable, a: float, b: float, sec: float) -> void:
	var tw := create_tween()
	tw.tween_method(setter, a, b, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func post(k: String, v: float) -> void:
	M.post.set_shader_parameter(k, v)


func objective(t: String) -> void:
	S.obj_text = t
	U.objective(t)


func say(lines: Array) -> void:
	if S.fast:
		return
	for l in lines:
		U.say(l[0], fmt_n(l[1]), l[2] if l.size() > 2 else 0.0)


func msg(t: String, d := 3.0) -> void:
	if S.fast:
		return
	U.msg(fmt_n(t), d)


# ---------------------------------------------------------------- day-script waits
func until(cond: Callable, nc := false) -> bool:
	var id := run_id
	if not nc and S.replay_n > 0:
		S.replay_n -= 1
		S.step_n += 1
		if S.replay_n == 0:
			call_deferred("cp_apply")
		await get_tree().process_frame
		return id == run_id
	while true:
		if id != run_id:
			return false
		if live() and cond.call():
			break
		await get_tree().process_frame
	if id != run_id:
		return false
	if not nc:
		S.step_n += 1
		cp_save()
	return true


func wait(sec: float, nc := false) -> bool:
	var t: float = S.time + sec
	return await until(func(): return S.time >= t, nc)


func talk(lines: Array) -> void:
	say(lines)
	var tot := 0.0
	for l in lines:
		tot += l[2] if l.size() > 2 else 1.6 + l[1].length() * 0.055
	await wait(tot + 0.2, true)


# =====================================================================
# world presentation
# =====================================================================
func apply_world(w: String, feed := false) -> void:
	var k: String = WKIND.get(w, "real")
	var Gr: Dictionary = W.G
	Gr.real.visible = isRealW(w)
	Gr.fake.visible = w == "fake"
	Gr.mem.visible = isMem(w)
	Gr.anom.visible = isAnom(w)
	for id in ["t1", "t2", "t4", "t5", "t7", "t0"]:
		Gr[id].visible = w == id or (w == "endB" and id == "t1")
	Gr.a3.visible = w == "a3"
	Gr.a6.visible = w == "a6"
	Gr.hosp.visible = w == "hosp"
	var env: Environment = M.env
	var P := {}
	match k:
		"mem": P = {"amb": Color(1.0, 0.85, 0.65), "ae": 0.35, "fog": Color(1.0, 0.85, 0.65), "fd": 0.02, "moon": 0.0, "vhs": 1.0, "anom": 0.0, "grain": 0.05, "win": Color(0.17, 0.11, 0.19)}
		"night": P = {"amb": Color(0.38, 0.44, 0.63), "ae": 0.07, "fog": Color(0.3, 0.35, 0.5), "fd": 0.03, "moon": 0.2, "vhs": 1.0, "anom": 0.0, "grain": 0.06, "win": Color(0.1, 0.14, 0.25)}
		"anom": P = {"amb": Color(1.0, 0.38, 0.31), "ae": 0.2, "fog": Color(0.55, 0.06, 0.03), "fd": 0.05, "moon": 0.0, "vhs": 0.7, "anom": 1.0, "grain": 0.09, "win": Color(0.31, 0.0, 0.0)}
		"hosp": P = {"amb": Color(0.9, 0.94, 1.0), "ae": 0.5, "fog": Color(0.75, 0.78, 0.8), "fd": 0.012, "moon": 0.0, "vhs": 0.0, "anom": 0.0, "grain": 0.05, "win": Color(0.86, 0.9, 0.93)}
		_: P = {"amb": Color(0.45, 0.5, 0.65), "ae": 0.06, "fog": Color(0.75, 0.75, 0.78), "fd": 0.035, "moon": 0.12, "vhs": 0.0, "anom": 0.0, "grain": 0.06, "win": Color(0.1, 0.13, 0.22)}
	env.ambient_light_color = P.amb
	env.ambient_light_energy = P.ae
	env.volumetric_fog_albedo = P.fog
	env.volumetric_fog_density = P.fd
	M.moon.light_energy = P.moon if S.zone == "house" else 0.0
	if not feed:
		post("vhs", P.vhs)
		post("grain", P.grain)
		if not S.flux and S.decoy <= 0:
			S.anom_v = P.anom
	for m in W.win_mats:
		m.emission = P.win
		m.albedo_color = P.win
	# light pool
	var pl: Array = []
	var col := Color(1.0, 0.76, 0.53)
	var en := 0.0
	var rng := 9.0
	var rooms: Array = []
	if k == "mem" and not S.blackout:
		pl = POOLS.mem; en = 1.8
	elif k == "night":
		pl = POOLS.night; col = Color(1.0, 0.63, 0.38); en = 1.0; rng = 6.5
	elif k == "anom":
		pl = POOLS.anom; col = Color(1.0, 0.13, 0.06); en = 2.6; rng = 8.5
	elif k == "hosp":
		pl = POOLS.hosp; col = Color(0.91, 0.95, 1.0); en = 2.5; rng = 10.0
	elif S.zone == "base" and S.power and not feed:
		pl = POOLS.base; col = Color(1.0, 0.69, 0.44); en = 1.1; rng = 7.0
	elif k == "real" and S.power:
		for r in LIT:
			if S.lit.get(r, false):
				for lp in LIT[r].lamps:
					pl.append(lp)
					rooms.append(r)
		col = Color(1.0, 0.81, 0.59); en = 2.6; rng = 10.5
	S.pool_rooms = rooms
	for i in W.pool.size():
		var l: OmniLight3D = W.pool[i]
		if i < pl.size():
			l.position = Vector3(pl[i][0], pl[i][1], pl[i][2])
			l.light_color = col
			l.light_energy = en
			l.omni_range = rng
			l.visible = true
		else:
			l.visible = false
	for i in W.lamp_fix.size():
		W.lamp_fix[i].emission_energy_multiplier = 3.0 if (k == "mem" and not S.blackout) else 0.0
	if k == "real" and S.power:
		for r in LIT:
			if S.lit.get(r, false):
				for j in LIT[r].fix:
					W.lamp_fix[j].emission_energy_multiplier = 3.0
	W.bulb_mat.emission_energy_multiplier = 3.0 if (isRealW(w) and S.power) else 0.0
	W.tv_light.light_energy = (0.9 if isRealW(w) and S.power else (0.5 if k == "night" else 0.3))
	W.fam_mat.albedo_texture = W.tex.family_fake if w == "fake" else W.tex.family
	W.fuse_lamp.emission = Color(0.0, 0.6, 0.1) if F.get("powerOn", false) else Color(0.4, 0.0, 0.0)
	for id in ITEMS:
		ITEMS[id].node.visible = not F.get("got_" + id, false) and ITEMS[id].when.call(w)
	for t in MON:
		var m = MON[t]
		m.node.visible = m.active and w in m.worlds and not feed
	angel.visible = S.angel_on and w == S.world and not feed


func flash_i() -> float:
	if S.force_flash:
		return 2.6
	if S.flash_kill > 0 or not S.flash or S.hidden != null:
		return 0.0
	var i := 2.7
	if S.world != "fake" and S.batt < 25:
		i *= 0.3 + 0.7 * (S.batt / 25.0)
	if S.flick > 0 and randf() < 0.5:
		i *= 0.06
	return i


func set_world(w: String) -> void:
	S.world = w
	apply_world(w)
	var k: String = WKIND.get(w, "real")
	A.set_loop("drone", 0.0 if w == "hosp" else (0.06 if k == "mem" else (0.35 if k == "anom" else 0.22)), 1.0)
	A.set_loop("room", 0.04 if w == "hosp" else 0.18, 1.0)
	A.set_loop("mainshum", 0.05 if k in ["mem", "night"] else 0.0)
	A.set_loop("music", 0.12 if w in ["t1", "endB", "t4"] else 0.0)
	M.set_lowpass(3600.0 if k in ["mem", "night"] else (2600.0 if k == "anom" else 20000.0))
	U.batt_visible(w != "hosp" and w != "endB")
	W.tv_mat.set_shader_parameter("mode", 1.0)
	S.behind = null


# =====================================================================
# interactables & items
# =====================================================================
func I(pos: Callable, r: float, when: Callable, label: Callable, use: Callable) -> void:
	inter.append({"pos": pos, "r": r, "when": when, "label": label, "use": use})


func V(x: float, y: float, z: float) -> Callable:
	var p := Vector3(x, y, z)
	return func(): return p


func item(id: String, node: Node3D, label: String, when: Callable, on_take = null, r := 2.0) -> void:
	ITEMS[id] = {"node": node, "when": when}
	node.visible = false
	I(func(): return node.global_position, r, func(): return node.visible and S.hidden == null, func(): return label,
		func(): take(id, on_take))


func take(id: String, cb = null) -> void:
	F["got_" + id] = true
	ITEMS[id].node.visible = false
	A.play("pick", -4)
	emit_noise(S.x, S.z, 2.5)
	if cb is Callable:
		cb.call()


func tape_obj(big: String, small: String, x: float, y: float, z: float, ry := 0.0) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	g.rotation.y = ry
	W.G.house.add_child(g)
	M.model("tape", Vector3.ZERO, 0.0, g)
	var l := Label3D.new()
	l.text = big + ("  " + small if small != "" else "")
	l.font = M.f_mark
	l.font_size = 22
	l.pixel_size = 0.0012
	l.modulate = Color(0.1, 0.08, 0.06)
	l.rotation.x = -PI / 2
	l.position = Vector3(0, 0.0156, 0)
	l.shaded = true
	g.add_child(l)
	return g


func small_obj(kind: String, x: float, y: float, z: float) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	W.G.house.add_child(g)
	match kind:
		"bat":
			for o in [-0.019, 0.019]:
				var b: MeshInstance3D = M.cyl(0.017, 0.017, 0.06, Vector3(0, 0, o), Tex.flat(Color(0.11, 0.11, 0.11), 0.45), g)
				b.rotation.z = PI / 2
				var band: MeshInstance3D = M.cyl(0.0172, 0.0172, 0.022, Vector3(0.016, 0, o), Tex.flat(Color(0.78, 0.4, 0.11), 0.4), g)
				band.rotation.z = PI / 2
		"key":
			var r := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.014; tm.outer_radius = 0.026
			r.mesh = tm
			r.material_override = Tex.mat("brass")
			g.add_child(r)
			M.box(Vector3(0.008, 0.006, 0.06), Vector3(0, 0, 0.045), Tex.mat("brass"), false, g)
		"knife":
			M.box(Vector3(0.2, 0.004, 0.03), Vector3(0.1, 0, 0), Tex.mat("metal"), false, g)
			M.box(Vector3(0.11, 0.02, 0.025), Vector3(-0.05, 0, 0), Tex.mat("wood_dark"), false, g)
		"reel":
			M.cyl(0.08, 0.08, 0.02, Vector3.ZERO, Tex.flat(Color(0.23, 0.16, 0.1), 0.3, 0.3), g)
			M.cyl(0.03, 0.03, 0.022, Vector3.ZERO, Tex.mat("cream"), g)
		"doll":
			M.cyl(0.05, 0.08, 0.22, Vector3(0, 0.11, 0), Tex.flat(Color(0.85, 0.69, 0.75), 0.8), g)
			W._sphere(0.06, Vector3(0, 0.27, 0), Tex.flat(Color(0.91, 0.86, 0.8), 0.6), g)
		"ball":
			W._sphere(0.11, Vector3.ZERO, Tex.flat(Color(0.75, 0.22, 0.17), 0.4), g)
		"blocks":
			for i in 4:
				M.box(Vector3(0.08, 0.08, 0.08), Vector3((i % 2) * 0.09, floorf(i / 2.0) * 0.08, 0), Tex.flat([Color(0.67, 0.2, 0.2), Color(0.2, 0.6, 0.4), Color(0.2, 0.4, 0.67), Color(0.8, 0.67, 0.2)][i], 0.6), false, g)
		"bear":
			var bm := Tex.flat(Color(0.48, 0.32, 0.2), 1.0)
			W._sphere(0.12, Vector3(0, 0.12, 0), bm, g)
			W._sphere(0.085, Vector3(0, 0.28, 0), bm, g)
		"note":
			M.quad(Vector2(0.2, 0.27), Vector3.ZERO, Vector3(-PI / 2, 0, 0), Tex.flat(Color(0.89, 0.85, 0.78), 0.9), g)
		"tape_roll":
			var r := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.025; tm.outer_radius = 0.06
			r.mesh = tm
			r.material_override = Tex.flat(Color(0.85, 0.81, 0.66), 0.35)
			g.add_child(r)
	return g


func _build_items() -> void:
	var real := func(w): return isRealW(w)
	item("tape1", tape_obj("1", "VEČERA", 4.35, 0.457, 3.15, 0.3), "Vziať kazetu 1 · VEČERA", func(w): return isRealW(w) and S.day == 1)
	item("tape2", tape_obj("2", "NARODENINY", 9.85, 0.53, 12.3, -0.6), "Vziať kazetu 2 · NARODENINY", func(w): return isRealW(w) and S.day == 1)
	item("tape3", tape_obj("3", "VYSIELANIE", 21.3, 0.79, 1.05, 0.2), "Vziať kazetu 3 · VYSIELANIE", func(w): return isRealW(w) and S.day == 2)
	item("tape4", tape_obj("4", "HODINY", 12.7, 0.787, 3.5, 0.5), "Vziať kazetu 4 · HODINY", func(w): return isRealW(w) and S.day == 3)
	item("tape5", tape_obj("5", "DIEŤA", 49, 0.915, 8.8, 1.1), "Vziať kazetu 5 · DIEŤA", func(w): return isRealW(w) and S.day == 3)
	item("tape6", tape_obj("6", "HRAČKY", 21.2, 0.915, 14.55, 0.1), "Vziať kazetu 6 · HRAČKY", func(w): return isRealW(w) and S.day == 4 and F.get("photosOk", false))
	item("tape7", tape_obj("7", "NOC", 17.6, 0.515, 14.6, 0.7), "Vziať kazetu 7 · NOC", func(w): return isRealW(w) and S.day == 5 and F.get("powerOn", false))
	item("tapeX", tape_obj("?", "", 18.72, 0.935, 10.2, 1.2), "Vziať kazetu bez čísla", func(w): return w == "fake")
	item("tape13", tape_obj("13", "REALITA", 46.2, 0.915, 11.2, 0.4), "Vziať kazetu 13 · REALITA", func(w): return w == "real" and S.day == 6 and F.get("revealed", false), break_tape)
	item("tape0", tape_obj("0", "", 10.6, 0.515, 14.55, 0.4), "Vziať kazetu bez štítku… je na nej nula", func(w): return isRealW(w) and S.day == 7 and all_notes())
	item("knife", small_obj("knife", 12.2, 0.925, 0.45), "Vziať nôž", real, func():
		S.knife = 3
		msg("Nôž.", 2))
	item("keyKid", small_obj("key", 10.2, 0.93, 0.4), "Vziať kľúč od detskej izby", func(w): return w == "t1", func():
		objective("Vráť sa k televízoru.")
		S.can_exit = true
		say([["MAMA", "Ešte jeden tanier. Pre hosťa.", 2.8]]))
	item("keyBase", small_obj("key", 8.45, 0.25, 0.72), "Vziať kľúč od pivnice", func(w): return isRealW(w) and F.get("clockOk", false))
	for r in [["reel1", 17.2, 0.6, 12.55], ["reel2", 22.3, 0.66, 12.9], ["reel3", 13.6, 0.66, 14.7]]:
		item(r[0], small_obj("reel", r[1], r[2], r[3]), "Vziať cievku pásky", func(w): return w == "a3", func():
			var n := 0
			for k in ["reel1", "reel2", "reel3"]:
				n += 1 if has(k) else 0
			msg("Cievka %d z 3" % n, 2)
			if n == 3:
				S.can_exit = true
				objective("Máš všetky cievky. Bež k televízoru!"))
	for r in [["toy1", "bear", 7.5, 0, 13.5], ["toy2", "doll", 13.6, 0.92, 0.4], ["toy3", "ball", 19.5, 0.12, 3.5], ["toy4", "blocks", 20.5, 0.04, 8.4]]:
		item(r[0], small_obj(r[1], r[2], r[3], r[4]), "Vziať hračku", func(w): return w == "a6", func():
			var n := 0
			for k in ["toy1", "toy2", "toy3", "toy4"]:
				n += 1 if has(k) else 0
			msg("Hračka %d zo 4" % n, 2)
			A.play("giggle", -6)
			if n == 4:
				S.can_exit = true
				objective("Máš všetky hračky. Bež k televízoru!"))
	for d in range(1, 8):
		for i in 4:
			var p = BATS[(d * 5 + i * 3) % BATS.size()]
			var dd := d
			item("b%d_%d" % [d, i], small_obj("bat", p[0], p[1] + 0.002 * i, p[2] + 0.01 * i), "Vziať batérie", func(w): return isRealW(w) and S.day == dd, func():
				S.batt = minf(100.0, S.batt + 40.0)
				say([["", "Batérie. Baterka zase svieti.", 2]]))
	item("spool", small_obj("reel", 15.32, 0.83, 13.5), "Vziať náhradnú cievku", func(w): return isRealW(w) and S.day == 7 and F.get("t13broken", false) and not F.get("t13fixed", false), func(): msg("Náhradná cievka.", 2))
	item("roll", small_obj("tape_roll", 16.5, 1.33, 0.45), "Vziať lepiacu pásku", func(w): return isRealW(w) and S.day == 7 and F.get("t13broken", false) and not F.get("t13fixed", false), func(): msg("Lepiaca páska.", 2))
	# notes
	for n in [["n1", 13.65, 0.645, 14.72, 1], ["n2", 20.7, 0.778, 0.9, 2], ["n3", 46.7, 0.915, 11.35, 3], ["n4", 23.68, 0.605, 11.42, 4], ["n5", 18.3, 0.405, 13.5, 5], ["n6", 6.0, 0.905, 8.33, 6]]:
		var o := small_obj("note", n[1], n[2], n[3])
		var nid: String = n[0]
		var dmin: int = n[4]
		I(func(): return o.global_position, 1.8, func():
			o.visible = isRealW(S.world) and S.day >= dmin
			return o.visible and S.hidden == null, func(): return "Prečítať", func():
			F["read_" + nid] = true
			if all_notes():
				add_clue("zero")
			U.show_note(C.NOTES[nid][0], C.NOTES[nid][1])
			A.play("pick", -6))


func all_notes() -> bool:
	for k in C.NOTES:
		if not F.get("read_" + k, false):
			return false
	return true


func add_clue(k: String) -> void:
	if not F.has("clues"):
		F.clues = []
	if k in F.clues:
		return
	F.clues.append(k)
	U.toast("Denník: nový záznam")


func emit_noise(x: float, z: float, r: float) -> void:
	S.noises.append({"x": x, "z": z, "r": r})


func lit_at(x: float, z: float, m := 0.0):
	if not isRealW(S.world) or not S.power or zone_of(x) != "house":
		return null
	for k in LIT:
		var r = LIT[k].r
		if S.lit.get(k, false) and x > r[0] + m and x < r[2] - m and z > r[1] + m and z < r[3] - m:
			return k
	return null


func safe_now() -> bool:
	return lit_at(S.x, S.z, 0.15) != null


func _build_inter() -> void:
	for k in LIT:
		var sw = LIT[k].sw
		var kk: String = k
		I(V(sw[0], sw[1], sw[2]), 2.0, func(): return isRealW(S.world) and S.hidden == null, func(): return "Zhasnúť svetlo" if S.lit.get(kk, false) else "Rozsvietiť", func():
			A.play("click", -4)
			if not S.power:
				say([["", "Vypínač cvakol. Nič. Nejde prúd.", 2.4]])
				return
			S.lit[kk] = not S.lit.get(kk, false)
			apply_world(S.world)
			if S.lit[kk]:
				add_clue("light"))
	for b in [[10.2, 1.3, 6.1], [3.0, 1.3, 8.1], [16.1, 1.3, 9.1], [17.2, 1.3, 0.1]]:
		I(V(b[0], b[1], b[2]), 1.8, func(): return isRealW(S.world) and S.hidden == null, func(): return "Vypínač", func():
			A.play("click", -4)
			say([["", ["Cvak. Nič. Žiarovka je prasknutá.", "Cvak. Tma. Niekto vykrútil žiarovku.", "Cvak. Iskra. Nič."][randi() % 3], 2.4]]))
	for i in 4:
		var p = W.PAINT_POS[i]
		var ii := i
		I(V(p[0], p[1], p[2]), 2.6, func(): return S.world != "hosp", func(): return "Prezrieť obraz", func():
			add_clue("p%d" % (ii + 1))
			U.show_image(W.tex["paint%d" % (ii + 1)], "Obraz " + ["I", "II", "III", "IV"][ii]))
	I(V(10.6, 1.6, 6.1), 2.2, func(): return S.world != "hosp", func(): return "Pozrieť fotku", func():
		if S.world == "fake":
			U.show_image(W.tex.family_fake, "Je na nej päť ľudí. Ten piaty je vyšší než dvere.")
		else:
			U.show_image(W.tex.family, "Mama, otec, Lucia a ty. Október 1998."))
	I(V(0.1, 1.7, 9.6), 2.4, func(): return S.world != "hosp", func(): return "Pozrieť portrét", func(): U.show_image(W.tex.granny, "Babička. Niekto jej vyškrabal oči."))
	I(V(13.25, 0.66, 14.6), 1.8, func(): return S.world != "hosp" and S.hidden == null, func(): return "Pozrieť kresbu", func():
		F.sawDrawing = true
		add_clue("drawing")
		U.show_image(W.tex.drawing, "Detská kresba. Poistky."))
	for mp in [[8.9, 12.0], [18.92, 10.2]]:
		I(V(mp[0], 1.55, mp[1]), 1.8, func(): return S.world != "hosp", func(): return "Pozrieť do zrkadla", func():
			if S.world == "fake":
				add_clue("mirror")
				say([["", "V zrkadle nie si.", 2.6]])
			elif S.day >= 4 and isRealW(S.world) and randf() < 0.5:
				say([["", "Za tebou niekto stál. Teraz tam nie je nikto.", 3]])
				A.play("giggle", -4)
			else:
				say([["", "Tvoj odraz. Vyzerá unavene.", 2.4]]))
	I(V(4.5, 0.85, 0.95), 2.4, func(): return S.world != "hosp" and S.hidden == null, tv_label, tv_use)
	I(V(8.45, 1.62, 0.7), 2.4, func(): return S.world != "hosp" and S.hidden == null, func(): return "Veľké hodiny", clock_use)
	I(V(4.5, 0.6, 5.0), 2.2, func(): return isRealW(S.world) and S.can_sleep == S.day and S.hidden == null, func(): return "Ísť spať", func(): F["slept%d" % S.day] = true)
	I(V(15.9, 1.3, 2.25), 1.8, func(): return isRealW(S.world) and W.doors.study.locked, func(): return "Číselný zámok", study_keypad)
	I(V(21.2, 1.0, 14.6), 2.0, func(): return isRealW(S.world) and S.day >= 4 and not F.get("photosOk", false), func(): return "Prezrieť fotky na komode", func():
		add_clue("photos")
		U.open_photos(func(o):
			if o == [0, 1, 2, 3]:
				F.photosOk = true
				A.play("lock")
				msg("V šuplíku niečo cvaklo.", 3)
				apply_world(S.world)
				return true
			return false))
	I(V(48, 1.5, 0.2), 2.0, func(): return isRealW(S.world) and S.day == 5 and not F.get("powerOn", false), func(): return "Poistková skriňa", func():
		U.open_levers(func(st):
			if st == [1, 0, 1, 1, 0]:
				F.powerOn = true
				S.power = true
				apply_world(S.world)
				A.play("slam", -8, 0.6)
				msg("Prúd ide.", 2.5)
				return true
			return false))
	I(V(6.5, 1.0, 14.9), 2.0, func(): return isRealW(S.world) and S.zone == "house" and S.hidden == null, func():
		if W.doors.base.locked:
			return "Odomknúť pivnicu" if has("keyBase") else "Pivnica · zamknuté"
		return "Zísť do pivnice", base_door)
	I(V(41.3, 0.9, 0.7), 2.0, func(): return S.zone == "base" and S.hidden == null, func(): return "Ísť hore", func(): stairs("house"))
	for id in DOORLBL:
		var d = W.doors[id]
		var did: String = id
		I(V(d.x, 1.0, d.z), 1.9, func(): return S.world != "hosp" and S.hidden == null, func(): return door_label(did), func(): door_use(did))
	for h in HIDES:
		var hh = h
		var p := Vector3(h.out[0] - 0.3, 0.4, h.z) if h.get("bed", false) else Vector3(h.x + (h.out[0] - h.x) * 0.4, 1.0, h.z)
		I(func(): return p, 1.9, func(): return S.hidden == null and S.world != "hosp" and S.world != "endB", func(): return "Schovať sa pod posteľ" if hh.get("bed", false) else "Schovať sa do skrine", func(): hide(hh))
	# memory worlds
	I(V(12.5, 0.9, 3.6), 2.0, func(): return S.world == "t2" and not S.candles_out, func(): return "Sfúknuť sviečky", blow_candles)
	I(func(): return W.people.kid_sit.global_position + Vector3(0, 0.7, 0) if S.world == "t5" else W.people.kid_lie.global_position + Vector3(0, 0.3, 0), 2.0,
		func(): return (S.world == "t5" and not F.get("t5talk", false)) or (S.world == "t7" and not F.get("t7talk", false)),
		func(): return "Prihovoriť sa dieťaťu" if S.world == "t5" else "Dotknúť sa dieťaťa", kid_talk)
	I(V(5.6, 0.32, 0.2), 2.2, func(): return S.world == "t0" and not S.t0done, func(): return "Vytiahnuť zástrčku zo zásuvky", func():
		S.t0done = true
		ending_c())
	# hospital
	I(V(HX + 2.5, 0.8, 2.0), 2.2, func(): return S.world == "hosp" and S.ending == null, func(): return "Zobudiť sa", ending_wake)
	I(V(HX + 4.55, 2.05, 5.55), 2.6, func(): return S.world == "hosp" and S.ending == null, func(): return "Vrátiť sa domov", ending_stay)
	# night changes
	for c in CHG:
		var cc = c
		I(V(c.pos[0], c.pos[1], c.pos[2]), 2.4, func(): return isRealW(S.world) and S.hidden == null and cc.id in S.changes and not F.get("chg_%s%d" % [cc.id, S.day], false),
			func(): return "Niečo tu nesedí…", func(): change_found(cc))
	# repair table
	I(V(21, 0.85, 1.0), 2.2, func(): return isRealW(S.world) and S.hidden == null and has("tape13") and F.get("t13broken", false) and not F.get("t13fixed", false),
		func(): return "Opraviť kazetu 13" if has("spool") and has("roll") else "Na opravu treba cievku a lepiacu pásku", func():
			if not (has("spool") and has("roll")):
				say([["", "Chýba mi náhradná cievka alebo lepiaca páska.", 2.6]])
				return
			U.open_repair(func():
				F.t13fixed = true
				A.play("lock"), func():
				if F.get("t13fixed", false) and not S.fix_scare:
					S.fix_scare = true
					await sleep(0.9)
					if not safe_now():
						name_call()))


func door_label(id: String) -> String:
	var d = W.doors[id]
	if d.locked:
		if id == "kid" and has("keyKid") and isRealW(S.world):
			return "Odomknúť kľúčom"
		return DOORLBL[id] + " · zamknuté"
	return "Zavrieť" if d.open else "Otvoriť"


func door_use(id: String) -> void:
	var d = W.doors[id]
	if d.locked:
		if id == "kid" and has("keyKid") and isRealW(S.world):
			d.locked = false
			F.kidOpen = true
			A.play("lock")
			await sleep(0.45)
			W.set_door(id, true)
			A.play_at("creak", Vector3(d.x, 1, d.z), -4)
			return
		A.play("lock", -4)
		if id == "study" and isRealW(S.world):
			study_keypad()
			return
		say([["", "Zamknuté. Zvonka." if id == "front" else ("Spí tam. Nechoď dnu." if id == "kid" and S.world == "t1" else "Zamknuté."), 2]])
		return
	W.set_door(id, not d.open)
	A.play_at("creak", Vector3(d.x, 1, d.z), -4)
	emit_noise(d.x, d.z, 6)


func study_keypad() -> void:
	add_clue("keypad")
	if not F.get("sawKeypad", false):
		F.sawKeypad = true
		say([["", "Na dverách je vyškrabané: SPOČÍTAJ, ČO VIDÍŠ. I · II · III · IV", 4.5]])
	U.open_keypad(func(c):
		if c == "7391":
			W.doors.study.locked = false
			F.studyOpen = true
			A.play("lock")
			get_tree().create_timer(0.4).timeout.connect(func():
				W.set_door("study", true)
				A.play("creak", -6))
			return true
		return false)


func clock_use() -> void:
	if S.world == "t4":
		F.t4clock = true
		add_clue("t4")
		S.can_exit = true
		msg("Hodiny stoja. Tri pätnásť.", 3)
		objective("Vráť sa k televízoru.")
		return
	if isRealW(S.world) and S.day == 3 and F.get("t4seen", false) and not F.get("clockOk", false):
		U.open_clock(func(h, mn):
			if h == 3 and mn == 15:
				F.clockOk = true
				A.play("lock")
				W.compart.position.z = 0.9
				W.compart.rotation.y = 1.2
				apply_world(S.world)
				msg("V hodinách sa otvorila skrinka.", 3)
				return true
			return false)
		return
	if S.world != "real":
		add_clue("clock")
	say([["", "Veľké hodiny. Kyvadlo sa hýbe." if S.world == "real" else "Ručičky idú dozadu.", 2.4]])


func base_door() -> void:
	if W.doors.base.locked:
		if has("keyBase"):
			W.doors.base.locked = false
			F.baseOpen = true
			A.play("lock")
			msg("Pivnica je odomknutá.", 2)
			return
		A.play("lock", -4)
		say([["", "Pivnica je zamknutá.", 2]])
		return
	stairs("base")


func stairs(to: String) -> void:
	await static_to(func():
		if to == "base":
			tp(42.3, 1.7, PI)
		else:
			tp(6.5, 14.2, 0.0)
		S.zone = to
		apply_world(S.world)
		A.play("creak", -4), 0.5)


# =====================================================================
# TV and tapes
# =====================================================================
func hand_list() -> Array:
	var out := []
	for id in ["0", "1", "2", "3", "4", "5", "6", "7", "X", "13"]:
		if has("tape" + id) and not F.get("used_" + id, false) and (id != "13" or F.get("t13fixed", false)):
			out.append(id)
	return out


func tv_label():
	if isRealW(S.world):
		if not S.power:
			return "Televízor · nejde prúd"
		if S.inserted != null and S.can_enter:
			return "Vojsť do televízora"
		if S.inserted != null:
			return null
		if hand_list().size() > 0:
			return "Vložiť kazetu do videa"
		return null
	if S.world == "endB":
		return null
	return "Vystúpiť z kazety" if S.can_exit else "Ešte nemôžeš odísť"


func tv_use() -> void:
	if isRealW(S.world):
		if not S.power:
			say([["", "Obrazovka je čierna. Vypadol prúd.", 2.4]])
			return
		if S.inserted != null and S.can_enter:
			enter_tape()
			return
		if hand_list().size() > 0:
			insert_tape()
		return
	if S.can_exit:
		exit_tape()
	else:
		A.play("whoosh", -14)


func insert_tape(force = null) -> void:
	var L := hand_list()
	if force == null and L.size() > 1:
		U.choose_tape(L, func(id): insert_tape(id))
		return
	var id: String = force if force != null else (L[0] if L.size() > 0 else "")
	if id == "" or not C.FEEDS.has(id):
		return
	F["used_" + id] = true
	S.inserted = id
	S.can_enter = false
	A.play("insert")
	W.tv_mat.set_shader_parameter("mode", 1.0)
	await sleep(0.9)
	var FD: Dictionary = C.FEEDS[id]
	S.feed = FD
	if id == "2":
		W.family_seat("party")
	if id == "1":
		W.family_seat("dinner")
	if id == "4":
		W.family_seat("tv")
	if id == "5":
		W.place(W.people.kid_sit, 10.05, 12.6, atan2(4.25, 1.7), W.G.t5)
	if id == "7":
		W.place(W.people.kid_lie, 9.72, 13.3, 0, W.G.t7, 0.52)
		W.people.kid_lie.rotation.x = -PI / 2
	if FD.get("live", false):
		W.tv_mat.set_shader_parameter("feed", feed_vp.get_texture())
		W.tv_mat.set_shader_parameter("gain", 1.6)
		W.tv_mat.set_shader_parameter("mode", 2.0)
		feed_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		live_tape()
		return
	await feed_snapshot(FD)
	objective("")
	say(FD.lines)
	var t := 0.0
	for l in FD.lines:
		t += l[2]
	await sleep(t)
	if S.inserted == id:
		S.can_enter = true
		objective("Obraz ťa ťahá dnu. Vojdi do televízora.")


func feed_snapshot(FD: Dictionary) -> void:
	var p = FD.pos
	var l = FD.look
	feed_cam.position = Vector3(p[0], p[1], p[2])
	feed_cam.look_at(Vector3(l[0], l[1], l[2]))
	post("stat", 0.9)
	apply_world(FD.world, true)
	if FD.world == "t1" or FD.world == "t2" or FD.world == "t4":
		pass
	feed_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := feed_vp.get_texture().get_image()
	feed_tex = ImageTexture.create_from_image(img)
	apply_world(S.world)
	post("stat", 0.0)
	W.tv_mat.set_shader_parameter("feed", feed_tex)
	W.tv_mat.set_shader_parameter("gain", 1.3)
	W.tv_mat.set_shader_parameter("mode", 2.0)


func enter_tape() -> void:
	var id = S.inserted
	if id == null:
		return
	await static_to(func():
		S.inserted = null
		S.can_enter = false
		S.feed = null
		S.can_exit = false
		W.tv_mat.set_shader_parameter("mode", 1.0)
		start_tape(id), 0.9)


func set_osd(on: bool, time := "", date := "", rec := false, anom := false) -> void:
	U.osd(on, time, date, rec, anom)


var door_snap = null


func start_tape(id: String) -> void:
	var map := {"0": "t0", "1": "t1", "2": "t2", "3": "a3", "4": "t4", "5": "t5", "6": "a6", "7": "t7", "13": "hosp"}
	var w: String = map.get(id, "")
	if w == "":
		return
	if id == "13":
		start_hosp()
		return
	door_snap = []
	for d in W.door_list:
		door_snap.append([d.id, d.open, d.locked])
		W.set_door(d.id, false, d.id == "front" or d.id == "base", true)
	set_world(w)
	tp(4.5, 1.7, PI)
	S.angel_on = false
	if w == "t0":
		start_t0()
	elif w == "t1":
		W.family_seat("dinner")
		W.set_door("kid", false, true, true)
		set_osd(true, "PM 7:42", "OKT. 14 1998")
		angel.position = Vector3(22.5, 0, 7.5)
		S.angel_on = true
		S.ang_idx = 0
		S.ang_away = 0.0
		F.t1kitchen = false
		objective("Rodina večeria v kuchyni. Choď za nimi.")
	elif w == "t2":
		W.family_seat("party")
		S.candles_out = false
		S.blackout = false
		for f in W.cake_flames:
			f.visible = true
		apply_world("t2")
		set_osd(true, "PM 6:15", "NOV. 02 1998")
		angel.position = Vector3(12.5, 0, 4.4)
		angel.rotation.y = PI
		S.angel_on = true
		objective("Sfúkni sviečky.")
		A.set_loop("music", 0.12)
	elif w == "t4":
		W.family_seat("tv")
		set_osd(true, "PM 9:30", "OKT. 20 1998")
		objective("Veľké hodiny v obývačke stoja. Pozri sa na ne.")
	elif w == "t5":
		set_osd(true, "AM 2:40", "OKT. 16 1998")
		W.place(W.people.kid_sit, 10.05, 12.6, atan2(14.3 - 10.05, 14.3 - 12.6), W.G.t5)
		angel.position = Vector3(14.3, 0, 14.3)
		angel.rotation.y = atan2(10 - 14.3, 12.6 - 14.3)
		S.angel_on = true
		W.set_door("kid", true, false, true)
		objective("Detská izba. Prihovor sa dieťaťu.")
	elif w == "t7":
		set_osd(true, "AM 3:07", "OKT. 21 1998")
		W.place(W.people.kid_lie, 9.72, 13.3, 0, W.G.t7, 0.52)
		W.people.kid_lie.rotation.x = -PI / 2
		W.set_door("kid", true, false, true)
		set_mon("host", {"x": 15.0, "z": 3.0, "mode": "patrol", "worlds": ["t7"], "wp": 1, "tape_only": true})
		objective("Detská izba.")
		S.obj_text2 = "Detská izba."
	elif w == "a3" or w == "a6":
		set_osd(true, "??:??", "?? ?? ????", false, true)
		for d in W.door_list:
			if d.id != "front" and d.id != "base":
				W.set_door(d.id, true, false, true)
		set_mon("tv", {"x": 22.0, "z": 13.0, "worlds": ["a3", "a6"], "delay": 6.0, "tape_only": true, "speed": 2.9 if w == "a6" else 2.6})
		if w == "a6":
			var s = MON.sister
			s.active = true; s.mode = "chase"; s.x = 2.0; s.z = 12.0; s.contact = true; s.present = 1.0; s.worlds = ["real", "a6"]
			objective("Nájdi 4 Luciine hračky.")
		else:
			objective("Nájdi 3 cievky pásky.")
	apply_world(w)


func exit_tape() -> void:
	var from: String = S.world
	await static_to(func():
		S.angel_on = false
		S.can_exit = false
		F["done_" + S.world] = true
		set_world("real")
		tp(4.5, 1.7, PI)
		set_osd(false)
		for t in MON:
			if MON[t].get("tape_only", false):
				MON[t].active = false
		if from == "a3" or from == "a6":
			MON.tv.active = false
			MON.sister.mode = "haunt", 0.9)
	if door_snap != null:
		for ds in door_snap:
			W.set_door(ds[0], ds[1], ds[2], true)
		door_snap = null
	if from == "t7":
		F.done_t7 = true
		MON.host.active = false
	if from == "t4":
		F.t4seen = true
	apply_world("real")


func static_to(fn: Callable, sec := 0.7) -> void:
	S.busy = true
	A.play("whoosh", -10)
	A.set_loop("tv", 0.5, 8)
	await tween_val(func(v): post("stat", v), 0.0, 1.0, sec * 0.6)
	await fn.call()
	await sleep(0.22)
	A.set_loop("tv", 0.0, 4)
	await tween_val(func(v): post("stat", v), 1.0, 0.0, sec)
	S.busy = false


func kid_talk() -> void:
	if S.world == "t5":
		F.t5talk = true
		await talk([["DIEŤA", "Mama hovorí, že ten pán je náš hosť.", 3], ["DIEŤA", "Ale ja viem, odkiaľ prišiel. Z kazety.", 3], ["DIEŤA", "Vždy, keď zaspím pri televízore, je o krok bližšie.", 3.4]])
		S.can_exit = true
		objective("Vráť sa k televízoru.")
	else:
		F.t7talk = true
		await talk([["DIEŤA", "Ty si… ja?", 2.4], ["DIEŤA", "Mama hovorí, že spím už veľmi dlho.", 3], ["DIEŤA", "Kazeta 13 je pravda. Nájdeš ju dole, keď nebude kam utiecť.", 3.6], ["DIEŤA", "Choď. Už ťa hľadá.", 2.4]])
		S.can_exit = true
		objective("Vráť sa k televízoru. Potichu.")


func blow_candles() -> void:
	S.candles_out = true
	S.busy = true
	A.play("blow", -4)
	A.set_loop("music", 0.0, 6)
	for f in W.cake_flames:
		f.visible = false
	await sleep(0.7)
	S.blackout = true
	S.flash = false
	apply_world("t2")
	A.set_loop("drone", 0.0, 10)
	await sleep(1.8)
	for p in ["mama", "otec", "lucia"]:
		W.people[p].visible = false
	S.blackout = false
	apply_world("t2")
	for l in W.pool:
		l.light_energy *= 0.4
	await sleep(0.3)
	await jumpscare()
	await static_to(func():
		for f in W.cake_flames:
			f.visible = true
		W.family_seat("dinner")
		F.t2done = true
		F.done_t2 = true
		S.angel_on = false
		if door_snap != null:
			for ds in door_snap:
				W.set_door(ds[0], ds[1], ds[2], true)
			door_snap = null
		set_world("real")
		tp(4.5, 1.7, PI)
		set_osd(false), 1.2)


func jumpscare() -> void:
	S.busy = true
	var f := fwd()
	angel.position = Vector3(S.x + f.x * 0.5, 1.6 - HEADY.host, S.z + f.z * 0.5)
	angel.rotation = Vector3(0, atan2(S.x - angel.position.x, S.z - angel.position.z), 0)
	S.angel_on = true
	angel.visible = true
	S.force_flash = true
	S.pitch = 0.0
	A.play("stinger")
	post("glitch", 1.0)
	S.shake = 1.0
	U.face_flash(0.08)
	await sleep(0.8)
	post("glitch", 0.0)
	S.force_flash = false
	S.angel_on = false
	angel.visible = false
	S.busy = false


# live tape (day 6)
func live_tape() -> void:
	objective("")
	S.live_stage = 0
	say(C.FEEDS.X.lines)
	await sleep(5.8)
	if S.world != "fake":
		return
	host_feed.visible = true
	S.live_stage = 1
	A.play("heart")
	say([["", "Neotáčaj sa.", 4]])
	await sleep(4.5)
	if S.live_stage != 1:
		return
	S.live_stage = 2
	A.play("heart", 2, 1.2)
	await sleep(2.0)
	if S.live_stage == 2:
		reveal_fake()


func reveal_fake() -> void:
	if S.live_stage == 3:
		return
	S.live_stage = 3
	host_feed.visible = false
	S.feed = null
	S.inserted = null
	feed_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	W.tv_mat.set_shader_parameter("mode", 1.0)
	await jumpscare()
	await static_to(func():
		set_world("real")
		S.batt = minf(S.batt, 31.0)
		F.revealed = true
		me_fig.visible = false, 1.3)


func update_live() -> void:
	if S.feed == null or not S.feed.get("live", false):
		me_fig.visible = false
		return
	me_fig.visible = true
	me_fig.position = Vector3(S.x, 0, S.z)
	me_fig.rotation.y = S.yaw + PI
	var b := Vector3(sin(S.yaw), 0, cos(S.yaw))
	feed_cam.position = Vector3(clampf(S.x + b.x * 2.6, 1.2, 7.8), 2.25, clampf(S.z + b.z * 2.6, 1.2, 7.6))
	feed_cam.look_at(Vector3(S.x, 1.35, S.z))
	if host_feed.visible:
		var k := 0.45 if S.live_stage == 2 else 0.95
		host_feed.position = Vector3(S.x + b.x * k, 0, S.z + b.z * k)
		host_feed.rotation.y = S.yaw + PI
	if S.live_stage >= 1 and S.live_stage < 3:
		var tv := atan2(-(4.5 - S.x), -(0.95 - S.z))
		var df := wrapf(S.yaw - tv, -PI, PI)
		if absf(df) > 1.9:
			reveal_fake()


func update_mem(dt: float) -> void:
	if S.world == "t1" and S.angel_on:
		angel.rotation.y = atan2(S.x - angel.position.x, S.z - angel.position.z)
		if not F.get("t1kitchen", false) and S.x > 9 and S.z < 6:
			F.t1kitchen = true
			objective("Nájdi kľúč od detskej izby.")
			say([["LUCIA", "On ťa vidí, {N}.", 2.6]])
		if F.get("t1kitchen", false):
			var lh = W.people.lucia.find_child("head", true, false)
			if lh:
				var ang: float = atan2(S.x - W.people.lucia.position.x, S.z - W.people.lucia.position.z) - W.people.lucia.rotation.y
				lh.rotation.y += (clampf(wrapf(ang, -PI, PI), -1.3, 1.3) - lh.rotation.y) * dt * 2
		if has("keyKid"):
			var v := Vector3(angel.position.x - S.x, 0, angel.position.z - S.z).normalized()
			var inv := v.dot(fwd()) > 0.45 and los(S.x, S.z, angel.position.x, angel.position.z)
			var P := [[22.5, 7.5], [19.7, 7.45], [16.5, 7.3], [13.6, 7.3], [10.2, 7.3]]
			S.ang_away = 0.0 if inv else S.ang_away + dt
			if S.ang_away > 1.1 and S.ang_idx < P.size() - 1:
				S.ang_idx += 1
				S.ang_away = 0.0
				angel.position.x = P[S.ang_idx][0]
				angel.position.z = P[S.ang_idx][1]
				A.play_at("heavy", angel.position + Vector3(0, 0.2, 0), -6)
	if S.world == "t2" and not S.candles_out:
		var ah = angel.find_child("head", true, false)
		if ah:
			ah.rotation.y = sin(S.time * 0.4) * 0.2
		S.sing_t -= dt
		if S.sing_t <= 0:
			S.sing_t = 7.0
			say([["RODINA", "♪ Všetko najlepšie k narodeninám… ♪", 2.6]])


# kazeta 0
func start_t0() -> void:
	W.family_seat("tv", W.G.t0)
	W.place(W.people.kid_sit, 4.5, 1.75, PI, W.G.t0, -0.38)
	set_osd(true, "PM 7:40", "OKT. 14 1998")
	objective("Toto je tá noc. Zastav to.")
	S.t0done = false
	S.t0T = 40.0
	await sleep(6)
	if S.world == "t0":
		say([["MAMA", "Zlatko, odstúp od toho!", 2.4]])


func update_t0(dt: float) -> void:
	if S.world != "t0" or S.t0done or S.busy:
		return
	S.t0T -= dt
	A.set_loop("tv", clampf(0.1 + (40 - S.t0T) * 0.012, 0, 0.6))
	if S.t0T < 12 and randf() < dt * 2:
		S.flick = 0.2
	if S.t0T <= 0:
		S.t0done = true
		_t0_late()


func _t0_late() -> void:
	A.play("slam", 0, 1.6)
	A.play("stinger")
	await tween_val(func(v): post("stat", v), 0.0, 1.0, 0.3)
	msg("Neskoro.", 2.5)
	await sleep(1.5)
	F.used_0 = false
	await static_to(func():
		if door_snap != null:
			for ds in door_snap:
				W.set_door(ds[0], ds[1], ds[2], true)
			door_snap = null
		set_world("real")
		tp(4.5, 1.7, PI)
		set_osd(false)
		objective("Pusti kazetu 13 v obývačke. Alebo to skús znova."), 0.9)
	post("stat", 0.0)


# =====================================================================
# hospital and endings
# =====================================================================
func start_hosp() -> void:
	mons_off()
	set_world("hosp")
	tp(HX + 3.9, 4.9, PI * 0.15)
	set_osd(false)
	S.flash = false
	S.ending = null
	objective("")
	await sleep(2.5)
	objective("Zobuď sa. Alebo sa vráť domov, do kaziet.")


func ending_wake() -> void:
	S.ending = "A"
	S.busy = true
	S.lock_cam = true
	objective("")
	await tween_val(func(v): post("fade", v), 0.0, 1.0, 1.6)
	W.place(W.people.mamaH, HX + 1.7, 2.15, PI / 2)
	tp(HX + 2.5, 1.95, PI / 2, 1.15)
	S.cam_y = 0.86
	await tween_val(func(v): post("fade", v), 1.0, 0.0, 2.2)
	say([["MAMA", "{N}… Bože, ty si hore.", 3], ["MAMA", "Doktor! Je hore!", 2.4]])
	await sleep(5.6)
	angel.position = Vector3(HX + 0.45, 0, 5.45)
	angel.rotation.y = PI * 0.8
	S.angel_on = true
	angel.visible = true
	var y0: float = S.yaw
	var p0: float = S.pitch
	var ty := atan2(-(HX + 0.45 - S.x), -(5.45 - S.z))
	await tween_val(func(v):
		S.yaw = y0 + wrapf(ty - y0, -PI, PI) * v
		S.pitch = p0 + (0.12 - p0) * v, 0.0, 1.0, 4.2)
	A.play("heart")
	await sleep(0.9)
	A.play("heart")
	await sleep(4.0)
	end_game("KONIEC · PREBUDENIE", "Mama plače od šťastia. Prístroje pípajú. V rohu izby stojí niekto, koho nikto iný nevidí. Hodiny nad posteľou idú dozadu. Naozaj si vonku?")


func ending_stay() -> void:
	S.ending = "B"
	S.busy = true
	await static_to(func():
		W.family_seat("dinner")
		set_world("endB")
		S.lock_cam = true
		tp(12.5, 4.3, 0.0, -0.32)
		S.cam_y = 1.12
		set_osd(true, "PM 7:42", "OKT. 14 1998", true), 1.2)
	say([["MAMA", "Konečne si doma, {N}.", 2.6], ["OTEC", "Sadni si. Už nikam nepôjdeš.", 2.8], ["LUCIA", "Nikdy.", 2]])
	await sleep(8.6)
	await tween_val(func(v): post("fade", v), 0.0, 1.0, 2.5)
	end_game("KONIEC · ZOSTAL SI", "Rodina je zase spolu, navždy na pásku. Niekde v nemocnici sa na posteli pohne prikrývka. Kazeta 14 sa práve nahráva.")


func ending_c() -> void:
	S.ending = "C"
	S.busy = true
	A.play("click")
	W.tv_mat.set_shader_parameter("on", 0.0)
	A.set_loop("tv", 0.0, 10)
	await sleep(0.9)
	await static_to(func():
		W.family_seat("dinner")
		set_world("endB")
		W.place(W.people.kid_sit, 12.5, 4.4, PI, W.G.t1)
		S.lock_cam = true
		tp(12.5, 6.6, 0.0, -0.35)
		S.cam_y = 2.05
		set_osd(false), 1.4)
	say([["MAMA", "Kto chce ešte polievku?", 2.6], ["LUCIA", "Ja!", 1.6], ["DIEŤA", "Mami… v rohu niekto stojí.", 3], ["MAMA", "Nikto tam nie je, zlatko. Jedz.", 3]])
	await sleep(11.5)
	await tween_val(func(v): post("fade", v), 0.0, 1.0, 2.5)
	W.tv_mat.set_shader_parameter("on", 1.0)
	end_game("KONIEC · KAZETA 0", "Zástrčka vypadla zo zásuvky. Televízor zhasol. V tú noc nikto nezmizol. Hosť nikdy nebol cudzí. Celé roky stál v rohu izby a pozeral sa na rodinu, ktorú stratil. Bolo to tvoje vlastné ja z budúcnosti, ktorá sa už nestane.")


func end_game(t: String, p: String) -> void:
	S.running = false
	A.set_loop("chase", 0.0)
	A.set_loop("music", 0.0)
	SNAP = null
	CP = null
	M.save_game()
	var best := _stats_best()
	U.show_end(t, p, S.ending if S.ending else "?", _stats_block(), best)


# =====================================================================
# player
# =====================================================================
func handle_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and S.running and not S.paused and not S.ui:
		look(e.relative.x, e.relative.y)
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if S.cine and (k == KEY_SPACE or k == KEY_ENTER or k == KEY_ESCAPE):
			S.skip = true
			return
		if not S.running:
			return
		if k == KEY_ESCAPE:
			if S.ui:
				U.close_panel()
			elif not S.dead:
				U.toggle_pause()
			return
		if S.paused:
			return
		if k == KEY_TAB or k == KEY_I:
			if S.ui:
				U.close_panel()
			else:
				open_bag()
			return
		if k == KEY_M:
			if S.ui:
				U.close_panel()
			else:
				open_map()
			return
		if k == KEY_E or k == KEY_ENTER:
			act()
		elif k == KEY_F:
			toggle_flash()
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if S.cine:
			S.skip = true
			return
		if S.running and not S.paused and not S.ui:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				act()


func look(dx: float, dy: float) -> void:
	var k := 0.0022 * float(M.SET.sens)
	if S.lock_cam or (S.busy and S.qte == null):
		return
	S.yaw -= dx * k
	S.pitch = clampf(S.pitch - dy * k, -1.35, 1.35)
	torch_sway += Vector2(dx, dy) * 0.00012
	if S.hidden != null:
		var df := wrapf(S.yaw - S.hide_yaw, -PI, PI)
		S.yaw = S.hide_yaw + clampf(df, -0.7, 0.7)
		S.pitch = clampf(S.pitch, -0.4, 0.4)


func act() -> void:
	if not S.running or S.paused or S.dead:
		return
	if S.qte != null:
		qte_resolve(true)
		return
	if S.ui or S.busy:
		return
	if S.hidden != null:
		unhide()
		return
	if cur != null and cur.lbl != null:
		cur.o.use.call()


func toggle_flash() -> void:
	if S.busy or S.world == "hosp" or S.hidden != null or S.ui:
		return
	if not S.flash and S.batt <= 0 and S.world != "fake":
		A.play("click", -4)
		say([["", "Baterka je vybitá. Nájdi batérie.", 2.4]])
		return
	S.flash = not S.flash
	A.play("click", -6)


func open_bag() -> void:
	if not S.running or S.dead or S.busy or S.ui:
		return
	U.open_bag()


func open_map() -> void:
	if not S.running or S.dead or S.busy or S.ui:
		return
	U.open_map()


func move_player(dt: float) -> void:
	var f := 0.0
	var s := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): f += 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): f -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): s += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): s -= 1
	var mag := Vector2(f, s).length()
	if mag > 1.0:
		f /= mag; s /= mag
	var want := Input.is_physical_key_pressed(KEY_SHIFT) and mag > 0.1
	if S.tired and S.stam > 45:
		S.tired = false
	S.run = want and not S.tired and S.stam > 0
	if S.run:
		S.stam -= dt * 19.0
		S.stam_cd = 1.2
		if S.stam <= 0:
			S.stam = 0.0
			S.tired = true
			A.play("pant", -6)
	else:
		S.stam_cd = S.get("stam_cd", 0.0) - dt
		if S.stam_cd <= 0:
			S.stam = minf(100.0, S.stam + dt * (11.0 if mag > 0.1 else 20.0))
	var sp: float = (3.5 if S.run else (1.4 if S.tired else 1.9)) * minf(1.0, mag)
	var fw := fwd()
	var rt := Vector3(cos(S.yaw), 0, -sin(S.yaw))
	player.velocity = (fw * f + rt * s) * sp
	var before := player.position
	player.move_and_slide()
	player.position.y = 0
	var moved := Vector2(player.position.x - before.x, player.position.z - before.z).length()
	S.x = player.position.x
	S.z = player.position.z
	S.moving = moved > 0.002
	S.bob += moved * (3.2 if S.run else 3.6)
	S.step_acc += moved
	if S.step_acc > (0.85 if S.run else 0.7):
		S.step_acc = 0.0
		A.play("step%d" % (randi() % 5), -13.0 if S.run else -18.0, randf_range(0.92, 1.06))
		mimic_echo()
		emit_noise(S.x, S.z, 10.0 if S.run else 2.3)


func hide(h: Dictionary) -> void:
	S.hidden = h
	S.pre_flash = S.flash
	tp(h.x, h.z, h.yaw, 0.02 if h.get("bed", false) else 0.0)
	S.hide_yaw = h.yaw
	U.hide_overlay(true, h.get("bed", false), A.mic_on)
	A.play("creak", -6)
	for t in MON:
		var m = MON[t]
		if m.active and m.state == "chase" and Vector2(m.x - S.x, m.z - S.z).length() < 6 and los(m.x, m.z, S.x, S.z):
			m.hunt_hide = h


func unhide() -> void:
	var h = S.hidden
	if h == null:
		return
	S.hidden = null
	tp(h.out[0], h.out[1], S.yaw)
	S.flash = false
	U.hide_overlay(false)
	A.play("creak", -6)


func mic_heard() -> void:
	if S.hidden == null or S.time - mic_heard_t < 2.5:
		return
	mic_heard_t = S.time
	U.hide_heard()
	emit_noise(S.x, S.z, 18)
	for t in MON:
		var m = MON[t]
		if m.active and zone_of(m.x) == S.zone and S.world in m.worlds and Vector2(m.x - S.x, m.z - S.z).length() < 18:
			m.hunt_hide = S.hidden
			m.state = "chase"
			m.tx = S.x
			m.tz = S.z


# ---------------------------------------------------------------- damage, death, knife
func damage(n: float, cause: String) -> void:
	if S.dead or safe_now() or S.invuln > 0:
		return
	n = roundf(n * dif().dmg)
	S.hp = maxf(0.0, S.hp - n)
	S.hurt_t = 0.0
	A.play("hurt")
	S.shake = 0.9
	S.dmg = 1.0
	if S.hp <= 0:
		die(cause + " ťa dostal" + ("a" if cause == "Matka" or cause == "Sestra" else "") + ".")


func die(text: String, m = null) -> void:
	if S.dead:
		return
	S.dead = true
	S.busy = true
	A.set_loop("chase", 0.0, 6)
	if S.hidden != null:
		S.hidden = null
		U.hide_overlay(false)
	if m != null:
		death_pose(m)
	A.play("stinger")
	U.face_flash(0.26)
	post("glitch", 1.0)
	S.shake = 1.2
	await sleep(1.3)
	post("glitch", 0.0)
	post("fade", 1.0)
	show_death(text)


func death_pose(m: Dictionary) -> void:
	var f := fwd()
	m.x = S.x + f.x * 0.55
	m.z = S.z + f.z * 0.55
	m.node.position = Vector3(m.x, 1.6 - HEADY[m.type], m.z)
	m.node.rotation = Vector3(0, atan2(S.x - m.x, S.z - m.z), 0)
	m.node.visible = true
	m.frozen = true
	S.force_flash = true
	S.pitch = 0.0


func show_death(text: String) -> void:
	ST.deaths += 1
	_save_stats()
	S.deaths_today += 1
	var can_cp: bool = S.deaths_today == 1 and CP != null and CP.day == S.day
	S.retry_cp = can_cp
	var t := text + (" Pokračuješ od posledného uloženia. Ešte jedna smrť a deň %d začne odznova." % S.day if can_cp else " Druhá smrť. Deň %d sa začína odznova." % S.day)
	U.show_death(t, can_cp)


func retry() -> void:
	post("fade", 0.0)
	if S.retry_cp:
		start_day(S.day, true, CP)
	else:
		CP = null
		S.deaths_today = 0
		M.save_game()
		start_day(S.day, true)


func mon_attack(m: Dictionary) -> void:
	if S.dead or S.qte != null or S.busy:
		return
	if S.knife > 0:
		S.qte = {"m": m, "t": 1.3, "max": 1.3}
		U.qte(true)
		A.play("stinger", -4)
		S.shake = 0.6
	else:
		hit_by(m)


func hit_by(m: Dictionary) -> void:
	damage(m.dmg, m.name)
	m.cool = 2.8
	m.back = 1.4
	if m.type == "host":
		m.cool = 16.0
		teleport_far(m)
	if m.type == "mimic":
		m.state = "wander"
		m.face = 0.0
		teleport_far(m)


func qte_resolve(ok: bool) -> void:
	var q = S.qte
	S.qte = null
	U.qte(false)
	if q == null:
		return
	var m: Dictionary = q.m
	if ok:
		S.knife -= 1
		A.play("knife_hit")
		A.play_at("shriek", m.node.global_position + Vector3(0, 1.5, 0))
		post("glitch", 0.7)
		get_tree().create_timer(0.2).timeout.connect(func(): post("glitch", 0.0))
		m.stun = 4.5
		if m.type == "butcher" or m.type == "mother":
			m.state = "patrol"
		m.hunt_hide = null
		knife_v.rotation.x = -1.2
		get_tree().create_timer(0.2).timeout.connect(func(): knife_v.rotation.x = -0.3)
		msg("Zásah! Nôž vydrží ešte %d×." % S.knife if S.knife > 0 else "Nôž sa zlomil.", 2.4)
	else:
		hit_by(m)


# =====================================================================
# monsters
# =====================================================================
func _build_monsters() -> void:
	var defs := {"host": ["m_host", "Hosť", 40, 2.35, 1.0], "butcher": ["m_butcher", "Mäsiar", 55, 3.05, 1.05], "mother": ["m_mother", "Matka", 35, 3.5, 0.7],
		"sister": ["m_sister", "Sestra", 30, 2.4, 1.0], "tv": ["m_announcer", "Hlásateľ", 35, 2.75, 1.0], "mimic": ["m_double", "Dvojník", 45, 3.25, 1.0]}
	for t in defs:
		var d = defs[t]
		var n: Node3D = M.model(d[0], Vector3.ZERO, 0.0, M)
		_merge_model(n)
		n.visible = false
		var m := {"type": t, "node": n, "name": d[1], "dmg": d[2], "speed": d[3], "walk": d[4], "x": 0.0, "z": 0.0, "rot": 0.0, "active": false,
			"state": "off", "mode": "", "path": null, "path_t": 0.0, "lit": 0.0, "stun": 0.0, "flee": 0.0, "cool": 0.0, "alert": 0.0, "lost": 0.0,
			"walk_t": 0.0, "snd_t": 0.0, "tx": 0.0, "tz": 0.0, "wait": 0.0, "worlds": [], "frozen": false, "head": n.find_child("head", true, false)}
		MON[t] = m
	# looping sounds that follow the host and the announcer
	for t in ["host", "tv"]:
		var p := AudioStreamPlayer3D.new()
		p.stream = A.sfx.hosthum if t == "host" else A.sfx.static
		p.volume_db = -4 if t == "host" else -10
		p.unit_size = 2.5
		p.position = Vector3(0, 1.6, 0)
		MON[t].node.add_child(p)
		MON[t].hum = p
	var scr = MON.tv.node.find_child("screen", true, false)
	if scr:
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;render_mode unshaded;uniform sampler2D img:source_color;uniform float face=0.0;float h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}void fragment(){float n=h(floor(UV*vec2(90.,70.))+floor(TIME*30.));vec3 c=vec3(n)*.8;vec3 fc=texture(img,UV).rgb;c=mix(c,fc*1.3+n*.15,face);c*=.8+.2*sin(UV.y*300.);ALBEDO=c*1.3;}"
		sm.shader = sh
		sm.set_shader_parameter("img", W.tex.face)
		scr.material_override = sm
		MON.tv.screen = sm


func set_mon(t: String, o: Dictionary) -> Dictionary:
	var m: Dictionary = MON[t]
	var base := {"active": true, "state": "patrol", "path": null, "lit": 0.0, "stun": 0.0, "flee": 0.0, "cool": 0.0, "alert": 0.0, "lost": 0.0, "hunt_hide": null,
		"gone": false, "frozen": false, "warned": false, "present": 0.0, "tgt": null, "contact": true, "tape_only": false, "mode": "", "idle_t": 0.0, "roam": false,
		"roam_both": false, "wp": 0, "delay": 0.0, "resp": 12.0, "stare": 0.0, "face": 0.0, "warn": false, "safe_t": 0.0, "far_t": 0.0, "z_t": 0.0, "shr_t": 0.0,
		"back": 0.0, "step_acc": 0.0, "lx": null, "lz": null}
	for k in base:
		m[k] = base[k]
	for k in o:
		m[k] = o[k]
	if not o.has("rot"):
		m.rot = 0.0
	if not o.has("speed"):
		m.speed = {"host": 2.35, "butcher": 3.05, "mother": 3.5, "sister": 2.4, "tv": 2.75, "mimic": 3.25}[t]
	m.node.rotation = Vector3.ZERO
	sync_mon(m)
	return m


func mons_off() -> void:
	for t in MON:
		MON[t].active = false
		MON[t].node.visible = false
	A.set_loop("chase", 0.0)


func sync_mon(m: Dictionary) -> void:
	m.node.position.x = m.x
	m.node.position.z = m.z
	m.node.rotation.y = m.rot


func seen_by_player(m: Dictionary, cone := 0.62) -> bool:
	var dx: float = m.x - S.x
	var dz: float = m.z - S.z
	var d := sqrt(dx * dx + dz * dz)
	if d > 24 or zone_of(m.x) != S.zone or d < 0.01:
		return false
	var f := fwd()
	return (dx * f.x + dz * f.z) / d > cos(cone) and los(S.x, S.z, m.x, m.z)


func sees(m: Dictionary, rng: float, fov: float) -> bool:
	if S.hidden != null or zone_of(m.x) != S.zone:
		return false
	var dx: float = S.x - m.x
	var dz: float = S.z - m.z
	var d := sqrt(dx * dx + dz * dz)
	if d > rng:
		return false
	var a := wrapf(atan2(dx, dz) - m.rot, -PI, PI)
	return absf(a) < fov and los(m.x, m.z, S.x, S.z)


func face_to(m: Dictionary, x: float, z: float, dt: float) -> void:
	var ty := atan2(x - m.x, z - m.z)
	m.rot += wrapf(ty - m.rot, -PI, PI) * minf(1.0, dt * 5)


func mon_move(m: Dictionary, tx: float, tz: float, sp: float, dt: float) -> float:
	m.path_t -= dt
	var d := Vector2(tx - m.x, tz - m.z).length()
	var nx := tx
	var nz := tz
	if not (d < 7 and los(m.x, m.z, tx, tz)):
		if m.path_t <= 0 or m.path == null:
			m.path_t = 0.45
			m.path = bfs(m.x, m.z, tx, tz)
		if m.path != null and m.path.size() > 0:
			var n = m.path[0]
			if Vector2(n[0] - m.x, n[1] - m.z).length() < 0.3:
				m.path.pop_front()
				n = m.path[0] if m.path.size() > 0 else [tx, tz]
			nx = n[0]
			nz = n[1]
		else:
			nx = m.x
			nz = m.z
	var dx: float = nx - m.x
	var dz: float = nz - m.z
	var l := sqrt(dx * dx + dz * dz)
	m.moved = 0.0
	if l > 0.02:
		var st := minf(l, sp * dif().spd * dt)
		var ox: float = m.x + dx / l * st
		var oz: float = m.z + dz / l * st
		if lit_at(ox, oz, -0.35) != null and lit_at(m.x, m.z, -0.35) == null:
			face_to(m, S.x, S.z, dt)
			return d
		m.x = ox
		m.z = oz
		m.moved = st
		m.rot += wrapf(atan2(dx, dz) - m.rot, -PI, PI) * minf(1.0, dt * 7)
		m.walk_t += st * 3.1
		var amt := 0.42 * minf(1.0, sp / 1.4)
		m.node.rotation.z = sin(m.walk_t) * 0.04 * amt
		m.node.position.y = absf(sin(m.walk_t)) * 0.025 * amt
	for dd in W.door_list:
		if not dd.open and not dd.locked and Vector2(dd.x - m.x, dd.z - m.z).length() < 0.95:
			W.set_door(dd.id, true)
			A.play_at("creak", Vector3(dd.x, 1, dd.z), -4)
	return d


func rand_wp(m: Dictionary, zone = null) -> Array:
	var L: Array = WP[zone if zone else zone_of(m.x)]
	for k in 14:
		var w = L[randi() % L.size()]
		if Vector2(w[0] - m.x, w[1] - m.z).length() > 3 and lit_at(w[0], w[1], -0.5) == null and bfs(m.x, m.z, w[0], w[1]) != null:
			return w
	return L[0]


func teleport_near(m: Dictionary, dmin: float, dmax: float) -> bool:
	if not WP.has(S.zone):
		return false
	var L: Array = WP[S.zone]
	for k in 40:
		var w = L[randi() % L.size()]
		var x: float = w[0] + randf() - 0.5
		var z: float = w[1] + randf() - 0.5
		var d := Vector2(x - S.x, z - S.z).length()
		if d < dmin or d > dmax or lit_at(x, z, -0.5) != null:
			continue
		m.x = x
		m.z = z
		if not seen_by_player(m, 0.9):
			return true
	return false


func teleport_far(m: Dictionary) -> void:
	var zn := zone_of(m.x)
	var L: Array = WP["house" if zn == "hosp" else zn]
	var best = L[0]
	var bd := 0.0
	for w in L:
		var d := Vector2(w[0] - S.x, w[1] - S.z).length()
		if d > bd and not seen_by_player({"x": w[0], "z": w[1]}):
			bd = d
			best = w
	m.x = best[0]
	m.z = best[1]
	m.path = null


func rule_anom() -> bool:
	var b := isAnom(S.world)
	return not b if S.flux != null else b


func light_check(m: Dictionary, dt: float) -> void:
	if not m.node.visible or S.hidden != null or m.stun > 0 or m.flee > 0 or safe_now():
		m.lit = 0.0
		return
	var fi := flash_i()
	if fi < 0.6:
		m.lit = maxf(0.0, m.lit - dt * 2)
		return
	var cp := cam.global_position
	var v := Vector3(m.x, HEADY[m.type] * 0.7, m.z) - cp
	var d := v.length()
	var fw := -cam.global_transform.basis.z
	if d > 13 or v.normalized().dot(fw) < cos(0.38) or not los(S.x, S.z, m.x, m.z):
		m.lit = maxf(0.0, m.lit - dt * 2)
		return
	m.lit += dt
	if rule_anom():
		if m.lit > 0.3:
			m.flee = 6.0
			m.lit = 0.0
			m.path = null
			A.play_at("shriek", m.node.global_position + Vector3(0, 1.5, 0))
		return
	if m.lit > 0.2 and not m.warned:
		m.warned = true
		S.flick = 0.7
		A.play("heart", 0, 1.1)
	if not S.lethal:
		if m.lit > 0.55:
			S.flash = false
			A.play("click")
			A.play("whisper", -2)
			m.lit = 0.0
		return
	if m.lit > 1.0:
		die("%s nesmie vidieť svetlo." % m.name, m)


func update_mon(m: Dictionary, dt: float) -> void:
	if not m.active or not S.world in m.worlds:
		m.node.visible = false
		return
	var same: bool = zone_of(m.x) == S.zone
	m.node.visible = same and not m.gone and not (m.type == "sister" and m.mode != "chase" and m.present <= 0) and not (m.type == "tv" and m.delay > 0) and not (m.type == "host" and m.cool > 0)
	if m.frozen:
		return
	m.cool = maxf(0.0, m.cool - dt)
	m.stun = maxf(0.0, m.stun - dt)
	m.flee = maxf(0.0, m.flee - dt)
	m.back = maxf(0.0, m.back - dt)
	var d := Vector2(S.x - m.x, S.z - m.z).length()
	if m.stun > 0:
		m.node.rotation.z = sin(S.time * 30) * 0.05
		if m.stun < 0.1:
			teleport_far(m)
			m.stun = 0.0
			m.node.rotation.z = 0
		sync_mon(m)
		return
	light_check(m, dt)
	if S.dead:
		return
	if m.flee > 0:
		var L: Array = WP[zone_of(m.x) if zone_of(m.x) != "hosp" else "house"]
		var best = L[0]
		var bd := 0.0
		for w in L:
			var e := Vector2(w[0] - S.x, w[1] - S.z).length()
			if e > bd:
				bd = e
				best = w
		mon_move(m, best[0], best[1], m.speed * 1.25, dt)
		sync_mon(m)
		return
	if m.back > 0:
		var ax: float = m.x - S.x
		var az: float = m.z - S.z
		var l := maxf(0.01, sqrt(ax * ax + az * az))
		mon_move(m, m.x + ax / l, m.z + az / l, 1.4, dt)
		sync_mon(m)
		return
	# hearing
	for n in S.noises:
		if zone_of(n.x) != zone_of(m.x):
			continue
		var nd := Vector2(n.x - m.x, n.z - m.z).length()
		var k := 1.4 if m.type == "mother" else (1.0 if m.type == "butcher" else 0.0)
		if k > 0 and nd < n.r * k and m.state != "chase":
			m.state = "hunt"
			m.tx = n.x
			m.tz = n.z
			m.path = null
			if m.type == "mother" and m.shr_t <= 0:
				m.shr_t = 4.0
				A.play_at("shriek", m.node.global_position + Vector3(0, 1.5, 0), -2)
	m.shr_t = maxf(0.0, m.shr_t - dt)
	# hunting a hiding place
	if m.hunt_hide != null and S.hidden == m.hunt_hide:
		var h = m.hunt_hide
		if mon_move(m, h.out[0], h.out[1], m.speed, dt) < 0.6:
			m.hunt_hide = null
			unhide()
			A.play("shriek")
			U.face_flash(0.12)
			mon_attack(m)
		sync_mon(m)
		return
	if m.hunt_hide != null and S.hidden == null:
		m.hunt_hide = null
	if lit_at(m.x, m.z, -0.2) != null and m.flee <= 0:
		m.flee = 2.5
		m.path = null
	if safe_now() and (m.state == "chase" or m.state == "hunt"):
		m.safe_t += dt
		if m.safe_t > 3:
			m.safe_t = 0.0
			m.state = "wander" if m.type == "mother" else "patrol"
			m.tgt = null
			m.alert = 0.0
			if m.type == "butcher":
				A.play_at("grunt", m.node.global_position + Vector3(0, 1.6, 0))
	else:
		m.safe_t = 0.0
	call("beh_" + m.type, m, dt, d)
	if S.hidden == null and same and d < 0.85 and m.cool <= 0 and not m.gone and m.contact and not safe_now():
		mon_attack(m)
	sync_mon(m)


func beh_host(m: Dictionary, dt: float, d: float) -> void:
	if m.cool > 0:
		m.node.visible = false
		return
	if m.mode == "chase":
		mon_move(m, S.x, S.z, 2.95, dt)
		m.state = "chase"
		return
	if m.mode == "patrol":
		var W7 := [[15, 3], [12.5, 4], [12.5, 7.5], [16.5, 7.5], [22, 7.5], [12.5, 7.5], [8.5, 7.5], [5.5, 6.5], [2.5, 6.5], [2.5, 2.5], [6.5, 2.2], [7.5, 6.5]]
		if m.state != "chase":
			if sees(m, 9.5 if S.flash else 5.2, 1.0) or (S.run and d < 4.5 and los(m.x, m.z, S.x, S.z)) or d < 1.2:
				m.alert += dt * (3.0 if d < 3 else 1.6)
			else:
				m.alert = maxf(0.0, m.alert - dt * 0.4)
			if m.alert >= 1:
				m.state = "chase"
				A.play("stinger", -4)
				objective("Uteč!")
			else:
				var w = W7[int(m.wp) % W7.size()]
				if mon_move(m, w[0], w[1], 1.05, dt) < 0.3:
					m.wp = (int(m.wp) + 1) % W7.size()
		else:
			var sv := sees(m, 12, 1.4)
			m.lost = 0.0 if sv else m.lost + dt
			mon_move(m, S.x, S.z, 2.8, dt)
			if m.lost > 4.5:
				m.state = "patrol"
				m.alert = 0.0
				objective(S.obj_text2)
		return
	# stalk: moves only when unseen
	if zone_of(m.x) != S.zone:
		m.far_t += dt
		if m.far_t > 6:
			teleport_near(m, 7, 11)
			m.far_t = 0.0
		return
	var seen := seen_by_player(m)
	face_to(m, S.x, S.z, dt)
	if seen:
		if m.head:
			m.head.rotation.z = 0.28 + sin(S.time * 2) * 0.08
		m.state = "frozen"
	else:
		mon_move(m, S.x, S.z, m.speed, dt)
		m.state = "stalk"
	if d > 15:
		m.far_t += dt
		if m.far_t > 4:
			teleport_near(m, 7, 10)
			m.far_t = 0.0
	else:
		m.far_t = 0.0


func beh_butcher(m: Dictionary, dt: float, d: float) -> void:
	m.snd_t -= dt
	var pos3: Vector3 = m.node.global_position + Vector3(0, 1.2, 0)
	if m.state == "idle":
		m.rot = PI * 0.5
		var cl = m.node.find_child("cleaver", true, false)
		if cl:
			cl.rotation.x = 0.12 - maxf(0.0, sin(S.time * 7.5)) * 0.9
		if m.snd_t <= 0:
			m.snd_t = 0.82
			if zone_of(m.x) == S.zone or Vector2(m.x - S.x, m.z - S.z).length() < 25:
				A.play_at("chop", pos3, 2, 1.0, 5.0)
		m.idle_t -= dt
		if m.idle_t <= 0 and m.roam:
			m.state = "patrol"
			m.tgt = null
	if m.state != "chase" and sees(m, 15.0 if S.flash else 7.5, 1.0):
		m.alert += dt * (3.0 if d < 4 else 1.7)
		if m.alert >= 1:
			m.state = "chase"
			A.play_at("grunt", pos3, 2)
			A.play("stinger", -4)
			m.lost = 0.0
	elif m.state != "chase":
		m.alert = maxf(0.0, m.alert - dt * 0.5)
	if m.state == "patrol":
		if m.tgt == null:
			if m.roam_both and randf() < 0.25:
				m.tgt = rand_wp(m, "base" if zone_of(m.x) == "house" else "house")
			else:
				m.tgt = rand_wp(m)
			if zone_of(m.tgt[0]) != zone_of(m.x):
				var a = ARRIVE[zone_of(m.tgt[0])]
				m.x = a[0]
				m.z = a[1]
				m.path = null
		if mon_move(m, m.tgt[0], m.tgt[1], m.walk, dt) < 0.4:
			m.wait += dt
			if m.wait > 2.5:
				m.wait = 0.0
				m.tgt = null
	if m.state == "hunt":
		if mon_move(m, m.tx, m.tz, m.walk * 1.7, dt) < 0.5:
			m.wait += dt
			face_to(m, m.tx + sin(S.time), m.tz, dt)
			if m.wait > 3:
				m.wait = 0.0
				m.state = "patrol"
				m.tgt = null
	if m.state == "chase":
		var sv := sees(m, 16, 1.6)
		m.lost = 0.0 if sv else m.lost + dt
		if sv:
			m.lx = S.x
			m.lz = S.z
		if zone_of(m.x) != S.zone:
			m.z_t += dt
			if m.z_t > 3.2 and ARRIVE.has(S.zone):
				m.z_t = 0.0
				var a = ARRIVE[S.zone]
				m.x = a[0]
				m.z = a[1]
				m.path = null
				A.play("slam", -6)
		else:
			m.z_t = 0.0
		if S.hidden != null:
			mon_move(m, m.lx if m.lx != null else S.x, m.lz if m.lz != null else S.z, m.walk * 1.6, dt)
			if m.lost > 3:
				m.state = "patrol"
				m.tgt = null
		else:
			mon_move(m, S.x, S.z, m.speed, dt)
		if m.snd_t <= 0:
			m.snd_t = 2.6
			A.play_at("grunt", pos3, 0)
		if m.lost > 5.5:
			m.state = "hunt"
			m.tx = m.lx if m.lx != null else S.x
			m.tz = m.lz if m.lz != null else S.z
	m.step_acc += m.get("moved", 0.0)
	if m.step_acc > 0.9:
		m.step_acc = 0.0
		if zone_of(m.x) == S.zone:
			A.play_at("heavy", Vector3(m.x, 0.2, m.z), 0)


func beh_mother(m: Dictionary, dt: float, d: float) -> void:
	m.snd_t -= dt
	if m.snd_t <= 0:
		m.snd_t = 0.7 if m.state == "hunt" else 1.4 + randf() * 1.5
		if zone_of(m.x) == S.zone:
			A.play_at("crack", m.node.global_position + Vector3(0, 1.5, 0), 0)
	m.node.rotation.x = 0.1 + sin(S.time * 13) * 0.01
	if m.state == "hunt":
		if mon_move(m, m.tx, m.tz, m.speed, dt) < 0.5:
			m.state = "sniff"
			m.wait = 2.6
	elif m.state == "sniff":
		m.wait -= dt
		face_to(m, m.x + sin(S.time * 2), m.z + cos(S.time * 2), dt)
		if m.wait <= 0:
			m.state = "wander"
	else:
		m.state = "wander"
		if m.tgt == null:
			m.tgt = rand_wp(m)
		if mon_move(m, m.tgt[0], m.tgt[1], m.walk, dt) < 0.4:
			m.wait += dt
			if m.wait > 3:
				m.wait = 0.0
				m.tgt = null
	if m.state == "chase":
		m.state = "hunt"


func beh_sister(m: Dictionary, dt: float, d: float) -> void:
	var pos3: Vector3 = m.node.global_position + Vector3(0, 1.0, 0)
	if m.mode == "chase":
		m.contact = true
		mon_move(m, S.x, S.z, m.speed, dt)
		m.snd_t -= dt
		if m.snd_t <= 0:
			m.snd_t = 3.0
			A.play_at("giggle", pos3)
		return
	m.contact = false
	if m.present <= 0:
		m.node.visible = false
		m.resp -= dt
		if m.resp <= 0:
			var prev := [m.x, m.z]
			if teleport_near(m, 3.5, 8):
				m.present = 14.0
				m.stare = 0.0
				A.play_at("giggle", m.node.global_position + Vector3(0, 1.0, 0))
			else:
				m.x = prev[0]
				m.z = prev[1]
				m.resp = 3.0
		return
	m.present -= dt
	face_to(m, S.x, S.z, dt)
	m.snd_t -= dt
	if m.snd_t <= 0:
		m.snd_t = 3 + randf() * 2
		A.play_at("giggle", pos3, -4)
	var look_at_her := seen_by_player(m, 0.32)
	m.stare = m.stare + dt if look_at_her else maxf(0.0, m.stare - dt * 0.7)
	if m.stare > 1.2 and not m.warn:
		m.warn = true
		add_clue("sister")
		S.flick = 0.5
		A.play("heart", 0, 1.3)
	if m.stare > 2.0:
		m.present = 0.0
		m.warn = false
		U.face_flash(0.14)
		A.play_at("shriek", pos3)
		post("glitch", 0.9)
		get_tree().create_timer(0.25).timeout.connect(func(): post("glitch", 0.0))
		damage(m.dmg, "Sestra")
		m.resp = 30 + randf() * 25
		return
	if d < 1.3:
		m.present = 0.0
		A.play("giggle")
		say([["LUCIA", "Hihi. Našla som ťa.", 2.4]])
		m.resp = 25 + randf() * 20
		return
	if m.present <= 0:
		m.resp = 28 + randf() * 30
		m.warn = false


func beh_tv(m: Dictionary, dt: float, d: float) -> void:
	if m.delay > 0:
		m.delay -= dt
		m.node.visible = false
		return
	if m.has("screen"):
		m.screen.set_shader_parameter("face", 1.0 if d < 4 else 0.0)
	mon_move(m, S.x, S.z, m.speed, dt)
	m.state = "chase"
	m.snd_t -= dt
	if m.snd_t <= 0:
		m.snd_t = 2.5 + randf() * 2
		A.play_at("radio", m.node.global_position + Vector3(0, 1.7, 0))
		if randf() < 0.4:
			say([["HLÁSATEĽ", ["Neprepínajte.", "Ste naživo.", "Nasleduje reklama na ticho.", "Vidíme vás."][randi() % 4], 2.2]])


func beh_mimic(m: Dictionary, dt: float, d: float) -> void:
	if zone_of(m.x) != S.zone:
		m.far_t += dt
		if m.far_t > 8:
			teleport_near(m, 8, 12)
			m.far_t = 0.0
		return
	if m.state == "chase":
		mon_move(m, S.x, S.z, m.speed, dt)
		m.lost = 0.0 if seen_by_player(m, 0.9) else m.lost + dt
		if m.lost > 4:
			m.state = "wander"
			m.face = 0.0
		return
	var look_at_him := seen_by_player(m, 0.45)
	if look_at_him:
		face_to(m, S.x, S.z, dt * 0.35)
		var a := atan2(S.x - m.x, S.z - m.z)
		var df := wrapf(a - m.rot, -PI, PI)
		m.face = m.face + dt if absf(df) < 0.45 and d < 10 else maxf(0.0, m.face - dt * 0.5)
		if m.face > 0.8 and not m.warn:
			m.warn = true
			A.play("heart", 0, 1.2)
			S.flick = 0.4
		if m.face > 1.7:
			m.state = "chase"
			m.warn = false
			A.play_at("shriek", m.node.global_position + Vector3(0, 1.6, 0))
			U.face_flash(0.08)
	else:
		m.face = maxf(0.0, m.face - dt * 0.5)
		m.warn = false
		if S.moving:
			if m.tgt == null:
				m.tgt = rand_wp(m)
			if mon_move(m, m.tgt[0], m.tgt[1], 1.9, dt) < 0.4:
				m.tgt = null


func mimic_echo() -> void:
	var m = MON.mimic
	if not m.active or zone_of(m.x) != S.zone or not S.world in m.worlds:
		return
	if Vector2(m.x - S.x, m.z - S.z).length() > 16:
		return
	get_tree().create_timer(0.24).timeout.connect(func(): A.play_at("step%d" % (randi() % 5), Vector3(m.x, 0.2, m.z), -6))


func host_intro() -> void:
	set_mon("host", {"x": 22.5, "z": 7.5, "mode": "stalk", "worlds": ["real"], "rot": -PI / 2, "dmg": 20})
	msg("Na konci chodby niekto stojí.", 3)
	A.play("moan", -4)
	if not await wait(2.6):
		return
	S.flick = 1.0
	if not await wait(10.0):
		return
	A.play("whisper")
	MON.host.active = false
	MON.host.node.visible = false
	MON.host.dmg = 40


# =====================================================================
# navigation (BFS over a 0.5 m grid)
# =====================================================================
func _build_nav() -> void:
	nav.resize(NW * NH)
	nav_door.resize(NW * NH)
	for j in NH:
		for i in NW:
			var x := (i + 0.5) * NS
			var z := (j + 0.5) * NS
			var s := 0
			if not ((x > 0 and x < 24 and z > 0 and z < 15) or (x > 40 and x < 54 and z > 0 and z < 12)):
				s = 1
			else:
				for r in M.rects:
					var rr: Rect2 = r
					var thin := rr.size.x < 0.3 or rr.size.y < 0.3
					if thin:
						if x - 0.25 < rr.end.x and x + 0.25 > rr.position.x and z - 0.25 < rr.end.y and z + 0.25 > rr.position.y:
							s = 1
							break
					elif x > rr.position.x - 0.12 and x < rr.end.x + 0.12 and z > rr.position.y - 0.12 and z < rr.end.y + 0.12:
						s = 1
						break
			nav_door[i + j * NW] = null
			for d in W.door_list:
				var hw: float = d.w / 2 + 0.3
				var inside := (absf(x - d.x) < hw and absf(z - d.z) < 0.35) if d.axis == "x" else (absf(x - d.x) < 0.35 and absf(z - d.z) < hw)
				if inside:
					nav_door[i + j * NW] = d
					s = 0
			nav[i + j * NW] = s
	_build_astar()


var astar: AStarGrid2D
var door_cells: Array = []


func nav_solid(i: int) -> bool:
	if nav[i] == 1:
		return true
	var d = nav_door[i]
	return d != null and d.locked and not d.open


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, NW, NH)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for j in NH:
		for i in NW:
			var k := i + j * NW
			if nav[k] == 1:
				astar.set_point_solid(Vector2i(i, j), true)
			elif nav_door[k] != null:
				door_cells.append([Vector2i(i, j), nav_door[k]])


func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floorf(x / NS)), 0, NW - 1), clampi(int(floorf(z / NS)), 0, NH - 1))


func nearest_free(c: Vector2i) -> Vector2i:
	if not nav_solid(c.x + c.y * NW):
		return c
	for r in range(1, 5):
		for a in range(-r, r + 1):
			for b in range(-r, r + 1):
				var i := c.x + a
				var j := c.y + b
				if i >= 0 and j >= 0 and i < NW and j < NH and not nav_solid(i + j * NW):
					return Vector2i(i, j)
	return c


func bfs(sx: float, sz: float, tx: float, tz: float):
	for dc in door_cells:
		var d = dc[1]
		astar.set_point_solid(dc[0], d.locked and not d.open)
	var s := nearest_free(cell_of(sx, sz))
	var t := nearest_free(cell_of(tx, tz))
	var ids := astar.get_id_path(s, t)
	if ids.is_empty():
		return null
	var p := []
	for k in range(1, ids.size()):
		p.append([(ids[k].x + 0.5) * NS, (ids[k].y + 0.5) * NS])
	return p


# =====================================================================
# scares & ambience
# =====================================================================
func scare_ok() -> bool:
	if not S.running or S.busy or S.dead or S.hidden != null or S.qte != null or S.inserted != null or S.feed != null or S.behind != null:
		return false
	if not (isRealW(S.world) or S.world == "t1"):
		return false
	for t in MON:
		if MON[t].active and MON[t].state == "chase":
			return false
	return true


func scare_tick(dt: float) -> void:
	if not scare_ok() or safe_now():
		return
	SC.t -= dt
	if SC.t > 0:
		return
	SC.t = (34 - S.day * 2.5) + randf() * 34
	var o := ["behind", "behind", "slam", "run", "face", "dark"] if isRealW(S.world) else ["slam", "run", "face"]
	if isRealW(S.world) and nm():
		o.append_array(["name", "name"])
	do_scare(o[randi() % o.size()])


func do_scare(k: String) -> void:
	match k:
		"name":
			name_call()
		"behind":
			var b := -fwd() * 2.1
			var x: float = S.x + b.x
			var z: float = S.z + b.z
			if not los(S.x, S.z, x, z) or not los(S.x, S.z, x, z, 0.4):
				do_scare("run")
				return
			angel.position = Vector3(x, 0, z)
			angel.rotation = Vector3(0, atan2(S.x - x, S.z - z), 0)
			S.angel_on = true
			S.behind = {"t": 0.0, "w": false}
			A.play_side("whisper", 0.0, -6)
		"dark":
			if not S.flash:
				do_scare("face")
				return
			S.busy = true
			S.flash_kill = 2.4
			A.play("click")
			await sleep(0.8)
			A.play("moan", -6, 1.4)
			await sleep(1.5)
			S.flash_kill = 0.0
			await jumpscare()
		"slam":
			for d in W.door_list:
				var dd := Vector2(d.x - S.x, d.z - S.z).length()
				if d.open and dd > 2.2 and dd < 9:
					W.set_door(d.id, false)
					A.play_at("slam", Vector3(d.x, 1.2, d.z))
					break
			S.shake = 0.55
			S.flick = 0.7
		"run":
			A.play_side("run_by", -1.0 if randf() < 0.5 else 1.0)
			get_tree().create_timer(1.7).timeout.connect(func(): A.play("heart"))
			S.flick = 0.3
		"face":
			U.face_flash(0.11)
			A.play("stab")
			post("glitch", 0.8)
			get_tree().create_timer(0.18).timeout.connect(func(): post("glitch", 0.0))
			S.flick = 0.5


func name_call() -> void:
	var n = nm()
	if n == null:
		do_scare("face")
		return
	var side := -1.0 if randf() < 0.5 else 1.0
	A.play_side("whisper", side * 0.8)
	say([["", "…%s…" % n, 2]])
	A.speak("???", n)
	await sleep(2.2)
	if S.dead or S.busy or safe_now():
		return
	A.play_side("moan", side * 0.4, -2)
	say([["???", "%s!" % n, 1.6]])
	A.speak("???", n + "!")
	await sleep(1.3)
	if S.dead or S.busy or safe_now():
		return
	U.face_flash(0.15)
	A.play("stinger")
	post("glitch", 0.9)
	S.shake = 0.8
	S.flick = 0.6
	get_tree().create_timer(0.22).timeout.connect(func(): post("glitch", 0.0))


func update_behind(dt: float) -> void:
	var B = S.behind
	if B == null:
		return
	B.t += dt
	var a := angel.position
	var v := Vector3(a.x - S.x, 0, a.z - S.z).normalized()
	if v.dot(fwd()) > 0.55 and los(S.x, S.z, a.x, a.z):
		S.behind = null
		U.face_flash(0.09)
		A.play("stab")
		S.shake = 0.5
		post("glitch", 0.9)
		S.flick = 0.5
		get_tree().create_timer(0.26).timeout.connect(func():
			post("glitch", 0.0)
			S.angel_on = false)
		return
	if B.t > 2.6 and not B.w:
		B.w = true
		A.play_side("whisper", 0.0)
		say([["", "…za tebou…", 2.6]])
	if B.t > 9:
		S.behind = null
		S.angel_on = false


func ambient_tick(dt: float) -> void:
	if S.busy or S.world == "hosp" or S.world == "endB":
		return
	if SC.chop != null:
		var c = SC.chop
		var dd := Vector2(c.x - S.x, c.z - S.z).length()
		if dd < 3.3:
			SC.chop = null
			say([["", "Sekanie prestalo.", 2]])
			A.play("heart")
		else:
			c.t -= dt
			if c.t <= 0:
				c.n -= 1
				c.t = 0.5 + randf() * 0.65
				A.play_at("chop", Vector3(c.x, 1.0, c.z), 4, 1.0, 6.0)
				if c.n <= 0:
					SC.chop = null
	SC.amb -= dt
	if SC.amb > 0:
		return
	SC.amb = 8 + randf() * 12
	var w: String = S.world
	var r := 0.0 if SC.first else randf()
	SC.first = false
	var side := randf() * 1.6 - 0.8
	if r < 0.25 and w != "t2" and not MON.butcher.active:
		var src := [14.6, 2.2] if randf() < 0.5 else [6.5, 14.6]
		SC.chop = {"x": src[0], "z": src[1], "n": 7 + randi() % 9, "t": 0.0}
	elif r < 0.5:
		A.play_side("whisper", side, -2)
		if randf() < 0.7:
			say([["", C.WHISPERS[randi() % C.WHISPERS.size()], 3]])
	elif r < 0.62:
		A.play_side("knock", side, 2)
	elif r < 0.74:
		A.play("steps_above", -4)
	elif r < 0.82:
		A.play_side("creak", side)
	elif r < 0.93:
		A.play_side("moan", side, -2)
		if randf() < 0.6:
			say([["???", "Poď ku mne, {N}…" if randf() < 0.5 else "Prečo ťa niet v kazete?", 2.8]])
	else:
		A.play_side("scream", side, -6)


func lights_tick(dt: float) -> void:
	var on := []
	for k in S.lit:
		if S.lit[k]:
			on.append(k)
	if on.is_empty() or not isRealW(S.world) or S.busy:
		return
	SC.lt = SC.get("lt", 70.0) - dt
	if S.room_flick != null:
		S.room_flick.t -= dt
		var f := 0.05 if randf() < 0.5 else 1.0
		for i in S.pool_rooms.size():
			if S.pool_rooms[i] == S.room_flick.k:
				W.pool[i].light_energy = 2.6 * f
		if S.room_flick.t <= 0:
			var k: String = S.room_flick.k
			if S.room_flick.off:
				S.lit[k] = false
				A.play("click")
				say([["", "Svetlo v " + LIT[k].name + " zhaslo.", 2.6]])
			S.room_flick = null
			apply_world(S.world)
		return
	if SC.lt > 0:
		return
	SC.lt = 55 + randf() * 60
	var k2: String = on[randi() % on.size()]
	S.room_flick = {"k": k2, "t": 1.8, "off": randf() < (0.35 if lit_at(S.x, S.z, 0.15) == k2 else 0.7)}
	A.play("mainshum", -10)


# ---------------------------------------------------------------- reality flux
func flux_tick(dt: float) -> void:
	var cfg = C.FLUX[S.day] if S.day < C.FLUX.size() else null
	var ok: bool = cfg != null and S.running and not S.busy and not S.dead and not S.ui and (isRealW(S.world) or isAnom(S.world))
	var target := 1.0 if isAnom(S.world) else 0.0
	if ok:
		if cfg.has("decoy"):
			SC.fd = SC.get("fd", cfg.decoy) - dt
			if SC.fd <= 0:
				SC.fd = cfg.decoy * (0.6 + randf() * 0.8)
				S.decoy = 0.18 + randf() * 0.25
				flux_flash(0.4)
		if cfg.has("every"):
			if S.flux != null:
				S.flux.t -= dt
				if S.flux.t <= 0:
					S.flux = null
					flux_flash(0.8)
					apply_world(S.world)
			else:
				SC.ft = SC.get("ft", cfg.every * 0.6) - dt * dif().flux
				if SC.ft <= 0:
					SC.ft = cfg.every * (0.7 + randf() * 0.6)
					S.flux = {"t": cfg.dur[0] + randf() * (cfg.dur[1] - cfg.dur[0])}
					flux_flash(0.9)
					add_clue("flux")
					apply_world(S.world)
	elif not S.busy and S.running:
		S.flux = null
	var vis: float = cfg.vis if cfg != null and cfg.has("vis") else 1.0
	if S.flux != null:
		target = (1 - vis) * 0.6 if isAnom(S.world) else vis
	if S.decoy > 0:
		S.decoy -= dt
		target = 0.1 if isAnom(S.world) else maxf(target, 0.85)
	S.anom_v += (target - S.anom_v) * minf(1.0, dt * (20.0 if S.decoy > 0 else 3.0))
	post("anom", S.anom_v)
	if isAnom(S.world):
		W.G.anom.visible = S.flux == null or vis < 0.6
	else:
		W.G.anom.visible = (S.flux != null and vis >= 0.6) or S.decoy > 0


func flux_flash(p: float) -> void:
	post("stat", maxf(S.stat_v, p))
	A.play("whoosh", -12, 2.0)
	get_tree().create_timer(0.13).timeout.connect(func():
		if not S.busy:
			post("stat", 0.0))


# ---------------------------------------------------------------- night changes
func choose_changes(day: int) -> void:
	_change_off_all()
	S.changes = []
	var n: int = C.CHG_N[day] if day < C.CHG_N.size() else 0
	if n == 0:
		return
	var s := day * 977 + 13
	var pool := []
	for c in CHG:
		pool.append(c)
	for i in n:
		s = (s * 16807) % 2147483647
		var idx := int(floorf(float(s) / 2147483647.0 * pool.size()))
		var c = pool[idx]
		pool.remove_at(idx)
		S.changes.append(c.id)
	for id in S.changes:
		if not F.get("chg_%s%d" % [id, day], false):
			_change_set(id, true)


func _change_set(id: String, on: bool) -> void:
	match id:
		"paint": W.frames[0].rotation.z = PI if on else 0.0
		"photo": W.frames[4].rotation.y = PI if on else 0.0
		"granny": W.frames[5].visible = not on
		_: W.chg[id].visible = on


func _change_off_all() -> void:
	for c in CHG:
		_change_set(c.id, false)


func change_found(c: Dictionary) -> void:
	F["chg_%s%d" % [c.id, S.day]] = true
	ST.chg = ST.get("chg", 0) + 1
	_save_stats()
	var n := 0
	for id in S.changes:
		n += 1 if F.get("chg_%s%d" % [id, S.day], false) else 0
	flux_flash(0.5)
	A.play("whoosh", -6, 0.6)
	_change_set(c.id, false)
	var rw := ""
	if S.batt < S.hp:
		S.batt = minf(100.0, S.batt + 30)
		rw = "+30 % baterka"
	else:
		S.hp = minf(100.0, S.hp + 30)
		rw = "+30 život"
	msg("%s (%d/%d) · %s" % [c.txt, n, S.changes.size(), rw], 3.6)


# ---------------------------------------------------------------- broken tape 13
func break_tape() -> void:
	F.t13broken = true
	A.play("crack")
	await sleep(0.25)
	A.play("stinger")
	U.face_flash(0.09)
	post("glitch", 0.8)
	S.shake = 0.7
	get_tree().create_timer(0.2).timeout.connect(func(): post("glitch", 0.0))
	msg("Kazeta 13 ti praskla v rukách. Páska vyliezla von.", 4.5)
	add_clue("broken")


# =====================================================================
# days
# =====================================================================
func reset_doors() -> void:
	W.set_door("lk", false, false, true)
	W.set_door("kh", true, false, true)
	W.set_door("kid", F.get("kidOpen", false), not F.get("kidOpen", false), true)
	W.set_door("bath", false, false, true)
	W.set_door("bed", false, S.day < 4, true)
	W.set_door("study", F.get("studyOpen", false), not F.get("studyOpen", false), true)
	W.set_door("stor", false, false, true)
	W.set_door("front", false, true, true)
	W.set_door("base", false, not F.get("baseOpen", false), true)
	W.compart.position.z = 0.9 if F.get("clockOk", false) else 0.63
	W.compart.rotation.y = 1.2 if F.get("clockOk", false) else 0.0


func start_day(n: int, keep := false, cp = null) -> void:
	S.day = n
	S.dead = false
	S.busy = true
	U.hide_overlays()
	S.ui = false
	if not keep or SNAP == null or SNAP.day != n:
		SNAP = {"day": n, "F": F.duplicate(true), "batt": maxf(S.batt, 60.0), "knife": S.knife}
		M.save_game()
	F = (cp.F if cp != null else SNAP.F).duplicate(true)
	S.batt = SNAP.batt
	S.knife = SNAP.knife
	S.step_n = 0
	S.replay_n = cp.step_n if cp != null else 0
	S.fast = cp != null and cp.step_n > 0
	S.resume_cp = cp
	if cp == null:
		S.deaths_today = 0
	for kv in {"hp": 100.0, "stam": 100.0, "tired": false, "hidden": null, "qte": null, "inserted": null, "feed": null, "can_enter": false, "can_exit": false,
			"can_sleep": 0, "power": true, "lethal": true, "blackout": false, "candles_out": false, "angel_on": false, "flash": false, "lock_cam": false,
			"cam_y": 0.0, "behind": null, "lit": {}, "room_flick": null, "flux": null, "decoy": 0.0, "dayT": 0.0, "live_stage": 0, "force_flash": false,
			"flash_kill": 0.0, "ending": null, "obj_text2": ""}:
		S[kv] = {"hp": 100.0, "stam": 100.0, "tired": false, "hidden": null, "qte": null, "inserted": null, "feed": null, "can_enter": false, "can_exit": false,
			"can_sleep": 0, "power": true, "lethal": true, "blackout": false, "candles_out": false, "angel_on": false, "flash": false, "lock_cam": false,
			"cam_y": 0.0, "behind": null, "lit": {}, "room_flick": null, "flux": null, "decoy": 0.0, "dayT": 0.0, "live_stage": 0, "force_flash": false,
			"flash_kill": 0.0, "ending": null, "obj_text2": ""}[kv]
	U.hide_overlay(false)
	U.qte(false)
	me_fig.visible = false
	host_feed.visible = false
	feed_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mons_off()
	for t in MON:
		MON[t].tape_only = false
		MON[t].frozen = false
	reset_doors()
	set_osd(false)
	objective("")
	W.tv_mat.set_shader_parameter("mode", 1.0)
	W.tv_mat.set_shader_parameter("on", 1.0)
	door_snap = null
	post("fade", 1.0)
	U.day_card(n, "Pokračovanie" if cp != null else C.DAYNAME[n])
	run_id += 1
	S.zone = "house"
	set_world("real")
	W.family_seat("dinner")
	SC = {"t": 40 + randf() * 20, "amb": 10.0, "chop": null, "first": true}
	choose_changes(n)
	await sleep(1.4 if cp != null else 2.6)
	U.day_card_hide()
	S.busy = false
	tween_val(func(v): post("fade", v), 1.0, 0.0, 1.8)
	if cp != null and cp.step_n == 0:
		call_deferred("cp_apply")
	if cp == null and C.CHG_N[n] > 0:
		get_tree().create_timer(9.0).timeout.connect(func(): msg("Niečo je inak.", 3))
	call("day%d" % n)


func end_day() -> void:
	var n: int = S.day
	S.busy = true
	A.set_loop("chase", 0.0, 4)
	await tween_val(func(v): post("fade", v), 0.0, 1.0, 1.8)
	mons_off()
	if n < 7:
		msg("Svitá. Deň %d je za tebou." % n, 3)
	await sleep(2.6)
	start_day(n + 1)


func day1() -> void:
	S.lethal = false
	tp(1.4, 11.5, -PI / 2)
	if not await wait(1.5): return
	objective("Choď do obývačky. Niekto nechal zapnutý televízor.")
	if not await until(func(): return S.x < 9 and S.z < 8 and isRealW(S.world)): return
	objective("Na stolíku leží kazeta. Vezmi ju.")
	if not await until(func(): return has("tape1")): return
	objective("Vlož kazetu do televízora.")
	if not await until(func(): return F.get("done_t1", false) and isRealW(S.world)): return
	msg("Kľúč z kazety máš stále v ruke.", 3.5)
	objective("Odomkni detskú izbu na chodbe.")
	if not await until(func(): return S.x > 11 and S.z > 6 and S.z < 9 and S.zone == "house"): return
	await host_intro()
	if not await until(func(): return F.get("kidOpen", false)): return
	objective("Prehľadaj detskú izbu.")
	if not await until(func(): return has("tape2")): return
	objective("Pusti kazetu 2.")
	if not await until(func(): return F.get("t2done", false) and isRealW(S.world) and not S.busy): return
	if not await wait(1.5): return
	if not has("knife"):
		objective("V kuchyni na linke leží nôž. Vezmi si ho.")
	if not await until(func(): return has("knife")): return
	objective("Choď spať na gauč v obývačke.")
	S.can_sleep = 1
	if not await until(func(): return F.get("slept1", false)): return
	end_day()


func day2() -> void:
	tp(4.5, 6.2, 0.0)
	set_mon("mother", {"x": 21.5, "z": 7.5, "worlds": ["real"], "state": "wander"})
	if not await wait(1.2): return
	msg("Niečo chodí po dome.", 4.5)
	if not await wait(4.0): return
	objective("Pracovňa je zamknutá.")
	if not await until(func(): return F.get("sawKeypad", false) or F.get("studyOpen", false)): return
	objective("Nájdi kód.")
	if not await until(func(): return F.get("studyOpen", false)): return
	objective("Prehľadaj pracovňu.")
	if not await until(func(): return has("tape3")): return
	objective("Pusti kazetu 3.")
	if not await until(func(): return F.get("done_a3", false) and isRealW(S.world)): return
	objective("Choď spať.")
	S.can_sleep = 2
	if not await until(func(): return F.get("slept2", false)): return
	end_day()


func day3() -> void:
	tp(4.5, 6.2, 0.0)
	set_mon("mother", {"x": 21.5, "z": 11.0, "worlds": ["real"], "state": "wander"})
	set_mon("butcher", {"x": 48.2, "z": 8.8, "state": "idle", "idle_t": 1e9, "roam": false, "worlds": ["real"], "rot": PI / 2})
	if not await wait(1.2): return
	msg("Z pivnice sa ozýva sekanie.", 3.5)
	if not await wait(3.2): return
	objective("Na kuchynskom stole leží kazeta.")
	if not await until(func(): return has("tape4")): return
	objective("Pusti kazetu 4.")
	if not await until(func(): return F.get("done_t4", false) and isRealW(S.world)): return
	F.t4seen = true
	objective("Veľké hodiny.")
	if not await until(func(): return has("keyBase")): return
	objective("Odomkni pivnicu vo vstupnej hale.")
	if not await until(func(): return S.zone == "base"): return
	objective("Kazeta 5 je v pivnici.")
	MON.butcher.idle_t = 12.0
	MON.butcher.roam = true
	if not await until(func(): return has("tape5")): return
	var b = MON.butcher
	b.state = "chase"
	b.lost = 0.0
	A.play_at("grunt", b.node.global_position + Vector3(0, 1.6, 0), 4)
	objective("UTEČ HORE!")
	if not await until(func(): return S.zone == "house"): return
	if not await wait(5.0): return
	objective("Pusti kazetu 5.")
	if not await until(func(): return F.get("done_t5", false) and isRealW(S.world)): return
	objective("Choď spať.")
	S.can_sleep = 3
	if not await until(func(): return F.get("slept3", false)): return
	end_day()


func day4() -> void:
	tp(4.5, 6.2, 0.0)
	set_mon("sister", {"x": 12.0, "z": 12.0, "mode": "haunt", "worlds": ["real", "a6"], "resp": 14.0})
	set_mon("butcher", {"x": 12.5, "z": 7.5, "state": "patrol", "roam": true, "roam_both": true, "worlds": ["real"]})
	if not await wait(1.2): return
	msg("Spálňa rodičov je po 26 rokoch odomknutá.", 3.5)
	if not await wait(3.8): return
	objective("Choď do spálne rodičov.")
	if not await until(func(): return S.x > 19 and S.z > 9 and S.zone == "house"): return
	objective("Fotky na komode.")
	if not await until(func(): return F.get("photosOk", false)): return
	objective("V šuplíku komody je kazeta 6.")
	if not await until(func(): return has("tape6")): return
	objective("Pusti kazetu 6.")
	if not await until(func(): return F.get("done_a6", false) and isRealW(S.world)): return
	objective("Choď spať.")
	S.can_sleep = 4
	if not await until(func(): return F.get("slept4", false)): return
	end_day()


func day5() -> void:
	tp(4.5, 6.2, 0.0)
	S.power = false
	F.baseOpen = true
	W.doors.base.locked = false
	apply_world("real")
	W.tv_mat.set_shader_parameter("on", 0.0)
	set_mon("mother", {"x": 20.0, "z": 7.5, "worlds": ["real"], "state": "wander"})
	set_mon("butcher", {"x": 47.0, "z": 8.0, "state": "patrol", "roam": true, "worlds": ["real"]})
	set_mon("sister", {"x": 12.0, "z": 12.0, "mode": "haunt", "worlds": ["real"], "resp": 40.0})
	if not await wait(1.2): return
	msg("Vypadol prúd. Televízor je mŕtvy.", 3.5)
	if not await wait(3.2): return
	objective("Poistky sú v pivnici.")
	if not await until(func(): return (S.zone == "base" and Vector2(S.x - 48, S.z - 0.6).length() < 2.6) or F.get("powerOn", false)): return
	if not await until(func(): return F.get("powerOn", false)): return
	W.tv_mat.set_shader_parameter("on", 1.0)
	objective("Kazeta 7 je v komore.")
	if not await until(func(): return has("tape7")): return
	objective("Pusti kazetu 7.")
	if not await until(func(): return F.get("done_t7", false) and isRealW(S.world)): return
	objective("Choď spať.")
	S.can_sleep = 5
	if not await until(func(): return F.get("slept5", false)): return
	end_day()


func day6() -> void:
	set_world("fake")
	tp(4.5, 6.2, 0.0)
	if not await wait(1.2): return
	msg("Ticho. Žiadne kroky. Žiadne sekanie.", 3.5)
	if not await wait(3.6): return
	objective("Hľadaj ďalšiu kazetu.")
	if not await until(func(): return has("tapeX")): return
	objective("Pusti ju.")
	if not await until(func(): return F.get("revealed", false) and not S.busy): return
	F.baseOpen = true
	W.doors.base.locked = false
	if not await wait(2.5): return
	set_mon("host", {"x": 22.5, "z": 7.5, "mode": "chase", "worlds": ["real"], "speed": 2.95})
	set_mon("mimic", {"x": 2.0, "z": 13.0, "state": "wander", "worlds": ["real"]})
	objective("UTEČ DO PIVNICE!")
	if not await until(func(): return S.zone == "base"): return
	MON.host.mode = "stalk"
	MON.host.state = "stalk"
	objective("Nájdi kazetu 13.")
	if not await until(func(): return has("tape13")): return
	objective("Choď spať.")
	S.can_sleep = 6
	if not await until(func(): return F.get("slept6", false)): return
	end_day()


func day7() -> void:
	tp(20.6, 11.4, -PI / 2)
	F.baseOpen = true
	W.doors.base.locked = false
	W.set_door("bed", true, false, true)
	set_mon("mother", {"x": 4.0, "z": 11.0, "worlds": ["real"], "state": "wander"})
	set_mon("butcher", {"x": 12.5, "z": 2.0, "state": "patrol", "roam": true, "roam_both": true, "worlds": ["real"]})
	set_mon("sister", {"x": 12.0, "z": 12.0, "mode": "haunt", "worlds": ["real"], "resp": 25.0})
	set_mon("host", {"x": 2.0, "z": 2.0, "mode": "stalk", "worlds": ["real"]})
	set_mon("mimic", {"x": 16.0, "z": 3.0, "state": "wander", "worlds": ["real"]})
	if not await wait(1.2): return
	msg("Posledný deň.", 3.5)
	if not await wait(3.2): return
	if not F.get("t13fixed", false):
		objective("Oprav kazetu 13.")
	if not await until(func(): return F.get("t13fixed", false) or (has("spool") and has("roll"))): return
	if not F.get("t13fixed", false):
		objective("Stôl v pracovni.")
	if not await until(func(): return F.get("t13fixed", false)): return
	objective("Pusti kazetu 13 v obývačke.")
	if all_notes():
		get_tree().create_timer(12.0).timeout.connect(func():
			if S.day == 7:
				say([["", "…nula… tam, kde spia hračky…", 3.2]]))
	await until(func(): return S.world == "hosp")


# =====================================================================
# saves & stats
# =====================================================================
func cp_save() -> void:
	if not isRealW(S.world) or S.busy or S.dead or S.hidden != null or S.inserted != null or S.cine or S.fast:
		return
	CP = {"day": S.day, "step_n": S.step_n, "F": F.duplicate(true), "batt": S.batt, "knife": S.knife, "hp": maxf(S.hp, 50.0), "x": S.x, "z": S.z,
		"yaw": S.yaw, "lit": S.lit.duplicate(), "world": S.world, "power": S.power}
	M.save_game()
	U.toast("● Uložené", 1.4, true)


func cp_apply() -> void:
	var c = S.resume_cp
	if c == null:
		return
	S.resume_cp = null
	S.fast = false
	if c.world != S.world:
		set_world(c.world)
	S.power = c.power
	tp(c.x, c.z, c.yaw)
	S.lit = c.lit.duplicate()
	S.batt = c.batt
	S.knife = c.knife
	S.hp = c.hp
	S.invuln = 3.0
	apply_world(S.world)
	msg("Pokračuješ od posledného uloženia.", 3)


func _load_stats() -> void:
	var f := FileAccess.open("user://k13_stats.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			ST = d


func _save_stats() -> void:
	var f := FileAccess.open("user://k13_stats.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(ST))


func reset_stats() -> void:
	ST = {"time": 0.0, "deaths": 0, "chg": 0, "best": ST.get("best", [])}
	_save_stats()


func fmt_t(s: float) -> String:
	var t := int(round(s))
	var h := t / 3600
	var m := (t / 60) % 60
	var x := t % 60
	return ("%d:%02d:%02d" % [h, m, x]) if h > 0 else ("%d:%02d" % [m, x])


func _stats_block() -> Array:
	var notes := 0
	for k in C.NOTES:
		notes += 1 if F.get("read_" + k, false) else 0
	var clues: int = F.get("clues", []).size()
	return [["Čas", fmt_t(ST.time)], ["Smrti", str(ST.deaths)], ["Indície", "%d / %d" % [clues, C.CLUES.size()]], ["Zmeny v dome", "%d / 13" % ST.get("chg", 0)],
		["Poznámky", "%d / 6" % notes], ["Koniec", S.ending if S.ending else "?"]]


func _stats_best() -> Array:
	var best: Array = ST.get("best", [])
	best.append({"t": ST.time, "e": S.ending if S.ending else "?", "d": ST.deaths})
	best.sort_custom(func(a, b): return a.t < b.t)
	best = best.slice(0, 5)
	ST.best = best
	_save_stats()
	var out := []
	for b in best:
		out.append("%s · koniec %s · smrti %d" % [fmt_t(b.t), b.e, int(b.d)])
	return out


# =====================================================================
# intro cinematic
# =====================================================================
func intro_cine() -> void:
	S.busy = true
	S.lock_cam = true
	S.cine = true
	S.skip = false
	set_world("real")
	S.lit = {}
	S.flash = true
	S.batt = 90.0
	U.cine(true)
	set_osd(true, "PM 11:59", "OKT. 14 2024", true)
	var K := [[1.0, 11.5, -PI / 2, 0.0], [3.2, 11.2, -PI * 0.4, 0.02], [4.5, 9.6, -0.05, 0.0], [4.5, 6.6, 0.0, -0.06], [4.5, 4.0, 0.0, -0.04], [4.5, 2.2, 0.0, -0.02]]
	post("fade", 1.0)
	tween_val(func(v): post("fade", v), 1.0, 0.0, 2.2)
	A.set_loop("drone", 0.35, 1)
	var t0: float = S.time
	var dur := 15.0
	var last_beat := -10.0
	var wh := false
	var tvf := false
	while not S.skip and S.time - t0 < dur:
		var k: float = (S.time - t0) / dur
		var fi: float = k * (K.size() - 1)
		var i := mini(K.size() - 2, int(floorf(fi)))
		var u := fi - i
		var e := u * u * (3 - 2 * u)
		var a = K[i]
		var b = K[i + 1]
		tp(lerpf(a[0], b[0], e), lerpf(a[1], b[1], e), lerpf(a[2], b[2], e), lerpf(a[3], b[3], e))
		if S.time - last_beat > (0.55 if k > 0.7 else 1.1):
			last_beat = S.time
			A.play("heart", -10 + k * 10)
		if k > 0.55 and not wh:
			wh = true
			A.play("whisper")
			say([["", "…vitaj doma, %s…" % nm() if nm() else "…vitaj doma…", 2.6]])
			if nm():
				A.speak("???", "vitaj doma, " + nm())
		if k > 0.82 and not tvf:
			tvf = true
			A.set_loop("tv", 0.5, 2)
		await get_tree().process_frame
	if not S.skip:
		U.face_flash(0.12)
		A.play("stinger")
		post("glitch", 1.0)
		await sleep(0.5)
		post("glitch", 0.0)
	A.set_loop("tv", 0.0)
	await tween_val(func(v): post("fade", v), 0.0, 1.0, 0.6)
	set_osd(false)
	U.cine(false)
	S.cine = false
	S.lock_cam = false
	S.busy = false


func begin_game(day: int, from_save: bool) -> void:
	S.running = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	U.hud_show(true)
	if day == 1 and not from_save:
		await intro_cine()
		start_day(1, false)
	elif from_save and CP != null and CP.day == day:
		S.deaths_today = 0
		start_day(day, true, CP)
	else:
		start_day(day, from_save)


func new_game() -> void:
	reset_stats()
	CP = null
	SNAP = null
	F = {}
	S.batt = 90.0
	S.knife = 0
	M.save_game()


# =====================================================================
# main loop
# =====================================================================
func physics(dt: float) -> void:
	if live() and S.qte == null and not S.busy and not S.dead and S.hidden == null and not S.lock_cam:
		move_player(dt)


func process(dt: float) -> void:
	var lv := live()
	if lv:
		S.time += dt
		S.dayT += dt
		ST.time = ST.get("time", 0.0) + dt
		S.invuln = maxf(0.0, S.invuln - dt)
		if S.qte != null:
			S.qte.t -= dt
			U.qte_fill(S.qte.t / S.qte.max)
			if S.qte.t <= 0:
				qte_resolve(false)
		elif not S.busy and not S.dead:
			S.zone = zone_of(S.x)
			for k in MON:
				update_mon(MON[k], dt)
			update_mem(dt)
			update_t0(dt)
			if S.world == "fake":
				update_live()
			else:
				me_fig.visible = false
			scare_tick(dt)
			ambient_tick(dt)
			update_behind(dt)
			lights_tick(dt)
			room_t -= dt
			if room_t <= 0:
				room_t = 0.5
				for r in C.ROOMS:
					if S.x >= r[2] and S.x < r[4] and S.z >= r[3] and S.z < r[5] and isRealW(S.world):
						F["seen_" + r[0]] = true
		if not S.cine:
			flux_tick(dt)
		S.noises.clear()
		var chasing := false
		if not S.dead:
			for k in MON:
				var m = MON[k]
				if m.active and S.world in m.worlds and zone_of(m.x) == S.zone and m.stun <= 0:
					if (m.state == "chase" and not (m.type == "host" and m.mode == "stalk")) or (m.type == "tv" and m.delay <= 0) or (m.type == "sister" and m.mode == "chase") or (m.type == "mother" and m.state == "hunt" and Vector2(m.x - S.x, m.z - S.z).length() < 9):
						chasing = true
		A.set_loop("chase", 0.55 if chasing else 0.0, 6.0 if chasing else 0.8)
		S.flash_kill = maxf(0.0, S.flash_kill - dt)
		if S.flash and S.world != "fake" and S.world != "hosp" and S.world != "endB":
			S.batt = maxf(0.0, S.batt - dt * 0.4 * dif().drain)
			if S.batt <= 0:
				S.flash = false
				A.play("click")
				msg("Baterka je vybitá. Nájdi batérie.", 3)
		if S.world != "fake" and S.flash and S.batt < 20 and randf() < dt * 0.7:
			S.flick = 0.25 + randf() * 0.5
		S.hurt_t += dt
		if S.hurt_t > 8 and S.hp < 100:
			S.hp = minf(100.0, S.hp + dt * 2)
		S.dmg = maxf(0.35 if S.hp < 35 else 0.0, S.dmg - dt * 1.4)
		post("dmg", S.dmg)
		var tired_v: float = 0.85 if S.tired else pow(1.0 - S.stam / 100.0, 2.0) * 0.6
		post("tired", tired_v)
		var exert: float = 1.0 if S.tired else clampf((70.0 - S.stam) / 60.0, 0.0, 1.0)
		A.set_loop("breath", exert * 0.22 + (0.05 if chasing else 0.0), 2.0)
		A.loops.breath.pitch_scale = 1.0 + exert * 0.45
		# clocks
		var back: bool = S.world != "real"
		if S.world == "t4":
			W.gS.rotation.z = 0.0
			W.gM.rotation.z = -PI / 2
			W.gH.rotation.z = -(3.25 / 12.0) * TAU
			W.pend.rotation.z = 0.0
		else:
			S.clock += -dt if back else dt
			var sec: float = S.clock
			W.gS.rotation.z = -floorf(sec) / 60.0 * TAU
			W.gM.rotation.z = -(sec / 3600.0 + 0.7) * TAU
			W.gH.rotation.z = -(sec / 43200.0 + 0.32) * TAU
			W.pend.rotation.z = sin(sec * PI) * 0.18
		W.hosp_hands[2].rotation.z = floorf(S.time) / 60.0 * TAU
		W.hosp_hands[1].rotation.z = (S.time / 3600.0 + 0.2) * TAU
		W.hosp_hands[0].rotation.z = (S.time / 43200.0 + 0.6) * TAU
		tick_acc += dt
		if tick_acc >= 1:
			tick_acc = 0.0
			var cd := Vector2(S.x - HX - 2.5, S.z - 0.2).length() if S.world == "hosp" else Vector2(S.x - 8.45, S.z - 0.45).length()
			if cd < 5 and S.world != "t4" and S.world != "t2":
				A.play_at("tick_back" if back else "tick", Vector3(8.45, 1.7, 0.6) if S.world != "hosp" else Vector3(HX + 2.5, 2.1, 0.1), -6)
		if S.world == "hosp":
			beep_acc += dt
			if beep_acc > 1.05:
				beep_acc = 0.0
				A.play_at("beep", Vector3(HX + 3.5, 1.35, 1.8), -8)
		if not S.busy:
			var td := Vector2(S.x - 4.5, S.z - 0.95).length()
			var on: bool = S.world != "hosp" and S.power and W.tv_mat.get_shader_parameter("mode") > 0.5
			A.set_loop("tv", maxf(0.0, 0.22 * (1 - td / 8)) * (0.4 if W.tv_mat.get_shader_parameter("mode") > 1.5 else 1.0) if on and S.world != "t0" else 0.0)
		# microphone while hiding
		if S.hidden != null:
			var lvm: float = A.mic_level
			U.mic_fill(minf(1.0, lvm * 9.0))
			if A.mic_on:
				mic_loud = mic_loud + dt if lvm > 0.07 else 0.0
				if mic_loud > 0.25:
					mic_heard()
		# pick target
		cur = null
		if not S.busy and S.hidden == null and S.qte == null:
			_pick()
		U.prompt(cur.lbl if cur else null, S.hidden != null)
		U.update_hud(dt)
	# host hum / tv static volume
	for t in ["host", "tv"]:
		var want: bool = MON[t].node.visible and live()
		if MON[t].hum.playing != want:
			MON[t].hum.playing = want
	# camera
	S.shake = maxf(0.0, S.shake - dt * 1.4)
	var sh: float = S.shake * S.shake
	var still: bool = S.lock_cam or S.hidden != null
	var bob_y: float = 0.0 if still else sin(S.bob) * 0.035
	var bob_x: float = 0.0 if still else cos(S.bob * 0.5) * 0.02
	var cam_y: float = S.cam_y if S.lock_cam and S.cam_y > 0 else (0.22 if S.hidden != null and S.hidden.get("bed", false) else (1.55 if S.hidden != null else 1.6))
	player.position = Vector3(S.x, 0, S.z)
	player.rotation.y = S.yaw
	head.position = Vector3(bob_x + randf_range(-1, 1) * sh * 0.06, cam_y + bob_y + randf_range(-1, 1) * sh * 0.06, 0)
	head.rotation.x = S.pitch + randf_range(-1, 1) * sh * 0.025
	torch.visible = S.running and not S.lock_cam and S.hidden == null and S.world != "hosp"
	knife_v.visible = S.knife > 0 and S.hidden == null and not S.lock_cam and S.running
	torch_sway = torch_sway.lerp(Vector2.ZERO, minf(1.0, dt * 6.0)).clamp(Vector2(-0.04, -0.04), Vector2(0.04, 0.04))
	var tb := Vector3(sin(S.bob * 0.5) * 0.012, absf(cos(S.bob * 0.5)) * 0.01, 0)
	torch.position = torch.position.lerp(TORCH_REST + tb + Vector3(-torch_sway.x, torch_sway.y, 0), minf(1.0, dt * 12.0))
	var fi := flash_i()
	S.flick = maxf(0.0, S.flick - dt)
	flash.light_energy = fi * 3.3
	torch_lens.emission_energy_multiplier = 3.0 if fi > 0.5 else 0.0
	hand_light.light_energy = 0.18 if fi > 0.5 else 0.06
	if isRealW(S.world) and S.power:
		W.tv_light.light_energy = 0.7 + randf() * 0.4
	for k in MON:
		var m = MON[k]
		if not m.active:
			m.node.visible = false
	angel.visible = S.angel_on
	for d in W.door_list:
		d.cur = lerpf(d.cur, d.target, minf(1.0, dt * 4.0))
		d.pv.rotation.y = d.cur


func _pick() -> void:
	var cp := cam.global_position
	var fw := -cam.global_transform.basis.z
	var best = null
	var bs := 1e9
	for o in inter:
		if not o.when.call():
			continue
		var p: Vector3 = o.pos.call()
		var v := p - cp
		var d := v.length()
		if d > o.r:
			continue
		var a := acos(clampf(v.normalized().dot(fw), -1.0, 1.0))
		if a > atan(0.3 / maxf(0.3, d)) + 0.1:
			continue
		if S.world != "hosp":
			var q := PhysicsRayQueryParameters3D.create(cp, p - v.normalized() * 0.18)
			q.exclude = [player.get_rid()]
			if not M.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				continue
		if a < bs:
			bs = a
			best = o
	if best != null:
		var l = best.label.call()
		if l != null:
			cur = {"o": best, "lbl": l}
