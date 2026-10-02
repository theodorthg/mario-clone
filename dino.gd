class_name Dino
extends CharacterBody2D

## Rideable dragon. Hatches from an Egg, waits, and is mounted by landing on
## its saddle from above. While ridden it is re-parented under the Player
## (physics off, drawn behind the rider) — the player's own body does all
## the moving, this node only animates and provides the tongue.
## Getting hit while riding throws the rider off and the dragon runs away
## in panic (it can be caught and re-mounted).

enum State { IDLE, RIDDEN, FLEE }

const FRAMES := preload("res://assets/graphics/dino.tres")
const RIDE_LIFT := 13.0      # rider sprite sits this many px higher
const RIDE_BACK := 4.0       # ... and this far towards the tail
const TONGUE_LEN := 44.0
const TONGUE_TIME := 0.28
const MOUTH := Vector2(12, -21)

var state: int = State.IDLE
var facing := 1
var sprite: AnimatedSprite2D
var _shape: CollisionShape2D
var _area: Area2D
var _mount_cd := 0.6
var _flee_t := 0.0
var _tongue_t := -1.0
var _tongue_len := 0.0
var _tongue_caught := false
var _tongue: Node2D
var _tongue_area: Area2D

func _ready() -> void:
	collision_layer = 32
	collision_mask = 1
	add_to_group("dino")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -16)
	sprite.play(&"idle")
	add_child(sprite)
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 22)
	_shape.shape = r
	_shape.position = Vector2(0, -11)
	add_child(_shape)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var ash := CollisionShape2D.new()
	var ar := RectangleShape2D.new()
	ar.size = Vector2(18, 26)
	ash.shape = ar
	ash.position = Vector2(0, -13)
	_area.add_child(ash)
	add_child(_area)
	_tongue = Node2D.new()
	_tongue.z_index = 1
	_tongue.set_meta("net_tongue", true)
	_tongue.draw.connect(_draw_tongue)
	add_child(_tongue)
	_tongue_area = Area2D.new()
	_tongue_area.collision_layer = 0
	_tongue_area.collision_mask = 4 | 8
	var tsh := CollisionShape2D.new()
	# Tall hitbox: the tongue is drawn at mouth height, but must also catch
	# enemies standing on the same ground as the dragon (they are only ~14 px
	# tall, the mouth sits ~20 px above the feet).
	var tr := RectangleShape2D.new()
	tr.size = Vector2(12, 28)
	tsh.shape = tr
	tsh.position = Vector2(0, 9)
	_tongue_area.add_child(tsh)
	_tongue_area.monitoring = false
	_tongue.add_child(_tongue_area)

func _physics_process(delta: float) -> void:
	_mount_cd = maxf(_mount_cd - delta, 0.0)
	_update_tongue(delta)
	if state == State.RIDDEN:
		return
	velocity.y = minf(velocity.y + 1100.0 * delta, 320.0)
	if state == State.FLEE:
		_flee_t -= delta
		velocity.x = facing * 115.0
		if _flee_t <= 0.0:
			state = State.IDLE
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()
	if state == State.FLEE and is_on_wall():
		facing = -facing
	sprite.flip_h = facing < 0
	if state == State.FLEE:
		_play(&"run")
	elif not is_on_floor():
		_play(&"jump")
	else:
		_play(&"idle")
		var p := _player()
		if p:
			facing = 1 if p.global_position.x > global_position.x else -1
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	if _mount_cd <= 0.0:
		for b in _area.get_overlapping_bodies():
			if b is Player and b.riding == null and b.mode == Player.Mode.NORMAL \
					and b.velocity.y > 0.0 and b.global_position.y <= global_position.y - 12.0:
				b.mount(self)
				break

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] if not ps.is_empty() else null

func _play(anim: StringName) -> void:
	if _tongue_t >= 0.0:
		anim = &"eat" if anim == &"idle" or anim == &"jump" else &"eat_walk"
	if sprite.animation != anim:
		sprite.play(anim)

func hop() -> void:
	velocity.y = -180.0

# ----------------------------------------------------------------- riding --
func attach_to(p: Player) -> void:
	state = State.RIDDEN
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_area.monitoring = false
	var parent := get_parent()
	if parent:
		parent.remove_child(self)
	p.add_child(self)
	p.move_child(self, 0)
	position = Vector2.ZERO
	facing = p.facing

func detach_from(p: Player) -> void:
	var feet := p.global_position
	var level := p.get_parent()
	p.remove_child(self)
	level.add_child(self)
	global_position = feet
	collision_layer = 32
	collision_mask = 1
	_area.monitoring = true
	sprite.modulate = Color.WHITE

func dismounted(dir: int, fled: bool) -> void:
	facing = dir
	_mount_cd = 0.8 if fled else 0.45
	if fled:
		state = State.FLEE
		_flee_t = 5.0
		velocity.y = -120.0
	else:
		state = State.IDLE

func update_ridden(on_floor: bool, v: Vector2, dir: int) -> void:
	facing = dir
	sprite.flip_h = dir < 0
	if not on_floor:
		_play(&"jump")
	elif absf(v.x) > 110.0:
		_play(&"run")
	elif absf(v.x) > 4.0:
		_play(&"walk")
		sprite.speed_scale = clampf(absf(v.x) / 70.0, 0.7, 1.6)
	else:
		_play(&"idle")
		sprite.speed_scale = 1.0

# ------------------------------------------------------------------ tongue --
func tongue(dir: int) -> void:
	if _tongue_t >= 0.0:
		return
	facing = dir
	_tongue_t = 0.0
	_tongue_caught = false
	_tongue_area.set_deferred("monitoring", true)
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play("tongue")

func _update_tongue(delta: float) -> void:
	if _tongue_t < 0.0:
		return
	_tongue_t += delta
	var k := _tongue_t / TONGUE_TIME
	if k >= 1.0:
		_tongue_t = -1.0
		_tongue_len = 0.0
		_tongue_area.set_deferred("monitoring", false)
		_tongue.queue_redraw()
		return
	var out := 1.0 - absf(k * 2.0 - 1.0)
	if _tongue_caught:
		out = minf(out, _tongue_len / TONGUE_LEN)
	_tongue_len = TONGUE_LEN * out
	var mouth := Vector2(MOUTH.x * facing, MOUTH.y)
	_tongue_area.position = mouth + Vector2(facing * _tongue_len, 0)
	_tongue.queue_redraw()
	if not _tongue_caught and _tongue_area.monitoring:
		for a in _tongue_area.get_overlapping_areas():
			var e := a.get_parent()
			if e != null and e.has_method("kill_flip") and not e.dead:
				_eat(e)
				break

func _eat(e: Node2D) -> void:
	_tongue_caught = true
	e.dead = true
	e.remove_from_group("enemies")
	var pos := e.global_position
	e.queue_free()
	if Game.instance:
		Game.instance.add_score(200, pos)
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play("gulp")
	if _tongue_t < TONGUE_TIME * 0.5:
		_tongue_t = TONGUE_TIME - _tongue_t

func _draw_tongue() -> void:
	draw_tongue_on(_tongue, facing, _tongue_len)

## Also used by the Wi-Fi guest (NetClient) to draw a remote dragon's tongue.
static func draw_tongue_on(ci: CanvasItem, dir: int, length: float) -> void:
	if length <= 0.5:
		return
	var mouth := Vector2(MOUTH.x * dir, MOUTH.y)
	var tip := mouth + Vector2(dir * length, 0)
	var a := Vector2(minf(mouth.x, tip.x), mouth.y - 1)
	ci.draw_rect(Rect2(a, Vector2(absf(tip.x - mouth.x), 3)), Color("#ff6a8a"))
	ci.draw_rect(Rect2(a + Vector2(0, 2), Vector2(absf(tip.x - mouth.x), 1)), Color("#c0305a"))
	ci.draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), Color("#ff6a8a"))
	ci.draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), Color("#1a1018"), false, 1.0)
