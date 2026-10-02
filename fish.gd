class_name Fish
extends Node2D

## Fish (grid 'e' = slow yellow fish swimming in waves, 'E' = fast red fish
## that darts at the hero's depth). Once in view it swims toward the hero's
## side and keeps going until it leaves the screen. Touching hurts (no
## stomping while swimming); fireball, star or shell knock it out.

const FRAMES_Y := preload("res://assets/graphics/enemy_fish.tres")
const FRAMES_R := preload("res://assets/graphics/enemy_fish_red.tres")

var fast := false
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
	sprite.sprite_frames = FRAMES_R if fast else FRAMES_Y
	sprite.play(&"swim")
	sprite.offset = Vector2(0, -5)
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 7)
	hs.shape = r
	hs.position = Vector2(0, -5)
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
	var p: Player = game.target_for(global_position)
	if not active:
		if not game.is_near_view(global_position, 8.0):
			return
		active = true
		_y0 = position.y
		dir = -1.0 if p.global_position.x < global_position.x else 1.0
	_t += delta
	if fast:
		position.x += dir * 92.0 * _speed_mul * delta
		# homes in on the hero's depth a little while it is still ahead
		if (p.global_position.x - global_position.x) * dir > 0.0:
			position.y = move_toward(position.y, p.global_position.y - 6.0, 24.0 * delta)
	else:
		position.x += dir * 34.0 * _speed_mul * delta
		position.y = _y0 + sin(_t * 2.2) * 12.0
	sprite.flip_h = dir > 0.0            # art faces left
	if _t > 1.0 and not game.is_near_view(global_position, 80.0):
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
	tw.tween_property(self, "position:x", position.x + d * 24.0, 1.4)
	tw.tween_property(self, "position:y", position.y + 200.0, 1.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(queue_free)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
