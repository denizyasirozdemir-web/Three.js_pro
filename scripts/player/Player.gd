extends CharacterBody3D
## First-person player: movement, stamina, flashlight, interaction, hiding, fear.

signal died

const WALK_SPEED := 3.1
const SPRINT_SPEED := 5.7
const CROUCH_SPEED := 1.6
const ACCEL := 10.0
const GRAVITY := 18.0
const JUMP_VELOCITY := 4.6
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.0
const EYE_OFFSET := -0.12

var head: Node3D
var camera: Camera3D
var flashlight_pivot: Node3D
var flashlight: SpotLight3D
var flash_fill: OmniLight3D
var ray: RayCast3D
var shape: CollisionShape3D
var capsule: CapsuleShape3D

var pitch := 0.0
var stamina := 100.0
var exhausted := false
var battery := 100.0
var flashlight_on := false
var crouching := false
var sprinting := false
var controls_enabled := true
var dead := false
var hidden_in: Node = null
var current_prompt := ""
var current_target: Node = null
var fear := 0.0

var _bob_t := 0.0
var _step_dist := 0.0
var _trauma := 0.0
var _shake_t := 0.0
var _heart_timer := 0.0
var _breath: AudioStreamPlayer
var _flicker_t := 0.0
var _look_at_target: Node3D = null
var _cur_height := STAND_HEIGHT


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4

	capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = STAND_HEIGHT
	shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = STAND_HEIGHT * 0.5
	add_child(shape)

	head = Node3D.new()
	head.position.y = STAND_HEIGHT + EYE_OFFSET
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	head.add_child(camera)

	flashlight_pivot = Node3D.new()
	flashlight_pivot.top_level = true
	add_child(flashlight_pivot)
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 30.0
	flashlight.spot_angle = 27.0
	flashlight.spot_angle_attenuation = 0.9
	flashlight.spot_attenuation = 0.8
	flashlight.light_energy = 3.2
	flashlight.light_color = Color(1.0, 0.94, 0.82)
	flashlight.shadow_enabled = true
	flashlight.shadow_blur = 1.5
	flashlight.light_volumetric_fog_energy = 0.6
	flashlight.visible = false
	flashlight.position = Vector3(0.18, -0.15, 0.0)
	flashlight_pivot.add_child(flashlight)
	# small fill light so nearby surfaces read when the torch is on
	flash_fill = OmniLight3D.new()
	flash_fill.omni_range = 3.5
	flash_fill.light_energy = 0.12
	flash_fill.light_color = Color(1.0, 0.94, 0.82)
	flash_fill.visible = false
	camera.add_child(flash_fill)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.4)
	ray.collision_mask = 1 | 2 | 16
	ray.collide_with_areas = true
	ray.exclude_parent = true
	camera.add_child(ray)

	_breath = AudioStreamPlayer.new()
	_breath.stream = Sfx.get_stream("breath_heavy")
	_breath.volume_db = -60.0
	_breath.bus = "SFX"
	add_child(_breath)
	_breath.play()

	Game.player = self


func _unhandled_input(event: InputEvent) -> void:
	if dead or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Game.touch_mode:
		_apply_look(event.relative, Game.mouse_sensitivity)
	if not controls_enabled and not hidden_in:
		return
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("reload"):
		swap_battery()
	elif event.is_action_pressed("interact"):
		if hidden_in:
			hidden_in.interact(self)
		elif current_target:
			current_target.interact(self)


func _apply_look(rel: Vector2, sens: float) -> void:
	if hidden_in:
		# limited look while hidden
		rotation.y -= rel.x * sens * 0.5
		pitch = clampf(pitch - rel.y * sens * 0.5, -0.35, 0.35)
		var base_yaw: float = hidden_in.get_hide_yaw()
		rotation.y = base_yaw + clampf(wrapf(rotation.y - base_yaw, -PI, PI), -0.6, 0.6)
	elif controls_enabled:
		rotation.y -= rel.x * sens
		pitch = clampf(pitch - rel.y * sens, deg_to_rad(-85), deg_to_rad(85))
	head.rotation.x = pitch


func _physics_process(delta: float) -> void:
	if Game.touch_look != Vector2.ZERO:
		if not dead:
			_apply_look(Game.touch_look, Game.touch_sensitivity)
		Game.touch_look = Vector2.ZERO
	_update_flashlight(delta)
	_update_fear(delta)
	_update_shake(delta)
	if dead:
		if _look_at_target and is_instance_valid(_look_at_target):
			var tgt := _look_at_target.global_position + Vector3.UP * 2.2
			var xf := camera.global_transform.looking_at(tgt, Vector3.UP)
			camera.global_basis = camera.global_basis.slerp(xf.basis, minf(1.0, delta * 14.0))
		return
	if hidden_in:
		_update_interaction()
		return

	var input := Vector2.ZERO
	if controls_enabled:
		input = (Input.get_vector("move_left", "move_right", "move_forward", "move_back") + Game.touch_move).limit_length(1.0)
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	# crouch
	var want_crouch := controls_enabled and (Input.is_action_pressed("crouch") or Game.touch_crouch)
	if not want_crouch and crouching:
		# only stand up if there is headroom
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.UP * (STAND_HEIGHT + 0.1), collision_mask, [get_rid()])
		if space.intersect_ray(q).is_empty():
			crouching = false
	elif want_crouch:
		crouching = true
	var target_h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_cur_height = lerpf(_cur_height, target_h, minf(1.0, delta * 10.0))
	capsule.height = _cur_height
	shape.position.y = _cur_height * 0.5

	# sprint & stamina
	var moving := input.length() > 0.1
	sprinting = controls_enabled and Input.is_action_pressed("sprint") and moving and not crouching and not exhausted and input.y < 0.5
	if sprinting:
		stamina = maxf(0.0, stamina - 17.0 * delta)
		if stamina <= 0.0:
			exhausted = true
			Game.hint("You're out of breath.")
	else:
		stamina = minf(100.0, stamina + (9.0 if moving else 15.0) * delta)
		if exhausted and stamina > 35.0:
			exhausted = false
	var target_breath := -60.0
	if exhausted:
		target_breath = -6.0
	elif stamina < 50.0:
		target_breath = lerpf(-30.0, -10.0, 1.0 - stamina / 50.0)
	_breath.volume_db = lerpf(_breath.volume_db, target_breath, delta * 3.0)

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	elif exhausted:
		speed = WALK_SPEED * 0.8

	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(dir * speed, minf(1.0, ACCEL * delta))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif controls_enabled and Input.is_action_just_pressed("jump") and not crouching and stamina > 10.0:
		velocity.y = JUMP_VELOCITY
		stamina -= 8.0
	var was_air := not is_on_floor()
	move_and_slide()
	if was_air and is_on_floor():
		_footstep(1.0)

	# head bob + footsteps
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var head_y := _cur_height + EYE_OFFSET
	if is_on_floor() and hspeed > 0.3:
		_bob_t += delta * hspeed * 2.2
		_step_dist += hspeed * delta
		var stride := 2.1 if sprinting else (1.0 if crouching else 1.55)
		if _step_dist >= stride:
			_step_dist = 0.0
			_footstep(hspeed / WALK_SPEED)
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 5.0)
	var bob_amt := 0.05 if sprinting else 0.03
	head.position.y = head_y + sin(_bob_t * 2.0) * bob_amt
	head.position.x = cos(_bob_t) * bob_amt * 0.6
	camera.rotation.z = lerpf(camera.rotation.z, -input.x * 0.025, delta * 6.0)
	var target_fov := 78.0 if sprinting else 72.0
	camera.fov = lerpf(camera.fov, target_fov, delta * 5.0)

	_update_interaction()


func _footstep(intensity: float) -> void:
	var metal := _on_metal()
	var n := Sfx.pick("step_metal", 3) if metal else Sfx.pick("step_concrete", 4)
	var vol := -14.0
	var radius := 7.0
	if sprinting:
		vol = -6.0
		radius = 16.0
	elif crouching:
		vol = -24.0
		radius = 1.8
	if metal:
		radius *= 1.4
	Sfx.play(n, vol + clampf(intensity - 1.0, 0.0, 1.0) * 3.0, randf_range(0.9, 1.1))
	Game.make_noise(global_position, radius)


func _on_metal() -> bool:
	# boiler room & furnace walkways use steel grating
	var p := global_position
	return (p.x > 20.0 and p.z < -4.0) or (p.z < -16.0 and p.x > -36.0 and p.x < 20.0 and p.z > -22.0)


func _update_interaction() -> void:
	current_target = null
	current_prompt = ""
	if dead or not controls_enabled and not hidden_in:
		return
	if hidden_in:
		current_prompt = "[E] Leave the locker"
		return
	ray.force_raycast_update()
	if ray.is_colliding():
		var n: Node = ray.get_collider()
		while n and not n.has_method("interact"):
			n = n.get_parent()
		if n and n.has_method("get_prompt"):
			var p: String = n.get_prompt()
			if p != "":
				current_target = n
				current_prompt = p


# ------------------------------------------------------------ flashlight
func toggle_flashlight() -> void:
	if not Game.has_flashlight:
		return
	if battery <= 0.0 and not flashlight_on:
		Sfx.play("flashlight_click", -6.0, 0.8)
		Game.hint("The battery is dead. [R] to swap batteries.")
		return
	flashlight_on = not flashlight_on
	Sfx.play("flashlight_click", -4.0)
	flashlight.visible = flashlight_on
	flash_fill.visible = flashlight_on


func swap_battery() -> void:
	if not Game.has_flashlight:
		return
	if Game.spare_batteries <= 0:
		Game.hint("No spare batteries.")
		return
	if battery > 90.0:
		Game.hint("The battery is still almost full.")
		return
	Game.spare_batteries -= 1
	battery = 100.0
	Sfx.play("battery", -4.0)
	Game.hint("Battery replaced.")
	Game.inventory_changed.emit()


func _update_flashlight(delta: float) -> void:
	# lazy follow of the light gives the beam some weight
	var target := camera.global_transform
	flashlight_pivot.global_position = target.origin
	flashlight_pivot.global_basis = flashlight_pivot.global_basis.slerp(target.basis.orthonormalized(), minf(1.0, delta * 16.0)).orthonormalized()
	if not flashlight_on:
		return
	battery = maxf(0.0, battery - delta * 0.42)
	var e := 3.2
	if battery < 25.0:
		e = lerpf(0.6, 3.2, battery / 25.0)
		_flicker_t -= delta
		if _flicker_t <= 0.0:
			_flicker_t = randf_range(0.05, 1.5 * battery / 25.0 + 0.1)
			if randf() < 0.35:
				e *= randf_range(0.0, 0.4)
	flashlight.light_energy = lerpf(flashlight.light_energy, e, minf(1.0, delta * 25.0))
	if battery <= 0.0:
		flashlight_on = false
		flashlight.visible = false
		flash_fill.visible = false
		Sfx.play("flashlight_click", -6.0, 0.7)
		Game.hint("The flashlight died. [R] to swap batteries.")


# ------------------------------------------------------------ fear / shake
func _update_fear(delta: float) -> void:
	var target_fear := 0.0
	var m = Game.monster
	if m and is_instance_valid(m) and m.is_active():
		var d := global_position.distance_to(m.global_position)
		target_fear = clampf(1.0 - (d - 4.0) / 26.0, 0.0, 1.0)
		if m.is_chasing():
			target_fear = maxf(target_fear, 0.7)
		if d < 14.0 and m.is_active():
			add_trauma(delta * (1.0 - d / 14.0) * 0.15)
	fear = lerpf(fear, target_fear, delta * 1.5)
	if fear > 0.15:
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = lerpf(1.1, 0.38, fear)
			Sfx.play("heartbeat", lerpf(-22.0, 0.0, fear))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _update_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 0.8)
	_shake_t += delta * 30.0
	var s := _trauma * _trauma
	camera.h_offset = (sin(_shake_t * 1.3) * 0.5 + sin(_shake_t * 2.9) * 0.5) * 0.12 * s
	camera.v_offset = (cos(_shake_t * 1.7) * 0.5 + sin(_shake_t * 3.3) * 0.5) * 0.12 * s


# ------------------------------------------------------------ hiding
func enter_hide(spot: Node) -> void:
	hidden_in = spot
	controls_enabled = false
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", spot.get_hide_position(), 0.35)
	tw.tween_property(self, "rotation:y", spot.get_hide_yaw(), 0.35)
	pitch = 0.0
	head.rotation.x = 0.0
	crouching = false
	Sfx.set_muffled(true)


func exit_hide(exit_pos: Vector3) -> void:
	hidden_in = null
	Sfx.set_muffled(false)
	var tw := create_tween()
	tw.tween_property(self, "global_position", exit_pos, 0.3)
	tw.tween_callback(func(): controls_enabled = true)


func is_hidden() -> bool:
	return hidden_in != null


func get_head_position() -> Vector3:
	return camera.global_position


# ------------------------------------------------------------ death / respawn
func kill(by: Node3D) -> void:
	if dead:
		return
	dead = true
	controls_enabled = false
	_look_at_target = by
	if hidden_in:
		hidden_in = null
		Sfx.set_muffled(false)
	add_trauma(1.0)
	died.emit()


func respawn(pos: Vector3, yaw: float) -> void:
	dead = false
	_look_at_target = null
	hidden_in = null
	Sfx.set_muffled(false)
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	camera.rotation = Vector3.ZERO
	pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	stamina = 100.0
	exhausted = false
	fear = 0.0
	_trauma = 0.0
	battery = maxf(battery, 40.0)
	controls_enabled = true
