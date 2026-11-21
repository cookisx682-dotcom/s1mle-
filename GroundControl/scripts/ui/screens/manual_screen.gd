extends "res://scripts/ui/screens/screen_base.gd"
## Technical manual page. Shows the steps of the active repair in the correct order —
## the player has to dictate them at the console.


func _draw() -> void:
	var s := size
	var g := UiTheme.COL_GREEN
	var fs := font_px()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.04, 0.03))
	var m := MissionGenerator.active
	var y := fs + 2.0
	if m.is_empty() or str(m.get("type", "")) != "repair":
		text(Vector2(4, y), "TECHNICAL MANUALS · INDEX", g, fs)
		y += fs + 6.0
		for tpl in MissionGenerator.templates.values():
			if str(tpl.get("type", "")) == "repair" and y < s.y - 4.0:
				text(Vector2(8, y), "> " + str(tpl.get("manual", "")), g.darkened(0.4), maxi(8, fs - 2))
				y += fs + 2.0
		text(Vector2(4, s.y - 4), "NO ACTIVE PROCEDURE", g.darkened(0.5), maxi(8, fs - 2))
		return
	text(Vector2(4, y), str(m.get("manual", "")), g, fs)
	y += fs + 8.0
	var steps: Array = m.get("steps", [])
	var progress := int(m.get("progress", 0))
	for i in steps.size():
		var col := g
		var prefix := "%d. " % (i + 1)
		if i < progress:
			col = g.darkened(0.55)
			prefix = "OK "
		elif i == progress and blink(1.5):
			col = Color.WHITE
		draw_string(UiTheme.mono_font(), Vector2(6, y), prefix + str(steps[i]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 10.0, maxi(8, fs - 1), col)
		y += fs + 3.0
	text(Vector2(4, s.y - 4), "DICTATE AT CONSOLE · ERRORS %d/%d" % [int(m.get("mistakes", 0)), int(m.get("max_mistakes", 3))], UiTheme.COL_AMBER, maxi(8, fs - 2))
