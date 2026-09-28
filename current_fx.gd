class_name CurrentFx
extends Node2D

## Shows a water current (v1.3, level CURRENTS): faint streaks and tiny
## bubbles drifting in the flow direction across its rectangle. Drawn in
## front of the water layer so it also shows inside pools.

const SPEED := 46.0             # px/s, a little slower than the push itself
const GAP := Vector2(28, 12)

var rect := Rect2()
var dir := 1
var _t := 0.0

func _ready() -> void:
	z_index = 3
	position = rect.position

func _process(delta: float) -> void:
	if Game.instance and not Game.instance.is_near_view(global_position + rect.size * 0.5, rect.size.x * 0.5 + 20.0):
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var off := fposmod(_t * SPEED * dir, GAP.x)
	var rows := int(rect.size.y / GAP.y)
	for k in rows:
		var y := GAP.y * (k + 0.5)
		# every other row shifted so the streaks don't line up
		var x := off + (GAP.x * 0.5 if k % 2 == 1 else 0.0) - GAP.x
		while x < rect.size.x:
			if x >= 0.0 and x + 12.0 <= rect.size.x:
				var a := 0.5 + 0.15 * sin(_t * 3.0 + x * 0.1 + k)
				var yy := y + 1.5 * sin(_t * 4.0 + x * 0.2)
				draw_line(Vector2(x, yy), Vector2(x + 12.0, yy), Color(1, 1, 1, a), 1.0)
				# a brighter head in the flow direction + a bubble beside it
				var hx := x + 11.0 if dir > 0 else x
				draw_rect(Rect2(hx, yy - 0.5, 1, 1), Color(1, 1, 1, minf(a + 0.3, 1.0)))
				draw_rect(Rect2(x + 6.0, yy - 4.0, 2, 2), Color(0.85, 0.95, 1, a * 0.9))
			x += GAP.x
