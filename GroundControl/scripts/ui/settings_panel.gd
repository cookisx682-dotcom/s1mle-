extends Control
## Settings screen (used by the main menu and the pause menu).
## Every change is saved to user://settings.json immediately.

signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.glow_box(UiTheme.COL_BG, UiTheme.COL_CYAN, Color(UiTheme.COL_CYAN, 0.2), 8))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := UiTheme.label("SETTINGS", 22, UiTheme.COL_CYAN)
	title.add_theme_font_override("font", UiTheme.mono_font_bold())
	v.add_child(title)
	_slider(v, "MASTER VOLUME", "master_volume", 0.0, 1.0, 0.05)
	_slider(v, "MUSIC VOLUME", "music_volume", 0.0, 1.0, 0.05)
	_slider(v, "SFX VOLUME", "sfx_volume", 0.0, 1.0, 0.05)
	_slider(v, "MOUSE SENSITIVITY", "mouse_sensitivity", 0.2, 3.0, 0.1)
	_check(v, "CRT SHADER (monitors)", "crt_enabled")
	_check(v, "PIXEL EFFECT (480x270 + dithering)", "pixel_enabled")
	_check(v, "FILM NOISE", "noise_enabled")
	_check(v, "FULLSCREEN", "fullscreen")
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 34)
	back.pressed.connect(_close)
	v.add_child(back)


func open() -> void:
	visible = true


func _close() -> void:
	AudioManager.play_sfx("ui_click")
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _slider(parent: Control, title: String, key: String, min_v: float, max_v: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := UiTheme.label(title, 13)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = float(SaveSystem.get_setting(key, 1.0))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := UiTheme.label("%.2f" % s.value, 12, UiTheme.COL_CYAN)
	val.custom_minimum_size = Vector2(44, 0)
	row.add_child(val)
	s.value_changed.connect(func(x: float):
		val.text = "%.2f" % x
		SaveSystem.set_setting(key, x)
	)


func _check(parent: Control, title: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = bool(SaveSystem.get_setting(key, false))
	c.toggled.connect(func(on: bool):
		AudioManager.play_sfx("switch")
		SaveSystem.set_setting(key, on)
	)
	parent.add_child(c)
