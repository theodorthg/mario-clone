class_name Shroom
extends CharacterBody2D

## Walking angry-mushroom enemy (goomba role). Origin = feet.
## - wakes up only once it gets near the camera view (classic "spawn when
##   on-screen"), so a long level doesn't start with every enemy marching
## - walks off ledges, turns at walls and when bumping into another enemy
## - stomped -> squish; fireball / star / block bump / dragon tongue -> flip
## - `winged` variant hops along; the first stomp only tears the wings off
##   (it becomes a plain walker), like the classic winged enemies.

const FRAMES := preload("res://assets/graphics/enemy_shroom.tres")
const GRAVITY := 1100.0
const BASE_SPEED := 32.0

var dir := -1
var speed := BASE_SPEED
var winged := false
var _hop_wait := 0.0
var active := false
var dead := false
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _turn_cd := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 3.0
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -9)
	sprite.play(&"fly" if winged else &"walk")
	add_child(sprite)
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 14)
	sh.shape = r
	sh.position = Vector2(0, -7)
	add_child(sh)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2 | 4
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(14, 13)
	hs.shape = hr
	hs.position = Vector2(0, -7)
	hitbox.add_child(hs)
	add_child(hitbox)
	hitbox.area_entered.connect(_on_area)
	if Game.instance:
		speed = BASE_SPEED * Game.instance.enemy_speed_mul()

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not active:
		var game := Game.instance
		if game == null or game.is_near_view(global_position, 40.0):
			active = true
		else:
			return
	_turn_cd = maxf(_turn_cd - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * (0.7 if winged else 1.0) * delta, 320.0)
	velocity.x = dir * speed
	if winged and is_on_floor():
		_hop_wait -= delta
		if _hop_wait <= 0.0:
			velocity.y = -250.0
			_hop_wait = 0.35
	move_and_slide()
	if is_on_wall():
		dir = -dir
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

func _on_area(a: Area2D) -> void:
	var other := a.get_parent()
	if other != self and other is Shroom and not other.dead and not dead and _turn_cd <= 0.0:
		dir = 1 if global_position.x > other.global_position.x else -1
		_turn_cd = 0.2

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		if Game.instance:
			Game.instance.award_chain(p, global_position)
		return
	var prev_feet := p.global_position.y - p.velocity.y * get_physics_process_delta_time()
	var my_top := global_position.y - 12.0
	if p.velocity.y > 0.0 and prev_feet <= my_top + 4.0:
		if winged:
			winged = false
			sprite.play(&"walk")
			velocity.y = 0.0
		else:
			squish()
		p.bounce()
		if Game.instance:
			Game.instance.award_chain(p, global_position)
		_snd("stomp")
	else:
		p.hurt()

func squish() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	sprite.play(&"squish")
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(queue_free)

## Knocked out by fireball / star / block from below / tongue: flip upside
## down, hop, fall out of the level.
func kill_flip(from_x: float, award := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	sprite.play(&"flipped")
	sprite.flip_v = true
	sprite.offset = Vector2(0, -9)
	var hop_dir := 1.0 if global_position.x >= from_x else -1.0
	_snd("kick")
	if award and Game.instance:
		Game.instance.add_score(100, global_position)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + hop_dir * 40.0, 1.2)
	tw.tween_method(func(t: float): position.y = _arc_y(t), 0.0, 1.2, 1.2)
	tw.chain().tween_callback(queue_free)
	set_meta("arc_y0", position.y)

func _arc_y(t: float) -> float:
	var y0: float = get_meta("arc_y0", position.y)
	return y0 - 180.0 * t + 0.5 * 900.0 * t * t

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
