class_name GameSettings

## Gameplay settings — persisted in user://settings.cfg section [s], shared by
## the start-screen and pause Settings menu. (Sound volumes are a separate
## section owned by sound_manager.gd.)

const CFG_PATH := "user://settings.cfg"

const DEF := {
	"lives": 3,             # LIVES_MIN..LIVES_MAX (total, active one included)
	"difficulty": 1,        # 0 easy, 1 normal, 2 hard — enemy speed + time
	"time_limit": 1,        # index into TIME_NAMES
	"coin_points": 200,     # points per coin
	"coins_per_life": 100,  # 0 = off
	"start_big": false,     # start every life as big hero (easier)
	"touch_buttons": 0,     # index into TOUCH_NAMES: on-screen move/jump/run buttons
}

const LIVES_MIN := 1
const LIVES_MAX := 9
const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const TIME_NAMES := ["Off", "Level", "Short"]
const COIN_POINTS := [0, 100, 200, 500]
const COINS_PER_LIFE := [0, 50, 100, 200]
## Auto = shown on touch devices unless a gamepad / D-pad is connected
## (e.g. Anbernic RG552: touchscreen AND D-pad -> hidden). Pause + mute at
## the top are never affected.
const TOUCH_NAMES := ["Auto", "On", "Off"]

static func touch_buttons_visible(mode: int, touch_device: bool, joypads: int) -> bool:
	match mode:
		1:
			return true
		2:
			return false
	return touch_device and joypads == 0

static func load_all() -> Dictionary:
	var out := DEF.duplicate()
	var c := ConfigFile.new()
	if c.load(CFG_PATH) == OK:
		for k in DEF:
			out[k] = c.get_value("s", k, DEF[k])
	return out

static func save(data: Dictionary) -> void:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	for k in data:
		c.set_value("s", k, data[k])
	c.save(CFG_PATH)

## Highest world the player has reached (for the world select on Play).
static func reached_world() -> int:
	var c := ConfigFile.new()
	if c.load(CFG_PATH) != OK:
		return 1
	return int(c.get_value("progress", "world", 1))

static func set_reached_world(w: int) -> void:
	if w <= reached_world():
		return
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	c.set_value("progress", "world", w)
	c.save(CFG_PATH)

static func enemy_speed_mul(difficulty: int) -> float:
	return [0.8, 1.0, 1.25][clampi(difficulty, 0, 2)]

## Level timer start value (0 = no timer).
static func level_time(cfg: Dictionary, level_time_value: int) -> int:
	match int(cfg.time_limit):
		0:
			return 0
		2:
			return int(level_time_value * 0.75)
		_:
			var extra := 100 if int(cfg.difficulty) == 0 else 0
			return level_time_value + extra
