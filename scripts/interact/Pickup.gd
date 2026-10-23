extends Area3D
## A small item the player can pick up. `on_pick` callback runs when collected.

var prompt := "[E] Pick up"
var on_pick: Callable
var spin := false
var _t := 0.0
var _base_y := 0.0
var _glow: OmniLight3D


func setup(p_prompt: String, mesh_root: Node3D, glow_color := Color(0, 0, 0, 0)) -> void:
	prompt = p_prompt
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.45
	cs.shape = sph
	add_child(cs)
	add_child(mesh_root)
	if glow_color.a > 0.0:
		_glow = OmniLight3D.new()
		_glow.light_color = glow_color
		_glow.light_energy = 0.35
		_glow.omni_range = 1.6
		_glow.position.y = 0.25
		add_child(_glow)


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_t += delta
	if _glow:
		_glow.light_energy = 0.25 + 0.15 * sin(_t * 3.0)


func get_prompt() -> String:
	return prompt


func interact(_player) -> void:
	Sfx.play("pickup", -6.0)
	if on_pick.is_valid():
		on_pick.call()
	queue_free()
