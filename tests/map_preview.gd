extends Node3D
## Top-down render of scenes/Level.tscn (roof hidden). Run with a real renderer:
## godot --rendering-driver opengl3 res://tests/MapPreview.tscn -- out.png


func _ready() -> void:
	var lvl: Node3D = load("res://scenes/Level.tscn").instantiate()
	add_child(lvl)
	for n in lvl.find_children("*", "MeshInstance3D", true, false):
		if n.global_position.y > 4.4:
			n.visible = false
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(30), 0)
	sun.light_energy = 0.8
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 86
	cam.position = Vector3(6, 60, 0)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.far = 200
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(2.0).timeout
	var args := OS.get_cmdline_user_args()
	get_viewport().get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://map.png")
	get_tree().quit()
