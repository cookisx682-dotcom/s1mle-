extends Node
## SaveSystem (autoload)
## - user://save.json     : story progress checkpoint (taken at the start of every shift) + achievements
## - user://settings.json : player settings (volume, mouse, CRT/pixel effects, fullscreen)
## Achievements are kept when a New Game wipes the progress.

signal settings_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1

const DEFAULT_SETTINGS := {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"mouse_sensitivity": 1.0,
	"crt_enabled": true,
	"pixel_enabled": true,
	"noise_enabled": true,
	"fullscreen": false,
}

var data: Dictionary = {"version": SAVE_VERSION, "progress": {}, "achievements": {}}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_files()
	apply_settings.call_deferred()


# ---------------------------------------------------------------- progress

func has_progress() -> bool:
	var p: Variant = data.get("progress", {})
	return p is Dictionary and (p as Dictionary).has("day_index")


func get_progress() -> Dictionary:
	var p: Variant = data.get("progress", {})
	if p is Dictionary:
		return (p as Dictionary).duplicate(true)
	return {}


func save_progress(progress: Dictionary) -> void:
	data["progress"] = progress.duplicate(true)
	data["saved_at"] = Time.get_datetime_string_from_system()
	_write_save()


func clear_progress() -> void:
	data["progress"] = {}
	_write_save()


# ---------------------------------------------------------------- achievements

func get_achievements() -> Dictionary:
	var a: Variant = data.get("achievements", {})
	if a is Dictionary:
		return (a as Dictionary).duplicate()
	return {}


func save_achievements(unlocked: Dictionary) -> void:
	data["achievements"] = unlocked.duplicate()
	_write_save()


# ---------------------------------------------------------------- settings

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key, default_value))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_write_json(SETTINGS_PATH, settings)
	apply_settings()


func apply_settings() -> void:
	var want_fullscreen := bool(get_setting("fullscreen", false))
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_fullscreen and not is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_fullscreen and is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	AudioManager.apply_volumes()
	settings_changed.emit()


# ---------------------------------------------------------------- file IO

func _load_files() -> void:
	var d: Variant = _read_json(SAVE_PATH)
	if d is Dictionary:
		data.merge(d, true)
	var s: Variant = _read_json(SETTINGS_PATH)
	if s is Dictionary:
		settings.merge(s, true)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _write_save() -> void:
	data["version"] = SAVE_VERSION
	_write_json(SAVE_PATH, data)


func _write_json(path: String, value: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(value, "\t"))
