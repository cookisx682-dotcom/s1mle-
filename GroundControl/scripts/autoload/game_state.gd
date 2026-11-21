extends Node
## GameState (autoload)
## Holds the story state (current day, Mia's trust, flags, per-shift statistics) and is the
## single interpreter of data-driven "effects" and "conditions" used by every JSON file.
## Adding a new effect type here makes it available to dialogues, faxes, missions, events...
##
## Effect format:    {"type": "trust", "value": 5}   (optionally "if": <condition>)
## Condition format: {"flag": "x", "min_trust": 60, "card": ["c_a", "c_b"], "any": [...]}

signal trust_changed(value: int)
signal flag_changed(flag_name: String, value: Variant)
signal game_event(event_name: String, data: Dictionary)
signal notify(text: String, kind: String)
signal day_started(day: Dictionary)
signal day_finished(day: Dictionary, report: Dictionary)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const DAYS_PATH := "res://data/days.json"
const START_TRUST := 50

var config: Dictionary = {}
var days: Array = []
var day_index: int = 0
var trust: int = START_TRUST
var flags: Dictionary = {}
var day_stats: Dictionary = {}
var in_game: bool = false
var ending_id: String = ""
var _fired_triggers: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	var raw: Variant = DataLoader.load_json(DAYS_PATH, {})
	if raw is Dictionary:
		config = raw
	days = config.get("days", [])
	_connect_signals.call_deferred()


func _connect_signals() -> void:
	TimeManager.shift_ended.connect(_on_shift_ended)
	ResourceManager.depleted.connect(_on_resource_depleted)


## Input actions are created in code so project.godot stays readable.
func _setup_input() -> void:
	_add_key_action("station_left", [KEY_A, KEY_LEFT])
	_add_key_action("station_right", [KEY_D, KEY_RIGHT])
	_add_key_action("pause", [KEY_ESCAPE])
	_add_key_action("crisis_1", [KEY_1, KEY_KP_1])
	_add_key_action("crisis_2", [KEY_2, KEY_KP_2])
	_add_key_action("crisis_3", [KEY_3, KEY_KP_3])
	_add_key_action("advance", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_add_mouse_action("interact", MOUSE_BUTTON_LEFT)
	_add_mouse_action("back", MOUSE_BUTTON_RIGHT)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse_action(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- game flow

func new_game() -> void:
	day_index = 0
	trust = START_TRUST
	flags = {}
	ending_id = ""
	in_game = false
	BoardManager.reset()
	DialogueManager.reset()
	EventManager.reset()
	SaveSystem.clear_progress()


## Snapshot = everything needed to restart the current shift (saved at shift start).
func make_snapshot() -> Dictionary:
	return {
		"day_index": day_index,
		"trust": trust,
		"flags": flags.duplicate(true),
		"board": BoardManager.serialize(),
	}


func load_snapshot(p: Dictionary) -> void:
	day_index = clampi(int(p.get("day_index", 0)), 0, maxi(0, days.size() - 1))
	trust = int(p.get("trust", START_TRUST))
	var f: Variant = p.get("flags", {})
	flags = (f as Dictionary).duplicate(true) if f is Dictionary else {}
	ending_id = ""
	in_game = false
	var b: Variant = p.get("board", {})
	BoardManager.deserialize(b if b is Dictionary else {})
	DialogueManager.reset()
	EventManager.reset()


func get_day() -> Dictionary:
	if day_index >= 0 and day_index < days.size():
		return days[day_index]
	return {}


func is_last_day() -> bool:
	return day_index >= days.size() - 1


func begin_day() -> void:
	var day := get_day()
	day_stats = {
		"missions_ok": 0, "missions_failed": 0, "deductions": 0, "wrong_links": 0,
		"crises_ok": 0, "crises_failed": 0, "cards": 0,
	}
	_fired_triggers = {}
	in_game = true
	DialogueManager.reset_day(str(day.get("title", "")))
	ResourceManager.start_day(day)
	MissionGenerator.start_day(day)
	EventManager.start_day(day)
	TimeManager.start_shift(day)
	day_started.emit(day)
	emit_event("day_started", {"day": str(day.get("id", ""))})


func finish_day(aborted: bool = false) -> void:
	if not in_game:
		return
	in_game = false
	TimeManager.stop_shift()
	ResourceManager.stop_day()
	EventManager.stop_day()
	MissionGenerator.stop_day()
	var report := build_report(aborted)
	emit_event("day_report", report)
	day_finished.emit(get_day(), report)


## Moves to the next day. Returns false when there is none.
func advance_day() -> bool:
	if day_index + 1 >= days.size():
		return false
	day_index += 1
	return true


func _on_shift_ended() -> void:
	finish_day(false)


func _on_resource_depleted(what: String) -> void:
	if what == "oxygen" and in_game:
		post_notify("OXYGEN CRITICAL — MIA RETURNS TO THE LANDER. SHIFT ABORTED.", "alert")
		finish_day.call_deferred(true)


func build_report(aborted: bool) -> Dictionary:
	var s := day_stats
	var wasted := snappedf(ResourceManager.oxygen_wasted, 0.1)
	var score := 60
	score += 10 * int(s.get("missions_ok", 0)) - 10 * int(s.get("missions_failed", 0))
	score += 8 * int(s.get("deductions", 0)) - 3 * int(s.get("wrong_links", 0))
	score += 8 * int(s.get("crises_ok", 0)) - 10 * int(s.get("crises_failed", 0))
	score -= int(wasted * 2.0)
	score = clampi(score, 0, 100)
	var grade := "F"
	if aborted:
		score = 0
	elif score >= 90:
		grade = "A"
	elif score >= 75:
		grade = "B"
	elif score >= 60:
		grade = "C"
	elif score >= 45:
		grade = "D"
	var comments: Dictionary = config.get("report_comments", {})
	return {
		"aborted": aborted,
		"missions_ok": int(s.get("missions_ok", 0)),
		"missions_failed": int(s.get("missions_failed", 0)),
		"deductions": int(s.get("deductions", 0)),
		"wrong_links": int(s.get("wrong_links", 0)),
		"crises_ok": int(s.get("crises_ok", 0)),
		"crises_failed": int(s.get("crises_failed", 0)),
		"cards": int(s.get("cards", 0)),
		"oxygen_left": snappedf(ResourceManager.oxygen, 0.1),
		"power_left": snappedf(ResourceManager.power, 0.1),
		"oxygen_wasted": wasted,
		"no_oxygen_waste": (not aborted) and wasted <= 0.0,
		"trust": trust,
		"score": score,
		"grade": grade,
		"comment": str(comments.get(grade, "")),
	}


## True while story-critical content is still waiting (the shift clock holds near its end).
func has_pending_story() -> bool:
	return DialogueManager.has_pending() or EventManager.has_required_pending() or MissionGenerator.has_story_pending()


# ---------------------------------------------------------------- state helpers

func change_trust(delta: int) -> void:
	if delta == 0:
		return
	trust = clampi(trust + delta, 0, 100)
	trust_changed.emit(trust)
	emit_event("trust_changed", {"value": trust, "delta": delta})


func set_flag(flag_name: String, value: Variant = true) -> void:
	if flag_name == "":
		return
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)
	emit_event("flag_set", {"flag": flag_name, "value": value})


func get_flag(flag_name: String) -> bool:
	var v: Variant = flags.get(flag_name, false)
	if v is bool:
		return v
	return v != null and str(v) != "" and str(v) != "0" and str(v) != "false"


func add_stat(stat_name: String, amount: int = 1) -> void:
	day_stats[stat_name] = int(day_stats.get(stat_name, 0)) + amount


func post_notify(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)


## Emits a game event (used by achievements and by day "triggers" in days.json).
func emit_event(event_name: String, data: Dictionary = {}) -> void:
	game_event.emit(event_name, data)
	if in_game:
		_check_day_triggers(event_name, data)


func _check_day_triggers(event_name: String, data: Dictionary) -> void:
	var triggers: Array = get_day().get("triggers", [])
	for i in triggers.size():
		var tr: Dictionary = triggers[i]
		var key := str(tr.get("id", "trigger_%d" % i))
		if bool(tr.get("once", true)) and _fired_triggers.has(key):
			continue
		if not event_matches(tr, event_name, data):
			continue
		if not check_condition(tr.get("if", null)):
			continue
		_fired_triggers[key] = true
		apply_effects(tr.get("effects", []))


## {"on": "deduction_found", "match": {"id": "ded_x", "min_value": 90}}
## Keys starting with min_/max_ compare numbers, other keys must be equal.
static func event_matches(trigger: Dictionary, event_name: String, data: Dictionary) -> bool:
	if str(trigger.get("on", "")) != event_name:
		return false
	var m: Variant = trigger.get("match", {})
	if not (m is Dictionary):
		return true
	for key in (m as Dictionary).keys():
		var k := str(key)
		var expected: Variant = m[key]
		if k.begins_with("min_"):
			if float(data.get(k.substr(4), -INF)) < float(expected):
				return false
		elif k.begins_with("max_"):
			if float(data.get(k.substr(4), INF)) > float(expected):
				return false
		elif not values_equal(data.get(k, null), expected):
			return false
	return true


static func values_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var a_num := ta == TYPE_INT or ta == TYPE_FLOAT
	var b_num := tb == TYPE_INT or tb == TYPE_FLOAT
	if a_num and b_num:
		return is_equal_approx(float(a), float(b))
	var a_str := ta == TYPE_STRING or ta == TYPE_STRING_NAME
	var b_str := tb == TYPE_STRING or tb == TYPE_STRING_NAME
	if a_str and b_str:
		return str(a) == str(b)
	if ta != tb:
		return false
	return a == b


# ---------------------------------------------------------------- effects

func apply_effects(effects: Variant) -> void:
	if effects == null:
		return
	for e in DataLoader.as_list(effects):
		if e is Dictionary:
			_apply_effect(e)


func _apply_effect(e: Dictionary) -> void:
	if e.has("if") and not check_condition(e["if"]):
		return
	var t := str(e.get("type", ""))
	match t:
		"trust":
			change_trust(int(e.get("value", 0)))
		"flag":
			set_flag(str(e.get("name", "")), e.get("value", true))
		"card":
			BoardManager.discover(str(e.get("id", "")))
		"dialogue":
			DialogueManager.queue(str(e.get("id", "")))
		"say":
			DialogueManager.say(str(e.get("speaker", "MIA")), str(e.get("text", "")))
		"fax":
			EventManager.queue_fax(str(e.get("id", "")))
		"visitor":
			EventManager.show_visitor(str(e.get("id", "")))
		"crisis":
			EventManager.start_crisis(str(e.get("id", "")))
		"mission":
			var params: Variant = e.get("params", {})
			MissionGenerator.queue_mission(str(e.get("template", "random")), params if params is Dictionary else {})
		"oxygen":
			ResourceManager.change_oxygen(float(e.get("value", 0.0)), bool(e.get("waste", false)))
		"power":
			ResourceManager.change_power(float(e.get("value", 0.0)))
		"system":
			ResourceManager.set_system(str(e.get("name", "")), bool(e.get("value", true)))
		"time":
			TimeManager.add_penalty_minutes(float(e.get("minutes", 0.0)))
		"achievement":
			AchievementManager.unlock(str(e.get("id", "")))
		"notify":
			post_notify(str(e.get("text", "")), str(e.get("kind", "info")))
		"event":
			var d: Variant = e.get("data", {})
			emit_event(str(e.get("name", "")), d if d is Dictionary else {})
		"stat":
			add_stat(str(e.get("name", "")), int(e.get("value", 1)))
		"sound":
			AudioManager.play_sfx(str(e.get("name", "")))
		"ending":
			ending_id = str(e.get("id", "default"))
		"end_day":
			finish_day.call_deferred(false)
		"delay":
			_delay_effects(float(e.get("seconds", 1.0)), e.get("effects", []))
		_:
			push_warning("Unknown effect type '%s'" % t)


func _delay_effects(seconds: float, effects: Variant) -> void:
	var timer := get_tree().create_timer(seconds, false)
	timer.timeout.connect(_on_delay_timeout.bind(effects))


func _on_delay_timeout(effects: Variant) -> void:
	if in_game:
		apply_effects(effects)


# ---------------------------------------------------------------- conditions

func check_condition(c: Variant) -> bool:
	if c == null:
		return true
	if c is Array:
		for sub in c:
			if not check_condition(sub):
				return false
		return true
	if not (c is Dictionary):
		return true
	var cond: Dictionary = c
	for key in cond.keys():
		var v: Variant = cond[key]
		match str(key):
			"flag":
				for f in DataLoader.as_list(v):
					if not get_flag(str(f)):
						return false
			"not_flag":
				for f in DataLoader.as_list(v):
					if get_flag(str(f)):
						return false
			"min_trust":
				if trust < int(v):
					return false
			"max_trust":
				if trust > int(v):
					return false
			"card":
				for cid in DataLoader.as_list(v):
					if not BoardManager.discovered.has(str(cid)):
						return false
			"deduction":
				for did in DataLoader.as_list(v):
					if not BoardManager.deductions_found.has(str(did)):
						return false
			"no_deduction":
				for did in DataLoader.as_list(v):
					if BoardManager.deductions_found.has(str(did)):
						return false
			"min_day":
				if day_index + 1 < int(v):
					return false
			"any":
				var ok := false
				for sub in DataLoader.as_list(v):
					if check_condition(sub):
						ok = true
						break
				if not ok:
					return false
			_:
				push_warning("Unknown condition key '%s'" % str(key))
	return true
