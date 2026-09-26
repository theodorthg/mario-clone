class_name WarpZone
extends Area2D

## Enterable pipe mouth. "down": origin = pipe top center, the player must
## stand on the pipe (within a few px of its center) and hold down.
## "right": origin = side mouth at floor level, the player walks into it.

var kind := "down"
var warp := {}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	if kind == "down":
		r.size = Vector2(14, 6)
		sh.position = Vector2(0, -3)
	else:
		r.size = Vector2(6, 26)
		sh.position = Vector2(-3, -13)
	sh.shape = r
	add_child(sh)

func _physics_process(_delta: float) -> void:
	if Game.instance == null:
		return
	for b in get_overlapping_bodies():
		if not (b is Player):
			continue
		var p: Player = b
		if p.mode != Player.Mode.NORMAL or not p.input_enabled or not p.is_on_floor():
			continue
		if kind == "down":
			if Input.is_action_pressed("move_down") and absf(p.global_position.x - global_position.x) <= 9.0:
				Game.instance.enter_warp(self)
		elif Input.is_action_pressed("move_right"):
			Game.instance.enter_warp(self)
