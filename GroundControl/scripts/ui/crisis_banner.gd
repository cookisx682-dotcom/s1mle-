extends PanelContainer
## Flashing crisis banner (top centre) with a countdown and 2–3 answers.
## Answer with keys 1/2/3 (handled in game.gd) or by clicking while the mouse is free.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var title_label: Label
var text_label: Label
var timer_bar: ProgressBar
var options_box: VBoxContainer
var _t := 0.0
var _closing := 0.0
var _box_a: StyleBoxFlat
var _box_b: StyleBoxFlat


func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -300
	offset_right = 300
	offset_top = 56
	custom_minimum_size = Vector2(600, 0)
	_box_a = UiTheme.glow_box(Color(0.16, 0.02, 0.03, 0.95), UiTheme.COL_RED, Color(UiTheme.COL_RED, 0.35), 8)
	_box_b = UiTheme.glow_box(Color(0.1, 0.01, 0.02, 0.95), UiTheme.COL_RED.darkened(0.5), Color(UiTheme.COL_RED, 0.1), 4)
	add_theme_stylebox_override("panel", _box_a)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	title_label = UiTheme.label("", 18, UiTheme.COL_RED)
	title_label.add_theme_font_override("font", UiTheme.mono_font_bold())
	v.add_child(title_label)
	text_label = UiTheme.label("", 14, UiTheme.COL_TEXT, true)
	v.add_child(text_label)
	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 8)
	timer_bar.max_value = 1.0
	timer_bar.add_theme_stylebox_override("fill", UiTheme.bar_style(UiTheme.COL_RED))
	v.add_child(timer_bar)
	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 4)
	v.add_child(options_box)


func show_crisis(c: Dictionary) -> void:
	_closing = 0.0
	title_label.text = "!! %s !!" % str(c.get("title", "ALERT")).to_upper()
	text_label.text = str(c.get("text", ""))
	for child in options_box.get_children():
		child.queue_free()
	var opts: Array = c.get("options", [])
	for i in opts.size():
		var txt := "[%d] %s" % [i + 1, str(opts[i].get("text", ""))]
		var b := UiTheme.wrap_button(txt, 30, 14)
		b.pressed.connect(_on_option.bind(i))
		options_box.add_child(b)
	visible = true


func hide_crisis(success: bool) -> void:
	for child in options_box.get_children():
		child.queue_free()
	title_label.text = "RESOLVED" if success else "FAILED"
	title_label.add_theme_color_override("font_color", UiTheme.COL_GREEN if success else UiTheme.COL_RED)
	text_label.text = ""
	_closing = 1.6


func _on_option(i: int) -> void:
	EventManager.resolve_crisis(i)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _closing > 0.0:
		_closing -= delta
		if _closing <= 0.0:
			visible = false
			title_label.add_theme_color_override("font_color", UiTheme.COL_RED)
		return
	add_theme_stylebox_override("panel", _box_a if fmod(_t * 3.0, 1.0) < 0.5 else _box_b)
	timer_bar.value = EventManager.crisis_time_left / maxf(0.01, EventManager.crisis_total)
