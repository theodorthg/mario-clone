class_name SaveGame

## The saved run (v1.2, player wish: "quit on the map and carry on later,
## nothing may get lost"): score, coins, lives, power, dragon and the map
## spot, in user://savegame.cfg section [run]. game.gd writes it on every
## map step, course start, quit and when the app closes / goes to the
## background; the title then offers "Continue". A run that ends (game over
## / all courses cleared) removes it. Level select runs never write it.

const PATH := "user://savegame.cfg"
const KEYS := ["id", "name", "score", "coins", "lives", "power", "dino", "at", "best"]
## v1.6 (2 players take turns), optional so older saves still load:
## players (1/2), turn (0 Mario / 1 Luigi = whose turn), reach (furthest
## course of this player, ID) and other (the waiting player: a Dictionary
## with the KEYS + reach, resume, cp).
const OPT_KEYS := {"players": 1, "turn": 0, "reach": "", "other": {}}

static func exists() -> bool:
	return not load_run().is_empty()

## {} when there is no saved run (or the file is unusable).
static func load_run() -> Dictionary:
	var c := ConfigFile.new()
	if c.load(PATH) != OK or not c.has_section("run"):
		return {}
	var out := {}
	for k in KEYS:
		if not c.has_section_key("run", k):
			return {}
		out[k] = c.get_value("run", k)
	for k in OPT_KEYS:
		out[k] = c.get_value("run", k, OPT_KEYS[k])
	if int(out.lives) <= 0:
		return {}
	return out

static func store(run: Dictionary) -> void:
	var c := ConfigFile.new()
	for k in KEYS:
		c.set_value("run", k, run[k])
	for k in OPT_KEYS:
		if run.has(k):
			c.set_value("run", k, run[k])
	c.save(PATH)

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## A new run id: ties a run to its one high score entry.
static func new_id() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) * 10 + randi() % 10
