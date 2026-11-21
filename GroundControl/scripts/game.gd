extends Node
## Main gameplay controller.
## Builds the pixel-rendered 3D room (SubViewport 480x270 → nearest upscale + post shader),
## the HUD and all station overlays, and routes input between:
##   "look"    — mouse turns the head, A/D jump between stations, click opens a station
##   "station" — camera zoomed in, overlay UI active (RMB / ESC returns)
##   "intro" / "report" / "ending" — full-screen sequences

const ControlRoom = preload("res://scripts/world/control_room.gd")
const CameraRig = preload("res://scripts/world/camera_rig.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const RadioOverlay = preload("res://scripts/ui/overlays/radio_overlay.gd")
const MonitorsOverlay = preload("res://scripts/ui/overlays/monitors_overlay.gd")
const BoardOverlay = preload("res://scripts/ui/overlays/board_overlay.gd")
const WindowOverlay = preload("res://scripts/ui/overlays/window_overlay.gd")
const PhoneOverlay = preload("res://scripts/ui/overlays/phone_overlay.gd")
const DailyReport = preload("res://scripts/ui/overlays/daily_report.gd")
const IntroCard = preload("res://scripts/ui/intro_card.gd")
const EndingSequence = preload("res://scripts/ui/ending_sequence.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const PIXEL_SHADER = preload("res://shaders/pixelate.gdshader")

const PIXEL_RES := Vector2i(480, 270)
const MENU_SCENE := "res://scenes/main_menu.tscn"

var pixel_vp: SubViewport
var world_rect: TextureRect
var pixel_mat: ShaderMaterial
var room: ControlRoom
var rig: CameraRig
var hud: Hud
var overlays: Dictionary = {}
var current_station := ""
var report: DailyReport
var intro: IntroCard
var ending: EndingSequence
var pause_menu: PauseMenu
var state := "intro"
var _attention_acc := 0.0


func _ready() -> void:
	_build_world()
	_build_ui()
	_connect_signals()
	_apply_settings()
	AudioManager.play_ambience("room_tone")
	AudioManager.play_music("night_shift")
	_start_day_sequence()


# ---------------------------------------------------------------- construction

func _build_world() -> void:
	pixel_vp = SubViewport.new()
	pixel_vp.size = PIXEL_RES
	pixel_vp.own_world_3d = true
	pixel_vp.msaa_3d = Viewport.MSAA_DISABLED
	pixel_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_vp)

	room = ControlRoom.new()
	room.set("era", str(GameState.get_day().get("era", "1970s")))
	pixel_vp.add_child(room)

	rig = CameraRig.new()
	rig.position = ControlRoom.EYE
	pixel_vp.add_child(rig)
	rig.call("set_stations", room.get("stations"))
	rig.call("reset_view")

	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	world_rect = TextureRect.new()
	world_rect.texture = pixel_vp.get_texture()
	world_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pixel_mat = ShaderMaterial.new()
	pixel_mat.shader = PIXEL_SHADER
	world_rect.material = pixel_mat
	layer.add_child(world_rect)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var defs := {
		"console": RadioOverlay, "monitors": MonitorsOverlay, "board": BoardOverlay,
		"window": WindowOverlay, "phone": PhoneOverlay,
	}
	for id in defs.keys():
		var ov: Control = (defs[id] as GDScript).new()
		ui.add_child(ov)
		ov.connect("close_requested", close_station)
		overlays[id] = ov

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)

	var top := CanvasLayer.new()
	top.layer = 30
	add_child(top)
	report = DailyReport.new()
	top.add_child(report)
	report.connect("continue_pressed", _on_report_continue)
	report.connect("retry_pressed", _on_report_retry)
	intro = IntroCard.new()
	top.add_child(intro)
	ending = EndingSequence.new()
	top.add_child(ending)

	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 50
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_layer.add_child(pause_menu)
	pause_menu.connect("resumed", _on_resumed)
	pause_menu.connect("quit_to_menu", _quit_to_menu)


func _connect_signals() -> void:
	rig.connect("hovered_changed", hud.set_prompt)
	GameState.day_finished.connect(_on_day_finished)
	EventManager.visitor_arrived.connect(room.show_visitor)
	EventManager.visitor_left.connect(room.hide_visitor)
	EventManager.crisis_started.connect(_on_crisis_started)
	EventManager.crisis_ended.connect(_on_crisis_ended)
	BoardManager.board_changed.connect(room.refresh_board)
	ResourceManager.system_changed.connect(room.set_lever)
	SaveSystem.settings_changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_apply_settings)


func _apply_settings() -> void:
	var pixel_on := bool(SaveSystem.get_setting("pixel_enabled", true))
	if pixel_on:
		pixel_vp.size = PIXEL_RES
	else:
		pixel_vp.size = get_window().size
	pixel_mat.set_shader_parameter("effect_enabled", pixel_on)
	pixel_mat.set_shader_parameter("resolution", Vector2(pixel_vp.size))
	pixel_mat.set_shader_parameter("noise_strength", 0.035 if bool(SaveSystem.get_setting("noise_enabled", true)) else 0.0)
	room.call("set_crt_enabled", bool(SaveSystem.get_setting("crt_enabled", true)))


# ---------------------------------------------------------------- day flow

func _start_day_sequence() -> void:
	state = "intro"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	var day := GameState.get_day()
	room.call("set_era", str(day.get("era", "1970s")))
	rig.call("set_stations", room.get("stations"))
	rig.call("reset_view")
	rig.set("cinematic", false)
	SaveSystem.save_progress(GameState.make_snapshot())
	var lines: Array = [str(day.get("date", "")), str(day.get("title", ""))]
	lines.append_array(day.get("intro", []))
	intro.call("play", lines)
	await intro.finished
	hud.visible = true
	hud.call("set_look_mode", true)
	state = "look"
	_capture_mouse()
	GameState.begin_day()


func _on_day_finished(_day: Dictionary, rep: Dictionary) -> void:
	if state == "station":
		_close_overlay_only()
	state = "report"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.call("set_look_mode", false)
	report.call("show_report", GameState.get_day(), rep)


func _on_report_continue() -> void:
	report.call("close")
	if GameState.is_last_day() or GameState.ending_id != "":
		_play_ending()
	elif GameState.advance_day():
		_start_day_sequence()
	else:
		_play_ending()


func _on_report_retry() -> void:
	report.call("close")
	GameState.load_snapshot(SaveSystem.get_progress())
	_start_day_sequence()


func _play_ending() -> void:
	state = "ending"
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var endings: Dictionary = GameState.config.get("endings", {})
	var key := GameState.ending_id if endings.has(GameState.ending_id) else "signal_acquired"
	var e: Dictionary = endings.get(key, {})
	await ending.play_cliffhanger(e.get("cliffhanger", ["SIGNAL ACQUIRED", "TO BE CONTINUED"]))
	GameState.emit_event("demo_complete", {"ending": key})
	var teaser: Dictionary = e.get("teaser", {})
	if not teaser.is_empty():
		room.call("set_era", str(teaser.get("era", "1980s")))
		rig.call("set_stations", room.get("stations"))
		rig.call("reset_view")
		rig.set("cinematic", true)
		await ending.play_teaser(teaser)
	SaveSystem.clear_progress()
	_quit_to_menu()


# ---------------------------------------------------------------- stations

func open_station(id: String) -> void:
	if not overlays.has(id):
		return
	var st: Dictionary = room.call("get_station", id)
	if st.is_empty():
		return
	state = "station"
	current_station = id
	rig.call("look_at_station", id)
	rig.call("zoom_to", st["focus"])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.call("set_look_mode", false)
	AudioManager.play_sfx("ui_click")
	overlays[id].call("open")


func close_station() -> void:
	if state != "station":
		return
	_close_overlay_only()
	state = "look"
	hud.call("set_look_mode", true)
	_capture_mouse()


func _close_overlay_only() -> void:
	if overlays.has(current_station):
		overlays[current_station].call("close")
	current_station = ""
	rig.call("unzoom")


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if state != "look" and state != "station":
		return
	# crisis answers work from anywhere
	if EventManager.has_crisis():
		for i in 3:
			if event.is_action_pressed("crisis_%d" % (i + 1)):
				EventManager.resolve_crisis(i)
				get_viewport().set_input_as_handled()
				return
	if state == "station":
		if event.is_action_pressed("pause") or event.is_action_pressed("back"):
			close_station()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("station_left") or event.is_action_pressed("station_right"):
			var dir := 1 if event.is_action_pressed("station_left") else -1
			close_station()
			rig.call("step_station", dir)
			get_viewport().set_input_as_handled()
		return
	# look mode
	if event.is_action_pressed("pause"):
		_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("station_left"):
		rig.call("step_station", 1)
	elif event.is_action_pressed("station_right"):
		rig.call("step_station", -1)
	elif event.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()
			get_viewport().set_input_as_handled()
			return
		var target: Variant = rig.get("hovered")
		if target != null and is_instance_valid(target):
			open_station(str((target as Node).get("station_id")))
			get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.call("open")


func _on_resumed() -> void:
	get_tree().paused = false
	if state == "look":
		_capture_mouse()


func _quit_to_menu() -> void:
	get_tree().paused = false
	if GameState.in_game:
		GameState.in_game = false
		TimeManager.stop_shift()
		ResourceManager.stop_day()
		EventManager.stop_day()
		MissionGenerator.stop_day()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------------------------------------------------------------- crises & attention

func _on_crisis_started(c: Dictionary) -> void:
	hud.get("crisis_banner").call("show_crisis", c)


func _on_crisis_ended(success: bool) -> void:
	hud.get("crisis_banner").call("hide_crisis", success)


func _process(delta: float) -> void:
	_attention_acc += delta
	if _attention_acc < 0.25:
		return
	_attention_acc = 0.0
	var mtype := MissionGenerator.active_type()
	var att := {
		"console": DialogueManager.has_pending() or mtype == "repair",
		"monitors": mtype == "navigation" or mtype == "repair",
		"board": not BoardManager.inbox().is_empty(),
		"window": not EventManager.current_visitor.is_empty(),
		"phone": not EventManager.fax_inbox.is_empty(),
	}
	for id in att.keys():
		room.call("set_attention", id, att[id])
	hud.set("attention", att)
	hud.set("current_station", current_station if state == "station" else str(rig.call("nearest_station_id")))
