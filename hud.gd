class_name Hud
extends Control

## In-play HUD (CanvasLayer 10): score / coins / world / time / lives along
## the top edge in the pixel font, the mandatory frosted-glass Pause + Mute
## buttons top-right (global CLAUDE.md #15), a center banner ("HURRY UP!",
## "COURSE CLEAR!") and the full-screen "WORLD 1-1" intro card.
## Lives are shown as the RESERVE (active life not counted, #16).

const BTN := 22.0
const MARGIN := 6.0
const MANY_THRESHOLD := 5

signal pause_pressed
signal mute_pressed

var _score: Label
var _coins: Label
var _world: Label
var _time: Label
var _lives: Label
var _banner: Label
var _banner_tween: Tween
var _card: ColorRect
var _card_title: Label
var _card_name: Label
var _card_lives: Label
var _mute_icon: Control
var _pause_btn: Button
var _mute_btn: Button
var _coin_icon: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_score = _column("SCORE", 10)
	_coins = _column("COINS", 86)
	_world = _column("WORLD", 150)
	_time = _column("TIME", 206)
	_lives = _column("LIVES", 256)
	_coin_icon = TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/graphics/coin.png")
	at.region = Rect2(0, 0, 12, 16)
	_coin_icon.texture = at
	_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coin_icon)
	_coin_icon.position = Vector2(85, 12)
	_coin_icon.size = Vector2(6, 8)
	_coins.position.x = 93

	_pause_btn = _glass_button(0)
	_pause_btn.text = "II"
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_mute_btn = _glass_button(1)
	_mute_btn.pressed.connect(func(): mute_pressed.emit())
	_mute_icon = Control.new()
	_mute_icon.set_script(preload("res://mute_icon.gd"))
	_mute_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_mute_icon.offset_left = _mute_btn.offset_left
	_mute_icon.offset_top = _mute_btn.offset_top
	_mute_icon.offset_right = _mute_btn.offset_right
	_mute_icon.offset_bottom = _mute_btn.offset_bottom
	add_child(_mute_icon)

	_banner = UiStyle.heading("", 16)
	UiStyle.impact_label(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -160
	_banner.offset_right = 160
	_banner.offset_top = -40
	_banner.offset_bottom = -20
	_banner.visible = false
	add_child(_banner)

	_card = ColorRect.new()
	_card.color = Color("05060d")
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	_card_title = _card_label(24, -34)
	_card_name = _card_label(8, -6)
	_card_name.add_theme_color_override("font_color", UiStyle.ACCENT)
	_card_lives = _card_label(16, 14)
	_card_lives.offset_left = -180
	var icon := TextureRect.new()
	var at_h := AtlasTexture.new()
	at_h.atlas = preload("res://assets/graphics/hero_small.png")
	at_h.region = Rect2(0, 0, 20, 20)
	icon.texture = at_h
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -34
	icon.offset_right = -14
	icon.offset_top = 8
	icon.offset_bottom = 28
	_card.add_child(icon)
	set_meta("card_icon", icon)

func _column(title: String, x: float) -> Label:
	var t := Label.new()
	t.text = title
	t.position = Vector2(x, 3)
	t.add_theme_font_size_override("font_size", 8)
	t.add_theme_color_override("font_color", Color("fff0c0"))
	t.add_theme_color_override("font_outline_color", UiStyle.INK)
	t.add_theme_constant_override("outline_size", 3)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	var v := Label.new()
	v.position = Vector2(x, 12)
	v.add_theme_font_size_override("font_size", 8)
	v.add_theme_color_override("font_color", Color.WHITE)
	v.add_theme_color_override("font_outline_color", UiStyle.INK)
	v.add_theme_constant_override("outline_size", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	return v

func _glass_button(slot: int) -> Button:
	var b := Button.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_right = -MARGIN - slot * (BTN + 4)
	b.offset_left = b.offset_right - BTN
	b.offset_top = MARGIN - 2
	b.offset_bottom = b.offset_top + BTN
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.style_button(b, 8)
	var g := UiStyle.make_glass_backdrop()
	add_child(g.backbuffer)
	add_child(g.glass)
	g.glass.visible = true
	g.glass.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	g.glass.offset_left = b.offset_left
	g.glass.offset_right = b.offset_right
	g.glass.offset_top = b.offset_top
	g.glass.offset_bottom = b.offset_bottom
	add_child(b)
	return b

func _card_label(size: int, y: float) -> Label:
	var l := UiStyle.heading("", size)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = y - 10
	l.offset_bottom = y + 20
	_card.add_child(l)
	return l

# ------------------------------------------------------------------ values --
func set_score(n: int) -> void:
	_score.text = "%06d" % n

func set_coins(n: int) -> void:
	_coins.text = "x%02d" % n

func set_world(w: String) -> void:
	_world.text = " " + w

func set_time(t: int) -> void:
	_time.text = "---" if t < 0 else "%03d" % t

func set_lives(total: int) -> void:
	var reserve := maxi(total - 1, 0)
	_lives.text = "x%d" % reserve if reserve < MANY_THRESHOLD else "x%d" % reserve

func set_muted(m: bool) -> void:
	_mute_icon.set_muted(m)

func set_buttons_visible(v: bool) -> void:
	_pause_btn.visible = v
	_mute_btn.visible = v
	_mute_icon.visible = v

# ----------------------------------------------------------------- banners --
## Boss health pips under the HUD row (hp < 0 hides them).
var _boss_box: HBoxContainer

func set_boss(hp: int, max_hp: int) -> void:
	if _boss_box == null:
		_boss_box = HBoxContainer.new()
		_boss_box.anchor_left = 0.5
		_boss_box.anchor_right = 0.5
		_boss_box.offset_left = -60
		_boss_box.offset_right = 60
		_boss_box.offset_top = 26
		_boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_boss_box.add_theme_constant_override("separation", 3)
		_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_boss_box)
	for c in _boss_box.get_children():
		c.queue_free()
	_boss_box.visible = hp >= 0
	if hp < 0:
		return
	var l := Label.new()
	l.text = "BOSS"
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	l.add_theme_color_override("font_outline_color", UiStyle.INK)
	l.add_theme_constant_override("outline_size", 2)
	_boss_box.add_child(l)
	for i in max_hp:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 6)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = Color("e8402e") if i < hp else Color(0.2, 0.15, 0.2, 0.8)
		_boss_box.add_child(pip)

func show_banner(text: String, duration: float) -> void:
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(maxf(duration - 0.4, 0.0))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.2)
	_banner_tween.tween_callback(func(): _banner.visible = false)

func show_card(world: String, name: String, lives_total: int) -> void:
	_card_title.text = "WORLD " + world
	_card_name.text = name
	_card_lives.text = "   x %d" % maxi(lives_total, 0)
	get_meta("card_icon").visible = true
	_card.visible = true
	queue_redraw()

func show_text_card(title: String, sub := "") -> void:
	_card_title.text = title
	_card_name.text = sub
	_card_lives.text = ""
	get_meta("card_icon").visible = false
	_card.visible = true

func hide_card() -> void:
	_card.visible = false
