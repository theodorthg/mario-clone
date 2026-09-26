class_name Boss
extends CharacterBody2D

## Castle boss (grid 'Z'): a horned dragon-ogre king, recoloured per world.
## Wakes when the hero walks into the arena (level ARENA columns): the game
## locks the camera + closes a wall behind the hero. Paces, jumps and breathes
## flames aimed at the hero; faster with every hit.
## Damage: stomp (hero bounces off) = 1, star touch = 1, 5 fireballs = 1.
## Immune to shells, blocks and the dragon's tongue (no kill_flip()).

const GRAVITY := 1100.0
const INVULN := 1.2

var world := 1
var max_hp := 3
var hp := 3
var arena_left := 0.0
var arena_right := 0.0
var active := false
var dead := false
var facing := -1
var sprite: AnimatedSprite2D
var hitbox: Area2D
var _act := 0.0
var _inv := 0.0
var _fire_hits := 0
var _target_x := 0.0
var _roar := 0.0
var _hit_rect: RectangleShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("boss")
	max_hp = 3 + (1 if world >= 3 else 0)
	hp = max_hp
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://assets/graphics/boss_%d.tres" % clampi(world, 1, 4))
	sprite.offset = Vector2(0, -17)
	sprite.scale = Vector2(2, 2)      # 32x34 art drawn at 2x: a 4-tile giant
	sprite.play(&"walk")
	sprite.flip_h = true
	add_child(sprite)
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 54)
	sh.shape = r
	sh.position = Vector2(0, -27)
	add_child(sh)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	var hs := CollisionShape2D.new()
	_hit_rect = RectangleShape2D.new()
	_hit_rect.size = Vector2(44, 56)
	hs.shape = _hit_rect
	hs.position = Vector2(0, -28)
	hitbox.add_child(hs)
	add_child(hitbox)
	_target_x = position.x
	_act = 1.5

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := Game.instance
	if game == null or game.player == null:
		return
	var p: Player = game.player
	if not active:
		if p.global_position.x > arena_left + 40.0 and p.mode == Player.Mode.NORMAL:
			active = true
			game.start_boss(self)
		else:
			return
	_inv = maxf(_inv - delta, 0.0)
	sprite.visible = _inv <= 0.0 or int(_inv * 16.0) % 2 == 0
	facing = 1 if p.global_position.x > global_position.x else -1
	sprite.flip_h = facing < 0
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	var rage := 1.0 + 0.25 * (max_hp - hp)
	if _roar > 0.0:
		_roar -= delta
		velocity.x = 0.0
		if _roar <= 0.0:
			sprite.play(&"walk")
	else:
		if absf(_target_x - global_position.x) < 4.0:
			_target_x = randf_range(arena_left + 80.0, arena_right - 64.0)
		velocity.x = signf(_target_x - global_position.x) * 38.0 * rage
		_act -= delta * rage
		if _act <= 0.0 and is_on_floor():
			_act = randf_range(1.6, 2.6)
			if randf() < 0.55:
				_breathe(p)
			else:
				velocity.y = -360.0
				sprite.play(&"jump")
	var was_air := not is_on_floor()
	move_and_slide()
	if was_air and is_on_floor():
		if sprite.animation == &"jump":
			sprite.play(&"walk")
		_snd("bump")
	global_position.x = clampf(global_position.x, arena_left + 36.0, arena_right - 28.0)
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

func _breathe(p: Player) -> void:
	_roar = 0.6
	sprite.play(&"roar")
	_snd("dino")
	var f := BossFlame.new()
	var mouth := global_position + Vector2(facing * 28.0, -40.0)
	var aim := (p.global_position + Vector2(0, -10) - mouth).normalized()
	aim.x = signf(aim.x) * maxf(absf(aim.x), 0.8)
	f.velocity = aim.normalized() * 115.0
	f.position = mouth
	get_parent().add_child(f)

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL or _inv > 0.0:
		return
	if p.star_t > 0.0:
		take_hit()
		return
	var prev_feet := p.global_position.y - p.velocity.y * get_physics_process_delta_time()
	var dt := get_physics_process_delta_time()
	var top := global_position.y - _hit_rect.size.y
	# allowance for the boss rising into a falling hero during its jump
	if p.velocity.y > 0.0 and prev_feet <= top + 8.0 + maxf(-velocity.y, 0.0) * dt:
		p.bounce()
		p.velocity.y = -340.0
		take_hit()
	else:
		p.hurt()

## Fireball hit (fireball.gd checks for this method first).
func fire_hit() -> void:
	if dead or _inv > 0.0:
		return
	_fire_hits += 1
	sprite.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if _fire_hits >= 5:
		_fire_hits = 0
		take_hit()

func take_hit() -> void:
	if dead or _inv > 0.0:
		return
	hp -= 1
	_inv = INVULN
	_snd("stomp")
	_snd("kick")
	var game := Game.instance
	if game:
		game.boss_hp_changed(hp, max_hp)
		game.add_score(1000, global_position + Vector2(0, -30))
	if hp <= 0:
		_die()

func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	hitbox.set_deferred("monitoring", false)
	sprite.visible = true
	sprite.play(&"roar")
	sprite.flip_v = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 40.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y + 300.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if Game.instance:
			Game.instance.boss_defeated(self)
		queue_free())

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
