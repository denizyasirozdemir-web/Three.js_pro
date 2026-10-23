extends Node
## Captures screenshots from a few places in the level (needs a real renderer).
## Run: godot --rendering-driver opengl3 res://tests/Shots.tscn -- <outdir>

var world
var outdir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		outdir = args[0]
	DirAccess.make_dir_recursive_absolute(outdir)
	world = load("res://scenes/World.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(9.0).timeout
	var p = world.player
	world.hud.fade(0.0, 0.0)
	Game.has_flashlight = true
	p.battery = 100
	p.toggle_flashlight()
	var shots := [
		["01_lobby", Vector3(-48, 0.1, 37), 0.0, 0.0],
		["02_security", Vector3(-54, 0.1, 35), deg_to_rad(60), -0.25],
		["03_hall", Vector3(-30, 0.1, 30), deg_to_rad(-140), 0.05],
		["04_hall_hats", Vector3(8, 0.1, 18), 0.0, -0.35],
		["05_furnace", Vector3(-8, 0.1, -18), 0.0, 0.05],
		["06_warehouse", Vector3(24, 0.1, 6), deg_to_rad(-90), 0.0],
		["07_boiler", Vector3(44, 0.1, -8), deg_to_rad(10), 0.0],
		["08_lockers", Vector3(-44, 0.1, 10), deg_to_rad(20), -0.05],
	]
	for s in shots:
		await _shot(p, s)
	# monster close-up
	world.monster.activate(Vector3(-20, 0, 20))
	world.monster.deactivate()
	world.monster.visible = true
	world.monster.global_position = Vector3(-14, 0, 12)
	world.monster.visual.rotation.y = 0
	await _shot(p, ["09_monster", Vector3(-14, 0.1, 17), 0.0, 0.1])
	# power on
	world._set_power(true)
	await get_tree().create_timer(1.0).timeout
	await _shot(p, ["10_hall_power", Vector3(-30, 0.1, 30), deg_to_rad(-140), 0.05])
	await _shot(p, ["11_foreman", Vector3(-44, 0.1, -20), deg_to_rad(150), 0.0])
	await _shot(p, ["12_warehouse_power", Vector3(24, 0.1, 26), deg_to_rad(-90), 0.0])
	Game.open_note("voss", world.NOTES["voss"][0], world.NOTES["voss"][1])
	await get_tree().create_timer(0.5).timeout
	_save("13_note")
	world.hud.close_note()
	Game.say("HARLAN", "Breaker panel's on the west wall, near you. Three main fuses are missing.")
	Game.set_objective("Find the three missing fuses (0/3).")
	await get_tree().create_timer(0.8).timeout
	_save("14_subtitles")
	get_tree().quit()


func _shot(p, s) -> void:
	p.global_position = s[1]
	p.rotation.y = s[2]
	p.pitch = s[3]
	p.head.rotation.x = s[3]
	await get_tree().create_timer(1.2).timeout
	_save(s[0])


func _save(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(outdir.path_join(n + ".png"))
	print("saved ", n)
