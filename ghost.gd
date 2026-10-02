class_name Ghost
extends Node2D

## Ghost house ghost (grid 'l', v1.4). Floats after the hero — through walls
## — while the hero looks away, and freezes, shy (hands over its eyes, see-
## through), as soon as the hero faces it. Touching it hurts, stomping does
## not work and fireballs just fizzle on it (fire_hit); a star, a kicked
## shell or the dragon's tongue send it away.

const FRAMES := preload("res://assets/graphics/enemy_ghost.tres")
const SPEED := 30.0
const WAKE := 36.0               # starts once this close to the view

var dead := false
var active := false
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _shy := true
var _t := 0.0
var _boo_cd := 0.0
var _speed_mul := 1.0

func _ready() -> void:
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -9)
	sprite.play(&"shy")
	add_child(sprite)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 12)
	hs.shape = r
	hs.position = Vector2(0, -9)
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
		if not game.is_near_view(global_position, WAKE):
			return
		active = true
	_t += delta
	_boo_cd = maxf(_boo_cd - delta, 0.0)
	var to := p.global_position + Vector2(0, -10) - global_position
	# faced: the hero's facing points from the hero toward the ghost
	var faced := p.facing == (1 if global_position.x > p.global_position.x else -1)
	var shy := faced and p.mode == Player.Mode.NORMAL
	if shy != _shy:
		_shy = shy
		sprite.play(&"shy" if shy else &"chase")
		if not shy and _boo_cd <= 0.0:
			_boo_cd = 4.0
			_snd("ghost")
	if not shy and to.length() > 2.0:
		position += to.normalized() * SPEED * _speed_mul * delta
		sprite.flip_h = to.x > 0.0
	position.y += sin(_t * 3.0) * 0.12
	sprite.modulate.a = 0.5 if shy else 0.92
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

## Fireballs fizzle on a ghost (fireball.gd calls this first).
func fire_hit() -> void:
	pass

func kill_flip(from_x: float, award := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	sprite.play(&"flipped")
	_snd("ghost")
	if award and Game.instance:
		Game.instance.add_score(100, global_position)
	var d := 1.0 if global_position.x >= from_x else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(d * 30.0, -60.0), 0.9)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(queue_free)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
