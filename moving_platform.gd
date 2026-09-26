class_name MovingPlatform
extends AnimatableBody2D

## 3-tile lift (grid '~' = moves sideways, '^' = moves up and down), placed
## with its top-left at the grid cell. Travels `travel` px and back on a
## smooth sine in `period` s. One-way from below (jump up through it);
## sync_to_physics carries the hero / enemies standing on it.

const TEX := preload("res://assets/graphics/lift.png")
const W := 48.0

var axis := Vector2.RIGHT
var travel := 64.0
var period := 3.6
var phase := 0.0
var _origin := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_origin = position
	_t = phase * period
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W, 5)
	sh.shape = r
	sh.position = Vector2(W * 0.5, 2.5)
	sh.one_way_collision = true
	add_child(sh)
	var s := Sprite2D.new()
	s.texture = TEX
	s.centered = false
	s.position = Vector2(-1, -1)
	add_child(s)
	_apply()

func _physics_process(delta: float) -> void:
	_t += delta
	_apply()

func _apply() -> void:
	var k := 0.5 - 0.5 * cos(TAU * _t / period)
	position = (_origin + axis * travel * k).round()
