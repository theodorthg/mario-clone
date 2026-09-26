class_name Penguin
extends Shroom

## Snow penguin (grid 'q'): a quicker walker that every few seconds throws
## itself on its belly and slides fast (hard to jump over). Stomp = squish,
## like the mushroom walker it is built on (shroom.gd).

const PENGUIN_FRAMES := preload("res://assets/graphics/enemy_penguin.tres")

var _slide_t := 0.0
var _next_slide := 2.5
var _walk_speed := 0.0

func _ready() -> void:
	super._ready()
	sprite.sprite_frames = PENGUIN_FRAMES
	sprite.play(&"walk")
	sprite.offset = Vector2(0, -9)
	_walk_speed = speed * 1.4
	speed = _walk_speed
	_next_slide = randf_range(1.5, 3.5)

func _physics_process(delta: float) -> void:
	if active and not dead:
		if _slide_t > 0.0:
			_slide_t -= delta
			if _slide_t <= 0.0:
				speed = _walk_speed
				sprite.play(&"walk")
		else:
			_next_slide -= delta
			if _next_slide <= 0.0 and is_on_floor():
				_next_slide = randf_range(2.5, 4.5)
				_slide_t = 1.1
				speed = _walk_speed * 2.6
				sprite.play(&"slide")
		sprite.flip_h = dir < 0
	super._physics_process(delta)
