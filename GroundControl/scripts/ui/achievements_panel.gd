extends Control
## Achievements screen: locked ones are grey, unlocked ones glow cyan.

signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var list: VBoxContainer
var header: Label
var _t := 0.0
var _glow_boxes: Array = []


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
	panel.custom_minimum_size = Vector2(620, 520)
	panel.add_theme_stylebox_override("panel", UiTheme.glow_box(UiTheme.COL_BG, UiTheme.COL_CYAN, Color(UiTheme.COL_CYAN, 0.2), 8))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	header = UiTheme.label("ACHIEVEMENTS", 22, UiTheme.COL_CYAN)
	header.add_theme_font_override("font", UiTheme.mono_font_bold())
	v.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 34)
	back.pressed.connect(_close)
	v.add_child(back)


func open() -> void:
	_refresh()
	visible = true


func _close() -> void:
	AudioManager.play_sfx("ui_click")
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	_glow_boxes = []
	var defs := AchievementManager.get_defs()
	header.text = "ACHIEVEMENTS  %d / %d" % [AchievementManager.unlocked_count(), defs.size()]
	for d in defs:
		var id := str(d.get("id", ""))
		var on := AchievementManager.is_unlocked(id)
		var row := PanelContainer.new()
		var box: StyleBoxFlat
		if on:
			box = UiTheme.glow_box(Color("0e2333"), UiTheme.COL_CYAN, Color(UiTheme.COL_CYAN, 0.4), 6)
			_glow_boxes.append(box)
		else:
			box = UiTheme.box(Color("0b0f18"), Color("2a3140"), 2, 8)
		row.add_theme_stylebox_override("panel", box)
		list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var icon := PanelContainer.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.COL_CYAN if on else Color("1f2533"), UiTheme.COL_CYAN if on else Color("2a3140"), 0, 0))
		var glyph := UiTheme.label(str(d.get("icon", "**")) if on else "??", 16, UiTheme.COL_BG if on else Color("4a5263"))
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_child(glyph)
		h.add_child(icon)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UiTheme.label(str(d.get("title", id)), 15, UiTheme.COL_CYAN if on else Color("6b7385")))
		tv.add_child(UiTheme.label(str(d.get("description", "")), 12, UiTheme.COL_TEXT if on else Color("4f5768"), true))


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var a := 0.25 + 0.2 * sin(_t * 3.0)
	for b in _glow_boxes:
		(b as StyleBoxFlat).shadow_color = Color(UiTheme.COL_CYAN, a)
