extends SceneTree

## Scripted play-through for development (NOT shipped, NOT an autoload):
##   godot --path . --script res://tools/playtest.gd -- <scenario> <outdir>
## Runs the real game scene in a window, drives it with Input.action_press(),
## prints state lines and saves screenshots to <outdir>/<scenario>_<n>.png.
## Scenarios: basic, powerup, stomp, pipe, flag, dino, title

var game: Game
var outdir := "/tmp"
var scenario := "basic"
var shot_n := 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		scenario = args[0]
	if args.size() > 1:
		outdir = args[1]
	var scene: PackedScene = load("res://game.tscn")
	game = scene.instantiate()
	root.add_child(game)
	_run.call_deferred()

func _wait(t: float) -> void:
	await create_timer(t).timeout

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(label: String) -> void:
	await _frames(2)
	var img := root.get_viewport().get_texture().get_image()
	shot_n += 1
	var path := "%s/%s_%02d_%s.png" % [outdir, scenario, shot_n, label]
	img.save_png(path)
	print("SHOT ", path)

func state(label: String) -> void:
	var p := game.player
	if p:
		print("STATE %s: pos=%s vel=%s power=%d on_floor=%s anim=%s score=%d coins=%d lives=%d area=%s gstate=%d" % [
			label, p.global_position.round(), p.velocity.round(), p.power, p.is_on_floor(),
			p.sprite.animation, game.score, game.coins, game.lives, game.area, game.state])
	else:
		print("STATE %s: no player, gstate=%d" % [label, game.state])

func hold(action: String, t: float) -> void:
	Input.action_press(action)
	await _wait(t)
	Input.action_release(action)

func press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)

## Gamepad button press + release through the real input pipeline.
func _pad(b: int) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		ev.pressed = down
		ev.device = 0
		Input.parse_input_event(ev)
		await _frames(2)

## An action press + release as input EVENTS (Input.action_press() only
## sets the state; _unhandled_input handlers such as the world map's
## never see it).
func _act(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(2)

func start_play() -> void:
	await _wait(0.5)
	game.menus.hide_all()
	game._start_game()
	await _wait(Game.CARD_TIME + 0.3)

func teleport(cell: Vector2i) -> void:
	game.player.global_position = Vector2(cell.x * 16 + 8, (cell.y + 1) * 16)
	game.player.velocity = Vector2.ZERO
	game._update_camera(0.0, true)
	await _frames(3)

## The player's saved run / high scores / settings on this machine: kept
## aside while a scenario runs (autosave and game overs write them).
const USER_FILES := ["user://savegame.cfg", "user://hall_of_fame.cfg", "user://settings.cfg"]
var _user_backup := {}

## The backup also goes to disk (user://_playtest_backup/): a scenario that
## dies on a script error never reaches _restore_user_files(), so the next
## run restores that copy first (v1.7: aborted co-op runs had left test
## entries in the real high score list).
const BACKUP_DIR := "user://_playtest_backup/"

func _backup_user_files() -> void:
	if FileAccess.file_exists(BACKUP_DIR + "pending"):
		print("PLAYTEST: the last run was aborted - restoring its backup first")
		for f in USER_FILES:
			var b: String = BACKUP_DIR + String(f).get_file()
			if FileAccess.file_exists(b):
				var fa := FileAccess.open(f, FileAccess.WRITE)
				fa.store_buffer(FileAccess.get_file_as_bytes(b))
				fa.close()
			elif FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	for f in USER_FILES:
		_user_backup[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
		var b: String = BACKUP_DIR + String(f).get_file()
		if _user_backup[f] == null:
			if FileAccess.file_exists(b):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(b))
		else:
			var fa := FileAccess.open(b, FileAccess.WRITE)
			fa.store_buffer(_user_backup[f])
			fa.close()
	FileAccess.open(BACKUP_DIR + "pending", FileAccess.WRITE).close()

func _restore_user_files() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_DIR + "pending"))
	for f in USER_FILES:
		if _user_backup.get(f) == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(_user_backup[f])
			fa.close()

func _button_texts() -> Array:
	var out := []
	for b in game.menus.find_children("*", "Button", true, false):
		if b.visible:
			out.append(b.text)
	return out

func _press_button(text: String) -> void:
	for b in game.menus.find_children("*", "Button", true, false):
		if b.visible and b.text == text:
			b.pressed.emit()
			await _frames(3)
			return
	print("BUTTON NOT FOUND: ", text, " in ", _button_texts())

func _hints() -> String:
	var out := []
	for l in game.menus.find_children("*", "Label", true, false):
		if l.visible and l.get_parent() == game.menus._vbox:
			out.append(l.text.replace("\n", " / "))
	return " | ".join(out)

## A key press + release as real events (join screen reads them).
func _key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(2)

func _keys(action: String) -> Array:
	return InputMap.action_get_events(action).filter(func(e): return e is InputEventKey).map(
		func(e): return OS.get_keycode_string(e.physical_keycode if e.physical_keycode else e.keycode))

func teleport_hero(p: Player, cell: Vector2i) -> void:
	p.global_position = Vector2(cell.x * 16 + 8, (cell.y + 1) * 16)
	p.velocity = Vector2.ZERO
	await _frames(3)

## Peak height (px) of a held jump from standing on flat ground.
func _jump_height() -> float:
	await _wait(0.3)
	var y0 := game.player.global_position.y
	var top := y0
	Input.action_press("jump")
	for i in 60:
		await physics_frame
		top = minf(top, game.player.global_position.y)
	Input.action_release("jump")
	await _wait(0.8)
	return y0 - top

func _run() -> void:
	# the game's _ready (which creates the splash) runs only once the tree
	# is live — skip the splash from here, not from _init()
	await process_frame
	_backup_user_files()
	if scenario != "splash":
		game.skip_splash()
	match scenario:
		"title":
			await _wait(1.5)
			await shot("title")
			game.menus._show_screen(Menus.Screen.SETTINGS)
			await shot("settings")
			game.menus._show_screen(Menus.Screen.SOUND)
			await shot("sound")
			game.menus._show_screen(Menus.Screen.HELP)
			await shot("help")
			game.menus._show_screen(Menus.Screen.HIGHSCORES)
			await shot("hof")
		"basic":
			await start_play()
			state("start")
			await shot("start")
			await hold("move_right", 1.2)
			state("walked")
			await shot("walked")
			Input.action_press("move_right")
			Input.action_press("jump")
			await _wait(0.25)
			state("jumping")
			await shot("jump")
			Input.action_release("jump")
			await _wait(0.6)
			Input.action_release("move_right")
			state("landed")
			Input.action_press("run")
			await hold("move_right", 1.5)
			Input.action_release("run")
			state("ran")
			await shot("ran")
		"powerup":
			await start_play()
			await teleport(Vector2i(22, 16))   # under the M block (col 22 row 13)
			await hold("jump", 0.3)
			await _wait(0.2)
			await shot("bumped")
			await _wait(1.2)
			state("mushroom out")
			await shot("mushroom_out")
			# wait until the mushroom slides down to the ground, then stand in its way
			var items := game.get_tree().get_nodes_in_group("items")
			for i in 120:
				if items.is_empty() or (items[0].is_on_floor() and items[0].global_position.y > 260.0):
					break
				await _frames(2)
			if not items.is_empty():
				game.player.global_position = items[0].global_position + Vector2(40, 0)
				print("mushroom at ", items[0].global_position)
			await _wait(1.5)
			state("after grow")
			await shot("grown")
			await teleport(Vector2i(21, 16))
			await hold("jump", 0.3)
			await _wait(0.5)
			state("after brick")
			await shot("brick_broken")
		"stomp":
			await start_play()
			await teleport(Vector2i(19, 16))
			await _wait(0.3)
			var enemies := game.get_tree().get_nodes_in_group("enemies")
			enemies.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
			var e: Node2D = enemies[0]
			print("enemy at ", e.global_position, " active=", e.active)
			game.player.global_position = e.global_position + Vector2(0, -24)
			game.player.velocity = Vector2(0, 60)
			await _wait(0.35)            # time, not frames: frame rate varies
			state("just after stomp")
			await shot("stomped")
			state("after stomp")
		"pipe":
			await start_play()
			await teleport(Vector2i(53, 12))   # on top of the warp pipe
			game.player.global_position.x = 54 * 16   # pipe center (2 cells wide)
			await _wait(0.3)
			await hold("move_down", 0.4)
			await _wait(1.6)
			state("in bonus room")
			await shot("bonus_room")
			await _wait(0.8)
			await shot("bonus_landed")
			await teleport(Vector2i(299, 16))
			await hold("move_right", 0.6)
			await _wait(2.2)
			state("back in main")
			await shot("exit_pipe")
		"flag":
			await start_play()
			await teleport(Vector2i(243, 8))   # top of the final staircase
			game.player.global_position.y -= 40.0
			game.player.velocity = Vector2(160, -310)
			Input.action_press("run")
			Input.action_press("move_right")
			for i in 150:                      # physics frames: ~2.5 s
				if game.state != Game.State.PLAYING:
					break
				await physics_frame
			Input.action_release("move_right")
			Input.action_release("run")
			await _wait(0.3)
			await shot("pole_grab")
			await _wait(1.5)
			await shot("pole_down")
			await _wait(3.5)
			state("clear")
			await shot("castle")
			for i in 12:
				await _wait(0.5)
				# (v1.1: after the tally the course makes way for the world map)
				print("t+%.1f state=%d time=%d flag=%s" % [i * 0.5, game.state, game.time_left,
					game.level.castle_flag.position if game.level else "-> map"])
			await shot("castle_flag")
		"dino":
			await start_play()
			await teleport(Vector2i(129, 16))  # under the Y block (col 129 row 13)
			await hold("jump", 0.3)
			await _wait(2.0)
			await shot("hatched")
			var dinos := game.get_tree().get_nodes_in_group("dino")
			print("dinos: ", dinos.size())
			if not dinos.is_empty():
				var d: Node2D = dinos[0]
				game.player.global_position = d.global_position + Vector2(0, -40)
				game.player.velocity = Vector2(0, 50)
				await _wait(0.8)
				state("mounted?")
				await shot("riding")
				await hold("move_right", 1.0)
				await shot("ride_walk")
				await press("run")
				await _frames(6)
				await shot("tongue")
				await _wait(1.0)
				state("after tongue")
		"fire":
			await start_play()
			game.change_power(Player.Power.FIRE, false)
			await _wait(1.0)
			await teleport(Vector2i(19, 16))
			await shot("fire_hero")
			for i in 3:
				await press("run")
				await _wait(0.25)
			await shot("fireballs")
			await _wait(1.0)
			state("after fireballs")
		"star":
			await start_play()
			await teleport(Vector2i(18, 16))
			game.collect_powerup(PowerUp.Kind.STAR, game.player.global_position)
			print("music: ", game._snd_call("current_music", ""))
			await hold("move_right", 1.6)
			await shot("star_run")
			state("after star run")
		"gameover":
			await start_play()
			game.lives = 1
			game.player_died(false)
			await _wait(1.0)
			await shot("dying")
			await _wait(5.0)
			await shot("gameover")
			print("menu screen: ", game.menus.screen)
			game.menus._commit_score()
			await shot("hof")
		"dinohit":
			await start_play()
			await teleport(Vector2i(129, 16))
			await hold("jump", 0.3)
			await _wait(2.0)
			var ds := game.get_tree().get_nodes_in_group("dino")
			var dn: Node2D = ds[0]
			game.player.global_position = dn.global_position + Vector2(0, -40)
			game.player.velocity = Vector2(0, 50)
			await _wait(0.6)
			state("mounted")
			# ride down onto the ground, face an enemy placed 30 px ahead, tongue it
			game.player.global_position = Vector2(133 * 16 + 8, 272)
			game.player.facing = 1
			await _frames(4)
			var victim := Shroom.new()
			victim.position = game.player.global_position + Vector2(30, 0)
			game.level.add_child(victim)
			await _frames(2)
			await press("run")
			await _frames(5)
			await shot("tongue_catch")
			await _wait(0.4)
			state("after tongue")
			print("victim eaten: ", not is_instance_valid(victim))
			# now get hit: put an enemy right next to the rider
			var es2 := game.get_tree().get_nodes_in_group("enemies")
			if not es2.is_empty():
				es2[0].global_position = game.player.global_position + Vector2(10, 0)
			await _wait(0.5)
			await shot("thrown_off")
			state("after hit")
			print("riding: ", game.player.riding)
		"checkpoint":
			await start_play()
			await teleport(Vector2i(141, 16))
			await hold("move_right", 0.4)
			state("at checkpoint")
			game.player_died(true)
			await _wait(2.8 + Game.CARD_TIME + 0.5)
			state("respawned")
			await shot("respawn")
		"levels":
			for idx in [1, 2]:
				game.menus.hide_all()
				game._start_game()
				game.level_index = idx
				game._begin_level()
				await _wait(Game.CARD_TIME + 0.4)
				await teleport(Vector2i(30 if idx == 1 else 16, 12 if idx == 1 else 16))
				await _wait(0.6)
				await shot("level_%d" % (idx + 1))
				await teleport(Vector2i(48 if idx == 1 else 60, 12))
				await _wait(1.8)
				await shot("level_%d_b" % (idx + 1))
		"card":
			await _wait(0.5)
			game.menus.hide_all()
			game._start_game()
			await _wait(1.0)
			await shot("world_card")
		"ridebig":
			await start_play()
			game.change_power(Player.Power.BIG, false)
			await _wait(1.0)
			var d := Dino.new()
			game.level.add_child(d)
			d.global_position = Vector2(40 * 16, 272)
			await _wait(0.8)
			await teleport(Vector2i(40, 14))
			game.player.velocity = Vector2(0, 60)
			await _wait(0.6)
			state("big mounted")
			await shot("big_ride_idle")
			await hold("move_right", 0.5)
			await shot("big_ride_walk")
			game.change_power(Player.Power.FIRE, false)
			await _wait(1.0)
			Input.action_press("jump")
			await _wait(0.2)
			await shot("fire_ride_jump")
			Input.action_release("jump")
			await _wait(0.8)
			game.player.facing = -1
			await hold("move_left", 0.4)
			await shot("fire_ride_left")
		"worlds":
			# 2-1 cave, 3-1 desert, 4-1 snow: two views each
			# 2-1/2-2 cave, 3-1/3-2 desert, 4-1/4-2 snow: two views each
			var spots := {"2-1": [Vector2i(16, 16), Vector2i(76, 13)], "3-1": [Vector2i(36, 16), Vector2i(72, 13)],
				"4-1": [Vector2i(20, 16), Vector2i(70, 14)], "2-2": [Vector2i(30, 13), Vector2i(84, 11)],
				"3-2": [Vector2i(48, 16), Vector2i(86, 11)], "4-2": [Vector2i(46, 11), Vector2i(80, 12)]}
			var only := OS.get_environment("WORLDS")
			for idx in Game.LEVELS.size():
				var lid: String = Game.LEVELS[idx].ID
				if not spots.has(lid) or (only != "" and not lid in only.split(",")):
					continue
				game.menus.hide_all()
				game._start_game()
				game.level_index = idx
				game._begin_level()
				await _wait(Game.CARD_TIME + 0.4)
				for k in 2:
					for n in game.get_tree().get_nodes_in_group("enemies"):
						if absf(n.global_position.x - spots[lid][k].x * 16) < 48:
							n.queue_free()
					await teleport(spots[lid][k])
					await _wait(1.2)
					state("world %s spot %d" % [lid, k])
					await shot("world_%s_%d" % [lid, k])
		"turtle":
			game.menus.hide_all()
			game._start_game()
			game.level_index = Game.first_level_of_world(2)
			game._begin_level()
			await _wait(Game.CARD_TIME + 0.4)
			var tt: Turtle = null
			for n in game.level.get_children():
				if n is Turtle and absf(n.global_position.x - 110 * 16) < 40:
					tt = n
			await teleport(Vector2i(106, 16))
			await _wait(0.2)
			tt.global_position = Vector2(112 * 16 + 8, 272)
			game.player.global_position = Vector2(112 * 16 + 8, 236)
			game.player.velocity = Vector2(0, 100)
			await _wait(0.12)
			print("TURTLE after stomp: state=%d dead=%s score=%d" % [tt.state, tt.dead, game.score])
			await shot("shell")
			await teleport(Vector2i(109, 16))
			var score0 := game.score
			await hold("move_right", 0.45)
			await _wait(0.1)
			print("TURTLE after kick: state=%d vx=%.0f" % [tt.state, tt.velocity.x])
			await shot("kicked")
			await _wait(1.2)
			var alive := 0
			for n in game.level.get_children():
				if n is Shroom and not n.dead and absf(n.global_position.x - 118 * 16) < 80:
					alive += 1
			print("TURTLE combo: score +%d, shrooms left near alley=%d, shell state=%d" % [game.score - score0, alive, tt.state if is_instance_valid(tt) else -1])
			await shot("combo")
			# red turtle stays on its ledge (160..164, top row 13)
			var red: Turtle = null
			for n in game.level.get_children():
				if n is Turtle and n.red and absf(n.global_position.x - 162 * 16) < 40:
					red = n
			print("RED before: pos=%s active=%s" % [red.global_position.round(), red.active])
			await teleport(Vector2i(156, 16))
			for i in 8:
				await _wait(0.5)
				if not is_instance_valid(red):
					print("RED freed at t=%.1f" % (i * 0.5))
					break
				print("RED t=%.1f pos=%s dir=%d state=%d floor=%s" % [i * 0.5, red.global_position.round(), red.dir, red.state, red.is_on_floor()])
			await shot("red_ledge")
		"exitpipe":
			game.menus.hide_all()
			game._start_game()
			game.level_index = Game.first_level_of_world(2)
			game._begin_level()
			await _wait(Game.CARD_TIME + 0.4)
			await teleport(Vector2i(205, 14))
			await _wait(0.3)
			await hold("move_down", 1.2)
			await _wait(1.5)
			state("after exit pipe")
			await shot("exit_area")
		"ice":
			game.menus.hide_all()
			game._start_game()
			game.level_index = Game.first_level_of_world(4)
			game._begin_level()
			await _wait(Game.CARD_TIME + 0.4)
			for n in game.get_tree().get_nodes_in_group("enemies"):
				n.queue_free()
			for spot in [Vector2i(3, 16), Vector2i(22, 16)]:
				await teleport(spot)
				await _wait(0.2)
				Input.action_press("run")
				await hold("move_right", 0.7)
				Input.action_release("run")
				var x0 := game.player.global_position.x
				await _wait(1.0)
				print("ICE slide from col %d: slid %.0f px after release" % [spot.x, game.player.global_position.x - x0])
			await shot("ice")
		"controls":
			await _wait(0.8)
			game.menus._show_screen(Menus.Screen.CONTROLS)
			await shot("controls")
			# rebind jump (pad) to X: X leaves "run", run keeps Y
			ControlsConfig.set_binding("jump", "pad", 2)
			ControlsConfig.set_binding("jump", "key", KEY_H)
			var names := func(a): return "%s | %s" % [ControlsConfig.key_label(a), ControlsConfig.pad_label(a)]
			print("CTRL jump=", names.call("jump"), "  run=", names.call("run"))
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_H
			print("CTRL H is jump: ", InputMap.event_is_action(ev, "jump"))
			game.menus._refresh_slots()
			await shot("rebound")
			ControlsConfig.reset()
			print("CTRL after reset jump=", names.call("jump"), "  run=", names.call("run"))
		"castle":
			game.menus.hide_all()
			game._start_game(3)
			await _wait(Game.CARD_TIME + 0.4)
			state("castle start")
			await teleport(Vector2i(28, 16))
			await _wait(0.8)
			await shot("firebars")
			await teleport(Vector2i(66, 16))
			await _wait(1.5)
			await shot("lava_lake")
			game.change_power(Player.Power.FIRE, false)
			await _wait(1.0)
			var ar: Vector2i = Game.LEVELS[game.level_index].ARENA     # castles vary in length
			await teleport(Vector2i(ar.x + 5, 16))
			await _wait(1.0)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			print("BOSS active=%s hp=%d cam_left=%d" % [boss.active, boss.hp, game.camera.limit_left])
			await shot("arena")
			# stomp it three times (drop onto its head, invulnerability between)
			for i in 3:
				if not is_instance_valid(boss) or boss.dead:
					break
				boss._act = 99.0          # no jumps / flames while the test drops onto it
				await _wait(maxf(boss._inv, 0.0) + 0.1)
				game.player.global_position = boss.global_position + Vector2(0, -80)
				game.player.velocity = Vector2(0, 150)
				await _wait(1.4)
				print("BOSS after stomp %d: hp=%d power=%d" % [i + 1, boss.hp if is_instance_valid(boss) else -1, game.player.power])
			await _wait(1.0)
			await shot("defeated")
			await _wait(5.0)
			state("after boss")
			print("level now: ", Game.LEVELS[game.level_index].ID)
		"cheat":
			await _wait(1.0)
			for b in [1, 3, 2, 0]:
				var ev := InputEventJoypadButton.new()
				ev.button_index = b
				ev.pressed = true
				ev.device = 0
				Input.parse_input_event(ev)
				await _frames(2)
				var up := ev.duplicate()
				up.pressed = false
				Input.parse_input_event(up)
				await _frames(2)
			await _wait(0.3)
			print("CHEAT screen=%d (LEVELS=%d)" % [game.menus.screen, Menus.Screen.LEVELS])
			await shot("level_select")
			var idx := Game.first_level_of_world(4) + 2
			game.menus._cheat_pending = idx > Game.reached_level_index()
			game.menus.hide_all()
			game.menus.play_pressed.emit(idx)
			await _wait(Game.CARD_TIME + 0.4)
			print("CHEAT level=%s cheated=%s reached=%s" % [Game.LEVELS[game.level_index].ID, game.cheated, GameSettings.reached_level_id()])
			game.lives = 1
			game.player_died(false)
			await _wait(6.5)
			await shot("gameover_cheated")
			print("CHEAT gameover screen=%d name_edit=%s" % [game.menus.screen, game.menus._name_edit])
		"fixes":
			# v0.14: lenient stomp, overlapping walkers, double stomp, fair bats
			await start_play()
			var p := game.player
			var lvl := game.level
			for e in game.get_tree().get_nodes_in_group("enemies"):
				e.queue_free()             # only the test's own enemies
			await _frames(2)
			# 1) edge stomp: hero falls onto the shroom's shoulder (9 px off-centre)
			var sh := Shroom.new()
			sh.position = Vector2(20 * 16 + 8, 17 * 16)
			lvl.add_child(sh)
			await _frames(3)
			sh.speed = 0.0
			p.global_position = sh.global_position + Vector2(-11, -26)
			p.velocity = Vector2(60, 200)
			await _wait(0.2)
			print("FIX edge stomp: shroom dead=%s hero power=%d state=%d" % [sh.dead, p.power, game.state])
			# 2) turtle dropped exactly onto a shroom: they must walk apart
			var s2 := Shroom.new()
			s2.position = Vector2(30 * 16 + 8, 17 * 16)
			lvl.add_child(s2)
			var t2 := Turtle.new()
			t2.position = s2.position + Vector2(0, -2)
			lvl.add_child(t2)
			await _wait(1.2)
			print("FIX overlap: |dx| after 1.2 s = %.0f px (dirs %d / %d)" % [
				absf(t2.global_position.x - s2.global_position.x), t2.dir, s2.dir])
			# 3) two enemies on the same spot, stomp them: both go down, no damage
			var s3 := Shroom.new()
			s3.position = Vector2(40 * 16 + 8, 17 * 16)
			lvl.add_child(s3)
			var t3 := Turtle.new()
			t3.position = s3.position
			lvl.add_child(t3)
			await _frames(3)
			s3.speed = 0.0
			t3.speed = 0.0
			p.star_t = 0.0
			p.invuln_t = 0.0
			p.global_position = s3.global_position + Vector2(0, -40)
			p.velocity = Vector2(0, 150)
			await _wait(0.5)
			print("FIX double stomp: shroom dead=%s turtle state=%d hero power=%d lives=%d state=%d" % [
				s3.dead, t3.state, p.power, game.lives, game.state])
			# 4) bat: warning phase, then it flies above a small hero's head
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(2))
			await _wait(Game.CARD_TIME + 0.4)
			p = game.player
			var bat: Bat = null
			for n in game.get_tree().get_nodes_in_group("enemies"):
				if n is Bat and bat == null:
					bat = n
				elif not (n is Bat):
					n.queue_free()
			var bc := -1
			var floor_r := 19
			for dc in [4, -4, 5, -5, 3, -3, 6, -6]:
				var c: int = int(bat.global_position.x / 16) + dc
				var r := int(bat.global_position.y / 16) + 2
				while r < 19 and not (game.level.at(c, r) in ["#", "c", "X", "w", "B", "?"]):
					r += 1
				if r < 19:
					bc = c
					floor_r = r
					break
			p.global_position = Vector2(bc * 16 + 8, floor_r * 16)
			p.velocity = Vector2.ZERO
			p.invuln_t = 30.0
			game._update_camera(0.0, true)
			await _wait(0.3)
			print("FIX bat after 0.3 s: state=%d (3 = warning) bat=%s hero=%s gstate=%d" % [bat._state,
				bat.global_position.round(), p.global_position.round(), game.state])
			await shot("bat_warn")
			var lowest := -INF
			for i in 90:
				await physics_frame
				if is_instance_valid(bat):
					lowest = maxf(lowest, bat.global_position.y + 10.0)
			print("FIX bat: state=%d, lowest hitbox edge %.0f px above the hero's feet (small hero 14, big 26, ducking 14)" % [
				bat._state if is_instance_valid(bat) else -1, p.global_position.y - lowest])
			await shot("bat_fly")
			# 5) castle moods
			for w in range(1, 7):
				game.menus.hide_all()
				game._start_game(Game.castle_of_world(w))
				await _wait(Game.CARD_TIME + 0.3)
				await teleport(Vector2i(10, 16))      # entrance hall, looking at section A
				await _wait(0.3)
				await shot("castle_%d" % w)
		"bossfair":
			# v0.15: telegraphed attacks, stun without attacks, projectiles fizzle,
			# no breath at a hero above, flower drop when out of fire power
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(2), true, true)
			await _wait(Game.CARD_TIME + 0.3)
			var p := game.player
			Input.action_press("move_right")
			await _wait(1.6)
			Input.action_release("move_right")
			await _wait(0.2)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			game.change_power(Player.Power.BIG, false)
			await _wait(1.0)
			p.global_position = Vector2(boss.global_position.x - 110.0, boss.global_position.y)
			p.velocity = Vector2.ZERO
			boss._act = 0.0
			await _wait(0.2)
			print("FAIR windup: anim=%s windup=%.2f crouch=%.2f (telegraph before the attack)" % [
				boss.sprite.animation, boss._windup, boss._crouch])
			await shot("windup")
			boss._act = 99.0
			boss._windup = 0.0
			boss._crouch = 0.0
			boss._breathe(p)
			await _wait(0.15)
			var flames := func() -> int:
				var n := 0
				for c in game.level.get_children():
					if c is BossFlame:
						n += 1
				return n
			print("FAIR before stomp: projectiles=%d" % flames.call())
			p.invuln_t = 0.0
			p.global_position = boss.global_position + Vector2(0, -80)
			p.velocity = Vector2(0, 150)
			await _wait(0.35)
			var flower := 0
			for it in game.get_tree().get_nodes_in_group("items"):
				if it is PowerUp and it.kind == PowerUp.Kind.FLOWER:
					flower += 1
			print("FAIR after stomp: hp=%d/%d stun=%.2f stars=%s anim=%s projectiles=%d flower=%d" % [boss.hp, boss.max_hp,
				boss._stun, boss._stars.visible, boss.sprite.animation, flames.call(), flower])
			await shot("stunned")
			boss._act = 0.0                         # would attack now if it could
			var spawned := 0
			for i in 50:
				await physics_frame
				spawned = maxi(spawned, flames.call())
			print("FAIR during stun: projectiles spawned=%d, after stun act=%.2f target=%.0f (hero x %.0f)" % [
				spawned, boss._act, boss._target_x, p.global_position.x])
			# hero hovering above the boss: the breath is called off
			await _wait(1.5)
			boss._act = 99.0
			boss._windup = 0.05
			boss.sprite.play(&"windup")
			p.global_position = boss.global_position + Vector2(10, -90)
			p.velocity = Vector2(0, -200)
			await _wait(0.15)
			print("FAIR hero above: projectiles=%d (expected 0)" % flames.call())
			await _wait(2.0)
			for it in game.get_tree().get_nodes_in_group("items"):
				if it is PowerUp and it.kind == PowerUp.Kind.FLOWER:
					print("FAIR flower rests at %s (arena %.0f..%.0f)" % [it.global_position.round(), boss.arena_left, boss.arena_right])
		"bossanim":
			# frame strip of the boss moving (idle / walk / windup / jump / stun)
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(4), true, true)
			await _wait(Game.CARD_TIME + 0.3)
			game.player.star_t = 60.0
			Input.action_press("move_right")
			await _wait(1.4)
			Input.action_release("move_right")
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			game.player.global_position.x = boss.arena_left + 60.0
			for i in 16:
				await _wait(0.18)
				var img := root.get_viewport().get_texture().get_image()
				var xf := root.get_viewport().get_final_transform() * root.get_viewport().get_canvas_transform()
				var c := xf * boss.global_position
				var sc := xf.get_scale().x
				img = img.get_region(Rect2i(int(c.x - 45 * sc), int(c.y - 85 * sc), int(90 * sc), int(95 * sc)))
				img.save_png("%s/bossanim_%02d_%s.png" % [outdir, i, boss.sprite.animation])
				if i == 8:
					boss.take_hit()
			print("BOSSANIM done")
		"lifepoints":
			# v0.15: Settings "1-UP points" — an extra life every N points
			await start_play()
			game.cfg["life_points"] = 2500
			var l0 := game.lives
			game.add_score(2000, game.player.global_position)
			var l1 := game.lives
			game.add_score(1000, game.player.global_position)      # crosses 2500
			var l2 := game.lives
			game.add_score(5200, game.player.global_position)      # 8200: crosses 5000 + 7500
			print("LIFEPTS lives %d -> %d (2000) -> %d (3000) -> %d (8200, expect +2)" % [l0, l1, l2, game.lives])
			game.cfg["life_points"] = 0
			var l3 := game.lives
			game.add_score(5000, null)
			print("LIFEPTS off: lives %d -> %d" % [l3, game.lives])
			game._to_title()
			await _wait(0.5)
			game.menus._return_screen = Menus.Screen.START
			game.menus._show_screen(Menus.Screen.SETTINGS)
			await _frames(3)
			await shot("settings_top")
			# D-pad down to the last row: the list must scroll along
			for i in 7:
				await _pad(12)
			await _frames(3)
			var f := game.get_viewport().gui_get_focus_owner()
			print("LIFEPTS focus after 7x down: %s in row '%s'" % [f.text if f is Button else f, (f.get_parent().get_child(0) as Label).text if f and f.get_parent().get_child(0) is Label else "?"])
			await shot("settings_bottom")
		"cheatpick":
			# the real way: open the level select with the pad code, move the
			# focus to a course, confirm with the pad or a tap. (A synthetic
			# mouse click is only honoured while the REAL pointer is over the
			# test window — Godot drops GUI mouse input otherwise — so it is
			# not part of this check.)
			for how in ["pad", "tap"]:
				game._to_title()
				await _wait(0.8)
				for b in [1, 3, 2, 0]:
					await _pad(b)
				await _wait(0.3)
				var target := "6-1" if how == "pad" else "4-2"
				var btn: Button = null
				for n in game.menus.find_children("*", "Button", true, false):
					if n.text.strip_edges() == target:
						btn = n
				print("PICK[%s] screen=%d button %s found=%s" % [how, game.menus.screen, target, btn != null])
				if how == "pad":
					btn.grab_focus()
					await _frames(2)
					await _pad(0)
				else:
					var c: Vector2 = btn.get_viewport().get_final_transform() * btn.get_global_rect().get_center()
					for down in [true, false]:
						var st := InputEventScreenTouch.new()
						st.pressed = down
						st.position = c
						Input.parse_input_event(st)
						await _frames(2)
				await _wait(Game.CARD_TIME + 0.5)
				print("PICK[%s] wanted %s -> started %s cheated=%s state=%d screen=%d" % [how, target,
					Game.LEVELS[game.level_index].ID, game.cheated, game.state, game.menus.screen])
		"newenemies":
			# bat (2-1)
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(2))
			await _wait(Game.CARD_TIME + 0.4)
			var bat: Bat = null
			for n in game.level.get_children():
				if n is Bat and absf(n.global_position.x - 35 * 16) < 20:
					bat = n
			await teleport(Vector2i(31, 16))
			game.player.star_t = 3.0            # survive the swoop, we only watch it
			await _wait(0.7)
			print("BAT state=%d pos=%s" % [bat._state, bat.global_position.round()])
			await shot("bat_swoop")
			await _wait(1.0)
			print("BAT dead=%s (star touch)" % [not is_instance_valid(bat) or bat.dead])
			# cactus (3-1) vs fireballs
			game._start_game(Game.first_level_of_world(3))
			await _wait(Game.CARD_TIME + 0.4)
			game.change_power(Player.Power.FIRE, false)
			await _wait(1.0)
			var cac: CactusStack = null
			for n in game.level.get_children():
				if n is CactusStack and absf(n.global_position.x - 36 * 16) < 30:
					cac = n
			await teleport(Vector2i(28, 16))
			game.player.facing = 1
			await _wait(0.3)
			await shot("cactus")
			for i in 4:
				await press("run")
				await _wait(0.45)
				print("CACTUS segments=%s" % (cac.segments if is_instance_valid(cac) and not cac.dead else 0))
			# penguin (4-1)
			game._start_game(Game.first_level_of_world(4))
			await _wait(Game.CARD_TIME + 0.4)
			await teleport(Vector2i(3, 16))
			var pen: Penguin = null
			for n in game.level.get_children():
				if n is Penguin:
					pen = n
					break
			var slid := false
			for i in 40:
				await _wait(0.1)
				if is_instance_valid(pen) and pen.sprite.animation == &"slide":
					slid = true
					await shot("penguin_slide")
					break
			print("PENGUIN slid=%s speed=%.0f" % [slid, pen.speed if is_instance_valid(pen) else -1.0])
		"bossselect":
			await _wait(0.8)
			game.menus._open_level_select()
			await shot("level_select")
			game.menus._boss_pending = true
			game.menus._cheat_pending = true
			game.menus.hide_all()
			game.menus.play_pressed.emit(Game.castle_of_world(3))
			await _wait(Game.CARD_TIME + 0.4)
			state("at boss 3-3")
			print("BOSSSEL level=%s cheated=%s" % [Game.LEVELS[game.level_index].ID, game.cheated])
			for i in 8:
				Input.action_press("move_right")
				await _wait(0.25)
				var bb := game.get_tree().get_nodes_in_group("boss")
				print("BOSSSEL t=%.2f px=%.0f state=%d bosses=%d active=%s started=%s" % [i * 0.25,
					game.player.global_position.x if game.player else -1.0, game.state, bb.size(),
					bb[0].active if bb.size() > 0 else false, game.level.get_meta("boss_started", false)])
			Input.action_release("move_right")
			await _wait(0.6)
			var bosses := game.get_tree().get_nodes_in_group("boss")
			print("BOSSSEL boss active=%s hp=%d cam_left=%d" % [bosses[0].active, bosses[0].hp, game.camera.limit_left])
			await shot("boss_arena")
		"bossfix":
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(1), true, true)
			await _wait(Game.CARD_TIME + 0.4)
			print("FIX boss-direct start: power=%d (FIRE=%d)" % [game.player.power, Player.Power.FIRE])
			game.player_died(true)
			await _wait(2.8 + Game.CARD_TIME + 0.8)
			print("FIX after death respawn: power=%d pos=%s" % [game.player.power, game.player.global_position.round()])
			# normal run: pass the boss checkpoint small, bump the flower block
			game._start_game(Game.castle_of_world(1))
			await _wait(Game.CARD_TIME + 0.4)
			var ar: Vector2i = Game.LEVELS[game.level_index].ARENA
			await teleport(Vector2i(ar.x - 10, 16))
			await hold("move_right", 0.5)
			await _wait(0.8)
			print("FIX after boss checkpoint: power=%d cp=%s" % [game.player.power, game.checkpoint_pos])
			await teleport(Vector2i(ar.x - 4, 16))
			await hold("jump", 0.25)
			await _wait(1.5)
			await shot("flower_block")
			var items := game.get_tree().get_nodes_in_group("items")
			print("FIX items from N block: %s" % [items.map(func(i): return i.kind)])
			# beat the boss -> extra life
			await teleport(Vector2i(ar.x + 5, 16))
			await _wait(1.0)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			var lives0 := game.lives
			for i in 3:
				if not is_instance_valid(boss) or boss.dead:
					break
				boss._act = 99.0
				await _wait(maxf(boss._inv, 0.0) + 0.1)
				game.player.global_position = boss.global_position + Vector2(0, -80)
				game.player.velocity = Vector2(0, 150)
				await _wait(1.4)
			await _wait(3.0)
			print("FIX lives before=%d after win=%d" % [lives0, game.lives])
			await shot("win_1up")
		"splash":
			# fresh game WITH splash (the default init skipped it)
			var g2: Game = load("res://game.tscn").instantiate()
			root.remove_child(game)
			game.queue_free()
			game = g2
			root.add_child(game)
			await _wait(1.5)
			await shot("splash_bar")
			print("SPLASH active=%s menu=%d" % [is_instance_valid(game.splash) and game.splash._active, game.menus.screen])
			await _wait(2.2)
			print("SPLASH after: menu=%d (START=%d)" % [game.menus.screen, Menus.Screen.START])
		"bossstress":
			# wall-up stress test (RG552 one-off crash hunt): enter every boss
			# arena repeatedly, sometimes dying right at the moment it walls up
			var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 12
			for i in runs:
				var w := i % 4 + 1
				game.menus.hide_all()
				game._start_game(Game.castle_of_world(w), true, true)
				await _wait(Game.CARD_TIME + 0.3)
				Input.action_press("move_right")
				var started := false
				for f in 90:
					await _frames(1)
					if game.level and game.level.get_meta("boss_started", false):
						started = true
						break
				Input.action_release("move_right")
				if i % 3 == 1 and game.player:
					game.player_died(false)          # die in the same frame as the wall-up
				await _frames(20 + i * 3)
				var b := game.get_tree().get_nodes_in_group("boss")
				print("STRESS run=%d world=%d started=%s state=%d bosses=%d" % [i, w, started, game.state, b.size()])
			print("STRESS done")
		"lifts":
			game.menus.hide_all()
			game._start_game(2)                  # 1-3: sideways lift over the pond
			await _wait(Game.CARD_TIME + 0.3)
			var lift: MovingPlatform = null
			for n in game.level.get_children():
				if n is MovingPlatform:
					lift = n
			game.player.global_position = lift.global_position + Vector2(24, -20)
			game.player.velocity = Vector2.ZERO
			game.player.star_t = 30.0           # enemies nearby: invulnerable observer
			game._update_camera(0.0, true)
			await _wait(0.6)
			var x0 := game.player.global_position.x
			var lx0 := lift.global_position.x
			await _wait(1.2)
			print("LIFT h: lift moved %.0f px, hero moved %.0f px, on_floor=%s y=%.0f (lift top %.0f) state=%d" % [
				lift.global_position.x - lx0, game.player.global_position.x - x0, game.player.is_on_floor(),
				game.player.global_position.y, lift.global_position.y, game.state])
			await shot("lift_h")
			game._start_game(Game.first_level_of_world(2) + 1)   # 2-2: vertical lift over lava
			await _wait(Game.CARD_TIME + 0.3)
			for n in game.level.get_children():
				if n is MovingPlatform:
					lift = n
			game.player.global_position = lift.global_position + Vector2(24, -20)
			game.player.velocity = Vector2.ZERO
			game.player.star_t = 30.0
			game._update_camera(0.0, true)
			await _wait(0.5)
			var y0 := game.player.global_position.y
			await _wait(1.3)
			print("LIFT v: hero dy=%.0f on_floor=%s alive_state=%d" % [game.player.global_position.y - y0, game.player.is_on_floor(), game.state])
			await shot("lift_v")
		"bossvariants":
			for w in [2, 3, 4]:
				game.menus.hide_all()
				game._start_game(Game.castle_of_world(w), true, true)
				await _wait(Game.CARD_TIME + 0.3)
				game.player.star_t = 30.0       # invulnerable observer
				Input.action_press("move_right")
				await _wait(1.8)
				Input.action_release("move_right")
				await _wait(0.3)
				var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
				boss._act = 99.0
				boss._breathe(game.player)
				if w == 3:
					boss.velocity.y = -360.0
					boss._jumping = true
				await _wait(0.7)
				var kinds := {}
				for n in game.level.get_children():
					if n is BossFlame:
						kinds[n.kind] = int(kinds.get(n.kind, 0)) + 1
				print("VARIANT world=%d projectiles=%s" % [w, kinds])
				await shot("boss_w%d" % w)
		"sky":
			# world 5: backdrop, falling slab, tipping plank, imp, gull, boss bolts
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(5))
			await _wait(Game.CARD_TIME + 0.4)
			var p := game.player
			await shot("start")
			var slab: FallingPlatform = null
			var tip: TipPlatform = null
			for n in game.level.get_children():
				if n is FallingPlatform and slab == null:
					slab = n
				if n is TipPlatform and tip == null:
					tip = n
			p.global_position = slab.global_position + Vector2(24, -2)
			p.velocity = Vector2.ZERO
			game._update_camera(0.0, true)
			await _wait(0.3)
			var y0 := p.global_position.y
			print("SLAB t=0.3 hero_y=%.0f slab_y=%.0f on_floor=%s" % [y0, slab.global_position.y, p.is_on_floor()])
			await _wait(0.6)
			print("SLAB t=0.9 hero_y=%.0f slab_y=%.0f on_floor=%s (falls with it)" % [p.global_position.y, slab.global_position.y, p.is_on_floor()])
			await shot("slab_falling")
			await _wait(2.5)
			print("SLAB after fall: state=%d lives=%d" % [game.state, game.lives])
			await _wait(3.0)
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(5))
			await _wait(Game.CARD_TIME + 0.4)
			p = game.player
			for n in game.level.get_children():
				if n is TipPlatform:
					tip = n
					break
			p.global_position = tip.global_position + Vector2(26, -2)
			p.velocity = Vector2.ZERO
			game._update_camera(0.0, true)
			for i in 9:
				await _wait(0.3)
				var col := p.get_last_slide_collision()
				print("TIP t=%.1f rot=%.0f deg hero=(%.0f,%.0f) on_floor=%s floor_n=%s col=%s" % [0.3 * (i + 1), rad_to_deg(tip.rotation),
					p.global_position.x - tip.global_position.x, p.global_position.y - tip.global_position.y, p.is_on_floor(),
					p.get_floor_normal().snapped(Vector2(0.01, 0.01)), col.get_collider().get_class() + " n=" + str(col.get_normal().snapped(Vector2(0.01, 0.01))) if col else "-"])
				if i == 1:
					await shot("tipping")
			await _wait(2.5)
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(5))
			await _wait(Game.CARD_TIME + 0.4)
			p = game.player
			p.star_t = 60.0
			await teleport(Vector2i(80, 16))
			await _wait(5.5)
			var spikies := 0
			var imp_x := -1.0
			for n in game.level.get_children():
				if n is Spiky and n.from_sky:
					spikies += 1
				if n is CloudImp:
					imp_x = n.global_position.x - p.global_position.x
			print("IMP rel_x=%.0f thrown spikies=%d" % [imp_x, spikies])
			await shot("imp")
			await teleport(Vector2i(118, 16))
			await _wait(1.0)
			for n in game.level.get_children():
				if n is Gull:
					print("GULL active=%s pos=%s" % [n.active, n.global_position.round()])
			await shot("gull")
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(5), true, true)
			await _wait(Game.CARD_TIME + 0.3)
			game.player.star_t = 30.0
			Input.action_press("move_right")
			await _wait(1.8)
			Input.action_release("move_right")
			await _wait(0.3)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			boss._act = 99.0
			boss._breathe(game.player)
			await _wait(0.3)
			await shot("bolts_warn")
			await _wait(0.45)
			var kinds := {}
			for n in game.level.get_children():
				if n is BossFlame:
					kinds[n.kind] = int(kinds.get(n.kind, 0)) + 1
			print("BOSS5 hp=%d projectiles=%s" % [boss.max_hp, kinds])
			await shot("bolts_strike")
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(5) + 1)
			await _wait(Game.CARD_TIME + 0.4)
			await shot("dusk")
		"sea":
			# world 6: swimming, surface cap, enemies, exit pipe to the beach, last boss
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(6))
			await _wait(Game.CARD_TIME + 0.4)
			var p := game.player
			p.star_t = 60.0
			print("SEA swimming=%s music=%s" % [p.swimming, game._snd_call("current_music", "")])
			await shot("start")
			var y0 := p.global_position.y
			for i in 8:
				await press("jump")
				await _wait(0.18)
			print("SWIM after 8 fast strokes: rose %.0f px, feet y=%.0f (surface cap %.0f + body)" % [
				y0 - p.global_position.y, p.global_position.y, Player.SWIM_TOP])
			await shot("surface")
			var yt := p.global_position.y
			await _wait(1.0)
			print("SWIM sink 1 s: %.0f px (vy=%.0f)" % [p.global_position.y - yt, p.velocity.y])
			var x0 := p.global_position.x
			Input.action_press("move_right")
			await _wait(1.0)
			print("SWIM right 1 s: moved %.0f px vx=%.0f anim=%s on_floor=%s pos=%s" % [p.global_position.x - x0,
				p.velocity.x, p.sprite.animation, p.is_on_floor(), p.global_position.round()])
			Input.action_release("move_right")
			await teleport(Vector2i(45, 8))
			await _wait(0.6)
			await shot("walls")
			var kinds := {}
			for n in game.level.get_children():
				for cls in ["Fish", "Jellyfish", "Crab", "Urchin"]:
					if n.get_script() and n.get_script().get_global_name() == cls:
						kinds[cls] = int(kinds.get(cls, 0)) + 1
			print("SEA enemies: ", kinds)
			await teleport(Vector2i(126, 13))
			await _wait(2.0)
			await shot("jelly")
			# exit pipe -> beach
			await teleport(Vector2i(200, 16))
			Input.action_press("move_right")
			await _wait(2.5)
			Input.action_release("move_right")
			await _wait(1.5)
			print("EXIT area=%s swimming=%s theme=%s" % [game.area, p.swimming, game.backdrop.theme])
			await shot("beach")
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(6) + 1)
			await _wait(Game.CARD_TIME + 0.4)
			await shot("deep")
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(6), true, true)
			await _wait(Game.CARD_TIME + 0.3)
			game.player.star_t = 30.0
			Input.action_press("move_right")
			await _wait(1.8)
			Input.action_release("move_right")
			await _wait(0.3)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			var seen := {}
			for i in 6:
				boss._act = 99.0
				boss._breathe(game.player)
				await _wait(0.2)
				for n in game.level.get_children():
					if n is BossFlame:
						seen[n.kind] = true
				await _wait(0.9)
			print("BOSS6 hp=%d attacks seen=%s" % [boss.max_hp, seen.keys()])
			await shot("final_boss")
		"map":
			# v1.1 world map: Play -> map, walk, enter, clear -> reveal, pause, tap
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			var saved_level = c.get_value("progress", "level", "")
			var saved_world = c.get_value("progress", "world", 1)
			c.set_value("progress", "level", "1-3")
			c.set_value("progress", "world", 1)
			c.save(GameSettings.CFG_PATH)
			await _wait(0.6)
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(0.8)
			var m := game.world_map
			print("MAP state=%d (MAP=%d) reach=%d at=%d hud_world=%s music=%s" % [game.state, Game.State.MAP, m.reach, m.at,
				Game.LEVELS[game.level_index].ID, game._snd_call("current_music", "")])
			await shot("map_start")
			await _act("move_right")                 # 1-4 is locked: must not move
			await _wait(0.6)
			print("MAP right into a locked course: at=%d" % m.at)
			await _act("move_left")
			await _wait(1.2)
			print("MAP left: at=%d" % m.at)
			await _act("move_right")
			await _wait(1.2)
			print("MAP right again: at=%d banner='%s'" % [m.at, m._title.text])
			await _act("pause")
			await _wait(0.3)
			print("MAP pause: paused=%s menu=%d" % [game._paused, game.menus.screen])
			game.menus.hide_all()
			game._resume()
			await _wait(0.3)
			await _act("jump")
			await _wait(Game.CARD_TIME + 0.4)
			print("MAP entered: state=%d course=%s" % [game.state, Game.LEVELS[game.level_index].ID])
			# clear the course: back to the map, road to 1-4 is revealed
			game.state = Game.State.CLEAR
			game._level_done()
			await _wait(2.3)
			print("MAP after clear: state=%d busy=%s reach(during)=%d" % [game.state, m.is_busy(), m.reach])
			await _wait(0.5)
			await shot("map_reveal")
			await _wait(2.0)
			c.load(GameSettings.CFG_PATH)
			print("MAP after reveal: reach=%d at=%d saved level=%s" % [m.reach, m.at, c.get_value("progress", "level", "")])
			await shot("map_after")
			# a tap on the 1-1 marker walks there, a second tap enters it
			for n in 2:
				var sp: Vector2 = root.get_viewport().get_final_transform() * (game.get_viewport().get_canvas_transform() \
					* (WorldMapData.NODES[0] + Vector2(0, -4)))
				for down in [true, false]:
					var st := InputEventScreenTouch.new()
					st.pressed = down
					st.position = sp
					Input.parse_input_event(st)
					await _frames(2)
				await _wait(4.0)
				print("MAP tap %d: state=%d at=%d" % [n + 1, game.state, m.at])
			c.set_value("progress", "level", saved_level)
			c.set_value("progress", "world", saved_world)
			c.save(GameSettings.CFG_PATH)
		"mapview":
			# screenshots of the map at a given progress (env MAP_AT = course index)
			var at := int(OS.get_environment("MAP_AT")) if OS.get_environment("MAP_AT") != "" else 14
			game.menus.hide_all()
			game._new_run(false)
			game._run_reach = at
			game._show_map(at)
			await _wait(1.0)
			await shot("map_at_%d" % at)
		"selects":
			# the level select must fit all worlds on the 270-px canvas
			await _wait(0.5)
			game.menus._show_screen(Menus.Screen.LEVELS)
			await _frames(3)
			await shot("levels")
		"mutebtn":
			# the Sound menu's mute label must follow every toggle (v0.11 fix)
			await _wait(0.5)
			var snd := root.get_node("/root/Snd")
			var was: bool = snd.is_muted()
			game.menus._show_screen(Menus.Screen.SOUND)
			await _frames(2)
			var btn: Button = null
			for n in game.menus.find_children("*", "Button", true, false):
				if n.text in ["On", "Muted"]:
					btn = n
			for i in 2:
				btn.pressed.emit()
				await _frames(1)
				print("MUTE click %d: label=%s muted=%s hud=%s" % [i + 1, btn.text, snd.is_muted(), game.hud._muted if "_muted" in game.hud else "?"])
			game._toggle_mute()             # M key / Select while the menu is open
			await _frames(1)
			print("MUTE via key: label=%s muted=%s" % [btn.text, snd.is_muted()])
			game.menus._show_screen(Menus.Screen.SETTINGS)
			await _frames(2)
			game._toggle_mute()             # button freed: no error expected
			await _frames(1)
			snd.set_muted(was)
			print("MUTE done, restored=%s" % was)
		"jumpfeel":
			# v0.11 assists: tap / hold / double jump heights, landing slide
			await start_play()
			game.player.star_t = 60.0
			var p := game.player
			# [label, first hold, second press at (or -1), second hold]
			for spec in [["tap", 0.03, -1.0, 0.0], ["hold", 0.6, -1.0, 0.0],
					["double tap", 0.03, 0.25, 0.03], ["double hold", 0.3, 0.4, 0.6]]:
				await teleport(Vector2i(8, 16))
				await _wait(0.3)
				var y0 := p.global_position.y
				var top := y0
				Input.action_press("jump")
				var t := 0.0
				var second := false
				while t < 2.0:
					await physics_frame
					t += 1.0 / 60.0
					if t >= spec[1] and not second:
						Input.action_release("jump")
					if spec[2] > 0.0 and not second and t >= spec[2]:
						second = true
						Input.action_press("jump")
					if second and t >= spec[2] + spec[3]:
						Input.action_release("jump")
					top = minf(top, p.global_position.y)
				print("JUMP %-12s height=%.1f px = %.2f tiles" % [spec[0], y0 - top, (y0 - top) / 16.0])
			# landing slide: keep the direction held through the jump, let go
			# on touchdown (what a player does on a narrow platform)
			for sp in [["walk", false], ["run", true]]:
				await teleport(Vector2i(2, 16))
				if sp[1]:
					Input.action_press("run")
				Input.action_press("move_right")
				await _wait(0.9)
				Input.action_press("jump")
				await _wait(0.3)
				Input.action_release("jump")
				while not p.is_on_floor():
					await physics_frame
				Input.action_release("move_right")
				Input.action_release("run")
				var xl := p.global_position.x
				var vl := p.velocity.x
				await _wait(0.8)
				print("SLIDE %s: speed on touchdown %.0f px/s, slid %.1f px" % [sp[0], vl, p.global_position.x - xl])
			# 1-4 pillars: walk right, jump at the ledge / pillar edge (hold 0.3 s),
			# let go of the direction on touchdown
			game.menus.hide_all()
			game._start_game(3)
			await _wait(Game.CARD_TIME + 0.3)
			p = game.player
			p.star_t = 60.0
			await teleport(Vector2i(8, 16))
			for edge in [188.0, 268.0]:
				Input.action_press("move_right")
				while p.global_position.x < edge:
					await physics_frame
				Input.action_press("jump")
				await _wait(0.3)
				Input.action_release("jump")
				await _wait(0.1)
				while not p.is_on_floor() and game.state == Game.State.PLAYING:
					await physics_frame
				Input.action_release("move_right")
				await _wait(0.6)
				print("PILLAR from x>%.0f: x=%.0f y=%.0f (pillar top y=224; pillars x 224..272 / 304..352) state=%d" % [
					edge, p.global_position.x, p.global_position.y, game.state])
			await shot("pillars")
		"pause":
			await start_play()
			game._toggle_pause()
			await shot("paused")
			game._toggle_pause()
			await _wait(0.3)
			state("resumed")
		"save":
			# v1.2 autosave: quit dialog + name, Continue, game over, New Game,
			# level select runs leave the saved game alone
			SaveGame.clear()
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			c.set_value("progress", "level", "1-3")
			c.set_value("progress", "world", 1)
			c.save(GameSettings.CFG_PATH)
			await _wait(0.6)
			game._to_title()
			await _frames(3)
			print("SAVE title without save: ", _button_texts())
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(0.8)
			game.score = 912340          # beats every entry on this machine
			game.lives = 5
			game.coins = 7
			game.power = Player.Power.FIRE
			await _act("move_left")
			await _wait(1.4)
			var s := SaveGame.load_run()
			print("SAVE after map step: at=%s score=%d lives=%d coins=%d power=%d id_ok=%s" % [s.at, s.score,
				s.lives, s.coins, s.power, int(s.id) == game.run_id])
			var run := game.run_id
			await _act("pause")
			await _wait(0.3)
			await _press_button("Main Menu")
			print("SAVE quit dialog: screen=%d (QUIT=%d) buttons=%s" % [game.menus.screen, Menus.Screen.QUIT, _button_texts()])
			print("SAVE quit text: ", _hints())
			await shot("quit_menu")
			game.menus._name_edit.text = "tester"
			await _press_button("Save & Menu")
			await _wait(0.4)
			var list := HallOfFame.load_list()
			var r := HallOfFame.run_rank(run)
			print("SAVE hof: rank=%d name=%s score=%s entries_of_run=%d" % [r, list[r].name, list[r].score,
				list.filter(func(e): return int(e.get("run", 0)) == run).size()])
			print("SAVE title with save: state=%d buttons=%s" % [game.state, _button_texts()])
			await shot("title_continue")
			await _press_button("Continue  1-2")
			await _wait(0.8)
			print("SAVE continued: state=%d at=%d score=%d lives=%d coins=%d power=%d same_run=%s name=%s" % [
				game.state, game.world_map.at, game.score, game.lives, game.coins, game.power,
				game.run_id == run, game.run_name])
			await _act("jump")
			await _wait(Game.CARD_TIME + 0.4)
			print("SAVE in course: state=%d course=%s power=%d" % [game.state, Game.LEVELS[game.level_index].ID,
				game.player.power])
			game.add_score(1000)
			await _act("pause")
			await _wait(0.3)
			await _press_button("Exit")
			print("SAVE exit dialog: buttons=%s name_field=%s" % [_button_texts(),
				game.menus._name_edit.text if game.menus._name_edit else "-"])
			print("SAVE exit text: ", _hints())
			await shot("quit_exit")
			await _press_button("Back")
			print("SAVE back: screen=%d (PAUSE=%d)" % [game.menus.screen, Menus.Screen.PAUSE])
			list = HallOfFame.load_list()
			r = HallOfFame.run_rank(run)
			print("SAVE hof in course: score=%s name=%s; saved score=%d" % [list[r].score, list[r].name,
				SaveGame.load_run().score])
			game.menus.hide_all()
			game._resume()
			await _wait(0.3)
			game.lives = 1
			game.player_died(false)
			await _wait(6.0)
			print("SAVE game over: screen=%d save_exists=%s name_field=%s" % [game.menus.screen,
				SaveGame.exists(), game.menus._name_edit.text if game.menus._name_edit else "-"])
			await shot("gameover")
			await _press_button("Menu")
			await _wait(0.3)
			print("SAVE title after game over: ", _button_texts())
			# a new game over a saved run asks first
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(0.8)
			game.score = 5000
			game.save_run()
			var old_id := int(SaveGame.load_run().id)
			game._to_title()
			await _frames(3)
			await _press_button("New Game")
			await _frames(3)
			var fo := game.get_viewport().gui_get_focus_owner()
			print("SAVE new game dialog: screen=%d (NEWGAME=%d) focus=%s text=%s" % [game.menus.screen,
				Menus.Screen.NEWGAME, fo.text if fo is Button else "?", _hints()])
			await shot("newgame")
			await _press_button("New Game")
			await _press_button("1 Player")          # v1.6: players choice first
			await _wait(0.8)
			print("SAVE new run: state=%d score=%d save_replaced=%s" % [game.state, game.score,
				int(SaveGame.load_run().id) != old_id])
			# the level select never touches the saved game
			var keep := int(SaveGame.load_run().id)
			game._start_game(0)
			await _wait(Game.CARD_TIME + 0.4)
			game.add_score(300)
			await _act("pause")
			await _wait(0.3)
			await _press_button("Main Menu")
			print("SAVE practice dialog: ", _hints(), " buttons=", _button_texts())
			await _press_button("Main Menu")
			await _wait(0.3)
			print("SAVE practice kept save: %s" % (int(SaveGame.load_run().id) == keep))
		"polish":
			# v1.2.1: shell payout limit, boss by difficulty (daze, flowers) and
			# never firing upward, the ten bonus rooms, the dragon waiting at the
			# grotto, level select = no high score, name asked once, Clear list
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(2))
			await _wait(Game.CARD_TIME + 0.4)
			var p := game.player
			var tt := Turtle.new()
			game.level.add_child(tt)
			tt.global_position = p.global_position + Vector2(48, 0)
			await _wait(0.3)
			tt._set_state(Turtle.State.SHELL)
			var s0 := game.score
			var l0 := game.lives
			var n := 0
			for i in 60:
				if tt.dead:
					break
				tt._safe_t = 0.0
				p.invuln_t = 0.0
				p.stomp_grace = 0.1
				p.global_position = tt.global_position + Vector2(0, -12)
				tt._touch_player(p)
				n += 1
			print("SHELL farm: touches=%d dead=%s paid=%d score +%d lives +%d" % [n, tt.dead, tt.paid,
				game.score - s0, game.lives - l0])
			# boss by difficulty
			var cfg0 := GameSettings.load_all()
			var flames := func() -> Array:
				var out := []
				for c in game.level.get_children():
					if c is BossFlame and not c.is_queued_for_deletion():
						out.append(c)
				return out
			for d in 3:
				var cf := GameSettings.load_all()
				cf.difficulty = d
				GameSettings.save(cf)
				game.menus.hide_all()
				game._start_game(Game.castle_of_world(1), false, true)
				await _wait(Game.CARD_TIME + 0.3)
				p = game.player
				Input.action_press("move_right")
				await _wait(1.6)
				Input.action_release("move_right")
				await _wait(0.3)
				var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
				boss._act = 99.0
				game.change_power(Player.Power.BIG, false)
				await _wait(2.4)
				var fl := 0
				for it in game.get_tree().get_nodes_in_group("items"):
					if it is PowerUp and it.kind == PowerUp.Kind.FLOWER and it.global_position.x >= boss.arena_left:
						fl += 1
				boss.take_hit()
				print("BOSS %s: difficulty=%d stun=%.2f flower after losing fire=%d" % [
					GameSettings.DIFF_NAMES[d], boss.difficulty, boss._stun, fl])
				if d == 1:
					await _wait(0.9)
					await shot("boss_flower")
					# never upward: hero in the air in front of it, every world's breath
					var min_vy := 999.0
					var kinds := {}
					for w in [1, 2, 4, 5, 6, 6, 6, 6]:
						for f in flames.call():
							f.queue_free()
						boss.world = w
						boss._stun = 0.0
						p.global_position = boss.global_position + Vector2(-100, -70)
						boss._breathe(p)
						for f in flames.call():
							if f.kind in ["flame", "ice"]:
								min_vy = minf(min_vy, f.velocity.y)
								kinds[f.kind] = true
					print("BOSS aim: smallest vy of flames/ice = %.1f (>= 0: nothing upward) kinds=%s" % [min_vy, kinds.keys()])
					await _wait(0.8)
					await shot("boss_ice")
			GameSettings.save(cfg0)
			# the ten bonus rooms
			for id in ["1-1", "1-2", "1-3", "2-1", "2-2", "3-1", "3-2", "4-1", "4-2", "5-1"]:
				game.menus.hide_all()
				game._start_game(Game.level_of_id(id))
				if id == "3-2":
					game.has_dino = true
					game._begin_level()
				await _wait(Game.CARD_TIME + 0.3)
				p = game.player
				var rode := p.riding != null
				for z in game.level.get_children():
					if z is WarpZone and z.warp.area == "bonus":
						game.enter_warp(z)
						break
				await _wait(1.6)
				print("BONUS %s: area=%s theme=%s music=%s swimming=%s dragon: rode=%s now=%s parked=%s" % [id,
					game.area, game.backdrop.theme, game._snd_call("current_music", ""), p.swimming, rode,
					p.riding != null, game._dino_parked])
				await shot("bonus_" + id)
				if id == "3-2":
					for z in game.level.get_children():
						if z is WarpZone and z.warp.area == "main":
							p.global_position = z.global_position + Vector2(-6, 0)
							game.enter_warp(z)
							break
					await _wait(2.2)
					print("GROTTO left: area=%s swimming=%s riding=%s parked=%s" % [game.area, p.swimming,
						p.riding != null, game._dino_parked])
					await shot("grotto_back")
			print("HOF practice: score=%d rank=%d (expected -1)" % [game.score, HallOfFame.run_rank(game.run_id)])
			# a named run: the quit dialog shows the entry, no name field
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(0.8)
			game.score = 987650
			game.set_run_name("anna")
			await _act("pause")
			await _wait(0.3)
			await _press_button("Main Menu")
			print("QUIT named: name_field=%s text=%s buttons=%s" % [game.menus._name_edit != null, _hints(), _button_texts()])
			await shot("quit_named")
			await _press_button("Save & Menu")
			await _wait(0.3)
			await _press_button("High Scores")
			print("HOF screen: buttons=%s" % [_button_texts()])
			await _press_button("Clear list")
			var fo := game.get_viewport().gui_get_focus_owner()
			print("CLEAR dialog: screen=%d focus=%s" % [game.menus.screen, fo.text if fo is Button else "?"])
			await shot("clear_dialog")
			await _press_button("Delete")
			print("CLEAR done: entries=%d buttons=%s" % [HallOfFame.load_list().size(), _button_texts()])
		"water":
			# v1.3: castle pools (moat + tank in 6-3), leap out at the surface,
			# currents, the dragon waiting at a pool, currents in 6-1
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(6))
			await _wait(Game.CARD_TIME + 0.4)
			var p := game.player
			p.star_t = 60.0
			await teleport(Vector2i(32, 13))
			await hold("move_right", 0.6)
			await _wait(0.4)
			print("POOL in: swimming=%s area_water=%s pos=%s" % [p.swimming, p.area_water, p.global_position.round()])
			await shot("moat")
			await teleport(Vector2i(46, 17))
			var x0 := p.global_position.x
			await _wait(0.6)
			print("CURRENT (moat, flows left): dx after 0.6 s = %.0f px" % (p.global_position.x - x0))
			await teleport(Vector2i(35, 14))
			await _wait(0.1)
			Input.action_press("jump")
			await _wait(0.05)
			print("LEAP: vy=%.0f swimming=%s" % [p.velocity.y, p.swimming])
			var top_y := p.global_position.y
			for i in 30:
				await physics_frame
				top_y = minf(top_y, p.global_position.y)
			Input.action_release("jump")
			print("LEAP highest feet y=%.0f (surface y=224, rim top y=224)" % top_y)
			# tank: leap out onto the far rim
			await teleport(Vector2i(96, 9))
			await shot("tank")
			await teleport(Vector2i(96, 9))
			Input.action_press("move_right")
			Input.action_press("jump")
			for i in 48:
				await physics_frame
				if i % 4 == 0:
					print("TANK t=%d pos=%s v=%s swim=%s leap=%.2f floor=%s" % [i, p.global_position.round(), p.velocity.round(),
						p.swimming, p._leap_t, p.is_on_floor()])
			Input.action_release("jump")
			await _wait(0.3)
			Input.action_release("move_right")
			await _wait(0.5)
			print("TANK leap: pos=%s on_floor=%s (rim top y=144, cols 98-99)" % [p.global_position.round(), p.is_on_floor()])
			# the dragon waits at the pool
			await teleport(Vector2i(31, 16))
			var d := Dino.new()
			game.level.add_child(d)
			d.global_position = p.global_position
			p.mount(d)
			await _wait(0.2)
			await teleport(Vector2i(40, 16))
			await _wait(0.3)
			print("DINO in pool: riding=%s parked=%s swimming=%s" % [p.riding != null, game._dino_parked, p.swimming])
			await teleport(Vector2i(57, 16))
			await _wait(0.5)
			print("DINO back on land: riding=%s parked=%s" % [p.riding != null, game._dino_parked])
			# 6-1: the warm stream carries you right
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(6))
			await _wait(Game.CARD_TIME + 0.4)
			p = game.player
			p.star_t = 60.0
			await teleport(Vector2i(125, 5))
			x0 = p.global_position.x
			await _wait(1.0)
			print("STREAM 6-1 (flows right): dx after 1 s = %.0f px" % (p.global_position.x - x0))
			await shot("stream")
		"ghost":
			# v1.4 world 7: doors (door room, closet, crypt exit), ghosts shy
			# when faced, bone turtles fall apart + stand up, phantom king
			var go := func(lv: int) -> void:
				game.menus.hide_all()
				game._start_game(lv, true)
				await _wait(Game.CARD_TIME + 0.4)
			var vshot := func(label: String) -> void:
				var keep: float = game.player.invuln_t
				game.player.invuln_t = 0.0
				await shot(label)
				game.player.invuln_t = keep
			var door := func(cell: Vector2i, label: String) -> void:
				await teleport(cell)
				await _wait(0.25)
				Input.action_press("move_down")
				await _frames(3)
				Input.action_release("move_down")
				await _wait(1.6)
				print("DOOR %s from %s -> cell %s area=%s gstate=%d alpha=%.2f" % [label, cell,
					Vector2i(int(game.player.global_position.x / 16.0), int(game.player.global_position.y / 16.0) - 1),
					game.area, game.state, game.player.modulate.a])
			await go.call(Game.first_level_of_world(7))
			var p := game.player
			await shot("hall_start")
			# the ghost at (21,10) is in view to the right; the hero faces right
			var gh: Ghost = null
			for e in game.get_tree().get_nodes_in_group("enemies"):
				if e is Ghost and (gh == null or e.global_position.x < gh.global_position.x):
					gh = e
			await teleport(Vector2i(12, 16))
			p.facing = 1
			var g0 := gh.global_position
			await _wait(1.0)
			print("GHOST faced: moved %.1f px shy=%s alpha=%.2f" % [gh.global_position.distance_to(g0), gh._shy, gh.sprite.modulate.a])
			await shot("ghost_shy")
			await hold("move_left", 0.08)
			g0 = gh.global_position
			var d0 := g0.distance_to(p.global_position)
			await _wait(1.0)
			print("GHOST back turned: moved %.1f px, distance %.0f -> %.0f shy=%s" % [
				gh.global_position.distance_to(g0), d0, gh.global_position.distance_to(p.global_position), gh._shy])
			await shot("ghost_chase")
			p.invuln_t = 99.0
			# doors
			await door.call(Vector2i(42, 16), "first wall")
			await vshot.call("behind_wall")
			await door.call(Vector2i(48, 16), "back")
			await door.call(Vector2i(99, 16), "right (closet)")
			await vshot.call("closet")
			await door.call(Vector2i(256, 16), "closet back")
			await door.call(Vector2i(87, 16), "left (back to wall)")
			await door.call(Vector2i(93, 16), "middle (on)")
			await teleport(Vector2i(90, 16))
			await vshot.call("door_room")
			await door.call(Vector2i(232, 16), "back door")
			await vshot.call("graveyard_exit")
			# bone turtle: stomp -> pile, stands up again
			await go.call(Game.first_level_of_world(7))
			p = game.player
			var bt: BoneTurtle = null
			for e in game.get_tree().get_nodes_in_group("enemies"):
				if e is BoneTurtle:
					bt = e
					break
			await teleport(Vector2i(int(bt.global_position.x / 16.0) - 6, 16))
			await _wait(0.4)
			bt.active = true
			p.invuln_t = 99.0
			p.global_position = bt.global_position + Vector2(0, -40)
			p.velocity = Vector2(0, 120)
			await _wait(0.3)
			print("BONES stomped: state=%s (PILE=%d) lives=%d score=%d" % [bt.state, BoneTurtle.State.PILE, game.lives, game.score])
			await teleport(Vector2i(int(bt.global_position.x / 16.0) - 5, 16))
			await vshot.call("bones_pile")
			await _wait(4.4)
			print("BONES after 4.4 s: state=%s dead=%s t=%.2f pos=%s" % [bt.state, bt.dead, bt._t, bt.global_position.round()])
			# 7-2 chasm + secret crypt
			await go.call(Game.first_level_of_world(7) + 1)
			p = game.player
			p.invuln_t = 99.0
			await vshot.call("graveyard")
			await door.call(Vector2i(92, 16), "chasm crypt")
			await vshot.call("chasm_other_side")
			await door.call(Vector2i(210, 16), "secret crypt")
			await vshot.call("secret_ledge")
			# castle 7-3 + the phantom king
			await go.call(Game.castle_of_world(7))
			await shot("keep")
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(7), true, true)
			await _wait(Game.CARD_TIME + 0.3)
			p = game.player
			Input.action_press("move_right")
			await _wait(1.6)
			Input.action_release("move_right")
			await _wait(0.3)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			p.invuln_t = 99.0
			var phases := 0
			var up := 0
			var was := false
			for i in 900:
				await physics_frame
				var ph := boss._phase_t > 0.0
				if ph and not was:
					phases += 1
					print("BOSS phase %d at x=%.0f hero x=%.0f" % [phases, boss.global_position.x, p.global_position.x])
					if phases == 1:
						await _wait(0.3)
						await vshot.call("boss_phase")
				was = ph
				for c in game.level.get_children():
					if c is BossFlame and c.velocity.y < -1.0 and c.kind != "ice":
						up += 1
				p.invuln_t = 99.0
			print("BOSS 15 s: phases=%d upward flame frames=%d hp=%d" % [phases, up, boss.hp])
			await vshot.call("boss_after")
			# world map: region 7 (settings.cfg is restored after the run)
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			c.set_value("progress", "level", "7-2")
			c.set_value("progress", "world", 7)
			c.save(GameSettings.CFG_PATH)
			SaveGame.clear()
			game._to_title()
			await _wait(0.5)
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(1.0)
			var m := game.world_map
			print("MAP 7: reach=%d at=%d banner='%s' music=%s" % [m.reach, m.at, m._title.text, game._snd_call("current_music", "")])
			await shot("map_7")
			await _act("move_left")
			await _wait(1.2)
			print("MAP 7 left: at=%d banner='%s'" % [m.at, m._title.text])
			await shot("map_6_7")
		"volcano":
			# v1.5 world 8: salamander spit, magma blob -> rock (stand on it,
			# floats on lava, melts later), meteor fields, 8-2, the final
			# boss with every trick, victory after 8-3, map region 8
			var go := func(lv: int) -> void:
				game.menus.hide_all()
				game._start_game(lv, true)
				await _wait(Game.CARD_TIME + 0.4)
			var vshot := func(label: String) -> void:
				var keep: float = game.player.invuln_t
				game.player.invuln_t = 0.0
				await physics_frame
				game.player.sprite.visible = true
				await shot(label)
				game.player.invuln_t = keep
			var first_of := func(cls) -> Node:
				for e in game.level.get_children():
					if is_instance_of(e, cls) and not e.dead:
						return e
				return null
			var w8 := Game.first_level_of_world(8)
			await go.call(w8)
			var p := game.player
			await vshot.call("slopes_start")
			# salamander at column 20 walks left toward the hero: it spits
			game.change_power(Player.Power.BIG, false)
			await _wait(0.8)
			await teleport(Vector2i(11, 16))
			p.facing = 1
			var sala: Salamander = first_of.call(Salamander)
			var spits := 0
			var flat := true
			for i in 180:
				await physics_frame
				for c in game.level.get_children():
					if c is BossFlame and c.kind == "spit":
						spits = maxi(spits, 1)
						flat = flat and absf(c.velocity.y) < 0.1
				if spits and i % 20 == 0:
					pass
			print("SPIT: salamander at %s flames seen=%d horizontal=%s hero power after=%d (BIG=%d)" % [
				sala.global_position.round() if sala else Vector2.ZERO, spits, flat, p.power, Player.Power.BIG])
			await vshot.call("salamander")
			# magma blob on the hill (37,12): stomp -> rock, stand on it
			await go.call(w8)
			p = game.player
			p.invuln_t = 99.0
			var blob: MagmaBlob = first_of.call(MagmaBlob)
			await teleport(Vector2i(int(blob.global_position.x / 16.0) - 4, int(blob.global_position.y / 16.0) - 1))
			await _wait(0.3)
			blob.active = true
			blob._wait = 99.0
			p.global_position = blob.global_position + Vector2(0, -40)
			p.velocity = Vector2(0, 120)
			await _wait(0.35)
			print("BLOB stomped: state=%s (ROCK=%d) layer=%d score=%d" % [blob.state, MagmaBlob.State.ROCK, blob.collision_layer, game.score])
			p.global_position = blob.global_position + Vector2(0, -12)
			p.velocity = Vector2.ZERO
			await _wait(0.4)
			print("BLOB rock: hero on it: on_floor=%s feet y=%.0f rock top y=%.0f" % [p.is_on_floor(), p.global_position.y, blob.global_position.y - MagmaBlob.ROCK_H])
			await vshot.call("on_rock")
			await _wait(5.0)
			print("BLOB after 5.7 s with the hero on top: state=%s (still a rock)" % blob.state)
			await teleport(Vector2i(int(blob.global_position.x / 16.0) - 5, 16))
			await _wait(0.3)
			print("BLOB hero stepped off: state=%s (HOP=%d) layer=%d" % [blob.state, MagmaBlob.State.HOP, blob.collision_layer])
			# a blob over the lava pit (24..28) rests on the lava; stomped, it floats
			var b2 := MagmaBlob.new()
			b2.position = Vector2(26 * 16 + 8, 12 * 16)
			game.level.add_child(b2)
			b2.active = true
			b2._wait = 99.0
			await teleport(Vector2i(21, 16))
			await _wait(1.0)
			print("LAVA blob: y=%.0f on_lava=%s dead=%s (lava surface y=%d)" % [b2.global_position.y, b2._on_lava, b2.dead, 18 * 16 + 1])
			p.global_position = b2.global_position + Vector2(0, -40)
			p.velocity = Vector2(0, 120)
			await _wait(0.35)
			p.global_position = b2.global_position + Vector2(0, -12)
			p.velocity = Vector2.ZERO
			await _wait(0.5)
			print("LAVA rock: state=%s y=%.0f hero on_floor=%s gstate=%d (PLAYING=%d)" % [b2.state, b2.global_position.y, p.is_on_floor(), game.state, Game.State.PLAYING])
			await vshot.call("rock_on_lava")
			blob.fire_hit()
			print("FIRE on a blob: dead=%s" % blob.dead)
			# meteor field 1 (48..72): meteors with markers
			await teleport(Vector2i(56, 16))
			p.invuln_t = 99.0
			var metcount := 0
			var marks := 0
			var shot_done := false
			for i in 360:
				await physics_frame
				p.invuln_t = 99.0
				for c in game.level.get_children():
					if c is BossFlame and c.kind == "meteor" and not c.has_meta("counted"):
						c.set_meta("counted", true)
						metcount += 1
					if c is BossFlame.MeteorMark:
						marks = maxi(marks, 1)
						if not shot_done and c.t > 0.5:
							shot_done = true
							await vshot.call("meteor_mark")
			print("METEORS in 6 s standing in field 1: %d (markers seen=%d)" % [metcount, marks])
			p.invuln_t = 0.0
			var hurt := false
			for i in 480:
				await physics_frame
				if p.invuln_t > 0.0 or game.state != Game.State.PLAYING:
					hurt = true
					break
			print("METEOR standing still 8 s: hero got hit=%s power=%d" % [hurt, p.power])
			await teleport(Vector2i(40, 16))
			await _wait(3.0)
			var left := 0
			for c in game.level.get_children():
				if c is BossFlame and c.kind == "meteor":
					left += 1
			print("METEOR outside the field after 3 s: %d in the air (expected 0)" % left)
			# 8-2 magma core and its exit on the crater rim
			await go.call(w8 + 1)
			p = game.player
			await vshot.call("core_start")
			p.invuln_t = 99.0
			await teleport(Vector2i(207, 14))
			await hold("move_down", 1.2)
			await _wait(1.2)
			print("CORE exit pipe: area=%s theme=%s music=%s" % [game.area, game.level.data.AREAS[game.area]["theme"], game._snd_call("current_music", "")])
			await vshot.call("core_exit")
			# 8-3 inferno keep, final boss
			await go.call(Game.castle_of_world(8))
			await vshot.call("keep")
			game.menus.hide_all()
			game._start_game(Game.castle_of_world(8), true, true)
			await _wait(Game.CARD_TIME + 0.3)
			p = game.player
			Input.action_press("move_right")
			await _wait(1.6)
			Input.action_release("move_right")
			await _wait(0.3)
			var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
			var kinds := {}
			var up := 0
			var phases := 0
			var was := false
			var bshot := false
			for i in 1500:
				await physics_frame
				p.invuln_t = 99.0
				var ph := boss._phase_t > 0.0
				if ph and not was:
					phases += 1
				was = ph
				for c in game.level.get_children():
					if c is BossFlame:
						kinds[c.kind] = true
						if c.kind in ["flame", "spit"] and c.velocity.y < -1.0:
							up += 1
						if c.kind == "meteor" and not bshot and c._t > 0.4:
							bshot = true
							await vshot.call("boss_meteors")
			if not kinds.has("meteor"):
				boss._meteors(p)
				await _wait(0.5)
				for c in game.level.get_children():
					if c is BossFlame and c.kind == "meteor":
						kinds["meteor"] = true
				await vshot.call("boss_meteors")
			print("BOSS8 hp=%d/%d attacks=%s phases=%d upward flame frames=%d" % [boss.hp, boss.max_hp, kinds.keys(), phases, up])
			# defeat it: victory after the last course
			boss.hp = 1
			boss._inv = 0.0
			boss._phase_t = 0.0
			boss.take_hit()
			await _wait(9.0)
			print("VICTORY: gstate=%d screen=%d (VICTORY=%d) texts=%s" % [game.state, game.menus.screen, Menus.Screen.VICTORY, _button_texts()])
			await shot("victory")
			# world map region 8
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			c.set_value("progress", "level", "8-2")
			c.set_value("progress", "world", 8)
			c.save(GameSettings.CFG_PATH)
			SaveGame.clear()
			game._to_title()
			await _wait(0.5)
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(1.0)
			var m := game.world_map
			print("MAP 8: reach=%d at=%d banner='%s'" % [m.reach, m.at, m._title.text])
			await shot("map_8")
		"turns":
			# v1.6: two players take turns (Mario / Luigi)
			SaveGame.clear()
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			c.set_value("progress", "level", "1-1")
			c.set_value("progress", "world", 1)
			c.save(GameSettings.CFG_PATH)
			await _wait(0.6)
			game._to_title()
			await _frames(3)
			await _press_button("Play")
			print("TURNS players screen: screen=%d (PLAYERS=%d) buttons=%s" % [game.menus.screen,
				Menus.Screen.PLAYERS, _button_texts()])
			await shot("players")
			await _press_button("2 Players - take turns")
			await _wait(1.0)
			print("TURNS map: state=%d players=%d turn=%d map hero=%d label=%s other lives=%d ids differ=%s" % [
				game.state, game.players, game.turn, game.world_map.hero_index, game.world_map.player_label,
				int(game._other.lives), int(game._other.run_id) != game.run_id])
			await shot("map_mario")
			await _act("jump")
			await _wait(0.6)
			await shot("card_mario")
			await _wait(Game.CARD_TIME)
			print("TURNS course: hero=%d hud=%s" % [game.player.hero, game.hud._score_title.text])
			var mario_jump := await _jump_height()
			game.add_score(1234)
			var cp := game.player.global_position + Vector2(64, 0)
			game.checkpoint_pos = cp
			game.player_died(false)
			await _wait(4.0)
			print("TURNS after Mario's death: state=%d (MAP=%d) turn=%d map hero=%d score=%d lives=%d | waiting Mario: score=%d lives=%d in_course=%s cp=%s" % [
				game.state, Game.State.MAP, game.turn, game.world_map.hero_index, game.score, game.lives,
				int(game._other.score), int(game._other.lives), game._other._in_course, game._other.checkpoint_pos])
			await shot("map_luigi")
			await _act("jump")
			await _wait(0.6)
			await shot("card_luigi")
			await _wait(Game.CARD_TIME)
			print("TURNS Luigi course: hero=%d frames=%s hud=%s" % [game.player.hero,
				game.player.sprite.sprite_frames.resource_path.get_file(), game.hud._score_title.text])
			var luigi_jump := await _jump_height()
			print("TURNS jump height: Mario %.1f px, Luigi %.1f px (+%.0f%%)" % [mario_jump, luigi_jump,
				(luigi_jump / mario_jump - 1.0) * 100.0])
			await shot("luigi_play")
			game.add_score(500)
			var s := SaveGame.load_run()
			print("TURNS save: players=%s turn=%s score=%s other=%s" % [s.players, s.turn, s.score, s.other])
			game.player_died(false)
			await _wait(3.6)
			print("TURNS Mario resumes: state=%d turn=%d course=%s spawn=%s (cp %s) score=%d" % [game.state, game.turn,
				Game.LEVELS[game.level_index].ID, game.player.global_position.round() if game.player else null,
				cp.round(), game.score])
			await _wait(Game.CARD_TIME)
			# continue a saved 2-player run
			game._to_title()
			await _frames(3)
			print("TURNS title: ", _hints())
			await shot("title_2p")
			await _press_button(_button_texts()[0])
			await _wait(0.8)
			print("TURNS continued: players=%d turn=%d score=%d other score=%d other in_course=%s" % [game.players,
				game.turn, game.score, int(game._other.score), game._other._in_course])
			# Mario runs out of lives: Luigi plays on alone
			await _act("jump")
			await _wait(Game.CARD_TIME + 0.4)
			game.lives = 1
			game.player_died(false)
			await _wait(3.2)
			await shot("mario_out")
			await _wait(3.0)
			print("TURNS Mario out: state=%d turn=%d mario lives=%d" % [game.state, game.turn, int(game._other.lives)])
			await _wait(Game.CARD_TIME)
			game.player_died(false)
			await _wait(3.6)
			print("TURNS Luigi alone: turn=%d state=%d lives=%d" % [game.turn, game.state, game.lives])
			await _wait(Game.CARD_TIME)
			game.lives = 1
			game.player_died(false)
			await _wait(6.0)
			print("TURNS game over: screen=%d text=%s" % [game.menus.screen, _hints()])
			await shot("gameover_2p")
			var names := HallOfFame.load_list().map(func(e): return "%s %s" % [e.name, e.score])
			print("TURNS hof: ", names)
			game.menus._name_edits[1].text = "lu"
			await _press_button("Enter names")
			print("TURNS hof named: ", HallOfFame.load_list().map(func(e): return "%s %s" % [e.name, e.score]))
			await shot("gameover_named")
		"coop":
			# v1.7: Mario + Luigi at once
			SaveGame.clear()
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			c.set_value("progress", "level", "1-1")
			c.set_value("progress", "world", 1)
			c.save(GameSettings.CFG_PATH)
			await _wait(0.6)
			game._to_title()
			await _frames(3)
			await _press_button("Play")
			print("COOP players: ", _button_texts())
			await _press_button("2 Players - together")
			await shot("join_empty")
			await _key(KEY_SPACE)
			await _key(KEY_UP)
			print("COOP join: screen=%d (JOIN=%d) split=%s buttons=%s" % [game.menus.screen, Menus.Screen.JOIN,
				CoopInput.split, _button_texts()])
			print("COOP keys: p1_jump=%s p2_jump=%s p1_left=%s p2_left=%s p2_run=%s" % [_keys("p1_jump"),
				_keys("p2_jump"), _keys("p1_left"), _keys("p2_left"), _keys("p2_run")])
			await shot("join_ready")
			await _press_button("Start!")
			await _wait(1.0)
			print("COOP map: state=%d players=%d partner=%s label=%s" % [game.state, game.players,
				game.world_map.partner.visible, game.world_map.player_label])
			await shot("map")
			await _act("jump")
			await _wait(0.6)
			await shot("card")
			await _wait(Game.CARD_TIME)
			var m: Player = game.heroes[0]
			var l: Player = game.heroes[1]
			print("COOP course: mario=%s luigi=%s luigi frames=%s hud=%s lives=%s" % [m.global_position.round(),
				l.global_position.round(), l.sprite.sprite_frames.resource_path.get_file(), game.hud._score_title.text,
				game.hud._lives.text])
			await hold("p1_right", 0.8)
			print("COOP only Mario moved: mario x=%.0f luigi x=%.0f" % [m.global_position.x, l.global_position.x])
			await hold("p2_right", 0.5)
			print("COOP Luigi moved: luigi x=%.0f" % l.global_position.x)
			await shot("both")
			print("COOP target near Luigi is Luigi: ", game.target_for(l.global_position) == l)
			# head bounce: Luigi drops onto Mario
			l.global_position = m.global_position + Vector2(0, -40)
			l.velocity = Vector2.ZERO
			var pw := m.power
			var bounced := false
			var lowest := l.global_position.y
			for i in 40:
				await physics_frame
				lowest = maxf(lowest, l.global_position.y)
				if l.velocity.y < -100.0 and l.global_position.y < m.global_position.y - 8.0:
					bounced = true
			print("COOP head bounce: bounced=%s lowest feet y=%.0f (Mario head at %.0f) mario power %d->%d" % [bounced,
				lowest, m.global_position.y - 14.0, pw, m.power])
			# Luigi falls far behind: bubble, floats to Mario, pops
			await _wait(0.5)
			await teleport_hero(m, Vector2i(int(m.global_position.x / 16) + 14, 16))
			await _wait(0.8)
			print("COOP behind (dragged along by the screen edge): luigi x=%.0f mode=%d" % [l.global_position.x, l.mode])
			# stuck behind a wall he goes into a bubble (forced here)
			l.global_position.x = game.camera.global_position.x - 200.0
			l.start_bubble()
			await _wait(0.4)
			print("COOP stuck behind: luigi mode=%d (BUBBLE=%d)" % [l.mode, Player.Mode.BUBBLE])
			print("COOP dbg: mario=%s mode=%d cam=%s luigi=%s state=%d" % [m.global_position.round(), m.mode,
				game.camera.global_position.round(), l.global_position.round(), game.state])
			await _wait(0.3)
			await shot("bubble")
			await _wait(3.0)
			print("COOP popped: luigi mode=%d dist to mario=%.0f" % [l.mode, l.global_position.distance_to(m.global_position)])
			# both in bubbles: the course restarts (no life lost)
			var lives_b: Array = game.co_lives.duplicate()
			m.start_bubble()
			l.start_bubble()
			await _wait(0.3)
			print("COOP all bubbled: state=%d (DYING=%d)" % [game.state, Game.State.DYING])
			await _wait(1.6 + Game.CARD_TIME + 0.3)
			m = game.heroes[0]
			l = game.heroes[1]
			print("COOP restarted: state=%d lives %s -> %s modes %d %d" % [game.state, lives_b, game.co_lives, m.mode, l.mode])
			# Luigi loses a life, Mario plays on
			var lv: int = game.co_lives[1]
			l.invuln_t = 0.0
			l.hurt()
			await _wait(0.2)
			print("COOP luigi died: state=%d (PLAYING=%d) luigi lives %d->%d mode=%d" % [game.state, Game.State.PLAYING,
				lv, game.co_lives[1], l.mode])
			await _wait(1.8)
			print("COOP luigi back in a bubble: mode=%d" % l.mode)
			await _wait(3.0)
			print("COOP luigi popped again: mode=%d" % l.mode)
			# the partner comes along through a pipe
			var zone: WarpZone = null
			for n in game.level.get_children():
				if n is WarpZone and n.kind == "down" and n.warp.get("area", "") == "bonus":
					zone = n
					break
			m.global_position = zone.global_position
			m.velocity = Vector2.ZERO
			l.global_position = zone.global_position + Vector2(-40, 0)
			l.velocity = Vector2.ZERO
			await _frames(4)
			print("COOP before pipe: luigi mode=%d" % l.mode)
			print("COOP at pipe: mario=%s zone=%s" % [m.global_position.round(), zone.global_position.round()])
			Input.action_press("p1_down")
			for i in 14:
				await _wait(0.2)
				print("  t=%.1f state=%d mario=%s mode=%d luigi=%s mode=%d area=%s" % [i * 0.2, game.state,
					m.global_position.round(), m.mode, l.global_position.round(), l.mode, game.area])
				if i == 1:
					Input.action_release("p1_down")
			print("COOP after pipe: state=%d carried=%s" % [game.state, game._carried])
			print("COOP pipe: area=%s mario=%s luigi=%s luigi mode=%d visible=%.1f" % [game.area,
				m.global_position.round(), l.global_position.round(), l.mode, l.modulate.a])
			await shot("bonus_room")
			# Luigi out of lives: out, then a 1UP brings him back
			game.co_lives[1] = 1
			l.invuln_t = 0.0
			l.hurt()
			await _wait(2.2)
			print("COOP luigi out: heroes[1]=%s banner=%s hud lives=%s" % [game.heroes[1], game.hud._banner.text,
				game.hud._lives.text])
			game.one_up(m.global_position)
			await _wait(0.2)
			var l2: Player = game.heroes[1]
			print("COOP revived: luigi=%s mode=%d lives=%s" % [l2 != null, l2.mode if l2 else -1, game.co_lives])
			await _wait(3.5)
			print("COOP revived popped: mode=%d" % l2.mode)
			# team death: both lose a life, the course restarts
			var before: Array = game.co_lives.duplicate()
			game.player_died(false, m)
			await _wait(0.1)
			print("COOP mario died, luigi plays: state=%d" % game.state)
			game.player_died(false, l2)
			await _wait(4.5)
			print("COOP team death: lives %s -> %s state=%d (INTRO=%d) heroes=%d" % [before, game.co_lives,
				game.state, Game.State.INTRO, game.all_heroes().size()])
			await _wait(Game.CARD_TIME)
			# the flag: both clear the course
			m = game.heroes[0]
			var flag: Vector2i = Game.LEVELS[game.level_index].FLAG
			await teleport_hero(m, Vector2i(flag.x - 1, flag.y - 7))
			await hold("p1_right", 1.2)
			await _wait(1.0)
			await shot("flag")
			print("COOP flag: state=%d (CLEAR=%d) luigi visible=%.1f" % [game.state, Game.State.CLEAR,
				game.heroes[1].modulate.a if game.heroes[1] else -1.0])
			await _wait(8.0)
			print("COOP after clear: state=%d (MAP=%d) reach=%d" % [game.state, Game.State.MAP, game.world_map.reach])
			var sv := SaveGame.load_run()
			print("COOP save: players=%s co=%s score=%s" % [sv.players, sv.co, sv.score])
			game._to_title()
			await _frames(3)
			print("COOP title: ", _hints())
			await _press_button(_button_texts()[0])
			print("COOP continue asks to join: screen=%d (JOIN=%d)" % [game.menus.screen, Menus.Screen.JOIN])
			await _key(KEY_SPACE)
			await _key(KEY_UP)
			await _press_button("Start!")
			await _wait(1.0)
			print("COOP continued: players=%d co_lives=%s score=%d" % [game.players, game.co_lives, game.score])
			# game over: one team entry
			game.co_lives = [1, 1]
			await _act("jump")
			await _wait(Game.CARD_TIME + 0.4)
			game.add_score(800000)
			game.player_died(false, game.heroes[1])
			await _wait(2.0)
			game.player_died(false, game.heroes[0])
			await _wait(7.0)
			print("COOP game over: screen=%d hof=%s" % [game.menus.screen,
				HallOfFame.load_list().map(func(e): return "%s %s run %s" % [e.name, e.score, e.get("run", 0)])])
			await shot("gameover")
		"nethost":
			# v1.8 Wi-Fi: this window hosts (Mario); run "netguest" in a second one
			SaveGame.clear()
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			c.set_value("progress", "level", "1-1")
			c.set_value("progress", "world", 1)
			c.save(GameSettings.CFG_PATH)
			await _wait(0.6)
			game._to_title()
			await _frames(3)
			game.menus._start_hosting()
			print("NETHOST waiting: screen=%d (NETHOST=%d) text=%s" % [game.menus.screen, Menus.Screen.NETHOST, _hints()])
			await shot("waiting")
			for i in 200:
				if game.net_host and game.net_host.is_connected_guest():
					break
				await _wait(0.1)
			await _wait(1.0)
			print("NETHOST guest joined: state=%d (MAP=%d) players=%d" % [game.state, Game.State.MAP, game.players])
			await shot("map")
			await _wait(2.0)
			for k in 10:
				await _act("jump")
				await _wait(0.5)
				if game.state != Game.State.MAP:
					break
			await _wait(Game.CARD_TIME + 0.4)
			var m: Player = game.heroes[0]
			var l: Player = game.heroes[1]
			var lx := l.global_position.x
			await hold("p1_right", 0.6)
			print("NETHOST in course: mario x=%.0f luigi x=%.0f" % [m.global_position.x, l.global_position.x])
			for i in 60:
				await _wait(0.1)
			print("NETHOST luigi moved by the guest: %.0f -> %.0f, top y %.0f" % [lx, l.global_position.x, l.global_position.y])
			await shot("level")
			for i in 80:
				if game.is_paused():
					break
				await _wait(0.1)
			print("NETHOST paused by the guest: ", game.is_paused())
			for i in 80:
				if not game.is_paused():
					break
				await _wait(0.1)
			print("NETHOST resumed by the guest: ", not game.is_paused())
			await _wait(2.0)
			game._to_title()
			print("NETHOST stopped hosting: ", game.net_host == null)
			await _wait(2.0)
		"netguest":
			# v1.8 Wi-Fi: this window joins the "nethost" window as Luigi
			await _wait(2.5)
			game.menus.hide_all()
			game.menus._show_screen(Menus.Screen.NETJOIN)
			await _wait(3.0)
			print("NETGUEST found: ", game.menus._net_disc.found if game.menus._net_disc else {})
			await _wait(0.6)
			print("NETGUEST join screen: ", _button_texts())
			await shot("join")
			game.menus._connect_to("127.0.0.1")
			for i in 100:
				if game.net_client and game.net_client._scene_kind == "map":
					break
				await _wait(0.1)
			await _wait(1.0)
			print("NETGUEST map: state=%d (NET=%d) scene=%s menu=%d" % [game.state, Game.State.NET,
				game.net_client._scene_kind, game.menus.screen])
			await shot("map")
			for i in 100:
				if game.net_client._scene_kind == "level":
					break
				await _wait(0.1)
			await _wait(0.6)
			await shot("card")
			await _wait(Game.CARD_TIME + 0.8)
			print("NETGUEST level: puppets=%d strings=%d ping=%d ms theme=%s hud=%s" % [game.net_client._puppets.size(),
				game.net_client._strings.size(), game.net_client.link.ping_ms(), game.backdrop.theme,
				game.hud._score_title.text])
			await shot("level")
			Input.action_press("move_right")
			await _wait(1.2)
			Input.action_press("jump")
			await _wait(0.4)
			Input.action_release("jump")
			await _wait(0.6)
			Input.action_release("move_right")
			await _wait(0.4)
			await shot("level_moved")
			await _wait(2.5)
			game._toggle_pause()
			await _wait(1.0)
			print("NETGUEST pause menu: screen=%d (NETPAUSE=%d) host paused=%s" % [game.menus.screen,
				Menus.Screen.NETPAUSE, game.net_client._host_paused])
			await shot("pause")
			await _press_button("Resume")
			await _wait(1.0)
			print("NETGUEST resumed: host paused=%s" % game.net_client._host_paused)
			for i in 150:
				if game.state != Game.State.NET:
					break
				await _wait(0.1)
			await _wait(0.5)
			print("NETGUEST after host left: state=%d screen=%d (INFO=%d) text=%s" % [game.state, game.menus.screen,
				Menus.Screen.INFO, _hints()])
			await shot("left")
		"netshow":
			# v1.8: host cycles through the worlds; "netwatch" (2nd window)
			# shows them — compare the screenshots pairwise
			await _wait(0.6)
			game._to_title()
			await _frames(3)
			game.menus._start_hosting()
			for i in 200:
				if game.net_host and game.net_host.is_connected_guest():
					break
				await _wait(0.1)
			await _wait(1.5)
			for step in [[3, true], [4, false], [13, false], [16, false], [19, false], [22, false], [24, true]]:
				game.menus.hide_all()
				game._start_game(step[0], true, step[1])
				await _wait(Game.CARD_TIME + 1.3)
				if not step[1]:
					await hold("move_right", 0.8)
				else:
					await _wait(0.8)
				await shot("host_%s" % Game.LEVELS[step[0]].ID)
				print("NETSHOW %s nodes sent ~%d" % [Game.LEVELS[step[0]].ID, game.net_host._nids.size()])
				await _wait(1.5)
			game._to_title()
			await _wait(2.0)
		"netwatch":
			await _wait(2.5)
			game.menus.hide_all()
			game.menus._connect_to("127.0.0.1")
			var last := -1
			for i in 600:
				await _wait(0.1)
				if game.net_client == null:
					break
				if game.net_client._scene_kind == "level" and game.net_client._scene_id != last:
					last = game.net_client._scene_id
					await _wait(Game.CARD_TIME + 1.3 + 0.8)
					var id := str(game.hud._world.text).strip_edges()
					await shot("guest_%s" % id)
					print("NETWATCH %s puppets=%d theme=%s" % [id, game.net_client._puppets.size(), game.backdrop.theme])
		"starthop":
			# v1.5.1: entering a course with A (also "jump") must not make the
			# hero hop at the start
			SaveGame.clear()
			await _wait(0.5)
			game.menus.hide_all()
			game.menus.play_pressed.emit(-1)
			await _wait(1.2)
			await _pad(0)                      # A on the map: enter the course
			var y0 := 0.0
			var ymin := 99999.0
			for i in 200:
				await physics_frame
				if game.player:
					if y0 == 0.0:
						y0 = game.player.global_position.y
					ymin = minf(ymin, game.player.global_position.y)
			print("STARTHOP: state=%d spawn y=%.0f highest y=%.0f -> hop %.0f px (expected 0)" % [game.state, y0, ymin, y0 - ymin])
		"bossdiff":
			# v1.5.1: the boss fight has its own difficulty (Settings > Boss fight)
			for pair in [[2, 0], [2, 1], [0, 3], [1, 2]]:
				var cf := GameSettings.load_all()
				cf.difficulty = pair[0]
				cf.boss_difficulty = pair[1]
				GameSettings.save(cf)
				game.menus.hide_all()
				game._start_game(Game.castle_of_world(1), true, true)
				await _wait(Game.CARD_TIME + 0.3)
				var boss: Boss = game.get_tree().get_nodes_in_group("boss")[0]
				print("BOSSDIFF game=%s boss setting=%s -> boss difficulty=%d stun=%.1f flowers=%s enemy speed x%.2f" % [
					GameSettings.DIFF_NAMES[pair[0]], GameSettings.BOSS_DIFF_NAMES[pair[1]], boss.difficulty,
					Boss.STUN[boss.difficulty], Boss.FLOWERS[boss.difficulty], game.enemy_speed_mul()])
	await _wait(0.3)
	_restore_user_files()
	quit()
