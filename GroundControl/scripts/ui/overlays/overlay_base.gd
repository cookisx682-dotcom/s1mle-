extends Control
## Base for station overlays (the zoomed-in UI of a station).
## Content is built inside a low-resolution SubViewport (half of the window) and scaled up
## with nearest filtering → chunky pixel look. Screen-type stations add the CRT shader.
## Subclasses override _build(), _on_open() and _on_close().

signal close_requested

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const CRT_CANVAS = preload("res://shaders/crt_canvas.gdshader")

var use_crt := false
var crt_tint := Color(1, 1, 1, 1)
var dim_alpha := 0.35

var container: SubViewportContainer
var viewport: SubViewport
var root: Control
var _crt_mat: ShaderMaterial


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	viewport.add_child(root)

	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = CRT_CANVAS
	_crt_mat.set_shader_parameter("tint", crt_tint)
	SaveSystem.settings_changed.connect(_apply_crt)
	_apply_crt()
	_build()


func _apply_crt() -> void:
	container.material = _crt_mat if (use_crt and bool(SaveSystem.get_setting("crt_enabled", true))) else null


func open() -> void:
	visible = true
	_on_open()


func close() -> void:
	if not visible:
		return
	visible = false
	_on_close()


func is_open() -> bool:
	return visible


# virtual
func _build() -> void:
	pass


func _on_open() -> void:
	pass


func _on_close() -> void:
	pass


## Creates the framed window that holds the station UI.
## region: "full", "bottom" (lower ~45%, keeps the 3D scene visible) or "center".
## style: "screen" (dark terminal) or "paper" (fax / printout).
func make_window(title: String, region: String = "full", style: String = "screen") -> VBoxContainer:
	var panel := PanelContainer.new()
	var paper := style == "paper"
	var bg := UiTheme.COL_PAPER if paper else Color(0.02, 0.05, 0.1, 0.95)
	var border := Color("8c826a") if paper else UiTheme.COL_CYAN.darkened(0.25)
	panel.add_theme_stylebox_override("panel", UiTheme.box(bg, border, 2, 8))
	match region:
		"bottom":
			panel.anchor_left = 0.0
			panel.anchor_right = 1.0
			panel.anchor_top = 0.56
			panel.anchor_bottom = 1.0
			panel.offset_left = 10
			panel.offset_right = -10
			panel.offset_top = 0
			panel.offset_bottom = -10
		"center":
			panel.anchor_left = 0.15
			panel.anchor_right = 0.85
			panel.anchor_top = 0.08
			panel.anchor_bottom = 0.92
		_:
			panel.set_anchors_preset(Control.PRESET_FULL_RECT)
			panel.offset_left = 8
			panel.offset_right = -8
			panel.offset_top = 8
			panel.offset_bottom = -8
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	var title_col := UiTheme.COL_INK if paper else UiTheme.COL_CYAN
	var t := UiTheme.label(title, 13, title_col)
	t.add_theme_font_override("font", UiTheme.mono_font_bold())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var back := Button.new()
	back.text = "BACK [ESC]"
	back.add_theme_font_size_override("font_size", 11)
	back.pressed.connect(func(): close_requested.emit())
	header.add_child(back)

	var sep := ColorRect.new()
	sep.color = Color(title_col, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	v.add_child(body)
	return body


## Small titled frame for sub-sections.
func make_section(parent: Control, title: String, color: Color = UiTheme.COL_CYAN) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.35), color.darkened(0.5), 1, 5))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	v.add_child(UiTheme.label(title, 11, color))
	return v
