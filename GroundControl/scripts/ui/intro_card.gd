extends Control
## Black title card before each shift: date, shift title and a few typed lines.
## Click / SPACE skips the typing, then continues.

signal finished

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var date_label: Label
var title_label: Label
var body_label: Label
var hint_label: Label
var _tw: Tween
var _ready_to_close := false
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	visible = false
	var bg := ColorRect.new()
	bg.color = Color("03060c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	date_label = UiTheme.label("", 30, UiTheme.COL_CYAN)
	date_label.add_theme_font_override("font", UiTheme.mono_font_bold())
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(date_label)
	title_label = UiTheme.label("", 18, UiTheme.COL_VIOLET)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)
	body_label = UiTheme.label("", 16, UiTheme.COL_TEXT, true)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body_label)
	hint_label = UiTheme.label("[ CLICK TO BEGIN SHIFT ]", 13, UiTheme.COL_DIM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint_label)


## lines[0] = date, lines[1] = title, rest = body paragraphs.
func play(lines: Array) -> void:
	visible = true
	modulate.a = 1.0
	_ready_to_close = false
	date_label.text = str(lines[0]) if lines.size() > 0 else ""
	title_label.text = str(lines[1]) if lines.size() > 1 else ""
	var body: Array = lines.slice(2)
	body_label.text = "\n\n".join(PackedStringArray(body))
	body_label.visible_ratio = 0.0
	hint_label.visible = false
	AudioManager.play_sfx("radio_static")
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_interval(0.6)
	_tw.tween_property(body_label, "visible_ratio", 1.0, clampf(body_label.text.length() * 0.03, 0.5, 7.0))
	_tw.tween_callback(_on_typed)


func _on_typed() -> void:
	_ready_to_close = true
	hint_label.visible = true


func _process(delta: float) -> void:
	_t += delta
	if hint_label.visible:
		hint_label.modulate.a = 0.5 + 0.5 * sin(_t * 4.0)


func _advance() -> void:
	if not _ready_to_close:
		if _tw and _tw.is_valid():
			_tw.kill()
		body_label.visible_ratio = 1.0
		_on_typed()
		return
	AudioManager.play_sfx("ui_click")
	_ready_to_close = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func():
		visible = false
		finished.emit()
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("advance"):
		get_viewport().set_input_as_handled()
		_advance()
