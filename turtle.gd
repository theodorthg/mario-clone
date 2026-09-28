class_name Turtle
extends CharacterBody2D

## Shell turtle (koopa role). Origin = feet.
## WALK  — green walks off ledges, red turns around at ledges; `winged`
##         hops along, the first stomp only tears the wings off.
## SHELL — stomped: hides in its shell and sits still. Touch or stomp it to
##         KICK it; after WAKE_TIME it peeks out and walks again.
## SPIN  — kicked shell slides fast, bounces off walls, bumps blocks it hits
##         sideways (bricks break) and knocks out every enemy in its way with
##         a rising score chain. Stomping it stops it; running into it hurts.

enum State { WALK, SHELL, SPIN }

const FRAMES_GREEN := preload("res://assets/graphics/enemy_turtle.tres")
const FRAMES_RED := preload("res://assets/graphics/enemy_turtle_red.tres")
const GRAVITY := 1100.0
const BASE_SPEED := 30.0
const SHELL_SPEED := 210.0
const WAKE_TIME := 6.0
const PEEK_TIME := 1.6
const KICK_POINTS := 400
const SHELL_CHAIN := [500, 800, 1000, 2000, 4000, 5000, 8000]
## No endless point farm (v1.2.1, player: a shell stuck between two pipes
## can be stomped and kicked again and again): once one turtle has paid out
## this much for stomps and kicks — a 1UP counts as the whole amount — it
## breaks and flies off.
const PAYOUT_LIMIT := 10000

var red := false
var winged := false
var state := State.WALK
var dir := -1
var speed := BASE_SPEED
var active := false
var dead := false
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _body_rect: RectangleShape2D
var _hit_rect: RectangleShape2D
var _body_shape: CollisionShape2D
var _hit_shape: CollisionShape2D
var _shell_t := 0.0
var _safe_t := 0.0
var _chain := 0
var _hop_wait := 0.0
var _turn_cd := 0.0
var paid := 0                 # points paid out for stomps + kicks (PAYOUT_LIMIT)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 3.0
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES_RED if red else FRAMES_GREEN
	sprite.offset = Vector2(0, -13)
	add_child(sprite)
	_body_shape = CollisionShape2D.new()
	_body_rect = RectangleShape2D.new()
	_body_shape.shape = _body_rect
	add_child(_body_shape)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2 | 4
	_hit_shape = CollisionShape2D.new()
	_hit_rect = RectangleShape2D.new()
	_hit_shape.shape = _hit_rect
	hitbox.add_child(_hit_shape)
	add_child(hitbox)
	hitbox.area_entered.connect(_on_area)
	if Game.instance:
		speed = BASE_SPEED * Game.instance.enemy_speed_mul()
	_set_state(State.WALK)

func _set_state(s: State) -> void:
	state = s
	var tall := s == State.WALK
	# walker 12x22, shell 14x11 (hitbox slightly larger than the body)
	_body_rect.size = Vector2(12, 22) if tall else Vector2(14, 11)
	_body_shape.position = Vector2(0, -_body_rect.size.y * 0.5)
	_hit_rect.size = Vector2(14, 20) if tall else Vector2(16, 11)
	_hit_shape.position = Vector2(0, -_hit_rect.size.y * 0.5)
	sprite.offset.x = 0.0
	match s:
		State.WALK:
			sprite.play(&"fly" if winged else &"walk")
		State.SHELL:
			_shell_t = 0.0
			sprite.play(&"shell")
		State.SPIN:
			_chain = 0
			sprite.play(&"spin")

func is_moving_shell() -> bool:
	return state == State.SPIN and not dead

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := Game.instance
	if not active:
		if game == null or game.is_near_view(global_position, 40.0):
			active = true
		else:
			return
	_turn_cd = maxf(_turn_cd - delta, 0.0)
	_safe_t = maxf(_safe_t - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * (0.7 if winged else 1.0) * delta, 320.0)
	match state:
		State.WALK:
			velocity.x = dir * speed
			if winged and is_on_floor():
				_hop_wait -= delta
				if _hop_wait <= 0.0:
					velocity.y = -260.0
					_hop_wait = 0.4
			elif red and is_on_floor() and not _ground_ahead():
				dir = -dir
				velocity.x = dir * speed
			_separate_walkers()
			velocity.x = dir * speed
			sprite.flip_h = dir < 0
		State.SHELL:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_shell_t += delta
			if _shell_t > WAKE_TIME - PEEK_TIME:
				if sprite.animation != &"peek":
					sprite.play(&"peek")
				sprite.offset.x = 1.0 if int(_shell_t * 20.0) % 2 == 0 else -1.0
			if _shell_t > WAKE_TIME:
				_wake()
		State.SPIN:
			velocity.x = dir * SHELL_SPEED
	move_and_slide()
	if is_on_wall():
		if state == State.SPIN:
			_shell_hit_wall()
		dir = -dir
		sprite.flip_h = dir < 0
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	if state == State.SPIN:
		if game and not game.is_near_view(global_position, 220.0):
			queue_free()
			return
		for a in hitbox.get_overlapping_areas():
			_shell_strike(a.get_parent())
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

## Is there floor 10 px ahead? (red turtles don't walk off ledges)
func _ground_ahead() -> bool:
	var probe := global_transform.translated(Vector2(dir * 10.0, 0.0))
	return test_move(probe, Vector2(0, 6))

func _wake() -> void:
	_set_state(State.WALK)
	var game := Game.instance
	if game and game.player:
		dir = 1 if game.player.global_position.x > global_position.x else -1
	sprite.flip_h = dir < 0
	# stand up without getting stuck in a ceiling: shells never sit under
	# anything lower than 2 tiles in the level design, so just nudge upward
	position.y -= 0.5

func _on_area(a: Area2D) -> void:
	var other := a.get_parent()
	if other == self or dead or state != State.WALK or _turn_cd > 0.0:
		return
	if (other is Shroom or (other is Turtle and other.state == State.WALK)) and not other.dead:
		dir = 1 if global_position.x > other.global_position.x else -1
		_turn_cd = 0.2

## Overlapping walkers walk apart (see Shroom._separate_walkers).
func _separate_walkers() -> void:
	for a in hitbox.get_overlapping_areas():
		var o := a.get_parent()
		if o == self or not (o is Shroom or (o is Turtle and o.state == State.WALK)) or o.dead:
			continue
		var dx: float = global_position.x - o.global_position.x
		if absf(dx) < 12.0:
			dir = 1 if dx > 0.0 or (dx == 0.0 and get_instance_id() > o.get_instance_id()) else -1
			return

func _shell_strike(other: Node) -> void:
	if other == self or other == null or not other.has_method("kill_flip") or other.dead:
		return
	if other is Turtle and other.is_moving_shell():
		# two sliding shells: both go down
		kill_flip(other.global_position.x)
	other.kill_flip(global_position.x)
	var game := Game.instance
	if game:
		if _chain < SHELL_CHAIN.size():
			game.add_score(SHELL_CHAIN[_chain], other.global_position)
		else:
			game.one_up(other.global_position)
	_chain += 1

func _shell_hit_wall() -> void:
	_snd("bump")
	var game := Game.instance
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var b := c.get_collider()
		if b is Block and absf(c.get_normal().x) > 0.5 and game and game.player:
			b.bump(game.player, true)
			break

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		if Game.instance:
			Game.instance.award_chain(p, global_position)
		return
	var stomp := p.can_stomp(global_position.y - _hit_rect.size.y, _hit_rect.size.y)
	match state:
		State.WALK:
			if stomp:
				if winged:
					winged = false
					sprite.play(&"walk")
					velocity.y = 0.0
				else:
					_set_state(State.SHELL)
					velocity = Vector2.ZERO
				_stomped(p)
			else:
				p.hurt()
		State.SHELL:
			if _safe_t > 0.0:
				return
			var kick_dir := 1 if global_position.x >= p.global_position.x else -1
			if stomp:
				p.bounce()
			_kick(kick_dir)
		State.SPIN:
			if stomp:
				_set_state(State.SHELL)
				velocity.x = 0.0
				_stomped(p)
			elif _safe_t <= 0.0:
				p.hurt()
	if paid >= PAYOUT_LIMIT and not dead:
		kill_flip(p.global_position.x)

func _stomped(p: Player) -> void:
	p.bounce()
	_safe_t = 0.2
	if Game.instance:
		var i := p.stomp_chain
		paid += Game.CHAIN[i] if i < Game.CHAIN.size() else PAYOUT_LIMIT
		Game.instance.award_chain(p, global_position)
	_snd("stomp")

func _kick(kick_dir: int) -> void:
	dir = kick_dir
	_set_state(State.SPIN)
	_safe_t = 0.25
	position.x += dir * 4.0
	if Game.instance:
		paid += KICK_POINTS
		Game.instance.add_score(KICK_POINTS, global_position)
	_snd("kick")

## Knocked out by fireball / star / block from below / shell / tongue.
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
	sprite.offset = Vector2(0, -8)
	var hop_dir := 1.0 if global_position.x >= from_x else -1.0
	_snd("kick")
	if award and Game.instance:
		Game.instance.add_score(100, global_position)
	set_meta("arc_y0", position.y)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + hop_dir * 40.0, 1.2)
	tw.tween_method(func(t: float): position.y = _arc_y(t), 0.0, 1.2, 1.2)
	tw.chain().tween_callback(queue_free)

func _arc_y(t: float) -> float:
	var y0: float = get_meta("arc_y0", position.y)
	return y0 - 180.0 * t + 0.5 * 900.0 * t * t

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
