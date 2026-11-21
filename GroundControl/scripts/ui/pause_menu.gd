extends Control
## Pause menu (ESC). Runs while the tree is paused.

signal resumed
signal quit_to_menu

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const AchievementsPanel = preload("res://scripts/ui/achievements_panel.gd")

var settings_panel: Control
var achievements_panel: Control
var box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := UiTheme.label("— PAUSED —", 26, UiTheme.COL_CYAN)
	title.add_theme_font_override("font", UiTheme.mono_font_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_button("RESUME", _resume)
	_button("SETTINGS", func(): settings_panel.call("open"))
	_button("ACHIEVEMENTS", func(): achievements_panel.call("open"))
	_button("QUIT TO MENU", func(): quit_to_menu.emit())
	var note := UiTheme.label("Progress is saved at the start of every shift.", 11, UiTheme.COL_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	achievements_panel = AchievementsPanel.new()
	add_child(achievements_panel)


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		cb.call()
	)
	box.add_child(b)


func open() -> void:
	visible = true


func _resume() -> void:
	visible = false
	resumed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if settings_panel.visible or achievements_panel.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()
