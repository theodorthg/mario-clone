class_name Bat
extends Node2D

## Cave bat (grid 'a', placed right under the ceiling). Sleeps upside down
## until the hero passes below it, then swoops down at the hero's height and
## flies on sideways with a wavy flight. Flies through walls. Stomp, fireball,
## star, shell, tongue or a block from below knock it out.

const FRAMES := preload("res://assets/graphics/enemy_bat.tres")

var dead := false
var velocity := Vector2.ZERO
var _state := 0           # 0 hang, 1 dive, 2 fly
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
			if absf(dx) < 72.0 and p.global_position.y > global_position.y + 24.0 \
					and game.is_near_view(global_position, 0.0):
				_state = 1
				_target_y = p.global_position.y - 10.0
				velocity = Vector2(signf(dx) * 55.0, 150.0) * _speed_mul
				sprite.play(&"fly")
				_snd("tongue")
		1:
			# swoop down, easing out right at the hero's height
			velocity.y = clampf((_target_y - global_position.y) * 3.0, 0.0, 190.0 * _speed_mul)
			if _target_y - global_position.y < 3.0:
				_state = 2
				velocity = Vector2(signf(velocity.x if velocity.x != 0.0 else 1.0) * 80.0 * _speed_mul, 0.0)
		2:
			_t += delta
			velocity.y = sin(_t * 6.0) * 30.0
			if not game.is_near_view(global_position, 160.0):
				queue_free()
				return
	position += velocity * delta
	sprite.flip_h = velocity.x < 0.0
	if _state == 0:
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
	var prev_feet := p.global_position.y - p.velocity.y * get_physics_process_delta_time()
	if p.velocity.y > 0.0 and prev_feet <= global_position.y + 6.0:
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
