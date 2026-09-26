class_name BrickShard
extends Sprite2D

## One of the four spinning pieces of a broken brick.

var velocity := Vector2.ZERO
var cave := false
var _t := 0.0

func _ready() -> void:
	z_index = 3
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/graphics/shard.png")
	at.region = Rect2(0, 0, 6, 6)
	texture = at
	if cave:
		modulate = Color(0.55, 0.7, 1.4)

func _process(delta: float) -> void:
	_t += delta
	velocity.y += 900.0 * delta
	position += velocity * delta
	rotation = floorf(_t * 12.0) * PI * 0.5
	if _t > 1.5:
		queue_free()
