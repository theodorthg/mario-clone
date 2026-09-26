class_name BossFlame
extends Node2D

## Boss fire breath: flies straight (aimed at the hero when breathed), passes
## through walls, hurts on touch, vanishes off screen or after 5 s.

const FRAMES := preload("res://assets/graphics/boss_flame.tres")

var velocity := Vector2(-110, 0)
var _t := 0.0
var _sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 2
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.play(&"burn")
	_sprite.flip_h = velocity.x > 0.0     # art points left (flame tail right)
	_sprite.rotation = atan2(velocity.y, absf(velocity.x)) * (-1.0 if velocity.x < 0.0 else 1.0)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	var game := Game.instance
	if game == null or _t > 5.0 or not game.is_near_view(global_position, 40.0):
		queue_free()
		return
	var p: Player = game.player
	if p == null or p.mode != Player.Mode.NORMAL or p.star_t > 0.0:
		return
	var center := p.global_position + Vector2(0, -7.0 if not p.is_big() else -14.0)
	var d := (global_position - center).abs()
	if d.x < 12.0 and d.y < (9.0 if not p.is_big() else 16.0):
		p.hurt()
		queue_free()
