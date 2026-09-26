class_name Menus
extends Control

## Start / Settings (+Sound sub-page) / Pause / Game-Over / High Scores /
## Help screens, each built on demand into one shared glass-backed panel.
## Ported from centipede's menus.gd (global CLAUDE.md #7/#8/#15/#17/#18/#19:
## frosted glass, framed panel, cancel-button tagging, focus wrap, deferred
## default focus, help paging via ui_left/right + wheel + page dots, Sound
## list in a ScrollContainer, LineEdit ui_accept intercept, auto-commit of a
## qualifying score as "YOU") — re-scaled for the 480x270 landscape canvas.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal settings_changed(cfg: Dictionary)

enum Screen { NONE, START, SETTINGS, SOUND, PAUSE, GAMEOVER, HELP, HIGHSCORES, VICTORY }

const PANEL_W := 250.0
const BTN_H := 22.0
const GAP := 3
const FONT := 16

## Illustrated How-to-Play pages rendered from assets/help_src/*.svg (see
## render.sh) — desktop set shows keyboard + gamepad, touch set the on-screen
## buttons; both share the goal/items/dragon pages.
const HELP_DIR := "res://assets/graphics/help/"
const HELP_DESKTOP := [
	{"file": "controls", "h": "Controls"},
	{"file": "items", "h": "Blocks & Items"},
	{"file": "dragon", "h": "The Dragon"},
	{"file": "goal", "h": "Goal & Points"},
]
const HELP_TOUCH := [
	{"file": "touch", "h": "Touch Controls"},
	{"file": "items", "h": "Blocks & Items"},
	{"file": "dragon", "h": "The Dragon"},
	{"file": "goal", "h": "Goal & Points"},
]
const HELP_FALLBACK := {
	"controls": "Move: Arrows / A D / D-pad\nJump: Space / Z / K / W / Up  (A)\nRun, fireball, tongue: Shift / X / J  (X/Y)\nDuck / enter pipe: Down\nPause: Esc / P (Start)   Mute: M (Select)\nScreenshot: F12",
	"touch": "Left / right buttons: move\nA: jump   B: run, fireball, tongue\nHold B while moving to run.\nII: pause   Speaker: mute",
	"items": "Hit ? blocks from below.\nMushroom: grow big.  Fire flower: throw fireballs.\nStar: invincible for a while.  Green mushroom: extra life.\nBig heroes break bricks.",
	"dragon": "An egg hides in one ? block.\nJump onto the dragon to ride it.\nRun button: tongue eats enemies.\nDown + jump: hop off.  A hit throws you off.",
	"goal": "Stomp enemies from above.\nCoins: points, 100 coins = extra life.\nPipes marked by coins lead to bonus rooms.\nGrab the flag pole as high as you can!",
}

var screen: int = Screen.NONE
var _return_screen: int = Screen.START
var _touch := false
var _cfg := {}
var _help_page := 0
var _panel: PanelContainer
var _vbox: VBoxContainer
var _help_back_btn: Button
var _name_edit: LineEdit
var _glass: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := UiStyle.make_glass_backdrop()
	add_child(g.backbuffer)
	add_child(g.glass)
	_glass = g.glass
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	add_child(_panel)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", GAP)
	_panel.add_child(_vbox)
	_cfg = GameSettings.load_all()
	resized.connect(_recenter_panel)
	hide_all()

func set_touch_context(t: bool) -> void:
	_touch = t

func is_open() -> bool:
	return screen != Screen.NONE

func hide_all() -> void:
	screen = Screen.NONE
	visible = false
	_glass.visible = false
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.stop_preview()

func _show_screen(s: int) -> void:
	screen = s
	visible = true
	_glass.visible = true
	_rebuild()

func _rebuild() -> void:
	_name_edit = null
	_help_back_btn = null
	# remove_child() BEFORE queue_free() — see centipede CLAUDE.md / global #18:
	# otherwise the deferred focus scan below still finds the old controls.
	for c in _vbox.get_children():
		_vbox.remove_child(c)
		c.queue_free()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	match screen:
		Screen.START:
			_build_start()
		Screen.SETTINGS:
			_build_settings()
		Screen.SOUND:
			_build_sound()
		Screen.PAUSE:
			_build_pause()
		Screen.GAMEOVER:
			_build_gameover(false)
		Screen.VICTORY:
			_build_gameover(true)
		Screen.HELP:
			_build_help()
		Screen.HIGHSCORES:
			_build_highscores()
	_panel.reset_size()
	_recenter_panel.call_deferred()
	if screen == Screen.HELP and _help_back_btn:
		_help_back_btn.grab_focus.call_deferred()
	else:
		_focus_first.call_deferred()
	if screen != Screen.SOUND:
		_wrap_focus_vertically.call_deferred()

func _recenter_panel() -> void:
	var vp := get_viewport_rect().size
	var sz: Vector2 = _panel.get_combined_minimum_size()
	sz.x = maxf(sz.x, _panel.custom_minimum_size.x)
	_panel.size = sz
	_panel.position = ((vp - sz) * 0.5).round()

func _focusable_controls() -> Array[Control]:
	var list: Array[Control] = []
	for n in _vbox.find_children("*", "", true, false):
		if n is Control and n.visible and n.focus_mode != Control.FOCUS_NONE \
				and not (n is BaseButton and n.disabled):
			list.append(n)
	return list

func _focus_first() -> void:
	var list := _focusable_controls()
	if not list.is_empty():
		list[0].grab_focus()

func _wrap_focus_vertically() -> void:
	var list := _focusable_controls()
	if list.size() <= 2:
		return
	var first := list[0]
	var last := list[-1]
	first.focus_neighbor_top = first.get_path_to(last)
	last.focus_neighbor_bottom = last.get_path_to(first)

func show_start() -> void:
	_show_screen(Screen.START)

func show_pause() -> void:
	_show_screen(Screen.PAUSE)

func show_gameover(score: int, world: String, victory := false) -> void:
	set_meta("go_score", score)
	set_meta("go_world", world)
	set_meta("go_committed", false)
	set_meta("go_highlight", -1)
	_show_screen(Screen.VICTORY if victory else Screen.GAMEOVER)

func show_highscores(from: int) -> void:
	_return_screen = from
	_show_screen(Screen.HIGHSCORES)

# ---------------------------------------------------------------- widgets --
func _heading(text: String, size := 24) -> Label:
	var l := UiStyle.heading(text, size)
	UiStyle.impact_label(l)
	return l

func _button(text: String, cb: Callable, is_cancel := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		var snd := get_node_or_null("/root/Snd")
		if snd:
			snd.play("bump")
		cb.call())
	UiStyle.style_button(b, FONT)
	if is_cancel:
		b.set_meta("is_cancel", true)
	return b

func _hint(text: String, size := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	l.add_theme_constant_override("line_spacing", 3)
	return l

func _row(label_text: String, label_w := 110.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, BTN_H)
	row.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(label_w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", UiStyle.INK)
	l.add_theme_constant_override("outline_size", 2)
	row.add_child(l)
	return row

func _stepper(row: HBoxContainer, get_val: Callable, set_val: Callable, fmt: Callable) -> void:
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(70, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_l.add_theme_font_size_override("font_size", FONT)
	val_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var refresh := func(): val_l.text = fmt.call(get_val.call())
	var minus := _button("-", func(): set_val.call(-1); refresh.call())
	minus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var plus := _button("+", func(): set_val.call(1); refresh.call())
	plus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	refresh.call()
	row.add_child(minus)
	row.add_child(val_l)
	row.add_child(plus)

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _hbox(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	for c in children:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(c)
	return h

# ------------------------------------------------------------------ start --
func _build_start() -> void:
	_vbox.add_child(_heading("MARIO CLONE", 32))
	var sub := _hint("A pixel platform adventure")
	sub.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(sub)
	_vbox.add_child(_spacer(2))
	_vbox.add_child(_button("Play", func():
		hide_all()
		play_pressed.emit()))
	_vbox.add_child(_button("Settings", func():
		_return_screen = Screen.START
		_show_screen(Screen.SETTINGS)))
	_vbox.add_child(_button("High Scores", func(): show_highscores(Screen.START)))
	_vbox.add_child(_button("How to Play", func():
		_return_screen = Screen.START
		_help_page = 0
		_show_screen(Screen.HELP)))
	if not OS.has_feature("web"):
		_vbox.add_child(_button("Exit", func(): get_tree().quit()))

# ------------------------------------------------------------------ pause --
func _build_pause() -> void:
	_vbox.add_child(_heading("PAUSED"))
	_vbox.add_child(_button("Resume", func():
		hide_all()
		resume_pressed.emit()))
	_vbox.add_child(_button("Settings", func():
		_return_screen = Screen.PAUSE
		_show_screen(Screen.SETTINGS)))
	_vbox.add_child(_button("High Scores", func(): show_highscores(Screen.PAUSE)))
	_vbox.add_child(_button("How to Play", func():
		_return_screen = Screen.PAUSE
		_help_page = 0
		_show_screen(Screen.HELP)))
	_vbox.add_child(_button("Main Menu", func():
		hide_all()
		quit_to_menu_pressed.emit()))
	if not OS.has_feature("web"):
		_vbox.add_child(_button("Exit", func(): get_tree().quit()))

# --------------------------------------------------------------- gameover --
func _build_gameover(victory: bool) -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	var score: int = get_meta("go_score", 0)
	var world: String = get_meta("go_world", "1-1")
	var committed: bool = get_meta("go_committed", false)
	_vbox.add_child(_heading("YOU WIN!" if victory else "GAME OVER"))
	var score_l := _hint("SCORE %06d  -  WORLD %s" % [score, world], 16)
	_vbox.add_child(score_l)
	if HallOfFame.qualifies(score) and not committed:
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Your name"
		_name_edit.max_length = 8
		_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_edit.custom_minimum_size = Vector2(120, BTN_H)
		_name_edit.add_theme_font_size_override("font_size", FONT)
		_name_edit.text_submitted.connect(func(_t: String): _commit_score())
		var entry := HBoxContainer.new()
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.add_theme_constant_override("separation", 4)
		entry.add_child(_name_edit)
		entry.add_child(_button("Enter", func(): _commit_score()))
		_vbox.add_child(entry)
	var grid := _hof_grid()
	_vbox.add_child(grid)
	_render_hof(grid, HallOfFame.load_list(), get_meta("go_highlight", -1))
	var btns := [
		_button("Play Again", func():
			_maybe_auto_commit()
			hide_all()
			restart_pressed.emit()),
		_button("Menu", func():
			_maybe_auto_commit()
			hide_all()
			quit_to_menu_pressed.emit()),
	]
	if not OS.has_feature("web"):
		btns.append(_button("Exit", func():
			_maybe_auto_commit()
			get_tree().quit()))
	_vbox.add_child(_hbox(btns))

func _commit_score() -> void:
	var who := (_name_edit.text if _name_edit else "").strip_edges()
	if who == "":
		who = "YOU"
	who = who.to_upper()
	var score: int = get_meta("go_score", 0)
	var list := HallOfFame.insert(who, score, get_meta("go_world", "1-1"))
	set_meta("go_committed", true)
	var idx := -1
	for i in list.size():
		if list[i].name == who and int(list[i].score) == score:
			idx = i
			break
	set_meta("go_highlight", idx)
	_rebuild()

func _maybe_auto_commit() -> void:
	if _name_edit != null and not get_meta("go_committed", false):
		_commit_score()

func _hof_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 1)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return g

func _cell(text: String, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	return l

func _render_hof(grid: GridContainer, list: Array, highlight: int) -> void:
	if list.is_empty():
		grid.columns = 1
		var h := _hint("- no entries yet -")
		h.custom_minimum_size = Vector2(200, 0)
		grid.add_child(h)
		return
	for i in list.size():
		var e = list[i]
		var col := UiStyle.ACCENT if i == highlight else Color.WHITE
		grid.add_child(_cell("%d." % (i + 1), col, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(_cell(str(e.name).to_upper(), col))
		grid.add_child(_cell(str(e.get("world", "1-1")), Color(col.r, col.g, col.b, 0.7)))
		grid.add_child(_cell("%06d" % int(e.score), col, HORIZONTAL_ALIGNMENT_RIGHT))

# ------------------------------------------------------------- highscores --
func _build_highscores() -> void:
	_vbox.add_child(_heading("HIGH SCORES"))
	var grid := _hof_grid()
	_vbox.add_child(grid)
	_render_hof(grid, HallOfFame.load_list(), -1)
	_vbox.add_child(_spacer(2))
	_vbox.add_child(_button("Back", func(): _show_screen(_return_screen), true))

# --------------------------------------------------------------- settings --
func _build_settings() -> void:
	_panel.custom_minimum_size = Vector2(300, 0)
	_vbox.add_child(_heading("SETTINGS"))
	var lives_row := _row("Lives")
	_stepper(lives_row, func(): return _cfg.lives,
		func(d): _set_cfg("lives", clampi(_cfg.lives + d, GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)),
		func(v): return str(v))
	_vbox.add_child(lives_row)
	var diff_row := _row("Difficulty")
	_stepper(diff_row, func(): return _cfg.difficulty,
		func(d): _set_cfg("difficulty", posmod(_cfg.difficulty + d, GameSettings.DIFF_NAMES.size())),
		func(v): return GameSettings.DIFF_NAMES[v])
	_vbox.add_child(diff_row)
	var time_row := _row("Timer")
	_stepper(time_row, func(): return _cfg.time_limit,
		func(d): _set_cfg("time_limit", posmod(_cfg.time_limit + d, GameSettings.TIME_NAMES.size())),
		func(v): return GameSettings.TIME_NAMES[v])
	_vbox.add_child(time_row)
	var coin_row := _row("Coin points")
	_stepper(coin_row, func(): return GameSettings.COIN_POINTS.find(int(_cfg.coin_points)),
		func(d):
			var i := posmod(GameSettings.COIN_POINTS.find(int(_cfg.coin_points)) + d, GameSettings.COIN_POINTS.size())
			_set_cfg("coin_points", GameSettings.COIN_POINTS[i]),
		func(v): return str(GameSettings.COIN_POINTS[maxi(v, 0)]))
	_vbox.add_child(coin_row)
	var life_row := _row("1-UP coins")
	_stepper(life_row, func(): return GameSettings.COINS_PER_LIFE.find(int(_cfg.coins_per_life)),
		func(d):
			var i := posmod(GameSettings.COINS_PER_LIFE.find(int(_cfg.coins_per_life)) + d, GameSettings.COINS_PER_LIFE.size())
			_set_cfg("coins_per_life", GameSettings.COINS_PER_LIFE[i]),
		func(v):
			var n: int = GameSettings.COINS_PER_LIFE[maxi(v, 0)]
			return "Off" if n == 0 else str(n))
	_vbox.add_child(life_row)
	var big_row := _row("Start big")
	_stepper(big_row, func(): return _cfg.start_big,
		func(_d): _set_cfg("start_big", not bool(_cfg.start_big)),
		func(v): return "Yes" if v else "No")
	_vbox.add_child(big_row)
	_vbox.add_child(_hbox([
		_button("Sound", func(): _show_screen(Screen.SOUND)),
		_button("Back", func(): _show_screen(_return_screen), true),
	]))

func _set_cfg(key: String, value) -> void:
	_cfg[key] = value
	GameSettings.save(_cfg)
	settings_changed.emit(_cfg)

# ------------------------------------------------------------------ sound --
func _build_sound() -> void:
	_panel.custom_minimum_size = Vector2(340, 0)
	_vbox.add_child(_heading("SOUND"))
	var snd := get_node_or_null("/root/Snd")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if snd == null:
		list.add_child(_hint("Sound manager unavailable."))
	else:
		var mute_row := _row("Mute all", 170)
		var mute_btn: Button
		mute_btn = _button("Muted" if snd.is_muted() else "On", func():
			var m: bool = snd.toggle_mute()
			mute_btn.text = "Muted" if m else "On")
		mute_btn.custom_minimum_size = Vector2(90, BTN_H)
		mute_row.add_child(mute_btn)
		list.add_child(mute_row)
		for key in snd.ORDER:
			list.add_child(_sound_row(snd, key))
	_vbox.add_child(scroll)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.SETTINGS), true))

func _sound_row(snd: Node, key: String) -> HBoxContainer:
	var row := _row(snd.SOUNDS[key][0], 170)
	(row.get_child(0) as Label).add_theme_font_size_override("font_size", 8)
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(40, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_l.add_theme_font_size_override("font_size", 8)
	val_l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var refresh := func(): val_l.text = "%d%%" % snd.get_volume(key)
	var change := func(d: int):
		snd.set_volume(key, snd.get_volume(key) + d)
		refresh.call()
		snd.preview_exclusive(key)
	var minus := _button("-", func(): change.call(-10))
	minus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	var plus := _button("+", func(): change.call(10))
	plus.custom_minimum_size = Vector2(BTN_H, BTN_H)
	refresh.call()
	row.add_child(minus)
	row.add_child(val_l)
	row.add_child(plus)
	return row

# ------------------------------------------------------------------- help --
func _help_pages() -> Array:
	return HELP_TOUCH if _touch else HELP_DESKTOP

func _build_help() -> void:
	_panel.custom_minimum_size = Vector2(360, 0)
	var pages := _help_pages()
	var p: Dictionary = pages[_help_page]
	_vbox.add_child(_heading(p.h, 16))
	var path: String = HELP_DIR + str(p.file) + ".png"
	if ResourceLoader.exists(path):
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(340, 170)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.texture = load(path)
		_vbox.add_child(img)
	else:
		var t := _hint(HELP_FALLBACK.get(p.file, ""), 8)
		t.custom_minimum_size = Vector2(340, 110)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_vbox.add_child(t)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 6)
	var prev_btn := _button("<", func(): _turn_help(-1))
	prev_btn.custom_minimum_size = Vector2(BTN_H + 8, BTN_H)
	nav.add_child(prev_btn)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 5)
	for i in pages.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(5, 5)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = UiStyle.ACCENT if i == _help_page else Color(1, 1, 1, 0.25)
		dots.add_child(d)
	nav.add_child(dots)
	var next_btn := _button(">", func(): _turn_help(1))
	next_btn.custom_minimum_size = Vector2(BTN_H + 8, BTN_H)
	nav.add_child(next_btn)
	_help_back_btn = _button("Back", func(): _show_screen(_return_screen), true)
	_help_back_btn.custom_minimum_size = Vector2(80, BTN_H)
	nav.add_child(_help_back_btn)
	_vbox.add_child(nav)

func _turn_help(d: int) -> void:
	_help_page = wrapi(_help_page + d, 0, _help_pages().size())
	_rebuild()

# ------------------------------------------------------------------ input --
func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if _name_edit != null and is_instance_valid(_name_edit) and _name_edit.has_focus() \
			and event.is_action_pressed("ui_accept"):
		_commit_score()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		for b in _vbox.find_children("*", "Button", true, false):
			if b.visible and b.get_meta("is_cancel", false):
				b.pressed.emit()
				get_viewport().set_input_as_handled()
				return
		if screen == Screen.PAUSE:
			hide_all()
			resume_pressed.emit()
			get_viewport().set_input_as_handled()
		return
	if screen != Screen.HELP:
		return
	if event.is_action_pressed("ui_right"):
		_turn_help(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_turn_help(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn_help(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn_help(-1)
			get_viewport().set_input_as_handled()
