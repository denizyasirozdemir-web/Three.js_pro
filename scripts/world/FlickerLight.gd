extends Node3D
## A ceiling lamp: light + glowing fixture. Can depend on power and flicker.

@export var light: Light3D
@export var bulb_mat: StandardMaterial3D
@export var base_energy := 1.0
## Off until the generator runs. Emergency lights and the furnace glow don't need power.
@export var needs_power := true
@export_range(0.0, 1.0) var flicker := 0.0          # 0 = steady, 1 = very unstable
var broken := false
var _t := 0.0
var _cur := 0.0
var _off_timer := 0.0


func _ready() -> void:
	add_to_group("lamps")
	_t = randf() * 10.0


func is_lit() -> bool:
	return not broken and (Game.power_on or not needs_power)


func _process(delta: float) -> void:
	if light == null:
		return
	_t += delta
	var target := base_energy if is_lit() else 0.0
	if target > 0.0 and flicker > 0.0:
		_off_timer -= delta
		if _off_timer <= 0.0:
			_off_timer = randf_range(0.03, 2.5 / (flicker + 0.1))
			if randf() < flicker * 0.5:
				target *= randf_range(0.0, 0.3)
		target *= 1.0 - flicker * 0.15 * (0.5 + 0.5 * sin(_t * 23.0))
	_cur = target if absf(_cur - target) > 0.3 or flicker > 0.0 else lerpf(_cur, target, delta * 10.0)
	light.light_energy = _cur
	light.visible = _cur > 0.01
	if bulb_mat:
		bulb_mat.emission_energy_multiplier = _cur * 3.0


func burst() -> void:
	if broken:
		return
	broken = true
	Sfx.play_3d("light_burst", global_position, 0.0, randf_range(0.9, 1.1))
	# sparks
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.2
	p.explosiveness = 0.95
	p.direction = Vector3.DOWN
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	var m := SphereMesh.new()
	m.radius = 0.015
	m.height = 0.03
	var sm := StandardMaterial3D.new()
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.7, 0.3)
	sm.emission_energy_multiplier = 8.0
	sm.albedo_color = Color(1, 0.8, 0.4)
	m.material = sm
	p.mesh = m
	add_child(p)
	p.emitting = true
