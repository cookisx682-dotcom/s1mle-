extends Node
## AchievementManager (autoload)
## Definitions live in res://data/achievements.json. Each one has a trigger that matches
## a game event, e.g. {"on": "deduction_found"} or {"on": "trust_changed", "match": {"min_value": 90}}.
## Unlocks are saved immediately (SaveSystem) and shown as a pixel toast in the top-right corner.

signal achievement_unlocked(achievement_id: String)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const PATH := "res://data/achievements.json"
const TOAST_SIZE := Vector2(340, 70)

var defs: Array = []
var unlocked: Dictionary = {}       # id -> unix time
var _layer: CanvasLayer
var _queue: Array = []
var _showing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raw: Variant = DataLoader.load_json(PATH, {})
	if raw is Dictionary:
		defs = (raw as Dictionary).get("achievements", [])
	unlocked = SaveSystem.get_achievements()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	GameState.game_event.connect(_on_game_event)


func get_defs() -> Array:
	return defs


func get_def(achievement_id: String) -> Dictionary:
	for d in defs:
		if str(d.get("id", "")) == achievement_id:
			return d
	return {}


func is_unlocked(achievement_id: String) -> bool:
	return unlocked.has(achievement_id)


func unlocked_count() -> int:
	var n := 0
	for d in defs:
		if unlocked.has(str(d.get("id", ""))):
			n += 1
	return n


func unlock(achievement_id: String) -> void:
	if achievement_id == "" or unlocked.has(achievement_id):
		return
	var def := get_def(achievement_id)
	if def.is_empty():
		push_warning("Unknown achievement '%s'" % achievement_id)
		return
	unlocked[achievement_id] = int(Time.get_unix_time_from_system())
	SaveSystem.save_achievements(unlocked)
	achievement_unlocked.emit(achievement_id)
	_queue.append(def)
	if not _showing:
		_show_next()


func _on_game_event(event_name: String, data: Dictionary) -> void:
	for d in defs:
		var id := str(d.get("id", ""))
		if unlocked.has(id):
			continue
		var trig: Variant = d.get("trigger", {})
		if trig is Dictionary and GameState.event_matches(trig, event_name, data):
			unlock(id)


# ---------------------------------------------------------------- toast

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var def: Dictionary = _queue.pop_front()
	var vw := get_viewport().get_visible_rect().size.x

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.glow_box(UiTheme.COL_BG, UiTheme.COL_CYAN, Color(UiTheme.COL_CYAN, 0.35), 8))
	panel.custom_minimum_size = TOAST_SIZE
	panel.size = TOAST_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(vw + 20.0, 18.0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.COL_CYAN, UiTheme.COL_CYAN, 0, 0))
	var glyph := UiTheme.label(str(def.get("icon", "**")), 18, UiTheme.COL_BG)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(glyph)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiTheme.label("ACHIEVEMENT UNLOCKED", 11, UiTheme.COL_VIOLET))
	col.add_child(UiTheme.label(str(def.get("title", "")), 15, UiTheme.COL_CYAN))
	row.add_child(col)

	var font_override := UiTheme.mono_font()
	for l in [glyph]:
		(l as Label).add_theme_font_override("font", UiTheme.mono_font_bold())
	for c in col.get_children():
		(c as Label).add_theme_font_override("font", font_override)

	_layer.add_child(panel)
	AudioManager.play_sfx("achievement")
	var target_x := vw - TOAST_SIZE.x - 18.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:x", target_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2)
	tw.tween_property(panel, "position:x", vw + 20.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_show_next)
