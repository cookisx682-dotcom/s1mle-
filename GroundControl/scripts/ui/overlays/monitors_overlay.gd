extends "res://scripts/ui/overlays/overlay_base.gd"
## Station 2 — monitors. Large interactive versions of the CRT screens:
## terrain map (click to send Mia), life support, helmet camera and the technical manual.

const LifeSupportScreen = preload("res://scripts/ui/screens/life_support_screen.gd")
const TerrainMapScreen = preload("res://scripts/ui/screens/terrain_map_screen.gd")
const HelmetCamScreen = preload("res://scripts/ui/screens/helmet_cam_screen.gd")
const ManualScreen = preload("res://scripts/ui/screens/manual_screen.gd")

var screens: Array = []
var brief_label: Label
var status_label: Label


func _init() -> void:
	use_crt = true
	crt_tint = Color(0.95, 1.0, 0.97)


func _build() -> void:
	var body := make_window("MONITOR BANK · TELEMETRY")
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.45
	h.add_child(left)
	var map: Control = _add_screen(left, TerrainMapScreen, 3.0)
	map.set("interactive", true)
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	brief_label = UiTheme.label("", 11, UiTheme.COL_AMBER, true)
	brief_label.custom_minimum_size = Vector2(0, 30)
	left.add_child(brief_label)
	status_label = UiTheme.label("", 10, UiTheme.COL_GREEN, true)
	left.add_child(status_label)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_add_screen(right, LifeSupportScreen, 1.0)
	_add_screen(right, HelmetCamScreen, 1.2)
	_add_screen(right, ManualScreen, 1.3)
	_set_on_screen(false)


func _add_screen(parent: Control, screen_script: GDScript, ratio: float) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color.BLACK, Color("2b4a3c"), 1, 2))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = ratio
	parent.add_child(frame)
	var s: Control = screen_script.new()
	s.set("interactive", true)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(60, 40)
	frame.add_child(s)
	screens.append(s)
	return s


func _set_on_screen(v: bool) -> void:
	for s in screens:
		s.set("on_screen", v)


func _on_open() -> void:
	_set_on_screen(true)


func _on_close() -> void:
	_set_on_screen(false)


func _process(_delta: float) -> void:
	if not visible:
		return
	var m := MissionGenerator.active
	if m.is_empty():
		brief_label.text = "No traverse requested. Mia is at the lander."
		status_label.text = ""
		return
	if str(m.get("type", "")) == "navigation":
		brief_label.text = "MIA: \"%s\"" % str(m.get("brief", ""))
		if str(m.get("state", "")) == "travel":
			status_label.text = "EN ROUTE…"
		else:
			var cam := "CAM TRIANGULATION ON (green box)" if ResourceManager.is_on("cam") else "HELMET CAM OFF — navigating blind"
			status_label.text = "Click the target cell. Attempts left: %d · %s" % [int(m["max_attempts"]) - int(m["attempts"]), cam]
	else:
		brief_label.text = "MIA: \"%s\"" % str(m.get("brief", ""))
		status_label.text = "Read the manual (right), then dictate the steps at the RADIO CONSOLE."
