class_name MagmaBlob
extends CharacterBody2D

## Magma blob (grid 'm', v1.5): a glowing blob that hops toward the hero.
## Stomped, it cools into a rock the hero can stand on (a step up to high
## ledges); after COOL s it glows and melts back into a blob — never while
## the hero stands on it. Lava is its element: blobs and rocks both rest on
## the lava surface, so a blob stomped over a lava pit leaves a floating
## stepping stone. Fire can't hurt it; a star, a kicked shell or the
## dragon's tongue finish it.

enum State { HOP, ROCK }

const FRAMES := preload("res://assets/graphics/enemy_magma.tres")
const GRAVITY := 1000.0
const HOP_V := -250.0
const HOP_X := 46.0
const COOL := 5.0
const GLOW := 1.2
const ROCK_H := 9.0

var state := State.HOP
var dead := false
var active := false
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _body_shape: CollisionShape2D
var _wait := 0.6
var _t := 0.0
var _safe_t := 0.0
var _speed_mul := 1.0
var _dir := -1
var _on_lava := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 3.0
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -6)
	sprite.animation = &"hop"
	add_child(sprite)
	_body_shape = CollisionShape2D.new()
	var br := RectangleShape2D.new()
	br.size = Vector2(12, 10)
	_body_shape.shape = br
	_body_shape.position = Vector2(0, -5)
	add_child(_body_shape)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(14, 11)
	hs.shape = hr
	hs.position = Vector2(0, -6)
	hitbox.add_child(hs)
	add_child(hitbox)
	if Game.instance:
		_speed_mul = Game.instance.enemy_speed_mul()

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := Game.instance
	if not active:
		if game == null or game.is_near_view(global_position, 40.0):
			active = true
		else:
			return
	_safe_t = maxf(_safe_t - delta, 0.0)
	var grounded := is_on_floor() or _on_lava
	if not _on_lava:
		velocity.y = minf(velocity.y + GRAVITY * delta, 340.0)
	if state == State.HOP:
		if grounded:
			velocity.x = 0.0
			_wait -= delta
			if _wait <= 0.0 and game and game.target_for(global_position):
				_dir = 1 if game.target_for(global_position).global_position.x > global_position.x else -1
				velocity = Vector2(_dir * HOP_X * _speed_mul, HOP_V)
				_wait = randf_range(0.6, 1.1) / _speed_mul
				_on_lava = false
		sprite.frame = 0 if grounded else 1
	else:
		velocity.x = 0.0
		_t += delta
		if _t > COOL - GLOW and sprite.animation != &"glow":
			sprite.play(&"glow")
		if _t >= COOL and not _hero_on_top():
			_melt()
	move_and_slide()
	_rest_on_lava()
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	if state == State.HOP and _safe_t <= 0.0:
		for b in hitbox.get_overlapping_bodies():
			if b is Player:
				_touch_player(b)
				break

## Lava is a floor for blobs and rocks: rest on its surface (1 px in).
func _rest_on_lava() -> void:
	var game := Game.instance
	if game == null or game.level == null or velocity.y < 0.0:
		_on_lava = false
		return
	var c := int(floorf(global_position.x / Level.T))
	var r := int(floorf((global_position.y - 1.0) / Level.T))
	if not (game.level.at(c, r) in ["L", "b"]):
		_on_lava = false
		return
	while game.level.at(c, r - 1) in ["L", "b"]:
		r -= 1
	global_position.y = r * Level.T + 1.0
	velocity.y = 0.0
	_on_lava = true

func _hero_on_top() -> bool:
	var game := Game.instance
	if game == null:
		return false
	for p in game.all_heroes():
		if absf(p.global_position.x - global_position.x) < 14.0 \
				and absf(p.global_position.y - (global_position.y - ROCK_H)) < 4.0:
			return true
	return false

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		Game.instance.award_chain(p, global_position)
		return
	if p.can_stomp(global_position.y - 11.0, 11.0):
		p.bounce()
		Game.instance.award_chain(p, global_position)
		_cool()
	else:
		p.hurt()

## Stomped: cools into a rock — solid ground (world layer) for a while.
func _cool() -> void:
	state = State.ROCK
	_t = 0.0
	velocity = Vector2.ZERO
	sprite.play(&"rock")
	var br := RectangleShape2D.new()
	br.size = Vector2(14, ROCK_H)
	_body_shape.set_deferred("shape", br)
	_body_shape.set_deferred("position", Vector2(0, -ROCK_H * 0.5))
	set_deferred("collision_layer", 1)
	_snd("harden")

func _melt() -> void:
	state = State.HOP
	_safe_t = 0.4
	_wait = 0.8
	sprite.animation = &"hop"
	sprite.stop()
	var br := RectangleShape2D.new()
	br.size = Vector2(12, 10)
	_body_shape.set_deferred("shape", br)
	_body_shape.set_deferred("position", Vector2(0, -5))
	set_deferred("collision_layer", 4)

## Fireballs just fizzle on magma (fireball.gd calls this first).
func fire_hit() -> void:
	pass

func kill_flip(from_x: float, award := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	sprite.play(&"flipped")
	sprite.flip_v = true
	_snd("kick")
	if award and Game.instance:
		Game.instance.add_score(100, global_position)
	var hop := 1.0 if global_position.x >= from_x else -1.0
	var y0 := position.y
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + hop * 40.0, 1.2)
	tw.tween_method(func(t: float): position.y = y0 - 180.0 * t + 450.0 * t * t, 0.0, 1.2, 1.2)
	tw.chain().tween_callback(queue_free)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
