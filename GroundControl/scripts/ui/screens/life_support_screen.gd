extends "res://scripts/ui/screens/screen_base.gd"
## Green life-support readout: oxygen, power, temperature and system states.


func _draw() -> void:
	var s := size
	var g := UiTheme.COL_GREEN
	var fs := font_px()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.05, 0.03))
	text(Vector2(4, fs + 2), "LIFE SUPPORT · SELENE-1", g, fs)
	var rows := [
		["O2 ", ResourceManager.oxygen, 100.0, "%"],
		["PWR", ResourceManager.power, 100.0, "%"],
		["TMP", ResourceManager.temperature, 30.0, "C"],
	]
	var y := fs * 2.0 + 8.0
	var bar_x := fs * 3.0
	var bar_w := s.x - bar_x - fs * 4.0
	var row_h := fs + 6.0
	for r in rows:
		var v := float(r[1])
		var frac := clampf(v / float(r[2]), 0.0, 1.0)
		var col := g
		if frac < 0.15:
			col = UiTheme.COL_RED if blink(3.0) else UiTheme.COL_RED.darkened(0.5)
		elif frac < 0.3:
			col = UiTheme.COL_AMBER
		text(Vector2(4, y + fs - 2), str(r[0]), g, fs)
		draw_rect(Rect2(bar_x, y, bar_w, fs - 1), g.darkened(0.8))
		# segmented bar: retro LED style
		var segs := 16
		var seg_w := bar_w / segs
		for i in int(frac * segs + 0.5):
			draw_rect(Rect2(bar_x + i * seg_w + 1, y + 1, seg_w - 2, fs - 3), col)
		text(Vector2(bar_x + bar_w + 4, y + fs - 2), "%d%s" % [int(v), str(r[3])], col, fs)
		y += row_h
	y += 2.0
	var sys := ""
	for k in ["heat", "lights", "rover", "cam"]:
		sys += ("+" if ResourceManager.is_on(k) else "-") + str(k).to_upper().left(4) + " "
	text(Vector2(4, y + fs), sys, g.darkened(0.2), maxi(8, fs - 2))
	y += fs + 4.0
	if interactive:
		text(Vector2(4, y + fs), "BUS LOAD %.3f %%/s · O2 WASTED %.1f%%" % [ResourceManager.power_draw(), ResourceManager.oxygen_wasted], g.darkened(0.3), maxi(8, fs - 2))
