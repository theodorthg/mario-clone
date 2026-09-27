class_name FallingPlatform
extends AnimatableBody2D

## 3-tile sandstone slab (grid 'D', top-left at the cell). Holds for a moment
## once the hero stands on it, shakes, then drops — carrying the hero down,
## so jump off in time — and reappears at its spot a few seconds later.
## One-way from below, like the lifts (moving_platform.gd).

const TEX := preload("res://assets/graphics/drop.png")
const W := 48.0
const HOLD := 0.5
const RESPAWN := 3.5

enum St { IDLE, SHAKE, FALL, GONE }

var _st := St.IDLE
var _t := 0.0
var _vy := 0.0
var _origin := Vector2.ZERO
var _sprite: Sprite2D
var _shape: CollisionShape2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_origin = position
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(W, 5)
	_shape.shape = r
	_shape.position = Vector2(W * 0.5, 2.5)
	_shape.one_way_collision = true
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.centered = false
	_sprite.position = Vector2(-1, -1)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	match _st:
		St.IDLE:
			if _hero_on_top():
				_st = St.SHAKE
				_t = 0.0
				_snd("bump")
		St.SHAKE:
			_t += delta
			_sprite.position.x = -1.0 + (1.0 if int(_t * 30.0) % 2 == 0 else -1.0)
			if _t >= HOLD:
				_st = St.FALL
				_vy = 0.0
				_sprite.position.x = -1.0
		St.FALL:
			_vy = minf(_vy + 600.0 * delta, 260.0)
			position.y += _vy * delta
			if position.y > Level.ROWS * Level.T + 40.0:
				_st = St.GONE
				_t = 0.0
				visible = false
				_shape.set_deferred("disabled", true)
		St.GONE:
			_t += delta
			if _t >= RESPAWN and not _hero_near_origin():
				position = _origin
				visible = true
				_shape.set_deferred("disabled", false)
				modulate.a = 0.0
				create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
				_st = St.IDLE

func _hero_on_top() -> bool:
	var game := Game.instance
	if game == null or game.player == null:
		return false
	var p: Player = game.player
	if p.mode != Player.Mode.NORMAL or not p.is_on_floor():
		return false
	var feet := p.global_position
	return feet.x > global_position.x - 5.0 and feet.x < global_position.x + W + 5.0 \
		and absf(feet.y - global_position.y) < 3.0

func _hero_near_origin() -> bool:
	var game := Game.instance
	if game == null or game.player == null:
		return false
	var d := game.player.global_position - (_origin + Vector2(W * 0.5, 0.0))
	return absf(d.x) < W and d.y > -40.0 and d.y < 24.0

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
