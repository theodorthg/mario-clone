class_name Game
extends Node2D

## Top-level conductor: title/attract screen, world map (v1.1), "WORLD 1-1"
## card, playing, death, pipe warps, flag-pole finish with time bonus, game
## over. A run: Play -> map -> course -> (clear) -> map -> ... Score, lives
## and power carry across the map; the level select cheat / "Boss" starts a
## course directly and joins the same flow afterwards.
## v1.2: the run is saved all along (save_run -> SaveGame + its high score
## entry); the title offers "Continue", quitting asks first.
## Entities talk to it through Game.instance (add_score, add_coin,
## award_chain, collect_powerup, change_power, player_died, enter_warp,
## flag_reached, set_checkpoint, is_near_view, enemy_speed_mul).
##
## "Freezing" the world (grow/shrink flicker, death) sets World's
## process_mode to DISABLED; this node itself always processes and drives
## those short sequences with its own tweens.

enum State { TITLE, INTRO, PLAYING, TRANSITION, DYING, CLEAR, GAMEOVER, MAP }

const THEME_MUSIC := {"cave": "music_cave", "cavern": "music_cave", "desert": "music_desert",
	"desert_dusk": "music_desert", "snow": "music_snow", "snow_night": "music_snow", "fortress": "music_castle",
	"sky": "music_sky", "sky_dusk": "music_sky", "sea": "music_sea", "sea_deep": "music_sea",
	"fortress_magma": "music_castle", "fortress_sun": "music_castle", "fortress_ice": "music_castle",
	"fortress_storm": "music_castle", "fortress_tide": "music_castle",
	"ghost": "music_ghost", "ghost_yard": "music_ghost", "fortress_ghost": "music_castle",
	"volcano": "music_volcano", "volcano_core": "music_volcano", "fortress_volcano": "music_castle"}
const MAP_THEME := "map"
const WORLD_NAMES := ["Meadows", "Caverns", "Desert", "Snow", "Sky", "Sea", "Ghosts", "Volcano"]
const LEVELS := [
	preload("res://levels/level_1_1.gd"),
	preload("res://levels/level_1_2.gd"),
	preload("res://levels/level_1_3.gd"),
	preload("res://levels/level_1_4.gd"),
	preload("res://levels/level_2_1.gd"),
	preload("res://levels/level_2_2.gd"),
	preload("res://levels/level_2_3.gd"),
	preload("res://levels/level_3_1.gd"),
	preload("res://levels/level_3_2.gd"),
	preload("res://levels/level_3_3.gd"),
	preload("res://levels/level_4_1.gd"),
	preload("res://levels/level_4_2.gd"),
	preload("res://levels/level_4_3.gd"),
	preload("res://levels/level_5_1.gd"),
	preload("res://levels/level_5_2.gd"),
	preload("res://levels/level_5_3.gd"),
	preload("res://levels/level_6_1.gd"),
	preload("res://levels/level_6_2.gd"),
	preload("res://levels/level_6_3.gd"),
	preload("res://levels/level_7_1.gd"),
	preload("res://levels/level_7_2.gd"),
	preload("res://levels/level_7_3.gd"),
	preload("res://levels/level_8_1.gd"),
	preload("res://levels/level_8_2.gd"),
	preload("res://levels/level_8_3.gd"),
]
const CHAIN := [100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000]
const TIME_TICK := 0.4
const STAR_TIME := 10.0
const CARD_TIME := 2.2
const PlayerScript := preload("res://player.gd")

static var instance: Game

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var backdrop: Backdrop = $Backdrop
@onready var hud: Hud = $HUD/Root
@onready var menus: Menus = $Menus/Root
@onready var touch: TouchControls = $Touch/Root

var state: int = State.TITLE
var cfg := {}
var level: Level
var player: Player
var level_index := 0
var score := 0
var coins := 0
var lives := 3
var time_left := 0
var power := 0
var has_dino := false
## the dragon can't swim: in an underwater course it waits "off stage" and
## comes back in the next course (unless the hero loses a life)
var _dino_parked := false
var checkpoint_pos = null
var area := "main"
var _time_acc := 0.0
var _hurry := false
var _paused := false
var _touch := false
var _last_window := Vector2i.ZERO
var _attract_dir := 1.0
var _cam_pos := Vector2.ZERO
var _freeze_tween: Tween
var _tally_step := 1
## true once the level select cheat started a course not reached yet:
## the whole run then gets no high score entry and saves no progress
var cheated := false
var world_map: WorldMap
## furthest course this run may enter from the map (saved progress, or
## further when the level select started a course beyond it)
var _run_reach := 0
## furthest course entered in this run (for its high score entry)
var _run_best := 0
## the run's saved game / high score entry (SaveGame.new_id) and the name
## the player gave it ("" = not asked yet, the entry reads "YOU")
var run_id := 0
var run_name := ""
## started from the level select: never written to the saved game and no
## high score entry, so trying a course there can't replace the player's
## real run or fill up the list
var practice := false
var splash: Splash

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	backdrop.camera = camera
	cfg = GameSettings.load_all()
	ControlsConfig.apply()
	_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	hud.pause_pressed.connect(_toggle_pause)
	hud.mute_pressed.connect(_toggle_mute)
	hud.set_muted(_snd_call("is_muted", false))
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.mute_changed.connect(hud.set_muted)     # also when muted in the Sound menu
	menus.play_pressed.connect(func(i: int):
		if i < 0:
			start_map_run()           # "Play" / "New Game": the world map
		else:
			_start_game(i, menus.take_cheat(), menus.take_boss()))
	menus.continue_pressed.connect(continue_run)
	menus.resume_pressed.connect(_resume)
	menus.restart_pressed.connect(func():
		# "Play Again": a fresh run, back on the map where the last one ended
		_new_run(cheated, practice)
		_run_reach = maxi(_run_reach, level_index)
		_show_map(level_index))
	menus.quit_to_menu_pressed.connect(_to_title)
	menus.settings_changed.connect(func(c):
		cfg = c
		apply_touch_layout())
	Input.joy_connection_changed.connect(func(_id, _connected): apply_touch_layout())
	add_to_group("touch_layout_listeners")
	get_window().size_changed.connect(_apply_display_mode)
	_last_window = DisplayServer.window_get_size()
	_apply_display_mode()
	# splash with a fake loading bar first, then the title screen
	splash = Splash.new()
	add_child(splash)
	splash.done.connect(_to_title, CONNECT_ONE_SHOT)

## Tests/tools: jump straight to the title screen.
func skip_splash() -> void:
	if splash and is_instance_valid(splash):
		splash.finish()

## World freeze / thaw. Deferred: this is often triggered from inside a
## physics callback (area body_entered), where disabling CollisionObjects
## directly is not allowed.
func _set_world_active(on: bool) -> void:
	world.set_deferred("process_mode", Node.PROCESS_MODE_PAUSABLE if on else Node.PROCESS_MODE_DISABLED)

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Window closed, Android back / app sent to the background (it may be
## killed there without further notice): save the run first.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST,
			NOTIFICATION_APPLICATION_PAUSED]:
		save_run()

# ================================================================= display --
func _apply_display_mode() -> void:
	# Landscape side-scroller: keep the 270px design height, let extra width
	# (21:9 phones, ultrawide) simply show more of the level.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	touch.relayout()

func apply_touch_layout() -> void:
	var show := GameSettings.touch_buttons_visible(int(cfg.get("touch_buttons", 0)), _touch,
		Input.get_connected_joypads().size())
	touch.visible = show and state in [State.PLAYING, State.MAP] and not _paused
	# help: touch-only pages unless a gamepad is there (RG552 has both)
	menus.set_touch_context(_touch and Input.get_connected_joypads().is_empty())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _touch:
			_touch = true
			get_tree().call_group("touch_layout_listeners", "apply_touch_layout")
	if event.is_action_pressed("pause") and state in [State.PLAYING, State.TRANSITION, State.INTRO, State.MAP] \
			and not menus.is_open():
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mute"):
		_toggle_mute()

# =================================================================== flow --
func _to_title() -> void:
	save_run()
	state = State.TITLE
	get_tree().paused = false
	_paused = false
	_snd_call("stop_all")
	hud.hide_card()
	hud.visible = false
	touch.visible = false
	if world_map:
		world_map.hide_map()
	_build_level(0, false)
	_snd_call("play_music", null, ["music_title"])
	menus.show_start()

static func world_of(idx: int) -> int:
	return int(String(LEVELS[idx].ID).get_slice("-", 0))

## Index of the furthest course ever reached (without cheating).
static func reached_level_index() -> int:
	var id := GameSettings.reached_level_id()
	for i in LEVELS.size():
		if LEVELS[i].ID == id:
			return i
	return first_level_of_world(GameSettings.reached_world())

## Index of the castle course (the one without a flag pole) of world w.
static func castle_of_world(w: int) -> int:
	for i in LEVELS.size():
		if world_of(i) == w and LEVELS[i].FLAG.x < 0:
			return i
	return first_level_of_world(w)

static func first_level_of_world(w: int) -> int:
	for i in LEVELS.size():
		if world_of(i) == w:
			return i
	return 0

## New run starting at LEVELS[start] (world select / "Play Again" continues
## at the first course of the world where the last run ended).
## at_boss (level select "Boss"): spawn right in front of the castle's boss
## arena — dying there respawns at the same spot (it acts as the checkpoint).
func _start_game(start := 0, cheat := false, at_boss := false) -> void:
	_new_run(cheat, true)
	level_index = clampi(start, 0, LEVELS.size() - 1)
	_run_reach = maxi(_run_reach, level_index)
	var arena = LEVELS[level_index].get_script_constant_map().get("ARENA")
	if at_boss and arena != null:
		checkpoint_pos = Vector2((arena.x - 3) * Level.T + Level.T * 0.5, (Level.ROWS - 3) * Level.T)
	_begin_level()

## Reset everything a run carries (score, coins, lives, power, dragon).
## from_select: a level select run (not saved, see `practice`).
func _new_run(cheat := false, from_select := false) -> void:
	cheated = cheat
	practice = cheat or from_select
	run_id = SaveGame.new_id()
	run_name = ""
	_run_best = 0
	cfg = GameSettings.load_all()
	score = 0
	coins = 0
	lives = int(cfg.lives)
	power = Player.Power.BIG if cfg.start_big else Player.Power.SMALL
	has_dino = false
	_dino_parked = false
	checkpoint_pos = null
	_paused = false
	get_tree().paused = false
	_run_reach = reached_level_index()

## Title "Play": a new run on the world map, the hero on the furthest
## course reached so far.
func start_map_run() -> void:
	_new_run(false)
	_show_map(_run_reach)

## Title "Continue": the saved run, back on the map where it was left.
func continue_run() -> void:
	var s := SaveGame.load_run()
	if s.is_empty():
		start_map_run()
		return
	_new_run(false)
	run_id = int(s.id)
	run_name = str(s.name)
	score = int(s.score)
	coins = int(s.coins)
	lives = clampi(int(s.lives), 1, 99)
	power = clampi(int(s.power), Player.Power.SMALL, Player.Power.FIRE)
	has_dino = bool(s.dino)
	_run_best = maxi(level_of_id(str(s.best)), 0)
	var at := maxi(level_of_id(str(s.at)), 0)
	_run_reach = maxi(_run_reach, at)
	_show_map(at)

## Index of the course with this ID ("2-3"), -1 if unknown.
static func level_of_id(id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i].ID == id:
			return i
	return -1

## Autosave: the run to SaveGame (not for level select runs) and its score to
## its high score entry. Called on every map step, course start, before the
## quit dialog / main menu and when the app closes. Returns what the quit
## dialog shows.
func save_run() -> Dictionary:
	if run_id == 0 or state in [State.TITLE, State.GAMEOVER]:
		return {}
	_sync_hof()
	# mid-course: what the hero has right now (the course restarts from the map)
	var in_course := state in [State.INTRO, State.PLAYING, State.TRANSITION]
	var cur_power: int = player.power if player and state != State.DYING else power
	var cur_dino: bool = (player.riding != null or _dino_parked) if player and in_course else has_dino
	var at := level_index
	if state == State.MAP and world_map:
		at = world_map.destination()
	if not practice and state != State.DYING:
		SaveGame.store({"id": run_id, "name": run_name, "score": score, "coins": coins,
			"lives": lives, "power": cur_power, "dino": cur_dino, "at": LEVELS[at].ID,
			"best": LEVELS[maxi(_run_best, at)].ID})
	return {"saved": not practice, "practice": practice, "in_course": state != State.MAP,
		"score": score, "lives": lives, "coins": coins, "world": LEVELS[at].ID,
		"rank": HallOfFame.run_rank(run_id), "name": run_name}

## Keep the run's high score entry up to date (created once it qualifies).
## Level select runs (practice) never get one (v1.2.1, player: "the high
## score list fills up" — every boss tried from the level select left a
## "YOU" entry).
func _sync_hof() -> int:
	if practice or run_id == 0 or score <= 0:
		return -1
	return HallOfFame.record_run(run_id, run_name if run_name != "" else "YOU", score,
		LEVELS[maxi(_run_best, level_index)].ID)

## Quit dialog "Save & Exit".
func quit_game() -> void:
	save_run()
	get_tree().quit()

## The player named the run (quit dialog / game over): renames its entry.
func set_run_name(who: String) -> int:
	run_name = who.strip_edges().to_upper()
	var rank := _sync_hof()
	save_run()
	return rank

## Switch to the world map, hero on course `at_idx`. With `reveal_to` the
## road to that (newly unlocked) course draws itself and the hero walks on.
func _show_map(at_idx: int, reveal_to := -1) -> void:
	state = State.MAP
	_paused = false
	get_tree().paused = false
	_snd_call("stop_all")
	if level:
		world.remove_child(level)
		level.queue_free()
		level = null
	player = null
	for n in get_tree().get_nodes_in_group("fireball"):
		n.queue_free()
	_set_world_active(true)
	backdrop.set_theme(MAP_THEME)
	hud.hide_card()
	hud.set_boss(-1, 0)
	hud.visible = true
	hud.set_buttons_visible(true)
	if world_map == null:
		world_map = WorldMap.new()
		world_map.name = "WorldMap"
		world.add_child(world_map)
		world_map.course_chosen.connect(_enter_course)
		world_map.node_changed.connect(func(i: int):
			level_index = i
			_update_hud()
			save_run())
	world_map.setup(reveal_to - 1 if reveal_to >= 0 else _run_reach, at_idx, power)
	if reveal_to >= 0:
		world_map.reveal(reveal_to)
	level_index = world_map.at
	_update_hud()
	save_run()
	hud.set_time(-1)
	camera.limit_left = 0
	camera.limit_right = WorldMapData.SIZE.x
	camera.limit_top = 0
	camera.limit_bottom = WorldMapData.SIZE.y
	_cam_pos = Vector2(world_map.hero_position().x, WorldMapData.SIZE.y * 0.5)
	_apply_camera()
	_snd_call("play_music", null, ["music_map"])
	apply_touch_layout()

func _enter_course(i: int) -> void:
	if state != State.MAP:
		return
	world_map.hide_map()
	level_index = i
	checkpoint_pos = null
	_begin_level()

func _begin_level() -> void:
	state = State.INTRO
	_snd_call("stop_all")
	hud.visible = true
	hud.set_buttons_visible(false)
	touch.visible = false
	var data: Script = LEVELS[level_index]
	if not cheated:
		GameSettings.set_reached_world(world_of(level_index))
		GameSettings.set_reached_level_id(data.ID, level_index, reached_level_index())
	_run_best = maxi(_run_best, level_index)
	hud.show_card(data.ID, data.NAME, lives)
	hud.set_boss(-1, 0)
	_update_hud()
	_set_world_active(false)
	_build_level(level_index, true)
	# the A press that entered the course (map, level select) is also a
	# jump: the world only stops at the end of this frame (deferred), so a
	# fresh hero would still jump off here and fly on after the card
	# (player 2026-09-29: "hops at the start of every level"). No input
	# until the card is gone.
	if player:
		player.input_enabled = false
	save_run()
	time_left = GameSettings.level_time(cfg, data.TIME)
	_time_acc = 0.0
	_hurry = false
	hud.set_time(time_left if time_left > 0 else -1)
	var tw := create_tween()
	tw.tween_interval(CARD_TIME)
	tw.tween_callback(func():
		hud.hide_card()
		hud.set_buttons_visible(true)
		if player:
			player.input_enabled = true
			player.jump_buffer_t = 0.0
		_set_world_active(true)
		state = State.PLAYING
		apply_touch_layout()
		_play_area_music())

func _build_level(idx: int, with_player: bool) -> void:
	if level:
		world.remove_child(level)
		level.queue_free()
	player = null
	for n in get_tree().get_nodes_in_group("fireball"):
		n.queue_free()
	level = Level.new()
	level.name = "Level"
	world.add_child(level)
	level.setup(LEVELS[idx])
	area = "main"
	var start: Vector2 = level.start_pos
	if with_player:
		if checkpoint_pos != null:
			start = checkpoint_pos
			for cp in level.get_children():
				if cp is Checkpoint and cp.global_position.distance_to(start) < 4.0:
					cp.set_active_silent()
		if _is_boss_spawn(start):
			power = Player.Power.FIRE      # (re)start at the boss: always fire power
		player = PlayerScript.new()
		player.name = "Player"
		player.power = power
		level.add_child(player)
		player.global_position = start
		player.fireball_requested.connect(_spawn_fireball)
		var water: bool = level.areas.get(level.area_at(start.x), {"theme": ""}).theme in Level.WATER_THEMES
		_dino_parked = has_dino and water
		if has_dino and not water:
			var d := Dino.new()
			level.add_child(d)
			d.global_position = start
			player.mount(d)
	_enter_area(level.area_at(start.x), true)
	_cam_pos = Vector2(start.x, start.y - 30.0)
	_update_camera(0.0, true)

## Spawning at the checkpoint in front of a castle's boss arena (or the
## level select's "Boss" start)?
func _is_boss_spawn(pos: Vector2) -> bool:
	var arena = LEVELS[level_index].get_script_constant_map().get("ARENA")
	return checkpoint_pos != null and arena != null and pos.x >= (arena.x - 10) * Level.T \
		and pos.x < arena.x * Level.T

func _enter_area(name: String, snap := false) -> void:
	area = name
	var a: Dictionary = level.areas.get(name, {"rect": Rect2(0, 0, level.cols * Level.T, Level.ROWS * Level.T), "theme": "grass"})
	var r: Rect2 = a.rect
	camera.limit_left = int(r.position.x)
	camera.limit_right = int(r.end.x)
	camera.limit_top = 0
	camera.limit_bottom = int(r.end.y)
	backdrop.set_theme(a.theme)
	if player:
		var water: bool = a.theme in Level.WATER_THEMES
		player.area_water = water
		player.swimming = water
		player.left_limit = r.position.x
		player.right_limit = r.end.x
		# the dragon can't swim: it stays behind right away (no dragon in the
		# pipe animation); _update_dino_water() brings it back on dry land
		if water and player.park_dino():
			_dino_parked = true
	if snap and player:
		_cam_pos = player.global_position + Vector2(0, -30)

func _play_area_music() -> void:
	if player and player.star_t > 0.0:
		_snd_call("play_music", null, ["music_star"])
		return
	var theme: String = level.areas.get(area, {"theme": "grass"}).theme
	var key: String = THEME_MUSIC.get(theme, "music_overworld")
	_snd_call("play_music", null, [key, 1.2 if _hurry else 1.0])

# ================================================================ process --
func _process(delta: float) -> void:
	var win := DisplayServer.window_get_size()
	if win != _last_window:
		_last_window = win
		_apply_display_mode()
	if _paused:
		return
	match state:
		State.TITLE:
			_attract(delta)
		State.PLAYING:
			_tick_time(delta)
			if player and player.star_t <= 0.0 and _snd_call("current_music", "") == "music_star":
				_play_area_music()

func _physics_process(delta: float) -> void:
	if _paused or state == State.TITLE:
		return
	if state == State.MAP:
		if world_map:
			_cam_pos = Vector2(world_map.hero_position().x, WorldMapData.SIZE.y * 0.5)
			_apply_camera()
		return
	if state == State.PLAYING:
		_update_dino_water()
	_update_camera(delta, false)

## The dragon can't swim: diving into water (underwater area, bonus grotto,
## castle pool) it waits "off stage"; back on dry ground it is there again.
func _update_dino_water() -> void:
	if player == null or player.mode != Player.Mode.NORMAL:
		return
	if player.swimming and player.riding:
		player.park_dino()
		_dino_parked = true
	elif _dino_parked and player.riding == null and not player.swimming and not player.area_water \
			and player.is_on_floor():
		_dino_parked = false
		var d := Dino.new()
		level.add_child(d)
		d.global_position = player.global_position
		player.mount(d)

func _attract(delta: float) -> void:
	var vw := get_viewport_rect().size.x
	_cam_pos.x += _attract_dir * 28.0 * delta
	if _cam_pos.x > camera.limit_right - vw * 0.5:
		_attract_dir = -1.0
	elif _cam_pos.x < camera.limit_left + vw * 0.5:
		_attract_dir = 1.0
	_cam_pos.y = 200.0
	_apply_camera()

func _update_camera(delta: float, snap: bool) -> void:
	if player == null:
		_apply_camera()
		return
	var p := player.global_position
	# horizontal: small dead zone around the center
	var dz := 12.0
	if p.x > _cam_pos.x + dz:
		_cam_pos.x = p.x - dz
	elif p.x < _cam_pos.x - dz:
		_cam_pos.x = p.x + dz
	# vertical: settle on the ground line, follow only big climbs/falls
	var target_y := p.y - 36.0
	if player.is_on_floor() or snap:
		_cam_pos.y = target_y if snap else lerpf(_cam_pos.y, target_y, minf(1.0, delta * 4.0))
	else:
		if p.y - 70.0 < _cam_pos.y - 60.0:
			_cam_pos.y = p.y - 70.0 + 60.0
		elif p.y > _cam_pos.y + 90.0:
			_cam_pos.y = p.y - 90.0
	_apply_camera()

func _apply_camera() -> void:
	var vs := get_viewport_rect().size
	var half := vs * 0.5
	var lo := Vector2(camera.limit_left + half.x, camera.limit_top + half.y)
	var hi := Vector2(camera.limit_right - half.x, camera.limit_bottom - half.y)
	_cam_pos.x = clampf(_cam_pos.x, lo.x, maxf(lo.x, hi.x))
	_cam_pos.y = clampf(_cam_pos.y, lo.y, maxf(lo.y, hi.y))
	camera.global_position = _cam_pos

func is_near_view(pos: Vector2, margin: float) -> bool:
	var vs := get_viewport_rect().size
	var c := camera.global_position
	return absf(pos.x - c.x) < vs.x * 0.5 + margin and absf(pos.y - c.y) < vs.y * 0.5 + margin + 64.0

func enemy_speed_mul() -> float:
	return GameSettings.enemy_speed_mul(int(cfg.get("difficulty", 1)))

func _tick_time(delta: float) -> void:
	if time_left <= 0:
		return
	_time_acc += delta
	while _time_acc >= TIME_TICK and time_left > 0:
		_time_acc -= TIME_TICK
		time_left -= 1
		hud.set_time(time_left)
		if time_left == 100 and not _hurry:
			_hurry = true
			_snd_call("play", null, ["hurry"])
			hud.show_banner("HURRY UP!", 1.6)
			_snd_call("set_music_pitch", null, [1.2])
		if time_left == 0:
			hud.show_banner("TIME UP", 2.0)
			player_died(false)

# ================================================================ scoring --
func add_score(n: int, pos = null) -> void:
	var before := score
	score += n
	hud.set_score(score)
	if pos != null and n > 0:
		_popup(str(n), pos)
	# Settings "1-UP points": an extra life every N points (v0.15, player
	# wish — gives weaker players a chance). Stateless: counts the
	# thresholds this addition crossed, so changing the setting mid-run works.
	var step := int(cfg.get("life_points", 0))
	if step > 0 and n > 0 and state != State.TITLE:
		for i in floori(score / float(step)) - floori(before / float(step)):
			var at: Vector2 = pos if pos != null else (player.global_position + Vector2(0, -34) if player else Vector2.ZERO)
			one_up(at + Vector2(0, -12.0 * i))

func _popup(text: String, pos: Vector2) -> void:
	var p := ScorePopup.new()
	p.setup(text, pos)
	level.add_child(p)

func add_coin(_from_level: bool, pos: Vector2) -> void:
	coins += 1
	add_score(int(cfg.coin_points))
	_snd_call("play", null, ["coin"])
	var per := int(cfg.coins_per_life)
	if per > 0 and coins >= per:
		coins = 0
		one_up(pos)
	elif per == 0 and coins >= 100:
		coins = 0
	hud.set_coins(coins)

func one_up(pos: Vector2) -> void:
	lives = mini(lives + 1, 99)
	hud.set_lives(lives)
	_snd_call("play", null, ["oneup"])
	_popup("1UP", pos)

func award_chain(p: Player, pos: Vector2) -> void:
	var i := p.stomp_chain
	if i < CHAIN.size():
		add_score(CHAIN[i], pos)
	else:
		one_up(pos)
	p.stomp_chain += 1

func block_bumped() -> void:
	pass

func collect_powerup(kind: int, pos: Vector2) -> void:
	if player == null:
		return
	match kind:
		PowerUp.Kind.MUSHROOM:
			add_score(1000, pos)
			if player.power == Player.Power.SMALL:
				change_power(Player.Power.BIG, false)
			else:
				_snd_call("play", null, ["powerup"])
		PowerUp.Kind.FLOWER:
			add_score(1000, pos)
			if player.power != Player.Power.FIRE:
				change_power(Player.Power.FIRE, false)
			else:
				_snd_call("play", null, ["powerup"])
		PowerUp.Kind.ONEUP:
			one_up(pos)
		PowerUp.Kind.STAR:
			add_score(1000, pos)
			player.start_star(STAR_TIME)
			_snd_call("play_music", null, ["music_star"])

## Grow / shrink with the classic freeze + flicker between both looks.
func change_power(new_power: int, hurt: bool) -> void:
	if player == null:
		return
	var old := player.power
	power = new_power
	_snd_call("play", null, ["powerdown" if hurt else "powerup"])
	player.set_power(new_power)
	_set_world_active(false)
	if _freeze_tween and _freeze_tween.is_valid():
		_freeze_tween.kill()
	_freeze_tween = create_tween()
	for i in 10:
		var show_p := old if i % 2 == 0 else new_power
		_freeze_tween.tween_callback(func(): if player: player.show_power_frame(show_p))
		_freeze_tween.tween_interval(0.07)
	_freeze_tween.tween_callback(func():
		if player:
			player.show_power_frame(new_power)
		if state == State.PLAYING or state == State.TRANSITION:
			_set_world_active(true))

func _spawn_fireball(pos: Vector2, dir: int) -> void:
	var f := Fireball.new()
	f.dir = dir
	f.position = pos
	level.add_child(f)
	_snd_call("play", null, ["fireball"])

func set_checkpoint(pos: Vector2) -> void:
	checkpoint_pos = pos
	_snd_call("play", null, ["checkpoint"])
	if player and player.power == Player.Power.SMALL:
		change_power(Player.Power.BIG, false)

# ================================================================== death --
func player_died(pit: bool) -> void:
	if state != State.PLAYING or player == null:
		return
	state = State.DYING
	touch.visible = false
	_snd_call("stop_music")
	_snd_call("play", null, ["jingle_death"])
	if player.riding:
		var d := player.riding
		player.riding = null
		d.queue_free()
	has_dino = false
	_dino_parked = false
	player.mode = Player.Mode.DEAD
	player.collision_mask = 0
	_set_world_active(false)
	var tw := create_tween()
	if not pit:
		player.set_power(Player.Power.SMALL)
		player.play_anim(&"death")
		player.z_index = 10
		var y0 := player.global_position.y
		tw.tween_interval(0.5)
		tw.tween_property(player, "global_position:y", y0 - 48.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(player, "global_position:y", y0 + 260.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_interval(0.9)
	else:
		tw.tween_interval(2.4)
	tw.tween_callback(_after_death)

func _after_death() -> void:
	power = Player.Power.BIG if cfg.start_big else Player.Power.SMALL
	# global CLAUDE.md #16: check the reserve BEFORE decrementing
	if lives - 1 <= 0:
		lives = 0
		hud.set_lives(1)
		_game_over(false)
		return
	lives -= 1
	_begin_level()

func _game_over(victory: bool) -> void:
	state = State.GAMEOVER
	_set_world_active(false)
	touch.visible = false
	hud.set_buttons_visible(false)
	_snd_call("stop_music")
	if not victory:
		_snd_call("play", null, ["jingle_gameover"])
	var data: Script = LEVELS[level_index]
	# the run is over: its score is in the high scores (named on the next
	# screen), the saved game goes — the title offers "Play" again
	_sync_hof()
	if int(SaveGame.load_run().get("id", 0)) == run_id:
		SaveGame.clear()
	if victory:
		level_index = 0      # "Play Again" after the last course starts over at 1-1
	hud.show_text_card("GAME OVER" if not victory else "THANK YOU!", "" if not victory else "You cleared every course")
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func():
		hud.hide_card()
		menus.show_gameover(score, data.ID, victory))

# ================================================================== pipes --
func enter_warp(zone: WarpZone) -> void:
	if state != State.PLAYING or player == null:
		return
	state = State.TRANSITION
	var w: Dictionary = zone.warp
	player.set_scripted(true)
	player.collision_mask = 0
	player.z_index = -2
	player.play_anim(&"ride" if player.riding else &"idle", player.facing < 0)
	var tw := create_tween()
	if zone.kind == "door":
		# ghost house door (v1.4): it opens, the hero steps in and fades
		player.global_position.x = zone.global_position.x
		var door := level.door_at(w["entry"])
		if door:
			door.open(0.9)
		_snd_call("play", null, ["door"])
		tw.tween_property(player, "modulate:a", 0.0, 0.3)
		tw.tween_interval(0.2)
		tw.tween_callback(func(): _arrive(w))
		return
	_snd_call("play", null, ["pipe"])
	if zone.kind == "down":
		player.global_position.x = zone.global_position.x
		tw.tween_property(player, "global_position:y", player.global_position.y + 34.0, 0.8)
	else:
		player.play_anim(&"walk", false)
		tw.tween_property(player, "global_position:x", player.global_position.x + 26.0, 0.8)
	tw.tween_interval(0.25)
	tw.tween_callback(func(): _arrive(w))

func _arrive(w: Dictionary) -> void:
	if player == null:
		return
	var pos := level.arrive_position(w)
	_enter_area(w["area"])
	if w["arrive_kind"] == "up":
		player.global_position = pos + Vector2(0, 34)
		_cam_pos = pos + Vector2(0, -30)
		_update_camera(0.0, true)
		_play_area_music()
		_snd_call("play", null, ["pipe"])
		var tw := create_tween()
		tw.tween_property(player, "global_position:y", pos.y, 0.8)
		tw.tween_callback(_finish_warp)
	elif w["arrive_kind"] == "door":
		player.global_position = pos
		player.z_index = 0                 # fades in in front of the open door
		_cam_pos = pos + Vector2(0, -30)
		_update_camera(0.0, true)
		_play_area_music()
		var door := level.door_at(w["arrive"])
		if door:
			door.open(0.7)
		_snd_call("play", null, ["door"])
		var tw := create_tween()
		tw.tween_interval(0.15)
		tw.tween_property(player, "modulate:a", 1.0, 0.3)
		tw.tween_callback(_finish_warp)
	else:
		player.global_position = pos
		_cam_pos = pos + Vector2(0, -30)
		_update_camera(0.0, true)
		_play_area_music()
		_finish_warp()

func _finish_warp() -> void:
	if player == null:
		return
	player.modulate.a = 1.0
	player.z_index = 0
	player.collision_mask = 1
	player.set_scripted(false)
	state = State.PLAYING

# =============================================================== the goal --
func flag_reached(pole: Flagpole, p: Player) -> void:
	if state != State.PLAYING:
		return
	state = State.CLEAR
	touch.visible = false
	_snd_call("stop_music")
	_snd_call("play", null, ["flagpole"])
	var base_y := pole.global_position.y
	var h := base_y - p.global_position.y
	add_score(Flagpole.points_for_height(h), Vector2(pole.global_position.x + 12, p.global_position.y - 20))
	has_dino = p.riding != null or _dino_parked
	_dino_parked = false
	if p.riding:
		var d := p.riding
		p.riding = null
		d.detach_from(p)
		d.dismounted(1, false)
		d.global_position = Vector2(pole.global_position.x - 20, base_y + 16)
		p.set_power(p.power)
	p.set_scripted(true)
	p.collision_mask = 0
	p.global_position.x = pole.global_position.x - 5
	p.play_anim(&"climb", false)
	var slide := maxf(base_y - p.global_position.y, 0.0) / 120.0
	pole.lower_flag(maxf(slide, 0.4))
	var tw := create_tween()
	tw.tween_property(p, "global_position:y", base_y, maxf(slide, 0.1))
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		p.global_position.x = pole.global_position.x + 5
		p.play_anim(&"climb", true))
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		_snd_call("play", null, ["jingle_clear"])
		p.global_position.x = pole.global_position.x + 15
		p.collision_mask = 1
		p.set_scripted(false)
		p.input_enabled = false
		p.auto_walk = 1.0)
	tw.tween_callback(_walk_to_castle)

func _walk_to_castle() -> void:
	if player == null:
		return
	if player.global_position.x >= level.castle_door.x:
		player.visible = false
		player.auto_walk = 0.0
		player.set_scripted(true)
		# ~60 ticks regardless of how much time is left (about 2 s)
		_tally_step = maxi(1, ceili(time_left / 60.0))
		_tally_time()
		return
	get_tree().create_timer(0.05, true, true).timeout.connect(_walk_to_castle)

func _tally_time() -> void:
	if time_left <= 0:
		_level_done()
		return
	var step := mini(_tally_step, time_left)
	time_left -= step
	add_score(50 * step)
	hud.set_time(time_left)
	_snd_call("play", null, ["tick"])
	get_tree().create_timer(0.03, true, true).timeout.connect(_tally_time)

func _level_done() -> void:
	checkpoint_pos = null
	level.raise_castle_flag()
	_snd_call("play", null, ["checkpoint"])
	power = player.power if player else power
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func():
		var next := level_index + 1
		if next >= LEVELS.size():
			_game_over(true)
			return
		# unlock the next course right away (quitting on the map keeps it)
		if not cheated:
			GameSettings.set_reached_world(world_of(next))
			GameSettings.set_reached_level_id(LEVELS[next].ID, next, reached_level_index())
		var fresh := next > _run_reach
		_run_reach = maxi(_run_reach, next)
		_show_map(level_index, next if fresh else -1))

# =================================================================== boss --
## The boss woke up: lock the camera to the arena, wall off the way back.
## Called deferred by boss.gd (NOT from inside its _physics_process): the
## wall-up changes TileMapLayer cells + collision, which must not happen in
## the middle of a physics step (suspected cause of a one-off crash on the
## RG552, see TODO.md). Idempotent per level; ignored once the level or the
## boss is gone or the game left PLAYING (death / pause race).
func start_boss(boss: Boss) -> void:
	if state != State.PLAYING or level == null or not is_instance_valid(boss) \
			or boss.dead or not boss.is_inside_tree() or boss.get_parent() != level \
			or level.get_meta("boss_started", false):
		return
	level.set_meta("boss_started", true)
	camera.limit_left = int(boss.arena_left)
	camera.limit_right = int(boss.arena_right)
	if player:
		player.left_limit = boss.arena_left
		player.right_limit = boss.arena_right
	var gate_c := int(boss.arena_left / Level.T)
	# never wall anyone in: the hero (and a ridden dragon) must be clear of it
	var gate_right := float(gate_c + 1) * Level.T
	if player and player.global_position.x - 10.0 < gate_right:
		player.global_position.x = gate_right + 12.0
	for r in range(0, Level.ROWS - 3):
		var cell := Vector2i(gate_c, r)
		if level.tiles.get_cell_source_id(cell) == -1:
			level.tiles.set_cell(cell, 0, Level.CASTLE_WALL)
	_snd_call("play", null, ["break"])
	_snd_call("set_music_pitch", null, [1.12])
	hud.show_banner("BOSS!", 1.2)
	hud.set_boss(boss.hp, boss.max_hp)

func boss_hp_changed(hp: int, max_hp: int) -> void:
	hud.set_boss(hp, max_hp)

func boss_defeated(_boss: Boss) -> void:
	if state != State.PLAYING:
		return
	state = State.CLEAR
	touch.visible = false
	hud.set_boss(-1, 0)
	_snd_call("stop_music")
	_snd_call("play", null, ["jingle_world"])
	has_dino = (player != null and player.riding != null) or _dino_parked
	_dino_parked = false
	hud.show_banner("WORLD %d CLEAR!" % world_of(level_index), 3.0)
	if player:
		player.input_enabled = false
		player.velocity.x = 0.0
	add_score(5000, player.global_position + Vector2(0, -40) if player else null)
	var tw := create_tween()
	# reward: an extra life for every boss beaten
	tw.tween_interval(1.2)
	tw.tween_callback(func(): one_up(player.global_position + Vector2(0, -56) if player else Vector2.ZERO))
	tw.tween_interval(2.0)
	tw.tween_callback(func():
		_tally_step = maxi(1, ceili(time_left / 60.0))
		_tally_time())

# ================================================================== pause --
func _toggle_pause() -> void:
	if state not in [State.PLAYING, State.TRANSITION, State.INTRO, State.MAP]:
		return
	_paused = not _paused
	get_tree().paused = _paused
	_snd_call("play", null, ["pause"])
	_snd_call("pause_music", null, [_paused])
	if _paused:
		touch.visible = false
		menus.show_pause()
	else:
		menus.hide_all()
		apply_touch_layout()

func _resume() -> void:
	_paused = false
	get_tree().paused = false
	_snd_call("pause_music", null, [false])
	apply_touch_layout()

func _toggle_mute() -> void:
	hud.set_muted(_snd_call("toggle_mute", false))

func _update_hud() -> void:
	hud.set_score(score)
	hud.set_coins(coins)
	hud.set_lives(lives)
	hud.set_world(LEVELS[level_index].ID)

## Calls a method on the Snd autoload if present (it is absent under
## `godot --script`), returning `fallback` otherwise.
func _snd_call(method: String, fallback = null, args := []):
	var s := get_node_or_null("/root/Snd")
	if s == null or not s.has_method(method):
		return fallback
	return s.callv(method, args)
