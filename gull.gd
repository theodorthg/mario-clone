class_name Gull
extends Node2D

## Seagull (grid 'y'): once it comes into view it glides toward the hero's
## side with a gentle wave and keeps going until it leaves the screen.
## Stomp it (bounce!); fireball, star, shell or tongue knock it out.

const FRAMES := preload("res://assets/graphics/enemy_gull.tres")
const SPEED := 72.0

var dead := false
var active := false
var dir := -1.0
var _t := 0.0
var _y0 := 0.0
var _speed_mul := 1.0
var sprite: AnimatedSprite2D
var hitbox: Area2D

func _ready() -> void:
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.play(&"fly")
	sprite.offset = Vector2(0, -6)
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 8)
	hs.shape = r
	hs.position = Vector2(0, -6)
	hitbox.add_child(hs)
	add_child(hitbox)
	if Game.instance:
		_speed_mul = Game.instance.enemy_speed_mul()

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := Game.instance
	if game == null or game.target_for(global_position) == null:
		return
	if not active:
		if not game.is_near_view(global_position, 8.0):
			return
		active = true
		_y0 = position.y
		dir = -1.0 if game.target_for(global_position).global_position.x < global_position.x else 1.0
	_t += delta
	position.x += dir * SPEED * _speed_mul * delta
	position.y = _y0 + sin(_t * 3.0) * 10.0
	sprite.flip_h = dir > 0.0            # art faces left
	if _t > 1.0 and not game.is_near_view(global_position, 60.0):
		queue_free()
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
	if p.can_stomp(global_position.y - 10.0, 8.0):
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
	var d := 1.0 if global_position.x >= from_x else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + d * 30.0, 1.0)
	tw.tween_property(self, "position:y", position.y + 260.0, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(queue_free)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
