class_name Sparkle
extends Node2D

## Four-point twinkle drawn procedurally (coin pickup, egg hatch, ...).

var _t := 0.0
const DURATION := 0.3

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()

func _draw() -> void:
	var k := _t / DURATION
	var r := 2.0 + k * 7.0
	var col := Color(1, 1, 0.8, 1.0 - k)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_rect(Rect2((d * r).round() - Vector2(1, 1), Vector2(2, 2)), col)
	draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), Color(1, 1, 1, 1.0 - k))
