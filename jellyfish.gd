class_name Jellyfish
extends Node2D

## Jellyfish (grid 'j'): sinks slowly, then pulses up toward the hero in a
## quick diagonal burst, again and again — keep your distance. Touching
## hurts; fireball, star or shell knock it out. Stays below the surface.

const FRAMES := preload("res://assets/graphics/enemy_jelly.tres")
const SINK := 1.1
const PULSE := 0.45

var dead := false
var active := false
var velocity := Vector2.ZERO
var _phase_t := 0.6
var _pulsing := false
var _speed_mul := 1.0
var sprite: AnimatedSprite2D
var hitbox: Area2D

func _ready() -> void:
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.play(&"drift")
	sprite.offset = Vector2(0, -7)
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 12)
	hs.shape = r
	hs.position = Vector2(0, -7)
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
		if not game.is_near_view(global_position, 0.0):
			return
		active = true
	_phase_t -= delta * _speed_mul
	if _phase_t <= 0.0:
		_pulsing = not _pulsing
		if _pulsing:
			_phase_t = PULSE
			var dx := signf(p.global_position.x - global_position.x)
			var up := -95.0 if p.global_position.y - 8.0 < global_position.y + 24.0 else -40.0
			velocity = Vector2(dx * 70.0, up) * _speed_mul
			sprite.play(&"pulse")
		else:
			_phase_t = SINK
			sprite.play(&"drift")
	if not _pulsing:
		velocity = velocity.move_toward(Vector2(0, 22.0), 160.0 * delta)
	position += velocity * delta
	position.y = clampf(position.y, Player.SWIM_TOP + 16.0, Level.ROWS * Level.T - 20.0)
	if not game.is_near_view(global_position, 260.0):
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
