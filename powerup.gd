class_name PowerUp
extends CharacterBody2D

## Mushroom (grow), 1-UP mushroom, fire flower, star. Rises out of its block
## (emerge()), then: mushrooms slide and turn at walls, the star bounces, the
## flower stays put. Collected by touching the player. Origin = feet.

enum Kind { MUSHROOM, ONEUP, FLOWER, STAR }

const FRAMES := preload("res://assets/graphics/powerups.tres")
const GRAVITY := 900.0

var kind: int = Kind.MUSHROOM
var dir := 1
var sprite: AnimatedSprite2D
var area: Area2D
var _emerging := false
var _taken := false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	add_to_group("items")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -8.5)
	sprite.play(([&"mushroom", &"oneup", &"flower", &"star"] as Array[StringName])[kind])
	add_child(sprite)
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 14)
	sh.shape = r
	sh.position = Vector2(0, -7)
	add_child(sh)
	area = Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	var ash := CollisionShape2D.new()
	var ar := RectangleShape2D.new()
	ar.size = Vector2(14, 14)
	ash.shape = ar
	ash.position = Vector2(0, -7)
	area.add_child(ash)
	add_child(area)
	area.body_entered.connect(func(b): if b is Player and not _emerging: _collect(b))

## Slides up out of the block above-left of it (position = block bottom).
func emerge() -> void:
	_emerging = true
	z_index = -1
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 16.0, 0.6)
	tw.tween_callback(func():
		_emerging = false
		z_index = 0
		collision_mask = 1
		if kind == Kind.STAR:
			velocity = Vector2(70, -200)
		for b in area.get_overlapping_bodies():
			if b is Player:
				_collect(b))

func hop(d: float) -> void:
	velocity.y = -220.0
	if d != 0.0 and kind != Kind.FLOWER:
		dir = int(d)

func _physics_process(delta: float) -> void:
	if _emerging or _taken:
		return
	if kind == Kind.FLOWER:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 320.0)
	var spd := 70.0 if kind == Kind.STAR else 58.0
	velocity.x = dir * spd
	move_and_slide()
	if is_on_wall():
		dir = -dir
	if kind == Kind.STAR and is_on_floor():
		velocity.y = -240.0
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()

func _collect(p: Player) -> void:
	if _taken or p.mode != Player.Mode.NORMAL:
		return
	_taken = true
	if Game.instance:
		Game.instance.collect_powerup(kind, global_position)
	queue_free()
