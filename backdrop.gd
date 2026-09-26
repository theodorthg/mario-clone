class_name Backdrop
extends Node2D

## Themed background: a screen-filling sky (CanvasLayer -100 + sky.gdshader)
## plus horizontally repeating parallax layers.
##
## Each layer is ONE Sprite2D kept glued to the camera's left edge; its
## texture region scrolls by (camera x * factor), with texture_repeat on, so
## it appears to move `factor` times as fast as the world and repeats
## forever without seams (the art in tools/gen_backgrounds.py tiles at 640px).
## Vertically the layer sits at a world y and follows the camera by
## (1 - vfactor), so far layers barely move up/down.

const THEMES := {
	"grass": {
		"sky": [Color("3b6bd6"), Color("73acf0"), Color("d8eefa"), 0.55],
		"layers": [
			# texture, world y of top edge, x factor, y factor, autoscroll px/s
			["res://assets/graphics/bg_clouds.png", 26.0, 0.12, 0.1, 5.0],
			["res://assets/graphics/bg_mountains.png", 72.0, 0.18, 0.35, 0.0],
			["res://assets/graphics/bg_hills_far.png", 150.0, 0.32, 0.6, 0.0],
			["res://assets/graphics/bg_hills_near.png", 178.0, 0.48, 0.75, 0.0],
			["res://assets/graphics/bg_trees.png", 196.0, 0.66, 0.9, 0.0],
		],
	},
	"cave": {
		"sky": [Color("05060d"), Color("0c1024"), Color("1a2140"), 0.5],
		"layers": [],
	},
}
const REF_CAM_Y := 185.0

var camera: Camera2D
var _sky_layer: CanvasLayer
var _sky: ColorRect
var _layers: Array = []    # [{sprite, y, fx, fy, auto}]
var _time := 0.0
var theme := ""

func _ready() -> void:
	z_index = -50
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -100
	add_child(_sky_layer)
	_sky = ColorRect.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/ui/sky.gdshader")
	_sky.material = mat
	_sky_layer.add_child(_sky)

func set_theme(name: String) -> void:
	if name == theme:
		return
	theme = name
	var th: Dictionary = THEMES.get(name, THEMES["grass"])
	var mat: ShaderMaterial = _sky.material
	mat.set_shader_parameter("top_color", th.sky[0])
	mat.set_shader_parameter("mid_color", th.sky[1])
	mat.set_shader_parameter("horizon_color", th.sky[2])
	mat.set_shader_parameter("mid_pos", th.sky[3])
	for l in _layers:
		l.sprite.queue_free()
	_layers.clear()
	for spec in th.layers:
		var s := Sprite2D.new()
		s.texture = load(spec[0])
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		add_child(s)
		_layers.append({"sprite": s, "y": spec[1], "fx": spec[2], "fy": spec[3], "auto": spec[4]})
	_process(0.0)

func _process(delta: float) -> void:
	_time += delta
	if camera == null:
		return
	var view := get_viewport_rect().size
	var cam := camera.get_screen_center_position()
	var left := cam.x - view.x * 0.5
	for l in _layers:
		var s: Sprite2D = l.sprite
		var h: float = s.texture.get_height()
		var ox: float = left * l.fx + _time * l.auto
		s.region_rect = Rect2(roundf(ox), 0.0, view.x + 2.0, h)
		s.global_position = Vector2(roundf(left) - 1.0, roundf(l.y + (cam.y - REF_CAM_Y) * (1.0 - l.fy)))
