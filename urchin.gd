class_name Urchin
extends Node2D

## Sea urchin (grid 'i'): sits still, its spines hurt on touch — nothing
## knocks it out (not an "enemies" member, no kill_flip()), swim around it.
## With a star the hero just passes through.

const FRAMES := preload("res://assets/graphics/enemy_urchin.tres")

var hitbox: Area2D
var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.play(&"idle")
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := CircleShape2D.new()
	r.radius = 6.5
	hs.shape = r
	hs.position = Vector2(0, -8)
	hitbox.add_child(hs)
	add_child(hitbox)
	_base_y = position.y
	_t = fmod(position.x * 0.013, TAU)

func _physics_process(delta: float) -> void:
	_t += delta
	position.y = _base_y + roundf(sin(_t * 1.6) * 1.5)
	for b in hitbox.get_overlapping_bodies():
		if b is Player and b.mode == Player.Mode.NORMAL and b.star_t <= 0.0:
			b.hurt()
			break
