class_name BoneTurtle
extends CharacterBody2D

## Bone turtle (grid 'O', v1.4): a skeleton turtle that walks and turns at
## ledges like a red turtle. A stomp — or a fireball — makes it fall apart
## into a harmless pile of bones; after COLLAPSE s it rattles and stands up
## again. Only a star, a kicked shell or the dragon's tongue finish it.

enum State { WALK, PILE }

const FRAMES := preload("res://assets/graphics/enemy_bones.tres")
const GRAVITY := 1100.0
const SPEED := 26.0
const COLLAPSE := 4.0
const RATTLE := 1.0

var state := State.WALK
var dir := -1
var dead := false
var active := false
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _body_rect: RectangleShape2D
var _body_shape: CollisionShape2D
var _hit_rect: RectangleShape2D
var _t := 0.0
var _safe_t := 0.0
var _rattled := false
var _speed_mul := 1.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 3.0
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -13)
	sprite.play(&"walk")
	add_child(sprite)
	_body_shape = CollisionShape2D.new()
	_body_rect = RectangleShape2D.new()
	_body_rect.size = Vector2(12, 22)
	_body_shape.shape = _body_rect
	_body_shape.position = Vector2(0, -11)
	add_child(_body_shape)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	_hit_rect = RectangleShape2D.new()
	_hit_rect.size = Vector2(14, 20)
	hs.shape = _hit_rect
	hs.position = Vector2(0, -10)
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
	velocity.y = minf(velocity.y + GRAVITY * delta, 320.0)
	if state == State.WALK:
		if is_on_floor() and not _ground_ahead():
			dir = -dir
		velocity.x = dir * SPEED * _speed_mul
		sprite.flip_h = dir < 0
	else:
		velocity.x = 0.0
		_t += delta
		if _t > COLLAPSE - RATTLE:
			sprite.offset.x = 1.0 if int(_t * 24.0) % 2 == 0 else -1.0
			if not _rattled:
				_rattled = true
				_snd("bones")
		if _t >= COLLAPSE:
			_stand_up()
	move_and_slide()
	if state == State.WALK and is_on_wall():
		dir = -dir
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	if state == State.WALK:
		for b in hitbox.get_overlapping_bodies():
			if b is Player:
				_touch_player(b)
				break

func _ground_ahead() -> bool:
	var probe := global_transform.translated(Vector2(dir * 10.0, 0.0))
	return test_move(probe, Vector2(0, 6))

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL or _safe_t > 0.0:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		Game.instance.award_chain(p, global_position)
		return
	if p.can_stomp(global_position.y - _hit_rect.size.y, _hit_rect.size.y):
		p.bounce()
		Game.instance.award_chain(p, global_position)
		_collapse()
	else:
		p.hurt()

## A fireball knocks it apart too (fireball.gd calls this first).
func fire_hit() -> void:
	if state == State.WALK:
		if Game.instance:
			Game.instance.add_score(200, global_position)
		_collapse()

func _collapse() -> void:
	state = State.PILE
	_t = 0.0
	_rattled = false
	_safe_t = 0.2
	sprite.play(&"pile")
	_body_rect.size = Vector2(12, 8)
	_body_shape.position = Vector2(0, -4)
	_snd("bones")

func _stand_up() -> void:
	state = State.WALK
	sprite.offset.x = 0.0
	sprite.play(&"walk")
	_body_rect.size = Vector2(12, 22)
	_body_shape.position = Vector2(0, -11)
	position.y -= 0.5
	var game := Game.instance
	if game and game.player:
		dir = 1 if game.player.global_position.x > global_position.x else -1

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
