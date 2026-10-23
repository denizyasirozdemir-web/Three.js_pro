extends Node3D
## Builds Kessler Ironworks Plant 9 entirely from code: architecture, props,
## lights, signage, sound emitters and the navigation mesh.
##
## Layout (top view, metres; -Z is north):
##
##  z=-40 +-------------+---------------------+---------------+
##        | FOREMAN     |   FURNACE / LINE 9  |  BOILER ROOM  |
##        | OFFICE      |                     |               |
##  z=-16 +----[pwr]----+------[ opening ]----+               |
##        | LOCKER ROOM |                     +-----[door]----+ z=-4
##        |             |   MAIN PRODUCTION   |               |
##  z=12  +----[door]---+   HALL              |   WAREHOUSE   |==> LOADING
##        | LOBBY       |                     |               |    BAY
##  z=40  +---[entry]---+---------------------+---------------+
##       x=-60        x=-36                 x=20            x=60

const Usable := preload("res://scripts/interact/Usable.gd")
const Pickup := preload("res://scripts/interact/Pickup.gd")
const Note := preload("res://scripts/interact/Note.gd")
const Door := preload("res://scripts/interact/Door.gd")
const Locker := preload("res://scripts/interact/Locker.gd")
const Trigger := preload("res://scripts/interact/Trigger.gd")
const FlickerLight := preload("res://scripts/world/FlickerLight.gd")

const LOW_H := 4.5
const HIGH_H := 12.0

var geo: NavigationRegion3D
var props: Node3D
var lights: Node3D
var spawn_pos := Vector3(-48, 0.1, 37.0)
var spawn_yaw := 0.0
var patrol_points: Array[Vector3] = []
var emergency_lights: Array = []
var alarm_lights: Array = []

var fusebox: StaticBody3D
var fuse_slots: Array[MeshInstance3D] = []
var generator: StaticBody3D
var generator_exhaust: CPUParticles3D
var console: StaticBody3D
var console_screen_mat: StandardMaterial3D
var shutter: AnimatableBody3D
var foreman_door: AnimatableBody3D
var writing_label: Label3D

var M := {}  # materials


# ================================================================ entry
func build() -> void:
	geo = NavigationRegion3D.new()
	geo.name = "Geometry"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.25
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.filter_baking_aabb = AABB(Vector3(-61, -1, -41), Vector3(140, 4, 82))
	geo.navigation_mesh = nm
	add_child(geo)
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	lights = Node3D.new()
	lights.name = "Lights"
	add_child(lights)

	_make_materials()
	_build_shell()
	_build_lobby()
	_build_hall()
	_build_warehouse()
	_build_boiler()
	_build_furnace()
	_build_lockers()
	_build_foreman()
	_build_exterior()
	_build_patrol_points()
	_build_markers()


func bake_nav() -> void:
	geo.bake_navigation_mesh(false)


# ================================================================ scene support
## Called when the level comes from scenes/Level.tscn (the editable map) instead of build().
## Looks up every node the story needs by name, so you can move things in the editor freely.
func resolve() -> void:
	geo = $Geometry
	props = $Props
	lights = $Lights
	M.rubber = _flat(Color(0.03, 0.03, 0.03), 0.9)
	M.ceramic = _flat(Color(0.85, 0.85, 0.8), 0.3)
	M.brass = _flat(Color(0.6, 0.45, 0.2), 0.4, 0.9)
	fusebox = find_child("FuseBox", true, false)
	fuse_slots.clear()
	for i in range(3):
		fuse_slots.append(fusebox.get_node("FuseSlot%d" % i))
	generator = find_child("Generator", true, false)
	generator_exhaust = generator.get_node("Exhaust")
	console = find_child("Line9Console", true, false)
	console_screen_mat = console.get_node("Screen").material_override
	shutter = find_child("LoadingBayShutter", true, false)
	foreman_door = find_child("ForemanDoor", true, false)
	writing_label = find_child("HeCountsUs", true, false)
	alarm_lights.clear()
	for n in lights.get_children():
		if str(n.name).begins_with("AlarmLight"):
			alarm_lights.append(n)
	var spawn: Node3D = $Markers/PlayerSpawn
	spawn_pos = spawn.global_position
	spawn_yaw = spawn.global_rotation.y
	patrol_points.clear()
	for m in $Markers/PatrolPoints.get_children():
		patrol_points.append(m.global_position)


## Marker nodes you can drag around in the editor: spawn, patrol route, items, documents, story triggers.
func _build_markers() -> void:
	var root := Node3D.new()
	root.name = "Markers"
	add_child(root)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = spawn_pos
	spawn.rotation.y = spawn_yaw
	root.add_child(spawn)
	var pp := Node3D.new()
	pp.name = "PatrolPoints"
	root.add_child(pp)
	for i in range(patrol_points.size()):
		_marker(pp, "Patrol%02d" % (i + 1), patrol_points[i])
	# items: the name prefix decides what spawns there (Flashlight, Fuse..., Keycard, Battery...)
	var items := Node3D.new()
	items.name = "Items"
	root.add_child(items)
	var item_spots := {
		"Flashlight": Vector3(-57.2, 0.95, 38.5),
		"Fuse_Warehouse": Vector3(55.5, 1.3, 14),
		"Fuse_LockerRoom": Vector3(-46, 0.6, -10),
		"Fuse_Furnace": Vector3(-31.4, 1.02, -37.6),
		"Keycard": Vector3(-47.4, 0.85, -31.8),
		"Battery_Security": Vector3(-56.0, 0.95, 38.8),
		"Battery_Hall": Vector3(-33.8, 0.95, 2.15),
		"Battery_Warehouse": Vector3(22.2, 0.95, -2.05),
		"Battery_Boiler": Vector3(25.2, 0.95, -14.25),
		"Battery_Lockers": Vector3(-44.0, 0.52, 6.0),
		"Battery_Control": Vector3(10.5, 0.95, -39.2),
		"Battery_Pallets": Vector3(45.6, 2.45, 33),
		"Battery_Foreman": Vector3(-59.4, 1.35, -36.0),
	}
	for n in item_spots:
		_marker(items, n, item_spots[n])
	# documents: the name is the note id used by World.NOTES
	var notes := Node3D.new()
	notes.name = "Notes"
	root.add_child(notes)
	var note_spots := {
		"notice": Vector3(-46.8, 1.17, 24.0),
		"security": Vector3(-58.5, 0.92, 38.4),
		"maintenance": Vector3(-34.5, 0.92, 1.9),
		"manifest": Vector3(22.9, 0.92, -2.3),
		"diary": Vector3(-53, 0.5, 3.0),
		"scrawl": Vector3(25.6, 0.92, -13.8),
		"voss": Vector3(-48.6, 0.83, -32.1),
		"incident": Vector3(-59.4, 1.31, -37.0),
		"last": Vector3(9.7, 0.92, -39.3),
	}
	for n in note_spots:
		_marker(notes, n, note_spots[n])
	# story triggers (resize them with their CollisionShape3D in the editor)
	var trig := Node3D.new()
	trig.name = "Triggers"
	root.add_child(trig)
	var trigger_spots := [
		["Hall", Vector3(-31, 2, 30), Vector3(4, 4, 6), true],
		["Warehouse", Vector3(26, 2, 8), Vector3(6, 4, 10), true],
		["Boiler", Vector3(30, 2, -10), Vector3(14, 4, 10), true],
		["Furnace", Vector3(-10, 2, -20), Vector3(10, 4, 6), true],
		["LockerRoom", Vector3(-48, 2, 8), Vector3(6, 4, 4), true],
		["ForemanOffice", Vector3(-48, 2, -20), Vector3(6, 4, 6), true],
		["Exit", Vector3(64, 2, 26), Vector3(4, 6, 10), false],
		["Catwalk", Vector3(-8, 2, -6), Vector3(20, 4, 6), true],
	]
	for t in trigger_spots:
		var tr := Trigger.new()
		tr.name = t[0]
		tr.setup(t[2], Callable(), t[3])
		tr.position = t[1]
		trig.add_child(tr)


func _marker(parent: Node3D, n: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	m.gizmo_extents = 0.5
	parent.add_child(m)
	return m


## Prepares the generated tree to be saved as a .tscn: readable names + ownership.
func prepare_for_save() -> void:
	var counter := {}
	_prepare(self, counter)


func _prepare(n: Node, counter: Dictionary) -> void:
	for c in n.get_children():
		if str(c.name).begins_with("@"):
			var base := c.get_class()
			if c is StaticBody3D and c.get_child_count() > 1 and c.get_child(1) is MeshInstance3D:
				base = "Solid"
			elif c is MeshInstance3D:
				base = "Mesh"
			elif c is Label3D:
				base = "Sign"
			counter[base] = counter.get(base, 0) + 1
			c.name = "%s%d" % [base, counter[base]]
		c.owner = self
		_prepare(c, counter)


# ================================================================ materials
func _noise_tex(freq: float, a: Color, b: Color, normal := false, cellular := false, octaves := 5) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR if cellular else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = randi()
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	else:
		var g := Gradient.new()
		g.set_color(0, a)
		g.set_color(1, b)
		t.color_ramp = g
	return t


func _tex_mat(a: Color, b: Color, rough: float, metal: float, scale: float, freq := 0.02, cellular := false, normal_strength := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(freq, a, b, false, cellular)
	m.roughness = rough
	m.metallic = metal
	m.normal_enabled = true
	m.normal_texture = _noise_tex(freq * 3.0, a, b, true)
	m.normal_scale = normal_strength
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _flat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _hazard_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var stripe := int((x + y) / 16) % 2 == 0
			var c := Color(0.75, 0.6, 0.05) if stripe else Color(0.05, 0.05, 0.05)
			# grime
			c = c.darkened(randf() * 0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_materials() -> void:
	M.concrete = _tex_mat(Color(0.16, 0.16, 0.15), Color(0.32, 0.31, 0.29), 0.95, 0.0, 0.18, 0.015)
	M.floor = _tex_mat(Color(0.12, 0.12, 0.11), Color(0.27, 0.26, 0.24), 0.9, 0.0, 0.12, 0.02, false, 0.6)
	M.wall = _tex_mat(Color(0.2, 0.22, 0.2), Color(0.34, 0.36, 0.33), 0.95, 0.0, 0.15, 0.01)
	M.office_wall = _tex_mat(Color(0.3, 0.32, 0.27), Color(0.45, 0.46, 0.4), 0.95, 0.0, 0.3, 0.02)
	M.tile = _tex_mat(Color(0.35, 0.37, 0.36), Color(0.5, 0.52, 0.5), 0.6, 0.0, 0.8, 0.05, true)
	M.metal = _tex_mat(Color(0.18, 0.19, 0.2), Color(0.3, 0.31, 0.32), 0.5, 0.8, 0.3, 0.03)
	M.rust = _tex_mat(Color(0.22, 0.1, 0.04), Color(0.45, 0.24, 0.1), 0.85, 0.5, 0.35, 0.04, true)
	M.dark_metal = _tex_mat(Color(0.06, 0.06, 0.065), Color(0.14, 0.14, 0.15), 0.6, 0.7, 0.3, 0.03)
	M.green_paint = _tex_mat(Color(0.12, 0.22, 0.16), Color(0.2, 0.3, 0.22), 0.7, 0.3, 0.3, 0.04)
	M.blue_paint = _tex_mat(Color(0.1, 0.15, 0.25), Color(0.18, 0.24, 0.33), 0.7, 0.3, 0.3, 0.04)
	M.wood = _tex_mat(Color(0.25, 0.16, 0.08), Color(0.4, 0.28, 0.15), 0.9, 0.0, 0.6, 0.06)
	M.crate = _tex_mat(Color(0.3, 0.22, 0.12), Color(0.45, 0.35, 0.2), 0.95, 0.0, 0.5, 0.05)
	M.grate = _tex_mat(Color(0.1, 0.1, 0.1), Color(0.25, 0.25, 0.25), 0.6, 0.85, 1.5, 0.2, true)
	M.rubber = _flat(Color(0.03, 0.03, 0.03), 0.9)
	M.paper = _flat(Color(0.8, 0.78, 0.68), 1.0)
	M.blood = _flat(Color(0.18, 0.01, 0.01), 0.3)
	M.oil = _flat(Color(0.02, 0.02, 0.02), 0.15, 0.3)
	M.slag = _tex_mat(Color(0.03, 0.03, 0.03), Color(0.12, 0.1, 0.09), 0.9, 0.2, 0.6, 0.08, true)
	M.lamp_shade = _flat(Color(0.12, 0.14, 0.12), 0.5, 0.7)
	M.chalkboard = _flat(Color(0.05, 0.08, 0.06), 0.95)
	M.chalk = _glow(Color(0.85, 0.85, 0.8), 0.15)
	M.molten = _glow(Color(1.0, 0.35, 0.05), 6.0)
	M.molten_dim = _glow(Color(1.0, 0.25, 0.02), 2.0)
	M.screen = _glow(Color(0.2, 0.9, 0.4), 0.3)
	M.glass = _flat(Color(0.5, 0.6, 0.65, 0.25), 0.1, 0.2)
	M.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	M.skylight = _glow(Color(0.35, 0.45, 0.6), 0.6)
	var hz := StandardMaterial3D.new()
	hz.albedo_texture = _hazard_tex()
	hz.roughness = 0.8
	hz.uv1_triplanar = true
	hz.uv1_world_triplanar = true
	hz.uv1_scale = Vector3.ONE * 1.4
	hz.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	M.hazard = hz
	M.yellow = _flat(Color(0.7, 0.55, 0.05), 0.8)
	M.white_line = _flat(Color(0.55, 0.52, 0.4), 0.9)
	M.brass = _flat(Color(0.6, 0.45, 0.2), 0.4, 0.9)
	M.ceramic = _flat(Color(0.85, 0.85, 0.8), 0.3)
	M.locker = _tex_mat(Color(0.18, 0.25, 0.3), Color(0.28, 0.34, 0.38), 0.6, 0.6, 0.6, 0.05)
	M.locker_door = _tex_mat(Color(0.2, 0.28, 0.33), Color(0.3, 0.37, 0.4), 0.6, 0.6, 0.6, 0.05)
	M.door = _tex_mat(Color(0.25, 0.2, 0.08), Color(0.4, 0.33, 0.12), 0.7, 0.6, 0.4, 0.05)
	M.shutter = _tex_mat(Color(0.2, 0.2, 0.2), Color(0.35, 0.33, 0.3), 0.6, 0.7, 1.2, 0.1)


# ================================================================ primitives
func box(center: Vector3, size: Vector3, mat: Material, collide := true, parent: Node3D = null, shadow := true) -> MeshInstance3D:
	if parent == null:
		parent = geo
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.position = center
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		sb.add_child(mi)
		parent.add_child(sb)
	else:
		mi.position = center
		parent.add_child(mi)
	return mi


func cyl(center: Vector3, radius: float, height: float, mat: Material, axis := "y", collide := true, parent: Node3D = null, segs := 16) -> MeshInstance3D:
	if parent == null:
		parent = geo
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	var rot := Vector3.ZERO
	if axis == "x":
		rot = Vector3(0, 0, PI / 2)
	elif axis == "z":
		rot = Vector3(PI / 2, 0, 0)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.position = center
		sb.rotation = rot
		var cs := CollisionShape3D.new()
		var cshape := CylinderShape3D.new()
		cshape.radius = radius
		cshape.height = height
		cs.shape = cshape
		sb.add_child(cs)
		sb.add_child(mi)
		parent.add_child(sb)
	else:
		mi.position = center
		mi.rotation = rot
		parent.add_child(mi)
	return mi


func sphere(center: Vector3, radius: float, mat: Material, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	if parent == null:
		parent = props
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = center
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Wall running along X at depth z. openings: [[center_x, width, height], ...]
func wall_x(z: float, x0: float, x1: float, h: float, openings := [], mat: Material = null, t := 0.5) -> void:
	if mat == null:
		mat = M.wall
	openings.sort_custom(func(a, b): return a[0] < b[0])
	var cur := x0
	for o in openings:
		var a: float = o[0] - o[1] * 0.5
		var b: float = o[0] + o[1] * 0.5
		if a > cur:
			box(Vector3((cur + a) * 0.5, h * 0.5, z), Vector3(a - cur, h, t), mat)
		if o[2] < h:
			box(Vector3(o[0], (o[2] + h) * 0.5, z), Vector3(o[1], h - o[2], t), mat)
		_door_frame(Vector3(o[0], 0, z), o[1], o[2], true, t)
		cur = b
	if cur < x1:
		box(Vector3((cur + x1) * 0.5, h * 0.5, z), Vector3(x1 - cur, h, t), mat)


## Wall running along Z at x. openings: [[center_z, width, height], ...]
func wall_z(x: float, z0: float, z1: float, h: float, openings := [], mat: Material = null, t := 0.5) -> void:
	if mat == null:
		mat = M.wall
	openings.sort_custom(func(a, b): return a[0] < b[0])
	var cur := z0
	for o in openings:
		var a: float = o[0] - o[1] * 0.5
		var b: float = o[0] + o[1] * 0.5
		if a > cur:
			box(Vector3(x, h * 0.5, (cur + a) * 0.5), Vector3(t, h, a - cur), mat)
		if o[2] < h:
			box(Vector3(x, (o[2] + h) * 0.5, o[0]), Vector3(t, h - o[2], o[1]), mat)
		_door_frame(Vector3(x, 0, o[0]), o[1], o[2], false, t)
		cur = b
	if cur < z1:
		box(Vector3(x, h * 0.5, (cur + z1) * 0.5), Vector3(t, h, z1 - cur), mat)


func _door_frame(base: Vector3, w: float, h: float, along_x: bool, t: float) -> void:
	var ft := t + 0.12
	var post := 0.18
	if along_x:
		box(base + Vector3(-w * 0.5 - post * 0.5 + 0.09, h * 0.5, 0), Vector3(post, h, ft), M.hazard, false)
		box(base + Vector3(w * 0.5 + post * 0.5 - 0.09, h * 0.5, 0), Vector3(post, h, ft), M.hazard, false)
		box(base + Vector3(0, h + 0.09, 0), Vector3(w + post * 2, 0.18, ft), M.hazard, false)
	else:
		box(base + Vector3(0, h * 0.5, -w * 0.5 - post * 0.5 + 0.09), Vector3(ft, h, post), M.hazard, false)
		box(base + Vector3(0, h * 0.5, w * 0.5 + post * 0.5 - 0.09), Vector3(ft, h, post), M.hazard, false)
		box(base + Vector3(0, h + 0.09, 0), Vector3(ft, 0.18, w + post * 2), M.hazard, false)


func door(pos: Vector3, w: float, h: float, axis: Vector3, req := "", msg := "It's locked.", mat: Material = null) -> AnimatableBody3D:
	var d := Door.new()
	d.setup(w, h, axis, mat if mat else M.door, req, msg)
	d.position = pos
	props.add_child(d)
	return d


func signage(text: String, pos: Vector3, yaw_deg: float, size := 48, col := Color(0.85, 0.85, 0.8), plate := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = deg_to_rad(yaw_deg)
	l.shaded = true
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	props.add_child(l)
	if plate:
		var lines := text.split("\n")
		var maxlen := 0
		for s in lines:
			maxlen = maxi(maxlen, s.length())
		var w := maxlen * size * 0.006 * 0.62 + 0.3
		var hgt := lines.size() * size * 0.006 * 1.2 + 0.2
		var plate_mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, hgt, 0.04)
		plate_mi.mesh = bm
		plate_mi.material_override = _flat(Color(0.08, 0.12, 0.1), 0.8, 0.3)
		plate_mi.position = Vector3(0, 0, -0.03)
		l.add_child(plate_mi)
	return l


func lamp(pos: Vector3, col: Color, energy: float, rng: float, needs_power := true, flicker := 0.0, kind := "hanging", shadows := false) -> Node3D:
	var fl := FlickerLight.new()
	fl.position = pos
	fl.needs_power = needs_power
	fl.flicker = flicker
	fl.base_energy = energy
	var ol := OmniLight3D.new()
	ol.light_color = col
	ol.omni_range = rng
	ol.omni_attenuation = 1.2
	ol.light_energy = energy
	ol.shadow_enabled = shadows
	ol.light_volumetric_fog_energy = 1.4
	ol.position.y = -0.35 if kind == "hanging" else 0.0
	fl.add_child(ol)
	fl.light = ol
	fl.bulb_mat = _glow(col, 0.0)
	match kind:
		"hanging":
			var shade := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.12
			cm.bottom_radius = 0.55
			cm.height = 0.35
			shade.mesh = cm
			shade.material_override = M.lamp_shade
			shade.position.y = -0.15
			fl.add_child(shade)
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.14
			sm.height = 0.28
			bulb.mesh = sm
			bulb.material_override = fl.bulb_mat
			bulb.position.y = -0.3
			fl.add_child(bulb)
			var cable := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.015
			cc.bottom_radius = 0.015
			cc.height = 2.0
			cable.mesh = cc
			cable.material_override = M.rubber
			cable.position.y = 1.0
			fl.add_child(cable)
		"tube":
			var tube := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.4, 0.08, 0.16)
			tube.mesh = bm
			tube.material_override = fl.bulb_mat
			fl.add_child(tube)
			var housing := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(1.5, 0.08, 0.26)
			housing.mesh = hb
			housing.material_override = M.lamp_shade
			housing.position.y = 0.07
			fl.add_child(housing)
		"cage":
			var b := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.11
			s.height = 0.22
			b.mesh = s
			b.material_override = fl.bulb_mat
			fl.add_child(b)
			var cage := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(0.3, 0.3, 0.12)
			cage.mesh = cb
			cage.material_override = M.lamp_shade
			cage.position.z = 0.1
			fl.add_child(cage)
	lights.add_child(fl)
	return fl


func emergency(pos: Vector3, flicker := 0.15) -> Node3D:
	var l := lamp(pos, Color(1.0, 0.12, 0.06), 0.9, 7.5, false, flicker, "cage")
	emergency_lights.append(l)
	return l


func crate(pos: Vector3, s := 1.2, mat: Material = null) -> void:
	box(pos + Vector3(0, s * 0.5, 0), Vector3(s, s, s), mat if mat else M.crate)
	# slats
	box(pos + Vector3(0, s * 0.5, s * 0.5 + 0.01), Vector3(s * 0.95, 0.1, 0.03), M.wood, false, props, false)
	box(pos + Vector3(0, s * 0.5, -s * 0.5 - 0.01), Vector3(s * 0.95, 0.1, 0.03), M.wood, false, props, false)


func barrel(pos: Vector3, mat: Material = null) -> void:
	cyl(pos + Vector3(0, 0.45, 0), 0.32, 0.9, mat if mat else M.rust)
	cyl(pos + Vector3(0, 0.3, 0), 0.335, 0.04, M.dark_metal, "y", false, props)
	cyl(pos + Vector3(0, 0.62, 0), 0.335, 0.04, M.dark_metal, "y", false, props)


func table(pos: Vector3, size := Vector3(1.6, 0.9, 0.8), mat: Material = null) -> float:
	var m: Material = mat if mat else M.metal
	box(pos + Vector3(0, size.y - 0.03, 0), Vector3(size.x, 0.06, size.z), m)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(pos + Vector3(sx * (size.x * 0.5 - 0.06), (size.y - 0.06) * 0.5, sz * (size.z * 0.5 - 0.06)), Vector3(0.06, size.y - 0.06, 0.06), M.dark_metal, false, props)
	return pos.y + size.y


func stain(pos: Vector3, size: Vector2, mat: Material = null) -> void:
	var mi := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.5
	pm.height = 0.005
	pm.radial_segments = 12
	mi.mesh = pm
	mi.material_override = mat if mat else M.oil
	mi.position = pos + Vector3(0, 0.006, 0)
	mi.scale = Vector3(size.x, 1, size.y)
	mi.rotation.y = randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(mi)


func pipe_run(a: Vector3, b: Vector3, r: float, mat: Material = null) -> void:
	var d := b - a
	var axis := "x"
	if absf(d.y) > absf(d.x) and absf(d.y) > absf(d.z):
		axis = "y"
	elif absf(d.z) > absf(d.x):
		axis = "z"
	cyl((a + b) * 0.5, r, d.length(), mat if mat else M.rust, axis, false, props, 10)
	# flanges
	var n := int(d.length() / 4.0)
	for i in range(1, n + 1):
		var p := a + d * (float(i) / (n + 1))
		cyl(p, r * 1.35, 0.12, M.dark_metal, axis, false, props, 10)


func steam_vent(pos: Vector3, dir := Vector3.UP) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.2
	p.direction = dir
	p.spread = 12.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 0.8
	p.damping_max = 1.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.6)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _soft_dot()
	qm.material = sm
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.7, 0.7, 0.18))
	g.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	p.color_ramp = g
	p.position = pos
	props.add_child(p)
	Sfx.loop_3d("steam_hiss", props, pos, -10.0, 14.0, 2.0)


var _dot_tex: GradientTexture2D
func _soft_dot() -> GradientTexture2D:
	if _dot_tex:
		return _dot_tex
	_dot_tex = GradientTexture2D.new()
	_dot_tex.fill = GradientTexture2D.FILL_RADIAL
	_dot_tex.fill_from = Vector2(0.5, 0.5)
	_dot_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_dot_tex.gradient = g
	return _dot_tex


func locker_at(pos: Vector3, facing: Vector3) -> void:
	var l := Locker.new()
	l.build(M.locker, M.locker_door, facing)
	l.position = pos
	geo.add_child(l)


func hardhat(pos: Vector3, col: Color) -> void:
	var mat := _flat(col, 0.5)
	var dome := sphere(pos + Vector3(0, 0.02, 0), 0.16, mat, Vector3(1, 0.7, 1.15))
	dome.rotation.z = randf_range(-0.3, 0.3)
	var brim := cyl(pos, 0.2, 0.02, mat, "y", false, props, 12)
	brim.scale = Vector3(1, 1, 1.25)


func shelf_rack(x0: float, x1: float, z: float, h := 5.0, depth := 1.6) -> void:
	var len := x1 - x0
	var cx := (x0 + x1) * 0.5
	# solid collider for the whole rack (keeps navigation simple)
	var sb := StaticBody3D.new()
	sb.position = Vector3(cx, h * 0.5, z)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(len, h, depth)
	cs.shape = bs
	sb.add_child(cs)
	geo.add_child(sb)
	# visuals
	var posts := int(len / 2.6) + 1
	for i in range(posts):
		var px := x0 + i * len / (posts - 1)
		for sz in [-1, 1]:
			box(Vector3(px, h * 0.5, z + sz * (depth * 0.5 - 0.05)), Vector3(0.1, h, 0.1), M.blue_paint, false, props)
	for lvl in range(4):
		var y := 0.15 + lvl * (h / 4.0)
		box(Vector3(cx, y, z), Vector3(len, 0.06, depth), M.metal, false, props)
		box(Vector3(cx, y + 0.08, z - depth * 0.5), Vector3(len, 0.12, 0.05), M.hazard, false, props, false)
		# cargo on each level
		var x := x0 + 0.5
		while x < x1 - 0.8:
			var r := randf()
			if r < 0.55:
				var s := randf_range(0.7, 1.1)
				var m: Material = M.crate if randf() < 0.7 else M.green_paint
				box(Vector3(x + s * 0.5, y + 0.03 + s * 0.5, z + randf_range(-0.15, 0.15)), Vector3(s, s, minf(s, depth - 0.2)), m, false, props)
				x += s + randf_range(0.1, 0.5)
			elif r < 0.75:
				for k in range(2):
					cyl(Vector3(x + 0.35, y + 0.48, z - 0.35 + k * 0.7), 0.3, 0.9, M.rust, "y", false, props, 10)
				x += 0.8
			else:
				x += randf_range(0.6, 1.4)


# ================================================================ shell
func _build_shell() -> void:
	# floor
	box(Vector3(0, -0.25, 0), Vector3(120, 0.5, 80), M.floor)
	# roof (no collision - unreachable)
	box(Vector3(0, HIGH_H + 0.25, 0), Vector3(121, 0.5, 81), M.concrete, false, props)
	# low ceilings over the west wing
	box(Vector3(-48, LOW_H + 0.1, 0), Vector3(24, 0.2, 80), M.concrete, false, props)
	for z in [-34.0, -22.0, -6.0, 6.0, 20.0, 32.0]:
		box(Vector3(-48, LOW_H - 0.05, z), Vector3(24, 0.1, 0.25), M.dark_metal, false, props, false)

	# outer walls
	wall_x(40, -60, 60, HIGH_H, [[-48.0, 3.0, 3.2]])
	wall_x(-40, -60, 60, HIGH_H)
	wall_z(-60, -40, 40, HIGH_H)
	wall_z(60, -40, 40, HIGH_H, [[26.0, 8.0, 6.0]])
	# west wing / hall divider
	wall_z(-36, -40, 40, HIGH_H, [[30.0, 3.0, 3.5], [-2.0, 3.0, 3.5]])
	# west wing rooms
	wall_x(12, -60, -36, LOW_H, [[-48.0, 3.0, 3.5]], M.office_wall)
	wall_x(-16, -60, -36, LOW_H, [[-48.0, 3.0, 3.5]], M.office_wall)
	# hall / furnace
	wall_x(-16, -36, 20, HIGH_H, [[-10.0, 8.0, 6.0]])
	# east side
	wall_z(20, -40, 40, HIGH_H, [[-28.0, 3.0, 3.5], [8.0, 5.0, 5.0], [30.0, 3.0, 3.5]])
	wall_x(-4, 20, 60, HIGH_H, [[44.0, 3.0, 3.5]])

	# doors
	door(Vector3(-48, 0, 40), 3.0, 3.2, Vector3.RIGHT, "never", "The entrance locked behind you. Chained from the outside.")
	door(Vector3(-36, 0, 30), 3.0, 3.5, Vector3.BACK)
	door(Vector3(-36, 0, -2), 3.0, 3.5, Vector3.BACK)
	door(Vector3(-48, 0, 12), 3.0, 3.5, Vector3.RIGHT)
	foreman_door = door(Vector3(-48, 0, -16), 3.0, 3.5, Vector3.RIGHT, "power", "The door is electronically sealed. No power.")
	foreman_door.name = "ForemanDoor"
	door(Vector3(20, 0, -28), 3.0, 3.5, Vector3.BACK)
	door(Vector3(20, 0, 30), 3.0, 3.5, Vector3.BACK)
	door(Vector3(44, 0, -4), 3.0, 3.5, Vector3.RIGHT)
	shutter = door(Vector3(60, 0, 26), 8.0, 6.0, Vector3.BACK, "finale", "The loading bay shutter. It won't budge without the Line 9 override.", M.shutter)
	shutter.name = "LoadingBayShutter"
	shutter.big_shutter = true

	# skylights with moonlight shafts
	for p in [Vector3(-22, HIGH_H, 2), Vector3(4, HIGH_H, 22), Vector3(-10, HIGH_H, 34), Vector3(40, HIGH_H, 12), Vector3(-8, HIGH_H, -28)]:
		box(p + Vector3(0, -0.02, 0), Vector3(4, 0.06, 4), M.skylight, false, props, false)
		var sl := SpotLight3D.new()
		sl.light_color = Color(0.45, 0.55, 0.8)
		sl.light_energy = 1.4
		sl.spot_range = 16.0
		sl.spot_angle = 18.0
		sl.light_volumetric_fog_energy = 3.0
		sl.shadow_enabled = false
		sl.position = p + Vector3(0, -0.2, 0)
		sl.rotation.x = -PI / 2
		lights.add_child(sl)


# ================================================================ lobby
func _build_lobby() -> void:
	# security booth (SW corner)
	wall_z(-53, 33, 40, 3.0, [[35.6, 1.2, 2.4]], M.office_wall, 0.2)
	box(Vector3(-56.5, 0.55, 33), Vector3(7, 1.1, 0.2), M.office_wall)
	box(Vector3(-56.5, 2.75, 33), Vector3(7, 0.5, 0.2), M.office_wall)
	box(Vector3(-56.5, 1.75, 33), Vector3(7, 1.3, 0.04), M.glass, false, props, false)
	box(Vector3(-56.5, 3.05, 36.5), Vector3(7, 0.1, 7.2), M.concrete, false, props)
	table(Vector3(-57.5, 0, 38.6), Vector3(3.2, 0.9, 1.0), M.wood)
	# CCTV monitors (dead)
	for i in range(3):
		box(Vector3(-58.6 + i * 0.75, 1.15, 39.0), Vector3(0.6, 0.45, 0.4), M.dark_metal, false, props)
	box(Vector3(-55, 0.45, 39.4), Vector3(0.6, 0.9, 0.6), M.dark_metal)  # filing cabinet
	lamp(Vector3(-56.5, 2.95, 36.5), Color(1.0, 0.85, 0.6), 0.6, 5.0, false, 0.6, "tube")
	signage("SECURITY", Vector3(-53.1, 2.6, 35.6), 90, 40)

	# reception
	box(Vector3(-46, 0.55, 24), Vector3(5, 1.1, 1.2), M.wood)
	box(Vector3(-46, 1.13, 24), Vector3(5.2, 0.06, 1.4), M.dark_metal, false, props)
	box(Vector3(-44.5, 1.3, 24.2), Vector3(0.5, 0.35, 0.4), M.dark_metal, false, props)  # old terminal
	for i in range(3):
		box(Vector3(-57.5, 0.25, 20 + i * 2.5), Vector3(0.6, 0.5, 2.0), M.wood)  # benches
	box(Vector3(-40, 0.4, 37), Vector3(1.0, 0.8, 1.0), M.dark_metal)  # vending machine base
	box(Vector3(-40, 1.3, 37.5), Vector3(1.0, 1.8, 0.8), M.blue_paint)
	box(Vector3(-40, 1.5, 37.08), Vector3(0.7, 0.9, 0.04), M.screen, false, props)
	cyl(Vector3(-38, 0.5, 18), 0.3, 1.0, M.green_paint)  # planter
	sphere(Vector3(-38, 1.1, 18), 0.4, _flat(Color(0.1, 0.08, 0.04)), Vector3(1, 0.6, 1))
	# time clock + card rack next to the hall door
	box(Vector3(-36.4, 1.4, 34.5), Vector3(0.3, 0.6, 0.5), M.dark_metal, false, props)
	for i in range(14):
		box(Vector3(-36.3, 1.0 + (i % 7) * 0.14, 35.2 + int(i / 7) * 0.12), Vector3(0.03, 0.1, 0.08), M.paper, false, props, false)
	signage("KESSLER IRONWORKS\nPLANT 9", Vector3(-46, 3.2, 12.3), 0, 64, Color(0.8, 0.75, 0.6))
	signage("DAYS WITHOUT AN INCIDENT:  0", Vector3(-59.7, 2.6, 26), 90, 36, Color(0.9, 0.3, 0.2))
	signage("PRODUCTION HALL  >", Vector3(-36.3, 3.8, 30), -90, 36)
	signage("LOCKER ROOMS", Vector3(-48, 3.8, 12.3), 0, 32)
	signage("CLOCK IN.\nEVERY SHIFT. EVERY WORKER.", Vector3(-36.3, 2.4, 34.5), -90, 22)

	lamp(Vector3(-46, LOW_H - 0.1, 26), Color(1.0, 0.9, 0.7), 0.9, 9.0, false, 0.9, "tube")
	lamp(Vector3(-46, LOW_H - 0.1, 18), Color(1.0, 0.9, 0.7), 1.0, 9.0, true, 0.2, "tube")
	lamp(Vector3(-52, LOW_H - 0.1, 30), Color(1.0, 0.9, 0.7), 1.0, 9.0, true, 0.1, "tube")
	emergency(Vector3(-37, 3.9, 30))
	emergency(Vector3(-48, 3.4, 39.6))
	stain(Vector3(-44, 0, 32), Vector2(2.0, 1.2))
	stain(Vector3(-50, 0, 20), Vector2(1.0, 1.4), M.oil)


# ================================================================ main hall
func _build_hall() -> void:
	# structural pillars
	for x in [-30.0, -14.0, 4.0, 14.0]:
		for z in [-6.0, 6.0, 18.0, 30.0]:
			box(Vector3(x, HIGH_H * 0.5, z), Vector3(0.8, HIGH_H, 0.8), M.rust)
			box(Vector3(x, 0.6, z), Vector3(1.0, 1.2, 1.0), M.hazard)
	# crane rail + chains
	box(Vector3(-8, 10.0, 14), Vector3(56, 0.6, 0.6), M.yellow, false, props)
	box(Vector3(-12, 9.4, 14), Vector3(2.0, 0.8, 1.6), M.dark_metal, false, props)
	for i in range(18):
		box(Vector3(-12, 9.0 - i * 0.22, 14), Vector3(0.08, 0.18, 0.04 if i % 2 == 0 else 0.1), M.dark_metal, false, props, false)
	box(Vector3(-12, 4.9, 14), Vector3(0.6, 0.3, 0.2), M.rust, false, props)  # hook

	# conveyor line A & B, each with a gap to cross
	for seg in [[-22.0, -10.0, 8.0], [-22.0, 12.0, 34.0], [-4.0, -10.0, 14.0], [-4.0, 18.0, 34.0]]:
		_conveyor(seg[0], seg[1], seg[2])
	signage("LINE 9", Vector3(-22, 2.6, 34.6), 0, 72, Color(0.9, 0.8, 0.2), false)
	signage("LINE 8", Vector3(-4, 2.6, 34.6), 0, 72, Color(0.9, 0.8, 0.2), false)
	# presses
	for p in [Vector3(-22, 0, 0), Vector3(-22, 0, 24), Vector3(-4, 0, 4), Vector3(-4, 0, 28)]:
		_press(p)
	# robotic arms
	for p in [Vector3(-19.5, 0, 16), Vector3(-6.8, 0, 9), Vector3(-1.2, 0, 22)]:
		_robot_arm(p)

	# crate & barrel clusters
	for c in [Vector3(8, 0, 32), Vector3(9.5, 0, 33), Vector3(8.6, 1.2, 32.5), Vector3(14, 0, -3), Vector3(15.4, 0, -2.6), Vector3(-32, 0, 22), Vector3(-32, 0, 23.4), Vector3(-30, 0, -12), Vector3(-31.5, 0, -11.5)]:
		crate(c)
	for b in [Vector3(10, 0, 30.5), Vector3(11, 0, 30), Vector3(16, 0, -5), Vector3(-33.5, 0, 25), Vector3(-34, 0, 26), Vector3(17.5, 0, 36), Vector3(18.2, 0, 35.2)]:
		barrel(b)

	# breaker panel (main fuse box) on the west wall
	_build_fusebox(Vector3(-35.65, 0, 6))
	table(Vector3(-34.2, 0, 2.0), Vector3(1.2, 0.9, 0.7))

	# 14 hard hats in a circle around a dark stain
	var c := Vector3(8, 0, 12)
	stain(c, Vector2(3.0, 3.0), M.blood)
	for i in range(14):
		var a := TAU * i / 14.0
		hardhat(c + Vector3(cos(a), 0, sin(a)) * 2.2, Color(0.75, 0.6, 0.08) if i != 13 else Color(0.8, 0.8, 0.8))

	# catwalk along the north wall (decorative)
	box(Vector3(-8, 5.0, -14.8), Vector3(54, 0.1, 2.0), M.grate, false, props)
	box(Vector3(-8, 6.0, -13.85), Vector3(54, 0.06, 0.06), M.yellow, false, props, false)
	for i in range(28):
		box(Vector3(-34 + i * 2.0, 5.5, -13.85), Vector3(0.05, 1.0, 0.05), M.yellow, false, props, false)
	# overhead pipes
	pipe_run(Vector3(-35.5, 8.5, -12), Vector3(19.5, 8.5, -12), 0.35)
	pipe_run(Vector3(-35.5, 9.2, 38), Vector3(19.5, 9.2, 38), 0.45, M.green_paint)
	pipe_run(Vector3(18, 7.8, -15.5), Vector3(18, 7.8, 39.5), 0.3)
	pipe_run(Vector3(-35.5, 7.0, 8), Vector3(19.5, 7.0, 8), 0.2, M.blue_paint)

	# lockers to hide in
	locker_at(Vector3(-35.2, 0, 16), Vector3.RIGHT)
	locker_at(Vector3(-35.2, 0, 17), Vector3.RIGHT)
	locker_at(Vector3(19.2, 0, 20), Vector3.LEFT)
	locker_at(Vector3(0, 0, 39.2), Vector3.FORWARD)
	locker_at(Vector3(1, 0, 39.2), Vector3.FORWARD)
	locker_at(Vector3(12, 0, -15.2), Vector3.BACK)

	# stains & floor markings
	for z in range(-14, 40, 4):
		box(Vector3(-25.0, 0.003, z), Vector3(0.12, 0.006, 2.0), M.white_line, false, props, false)
		box(Vector3(-1.0, 0.003, z), Vector3(0.12, 0.006, 2.0), M.white_line, false, props, false)
	for s in [Vector3(-20, 0, 10), Vector3(-10, 0, -8), Vector3(10, 0, 4), Vector3(-26, 0, 30), Vector3(2, 0, 12)]:
		stain(s, Vector2(randf_range(1, 3), randf_range(1, 3)))
	# a drag mark of something dark leading toward the furnace
	for i in range(10):
		stain(Vector3(-10 + randf_range(-0.3, 0.3), 0, 2 - i * 1.6), Vector2(0.6, 1.2), M.blood)

	signage("WAREHOUSE B  >", Vector3(19.7, 5.6, 8), -90, 48)
	signage("FURNACE / SMELTING", Vector3(-10, 6.6, -15.7), 0, 48)
	signage("SAFETY IS EVERYONE'S JOB", Vector3(-35.7, 4.5, 20), 90, 40, Color(0.9, 0.8, 0.3))
	signage("QUOTA: 14", Vector3(-22, 5, -15.7), 0, 40, Color(0.9, 0.3, 0.2))

	# hall lights (powered)
	for x in [-26.0, -8.0, 10.0]:
		for z in [-8.0, 6.0, 20.0, 34.0]:
			lamp(Vector3(x, 8.6, z), Color(1.0, 0.82, 0.55), 2.2, 18.0, true, 0.08 if randf() < 0.7 else 0.5)
	emergency(Vector3(-35.6, 3.9, -2))
	emergency(Vector3(-35.6, 3.9, 30))
	emergency(Vector3(-35.4, 2.6, 6), 0.4)
	emergency(Vector3(19.6, 3.9, 30))
	emergency(Vector3(19.6, 5.3, 8))
	emergency(Vector3(-10, 6.3, -15.6))
	emergency(Vector3(6, 3.0, 16), 0.6)

	# hum of the dead machines comes back with power
	var hum_root := Node3D.new()
	hum_root.name = "MachineHum"
	props.add_child(hum_root)
	for p in [Vector3(-22, 1, 0), Vector3(-22, 1, 24), Vector3(-4, 1, 4), Vector3(-4, 1, 28)]:
		var a := Sfx.loop_3d("amb_machine", hum_root, p, -4.0, 26.0, 4.0, false)
		a.add_to_group("power_sounds", true)
	for p in [Vector3(-30, 9, 0), Vector3(10, 9, 30)]:
		Sfx.loop_3d("amb_vent", props, p, -12.0, 25.0, 4.0)


func _conveyor(x: float, z0: float, z1: float) -> void:
	var len := z1 - z0
	var cz := (z0 + z1) * 0.5
	box(Vector3(x, 0.45, cz), Vector3(2.0, 0.9, len), M.dark_metal)
	box(Vector3(x, 0.92, cz), Vector3(1.7, 0.04, len), M.rubber, false, props)
	box(Vector3(x - 0.95, 1.0, cz), Vector3(0.1, 0.2, len), M.hazard, false, props)
	box(Vector3(x + 0.95, 1.0, cz), Vector3(0.1, 0.2, len), M.hazard, false, props)
	var z := z0 + 1.0
	while z < z1 - 1.0:
		if randf() < 0.35:
			var s := randf_range(0.35, 0.6)
			box(Vector3(x + randf_range(-0.3, 0.3), 0.94 + s * 0.5, z), Vector3(s, s, s), M.rust if randf() < 0.5 else M.metal, false, props)
		z += randf_range(1.5, 3.0)


func _press(p: Vector3) -> void:
	for sx in [-1.6, 1.6]:
		box(p + Vector3(sx, 3.0, 0), Vector3(0.6, 6.0, 1.4), M.green_paint)
	box(p + Vector3(0, 6.3, 0), Vector3(4.0, 1.0, 1.8), M.green_paint, false, props)
	box(p + Vector3(0, 3.6, 0), Vector3(2.4, 1.6, 1.4), M.dark_metal, false, props)
	cyl(p + Vector3(0, 5.0, 0), 0.25, 1.4, M.metal, "y", false, props)
	box(p + Vector3(0, 6.3, 0.91), Vector3(3.8, 0.3, 0.02), M.hazard, false, props, false)


func _robot_arm(p: Vector3) -> void:
	cyl(p + Vector3(0, 0.4, 0), 0.6, 0.8, M.yellow)
	var root := Node3D.new()
	root.position = p + Vector3(0, 0.8, 0)
	root.rotation.y = randf() * TAU
	props.add_child(root)
	var a1 := box(Vector3(0, 1.0, 0.3), Vector3(0.35, 2.0, 0.35), M.yellow, false, root)
	a1.rotation.x = 0.35
	var a2 := box(Vector3(0, 1.9, 1.2), Vector3(0.28, 0.28, 1.8), M.yellow, false, root)
	a2.rotation.x = -0.4
	box(Vector3(0, 1.4, 2.0), Vector3(0.2, 0.6, 0.2), M.dark_metal, false, root)


func _build_fusebox(base: Vector3) -> void:
	fusebox = Usable.new()
	fusebox.name = "FuseBox"
	fusebox.position = base + Vector3(0.2, 0, 0)
	geo.add_child(fusebox)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.4, 1.4, 1.2)
	cs.shape = bs
	cs.position = Vector3(0, 1.5, 0)
	fusebox.add_child(cs)
	box(Vector3(0, 1.5, 0), Vector3(0.35, 1.4, 1.2), M.dark_metal, false, fusebox)
	box(Vector3(0.18, 1.5, 0), Vector3(0.02, 1.25, 1.05), M.metal, false, fusebox)
	box(Vector3(0.19, 2.1, 0), Vector3(0.02, 0.12, 1.0), M.hazard, false, fusebox, false)
	for i in range(3):
		var slot := box(Vector3(0.2, 1.55, -0.3 + i * 0.3), Vector3(0.06, 0.4, 0.14), M.dark_metal, false, fusebox)
		slot.name = "FuseSlot%d" % i
		fuse_slots.append(slot)
	box(Vector3(0.2, 1.0, 0.35), Vector3(0.1, 0.35, 0.08), M.rust, false, fusebox)  # main lever
	signage("MAIN BREAKER\nLINES 1-9", Vector3(0.21, 2.45, 0), 90, 24, Color(0.9, 0.9, 0.85), false).reparent(fusebox, false)
	# cables running up from the panel
	for i in range(3):
		box(Vector3(0.05, 6.0, -0.3 + i * 0.3), Vector3(0.06, 7.6, 0.06), M.rubber, false, fusebox, false)


func set_fuse_visual(i: int) -> void:
	if i < fuse_slots.size():
		fuse_slots[i].material_override = _glow(Color(0.3, 0.8, 1.0), 2.0)


# ================================================================ warehouse
func _build_warehouse() -> void:
	for z in [2.0, 10.0, 18.0]:
		shelf_rack(25, 37.5, z)
		shelf_rack(40.5, 53, z)
	shelf_rack(26, 34, 36.5, 4.0)
	# forklift
	var f := Vector3(30, 0, 29)
	box(f + Vector3(0, 0.8, 0), Vector3(1.4, 1.2, 2.4), M.yellow)
	box(f + Vector3(0, 2.0, 0.4), Vector3(1.3, 0.08, 1.4), M.dark_metal, false, props)
	for sx in [-0.62, 0.62]:
		box(f + Vector3(sx, 1.2, 1.0), Vector3(0.06, 1.6, 0.06), M.dark_metal, false, props)
		box(f + Vector3(sx * 0.5, 0.1, -1.8), Vector3(0.15, 0.06, 1.2), M.dark_metal, false, props)
	box(f + Vector3(0, 1.8, -1.25), Vector3(1.3, 2.6, 0.12), M.dark_metal, false, props)
	for w in [Vector3(-0.72, 0.35, 0.8), Vector3(0.72, 0.35, 0.8), Vector3(-0.72, 0.35, -0.7), Vector3(0.72, 0.35, -0.7)]:
		cyl(f + w, 0.35, 0.25, M.rubber, "x", false, props, 12)
	# pallets & crate stacks
	for p in [Vector3(45, 0, 33), Vector3(46.3, 0, 33), Vector3(45.6, 1.2, 33), Vector3(56.5, 0, 37.5), Vector3(55.2, 0, 37.5), Vector3(55.5, 0, 14), Vector3(22.5, 0, 38)]:
		crate(p)
	crate(Vector3(56.5, 0, 10), 1.0, M.green_paint)
	# specimen crates - stencilled
	for p in [Vector3(36, 0, 25), Vector3(37.4, 0, 25.3)]:
		crate(p, 1.3, M.green_paint)
	signage("SPECIMEN ORE\nDO NOT OPEN", Vector3(36.7, 0.9, 25.98), 0, 20, Color(0.9, 0.9, 0.8), false)
	table(Vector3(22.6, 0, -2.2), Vector3(1.4, 0.9, 0.7), M.wood)

	signage("LOADING BAY", Vector3(59.7, 6.8, 26), -90, 64, Color(0.9, 0.8, 0.2))
	signage("BOILER ROOM  v", Vector3(44, 4.1, -3.7), 0, 32)
	for i in range(8):
		box(Vector3(59.7, 0.004, 22.5 + i), Vector3(0.6, 0.008, 0.5), M.yellow, false, props, false)
	box(Vector3(56, 0.004, 26), Vector3(0.12, 0.008, 8.0), M.yellow, false, props, false)

	for x in [28.0, 40.0, 52.0]:
		for z in [6.0, 22.0, 34.0]:
			lamp(Vector3(x, 8.0, z), Color(0.85, 0.9, 1.0), 1.8, 16.0, true, 0.1 if randf() < 0.75 else 0.6)
	emergency(Vector3(59.6, 6.5, 21.5))
	emergency(Vector3(59.6, 6.5, 30.5))
	emergency(Vector3(44, 3.8, -3.6))
	emergency(Vector3(20.6, 3.8, 30))
	emergency(Vector3(38, 2.0, 14), 0.5)
	for s in [Vector3(32, 0, 14), Vector3(48, 0, 26), Vector3(42, 0, -1)]:
		stain(s, Vector2(randf_range(1, 2.5), randf_range(1, 2.5)))
	Sfx.loop_3d("amb_vent", props, Vector3(40, 10, 20), -10.0, 30.0, 5.0)
	locker_at(Vector3(21.0, 0, 16), Vector3.RIGHT)
	locker_at(Vector3(59.2, 0, 4), Vector3.LEFT)
	locker_at(Vector3(59.2, 0, 5), Vector3.LEFT)
	locker_at(Vector3(40, 0, 39.2), Vector3.FORWARD)


# ================================================================ boiler room
func _build_boiler() -> void:
	# grating overlay
	box(Vector3(40, 0.01, -22), Vector3(40, 0.02, 36), M.grate, false, props, false)
	# boilers
	for x in [32.0, 46.0]:
		cyl(Vector3(x, 2.4, -30), 2.2, 8.0, M.rust, "x")
		cyl(Vector3(x - 4.05, 2.4, -30), 2.3, 0.2, M.dark_metal, "x", false, props)
		cyl(Vector3(x + 4.05, 2.4, -30), 2.3, 0.2, M.dark_metal, "x", false, props)
		for sx in [-3.0, 3.0]:
			box(Vector3(x + sx, 0.4, -30), Vector3(0.6, 0.8, 4.0), M.dark_metal)
		cyl(Vector3(x, 4.6 + 3.5, -30), 0.4, 7.0, M.rust, "y", false, props, 10)
		# gauge
		cyl(Vector3(x - 4.2, 3.2, -30), 0.22, 0.08, M.ceramic, "x", false, props, 12)
		steam_vent(Vector3(x + 2.0, 4.5, -28.5), Vector3(0.3, 1, 0.2))
	# water tanks
	cyl(Vector3(56, 3.0, -35), 2.2, 6.0, M.green_paint)
	cyl(Vector3(56, 3.0, -24), 1.6, 6.0, M.green_paint)
	# pipe maze
	pipe_run(Vector3(20.5, 6.0, -20), Vector3(59.5, 6.0, -20), 0.4)
	pipe_run(Vector3(20.5, 4.5, -10), Vector3(59.5, 4.5, -10), 0.25, M.blue_paint)
	pipe_run(Vector3(36, 0.4, -39.5), Vector3(36, 0.4, -33), 0.3)
	pipe_run(Vector3(25, 8.0, -39.5), Vector3(25, 8.0, -4.5), 0.35)
	pipe_run(Vector3(40, 9.0, -39.5), Vector3(40, 9.0, -4.5), 0.5, M.dark_metal)
	for x in [26.0, 34.0, 52.0]:
		pipe_run(Vector3(x, 0.0, -20), Vector3(x, 6.0, -20), 0.2)
	steam_vent(Vector3(30, 6.0, -20), Vector3(0, -1, 0.3))
	steam_vent(Vector3(50, 4.5, -10), Vector3(0.4, 1, 0))
	# workbench with tools
	table(Vector3(26, 0, -14), Vector3(2.0, 0.9, 0.8))
	box(Vector3(26.4, 1.05, -14), Vector3(0.5, 0.25, 0.3), _flat(Color(0.6, 0.1, 0.05)), false, props)

	# backup generator
	generator = Usable.new()
	generator.name = "Generator"
	generator.position = Vector3(50, 0, -14)
	geo.add_child(generator)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.2, 2.6, 2.4)
	cs.shape = bs
	cs.position.y = 1.3
	generator.add_child(cs)
	box(Vector3(0, 1.2, 0), Vector3(4.0, 2.2, 2.2), M.green_paint, false, generator)
	box(Vector3(0, 0.15, 0), Vector3(4.4, 0.3, 2.6), M.dark_metal, false, generator)
	box(Vector3(-1.2, 2.45, 0), Vector3(1.2, 0.5, 1.0), M.dark_metal, false, generator)
	for i in range(8):
		box(Vector3(1.0 + i * 0.12, 1.4, 1.11), Vector3(0.05, 1.2, 0.02), M.dark_metal, false, generator, false)
	box(Vector3(-1.2, 1.4, 1.12), Vector3(0.8, 0.6, 0.04), M.dark_metal, false, generator)
	box(Vector3(-1.4, 1.5, 1.15), Vector3(0.12, 0.12, 0.04), _glow(Color(1, 0.2, 0.1), 1.5), false, generator)
	cyl(Vector3(1.6, 4.6, -0.6), 0.2, 4.4, M.rust, "y", false, generator, 10)
	signage("BACKUP GENERATOR\nPULL TO START", Vector3(-1.2, 1.85, 1.15), 0, 18, Color(0.9, 0.9, 0.85), false).reparent(generator, false)
	generator_exhaust = CPUParticles3D.new()
	generator_exhaust.name = "Exhaust"
	generator_exhaust.emitting = false
	generator_exhaust.amount = 30
	generator_exhaust.lifetime = 3.0
	generator_exhaust.direction = Vector3.UP
	generator_exhaust.spread = 10
	generator_exhaust.initial_velocity_min = 1.5
	generator_exhaust.initial_velocity_max = 2.5
	generator_exhaust.gravity = Vector3(0.2, 0.3, 0)
	generator_exhaust.scale_amount_min = 1.0
	generator_exhaust.scale_amount_max = 2.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _soft_dot()
	qm.material = sm
	generator_exhaust.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(0.15, 0.15, 0.15, 0.4))
	g.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	generator_exhaust.color_ramp = g
	generator_exhaust.position = Vector3(1.6, 6.8, -0.6)
	generator.add_child(generator_exhaust)

	signage("BOILER ROOM  >", Vector3(19.7, 4.1, -28), -90, 32)
	for x in [30.0, 46.0]:
		for z in [-34.0, -12.0]:
			lamp(Vector3(x, 7.5, z), Color(1.0, 0.75, 0.45), 1.6, 14.0, true, 0.3)
	lamp(Vector3(50, 3.2, -11.3), Color(1.0, 0.6, 0.3), 0.6, 4.5, false, 0.7, "cage")
	emergency(Vector3(20.6, 3.8, -28))
	emergency(Vector3(44, 3.8, -4.4))
	emergency(Vector3(39, 2.5, -36), 0.4)
	locker_at(Vector3(21.0, 0, -36), Vector3.RIGHT)
	locker_at(Vector3(59.2, 0, -14), Vector3.LEFT)
	for i in range(3):
		Sfx.loop_3d("amb_vent", props, Vector3(25 + i * 15, 9, -30), -14.0, 18.0, 3.0)


# ================================================================ furnace
func _build_furnace() -> void:
	# walkway grating near the hall opening
	box(Vector3(-8, 0.01, -19), Vector3(56, 0.02, 6), M.grate, false, props, false)
	# the furnace
	box(Vector3(-8, 4.5, -37), Vector3(12, 9, 6), M.slag)
	box(Vector3(-8, 4.5, -33.9), Vector3(12.4, 0.6, 0.3), M.hazard, false, props)
	box(Vector3(-8, 9.5, -37), Vector3(10, 1.0, 5), M.rust, false, props)
	cyl(Vector3(-8, 10.8, -37), 1.2, 2.6, M.rust, "y", false, props)
	# glowing mouth
	box(Vector3(-8, 2.2, -33.98), Vector3(4.0, 2.6, 0.05), M.molten, false, props, false)
	box(Vector3(-8, 0.5, -33.0), Vector3(4.6, 1.0, 1.8), M.slag)
	box(Vector3(-8, 1.01, -33.0), Vector3(3.6, 0.04, 1.4), M.molten_dim, false, props, false)
	# molten channel to the casting pit
	box(Vector3(-8, 0.2, -28.5), Vector3(1.2, 0.4, 7.0), M.slag)
	box(Vector3(-8, 0.41, -28.5), Vector3(0.8, 0.02, 7.0), M.molten, false, props, false)
	box(Vector3(-8, 0.4, -24.5), Vector3(4.0, 0.8, 2.0), M.slag)
	box(Vector3(-8, 0.81, -24.5), Vector3(3.4, 0.02, 1.5), M.molten_dim, false, props, false)
	# ladles hanging from the rail
	box(Vector3(-8, 9.5, -26), Vector3(50, 0.5, 0.5), M.yellow, false, props)
	for x in [-26.0, 8.0]:
		cyl(Vector3(x, 3.6, -26), 1.3, 2.0, M.rust, "y", false, props)
		box(Vector3(x, 6.6, -26), Vector3(0.1, 4.6, 0.1), M.dark_metal, false, props, false)
		box(Vector3(x, 4.63, -26), Vector3(2.0, 0.05, 2.0), M.molten_dim, false, props, false)
	# slag heaps
	for p in [Vector3(-20, 0, -36), Vector3(-17, 0, -38), Vector3(2, 0, -37), Vector3(-28, 0, -30)]:
		var mi := sphere(p, 1.4, M.slag, Vector3(1.4, 0.6, 1.2))
		mi.rotation.y = randf() * TAU
		box(p + Vector3(0, 0.3, 0), Vector3(2.4, 0.6, 2.0), M.slag, true, geo, false).visible = false
	# workbench where fuse C lies
	table(Vector3(-32, 0, -37.6), Vector3(2.4, 0.95, 0.9))
	box(Vector3(-33, 1.1, -37.6), Vector3(0.4, 0.3, 0.3), M.dark_metal, false, props)

	# Line 9 control booth (SE corner)
	wall_z(8, -40, -32, 3.2, [[-34.0, 1.6, 2.4]], M.office_wall, 0.25)
	box(Vector3(13, 0.55, -32), Vector3(10, 1.1, 0.25), M.office_wall)
	box(Vector3(13, 2.85, -32), Vector3(10, 0.7, 0.25), M.office_wall)
	box(Vector3(13, 1.8, -32), Vector3(10, 1.4, 0.04), M.glass, false, props, false)
	box(Vector3(13, 3.25, -36), Vector3(10.2, 0.1, 8.2), M.concrete, false, props)
	lamp(Vector3(13, 3.1, -36), Color(0.8, 1.0, 0.85), 0.9, 6.0, true, 0.3, "tube")
	signage("LINE 9 CONTROL", Vector3(13, 2.85, -31.85), 0, 32, Color(0.9, 0.8, 0.2))
	console = Usable.new()
	console.name = "Line9Console"
	console.position = Vector3(14, 0, -39.2)
	geo.add_child(console)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 1.2, 1.0)
	cs.shape = bs
	cs.position.y = 0.6
	console.add_child(cs)
	box(Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 0.9), M.dark_metal, false, console)
	var top := box(Vector3(0, 1.2, 0.1), Vector3(3.2, 0.1, 0.8), M.metal, false, console)
	top.rotation.x = 0.3
	console_screen_mat = _glow(Color(0.8, 0.15, 0.05), 0.6)
	box(Vector3(0, 1.7, -0.35), Vector3(1.6, 0.9, 0.06), console_screen_mat, false, console).name = "Screen"
	for i in range(10):
		box(Vector3(-1.3 + i * 0.28, 1.27, 0.25), Vector3(0.1, 0.06, 0.1), _glow(Color(randf(), randf_range(0.3, 1), 0.1), 0.6), false, console)
	box(Vector3(1.2, 1.3, 0.2), Vector3(0.18, 0.05, 0.12), M.dark_metal, false, console)  # card reader
	box(Vector3(1.2, 1.36, 0.2), Vector3(0.12, 0.02, 0.04), _glow(Color(1, 0.1, 0.05), 2.0), false, console)
	table(Vector3(10, 0, -39.3), Vector3(1.6, 0.9, 0.7), M.metal)

	# lights: the furnace somehow still burns
	var fglow := lamp(Vector3(-8, 2.5, -31), Color(1.0, 0.45, 0.12), 3.5, 18.0, false, 0.25, "none", true)
	fglow.base_energy = 3.5
	lamp(Vector3(-8, 1.5, -24.5), Color(1.0, 0.4, 0.1), 1.6, 8.0, false, 0.3, "none")
	for x in [-26.0, 8.0]:
		lamp(Vector3(x, 8.6, -21.0), Color(1.0, 0.8, 0.55), 1.8, 16.0, true, 0.2)
	emergency(Vector3(-35.4, 3.0, -36))
	emergency(Vector3(19.5, 3.8, -28))
	Sfx.loop_3d("furnace_roar", props, Vector3(-8, 2, -32), 0.0, 32.0, 6.0)
	locker_at(Vector3(-35.2, 0, -24), Vector3.RIGHT)
	locker_at(Vector3(-35.2, 0, -25), Vector3.RIGHT)
	locker_at(Vector3(19.2, 0, -20), Vector3.LEFT)
	signage("IT DOES NOT MELT", Vector3(-35.7, 3.2, -30), 90, 48, Color(0.6, 0.05, 0.03), false)


# ================================================================ locker rooms
func _build_lockers() -> void:
	box(Vector3(-48, 0.005, -2), Vector3(24, 0.01, 28), M.tile, false, props, false)
	for z in range(-6, 11):
		locker_at(Vector3(-59.2, 0, z), Vector3.RIGHT)
	for z in range(3, 11):
		locker_at(Vector3(-36.8, 0, z + 0.5), Vector3.LEFT)
	for z in range(-6, 5):
		locker_at(Vector3(-50.0, 0, z), Vector3.LEFT)
	# benches
	for x in [-53.0, -44.0]:
		box(Vector3(x, 0.45, 1.0), Vector3(0.45, 0.08, 14), M.wood)
		for z in [-5.0, 1.0, 7.0]:
			box(Vector3(x, 0.2, z), Vector3(0.3, 0.42, 0.3), M.dark_metal, false, props)
	# showers / partitions at the south end
	for i in range(5):
		box(Vector3(-59.0 + i * 2.2, 1.1, -12.0), Vector3(0.08, 2.2, 3.5), M.tile)
		cyl(Vector3(-58.0 + i * 2.2, 2.4, -14.5), 0.12, 0.05, M.metal, "y", false, props)
	box(Vector3(-46, 0.5, -10), Vector3(1.8, 0.08, 0.6), M.wood)
	box(Vector3(-46, 0.24, -10), Vector3(0.3, 0.46, 0.3), M.dark_metal, false, props)
	box(Vector3(-55, 1.6, 11.7), Vector3(3.0, 1.2, 0.05), _flat(Color(0.5, 0.55, 0.55), 0.05, 1.0), false, props, false)  # mirror
	# the drip
	var dp := Node3D.new()
	dp.position = Vector3(-56, 3, -14)
	dp.name = "Drip"
	props.add_child(dp)
	stain(Vector3(-56, 0, -14), Vector2(1.5, 1.5), M.oil)

	lamp(Vector3(-52, LOW_H - 0.1, 6), Color(0.85, 0.95, 1.0), 1.0, 9.0, true, 0.6, "tube")
	lamp(Vector3(-44, LOW_H - 0.1, -4), Color(0.85, 0.95, 1.0), 1.0, 9.0, true, 0.15, "tube")
	lamp(Vector3(-55, LOW_H - 0.1, -12), Color(0.85, 0.95, 1.0), 0.5, 7.0, false, 0.95, "tube")
	emergency(Vector3(-48, 3.9, 11.6))
	emergency(Vector3(-37.0, 3.9, -2))
	emergency(Vector3(-48, 3.9, -15.6))
	signage("FOREMAN", Vector3(-48, 3.9, -15.7), 0, 32)
	signage("WASH YOUR HANDS.\nTHEY KNOW WHAT YOU TOUCHED.", Vector3(-59.7, 2.4, -9), 90, 20, Color(0.7, 0.7, 0.6))


# ================================================================ foreman office
func _build_foreman() -> void:
	box(Vector3(-48, 0.005, -28), Vector3(24, 0.01, 24), M.wood, false, props, false)
	# desk
	box(Vector3(-48, 0.4, -32), Vector3(2.6, 0.8, 1.2), M.wood)
	box(Vector3(-48, 0.81, -32), Vector3(2.7, 0.03, 1.3), M.dark_metal, false, props)
	box(Vector3(-49, 0.95, -32.3), Vector3(0.4, 0.25, 0.3), M.dark_metal, false, props)  # radio set
	box(Vector3(-48, 0.25, -33.2), Vector3(0.6, 0.5, 0.6), M.dark_metal)  # chair
	box(Vector3(-48, 0.8, -33.5), Vector3(0.6, 0.6, 0.08), M.dark_metal, false, props)
	# filing cabinets along the west wall
	for z in [-38.0, -37.0, -36.0, -35.0]:
		box(Vector3(-59.4, 0.65, z), Vector3(0.7, 1.3, 0.9), M.green_paint)
	# chalkboard with tally marks: fourteen, and a fifteenth started
	box(Vector3(-36.35, 2.0, -28), Vector3(0.06, 1.6, 4.0), M.chalkboard)
	for i in range(15):
		var group := int(i / 5)
		var k := i % 5
		var zz := -29.6 + group * 1.1 + k * 0.18
		if k == 4:
			var slash := box(Vector3(-36.4, 2.1, zz - 0.36), Vector3(0.01, 0.05, 0.9), M.chalk, false, props, false)
			slash.rotation.x = 0.6
		else:
			box(Vector3(-36.4, 2.1, zz), Vector3(0.01, 0.6, 0.04), M.chalk if i < 14 else M.blood, false, props, false)
	signage("SHIFT COUNT", Vector3(-36.4, 2.62, -28), -90, 24, Color(0.85, 0.85, 0.8), false)
	# photos of fourteen workers
	for i in range(14):
		var r := int(i / 7)
		var c := i % 7
		box(Vector3(-48 + (c - 3) * 0.6, 2.4 - r * 0.7, -39.7), Vector3(0.4, 0.5, 0.03), M.paper if i != 6 else M.blood, false, props, false)
	# a chair facing the corner
	box(Vector3(-58.5, 0.25, -17.2), Vector3(0.6, 0.5, 0.6), M.dark_metal)
	box(Vector3(-58.5, 0.8, -16.9), Vector3(0.6, 0.6, 0.08), M.dark_metal, false, props)
	stain(Vector3(-52, 0, -24), Vector2(1.2, 2.5), M.blood)
	stain(Vector3(-54, 0, -26), Vector2(0.8, 1.4), M.blood)

	lamp(Vector3(-48, LOW_H - 0.1, -28), Color(1.0, 0.85, 0.6), 1.0, 10.0, true, 0.4, "tube")
	lamp(Vector3(-54, LOW_H - 0.1, -36), Color(1.0, 0.85, 0.6), 0.8, 8.0, true, 0.8, "tube")
	writing_label = signage("HE COUNTS US", Vector3(-36.35, 3.3, -22), -90, 64, Color(0.5, 0.03, 0.02), false)
	writing_label.name = "HeCountsUs"
	writing_label.visible = false
	signage("E. VOSS - SHIFT FOREMAN", Vector3(-48, 3.0, -16.3), 180, 26)


# ================================================================ exterior
func _build_exterior() -> void:
	box(Vector3(70, -0.25, 26), Vector3(20, 0.5, 20), M.concrete)
	box(Vector3(70, 3, 36.2), Vector3(20, 6, 0.4), M.wall)
	box(Vector3(70, 3, 15.8), Vector3(20, 6, 0.4), M.wall)
	var dawn := OmniLight3D.new()
	dawn.light_color = Color(0.6, 0.65, 0.85)
	dawn.light_energy = 1.2
	dawn.omni_range = 20.0
	dawn.position = Vector3(70, 6, 26)
	lights.add_child(dawn)
	for i in range(2):
		var al := SpotLight3D.new()
		al.light_color = Color(1, 0.2, 0.05)
		al.light_energy = 0.0
		al.spot_range = 18.0
		al.spot_angle = 25.0
		al.light_volumetric_fog_energy = 2.5
		al.position = Vector3(59.0, 6.6, 21.0 + i * 10.0)
		al.name = "AlarmLight%d" % alarm_lights.size()
		lights.add_child(al)
		alarm_lights.append(al)
	var cl := SpotLight3D.new()
	cl.light_color = Color(1, 0.2, 0.05)
	cl.light_energy = 0.0
	cl.spot_range = 14.0
	cl.spot_angle = 25.0
	cl.position = Vector3(13, 3.0, -33)
	cl.name = "AlarmLight%d" % alarm_lights.size()
	lights.add_child(cl)
	alarm_lights.append(cl)
	var hl := SpotLight3D.new()
	hl.light_color = Color(1, 0.2, 0.05)
	hl.light_energy = 0.0
	hl.spot_range = 22.0
	hl.spot_angle = 30.0
	hl.position = Vector3(-8, 10.5, 12)
	hl.name = "AlarmLight%d" % alarm_lights.size()
	lights.add_child(hl)
	alarm_lights.append(hl)


func _build_patrol_points() -> void:
	patrol_points = [
		Vector3(-28, 0, -8), Vector3(-14, 0, 0), Vector3(-14, 0, 22), Vector3(0, 0, 36),
		Vector3(10, 0, 10), Vector3(12, 0, -10), Vector3(-30, 0, 34),
		Vector3(30, 0, 6), Vector3(47, 0, 6), Vector3(38.5, 0, 14), Vector3(30, 0, 24),
		Vector3(50, 0, 26), Vector3(42, 0, 36),
		Vector3(26, 0, -10), Vector3(38, 0, -20), Vector3(54, 0, -20), Vector3(40, 0, -37),
		Vector3(-30, 0, -22), Vector3(-20, 0, -30), Vector3(3, 0, -28), Vector3(12, 0, -20),
		Vector3(-42, 0, 0), Vector3(-52, 0, -4), Vector3(-42, 0, 8),
	]


# ================================================================ dynamic items
func add_pickup(pos: Vector3, prompt: String, kind: String, cb: Callable) -> Area3D:
	var root := Node3D.new()
	var glow := Color(0, 0, 0, 0)
	match kind:
		"flashlight":
			var body := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.035
			cm.bottom_radius = 0.03
			cm.height = 0.26
			body.mesh = cm
			body.material_override = M.rubber
			body.rotation.z = PI / 2
			root.add_child(body)
			var lens := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.05
			lm.bottom_radius = 0.036
			lm.height = 0.06
			lens.mesh = lm
			lens.material_override = _glow(Color(1, 0.95, 0.8), 0.4)
			lens.rotation.z = PI / 2
			lens.position.x = 0.15
			root.add_child(lens)
			glow = Color(1, 0.9, 0.7, 1)
		"fuse":
			var body := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.045
			cm.height = 0.2
			body.mesh = cm
			body.material_override = M.ceramic
			body.rotation.z = PI / 2
			root.add_child(body)
			for sx in [-0.12, 0.12]:
				var cap := MeshInstance3D.new()
				var cc := CylinderMesh.new()
				cc.top_radius = 0.05
				cc.bottom_radius = 0.05
				cc.height = 0.05
				cap.mesh = cc
				cap.material_override = M.brass
				cap.rotation.z = PI / 2
				cap.position.x = sx
				root.add_child(cap)
			glow = Color(0.3, 0.7, 1.0, 1)
		"battery":
			var body := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.025
			cm.height = 0.1
			body.mesh = cm
			body.material_override = _flat(Color(0.7, 0.45, 0.05), 0.4, 0.4)
			root.add_child(body)
			glow = Color(1.0, 0.7, 0.2, 1)
		"keycard":
			var card := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.09, 0.004, 0.055)
			card.mesh = bm
			card.material_override = _flat(Color(0.85, 0.85, 0.85), 0.5)
			root.add_child(card)
			var strip := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.09, 0.005, 0.012)
			strip.mesh = sm
			strip.material_override = _glow(Color(0.9, 0.1, 0.05), 1.0)
			strip.position.z = 0.015
			root.add_child(strip)
			glow = Color(1.0, 0.2, 0.1, 1)
	var p := Pickup.new()
	p.setup(prompt, root, glow)
	p.on_pick = cb
	p.position = pos
	props.add_child(p)
	return p


func add_note(pos: Vector3, id: String, title: String, body: String) -> void:
	var n := Note.new()
	n.setup(id, title, body)
	n.position = pos
	props.add_child(n)


func add_trigger(center: Vector3, size: Vector3, cb: Callable, once := true) -> Area3D:
	var t := Trigger.new()
	t.setup(size, cb, once)
	t.position = center
	props.add_child(t)
	return t
