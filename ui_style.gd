class_name UiStyle

## Shared menu chrome (menus.gd, hud.gd, touch_controls.gd). Same system as
## centipede/galaga's ui_style.gd — framed panel, per-state button boxes,
## outlined headings, frosted-glass backdrop — re-scaled for this project's
## 480x270 landscape canvas and its own pixel font (assets/ui/pixel_font.ttf,
## crisp at sizes 8/16/24/32). Palette: night-blue panel, coin-gold accent.

const ACCENT := Color("ffd83c")
const ACCENT_DARK := Color("c26f10")
const PANEL_BG := Color(0.05, 0.07, 0.16, 0.9)
const PANEL_BORDER := Color("ffd83c")
const INK := Color("1a1018")

static func panel_style(margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func style_button(b: Button, font_size := 16) -> void:
	var alphas := {"normal": 0.14, "hover": 0.32, "pressed": 0.08, "disabled": 0.05}
	for state in alphas:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, alphas[state])
		sb.set_corner_radius_all(5)
		sb.set_border_width_all(1)
		sb.border_color = ACCENT if state == "hover" else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
		sb.set_content_margin_all(2)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 2)
	b.add_theme_font_size_override("font_size", font_size)
	# Focusable buttons (gamepad/keyboard navigation) — without this override
	# Godot draws its default focus rectangle over the glass look.
	var focus_sb := StyleBoxFlat.new()
	focus_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.24)
	focus_sb.set_corner_radius_all(5)
	focus_sb.set_border_width_all(2)
	focus_sb.border_color = ACCENT
	focus_sb.set_content_margin_all(2)
	b.add_theme_stylebox_override("focus", focus_sb)

static func heading(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	return l

## "Marquee" treatment for big moments (menu headings, WORLD 1-1 card,
## GAME OVER, TIME UP): white fill, gold outline, drop shadow.
static func impact_label(l: Label, fill := Color.WHITE, outline := ACCENT_DARK) -> void:
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 2)

## Frosted-glass backdrop: BackBufferCopy + ColorRect running
## frosted_glass.gdshader (GL Compatibility needs the explicit BackBufferCopy).
static func make_glass_backdrop() -> Dictionary:
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var glass := ColorRect.new()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/ui/frosted_glass.gdshader")
	mat.set_shader_parameter("blur", 7.0)
	mat.set_shader_parameter("tint", Color(0.02, 0.03, 0.1, 1.0))
	mat.set_shader_parameter("tint_amount", 0.45)
	glass.material = mat
	return {"backbuffer": bbc, "glass": glass}
