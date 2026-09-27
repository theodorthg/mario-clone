class_name BossFlame
extends Node2D

## Boss projectile, passes through walls, hurts on touch, vanishes off screen
## or after 5 s. Kinds (boss variants per world, see boss.gd):
##   "flame" — straight fire breath (aimed at the hero when breathed)
##   "wave"  — sand shock wave hugging the arena floor (jump over it)
##   "ice"   — ice ball thrown in an arc that bounces along the floor
##   "bolt"  — lightning: flashes in place for BOLT_WARN s, then strikes
##             straight down to the arena floor

const FRAMES := preload("res://assets/graphics/boss_flame.tres")
const ICE := preload("res://assets/graphics/ice_ball.tres")
const BOLT := preload("res://assets/graphics/bolt.tres")
const BOLT_WARN := 0.6

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
	elif kind == "bolt":
		_sprite.sprite_frames = BOLT
		_sprite.play(&"zap")
		_sprite.scale = Vector2(1.5, 1.5)
	else:
		_sprite.sprite_frames = FRAMES
		_sprite.play(&"burn")
		_sprite.flip_h = velocity.x > 0.0     # art points left (flame tail right)
		_sprite.rotation = atan2(velocity.y, absf(velocity.x)) * (-1.0 if velocity.x < 0.0 else 1.0)
		if kind == "wave":
			_sprite.modulate = Color(1.25, 1.05, 0.6)
			_sprite.scale = Vector2(1.2, 0.8)
	add_child(_sprite)

## The boss was hit: every projectile still flying vanishes in a puff.
func fizzle() -> void:
	var sp := Sparkle.new()
	sp.position = position
	get_parent().add_child(sp)
	queue_free()

func _physics_process(delta: float) -> void:
	_t += delta
	if kind == "bolt":
		if _t < BOLT_WARN:
			_sprite.visible = int(_t * 14.0) % 2 == 0
			return                     # warning flash: harmless
		_sprite.visible = true
		velocity = Vector2(0, 460.0)
		if position.y >= floor_y - 12.0:
			queue_free()
			return
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
	if game == null or _t > 5.0 or not game.is_near_view(global_position, 60.0):
		queue_free()
		return
	var p: Player = game.player
	if p == null or p.mode != Player.Mode.NORMAL or p.star_t > 0.0:
		return
	var center := p.global_position + Vector2(0, -7.0 if not p.is_big() else -14.0)
	var d := (global_position - center).abs()
	var reach := Vector2(8.0, 14.0) if kind == "bolt" else Vector2(12.0, 9.0)
	if d.x < reach.x and d.y < reach.y + (0.0 if not p.is_big() else 7.0):
		p.hurt()
		queue_free()
