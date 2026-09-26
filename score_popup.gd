class_name ScorePopup
extends Label

## Floating "+200" / "1UP" that rises and fades.

var _t := 0.0

func setup(text_value: String, pos: Vector2) -> void:
	text = text_value
	position = (pos + Vector2(-20, -10)).round()
	size = Vector2(40, 10)

func _ready() -> void:
	z_index = 20
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", Color("#fff6c0") if text != "1UP" else Color("#9af07e"))
	add_theme_color_override("font_outline_color", Color("#1a1018"))
	add_theme_constant_override("outline_size", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	position.y -= 30.0 * delta
	modulate.a = clampf(1.6 - _t * 1.6, 0.0, 1.0)
	if _t > 1.0:
		queue_free()
