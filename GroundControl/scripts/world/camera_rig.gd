extends Node3D
## Seated first-person camera. The player never walks: the mouse turns the head within
## yaw ±160° / pitch ±35° (smoothed), A/D snap to neighbouring stations and clicking a
## station zooms the camera to its close-up. A ray from the screen centre finds what
## the player is looking at.

signal hovered_changed(target: Node)

const YAW_LIMIT := 160.0
const PITCH_LIMIT := 35.0
const BASE_SENSITIVITY := 0.11
const SMOOTH := 9.0
const RAY_LENGTH := 6.0

var camera: Camera3D
var yaw := 0.0
var pitch := -6.0
var target_yaw := 0.0
var target_pitch := -6.0
var stations: Array = []          # [{id, name, yaw, pitch, focus}] sorted by yaw
var look_enabled := true
var zoomed := false
var cinematic := false
var hovered: Node = null
var _time := 0.0
var _zoom_from := Transform3D.IDENTITY
var _zoom_to := Transform3D.IDENTITY
var _tween: Tween


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.05
	camera.far = 60.0
	camera.current = true
	add_child(camera)
	_apply_rotation()


func set_stations(list: Array) -> void:
	stations = list.duplicate()
	stations.sort_custom(func(a, b): return float(a["yaw"]) < float(b["yaw"]))


## Looks straight at the main console.
func reset_view() -> void:
	target_yaw = 0.0
	target_pitch = -8.0
	for s in stations:
		if s["id"] == "console":
			target_pitch = float(s["pitch"])
	yaw = target_yaw
	pitch = target_pitch
	zoomed = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	if not look_enabled or zoomed or cinematic or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	var s := BASE_SENSITIVITY * float(SaveSystem.get_setting("mouse_sensitivity", 1.0))
	target_yaw = clampf(target_yaw - motion.relative.x * s, -YAW_LIMIT, YAW_LIMIT)
	target_pitch = clampf(target_pitch - motion.relative.y * s, -PITCH_LIMIT, PITCH_LIMIT)


func _process(delta: float) -> void:
	_time += delta
	if cinematic:
		target_yaw = sin(_time * 0.11) * 75.0
		target_pitch = -4.0 + sin(_time * 0.17) * 4.0
	var k := 1.0 - exp(-SMOOTH * delta)
	yaw = lerpf(yaw, target_yaw, k)
	pitch = lerpf(pitch, target_pitch, k)
	_apply_rotation()


func _apply_rotation() -> void:
	rotation_degrees = Vector3(0.0, yaw, 0.0)
	if not zoomed and camera != null:
		camera.transform = _rest_transform()


## Camera transform (relative to the rig) when not zoomed, with a tiny breathing sway.
func _rest_transform() -> Transform3D:
	var sway := Vector3(sin(_time * 0.7) * 0.004, sin(_time * 1.3) * 0.006, 0.0)
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), 0.0, deg_to_rad(sin(_time * 0.5) * 0.25)))
	return Transform3D(b, sway)


func _physics_process(_delta: float) -> void:
	if zoomed or not look_enabled or cinematic or camera == null:
		_set_hovered(null)
		return
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * RAY_LENGTH
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var target: Node = null
	if not hit.is_empty():
		var col: Object = hit.get("collider")
		if col is Node and (col as Node).has_method("set_highlight"):
			target = col as Node
	_set_hovered(target)


func _set_hovered(target: Node) -> void:
	if target == hovered:
		return
	if hovered != null and is_instance_valid(hovered):
		hovered.call("set_highlight", false)
	hovered = target
	if hovered != null:
		hovered.call("set_highlight", true)
	hovered_changed.emit(hovered)


# ---------------------------------------------------------------- stations

## dir = +1 → station to the left (A), -1 → station to the right (D).
func step_station(dir: int) -> void:
	if stations.is_empty():
		return
	var best := 0
	var best_d := INF
	for i in stations.size():
		var d := absf(float(stations[i]["yaw"]) - target_yaw)
		if d < best_d:
			best_d = d
			best = i
	var idx := best
	if best_d < 12.0:
		idx = clampi(best + dir, 0, stations.size() - 1)
	else:
		# not aligned yet: go to the nearest station in the pressed direction
		idx = best
		for i in stations.size():
			var y := float(stations[i]["yaw"])
			if dir > 0 and y > target_yaw:
				idx = i
				break
			if dir < 0 and y < target_yaw:
				idx = i
	target_yaw = float(stations[idx]["yaw"])
	target_pitch = float(stations[idx]["pitch"])
	AudioManager.play_sfx("ui_hover")


func nearest_station_id() -> String:
	var best := ""
	var best_d := INF
	for s in stations:
		var d := absf(float(s["yaw"]) - yaw)
		if d < best_d:
			best_d = d
			best = str(s["id"])
	return best if best_d < 30.0 else ""


func look_at_station(station_id: String) -> void:
	for s in stations:
		if s["id"] == station_id:
			target_yaw = float(s["yaw"])
			target_pitch = float(s["pitch"])


# ---------------------------------------------------------------- zoom

func zoom_to(focus: Transform3D) -> void:
	zoomed = true
	_set_hovered(null)
	_zoom_from = camera.transform
	_zoom_to = global_transform.affine_inverse() * focus
	_run_zoom(0.45, false)


func unzoom() -> void:
	if not zoomed:
		return
	_zoom_from = camera.transform
	_zoom_to = _rest_transform()
	_run_zoom(0.4, true)


func _run_zoom(duration: float, ending: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_zoom, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if ending:
		_tween.tween_callback(_end_zoom)


func _apply_zoom(t: float) -> void:
	camera.transform = _zoom_from.interpolate_with(_zoom_to, t)


func _end_zoom() -> void:
	zoomed = false
