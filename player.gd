class_name Player
extends CharacterBody2D

## The hero. Origin = feet (bottom center). Physics tuned in px/s at 16px
## tiles (see CLAUDE.md "Physik"): walking jump clears 4 tiles, running jump
## ~5.5 tiles; gravity is light while the jump button is held on the way up
## (variable jump height) and heavy otherwise — but always light for the
## first JUMP_MIN_HOLD s, so even a quick tap clears ~3 tiles.
## Assists (v0.11, "old men must make it too"): firm ground braking (little
## sliding after landing, extra brake on touchdown without input), stronger
## air control, and one double jump (press jump again in mid-air; setting).
## Underwater areas (Level.WATER_THEMES) switch to `swimming` (set by
## game.gd): slow sinking, every jump press is a swim stroke, the water
## surface (SWIM_TOP) caps how high the hero can rise.
##
## Scripted sequences (pipe, flag pole, death, power change) put the player
## into a non-NORMAL `mode`; game.gd drives those via the helper methods at
## the bottom instead of _physics_process.

signal fireball_requested(pos: Vector2, dir: int)

enum Power { SMALL, BIG, FIRE }
enum Mode { NORMAL, DEAD, SCRIPTED }

const WALK_MAX := 90.0
const RUN_MAX := 155.0
const ACCEL := 320.0
const RUN_ACCEL := 380.0
const DECEL := 560.0
const DECEL_ICE := 80.0         # ice keeps its old slide
const OVERSPEED_DECEL := 140.0  # above the current top speed (run released)
const SKID_DECEL := 900.0
const AIR_ACCEL := 340.0
const AIR_DRAG := 130.0         # stick released in the air
const LAND_BRAKE := 0.5         # keep this much speed on touchdown w/o input
const JUMP_V := 270.0
const JUMP_MIN_HOLD := 0.15
const AIR_JUMP_V := 235.0
const JUMP_RUN_BONUS := 50.0
const GRAVITY_HOLD := 560.0
const GRAVITY := 1400.0
const MAX_FALL := 340.0
const COYOTE := 0.08
const JUMP_BUFFER := 0.12
const SWIM_GRAVITY := 300.0
const SWIM_MAX_FALL := 90.0
const SWIM_STROKE := 150.0
const SWIM_MAX := 75.0
const SWIM_RUN_MAX := 105.0
const SWIM_ACCEL := 260.0
const SWIM_DRAG := 150.0
const SWIM_WALK := 55.0          # walking on the sea floor
const SWIM_TOP := 44.0           # water surface: the head stays below it
const STOMP_BOUNCE := 190.0
const STOMP_BOUNCE_HELD := 290.0

const FRAMES := {
	Power.SMALL: preload("res://assets/graphics/hero_small.tres"),
	Power.BIG: preload("res://assets/graphics/hero_big.tres"),
	Power.FIRE: preload("res://assets/graphics/hero_fire.tres"),
}
const FRAMES_SMALL_FIRE := preload("res://assets/graphics/hero_small_fire.tres")
const CELL_H := {Power.SMALL: 20.0, Power.BIG: 32.0, Power.FIRE: 32.0}

var power: int = Power.SMALL
var mode: int = Mode.NORMAL
var facing := 1
var crouching := false
var input_enabled := true
var invuln_t := 0.0
var star_t := 0.0
var coyote_t := 0.0
var jump_buffer_t := 0.0
var jump_held_phase := false
var jump_min_t := 0.0
var air_jumps := 0
var _was_on_floor := true
var stomp_chain := 0
var throw_t := 0.0
var riding: Dino = null
var swimming := false
var auto_walk := 0.0            # scripted walking while input is disabled
var left_limit := -INF
var right_limit := INF

var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var _rect: RectangleShape2D
var _star_hue := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 3.0
	floor_constant_speed = true
	safe_margin = 0.05
	add_to_group("player")
	sprite = AnimatedSprite2D.new()
	sprite.centered = true
	add_child(sprite)
	_rect = RectangleShape2D.new()
	shape = CollisionShape2D.new()
	shape.shape = _rect
	add_child(shape)
	set_power(power)

# ----------------------------------------------------------------- power --
func set_power(p: int) -> void:
	power = p
	_apply_visual_power(p)
	_apply_shape()

## Visual-only swap, used by the grow/shrink flicker in game.gd.
func _apply_visual_power(p: int, small_fire := false) -> void:
	var anim := sprite.animation if sprite.sprite_frames else &"idle"
	sprite.sprite_frames = FRAMES_SMALL_FIRE if small_fire else FRAMES[p]
	var h: float = 20.0 if small_fire else CELL_H[p]
	sprite.offset = Vector2(0, -h * 0.5 - (Dino.RIDE_LIFT if riding else 0.0))
	sprite.position.x = -Dino.RIDE_BACK * facing if riding else 0.0
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		sprite.play(&"idle")

func show_power_frame(p: int) -> void:
	_apply_visual_power(p)

func _on_ice() -> bool:
	var game := Game.instance
	if game == null or game.level == null:
		return false
	var r := int(floorf((global_position.y + 2.0) / Level.T))
	for dx in [-5.0, 0.0, 5.0]:
		if game.level.is_ice(int(floorf((global_position.x + dx) / Level.T)), r):
			return true
	return false

func is_big() -> bool:
	return power != Power.SMALL

func _apply_shape() -> void:
	var h := 14.0
	if riding:
		h = 26.0
	elif power != Power.SMALL and not crouching:
		h = 26.0
	_rect.size = Vector2(12, h)
	shape.position = Vector2(0, -h * 0.5)

func body_top() -> float:
	return global_position.y - _rect.size.y

# ---------------------------------------------------------------- physics --
func _physics_process(delta: float) -> void:
	if mode != Mode.NORMAL:
		return
	invuln_t = maxf(invuln_t - delta, 0.0)
	throw_t = maxf(throw_t - delta, 0.0)
	if star_t > 0.0:
		star_t = maxf(star_t - delta, 0.0)
	_update_blink(delta)

	var dir := 0.0
	var run := false
	var down := false
	var jump_now := false
	if not input_enabled:
		dir = auto_walk
	else:
		dir = Input.get_axis("move_left", "move_right")
		run = Input.is_action_pressed("run")
		down = Input.is_action_pressed("move_down")
		if Input.is_action_just_pressed("jump"):
			jump_buffer_t = JUMP_BUFFER
			jump_now = true
		if Input.is_action_just_pressed("run"):
			_action_pressed()
	jump_buffer_t = maxf(jump_buffer_t - delta, 0.0)

	jump_min_t = maxf(jump_min_t - delta, 0.0)

	var on_floor := is_on_floor()
	var ice := on_floor and _on_ice()
	if on_floor:
		coyote_t = COYOTE
		air_jumps = 1 if _double_jump_enabled() else 0
		if velocity.y >= 0.0:
			stomp_chain = 0
		# touchdown without holding a direction: brake hard so narrow
		# platforms are easy to land on (not on ice — that stays slippery)
		if not _was_on_floor and dir == 0.0 and not ice:
			velocity.x *= LAND_BRAKE
	else:
		coyote_t = maxf(coyote_t - delta, 0.0)
	_was_on_floor = on_floor

	# crouch (big only, on the ground, not while riding)
	var want_crouch: bool = down and on_floor and power != Power.SMALL and riding == null
	if want_crouch != crouching and (want_crouch or on_floor):
		if not want_crouch and _ceiling_blocked():
			pass
		else:
			crouching = want_crouch
			_apply_shape()
	if crouching:
		dir = 0.0

	if swimming:
		_swim(delta, dir, run, on_floor, jump_now)
	else:
		# horizontal (ice blocks: much less grip on the ground)
		var grip := 0.28 if ice else 1.0
		var top := RUN_MAX if run else WALK_MAX
		if dir != 0.0:
			facing = 1 if dir > 0.0 else -1
			var target := dir * top
			if on_floor and velocity.x != 0.0 and signf(velocity.x) != signf(dir):
				velocity.x = move_toward(velocity.x, 0.0, SKID_DECEL * grip * delta)
			elif absf(velocity.x) > top and signf(velocity.x) == signf(dir):
				velocity.x = move_toward(velocity.x, target, OVERSPEED_DECEL * delta)
			else:
				var acc := (RUN_ACCEL if run else ACCEL) * grip if on_floor else AIR_ACCEL
				velocity.x = move_toward(velocity.x, target, acc * delta)
		else:
			var brake := (DECEL_ICE if ice else DECEL) if on_floor else AIR_DRAG
			velocity.x = move_toward(velocity.x, 0.0, brake * delta)

		# jump (ground / coyote first, else the one double jump in mid-air)
		if jump_buffer_t > 0.0 and coyote_t > 0.0:
			if down and riding != null:
				_dismount_jump()
			else:
				_jump()
		elif jump_now and not on_floor and air_jumps > 0:
			_air_jump(dir)

		# gravity (variable height, but never shorter than JUMP_MIN_HOLD)
		var released := not Input.is_action_pressed("jump") or not input_enabled
		if jump_held_phase and (velocity.y >= 0.0 or (released and jump_min_t <= 0.0)):
			jump_held_phase = false
		var g := GRAVITY_HOLD if jump_held_phase else GRAVITY
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	var vy_before := velocity.y
	move_and_slide()
	_check_head_bump(vy_before)
	if swimming and body_top() < SWIM_TOP:
		global_position.y = SWIM_TOP + _rect.size.y
		velocity.y = maxf(velocity.y, 0.0)

	# keep inside the current area horizontally
	if global_position.x < left_limit + 6.0:
		global_position.x = left_limit + 6.0
		velocity.x = maxf(velocity.x, 0.0)
	if global_position.x > right_limit - 6.0:
		global_position.x = right_limit - 6.0
		velocity.x = minf(velocity.x, 0.0)

	_update_animation(on_floor, dir, run)

	if global_position.y > Level.ROWS * Level.T + 24.0 and Game.instance:
		Game.instance.player_died(true)

## Underwater movement: slower, floaty; every jump press is a stroke up.
func _swim(delta: float, dir: float, run: bool, on_floor: bool, stroke: bool) -> void:
	var top := SWIM_WALK if on_floor else (SWIM_RUN_MAX if run else SWIM_MAX)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		velocity.x = move_toward(velocity.x, dir * top, SWIM_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (DECEL if on_floor else SWIM_DRAG) * delta)
	if stroke:
		jump_buffer_t = 0.0
		velocity.y = -SWIM_STROKE
		_snd("swim")
	jump_held_phase = false
	velocity.y = minf(velocity.y + SWIM_GRAVITY * delta, SWIM_MAX_FALL)

func _jump() -> void:
	jump_buffer_t = 0.0
	coyote_t = 0.0
	var bonus := JUMP_RUN_BONUS * clampf(absf(velocity.x) / RUN_MAX, 0.0, 1.0)
	velocity.y = -(JUMP_V + bonus)
	jump_held_phase = true
	jump_min_t = JUMP_MIN_HOLD
	_snd("jump_big" if power != Power.SMALL or riding else "jump")

## Double jump: a fresh (slightly lower) jump in mid-air. Holding a
## direction against the current drift turns it around right away.
func _air_jump(dir: float) -> void:
	air_jumps -= 1
	jump_buffer_t = 0.0
	velocity.y = -AIR_JUMP_V
	if dir != 0.0 and signf(velocity.x) != signf(dir):
		velocity.x = dir * minf(absf(velocity.x), WALK_MAX * 0.5)
	jump_held_phase = true
	jump_min_t = JUMP_MIN_HOLD
	_snd("jump2")
	var parent := get_parent()
	if parent:
		var puff := JumpPuff.new()
		puff.position = global_position
		parent.add_child(puff)

func _double_jump_enabled() -> bool:
	var game := Game.instance
	return game == null or bool(game.cfg.get("double_jump", true))

func bounce(held_boost := true) -> void:
	var held := Input.is_action_pressed("jump") and held_boost
	velocity.y = -(STOMP_BOUNCE_HELD if held else STOMP_BOUNCE)
	if swimming:
		velocity.y = -SWIM_STROKE
		held = false
	jump_held_phase = held
	jump_min_t = 0.0
	coyote_t = 0.0
	air_jumps = 1 if _double_jump_enabled() else 0     # stomping refills it

func _ceiling_blocked() -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 12)
	params.shape = r
	params.transform = Transform2D(0.0, global_position + Vector2(0, -20))
	params.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()

## Head hit something while moving up: pick the block closest to the
## player's center (SMB behaviour when the head overlaps two blocks).
func _check_head_bump(vy_before: float) -> void:
	if vy_before >= 0.0:
		return
	var best: Block = null
	var best_d := INF
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < 0.7:
			continue
		var b := col.get_collider()
		if b is Block:
			var d := absf((b as Block).global_position.x - global_position.x)
			if d < best_d:
				best_d = d
				best = b
	if best:
		best.bump(self)
	elif is_on_ceiling():
		_snd("bump")

# ----------------------------------------------------------------- actions --
func _action_pressed() -> void:
	if riding:
		riding.tongue(facing)
	elif power == Power.FIRE and not crouching:
		if get_tree().get_nodes_in_group("fireball").size() < 2:
			throw_t = 0.15
			fireball_requested.emit(global_position + Vector2(facing * 6, -18), facing)

# ------------------------------------------------------------------ riding --
func mount(d: Dino) -> void:
	riding = d
	d.attach_to(self)
	velocity.y = 0.0
	crouching = false
	_apply_shape()
	_apply_visual_power(power)
	_snd("dino")

func _dismount_jump() -> void:
	var d := riding
	_detach_dino(false)
	velocity.y = -JUMP_V
	jump_held_phase = true
	jump_min_t = JUMP_MIN_HOLD
	jump_buffer_t = 0.0
	coyote_t = 0.0
	d.dismounted(facing, false)

func lose_dino() -> void:
	var d := riding
	_detach_dino(true)
	velocity.y = -200.0
	invuln_t = 1.5
	d.dismounted(facing, true)
	_snd("powerdown")

func _detach_dino(_hit: bool) -> void:
	riding.detach_from(self)
	riding = null
	_apply_shape()
	_apply_visual_power(power)

# ------------------------------------------------------------------ damage --
## Returns true when the hit actually did something (for enemies to know).
func hurt() -> bool:
	if mode != Mode.NORMAL or invuln_t > 0.0 or star_t > 0.0:
		return false
	if riding:
		lose_dino()
		return true
	var game := Game.instance
	if power == Power.SMALL:
		if game:
			game.player_died(false)
		return true
	if game:
		game.change_power(power - 1, true)
	invuln_t = 2.0
	return true

func start_star(duration: float) -> void:
	star_t = duration

# --------------------------------------------------------------- visuals --
func _update_blink(delta: float) -> void:
	if star_t > 0.0:
		_star_hue = fmod(_star_hue + delta * 6.0, 1.0)
		sprite.modulate = Color.from_hsv(_star_hue, 0.55, 1.0) if star_t > 1.5 or int(star_t * 10) % 2 == 0 else Color.WHITE
		sprite.visible = true
		if riding:
			riding.sprite.modulate = sprite.modulate
	else:
		sprite.modulate = Color.WHITE
		if riding:
			riding.sprite.modulate = Color.WHITE
		sprite.visible = invuln_t <= 0.0 or int(invuln_t * 20.0) % 2 == 0

func _update_animation(on_floor: bool, dir: float, run: bool) -> void:
	sprite.flip_h = facing < 0
	var anim := &"idle"
	if riding:
		anim = &"ride"
	elif crouching:
		anim = &"crouch"
	elif not on_floor:
		anim = &"swim" if swimming else &"jump"
	elif throw_t > 0.0:
		anim = &"throw"
	elif dir != 0.0 and velocity.x != 0.0 and signf(velocity.x) != signf(dir):
		anim = &"skid"
		if sprite.animation != &"skid":
			_snd("skid")
	elif absf(velocity.x) > 4.0:
		anim = &"walk"
	if sprite.animation != anim:
		sprite.play(anim)
	if anim == &"walk":
		sprite.speed_scale = clampf(absf(velocity.x) / 60.0, 0.6, 2.4)
	else:
		sprite.speed_scale = 1.0
	if riding:
		sprite.position.x = -Dino.RIDE_BACK * facing
		riding.update_ridden(on_floor, velocity, facing)

func _snd(key: String) -> void:
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play(key)

# ------------------------------------------------------- scripted helpers --
func set_scripted(on: bool) -> void:
	mode = Mode.SCRIPTED if on else Mode.NORMAL
	if on:
		velocity = Vector2.ZERO

func play_anim(anim: StringName, flip := false) -> void:
	sprite.flip_h = flip
	sprite.speed_scale = 1.0
	if sprite.animation != anim:
		sprite.play(anim)

func reset_state() -> void:
	mode = Mode.NORMAL
	velocity = Vector2.ZERO
	crouching = false
	invuln_t = 0.0
	star_t = 0.0
	stomp_chain = 0
	jump_buffer_t = 0.0
	jump_min_t = 0.0
	coyote_t = 0.0
	air_jumps = 0
	_was_on_floor = true
	facing = 1
	collision_mask = 1
	z_index = 0
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	_apply_shape()
	play_anim(&"idle")
