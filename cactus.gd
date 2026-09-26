class_name CactusStack
extends CharacterBody2D

## Desert cactus stack (grid 'p'): 3 swaying spiky balls, the top one with a
## face and a flower, creeping toward the hero. SPIKY — stomping it hurts
## (only a star makes that safe). Each fireball knocks off one ball (+200);
## shells, stars, blocks and the dragon's tongue take the whole stack.

const FRAMES := preload("res://assets/graphics/enemy_cactus.tres")
const SEG_H := 11.0
const GRAVITY := 1100.0

var segments := 3
var dead := false
var active := false
var dir := -1
var speed := 18.0
var _t := 0.0
var _sprites: Array[AnimatedSprite2D] = []
var hitbox: Area2D
var _hit_rect: RectangleShape2D
var _hit_shape: CollisionShape2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 3.0
	add_to_group("enemies")
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 10)
	sh.shape = r
	sh.position = Vector2(0, -5)
	add_child(sh)
	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	_hit_shape = CollisionShape2D.new()
	_hit_rect = RectangleShape2D.new()
	_hit_shape.shape = _hit_rect
	hitbox.add_child(_hit_shape)
	add_child(hitbox)
	_t = randf() * 3.0
	if Game.instance:
		speed *= Game.instance.enemy_speed_mul()
	_rebuild()

func _rebuild() -> void:
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	for i in segments:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = FRAMES
		s.play(&"head" if i == segments - 1 else &"seg")
		s.centered = false
		add_child(s)
		_sprites.append(s)
	_hit_rect.size = Vector2(12, segments * SEG_H)
	_hit_shape.position = Vector2(0, -segments * SEG_H * 0.5)
	_sway()

func _sway() -> void:
	for i in _sprites.size():
		var s := _sprites[i]
		var wob := roundf(sin(_t * 3.0 + i * 1.1) * 1.5)
		s.position = Vector2(-8.0 + wob, -17.0 - i * SEG_H)

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := Game.instance
	if not active:
		if game == null or game.is_near_view(global_position, 40.0):
			active = true
		else:
			return
	_t += delta
	_sway()
	if game and game.player:
		dir = 1 if game.player.global_position.x > global_position.x else -1
	velocity.x = dir * speed
	velocity.y = minf(velocity.y + GRAVITY * delta, 320.0)
	move_and_slide()
	if global_position.y > Level.ROWS * Level.T + 40.0:
		queue_free()
		return
	for b in hitbox.get_overlapping_bodies():
		if b is Player:
			var p: Player = b
			if p.mode != Player.Mode.NORMAL:
				break
			if p.star_t > 0.0:
				kill_flip(p.global_position.x)
				game.award_chain(p, global_position)
			else:
				p.hurt()
			break

## Fireball: knock off one ball.
func fire_hit() -> void:
	if dead:
		return
	if Game.instance:
		Game.instance.add_score(200, global_position + Vector2(0, -segments * SEG_H))
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.play("kick")
	segments -= 1
	if segments <= 0:
		kill_flip(global_position.x)
		return
	var ball := Sprite2D.new()
	ball.texture = _sprites[0].sprite_frames.get_frame_texture(&"seg", 0)
	ball.global_position = global_position + Vector2(0, -8)
	get_parent().add_child(ball)
	var tw := ball.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "position:y", ball.position.y + 200.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "rotation", 6.0, 0.9)
	tw.chain().tween_callback(ball.queue_free)
	_rebuild()

func kill_flip(from_x: float, award := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	if award and Game.instance:
		Game.instance.add_score(100, global_position)
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.play("kick")
	var d := 1.0 if global_position.x >= from_x else -1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", position.x + d * 40.0, 1.1)
	tw.tween_property(self, "position:y", position.y + 280.0, 1.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "rotation", d * 2.5, 1.1)
	tw.chain().tween_callback(queue_free)
