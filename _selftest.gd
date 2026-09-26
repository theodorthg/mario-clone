extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Parse-checks every script (a parse error makes load() fail) and sanity-
## checks project config, level data and the scoring tables.

const SCRIPTS := [
	"res://ui_style.gd", "res://game_settings.gd", "res://hall_of_fame.gd",
	"res://sound_manager.gd", "res://screenshot_capture.gd", "res://mute_icon.gd",
	"res://decor_index.gd", "res://level.gd", "res://player.gd", "res://block.gd",
	"res://coin.gd", "res://block_coin.gd", "res://sparkle.gd", "res://brick_shard.gd",
	"res://score_popup.gd", "res://shroom.gd", "res://powerup.gd", "res://fireball.gd",
	"res://dino.gd", "res://egg.gd", "res://flagpole.gd", "res://warp_zone.gd",
	"res://checkpoint.gd", "res://backdrop.gd", "res://hud.gd", "res://menus.gd",
	"res://touch_controls.gd", "res://chomper.gd", "res://turtle.gd", "res://controls_config.gd", "res://game.gd",
]

func _init() -> void:
	var fails := 0
	for path in SCRIPTS:
		fails += _expect(load(path) != null, "parses: %s" % path)

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
		fails += _expect(grid[lv.FLAG.y][lv.FLAG.x] == "X", "%s flag pole stands on a hard block" % lv.ID)
		fails += _expect(grid[lv.START.y + 1][lv.START.x] == "#", "%s start cell is on ground" % lv.ID)
		for wp in lv.WARPS:
			var e: Vector2i = wp["entry"]
			fails += _expect(grid[e.y][e.x] in ["W", ">"], "%s warp entry %s is a W/> cell" % [lv.ID, e])
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
	fails += _expect(GameSettings.level_time({"time_limit": 0, "difficulty": 1}, 400) == 0, "timer off -> 0")
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
