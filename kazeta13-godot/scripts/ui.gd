extends Node
## HUD, panels, overlays, menus flow (how-to, name, story), death and endings.

var M
var G
var A
var hud: Control
var top: Control
var L := {}
var sub_q: Array = []
var sub_t := 0.0
var msg_t := 0.0
var toast_t := 0.0
var face_t := 0.0
var panel: Control = null
var panel_close_cb = null
var hud_hp := 100.0
var hud_batt := 90.0
var hud_flash := 0.0
var batt_on := true
var story_i := 0
var story_full := ""
var story_cb = null


# =====================================================================
# styles & helpers
# =====================================================================
func ls(font: Font, size: int, col := Color(0.92, 0.9, 0.86), shadow := true) -> LabelSettings:
	var l := LabelSettings.new()
	l.font = font
	l.font_size = size
	l.font_color = col
	if shadow:
		l.shadow_color = Color(0, 0, 0, 0.8)
		l.shadow_size = 6
	return l


func lab(parent: Control, text: String, s: LabelSettings, anchor: Vector4, align := HORIZONTAL_ALIGNMENT_CENTER, valign := VERTICAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = s
	l.horizontal_alignment = align
	l.vertical_alignment = valign
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.anchor_left = anchor.x
	l.anchor_top = anchor.y
	l.anchor_right = anchor.z
	l.anchor_bottom = anchor.w
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func full(parent: Node, col := Color(0, 0, 0, 0)) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE if col.a == 0 else Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	return c


func sbox(bg: Color, border := Color(0.3, 0.28, 0.26), r := 8, bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func btn(parent: Control, text: String, cb: Callable, size := 24, minw := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", M.f_title_ui)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	b.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.32))
	b.add_theme_stylebox_override("normal", sbox(Color(0.11, 0.105, 0.1)))
	b.add_theme_stylebox_override("hover", sbox(Color(0.14, 0.12, 0.11), Color(1, 0.3, 0.23)))
	b.add_theme_stylebox_override("pressed", sbox(Color(0.2, 0.08, 0.07), Color(1, 0.3, 0.23)))
	b.add_theme_stylebox_override("focus", sbox(Color(0.11, 0.105, 0.1), Color(0.6, 0.3, 0.25)))
	b.add_theme_stylebox_override("disabled", sbox(Color(0.07, 0.07, 0.07), Color(0.2, 0.2, 0.2)))
	b.custom_minimum_size = Vector2(minw, 0)
	b.pressed.connect(func():
		A.play("click", -10)
		cb.call())
	parent.add_child(b)
	return b


func text_label(parent: Control, text: String, font: Font, size: int, col := Color(0.88, 0.85, 0.8), align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = ls(font, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	parent.add_child(l)
	return l


# =====================================================================
# build
# =====================================================================
func build() -> void:
	var hl := CanvasLayer.new()
	hl.layer = 2
	M.add_child(hl)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.add_child(hud)
	hud.visible = false
	L.day = lab(hud, "DEŇ 1", ls(M.f_osd, 34), Vector4(0.015, 0.02, 0.4, 0.08), HORIZONTAL_ALIGNMENT_LEFT)
	L.clock = lab(hud, "23:00", ls(M.f_osd, 22, Color(0.7, 0.68, 0.64)), Vector4(0.015, 0.075, 0.4, 0.11), HORIZONTAL_ALIGNMENT_LEFT)
	L.safe = lab(hud, "", ls(M.f_ui, 13, Color(1.0, 0.84, 0.47)), Vector4(0.015, 0.11, 0.4, 0.15), HORIZONTAL_ALIGNMENT_LEFT)
	L.obj = lab(hud, "", ls(M.f_ui, 16), Vector4(0.22, 0.02, 0.78, 0.1))
	L.prompt = lab(hud, "", ls(M.f_ui, 18), Vector4(0.25, 0.53, 0.75, 0.6))
	L.sub = lab(hud, "", ls(M.f_ui, 22), Vector4(0.12, 0.76, 0.88, 0.9))
	L.msg = lab(hud, "", ls(M.f_ui, 30), Vector4(0.1, 0.3, 0.9, 0.42))
	L.toast = lab(hud, "", ls(M.f_ui, 14, Color(0.85, 0.8, 0.7)), Vector4(0.6, 0.02, 0.985, 0.07), HORIZONTAL_ALIGNMENT_RIGHT)
	var dot := ColorRect.new()
	dot.color = Color(0.92, 0.9, 0.86, 0.5)
	dot.anchor_left = 0.5; dot.anchor_top = 0.5; dot.anchor_right = 0.5; dot.anchor_bottom = 0.5
	dot.offset_left = -2; dot.offset_top = -2; dot.offset_right = 2; dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	L.dot = dot
	var bars := Control.new()
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_hud.bind(bars))
	hud.add_child(bars)
	L.bars = bars
	# VHS OSD
	var osd := Control.new()
	osd.set_anchors_preset(Control.PRESET_FULL_RECT)
	osd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(osd)
	L.osd = osd
	L.osd_a = lab(osd, "PLAY ▶", ls(M.f_osd, 40), Vector4(0.6, 0.03, 0.97, 0.1), HORIZONTAL_ALIGNMENT_RIGHT)
	L.osd_t = lab(osd, "PM 7:42\nOKT. 14 1998", ls(M.f_osd, 40), Vector4(0.5, 0.8, 0.975, 0.97), HORIZONTAL_ALIGNMENT_RIGHT)
	osd.visible = false
	# hide overlay (wardrobe slats / under the bed)
	var ho := Control.new()
	ho.set_anchors_preset(Control.PRESET_FULL_RECT)
	ho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ho.draw.connect(func():
		var sz := ho.size
		if ho.get_meta("bed", false):
			ho.draw_rect(Rect2(0, 0, sz.x, sz.y * 0.36), Color(0.02, 0.015, 0.01, 0.97))
			ho.draw_rect(Rect2(0, sz.y * 0.36, sz.x, 10), Color(0.08, 0.05, 0.03, 1))
		else:
			var y := 0.0
			while y < sz.y:
				ho.draw_rect(Rect2(0, y, sz.x, 34), Color(0.03, 0.02, 0.015, 0.96))
				y += 52
			ho.draw_rect(Rect2(0, 0, sz.x * 0.16, sz.y), Color(0.02, 0.015, 0.01, 0.98))
			ho.draw_rect(Rect2(sz.x * 0.84, 0, sz.x * 0.16, sz.y), Color(0.02, 0.015, 0.01, 0.98)))
	hud.add_child(ho)
	L.hide = ho
	L.hide_txt = lab(ho, "", ls(M.f_ui, 16, Color(0.85, 0.8, 0.7)), Vector4(0.3, 0.86, 0.7, 0.92))
	var mf := ColorRect.new()
	mf.color = Color(0.9, 0.3, 0.2, 0.8)
	mf.anchor_left = 0.4; mf.anchor_right = 0.4; mf.anchor_top = 0.93; mf.anchor_bottom = 0.935
	ho.add_child(mf)
	L.mic_fill = mf
	ho.visible = false
	# knife QTE
	var qt := Control.new()
	qt.set_anchors_preset(Control.PRESET_FULL_RECT)
	qt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(qt)
	lab(qt, "BODNI!", ls(M.f_title, 90, Color(1, 0.25, 0.2)), Vector4(0.2, 0.32, 0.8, 0.5))
	lab(qt, "Stlač E", ls(M.f_ui, 20), Vector4(0.2, 0.5, 0.8, 0.56))
	var qf := ColorRect.new()
	qf.color = Color(1, 0.3, 0.2, 0.9)
	qf.anchor_left = 0.35; qf.anchor_right = 0.65; qf.anchor_top = 0.58; qf.anchor_bottom = 0.59
	qt.add_child(qf)
	L.qte_fill = qf
	L.qte = qt
	qt.visible = false
	# cinematic letterbox
	var cine := Control.new()
	cine.set_anchors_preset(Control.PRESET_FULL_RECT)
	cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := ColorRect.new(); t1.color = Color.BLACK; t1.anchor_right = 1; t1.anchor_bottom = 0.1; cine.add_child(t1)
	var t2 := ColorRect.new(); t2.color = Color.BLACK; t2.anchor_right = 1; t2.anchor_top = 0.9; t2.anchor_bottom = 1; cine.add_child(t2)
	lab(cine, "medzerník = preskočiť", ls(M.f_ui, 12, Color(0.5, 0.5, 0.5)), Vector4(0.6, 0.92, 0.98, 0.98), HORIZONTAL_ALIGNMENT_RIGHT)
	hud.add_child(cine)
	L.cine = cine
	cine.visible = false
	# overlays layer
	var tl := CanvasLayer.new()
	tl.layer = 4
	M.add_child(tl)
	top = Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(top)
	# face flash
	var ff := TextureRect.new()
	ff.texture = M.world.tex.face
	ff.set_anchors_preset(Control.PRESET_FULL_RECT)
	ff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ff.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fbg := full(top, Color.BLACK)
	fbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fbg.add_child(ff)
	fbg.visible = false
	L.face = fbg
	L.face_img = ff
	# day card
	var dc := full(top, Color.BLACK)
	L.dc_t = lab(dc, "DEŇ 1", ls(M.f_osd, 110), Vector4(0.1, 0.34, 0.9, 0.5))
	L.dc_s = lab(dc, "", ls(M.f_ui, 16, Color(0.6, 0.57, 0.52)), Vector4(0.1, 0.5, 0.9, 0.56))
	dc.visible = false
	L.daycard = dc


# =====================================================================
# HUD API
# =====================================================================
func hud_show(on: bool) -> void:
	hud.visible = on


func objective(t: String) -> void:
	L.obj.text = t.to_upper()


func say(who: String, text: String, d := 0.0) -> void:
	sub_q.append([who, text, d if d > 0 else 1.6 + text.length() * 0.055])


func msg(t: String, d := 3.0) -> void:
	L.msg.text = t
	msg_t = d


func toast(t: String, d := 2.2, small := false) -> void:
	if small and toast_t > 0:
		return
	L.toast.text = t
	toast_t = d
	A.play("tick", -14)


func osd(on: bool, time := "", date := "", rec := false, anom := false) -> void:
	L.osd.visible = on
	if on:
		L.osd_t.text = time + "\n" + date
		L.osd_a.text = "REC ●" if rec else ("?? ▶" if anom else "PLAY ▶")
		L.osd_a.label_settings.font_color = Color(1, 0.3, 0.25) if rec or anom else Color(0.92, 0.9, 0.86)


func batt_visible(on: bool) -> void:
	batt_on = on


func hide_overlay(on: bool, bed := false, mic := false) -> void:
	L.hide.visible = on
	L.hide.set_meta("bed", bed)
	L.hide.queue_redraw()
	L.hide_txt.text = "Mikrofón počúva · buď ticho" if mic else "Skrývaš sa · E = vyjsť"
	L.mic_fill.visible = mic


func hide_heard() -> void:
	L.hide_txt.text = "POČULI ŤA!"


func mic_fill(v: float) -> void:
	L.mic_fill.anchor_right = 0.4 + 0.2 * v


func qte(on: bool) -> void:
	L.qte.visible = on


func qte_fill(v: float) -> void:
	L.qte_fill.anchor_left = 0.5 - 0.15 * maxf(0.0, v)
	L.qte_fill.anchor_right = 0.5 + 0.15 * maxf(0.0, v)


func face_flash(sec: float) -> void:
	L.face.visible = true
	L.face_img.scale = Vector2.ONE * randf_range(1.0, 1.15)
	L.face_img.pivot_offset = L.face_img.size / 2
	L.face_img.rotation = randf_range(-0.07, 0.07)
	face_t = sec


func day_card(n: int, sub: String) -> void:
	L.dc_t.text = "DEŇ %d" % n
	L.dc_s.text = sub.to_upper()
	L.daycard.visible = true
	L.day.text = "DEŇ %d" % n


func day_card_hide() -> void:
	L.daycard.visible = false


func cine(on: bool) -> void:
	L.cine.visible = on
	L.bars.visible = not on
	L.dot.visible = not on


func prompt(lbl, hidden: bool) -> void:
	if hidden:
		L.prompt.text = "[E]  Vyjsť"
		L.dot.color.a = 0.45
		return
	L.prompt.text = ("[E]  " + str(lbl)) if lbl != null else ""
	L.dot.color.a = 0.95 if lbl != null else 0.45
	var dim: bool = lbl != null and (str(lbl).contains("zamknuté") or str(lbl).contains("Ešte nemôžeš") or str(lbl).contains("nejde prúd"))
	L.prompt.label_settings.font_color = Color(0.6, 0.58, 0.55) if dim else Color(0.92, 0.9, 0.86)


func update_hud(dt: float) -> void:
	var S: Dictionary = G.S
	if S.hp < hud_hp - 0.5:
		hud_flash = 1.0
	hud_flash = maxf(0.0, hud_flash - dt * 1.5)
	hud_hp = lerpf(hud_hp, S.hp, minf(1.0, dt * 6.0))
	hud_batt = lerpf(hud_batt, 100.0 if S.world == "fake" else S.batt, minf(1.0, dt * 6.0))
	L.bars.queue_redraw()
	L.safe.text = "☀ SVETLO ŤA CHRÁNI" if G.safe_now() else ""
	var mins: int = (23 * 60 + int(S.dayT / 1.5)) % 1440
	L.clock.text = "%02d:%02d" % [mins / 60, mins % 60]


func _process(dt: float) -> void:
	if sub_t > 0:
		sub_t -= dt
	elif sub_q.size() > 0:
		var l: Array = sub_q.pop_front()
		L.sub.text = (l[0] + "   " if l[0] != "" else "") + l[1]
		sub_t = l[2]
		A.speak(l[0], l[1])
	else:
		L.sub.text = ""
	if msg_t > 0:
		msg_t -= dt
		if msg_t <= 0:
			L.msg.text = ""
	if toast_t > 0:
		toast_t -= dt
		if toast_t <= 0:
			L.toast.text = ""
	if face_t > 0:
		face_t -= dt
		if face_t <= 0:
			L.face.visible = false
	if story_cb != null and L.has("story_t") and L.story_t.visible_characters < story_full.length():
		L.story_t.visible_characters += 2
		if L.story_t.visible_characters % 6 == 0:
			A.play("tick", -22)


func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI / 6.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_hud(c: Control) -> void:
	var S: Dictionary = G.S
	var white := Color(0.95, 0.94, 0.9, 0.92)
	var dim := Color(0.95, 0.94, 0.9, 0.35)
	var base := Vector2(46, c.size.y - 118)
	var font: Font = M.f_title_ui
	var rows := [["hp", hud_hp / 100.0, str(int(round(hud_hp)))]]
	if batt_on:
		rows.append(["batt", hud_batt / 100.0, "%d %%" % int(round(hud_batt))])
	if S.knife > 0:
		rows.append(["knife", S.knife / 3.0, "%d×" % S.knife])
	base.y = c.size.y - 58 - (rows.size() - 1) * 60
	for i in rows.size():
		var kind: String = rows[i][0]
		var v: float = clampf(rows[i][1], 0.0, 1.0)
		var ctr := base + Vector2(i * 22, i * 60)
		var accent := Color(0.95, 0.25, 0.2, 0.95) if v < 0.25 else white
		if kind == "hp" and hud_flash > 0:
			accent = Color(1, 0.2, 0.15, 0.95).lerp(white, 1.0 - hud_flash)
		var hx := _hex(ctr, 25)
		c.draw_colored_polygon(hx, Color(0.03, 0.03, 0.04, 0.6))
		c.draw_polyline(hx, accent, 2.5, true)
		c.draw_polyline(_hex(ctr, 30), Color(accent.r, accent.g, accent.b, 0.25), 1.5, true)
		if kind == "hp":
			var heart := PackedVector2Array()
			for k in 40:
				var t := k / 40.0 * TAU
				heart.append(ctr + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 0.82 + Vector2(0, -1))
			c.draw_colored_polygon(heart, accent)
		elif kind == "batt":
			var r := Rect2(ctr + Vector2(-13, -8), Vector2(23, 16))
			c.draw_rect(r, accent, false, 2.0, true)
			c.draw_rect(Rect2(ctr + Vector2(10, -4), Vector2(4, 8)), accent, true, -1.0, true)
			c.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * v, r.size.y - 6)), accent, true, -1.0, true)
		else:
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-12, 10), ctr + Vector2(8, -12), ctr + Vector2(12, -8), ctr + Vector2(-8, 13)]), accent)
		var bp := ctr + Vector2(38, -12)
		var bw := 230.0
		var bh := 24.0
		var frame := PackedVector2Array([bp, bp + Vector2(bw, 0), bp + Vector2(bw - 8, bh), bp + Vector2(0, bh), bp])
		c.draw_colored_polygon(frame, Color(0.03, 0.03, 0.04, 0.45))
		c.draw_polyline(frame, dim, 1.5, true)
		var fw := maxf(0.0, (bw - 10) * v)
		if fw > 1.0:
			c.draw_colored_polygon(PackedVector2Array([bp + Vector2(3, 3), bp + Vector2(3 + fw, 3), bp + Vector2(3 + fw - 6 * minf(1.0, fw / 10.0), bh - 3), bp + Vector2(3, bh - 3)]), Color(accent.r, accent.g, accent.b, 0.85))
			var x := 20.0
			while x < fw:
				c.draw_line(bp + Vector2(3 + x, 5), bp + Vector2(3 + x - 3, bh - 5), Color(0, 0, 0, 0.18), 2.0, true)
				x += 20.0
		var tp := bp + Vector2(bw + 10, bh - 4)
		c.draw_string(font, tp + Vector2(1, 1), rows[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.6))
		c.draw_string(font, tp, rows[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, accent)


# =====================================================================
# panels
# =====================================================================
func open_panel(title: String, build: Callable, on_close = null, width := 0.62) -> VBoxContainer:
	close_panel(false)
	G.S.ui = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := full(top, Color(0, 0, 0, 0.72))
	panel = bg
	panel_close_cb = on_close
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.065, 0.06, 0.98), Color(0.32, 0.28, 0.24), 12, 2))
	pc.anchor_left = 0.5 - width / 2
	pc.anchor_right = 0.5 + width / 2
	pc.anchor_top = 0.08
	pc.anchor_bottom = 0.92
	bg.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	sc.add_child(v)
	if title != "":
		text_label(v, title, M.f_title_ui, 28, Color(0.95, 0.9, 0.82))
	build.call(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	btn(row, "ZAVRIEŤ", func(): close_panel(), 22, 180)
	return v


func close_panel(cb := true) -> void:
	if panel == null:
		return
	panel.queue_free()
	panel = null
	G.S.ui = false
	var f = panel_close_cb
	panel_close_cb = null
	if G.S.running and not G.S.paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if cb and f is Callable:
		f.call()


func show_note(title: String, paras: Array) -> void:
	open_panel("", func(v: VBoxContainer):
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", sbox(Color(0.88, 0.84, 0.75), Color(0.6, 0.5, 0.4), 4, 1))
		v.add_child(pc)
		var vv := VBoxContainer.new()
		vv.add_theme_constant_override("separation", 10)
		pc.add_child(vv)
		text_label(vv, title, M.f_type, 24, Color(0.2, 0.1, 0.06))
		for p in paras:
			text_label(vv, p, M.f_type, 19, Color(0.15, 0.12, 0.1)), null, 0.5)


func show_image(t: Texture2D, cap: String) -> void:
	open_panel("", func(v: VBoxContainer):
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 400)
		v.add_child(tr)
		text_label(v, cap, M.f_type, 20, Color(0.85, 0.8, 0.72), HORIZONTAL_ALIGNMENT_CENTER), null, 0.5)


func open_keypad(ok: Callable) -> void:
	var code := [""]
	open_panel("Číselný zámok", func(v: VBoxContainer):
		var disp := text_label(v, "____", M.f_osd, 72, Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
		text_label(v, "Zadaj štvormiestny kód", M.f_ui, 15, Color(0.6, 0.58, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 10)
		var cc := CenterContainer.new()
		cc.add_child(g)
		v.add_child(cc)
		var upd := func(): disp.text = (code[0] + "____").substr(0, 4)
		for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
			var kk: String = k
			btn(g, kk, func():
				if kk == "C":
					code[0] = ""
				elif kk == "OK":
					if ok.call(code[0]):
						close_panel()
						return
					disp.text = "CHYBA"
					A.play("hurt", -14, 1.6)
					code[0] = ""
					get_tree().create_timer(0.7).timeout.connect(upd)
					return
				elif code[0].length() < 4:
					code[0] += kk
				upd.call(), 30, 90), null, 0.4)


func open_clock(ok: Callable) -> void:
	var hm := [12, 0]
	open_panel("Veľké hodiny", func(v: VBoxContainer):
		text_label(v, "Nastav ručičky veľkých hodín", M.f_ui, 16, Color(0.7, 0.66, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		v.add_child(row)
		var mk := func(idx: int):
			var col := VBoxContainer.new()
			row.add_child(col)
			var val := Label.new()
			var refresh := func(): val.text = str(hm[0]) if idx == 0 else "%02d" % hm[1]
			btn(col, "▲", func():
				if idx == 0: hm[0] = hm[0] % 12 + 1
				else: hm[1] = (hm[1] + 5) % 60
				refresh.call(), 26, 80)
			val.label_settings = ls(M.f_osd, 64)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(val)
			btn(col, "▼", func():
				if idx == 0: hm[0] = (hm[0] + 10) % 12 + 1
				else: hm[1] = (hm[1] + 55) % 60
				refresh.call(), 26, 80)
			refresh.call()
		mk.call(0)
		text_label(row, ":", M.f_osd, 64)
		mk.call(1)
		var go_row := HBoxContainer.new()
		go_row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(go_row)
		var go: Button
		go = btn(go_row, "NASTAVIŤ", func():
			if ok.call(hm[0], hm[1]):
				close_panel()
			else:
				go.text = "NIČ SA NESTALO"
				get_tree().create_timer(0.9).timeout.connect(func(): go.text = "NASTAVIŤ"), 24, 220), null, 0.42)


func open_photos(ok: Callable) -> void:
	var order := [2, 0, 3, 1]
	var sel := [-1]
	open_panel("Fotky na komode", func(v: VBoxContainer):
		text_label(v, "Zoraď fotky Lucie od najmladšej po najstaršiu. Klikni na dve fotky a vymenia sa.", M.f_ui, 16, Color(0.75, 0.7, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var draw := func(): pass
		draw = func():
			for c in row.get_children():
				c.queue_free()
			for i in 4:
				var ii := i
				var b := TextureButton.new()
				b.texture_normal = M.world.tex["photo%d" % order[i]]
				b.ignore_texture_size = true
				b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				b.custom_minimum_size = Vector2(150, 190)
				b.modulate = Color(1, 0.75, 0.7) if sel[0] == i else Color.WHITE
				b.pressed.connect(func():
					A.play("click", -10)
					if sel[0] < 0:
						sel[0] = ii
					else:
						var t = order[sel[0]]
						order[sel[0]] = order[ii]
						order[ii] = t
						sel[0] = -1
					draw.call())
				row.add_child(b)
		draw.call()
		var go_row := HBoxContainer.new()
		go_row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(go_row)
		var go: Button
		go = btn(go_row, "POTVRDIŤ", func():
			if ok.call(order):
				close_panel()
			else:
				go.text = "NESPRÁVNE"
				A.play("hurt", -14, 1.6)
				get_tree().create_timer(0.9).timeout.connect(func(): go.text = "POTVRDIŤ"), 24, 220), null, 0.72)


func open_levers(ok: Callable) -> void:
	var st := [0, 0, 0, 0, 0]
	open_panel("Poistková skriňa", func(v: VBoxContainer):
		text_label(v, "Nastav páky a zapni prúd.", M.f_ui, 16, Color(0.75, 0.7, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		for i in 5:
			var ii := i
			var b: Button
			b = btn(row, "%d\n▼" % (i + 1), func():
				st[ii] ^= 1
				b.text = "%d\n%s" % [ii + 1, "▲" if st[ii] else "▼"], 30, 80)
		var go_row := HBoxContainer.new()
		go_row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(go_row)
		var go: Button
		go = btn(go_row, "ZAPNÚŤ PRÚD", func():
			if ok.call(st):
				close_panel()
			else:
				go.text = "ISKRY… NIČ"
				A.play("crack")
				get_tree().create_timer(0.9).timeout.connect(func(): go.text = "ZAPNÚŤ PRÚD"), 24, 240), null, 0.5)


func choose_tape(list: Array, cb: Callable) -> void:
	open_panel("Ktorú kazetu vložíš?", func(v: VBoxContainer):
		var row := HFlowContainer.new()
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		v.add_child(row)
		for id in list:
			var iid: String = id
			btn(row, "Kazeta bez čísla" if iid == "X" else "Kazeta " + iid, func():
				close_panel(false)
				cb.call(iid), 22, 180), null, 0.5)


func open_repair(on_done: Callable, on_close: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	var done := [false]
	open_panel("Kazeta 13", func(v: VBoxContainer):
		var cap := text_label(v, "Navíjaš pásku späť do kazety…", M.f_ui, 18, Color(0.8, 0.75, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
		var cv := Control.new()
		cv.custom_minimum_size = Vector2(420, 240)
		v.add_child(cv)
		cv.draw.connect(func():
			var k := minf(1.0, (Time.get_ticks_msec() - t0) / 4200.0)
			var o := Vector2((cv.size.x - 420) / 2, 0)
			cv.draw_rect(Rect2(o + Vector2(30, 30), Vector2(360, 180)), Color(0.11, 0.105, 0.1))
			cv.draw_rect(Rect2(o + Vector2(50, 44), Vector2(320, 70)), Color(0.89, 0.85, 0.75))
			cv.draw_rect(Rect2(o + Vector2(50, 44), Vector2(320, 12)), Color(0.72, 0.25, 0.18))
			cv.draw_string(M.f_mark, o + Vector2(66, 100), "13", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.08, 0.07, 0.05))
			cv.draw_string(M.f_type, o + Vector2(120, 96), "oprava…" if k < 1 else "REALITA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.08, 0.07, 0.05))
			cv.draw_rect(Rect2(o + Vector2(110, 130), Vector2(200, 60)), Color(0.02, 0.02, 0.02))
			var tm := Time.get_ticks_msec() / 180.0
			for x in [150, 270]:
				var ctr := o + Vector2(x, 160)
				cv.draw_arc(ctr, 20, 0, TAU, 24, Color(0.85, 0.83, 0.78), 5)
				for i in 3:
					var a: float = tm * (1 if x > 200 else -1) + i * TAU / 3
					cv.draw_line(ctr + Vector2(cos(a), sin(a)) * 6, ctr + Vector2(cos(a), sin(a)) * 17, Color(0.85, 0.83, 0.78), 4)
			var sag := 60.0 * (1 - k)
			var pts := PackedVector2Array()
			for i in 21:
				var t := i / 20.0
				pts.append(o + Vector2(170 + 80 * t, 160 + sin(t * PI) * (30 + sag)))
			cv.draw_polyline(pts, Color(0.23, 0.14, 0.08), 4)
			cv.draw_rect(Rect2(o + Vector2(30, 222), Vector2(360 * k, 8)), Color(0.9, 0.3, 0.22))
			if k >= 1 and not done[0]:
				done[0] = true
				on_done.call()
				cap.text = "Kazeta 13 je opravená. Môžeš ju pustiť."
			elif k < 1 and randf() < 0.15:
				A.play("tick", -16))
		var tm2 := Timer.new()
		tm2.wait_time = 0.03
		tm2.autostart = true
		tm2.timeout.connect(func(): cv.queue_redraw())
		v.add_child(tm2), on_close, 0.5)


func open_bag() -> void:
	var S: Dictionary = G.S
	var F: Dictionary = G.F
	open_panel("", func(v: VBoxContainer):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		v.add_child(row)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		text_label(left, "Taška", M.f_title_ui, 28, Color(0.95, 0.9, 0.82))
		var add := func(ic: String, t: String, s: String):
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			left.add_child(h)
			var il := text_label(h, ic, M.f_ui, 22, Color(1, 0.6, 0.45))
			il.custom_minimum_size = Vector2(30, 0)
			var vv := VBoxContainer.new()
			vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(vv)
			text_label(vv, t, M.f_ui, 17, Color(0.92, 0.9, 0.86))
			if s != "":
				text_label(vv, s, M.f_ui, 13, Color(0.6, 0.58, 0.55))
		if G.has("tape13") and F.get("t13broken", false) and not F.get("t13fixed", false) and not F.get("used_13", false):
			add.call("✕", "Zlomená kazeta 13", "Treba náhradnú cievku a lepiacu pásku. Oprava na stole v pracovni.")
		for id in G.hand_list():
			add.call("▭", "Kazeta " + ("bez čísla" if id == "X" else id), "Vlož ju do televízora v obývačke.")
		if G.has("keyKid") and not F.get("kidOpen", false):
			add.call("⚷", "Kľúč od detskej izby", "Z kazety. Stále je v ruke.")
		if G.has("keyBase") and not F.get("baseOpen", false):
			add.call("⚷", "Kľúč od pivnice", "Bol schovaný v hodinách.")
		if G.has("knife"):
			add.call("†", "Nôž", ("Vydrží ešte %d×" % S.knife) if S.knife > 0 else "Zlomený")
		if S.changes.size() > 0 and G.isRealW(S.world):
			var n := 0
			for id in S.changes:
				n += 1 if F.get("chg_%s%d" % [id, S.day], false) else 0
			add.call("?", "Zmeny v dome", "%d / %d nájdené" % [n, S.changes.size()])
		add.call("◐", "Baterka", "%d %%" % int(round(100.0 if S.world == "fake" else S.batt)))
		add.call("♥", "Život", "%d / 100" % int(round(S.hp)))
		if S.world == "a3":
			var r := 0
			for k in ["reel1", "reel2", "reel3"]:
				r += 1 if G.has(k) else 0
			add.call("◎", "Cievky pásky", "%d / 3" % r)
		if S.world == "a6":
			var y := 0
			for k in ["toy1", "toy2", "toy3", "toy4"]:
				y += 1 if G.has(k) else 0
			add.call("◎", "Luciine hračky", "%d / 4" % y)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right)
		text_label(right, "Denník", M.f_title_ui, 28, Color(0.95, 0.9, 0.82))
		if S.obj_text != "":
			text_label(right, "Teraz: " + S.obj_text, M.f_type, 16, Color(1, 0.75, 0.55))
		var cl: Array = F.get("clues", [])
		if cl.is_empty():
			text_label(right, "Zatiaľ prázdny. Všímaj si obrazy, hodiny, fotky a poznámky.", M.f_type, 15, Color(0.6, 0.58, 0.55))
		for k in cl:
			text_label(right, "· " + C.CLUES.get(k, k), M.f_type, 15, Color(0.85, 0.8, 0.72))
		var read := []
		for k in C.NOTES:
			if F.get("read_" + k, false):
				read.append(k)
		if read.size() > 0:
			text_label(right, "Poznámky", M.f_title_ui, 20, Color(0.9, 0.85, 0.78))
			for k in read:
				var kk: String = k
				btn(right, C.NOTES[kk][0], func():
					close_panel(false)
					show_note(C.NOTES[kk][0], C.NOTES[kk][1]), 15)
		, null, 0.8)


func open_map() -> void:
	var S: Dictionary = G.S
	var F: Dictionary = G.F
	var base: bool = S.zone == "base"
	open_panel("", func(v: VBoxContainer):
		var cv := Control.new()
		cv.custom_minimum_size = Vector2(760, 500)
		v.add_child(cv)
		cv.draw.connect(func():
			var Wd := 760.0
			var Hh := 500.0
			var o := Vector2((cv.size.x - Wd) / 2, 0)
			cv.draw_rect(Rect2(o, Vector2(Wd, Hh)), Color(0.9, 0.86, 0.77))
			var ox := 40.0 if base else 0.0
			var w := 14.0 if base else 24.0
			var h := 12.0 if base else 15.0
			var sc := minf((Wd - 80) / w, (Hh - 80) / h)
			var X := func(x): return o.x + 40 + (x - ox) * sc
			var Z := func(z): return o.y + 40 + z * sc
			var ink := Color(0.16, 0.12, 0.07)
			for r in C.ROOMS:
				var is_b: bool = r[2] >= 40
				if is_b != base:
					continue
				var rect := Rect2(X.call(r[2]), Z.call(r[3]), (r[4] - r[2]) * sc, (r[5] - r[3]) * sc)
				if not F.get("seen_" + r[0], false):
					cv.draw_rect(rect, Color(0.24, 0.16, 0.08, 0.18), false, 2.0)
					continue
				cv.draw_rect(rect, Color(1, 0.84, 0.47, 0.45) if S.lit.get(r[0], false) else Color(0.47, 0.37, 0.24, 0.12))
				cv.draw_rect(rect, ink, false, 3.5)
				var fs := maxi(13, int(sc * 0.55))
				var tw: float = M.f_mark.get_string_size(r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				cv.draw_string(M.f_mark, rect.get_center() + Vector2(-tw / 2, fs * 0.35), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			for d in M.world.door_list:
				if (d.x >= 40) != base:
					continue
				var a: bool = d.axis == "x"
				cv.draw_line(Vector2(X.call(d.x - d.w / 2 if a else d.x), Z.call(d.z if a else d.z - d.w / 2)), Vector2(X.call(d.x + d.w / 2 if a else d.x), Z.call(d.z if a else d.z + d.w / 2)), Color(0.9, 0.86, 0.77), 6)
			var icon := func(x: float, z: float, t: String, col := ink):
				cv.draw_string(M.f_type, Vector2(X.call(x) - 8, Z.call(z) + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
			if not base:
				for k in G.LIT:
					var s = G.LIT[k].sw
					icon.call(s[0], s[2], "☀" if S.lit.get(k, false) else "○", Color(0.66, 0.42, 0) if S.lit.get(k, false) else ink)
				icon.call(4.5, 1.1, "▭ TV")
				icon.call(6.5, 14.4, "↓ pivnica")
			else:
				icon.call(41.3, 1.6, "↑ hore")
			for hd in G.HIDES:
				if (hd.x >= 40) == base:
					icon.call(hd.out[0], hd.out[1], "▯")
			if S.zone == ("base" if base else "house"):
				var p := Vector2(X.call(S.x), Z.call(S.z))
				var f: Vector3 = G.fwd()
				var fv := Vector2(f.x, f.z)
				var rv := Vector2(-f.z, f.x)
				cv.draw_colored_polygon(PackedVector2Array([p + fv * 16, p - fv * 8 + rv * 9, p - fv * 8 - rv * 9]), Color(0.72, 0.11, 0.11))
			cv.draw_string(M.f_type, o + Vector2(40, Hh - 14), "☀ svetlo   ○ vypínač   ▯ skrýša", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.16, 0.12, 0.07, 0.7)))
		text_label(v, "Pivnica · ručne kreslený plán" if base else "Prízemie · kreslíš ho, ako objavuješ izby", M.f_type, 15, Color(0.7, 0.66, 0.6), HORIZONTAL_ALIGNMENT_CENTER), null, 0.72)


# =====================================================================
# pause, settings, death, end
# =====================================================================
func toggle_pause() -> void:
	var S: Dictionary = G.S
	if not S.running or S.dead:
		return
	S.paused = not S.paused
	if S.paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var bg := full(top, Color(0, 0, 0, 0.8))
		L.pause = bg
		lab(bg, "PAUZA", ls(M.f_osd, 72), Vector4(0.1, 0.18, 0.9, 0.32))
		var v := VBoxContainer.new()
		v.anchor_left = 0.38; v.anchor_right = 0.62; v.anchor_top = 0.38; v.anchor_bottom = 0.8
		v.add_theme_constant_override("separation", 10)
		bg.add_child(v)
		btn(v, "▶  POKRAČOVAŤ", toggle_pause, 26)
		btn(v, "⚙  NASTAVENIA", open_settings, 26)
		btn(v, "HLAVNÉ MENU", func(): get_tree().reload_current_scene(), 22)
		btn(v, "UKONČIŤ", func(): get_tree().quit(), 22)
		lab(bg, "Tab: taška a denník · M: mapa", ls(M.f_ui, 13, Color(0.55, 0.52, 0.47)), Vector4(0.1, 0.86, 0.9, 0.9))
	else:
		if L.has("pause") and is_instance_valid(L.pause):
			L.pause.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func open_settings() -> void:
	var SET: Dictionary = M.SET
	var bg := full(top, Color(0, 0, 0, 0.85))
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.065, 0.06, 0.98), Color(0.32, 0.28, 0.24), 12, 2))
	pc.anchor_left = 0.3; pc.anchor_right = 0.7; pc.anchor_top = 0.08; pc.anchor_bottom = 0.92
	bg.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	text_label(v, "Nastavenia", M.f_title_ui, 30)
	var slider := func(title: String, key: String, lo: float, hi: float):
		var l := text_label(v, "", M.f_ui, 16)
		var upd := func(): l.text = "%s  %d %%" % [title, int(SET[key] * 100)]
		upd.call()
		var hs := HSlider.new()
		hs.min_value = lo
		hs.max_value = hi
		hs.step = 0.01
		hs.value = SET[key]
		hs.custom_minimum_size = Vector2(0, 24)
		hs.value_changed.connect(func(x):
			SET[key] = x
			upd.call()
			M.apply_settings())
		v.add_child(hs)
	text_label(v, "Grafika", M.f_ui, 16)
	var gr := HBoxContainer.new()
	v.add_child(gr)
	var gbs := []
	for i in 3:
		var ii := i
		var b := btn(gr, ["Nízka", "Stredná", "Vysoká"][i], func():
			SET.gfx = ii
			M.apply_settings()
			for k in 3:
				gbs[k].modulate = Color(1, 0.6, 0.5) if k == ii else Color.WHITE, 18)
		b.modulate = Color(1, 0.6, 0.5) if int(SET.get("gfx", 1)) == i else Color.WHITE
		gbs.append(b)
	text_label(v, "Ak sa hra seká, daj Nízka.", M.f_ui, 12, Color(0.55, 0.52, 0.48))
	slider.call("Hlasitosť", "vol", 0.0, 1.0)
	slider.call("Citlivosť myši", "sens", 0.3, 2.0)
	slider.call("Jas", "bright", 0.6, 1.6)
	text_label(v, "Obtiažnosť", M.f_ui, 16)
	var dr := HBoxContainer.new()
	v.add_child(dr)
	var dbs := []
	for i in 3:
		var ii := i
		var b := btn(dr, C.DIFF[i].n, func():
			SET.diff = ii
			M.apply_settings()
			for k in 3:
				dbs[k].modulate = Color(1, 0.6, 0.5) if k == ii else Color.WHITE, 18)
		b.modulate = Color(1, 0.6, 0.5) if int(SET.diff) == i else Color.WHITE
		dbs.append(b)
	var tg := func(title: String, key: String, note: String, on_change = null):
		var h := HBoxContainer.new()
		v.add_child(h)
		var l := text_label(h, title, M.f_ui, 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b: Button
		b = btn(h, "ZAPNUTÉ" if SET[key] else "VYPNUTÉ", func():
			SET[key] = not SET[key]
			b.text = "ZAPNUTÉ" if SET[key] else "VYPNUTÉ"
			M.apply_settings()
			if on_change is Callable:
				on_change.call(), 16, 140)
		if note != "":
			text_label(v, note, M.f_ui, 12, Color(0.55, 0.52, 0.48))
	tg.call("Hlasy postáv", "voices", "Postavy hovoria nahlas cez hlas systému (ak ho máš).", func():
		if SET.voices:
			A.speak("MAMA", "Zlatko? Si to ty?"))
	tg.call("Mikrofón pri schovávaní", "mic", "Počúva iba vtedy, keď sa skrývaš. Keď je hlučno, príšery ťa nájdu.")
	tg.call("Celá obrazovka", "fullscreen", "")
	tg.call("Zobraziť FPS", "fps", "")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	btn(row, "✓  HOTOVO", func():
		M.save_settings()
		bg.queue_free(), 24, 200)


func show_death(text: String, can_cp: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := full(top, Color(0.03, 0, 0, 0.94))
	L.death = bg
	lab(bg, "KONIEC", ls(M.f_title, 96, Color(1, 0.28, 0.2)), Vector4(0.1, 0.22, 0.9, 0.4))
	lab(bg, text, ls(M.f_ui, 18, Color(0.75, 0.7, 0.64)), Vector4(0.2, 0.42, 0.8, 0.56))
	var row := HBoxContainer.new()
	row.anchor_left = 0.3; row.anchor_right = 0.7; row.anchor_top = 0.62; row.anchor_bottom = 0.7
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(row)
	btn(row, "↻  POKRAČOVAŤ" if can_cp else "↻  DEŇ ODZNOVA", func():
		bg.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		G.retry(), 28, 300)


func hide_overlays() -> void:
	if L.has("death") and is_instance_valid(L.death):
		L.death.queue_free()
	close_panel(false)


func show_end(t: String, p: String, ending: String, stats: Array, best: Array) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	var bg := full(top, Color(0.01, 0.01, 0.012, 1.0))
	lab(bg, t, ls(M.f_title, 64, Color(0.95, 0.92, 0.88)), Vector4(0.08, 0.06, 0.92, 0.2))
	lab(bg, p, ls(M.f_type, 20, Color(0.78, 0.74, 0.67)), Vector4(0.15, 0.2, 0.85, 0.38))
	# the tape ejects, with your name on it
	var cas := PanelContainer.new()
	cas.add_theme_stylebox_override("panel", sbox(Color(0.08, 0.08, 0.08), Color(0.2, 0.2, 0.2), 10, 2))
	cas.anchor_left = 0.35; cas.anchor_right = 0.65; cas.anchor_top = 0.42; cas.anchor_bottom = 0.58
	bg.add_child(cas)
	var cv := VBoxContainer.new()
	cas.add_child(cv)
	var lbl := PanelContainer.new()
	lbl.add_theme_stylebox_override("panel", sbox(Color(0.89, 0.85, 0.75), Color(0.72, 0.25, 0.18), 3, 3))
	cv.add_child(lbl)
	var lv := VBoxContainer.new()
	lbl.add_child(lv)
	text_label(lv, G.nm() if G.nm() else "Kazeta 13", M.f_mark, 30, Color(0.1, 0.08, 0.06), HORIZONTAL_ALIGNMENT_CENTER)
	text_label(lv, "14.10.98 · koniec " + ending, M.f_type, 14, Color(0.25, 0.2, 0.15), HORIZONTAL_ALIGNMENT_CENTER)
	text_label(cv, "EJECT ⏏", M.f_osd, 24, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	cas.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(cas, "modulate:a", 1.0, 1.0).set_delay(0.4)
	A.play("insert", 0, 0.7)
	await get_tree().create_timer(5.2).timeout
	cas.queue_free()
	# stats
	var grid := GridContainer.new()
	grid.columns = 3
	grid.anchor_left = 0.2; grid.anchor_right = 0.8; grid.anchor_top = 0.4; grid.anchor_bottom = 0.6
	grid.add_theme_constant_override("h_separation", 40)
	bg.add_child(grid)
	for s in stats:
		var vv := VBoxContainer.new()
		grid.add_child(vv)
		text_label(vv, s[0], M.f_ui, 14, Color(0.6, 0.57, 0.52))
		text_label(vv, s[1], M.f_title_ui, 26)
	var bl := VBoxContainer.new()
	bl.anchor_left = 0.2; bl.anchor_right = 0.8; bl.anchor_top = 0.62; bl.anchor_bottom = 0.8
	bg.add_child(bl)
	text_label(bl, "Tvoje najlepšie prechody", M.f_title_ui, 18)
	for b in best:
		text_label(bl, b, M.f_type, 15, Color(0.75, 0.7, 0.64))
	# credits roll
	var clip := Control.new()
	clip.clip_contents = true
	clip.anchor_left = 0.68; clip.anchor_right = 0.98; clip.anchor_top = 0.42; clip.anchor_bottom = 0.98
	bg.add_child(clip)
	var roll := VBoxContainer.new()
	roll.position = Vector2(0, 600)
	roll.custom_minimum_size = Vector2(360, 0)
	clip.add_child(roll)
	var lines: Array = C.CREDITS.slice(0, 3)
	if G.nm():
		lines.append_array([G.nm(), ""])
	lines.append_array(C.CREDITS.slice(3))
	for i in lines.size():
		text_label(roll, G.fmt_n(lines[i]) if lines[i] != "" else " ", M.f_title_ui if i == 0 else M.f_type, 26 if i == 0 else 16, Color(0.85, 0.82, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	var tw2 := create_tween()
	tw2.tween_property(roll, "position:y", -900.0, 40.0)
	var row := HBoxContainer.new()
	row.anchor_left = 0.05; row.anchor_right = 0.4; row.anchor_top = 0.86; row.anchor_bottom = 0.94
	bg.add_child(row)
	var again := btn(row, "↺  HRAŤ ZNOVA", func(): get_tree().reload_current_scene(), 24, 260)
	again.modulate.a = 0.0
	create_tween().tween_property(again, "modulate:a", 1.0, 1.0).set_delay(6.0)


# =====================================================================
# new game flow: how-to -> name -> (easter eggs) -> story -> begin
# =====================================================================
func show_howto(on_done: Callable) -> void:
	var bg := full(top, Color(0.02, 0.02, 0.025, 1.0))
	var page := [0]
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(holder)
	var name_edit := LineEdit.new()
	var render := func(): pass
	render = func():
		for c in holder.get_children():
			c.queue_free()
		var pg = C.HOWTO[page[0]]
		lab(holder, "Návod na prežitie", ls(M.f_ui, 14, Color(0.6, 0.55, 0.5)), Vector4(0.1, 0.04, 0.9, 0.08))
		lab(holder, "%02d / %02d" % [page[0] + 1, C.HOWTO.size()], ls(M.f_osd, 24, Color(0.6, 0.55, 0.5)), Vector4(0.8, 0.04, 0.95, 0.08), HORIZONTAL_ALIGNMENT_RIGHT)
		lab(holder, pg[0], ls(M.f_title, 60, Color(0.95, 0.92, 0.88)), Vector4(0.1, 0.08, 0.9, 0.2))
		var g := GridContainer.new()
		g.columns = 2
		g.anchor_left = 0.1; g.anchor_right = 0.9; g.anchor_top = 0.22; g.anchor_bottom = 0.8
		g.add_theme_constant_override("h_separation", 40)
		g.add_theme_constant_override("v_separation", 18)
		holder.add_child(g)
		for it in pg[1]:
			var vv := VBoxContainer.new()
			vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(vv)
			text_label(vv, it[0], M.f_title_ui, 22, Color(1, 0.55, 0.42))
			text_label(vv, it[1], M.f_ui, 16, Color(0.82, 0.78, 0.72))
		if page[0] == C.HOWTO.size() - 1:
			var nv := VBoxContainer.new()
			nv.anchor_left = 0.1; nv.anchor_right = 0.55; nv.anchor_top = 0.6; nv.anchor_bottom = 0.84
			holder.add_child(nv)
			text_label(nv, "Tvoje meno", M.f_title_ui, 22, Color(1, 0.55, 0.42))
			text_label(nv, "Dom ťa bude volať menom. Nechaj prázdne, ak nechceš.", M.f_ui, 14, Color(0.7, 0.66, 0.6))
			name_edit = LineEdit.new()
			name_edit.max_length = 16
			name_edit.text = str(M.SET.get("name", ""))
			name_edit.placeholder_text = "meno"
			name_edit.add_theme_font_override("font", M.f_type)
			name_edit.add_theme_font_size_override("font_size", 22)
			name_edit.custom_minimum_size = Vector2(300, 44)
			nv.add_child(name_edit)
		var row := HBoxContainer.new()
		row.anchor_left = 0.1; row.anchor_right = 0.9; row.anchor_top = 0.86; row.anchor_bottom = 0.94
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 30)
		holder.add_child(row)
		var prev := btn(row, "◀  SPÄŤ", func():
			page[0] = maxi(0, page[0] - 1)
			render.call(), 24, 200)
		prev.disabled = page[0] == 0
		btn(row, "ZAČAŤ  ▶" if page[0] == C.HOWTO.size() - 1 else "ĎALEJ  ▶", func():
			if page[0] < C.HOWTO.size() - 1:
				page[0] += 1
				render.call()
				return
			M.SET.name = name_edit.text.replace("<", "").replace(">", "").substr(0, 16)
			M.save_settings()
			bg.queue_free()
			name_egg(func(): show_story(on_done)), 24, 220)
	render.call()


func name_egg(next: Callable) -> void:
	var n: String = str(M.SET.get("name", "")).strip_edges().to_lower()
	if n == "":
		next.call()
		return
	var who = C.EGG.get(n)
	if n != "porty" and who == null:
		next.call()
		return
	var bg := full(top, Color.BLACK)
	var tr := TextureRect.new()
	tr.texture = M.world.tex.face
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.anchor_left = 0.3; tr.anchor_right = 0.7; tr.anchor_top = 0.05; tr.anchor_bottom = 0.75
	bg.add_child(tr)
	var p := lab(bg, "", ls(M.f_title, 54, Color(0.95, 0.9, 0.85)), Vector4(0.05, 0.76, 0.95, 0.95))
	A.play("stinger")
	var shown: String = str(M.SET.name)
	if n == "porty":
		p.text = "PORTY."
		await get_tree().create_timer(0.2).timeout
		A.play("shriek")
		A.play("shriek", 0, 0.8)
		var steps := [[1.1, "Vedeli sme, že prídeš."], [1.3, "Celý dom ťa volá po mene."], [1.3, "PORTY. PORTY. PORTY."], [1.3, "Kazeta 13 je tvoja."]]
		for i in steps.size():
			await get_tree().create_timer(steps[i][0]).timeout
			p.text = steps[i][1]
			A.speak("???", steps[i][1])
			if i == 2:
				A.play("stinger")
				bg.color = Color(0.35, 0, 0)
				p.label_settings.font_color = Color(1, 0.2, 0.15)
			else:
				A.play("moan", -2, 1.0 + i * 0.05)
		await get_tree().create_timer(1.4).timeout
	else:
		p.text = "%s? To meno už niekto má." % shown
		await get_tree().create_timer(0.25).timeout
		A.play("shriek")
		await get_tree().create_timer(1.15).timeout
		p.text = "Ja som Hosť. A odteraz aj ty." if who == "Hosť" else "%s ťa už čaká v dome." % who
		A.speak("???", p.text)
		A.play("moan")
		await get_tree().create_timer(2.2).timeout
	bg.queue_free()
	next.call()


func show_story(on_done: Callable) -> void:
	var bg := full(top, Color(0.01, 0.01, 0.012, 1.0))
	L.story = bg
	var t := lab(bg, "", ls(M.f_type, 30, Color(0.9, 0.86, 0.8)), Vector4(0.15, 0.25, 0.85, 0.75))
	L.story_t = t
	lab(bg, "klikni alebo stlač medzerník", ls(M.f_ui, 13, Color(0.5, 0.48, 0.45)), Vector4(0.1, 0.88, 0.9, 0.93))
	story_i = 0
	story_cb = on_done
	_story_show()
	bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			story_next())


func _story_show() -> void:
	story_full = G.fmt_n(C.STORY[story_i])
	L.story_t.text = story_full
	L.story_t.visible_characters = 0


func story_next() -> void:
	if story_cb == null:
		return
	if L.story_t.visible_characters < story_full.length():
		L.story_t.visible_characters = story_full.length()
		return
	story_i += 1
	if story_i >= C.STORY.size():
		var cb = story_cb
		story_cb = null
		L.story.queue_free()
		cb.call()
		return
	_story_show()


func _unhandled_input(e: InputEvent) -> void:
	if story_cb != null and e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_SPACE or e.physical_keycode == KEY_ENTER):
		story_next()
		get_viewport().set_input_as_handled()
