class_name TouchControls
extends Node2D

## On-screen buttons for touch devices (CanvasLayer 11): left / down / right
## bottom-left (down = duck, enter pipes, with A: hop off the dragon), B (run
## / fireball / tongue) and A (jump) bottom-right. Built on
## TouchScreenButton, which handles multi-touch natively and presses the
## InputMap actions directly — so player.gd needs no touch-specific code.
## Landscape platformer exception to global CLAUDE.md #4/#5 (swipe + top
## band): a side-scroller needs held directions and two thumbs, the buttons
## overlay the lower corners of the playfield instead.

const SIZE := 40.0
const MARGIN := 10.0

var _left: TouchScreenButton
var _down: TouchScreenButton
var _right: TouchScreenButton
var _a: TouchScreenButton
var _b: TouchScreenButton

func _ready() -> void:
	_left = _make("left", "move_left", true)
	_down = _make("down", "move_down", true)
	_right = _make("right", "move_right", true)
	_b = _make("b", "run", false)
	_a = _make("a", "jump", false)
	relayout()

func _make(tex: String, action: String, passby: bool) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = load("res://assets/ui/touch_%s.png" % tex)
	b.texture_pressed = load("res://assets/ui/touch_%s_pressed.png" % tex)
	b.action = action
	b.passby_press = passby
	var sh := CircleShape2D.new()
	sh.radius = SIZE * 0.62
	b.shape = sh
	b.shape_centered = true
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	add_child(b)
	return b

func relayout() -> void:
	if _left == null:
		return
	var vs := get_viewport_rect().size
	var y := vs.y - MARGIN - SIZE
	_left.position = Vector2(MARGIN, y)
	_down.position = Vector2(MARGIN + SIZE + 4.0, y + 6.0)
	_right.position = Vector2(MARGIN + (SIZE + 4.0) * 2.0, y)
	_a.position = Vector2(vs.x - MARGIN - SIZE, y - 14.0)
	_b.position = Vector2(vs.x - MARGIN - SIZE * 2.0 - 6.0, y + 4.0)
