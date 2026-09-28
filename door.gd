class_name Door
extends Sprite2D

## Ghost house door (grid 'H' = the floor cell in front of it, v1.4): a
## doorway two tiles high. Doors are linked in pairs by warps of kind "door"
## (level WARPS): press down (or up) in front of one to go through — game.gd
## opens it, fades the hero out and in again at the other one.

const TEX := preload("res://assets/graphics/door.png")
const CRYPT_TEX := preload("res://assets/graphics/crypt.png")

## graveyard: the door sits in a small crypt (48x44, door centred)
var crypt := false

func _ready() -> void:
	texture = CRYPT_TEX if crypt else TEX
	hframes = 2
	centered = false
	z_index = -1
	# position = bottom-left of the cell
	offset = Vector2(-16, -44) if crypt else Vector2(0, -32)

func open(t := 0.6) -> void:
	frame = 1
	get_tree().create_timer(t, false).timeout.connect(func():
		if is_instance_valid(self):
			frame = 0)
