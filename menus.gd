class_name Menus
extends Control

## Start / Settings (+Sound sub-page) / Pause / Game-Over / High Scores /
## Help screens, each built on demand into one shared glass-backed panel.
## Ported from centipede's menus.gd (global CLAUDE.md #7/#8/#15/#17/#18/#19:
## frosted glass, framed panel, cancel-button tagging, focus wrap, deferred
## default focus, help paging via ui_left/right + wheel + page dots, Sound
## list in a ScrollContainer, LineEdit ui_accept intercept, auto-commit of a
## qualifying score as "YOU") — re-scaled for the 480x270 landscape canvas.

signal play_pressed(level_index: int)
signal continue_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal settings_changed(cfg: Dictionary)

enum Screen { NONE, START, SETTINGS, SOUND, PAUSE, GAMEOVER, HELP, HIGHSCORES, VICTORY, CONTROLS, LEVELS,
	QUIT, NEWGAME, CLEARHOF, PLAYERS, JOIN, NETMENU, NETHOST, NETJOIN, NETWAIT, NETPAUSE, INFO,
	ONLINEMENU, ONLINEJOIN }

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
	{"file": "touch", "h": "Touch Controls"},
	{"file": "map", "h": "World Map"},
	{"file": "items", "h": "Blocks & Items"},
	{"file": "dragon", "h": "The Dragon"},
	{"file": "goal", "h": "Goal & Points"},
	{"file": "worlds", "h": "Turtles & Worlds"},
	{"file": "sky", "h": "Sky World"},
	{"file": "sea", "h": "Sea World"},
	{"file": "water", "h": "Pools & Currents"},
	{"file": "ghost", "h": "Ghost House"},
	{"file": "volcano", "h": "Volcano"},
	{"file": "castles", "h": "Castles & Secrets"},
	{"file": "players", "h": "Two Players"},
	{"file": "wifi", "h": "Wi-Fi"},
	{"file": "online", "h": "Online"},
]
const HELP_TOUCH := [
	{"file": "touch", "h": "Touch Controls"},
	{"file": "map", "h": "World Map"},
	{"file": "items", "h": "Blocks & Items"},
	{"file": "dragon", "h": "The Dragon"},
	{"file": "goal", "h": "Goal & Points"},
	{"file": "worlds", "h": "Turtles & Worlds"},
	{"file": "sky", "h": "Sky World"},
	{"file": "sea", "h": "Sea World"},
	{"file": "water", "h": "Pools & Currents"},
	{"file": "ghost", "h": "Ghost House"},
	{"file": "volcano", "h": "Volcano"},
	{"file": "castles", "h": "Castles & Secrets"},
	{"file": "players", "h": "Two Players"},
	{"file": "wifi", "h": "Wi-Fi"},
	{"file": "online", "h": "Online"},
]
const HELP_FALLBACK := {
	"controls": "Move: Arrows / A D / D-pad\nJump: Space / Z / K / W / Up  (A)\nRun, fireball, tongue: Shift / X / J  (X/Y)\nDuck / enter pipe: Down\nPause: Esc / P (Start)   Mute: M (Select)\nScreenshot: F12\nChange keys: Settings > Controls",
	"touch": "Left / right buttons: move\nA: jump   X: run, fireball, tongue\nHold X while moving to run.\nII: pause   Speaker: mute",
	"items": "Hit ? blocks from below.\nMushroom: grow big.  Fire flower: throw fireballs.\nStar: invincible for a while.  Green mushroom: extra life.\nBig heroes break bricks.",
	"dragon": "An egg hides in one ? block.\nJump onto the dragon to ride it.\nRun button: tongue eats enemies.\nDown + jump: hop off.  A hit throws you off.",
	"worlds": "Stomp a turtle, then kick its shell:\nit knocks out every enemy in its way.\nRed turtles turn at edges, winged ones need two stomps.\nIce is slippery. Lava and water: don't fall in!\nCave bats swoop (small: walk under them, big: duck),\ncactus stacks are spiky (use fire),\npenguins belly-slide.",
	"castles": "Fire bars spin, lava bubbles leap: time your jumps.\nThe boss ends every world: stomp its head 3-6 times\n(5 fireballs = 1 hit). A fire flower waits before\nthe arena; boss Easy/Normal: no fire left? it drops one\n(Settings: Boss fight). A win = 1UP.\nLevel select: on the title press B Y X A, type LEVELS\nor tap the title 5 times. 'Boss' starts at the boss arena\n(practice runs: not saved, no high score).",
	"sky": "Falling slabs shake, then drop: jump off in time.\nTipping planks tip toward your side: keep moving.\nJump up through the clouds.\nThe cloud imp throws spikies: stomp it from up high.\nSpikies can't be stomped: fire, shells or a star.\nGulls glide at you. The storm boss's lightning flashes first.",
	"sea": "Underwater you swim: every jump press is one stroke up.\nThe side pipe at the end leads to the beach.\nFish can't be stomped while swimming: dodge or use fire.\nJellyfish pulse toward you, crabs can be stomped.\nSea urchins can't be beaten: swim around them.",
	"water": "Castle pools: you swim in them. Press jump at\nthe surface to leap out onto the rim.\nStone teeth reach into the water: dive under them.\nCurrents (moving streaks) push you: hold run and\nswim hard against them, or let one carry you along.\nThe dragon can't swim - it waits on dry land.",
	"volcano": "Magma blobs hop at you. Stomp one: it cools into a rock\nyou can stand on - it even floats on lava. Fire can't hurt it.\nSalamanders spit fire along the ground - jump over it.\nMeteor fields: a blinking ring shows where a rock will land.\nThe volcano lord is the final boss. Good luck!",
	"ghost": "Doors: press down (or up) in front of one to go through.\nThey lead past walls - coins mark the right one.\nGhosts come closer while you look away and freeze\nwhen you face them; fire can't hurt them, a star can.\nBone turtles fall apart when stomped and rise again.\nThe phantom king fades out and appears elsewhere.",
	"map": "Play opens the world map. Walk with left / right,\nA or Space plays the course you stand on.\nTouch: tap a course to walk there, tap it again to play.\nA check = cleared, a lock = not reached yet.\nAfter a course the road to the next one opens.\nYour run is saved all along: quit any time,\nthen Continue on the title screen.",
	"players": "Take turns: Mario plays until he loses a life, then Luigi.\nTogether: both at once - each presses jump on his pad,\nor share a keyboard (Mario A D S W, Luigi arrows K L).\nFall behind or lose a life: you float back in a bubble.\nShared score, own lives, one team high score.",
	"wifi": "Both devices in the same Wi-Fi.\nMario: Play > 2 Players - Wi-Fi > Host a game.\nLuigi: ... > Join a game, pick Mario's (or type the\naddress Mario's screen shows). Same game version on both.",
	"online": "Play from anywhere (also in the browser).\nMario: Play > 2 Players - Online > Host a game.\nLuigi: ... > Join a game, type Mario's 4-letter room code.\nSame game version on both.",
	"goal": "Stomp enemies from above.\nCoins: points, 100 coins = extra life.\nPipes marked by coins lead to bonus rooms.\nGrab the flag pole as high as you can!\nExtra lives for points: Settings > 1-UP points.",
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
## focused instead of the first control when a screen opens (e.g. "Back"
## on the New Game confirmation)
var _default_focus: Control
## quit dialog: the confirm button (focus target after typing the name)
var _quit_btn: Button
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
	_name_edits = []
	_help_back_btn = null
	_default_focus = null
	_quit_btn = null
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
		Screen.CONTROLS:
			_build_controls()
		Screen.LEVELS:
			_build_levels()
		Screen.QUIT:
			_build_quit()
		Screen.NEWGAME:
			_build_newgame()
		Screen.CLEARHOF:
			_build_clearhof()
		Screen.PLAYERS:
			_build_players()
		Screen.JOIN:
			_build_join()
		Screen.NETMENU:
			_build_netmenu()
		Screen.NETHOST:
			_build_nethost()
		Screen.NETJOIN:
			_build_netjoin()
		Screen.NETWAIT:
			_build_netwait()
		Screen.NETPAUSE:
			_build_netpause()
		Screen.INFO:
			_build_info()
		Screen.ONLINEMENU:
			_build_onlinemenu()
		Screen.ONLINEJOIN:
			_build_onlinejoin()
	_panel.reset_size()
	_recenter_panel.call_deferred()
	# again once wrapped hint labels know their real width (before that they
	# report a too tall minimum -> empty band at the bottom of the panel)
	if not get_tree().process_frame.is_connected(_recenter_panel):
		get_tree().process_frame.connect(_recenter_panel, CONNECT_ONE_SHOT)
	if screen == Screen.HELP and _help_back_btn:
		_help_back_btn.grab_focus.call_deferred()
	elif _default_focus:
		_default_focus.grab_focus.call_deferred()
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
		if cb.is_valid():
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
	val_l.custom_minimum_size = Vector2(76, 0)
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
	var title := _heading("MARIO CLONE", 32)
	# touch cheat: tap the title 5 times quickly -> level select
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			var now := Time.get_ticks_msec()
			_title_taps = _title_taps + 1 if now - _title_tap_t < 600 else 1
			_title_tap_t = now
			if _title_taps >= 5:
				_title_taps = 0
				_open_level_select())
	_vbox.add_child(title)
	var sub := _hint("A pixel platform adventure")
	sub.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(sub)
	_vbox.add_child(_spacer(2))
	var save := SaveGame.load_run()
	if save.is_empty():
		# -1: the world map (v1.1), after choosing 1 / 2 players (v1.6)
		_vbox.add_child(_button("Play", func(): _show_screen(Screen.PLAYERS)))
	else:
		# v1.2: the saved run first; a new game asks before replacing it
		_vbox.add_child(_button("Continue  " + str(save.at), func():
			if int(save.get("players", 1)) == 3:
				_open_join(true)         # co-op: who plays with what (devices)
				return
			hide_all()
			continue_pressed.emit()))
		if int(save.get("players", 1)) == 3:
			var co: Dictionary = save.get("co", {})
			var ls: Array = co.get("lives", [0, 0])
			_vbox.add_child(_hint("Co-op  %06d points  -  MARIO x%d  LUIGI x%d" % [int(save.score), int(ls[0]), int(ls[1])]))
		elif int(save.get("players", 1)) == 2:
			_vbox.add_child(_hint(_two_player_line(save)))
		else:
			_vbox.add_child(_hint("%06d points  -  %d %s" % [int(save.score), int(save.lives),
				"life" if int(save.lives) == 1 else "lives"]))
		_vbox.add_child(_button("New Game", func(): _show_screen(Screen.NEWGAME)))
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
	# both ask first and show what is kept (v1.2, player: "quitting lost my
	# score and lives")
	_vbox.add_child(_button("Main Menu", func(): show_quit(false)))
	if not OS.has_feature("web"):
		_vbox.add_child(_button("Exit", func(): show_quit(true)))

# ------------------------------------------------------------ quit / save --
## Pause "Main Menu" / "Exit": saves the run first, then shows what is kept
## and — if the score made the high scores — asks for a name.
func show_quit(exit_app: bool) -> void:
	set_meta("quit_exit", exit_app)
	set_meta("quit_info", Game.instance.save_run() if Game.instance else {})
	_show_screen(Screen.QUIT)

func _build_quit() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	var exit_app: bool = get_meta("quit_exit", false)
	var info: Dictionary = get_meta("quit_info", {})
	_vbox.add_child(_heading("QUIT GAME?" if exit_app else "BACK TO MENU?"))
	if info.is_empty():
		_vbox.add_child(_hint("Nothing to save."))
	else:
		_vbox.add_child(_hint("SCORE %06d  -  WORLD %s" % [int(info.score), info.world], 16))
		_vbox.add_child(_hint("%d %s  -  %d coins" % [int(info.lives),
			"life" if int(info.lives) == 1 else "lives", int(info.coins)]))
		if int(info.get("players", 1)) == 2:
			for e in info.all:
				if int(e.hero) != int(info.hero):
					_vbox.add_child(_hint("%s: %06d  -  %d %s (saved too)" % [Player.HERO_NAMES[int(e.hero)],
						int(e.score), int(e.lives), "life" if int(e.lives) == 1 else "lives"]))
		var lines := ""
		if info.saved:
			lines = "Your run is saved: score, lives, coins, power and dragon.\n" \
				+ "Continue it any time from the title screen."
			if info.in_course:
				lines += "\nThis course then starts over (from the map)."
		else:
			lines = "Level select run: not saved, no high score.\nYour saved game stays as it is."
		var h := _hint(lines)
		h.add_theme_color_override("font_color", UiStyle.ACCENT)
		_vbox.add_child(h)
		# the name is asked once per run; later quits just show the entry
		# (v1.2.1, player: "asked again although nothing changed")
		if int(info.rank) >= 0 and str(info.name) != "":
			_vbox.add_child(_hint("High score #%d: %s" % [int(info.rank) + 1, info.name]))
		elif int(info.rank) >= 0 and int(info.get("players", 1)) == 2:
			_vbox.add_child(_hint("High score #%d: %s (rename it after the game)" % [int(info.rank) + 1,
				Player.HERO_NAMES[int(info.hero)]]))
		elif int(info.rank) >= 0:
			_vbox.add_child(_hint("HIGH SCORE #%d!  Enter your name:" % (int(info.rank) + 1)))
			_name_edit = _make_name_edit("")
			_name_edit.text_submitted.connect(func(_t: String): _quit_name_done())
			var entry := HBoxContainer.new()
			entry.alignment = BoxContainer.ALIGNMENT_CENTER
			entry.add_child(_name_edit)
			_vbox.add_child(entry)
	var saved: bool = not info.is_empty() and info.saved
	var confirm := ("Save & Exit" if saved else "Exit") if exit_app else ("Save & Menu" if saved else "Main Menu")
	_quit_btn = _button(confirm, func():
		if _name_edit and _name_edit.text.strip_edges() != "" and Game.instance:
			Game.instance.set_run_name(_name_edit.text)
		hide_all()
		if exit_app:
			if Game.instance:
				Game.instance.quit_game()
			else:
				get_tree().quit()
		else:
			quit_to_menu_pressed.emit())
	_vbox.add_child(_hbox([_quit_btn, _button("Back", func(): _show_screen(Screen.PAUSE), true)]))

## Name typed in the quit dialog (Enter / A): keep it, go on to the button.
func _quit_name_done() -> void:
	if _name_edit and _name_edit.text.strip_edges() != "" and Game.instance:
		Game.instance.set_run_name(_name_edit.text)
	if _quit_btn:
		_quit_btn.grab_focus()

## Title "New Game" while a run is saved: confirm replacing it.
func _build_newgame() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	var save := SaveGame.load_run()
	_vbox.add_child(_heading("NEW GAME?"))
	_vbox.add_child(_hint("Your saved run will be replaced:"))
	if not save.is_empty():
		_vbox.add_child(_hint("SCORE %06d  -  WORLD %s" % [int(save.score), save.at], 16))
		var rank := HallOfFame.run_rank(int(save.id))
		if rank >= 0:
			var h := _hint("Its high score (#%d) stays in the list." % (rank + 1))
			h.add_theme_color_override("font_color", UiStyle.ACCENT)
			_vbox.add_child(h)
	var back := _button("Back", func(): _show_screen(Screen.START), true)
	_vbox.add_child(_hbox([
		_button("New Game", func(): _show_screen(Screen.PLAYERS)),
		back,
	]))
	_default_focus = back

## Saved 2-player run on the title: both players' score and lives, the
## active one first.
func _two_player_line(save: Dictionary) -> String:
	var t := int(save.get("turn", 0))
	var o: Dictionary = save.get("other", {})
	var parts := ["%s %06d x%d" % [Player.HERO_NAMES[t], int(save.score), int(save.lives)]]
	if not o.is_empty():
		parts.append("%s %06d x%d" % [Player.HERO_NAMES[1 - t], int(o.get("score", 0)), int(o.get("lives", 0))])
	return "2 players:  " + "   ".join(parts)

# ---------------------------------------------------------------- players --
## v1.6: one player, or Mario and Luigi taking turns.
var _players_pending := 1

func take_players() -> int:
	var n := _players_pending
	_players_pending = 1
	return n

func _build_players() -> void:
	_panel.custom_minimum_size = Vector2(300, 0)
	_vbox.add_child(_heading("PLAYERS"))
	_vbox.add_child(_button("1 Player", func():
		_players_pending = 1
		hide_all()
		play_pressed.emit(-1)))
	_vbox.add_child(_button("2 Players - take turns", func():
		_players_pending = 2
		hide_all()
		play_pressed.emit(-1)))
	if coop_possible():
		_vbox.add_child(_button("2 Players - together", func(): _open_join(false)))
	if wifi_possible():
		_vbox.add_child(_button("2 Players - Wi-Fi", func():
			_net_continue = false
			_show_screen(Screen.NETMENU)))
	if online_possible():
		_vbox.add_child(_button("2 Players - Online", func():
			_net_continue = false
			_show_screen(Screen.ONLINEMENU)))
	var h := _hint("Take turns: Mario plays until he loses a life, then Luigi.\nTogether: both at once - two pads, or one keyboard\nfor two (Mario A D S W, Luigi arrow keys).")
	h.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(h)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.START), true))

# ------------------------------------------------------------------- join --
## Co-op (v1.7) needs two input devices: two gamepads, a keyboard for two,
## keyboard + pad or touch + pad. Not offered on a phone without a pad.
static func coop_possible() -> bool:
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return not mobile or not Input.get_connected_joypads().is_empty()

## Who plays with what: each player presses jump on his own device.
var _join := {"mario": "", "luigi": ""}
var _join_continue := false

func _open_join(cont: bool) -> void:
	_join = {"mario": "", "luigi": ""}
	_join_continue = cont
	_show_screen(Screen.JOIN)

func _join_label(who: String) -> String:
	var v: String = _join[who]
	if v == "":
		return "-"
	if v == "touch":
		return "touch buttons"
	if v == "keys":
		return "keyboard"
	return "gamepad " + v.get_slice(":", 1)

func _build_join() -> void:
	_panel.custom_minimum_size = Vector2(330, 0)
	_vbox.add_child(_heading("JOIN IN"))
	var ready: bool = _join.mario != "" and _join.luigi != ""
	var m := _button("MARIO:  " + (_join_label("mario") if _join.mario != "" else "press A / Space  (or tap)"), func():
		if _join.mario == "":
			_join.mario = "touch"
			_rebuild())
	m.add_theme_color_override("font_color", Player.HERO_COLORS[0])
	m.focus_mode = Control.FOCUS_NONE
	_vbox.add_child(m)
	var l := _button("LUIGI:  " + (_join_label("luigi") if _join.luigi != "" else "press A on another pad / Up"), Callable())
	l.add_theme_color_override("font_color", Player.HERO_COLORS[1])
	l.focus_mode = Control.FOCUS_NONE
	_vbox.add_child(l)
	if ready:
		_apply_join()
		var h := _hint(CoopInput.describe())
		h.add_theme_color_override("font_color", UiStyle.ACCENT)
		_vbox.add_child(h)
		var go := _button("Start!", func():
			hide_all()
			if Game.instance:
				Game.instance.coop_touch = _join.mario == "touch"
			if _join_continue:
				continue_pressed.emit()
			else:
				_players_pending = 3
				play_pressed.emit(-1))
		_vbox.add_child(_hbox([go, _button("Back", func(): _show_screen(Screen.START), true)]))
		_default_focus = go
	else:
		_vbox.add_child(_hint("Each player presses jump on his own controller:\npad A - keyboard Space (Mario) or Up arrow (Luigi)\n- Mario can also tap here to play with the touch buttons."))
		var back := _button("Back", func(): _show_screen(Screen.START), true)
		var row := []
		if _join_continue and wifi_possible():
			row.append(_button("Luigi via Wi-Fi", func():
				_net_continue = true
				_start_hosting()))
		if _join_continue and online_possible():
			row.append(_button("Luigi online", func():
				_net_continue = true
				_start_hosting(true)))
		row.append(back)
		_vbox.add_child(_hbox(row))
		_default_focus = back

func _apply_join() -> void:
	CoopInput.reset()
	var lu: String = _join.luigi
	if lu == "keys":
		CoopInput.split = _join.mario == "keys"
		CoopInput.luigi_keys = not CoopInput.split
	elif lu.begins_with("pad:"):
		CoopInput.luigi_pad = int(lu.get_slice(":", 1))
	CoopInput.build()

func _join_input(event: InputEvent) -> void:
	if _join.mario != "" and _join.luigi != "":
		return
	var who := ""
	var dev := ""
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		dev = "pad:%d" % event.device
		if _join.mario == "":
			who = "mario"
		elif _join.mario != dev:
			who = "luigi"
		else:
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in CoopInput.JOIN_P2_KEYS and _join.luigi == "":
			who = "luigi"
		elif code in CoopInput.JOIN_P1_KEYS and _join.mario == "":
			who = "mario"
		elif code in CoopInput.JOIN_P1_KEYS or code in CoopInput.JOIN_P2_KEYS:
			get_viewport().set_input_as_handled()
			return
		dev = "keys"
	if who == "":
		return
	get_viewport().set_input_as_handled()
	_join[who] = dev
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.play("coin")
	_rebuild()

# ------------------------------------------------------------------ Wi-Fi --
## v1.8 stage 1: two devices in the same Wi-Fi (native builds; a browser
## can't use the local network — stage 2 brings an internet relay).
static func wifi_possible() -> bool:
	return not OS.has_feature("web")

## v1.9 stage 2: over the internet through the relay (also in the browser),
## once its address is set (NetLink.relay_url()).
static func online_possible() -> bool:
	return NetLink.relay_url() != ""

var _net_online := false
var _room_code := ""

func show_room_code(code: String) -> void:
	_room_code = code
	if screen == Screen.NETHOST:
		_rebuild()
var _net_continue := false
var _net_disc: NetLink.Discovery
var _net_found_sig := ""
var _ip_edit: LineEdit
var _info := ["", ""]

func take_net_continue() -> bool:
	var c := _net_continue
	_net_continue = false
	return c

func show_info(title: String, text: String) -> void:
	_info = [title, text]
	_show_screen(Screen.INFO)

func show_net_pause() -> void:
	_show_screen(Screen.NETPAUSE)

func _build_info() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	_vbox.add_child(_heading(_info[0]))
	_vbox.add_child(_hint(_info[1]))
	_vbox.add_child(_button("OK", func(): _show_screen(Screen.START), true))

func _build_netmenu() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	_vbox.add_child(_heading("WI-FI"))
	_vbox.add_child(_button("Host a game  (Mario)", _start_hosting))
	_vbox.add_child(_button("Join a game  (Luigi)", func(): _show_screen(Screen.NETJOIN)))
	var h := _hint("Both devices in the same Wi-Fi. Mario's device runs\nthe game, Luigi's shows it and sends his buttons.\nBoth need the same game version.")
	h.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(h)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.PLAYERS), true))

func _start_hosting(online := false) -> void:
	if Game.instance == null:
		return
	_net_online = online
	_room_code = ""
	var err := Game.instance.net_host_start(online)
	if err != OK:
		if online:
			show_info("ONLINE", "Could not reach the online server (error %d)." % err)
		else:
			show_info("WI-FI", "Could not open the game for Wi-Fi (error %d).\nIs another copy of the game already hosting?" % err)
		return
	_show_screen(Screen.NETHOST)

func _build_onlinemenu() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	_vbox.add_child(_heading("ONLINE"))
	_vbox.add_child(_button("Host a game  (Mario)", func(): _start_hosting(true)))
	_vbox.add_child(_button("Join a game  (Luigi)", func(): _show_screen(Screen.ONLINEJOIN)))
	var h := _hint("Play from anywhere: Mario gets a room code and tells\nit to Luigi. Mario's device runs the game, Luigi's shows\nit. Works in the browser, too. Same game version on both.")
	h.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(h)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.PLAYERS), true))

func _build_onlinejoin() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	_vbox.add_child(_heading("JOIN ONLINE"))
	_vbox.add_child(_hint("Type the room code Mario's screen shows:"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "CODE"
	_ip_edit.max_length = 4
	_ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ip_edit.custom_minimum_size = Vector2(96, BTN_H)
	_ip_edit.add_theme_font_size_override("font_size", FONT)
	_ip_edit.text_changed.connect(func(t: String):
		var up := t.to_upper()
		if up != t:
			_ip_edit.text = up
			_ip_edit.caret_column = up.length())
	_ip_edit.text_submitted.connect(func(t: String): _join_code(t))
	row.add_child(_ip_edit)
	row.add_child(_button("Join", func(): _join_code(_ip_edit.text)))
	_vbox.add_child(row)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.ONLINEMENU), true))
	_default_focus = _ip_edit

func _join_code(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() != 4 or Game.instance == null:
		return
	set_meta("net_ip", "room " + code)
	if Game.instance.net_join(code, true) != OK:
		show_info("ONLINE", "Could not reach the online server.")
		return
	_show_screen(Screen.NETWAIT)

func _build_nethost() -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	_vbox.add_child(_heading("WAITING FOR LUIGI"))
	if _net_online:
		if _room_code == "":
			_vbox.add_child(_hint("Opening a room on the online server ..."))
		else:
			_vbox.add_child(_hint("Tell Luigi this room code:"))
			var code := _heading(_room_code, 32)
			code.add_theme_color_override("font_color", UiStyle.ACCENT)
			_vbox.add_child(code)
			_vbox.add_child(_hint("Luigi: Play > 2 Players - Online > Join a game."))
		_vbox.add_child(_button("Cancel", func():
			if Game.instance:
				Game.instance.net_stop()
			_show_screen(Screen.START), true))
		return
	var ips := NetLink.local_ips()
	var addr := ", ".join(ips) if not ips.is_empty() else "no Wi-Fi address found"
	_vbox.add_child(_hint("On Luigi's device: Play > 2 Players - Wi-Fi > Join.\nThis game shows up there by itself, or type its address:"))
	var a := _hint(addr, 16)
	a.add_theme_color_override("font_color", UiStyle.ACCENT)
	_vbox.add_child(a)
	_vbox.add_child(_button("Cancel", func():
		if Game.instance:
			Game.instance.net_stop()
		_show_screen(Screen.START), true))

func _build_netjoin() -> void:
	_panel.custom_minimum_size = Vector2(330, 0)
	_vbox.add_child(_heading("JOIN A GAME"))
	if _net_disc == null:
		_net_disc = NetLink.Discovery.new()
		if _net_disc.start_search() != OK:
			_vbox.add_child(_hint("(searching is not possible here - type the address)"))
	var found: Dictionary = _net_disc.found
	_net_found_sig = ",".join(found.keys())
	if found.is_empty():
		_vbox.add_child(_hint("Looking for games in this Wi-Fi ..."))
	for ip in found:
		var hb := _button("Mario on %s  (%s)" % [found[ip].name, ip], _connect_to.bind(ip))
		_vbox.add_child(hb)
		if _default_focus == null:
			_default_focus = hb
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.x.x"
	_ip_edit.text = str(GameSettings.load_all().get("last_host", ""))
	_ip_edit.custom_minimum_size = Vector2(150, BTN_H)
	_ip_edit.add_theme_font_size_override("font_size", FONT)
	_ip_edit.text_submitted.connect(func(t: String): _connect_to(t.strip_edges()))
	row.add_child(_ip_edit)
	row.add_child(_button("Connect", func(): _connect_to(_ip_edit.text.strip_edges())))
	_vbox.add_child(row)
	var back := _button("Back", func():
		_stop_search()
		_show_screen(Screen.NETMENU), true)
	_vbox.add_child(back)
	if _default_focus == null:
		_default_focus = back

func _stop_search() -> void:
	if _net_disc:
		_net_disc.stop()
		_net_disc = null

func _process(delta: float) -> void:
	if screen != Screen.NETJOIN or _net_disc == null:
		return
	_net_disc.poll(delta)
	if ",".join(_net_disc.found.keys()) != _net_found_sig and not (_ip_edit and _ip_edit.has_focus()):
		_rebuild()

func _connect_to(ip: String) -> void:
	if ip == "" or Game.instance == null:
		return
	_stop_search()
	var c := GameSettings.load_all()
	c["last_host"] = ip
	GameSettings.save(c)
	set_meta("net_ip", ip)
	if Game.instance.net_join(ip) != OK:
		show_info("WI-FI", "Could not connect to %s." % ip)
		return
	_show_screen(Screen.NETWAIT)

func _build_netwait() -> void:
	_vbox.add_child(_heading("CONNECTING"))
	var t: String = get_meta("net_ip", "")
	_vbox.add_child(_hint("to Mario's game %s ..." % (t if t.begins_with("room") else "at " + t)))
	_vbox.add_child(_button("Cancel", func(): if Game.instance: Game.instance.net_leave(""), true))

func _build_netpause() -> void:
	_vbox.add_child(_heading("PAUSED"))
	_vbox.add_child(_button("Resume", func():
		hide_all()
		if Game.instance:
			Game.instance.net_guest_resume()))
	_vbox.add_child(_button("Settings", func():
		_return_screen = Screen.NETPAUSE
		_show_screen(Screen.SETTINGS)))
	_vbox.add_child(_button("How to Play", func():
		_return_screen = Screen.NETPAUSE
		_help_page = 0
		_show_screen(Screen.HELP)))
	_vbox.add_child(_button("Leave game", func():
		if Game.instance:
			Game.instance.net_leave("")))
	_vbox.add_child(_hint("Mario's game is paused too."))

func _make_name_edit(text := "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = "Your name"
	e.text = text if text != "YOU" else ""
	e.max_length = 12 if Game.instance and Game.instance.players == 3 else 8
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(120, BTN_H)
	e.add_theme_font_size_override("font_size", FONT)
	return e

# --------------------------------------------------------------- gameover --
func _build_gameover(victory: bool) -> void:
	_panel.custom_minimum_size = Vector2(320, 0)
	_name_edit = null
	var practice := Game.instance != null and Game.instance.practice
	var score: int = get_meta("go_score", 0)
	var world: String = get_meta("go_world", "1-1")
	var committed: bool = get_meta("go_committed", false)
	# game.gd already entered the run's score (as "YOU" or its given name)
	var rank := HallOfFame.run_rank(Game.instance.run_id) if Game.instance else -1
	_vbox.add_child(_heading("YOU WIN!" if victory else "GAME OVER"))
	if Game.instance and Game.instance.players == 2:
		_build_gameover_2p(committed, practice)
		return
	var score_l := _hint("SCORE %06d  -  WORLD %s" % [score, world], 16)
	_vbox.add_child(score_l)
	if practice:
		var h := _hint("Level select run - no high score entry.")
		h.add_theme_color_override("font_color", UiStyle.ACCENT)
		_vbox.add_child(h)
	elif rank >= 0 and not committed:
		_name_edit = _make_name_edit(Game.instance.run_name)
		_name_edit.text_submitted.connect(func(_t: String): _commit_score())
		var entry := HBoxContainer.new()
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.add_theme_constant_override("separation", 4)
		entry.add_child(_name_edit)
		entry.add_child(_button("Enter", func(): _commit_score()))
		_vbox.add_child(entry)
	var grid := _hof_grid()
	_vbox.add_child(grid)
	_render_hof(grid, HallOfFame.load_list(), rank)
	_vbox.add_child(_gameover_buttons())

## Two players (v1.6): both scores, a name field for each one in the list.
var _name_edits: Array = []

func _build_gameover_2p(committed: bool, practice: bool) -> void:
	_name_edits = []
	var entries: Array = Game.instance.player_entries()
	var ranks := []
	for e in entries:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		var l := Label.new()
		l.text = "%s  %06d  WORLD %s" % [Player.HERO_NAMES[int(e.hero)], int(e.score), e.world]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Player.HERO_COLORS[int(e.hero)])
		row.add_child(l)
		if int(e.rank) >= 0:
			ranks.append(int(e.rank))
			if not committed:
				var ed := _make_name_edit(str(e.name))
				ed.placeholder_text = Player.HERO_NAMES[int(e.hero)]
				ed.set_meta("hero", int(e.hero))
				ed.text_submitted.connect(func(_t: String): _next_name_edit(ed))
				_name_edits.append(ed)
				row.add_child(ed)
		_vbox.add_child(row)
	if practice:
		_vbox.add_child(_hint("Level select run - no high score entry."))
	elif not _name_edits.is_empty():
		_name_edit = _name_edits[0]
		_vbox.add_child(_hbox([_button("Enter names", func(): _commit_score())]))
	var grid := _hof_grid()
	_vbox.add_child(grid)
	_render_hof(grid, HallOfFame.load_list(), ranks)
	_vbox.add_child(_gameover_buttons())

func _next_name_edit(ed: LineEdit) -> void:
	var i := _name_edits.find(ed)
	if i >= 0 and i + 1 < _name_edits.size():
		_name_edits[i + 1].grab_focus()
	else:
		_commit_score()

func _gameover_buttons() -> HBoxContainer:
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
	return _hbox(btns)

## Names the run's high score entry (empty = keeps "YOU" / the earlier name).
func _commit_score() -> void:
	if not _name_edits.is_empty() and Game.instance:
		for ed in _name_edits:
			if is_instance_valid(ed) and ed.text.strip_edges() != "":
				Game.instance.set_player_name(int(ed.get_meta("hero")), ed.text)
		_name_edits = []
		set_meta("go_committed", true)
		_rebuild()
		return
	var who := (_name_edit.text if _name_edit else "").strip_edges()
	if who != "" and Game.instance:
		Game.instance.set_run_name(who)
	set_meta("go_committed", true)
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

func _render_hof(grid: GridContainer, list: Array, highlight) -> void:
	var marks: Array = highlight if highlight is Array else [highlight]
	if list.is_empty():
		grid.columns = 1
		var h := _hint("- no entries yet -")
		h.custom_minimum_size = Vector2(200, 0)
		grid.add_child(h)
		return
	for i in list.size():
		var e = list[i]
		var col := UiStyle.ACCENT if i in marks else Color.WHITE
		grid.add_child(_cell("%d." % (i + 1), col, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(_cell(str(e.name).to_upper(), col))
		grid.add_child(_cell(str(e.get("world", "1-1")), Color(col.r, col.g, col.b, 0.7)))
		grid.add_child(_cell("%06d" % int(e.score), col, HORIZONTAL_ALIGNMENT_RIGHT))

# ------------------------------------------------- level select (cheat) --
## Start screen codes: gamepad B, Y, X, A  /  keyboard L E V E L S  /
## tap the title 5x. Opens a list of ALL courses. Choosing one beyond the
## furthest course reached marks the run as cheated (no high score entry).
const CHEAT_PAD := ["j1", "j3", "j2", "j0"]
const CHEAT_KEYS := ["kL", "kE", "kV", "kE", "kL", "kS"]
var _cheat_buf: Array[String] = []
var _cheat_pending := false
var _boss_pending := false
var _title_taps := 0
var _title_tap_t := 0

func take_boss() -> bool:
	var b := _boss_pending
	_boss_pending = false
	return b

func take_cheat() -> bool:
	var c := _cheat_pending
	_cheat_pending = false
	return c

func _cheat_input(event: InputEvent) -> void:
	var tok := ""
	if event is InputEventJoypadButton and event.pressed:
		tok = "j%d" % event.button_index
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		tok = "k" + OS.get_keycode_string(k).to_upper()
	if tok == "":
		return
	_cheat_buf.append(tok)
	if _cheat_buf.size() > 8:
		_cheat_buf.remove_at(0)
	for code in [CHEAT_PAD, CHEAT_KEYS]:
		if _cheat_buf.size() >= code.size() and _cheat_buf.slice(-code.size()) == code:
			_cheat_buf.clear()
			get_viewport().set_input_as_handled()     # the final A must not press "Play"
			_open_level_select()
			return

func _open_level_select() -> void:
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.play("oneup")
	_show_screen(Screen.LEVELS)

func _build_levels() -> void:
	_panel.custom_minimum_size = Vector2(300, 0)
	_vbox.add_child(_heading("LEVEL SELECT"))
	var reached := Game.reached_level_index()
	# more worlds than fit the 270-px canvas (v1.4): the rows scroll along
	# with the focus, hint + Back stay below
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 148)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	for w in range(1, Game.WORLD_NAMES.size() + 1):
		var n := 0
		for i in Game.LEVELS.size():
			if Game.world_of(i) != w:
				continue
			var lv: Script = Game.LEVELS[i]
			var is_castle: bool = lv.FLAG.x < 0
			var b := _button(String(lv.ID) + (" *" if is_castle else ""), func():
				_cheat_pending = i > reached
				_boss_pending = false
				hide_all()
				play_pressed.emit(i))
			b.custom_minimum_size = Vector2(66, BTN_H)
			if i > reached:
				b.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
			grid.add_child(b)
			n += 1
		while n < 4:
			grid.add_child(Control.new())
			n += 1
		# straight to the boss arena of this world's castle
		var ci := Game.castle_of_world(w)
		var bb := _button("Boss", func():
			_cheat_pending = ci > reached
			_boss_pending = true
			hide_all()
			play_pressed.emit(ci))
		bb.custom_minimum_size = Vector2(66, BTN_H)
		if ci > reached:
			bb.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
		grid.add_child(bb)
	scroll.add_child(grid)
	_vbox.add_child(scroll)
	var h := _hint("* = castle   Boss = boss arena   orange = not reached\nPractice runs: not saved, no high score entry.")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(h)
	_vbox.add_child(_button("Back", func(): _show_screen(Screen.START), true))

# ------------------------------------------------------------- highscores --
func _build_highscores() -> void:
	_vbox.add_child(_heading("HIGH SCORES"))
	var grid := _hof_grid()
	_vbox.add_child(grid)
	# highlight the running (pause) or saved (title) run's entry
	var run := int(SaveGame.load_run().get("id", 0))
	if _return_screen == Screen.PAUSE and Game.instance:
		run = Game.instance.run_id
	var list := HallOfFame.load_list()
	_render_hof(grid, list, HallOfFame.run_rank(run))
	_vbox.add_child(_spacer(2))
	var back := _button("Back", func(): _show_screen(_return_screen), true)
	if _return_screen == Screen.START and not list.is_empty():
		_vbox.add_child(_hbox([back, _button("Clear list", func(): _show_screen(Screen.CLEARHOF))]))
	else:
		_vbox.add_child(back)

## "Clear list": the whole board goes (default focus on "Back").
func _build_clearhof() -> void:
	_panel.custom_minimum_size = Vector2(300, 0)
	_vbox.add_child(_heading("CLEAR LIST?"))
	_vbox.add_child(_hint("All high score entries will be deleted.\nThis can't be undone."))
	var back := _button("Back", func(): show_highscores(Screen.START), true)
	_vbox.add_child(_hbox([
		_button("Delete", func():
			HallOfFame.clear()
			show_highscores(Screen.START)),
		back,
	]))
	_default_focus = back

# --------------------------------------------------------------- settings --
func _build_settings() -> void:
	_panel.custom_minimum_size = Vector2(300, 0)
	_vbox.add_child(_heading("SETTINGS"))
	# the rows scroll (8 no longer fit the 270-px canvas); the buttons stay
	# below, always reachable; follow_focus scrolls along with the D-pad
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var lives_row := _row("Lives")
	_stepper(lives_row, func(): return _cfg.lives,
		func(d): _set_cfg("lives", clampi(_cfg.lives + d, GameSettings.LIVES_MIN, GameSettings.LIVES_MAX)),
		func(v): return str(v))
	list.add_child(lives_row)
	var diff_row := _row("Difficulty")
	_stepper(diff_row, func(): return _cfg.difficulty,
		func(d): _set_cfg("difficulty", posmod(_cfg.difficulty + d, GameSettings.DIFF_NAMES.size())),
		func(v): return GameSettings.DIFF_NAMES[v])
	list.add_child(diff_row)
	var boss_row := _row("Boss fight")
	_stepper(boss_row, func(): return _cfg.boss_difficulty,
		func(d): _set_cfg("boss_difficulty", posmod(_cfg.boss_difficulty + d, GameSettings.BOSS_DIFF_NAMES.size())),
		func(v): return GameSettings.BOSS_DIFF_NAMES[v])
	list.add_child(boss_row)
	var time_row := _row("Timer")
	_stepper(time_row, func(): return _cfg.time_limit,
		func(d): _set_cfg("time_limit", posmod(_cfg.time_limit + d, GameSettings.TIME_NAMES.size())),
		func(v): return GameSettings.TIME_NAMES[v])
	list.add_child(time_row)
	var coin_row := _row("Coin points")
	_stepper(coin_row, func(): return GameSettings.COIN_POINTS.find(int(_cfg.coin_points)),
		func(d):
			var i := posmod(GameSettings.COIN_POINTS.find(int(_cfg.coin_points)) + d, GameSettings.COIN_POINTS.size())
			_set_cfg("coin_points", GameSettings.COIN_POINTS[i]),
		func(v): return str(GameSettings.COIN_POINTS[maxi(v, 0)]))
	list.add_child(coin_row)
	var life_row := _row("1-UP coins")
	_stepper(life_row, func(): return GameSettings.COINS_PER_LIFE.find(int(_cfg.coins_per_life)),
		func(d):
			var i := posmod(GameSettings.COINS_PER_LIFE.find(int(_cfg.coins_per_life)) + d, GameSettings.COINS_PER_LIFE.size())
			_set_cfg("coins_per_life", GameSettings.COINS_PER_LIFE[i]),
		func(v):
			var n: int = GameSettings.COINS_PER_LIFE[maxi(v, 0)]
			return "Off" if n == 0 else str(n))
	list.add_child(life_row)
	var pts_row := _row("1-UP points")
	_stepper(pts_row, func(): return GameSettings.LIFE_POINTS.find(int(_cfg.life_points)),
		func(d):
			var i := posmod(GameSettings.LIFE_POINTS.find(int(_cfg.life_points)) + d, GameSettings.LIFE_POINTS.size())
			_set_cfg("life_points", GameSettings.LIFE_POINTS[i]),
		func(v):
			var n: int = GameSettings.LIFE_POINTS[maxi(v, 0)]
			return "Off" if n == 0 else str(n))
	list.add_child(pts_row)
	var big_row := _row("Start big")
	_stepper(big_row, func(): return _cfg.start_big,
		func(_d): _set_cfg("start_big", not bool(_cfg.start_big)),
		func(v): return "Yes" if v else "No")
	list.add_child(big_row)
	var dj_row := _row("Double jump")
	_stepper(dj_row, func(): return _cfg.double_jump,
		func(_d): _set_cfg("double_jump", not bool(_cfg.double_jump)),
		func(v): return "Yes" if v else "No")
	list.add_child(dj_row)
	_vbox.add_child(scroll)
	_vbox.add_child(_hbox([
		_button("Sound", func(): _show_screen(Screen.SOUND)),
		_button("Controls", func(): _show_screen(Screen.CONTROLS)),
		_button("Back", func(): _show_screen(_return_screen), true),
	]))

# --------------------------------------------------------------- controls --
## Rebinding: press a slot button, then the new key / gamepad button.
var _slots: Array = []            # [{button, action, kind}]
var _listen := {}                 # {action, kind, button, t} while waiting

func _build_controls() -> void:
	_panel.custom_minimum_size = Vector2(330, 0)
	_listen = {}
	_slots.clear()
	_vbox.add_child(_heading("CONTROLS"))
	var touch_row := _row("Touch keys", 130)
	_stepper(touch_row, func(): return int(_cfg.touch_buttons),
		func(d): _set_cfg("touch_buttons", posmod(int(_cfg.touch_buttons) + d, GameSettings.TOUCH_NAMES.size())),
		func(v): return GameSettings.TOUCH_NAMES[v])
	_vbox.add_child(touch_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 124)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for spec in ControlsConfig.ACTIONS:
		var row := _row(spec[1], 110)
		var kb := _button("", Callable())
		kb.custom_minimum_size = Vector2(100, BTN_H)
		kb.pressed.connect(_start_listen.bind(spec[0], "key", kb))
		row.add_child(kb)
		_slots.append({"button": kb, "action": spec[0], "kind": "key"})
		if spec[2]:
			var pb := _button("", Callable())
			pb.custom_minimum_size = Vector2(90, BTN_H)
			pb.pressed.connect(_start_listen.bind(spec[0], "pad", pb))
			row.add_child(pb)
			_slots.append({"button": pb, "action": spec[0], "kind": "pad"})
		else:
			var l := _hint("D-pad")
			l.custom_minimum_size = Vector2(90, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(l)
		list.add_child(row)
	_vbox.add_child(scroll)
	_refresh_slots()
	_vbox.add_child(_hbox([
		_button("Defaults", func():
			ControlsConfig.reset()
			_listen = {}
			_refresh_slots()),
		_button("Back", func(): _show_screen(Screen.SETTINGS), true),
	]))

func _refresh_slots() -> void:
	for s in _slots:
		var b: Button = s.button
		if not is_instance_valid(b):
			continue
		if not _listen.is_empty() and _listen.button == b:
			b.text = "press..."
		else:
			b.text = ControlsConfig.key_label(s.action) if s.kind == "key" else ControlsConfig.pad_label(s.action)

func _start_listen(action: String, kind: String, b: Button) -> void:
	_listen = {"action": action, "kind": kind, "button": b, "t": Time.get_ticks_msec()}
	_refresh_slots()
	var token: int = _listen.t
	get_tree().create_timer(5.0, true, false, true).timeout.connect(func():
		if not _listen.is_empty() and _listen.t == token:
			_listen = {}
			_refresh_slots())

func _input(event: InputEvent) -> void:
	if screen == Screen.JOIN:
		_join_input(event)
		return
	if screen == Screen.START:
		_cheat_input(event)
		return
	if _listen.is_empty() or screen != Screen.CONTROLS:
		return
	if Time.get_ticks_msec() - int(_listen.t) < 150 or not event.is_pressed() or event.is_echo():
		return
	var value := -1
	if _listen.kind == "key" and event is InputEventKey:
		value = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	elif _listen.kind == "pad" and event is InputEventJoypadButton:
		value = event.button_index
	elif event is InputEventMouseButton:
		_listen = {}
		_refresh_slots()
		return
	if value < 0:
		return
	get_viewport().set_input_as_handled()
	ControlsConfig.set_binding(_listen.action, _listen.kind, value)
	var b: Button = _listen.button
	_listen = {}
	_refresh_slots()
	b.grab_focus.call_deferred()

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
		# the label follows Snd.mute_changed (button here, HUD speaker, M key,
		# Select). NB: a lambda passed while `mute_btn` is still unassigned
		# would capture null — that was the "label doesn't switch" bug.
		var mute_btn := _button("Muted" if snd.is_muted() else "On", func(): snd.toggle_mute())
		mute_btn.custom_minimum_size = Vector2(90, BTN_H)
		var show_mute := func(m: bool): mute_btn.text = "Muted" if m else "On"
		snd.mute_changed.connect(show_mute)
		mute_btn.tree_exiting.connect(func(): snd.mute_changed.disconnect(show_mute))
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
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if event.is_action_pressed("ui_accept"):
		for ed in _name_edits:
			if is_instance_valid(ed) and ed.has_focus():
				_next_name_edit(ed)
				get_viewport().set_input_as_handled()
				return
	if _name_edit != null and is_instance_valid(_name_edit) and _name_edit.has_focus() \
			and event.is_action_pressed("ui_accept"):
		if screen == Screen.QUIT:
			_quit_name_done()
		else:
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
