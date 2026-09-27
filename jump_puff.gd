class_name JumpPuff
extends Node2D

## Little cloud puff under the hero's feet on a double jump (procedural,
## like Sparkle): two pixel clouds drift apart and fade.

const DURATION := 0.3

var _t := 0.0

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()

func _draw() -> void:
	var k := _t / DURATION
	var col := Color(1, 1, 1, 0.9 * (1.0 - k))
	var edge := Color(0.62, 0.7, 0.85, 0.9 * (1.0 - k))
	for side in [-1.0, 1.0]:
		var c := Vector2(side * (3.0 + k * 9.0), -1.0 - k * 2.0).round()
		var r := roundf(3.0 - k * 1.5)
		draw_rect(Rect2(c + Vector2(-r - 1, -r + 1), Vector2(2 * r + 2, 2 * r - 1)), edge)
		draw_rect(Rect2(c + Vector2(-r, -r), Vector2(2 * r, 2 * r)), col)
