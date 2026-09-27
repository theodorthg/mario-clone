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
	# the game's _ready (which creates the splash) runs only once the tree
	# is live — skip the splash from here, not from _init()
	await process_frame
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
		"selects":
			# level select + world select must fit all worlds on the 270-px canvas
			await _wait(0.5)
			game.menus._show_screen(Menus.Screen.LEVELS)
			await _frames(3)
			await shot("levels")
			game.menus._show_screen(Menus.Screen.WORLDS)
			await _frames(3)
			await shot("worlds")
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
	await _wait(0.3)
	quit()
