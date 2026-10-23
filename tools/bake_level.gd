extends Node
## Regenerates the editable map from the code in scripts/world/Level.gd:
##   materials/*.tres         shared materials
##   scenes/rooms/*.tscn      one scene per area (each file stays small)
##   scenes/Level.tscn        the level: rooms + markers (spawn, patrol, items, notes, triggers)
## WARNING: this overwrites any changes you made to those files in the editor.
## Run: open tools/BakeLevel.tscn in Godot and press F6 (Run Current Scene),
## or from a terminal: godot --headless res://tools/BakeLevel.tscn

const Level := preload("res://scripts/world/Level.gd")
const OUT := "res://scenes/Level.tscn"


func _ready() -> void:
	seed(1986)  # same random props every time
	DirAccess.make_dir_recursive_absolute("res://materials")
	DirAccess.make_dir_recursive_absolute("res://scenes/rooms")
	var level := Level.new()
	level.name = "Level"
	add_child(level)
	level.build()
	var ok := true
	# 1. materials become shared .tres files so every room references the same ones
	for key in level.M:
		var path := "res://materials/%s.tres" % key
		ok = ok and _check(ResourceSaver.save(level.M[key], path), path)
		level.M[key].take_over_path(path)
	# 2. each area becomes its own scene, instanced back into the level
	var rooms := level.geo.get_children()
	for room in rooms:
		var idx := room.get_index()
		var path := "res://scenes/rooms/%s.tscn" % room.name
		# a room's props go in their own file too, so no single file gets big
		var props: Node = room.get_node("Props")
		var ppath := "res://scenes/rooms/%sProps.tscn" % room.name
		level.prepare_for_save(props)
		var pps := PackedScene.new()
		ok = ok and _check(pps.pack(props), ppath) and _check(ResourceSaver.save(pps, ppath), ppath)
		room.remove_child(props)
		props.free()
		var pinst: Node = load(ppath).instantiate()
		room.add_child(pinst)
		level.prepare_for_save(room)
		var ps := PackedScene.new()
		ok = ok and _check(ps.pack(room), path) and _check(ResourceSaver.save(ps, path), path)
		level.geo.remove_child(room)
		room.free()
		var inst: Node = load(path).instantiate()
		level.geo.add_child(inst)
		level.geo.move_child(inst, idx)
	# 3. the level itself
	level.prepare_for_save()
	var packed := PackedScene.new()
	ok = ok and _check(packed.pack(level), OUT) and _check(ResourceSaver.save(packed, OUT), OUT)
	print("Bake ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func _check(err: int, what: String) -> bool:
	if err != OK:
		push_error("%s: %s" % [what, error_string(err)])
		return false
	return true
