class_name TipPlatform
extends AnimatableBody2D

## 4-tile wooden plank balanced on a pivot in its middle (grid 'T', top-left
## at the cell like the lifts). Standing off-centre tips it toward that side
## — the further out, the faster; past ~45° the hero slides off. Levels out
## again when nobody stands on it. One-way from below.

const TEX := preload("res://assets/graphics/tipper.png")
const W := 64.0
const MAX_ANGLE := deg_to_rad(75.0)        # > 45° floor limit: the hero slides off
const TIP_SPEED := deg_to_rad(50.0)       # at the very end of the plank
const RETURN_SPEED := deg_to_rad(30.0)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	position += Vector2(W * 0.5, 0.0)       # the node sits on the pivot
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W, 5)
	sh.shape = r
	sh.position = Vector2(0, 2.5)
	sh.one_way_collision = true
	add_child(sh)
	var s := Sprite2D.new()
	s.texture = TEX
	s.position = Vector2(0, 2.5)
	add_child(s)

func _physics_process(delta: float) -> void:
	var off := 0.0
	var on := false
	var game := Game.instance
	# "standing on it" by position, not is_on_floor(): on a steep plank the
	# hero stops counting as grounded, but it must keep tipping until they
	# slide off (else it settles right at the 45° floor limit)
	# (co-op: both heroes' weight adds up)
	for p in (game.all_heroes() if game else []):
		if p.mode != Player.Mode.NORMAL or p.velocity.y <= -20.0:
			continue
		var local := to_local(p.global_position)
		# (on a slope the box corner touches, so the feet hover up to ~8 px above)
		if local.y > -10.0 and local.y < 6.0 and absf(local.x) < W * 0.5 + 4.0:
			on = true
			off = clampf(off + local.x / (W * 0.5), -1.0, 1.0)
	if on:
		rotation = move_toward(rotation, off * MAX_ANGLE, (TIP_SPEED * absf(off) + deg_to_rad(4.0)) * delta)
	else:
		rotation = move_toward(rotation, 0.0, RETURN_SPEED * delta)
