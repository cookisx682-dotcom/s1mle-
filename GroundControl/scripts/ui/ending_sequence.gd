extends Control
## Demo ending: the cliffhanger ("SIGNAL ACQUIRED — TO BE CONTINUED") and the short
## preview of the next decade. Texts come from days.json → "endings".

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var black: ColorRect
var big: Label
var small: Label
var caption: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	big = UiTheme.label("", 44, UiTheme.COL_CYAN)
	big.add_theme_font_override("font", UiTheme.mono_font_bold())
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_shadow_color", Color(UiTheme.COL_CYAN, 0.45))
	big.add_theme_constant_override("shadow_outline_size", 10)
	v.add_child(big)
	small = UiTheme.label("", 18, UiTheme.COL_VIOLET)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(small)
	caption = UiTheme.label("", 18, UiTheme.COL_GREEN, true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.anchor_left = 0.1
	caption.anchor_right = 0.9
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -160
	caption.offset_bottom = -60
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	add_child(caption)


## Big centred lines on black (cliffhanger).
func play_cliffhanger(lines: Array) -> void:
	visible = true
	black.modulate.a = 0.0
	big.text = ""
	small.text = ""
	caption.text = ""
	var fade := create_tween()
	fade.tween_property(black, "modulate:a", 1.0, 1.5)
	await fade.finished
	AudioManager.play_sfx("signal")
	for i in lines.size():
		var target := big if i == 0 else small
		await _type(target, str(lines[i]), 1.8)
	await get_tree().create_timer(2.0).timeout
	big.text = ""
	small.text = ""


## Year card, then the room of the next era fades in with captions.
func play_teaser(data: Dictionary) -> void:
	visible = true
	black.modulate.a = 1.0
	big.text = ""
	small.text = ""
	await _type(big, str(data.get("year", "")), 1.2)
	await _type(small, str(data.get("subtitle", "")), 1.5)
	big.text = ""
	small.text = ""
	var reveal := create_tween()
	reveal.tween_property(black, "modulate:a", 0.0, 2.0)
	await reveal.finished
	for line in data.get("captions", []):
		await _type(caption, str(line), 2.4)
	var fade_out := create_tween()
	fade_out.tween_property(black, "modulate:a", 1.0, 1.5)
	await fade_out.finished
	caption.text = ""
	await _type(big, str(data.get("title", "GROUND CONTROL")), 0.5)
	await _type(small, str(data.get("footer", "")), 3.0)


func _type(label: Label, text: String, hold: float) -> void:
	label.text = text
	label.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(label, "visible_ratio", 1.0, clampf(text.length() * 0.045, 0.3, 4.0))
	await tw.finished
	await get_tree().create_timer(hold).timeout
