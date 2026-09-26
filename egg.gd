class_name Egg
extends Node2D

## Dragon egg: slides out of its ?-block, wobbles, cracks and hatches a Dino
## on the spot. Origin = feet (bottom of the block it came from).

const FRAMES := preload("res://assets/graphics/egg.tres")

var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.offset = Vector2(0, -8)
	sprite.play(&"idle")
	add_child(sprite)
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 16.0, 0.5)
	tw.tween_callback(func(): z_index = 1)
	tw.tween_property(self, "position:y", position.y - 22.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - 16.0, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): sprite.play(&"crack"))
	tw.tween_interval(0.65)
	tw.tween_callback(_hatch)

func _hatch() -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play("hatch")
	var d := Dino.new()
	d.position = position
	get_parent().add_child(d)
	d.hop()
	for i in 6:
		var sp := Sparkle.new()
		sp.position = position + Vector2(randf_range(-10, 10), randf_range(-24, -4))
		get_parent().add_child(sp)
	sprite.play(&"shell")
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
