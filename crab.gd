class_name Crab
extends Shroom

## Crab (grid 'z'): scuttles sideways along the sea floor, a little quicker
## than the mushroom walker it is built on (shroom.gd). Stomp it (sink onto
## it), or use fire / a star / a shell.

const CRAB_FRAMES := preload("res://assets/graphics/enemy_crab.tres")

func _ready() -> void:
	super._ready()
	sprite.sprite_frames = CRAB_FRAMES
	sprite.offset = Vector2(0, -7)
	sprite.play(&"walk")
	speed *= 1.25
