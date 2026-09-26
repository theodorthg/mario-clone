class_name BlockCoin
extends Node2D

## Coin that pops out of a bumped block: flies up spinning fast, falls back,
## vanishes with a sparkle. Purely visual — the coin itself was already
## counted by Block._pop_coin().

const FRAMES := preload("res://assets/graphics/coin.tres")

var _vy := -300.0
var _start_y := 0.0

func _ready() -> void:
	z_index = 2
	var s := AnimatedSprite2D.new()
	s.sprite_frames = FRAMES
	s.offset = Vector2(0, -8)
	s.play(&"fast")
	add_child(s)
	_start_y = position.y

func _process(delta: float) -> void:
	_vy += 900.0 * delta
	position.y += _vy * delta
	if _vy > 0.0 and position.y > _start_y - 18.0:
		var sp := Sparkle.new()
		sp.position = position + Vector2(0, -8)
		get_parent().add_child(sp)
		queue_free()
