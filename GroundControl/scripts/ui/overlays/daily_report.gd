extends "res://scripts/ui/overlays/overlay_base.gd"
## End-of-shift printout with statistics and a grade.

signal continue_pressed
signal retry_pressed

var title_label: Label
var stats_label: Label
var grade_label: Label
var comment_label: Label
var continue_btn: Button
var retry_btn: Button


func _init() -> void:
	dim_alpha = 0.75


func _build() -> void:
	var body := make_window("SHIFT REPORT", "center", "paper")
	title_label = UiTheme.label("", 13, UiTheme.COL_INK)
	title_label.add_theme_font_override("font", UiTheme.mono_font_bold())
	body.add_child(title_label)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	stats_label = UiTheme.label("", 12, UiTheme.COL_INK)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(stats_label)
	var gv := VBoxContainer.new()
	h.add_child(gv)
	gv.add_child(UiTheme.label("GRADE", 11, Color("5a4a30")))
	grade_label = UiTheme.label("", 48, Color("8a2c24"))
	grade_label.add_theme_font_override("font", UiTheme.mono_font_bold())
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(grade_label)
	comment_label = UiTheme.label("", 11, Color("3a3020"), true)
	body.add_child(comment_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	retry_btn = Button.new()
	retry_btn.text = "RETRY SHIFT"
	retry_btn.pressed.connect(func(): retry_pressed.emit())
	row.add_child(retry_btn)
	continue_btn = Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	row.add_child(continue_btn)


func show_report(day: Dictionary, r: Dictionary) -> void:
	title_label.text = "%s · %s" % [str(day.get("date", "")), str(day.get("title", ""))]
	var lines := [
		"Missions completed ....... %d" % int(r["missions_ok"]),
		"Missions failed .......... %d" % int(r["missions_failed"]),
		"Deductions ............... %d" % int(r["deductions"]),
		"Wrong strings ............ %d" % int(r["wrong_links"]),
		"Crises handled ........... %d / %d" % [int(r["crises_ok"]), int(r["crises_ok"]) + int(r["crises_failed"])],
		"New cards ................ %d" % int(r["cards"]),
		"Oxygen left .............. %.1f %%" % float(r["oxygen_left"]),
		"Oxygen wasted ............ %.1f %%" % float(r["oxygen_wasted"]),
		"Power left ............... %.1f %%" % float(r["power_left"]),
		"Rapport with Mia ......... %d / 100" % int(r["trust"]),
	]
	stats_label.text = "\n".join(PackedStringArray(lines))
	grade_label.text = str(r["grade"])
	var comment := str(r.get("comment", ""))
	if bool(r.get("aborted", false)):
		comment = "SHIFT ABORTED. Mia had to return to the lander. — W. Hale"
	comment_label.text = comment
	retry_btn.visible = bool(r.get("aborted", false))
	continue_btn.text = "CONTINUE" if not GameState.is_last_day() else "END TRANSMISSION"
	open()
