class_name Flagpole
extends Node2D

## Goal pole. Origin = top of the base block (pole center x). The pole is
## POLE_SEGMENTS tiles tall with a ball on top and the flag hanging on its
## left near the top. Touching it ends the level; the contact height decides
## the bonus (see points_for_height()).

const POLE_SEGMENTS := 9
const HEIGHT := POLE_SEGMENTS * 16.0

var decor_tex: Texture2D
var flag: Sprite2D
var _area: Area2D
var _done := false

func _ready() -> void:
	z_index = -1
	for i in POLE_SEGMENTS:
		_add_sprite("pole", Vector2(-2, -16.0 * (i + 1)))
	_add_sprite("pole_ball", Vector2(-4, -HEIGHT - 7))
	flag = _add_sprite("flag", Vector2(-17, -HEIGHT + 4))
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, HEIGHT)
	sh.shape = r
	sh.position = Vector2(0, -HEIGHT * 0.5)
	_area.add_child(sh)
	add_child(_area)
	_area.body_entered.connect(_on_body)

func _add_sprite(name: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = decor_tex
	at.region = DecorIndex.RECTS[name]
	s.texture = at
	s.centered = false
	s.position = pos
	add_child(s)
	return s

func _on_body(b: Node) -> void:
	if _done or not (b is Player):
		return
	_done = true
	if Game.instance:
		Game.instance.flag_reached(self, b)

## Height above the base block's top, in px -> bonus points (classic table).
static func points_for_height(h: float) -> int:
	if h >= 128.0:
		return 5000
	if h >= 96.0:
		return 2000
	if h >= 64.0:
		return 800
	if h >= 32.0:
		return 400
	return 100

func lower_flag(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(flag, "position:y", -16.0 - 15.0, duration)
