extends Node
## TimeManager (autoload)
## One shift = `shift_minutes` of real time mapped onto an in-game clock (e.g. 20:00 → 04:00).
## Wrong board links add "penalty" minutes. Near the end the clock holds while story content
## (dialogues, required faxes, story missions) is still pending, so nothing important is skipped.

signal tick(progress: float)
signal shift_ended
signal penalty_applied(minutes: float)
signal holding_changed(holding: bool)

const HOLD_AT := 0.96

var running := false
var holding := false
var shift_seconds := 600.0
var elapsed := 0.0
var clock_start := 20 * 60
var clock_span := 8 * 60


func start_shift(day: Dictionary) -> void:
	shift_seconds = maxf(30.0, float(day.get("shift_minutes", 10.0)) * 60.0)
	clock_start = _parse_clock(str(day.get("clock_start", "20:00")))
	var clock_end := _parse_clock(str(day.get("clock_end", "04:00")))
	clock_span = clock_end - clock_start
	if clock_span <= 0:
		clock_span += 24 * 60
	elapsed = 0.0
	holding = false
	running = true
	tick.emit(0.0)


func stop_shift() -> void:
	running = false
	_set_holding(false)


func _process(delta: float) -> void:
	if not running:
		return
	if progress() >= HOLD_AT and GameState.has_pending_story():
		_set_holding(true)
		return
	_set_holding(false)
	elapsed += delta
	tick.emit(progress())
	if elapsed >= shift_seconds:
		running = false
		shift_ended.emit()


func progress() -> float:
	return clampf(elapsed / shift_seconds, 0.0, 1.0)


## Minutes since midnight on the in-game clock.
func clock_minutes() -> int:
	return (clock_start + int(progress() * clock_span)) % (24 * 60)


func clock_string() -> String:
	var m := clock_minutes()
	return "%02d:%02d" % [int(m / 60.0), m % 60]


## Wrong decisions cost time: pushes the clock forward (never past the hold point).
func add_penalty_minutes(minutes: float) -> void:
	if not running or minutes <= 0.0:
		return
	var secs := minutes / float(clock_span) * shift_seconds
	elapsed = minf(elapsed + secs, shift_seconds * HOLD_AT)
	penalty_applied.emit(minutes)
	GameState.post_notify("-%d MIN" % int(minutes), "alert")


func _set_holding(v: bool) -> void:
	if v == holding:
		return
	holding = v
	holding_changed.emit(v)


func _parse_clock(s: String) -> int:
	var parts := s.split(":")
	if parts.size() < 2:
		return 20 * 60
	return int(parts[0]) * 60 + int(parts[1])
