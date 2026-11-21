extends "res://scripts/ui/overlays/overlay_base.gd"
## Station 3 — the cork evidence board.
## Drag cards from the INBOX tray onto the board. Click a pinned card, then another one,
## to tie them with red string. A correct pair creates a deduction card; a wrong one costs time.

const BoardCard = preload("res://scripts/ui/overlays/board_card.gd")
const BoardStrings = preload("res://scripts/ui/overlays/board_strings.gd")
const CORK = preload("res://shaders/cork.gdshader")
const DRAG_THRESHOLD := 4.0

var board_area: Control
var cards_layer: Control
var strings: Control
var tray_box: HBoxContainer
var drag_layer: Control
var detail_title: Label
var detail_text: Label
var detail_panel: PanelContainer
var counter_label: Label
var banner: Label

var _press_card: Control = null
var _press_pos := Vector2.ZERO
var _ghost: Control = null
var _ghost_offset := Vector2.ZERO
var _dragging := false
var _selected := ""
var _banner_time := 0.0


func _init() -> void:
	dim_alpha = 0.2


func _build() -> void:
	var cork := ColorRect.new()
	cork.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cm := ShaderMaterial.new()
	cm.shader = CORK
	cork.material = cm
	cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cork)

	var frame := ReferenceRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.border_color = Color("2a1c12")
	frame.border_width = 6.0
	frame.editor_only = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	# header
	var header := HBoxContainer.new()
	header.anchor_right = 1.0
	header.offset_left = 10
	header.offset_right = -10
	header.offset_top = 6
	header.offset_bottom = 24
	root.add_child(header)
	var title := UiTheme.label("EVIDENCE BOARD", 13, UiTheme.COL_PAPER)
	title.add_theme_font_override("font", UiTheme.mono_font_bold())
	header.add_child(title)
	var hint := UiTheme.label("  drag cards from the inbox · click two pinned cards to tie a string", 10, Color("f3d9b0"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hint)
	counter_label = UiTheme.label("", 11, UiTheme.COL_PAPER)
	header.add_child(counter_label)
	var back := Button.new()
	back.text = "BACK [ESC]"
	back.add_theme_font_size_override("font_size", 11)
	back.pressed.connect(func(): close_requested.emit())
	header.add_child(back)

	# board area
	board_area = Control.new()
	board_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_area.offset_left = 10
	board_area.offset_top = 28
	board_area.offset_right = -10
	board_area.offset_bottom = -80
	board_area.mouse_filter = Control.MOUSE_FILTER_PASS
	board_area.gui_input.connect(_on_board_input)
	root.add_child(board_area)
	cards_layer = Control.new()
	cards_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(cards_layer)
	strings = BoardStrings.new()
	strings.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_area.add_child(strings)

	# detail panel (hovered card)
	detail_panel = PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.05, 0.1, 0.92), UiTheme.COL_CYAN.darkened(0.3), 1, 6))
	detail_panel.anchor_left = 1.0
	detail_panel.anchor_right = 1.0
	detail_panel.anchor_top = 1.0
	detail_panel.anchor_bottom = 1.0
	detail_panel.offset_left = -232
	detail_panel.offset_right = -10
	detail_panel.offset_top = -170
	detail_panel.offset_bottom = -84
	detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.visible = false
	root.add_child(detail_panel)
	var dv := VBoxContainer.new()
	detail_panel.add_child(dv)
	detail_title = UiTheme.label("", 11, UiTheme.COL_CYAN, true)
	dv.add_child(detail_title)
	detail_text = UiTheme.label("", 10, UiTheme.COL_TEXT, true)
	dv.add_child(detail_text)

	# inbox tray
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.07, 0.05, 0.92), Color("2a1c12"), 2, 4))
	tray.anchor_top = 1.0
	tray.anchor_bottom = 1.0
	tray.anchor_right = 1.0
	tray.offset_left = 10
	tray.offset_right = -10
	tray.offset_top = -76
	tray.offset_bottom = -6
	root.add_child(tray)
	var tv := VBoxContainer.new()
	tray.add_child(tv)
	tv.add_child(UiTheme.label("INBOX", 10, Color("f3d9b0")))
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 56)
	tv.add_child(scroll)
	tray_box = HBoxContainer.new()
	tray_box.add_theme_constant_override("separation", 6)
	scroll.add_child(tray_box)

	drag_layer = Control.new()
	drag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(drag_layer)

	banner = UiTheme.label("", 13, Color.WHITE)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.anchor_right = 1.0
	banner.offset_top = 30
	banner.offset_bottom = 50
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 4)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)

	BoardManager.board_changed.connect(_rebuild)
	BoardManager.link_created.connect(_on_link_created)
	BoardManager.link_failed.connect(_on_link_failed)
	_rebuild()


func _on_open() -> void:
	_selected = ""
	_rebuild()


func _on_close() -> void:
	_cancel_drag()
	_selected = ""
	strings.set("pending_from", "")


func _process(delta: float) -> void:
	if not visible:
		return
	strings.set("mouse_pos", board_area.get_local_mouse_position())
	strings.queue_redraw()
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			banner.text = ""


# ---------------------------------------------------------------- building

func _rebuild() -> void:
	if cards_layer == null:
		return
	if _dragging:
		return
	for c in cards_layer.get_children():
		c.queue_free()
	for c in tray_box.get_children():
		c.queue_free()
	for id in BoardManager.pinned.keys():
		var card := _make_card(str(id))
		card.position = BoardManager.get_pin_pos(str(id))
		card.rotation_degrees = card.get("tilt")
		cards_layer.add_child(card)
	for id in BoardManager.inbox():
		var card := _make_card(str(id))
		tray_box.add_child(card)
	counter_label.text = "DEDUCTIONS %d/%d  " % [BoardManager.deductions_found.size(), BoardManager.total_deductions()]


func _make_card(id: String) -> Control:
	var card: Control = BoardCard.new()
	card.call("setup", id)
	card.set("selected", id == _selected)
	card.gui_input.connect(_on_card_input.bind(card))
	card.mouse_entered.connect(_show_detail.bind(id))
	card.mouse_exited.connect(_hide_detail)
	return card


func _find_card(id: String) -> Control:
	for c in cards_layer.get_children():
		if c.get("card_id") == id and not c.is_queued_for_deletion():
			return c
	return null


# ---------------------------------------------------------------- input

func _on_card_input(event: InputEvent, card: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_card = card
			_press_pos = root.get_local_mouse_position()
			_dragging = false
		else:
			if _dragging:
				_finish_drag()
			elif _press_card == card:
				_on_card_clicked(card)
			_press_card = null
		card.accept_event()
	elif event is InputEventMouseMotion and _press_card == card:
		var mp := root.get_local_mouse_position()
		if not _dragging and mp.distance_to(_press_pos) > DRAG_THRESHOLD:
			_start_drag(card)
		if _dragging and _ghost != null:
			_ghost.position = mp - _ghost_offset
		card.accept_event()


func _on_board_input(event: InputEvent) -> void:
	# clicking empty cork cancels the current selection
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _selected != "":
		_set_selected("")


func _start_drag(card: Control) -> void:
	_dragging = true
	_ghost = BoardCard.new()
	_ghost.call("setup", str(card.get("card_id")))
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.rotation_degrees = 4.0
	drag_layer.add_child(_ghost)
	_ghost_offset = Vector2(42, 20)
	_ghost.position = root.get_local_mouse_position() - _ghost_offset
	card.modulate = Color(1, 1, 1, 0.3)


func _finish_drag() -> void:
	var id := str(_press_card.get("card_id")) if (_press_card != null and is_instance_valid(_press_card)) else ""
	var drop := board_area.get_local_mouse_position() - _ghost_offset
	var area := board_area.size
	_cancel_drag()
	if id == "":
		return
	if drop.x > -40 and drop.y > -20 and drop.x < area.x - 40 and drop.y < area.y - 20:
		drop.x = clampf(drop.x, 0.0, area.x - BoardCard.CARD_SIZE.x)
		drop.y = clampf(drop.y, 0.0, area.y - BoardCard.CARD_SIZE.y)
		BoardManager.pin(id, drop)
	_rebuild()


func _cancel_drag() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _press_card != null and is_instance_valid(_press_card):
		_press_card.modulate = Color.WHITE
	_dragging = false


func _on_card_clicked(card: Control) -> void:
	var id := str(card.get("card_id"))
	if not BoardManager.pinned.has(id):
		_flash_banner("Pin the card to the board first (drag it).", UiTheme.COL_AMBER)
		return
	AudioManager.play_sfx("ui_click")
	if _selected == "":
		_set_selected(id)
		return
	if _selected == id:
		_set_selected("")
		return
	var a := _selected
	_set_selected("")
	var result := BoardManager.try_connect(a, id)
	if result == "already":
		_flash_banner("Those are already tied together.", UiTheme.COL_PAPER)


func _set_selected(id: String) -> void:
	_selected = id
	strings.set("pending_from", id)
	for c in cards_layer.get_children():
		c.set("selected", c.get("card_id") == id)
		(c as Control).queue_redraw()


# ---------------------------------------------------------------- feedback

func _on_link_created(_a: String, _b: String, ded: String) -> void:
	var d := BoardManager.get_card(ded)
	_flash_banner("DEDUCTION — %s" % str(d.get("title", "")), UiTheme.COL_GREEN)
	await get_tree().process_frame
	var c := _find_card(ded)
	if c != null:
		c.call("do_flash", UiTheme.COL_GREEN)


func _on_link_failed(a: String, b: String) -> void:
	_flash_banner("THESE DON'T CONNECT — %d MIN LOST" % int(BoardManager.wrong_penalty_minutes), UiTheme.COL_RED)
	for id in [a, b]:
		var c := _find_card(str(id))
		if c != null:
			c.call("do_flash", UiTheme.COL_RED)


func _flash_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	_banner_time = 3.0


func _show_detail(id: String) -> void:
	var d := BoardManager.get_card(id)
	detail_title.text = str(d.get("title", id)).to_upper()
	detail_text.text = str(d.get("text", ""))
	detail_panel.visible = true


func _hide_detail() -> void:
	detail_panel.visible = false
