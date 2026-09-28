class_name HallOfFame

## Top-10 score board, persisted in user://hall_of_fame.cfg. Each entry also
## records the world reached ("1-1") — shown next to the score, ranking is by
## score alone (classic arcade convention).
## v1.2: a run keeps exactly ONE entry (key "run" = SaveGame id) that grows
## with its score — it is written while playing (autosave), so quitting,
## closing the app or starting over never loses a high score, and a
## continued run updates its entry instead of adding a second one.

const PATH := "user://hall_of_fame.cfg"
const MAX := 10

static func load_list() -> Array:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return []
	var raw = c.get_value("hof", "entries", [])
	if not raw is Array:
		return []
	# older versions could store a 0-point "YOU"
	return raw.filter(func(e): return e is Dictionary and int(e.get("score", 0)) > 0)

## High Scores "Clear list" (title only, after a confirmation).
static func clear() -> void:
	_save_list([])

static func _save_list(list: Array) -> void:
	var c := ConfigFile.new()
	c.set_value("hof", "entries", list)
	c.save(PATH)

static func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var list := load_list()
	if list.size() < MAX:
		return true
	return score > int(list[list.size() - 1].get("score", 0))

## Rank (0-based) of the entry of run `run`, -1 if it has none.
static func run_rank(run: int, list = null) -> int:
	if run == 0:
		return -1
	var l: Array = load_list() if list == null else list
	for i in l.size():
		if int(l[i].get("run", 0)) == run:
			return i
	return -1

## Creates or updates the entry of run `run`; returns its rank, or -1 when
## the score doesn't make the list.
static func record_run(run: int, who: String, score: int, world: String) -> int:
	var list := load_list()
	var i := run_rank(run, list)
	if i >= 0:
		var e: Dictionary = list[i]
		e["name"] = who
		e["score"] = maxi(int(e.get("score", 0)), score)
		e["world"] = world
	elif score > 0 and (list.size() < MAX or score > int(list[list.size() - 1].get("score", 0))):
		list.append({"name": who, "score": score, "world": world, "run": run})
	else:
		return -1
	list.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if list.size() > MAX:
		list = list.slice(0, MAX)
	_save_list(list)
	return run_rank(run, list)
