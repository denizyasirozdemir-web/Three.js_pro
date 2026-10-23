extends Node
## Headless smoke test: plays through the whole story by calling interactions directly.
## Run:  godot --headless res://tests/Test.tscn

var world
var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		fails += 1
		print("  FAIL  ", msg)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func find_pickup(prompt_part: String) -> Node:
	for n in world.level.props.get_children():
		if n.has_method("get_prompt") and n.get("prompt") != null and str(n.prompt).find(prompt_part) != -1:
			return n
	return null


func _ready() -> void:
	Engine.time_scale = 2.0
	var packed: PackedScene = load("res://scenes/World.tscn")
	world = packed.instantiate()
	get_tree().root.add_child.call_deferred(world)
	await wait(4.0)
	print("== setup")
	var map: RID = world.get_world_3d().navigation_map
	var polys: int = world.level.geo.navigation_mesh.get_polygon_count()
	check(polys > 100, "navmesh baked (%d polygons)" % polys)
	var path := NavigationServer3D.map_get_path(map, Vector3(-48, 0, 30), Vector3(50, 0, -20), true)
	check(path.size() > 2, "path lobby -> boiler room exists (%d points)" % path.size())
	var path2 := NavigationServer3D.map_get_path(map, Vector3(-28, 0, -8), Vector3(40, 0, -37), true)
	check(path2.size() > 2 and path2[path2.size() - 1].distance_to(Vector3(40, 0, -37)) < 2.0, "path hall -> boiler reaches target")
	check(world.level.scene_file_path == "res://scenes/Level.tscn", "level loaded from the editable scene")
	var lamps := get_tree().get_nodes_in_group("lamps")
	check(lamps.size() > 50 and lamps[0].light != null, "lamps restored from scene (%d)" % lamps.size())
	check(get_tree().get_nodes_in_group("doors").size() == 9, "doors registered (%d)" % get_tree().get_nodes_in_group("doors").size())
	check(get_tree().get_nodes_in_group("lockers").size() > 40, "lockers registered (%d)" % get_tree().get_nodes_in_group("lockers").size())
	check(get_tree().get_nodes_in_group("power_sounds").size() == 4, "machine hum emitters in group")
	check(world.level.patrol_points.size() == 24, "patrol points from markers")
	var p = world.player
	check(p != null and p.is_inside_tree(), "player spawned")
	for i in range(10):
		if Game.objective != "":
			break
		print("    t=", Time.get_ticks_msec(), " ready=", world._ready_done, " obj='", Game.objective, "'")
		await wait(1.0)
	check(Game.objective.find("flashlight") != -1, "objective 1: " + Game.objective)

	print("== flashlight")
	find_pickup("flashlight").interact(p)
	await wait(0.2)
	check(Game.has_flashlight and p.flashlight_on, "flashlight acquired and on")

	print("== enter hall")
	p.global_position = Vector3(-31, 0.1, 30)
	await wait(0.5)
	check(Game.objective.find("fuses") != -1, "objective 2: " + Game.objective)

	print("== fuse 1 -> monster awakens")
	p.global_position = Vector3(54, 0.1, 14)
	find_pickup("fuse").interact(p)
	await wait(5.0)
	check(Game.fuses_found == 1, "fuse count 1")
	check(world.monster.is_active(), "monster active at %s" % world.monster.global_position)
	var m0: Vector3 = world.monster.global_position
	await wait(4.0)
	check(world.monster.global_position.distance_to(m0) > 1.0, "monster moves on its own (%.1fm)" % world.monster.global_position.distance_to(m0))

	print("== noise lures monster")
	world.monster._grace = 0.0
	Game.make_noise(world.monster.global_position + Vector3(3, 0, 0), 50.0)
	check(world.monster.state == world.monster.State.INVESTIGATE, "monster investigates noise")

	print("== chase & death")
	world.monster.reset_to(Vector3(-10, 0, 0), 0.0)
	var mp: Vector3 = world.monster.global_position
	p.global_position = mp + Vector3(0, 0.1, 7)
	world.monster.visual.rotation.y = 0
	world.monster.visual.look_at(p.global_position, Vector3.UP)
	world.monster.visual.rotation.x = 0
	world.monster.visual.rotation.z = 0
	await wait(1.0)
	check(world.monster.is_chasing() or p.dead, "monster sees and chases player (state %d)" % world.monster.state)
	await wait(5.0)
	check(Game.deaths >= 1 or p.dead, "player was caught (deaths=%d)" % Game.deaths)
	await wait(6.0)
	check(not p.dead, "player respawned at checkpoint %s" % p.global_position)

	print("== hiding")
	var lk: Node = get_tree().get_nodes_in_group("lockers")[0]
	lk.interact(p)
	await wait(1.0)
	check(p.is_hidden(), "player hidden in locker")
	print("    locker busy=", lk._busy, " hidden=", p.is_hidden(), " ctrl=", p.controls_enabled)
	lk.interact(p)
	await wait(1.0)
	print("    locker busy=", lk._busy, " hidden=", p.is_hidden(), " ctrl=", p.controls_enabled, " dead=", p.dead)
	check(not p.is_hidden() and p.controls_enabled, "player left locker")

	print("== remaining fuses & breaker")
	world.monster.deactivate()
	for i in range(2):
		find_pickup("fuse").interact(p)
		await wait(0.1)
	check(Game.fuses_found == 3, "all fuses found")
	world.level.fusebox.interact(p)
	await wait(1.5)
	check(Game.fuses_inserted == 3, "fuses inserted")
	check(Game.objective.find("generator") != -1, "objective: " + Game.objective)

	print("== generator & power")
	world.level.generator.interact(p)
	await wait(4.5)
	check(Game.power_on, "power is on")
	check(not world.level.foreman_door.is_locked(), "foreman door unlocked")
	world.level.foreman_door.interact(p)
	await wait(1.6)
	check(world.level.foreman_door.is_open, "foreman door opens")

	print("== notes")
	var notes := 0
	for n in world.level.props.get_children():
		if n.get("note_id") != null:
			notes += 1
	check(notes == 9, "9 documents placed")

	print("== keycard & console")
	find_pickup("keycard").interact(p)
	await wait(0.2)
	check(Game.has_keycard, "keycard acquired")
	world.level.console.interact(p)
	await wait(4.0)
	check(Game.finale, "finale started")
	check(world.monster.enraged and world.monster.is_active(), "monster enraged")
	await wait(4.5)
	check(world.level.shutter.is_open, "shutter opened")

	print("== escape")
	world.monster.deactivate()
	while p.dead or not p.controls_enabled:
		await wait(0.5)
	p.global_position = Vector3(56, 0.2, 26)
	await wait(0.3)
	p.global_position = Vector3(64, 0.2, 26)
	await wait(1.0)
	check(world._ending, "ending triggered")
	Engine.time_scale = 8.0
	for i in range(30):
		await wait(2.0)
		print("    end t=", Time.get_ticks_msec(), " talking=", Game.is_talking(), " q=", Game._queue.size(), " vis=", world.hud.ending_root.visible)
		if world.hud.ending_root.visible:
			break
	check(world.hud.ending_root.visible, "ending screen shown")
	print(world.hud.ending_text.get_parsed_text().substr(0, 200))

	print("== RESULT: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(fails)
