class_name Boss
extends CharacterBody2D

## Castle boss (grid 'Z'): a horned dragon-ogre king, recoloured per world,
## with a different attack per world (see _breathe()).
## Wakes when the hero walks into the arena (level ARENA columns): the game
## locks the camera + closes a wall behind the hero. Paces, jumps and breathes
## flames aimed at the hero; faster with every hit.
## Damage: stomp (hero bounces off) = 1, star touch = 1, 5 fireballs = 1.
## Immune to shells, blocks and the dragon's tongue (no kill_flip()).
##
## Fair play (v0.15, player feedback: "it still shoots while stunned, the
## fire hits me right when I'm above it"):
## - every attack is telegraphed: WINDUP (rears back, claw raised) before a
##   breath, CROUCH before a jump;
## - a hit STUNs it (dizzy stars, no attacks, no walking) and every
##   projectile still flying fizzles; afterwards it first walks off to the
##   far side and waits a moment before the next attack;
## - no breath while the hero is (nearly) above it — it backs off instead;
##   nothing is ever fired upward: flames go level or down, ice balls are
##   spat out level and only bounce up off the floor (v1.2.1);
## - no fire power left? A hit makes it drop a fire flower (ammo).
## Animation: idle breathing, 4-phase walk, squash & stretch on jump/landing.
##
## By Settings > Difficulty (v1.2.1, player wish): Easy = as before (1 s
## daze, flowers); Normal = shorter daze, flowers; Hard = short daze, no
## flowers. Flowers: on a hit AND shortly after the hero loses fire power,
## tossed to the far side of the arena. No difficulty ever shoots upward at
## the hero (the rules above hold for all).

const GRAVITY := 1100.0
const INVULN := 1.2
const STUN := [1.0, 0.8, 0.5]            # by difficulty
const FLOWERS := [true, true, false]     # by difficulty
const FLOWER_DELAY := 1.2                # after the hero lost fire power
const MAX_DOWN := 0.65                   # steepest aim below the horizon (rad)
const FAN_STEP := 0.32
const WINDUP := 0.4
const PHASE := 0.4                       # world 7: fade out / fade in time
const CROUCH := 0.2
const SCALE := Vector2(2, 2)

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
var _stun := 0.0
var _windup := 0.0
var _crouch := 0.0
var _fire_hits := 0
var _target_x := 0.0
var _roar := 0.0
var _hit_rect: RectangleShape2D
var _jumping := false        # own jump in progress (world 3: shock waves on landing)
var _stars: Node2D
var _squash: Tween
var difficulty := 1
var _no_fire_t := 0.0         # how long the hero has been without fire power
var _phase_t := 0.0           # world 7: phasing (faded out, harmless, untouchable)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("boss")
	if Game.instance:
		difficulty = clampi(int(Game.instance.cfg.get("difficulty", 1)), 0, 2)
	max_hp = 3 + (1 if world >= 3 else 0) + (1 if world >= 6 else 0) + (1 if world >= 8 else 0)
	hp = max_hp
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://assets/graphics/boss_%d.tres" % clampi(world, 1, 8))
	sprite.offset = Vector2(0, -17)
	sprite.scale = SCALE              # 32x34 art drawn at 2x: a 4-tile giant
	sprite.play(&"idle")
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
	_stars = StunStars.new()
	_stars.position = Vector2(0, -78)
	_stars.visible = false
	add_child(_stars)
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
			game.start_boss.call_deferred(self)     # tile/collision changes outside the physics step
		else:
			return
	_inv = maxf(_inv - delta, 0.0)
	sprite.visible = _inv <= 0.0 or _stun > 0.0 or int(_inv * 16.0) % 2 == 0
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	var rage := 1.0 + 0.25 * (max_hp - hp)
	var dx := p.global_position.x - global_position.x
	# lost the fire power mid-fight (Easy/Normal): a flower flies in soon
	if FLOWERS[difficulty] and p.power != Player.Power.FIRE and p.mode == Player.Mode.NORMAL:
		_no_fire_t += delta
		if _no_fire_t >= FLOWER_DELAY:
			_no_fire_t = 0.0
			_drop_flower(p)
	else:
		_no_fire_t = 0.0
	if _phase_t > 0.0:
		# phasing (world 7): the tween moves it; attack right after
		_phase_t -= delta
		velocity.x = 0.0
		if _phase_t <= 0.0:
			_windup = WINDUP
			sprite.play(&"windup")
	elif _stun > 0.0:
		# dizzy: no attacks, slides to a stop
		_stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if _stun <= 0.0:
			_stars.visible = false
			_act = maxf(_act, 1.0)
			_retreat(p)
	elif _windup > 0.0:
		velocity.x = 0.0
		_windup -= delta
		if _windup <= 0.0:
			if _hero_above(p):
				_retreat(p)             # hero jumped over it meanwhile: no fire
			else:
				_breathe(p)
	elif _crouch > 0.0:
		velocity.x = 0.0
		_crouch -= delta
		if _crouch <= 0.0 and is_on_floor():
			velocity.y = -360.0
			_jumping = true
			sprite.play(&"jump")
			_stretch(Vector2(0.85, 1.2))
	elif _roar > 0.0:
		_roar -= delta
		velocity.x = 0.0
	else:
		facing = 1 if dx > 0.0 else -1
		if absf(_target_x - global_position.x) < 4.0:
			_target_x = randf_range(arena_left + 80.0, arena_right - 64.0)
		velocity.x = signf(_target_x - global_position.x) * 38.0 * rage
		_act -= delta * rage
		if _act <= 0.0 and is_on_floor():
			_act = randf_range(1.6, 2.6)
			if _hero_above(p):
				_retreat(p)
				_act = 0.8
			elif (world == 7 and randf() < 0.45) or (world == 8 and randf() < 0.25):
				_phase(p)
			elif randf() < 0.55:
				_windup = WINDUP
				sprite.play(&"windup")
			else:
				_crouch = CROUCH
				sprite.play(&"crouch")
				_stretch(Vector2(1.12, 0.88))
	sprite.flip_h = facing < 0
	var was_air := not is_on_floor()
	move_and_slide()
	if was_air and is_on_floor():
		if _jumping:
			_jumping = false
			if world == 3 or (world in [6, 8] and randf() < 0.5):
				_shock_waves()
		_stretch(Vector2(1.18, 0.82))
		_snd("bump")
	_animate()
	global_position.x = clampf(global_position.x, arena_left + 36.0, arena_right - 28.0)
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

## Idle / walk / jump from the movement — the special states set their
## own frame when they start (windup, roar, crouch, hurt).
func _animate() -> void:
	if _stun > 0.0 or _windup > 0.0 or _crouch > 0.0 or _roar > 0.0:
		return
	var anim := &"jump" if not is_on_floor() else (&"walk" if absf(velocity.x) > 1.0 else &"idle")
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = clampf(absf(velocity.x) / 38.0, 0.8, 2.0) if anim == &"walk" else 1.0

## Squash & stretch: snap to `k` (x, y factors), ease back to normal.
func _stretch(k: Vector2) -> void:
	if _squash:
		_squash.kill()
	sprite.scale = SCALE * k
	_squash = create_tween()
	_squash.tween_property(sprite, "scale", SCALE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hero_above(p: Player) -> bool:
	return absf(p.global_position.x - global_position.x) < 60.0 and p.global_position.y < global_position.y - 40.0

## Back off: walk away from the hero (never through them); cornered at a
## wall it just stays put for a moment.
func _retreat(p: Player) -> void:
	var away := -1.0 if p.global_position.x > global_position.x else 1.0
	_target_x = clampf(global_position.x + away * 160.0, arena_left + 80.0, arena_right - 64.0)

## Attack by world (each castle's boss fights a little differently):
## 1 one aimed flame · 2 a fan of three flames · 3 aimed flame, and every
## landing sends sand shock waves along the floor · 4 two bouncing ice balls
## · 5 aimed flame + three lightning bolts striking around the hero (they
## flash at the top of the arena first — step aside) · 7 fades out and
## reappears across the arena (see _phase), then a fan of flames · 6 (5 HP)
## picks one of the fan / ice balls / bolts each time, and every other
## landing sends shock waves · 8 the volcano lord, the final boss (6 HP):
## fan / two magma balls / aimed flame + a meteor rain around the hero
## (markers on the floor first), shock waves on every other landing, and
## now and then it phases like the phantom king
func _breathe(p: Player) -> void:
	_roar = 0.6
	facing = 1 if p.global_position.x > global_position.x else -1
	sprite.flip_h = facing < 0
	sprite.play(&"roar")
	_stretch(Vector2(1.08, 0.94))
	_snd("dino")
	var mouth := global_position + Vector2(facing * 28.0, -40.0)
	# never upward (v1.2.1, player: "no shooting upward in any variant"):
	# level with the mouth or down toward the hero, at most ~37° down
	var to := p.global_position + Vector2(0, -10) - mouth
	var down := clampf(atan2(to.y, maxf(absf(to.x), 1.0)), 0.0, MAX_DOWN)
	var aim := _dir(down)
	match world:
		2, 7:
			_fan(down, 110.0, mouth)
		4:
			_ice_pair(mouth)
		5:
			_shoot("flame", mouth, aim * 115.0)
			_bolts(p)
		6:
			# the tide king (world 6) knows every trick of the others
			match randi() % 3:
				0:
					_fan(down, 115.0, mouth)
				1:
					_ice_pair(mouth)
				_:
					_shoot("flame", mouth, aim * 120.0)
					_bolts(p)
		8:
			match randi() % 3:
				0:
					_fan(down, 120.0, mouth)
				1:
					_ice_pair(mouth, "magma")
				_:
					_shoot("flame", mouth, aim * 120.0)
					_meteors(p)
		_:
			_shoot("flame", mouth, aim * 115.0)

## Flight direction `down` radians below the horizon, toward `facing`.
func _dir(down: float) -> Vector2:
	return Vector2(float(facing) * cos(down), sin(down))

## Three flames 0.32 rad apart; the top one never above the horizon.
func _fan(down: float, speed: float, mouth: Vector2) -> void:
	var top := clampf(down - FAN_STEP, 0.0, 0.26)
	for k in 3:
		_shoot("flame", mouth, _dir(top + FAN_STEP * k) * speed)

## Two ice balls spat out level: they drop to the floor and bounce along it.
func _ice_pair(mouth: Vector2, kind := "ice") -> void:
	_shoot(kind, mouth, Vector2(facing * 95.0, 0.0))
	_shoot(kind, mouth, Vector2(facing * 140.0, 60.0))

## Final boss: three meteors crash down around the hero (each announced
## by a marker on the arena floor for METEOR_FALL s).
func _meteors(p: Player) -> void:
	for dx in [-56.0, 0.0, 56.0]:
		var m := BossFlame.new()
		m.kind = "meteor"
		m.target = Vector2(clampf(p.global_position.x + dx, arena_left + 24.0, arena_right - 24.0), global_position.y)
		get_parent().add_child(m)

func _bolts(p: Player) -> void:
	var sky_y := global_position.y - 11.0 * Level.T
	for dx in [-52.0, 0.0, 52.0]:
		var x := clampf(p.global_position.x + dx, arena_left + 24.0, arena_right - 24.0)
		_shoot("bolt", Vector2(x, sky_y), Vector2.ZERO)

func _shoot(kind: String, at: Vector2, vel: Vector2) -> void:
	var f := BossFlame.new()
	f.kind = kind
	f.velocity = vel
	f.floor_y = global_position.y
	f.position = at
	get_parent().add_child(f)

func _shock_waves() -> void:
	for d in [-1.0, 1.0]:
		_shoot("wave", global_position + Vector2(d * 22.0, -5.0), Vector2(d * 125.0, 0.0))

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL or _inv > 0.0 or _phase_t > 0.0:
		return
	if p.star_t > 0.0:
		take_hit()
		return
	var dt := get_physics_process_delta_time()
	var top := global_position.y - _hit_rect.size.y
	# allowance for the boss rising into a falling hero during its jump
	if p.can_stomp(top, _hit_rect.size.y, 10.0 + maxf(-velocity.y, 0.0) * dt):
		p.bounce()
		p.velocity.y = -340.0
		take_hit()
	else:
		p.hurt()

## Fireball hit (fireball.gd checks for this method first).
func fire_hit() -> void:
	if dead or _inv > 0.0 or _phase_t > 0.0:
		return
	_fire_hits += 1
	sprite.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if _fire_hits >= 5:
		_fire_hits = 0
		take_hit()

func take_hit() -> void:
	if dead or _inv > 0.0 or _phase_t > 0.0:
		return
	hp -= 1
	_inv = INVULN
	_snd("stomp")
	_snd("kick")
	var game := Game.instance
	if game:
		game.boss_hp_changed(hp, max_hp)
		game.add_score(1000, global_position + Vector2(0, -30))
	# every projectile still in the air fizzles out
	for n in get_parent().get_children():
		if n is BossFlame:
			n.fizzle()
	if hp <= 0:
		_die()
		return
	_stun = STUN[difficulty]
	_windup = 0.0
	_crouch = 0.0
	_roar = 0.0
	sprite.play(&"hurt")
	_stars.visible = true
	_stretch(Vector2(1.2, 0.8))
	if FLOWERS[difficulty] and game and game.player and game.player.power != Player.Power.FIRE:
		_drop_flower(game.player)

## Ammo: without fire power a hit makes the boss drop a fire flower, tossed
## to the side of the arena away from it (one at a time).
## World 7 (the phantom king): fades out, reappears on the far side of the
## hero and breathes a fan of flames. Untouchable while phasing — no damage
## either way.
func _phase(p: Player) -> void:
	_phase_t = PHASE * 2.0 + 0.3
	_snd("ghost")
	var mid := (arena_left + arena_right) * 0.5
	var tx := randf_range(mid + 30.0, arena_right - 64.0) if p.global_position.x < mid \
		else randf_range(arena_left + 80.0, mid - 30.0)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, PHASE)
	tw.tween_callback(func():
		global_position.x = tx
		_target_x = tx
		facing = 1 if p.global_position.x > tx else -1
		sprite.flip_h = facing < 0)
	tw.tween_interval(0.3)
	tw.tween_property(sprite, "modulate:a", 1.0, PHASE)

func _drop_flower(_p: Player) -> void:
	for it in get_tree().get_nodes_in_group("items"):
		if it is PowerUp and it.kind == PowerUp.Kind.FLOWER and not it.is_queued_for_deletion() \
				and it.global_position.x >= arena_left:
			return
	var f := PowerUp.new()
	f.kind = PowerUp.Kind.FLOWER
	f.position = position + Vector2(0, -40)
	get_parent().add_child(f)
	var mid := (arena_left + arena_right) * 0.5
	var tx := arena_left + 56.0 if global_position.x > mid else arena_right - 72.0
	f.toss_to(Vector2(tx, position.y))
	_snd("sprout")

func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	hitbox.set_deferred("monitoring", false)
	sprite.visible = true
	_stars.visible = false
	sprite.play(&"hurt")
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
