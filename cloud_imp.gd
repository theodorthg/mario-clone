class_name CloudImp
extends Node2D

## Cloud imp (grid 'u', place it high up): rides its cloud above the hero,
## keeps pace with them and every few seconds throws a spiky ball that
## becomes a Spiky walker when it lands (at most MAX_SPIKIES at a time).
## Stomp it — it floats high, a double jump or a high ledge helps — or hit
## it with a fireball / star / shell. After ZONE px past its spawn point
## (or when the hero turns back far) it gives up and floats away.

const FRAMES := preload("res://assets/graphics/enemy_imp.tres")
const ZONE := 110.0 * 16.0
const THROW_EVERY := 3.4
const MAX_SPIKIES := 3

var dead := false
var active := false
var _home := Vector2.ZERO
var _t := 0.0
var _throw_t := 2.2
var _leaving := false
var _spikies: Array = []
var _speed_mul := 1.0
var sprite: AnimatedSprite2D
var hitbox: Area2D

func _ready() -> void:
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.play(&"idle")
	sprite.offset = Vector2(0, -14)       # origin = bottom of the cloud
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 22)
	hs.shape = r
	hs.position = Vector2(0, -12)
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
	if not active:
		if not game.is_near_view(global_position, 16.0):
			return
		active = true
		_home = global_position
	_t += delta
	if not _leaving and (p.global_position.x > _home.x + ZONE or p.global_position.x < _home.x - 420.0):
		_leaving = true
	if _leaving:
		position += Vector2(-50.0, -80.0) * delta
		if not game.is_near_view(global_position, 60.0):
			queue_free()
		return
	# hover ahead of the hero, swinging to and fro
	var target_x := p.global_position.x + sin(_t * 0.9) * 72.0 + p.velocity.x * 0.45
	var vx := clampf((target_x - global_position.x) * 2.2, -150.0, 150.0) * _speed_mul
	position.x += vx * delta
	position.y = _home.y + sin(_t * 2.0) * 3.0
	sprite.flip_h = p.global_position.x < global_position.x
	_throw_t -= delta
	_spikies = _spikies.filter(func(s): return is_instance_valid(s) and not s.dead)
	if _throw_t <= 0.0 and _spikies.size() < MAX_SPIKIES and game.is_near_view(global_position, 0.0) \
			and p.mode == Player.Mode.NORMAL:
		_throw(p)
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

func _throw(p: Player) -> void:
	_throw_t = THROW_EVERY / _speed_mul
	sprite.play(&"throw")
	get_tree().create_timer(0.4, false).timeout.connect(func():
		if not dead:
			sprite.play(&"idle"))
	var s := Spiky.new()
	s.from_sky = true
	s.position = position + Vector2(8.0 if not sprite.flip_h else -8.0, -22.0)
	s.velocity = Vector2(signf(p.global_position.x - global_position.x) * 45.0, -170.0)
	get_parent().add_child(s)
	_spikies.append(s)

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		Game.instance.award_chain(p, global_position)
		return
	var prev_feet := p.global_position.y - p.velocity.y * get_physics_process_delta_time()
	if p.velocity.y > 0.0 and prev_feet <= global_position.y - 16.0:
		p.bounce()
		Game.instance.award_chain(p, global_position)
		_snd("stomp")
		kill_flip(p.global_position.x)
	else:
		p.hurt()

## Fireball: fireball.gd tries fire_hit() first, then kill_flip().
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
		Game.instance.add_score(1000, global_position)
	var d := 1.0 if global_position.x >= from_x else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + d * 30.0, 1.2)
	tw.tween_property(self, "position:y", position.y + 320.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(queue_free)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
