extends Node
## EventManager (autoload)
## Runs each day's timeline (days.json) plus random crises and side missions, and owns
## the content of res://data/events.json:
##  - crises   : timed emergencies with 2-3 answers (keys 1/2/3 or click)
##  - visitors : colleagues who appear behind the hall window with a message
##  - faxes    : orders from HQ on the phone/fax station, optionally with choices

signal fax_received(fax_id: String)
signal fax_answered(fax_id: String)
signal visitor_arrived(visitor: Dictionary)
signal visitor_left
signal crisis_started(crisis: Dictionary)
signal crisis_ended(success: bool)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const PATH := "res://data/events.json"

var crises: Dictionary = {}
var visitors: Dictionary = {}
var faxes: Dictionary = {}
var schedule: Array = []          # [{"at": 0..1, "effects": [...], "if": cond}]
var fax_inbox: Array = []
var fax_archive: Array = []       # [{"id", "answer"}]
var current_visitor: Dictionary = {}
var visitor_queue: Array = []
var active_crisis: Dictionary = {}
var crisis_time_left := 0.0
var crisis_total := 1.0
var running := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var raw: Variant = DataLoader.load_json(PATH, {})
	if raw is Dictionary:
		var r: Dictionary = raw
		crises = r.get("crises", {})
		visitors = r.get("visitors", {})
		faxes = r.get("faxes", {})
	rng.randomize()
	TimeManager.tick.connect(_on_tick)


func reset() -> void:
	schedule = []
	fax_inbox = []
	fax_archive = []
	current_visitor = {}
	visitor_queue = []
	active_crisis = {}


func start_day(day: Dictionary) -> void:
	running = true
	schedule = []
	fax_inbox = []
	visitor_queue = []
	current_visitor = {}
	active_crisis = {}
	for e in day.get("timeline", []):
		schedule.append({"at": float(e.get("at", 0.0)), "effects": e.get("effects", []), "if": e.get("if", null)})
	var rc: Dictionary = day.get("random_crises", {})
	var pool: Array = rc.get("pool", [])
	if not pool.is_empty():
		var win: Array = rc.get("window", [0.3, 0.8])
		for i in _rand_count(rc.get("count", [1, 1])):
			var cid := str(pool[rng.randi_range(0, pool.size() - 1)])
			schedule.append({"at": rng.randf_range(float(win[0]), float(win[1])), "effects": [{"type": "crisis", "id": cid}], "if": null})
	var sm: Dictionary = day.get("side_missions", {})
	if not sm.is_empty():
		var w2: Array = sm.get("window", [0.3, 0.8])
		for i in _rand_count(sm.get("count", [1, 1])):
			schedule.append({"at": rng.randf_range(float(w2[0]), float(w2[1])), "effects": [{"type": "mission", "template": "random"}], "if": null})
	schedule.sort_custom(_sort_at)


func stop_day() -> void:
	running = false
	if not active_crisis.is_empty():
		active_crisis = {}
		crisis_ended.emit(true)
	if not current_visitor.is_empty():
		current_visitor = {}
		visitor_left.emit()


func _rand_count(v: Variant) -> int:
	if v is Array and (v as Array).size() >= 2:
		return rng.randi_range(int(v[0]), int(v[1]))
	return int(v)


func _sort_at(a: Dictionary, b: Dictionary) -> bool:
	return float(a["at"]) < float(b["at"])


func _on_tick(p: float) -> void:
	if not running:
		return
	while not schedule.is_empty() and float(schedule[0]["at"]) <= p:
		var e: Dictionary = schedule.pop_front()
		if GameState.check_condition(e.get("if", null)):
			GameState.apply_effects(e["effects"])


func _process(delta: float) -> void:
	if active_crisis.is_empty() or not running:
		return
	crisis_time_left -= delta
	if crisis_time_left <= 0.0:
		resolve_crisis(-1)


# ---------------------------------------------------------------- crises

func has_crisis() -> bool:
	return not active_crisis.is_empty()


func start_crisis(crisis_id: String) -> void:
	if not crises.has(crisis_id):
		push_warning("Unknown crisis '%s'" % crisis_id)
		return
	if not active_crisis.is_empty():
		# one crisis at a time: try again a little later
		schedule.append({"at": TimeManager.progress() + 0.04, "effects": [{"type": "crisis", "id": crisis_id}], "if": null})
		schedule.sort_custom(_sort_at)
		return
	var c: Dictionary = (crises[crisis_id] as Dictionary).duplicate(true)
	c["id"] = crisis_id
	var opts: Array = c.get("options", [])
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	c["options"] = opts
	active_crisis = c
	crisis_total = maxf(3.0, float(c.get("timer", 20.0)))
	crisis_time_left = crisis_total
	AudioManager.play_sfx("alarm")
	DialogueManager.say("MIA", str(c.get("mia_line", "Ground, I've got a problem up here!")))
	GameState.emit_event("crisis_started", {"id": crisis_id})
	crisis_started.emit(active_crisis)


## index = chosen option, -1 = time ran out.
func resolve_crisis(index: int) -> void:
	if active_crisis.is_empty():
		return
	var c := active_crisis
	active_crisis = {}
	var success := false
	var opts: Array = c.get("options", [])
	if index >= 0 and index < opts.size():
		var o: Dictionary = opts[index]
		success = bool(o.get("correct", false))
		DialogueManager.say("YOU", str(o.get("text", "")))
		GameState.apply_effects(o.get("effects", []))
	if success:
		GameState.add_stat("crises_ok")
		AudioManager.play_sfx("crisis_ok")
		DialogueManager.say("MIA", str(c.get("success_line", "That did it. Thanks, Ground.")))
		GameState.apply_effects(c.get("success_effects", []))
	else:
		GameState.add_stat("crises_failed")
		AudioManager.play_sfx("crisis_fail")
		var line := str(c.get("fail_line", "That made it worse..."))
		if index < 0:
			line = str(c.get("timeout_line", "Ground? Ground, talk to me! ...I handled it myself. Barely."))
		DialogueManager.say("MIA", line)
		GameState.apply_effects(c.get("fail_effects", []))
	GameState.emit_event("crisis_resolved", {"id": c["id"], "success": success})
	crisis_ended.emit(success)


# ---------------------------------------------------------------- visitors

func show_visitor(visitor_id: String) -> void:
	if not visitors.has(visitor_id):
		push_warning("Unknown visitor '%s'" % visitor_id)
		return
	var v: Dictionary = (visitors[visitor_id] as Dictionary).duplicate(true)
	v["id"] = visitor_id
	if not current_visitor.is_empty():
		visitor_queue.append(v)
		return
	_present_visitor(v)


func _present_visitor(v: Dictionary) -> void:
	current_visitor = v
	AudioManager.play_sfx("knock")
	GameState.post_notify("%s IS AT THE WINDOW" % str(v.get("name", "SOMEONE")).to_upper(), "info")
	visitor_arrived.emit(v)


func acknowledge_visitor() -> void:
	if current_visitor.is_empty():
		return
	var v := current_visitor
	current_visitor = {}
	GameState.apply_effects(v.get("effects", []))
	GameState.emit_event("visitor_acknowledged", {"id": v["id"]})
	visitor_left.emit()
	if not visitor_queue.is_empty():
		get_tree().create_timer(3.0, false).timeout.connect(_next_visitor)


func _next_visitor() -> void:
	if current_visitor.is_empty() and not visitor_queue.is_empty() and running:
		_present_visitor(visitor_queue.pop_front())


# ---------------------------------------------------------------- faxes

func queue_fax(fax_id: String) -> void:
	if not faxes.has(fax_id):
		push_warning("Unknown fax '%s'" % fax_id)
		return
	if fax_inbox.has(fax_id) or is_archived(fax_id):
		return
	fax_inbox.append(fax_id)
	AudioManager.play_sfx("phone_ring")
	GameState.post_notify("INCOMING FAX — PHONE STATION", "info")
	fax_received.emit(fax_id)


func get_fax(fax_id: String) -> Dictionary:
	return faxes.get(fax_id, {})


func is_archived(fax_id: String) -> bool:
	for a in fax_archive:
		if str(a.get("id", "")) == fax_id:
			return true
	return false


func archived_answer(fax_id: String) -> String:
	for a in fax_archive:
		if str(a.get("id", "")) == fax_id:
			return str(a.get("answer", ""))
	return ""


func answer_fax(fax_id: String, choice_index: int) -> void:
	if not fax_inbox.has(fax_id):
		return
	var f := get_fax(fax_id)
	var choices: Array = f.get("choices", [])
	var answer := "ACKNOWLEDGED"
	fax_inbox.erase(fax_id)
	fax_archive.append({"id": fax_id, "answer": answer})
	if choice_index >= 0 and choice_index < choices.size():
		var ch: Dictionary = choices[choice_index]
		answer = str(ch.get("label", "OK"))
		fax_archive[fax_archive.size() - 1]["answer"] = answer
		GameState.apply_effects(ch.get("effects", []))
	if f.has("card"):
		BoardManager.discover(str(f["card"]))
	GameState.apply_effects(f.get("effects", []))
	AudioManager.play_sfx("paper")
	GameState.emit_event("fax_answered", {"id": fax_id, "answer": answer})
	fax_answered.emit(fax_id)


func has_required_pending() -> bool:
	for id in fax_inbox:
		if bool(get_fax(str(id)).get("required", false)):
			return true
	return false
