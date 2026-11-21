extends Control
## One card on the evidence board (drawn by hand: paper, coloured strip, pin, title, text).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const CARD_SIZE := Vector2(84, 54)
const TYPE_COLORS := {
	"report": Color("3fe0ff"), "measurement": Color("5cffb0"), "photo": Color("9b7bff"),
	"fax": Color("ffb547"), "sample": Color("d08a4a"), "deduction": Color("ff5a5f"),
}

var card_id := ""
var data: Dictionary = {}
var selected := false
var flash := 0.0
var flash_color := Color.WHITE
var tilt := 0.0


func setup(id: String) -> void:
	card_id = id
	data = BoardManager.get_card(id)
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""
	tilt = (float(hash(id) % 7) - 3.0) * 0.6


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 1.5)
		queue_redraw()


func _draw() -> void:
	var f := UiTheme.mono_font()
	var t := str(data.get("type", "report"))
	var strip: Color = TYPE_COLORS.get(t, Color.WHITE)
	var paper := Color("efe9d8") if t != "deduction" else Color("ffe3e3")
	# shadow + paper
	draw_rect(Rect2(Vector2(2, 3), size), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	draw_rect(Rect2(0, 0, size.x, 5), strip)
	if t == "photo":
		var r := Rect2(4, 9, 26, 20)
		draw_rect(r, Color("2b2b2b"))
		draw_rect(Rect2(4, 21, 26, 8), Color("8a8a8a"))
		draw_rect(Rect2(16, 15, 6, 6), Color("cfcfcf"))
	var x0 := 34.0 if t == "photo" else 4.0
	draw_string(f, Vector2(x0, 16), t.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 3, 8, strip.darkened(0.45))
	draw_multiline_string(f, Vector2(x0, 27), str(data.get("title", card_id)), HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 3, 9, 3, Color("1d1a14"))
	# pin
	draw_circle(Vector2(size.x * 0.5, 4), 3.0, Color("c0392b"))
	draw_circle(Vector2(size.x * 0.5 - 1, 3), 1.0, Color("ff9a8a"))
	if selected:
		draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), UiTheme.COL_CYAN, false, 2.0)
	if flash > 0.0:
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(flash_color, flash), false, 3.0)


func do_flash(c: Color) -> void:
	flash_color = c
	flash = 1.0
	queue_redraw()
