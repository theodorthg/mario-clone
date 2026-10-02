class_name WorldMap
extends Node2D

## The world map (v1.1): all 19 courses on one wide picture
## (assets/graphics/world_map.png + world_map_data.gd, both made by
## tools/gen_map.py). The hero walks along the roads between courses:
## D-pad / arrows toward a neighbour (the one whose road leaves in that
## direction), A / jump / Enter enters the course. Touch / mouse: tap a
## course to walk there, tap it again to enter.
## Unlocked = index <= reach, cleared = index < reach. Roads and markers are
## drawn here (not baked) so the road to a newly unlocked course can be
## revealed after a clear. game.gd owns the flow (show_map / course_chosen).

signal course_chosen(index: int)
signal node_changed(index: int)

const TEX := preload("res://assets/graphics/world_map.png")
const NODE_TEX := preload("res://assets/graphics/map_nodes.png")
const CASTLE_TEX := preload("res://assets/graphics/map_castles.png")
const SPEED := 120.0
const REVEAL_TIME := 1.1
const ENTER_DELAY := 0.4            # ignore a jump button still held from the course
const ROAD_FILL := {"dirt": Color8(236, 212, 158), "cloud": Color8(255, 255, 255), "plank": Color8(178, 122, 66)}
const ROAD_EDGE := {"dirt": Color8(150, 112, 62), "cloud": Color8(150, 180, 220), "plank": Color8(96, 60, 26)}

var reach := 0
var at := 0
var active := false
var hero: AnimatedSprite2D
var _legs: Array = []               # [{pts: Array[Vector2], to: int}] still to walk
var _leg_d := 0.0                   # distance walked on _legs[0]
var _reveal_seg := -1
var _reveal_k := 0.0
var _after_reveal := -1
var _delay := 0.0
var _layer: CanvasLayer
var _title: Label
var _hint: Label
var _names: Array[String] = []

func _ready() -> void:
	var bg := Sprite2D.new()
	bg.texture = TEX
	bg.centered = false
	bg.z_index = -2
	add_child(bg)
	hero = AnimatedSprite2D.new()
	hero.z_index = 2
	add_child(hero)
	partner = AnimatedSprite2D.new()
	partner.z_index = 1
	partner.visible = false
	add_child(partner)
	set_power(Player.Power.SMALL)
	# course name banner at the bottom of the screen
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	var band := ColorRect.new()
	band.color = Color(0.05, 0.04, 0.1, 0.7)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -24
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(band)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", UiStyle.ACCENT)
	_title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_title.offset_left = 10
	_title.offset_top = -21
	_title.offset_bottom = -3
	band.add_child(_title)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -170
	_hint.offset_right = -10
	_hint.offset_top = -16
	_hint.offset_bottom = -6
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	band.add_child(_hint)
	for lv in Game.LEVELS:
		_names.append(String(lv.NAME))

## Show the map with courses 0..reach_idx unlocked, the hero on at_idx.
func setup(reach_idx: int, at_idx: int, power: int) -> void:
	reach = clampi(reach_idx, 0, WorldMapData.NODES.size() - 1)
	at = clampi(at_idx, 0, reach)
	_legs.clear()
	_reveal_seg = -1
	_after_reveal = -1
	_delay = ENTER_DELAY
	set_power(power)
	hero.position = WorldMapData.NODES[at]
	hero.play(&"front")
	visible = true
	_layer.visible = true
	active = true
	_update_banner()
	queue_redraw()

func hide_map() -> void:
	active = false
	visible = false
	_layer.visible = false

## Which hero walks the map (0 Mario, 1 Luigi — 2 players take turns).
var hero_index := 0
## "MARIO" / "LUIGI" in front of the course name (2 players), else ""
var player_label := ""
## co-op (v1.7): Luigi walks along a step behind Mario
var coop := false
## Wi-Fi guest (v1.8): only shows what the host's map does (no input, no
## walking of its own) — apply_net_state()
var puppet := false
var partner: AnimatedSprite2D

func set_power(p: int) -> void:
	hero.sprite_frames = Player.frames_for(hero_index, p)
	if partner:
		partner.sprite_frames = Player.frames_for(1, p)
		partner.offset = Vector2(0, -Player.CELL_H[p] * 0.5 + 2.0)
	hero.offset = Vector2(0, -Player.CELL_H[p] * 0.5 + 2.0)

## Unlock course `to` (the one after a cleared course): the road to it draws
## itself, then the hero walks there by himself.
func reveal(to: int) -> void:
	if to <= reach or to >= WorldMapData.NODES.size():
		return
	_reveal_seg = to - 1
	_reveal_k = 0.0
	_after_reveal = to
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play("sprout")

func _update_partner() -> void:
	partner.visible = coop
	if not coop:
		return
	partner.position = hero.position + Vector2(10.0 if hero.flip_h else -10.0, 0.0)
	partner.flip_h = hero.flip_h
	if partner.animation != hero.animation:
		partner.play(hero.animation)

func hero_position() -> Vector2:
	return hero.position

func is_busy() -> bool:
	return not _legs.is_empty() or _reveal_seg >= 0

## Where the hero stands once the current reveal / walk is done (autosave).
func destination() -> int:
	if _reveal_seg >= 0:
		return _after_reveal
	if not _legs.is_empty():
		return _legs[_legs.size() - 1].to
	return at

# ------------------------------------------------------------------ input --
func net_state() -> Array:
	return [reach, at, hero.position, hero.animation, hero.flip_h, hero_index, coop, _reveal_seg, _reveal_k,
		_title.text, _hint.text, hero.sprite_frames.resource_path]

func apply_net_state(a: Array) -> void:
	if a.size() < 12:
		return
	puppet = true
	active = false
	visible = true
	_layer.visible = true
	reach = int(a[0])
	at = int(a[1])
	hero.position = a[2]
	if hero.sprite_frames == null or hero.sprite_frames.resource_path != a[11]:
		hero.sprite_frames = load(a[11])
		hero.offset = Vector2(0, -hero.sprite_frames.get_frame_texture(&"front", 0).get_height() * 0.5 + 2.0)
		partner.sprite_frames = load(String(a[11]).replace("hero_", "luigi_"))
		partner.offset = hero.offset
	if hero.animation != StringName(a[3]):
		hero.play(StringName(a[3]))
	hero.flip_h = a[4]
	hero_index = int(a[5])
	coop = a[6]
	_reveal_seg = int(a[7])
	_reveal_k = float(a[8])
	_title.text = a[9]
	_hint.text = a[10]
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not visible or Game.instance == null or Game.instance.state != Game.State.MAP:
		return
	if is_busy():
		return
	# directions first: the up arrow is also a "jump" key and must walk here,
	# not enter the course (there is no move_up action; ui_up = arrow/D-pad)
	var d := Vector2.ZERO
	if event.is_action_pressed("move_right"):
		d = Vector2.RIGHT
	elif event.is_action_pressed("move_left"):
		d = Vector2.LEFT
	elif event.is_action_pressed("ui_up"):
		d = Vector2.UP
	elif event.is_action_pressed("move_down"):
		d = Vector2.DOWN
	if d != Vector2.ZERO:
		get_viewport().set_input_as_handled()
		var n := _neighbour_toward(d)
		if n >= 0:
			_walk_to(n)
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if _delay <= 0.0:
			get_viewport().set_input_as_handled()
			_enter()
		return
	# a tap arrives as an emulated left click (touch -> mouse emulation)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (make_input_local(event) as InputEventMouseButton).position
		var best := -1
		var best_d := 20.0
		for i in reach + 1:
			var dd := p.distance_to(WorldMapData.NODES[i] + Vector2(0, -4))
			if dd < best_d:
				best_d = dd
				best = i
		if best < 0:
			return
		get_viewport().set_input_as_handled()
		if best == at:
			if _delay <= 0.0:
				_enter()
		else:
			_walk_to(best)

## The unlocked neighbour whose road leaves the current course roughly in
## direction d (roads curve, so compare with a point a few steps along).
func _neighbour_toward(d: Vector2) -> int:
	var best := -1
	var best_dot := 0.25
	for n in [at - 1, at + 1]:
		if n < 0 or n > reach:
			continue
		var pts: Array = WorldMapData.ROADS[mini(at, n)]
		var probe: Vector2 = pts[3] if n > at else pts[pts.size() - 4]
		var here: Vector2 = WorldMapData.NODES[at]
		var dir: Vector2 = (probe - here).normalized()
		var dot: float = dir.dot(d)
		if dot > best_dot:
			best_dot = dot
			best = n
	return best

func _enter() -> void:
	active = false
	var s := get_node_or_null("/root/Snd")
	if s:
		s.play("pipe")
	course_chosen.emit(at)

# ---------------------------------------------------------------- walking --
func _walk_to(target: int) -> void:
	_legs.clear()
	var i := at
	while i != target:
		var step := 1 if target > i else -1
		var pts: Array = WorldMapData.ROADS[mini(i, i + step)].duplicate()
		if step < 0:
			pts.reverse()
		_legs.append({"pts": pts, "to": i + step})
		i += step
	_leg_d = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_update_partner()
	if puppet:
		return
	_delay = maxf(_delay - delta, 0.0)
	if _reveal_seg >= 0:
		_reveal_k = minf(_reveal_k + delta / REVEAL_TIME, 1.0)
		queue_redraw()
		if _reveal_k >= 1.0:
			_reveal_seg = -1
			reach = _after_reveal
			_walk_to(_after_reveal)
			_update_banner()
		return
	if _legs.is_empty():
		if hero.animation != &"front":
			hero.play(&"front")
		return
	_leg_d += SPEED * delta
	var leg: Dictionary = _legs[0]
	var pos := _point_at(leg.pts, _leg_d)
	if pos.x != hero.position.x:
		hero.flip_h = pos.x < hero.position.x
	hero.position = pos
	if hero.animation != &"walk":
		hero.play(&"walk")
	if _leg_d >= _length(leg.pts):
		at = leg.to
		hero.position = WorldMapData.NODES[at]
		_legs.pop_front()
		_leg_d = 0.0
		_update_banner()
		node_changed.emit(at)
		if _legs.is_empty():
			_delay = 0.15

func _length(pts: Array) -> float:
	var l := 0.0
	for k in range(1, pts.size()):
		l += (pts[k] as Vector2).distance_to(pts[k - 1])
	return l

func _point_at(pts: Array, d: float) -> Vector2:
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var seg := a.distance_to(b)
		if d <= seg:
			return a.lerp(b, d / maxf(seg, 0.001))
		d -= seg
	return pts[pts.size() - 1]

func _update_banner() -> void:
	var lv: Script = Game.LEVELS[at]
	var done := at < reach
	_title.text = "%s%s  %s%s" % [player_label + ":  " if player_label != "" else "", lv.ID, _names[at],
		"  *" if done else ""]
	var touch := Game.instance != null and Game.instance.touch.visible
	_hint.text = ("tap again to play" if touch else "A / Space: play") if not is_busy() else ""

# ---------------------------------------------------------------- drawing --
func _draw() -> void:
	# roads: revealed ones in full, the one being revealed up to _reveal_k
	for i in WorldMapData.ROADS.size():
		var k := 1.0 if i < reach else (_reveal_k if i == _reveal_seg else 0.0)
		if k <= 0.0:
			continue
		var pts: Array = WorldMapData.ROADS[i]
		var kind: String = WorldMapData.ROAD_KIND[i]
		var line := _partial(pts, _length(pts) * k)
		draw_polyline(PackedVector2Array(line), ROAD_EDGE[kind], 5.0)
		draw_polyline(PackedVector2Array(line), ROAD_FILL[kind], 3.0)
	# course markers: cleared / open / locked
	var nc: Vector2i = WorldMapData.NODE_CELL
	var cc: Vector2i = WorldMapData.CASTLE_CELL
	var shown_reach := reach if _reveal_seg < 0 else _reveal_seg
	for i in WorldMapData.NODES.size():
		var frame := 1 if i < shown_reach else (0 if i == shown_reach else 2)
		var p: Vector2 = WorldMapData.NODES[i]
		if i in WorldMapData.CASTLES:
			draw_texture_rect_region(CASTLE_TEX, Rect2(p - Vector2(cc.x * 0.5, cc.y - 6), cc),
				Rect2(frame * cc.x, 0, cc.x, cc.y))
		else:
			draw_texture_rect_region(NODE_TEX, Rect2(p - Vector2(nc.x * 0.5, nc.y - 5), nc),
				Rect2(frame * nc.x, 0, nc.x, nc.y))

func _partial(pts: Array, d: float) -> Array:
	var out: Array = [pts[0]]
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var seg := a.distance_to(b)
		if d <= seg:
			out.append(a.lerp(b, d / maxf(seg, 0.001)))
			return out
		out.append(b)
		d -= seg
	return out
