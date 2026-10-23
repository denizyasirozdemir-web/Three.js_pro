extends Area3D
## A readable document. Stays in the world after reading.

var note_id := ""
var title := ""
var body := ""


func setup(p_id: String, p_title: String, p_body: String) -> void:
	note_id = p_id
	title = p_title
	body = p_body
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.2, 0.5)
	cs.shape = box
	add_child(cs)
	var paper := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.24, 0.005, 0.32)
	paper.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.7)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.8, 0.6)
	mat.emission_energy_multiplier = 0.08
	paper.material_override = mat
	paper.rotation.y = randf_range(-0.5, 0.5)
	add_child(paper)
	# scribbled lines
	for i in range(6):
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(randf_range(0.1, 0.18), 0.001, 0.008)
		line.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.1, 0.1, 0.15)
		line.material_override = lmat
		line.position = Vector3(0, 0.004, -0.12 + i * 0.045)
		paper.add_child(line)


func get_prompt() -> String:
	return "[E] Read: " + title


func interact(_player) -> void:
	Sfx.play("paper", -4.0)
	Game.open_note(note_id, title, body)
