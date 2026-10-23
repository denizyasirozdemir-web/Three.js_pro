extends Node
## Global game state, objectives, subtitles and input setup.

signal subtitle_shown(speaker: String, text: String, color: Color)
signal subtitle_hidden
signal subtitles_finished
signal objective_changed(text: String)
signal hint_shown(text: String)
signal inventory_changed
signal noise_made(pos: Vector3, radius: float)
signal note_opened(title: String, body: String)

const SPEAKER_COLORS := {
	"HARLAN": Color(1.0, 0.72, 0.3),
	"YOU": Color(0.85, 0.9, 1.0),
	"???": Color(0.9, 0.15, 0.12),
	"MARIA": Color(0.5, 0.85, 1.0),
	"PA SYSTEM": Color(0.7, 1.0, 0.6),
}

# --- settings
var mouse_sensitivity := 0.0022
var subtitles_enabled := true
var touch_sensitivity := 0.006

# --- touch input (iPhone / iPad / Android)
var touch_mode := false
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_crouch := false

# --- run state
var has_flashlight := false
var has_keycard := false
var fuses_found := 0
var fuses_inserted := 0
var spare_batteries := 0
var power_on := false
var generator_on := false
var finale := false
var notes_read: Array[String] = []
var flags := {}
var deaths := 0
var play_time := 0.0
var objective := ""

var checkpoint_pos := Vector3.ZERO
var checkpoint_yaw := 0.0

var player: Node = null
var monster: Node = null
var world: Node = null

# --- subtitle queue
var _queue: Array = []
var _line_time := 0.0
var _showing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func _setup_input() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL, KEY_C],
		"interact": [KEY_E],
		"flashlight": [KEY_F],
		"reload": [KEY_R],
		"objectives": [KEY_TAB],
		"pause": [KEY_ESCAPE, KEY_P],
		"jump": [KEY_SPACE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# mouse buttons (not on touch screens: taps are emulated as clicks there)
	if touch_mode:
		return
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interact", lmb)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("flashlight", rmb)


func new_game() -> void:
	has_flashlight = false
	has_keycard = false
	fuses_found = 0
	fuses_inserted = 0
	spare_batteries = 0
	power_on = false
	generator_on = false
	finale = false
	notes_read.clear()
	flags.clear()
	deaths = 0
	play_time = 0.0
	objective = ""
	_queue.clear()
	_showing = false
	touch_move = Vector2.ZERO
	touch_look = Vector2.ZERO
	touch_crouch = false


func _process(delta: float) -> void:
	if world != null and not get_tree().paused:
		play_time += delta
	_update_subtitles(delta)


# ------------------------------------------------------------ subtitles
## Queue a subtitle line. kind: "radio" plays radio chatter, "creepy" a distorted voice,
## "thought" is silent internal monologue.
func say(speaker: String, text: String, kind := "radio", duration := -1.0) -> void:
	if duration < 0.0:
		duration = clampf(1.6 + text.length() * 0.058, 2.2, 9.0)
	_queue.append({"speaker": speaker, "text": text, "kind": kind, "duration": duration})


func say_lines(lines: Array) -> void:
	for l in lines:
		say(l[0], l[1], l[2] if l.size() > 2 else "radio")


func clear_subtitles() -> void:
	_queue.clear()
	_showing = false
	_line_time = 0.0
	Sfx.stop_voice()
	subtitle_hidden.emit()


func is_talking() -> bool:
	return _showing or not _queue.is_empty()


func _update_subtitles(delta: float) -> void:
	if get_tree().paused:
		return
	if _showing:
		_line_time -= delta
		if _line_time <= 0.0:
			_showing = false
			Sfx.stop_voice()
			subtitle_hidden.emit()
			if _queue.is_empty():
				subtitles_finished.emit()
	if not _showing and not _queue.is_empty():
		var line: Dictionary = _queue.pop_front()
		_showing = true
		_line_time = line.duration
		var col: Color = SPEAKER_COLORS.get(line.speaker, Color.WHITE)
		match line.kind:
			"radio":
				Sfx.play_voice(false, line.duration)
			"creepy":
				Sfx.play_voice(true, line.duration)
				col = SPEAKER_COLORS["???"]
		subtitle_shown.emit(line.speaker, line.text, col)


# ------------------------------------------------------------ objectives & misc
func set_objective(text: String, play_sound := true) -> void:
	objective = text
	objective_changed.emit(text)
	if play_sound:
		Sfx.play("objective", -6.0)


func hint(text: String) -> void:
	hint_shown.emit(text)


func make_noise(pos: Vector3, radius: float) -> void:
	noise_made.emit(pos, radius)


func open_note(id: String, title: String, body: String) -> void:
	if not notes_read.has(id):
		notes_read.append(id)
	note_opened.emit(title, body)


func set_checkpoint(pos: Vector3, yaw: float) -> void:
	checkpoint_pos = pos
	checkpoint_yaw = yaw


func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]
