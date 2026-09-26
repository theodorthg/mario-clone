class_name Coin
extends Area2D

## Collectible coin placed in the level (grid char 'o'). Origin = feet of the
## cell (bottom center), sprite drawn above it.

const FRAMES := preload("res://assets/graphics/coin.tres")

var _taken := false

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitorable = false
	add_to_group("coins")
	var s := AnimatedSprite2D.new()
	s.sprite_frames = FRAMES
	s.offset = Vector2(0, -8)
	s.play(&"spin")
	add_child(s)
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 14)
	sh.shape = r
	sh.position = Vector2(0, -8)
	add_child(sh)
	body_entered.connect(func(b): if b is Player: collect())

func collect() -> void:
	if _taken:
		return
	_taken = true
	if Game.instance:
		Game.instance.add_coin(true, global_position + Vector2(0, -8))
	var sp := Sparkle.new()
	sp.position = position + Vector2(0, -8)
	get_parent().add_child(sp)
	queue_free()
