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
		"pause":
			await start_play()
			game._toggle_pause()
			await shot("paused")
			game._toggle_pause()
			await _wait(0.3)
			state("resumed")
	await _wait(0.3)
	quit()
