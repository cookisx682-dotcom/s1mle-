extends "res://scripts/ui/overlays/overlay_base.gd"
## Station 5 — phone / fax. Orders from HQ arrive as fax sheets. Some offer a choice
## (comply or not); the answer is permanent and recorded in the archive.

var list_box: VBoxContainer
var from_label: Label
var title_label: Label
var body_label: Label
var choice_box: HBoxContainer
var status_label: Label
var _shown_id := ""


func _build() -> void:
	var body := make_window("TELEFAX · LINE 2 · HQ", "full", "paper")
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	body.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	h.add_child(left)
	left.add_child(UiTheme.label("RECEIVED", 11, Color("5a4a30")))
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 3)
	left.add_child(list_box)

	var sheet := PanelContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_stylebox_override("panel", UiTheme.box(Color("f6f1e1"), Color("b9ae90"), 1, 10))
	h.add_child(sheet)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sheet.add_child(sv)
	from_label = UiTheme.label("", 10, Color("5a4a30"), true)
	sv.add_child(from_label)
	title_label = UiTheme.label("", 14, UiTheme.COL_INK, true)
	title_label.add_theme_font_override("font", UiTheme.mono_font_bold())
	sv.add_child(title_label)
	body_label = UiTheme.label("", 12, UiTheme.COL_INK, true)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(body_label)
	status_label = UiTheme.label("", 11, Color("8a2c24"), true)
	sv.add_child(status_label)
	choice_box = HBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 8)
	sv.add_child(choice_box)

	EventManager.fax_received.connect(func(_id): _refresh())
	EventManager.fax_answered.connect(func(_id): _refresh())


func _on_open() -> void:
	_shown_id = ""
	if not EventManager.fax_inbox.is_empty():
		_shown_id = str(EventManager.fax_inbox[0])
		AudioManager.play_sfx("fax")
	_refresh()


func _refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var ids: Array = []
	for id in EventManager.fax_inbox:
		ids.append(str(id))
	for a in EventManager.fax_archive:
		ids.append(str(a["id"]))
	if _shown_id == "" and not ids.is_empty():
		_shown_id = ids[0]
	for id in ids:
		var f := EventManager.get_fax(id)
		var unread := EventManager.fax_inbox.has(id)
		var b := Button.new()
		b.text = ("* " if unread else "  ") + str(f.get("title", id)).left(20)
		b.add_theme_font_size_override("font_size", 10)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show.bind(id))
		list_box.add_child(b)
	_show(_shown_id)


func _show(id: String) -> void:
	_shown_id = id
	for c in choice_box.get_children():
		c.queue_free()
	if id == "":
		from_label.text = ""
		title_label.text = "NO MESSAGES"
		body_label.text = "The fax machine is warm and silent."
		status_label.text = ""
		return
	var f := EventManager.get_fax(id)
	from_label.text = "FROM: %s\nREF: %s" % [str(f.get("from", "HQ")), str(f.get("ref", id.to_upper()))]
	title_label.text = str(f.get("title", ""))
	body_label.text = str(f.get("body", ""))
	if EventManager.fax_inbox.has(id):
		status_label.text = "AWAITING YOUR RESPONSE" if bool(f.get("required", false)) else ""
		var choices: Array = f.get("choices", [])
		if choices.is_empty():
			choices = [{"label": "ACKNOWLEDGE"}]
		for i in choices.size():
			var b := Button.new()
			b.text = str(choices[i].get("label", "OK"))
			b.pressed.connect(_answer.bind(id, i if not (f.get("choices", []) as Array).is_empty() else -1))
			choice_box.add_child(b)
	else:
		status_label.text = "FILED · YOUR RESPONSE: %s" % EventManager.archived_answer(id)


func _answer(id: String, index: int) -> void:
	AudioManager.play_sfx("ui_click")
	EventManager.answer_fax(id, index)
	if EventManager.fax_inbox.is_empty():
		_show(id)
	else:
		_shown_id = str(EventManager.fax_inbox[0])
		_refresh()
