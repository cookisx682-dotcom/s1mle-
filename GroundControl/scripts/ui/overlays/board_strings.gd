extends Control
## Draws the red strings on top of the cards (mouse-transparent layer).

const CARD_W := 84.0

var pending_from := ""      # card selected as the first end of a new string
var mouse_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pin(id: String) -> Vector2:
	return BoardManager.get_pin_pos(id) + Vector2(CARD_W * 0.5, 4)


func _draw() -> void:
	for l in BoardManager.links:
		var ded := str(l[2])
		for end_id in [str(l[0]), str(l[1])]:
			if BoardManager.pinned.has(end_id) and BoardManager.pinned.has(ded):
				_draw_string(_pin(end_id), _pin(ded), Color("d42a2a"))
	if pending_from != "" and BoardManager.pinned.has(pending_from):
		_draw_string(_pin(pending_from), mouse_pos, Color(0.9, 0.2, 0.2, 0.6))
	for id in BoardManager.pinned.keys():
		var p := _pin(str(id))
		draw_circle(p, 3.0, Color("c0392b"))


## Slightly sagging string drawn as a short polyline.
func _draw_string(a: Vector2, b: Vector2, c: Color) -> void:
	var pts := PackedVector2Array()
	var sag := minf(14.0, a.distance_to(b) * 0.08)
	for i in 9:
		var f := i / 8.0
		var p := a.lerp(b, f)
		p.y += sin(f * PI) * sag
		pts.append(p)
	draw_polyline(pts, Color(0, 0, 0, 0.3), 3.0)
	draw_polyline(pts, c, 1.5)
