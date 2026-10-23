extends Control
## Title screen, how-to-play panel and the story intro before the game starts.

const BG_SHADER := """
shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; } return v; }
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.03;
	float fog = fbm(uv * vec2(3.0, 2.0) + vec2(t, t * 0.4));
	fog = fog * fbm(uv * 5.0 - vec2(t * 1.7, 0.0));
	// factory silhouette
	float sil = 0.0;
	float base = 0.28 + 0.03 * step(0.5, fract(uv.x * 7.0));
	if (uv.y > 1.0 - base) sil = 1.0;
	for (int i = 0; i < 4; i++) {
		float x = 0.15 + float(i) * 0.09;
		if (abs(uv.x - x) < 0.012 && uv.y > 0.35) sil = 1.0;
	}
	vec3 sky = mix(vec3(0.05, 0.02, 0.02), vec3(0.0), uv.y);
	vec3 col = sky + vec3(0.25, 0.22, 0.2) * fog * 0.6;
	// red glow from the furnace windows
	float win = step(0.75, fract(uv.x * 22.0)) * step(0.74, uv.y) * step(uv.y, 0.77);
	float flick = 0.6 + 0.4 * sin(TIME * 7.0 + uv.x * 40.0) * sin(TIME * 3.1);
	col = mix(col, vec3(0.01), sil);
	col += vec3(0.8, 0.15, 0.03) * win * flick * (1.0 - step(0.58, uv.x));
	float d = distance(uv, vec2(0.5));
	col *= 1.0 - smoothstep(0.3, 0.9, d);
	float g = hash(uv * 900.0 + TIME * 50.0) - 0.5;
	col += g * 0.05;
	COLOR = vec4(col, 1.0);
}
"""

const INTRO := [
	"In October 1986, fourteen workers vanished during the night shift\nat Kessler Ironworks, Plant 9.",
	"The company blamed a gas leak.\nThe plant was sealed. Nobody went back.",
	"Forty years later, the site is scheduled for demolition.",
	"You are a contract electrician.\nYour job is simple: get the power back on\nbefore the survey crew arrives at dawn.",
	"Dispatch will guide you over the radio.",
	"Don't let the night shift count you.",
]

var font_main: Font
var title: Label
var menu_box: VBoxContainer
var help_panel: Control
var intro_label: Label
var _title_t := 0.0
var _intro_running := false
var _skip := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	font_main = SystemFont.new()
	(font_main as SystemFont).font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "Liberation Sans Narrow", "Arial", "Sans-Serif"])

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BG_SHADER
	sm.shader = sh
	bg.material = sm
	add_child(bg)

	title = _label("KESSLER WORKS", 110, Color(0.82, 0.78, 0.7))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -700
	title.offset_right = 700
	title.offset_top = 110
	title.offset_bottom = 240
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := _label("P L A N T   9", 30, Color(0.75, 0.15, 0.1))
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -700
	sub.offset_right = 700
	sub.offset_top = 240
	sub.offset_bottom = 290
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	menu_box = VBoxContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.offset_left = -170
	menu_box.offset_right = 170
	menu_box.offset_top = 10
	menu_box.offset_bottom = 260
	menu_box.add_theme_constant_override("separation", 14)
	add_child(menu_box)
	menu_box.add_child(_button("Clock In", _start))
	menu_box.add_child(_button("How to Play", func(): help_panel.visible = true))
	menu_box.add_child(_button("Quit", func(): get_tree().quit()))

	var foot := _label("Headphones recommended.  ·  Play in the dark.", 18, Color(0.5, 0.48, 0.44))
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_left = -500
	foot.offset_right = 500
	foot.offset_top = -60
	foot.offset_bottom = -30
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)

	_build_help()

	intro_label = _label("", 32, Color(0.85, 0.82, 0.75))
	intro_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.visible = false
	add_child(intro_label)

	Sfx.play_music("menu_music", 3.0, -2.0)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_main)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 54)
	b.add_theme_font_override("font", font_main)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	b.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.2))
	b.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.45), Color(0.4, 0.35, 0.3, 0.35)))
	b.add_theme_stylebox_override("hover", _style(Color(0.15, 0.02, 0.02, 0.7), Color(0.8, 0.2, 0.1, 0.8)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.02, 0.02, 0.8), Color(1, 0.3, 0.2)))
	b.add_theme_stylebox_override("focus", _style(Color(0.15, 0.02, 0.02, 0.7), Color(0.8, 0.2, 0.1, 0.8)))
	b.pressed.connect(func():
		Sfx.play("ui_click", -4.0)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -10.0))
	return b


func _build_help() -> void:
	help_panel = ColorRect.new()
	(help_panel as ColorRect).color = Color(0, 0, 0, 0.88)
	help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_panel.visible = false
	add_child(help_panel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_panel.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	c.add_child(v)
	var h := _label("HOW TO SURVIVE THE NIGHT SHIFT", 40, Color(0.85, 0.3, 0.2))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var txt := _label(
		"W A S D  —  Move                    Mouse  —  Look\n" +
		"Shift  —  Sprint (loud)               Ctrl / C  —  Crouch (silent)\n" +
		"E / Left Click  —  Interact          Space  —  Jump\n" +
		"F / Right Click  —  Flashlight       R  —  Swap battery\n" +
		"Tab  —  Show objective                Esc  —  Pause\n\n" +
		"• Something walks the plant. It hears running and sees light.\n" +
		"• Crouch to move silently. Turn the flashlight off when it's near.\n" +
		"• Hide in lockers — but never let it see you climb in.\n" +
		"• Read the documents you find. The plant remembers what happened.\n" +
		"• Your progress is saved at checkpoints when you complete objectives.",
		22, Color(0.78, 0.75, 0.7))
	v.add_child(txt)
	var back := _button("Back", func(): help_panel.visible = false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _process(delta: float) -> void:
	_title_t += delta
	# broken neon flicker on the title
	var f := 1.0
	if fmod(_title_t, 5.3) < 0.15 or (fmod(_title_t, 2.7) < 0.05):
		f = randf_range(0.2, 0.7)
	title.modulate = Color(f, f, f, 1)


func _unhandled_input(event: InputEvent) -> void:
	if _intro_running and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_skip = true


func _start() -> void:
	if _intro_running:
		return
	_intro_running = true
	menu_box.visible = false
	Sfx.play("stinger_low", -8.0)
	var tw := create_tween()
	for c in get_children():
		if c != intro_label and c is CanvasItem and c.get_index() > 0:
			tw.parallel().tween_property(c, "modulate:a", 0.0, 1.5)
	await tw.finished
	Sfx.stop_music(4.0)
	intro_label.visible = true
	for line in INTRO:
		if _skip:
			break
		intro_label.text = line
		intro_label.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(intro_label, "modulate:a", 1.0, 1.2)
		t.tween_interval(2.2 + line.length() * 0.02)
		t.tween_property(intro_label, "modulate:a", 0.0, 1.0)
		while t.is_running() and not _skip:
			await get_tree().process_frame
		t.kill()
	intro_label.modulate.a = 1.0
	intro_label.text = "Loading Plant 9..."
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/World.tscn")
