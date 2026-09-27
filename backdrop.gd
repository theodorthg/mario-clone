class_name Backdrop
extends Node2D

## Themed background: a screen-filling sky (CanvasLayer -100 + sky.gdshader)
## plus horizontally repeating parallax layers.
##
## Each layer is ONE Sprite2D kept glued to the camera's left edge; its
## texture region scrolls by (camera x * factor), with texture_repeat on, so
## it appears to move `factor` times as fast as the world and repeats
## forever without seams (the art in tools/gen_backgrounds.py tiles at 640px).
## Vertically the layer sits at a world y and follows the camera by
## (1 - vfactor), so far layers barely move up/down.

const LAYERS := [
	# texture, world y of top edge, x factor, y factor, autoscroll px/s
	["res://assets/graphics/bg_clouds.png", 26.0, 0.12, 0.1, 5.0],
	["res://assets/graphics/bg_mountains.png", 72.0, 0.18, 0.35, 0.0],
	["res://assets/graphics/bg_hills_far.png", 150.0, 0.32, 0.6, 0.0],
	["res://assets/graphics/bg_hills_near.png", 178.0, 0.48, 0.75, 0.0],
	["res://assets/graphics/bg_trees.png", 196.0, 0.66, 0.9, 0.0],
]
## sky: [top, mid, horizon, mid_pos, stars, moon(, sun)]; tints: one per
## LAYERS entry (same order) — OR "layers": own list of [texture, y, fx, fy,
## auto, tint] for biomes with their own scenery; world: CanvasModulate tint
## for tiles + actors; fx: screen-space particles ("snow", "motes", "sand",
## "embers", "wind", "bubbles").
const THEMES := {
	"grass": {
		"sky": [Color("3b6bd6"), Color("73acf0"), Color("d8eefa"), 0.55, 0.0, 0.0],
		"tints": [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE],
		"world": Color.WHITE,
	},
	"sunset": {
		"sky": [Color("2a2a6c"), Color("c85f7c"), Color("ffc27a"), 0.5, 0.0, 0.0],
		"tints": [Color(1.0, 0.72, 0.66), Color(0.86, 0.6, 0.78), Color(0.95, 0.7, 0.62),
			Color(0.9, 0.76, 0.6), Color(0.6, 0.5, 0.55)],
		"world": Color(1.0, 0.9, 0.82),
	},
	"night": {
		"sky": [Color("04061a"), Color("122250"), Color("2c3d78"), 0.55, 1.0, 1.0],
		"tints": [Color(0.42, 0.48, 0.72), Color(0.34, 0.4, 0.66), Color(0.3, 0.4, 0.58),
			Color(0.28, 0.4, 0.52), Color(0.2, 0.28, 0.4)],
		"world": Color(0.66, 0.72, 0.96),
	},
	"cave": {
		"sky": [Color("05060d"), Color("0c1024"), Color("1a2140"), 0.5, 0.0, 0.0],
		"tints": [],
		"world": Color.WHITE,
	},
	"cavern": {
		"sky": [Color("04050c"), Color("0c1026"), Color("171d3c"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_cave_far.png", 50.0, 0.18, 0.15, 0.0, Color.WHITE],
			["res://assets/graphics/bg_cave_crystals.png", 172.0, 0.38, 0.7, 0.0, Color.WHITE],
			["res://assets/graphics/bg_cave_near.png", 206.0, 0.6, 0.9, 0.0, Color.WHITE],
		],
		"world": Color(0.9, 0.9, 1.0),
		"fx": "motes",
	},
	"desert": {
		"sky": [Color("2a70d0"), Color("78bcf0"), Color("fce6b4"), 0.5, 0.0, 0.0, 1.0],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 22.0, 0.12, 0.1, 4.0, Color(1.0, 0.97, 0.9, 0.7)],
			["res://assets/graphics/bg_pyramids.png", 104.0, 0.2, 0.4, 0.0, Color.WHITE],
			["res://assets/graphics/bg_dunes_far.png", 150.0, 0.32, 0.6, 0.0, Color.WHITE],
			["res://assets/graphics/bg_cacti.png", 176.0, 0.5, 0.78, 0.0, Color.WHITE],
		],
		"world": Color(1.0, 0.97, 0.9),
		"fx": "sand",
	},
	"snow": {
		"sky": [Color("5a7ab8"), Color("a4c0e6"), Color("eef4fc"), 0.55, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 26.0, 0.12, 0.1, 3.0, Color(0.95, 0.97, 1.0)],
			["res://assets/graphics/bg_mountains.png", 72.0, 0.18, 0.35, 0.0, Color(0.92, 0.96, 1.0)],
			["res://assets/graphics/bg_pines_far.png", 138.0, 0.3, 0.6, 0.0, Color.WHITE],
			["res://assets/graphics/bg_snowhills.png", 178.0, 0.45, 0.75, 0.0, Color.WHITE],
			["res://assets/graphics/bg_pines_near.png", 190.0, 0.62, 0.9, 0.0, Color.WHITE],
		],
		"world": Color(0.96, 0.98, 1.0),
		"fx": "snow",
	},
	"fortress": {
		"sky": [Color("0a0206"), Color("3a0a14"), Color("8a2a18"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_castle_wall.png", 50.0, 0.15, 0.15, 0.0, Color.WHITE],
			["res://assets/graphics/bg_castle_pillars.png", 84.0, 0.42, 0.8, 0.0, Color(0.8, 0.76, 0.84)],
		],
		"world": Color(1.0, 0.92, 0.88),
		"fx": "embers",
	},
	# castle moods per world (v0.14: the castles looked all alike)
	"fortress_magma": {
		"sky": [Color("140202"), Color("5a1206"), Color("d0400e"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_castle_wall.png", 50.0, 0.15, 0.15, 0.0, Color(1.0, 0.72, 0.6)],
			["res://assets/graphics/bg_castle_pillars.png", 84.0, 0.42, 0.8, 0.0, Color(0.9, 0.6, 0.55)],
		],
		"world": Color(1.0, 0.84, 0.74),
		"fx": "embers",
	},
	"fortress_sun": {
		"sky": [Color("2a1a08"), Color("7a4a18"), Color("e0a050"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_castle_wall.png", 50.0, 0.15, 0.15, 0.0, Color(1.0, 0.88, 0.62)],
			["res://assets/graphics/bg_castle_pillars.png", 84.0, 0.42, 0.8, 0.0, Color(1.0, 0.86, 0.64)],
		],
		"world": Color(1.0, 0.92, 0.74),
		"fx": "sand",
	},
	"fortress_ice": {
		"sky": [Color("06102a"), Color("1a3a6a"), Color("5a8ac0"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_castle_wall.png", 50.0, 0.15, 0.15, 0.0, Color(0.72, 0.86, 1.0)],
			["res://assets/graphics/bg_castle_pillars.png", 84.0, 0.42, 0.8, 0.0, Color(0.7, 0.84, 1.0)],
		],
		"world": Color(0.82, 0.92, 1.0),
		"fx": "snow",
	},
	"fortress_storm": {
		"sky": [Color("0a0818"), Color("2a2250"), Color("5a4a8a"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_castle_wall.png", 50.0, 0.15, 0.15, 0.0, Color(0.72, 0.68, 0.9)],
			["res://assets/graphics/bg_castle_pillars.png", 84.0, 0.42, 0.8, 0.0, Color(0.66, 0.62, 0.86)],
		],
		"world": Color(0.86, 0.84, 0.98),
		"fx": "wind",
	},
	"fortress_tide": {
		"sky": [Color("021014"), Color("0a3a40"), Color("1a7a7a"), 0.5, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_castle_wall.png", 50.0, 0.15, 0.15, 0.0, Color(0.62, 0.9, 0.86)],
			["res://assets/graphics/bg_castle_pillars.png", 84.0, 0.42, 0.8, 0.0, Color(0.6, 0.86, 0.84)],
		],
		"world": Color(0.8, 0.96, 0.94),
		"fx": "bubbles",
	},
	"desert_dusk": {
		# sun sinking behind the dunes: purple-orange sky, warm dark layers
		"sky": [Color("2c2466"), Color("c05a78"), Color("ffb870"), 0.45, 0.0, 0.0, 1.0, Vector2(0.72, 0.52)],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 22.0, 0.12, 0.1, 4.0, Color(1.0, 0.7, 0.7, 0.75)],
			["res://assets/graphics/bg_pyramids.png", 104.0, 0.2, 0.4, 0.0, Color(0.82, 0.5, 0.52)],
			["res://assets/graphics/bg_dunes_far.png", 150.0, 0.32, 0.6, 0.0, Color(0.95, 0.66, 0.56)],
			["res://assets/graphics/bg_cacti.png", 176.0, 0.5, 0.78, 0.0, Color(0.72, 0.52, 0.5)],
		],
		"world": Color(1.0, 0.86, 0.78),
		"fx": "sand",
	},
	"map": {
		# world map (v1.1): the map picture covers the view — no parallax, no fx
		"sky": [Color("3b6bd6"), Color("73acf0"), Color("d8eefa"), 0.55, 0.0, 0.0],
		"layers": [],
		"world": Color.WHITE,
	},
	"sky": {
		# above the clouds: deep blue, sun high up, islands + a sea of clouds
		"sky": [Color("2a70dc"), Color("78c0f6"), Color("e6f4ff"), 0.55, 0.0, 0.0, 1.0, Vector2(0.78, 0.16)],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 20.0, 0.12, 0.1, 6.0, Color.WHITE],
			["res://assets/graphics/bg_sky_islands.png", 92.0, 0.2, 0.35, 0.0, Color.WHITE],
			["res://assets/graphics/bg_sky_sea_far.png", 150.0, 0.3, 0.55, 2.0, Color(0.86, 0.9, 1.0)],
			["res://assets/graphics/bg_sky_sea_near.png", 224.0, 0.5, 0.8, 4.0, Color(0.78, 0.84, 0.98)],
		],
		"world": Color.WHITE,
		"fx": "wind",
	},
	"sky_dusk": {
		"sky": [Color("2a2268"), Color("d0688c"), Color("ffc890"), 0.5, 0.0, 0.0, 1.0, Vector2(0.74, 0.5)],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 20.0, 0.12, 0.1, 6.0, Color(1.0, 0.72, 0.72, 0.85)],
			["res://assets/graphics/bg_sky_islands.png", 92.0, 0.2, 0.35, 0.0, Color(0.8, 0.56, 0.66)],
			["res://assets/graphics/bg_sky_sea_far.png", 150.0, 0.3, 0.55, 2.0, Color(1.0, 0.76, 0.72)],
			["res://assets/graphics/bg_sky_sea_near.png", 224.0, 0.5, 0.8, 4.0, Color(0.92, 0.66, 0.7)],
		],
		"world": Color(1.0, 0.9, 0.86),
		"fx": "wind",
	},
	"sea": {
		# underwater: light from the surface, reef hills, kelp, rising bubbles
		"sky": [Color("5abaea"), Color("1c6cb4"), Color("0b2e62"), 0.45, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_sea_rays.png", 0.0, 0.1, 0.1, 3.0, Color(1, 1, 1, 0.9)],
			["res://assets/graphics/bg_sea_far.png", 110.0, 0.18, 0.4, 0.0, Color.WHITE],
			["res://assets/graphics/bg_sea_kelp.png", 128.0, 0.32, 0.6, 0.0, Color.WHITE],
			["res://assets/graphics/bg_sea_near.png", 206.0, 0.5, 0.8, 0.0, Color.WHITE],
		],
		"world": Color(0.82, 0.93, 1.0),
		"fx": "bubbles",
	},
	"sea_deep": {
		"sky": [Color("2a6aa8"), Color("0e3470"), Color("040e2a"), 0.4, 0.0, 0.0],
		"layers": [
			["res://assets/graphics/bg_sea_rays.png", 0.0, 0.1, 0.1, 2.0, Color(0.7, 0.8, 1.0, 0.5)],
			["res://assets/graphics/bg_sea_far.png", 110.0, 0.18, 0.4, 0.0, Color(0.55, 0.62, 0.85)],
			["res://assets/graphics/bg_sea_kelp.png", 128.0, 0.32, 0.6, 0.0, Color(0.5, 0.64, 0.8)],
			["res://assets/graphics/bg_sea_near.png", 206.0, 0.5, 0.8, 0.0, Color(0.5, 0.58, 0.8)],
		],
		"world": Color(0.66, 0.78, 0.98),
		"fx": "bubbles",
	},
	"beach": {
		"sky": [Color("3b6bd6"), Color("73acf0"), Color("d8eefa"), 0.55, 0.0, 0.0, 1.0, Vector2(0.2, 0.18)],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 26.0, 0.12, 0.1, 5.0, Color.WHITE],
			["res://assets/graphics/bg_beach_sea.png", 150.0, 0.2, 0.55, 0.0, Color.WHITE],
			["res://assets/graphics/bg_palms.png", 158.0, 0.36, 0.7, 0.0, Color.WHITE],
		],
		"world": Color.WHITE,
	},
	"snow_night": {
		"sky": [Color("050a20"), Color("16285a"), Color("3a4f8a"), 0.55, 1.0, 1.0],
		"layers": [
			["res://assets/graphics/bg_clouds.png", 26.0, 0.12, 0.1, 3.0, Color(0.4, 0.46, 0.7, 0.8)],
			["res://assets/graphics/bg_mountains.png", 72.0, 0.18, 0.35, 0.0, Color(0.46, 0.54, 0.8)],
			["res://assets/graphics/bg_pines_far.png", 138.0, 0.3, 0.6, 0.0, Color(0.4, 0.5, 0.74)],
			["res://assets/graphics/bg_snowhills.png", 178.0, 0.45, 0.75, 0.0, Color(0.52, 0.62, 0.86)],
			["res://assets/graphics/bg_pines_near.png", 190.0, 0.62, 0.9, 0.0, Color(0.34, 0.42, 0.62)],
		],
		"world": Color(0.72, 0.8, 1.0),
		"fx": "snow",
	},
}
const REF_CAM_Y := 185.0

var camera: Camera2D
var _sky_layer: CanvasLayer
var _sky: ColorRect
var _layers: Array = []    # [{sprite, y, fx, fy, auto}]
var _time := 0.0
var theme := ""
var _world_tint: CanvasModulate
var _para_layer: CanvasLayer
var _fx_layer: CanvasLayer
var _fx: CPUParticles2D
var _fx_size := Vector2.ZERO

func _ready() -> void:
	z_index = -50
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -100
	add_child(_sky_layer)
	_sky = ColorRect.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/ui/sky.gdshader")
	_sky.material = mat
	_sky_layer.add_child(_sky)
	# parallax sprites live on their own CanvasLayer that follows the camera
	# like the world does, so the world's CanvasModulate tint does not darken
	# them a second time (they carry their own per-theme tint)
	_para_layer = CanvasLayer.new()
	_para_layer.layer = -50
	_para_layer.follow_viewport_enabled = true
	add_child(_para_layer)
	_world_tint = CanvasModulate.new()
	add_child(_world_tint)
	# weather / ambience particles in screen space, above the world
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 5
	add_child(_fx_layer)

func set_theme(name: String) -> void:
	if name == theme:
		return
	theme = name
	var th: Dictionary = THEMES.get(name, THEMES["grass"])
	var mat: ShaderMaterial = _sky.material
	mat.set_shader_parameter("top_color", th.sky[0])
	mat.set_shader_parameter("mid_color", th.sky[1])
	mat.set_shader_parameter("horizon_color", th.sky[2])
	mat.set_shader_parameter("mid_pos", th.sky[3])
	mat.set_shader_parameter("stars", th.sky[4])
	mat.set_shader_parameter("moon", th.sky[5])
	mat.set_shader_parameter("sun", th.sky[6] if th.sky.size() > 6 else 0.0)
	mat.set_shader_parameter("sun_uv", th.sky[7] if th.sky.size() > 7 else Vector2(0.8, 0.2))
	_world_tint.color = th.world
	for l in _layers:
		l.sprite.queue_free()
	_layers.clear()
	var specs: Array = []
	if th.has("layers"):
		specs = th.layers
	else:
		for i in th.tints.size():
			specs.append(LAYERS[i] + [th.tints[i]])
	for spec in specs:
		var s := Sprite2D.new()
		s.texture = load(spec[0])
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.self_modulate = spec[5]
		_para_layer.add_child(s)
		_layers.append({"sprite": s, "y": spec[1], "fx": spec[2], "fy": spec[3], "auto": spec[4]})
	_set_fx(th.get("fx", ""))
	_process(0.0)

func _set_fx(kind: String) -> void:
	if _fx:
		_fx.queue_free()
		_fx = null
	if kind == "":
		return
	var p := CPUParticles2D.new()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.local_coords = false
	match kind:
		"snow":
			p.amount = 110
			p.lifetime = 8.0
			p.direction = Vector2(0.25, 1.0)
			p.spread = 18.0
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector2(0, 4)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			p.color = Color(1, 1, 1, 0.9)
		"motes":
			p.amount = 36
			p.lifetime = 7.0
			p.direction = Vector2(0.2, -1.0)
			p.spread = 60.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.0
			var g := Gradient.new()
			g.set_color(0, Color(0.5, 0.95, 1.0, 0.0))
			g.set_color(1, Color(0.5, 0.95, 1.0, 0.0))
			g.add_point(0.3, Color(0.6, 0.95, 1.0, 0.8))
			g.add_point(0.7, Color(0.85, 0.7, 1.0, 0.7))
			p.color_ramp = g
		"embers":
			p.amount = 40
			p.lifetime = 6.0
			p.direction = Vector2(0.15, -1.0)
			p.spread = 25.0
			p.initial_velocity_min = 12.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector2(0, -4)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			var ge := Gradient.new()
			ge.set_color(0, Color(1.0, 0.8, 0.3, 0.9))
			ge.set_color(1, Color(0.9, 0.2, 0.1, 0.0))
			p.color_ramp = ge
		"sand":
			p.amount = 40
			p.lifetime = 5.0
			p.direction = Vector2(-1.0, 0.12)
			p.spread = 6.0
			p.initial_velocity_min = 55.0
			p.initial_velocity_max = 95.0
			p.gravity = Vector2(0, 2)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.0
			p.color = Color(1.0, 0.9, 0.66, 0.55)
		"wind":
			# thin fast streaks drifting left (drawn with a 7x1 fading dash)
			p.amount = 18
			p.lifetime = 3.0
			p.direction = Vector2(-1.0, 0.02)
			p.spread = 2.0
			p.initial_velocity_min = 150.0
			p.initial_velocity_max = 230.0
			p.gravity = Vector2.ZERO
			var img := Image.create_empty(7, 1, false, Image.FORMAT_RGBA8)
			for x in 7:
				img.set_pixel(x, 0, Color(1, 1, 1, 0.25 + 0.1 * x))
			p.texture = ImageTexture.create_from_image(img)
			p.color = Color(1, 1, 1, 0.55)
		"bubbles":
			# small rising rings, wobbling a little
			p.amount = 26
			p.lifetime = 7.0
			p.direction = Vector2(0.0, -1.0)
			p.spread = 12.0
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector2(0, -3)
			var bi := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
			for pt in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(3, 1), Vector2i(0, 2),
					Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3)]:
				bi.set_pixelv(pt, Color(1, 1, 1, 0.8))
			bi.set_pixel(1, 1, Color(1, 1, 1, 0.9))
			p.texture = ImageTexture.create_from_image(bi)
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.0
			p.color = Color(0.85, 0.95, 1.0, 0.7)
	p.preprocess = p.lifetime
	_fx = p
	_fx_size = Vector2.ZERO
	_fx_layer.add_child(p)

func _process(delta: float) -> void:
	_time += delta
	if camera == null:
		return
	var view := get_viewport_rect().size
	if _fx and view != _fx_size:
		# emit from the whole screen (plus margin) so no edge stays empty
		_fx_size = view
		_fx.position = view * 0.5 + Vector2(40, -20)
		_fx.emission_rect_extents = view * 0.5 + Vector2(60, 40)
	var cam := camera.get_screen_center_position()
	var left := cam.x - view.x * 0.5
	for l in _layers:
		var s: Sprite2D = l.sprite
		var h: float = s.texture.get_height()
		var ox: float = left * l.fx + _time * l.auto
		s.region_rect = Rect2(roundf(ox), 0.0, view.x + 2.0, h)
		s.global_position = Vector2(roundf(left) - 1.0, roundf(l.y + (cam.y - REF_CAM_Y) * (1.0 - l.fy)))
