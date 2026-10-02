class_name BossFlame
extends Node2D

## Boss projectile, passes through walls, hurts on touch, vanishes off screen
## or after 5 s. Kinds (boss variants per world, see boss.gd):
##   "flame" — straight fire breath (aimed at the hero when breathed)
##   "wave"  — sand shock wave hugging the arena floor (jump over it)
##   "ice"   — ice ball spat out level that bounces along the floor
##   "bolt"  — lightning: flashes in place for BOLT_WARN s, then strikes
##             straight down to the arena floor
##   "spit"  — a salamander's small flame, straight along the ground (v1.5)
##   "magma" — a magma ball that bounces like "ice" (volcano lord, v1.5)
##   "meteor"— a burning rock falling onto `target` (a floor point) in
##             METEOR_FALL s; a blinking marker shows where (v1.5)

const FRAMES := preload("res://assets/graphics/boss_flame.tres")
const ICE := preload("res://assets/graphics/ice_ball.tres")
const BOLT := preload("res://assets/graphics/bolt.tres")
const BOLT_WARN := 0.6
const METEOR := preload("res://assets/graphics/meteor.tres")
const METEOR_FALL := 1.0

## the blinking ring on the ground where a meteor will hit
class MeteorMark extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var on := int(t * 10.0) % 2 == 0
		var col := Color(1.0, 0.35, 0.1, 0.95) if on else Color(1.0, 0.85, 0.3, 0.8)
		var r := 11.0 - minf(t, 1.0) * 5.0
		draw_arc(Vector2(0, -2), r, 0.0, TAU, 20, col, 2.0)
		draw_line(Vector2(-4, -2), Vector2(4, -2), col, 2.0)
		draw_line(Vector2(0, -6), Vector2(0, 2), col, 2.0)

var velocity := Vector2(-110, 0)
var kind := "flame"
var floor_y := 0.0          # "ice": bounce height reference (arena floor)
var target := Vector2.ZERO  # "meteor": where it hits
var _mark: Node2D
var _boomed := false
var _bounces := 0
var _t := 0.0
var _sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 2
	_sprite = AnimatedSprite2D.new()
	if kind == "ice" or kind == "magma":
		_sprite.sprite_frames = ICE
		_sprite.play(&"spin")
		if kind == "magma":
			_sprite.modulate = Color(2.2, 0.75, 0.3)
	elif kind == "meteor":
		_sprite.sprite_frames = METEOR
		_sprite.play(&"fall")
		position = target + Vector2(96.0, -300.0)
		velocity = (target - position) / METEOR_FALL
		_mark = MeteorMark.new()
		_mark.position = target
		_mark.z_index = 3
		get_parent().add_child.call_deferred(_mark)
	elif kind == "bolt":
		_sprite.sprite_frames = BOLT
		_sprite.play(&"zap")
		_sprite.scale = Vector2(1.5, 1.5)
	else:
		_sprite.sprite_frames = FRAMES
		_sprite.play(&"burn")
		_sprite.flip_h = velocity.x > 0.0     # art points left (flame tail right)
		_sprite.rotation = atan2(velocity.y, absf(velocity.x)) * (-1.0 if velocity.x < 0.0 else 1.0)
		if kind == "wave":
			_sprite.modulate = Color(1.25, 1.05, 0.6)
			_sprite.scale = Vector2(1.2, 0.8)
		elif kind == "spit":
			_sprite.scale = Vector2(0.65, 0.65)
	add_child(_sprite)

## The boss was hit: every projectile still flying vanishes in a puff.
func fizzle() -> void:
	_free_mark()
	var sp := Sparkle.new()
	sp.position = position
	get_parent().add_child(sp)
	queue_free()

func _physics_process(delta: float) -> void:
	_t += delta
	if kind == "bolt":
		if _t < BOLT_WARN:
			_sprite.visible = int(_t * 14.0) % 2 == 0
			return                     # warning flash: harmless
		_sprite.visible = true
		velocity = Vector2(0, 460.0)
		if position.y >= floor_y - 12.0:
			queue_free()
			return
	if kind == "meteor":
		if _t >= METEOR_FALL * 0.5 and not _boomed:
			_boomed = true
			var s := get_node_or_null("/root/Snd")
			if s:
				s.play("meteor")    # whistle, then the crash as it lands
		if _t >= METEOR_FALL:
			_free_mark()
			var sp := Sparkle.new()
			sp.position = target + Vector2(0, -6)
			get_parent().add_child(sp)
			_hit_check(Vector2(14.0, 14.0))
			queue_free()
			return
		position += velocity * delta
		_hit_check(Vector2(9.0, 9.0))
		return
	if kind == "ice" or kind == "magma":
		velocity.y += 650.0 * delta
		if position.y >= floor_y - 7.0 and velocity.y > 0.0:
			position.y = floor_y - 7.0
			# spat out level (never upward, v1.2.1): a minimum rebound keeps it
			# a bouncing obstacle — about 2, 1.5, 1 tiles high
			velocity.y = -maxf(absf(velocity.y) * 0.78, 200.0 - 30.0 * _bounces)
			_bounces += 1
			if _bounces > 4:
				queue_free()
				return
	position += velocity * delta
	var game := Game.instance
	if game == null or _t > 5.0 or not game.is_near_view(global_position, 60.0):
		queue_free()
		return
	_hit_check(Vector2(8.0, 14.0) if kind == "bolt" else (Vector2(8.0, 6.0) if kind == "spit" else Vector2(12.0, 9.0)))

func _hit_check(reach: Vector2) -> void:
	var game := Game.instance
	if game == null:
		return
	for p in game.all_heroes():
		if p.mode != Player.Mode.NORMAL or p.star_t > 0.0:
			continue
		var center: Vector2 = p.global_position + Vector2(0, -7.0 if not p.is_big() else -14.0)
		var d := (global_position - center).abs()
		if d.x < reach.x and d.y < reach.y + (0.0 if not p.is_big() else 7.0):
			p.hurt()
			if kind != "meteor":
				queue_free()
				return

func _free_mark() -> void:
	if _mark and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null

func _exit_tree() -> void:
	_free_mark()
