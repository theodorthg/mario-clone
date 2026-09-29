class_name Salamander
extends Shroom

## Salamander (grid 'd', v1.5): a fire lizard that walks its ledge (turns
## at edges) and, when the hero is ahead of it on about the same height,
## stops, opens its mouth (WINDUP s warning) and spits a small flame along
## the ground — jump over it. Stompable; fire, a star or a shell beat it
## like the mushroom walker it is built on (shroom.gd).

const SALA_FRAMES := preload("res://assets/graphics/enemy_salamander.tres")
const WINDUP := 0.5
const RANGE := 190.0

var _spit_cd := 1.5
var _windup := 0.0

func _ready() -> void:
	super._ready()
	sprite.sprite_frames = SALA_FRAMES
	sprite.offset = Vector2(0, -5)
	sprite.play(&"walk")
	speed *= 0.7

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
	_spit_cd -= delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 320.0)
	if _windup > 0.0:
		velocity.x = 0.0
		_windup -= delta
		if _windup <= 0.0:
			_spit()
	else:
		if is_on_floor() and not _ground_ahead():
			dir = -dir
		velocity.x = dir * speed
		if _spit_cd <= 0.0 and game and game.player and _hero_ahead(game.player):
			_windup = WINDUP
			sprite.play(&"spit")
	sprite.flip_h = dir > 0
	move_and_slide()
	if is_on_wall():
		dir = -dir
	_separate_walkers()
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			_touch_player(b)
			break

func _hero_ahead(p: Player) -> bool:
	var dx := p.global_position.x - global_position.x
	return signf(dx) == float(dir) and absf(dx) < RANGE and absf(p.global_position.y - global_position.y) < 40.0 \
		and p.mode == Player.Mode.NORMAL

func _ground_ahead() -> bool:
	var probe := global_transform.translated(Vector2(dir * 10.0, 0.0))
	return test_move(probe, Vector2(0, 6))

func _spit() -> void:
	_spit_cd = randf_range(2.2, 3.2)
	sprite.play(&"walk")
	var f := BossFlame.new()
	f.kind = "spit"
	f.velocity = Vector2(dir * 120.0, 0.0)
	f.position = position + Vector2(dir * 11.0, -5.0)
	get_parent().add_child(f)
	_snd("spit")
