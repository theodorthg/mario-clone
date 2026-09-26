class_name LavaBubble
extends Node2D

## Fire blob that leaps out of a lava pit (grid 'b', placed in the pit
## column): rises to `height` px above the lava, falls back, waits, repeats.
## Hurts on touch from any side (no stomping); only a star is safe.

const FRAMES := preload("res://assets/graphics/lava_bubble.tres")
const GRAVITY := 700.0

var height := 120.0
var delay := 0.0          # phase offset so neighbouring bubbles alternate
var _vy := 0.0
var _wait := 0.0
var _base_y := 0.0
var _sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 1
	_base_y = position.y
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	add_child(_sprite)
	_wait = 0.6 + delay
	visible = false

func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_vy = -sqrt(2.0 * GRAVITY * height)
			visible = true
		return
	_vy += GRAVITY * delta
	position.y += _vy * delta
	_sprite.flip_v = _vy > 0.0
	if position.y >= _base_y and _vy > 0.0:
		position.y = _base_y
		visible = false
		_wait = 1.8
		return
	var game := Game.instance
	if game == null or game.player == null:
		return
	var p: Player = game.player
	if p.mode != Player.Mode.NORMAL or p.star_t > 0.0:
		return
	var center := p.global_position + Vector2(0, -7.0 if not p.is_big() else -14.0)
	var d := (global_position - center).abs()
	if d.x < 11.0 and d.y < (13.0 if not p.is_big() else 20.0):
		p.hurt()
