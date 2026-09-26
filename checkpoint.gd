class_name Checkpoint
extends Area2D

## Midway flag. Touching it makes it the respawn point for this level.

var _sprite: Sprite2D
var _on := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = -1
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_set_look(false)
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 40)
	sh.shape = r
	sh.position = Vector2(0, -20)
	add_child(sh)
	body_entered.connect(func(b): if b is Player: activate())

func _set_look(on: bool) -> void:
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/graphics/decor.png")
	at.region = DecorIndex.RECTS["cp_on" if on else "cp_off"]
	_sprite.texture = at
	_sprite.position = Vector2(-2, -at.region.size.y)

func activate() -> void:
	if _on:
		return
	_on = true
	_set_look(true)
	if Game.instance:
		Game.instance.set_checkpoint(global_position)

func set_active_silent() -> void:
	_on = true
	_set_look(true)
