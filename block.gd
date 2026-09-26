class_name Block
extends StaticBody2D

## ?-block / brick / hidden block. Origin = cell center. Bumped from below by
## Player._check_head_bump(). Contents: "coin", "powerup" (mushroom when the
## player is small, fire flower otherwise), "star", "oneup", "egg",
## "multicoin" (brick that pays out coins until MULTI_TIME runs out), or ""
## (plain brick: breaks when big, just bumps when small).

enum Kind { QUESTION, BRICK, HIDDEN }

const FRAMES := preload("res://assets/graphics/blocks.tres")
const MULTI_TIME := 4.0
const MULTI_MAX := 10

var kind: int = Kind.QUESTION
var content := ""
var cave := false
var used := false
var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var _bumping := false
var _multi_left := MULTI_MAX
var _multi_t := -1.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("blocks")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	add_child(sprite)
	shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	shape.shape = r
	add_child(shape)
	match kind:
		Kind.QUESTION:
			sprite.play(&"question")
		Kind.BRICK:
			sprite.play(&"cave_brick" if cave else &"brick")
		Kind.HIDDEN:
			sprite.visible = false
			# solid only when hit from BELOW: a one-way shape flipped upside down
			shape.one_way_collision = true
			shape.rotation = PI

func _process(delta: float) -> void:
	if _multi_t > 0.0:
		_multi_t -= delta

func bump(player: Player, from_shell := false) -> void:
	var game := Game.instance
	if used or _bumping:
		_snd("bump")
		return
	if kind == Kind.HIDDEN:
		shape.one_way_collision = false
		shape.rotation = 0.0
		sprite.visible = true
	_kill_enemies_on_top()
	match content:
		"":
			if player.is_big() or from_shell:
				_break()
				return
			_snd("bump")
			_bounce_anim()
			return
		"coin":
			_pop_coin()
			_set_used()
		"multicoin":
			if _multi_t < 0.0:
				_multi_t = MULTI_TIME
			_pop_coin()
			_multi_left -= 1
			if _multi_left <= 0 or _multi_t <= 0.0:
				_set_used()
		"powerup":
			_snd("sprout")
			_spawn_item(PowerUp.Kind.MUSHROOM if not player.is_big() else PowerUp.Kind.FLOWER)
			_set_used()
		"star":
			_snd("sprout")
			_spawn_item(PowerUp.Kind.STAR)
			_set_used()
		"oneup":
			_snd("sprout")
			_spawn_item(PowerUp.Kind.ONEUP)
			_set_used()
		"egg":
			_snd("sprout")
			if player.riding != null or not get_tree().get_nodes_in_group("dino").is_empty():
				# already have a dragon: the egg block pays out an extra life instead
				_spawn_item(PowerUp.Kind.ONEUP)
				_set_used()
				_bounce_anim()
				return
			var egg := Egg.new()
			egg.position = position + Vector2(0, 8)
			egg.z_index = -1
			get_parent().add_child(egg)
			_set_used()
	_bounce_anim()
	if game:
		game.block_bumped()

func _set_used() -> void:
	used = true
	sprite.play(&"used")

func _bounce_anim() -> void:
	_bumping = true
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -5.0, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", 0.0, 0.08).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _bumping = false)

func _pop_coin() -> void:
	var c := BlockCoin.new()
	c.position = position + Vector2(0, -8)
	get_parent().add_child(c)
	if Game.instance:
		Game.instance.add_coin(false, c.position)

func _spawn_item(k: int) -> void:
	var p := PowerUp.new()
	p.kind = k
	p.position = position + Vector2(0, 8)
	get_parent().add_child(p)
	p.emerge()

func _break() -> void:
	_snd("break")
	for i in 4:
		var s := BrickShard.new()
		s.position = position + Vector2(-4 + (i % 2) * 8, -4 + (i / 2) * 8)
		s.velocity = Vector2((-1 if i % 2 == 0 else 1) * randf_range(50, 80), -260.0 + (i / 2) * 90.0)
		s.cave = cave
		get_parent().add_child(s)
	if Game.instance:
		Game.instance.add_score(50)
	queue_free()

func _kill_enemies_on_top() -> void:
	var top := global_position.y - 8.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("kill_flip") and absf(e.global_position.x - global_position.x) < 14.0 \
				and absf(e.global_position.y - top) < 5.0:
			e.kill_flip(global_position.x, true)
	for p in get_tree().get_nodes_in_group("items"):
		if p is PowerUp and absf(p.global_position.x - global_position.x) < 14.0 \
				and absf(p.global_position.y - top) < 5.0:
			p.hop(signf(p.global_position.x - global_position.x))
	for c in get_tree().get_nodes_in_group("coins"):
		if absf(c.global_position.x - global_position.x) < 8.0 and absf(c.global_position.y - top) < 5.0:
			c.collect()

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)
