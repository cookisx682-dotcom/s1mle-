extends RefCounted
## Shared palette, monospace font and Theme for every UI element (pixel / 70s terminal style).

const COL_BG := Color("0b1428")
const COL_BG_DEEP := Color("060c18")
const COL_CYAN := Color("3fe0ff")
const COL_VIOLET := Color("9b7bff")
const COL_GREEN := Color("5cffb0")
const COL_AMBER := Color("ffb547")
const COL_RED := Color("ff5a5f")
const COL_TEXT := Color("cfe9ff")
const COL_DIM := Color("5a6b85")
const COL_PAPER := Color("e8e2cf")
const COL_INK := Color("1d1a14")

static var _font: Font = null
static var _font_bold: Font = null
static var _theme: Theme = null


## Crisp monospace system font (falls back to Godot's default font if none is installed).
static func mono_font() -> Font:
	if _font == null:
		_font = _make_font(400)
	return _font


static func mono_font_bold() -> Font:
	if _font_bold == null:
		_font_bold = _make_font(700)
	return _font_bold


static func _make_font(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Liberation Mono", "Cascadia Mono", "Courier New", "monospace"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NORMAL
	return f


## Flat pixel-style box (no rounded corners, no anti-aliasing).
static func box(bg: Color, border: Color, width: int = 2, pad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s


## Box with a soft coloured shadow, used as a "glow".
static func glow_box(bg: Color, border: Color, glow: Color, glow_size: int = 6) -> StyleBoxFlat:
	var s := box(bg, border, 2, 8)
	s.shadow_color = glow
	s.shadow_size = glow_size
	return s


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = mono_font()
	t.default_font_size = 13

	t.set_stylebox("normal", "Button", box(COL_BG, COL_CYAN.darkened(0.45)))
	t.set_stylebox("hover", "Button", box(Color("12354a"), COL_CYAN))
	t.set_stylebox("pressed", "Button", box(Color("1d5a70"), COL_CYAN))
	t.set_stylebox("hover_pressed", "Button", box(Color("1d5a70"), COL_CYAN))
	t.set_stylebox("disabled", "Button", box(COL_BG_DEEP, Color("2a3550")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_CYAN)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", COL_CYAN)
	t.set_color("font_disabled_color", "Button", COL_DIM)

	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("default_color", "RichTextLabel", COL_TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("panel", "PanelContainer", box(Color(0.03, 0.06, 0.12, 0.94), COL_CYAN.darkened(0.3), 2, 10))
	t.set_stylebox("panel", "Panel", box(Color(0.03, 0.06, 0.12, 0.94), COL_CYAN.darkened(0.3), 2, 10))

	t.set_stylebox("background", "ProgressBar", box(COL_BG_DEEP, COL_DIM, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(COL_CYAN, COL_CYAN, 0, 0))
	t.set_color("font_color", "ProgressBar", COL_TEXT)

	t.set_stylebox("slider", "HSlider", box(COL_BG_DEEP, COL_DIM, 1, 3))
	t.set_stylebox("grabber_area", "HSlider", box(COL_CYAN.darkened(0.3), COL_CYAN.darkened(0.3), 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(COL_CYAN, COL_CYAN, 0, 3))

	t.set_color("font_color", "CheckButton", COL_TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", COL_CYAN)
	t.set_color("font_hover_pressed_color", "CheckButton", COL_CYAN)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())

	t.set_stylebox("panel", "PopupPanel", box(COL_BG, COL_CYAN, 2, 10))
	t.set_stylebox("panel", "AcceptDialog", box(COL_BG, COL_CYAN, 2, 10))
	return t


## Label factory with size/colour overrides.
static func label(text: String, font_size: int = 13, color: Color = COL_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Button whose text wraps onto several lines (used for dialogue choices etc).
static func wrap_button(text: String, min_height: int = 26, font_size: int = 12) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, min_height)
	b.clip_text = true
	var l := label(text, font_size, COL_CYAN, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 8
	l.offset_right = -6
	l.offset_top = 2
	l.offset_bottom = -2
	b.add_child(l)
	b.set_meta("label", l)
	return b


## Changes the text of a button made by wrap_button().
static func set_wrap_button_text(b: Button, text: String) -> void:
	if b.has_meta("label"):
		var l: Label = b.get_meta("label")
		l.text = text


static func bar_style(color: Color) -> StyleBoxFlat:
	return box(color, color, 0, 0)
