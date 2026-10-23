extends CanvasLayer
## In-game interface: subtitles, objectives, prompts, notes, pause, death & ending screens.

signal resume_requested
signal quit_requested
signal ending_closed

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float fear = 0.0;
uniform float damage = 0.0;
uniform float hidden = 0.0;
uniform float grain = 0.07;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float n = rand(uv * vec2(1600.0, 900.0) + vec2(TIME * 37.0, TIME * 91.0)) - 0.5;
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.32 - fear * 0.1, 0.9, d);
	float pulse = 0.6 + 0.4 * sin(TIME * (4.0 + fear * 6.0));
	vec3 col = mix(vec3(0.0), vec3(0.4, 0.0, 0.0), clamp(fear * vig * pulse * 1.4, 0.0, 1.0));
	float a = vig * (0.8 + fear * 0.2);
	// scanline-ish flicker
	a += (sin(uv.y * 900.0 + TIME * 4.0) * 0.5 + 0.5) * 0.015;
	col += vec3(n) * grain * 3.0;
	a = max(a, abs(n) * grain);
	// locker slits
	if (hidden > 0.5) {
		bool band = uv.y > 0.36 && uv.y < 0.64 && uv.x > 0.2 && uv.x < 0.8;
		float slit = step(0.62, fract(uv.y * 16.0));
		float open = band ? slit : 0.0;
		a = mix(1.0, a, open);
		col = mix(vec3(0.0), col, open);
	}
	col = mix(col, vec3(0.45, 0.0, 0.0), damage);
	a = max(a, damage * 0.85);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
"""

var font_main: Font
var font_type: Font

var overlay: ColorRect
var overlay_mat: ShaderMaterial
var crosshair: Control
var prompt_label: Label
var hint_label: Label
var objective_box: VBoxContainer
var objective_label: Label
var inventory_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: RichTextLabel
var battery_bar: ProgressBar
var battery_label: Label
var stamina_bar: ProgressBar
var note_panel: PanelContainer
var note_title: Label
var note_body: RichTextLabel
var pause_panel: Control
var death_label: Label
var death_sub: Label
var fade_rect: ColorRect
var title_label: Label
var title_sub: Label
var ending_root: Control
var ending_text: RichTextLabel
var save_hint: Label

var _hint_tween: Tween
var _obj_tween: Tween
var _damage := 0.0
var note_open := false
var paused := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_main = _sys_font(["Bahnschrift", "DIN Alternate", "Roboto Condensed", "Arial Narrow", "DejaVu Sans Condensed", "Liberation Sans Narrow", "Arial", "Sans-Serif"])
	font_type = _sys_font(["Courier New", "Courier Prime", "American Typewriter", "Liberation Mono", "DejaVu Sans Mono", "Monospace"])
	_build()
	Game.subtitle_shown.connect(_on_subtitle)
	Game.subtitle_hidden.connect(_on_subtitle_hide)
	Game.objective_changed.connect(_on_objective)
	Game.hint_shown.connect(show_hint)
	Game.inventory_changed.connect(_update_inventory)
	Game.note_opened.connect(_on_note)


func _sys_font(names: Array) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


func _label(text: String, size: int, col := Color.WHITE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else font_main)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4, pad := 14) -> StyleBoxFlat:
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


func _full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(180, 8)
	b.max_value = 100
	b.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.15), 1, 2, 0))
	b.add_theme_stylebox_override("fill", _style(fill, Color(0, 0, 0, 0), 0, 2, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_override("font", font_main)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	b.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.2))
	b.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.5), Color(0.4, 0.35, 0.3, 0.4), 1, 2))
	b.add_theme_stylebox_override("hover", _style(Color(0.15, 0.02, 0.02, 0.7), Color(0.8, 0.2, 0.1, 0.8), 1, 2))
	b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.02, 0.02, 0.8), Color(1, 0.3, 0.2), 1, 2))
	b.add_theme_stylebox_override("focus", _style(Color(0.15, 0.02, 0.02, 0.7), Color(0.8, 0.2, 0.1, 0.8), 1, 2))
	b.pressed.connect(func():
		Sfx.play("ui_click", -4.0)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -10.0))
	return b


func _build() -> void:
	var root := Control.new()
	_full(root)
	add_child(root)

	overlay = ColorRect.new()
	_full(overlay)
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = sh
	overlay.material = overlay_mat
	root.add_child(overlay)

	# crosshair
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.35)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	prompt_label = _label("", 22, Color(0.95, 0.92, 0.85))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.offset_left = -400
	prompt_label.offset_right = 400
	prompt_label.offset_top = 28
	prompt_label.offset_bottom = 60
	root.add_child(prompt_label)

	hint_label = _label("", 22, Color(0.9, 0.85, 0.7))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.offset_left = -500
	hint_label.offset_right = 500
	hint_label.offset_top = 120
	hint_label.offset_bottom = 160
	hint_label.modulate.a = 0.0
	root.add_child(hint_label)

	# objective
	objective_box = VBoxContainer.new()
	objective_box.position = Vector2(36, 30)
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective_box)
	objective_box.add_child(_label("OBJECTIVE", 16, Color(0.85, 0.3, 0.2)))
	objective_label = _label("", 24, Color(0.92, 0.9, 0.84))
	objective_label.custom_minimum_size = Vector2(560, 0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_box.add_child(objective_label)
	inventory_label = _label("", 17, Color(0.6, 0.65, 0.7))
	objective_box.add_child(inventory_label)
	objective_box.modulate.a = 0.0

	# status (bottom right)
	var status := VBoxContainer.new()
	status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	status.offset_left = -240
	status.offset_top = -110
	status.offset_right = -36
	status.offset_bottom = -30
	status.alignment = BoxContainer.ALIGNMENT_END
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Game.touch_mode:
		# keep the bottom-right corner free for the touch buttons
		status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		status.offset_top = 30
		status.offset_bottom = 110
		status.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(status)
	battery_label = _label("FLASHLIGHT", 15, Color(0.7, 0.7, 0.65))
	status.add_child(battery_label)
	battery_bar = _bar(Color(0.95, 0.8, 0.35))
	status.add_child(battery_bar)
	var sl := _label("STAMINA", 15, Color(0.7, 0.7, 0.65))
	status.add_child(sl)
	stamina_bar = _bar(Color(0.75, 0.8, 0.85))
	status.add_child(stamina_bar)

	# subtitles
	subtitle_panel = PanelContainer.new()
	subtitle_panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.62), Color(0, 0, 0, 0), 0, 4, 18))
	subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_panel.offset_left = -520
	subtitle_panel.offset_right = 520
	subtitle_panel.offset_top = -170
	subtitle_panel.offset_bottom = -70
	subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Game.touch_mode:
		# sit between the joystick and the button cluster
		subtitle_panel.offset_left = -470
		subtitle_panel.offset_right = 230
		subtitle_panel.offset_top = -330
		subtitle_panel.offset_bottom = -250
	root.add_child(subtitle_panel)
	subtitle_label = RichTextLabel.new()
	subtitle_label.bbcode_enabled = true
	subtitle_label.fit_content = true
	subtitle_label.scroll_active = false
	subtitle_label.add_theme_font_override("normal_font", font_main)
	subtitle_label.add_theme_font_override("bold_font", font_main)
	subtitle_label.add_theme_font_size_override("normal_font_size", 26)
	subtitle_label.add_theme_font_size_override("bold_font_size", 26)
	subtitle_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.92))
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_panel.add_child(subtitle_label)
	subtitle_panel.modulate.a = 0.0

	# note reader
	note_panel = PanelContainer.new()
	var paper := _style(Color(0.82, 0.78, 0.66), Color(0.3, 0.25, 0.15), 2, 2, 40)
	paper.shadow_color = Color(0, 0, 0, 0.7)
	paper.shadow_size = 30
	note_panel.add_theme_stylebox_override("panel", paper)
	note_panel.set_anchors_preset(Control.PRESET_CENTER)
	note_panel.offset_left = -400
	note_panel.offset_right = 400
	note_panel.offset_top = -340
	note_panel.offset_bottom = 340
	note_panel.visible = false
	root.add_child(note_panel)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 16)
	note_panel.add_child(nv)
	note_title = _label("", 28, Color(0.15, 0.1, 0.05), font_type)
	note_title.remove_theme_color_override("font_shadow_color")
	note_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	nv.add_child(note_title)
	note_body = RichTextLabel.new()
	note_body.bbcode_enabled = true
	note_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note_body.add_theme_font_override("normal_font", font_type)
	note_body.add_theme_font_override("italics_font", font_type)
	note_body.add_theme_font_override("bold_font", font_type)
	note_body.add_theme_font_size_override("normal_font_size", 20)
	note_body.add_theme_font_size_override("italics_font_size", 20)
	note_body.add_theme_font_size_override("bold_font_size", 21)
	note_body.add_theme_color_override("default_color", Color(0.12, 0.1, 0.08))
	nv.add_child(note_body)
	var close := _label("Tap USE to close" if Game.touch_mode else "[E] / [Esc]  Close", 16, Color(0.35, 0.3, 0.25), font_type)
	close.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nv.add_child(close)

	# chapter title
	title_label = _label("", 64, Color(0.85, 0.82, 0.75))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.offset_left = -700
	title_label.offset_right = 700
	title_label.offset_top = -120
	title_label.offset_bottom = -40
	title_label.modulate.a = 0.0
	root.add_child(title_label)
	title_sub = _label("", 24, Color(0.7, 0.3, 0.25))
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub.set_anchors_preset(Control.PRESET_CENTER)
	title_sub.offset_left = -700
	title_sub.offset_right = 700
	title_sub.offset_top = -30
	title_sub.offset_bottom = 10
	title_sub.modulate.a = 0.0
	root.add_child(title_sub)

	save_hint = _label("CHECKPOINT", 16, Color(0.6, 0.6, 0.55))
	save_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	save_hint.offset_left = 36
	save_hint.offset_top = -60
	save_hint.offset_bottom = -30
	save_hint.modulate.a = 0.0
	root.add_child(save_hint)

	# fade
	fade_rect = ColorRect.new()
	_full(fade_rect)
	fade_rect.color = Color(0, 0, 0, 1)
	root.add_child(fade_rect)

	# death
	death_label = _label("YOU WERE COUNTED", 72, Color(0.75, 0.05, 0.03))
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.offset_left = -700
	death_label.offset_right = 700
	death_label.offset_top = -60
	death_label.offset_bottom = 30
	death_label.visible = false
	root.add_child(death_label)
	death_sub = _label("", 22, Color(0.6, 0.55, 0.5))
	death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_sub.set_anchors_preset(Control.PRESET_CENTER)
	death_sub.offset_left = -700
	death_sub.offset_right = 700
	death_sub.offset_top = 40
	death_sub.offset_bottom = 80
	death_sub.visible = false
	root.add_child(death_sub)

	_build_pause(root)
	_build_ending(root)


func _build_pause(root: Control) -> void:
	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0, 0, 0, 0.75)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var t := _label("PAUSED", 56, Color(0.85, 0.8, 0.72))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", func(): resume_requested.emit()))
	var sens_l := _label("Look sensitivity" if Game.touch_mode else "Mouse sensitivity", 18, Color(0.7, 0.68, 0.6))
	v.add_child(sens_l)
	var sens := HSlider.new()
	sens.custom_minimum_size = Vector2(320, 40 if Game.touch_mode else 24)
	if Game.touch_mode:
		sens.min_value = 0.002
		sens.max_value = 0.016
		sens.step = 0.0005
		sens.value = Game.touch_sensitivity
		sens.value_changed.connect(func(v2): Game.touch_sensitivity = v2)
	else:
		sens.min_value = 0.0005
		sens.max_value = 0.006
		sens.step = 0.0001
		sens.value = Game.mouse_sensitivity
		sens.value_changed.connect(func(v2): Game.mouse_sensitivity = v2)
	v.add_child(sens)
	var vol_l := _label("Master volume", 18, Color(0.7, 0.68, 0.6))
	v.add_child(vol_l)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol.custom_minimum_size = Vector2(320, 24)
	vol.value_changed.connect(func(v2): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v2, 0.0001))))
	v.add_child(vol)
	var sub := CheckBox.new()
	sub.text = "Subtitles"
	sub.button_pressed = Game.subtitles_enabled
	sub.add_theme_font_override("font", font_main)
	sub.add_theme_font_size_override("font_size", 20)
	sub.toggled.connect(func(on): Game.subtitles_enabled = on)
	v.add_child(sub)
	var controls := _label("Left side: move  ·  Right side: look  ·  Buttons on the right" if Game.touch_mode else "WASD move  ·  Shift sprint  ·  Ctrl crouch  ·  Space jump\nE interact  ·  F flashlight  ·  R swap battery  ·  Tab objective", 16, Color(0.55, 0.55, 0.5))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(controls)
	v.add_child(_button("Quit to Main Menu", func(): quit_requested.emit()))


func _build_ending(root: Control) -> void:
	ending_root = ColorRect.new()
	(ending_root as ColorRect).color = Color(0, 0, 0, 1)
	ending_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_root.visible = false
	root.add_child(ending_root)
	ending_text = RichTextLabel.new()
	ending_text.bbcode_enabled = true
	ending_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_text.offset_left = 200
	ending_text.offset_right = -200
	ending_text.offset_top = 120
	ending_text.offset_bottom = -120
	ending_text.add_theme_font_override("normal_font", font_main)
	ending_text.add_theme_font_override("bold_font", font_main)
	ending_text.add_theme_font_override("italics_font", font_type)
	ending_text.add_theme_font_size_override("normal_font_size", 26)
	ending_text.add_theme_font_size_override("bold_font_size", 60)
	ending_text.add_theme_font_size_override("italics_font_size", 22)
	ending_text.add_theme_color_override("default_color", Color(0.8, 0.78, 0.72))
	ending_text.scroll_active = false
	ending_root.add_child(ending_text)
	var b := _button("Return to Main Menu", func(): ending_closed.emit())
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -160
	b.offset_right = 160
	b.offset_top = -110
	b.offset_bottom = -62
	b.name = "EndButton"
	ending_root.add_child(b)


# ------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var prompt: String = p.current_prompt
	if Game.touch_mode:
		prompt = prompt.replace("[E] ", "USE: ")
	prompt_label.text = prompt if not note_open and not paused else ""
	crosshair.color.a = 0.85 if p.current_prompt != "" else 0.3
	crosshair.visible = not p.is_hidden()
	battery_bar.value = p.battery
	battery_label.visible = Game.has_flashlight
	battery_bar.visible = Game.has_flashlight
	battery_label.text = "FLASHLIGHT   ·   %d SPARE" % Game.spare_batteries if Game.has_flashlight else ""
	stamina_bar.value = p.stamina
	stamina_bar.modulate.a = lerpf(stamina_bar.modulate.a, 1.0 if p.stamina < 99.0 else 0.25, delta * 4.0)
	_damage = maxf(0.0, _damage - delta * 0.5)
	overlay_mat.set_shader_parameter("fear", p.fear)
	overlay_mat.set_shader_parameter("hidden", 1.0 if p.is_hidden() else 0.0)
	overlay_mat.set_shader_parameter("damage", _damage)
	if Input.is_action_pressed("objectives") and not paused:
		objective_box.modulate.a = lerpf(objective_box.modulate.a, 1.0, delta * 10.0)
	elif _obj_tween == null or not _obj_tween.is_running():
		objective_box.modulate.a = lerpf(objective_box.modulate.a, 0.35 if Game.objective != "" else 0.0, delta * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if note_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		close_note()
		get_viewport().set_input_as_handled()
	elif paused and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


# ------------------------------------------------------------ events
func _on_subtitle(speaker: String, text: String, col: Color) -> void:
	if not Game.subtitles_enabled:
		return
	var hex := col.to_html(false)
	subtitle_label.text = "[b][color=#%s]%s:[/color][/b]  %s" % [hex, speaker, text]
	var tw := create_tween()
	tw.tween_property(subtitle_panel, "modulate:a", 1.0, 0.15)


func _on_subtitle_hide() -> void:
	var tw := create_tween()
	tw.tween_property(subtitle_panel, "modulate:a", 0.0, 0.25)


func _on_objective(text: String) -> void:
	objective_label.text = text
	_update_inventory()
	if _obj_tween:
		_obj_tween.kill()
	_obj_tween = create_tween()
	_obj_tween.tween_property(objective_box, "modulate:a", 1.0, 0.4)
	_obj_tween.tween_interval(6.0)
	_obj_tween.tween_property(objective_box, "modulate:a", 0.35, 1.5)


func _update_inventory() -> void:
	var parts: Array[String] = []
	if Game.fuses_found > 0 or Game.fuses_inserted > 0:
		parts.append("Fuses: %d" % (Game.fuses_found - Game.fuses_inserted))
	if Game.has_keycard:
		parts.append("Keycard")
	if Game.has_flashlight:
		parts.append("Batteries: %d" % Game.spare_batteries)
	inventory_label.text = "   ·   ".join(parts)


func show_hint(text: String, dur := 3.5) -> void:
	hint_label.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.2)
	_hint_tween.tween_interval(dur)
	_hint_tween.tween_property(hint_label, "modulate:a", 0.0, 0.8)


func show_checkpoint() -> void:
	var tw := create_tween()
	tw.tween_property(save_hint, "modulate:a", 0.9, 0.4)
	tw.tween_interval(2.0)
	tw.tween_property(save_hint, "modulate:a", 0.0, 1.0)


func _on_note(title: String, body: String) -> void:
	note_title.text = title
	note_body.text = body
	note_panel.visible = true
	note_open = true
	get_tree().paused = true


func close_note() -> void:
	note_panel.visible = false
	note_open = false
	Sfx.play("paper", -10.0, 1.2)
	get_tree().paused = false


func flash_damage(amount := 1.0) -> void:
	_damage = amount


func fade(to_alpha: float, dur: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to_alpha, dur)
	return tw


func show_title(text: String, sub: String, hold := 3.0) -> void:
	title_label.text = text
	title_sub.text = sub
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(title_label, "modulate:a", 1.0, 1.5)
	tw.tween_property(title_sub, "modulate:a", 1.0, 2.0)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(title_label, "modulate:a", 0.0, 1.5)
	tw.parallel().tween_property(title_sub, "modulate:a", 0.0, 1.5)


func show_death(visible_now: bool) -> void:
	death_label.visible = visible_now
	death_sub.visible = visible_now
	if visible_now:
		var lines := [
			"The Foreman counted you.",
			"Fifteen.",
			"Clock in. Every shift. Every worker.",
			"It heard you breathing.",
			"Keep to the dark. Keep quiet.",
		]
		death_sub.text = lines[Game.deaths % lines.size()]
		death_label.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(death_label, "modulate:a", 1.0, 0.8)


func set_paused(on: bool) -> void:
	paused = on
	pause_panel.visible = on


func show_ending(text: String) -> void:
	ending_root.visible = true
	ending_text.text = text
	ending_text.visible_ratio = 0.0
	ending_root.get_node("EndButton").visible = false
	var tw := create_tween()
	tw.tween_property(ending_text, "visible_ratio", 1.0, 14.0)
	tw.tween_callback(func(): ending_root.get_node("EndButton").visible = true)
