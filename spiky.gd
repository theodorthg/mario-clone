class_name Spiky
extends Shroom

## Spiky shell walker (grid 'x', and thrown by the cloud imp): walks like the
## mushroom enemy it is built on (shroom.gd) but its spikes hurt — stomping
## it is not possible. Fireball, star, shell, block from below or the
## dragon's tongue knock it out. `from_sky`: thrown as a rolled-up ball, it
## unrolls on landing and walks toward the hero.

const SPIKY_FRAMES := preload("res://assets/graphics/enemy_spiky.tres")

var from_sky := false
var _falling := false

func _ready() -> void:
	super._ready()
	sprite.sprite_frames = SPIKY_FRAMES
	sprite.offset = Vector2(0, -8)
	if from_sky:
		_falling = true
		active = true
		sprite.play(&"ball")
	else:
		sprite.play(&"walk")

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _falling:
		velocity.y = minf(velocity.y + GRAVITY * delta, 320.0)
		move_and_slide()
		if is_on_floor():
			_falling = false
			var game := Game.instance
			if game and game.target_for(global_position):
				dir = 1 if game.target_for(global_position).global_position.x > global_position.x else -1
			sprite.play(&"walk")
		elif global_position.y > Level.ROWS * Level.T + 40.0:
			queue_free()
			return
		for b in hitbox.get_overlapping_bodies():
			if b is Player:
				_touch_player(b)
				break
		return
	sprite.flip_h = dir > 0          # art faces left
	super._physics_process(delta)

func _touch_player(p: Player) -> void:
	if p.mode != Player.Mode.NORMAL:
		return
	if p.star_t > 0.0:
		kill_flip(p.global_position.x)
		if Game.instance:
			Game.instance.award_chain(p, global_position)
		return
	p.hurt()                          # spikes: no stomping
