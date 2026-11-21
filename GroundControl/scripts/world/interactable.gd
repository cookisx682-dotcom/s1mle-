extends StaticBody3D
## A clickable station in the room. When the player looks at it, its meshes get a glowing
## outline (material_overlay with shaders/outline.gdshader).

const OUTLINE_SHADER = preload("res://shaders/outline.gdshader")

static var _outline_material: ShaderMaterial = null

var station_id: String = ""
var label_text: String = ""
var meshes: Array = []
var _highlighted := false


static func outline_material() -> ShaderMaterial:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = OUTLINE_SHADER
	return _outline_material


func set_highlight(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	for m in meshes:
		if is_instance_valid(m) and m is GeometryInstance3D:
			(m as GeometryInstance3D).material_overlay = outline_material() if on else null
