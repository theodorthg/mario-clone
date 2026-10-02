class_name Firebar
extends Node2D

## Rotating chain of fireballs around a hard block (castle hazard, grid 'F').
## Placed at the block centre; touching any ball hurts (a star protects).
## Cannot be destroyed. Speed / length / direction come from the level
## builder via the cell's column parity and the world number.

const FRAMES := preload("res://assets/graphics/fireball.tres")
const SPACING := 8.0

var balls := 6
var speed := 1.6          # radians per second, sign = direction
var angle := 0.0
var _sprites: Array[AnimatedSprite2D] = []

func _ready() -> void:
	z_index = 1
	for i in balls:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = FRAMES
		s.play(&"spin")
		s.frame = i % 4
		add_child(s)
		_sprites.append(s)
	_place()

func _physics_process(delta: float) -> void:
	angle = wrapf(angle + speed * delta, 0.0, TAU)
	_place()
	var game := Game.instance
	if game == null or game.target_for(global_position) == null or not game.is_near_view(global_position, 60.0):
		return
	var p: Player = game.target_for(global_position)
	if p.mode != Player.Mode.NORMAL or p.star_t > 0.0:
		return
	var center := p.global_position + Vector2(0, -7.0 if not p.is_big() else -14.0)
	var half := Vector2(5.0, 7.0 if not p.is_big() else 14.0)
	for s in _sprites:
		var d := (s.global_position - center).abs()
		if d.x < half.x + 3.0 and d.y < half.y + 3.0:
			p.hurt()
			return

func _place() -> void:
	var dir := Vector2.from_angle(angle)
	for i in _sprites.size():
		_sprites[i].position = dir * (i * SPACING)
