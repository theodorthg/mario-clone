class_name CoopInput

## Co-op controls (v1.7): who plays with what. On the join screen each
## player presses A / jump on his own device; that decides
## - luigi_pad: Luigi's gamepad (device id), Mario gets every OTHER device —
##   matters on the RG552, whose built-in D-pad and face buttons come as
##   separate device ids (see global CLAUDE.md #17),
## - luigi_keys: Luigi on the keyboard (Mario on a pad or touch),
## - split: both on one keyboard — Mario A/D/S + W/Space/Z jump +
##   Shift/J/X/Ctrl run, Luigi arrows + Up/K/Num0 jump + L/Num. run.
## build() then copies the normal actions (incl. the player's own key
## rebinds, ControlsConfig) into "p1_*" / "p2_*" actions with the devices
## split up; Player.act points at them. The normal actions stay as they are
## (menus, world map, pause and mute work for everyone).

const BASE := {"left": "move_left", "right": "move_right", "down": "move_down", "up": "ui_up",
	"jump": "jump", "run": "run"}
## Luigi's half of a shared keyboard
const P2_KEYS := {"left": [KEY_LEFT], "right": [KEY_RIGHT], "down": [KEY_DOWN], "up": [KEY_UP],
	"jump": [KEY_UP, KEY_K, KEY_KP_0], "run": [KEY_L, KEY_KP_PERIOD]}
## keys that make a player join on the join screen
const JOIN_P1_KEYS := [KEY_SPACE, KEY_W, KEY_Z, KEY_ENTER]
const JOIN_P2_KEYS := [KEY_UP, KEY_K, KEY_KP_0]

static var luigi_pad := -1
static var luigi_keys := false
static var split := false

static func reset() -> void:
	luigi_pad = -1
	luigi_keys = false
	split = false

static func action_names(hero: int) -> Dictionary:
	var d := {}
	for k in BASE:
		d[k] = "p%d_%s" % [hero + 1, k]
	return d

static func _p2_codes() -> Array:
	var all := []
	for k in P2_KEYS:
		all.append_array(P2_KEYS[k])
	return all

static func _code(e: InputEventKey) -> int:
	return e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode

## (Re)builds p1_* / p2_* from the current InputMap and connected pads.
static func build() -> void:
	var p2_codes := _p2_codes()
	for k in BASE:
		var names := [action_names(0)[k], action_names(1)[k]]
		for n in names:
			if InputMap.has_action(n):
				InputMap.erase_action(n)
			InputMap.add_action(n, InputMap.action_get_deadzone(BASE[k]) if InputMap.has_action(BASE[k]) else 0.5)
		if not InputMap.has_action(BASE[k]):
			continue
		for e in InputMap.action_get_events(BASE[k]):
			if e is InputEventKey:
				var to := 0
				if split:
					to = 1 if _code(e) in p2_codes else 0
				elif luigi_keys:
					to = 1
				if not split or to == 0 or _code(e) in P2_KEYS[k]:
					InputMap.action_add_event(names[to], e)
			elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
				for dev in Input.get_connected_joypads():
					var c: InputEvent = e.duplicate()
					c.device = dev
					InputMap.action_add_event(names[1 if dev == luigi_pad else 0], c)
			else:
				InputMap.action_add_event(names[0], e)
		if split:
			# Luigi's own keys that are no default binding (L, Num0, Num.)
			for code in P2_KEYS[k]:
				var have := InputMap.action_get_events(names[1]).any(
					func(ev): return ev is InputEventKey and _code(ev) == code)
				if not have:
					var ke := InputEventKey.new()
					ke.physical_keycode = code
					InputMap.action_add_event(names[1], ke)

## Short "who plays with what" line for menus / help.
static func describe() -> String:
	var mario := "keyboard (A D S, W / Space jump, Shift run)" if split else (
		"gamepad" if luigi_keys else "keyboard / touch / other pads")
	var luigi := "keyboard (arrows, Up / K jump, L run)" if split else (
		"keyboard" if luigi_keys else "gamepad %d" % luigi_pad)
	return "Mario: %s\nLuigi: %s" % [mario, luigi]
