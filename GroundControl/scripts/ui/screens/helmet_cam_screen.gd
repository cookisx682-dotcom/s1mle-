extends "res://scripts/ui/screens/screen_base.gd"
## "Helmet camera" feed: a tiny procedural pixel view of the lunar surface.
## Static when the camera is off, unpowered or during a signal dropout.
## After the probe is found (flag "probe_seen") its silhouette is in view.

var _stars: Array = []
var _rocks: Array = []


func _ready() -> void:
	super._ready()
	var r := RandomNumberGenerator.new()
	r.seed = 1971
	for i in 40:
		_stars.append(Vector2(r.randf(), r.randf() * 0.5))
	for i in 9:
		_rocks.append(Vector3(r.randf() * 3.0, 0.6 + r.randf() * 0.4, 0.4 + r.randf()))


func _draw() -> void:
	var s := size
	var fs := font_px()
	var g := UiTheme.COL_GREEN
	var cam_ok := ResourceManager.is_on("cam") and ResourceManager.power > 0.0
	var dropout := str(EventManager.active_crisis.get("id", "")) == "c_signal_drop"
	if not cam_ok or dropout:
		_draw_static(s)
		var msg := "SIGNAL LOST" if dropout else "NO VIDEO — CAM OFF"
		draw_rect(Rect2(0, s.y * 0.5 - fs, s.x, fs * 1.8), Color(0, 0, 0, 0.8))
		text(Vector2(s.x * 0.5 - msg.length() * fs * 0.3, s.y * 0.5 + fs * 0.4), msg, g, fs)
		return

	var m := MissionGenerator.active
	var walking := not m.is_empty() and str(m.get("state", "")) == "travel"
	var pan := t * (0.05 if not walking else 0.25)
	var bob := sin(t * (9.0 if walking else 1.2)) * (2.0 if walking else 0.6)
	var horizon := s.y * 0.52 + bob

	# sky + stars + Earth
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.02, 0.01))
	for st_v in _stars:
		var st: Vector2 = st_v
		var p := Vector2(fposmod(st.x - pan * 0.1, 1.0) * s.x, st.y * s.y + bob * 0.3)
		draw_rect(Rect2(p, Vector2(1, 1)), g.darkened(0.3))
	var earth := Vector2(fposmod(0.7 - pan * 0.1, 1.0) * s.x, s.y * 0.18)
	draw_circle(earth, maxf(3.0, s.y * 0.05), g.darkened(0.2))
	draw_circle(earth + Vector2(2, 0), maxf(3.0, s.y * 0.05), Color(0.0, 0.02, 0.01))

	# ground with dither stripes
	var ground := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var x := s.x * i / float(steps)
		ground.append(Vector2(x, horizon + sin(i * 1.7 + pan * 8.0) * 3.0))
	ground.append(Vector2(s.x, s.y))
	ground.append(Vector2(0, s.y))
	draw_colored_polygon(ground, g.darkened(0.72))
	var yy := horizon + 6.0
	while yy < s.y:
		draw_line(Vector2(0, yy), Vector2(s.x, yy), g.darkened(0.8), 1.0)
		yy += 2.0 + (yy - horizon) * 0.15

	# rocks
	for rk_v in _rocks:
		var rk: Vector3 = rk_v
		var rx := fposmod(rk.x - pan, 3.0) / 3.0 * s.x * 1.4 - s.x * 0.2
		var ry := horizon + (s.y - horizon) * (rk.y - 0.55)
		var rs := rk.z * s.y * 0.05 * (0.5 + (ry - horizon) / s.y)
		draw_rect(Rect2(rx, ry - rs, rs * 2.0, rs), g.darkened(0.45))

	# the probe
	if GameState.get_flag("probe_seen"):
		var px := s.x * 0.55
		var py := horizon + s.y * 0.18
		var w := s.y * 0.16
		draw_rect(Rect2(px - w * 0.5, py - w * 0.5, w, w * 0.5), g.darkened(0.1))
		draw_line(Vector2(px, py - w * 0.5), Vector2(px - w * 0.4, py - w * 1.2), g, 1.0)
		draw_line(Vector2(px + w * 0.3, py - w * 0.5), Vector2(px + w * 0.6, py - w), g, 1.0)
		if blink(0.6):
			draw_rect(Rect2(px - 1, py - w * 0.35, 2, 2), Color.WHITE)

	# overlay HUD
	text(Vector2(3, fs), "CAM-1", g, maxi(8, fs - 2))
	if blink(1.0):
		draw_circle(Vector2(s.x - fs * 2.4, fs * 0.6), 2.5, UiTheme.COL_RED)
	text(Vector2(s.x - fs * 2.0, fs), "REC", g, maxi(8, fs - 2))
	text(Vector2(3, s.y - 3), "HDG %03d" % int(fposmod(90.0 + pan * 40.0, 360.0)), g, maxi(8, fs - 2))
	# scanline roll
	var roll := fposmod(t * 20.0, s.y)
	draw_rect(Rect2(0, roll, s.x, 2), Color(g, 0.08))


func _draw_static(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.02))
	var block := maxf(2.0, s.y / 30.0)
	var y := 0.0
	while y < s.y:
		var x := 0.0
		while x < s.x:
			var v := randf()
			if v > 0.45:
				draw_rect(Rect2(x, y, block, block), Color(v * 0.5, v * 0.6, v * 0.5))
			x += block
		y += block
