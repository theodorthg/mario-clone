class_name MeteorField
extends Node2D

## Meteor field (level METEORS, v1.5): while the hero is inside columns
## c0..c1, a burning rock falls every few seconds somewhere near where the
## hero is heading. Each one is announced by a blinking marker on the
## ground (BossFlame kind "meteor", falls for METEOR_FALL s) — keep moving.

var c0 := 0
var c1 := 0
var _cd := 1.2

func _physics_process(delta: float) -> void:
	var game := Game.instance
	if game == null or game.level == null or game.state != Game.State.PLAYING:
		return
	# a hero inside the field (co-op: either one)
	var p: Player = null
	for h in game.all_heroes():
		if h.mode == Player.Mode.NORMAL and h.global_position.x >= c0 * Level.T \
				and h.global_position.x <= (c1 + 1) * Level.T:
			p = h
			break
	if p == null:
		return
	var x := p.global_position.x
	_cd -= delta * game.enemy_speed_mul()
	if _cd > 0.0:
		return
	_cd = randf_range(1.5, 2.3)
	var tx := clampf(x + p.velocity.x * 0.8 + randf_range(-28.0, 28.0), c0 * Level.T + 8.0, c1 * Level.T + 8.0)
	var floor_y := _floor_below(tx)
	if floor_y < 0.0:
		return
	var m := BossFlame.new()
	m.kind = "meteor"
	m.target = Vector2(tx, floor_y)
	game.level.add_child(m)

## World y of the first solid tile (or lava surface) under column x.
func _floor_below(x: float) -> float:
	var lv: Level = Game.instance.level
	var c := int(floorf(x / Level.T))
	for r in Level.ROWS:
		if lv.at(c, r) in ["L", "b"] or lv.tiles.get_cell_source_id(Vector2i(c, r)) != -1:
			return r * Level.T
	return -1.0
