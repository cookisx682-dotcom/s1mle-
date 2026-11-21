extends Control
## In-game HUD: clock & day, O2/power mini bars, crosshair + interaction prompt,
## notifications, radio subtitles, station strip with attention dots and the crisis banner.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const CrisisBanner = preload("res://scripts/ui/crisis_banner.gd")
const STATIONS := [["board", "BOARD"], ["monitors", "MONITORS"], ["console", "CONSOLE"], ["window", "WINDOW"], ["phone", "PHONE"]]
const KIND_COLORS := {
	"info": Color("3fe0ff"), "card": Color("9b7bff"), "alert": Color("ffb547"),
	"story": Color("5cffb0"), "radio": Color("5cffb0"),
}

var clock_label: Label
var o2_bar: ProgressBar
var pwr_bar: ProgressBar
var o2_label: Label
var pwr_label: Label
var prompt_label: Label
var notif_box: VBoxContainer
var subtitle_label: Label
var station_labels: Dictionary = {}
var hint_label: Label
var hold_label: Label
var cross_h: ColorRect
var cross_v: ColorRect
var crisis_banner: PanelContainer
var look_mode := true
var current_station := ""
var attention: Dictionary = {}
var _blink := 0.0
var _subtitle_time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()

	# top-left: day + clock
	clock_label = UiTheme.label("", 16, UiTheme.COL_CYAN)
	clock_label.position = Vector2(18, 14)
	clock_label.add_theme_font_override("font", UiTheme.mono_font_bold())
	add_child(clock_label)
	hold_label = UiTheme.label("SHIFT HELD — PENDING TRAFFIC", 12, UiTheme.COL_AMBER)
	hold_label.position = Vector2(18, 38)
	hold_label.visible = false
	add_child(hold_label)

	# top-right: O2 / PWR
	var res := VBoxContainer.new()
	res.anchor_left = 1.0
	res.anchor_right = 1.0
	res.offset_left = -230
	res.offset_right = -18
	res.offset_top = 14
	add_child(res)
	var r1 := _bar_row(res, "O2 ", UiTheme.COL_GREEN)
	o2_bar = r1[0]
	o2_label = r1[1]
	var r2 := _bar_row(res, "PWR", UiTheme.COL_AMBER)
	pwr_bar = r2[0]
	pwr_label = r2[1]

	# crosshair
	cross_h = ColorRect.new()
	cross_v = ColorRect.new()
	for c in [cross_h, cross_v]:
		var cr: ColorRect = c
		cr.anchor_left = 0.5
		cr.anchor_right = 0.5
		cr.anchor_top = 0.5
		cr.anchor_bottom = 0.5
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.color = Color(1, 1, 1, 0.7)
		add_child(cr)
	cross_h.offset_left = -6
	cross_h.offset_right = 6
	cross_h.offset_top = -1
	cross_h.offset_bottom = 1
	cross_v.offset_left = -1
	cross_v.offset_right = 1
	cross_v.offset_top = -6
	cross_v.offset_bottom = 6

	prompt_label = UiTheme.label("", 15, UiTheme.COL_CYAN)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_left = -400
	prompt_label.offset_right = 400
	prompt_label.offset_top = 24
	prompt_label.offset_bottom = 46
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 4)
	add_child(prompt_label)

	# notifications (left)
	notif_box = VBoxContainer.new()
	notif_box.position = Vector2(18, 70)
	notif_box.add_theme_constant_override("separation", 3)
	add_child(notif_box)

	# radio subtitles
	subtitle_label = UiTheme.label("", 15, UiTheme.COL_GREEN, true)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.anchor_left = 0.15
	subtitle_label.anchor_right = 0.85
	subtitle_label.anchor_top = 1.0
	subtitle_label.anchor_bottom = 1.0
	subtitle_label.offset_top = -150
	subtitle_label.offset_bottom = -88
	subtitle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle_label.add_theme_constant_override("outline_size", 5)
	add_child(subtitle_label)

	# station strip
	var strip := HBoxContainer.new()
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = -330
	strip.offset_right = 330
	strip.offset_top = -66
	strip.offset_bottom = -44
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 22)
	add_child(strip)
	for s in STATIONS:
		var l := UiTheme.label(str(s[1]), 13, UiTheme.COL_DIM)
		strip.add_child(l)
		station_labels[s[0]] = l

	hint_label = UiTheme.label("MOUSE look · A/D stations · CLICK use · RMB/ESC back · ESC pause", 11, UiTheme.COL_DIM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.anchor_left = 0.0
	hint_label.anchor_right = 1.0
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_top = -32
	hint_label.offset_bottom = -12
	add_child(hint_label)

	crisis_banner = CrisisBanner.new()
	add_child(crisis_banner)

	GameState.notify.connect(push_notification)
	DialogueManager.radio_message.connect(_on_radio)
	DialogueManager.line_shown.connect(_on_radio)


func _bar_row(parent: Control, title: String, col: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(UiTheme.label(title, 12, col))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100
	bar.custom_minimum_size = Vector2(130, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", UiTheme.bar_style(col))
	row.add_child(bar)
	var l := UiTheme.label("100%", 12, col)
	row.add_child(l)
	return [bar, l]


func _process(delta: float) -> void:
	_blink += delta
	var day := GameState.get_day()
	clock_label.text = "DAY %d · %s · %s" % [GameState.day_index + 1, str(day.get("date_short", day.get("date", ""))), TimeManager.clock_string()]
	hold_label.visible = TimeManager.holding and fmod(_blink, 1.0) < 0.7
	o2_bar.value = ResourceManager.oxygen
	pwr_bar.value = ResourceManager.power
	o2_label.text = "%d%%" % int(ResourceManager.oxygen)
	pwr_label.text = "%d%%" % int(ResourceManager.power)
	var on := fmod(_blink * 2.0, 1.0) < 0.6
	for id in station_labels.keys():
		var l: Label = station_labels[id]
		var base := UiTheme.COL_DIM
		if id == current_station:
			base = UiTheme.COL_CYAN
		if bool(attention.get(id, false)):
			l.text = ("* " if on else "  ") + _station_name(str(id))
			l.add_theme_color_override("font_color", UiTheme.COL_AMBER if id != current_station else UiTheme.COL_CYAN)
		else:
			l.text = _station_name(str(id))
			l.add_theme_color_override("font_color", base)
	if _subtitle_time > 0.0:
		_subtitle_time -= delta
		if _subtitle_time <= 0.0:
			subtitle_label.text = ""
	subtitle_label.visible = look_mode


func _station_name(id: String) -> String:
	for s in STATIONS:
		if s[0] == id:
			return str(s[1])
	return id


func set_look_mode(v: bool) -> void:
	look_mode = v
	cross_h.visible = v
	cross_v.visible = v
	prompt_label.visible = v
	hint_label.visible = v


func set_prompt(target: Node) -> void:
	if target == null:
		prompt_label.text = ""
		cross_h.color = Color(1, 1, 1, 0.7)
		cross_v.color = Color(1, 1, 1, 0.7)
		return
	prompt_label.text = "[CLICK]  " + str(target.get("label_text"))
	cross_h.color = UiTheme.COL_CYAN
	cross_v.color = UiTheme.COL_CYAN


func push_notification(text: String, kind: String) -> void:
	var l := UiTheme.label(text, 13, KIND_COLORS.get(kind, UiTheme.COL_CYAN))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	notif_box.add_child(l)
	while notif_box.get_child_count() > 6:
		var old := notif_box.get_child(0)
		notif_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _on_radio(speaker: String, text: String) -> void:
	subtitle_label.text = "%s: %s" % [speaker, text]
	subtitle_label.add_theme_color_override("font_color", UiTheme.COL_CYAN if speaker == "YOU" else UiTheme.COL_GREEN)
	_subtitle_time = clampf(2.0 + text.length() * 0.05, 3.0, 9.0)
