class_name BossFlame
extends Node2D

## Boss projectile, passes through walls, hurts on touch, vanishes off screen
## or after 5 s. Kinds (boss variants per world, see boss.gd):
##   "flame" — straight fire breath (aimed at the hero when breathed)
##   "wave"  — sand shock wave hugging the arena floor (jump over it)
##   "ice"   — ice ball thrown in an arc that bounces along the floor

const FRAMES := preload("res://assets/graphics/boss_flame.tres")
const ICE := preload("res://assets/graphics/ice_ball.tres")

var velocity := Vector2(-110, 0)
var kind := "flame"
var floor_y := 0.0          # "ice": bounce height reference (arena floor)
var _bounces := 0
var _t := 0.0
var _sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 2
	_sprite = AnimatedSprite2D.new()
	if kind == "ice":
		_sprite.sprite_frames = ICE
		_sprite.play(&"spin")
	else:
		_sprite.sprite_frames = FRAMES
		_sprite.play(&"burn")
		_sprite.flip_h = velocity.x > 0.0     # art points left (flame tail right)
		_sprite.rotation = atan2(velocity.y, absf(velocity.x)) * (-1.0 if velocity.x < 0.0 else 1.0)
		if kind == "wave":
			_sprite.modulate = Color(1.25, 1.05, 0.6)
			_sprite.scale = Vector2(1.2, 0.8)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_t += delta
	if kind == "ice":
		velocity.y += 650.0 * delta
		if position.y >= floor_y - 7.0 and velocity.y > 0.0:
			position.y = floor_y - 7.0
			velocity.y = -absf(velocity.y) * 0.78
			_bounces += 1
			if _bounces > 4:
				queue_free()
				return
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
