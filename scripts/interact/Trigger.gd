@tool
extends Area3D
## Fires a callback once when the player walks into it.

var on_enter: Callable
@export var once := true
var _fired := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body)


func setup(size: Vector3, cb: Callable, p_once := true) -> void:
	on_enter = cb
	once = p_once
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)


func _on_body(b: Node) -> void:
	if _fired and once:
		return
	if b == Game.player:
		_fired = true
		if on_enter.is_valid():
			on_enter.call()
