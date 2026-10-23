@tool
extends StaticBody3D
## A tall steel locker the player can hide inside.

@export var facing := Vector3.FORWARD   # direction the locker door faces
@export var door_pivot: Node3D
var _busy := false


func build(body_mat: Material, door_mat: Material, p_facing: Vector3) -> void:
	facing = p_facing.normalized()
	collision_layer = 1
	var size := Vector3(0.9, 2.1, 0.75)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	add_child(cs)
	# orient so local -Z == facing
	rotation.y = atan2(-facing.x, -facing.z)
	# shell (back, sides, top)
	var parts := [
		[Vector3(size.x, size.y, 0.04), Vector3(0, size.y * 0.5, size.z * 0.5 - 0.02)],
		[Vector3(0.04, size.y, size.z), Vector3(-size.x * 0.5 + 0.02, size.y * 0.5, 0)],
		[Vector3(0.04, size.y, size.z), Vector3(size.x * 0.5 - 0.02, size.y * 0.5, 0)],
		[Vector3(size.x, 0.04, size.z), Vector3(0, size.y - 0.02, 0)],
		[Vector3(size.x, 0.04, size.z), Vector3(0, 0.02, 0)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = body_mat
		mi.position = p[1]
		add_child(mi)
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-size.x * 0.5, 0, -size.z * 0.5)
	add_child(door_pivot)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(size.x, size.y - 0.05, 0.035)
	door.mesh = dm
	door.material_override = door_mat
	door.position = Vector3(size.x * 0.5, size.y * 0.5, 0)
	door_pivot.add_child(door)
	# vent slits on the door
	var slit_mat := StandardMaterial3D.new()
	slit_mat.albedo_color = Color(0.01, 0.01, 0.01)
	for i in range(5):
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.5, 0.025, 0.04)
		s.mesh = sm
		s.material_override = slit_mat
		s.position = Vector3(size.x * 0.5, 1.55 + i * 0.06, -0.005)
		door_pivot.add_child(s)


func _ready() -> void:
	add_to_group("lockers")


func get_hide_position() -> Vector3:
	return global_position + Vector3.UP * 0.05 + global_basis.z * 0.05


func get_hide_yaw() -> float:
	return rotation.y


func get_front_position() -> Vector3:
	return global_position + facing * 1.1


func get_prompt() -> String:
	if _busy:
		return ""
	return "[E] Hide in locker"


func interact(player) -> void:
	if _busy:
		return
	_busy = true
	Sfx.play_3d("locker", global_position + Vector3.UP * 1.2, -4.0)
	Game.make_noise(global_position, 4.0)
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation:y", deg_to_rad(-100), 0.2)
	if player.is_hidden():
		player.exit_hide(get_front_position())
	else:
		player.enter_hide(self)
	tw.tween_interval(0.25)
	tw.tween_property(door_pivot, "rotation:y", 0.0, 0.2)
	tw.tween_callback(func(): _busy = false)


func rip_open() -> void:
	Sfx.play_3d(Sfx.pick("metal_bang", 3), global_position + Vector3.UP, 4.0, 1.3)
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation:y", deg_to_rad(-170), 0.12)
