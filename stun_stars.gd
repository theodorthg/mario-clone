class_name StunStars
extends Node2D

## Three little stars circling above a stunned boss's head (procedural).

var _t := 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var ink := Color(0.1, 0.06, 0.1)
	for i in 3:
		var a := _t * 4.5 + TAU * i / 3.0
		var p := Vector2(cos(a) * 20.0, sin(a) * 6.0).round()
		var front := sin(a) > 0.0
		var col := Color(1.0, 0.9, 0.25) if front else Color(1.0, 0.97, 0.65, 0.75)
		# 4-point star: dark outline first, then the fill
		draw_rect(Rect2(p - Vector2(2, 5), Vector2(4, 10)), ink)
		draw_rect(Rect2(p - Vector2(5, 2), Vector2(10, 4)), ink)
		draw_rect(Rect2(p - Vector2(1, 4), Vector2(2, 8)), col)
		draw_rect(Rect2(p - Vector2(4, 1), Vector2(8, 2)), col)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
