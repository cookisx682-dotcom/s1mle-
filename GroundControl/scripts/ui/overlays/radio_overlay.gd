extends "res://scripts/ui/overlays/overlay_base.gd"
## Station 1 — main console & radio.
## Left: the voice-loop transcript (typed out) with answer choices.
## Right: system levers (heat / lights / rover / helmet cam), Mia's rapport, ping button
## and the repair dictation panel.

const SYSTEMS := [["heat", "HEATING"], ["lights", "HAB LIGHTS"], ["rover", "ROVER"], ["cam", "HELMET CAM"]]

var log_label: RichTextLabel
var choices_box: VBoxContainer
var continue_btn: Button
var call_btn: Button
var trust_bar: ProgressBar
var trust_label: Label
var load_label: Label
var system_buttons: Dictionary = {}
var repair_box: VBoxContainer
var repair_status: Label
var repair_buttons: VBoxContainer
var _type_tween: Tween
var _ping_cooldown := 0.0
var _type_acc := 0.0


func _init() -> void:
	use_crt = true
	crt_tint = Color(1.0, 0.97, 0.9)


func _build() -> void:
	var body := make_window("SELENE-1 · S-BAND VOICE LOOP")
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)

	# --- left column: conversation
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.8
	left.add_theme_constant_override("separation", 4)
	h.add_child(left)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(0, 100)
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_font_size_override("bold_font_size", 12)
	log_label.add_theme_font_override("bold_font", UiTheme.mono_font_bold())
	left.add_child(log_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 3)
	left.add_child(choices_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	left.add_child(row)
	continue_btn = Button.new()
	continue_btn.text = "CONTINUE  [SPACE]"
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.pressed.connect(_on_continue)
	row.add_child(continue_btn)
	call_btn = Button.new()
	call_btn.text = "PING SELENE"
	call_btn.pressed.connect(_on_call)
	row.add_child(call_btn)

	# --- right column: systems, rapport, repairs
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	h.add_child(right)
	var sys := make_section(right, "SYSTEM LEVERS", UiTheme.COL_AMBER)
	for s in SYSTEMS:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_system_pressed.bind(str(s[0])))
		sys.add_child(b)
		system_buttons[s[0]] = b
	load_label = UiTheme.label("", 10, UiTheme.COL_AMBER)
	sys.add_child(load_label)

	var rap := make_section(right, "RAPPORT WITH MIA", UiTheme.COL_VIOLET)
	trust_bar = ProgressBar.new()
	trust_bar.min_value = 0
	trust_bar.max_value = 100
	trust_bar.show_percentage = false
	trust_bar.custom_minimum_size = Vector2(0, 10)
	trust_bar.add_theme_stylebox_override("fill", UiTheme.bar_style(UiTheme.COL_VIOLET))
	rap.add_child(trust_bar)
	trust_label = UiTheme.label("", 10, UiTheme.COL_VIOLET)
	rap.add_child(trust_label)

	repair_box = make_section(right, "REPAIR DICTATION", UiTheme.COL_GREEN)
	repair_status = UiTheme.label("", 10, UiTheme.COL_GREEN, true)
	repair_box.add_child(repair_status)
	repair_buttons = VBoxContainer.new()
	repair_buttons.add_theme_constant_override("separation", 2)
	repair_box.add_child(repair_buttons)

	DialogueManager.transcript_added.connect(_on_transcript_added)
	DialogueManager.choices_shown.connect(_on_choices)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	ResourceManager.system_changed.connect(_on_system_changed)
	MissionGenerator.mission_started.connect(_on_mission_changed)
	MissionGenerator.mission_updated.connect(_on_mission_changed)
	GameState.trust_changed.connect(_on_trust_changed)
	_rebuild_log()
	_refresh_systems()
	_refresh_repair()
	_on_trust_changed(GameState.trust)


func _on_open() -> void:
	_rebuild_log()
	_refresh_systems()
	_refresh_repair()
	_on_trust_changed(GameState.trust)
	if not DialogueManager.is_active():
		DialogueManager.start_next()
	_on_choices(DialogueManager.current_choices)


func _process(delta: float) -> void:
	if not visible:
		return
	_ping_cooldown = maxf(0.0, _ping_cooldown - delta)
	call_btn.disabled = _ping_cooldown > 0.0 or DialogueManager.is_active()
	if DialogueManager.pending_count() > 0 and not DialogueManager.is_active():
		call_btn.text = "ANSWER (%d)" % DialogueManager.pending_count()
		call_btn.disabled = false
	else:
		call_btn.text = "PING SELENE"
	load_label.text = "BUS LOAD %.3f %%/s · PWR %d%%" % [ResourceManager.power_draw(), int(ResourceManager.power)]
	# typewriter clicks
	if _type_tween and _type_tween.is_running():
		_type_acc += delta
		if _type_acc > 0.06:
			_type_acc = 0.0
			AudioManager.play_sfx("typewriter", randf_range(0.9, 1.2))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("advance"):
		_on_continue()


# ---------------------------------------------------------------- transcript

func _format_line(speaker: String, text: String) -> String:
	var col := "#cfe9ff"
	match speaker:
		"MIA":
			col = "#5cffb0"
		"YOU":
			col = "#3fe0ff"
		"LOOP":
			col = "#9b7bff"
		_:
			col = "#ffb547"
	return "[color=%s][b]%s:[/b] %s[/color]\n" % [col, speaker, text.replace("[", "(").replace("]", ")")]


func _rebuild_log() -> void:
	log_label.clear()
	for e in DialogueManager.transcript:
		log_label.append_text(_format_line(str(e["speaker"]), str(e["text"])))
	log_label.visible_characters = -1


func _on_transcript_added(speaker: String, text: String) -> void:
	var before := log_label.get_total_character_count()
	log_label.append_text(_format_line(speaker, text))
	if not visible:
		log_label.visible_characters = -1
		return
	var after := log_label.get_total_character_count()
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	log_label.visible_characters = before
	_type_tween = create_tween()
	_type_tween.tween_property(log_label, "visible_characters", after, maxf(0.15, (after - before) * 0.022))


func _skip_typing() -> bool:
	if _type_tween and _type_tween.is_running():
		_type_tween.kill()
		log_label.visible_characters = -1
		return true
	return false


# ---------------------------------------------------------------- choices / flow

func _on_choices(choices: Array) -> void:
	for c in choices_box.get_children():
		c.queue_free()
	for c in choices:
		var txt := "> " + str(c["text"])
		var lines := ceili(txt.length() * 7.2 / 360.0)
		var b := UiTheme.wrap_button(txt, 8 + 14 * maxi(1, lines), 12)
		b.pressed.connect(_on_choice.bind(int(c["index"])))
		choices_box.add_child(b)
	continue_btn.visible = DialogueManager.is_active() and choices.is_empty()


func _on_choice(index: int) -> void:
	_skip_typing()
	AudioManager.play_sfx("ui_click")
	DialogueManager.choose(index)


func _on_continue() -> void:
	if _skip_typing():
		return
	if DialogueManager.is_active() and DialogueManager.current_choices.is_empty():
		AudioManager.play_sfx("ui_click")
		DialogueManager.advance()
	elif not DialogueManager.is_active() and DialogueManager.has_pending():
		DialogueManager.start_next()


func _on_dialogue_finished(_id: String) -> void:
	continue_btn.visible = false
	if visible and DialogueManager.has_pending():
		get_tree().create_timer(1.2, false).timeout.connect(_start_next_if_open)


func _start_next_if_open() -> void:
	if visible and not DialogueManager.is_active():
		DialogueManager.start_next()


func _on_call() -> void:
	AudioManager.play_sfx("radio_beep")
	if DialogueManager.has_pending() and not DialogueManager.is_active():
		DialogueManager.start_next()
		return
	_ping_cooldown = 20.0
	DialogueManager.say("YOU", "Selene, Ground. Radio check.")
	DialogueManager.idle_chatter()


# ---------------------------------------------------------------- systems

func _on_system_pressed(system_name: String) -> void:
	ResourceManager.toggle_system(system_name)
	AudioManager.play_sfx("switch")


func _on_system_changed(_name: String, _on: bool) -> void:
	_refresh_systems()


func _refresh_systems() -> void:
	for s in SYSTEMS:
		var b: Button = system_buttons[s[0]]
		var on := ResourceManager.is_on(str(s[0]))
		b.text = ("[ ON ] " if on else "[ -- ] ") + str(s[1])
		b.modulate = Color.WHITE if on else Color(0.65, 0.65, 0.7)


func _on_trust_changed(value: int) -> void:
	trust_bar.value = value
	var word := "COLD"
	if value >= 90:
		word = "BEST COLLEAGUES"
	elif value >= 70:
		word = "WARM"
	elif value >= 45:
		word = "PROFESSIONAL"
	elif value >= 25:
		word = "GUARDED"
	trust_label.text = "%d / 100 · %s" % [value, word]


# ---------------------------------------------------------------- repair

func _on_mission_changed(_m: Dictionary) -> void:
	_refresh_repair()


func _refresh_repair() -> void:
	for c in repair_buttons.get_children():
		c.queue_free()
	var m := MissionGenerator.active
	if m.is_empty() or str(m.get("type", "")) != "repair":
		repair_status.text = "No repair in progress."
		return
	var steps: Array = m["steps"]
	repair_status.text = "%s\nSTEP %d/%d · ERRORS %d/%d\nManual is on the MONITORS." % [
		str(m["title"]).to_upper(), int(m["progress"]) + 1, steps.size(), int(m["mistakes"]), int(m["max_mistakes"])]
	var opts: Array = m["options"]
	var done: Array = m["done"]
	for i in opts.size():
		var txt := str(opts[i])
		var b := UiTheme.wrap_button(txt, 8 + 12 * maxi(1, ceili(txt.length() * 6.0 / 190.0)), 10)
		b.disabled = done.has(i)
		b.pressed.connect(_on_dictate.bind(i))
		repair_buttons.add_child(b)


func _on_dictate(index: int) -> void:
	AudioManager.play_sfx("ui_click")
	MissionGenerator.dictate_step(index)
