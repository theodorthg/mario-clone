class_name Chomper
extends Node2D

## Biting plant living in a pipe (grid char 'Q' = pipe top-left with a
## plant). Cycle: hidden -> rises -> chomps -> sinks -> hidden. It stays down
## while the player stands right next to / on its pipe (the classic fairness
## rule). Hurts on touch; knocked out by fireball, star or dragon tongue.
## Drawn BEHIND the pipe tiles (z_index -1), so "hidden" really is hidden.

const FRAMES := preload("res://assets/graphics/chomper.tres")
const RISE := 26.0
const MOVE_TIME := 0.7
const UP_TIME := 1.4
const DOWN_TIME := 1.6

var pipe_top := Vector2.ZERO       # pipe mouth center, set by level.gd
var dead := false
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _t := 0.0
var _phase := 0                    # 0 down, 1 rising, 2 up, 3 sinking

func _ready() -> void:
	add_to_group("enemies")
	position = pipe_top + Vector2(0, RISE + 2.0)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -13)
	sprite.play(&"chomp")
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 20)
	sh.shape = r
	sh.position = Vector2(0, -12)
	hitbox.add_child(sh)
	add_child(hitbox)
	_t = randf_range(0.2, DOWN_TIME)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_t -= delta
	match _phase:
		0:
			if _t <= 0.0:
				var p := _player()
				if p and absf(p.global_position.x - pipe_top.x) < 26.0:
					_t = 0.4
				else:
					_phase = 1
					_t = MOVE_TIME
		1:
			position.y = pipe_top.y + 2.0 + RISE * clampf(_t / MOVE_TIME, 0.0, 1.0)
			if _t <= 0.0:
				_phase = 2
				_t = UP_TIME
		2:
			if _t <= 0.0:
				_phase = 3
				_t = MOVE_TIME
		3:
			position.y = pipe_top.y + 2.0 + RISE * (1.0 - clampf(_t / MOVE_TIME, 0.0, 1.0))
			if _t <= 0.0:
				_phase = 0
				_t = DOWN_TIME
	# only dangerous while at least partly above the pipe mouth
	if position.y < pipe_top.y + RISE - 4.0:
		for b in hitbox.get_overlapping_bodies():
			if b is Player:
				if b.star_t > 0.0:
					kill_flip(b.global_position.x)
				else:
					b.hurt()
				break

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] if not ps.is_empty() else null

func kill_flip(_from_x: float, _award := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play("kick")
	if Game.instance:
		Game.instance.add_score(200, global_position + Vector2(0, -20))
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
