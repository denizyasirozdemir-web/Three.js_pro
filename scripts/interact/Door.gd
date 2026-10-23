extends AnimatableBody3D
## Industrial sliding door. Can be locked by a requirement ("power", "keycard", "never").

@export var width := 3.0
@export var height := 3.5
## "" = always unlocked, "power", "keycard", "finale" or "never"
@export var requirement := ""
@export var locked_message := "It's locked."
@export var slide_axis := Vector3.RIGHT
## Big loading bay shutters roll up instead of sliding sideways.
@export var big_shutter := false
@export var _status_mat: StandardMaterial3D
var is_open := false
var on_opened: Callable

var _closed_pos := Vector3.ZERO
var _tween: Tween
var _busy := false


func setup(p_width: float, p_height: float, axis: Vector3, panel_mat: Material, p_req := "", p_msg := "It's locked.") -> void:
	width = p_width
	height = p_height
	slide_axis = axis
	requirement = p_req
	locked_message = p_msg
	collision_layer = 2
	collision_mask = 0
	sync_to_physics = false
	var thickness := 0.18
	var along_x := absf(axis.x) > 0.5
	var size := Vector3(width, height, thickness) if along_x else Vector3(thickness, height, width)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = height * 0.5
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = panel_mat
	mi.position.y = height * 0.5
	add_child(mi)
	# horizontal ribs make it read as a heavy steel door
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Color(0.2, 0.2, 0.2)
	rib_mat.metallic = 0.8
	rib_mat.roughness = 0.5
	var ribs := int(height / 0.6)
	for i in range(ribs):
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(width * 0.95, 0.06, thickness + 0.06) if along_x else Vector3(thickness + 0.06, 0.06, width * 0.95)
		r.mesh = rm
		r.material_override = rib_mat
		r.position.y = 0.3 + i * 0.6
		add_child(r)
	# status lamp
	_status_mat = StandardMaterial3D.new()
	_status_mat.emission_enabled = true
	_status_mat.emission_energy_multiplier = 3.0
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	lamp.mesh = sm
	lamp.material_override = _status_mat
	lamp.position = Vector3(0, height + 0.2, 0)
	add_child(lamp)
	_update_lamp()


func _ready() -> void:
	add_to_group("doors")
	_closed_pos = position


func is_locked() -> bool:
	match requirement:
		"":
			return false
		"power":
			return not Game.power_on
		"keycard":
			return not Game.has_keycard
		"finale":
			return not Game.finale
	return true


func _update_lamp() -> void:
	if _status_mat == null:
		return
	var c := Color(0.9, 0.1, 0.05) if is_locked() else Color(0.1, 0.9, 0.2)
	if requirement == "power" and not Game.power_on:
		c = Color(0.15, 0.02, 0.02)
	_status_mat.albedo_color = c
	_status_mat.emission = c


func _process(_d: float) -> void:
	_update_lamp()


func get_prompt() -> String:
	if _busy:
		return ""
	if is_locked():
		return "[E] Door (locked)"
	if big_shutter:
		return ""
	return "[E] Close door" if is_open else "[E] Open door"


func interact(_player) -> void:
	if _busy:
		return
	if is_locked():
		Sfx.play_3d("door_locked", global_position + Vector3.UP * 1.5, -2.0)
		Game.hint(locked_message)
		return
	if is_open:
		close()
	else:
		open()


func open(fast := false) -> void:
	if is_open or _busy:
		return
	is_open = true
	_busy = true
	var dur := 0.45 if fast else 1.4
	if big_shutter:
		dur = 6.0
		Sfx.play_3d("shutter_open", global_position + Vector3.UP * 3.0, 4.0, 1.0, 80.0)
	else:
		Sfx.play_3d("door_open", global_position + Vector3.UP * 1.5, 0.0 if fast else -3.0, 1.4 if fast else 1.0)
	Game.make_noise(global_position, 10.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target := _closed_pos + slide_axis * (width * 0.97)
	if big_shutter:
		target = _closed_pos + Vector3.UP * (height - 0.3)
	_tween.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		_busy = false
		if on_opened.is_valid():
			on_opened.call())


func close() -> void:
	if not is_open or _busy:
		return
	is_open = false
	_busy = true
	Sfx.play_3d("door_open", global_position + Vector3.UP * 1.5, -3.0, 0.9)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _closed_pos, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func(): _busy = false)


## The Foreman doesn't use handles. It rips doors open.
func monster_open() -> void:
	if is_open or is_locked() or big_shutter:
		return
	_busy = false
	open(true)
	Sfx.play_3d(Sfx.pick("metal_bang", 3), global_position + Vector3.UP * 1.5, 0.0, 1.2, 40.0)
