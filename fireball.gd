class_name Fireball
extends CharacterBody2D

## Bouncing fireball thrown by the fire-powered hero. Dies on walls, after a
## few seconds, or when leaving the view; knocks enemies out.

const FRAMES := preload("res://assets/graphics/fireball.tres")

var dir := 1
var _t := 0.0
var _area: Area2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("fireball")
	var s := AnimatedSprite2D.new()
	s.sprite_frames = FRAMES
	s.play(&"spin")
	add_child(s)
	var sh := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0
	sh.shape = c
	add_child(sh)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4
	var ash := CollisionShape2D.new()
	var ac := CircleShape2D.new()
	ac.radius = 5.0
	ash.shape = ac
	_area.add_child(ash)
	add_child(_area)
	_area.area_entered.connect(_on_area)
	velocity = Vector2(dir * 210.0, 60.0)

func _physics_process(delta: float) -> void:
	_t += delta
	velocity.y = minf(velocity.y + 1000.0 * delta, 300.0)
	move_and_slide()
	if is_on_floor():
		velocity.y = -170.0
	if is_on_wall() or _t > 3.0 or (Game.instance and not Game.instance.is_near_view(global_position, 16.0)):
		_die()

func _on_area(a: Area2D) -> void:
	var e := a.get_parent()
	if e != null and e.has_method("kill_flip") and not e.dead:
		if not (e is Chomper) and Game.instance:
			Game.instance.add_score(200, e.global_position)
		e.kill_flip(global_position.x)
		_die()

func _die() -> void:
	var sp := Sparkle.new()
	sp.position = position
	get_parent().add_child(sp)
	queue_free()
