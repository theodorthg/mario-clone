class_name ControlsConfig

## Player-rebindable controls, persisted in user://settings.cfg section
## [controls] as "<action>.key" (physical keycode) and "<action>.pad" (joypad
## button index). The defaults stay in project.godot [input] (written by
## tools/setup_input.gd); apply() rebuilds the InputMap from them and lays the
## overrides on top:
##  * key: the chosen key is ADDED to the action (the default keys stay) and
##    taken away from every other rebindable action — no double bindings.
##  * pad: the chosen button REPLACES the action's joypad buttons and is taken
##    away from the others (binding "jump" to B on a pad where B was run just
##    swaps them). D-pad / stick movement is never touched.

const CFG_PATH := "user://settings.cfg"
## [action, label, pad-rebindable]
const ACTIONS := [
	["move_left", "Left", false],
	["move_right", "Right", false],
	["move_down", "Down / Pipe", false],
	["jump", "Jump", true],
	["run", "Run / Fire", true],
	["pause", "Pause", true],
	["mute", "Mute", true],
]
const PAD_NAMES := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Select", 5: "Home", 6: "Start",
	7: "L3", 8: "R3", 9: "L1", 10: "R1", 11: "Up", 12: "Down", 13: "Left", 14: "Right"}

static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(CFG_PATH)
	return c

static func _names() -> Array:
	return ACTIONS.map(func(a): return a[0])

static func apply() -> void:
	InputMap.load_from_project_settings()
	var c := _cfg()
	for a in _names():
		var k := int(c.get_value("controls", a + ".key", 0))
		if k != 0:
			_bind_key(a, k)
	for a in _names():
		var b := int(c.get_value("controls", a + ".pad", -1))
		if b >= 0:
			_bind_pad(a, b)

static func _bind_key(action: String, key: int) -> void:
	for a in _names():
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e.physical_keycode == key or e.keycode == key):
				InputMap.action_erase_event(a, e)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

static func _bind_pad(action: String, button: int) -> void:
	for a in _names():
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton and (a == action or e.button_index == button):
				InputMap.action_erase_event(a, e)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)

## Store an override; an equal override on another action is dropped (the
## key/button moves over), then the InputMap is rebuilt.
static func set_binding(action: String, kind: String, value: int) -> void:
	var c := _cfg()
	for a in _names():
		if a != action and int(c.get_value("controls", a + "." + kind, -99)) == value:
			c.erase_section_key("controls", a + "." + kind)
	c.set_value("controls", action + "." + kind, value)
	c.save(CFG_PATH)
	apply()

static func reset() -> void:
	var c := _cfg()
	if c.has_section("controls"):
		c.erase_section("controls")
		c.save(CFG_PATH)
	apply()

static func key_label(action: String) -> String:
	var k := int(_cfg().get_value("controls", action + ".key", 0))
	if k == 0:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				k = e.physical_keycode if e.physical_keycode != 0 else e.keycode
				break
	return OS.get_keycode_string(k) if k != 0 else "-"

static func pad_label(action: String) -> String:
	var names := []
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			names.append(PAD_NAMES.get(e.button_index, str(e.button_index)))
	return " ".join(names) if not names.is_empty() else "-"
