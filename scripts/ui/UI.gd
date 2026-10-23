extends RefCounted
## Shared UI building blocks for the menu, HUD and touch controls (one look everywhere).

const MAIN_FONTS := ["Bahnschrift", "DIN Alternate", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "Liberation Sans Narrow", "Helvetica Neue", "Arial", "Sans-Serif"]
const TYPE_FONTS := ["Courier New", "Courier Prime", "American Typewriter", "Liberation Mono", "DejaVu Sans Mono", "Monospace"]


static func font(names: Array, weight := 400) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func label(text: String, size: int, col: Color, fnt: Font, shadow := 2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", fnt)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", shadow)
	l.add_theme_constant_override("shadow_offset_y", shadow)
	return l


static func style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func button(text: String, cb: Callable, fnt: Font, min_size := Vector2(320, 48), font_size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", fnt)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	b.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.2))
	var hot := style(Color(0.15, 0.02, 0.02, 0.7), Color(0.8, 0.2, 0.1, 0.8), 1, 2)
	b.add_theme_stylebox_override("normal", style(Color(0, 0, 0, 0.5), Color(0.4, 0.35, 0.3, 0.4), 1, 2))
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", style(Color(0.3, 0.02, 0.02, 0.8), Color(1, 0.3, 0.2), 1, 2))
	b.pressed.connect(func():
		Sfx.play("ui_click", -4.0)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -10.0))
	return b
