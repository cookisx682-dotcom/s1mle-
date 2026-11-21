extends "res://scripts/ui/screens/screen_base.gd"
## The big amber plot board above the console: Earth–Moon trajectory and mission status.
## When the signal has been found it shows a pulse ring every few seconds.


func _draw() -> void:
	var s := size
	var a := UiTheme.COL_AMBER
	var fs := font_px()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.03, 0.0))
	var moon := Vector2(s.x * 0.72, s.y * 0.55)
	var earth := Vector2(s.x * 0.16, s.y * 0.55)
	draw_circle(earth, s.y * 0.14, a.darkened(0.5))
	draw_arc(moon, s.y * 0.1, 0.0, TAU, 16, a, 1.0)
	# dashed transfer orbit
	var pts := 28
	for i in pts:
		if i % 2 == 0:
			continue
		var f0 := float(i) / pts
		var f1 := float(i + 1) / pts
		draw_line(_orbit(earth, moon, f0), _orbit(earth, moon, f1), a.darkened(0.4), 1.0)
	draw_arc(moon, s.y * 0.2, 0.0, TAU, 20, a.darkened(0.6), 1.0)
	# Selene-1 position marker
	if blink(1.2):
		var p := moon + Vector2(s.y * 0.06, -s.y * 0.05)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
	if GameState.get_flag("found_signal"):
		var r := fposmod(t * 0.35, 1.0)
		draw_arc(moon, s.y * (0.1 + r * 0.4), 0.0, TAU, 24, Color(UiTheme.COL_VIOLET, 1.0 - r), 1.0)
	text(Vector2(4, fs), "SELENE-1 · LUNAR SURFACE OPS", a, fs)
	var status := "LOOP ACTIVE" if GameState.in_game else "STANDBY"
	text(Vector2(4, s.y - 4), "%s · RAPPORT %d" % [status, GameState.trust], a.darkened(0.2), maxi(8, fs - 2))


func _orbit(e: Vector2, m: Vector2, f: float) -> Vector2:
	var p := e.lerp(m, f)
	p.y -= sin(f * PI) * size.y * 0.28
	return p
