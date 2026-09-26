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

func _run() -> void:
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
			await _frames(12)
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
			for i in 120:
				if game.state != Game.State.PLAYING:
					break
				await _frames(1)
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
				print("t+%.1f state=%d time=%d flag=%s" % [i * 0.5, game.state, game.time_left, game.level.castle_flag.position])
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
			game.level_index = 3
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
			game.level_index = 3
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
		"worldselect":
			var c := ConfigFile.new()
			c.load(GameSettings.CFG_PATH)
			var saved = c.get_value("progress", "world", 1)
			c.set_value("progress", "world", 3)
			c.save(GameSettings.CFG_PATH)
			await _wait(1.0)
			game.menus._show_screen(Menus.Screen.SETTINGS)
			await shot("settings")
			game.menus._show_screen(Menus.Screen.WORLDS)
			await shot("worlds")
			c.set_value("progress", "world", saved)
			c.save(GameSettings.CFG_PATH)
			game.menus.hide_all()
			game._start_game(Game.first_level_of_world(3))
			await _wait(Game.CARD_TIME + 0.4)
			state("started world 3")
			print("level id: ", Game.LEVELS[game.level_index].ID)
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
			await teleport(Vector2i(125, 16))
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
		"pause":
			await start_play()
			game._toggle_pause()
			await shot("paused")
			game._toggle_pause()
			await _wait(0.3)
			state("resumed")
	await _wait(0.3)
	quit()
