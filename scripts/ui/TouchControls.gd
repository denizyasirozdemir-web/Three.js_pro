extends CanvasLayer
## On-screen controls for phones and tablets (iPhone/iPad via Xogot, Android).
## Left side: floating move joystick. Right side: drag to look.
## Icon buttons drawn in code: amber-rimmed steel discs that match the plant's hazard paint.

const JOY_RADIUS := 115.0

const AMBER := Color(0.88, 0.66, 0.16)
const RED := Color(0.85, 0.18, 0.1)
const GLASS := Color(0.05, 0.05, 0.06, 0.58)
const GLASS_DOWN := Color(0.35, 0.24, 0.04, 0.7)
const INK := Color(0.93, 0.9, 0.82)

# id, action, kind, offset from bottom-right corner, radius, label
const BTN := [
	["use", "interact", "tap", Vector2(-175, -185), 80.0, "USE"],
	["run", "sprint", "hold", Vector2(-345, -112), 58.0, "RUN"],
	["crouch", "crouch", "toggle", Vector2(-350, -282), 52.0, "CROUCH"],
	["light", "flashlight", "tap", Vector2(-205, -372), 54.0, "LIGHT"],
	["batt", "reload", "tap", Vector2(-70, -335), 42.0, "BATTERY"],
	["jump", "jump", "tap", Vector2(-488, -82), 44.0, "JUMP"],
]
# top bar buttons: id, action, offset from top-center, half size
const TOP := [
	["obj", "", Vector2(-48, 46), 30.0],
	["pause", "pause", Vector2(48, 46), 30.0],
]

var _canvas: Control
var _font: Font
var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _btn_touch := {}   # touch index -> button index
var _btn_down := {}    # button index -> bool
var _scale := {}       # button index -> animated press scale
var _top_flash := {}
var _t := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = preload("res://scripts/ui/UI.gd").font(preload("res://scripts/ui/UI.gd").MAIN_FONTS, 600)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	for i in range(BTN.size()):
		_scale[i] = 1.0


# ------------------------------------------------------------ geometry
func _screen() -> Vector2:
	return _canvas.get_viewport_rect().size


func _btn_center(i: int) -> Vector2:
	var s := _screen()
	return Vector2(s.x, s.y) + BTN[i][3]


func _top_center(i: int) -> Vector2:
	return Vector2(_screen().x * 0.5, 0) + TOP[i][2]


func _button_at(pos: Vector2) -> int:
	var best := -1
	var bd := INF
	for i in range(BTN.size()):
		var d := pos.distance_to(_btn_center(i))
		if d <= BTN[i][4] * 1.18 and d < bd:
			best = i
			bd = d
	return best


func _top_at(pos: Vector2) -> int:
	for i in range(TOP.size()):
		var c := _top_center(i)
		if absf(pos.x - c.x) <= TOP[i][3] * 1.3 and absf(pos.y - c.y) <= TOP[i][3] * 1.3:
			return i
	return -1


# ------------------------------------------------------------ input
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _buzz(ms := 18) -> void:
	Input.vibrate_handheld(ms)


func _input(event: InputEvent) -> void:
	if not Game.touch_mode or not visible:
		return
	var paused := get_tree().paused
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			var t := _top_at(pos)
			if t != -1:
				_press_top(t)
				get_viewport().set_input_as_handled()
				return
			var b := _button_at(pos)
			if b != -1:
				_press_button(b, event.index)
				if not paused:
					get_viewport().set_input_as_handled()
				return
			if paused:
				return
			if pos.x < _screen().x * 0.42 and _joy_index == -1:
				_joy_index = event.index
				_joy_center = pos
				_joy_pos = pos
			elif _look_index == -1:
				_look_index = event.index
			get_viewport().set_input_as_handled()
		else:
			if _btn_touch.has(event.index):
				_release_button(_btn_touch[event.index])
				_btn_touch.erase(event.index)
			if event.index == _joy_index:
				_joy_index = -1
				Game.touch_move = Vector2.ZERO
			if event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if paused:
			return
		if event.index == _joy_index:
			_joy_pos = event.position
			# the base follows the thumb if it drifts too far, like most mobile shooters
			var off: Vector2 = _joy_pos - _joy_center
			if off.length() > JOY_RADIUS * 1.35:
				_joy_center = _joy_pos - off.normalized() * JOY_RADIUS * 1.35
			Game.touch_move = ((_joy_pos - _joy_center) / JOY_RADIUS).limit_length(1.0)
			get_viewport().set_input_as_handled()
		elif event.index == _look_index:
			Game.touch_look += event.relative
			get_viewport().set_input_as_handled()


func _press_button(i: int, index: int) -> void:
	var action: String = BTN[i][1]
	_buzz()
	match BTN[i][2]:
		"tap":
			_send(action, true)
			_send(action, false)
			_btn_down[i] = true
			get_tree().create_timer(0.14, true).timeout.connect(func(): _btn_down[i] = false)
		"hold":
			_send(action, true)
			_btn_down[i] = true
			_btn_touch[index] = i
		"toggle":
			Game.touch_crouch = not Game.touch_crouch


func _release_button(i: int) -> void:
	if BTN[i][2] == "hold":
		_send(BTN[i][1], false)
		_btn_down[i] = false


func _press_top(i: int) -> void:
	_buzz(12)
	_top_flash[i] = 0.25
	match TOP[i][0]:
		"pause":
			_send("pause", true)
			_send("pause", false)
		"obj":
			if Game.objective != "":
				Game.objective_changed.emit(Game.objective)


func _process(delta: float) -> void:
	_t += delta
	var p = Game.player
	visible = Game.touch_mode and p != null and is_instance_valid(p) and not p.dead and not _ending_shown()
	if get_tree().paused and _joy_index != -1:
		_joy_index = -1
		Game.touch_move = Vector2.ZERO
	for i in range(BTN.size()):
		var down: bool = _is_down(i)
		_scale[i] = lerpf(_scale[i], 0.88 if down else 1.0, minf(1.0, delta * 18.0))
	for k in _top_flash.keys():
		_top_flash[k] = maxf(0.0, _top_flash[k] - delta)
	_canvas.queue_redraw()


func _ending_shown() -> bool:
	var w = Game.world
	return w != null and w.get("_ending") == true


func _is_down(i: int) -> bool:
	if BTN[i][2] == "toggle":
		return Game.touch_crouch
	return _btn_down.get(i, false)


# ------------------------------------------------------------ drawing
func _on_draw() -> void:
	var c := _canvas
	var paused := get_tree().paused
	_draw_top_bar(c)
	if paused:
		return
	_draw_joystick(c)
	for i in range(BTN.size()):
		_draw_button(c, i)


func _ring(c: Control, center: Vector2, r: float, col: Color, w: float, from := 0.0, to := TAU) -> void:
	c.draw_arc(center, r, from, to, maxi(12, int(r * 0.8)), col, w, true)


func _label(c: Control, pos: Vector2, text: String, size: int, col: Color, width := 200.0) -> void:
	c.draw_string(_font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _draw_top_bar(c: Control) -> void:
	for i in range(TOP.size()):
		var ctr := _top_center(i)
		var h: float = TOP[i][3]
		var rect := Rect2(ctr - Vector2(h, h), Vector2(h, h) * 2.0)
		var flash: float = _top_flash.get(i, 0.0) * 4.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = GLASS.lerp(GLASS_DOWN, clampf(flash, 0, 1))
		sb.border_color = Color(AMBER, 0.5)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		c.draw_style_box(sb, rect)
		var ink := Color(INK, 0.9)
		match TOP[i][0]:
			"pause":
				c.draw_rect(Rect2(ctr + Vector2(-9, -11), Vector2(6, 22)), ink)
				c.draw_rect(Rect2(ctr + Vector2(3, -11), Vector2(6, 22)), ink)
			"obj":
				# clipboard with three lines
				var b := Rect2(ctr + Vector2(-11, -13), Vector2(22, 27))
				c.draw_rect(b, ink, false, 2.5)
				c.draw_rect(Rect2(ctr + Vector2(-5, -16), Vector2(10, 6)), ink)
				for k in range(3):
					c.draw_line(ctr + Vector2(-6, -4 + k * 6), ctr + Vector2(6, -4 + k * 6), ink, 2.0)


func _draw_joystick(c: Control) -> void:
	var s := _screen()
	if _joy_index != -1:
		var ctr := _joy_center
		c.draw_circle(ctr, JOY_RADIUS, Color(0, 0, 0, 0.28))
		_ring(c, ctr, JOY_RADIUS, Color(AMBER, 0.45), 3.0)
		_ring(c, ctr, JOY_RADIUS * 0.55, Color(1, 1, 1, 0.08), 2.0)
		# tick marks
		for k in range(16):
			var a := TAU * k / 16.0
			var l := 12.0 if k % 4 == 0 else 6.0
			var d := Vector2(cos(a), sin(a))
			c.draw_line(ctr + d * (JOY_RADIUS - l), ctr + d * JOY_RADIUS, Color(AMBER, 0.5 if k % 4 == 0 else 0.25), 2.0, true)
		var off := (_joy_pos - ctr).limit_length(JOY_RADIUS)
		var amt := off.length() / JOY_RADIUS
		# direction arc lights up toward the push
		if amt > 0.15:
			var ang := off.angle()
			_ring(c, ctr, JOY_RADIUS + 7, Color(AMBER, 0.35 + amt * 0.5), 5.0, ang - 0.5, ang + 0.5)
		var knob := ctr + off
		c.draw_circle(knob + Vector2(0, 4), 50, Color(0, 0, 0, 0.35))
		c.draw_circle(knob, 50, Color(0.16, 0.15, 0.13, 0.92))
		c.draw_circle(knob, 38, Color(0.24, 0.22, 0.19, 0.95))
		_ring(c, knob, 50, Color(AMBER, 0.85), 3.0)
		# grip dimples
		for k in range(3):
			c.draw_circle(knob + Vector2(-12 + k * 12, 0), 3.5, Color(0, 0, 0, 0.45))
	else:
		var hint := Vector2(maxf(190.0, s.x * 0.13), s.y - 190.0)
		var a := 0.16 + 0.06 * sin(_t * 2.0)
		_ring(c, hint, JOY_RADIUS, Color(AMBER, a), 2.0)
		c.draw_circle(hint, 34, Color(1, 1, 1, a * 0.4))
		for k in range(4):
			var ang := TAU * k / 4.0 - PI / 2
			var d := Vector2(cos(ang), sin(ang))
			var tip := hint + d * (JOY_RADIUS - 22)
			var side := Vector2(-d.y, d.x) * 9.0
			c.draw_colored_polygon(PackedVector2Array([tip + d * 10, tip + side, tip - side]), Color(INK, a + 0.1))
		_label(c, hint + Vector2(0, JOY_RADIUS + 34), "MOVE", 20, Color(INK, a + 0.15))
		_label(c, Vector2(s.x * 0.62, s.y * 0.2), "drag to look", 18, Color(INK, 0.12 + 0.04 * sin(_t * 2.0)), 300)


func _draw_button(c: Control, i: int) -> void:
	var p = Game.player
	var id: String = BTN[i][0]
	var r: float = BTN[i][4] * _scale[i]
	var ctr := _btn_center(i)
	var down := _is_down(i)
	var rim := Color(AMBER, 0.6)
	var fill := GLASS_DOWN if down else GLASS
	var active := false
	var verb: String = BTN[i][5]

	if id == "use" and p and p.current_prompt != "":
		active = true
		var pr: String = p.current_prompt.replace("[E] ", "")
		verb = pr.split(" ")[0].to_upper()
	if id == "run" and p and p.exhausted:
		rim = Color(RED, 0.7)
	if id == "light" and p and p.flashlight_on:
		active = true

	# drop shadow & body
	c.draw_circle(ctr + Vector2(0, 5), r, Color(0, 0, 0, 0.35))
	c.draw_circle(ctr, r, fill)
	c.draw_circle(ctr, r * 0.82, Color(1, 1, 1, 0.03))
	_ring(c, ctr, r, rim, 3.0)

	# pulsing halo when the button does something right now
	if active:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		_ring(c, ctr, r + 6 + pulse * 5, Color(AMBER, 0.25 + 0.35 * (1.0 - pulse)), 3.0)
	# gauges on the rim
	if id == "run" and p:
		var frac: float = p.stamina / 100.0
		_ring(c, ctr, r - 7, Color(0, 0, 0, 0.4), 6.0)
		_ring(c, ctr, r - 7, (RED if p.exhausted else Color(0.75, 0.85, 0.9, 0.9)), 6.0, -PI / 2, -PI / 2 + TAU * frac)
	if id == "light" and p:
		var frac2: float = p.battery / 100.0
		_ring(c, ctr, r - 7, Color(0, 0, 0, 0.4), 6.0)
		var bcol := AMBER if frac2 > 0.25 else RED
		_ring(c, ctr, r - 7, Color(bcol, 0.9), 6.0, -PI / 2, -PI / 2 + TAU * frac2)

	# icon
	var ink := Color(INK, 0.95 if (active or down) else 0.82)
	var k := r / 50.0
	var ic := ctr + Vector2(0, -6 * k)
	match id:
		"use":
			_icon_hand(c, ic + Vector2(0, -6 * k), k * 1.05, AMBER if active else ink)
		"run":
			_icon_runner(c, ic, k, ink)
		"crouch":
			_icon_crouch(c, ic, k, ink)
		"light":
			_icon_flashlight(c, ic, k, ink, p != null and p.flashlight_on)
		"batt":
			_icon_battery(c, ic, k, ink)
		"jump":
			_icon_jump(c, ic, k, ink)

	# caption
	var fs := int(clampf(r * 0.24, 12, 22))
	_label(c, ctr + Vector2(0, r * 0.62), verb, fs, Color(AMBER if active else INK, 0.9), r * 2.2)

	# badge: spare batteries
	if id == "batt":
		var n := Game.spare_batteries
		var bp := ctr + Vector2(r * 0.72, -r * 0.72)
		c.draw_circle(bp, 15, RED if n == 0 else AMBER)
		_label(c, bp + Vector2(0, 7), str(n), 19, Color(0.08, 0.06, 0.04), 30)


# ------------------------------------------------------------ icons (unit ~ 50px radius)
func _thick(c: Control, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	c.draw_line(a, b, col, w, true)
	c.draw_circle(a, w * 0.5, col)
	c.draw_circle(b, w * 0.5, col)


func _icon_hand(c: Control, o: Vector2, k: float, col: Color) -> void:
	# open palm reaching out
	var palm := Rect2(o + Vector2(-13, -2) * k, Vector2(26, 22) * k)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(8 * k))
	sb.anti_aliasing = true
	c.draw_style_box(sb, palm)
	var w := 6.5 * k
	for f in range(4):
		var x := (-9.75 + f * 6.5) * k
		var top := (-22.0 if f in [1, 2] else -18.0) * k
		_thick(c, o + Vector2(x, 0), o + Vector2(x, top), w, col)
	_thick(c, o + Vector2(-12, 12) * k, o + Vector2(-21, 2) * k, w, col)  # thumb


func _icon_runner(c: Control, o: Vector2, k: float, col: Color) -> void:
	var w := 5.0 * k
	c.draw_circle(o + Vector2(6, -20) * k, 5.5 * k, col)
	var hip := o + Vector2(-2, 4) * k
	var neck := o + Vector2(4, -12) * k
	_thick(c, neck, hip, w, col)
	_thick(c, neck + Vector2(0, 3) * k, o + Vector2(14, -2) * k, w, col)
	_thick(c, neck + Vector2(0, 3) * k, o + Vector2(-10, -6) * k, w, col)
	_thick(c, hip, o + Vector2(10, 14) * k, w, col)
	_thick(c, o + Vector2(10, 14) * k, o + Vector2(6, 22) * k, w, col)
	_thick(c, hip, o + Vector2(-10, 14) * k, w, col)
	_thick(c, o + Vector2(-10, 14) * k, o + Vector2(-18, 12) * k, w, col)
	for m in range(3):
		c.draw_line(o + Vector2(-26, -10 + m * 8) * k, o + Vector2(-18, -10 + m * 8) * k, Color(col, 0.5), 2.0 * k, true)


func _icon_crouch(c: Control, o: Vector2, k: float, col: Color) -> void:
	var w := 5.0 * k
	c.draw_circle(o + Vector2(8, -12) * k, 5.5 * k, col)
	var hip := o + Vector2(-8, 6) * k
	_thick(c, o + Vector2(4, -4) * k, hip, w, col)
	_thick(c, hip, o + Vector2(6, 10) * k, w, col)
	_thick(c, o + Vector2(6, 10) * k, o + Vector2(2, 20) * k, w, col)
	_thick(c, o + Vector2(2, -2) * k, o + Vector2(14, 6) * k, w, col)
	# "quiet" chevron above
	c.draw_polyline(PackedVector2Array([o + Vector2(-16, -22) * k, o + Vector2(-10, -16) * k, o + Vector2(-4, -22) * k]), Color(col, 0.6), 2.5 * k, true)


func _icon_flashlight(c: Control, o: Vector2, k: float, col: Color, on: bool) -> void:
	var rot := -0.6
	var xf := Transform2D(rot, o)
	var body := PackedVector2Array([Vector2(-20, -5), Vector2(4, -5), Vector2(4, 5), Vector2(-20, 5)])
	var head := PackedVector2Array([Vector2(4, -6), Vector2(14, -11), Vector2(14, 11), Vector2(4, 6)])
	for poly in [body, head]:
		var pts := PackedVector2Array()
		for v in poly:
			pts.append(xf * (v * k))
		c.draw_colored_polygon(pts, col)
	c.draw_line(xf * (Vector2(-10, -5) * k), xf * (Vector2(-10, 5) * k), Color(0, 0, 0, 0.5), 2.0 * k)
	if on:
		for a in [-0.35, 0.0, 0.35]:
			var d := Vector2(cos(a), sin(a))
			_thick(c, xf * (Vector2(18, 0) * k + d * 4 * k), xf * (Vector2(18, 0) * k + d * 14 * k), 3.0 * k, Color(AMBER, 0.95))


func _icon_battery(c: Control, o: Vector2, k: float, col: Color) -> void:
	var r := Rect2(o + Vector2(-16, -9) * k, Vector2(28, 18) * k)
	c.draw_rect(r, col, false, 3.0 * k)
	c.draw_rect(Rect2(o + Vector2(12, -4) * k, Vector2(4, 8) * k), col)
	for m in range(3):
		c.draw_rect(Rect2(o + Vector2(-12 + m * 8, -5) * k, Vector2(5, 10) * k), Color(col, 0.85))


func _icon_jump(c: Control, o: Vector2, k: float, col: Color) -> void:
	var w := 5.0 * k
	c.draw_polyline(PackedVector2Array([o + Vector2(-12, -2) * k, o + Vector2(0, -16) * k, o + Vector2(12, -2) * k]), col, w, true)
	_thick(c, o + Vector2(0, -14) * k, o + Vector2(0, 10) * k, w, col)
	_thick(c, o + Vector2(-14, 16) * k, o + Vector2(14, 16) * k, w * 0.7, Color(col, 0.6))
