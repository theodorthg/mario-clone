extends Node

## Autoload "Shot" — in-game screenshot key (F12, action "screenshot"). First
## reference implementation of the learn-path CLAUDE.md standard #20.
##
## - PROCESS_MODE_ALWAYS: works on pause/settings/help screens too.
## - Captures the frame FIRST, then shows the white flash (else the flash
##   itself would end up in the picture).
## - Linux/Windows: <user data dir>/screenshots/ (real folder, e.g.
##   ~/.local/share/godot/app_userdata/mario-clone/screenshots/)
##   Web: additionally a real browser download via JavaScriptBridge
##   Android: user://screenshots/ (fetch with `adb pull`)

const DIR := "user://screenshots"

var _layer: CanvasLayer
var _flash: ColorRect
var _toast: Label
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_flash)
	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -24
	_toast.offset_bottom = -10
	_toast.offset_left = -120
	_toast.offset_right = 120
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color("1a1018"))
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.modulate.a = 0.0
	_layer.add_child(_toast)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		take()
		get_viewport().set_input_as_handled()

func take() -> String:
	var img := get_viewport().get_texture().get_image()
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var fname := "screenshot_%s.png" % stamp
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/%s" % [DIR, fname]
	img.save_png(path)
	var where := ProjectSettings.globalize_path(path)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), fname, "image/png")
		where = "Downloads"
	elif OS.has_feature("android"):
		where = "app storage (adb pull)"
	_feedback("Screenshot saved: " + (fname if OS.has_feature("web") else where.get_file()))
	print("screenshot: ", ProjectSettings.globalize_path(path))
	return path

func _feedback(msg: String) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_toast.text = msg
	_flash.color.a = 0.7
	_toast.modulate.a = 1.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_flash, "color:a", 0.0, 0.15)
	_tween.tween_property(_toast, "modulate:a", 0.0, 0.4).set_delay(1.4)
