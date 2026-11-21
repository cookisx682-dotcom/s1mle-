extends Node
## ResourceManager (autoload)
## Oxygen, power and habitat temperature slowly drain during a shift.
## Systems (heat, lights, rover, helmet cam) draw power; switching them off saves it.
## Side effects: cold habitat → Mia breathes harder (more O2), no power → scrubbers struggle.
## "Wasted" oxygen (mistakes) is tracked separately for the daily report / achievement.

signal changed
signal system_changed(system_name: String, on: bool)
signal depleted(what: String)

const DEFAULT_RATES := {
	"oxygen_base": 0.045,
	"power_base": 0.02,
	"system_power": {"heat": 0.035, "lights": 0.015, "rover": 0.025, "cam": 0.015},
	"cold_threshold": 10.0,
	"cold_oxygen_mult": 1.3,
	"blackout_oxygen_mult": 2.0,
	"temp_target": 21.0,
	"temp_rise": 0.08,
	"temp_drop": 0.06,
	"temp_min": -5.0,
}

const SYSTEM_NAMES := {"heat": "HEATING", "lights": "HAB LIGHTS", "rover": "ROVER", "cam": "HELMET CAM"}

var rates: Dictionary = DEFAULT_RATES.duplicate(true)
var oxygen := 100.0
var power := 100.0
var temperature := 21.0
var systems: Dictionary = {"heat": true, "lights": true, "rover": true, "cam": true}
var oxygen_wasted := 0.0
var running := false
var _warned: Dictionary = {}
var _emit_acc := 0.0


func start_day(day: Dictionary) -> void:
	var r: Dictionary = day.get("resources", {})
	oxygen = float(r.get("oxygen", 100.0))
	power = float(r.get("power", 100.0))
	temperature = float(r.get("temperature", 21.0))
	rates = DEFAULT_RATES.duplicate(true)
	var custom: Dictionary = day.get("rates", {})
	rates.merge(custom, true)
	oxygen_wasted = 0.0
	_warned = {}
	running = true
	for k in systems.keys():
		systems[k] = true
		system_changed.emit(str(k), true)
	changed.emit()


func stop_day() -> void:
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	var o2_drain := float(rates["oxygen_base"])
	if temperature < float(rates["cold_threshold"]):
		o2_drain *= float(rates["cold_oxygen_mult"])
	if power <= 0.0:
		o2_drain *= float(rates["blackout_oxygen_mult"])
	oxygen = maxf(0.0, oxygen - o2_drain * delta)
	power = maxf(0.0, power - power_draw() * delta)
	if power <= 0.0:
		_blackout()
	if bool(systems["heat"]) and power > 0.0:
		temperature = move_toward(temperature, float(rates["temp_target"]), float(rates["temp_rise"]) * delta)
	else:
		temperature = move_toward(temperature, float(rates["temp_min"]), float(rates["temp_drop"]) * delta)
	_check_warnings()
	_emit_acc += delta
	if _emit_acc >= 0.2:
		_emit_acc = 0.0
		changed.emit()


## Power drain per second with the current system configuration.
func power_draw() -> float:
	var p := float(rates["power_base"])
	var sp: Dictionary = rates.get("system_power", {})
	for k in systems.keys():
		if bool(systems[k]):
			p += float(sp.get(k, 0.0))
	return p


func is_on(system_name: String) -> bool:
	return bool(systems.get(system_name, false))


func set_system(system_name: String, on: bool) -> void:
	if not systems.has(system_name):
		push_warning("Unknown system '%s'" % system_name)
		return
	if on and power <= 0.0:
		GameState.post_notify("NO POWER — %s CANNOT START" % SYSTEM_NAMES.get(system_name, system_name), "alert")
		on = false
	if bool(systems[system_name]) == on:
		return
	systems[system_name] = on
	system_changed.emit(system_name, on)
	GameState.emit_event("system_toggled", {"system": system_name, "on": on})
	changed.emit()


func toggle_system(system_name: String) -> bool:
	set_system(system_name, not is_on(system_name))
	return is_on(system_name)


## `waste` marks oxygen lost through mistakes (counted in the report).
func change_oxygen(value: float, waste: bool = false) -> void:
	oxygen = clampf(oxygen + value, 0.0, 100.0)
	if waste and value < 0.0:
		oxygen_wasted += -value
		GameState.post_notify("O2 LOST: %.1f%%" % -value, "alert")
	changed.emit()


func change_power(value: float) -> void:
	power = clampf(power + value, 0.0, 100.0)
	changed.emit()


func _blackout() -> void:
	var any_on := false
	for k in systems.keys():
		if bool(systems[k]):
			any_on = true
			systems[k] = false
			system_changed.emit(str(k), false)
	if any_on:
		GameState.post_notify("POWER DEPLETED — ALL SYSTEMS OFFLINE", "alert")
		AudioManager.play_sfx("alarm")


func _check_warnings() -> void:
	_warn_once("o2_25", oxygen < 25.0, "OXYGEN BELOW 25%")
	_warn_once("o2_10", oxygen < 10.0, "OXYGEN CRITICAL")
	_warn_once("pwr_20", power < 20.0, "POWER BELOW 20% — SHUT DOWN SYSTEMS")
	_warn_once("cold", temperature < float(rates["cold_threshold"]), "HABITAT IS GETTING COLD")
	if oxygen <= 0.0 and not _warned.has("o2_0"):
		_warned["o2_0"] = true
		depleted.emit("oxygen")


func _warn_once(key: String, condition: bool, text: String) -> void:
	if condition and not _warned.has(key):
		_warned[key] = true
		GameState.post_notify(text, "alert")
		AudioManager.play_sfx("alarm", 1.2, -6.0)
