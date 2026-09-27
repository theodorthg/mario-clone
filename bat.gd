class_name Bat
extends Node2D

## Cave bat (grid 'a', placed right under the ceiling). Sleeps upside down
## until the hero comes near below it, flutters in place for WARN s (warning
## squeak), then swoops down and flies on sideways with a wavy flight.
## Fair by design (v0.14, player feedback): it wakes only well inside the
## screen, and it levels out at FLY_H above the floor the hero stands on —
## a small hero walks underneath, a big one ducks (or jumps / stomps).
## Flies through walls. Stomp, fireball, star, shell, tongue or a block from
## below knock it out.

const FRAMES := preload("res://assets/graphics/enemy_bat.tres")
const WARN := 0.5
const FLY_H := 28.0          # origin above the hero's feet (hitbox 20-28 px up)

var dead := false
var velocity := Vector2.ZERO
var _state := 0           # 0 hang, 1 dive, 2 fly, 3 waking (warning)
var _target_y := 0.0
var _t := 0.0
var _speed_mul := 1.0
var sprite: AnimatedSprite2D
var hitbox: Area2D

func _ready() -> void:
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.play(&"hang")
	sprite.offset = Vector2(0, 6)       # origin = the ceiling point it hangs from
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 8)
	hs.shape = r
	hs.position = Vector2(0, 6)
	hitbox.add_child(hs)
	add_child(hitbox)
	if Game.instance:
		_speed_mul = Game.instance.enemy_speed_mul()

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := Game.instance
	if game == null or game.player == null:
		return
	var p: Player = game.player
	match _state:
		0:
			var dx := p.global_position.x - global_position.x
			if absf(dx) < 96.0 and p.global_position.y > global_position.y + 24.0 \
					and game.is_near_view(global_position, -24.0):
				_state = 3
				_t = 0.0
				sprite.play(&"fly")
				_snd("tongue")
		3:
			# warning: flutter in place, then dive toward where the hero is
			_t += delta
			sprite.position.x = 1.0 if int(_t * 24.0) % 2 == 0 else -1.0
			if _t >= WARN:
				sprite.position.x = 0.0
				_state = 1
				_t = 0.0
				var dx := p.global_position.x - global_position.x
				_target_y = p.global_position.y - FLY_H
				velocity = Vector2(signf(dx if dx != 0.0 else 1.0) * 45.0, 130.0) * _speed_mul
		1:
			# swoop down, easing out at the flight height
			velocity.y = clampf((_target_y - global_position.y) * 4.0, 0.0, 140.0 * _speed_mul)
			if _target_y - global_position.y < 3.0:
				_state = 2
				velocity = Vector2(signf(velocity.x if velocity.x != 0.0 else 1.0) * 70.0 * _speed_mul, 0.0)
		2:
			_t += delta
			velocity.y = sin(_t * 6.0) * 30.0
			if not game.is_near_view(global_position, 160.0):
				queue_free()
				return
	position += velocity * delta
	sprite.flip_h = velocity.x < 0.0
	if _state == 0 or _state == 3:
		return
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		Game.instance.award_chain(p, global_position)
		return
	if p.can_stomp(global_position.y + 2.0, 8.0):
		p.bounce()
		Game.instance.award_chain(p, global_position)
		_snd("stomp")
		kill_flip(p.global_position.x)
	else:
		p.hurt()

func kill_flip(from_x: float, award := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	sprite.play(&"flipped")
	sprite.flip_v = true
	_snd("kick")
	if award and Game.instance:
		Game.instance.add_score(100, global_position)
	var dir := 1.0 if global_position.x >= from_x else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + dir * 30.0, 1.0)
	tw.tween_property(self, "position:y", position.y + 260.0, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(queue_free)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
