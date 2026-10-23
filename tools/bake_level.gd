extends Node
## Regenerates scenes/Level.tscn from the code in scripts/world/Level.gd.
## WARNING: this overwrites any changes you made to Level.tscn in the editor.
## Run: open tools/BakeLevel.tscn in Godot and press F6 (Run Current Scene),
## or from a terminal: godot --headless res://tools/BakeLevel.tscn

const Level := preload("res://scripts/world/Level.gd")
const OUT := "res://scenes/Level.tscn"


func _ready() -> void:
	seed(1986)  # same random props every time
	var level := Level.new()
	level.name = "Level"
	add_child(level)
	level.build()
	level.prepare_for_save()
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("Baked %s: %s (%d nodes)" % [OUT, error_string(err), _count(level)])
	get_tree().quit(0 if err == OK else 1)


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c
