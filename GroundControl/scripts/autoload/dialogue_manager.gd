extends Node
## DialogueManager (autoload)
## Branching radio conversations with Mia from res://data/dialogues.json.
## Dialogues are queued (the console blinks) and play when the player opens the radio console.
## Node format:
##   {"speaker": "MIA", "text": "...", "variants": [{"if": {...}, "text": "..."}],
##    "effects": [...], "next": "node_id" | "choices": [{"text","next","effects","if"}], "end": true}
## Choices change Mia's trust (0–100) through "trust" effects; variants let her react to it.

signal dialogue_queued(dialogue_id: String)
signal dialogue_started(dialogue_id: String)
signal line_shown(speaker: String, text: String)
signal choices_shown(choices: Array)
signal dialogue_finished(dialogue_id: String)
signal radio_message(speaker: String, text: String)
signal transcript_added(speaker: String, text: String)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const PATH := "res://data/dialogues.json"

var db: Dictionary = {}
var idle_lines: Dictionary = {}
var queue_ids: Array = []
var current_id := ""
var current_node: Dictionary = {}
var current_speaker := ""
var current_text := ""
var current_choices: Array = []      # [{"text": String, "index": int}]
var transcript: Array = []           # [{"speaker", "text"}]
var _choice_defs: Array = []


func _ready() -> void:
	var raw: Variant = DataLoader.load_json(PATH, {})
	if raw is Dictionary:
		db = (raw as Dictionary).get("dialogues", {})
		idle_lines = (raw as Dictionary).get("idle", {})


func reset() -> void:
	queue_ids = []
	current_id = ""
	current_node = {}
	current_choices = []
	_choice_defs = []
	transcript = []


## Called when a shift starts: clears pending dialogue, keeps the log with a separator.
func reset_day(title: String) -> void:
	queue_ids = []
	current_id = ""
	current_node = {}
	current_choices = []
	_choice_defs = []
	_log("LOOP", "——— %s ———" % title)


func queue(dialogue_id: String) -> void:
	if not db.has(dialogue_id):
		push_warning("Unknown dialogue '%s'" % dialogue_id)
		return
	if dialogue_id == current_id or queue_ids.has(dialogue_id):
		return
	queue_ids.append(dialogue_id)
	dialogue_queued.emit(dialogue_id)
	GameState.post_notify("INCOMING TRANSMISSION — CONSOLE", "radio")
	AudioManager.play_sfx("radio_beep")


func has_pending() -> bool:
	return current_id != "" or not queue_ids.is_empty()


func is_active() -> bool:
	return current_id != ""


func pending_count() -> int:
	return queue_ids.size() + (1 if current_id != "" else 0)


## Starts the next queued dialogue. Returns true if a dialogue is (now) running.
func start_next() -> bool:
	if current_id != "":
		return true
	if queue_ids.is_empty():
		return false
	current_id = str(queue_ids.pop_front())
	var d: Dictionary = db[current_id]
	AudioManager.play_sfx("radio_static")
	dialogue_started.emit(current_id)
	_goto(str(d.get("start", "start")))
	return true


## Continues a line that has no choices.
func advance() -> void:
	if current_id == "" or not current_choices.is_empty():
		return
	var nxt := str(current_node.get("next", ""))
	if nxt == "" or bool(current_node.get("end", false)):
		_finish()
	else:
		_goto(nxt)


func choose(index: int) -> void:
	if index < 0 or index >= _choice_defs.size():
		return
	var c: Dictionary = _choice_defs[index]
	_log("YOU", str(c.get("text", "")))
	current_choices = []
	_choice_defs = []
	GameState.apply_effects(c.get("effects", []))
	var nxt := str(c.get("next", ""))
	if nxt == "":
		_finish()
	else:
		_goto(nxt)


## One-off radio line outside a dialogue (mission briefs, crisis chatter...).
func say(speaker: String, text: String) -> void:
	if text == "":
		return
	_log(speaker, text)
	radio_message.emit(speaker, text)


## Small talk when the player pings Mia — depends on her trust.
func idle_chatter() -> void:
	var bucket := "mid"
	if GameState.trust < 35:
		bucket = "low"
	elif GameState.trust >= 70:
		bucket = "high"
	var lines: Array = idle_lines.get(bucket, [])
	if lines.is_empty():
		return
	say("MIA", str(lines[randi() % lines.size()]))


# ---------------------------------------------------------------- internals

func _goto(node_id: String) -> void:
	var d: Dictionary = db.get(current_id, {})
	var nodes: Dictionary = d.get("nodes", {})
	if not nodes.has(node_id):
		push_warning("Dialogue '%s' has no node '%s'" % [current_id, node_id])
		_finish()
		return
	current_node = nodes[node_id]
	current_speaker = str(current_node.get("speaker", d.get("speaker", "MIA")))
	current_text = _resolve_text(current_node)
	current_choices = []
	_choice_defs = []
	for c in current_node.get("choices", []):
		if c is Dictionary and GameState.check_condition(c.get("if", null)):
			current_choices.append({"text": str(c.get("text", "...")), "index": _choice_defs.size()})
			_choice_defs.append(c)
	_log(current_speaker, current_text)
	line_shown.emit(current_speaker, current_text)
	choices_shown.emit(current_choices)
	GameState.apply_effects(current_node.get("effects", []))


func _resolve_text(node: Dictionary) -> String:
	for v in node.get("variants", []):
		if v is Dictionary and GameState.check_condition(v.get("if", null)):
			return str(v.get("text", ""))
	return str(node.get("text", ""))


func _finish() -> void:
	var id := current_id
	current_id = ""
	current_node = {}
	current_choices = []
	_choice_defs = []
	choices_shown.emit([])
	dialogue_finished.emit(id)
	GameState.emit_event("dialogue_finished", {"id": id})


func _log(speaker: String, text: String) -> void:
	transcript.append({"speaker": speaker, "text": text})
	if transcript.size() > 200:
		transcript.pop_front()
	transcript_added.emit(speaker, text)
