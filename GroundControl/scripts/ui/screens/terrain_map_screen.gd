extends "res://scripts/ui/screens/screen_base.gd"
## Amber terrain map grid. Shows landmarks, Mia, the lander and — when the helmet camera is
## on — a 3x3 "triangulation" hint around the target. In interactive mode clicking a cell
## sends Mia there (MissionGenerator.submit_navigation).

var hover_cell := Vector2i(-1, -1)
var _origin := Vector2.ZERO
var _cell := 10.0


func _layout() -> void:
	var fs := font_px()
	var top := fs + 6.0
	var area := Rect2(4.0, top, size.x - 8.0, size.y - top - 4.0)
	var ms := MissionGenerator.map_size
	_cell = floorf(minf(area.size.x / ms.x, area.size.y / ms.y))
	var grid_size := Vector2(_cell * ms.x, _cell * ms.y)
	_origin = (area.position + (area.size - grid_size) * 0.5).floor()


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))


func _cell_center(c: Vector2) -> Vector2:
	return _origin + (c + Vector2(0.5, 0.5)) * _cell


func _draw() -> void:
	_layout()
	var a := UiTheme.COL_AMBER
	var fs := font_px()
	var ms := MissionGenerator.map_size
	var m := MissionGenerator.active
	var is_nav := not m.is_empty() and str(m.get("type", "")) == "navigation"
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.035, 0.0))
	var title := "TERRAIN · MARE SERENITATIS"
	if is_nav:
		title = "TRAVERSE · %s" % str(m.get("title", "")).to_upper()
	text(Vector2(4, fs + 1), title, a, fs)

	# grid
	for x in ms.x + 1:
		var px := _origin.x + x * _cell
		draw_line(Vector2(px, _origin.y), Vector2(px, _origin.y + ms.y * _cell), a.darkened(0.78), 1.0)
	for y in ms.y + 1:
		var py := _origin.y + y * _cell
		draw_line(Vector2(_origin.x, py), Vector2(_origin.x + ms.x * _cell, py), a.darkened(0.78), 1.0)
	if interactive and _cell >= 16.0:
		var small := maxi(8, fs - 3)
		for x in ms.x:
			text(_origin + Vector2(x * _cell + 2, small), char(65 + x), a.darkened(0.6), small)
		for y in range(1, ms.y):
			text(_origin + Vector2(2, y * _cell + small), str(y + 1), a.darkened(0.6), small)

	# camera hint (only when the helmet camera feed is on)
	if interactive and is_nav and str(m.get("state", "")) == "active":
		if ResourceManager.is_on("cam") and ResourceManager.power > 0.0:
			var hc: Vector2i = m["hint_center"]
			var r := Rect2(_origin + Vector2(hc - Vector2i(1, 1)) * _cell, Vector2(_cell * 3, _cell * 3))
			draw_rect(r, Color(UiTheme.COL_GREEN, 0.12 if blink(1.0) else 0.07))
			draw_rect(r, Color(UiTheme.COL_GREEN, 0.6), false, 1.0)
			if on_screen:
				MissionGenerator.mark_cam_used()
		# wrong guesses
		for wc in m.get("wrong_cells", []):
			var rr := _cell_rect(wc).grow(-_cell * 0.25)
			draw_line(rr.position, rr.end, UiTheme.COL_RED, 2.0)
			draw_line(Vector2(rr.end.x, rr.position.y), Vector2(rr.position.x, rr.end.y), UiTheme.COL_RED, 2.0)

	# lander / habitat
	var hr := _cell_rect(MissionGenerator.home).grow(-_cell * 0.2)
	draw_rect(hr, a, false, 1.0)
	draw_line(hr.position + Vector2(0, hr.size.y), hr.position + Vector2(hr.size.x * 0.5, 0), a, 1.0)
	draw_line(hr.position + Vector2(hr.size.x * 0.5, 0), hr.end, a, 1.0)

	# landmarks
	for l in MissionGenerator.map_landmarks:
		var c: Vector2i = l["cell"]
		_draw_landmark(str(l["kind"]), _cell_center(Vector2(c)), a)
		if interactive and _cell >= 14.0:
			text(_cell_center(Vector2(c)) + Vector2(-_cell * 0.5, _cell * 0.5 + fs - 2), str(l["name"]), a.lightened(0.2), maxi(8, fs - 3))

	# Mia
	var mia_pos := _cell_center(Vector2(MissionGenerator.mia_cell))
	if is_nav and str(m.get("state", "")) == "travel":
		var from: Vector2i = m["from"]
		var to: Vector2i = m["target"]
		var corner := Vector2(to.x, from.y)
		draw_line(_cell_center(Vector2(from)), _cell_center(corner), Color(UiTheme.COL_GREEN, 0.5), 1.0)
		draw_line(_cell_center(corner), _cell_center(Vector2(to)), Color(UiTheme.COL_GREEN, 0.5), 1.0)
		mia_pos = _cell_center(_path_point(Vector2(from), corner, Vector2(to), float(m["travel_t"])))
	var ms_size := maxf(3.0, _cell * 0.3)
	if blink(2.5) or (is_nav and str(m.get("state", "")) == "travel"):
		draw_line(mia_pos - Vector2(ms_size, 0), mia_pos + Vector2(ms_size, 0), UiTheme.COL_GREEN, 2.0)
		draw_line(mia_pos - Vector2(0, ms_size), mia_pos + Vector2(0, ms_size), UiTheme.COL_GREEN, 2.0)

	# hover
	if interactive and hover_cell.x >= 0 and is_nav:
		draw_rect(_cell_rect(hover_cell), Color(1, 1, 1, 0.6), false, 1.0)
		text(Vector2(size.x - fs * 4.0, fs + 1), MissionGenerator.cell_name(hover_cell), Color.WHITE, fs)


func _path_point(from: Vector2, corner: Vector2, to: Vector2, f: float) -> Vector2:
	var l1 := from.distance_to(corner)
	var l2 := corner.distance_to(to)
	var total := maxf(0.001, l1 + l2)
	var d := clampf(f, 0.0, 1.0) * total
	if d <= l1:
		return from.lerp(corner, d / maxf(0.001, l1))
	return corner.lerp(to, (d - l1) / maxf(0.001, l2))


func _draw_landmark(kind: String, p: Vector2, col: Color) -> void:
	var r := _cell * 0.32
	match kind:
		"crater":
			draw_arc(p, r, 0.0, TAU, 12, col, 1.0)
			draw_arc(p + Vector2(1, 1), r * 0.5, 0.0, TAU, 8, col.darkened(0.4), 1.0)
		"peak":
			draw_polyline(PackedVector2Array([p + Vector2(-r, r * 0.7), p + Vector2(0, -r), p + Vector2(r, r * 0.7)]), col, 1.0)
		"boulders":
			for o in [Vector2(-r * 0.5, 0), Vector2(r * 0.4, -r * 0.4), Vector2(r * 0.3, r * 0.5)]:
				draw_rect(Rect2(p + o - Vector2(1.5, 1.5), Vector2(3, 3)), col)
		"rille":
			draw_polyline(PackedVector2Array([p + Vector2(-r, -r * 0.4), p + Vector2(-r * 0.3, r * 0.4), p + Vector2(r * 0.3, -r * 0.4), p + Vector2(r, r * 0.4)]), col, 1.0)
		"site":
			draw_rect(Rect2(p - Vector2(r, r) * 0.6, Vector2(r, r) * 1.2), col, false, 1.0)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), col)
		_:
			draw_line(p - Vector2(r, 0), p + Vector2(r, 0), col, 1.0)
			draw_line(p - Vector2(0, r), p + Vector2(0, r), col, 1.0)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		hover_cell = _cell_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var c := _cell_at(mb.position)
			if c.x >= 0:
				AudioManager.play_sfx("ui_click")
				MissionGenerator.submit_navigation(c)
				accept_event()


func _cell_at(pos: Vector2) -> Vector2i:
	_layout()
	var rel := (pos - _origin) / _cell
	var c := Vector2i(floori(rel.x), floori(rel.y))
	var ms := MissionGenerator.map_size
	if c.x < 0 or c.y < 0 or c.x >= ms.x or c.y >= ms.y:
		return Vector2i(-1, -1)
	return c
