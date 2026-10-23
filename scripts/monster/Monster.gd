extends CharacterBody3D
## "The Foreman" - the thing that walks Plant 9.
## Patrols, hears noise, sees the player, chases, searches, and kills.

signal chase_started
signal chase_ended
signal caught_player

enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, AMBUSH_LOCKER, KILL }

const PATROL_SPEED := 1.9
const INVESTIGATE_SPEED := 2.9
const CHASE_SPEED := 4.75
const ENRAGED_SPEED := 5.35
const KILL_DISTANCE := 1.35

var state := State.DORMANT
var phantom := false  # a non-interactive apparition used for scripted glimpses
var patrol_points: Array[Vector3] = []
var enraged := false

var agent: NavigationAgent3D
var visual: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _eye_mat: StandardMaterial3D
var _eye_light: OmniLight3D
var _breath: AudioStreamPlayer3D

var _target := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _sees_player := false
var _vision_timer := 0.0
var _lose_timer := 0.0
var _search_timer := 0.0
var _wait_timer := 0.0
var _growl_timer := 8.0
var _door_timer := 0.0
var _step_acc := 0.0
var _anim_t := 0.0
var _grace := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector3.ZERO
var _saw_hide := false
var _hide_spot: Node = null
var _seen_time := 0.0
var _speed := 0.0


func _ready() -> void:
	if phantom:
		collision_layer = 0
		collision_mask = 0
		_build_model()
		_eye_light.light_energy = 0.6
		set_physics_process(false)
		return
	collision_layer = 8
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.4
	cs.shape = cap
	cs.position.y = 1.2
	add_child(cs)

	agent = NavigationAgent3D.new()
	agent.radius = 0.6
	agent.height = 2.4
	agent.path_desired_distance = 0.9
	agent.target_desired_distance = 1.0
	agent.avoidance_enabled = false
	add_child(agent)

	_build_model()

	_breath = Sfx.loop_3d("monster_breath", self, Vector3(0, 2.3, 0), -4.0, 22.0, 3.0, false)

	Game.monster = self
	Game.noise_made.connect(_on_noise)
	visible = false
	set_physics_process(true)


# ------------------------------------------------------------ model
func _mat(col: Color, rough := 0.7, metal := 0.0, emissive := Color.BLACK, emi_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emi_e > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = emi_e
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _build_model() -> void:
	var flesh := _mat(Color(0.16, 0.09, 0.07), 0.55, 0.1)
	var char_mat := _mat(Color(0.05, 0.045, 0.04), 0.9)
	var rust := _mat(Color(0.32, 0.17, 0.08), 0.75, 0.6)
	var steel := _mat(Color(0.25, 0.25, 0.26), 0.45, 0.85)
	_eye_mat = _mat(Color(1, 0.4, 0.1), 0.3, 0.0, Color(1.0, 0.35, 0.05), 6.0)

	visual = Node3D.new()
	add_child(visual)

	_hips = _pivot(visual, Vector3(0, 1.25, 0))
	_part(_hips, _box(Vector3(0.5, 0.25, 0.3)), char_mat, Vector3.ZERO)
	# legs
	_leg_l = _pivot(_hips, Vector3(-0.18, -0.05, 0))
	_leg_r = _pivot(_hips, Vector3(0.18, -0.05, 0))
	for leg in [_leg_l, _leg_r]:
		_part(leg, _capsule(0.09, 0.7), flesh, Vector3(0, -0.32, 0))
		var shin := _pivot(leg, Vector3(0, -0.62, 0))
		_part(shin, _capsule(0.075, 0.68), char_mat, Vector3(0, -0.3, 0))
		_part(shin, _box(Vector3(0.16, 0.08, 0.32)), rust, Vector3(0, -0.62, -0.06))  # work boot
		_part(shin, _capsule(0.09, 0.2), steel, Vector3(0, -0.05, -0.04))  # knee brace
		if leg == _leg_l:
			_shin_l = shin
		else:
			_shin_r = shin

	# torso: hunched forward
	_torso = _pivot(_hips, Vector3(0, 0.1, 0))
	_torso.rotation.x = deg_to_rad(-28)
	_part(_torso, _capsule(0.24, 0.95), flesh, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.15, 1, 0.8))
	# exposed ribs
	for i in range(5):
		_part(_torso, _box(Vector3(0.44, 0.03, 0.06)), char_mat, Vector3(0, 0.25 + i * 0.1, -0.17), Vector3(0.2, 0, 0))
	# tattered work apron
	_part(_torso, _box(Vector3(0.5, 0.8, 0.03)), _mat(Color(0.12, 0.1, 0.06), 1.0), Vector3(0, 0.1, -0.22), Vector3(-0.25, 0, 0))
	# rebar spikes through the back
	for i in range(6):
		var spike := _part(_torso, _capsule(0.025, randf_range(0.5, 0.9)), rust,
				Vector3(randf_range(-0.18, 0.18), randf_range(0.3, 0.85), 0.18),
				Vector3(deg_to_rad(randf_range(30, 70)), 0, deg_to_rad(randf_range(-30, 30))))
		spike.position.z += 0.15
	# a length of chain hanging off the shoulder
	for i in range(7):
		_part(_torso, _box(Vector3(0.06, 0.1, 0.03)), steel, Vector3(0.28, 0.75 - i * 0.11, 0.05), Vector3(0, i * 1.57, 0))

	# head - welding helmet fused to the skull
	_head = _pivot(_torso, Vector3(0, 1.0, -0.08))
	_part(_head, _capsule(0.06, 0.25), flesh, Vector3(0, -0.08, 0))
	_part(_head, _box(Vector3(0.34, 0.4, 0.36)), steel, Vector3(0, 0.15, -0.04))
	_part(_head, _box(Vector3(0.36, 0.3, 0.06)), rust, Vector3(0, 0.12, -0.24))
	_part(_head, _box(Vector3(0.26, 0.035, 0.02)), _eye_mat, Vector3(0, 0.18, -0.275))  # glowing visor slit
	for x in [-0.07, 0.07]:
		_part(_head, SphereMesh.new(), _eye_mat, Vector3(x, 0.18, -0.27), Vector3.ZERO, Vector3.ONE * 0.05)
	# jaw hanging below the helmet
	_part(_head, _box(Vector3(0.22, 0.08, 0.2)), flesh, Vector3(0, -0.1, -0.12), Vector3(0.4, 0, 0))
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(1.0, 0.35, 0.08)
	_eye_light.light_energy = 1.2
	_eye_light.omni_range = 4.0
	_eye_light.position = Vector3(0, 0.18, -0.5)
	_head.add_child(_eye_light)

	# arms - unnaturally long
	_arm_l = _pivot(_torso, Vector3(-0.34, 0.85, 0))
	_arm_r = _pivot(_torso, Vector3(0.34, 0.85, 0))
	for arm in [_arm_l, _arm_r]:
		_part(arm, _capsule(0.07, 0.85), flesh, Vector3(0, -0.4, 0))
		var fore := _pivot(arm, Vector3(0, -0.8, 0))
		_part(fore, _capsule(0.06, 0.85), char_mat, Vector3(0, -0.4, 0))
		# hand: three long hooked fingers
		for f in range(3):
			var fx := (f - 1) * 0.04
			_part(fore, _capsule(0.015, 0.32), steel, Vector3(fx, -0.95, -0.05), Vector3(deg_to_rad(-25), 0, fx * 3.0))
		if arm == _arm_l:
			_fore_l = fore
		else:
			_fore_r = fore
	_arm_l.rotation = Vector3(deg_to_rad(10), 0, deg_to_rad(-8))
	_arm_r.rotation = Vector3(deg_to_rad(10), 0, deg_to_rad(8))


func _animate(delta: float, speed: float) -> void:
	var moving := speed > 0.2
	var rate := 3.2 if speed > 3.0 else 2.0
	if moving:
		_anim_t += delta * rate * maxf(speed, 1.0) * 0.8
	else:
		_anim_t += delta * 0.6
	var s := sin(_anim_t)
	var amp := clampf(speed / 3.0, 0.15, 1.0) if moving else 0.0
	_leg_l.rotation.x = s * 0.6 * amp
	_leg_r.rotation.x = -s * 0.6 * amp
	_shin_l.rotation.x = maxf(0.0, -cos(_anim_t)) * 0.9 * amp
	_shin_r.rotation.x = maxf(0.0, cos(_anim_t)) * 0.9 * amp
	_hips.position.y = 1.25 + absf(s) * 0.06 * amp - 0.04
	# a limp: the body sways and the head jerks
	_hips.rotation.z = sin(_anim_t) * 0.08 * amp
	var lean := -28.0 - (18.0 if state == State.CHASE else 0.0)
	_torso.rotation.x = lerpf(_torso.rotation.x, deg_to_rad(lean), delta * 4.0)
	_arm_l.rotation.x = deg_to_rad(10) - s * 0.5 * amp + (0.6 if state == State.CHASE else 0.0)
	_arm_r.rotation.x = deg_to_rad(10) + s * 0.5 * amp + (0.6 if state == State.CHASE else 0.0)
	_fore_l.rotation.x = -0.3 - absf(s) * 0.3
	_fore_r.rotation.x = -0.3 - absf(cos(_anim_t)) * 0.3
	# occasional unnatural head twitch
	if randf() < delta * 0.8:
		_head.rotation.z = randf_range(-0.6, 0.6)
		_head.rotation.y = randf_range(-0.5, 0.5)
	_head.rotation.z = lerpf(_head.rotation.z, 0.0, delta * 2.0)
	_head.rotation.y = lerpf(_head.rotation.y, 0.0, delta * 2.0)
	var flick := 0.9 + randf() * 0.2
	var hot := state == State.CHASE or state == State.AMBUSH_LOCKER or state == State.KILL
	var e := (10.0 if hot else 5.0) * flick
	_eye_mat.emission_energy_multiplier = e
	_eye_mat.emission = Color(1.0, 0.1, 0.05) if hot else Color(1.0, 0.4, 0.08)
	_eye_light.light_energy = (2.0 if hot else 1.0) * flick
	_eye_light.light_color = _eye_mat.emission


# ------------------------------------------------------------ public api
func is_active() -> bool:
	return state != State.DORMANT and visible


func is_chasing() -> bool:
	return state == State.CHASE or state == State.AMBUSH_LOCKER


func activate(pos: Vector3, start_state := State.PATROL) -> void:
	global_position = pos
	visible = true
	state = start_state
	_breath.play()
	_pick_patrol_target()


func deactivate() -> void:
	visible = false
	state = State.DORMANT
	_breath.stop()


func reset_to(pos: Vector3, grace := 6.0) -> void:
	var was_chasing := is_chasing()
	global_position = pos
	velocity = Vector3.ZERO
	state = State.PATROL
	_grace = grace
	_hide_spot = null
	_saw_hide = false
	_lose_timer = 0.0
	_pick_patrol_target()
	if was_chasing:
		chase_ended.emit()


func set_enraged() -> void:
	enraged = true
	_grace = 0.0
	_start_chase()


## Lure the monster to a position (e.g. the generator roaring to life).
func lure(pos: Vector3) -> void:
	if state in [State.PATROL, State.SEARCH, State.INVESTIGATE]:
		state = State.INVESTIGATE
		_target = pos


func far_patrol_point(from: Vector3) -> Vector3:
	var best := patrol_points[0]
	var bd := -1.0
	for p in patrol_points:
		var d := p.distance_to(from)
		if d > bd:
			bd = d
			best = p
	return best


# ------------------------------------------------------------ brain
func _physics_process(delta: float) -> void:
	if state == State.DORMANT or state == State.KILL:
		return
	var player = Game.player
	if player == null:
		return
	_grace = maxf(0.0, _grace - delta)

	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = 0.12
		_sees_player = _grace <= 0.0 and _check_vision(player)
		if _sees_player:
			_last_seen = player.global_position
			_seen_time = Time.get_ticks_msec() / 1000.0

	var speed := PATROL_SPEED
	match state:
		State.PATROL:
			if _sees_player:
				_start_chase()
			elif enraged and _grace <= 0.0 and not player.is_hidden():
				_start_chase()
			elif _arrived():
				_wait_timer -= delta
				speed = 0.0
				if _wait_timer <= 0.0:
					_pick_patrol_target()
		State.INVESTIGATE:
			speed = INVESTIGATE_SPEED
			if _sees_player:
				_start_chase()
			elif _arrived():
				_begin_search(_target)
		State.SEARCH:
			speed = PATROL_SPEED * 1.15
			_search_timer -= delta
			if _sees_player:
				_start_chase()
			elif _search_timer <= 0.0:
				state = State.PATROL
				_pick_patrol_target()
			elif _arrived():
				_wait_timer -= delta
				speed = 0.0
				if _wait_timer <= 0.0:
					_target = _random_near(_last_seen, 9.0)
					_wait_timer = randf_range(0.8, 2.0)
		State.CHASE:
			speed = ENRAGED_SPEED if enraged else CHASE_SPEED
			if player.dead:
				_end_chase()
			elif player.is_hidden():
				var since := Time.get_ticks_msec() / 1000.0 - _seen_time
				var hide_spot: Node = player.hidden_in
				if since < 0.9 and global_position.distance_to(hide_spot.global_position) < 9.0:
					# it saw you climb in
					state = State.AMBUSH_LOCKER
					_hide_spot = hide_spot
					_target = hide_spot.get_front_position()
				else:
					_last_seen = hide_spot.get_front_position()
					_end_chase()
					_begin_search(_last_seen)
			elif _sees_player or enraged:
				_lose_timer = 0.0
				_target = player.global_position
			else:
				_lose_timer += delta
				_target = _last_seen
				if _lose_timer > 4.5 or (_arrived() and _lose_timer > 1.0):
					_end_chase()
					_begin_search(_last_seen)
			if not player.dead and not player.is_hidden() and global_position.distance_to(player.global_position) < KILL_DISTANCE:
				_do_kill(player)
				return
		State.AMBUSH_LOCKER:
			speed = CHASE_SPEED
			if not player.is_hidden():
				state = State.CHASE
			elif global_position.distance_to(_target) < 1.4:
				_hide_spot.rip_open()
				_do_kill(player)
				return

	_move(delta, speed)
	_ambient_sounds(delta)
	_open_doors(delta)


func _arrived() -> bool:
	var d := Vector2(global_position.x - _target.x, global_position.z - _target.z).length()
	return d < 1.3 or (agent.is_navigation_finished() and d < 3.0)


func _move(delta: float, speed: float) -> void:
	if agent.target_position.distance_to(_target) > 0.4:
		agent.target_position = _target
	var dir := Vector3.ZERO
	var map := get_world_3d().navigation_map
	if speed > 0.0:
		if NavigationServer3D.map_get_iteration_id(map) > 0 and not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			dir = next - global_position
		else:
			dir = _target - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			dir = dir.normalized()
	_speed = lerpf(_speed, speed, minf(1.0, delta * 4.0))
	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()

	# face movement or the player when chasing
	var look := dir
	if state == State.CHASE and Game.player and _sees_player:
		look = Game.player.global_position - global_position
		look.y = 0
	if look.length() > 0.1:
		var target_yaw := atan2(-look.x, -look.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, minf(1.0, delta * 6.0))

	var hs := Vector2(velocity.x, velocity.z).length()
	_animate(delta, hs)

	# footsteps
	_step_acc += hs * delta
	if _step_acc > 1.25:
		_step_acc = 0.0
		Sfx.play_3d(Sfx.pick("monster_step", 2), global_position, -2.0 if hs > 3.0 else -7.0, randf_range(0.85, 1.05), 40.0)
		if Game.player:
			var d := global_position.distance_to(Game.player.global_position)
			if d < 12.0:
				Game.player.add_trauma(0.12 * (1.0 - d / 12.0))

	# unstick
	if speed > 0.0:
		if global_position.distance_to(_last_pos) < 0.02 * speed:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		if _stuck_timer > 2.5:
			_stuck_timer = 0.0
			if state == State.PATROL or state == State.SEARCH:
				_pick_patrol_target()
	_last_pos = global_position


func _check_vision(player) -> bool:
	if player.dead or player.is_hidden():
		return false
	var eye := global_position + Vector3.UP * 2.3
	var head: Vector3 = player.get_head_position()
	var to := head - eye
	var d := to.length()
	if d < 2.2:
		return true
	var view := 15.0
	if player.flashlight_on:
		view = 24.0
	if player.crouching:
		view *= 0.6
	if Game.power_on:
		view += 5.0
	if enraged:
		view = 60.0
	var in_beam := false
	if player.flashlight_on and d < 22.0:
		var beam_dir: Vector3 = -player.camera.global_basis.z
		in_beam = beam_dir.angle_to(-to) < deg_to_rad(14)
	if d > view and not in_beam:
		return false
	var fwd := -visual.global_basis.z
	var flat := Vector3(to.x, 0, to.z)
	if fwd.angle_to(flat) > deg_to_rad(65) and not in_beam:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, head, 1 | 2, [get_rid()])
	return space.intersect_ray(q).is_empty()


func _on_noise(pos: Vector3, radius: float) -> void:
	if state in [State.DORMANT, State.CHASE, State.KILL, State.AMBUSH_LOCKER]:
		return
	if _grace > 0.0:
		return
	if global_position.distance_to(pos) <= radius:
		if state != State.INVESTIGATE:
			Sfx.play_3d(Sfx.pick("monster_growl", 3), global_position + Vector3.UP * 2, -4.0, 1.1, 35.0)
		state = State.INVESTIGATE
		_target = pos
		_last_seen = pos


func _start_chase() -> void:
	if state == State.CHASE:
		return
	state = State.CHASE
	_lose_timer = 0.0
	if Game.player:
		_target = Game.player.global_position
		_last_seen = _target
	Sfx.play_3d("monster_scream", global_position + Vector3.UP * 2.2, 2.0, randf_range(0.9, 1.05), 60.0)
	Sfx.play("stinger_spotted", -4.0)
	chase_started.emit()


func _end_chase() -> void:
	if state == State.CHASE or state == State.AMBUSH_LOCKER:
		state = State.SEARCH
		chase_ended.emit()


func _begin_search(at: Vector3) -> void:
	state = State.SEARCH
	_last_seen = at
	_search_timer = randf_range(10.0, 16.0)
	_target = _random_near(at, 6.0)
	_wait_timer = randf_range(1.0, 2.0)


func _pick_patrol_target() -> void:
	if patrol_points.is_empty():
		return
	_wait_timer = randf_range(1.5, 4.0)
	# The Foreman drifts toward wherever the player is - it always seems to find you.
	if Game.player and randf() < 0.45:
		var pp: Vector3 = Game.player.global_position
		var sorted := patrol_points.duplicate()
		sorted.sort_custom(func(a, b): return a.distance_to(pp) < b.distance_to(pp))
		_target = sorted[randi_range(0, mini(3, sorted.size() - 1))]
	else:
		_target = patrol_points.pick_random()


func _random_near(center: Vector3, r: float) -> Vector3:
	var map := get_world_3d().navigation_map
	var p := center + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		return NavigationServer3D.map_get_closest_point(map, p)
	return p


func _ambient_sounds(delta: float) -> void:
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(5.0, 12.0) if state != State.CHASE else randf_range(2.5, 5.0)
		Sfx.play_3d(Sfx.pick("monster_growl", 3), global_position + Vector3.UP * 2.2, -3.0, randf_range(0.85, 1.1), 40.0)
		if randf() < 0.3:
			Sfx.play_3d("chain_rattle", global_position + Vector3.UP * 1.5, -8.0, 1.0, 25.0)


func _open_doors(delta: float) -> void:
	_door_timer -= delta
	if _door_timer > 0.0:
		return
	_door_timer = 0.25
	for door in get_tree().get_nodes_in_group("doors"):
		if door.global_position.distance_to(global_position) < 3.0 and door.has_method("monster_open"):
			door.monster_open()


func _do_kill(player) -> void:
	state = State.KILL
	velocity = Vector3.ZERO
	# lunge into the player's face
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	global_position = player.global_position + fwd * 1.05
	global_position.y = player.global_position.y
	var look: Vector3 = player.global_position - global_position
	visual.rotation.y = atan2(-look.x, -look.z)
	_torso.rotation.x = deg_to_rad(-55)
	_arm_l.rotation.x = deg_to_rad(110)
	_arm_r.rotation.x = deg_to_rad(110)
	_eye_mat.emission = Color(1, 0.05, 0.02)
	_eye_mat.emission_energy_multiplier = 16.0
	Sfx.play("jumpscare", 0.0)
	Sfx.play("monster_scream", -2.0, 0.8)
	player.kill(self)
	chase_ended.emit()
	caught_player.emit()
