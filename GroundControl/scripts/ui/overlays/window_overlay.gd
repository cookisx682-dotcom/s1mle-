extends "res://scripts/ui/overlays/overlay_base.gd"
## Station 4 — window to the operations hall. A colleague or the flight director
## may stand there with a message or an order. The 3D figure stays visible above the panel.

var name_label: Label
var msg_label: Label
var ack_btn: Button
var _tw: Tween


func _init() -> void:
	dim_alpha = 0.0


func _build() -> void:
	var body := make_window("HALL WINDOW · OPERATIONS FLOOR", "bottom")
	name_label = UiTheme.label("", 13, UiTheme.COL_AMBER)
	body.add_child(name_label)
	msg_label = UiTheme.label("", 12, UiTheme.COL_TEXT, true)
	msg_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(msg_label)
	ack_btn = Button.new()
	ack_btn.text = "ACKNOWLEDGE"
	ack_btn.pressed.connect(_on_ack)
	body.add_child(ack_btn)
	EventManager.visitor_arrived.connect(func(_v): _refresh())
	EventManager.visitor_left.connect(_refresh)


func _on_open() -> void:
	_refresh()


func _refresh() -> void:
	var v := EventManager.current_visitor
	if v.is_empty():
		name_label.text = "Nobody at the window."
		msg_label.text = "The hall is empty. Somewhere a vending machine hums, and the teletype in Room 3 chatters to itself."
		ack_btn.visible = false
		msg_label.visible_ratio = 1.0
		return
	name_label.text = "%s — %s" % [str(v.get("name", "?")).to_upper(), str(v.get("role", ""))]
	msg_label.text = "\"%s\"" % str(v.get("text", ""))
	ack_btn.visible = true
	ack_btn.text = str(v.get("button", "ACKNOWLEDGE"))
	if visible:
		if _tw and _tw.is_valid():
			_tw.kill()
		msg_label.visible_ratio = 0.0
		_tw = create_tween()
		_tw.tween_property(msg_label, "visible_ratio", 1.0, clampf(msg_label.text.length() * 0.02, 0.3, 3.0))


func _on_ack() -> void:
	AudioManager.play_sfx("ui_click")
	EventManager.acknowledge_visitor()
	close_requested.emit()
