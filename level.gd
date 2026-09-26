class_name Level
extends Node2D

## Builds one level from a generated levels/level_*.gd data script (ASCII grid
## + metadata, see tools/make_levels.py): terrain goes into a TileMapLayer with
## a TileSet created at runtime from assets/graphics/tiles.png; interactive
## things (blocks, coins, enemies, pipes' warp zones, flag, castle, decor)
## become their own nodes.
##
## Coordinates: cell (c, r) covers x in [c*16, c*16+16), y in [r*16, r*16+16).
## Every actor's origin is its FEET (bottom center), so an actor standing on
## cell row r has position.y == r*16 (top edge of that cell).

const T := 16
const ROWS := 20

# tiles.png atlas layout — keep in sync with tools/gen_tiles.py
const ROW_GRASS := 0
const ROW_MISC := 1
const ROW_PIPE := 2
const ROW_CAVE := 3
const HARD := Vector2i(4, 1)
const BRIDGE_L := Vector2i(5, 1)
const BRIDGE_M := Vector2i(6, 1)
const BRIDGE_R := Vector2i(7, 1)
const CAVE_BRICK := Vector2i(10, 1)
const WATER_TOP := Vector2i(11, 1)    # 4-frame tile animation (11..14)
const WATER := Vector2i(15, 1)
const PIPE_TOP_L := Vector2i(0, 2)
const PIPE_TOP_R := Vector2i(1, 2)
const PIPE_BODY_L := Vector2i(2, 2)
const PIPE_BODY_R := Vector2i(3, 2)
const SIDE_MOUTH_T := Vector2i(4, 2)
const SIDE_MOUTH_B := Vector2i(5, 2)
const SIDE_BODY_T := Vector2i(6, 2)
const SIDE_BODY_B := Vector2i(7, 2)

const DECOR := {"*": "bush_l", "+": "bush_s", "f": "flower_a", "t": "tuft", "r": "rock",
	"s": "sign", "n": "fence"}
const FLOWERS := ["flower_a", "flower_b", "flower_c"]

var data: Script
var grid: PackedStringArray
var cols := 0
var tiles: TileMapLayer
var water: TileMapLayer
var start_pos := Vector2.ZERO
var checkpoints: Array[Vector2] = []
var flagpole: Flagpole
var castle_door := Vector2.ZERO
var castle_flag: Sprite2D
var areas := {}                 # name -> {"rect": Rect2, "theme": String}
var warps: Array = []           # [{zone: WarpZone, ...}]
var decor_tex: Texture2D

static var _tileset_cache: TileSet

func setup(level_script: Script) -> void:
	data = level_script
	grid = PackedStringArray(data.GRID)
	cols = grid[0].length()
	decor_tex = load("res://assets/graphics/decor.png")
	_build_tiles()
	_build_entities()
	_build_meta()

func cell_center(c: int, r: int) -> Vector2:
	return Vector2(c * T + T * 0.5, r * T + T * 0.5)

func cell_feet(c: int, r: int) -> Vector2:
	return Vector2(c * T + T * 0.5, (r + 1) * T)

func at(c: int, r: int) -> String:
	if r < 0 or r >= ROWS or c < 0 or c >= cols:
		return "."
	return grid[r][c]

func area_at(x: float) -> String:
	for name in areas:
		var rect: Rect2 = areas[name].rect
		if x >= rect.position.x and x <= rect.end.x:
			return name
	return "main"

func bottom_y() -> float:
	return ROWS * T

# ------------------------------------------------------------------ tiles --
static func tileset() -> TileSet:
	if _tileset_cache:
		return _tileset_cache
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/graphics/tiles.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var plank := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)])
	var size: Vector2i = src.texture.get_size() / T
	for y in size.y:
		for x in size.x:
			var coords := Vector2i(x, y)
			if y == ROW_MISC and x > WATER_TOP.x and x < WATER.x:
				continue      # animation frames of WATER_TOP, not tiles of their own
			src.create_tile(coords)
			if coords == WATER_TOP:
				src.set_tile_animation_columns(coords, 4)
				src.set_tile_animation_frames_count(coords, 4)
				for f in 4:
					src.set_tile_animation_frame_duration(coords, f, 0.18)
			if coords == WATER_TOP or coords == WATER:
				continue      # water: no collision (falling in = pit death)
			var td := src.get_tile_data(coords, 0)
			var one_way := y == ROW_MISC and x >= BRIDGE_L.x and x <= BRIDGE_R.x
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, plank if one_way else full)
			if one_way:
				td.set_collision_polygon_one_way(0, 0, true)
	_tileset_cache = ts
	return ts

func _build_tiles() -> void:
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = tileset()
	tiles.z_index = 0
	add_child(tiles)
	# water sits in FRONT of actors (you sink behind the surface), see-through
	water = TileMapLayer.new()
	water.name = "Water"
	water.tile_set = tiles.tile_set
	water.z_index = 2
	water.collision_enabled = false
	add_child(water)
	for r in ROWS:
		for c in cols:
			var ch := grid[r][c]
			match ch:
				"#":
					tiles.set_cell(Vector2i(c, r), 0, _ground_tile(c, r, "#", ROW_GRASS))
				"c":
					tiles.set_cell(Vector2i(c, r), 0, _ground_tile(c, r, "c", ROW_CAVE))
				"X":
					tiles.set_cell(Vector2i(c, r), 0, HARD)
				"w":
					tiles.set_cell(Vector2i(c, r), 0, CAVE_BRICK)
				"=":
					var l := at(c - 1, r) == "="
					var rr := at(c + 1, r) == "="
					tiles.set_cell(Vector2i(c, r), 0, BRIDGE_M if (l and rr) else (BRIDGE_L if rr else BRIDGE_R))
				"v":
					water.set_cell(Vector2i(c, r), 0, WATER if at(c, r - 1) == "v" else WATER_TOP)
				"P", "W", "Q":
					_place_pipe(c, r)
				">":
					_place_side_pipe(c, r)

func _is_ground(c: int, r: int, ch: String) -> bool:
	# outside the grid: left/right/bottom continue the ground, top is open sky
	if r >= ROWS or c < 0 or c >= cols:
		return true
	if r < 0:
		return false
	return grid[r][c] == ch

func _ground_tile(c: int, r: int, ch: String, row: int) -> Vector2i:
	var m := 0
	if not _is_ground(c, r - 1, ch):
		m |= 1
	if not _is_ground(c, r + 1, ch):
		m |= 2
	if not _is_ground(c - 1, r, ch):
		m |= 4
	if not _is_ground(c + 1, r, ch):
		m |= 8
	if m == 0 and row == ROW_GRASS:
		# interior dirt: a few deterministic texture variants
		var h := (c * 73856093) ^ (r * 19349663)
		var v := absi(h) % 20
		return Vector2i(0 if v < 12 else (1 if v < 14 else (2 if v < 17 else 3)), ROW_MISC)
	if m == 0 and row == ROW_CAVE:
		return Vector2i(8 + (absi(c * 7 + r * 13) % 2), ROW_MISC)
	return Vector2i(m, row)

func _pipe_free(ch: String) -> bool:
	return ch in [".", "o", "g", "G"] or DECOR.has(ch)

func _place_pipe(c: int, r: int) -> void:
	tiles.set_cell(Vector2i(c, r), 0, PIPE_TOP_L)
	tiles.set_cell(Vector2i(c + 1, r), 0, PIPE_TOP_R)
	var rr := r + 1
	while rr < ROWS and _pipe_free(at(c, rr)) and _pipe_free(at(c + 1, rr)):
		tiles.set_cell(Vector2i(c, rr), 0, PIPE_BODY_L)
		tiles.set_cell(Vector2i(c + 1, rr), 0, PIPE_BODY_R)
		rr += 1

func _place_side_pipe(c: int, r: int) -> void:
	tiles.set_cell(Vector2i(c, r), 0, SIDE_MOUTH_T)
	tiles.set_cell(Vector2i(c, r + 1), 0, SIDE_MOUTH_B)
	var cc := c + 1
	while cc < cols and at(cc, r) == "." and at(cc, r + 1) == ".":
		tiles.set_cell(Vector2i(cc, r), 0, SIDE_BODY_T)
		tiles.set_cell(Vector2i(cc, r + 1), 0, SIDE_BODY_B)
		cc += 1

# --------------------------------------------------------------- entities --
func _build_entities() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.ID)
	var decor_layer := Node2D.new()
	decor_layer.name = "Decor"
	decor_layer.z_index = -1
	add_child(decor_layer)
	move_child(decor_layer, 0)
	for r in ROWS:
		for c in cols:
			var ch := grid[r][c]
			match ch:
				"?":
					_add_block(c, r, Block.Kind.QUESTION, "coin")
				"M":
					_add_block(c, r, Block.Kind.QUESTION, "powerup")
				"Y":
					_add_block(c, r, Block.Kind.QUESTION, "egg")
				"B":
					_add_block(c, r, Block.Kind.BRICK, "")
				"S":
					_add_block(c, r, Block.Kind.BRICK, "star")
				"C":
					_add_block(c, r, Block.Kind.BRICK, "multicoin")
				"U":
					_add_block(c, r, Block.Kind.BRICK, "oneup")
				"h":
					_add_block(c, r, Block.Kind.HIDDEN, "oneup")
				"o":
					var coin := Coin.new()
					coin.position = cell_feet(c, r)
					add_child(coin)
				"g", "G":
					var e := Shroom.new()
					e.winged = ch == "G"
					e.position = cell_feet(c, r)
					add_child(e)
				"Q":
					var ch_plant := Chomper.new()
					ch_plant.pipe_top = Vector2((c + 1) * T, r * T)
					ch_plant.z_index = -1
					add_child(ch_plant)
				_:
					if DECOR.has(ch):
						var name: String = DECOR[ch]
						if ch == "f":
							name = FLOWERS[rng.randi() % FLOWERS.size()]
						_add_decor(decor_layer, name, cell_feet(c, r))

func _add_block(c: int, r: int, kind: int, content: String) -> void:
	var b := Block.new()
	b.kind = kind
	b.content = content
	b.cave = data.AREAS.has("bonus") and c >= int(data.AREAS["bonus"]["from"])
	b.position = cell_center(c, r)
	add_child(b)

func _add_decor(parent: Node, name: String, feet: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	var at_tex := AtlasTexture.new()
	at_tex.atlas = decor_tex
	at_tex.region = DecorIndex.RECTS[name]
	s.texture = at_tex
	s.centered = false
	s.position = Vector2(roundf(feet.x - at_tex.region.size.x * 0.5), feet.y - at_tex.region.size.y)
	parent.add_child(s)
	return s

func _build_meta() -> void:
	start_pos = cell_feet(data.START.x, data.START.y)
	for cp in data.CHECKPOINTS:
		checkpoints.append(cell_feet(cp.x, cp.y))
		var marker := Checkpoint.new()
		marker.position = cell_feet(cp.x, cp.y)
		add_child(marker)
	for name in data.AREAS:
		var a: Dictionary = data.AREAS[name]
		var rect := Rect2(a["from"] * T, 0, (a["to"] - a["from"] + 1) * T, ROWS * T)
		areas[name] = {"rect": rect, "theme": a["theme"]}
	# flag pole: base block is the grid's X at FLAG; pole rises above it
	flagpole = Flagpole.new()
	flagpole.position = Vector2(data.FLAG.x * T + T * 0.5, data.FLAG.y * T)
	flagpole.decor_tex = decor_tex
	add_child(flagpole)
	# castle: bottom-left at CASTLE cell's bottom-left
	var cs := _add_decor(self, "castle", Vector2(data.CASTLE.x * T + 40, (data.CASTLE.y + 1) * T))
	cs.z_index = -1
	castle_door = Vector2(data.CASTLE.x * T + 40, (data.CASTLE.y + 1) * T)
	# flag hidden inside the tower top, raised by raise_castle_flag()
	castle_flag = _add_decor(self, "castle_flag", Vector2(data.CASTLE.x * T + 46, cs.position.y + 22))
	castle_flag.z_index = -2
	for w in data.WARPS:
		var z := WarpZone.new()
		z.kind = w["kind"]
		var e: Vector2i = w["entry"]
		if z.kind == "down":
			z.position = Vector2((e.x + 1) * T, e.y * T)          # pipe top center
		else:
			z.position = Vector2(e.x * T, (e.y + 2) * T)          # side mouth, floor level
		z.warp = w
		add_child(z)
		warps.append(w)

func raise_castle_flag() -> void:
	if castle_flag:
		var tw := create_tween()
		tw.tween_property(castle_flag, "position:y", castle_flag.position.y - 15.0, 0.8)

func arrive_position(w: Dictionary) -> Vector2:
	var a: Vector2i = w["arrive"]
	if w["arrive_kind"] == "up":
		return Vector2((a.x + 1) * T, a.y * T)
	return cell_feet(a.x, a.y)
