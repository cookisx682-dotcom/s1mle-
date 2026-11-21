extends Control
## Base for the custom-drawn CRT screens. The same class draws the small 3D monitors in the
## room (interactive = false) and the large versions in the station overlays (interactive = true).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var interactive := false
var on_screen := true          # false while the owning overlay is closed
var refresh_rate := 10.0
var t := 0.0
var _acc := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc >= 1.0 / refresh_rate:
		_acc = 0.0
		queue_redraw()


func font_px() -> int:
	return int(clampf(size.y / 10.0, 9.0, 13.0))


func text(pos: Vector2, s: String, color: Color, fs: int = -1) -> void:
	draw_string(UiTheme.mono_font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs if fs > 0 else font_px(), color)


func blink(speed: float = 2.0) -> bool:
	return fmod(t * speed, 1.0) < 0.5
