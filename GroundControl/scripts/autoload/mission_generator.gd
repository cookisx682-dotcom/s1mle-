extends Node
## MissionGenerator (autoload)
## Builds missions from templates in res://data/missions.json.
##  - "navigation": Mia describes a target relative to a landmark; the player clicks the cell on
##    the terrain map. Right cell = fast trip, wrong cell = wasted oxygen.
##  - "repair": the manual (monitors) lists steps; the player dictates them in order at the console.
## Templates with "random": true are used for procedural side missions (random landmarks,
## directions and briefs), others are story missions started by effects:
##   {"type": "mission", "template": "nav_site_alpha"}

signal mission_started(mission: Dictionary)
signal mission_updated(mission: Dictionary)
signal mission_finished(mission: Dictionary, success: bool)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const PATH := "res://data/missions.json"
const DEFAULT_DIRS := {"north": [0, -1], "south": [0, 1], "east": [1, 0], "west": [-1, 0]}

var config: Dictionary = {}
var templates: Dictionary = {}
var map_size := Vector2i(12, 8)
var home := Vector2i(2, 6)
var active: Dictionary = {}
var pending: Array = []
var map_landmarks: Array = []       # [{"name", "kind", "cell": Vector2i}] shown on the terrain map
var mia_cell := Vector2i(2, 6)
var rng := RandomNumberGenerator.new()
var _counter := 0
var _running := false


func _ready() -> void:
	var raw: Variant = DataLoader.load_json(PATH, {})
	if raw is Dictionary:
		config = raw
	var m: Dictionary = config.get("map", {})
	map_size = Vector2i(int(m.get("width", 12)), int(m.get("height", 8)))
	var h: Array = m.get("home", [2, 6])
	home = Vector2i(int(h[0]), int(h[1]))
	mia_cell = home
	for t in config.get("templates", []):
		if t is Dictionary:
			templates[str(t.get("id", ""))] = t
	rng.randomize()
	map_landmarks = _random_landmarks(4)


func start_day(_day: Dictionary) -> void:
	_running = true
	active = {}
	pending = []
	mia_cell = home
	map_landmarks = _random_landmarks(4)


func stop_day() -> void:
	_running = false
	active = {}
	pending = []
	mission_updated.emit(active)


func has_active() -> bool:
	return not active.is_empty()


func active_type() -> String:
	return str(active.get("type", ""))


func has_story_pending() -> bool:
	if bool(active.get("story", false)):
		return true
	for m in pending:
		if bool(m.get("story", false)):
			return true
	return false


# ---------------------------------------------------------------- creation

func queue_mission(template_id: String, params: Dictionary = {}) -> void:
	var t: Dictionary = {}
	if template_id == "random" or template_id == "":
		t = _pick_random_template()
	else:
		t = templates.get(template_id, {})
	if t.is_empty():
		push_warning("Unknown mission template '%s'" % template_id)
		return
	var m := _build(t, params)
	if active.is_empty() and _running:
		_start(m)
	elif bool(m.get("story", false)):
		pending.push_front(m)
	else:
		pending.append(m)


func _pick_random_template() -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for t in templates.values():
		if bool(t.get("random", false)):
			pool.append(t)
			total += float(t.get("weight", 1.0))
	if pool.is_empty():
		return {}
	var r := rng.randf() * total
	for t in pool:
		r -= float(t.get("weight", 1.0))
		if r <= 0.0:
			return t
	return pool[pool.size() - 1]


func _build(t: Dictionary, params: Dictionary) -> Dictionary:
	_counter += 1
	var m := {
		"id": "%s_%d" % [str(t.get("id", "m")), _counter],
		"template": str(t.get("id", "")),
		"type": str(t.get("type", "navigation")),
		"title": str(t.get("title", "Mission")),
		"story": bool(t.get("story", false)),
		"state": "active",
		"tpl": t,
		"params": params,
		"fmt": {"n": _counter},
	}
	if m["type"] == "repair":
		_build_repair(m, t)
	else:
		_build_navigation(m, t)
	return m


func _build_navigation(m: Dictionary, t: Dictionary) -> void:
	var landmarks: Array = []
	var target := Vector2i(-1, -1)
	var fmt: Dictionary = m["fmt"]
	if t.has("landmarks"):
		for l in t["landmarks"]:
			var nm := str(l.get("name", "?"))
			landmarks.append({"name": nm, "kind": str(l.get("kind", _kind_for(nm))), "cell": Vector2i(int(l.get("x", 0)), int(l.get("y", 0)))})
		var tg: Array = t.get("target", [0, 0])
		target = Vector2i(int(tg[0]), int(tg[1]))
	else:
		landmarks = _random_landmarks(int(t.get("landmark_count", 4)))
		var dirs: Dictionary = config.get("directions", DEFAULT_DIRS)
		var words: Dictionary = config.get("distance_words", {})
		var occupied := {home: true}
		for l in landmarks:
			occupied[l["cell"]] = true
		for attempt in 80:
			var ref: Dictionary = landmarks[rng.randi_range(0, landmarks.size() - 1)]
			var dname := str(dirs.keys()[rng.randi_range(0, dirs.size() - 1)])
			var dv: Array = dirs[dname]
			var dist := rng.randi_range(1, 2)
			var c: Vector2i = ref["cell"] + Vector2i(int(dv[0]), int(dv[1])) * dist
			if c.x < 0 or c.y < 0 or c.x >= map_size.x or c.y >= map_size.y or occupied.has(c):
				continue
			target = c
			fmt["landmark"] = ref["name"]
			fmt["dir"] = dname
			fmt["dist"] = str(words.get(str(dist), "%d grids" % dist))
			break
		if target.x < 0:
			target = Vector2i(map_size.x - 3, 2)
			fmt["landmark"] = landmarks[0]["name"] if not landmarks.is_empty() else "lander"
			fmt["dir"] = "near"
			fmt["dist"] = "somewhere"
	m["landmarks"] = landmarks
	m["target"] = target
	m["brief"] = _pick_text(t.get("brief", "Where to, Ground?")).format(fmt)
	m["attempts"] = 0
	m["max_attempts"] = int(t.get("max_attempts", 3))
	m["wrong_cells"] = []
	m["cam_used"] = false
	m["travel_t"] = 0.0
	m["travel_time"] = 5.0
	var off := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
	m["hint_center"] = Vector2i(clampi(target.x + off.x, 1, map_size.x - 2), clampi(target.y + off.y, 1, map_size.y - 2))


func _build_repair(m: Dictionary, t: Dictionary) -> void:
	var steps: Array = (t.get("steps", []) as Array).duplicate()
	var options: Array = steps.duplicate()
	options.append_array(t.get("distractors", []))
	_shuffle(options)
	m["steps"] = steps
	m["options"] = options
	m["done"] = []
	m["progress"] = 0
	m["mistakes"] = 0
	m["max_mistakes"] = int(t.get("max_mistakes", 3))
	m["manual"] = str(t.get("manual", "TECHNICAL MANUAL"))
	m["brief"] = _pick_text(t.get("brief", "Ground, I need a hand with the {title}.")).format({"title": m["title"]})


func _start(m: Dictionary) -> void:
	active = m
	if active["type"] == "navigation":
		map_landmarks = active["landmarks"]
		if bool(active["story"]):
			mia_cell = home
		active["from"] = mia_cell
		GameState.post_notify("NAVIGATION REQUEST — TERRAIN MAP ON MONITORS", "info")
	else:
		GameState.post_notify("REPAIR — MANUAL ON MONITORS, DICTATE AT CONSOLE", "info")
	DialogueManager.say("MIA", str(active["brief"]))
	AudioManager.play_sfx("radio_beep")
	mission_started.emit(active)
	GameState.emit_event("mission_started", {"template": active["template"], "type": active["type"]})


func _start_next() -> void:
	if _running and active.is_empty() and not pending.is_empty():
		_start(pending.pop_front())


# ---------------------------------------------------------------- navigation

func _process(delta: float) -> void:
	if active.is_empty() or active.get("type", "") != "navigation":
		return
	if active["state"] == "travel":
		active["travel_t"] = float(active["travel_t"]) + delta / float(active["travel_time"])
		if float(active["travel_t"]) >= 1.0:
			mia_cell = active["target"]
			_finish(true)


## Called by the interactive terrain map when the camera hint is actually shown.
func mark_cam_used() -> void:
	if not active.is_empty():
		active["cam_used"] = true


func submit_navigation(cell: Vector2i) -> void:
	if active.is_empty() or active["type"] != "navigation" or active["state"] != "active":
		return
	var t: Dictionary = active["tpl"]
	var target: Vector2i = active["target"]
	var d := absi(cell.x - target.x) + absi(cell.y - target.y)
	DialogueManager.say("YOU", "Head for grid %s." % cell_name(cell))
	if d == 0:
		var rover := ResourceManager.is_on("rover") and ResourceManager.power > 0.0
		var cost := float(t.get("rover_cost", 1.0)) if rover else float(t.get("walk_cost", 3.0))
		ResourceManager.change_oxygen(-cost, false)
		active["state"] = "travel"
		active["travel_t"] = 0.0
		active["travel_time"] = 5.0 if rover else 9.0
		active["from"] = mia_cell
		var go_line := "Copy. Rolling out." if rover else "Copy. Rover's off, so I'm walking. Give me a minute."
		DialogueManager.say("MIA", go_line)
		AudioManager.play_sfx("nav_ok")
		mission_updated.emit(active)
		return
	active["attempts"] = int(active["attempts"]) + 1
	(active["wrong_cells"] as Array).append(cell)
	ResourceManager.change_oxygen(-float(t.get("wrong_cost", 3.0)), true)
	var key := "near_lines" if d == 1 else "wrong_lines"
	var fallback := "Close... I think it's one grid over." if d == 1 else "Nothing here, Ground. That walk cost me air."
	DialogueManager.say("MIA", _pick_text(t.get(key, config.get(key, fallback))))
	AudioManager.play_sfx("nav_fail")
	if int(active["attempts"]) >= int(active["max_attempts"]):
		_finish(false)
	else:
		mission_updated.emit(active)


## "C4" style name for a grid cell.
func cell_name(cell: Vector2i) -> String:
	return "%s%d" % [char(65 + cell.x), cell.y + 1]


# ---------------------------------------------------------------- repair

func dictate_step(index: int) -> void:
	if active.is_empty() or active["type"] != "repair":
		return
	var opts: Array = active["options"]
	if index < 0 or index >= opts.size():
		return
	var done: Array = active["done"]
	if done.has(index):
		return
	var steps: Array = active["steps"]
	var t: Dictionary = active["tpl"]
	var progress := int(active["progress"])
	DialogueManager.say("YOU", str(opts[index]))
	if progress < steps.size() and str(opts[index]) == str(steps[progress]):
		done.append(index)
		active["progress"] = progress + 1
		AudioManager.play_sfx("switch")
		if progress + 1 >= steps.size():
			_finish(true)
		else:
			DialogueManager.say("MIA", _pick_text(t.get("ok_lines", config.get("ok_lines", "Done. Next step?"))))
			mission_updated.emit(active)
		return
	active["mistakes"] = int(active["mistakes"]) + 1
	DialogueManager.say("MIA", _pick_text(t.get("bad_lines", config.get("bad_lines", "Sparks! That was not the right step."))))
	AudioManager.play_sfx("string_fail")
	GameState.apply_effects(t.get("mistake_effects", []))
	if int(active["mistakes"]) >= int(active["max_mistakes"]):
		_finish(false)
	else:
		mission_updated.emit(active)


# ---------------------------------------------------------------- finishing

func _finish(success: bool) -> void:
	var m := active
	active = {}
	m["state"] = "done"
	var t: Dictionary = m["tpl"]
	var p: Dictionary = m["params"]
	if success:
		GameState.add_stat("missions_ok")
		DialogueManager.say("MIA", _pick_text(t.get("success_lines", "On site. Good call, Ground.")).format(m["fmt"]))
		AudioManager.play_sfx("crisis_ok")
		if m["type"] == "navigation":
			GameState.emit_event("navigation_success", {"template": m["template"], "helmet_cam": bool(m["cam_used"])})
		_grant_card(m, t)
		GameState.apply_effects(t.get("on_success", []))
		GameState.apply_effects(p.get("on_success", []))
	else:
		GameState.add_stat("missions_failed")
		DialogueManager.say("MIA", _pick_text(t.get("fail_lines", "I'm calling it, Ground. Heading back.")))
		AudioManager.play_sfx("crisis_fail")
		if m["type"] == "navigation" and bool(m["story"]):
			mia_cell = m["target"]
		GameState.apply_effects(t.get("on_fail", []))
		GameState.apply_effects(p.get("on_fail", []))
	GameState.emit_event("mission_finished", {"template": m["template"], "success": success})
	GameState.apply_effects(t.get("on_complete", []))
	GameState.apply_effects(p.get("on_complete", []))
	mission_finished.emit(m, success)
	mission_updated.emit(active)
	if not pending.is_empty():
		get_tree().create_timer(4.0, false).timeout.connect(_start_next)


func _grant_card(m: Dictionary, t: Dictionary) -> void:
	if t.has("card_id"):
		BoardManager.discover(str(t["card_id"]))
		return
	var c: Variant = t.get("card", null)
	if not (c is Dictionary):
		return
	var fmt: Dictionary = m["fmt"]
	var data := {
		"type": str(c.get("type", "report")),
		"title": str(c.get("title", "Mission log")).format(fmt),
		"text": str(c.get("text", "")).format(fmt),
	}
	var id := "dyn_%s" % str(m["id"])
	BoardManager.add_dynamic_card(id, data)
	BoardManager.discover(id)


# ---------------------------------------------------------------- helpers

func _random_landmarks(count: int) -> Array:
	var names: Array = (config.get("landmark_names", ["Crater", "Ridge", "Boulder Field", "Rille"]) as Array).duplicate()
	_shuffle(names)
	var result: Array = []
	var used := {home: true}
	var tries := 0
	var wanted := mini(count, names.size())
	while result.size() < wanted and tries < 500:
		tries += 1
		var c := Vector2i(rng.randi_range(1, map_size.x - 2), rng.randi_range(1, map_size.y - 2))
		if used.has(c) or _too_close(c, result):
			continue
		used[c] = true
		var nm := str(names[result.size()])
		result.append({"name": nm, "kind": _kind_for(nm), "cell": c})
	return result


func _too_close(c: Vector2i, existing: Array) -> bool:
	for l in existing:
		var o: Vector2i = l["cell"]
		if absi(o.x - c.x) + absi(o.y - c.y) < 3:
			return true
	return false


func _kind_for(landmark_name: String) -> String:
	var n := landmark_name.to_lower()
	if n.contains("crater") or n.contains("pit"):
		return "crater"
	if n.contains("ridge") or n.contains("peak") or n.contains("mons") or n.contains("hill"):
		return "peak"
	if n.contains("boulder") or n.contains("block"):
		return "boulders"
	if n.contains("rille") or n.contains("channel"):
		return "rille"
	if n.contains("site") or n.contains("station") or n.contains("probe"):
		return "site"
	return "mark"


func _pick_text(v: Variant) -> String:
	if v is Array:
		var arr: Array = v
		if arr.is_empty():
			return ""
		return str(arr[rng.randi_range(0, arr.size() - 1)])
	return str(v)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
