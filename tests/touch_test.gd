extends Node
## Simulates touch input: joystick walk, drag look, USE button.
## Run: godot --rendering-driver opengl3 res://tests/TouchTest.tscn -- <outdir>

var world
var fails := 0


func check(c: bool, m: String) -> void:
	print("  PASS  " if c else "  FAIL  ", m)
	if not c:
		fails += 1


func touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _ready() -> void:
	Game.touch_mode = true
	world = load("res://scenes/World.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(8.0).timeout
	var p = world.player
	world.hud.fade(0.0, 0.0)
	var size := get_viewport().get_visible_rect().size
	print("viewport ", size)
	# walk forward with joystick
	var z0: float = p.global_position.z
	touch(0, Vector2(200, size.y - 200), true)
	for k in range(60):
		drag(0, Vector2(200, size.y - 300), Vector2(0, -2))
		await get_tree().physics_frame
	touch(0, Vector2(200, size.y - 300), false)
	check(p.global_position.z < z0 - 1.0, "joystick moves player forward (%.2f m)" % (z0 - p.global_position.z))
	# look by dragging on the right side
	var yaw0: float = p.rotation.y
	touch(1, Vector2(size.x * 0.6, 300), true)
	for k in range(10):
		drag(1, Vector2(size.x * 0.6 + k * 10, 300), Vector2(10, 0))
		await get_tree().physics_frame
	touch(1, Vector2(size.x * 0.7, 300), false)
	check(absf(p.rotation.y - yaw0) > 0.2, "drag rotates camera (%.2f rad)" % absf(p.rotation.y - yaw0))
	# pick up the flashlight with the USE button
	p.global_position = Vector3(-56.6, 0.1, 37.3)
	for k in range(5):
		await get_tree().physics_frame
	var to: Vector3 = Vector3(-57.2, 0.95, 38.5) - p.get_head_position()
	p.rotation.y = atan2(-to.x, -to.z)
	p.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	p.head.rotation.x = p.pitch
	await get_tree().create_timer(0.3).timeout
	p.ray.force_raycast_update()
	print("    prompt: ", p.current_prompt, " ctrl=", p.controls_enabled, " pos=", p.global_position, " hit=", p.ray.get_collider(), " at ", p.ray.get_collision_point())
	var use_pos: Vector2 = Vector2(size.x, size.y) + Vector2(-175, -185)
	touch(2, use_pos, true)
	touch(2, use_pos, false)
	await get_tree().create_timer(0.3).timeout
	check(Game.has_flashlight, "USE button picks up the flashlight")
	# crouch toggle
	var crouch_pos: Vector2 = Vector2(size.x, size.y) + Vector2(-350, -282)
	touch(3, crouch_pos, true)
	touch(3, crouch_pos, false)
	await get_tree().create_timer(0.3).timeout
	check(p.crouching, "CROUCH toggles crouch")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		touch(4, Vector2(200, size.y - 200), true)
		drag(4, Vector2(260, size.y - 280), Vector2(60, -80))
		await get_tree().create_timer(0.2).timeout
		get_viewport().get_texture().get_image().save_png(args[0])
	print("== RESULT: %s" % ("OK" if fails == 0 else "FAILED"))
	get_tree().quit(fails)
