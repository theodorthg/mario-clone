extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Parse-checks every script (a parse error makes load() fail) and sanity-
## checks project config, level data and the scoring tables.

## Every script of the game (project root + levels/), found automatically —
## a hand-kept list silently went stale. A script "parses" only if it also
## COMPILES: in Godot 4 load() returns the resource even when compilation
## failed (incl. a broken dependency), so check can_instantiate() (v1.1:
## a type-inference error in world_map.gd broke game.gd while this test
## still printed "all checks passed" and exited 0).
func _all_scripts() -> Array[String]:
	var out: Array[String] = []
	for dir in ["res://", "res://levels/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "_selftest.gd":
				out.append(dir + f)
	return out

func _init() -> void:
	var fails := 0
	var scripts := _all_scripts()
	fails += _expect(scripts.size() > 40, "found %d scripts" % scripts.size())
	for path in scripts:
		var s: Script = load(path)
		fails += _expect(s != null and s.can_instantiate(), "compiles: %s" % path)

	var canvas := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	fails += _expect(is_equal_approx(canvas.x / canvas.y, 16.0 / 9.0), "design canvas is 16:9 (%dx%d)" % [canvas.x, canvas.y])
	fails += _expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "stretch mode = canvas_items")
	for action in ["move_left", "move_right", "move_down", "jump", "run", "pause", "mute", "screenshot", "ui_accept", "ui_cancel"]:
		fails += _expect(InputMap.has_action(action), "input action present: %s" % action)
	for action in InputMap.get_actions():
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				if e.device != -1:
					fails += _expect(false, "joypad binding of %s uses device -1" % action)

	# level data (every level in Game.LEVELS)
	for lv: Script in Game.LEVELS:
		var grid: Array = lv.GRID
		fails += _expect(grid.size() == 20, "%s has 20 rows" % lv.ID)
		var w: int = grid[0].length()
		var same := true
		for row in grid:
			same = same and row.length() == w
		fails += _expect(same, "%s rows all have width %d" % [lv.ID, w])
		if lv.FLAG.x >= 0:
			fails += _expect(grid[lv.FLAG.y][lv.FLAG.x] == "X", "%s flag pole stands on a hard block" % lv.ID)
		else:
			var has_boss := false
			for row in grid:
				has_boss = has_boss or "Z" in row
			var ar: Vector2i = lv.get_script_constant_map().get("ARENA", Vector2i(-1, -1))
			fails += _expect(has_boss and ar.y - ar.x + 1 >= 38, "%s castle has a boss + 38-wide arena" % lv.ID)
		fails += _expect(grid[lv.START.y + 1][lv.START.x] == "#", "%s start cell is on ground" % lv.ID)
		for wp in lv.WARPS:
			var e: Vector2i = wp["entry"]
			if wp.get("kind", "") == "door":
				# a door stands on the floor: 'H' cell with solid ground below
				fails += _expect(grid[e.y][e.x] == "H" and grid[e.y + 1][e.x] in ["#", "w", "X", "B"], "%s door %s is an H cell on the floor" % [lv.ID, e])
				var a: Vector2i = wp["arrive"]
				fails += _expect(wp.get("arrive_kind", "") != "door" or grid[a.y][a.x] == "H", "%s door %s leads to a door" % [lv.ID, e])
			else:
				fails += _expect(grid[e.y][e.x] in ["W", ">"], "%s warp entry %s is a W/> cell" % [lv.ID, e])
		for m in lv.get_script_constant_map().get("METEORS", []):
			fails += _expect(m.x >= 0 and m.x < m.y and m.y < grid[0].length(), "%s meteor field %s inside the level" % [lv.ID, m])
		for a in lv.AREAS.values():
			fails += _expect(int(a["to"]) - int(a["from"]) + 1 >= 38, "%s area wide enough for 2.2:1 screens" % lv.ID)
			fails += _expect(Backdrop.THEMES.has(a["theme"]), "%s theme %s exists" % [lv.ID, a["theme"]])
		for wp in lv.WARPS:
			fails += _expect(lv.AREAS.has(wp["area"]), "%s warp target area %s exists" % [lv.ID, wp["area"]])

	# worlds + touch button rule
	for w in range(1, Game.WORLD_NAMES.size() + 1):
		var i := Game.first_level_of_world(w)
		fails += _expect(Game.world_of(i) == w and String(Game.LEVELS[i].ID).ends_with("-1"), "world %d starts at %s" % [w, Game.LEVELS[i].ID])
	fails += _expect(not GameSettings.touch_buttons_visible(0, true, 1), "touch auto: hidden with gamepad (RG552)")
	fails += _expect(GameSettings.touch_buttons_visible(0, true, 0), "touch auto: shown on touch-only phone")
	fails += _expect(not GameSettings.touch_buttons_visible(0, false, 0), "touch auto: hidden on desktop")
	fails += _expect(GameSettings.touch_buttons_visible(1, false, 1), "touch on: always shown")

	# scoring tables
	fails += _expect(Flagpole.points_for_height(200) == 5000, "top of pole = 5000")
	fails += _expect(Flagpole.points_for_height(0) == 100, "bottom of pole = 100")
	fails += _expect(GameSettings.boss_difficulty({"difficulty": 2, "boss_difficulty": 0}) == 2, "boss difficulty 'As game' follows Difficulty")
	fails += _expect(GameSettings.boss_difficulty({"difficulty": 2, "boss_difficulty": 1}) == 0, "boss difficulty Easy despite a Hard game")
	fails += _expect(GameSettings.boss_difficulty({"difficulty": 0}) == 0, "boss difficulty missing in old settings -> as game")
	fails += _expect(GameSettings.level_time({"time_limit": 0, "difficulty": 1}, 400) == 0, "timer off -> 0")
	# v1.6 two players: Luigi has every frame set, the same animations, jumps a bit higher
	for pw in [Player.Power.SMALL, Player.Power.BIG, Player.Power.FIRE]:
		var mf: SpriteFrames = Player.frames_for(0, pw)
		var lf: SpriteFrames = Player.frames_for(1, pw)
		fails += _expect(lf != null and lf != mf and Array(lf.get_animation_names()) == Array(mf.get_animation_names()),
			"Luigi frames for power %d match Mario's animations" % pw)
	fails += _expect(Player.frames_for(1, Player.Power.SMALL, true) == Player.LUIGI_SMALL_FIRE, "Luigi small-fire flicker frames")
	fails += _expect(float(Player.JUMP_MUL[1]) > 1.0 and float(Player.JUMP_MUL[1]) < 1.06, "Luigi jumps a little higher")
	# v1.7 co-op: one keyboard for two — Luigi gets the arrows / K / L
	CoopInput.reset()
	CoopInput.split = true
	CoopInput.build()
	var codes := func(action: String) -> Array:
		return InputMap.action_get_events(action).filter(func(e): return e is InputEventKey).map(
			func(e): return e.physical_keycode if e.physical_keycode else e.keycode)
	fails += _expect(KEY_UP in codes.call("p2_jump") and not (KEY_UP in codes.call("p1_jump")), "co-op split: Up jumps for Luigi only")
	fails += _expect(KEY_SPACE in codes.call("p1_jump") and not (KEY_SPACE in codes.call("p2_jump")), "co-op split: Space jumps for Mario only")
	fails += _expect(KEY_A in codes.call("p1_left") and KEY_LEFT in codes.call("p2_left") and not (KEY_LEFT in codes.call("p1_left")), "co-op split: A / Left")
	fails += _expect(KEY_L in codes.call("p2_run") and not (KEY_K in codes.call("p1_jump")), "co-op split: L runs for Luigi, K no longer Mario's")
	CoopInput.reset()
	CoopInput.luigi_pad = 5
	CoopInput.build()
	fails += _expect(codes.call("p2_jump").is_empty() and KEY_UP in codes.call("p1_jump"), "co-op: Luigi on a pad -> the whole keyboard is Mario's")
	CoopInput.reset()
	fails += _expect(Game._slot_from_save(Game._slot_to_save({"score": 7, "coins": 3, "lives": 2, "power": 1,
		"has_dino": true, "level_index": 4, "_run_reach": 5, "_run_best": 4, "run_id": 99, "run_name": "AL",
		"checkpoint_pos": Vector2(40, 272), "_in_course": true})) == {"run_id": 99, "run_name": "AL", "score": 7,
		"coins": 3, "lives": 2, "power": 1, "has_dino": true, "level_index": 4, "_run_best": 4, "_run_reach": 5,
		"_in_course": true, "checkpoint_pos": Vector2(40, 272)}, "2-player slot survives the save game")
	fails += _expect(GameSettings.level_time({"time_limit": 1, "difficulty": 1}, 400) == 400, "timer normal -> level value")

	if fails == 0:
		print("_selftest: all checks passed")
	else:
		printerr("_selftest: %d check(s) FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _expect(cond: bool, label: String) -> int:
	if cond:
		print("  ok  ", label)
		return 0
	printerr("  FAIL ", label)
	return 1
