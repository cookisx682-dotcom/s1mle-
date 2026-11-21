extends Control
## Main menu: blurred control room in the background, pixel title with a cyan glow,
## New Game / Continue / Achievements / Settings / Quit.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControlRoom = preload("res://scripts/world/control_room.gd")
const CameraRig = preload("res://scripts/world/camera_rig.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const AchievementsPanel = preload("res://scripts/ui/achievements_panel.gd")
const BLUR_SHADER = preload("res://shaders/blur.gdshader")
const GAME_SCENE := "res://scenes/game.tscn"

var settings_panel: Control
var achievements_panel: Control
var continue_btn: Button
var confirm: ConfirmationDialog
var title_settings: LabelSettings
var _t := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_background()
	_build_menu()
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	achievements_panel = AchievementsPanel.new()
	add_child(achievements_panel)
	confirm = ConfirmationDialog.new()
	confirm.title = "NEW GAME"
	confirm.dialog_text = "Start a new game?\nYour story progress will be lost (achievements are kept)."
	confirm.confirmed.connect(_start_new)
	add_child(confirm)
	AudioManager.play_ambience("room_tone")
	AudioManager.play_music("menu_theme")


func _build_background() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 180)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var room := ControlRoom.new()
	room.menu_mode = true
	vp.add_child(room)
	var rig := CameraRig.new()
	rig.position = ControlRoom.EYE
	rig.cinematic = true
	vp.add_child(rig)
	var bg := TextureRect.new()
	bg.texture = vp.get_texture()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = BLUR_SHADER
	bg.material = m
	add_child(bg)


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	# pixel title: rendered small in its own viewport, then scaled up with nearest filtering
	var tvp := SubViewport.new()
	tvp.size = Vector2i(320, 52)
	tvp.transparent_bg = true
	tvp.disable_3d = true
	tvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(tvp)
	var tl := Label.new()
	tl.text = "GROUND CONTROL"
	title_settings = LabelSettings.new()
	title_settings.font = UiTheme.mono_font_bold()
	title_settings.font_size = 30
	title_settings.font_color = UiTheme.COL_CYAN
	title_settings.outline_size = 2
	title_settings.outline_color = Color("0b1428")
	title_settings.shadow_color = Color(UiTheme.COL_CYAN, 0.35)
	title_settings.shadow_size = 7
	title_settings.shadow_offset = Vector2.ZERO
	tl.label_settings = title_settings
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size = Vector2(320, 52)
	tvp.add_child(tl)
	var title := TextureRect.new()
	title.texture = tvp.get_texture()
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(960, 156)
	v.add_child(title)

	var sub := UiTheme.label("1969  ·  ·  ·  2069", 22, UiTheme.COL_VIOLET)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	v.add_child(spacer)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.custom_minimum_size = Vector2(300, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(buttons)
	_button(buttons, "NEW GAME", _on_new_game)
	continue_btn = _button(buttons, "CONTINUE", _on_continue)
	continue_btn.disabled = not SaveSystem.has_progress()
	if SaveSystem.has_progress():
		var p := SaveSystem.get_progress()
		var day_no := int(p.get("day_index", 0)) + 1
		continue_btn.text = "CONTINUE  (SHIFT %d)" % day_no
	_button(buttons, "ACHIEVEMENTS", func(): achievements_panel.call("open"))
	_button(buttons, "SETTINGS", func(): settings_panel.call("open"))
	_button(buttons, "QUIT", func(): get_tree().quit())

	var footer := UiTheme.label("DEMO v0.1 · DECADE I (1969–1972) · ESC closes panels", 12, UiTheme.COL_DIM)
	footer.anchor_left = 0.0
	footer.anchor_right = 1.0
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -34
	footer.offset_bottom = -12
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		cb.call()
	)
	b.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover"))
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	if title_settings != null:
		title_settings.shadow_color = Color(UiTheme.COL_CYAN, 0.25 + 0.15 * sin(_t * 2.2))


func _on_new_game() -> void:
	if SaveSystem.has_progress():
		confirm.popup_centered()
	else:
		_start_new()


func _start_new() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	if not SaveSystem.has_progress():
		return
	GameState.load_snapshot(SaveSystem.get_progress())
	get_tree().change_scene_to_file(GAME_SCENE)
