extends SceneTree

## Writes the complete [input] map into project.godot — the learn-path
## CLAUDE.md forbids hand-editing that block (the Object(InputEventKey,...)
## literal syntax is too error-prone). Re-run after changing a binding:
##   godot --headless --path . --script res://tools/setup_input.gd
##
## Conventions (global CLAUDE.md #17): every joypad event uses device=-1;
## letters get BOTH a physical_keycode and a keycode event.

const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_BACK := 4
const JOY_START := 6
const DPAD_UP := 11
const DPAD_DOWN := 12
const DPAD_LEFT := 13
const DPAD_RIGHT := 14

func _key(code: int) -> Array:
	var a := InputEventKey.new()
	a.physical_keycode = code
	var b := InputEventKey.new()
	b.keycode = code
	return [a, b]

func _joy(btn: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = btn
	return e

func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e

func _init() -> void:
	var map := {
		"ui_accept": [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _joy(JOY_A)],
		"ui_cancel": [_key(KEY_ESCAPE), _joy(JOY_B)],
		"ui_left": [_key(KEY_LEFT), _joy(DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"ui_right": [_key(KEY_RIGHT), _joy(DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"ui_up": [_key(KEY_UP), _joy(DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"ui_down": [_key(KEY_DOWN), _joy(DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _joy(DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _joy(DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _joy(DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"jump": [_key(KEY_SPACE), _key(KEY_K), _key(KEY_Z), _key(KEY_W), _key(KEY_UP), _joy(JOY_A), _joy(JOY_B)],
		"run": [_key(KEY_SHIFT), _key(KEY_J), _key(KEY_X), _key(KEY_CTRL), _joy(JOY_X), _joy(JOY_Y)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_START)],
		"mute": [_key(KEY_M), _joy(JOY_BACK)],
		"screenshot": [_key(KEY_F12)],
	}
	for action in map:
		var events: Array[InputEvent] = []
		for spec in map[action]:
			if spec is Array:
				for e in spec:
					events.append(e)
			else:
				events.append(spec)
		var dz := 0.35 if action.begins_with("move_") else 0.5
		ProjectSettings.set_setting("input/" + action, {"deadzone": dz, "events": events})
	var err := ProjectSettings.save()
	print("setup_input: saved project.godot (err=%d), %d actions" % [err, map.size()])
	quit()
