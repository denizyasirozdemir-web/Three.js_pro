extends Node3D
## Story director for KESSLER WORKS.
## Builds the level, spawns the player and The Foreman, and runs every scripted
## event, objective, radio call, scare, death and the ending.

const Level := preload("res://scripts/world/Level.gd")
const LEVEL_SCENE := "res://scenes/Level.tscn"
const Player := preload("res://scripts/player/Player.gd")
const Monster := preload("res://scripts/monster/Monster.gd")
const HUD := preload("res://scripts/ui/HUD.gd")
const TouchControls := preload("res://scripts/ui/TouchControls.gd")

var level: Level
var player: Player
var monster: Monster
var hud: HUD
var env: Environment

var _ambient: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _scare_timer := 40.0
var _drip_timer := 3.0
var _glimpse: Monster = null
var _glimpse_look := 0.0
var _alarm_t := 0.0
var _ready_done := false
var _ending := false
var _radio_hint_timer := 0.0


# ================================================================ setup
func _ready() -> void:
	Game.world = self
	Game.new_game()
	_setup_environment()

	# The map lives in scenes/Level.tscn so it can be edited in Godot.
	# If that file is missing, the level is generated from code instead.
	if ResourceLoader.exists(LEVEL_SCENE):
		level = (load(LEVEL_SCENE) as PackedScene).instantiate()
		add_child(level)
		level.resolve()
	else:
		level = Level.new()
		add_child(level)
		level.build()

	player = Player.new()
	add_child(player)
	player.global_position = level.spawn_pos
	player.rotation.y = level.spawn_yaw
	player.died.connect(_on_player_died)
	Game.set_checkpoint(level.spawn_pos, level.spawn_yaw)

	monster = Monster.new()
	add_child(monster)
	monster.global_position = Vector3(10, 0, -36)
	monster.chase_started.connect(_on_chase_started)
	monster.chase_ended.connect(_on_chase_ended)

	hud = HUD.new()
	add_child(hud)
	hud.resume_requested.connect(_toggle_pause)
	hud.quit_requested.connect(_quit_to_menu)
	hud.ending_closed.connect(_quit_to_menu)
	if Game.touch_mode:
		add_child(TouchControls.new())

	_place_items()
	_place_triggers()
	_wire_machines()

	_ambient = Sfx.loop_2d("amb_drone", -8.0)
	Sfx.stop_music(1.0)

	# Bake navigation after the geometry exists; the frame wait lets physics register shapes.
	await get_tree().physics_frame
	level.bake_nav()
	await get_tree().physics_frame
	monster.patrol_points = level.patrol_points.duplicate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ready_done = true
	_intro()


func _exit_tree() -> void:
	if _ambient:
		_ambient.queue_free()
	if _alarm:
		_alarm.queue_free()
	Sfx.stop_all()
	Sfx.set_muffled(false)
	Game.world = null
	Game.player = null
	Game.monster = null


func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.13, 0.17)
	env.ambient_light_energy = 0.18
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.055, 0.06)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.6, 0.6, 0.62)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.15
	if Game.touch_mode:
		# phones & tablets: drop the most expensive effects, keep the look
		env.ssao_enabled = false
		env.volumetric_fog_enabled = false
		env.fog_density = 0.028
		env.glow_intensity = 0.5
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.78
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ================================================================ content
const NOTES := {
	"notice": ["NOTICE TO ALL NIGHT SHIFT STAFF",
		"Effective immediately, Plant 9 will operate [b]around the clock[/b] until the Kessler-Voss contract is fulfilled.\n\nOvertime is mandatory. Absence will be treated as resignation.\n\nWorkers are reminded that the material arriving from Shaft 6 is [b]not to be discussed[/b] outside the plant, with family, or with each other.\n\nClock in. Every shift. Every worker.\n\n— Management\nMarch 14, 1986"],
	"security": ["SECURITY LOG — GATE 2",
		"Oct 21, 1986\n23:40 — Night shift clocked in. 14 cards punched.\n00:15 — Foreman Voss requested the gate stay locked until morning. Odd, but signed for it.\n01:50 — Humming from the hall. Assumed the transformers.\n02:13 — Card rack shows [b]15[/b] punched cards. Counted twice. There are only 14 names on the roster.\n02:31 — Radio from Harlan in dispatch: \"Don't go into the hall.\"\n02:32 — Going into the hall."],
	"maintenance": ["MAINTENANCE LOG — LINE 9",
		"Belt stopped three times tonight. Each time we found it wet. Not oil. Not water. Warm.\n\nVoss says keep it running. He's been standing by the furnace for six hours. Doesn't blink. Doesn't sweat.\n\nThe breaker keeps tripping, so I pulled the three main fuses and hid them so nobody could restart the line. One in the warehouse, one in the lockers, one by the furnace.\n\nIf you're reading this, [b]DON'T put them back.[/b]\n\n— R. Okafor, Maintenance"],
	"manifest": ["SHIPPING MANIFEST #6-0614",
		"ORIGIN: Kessler Mine, Shaft 6 (sealed)\nDESTINATION: Plant 9 — Furnace, Line 9\nCARGO: 40 tons \"specimen ore\"\n\nHANDLING:\n- Do NOT open crates.\n- Do NOT record serial numbers.\n- Do NOT respond if the crates respond.\n\nSigned: E. Voss, Shift Foreman"],
	"diary": ["TORN DIARY PAGE",
		"The ore hums. Nobody says it, but everyone hears it. It hums the way my mother used to hum in the kitchen.\n\nVoss put his hand on a crate today and smiled like a kid. Said it was \"singing to him.\"\n\nTonight he's making us melt it all. Says the board wants it gone before the inspectors come.\n\nI keep counting the guys in the locker room. I keep getting fifteen.\n\n— Tomás"],
	"scrawl": ["SCRAWLED ON A RAG",
		"HE COUNTS US\nevery shift he walks the floor and counts\nlast night 14\ntonight 15\n\nthere are only 14 of us\n\nhe went INTO the furnace\nand he WALKED BACK OUT\n\nhide in the lockers. he doesn't look in the lockers if he doesn't see you go in"],
	"voss": ["LETTER — UNSENT",
		"To the Board of Kessler Ironworks,\n\nThe ore does not melt. I have run Line 9 at 1,900 degrees for nine days. It does not melt. It [i]listens[/i].\n\nWhen I stand near the crucible I hear my father calling me from the mine. He has been dead since '61.\n\nThe workers are frightened, but they do not understand. It does not want to be melted. It wants to be [b]counted[/b]. It wants a full shift.\n\nI will give it one.\n\n— Elias Voss"],
	"incident": ["INCIDENT REPORT — CONFIDENTIAL",
		"DATE: October 22, 1986\nCAUSE (OFFICIAL): Carbon monoxide leak, Furnace Line 9\n\nPERSONNEL UNACCOUNTED FOR (14):\nOkafor R. — Maintenance\nRivera T. — Line 9\nVoss E. — Foreman\nBrandt K. — Line 8\n... (9 more names, smeared) ...\n[b]Pike H. — Dispatch / Radio Operator[/b]\n\nNOTE: Radio traffic from Plant 9 continued for three days after the site was sealed. Dispatch channel. Same voice. Recordings destroyed by order of the Board."],
	"last": ["NOTE TAPED TO THE CONSOLE",
		"If you got this far, he talked you through it too, didn't he.\n\nThe friendly voice on the radio. Calm. Helpful. Knows the plant like the back of his hand.\n\nThe override opens the loading bay. It also wakes the whole line. He will come for you at full speed.\n\nDon't stop. Don't hide. [b]Run[/b].\n\nAnd whatever you do —\n[b]don't answer the radio after you leave[/b]."],
}


func _place_items() -> void:
	# Item and document positions come from the Marker3D nodes under Level > Markers,
	# so they can be moved in the editor (scenes/Level.tscn).
	var L := level
	for m in L.get_node("Markers/Items").get_children():
		var n := str(m.name)
		var pos: Vector3 = m.global_position
		if n.begins_with("Flashlight"):
			L.add_pickup(pos, "[E] Take the flashlight", "flashlight", _on_flashlight)
		elif n.begins_with("Fuse"):
			L.add_pickup(pos, "[E] Take the fuse", "fuse", _on_fuse)
		elif n.begins_with("Keycard"):
			L.add_pickup(pos, "[E] Take Voss's keycard", "keycard", _on_keycard)
		elif n.begins_with("Battery"):
			L.add_pickup(pos, "[E] Take the battery", "battery", _on_battery)
	for m in L.get_node("Markers/Notes").get_children():
		var id := str(m.name)
		if NOTES.has(id):
			L.add_note(m.global_position, id, NOTES[id][0], NOTES[id][1])


func _place_triggers() -> void:
	var cbs := {
		"Hall": _on_enter_hall,
		"Warehouse": func(): _thought_once("wh", "Rows and rows of crates. All stamped SPECIMEN ORE."),
		"Boiler": func(): _thought_once("boiler", "It's warm in here. The boilers have been cold for forty years."),
		"Furnace": _on_enter_furnace,
		"LockerRoom": func(): _thought_once("lock", "A locker room. Some of these doors are still padlocked from the inside."),
		"ForemanOffice": _on_enter_foreman,
		"Exit": _on_exit_reached,
		# a fake-out: something runs across the catwalk above you
		"Catwalk": _catwalk_scare,
	}
	for t in level.get_node("Markers/Triggers").get_children():
		if cbs.has(str(t.name)):
			t.on_enter = cbs[str(t.name)]


func _wire_machines() -> void:
	var fb := level.fusebox
	fb.prompt_cb = func() -> String:
		if Game.fuses_inserted >= 3:
			return ""
		if Game.fuses_found > Game.fuses_inserted:
			return "[E] Insert fuse (%d/3)" % Game.fuses_inserted
		return "[E] Inspect breaker panel"
	fb.use_cb = _use_fusebox

	var gen := level.generator
	gen.prompt_cb = func() -> String:
		return "" if Game.generator_on else "[E] Pull the starter cord"
	gen.use_cb = _use_generator

	var con := level.console
	con.prompt_cb = func() -> String:
		if Game.finale:
			return ""
		return "[E] Swipe keycard" if Game.has_keycard else "[E] Line 9 override console"
	con.use_cb = _use_console


# ================================================================ story beats
func _intro() -> void:
	hud.fade(1.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	hud.show_title("KESSLER IRONWORKS · PLANT 9", "October 22nd  ·  02:13 AM", 3.0)
	await get_tree().create_timer(2.5).timeout
	hud.fade(0.0, 3.0)
	await get_tree().create_timer(3.0).timeout
	Sfx.play_3d("metal_bang_1", level.spawn_pos + Vector3(0, 2, 2.5), 2.0, 0.8)  # the doors slam behind you
	player.add_trauma(0.5)
	Game.say_lines([
		["YOU", "...The door. It locked behind me.", "thought"],
		["HARLAN", "This is Harlan at dispatch. You inside? Good. Don't worry about the door. Old locks.", "radio"],
		["HARLAN", "Plant 9's been dark since '86. Demolition crew surveys it at dawn, and they need the power on.", "radio"],
		["HARLAN", "First thing: the security booth on your left. There should be a flashlight on the desk.", "radio"],
	])
	Game.set_objective("Find a flashlight in the security booth.")
	_save_checkpoint()


func _on_flashlight() -> void:
	Game.has_flashlight = true
	player.battery = 100.0
	player.toggle_flashlight()
	Game.inventory_changed.emit()
	hud.show_hint("LIGHT: toggle flashlight   ·   BATT: swap battery" if Game.touch_mode else "[F] Toggle flashlight   ·   [R] Swap battery", 5.0)
	Game.say_lines([
		["HARLAN", "Got it? Good. Batteries in that thing are older than you are. Grab spares when you see them.", "radio"],
		["HARLAN", "The production hall is through the east door. That's where the breaker panel is.", "radio"],
	])
	Game.set_objective("Enter the main production hall (east door of the lobby).")


func _on_enter_hall() -> void:
	if Game.flags.get("hall"):
		return
	Game.flags["hall"] = true
	Game.say_lines([
		["YOU", "God, it's huge. And it smells like burnt hair.", "thought"],
		["HARLAN", "Main hall. Lines 8 and 9. My old man worked Line 9, you know.", "radio"],
		["HARLAN", "Breaker panel's on the west wall, near you. Three main fuses are missing.", "radio"],
		["HARLAN", "Someone hid them. Try the warehouse, the locker rooms, and the furnace.", "radio"],
	])
	Game.set_objective("Find the three missing fuses (0/3).")
	_save_checkpoint()
	_spawn_glimpse(Vector3(12, 0, -10))


func _thought_once(id: String, text: String) -> void:
	if Game.flags.get("t_" + id):
		return
	Game.flags["t_" + id] = true
	Game.say("YOU", text, "thought")


func _on_enter_furnace() -> void:
	if Game.flags.get("furnace"):
		return
	Game.flags["furnace"] = true
	Game.say_lines([
		["YOU", "The furnace is... burning? There's no power. There's no fuel. How is it burning?", "thought"],
		["HARLAN", "Don't stare into it too long. Find what you came for.", "radio"],
	])


func _on_enter_foreman() -> void:
	if Game.flags.get("foreman") or not Game.power_on:
		return
	Game.flags["foreman"] = true
	Sfx.play(Sfx.pick("whisper", 3), -6.0)
	Game.say("YOU", "Fourteen photos on the wall. Fourteen tally marks on the board. And a fifteenth... in red.", "thought")


func _on_battery() -> void:
	Game.spare_batteries += 1
	Game.inventory_changed.emit()
	if not Game.flags.get("battery_hint"):
		Game.flags["battery_hint"] = true
		hud.show_hint("Spare battery. Press [R] to swap when the light runs low.", 4.0)


func _on_fuse() -> void:
	Game.fuses_found += 1
	Game.inventory_changed.emit()
	_save_checkpoint()
	var n := Game.fuses_found
	if n < 3:
		Game.set_objective("Find the three missing fuses (%d/3)." % n)
	else:
		Game.set_objective("Insert the fuses into the breaker panel (main hall, west wall).")
	if n == 1:
		_awaken_monster()
	elif n == 2:
		Game.say_lines([
			["HARLAN", "Two down. You're doing better than the last guy.", "radio"],
			["YOU", "The last guy?", "thought"],
			["HARLAN", "...Bad joke. One more.", "radio"],
		])
	elif n == 3:
		Game.say("HARLAN", "That's all three. Get back to the breaker panel. Quietly.", "radio")


func _awaken_monster() -> void:
	# lights die around you, something screams, and the Foreman starts walking
	var pos := player.global_position
	for l in get_tree().get_nodes_in_group("lamps"):
		if l.is_lit() and l.global_position.distance_to(pos) < 22.0:
			l.burst()
	Sfx.play("power_down", -4.0)
	player.add_trauma(0.6)
	hud.flash_damage(0.35)
	await get_tree().create_timer(1.6).timeout
	var spawn := _far_point_within(pos, 28.0, 48.0)
	Sfx.play_3d("monster_scream", spawn + Vector3.UP * 2, 6.0, 0.85, 90.0)
	Sfx.play("stinger_low", -4.0)
	await get_tree().create_timer(2.5).timeout
	monster.activate(spawn)
	monster._grace = 8.0
	Game.say_lines([
		["YOU", "What the hell was that?!", "thought"],
		["HARLAN", "...Probably the building settling.", "radio"],
		["HARLAN", "Probably.", "creepy"],
		["HARLAN", "Listen. If you see anything... don't let it see you. Stay low, keep your light off, and use the lockers.", "radio"],
	])
	hud.show_hint("[Ctrl] Crouch to move silently   ·   Hide in lockers with [E]", 6.0)


func _far_point_within(from: Vector3, dmin: float, dmax: float) -> Vector3:
	var cands: Array[Vector3] = []
	for p in level.patrol_points:
		var d := p.distance_to(from)
		if d >= dmin and d <= dmax:
			cands.append(p)
	if cands.is_empty():
		return monster.far_patrol_point(from)
	return cands.pick_random()


func _use_fusebox() -> void:
	if Game.fuses_inserted >= 3:
		return
	if Game.fuses_found <= Game.fuses_inserted:
		if Game.fuses_found == 0:
			Game.say("YOU", "Three fuse slots. All empty. Someone pulled them on purpose.", "thought")
		else:
			Game.hint("You need more fuses.")
		return
	while Game.fuses_inserted < Game.fuses_found:
		level.set_fuse_visual(Game.fuses_inserted)
		Game.fuses_inserted += 1
	Sfx.play_3d("fuse_insert", level.fusebox.global_position + Vector3.UP * 1.5, 0.0)
	Game.make_noise(level.fusebox.global_position, 12.0)
	Game.inventory_changed.emit()
	if Game.fuses_inserted >= 3:
		await get_tree().create_timer(1.2).timeout
		Sfx.play_3d("electric_zap", level.fusebox.global_position + Vector3.UP * 1.5, 0.0)
		Game.say_lines([
			["HARLAN", "Panel's live, but there's no juice coming in. The grid feed's been cut for decades.", "radio"],
			["HARLAN", "Backup generator. Boiler room, far east side, through the warehouse or the furnace.", "radio"],
			["HARLAN", "It'll be loud when it starts. He'll hear it.", "radio"],
			["YOU", "...He?", "thought"],
		])
		Game.set_objective("Start the backup generator in the boiler room.")
		_save_checkpoint()
	else:
		Game.set_objective("Find the remaining fuses (%d/3), then return to the panel." % Game.fuses_found)


func _use_generator() -> void:
	if Game.generator_on:
		return
	if Game.fuses_inserted < 3:
		Game.say("YOU", "If I start this now, the power has nowhere to go. The breaker panel needs its fuses first.", "thought")
		return
	Game.generator_on = true
	level.generator.enabled = false
	Sfx.play_3d("generator_start", level.generator.global_position + Vector3.UP, 4.0, 1.0, 70.0)
	player.add_trauma(0.3)
	await get_tree().create_timer(2.8).timeout
	Sfx.loop_3d("generator_loop", level.generator, Vector3(0, 1.2, 0), -2.0, 35.0, 5.0)
	level.generator_exhaust.emitting = true
	Game.make_noise(level.generator.global_position, 90.0)
	if monster.is_active():
		monster.lure(level.generator.global_position + Vector3(0, 0, 3))
	await get_tree().create_timer(1.2).timeout
	_set_power(true)
	Game.say_lines([
		["HARLAN", "There it is! Lights! You did it.", "radio"],
		["HARLAN", "The foreman's office should be unsealed now. South end of the locker rooms.", "radio"],
		["HARLAN", "Voss kept a keycard for the Line 9 override. That opens the loading bay. That's your way out.", "radio"],
		["HARLAN", "Now move. He's coming to see who turned on the lights.", "radio"],
	])
	Game.set_objective("Find Foreman Voss's keycard (office south of the locker rooms).")
	_save_checkpoint()


func _set_power(on: bool) -> void:
	Game.power_on = on
	Sfx.play("power_on", -2.0)
	for s in get_tree().get_nodes_in_group("power_sounds"):
		s.play()
	level.writing_label.visible = true
	level.console_screen_mat.emission_energy_multiplier = 1.5
	env.ambient_light_energy = 0.3
	if _ambient:
		create_tween().tween_property(_ambient, "volume_db", -14.0, 3.0)


func _on_keycard() -> void:
	Game.has_keycard = true
	Game.inventory_changed.emit()
	_save_checkpoint()
	for l in get_tree().get_nodes_in_group("lamps"):
		if l.global_position.distance_to(player.global_position) < 14.0:
			l.flicker = 0.9
	Sfx.play("stinger_low", -6.0)
	Game.clear_subtitles()
	Game.say_lines([
		["HARLAN", "You found it. Good.", "radio"],
		["HARLAN", "You found my name too. Didn't you.", "creepy"],
		["HARLAN", "We clocked in together that night. Fourteen of us. The furnace wanted fifteen.", "creepy"],
		["HARLAN", "...Sorry. Bad signal. Use the card on the Line 9 console in the furnace room. Control booth, north-east corner.", "radio"],
	])
	Game.set_objective("Use the keycard on the Line 9 override console (furnace room).")


func _use_console() -> void:
	if Game.finale:
		return
	if not Game.has_keycard:
		Sfx.play_3d("keycard_denied", level.console.global_position + Vector3.UP, -2.0)
		Game.say("YOU", "LINE 9 OVERRIDE — AUTHORIZATION REQUIRED. I need the foreman's card.", "thought")
		return
	if not Game.power_on:
		Sfx.play_3d("keycard_denied", level.console.global_position + Vector3.UP, -2.0)
		Game.hint("The console is dead. No power.")
		return
	Game.finale = true
	level.console.enabled = false
	Sfx.play_3d("keycard_ok", level.console.global_position + Vector3.UP, 0.0)
	await get_tree().create_timer(0.6).timeout
	Sfx.play_3d("lever", level.console.global_position + Vector3.UP, 0.0)
	level.console_screen_mat.emission = Color(1.0, 0.1, 0.05)
	level.console_screen_mat.albedo_color = Color(1.0, 0.1, 0.05)
	level.console_screen_mat.emission_energy_multiplier = 4.0
	await get_tree().create_timer(0.8).timeout
	_alarm = Sfx.loop_2d("alarm_loop", -10.0, "SFX")
	for l in get_tree().get_nodes_in_group("lamps"):
		l.flicker = maxf(l.flicker, 0.5)
	for al in level.alarm_lights:
		al.light_energy = 6.0
	level.shutter.open()
	Game.say_lines([
		["PA SYSTEM", "LINE NINE OVERRIDE ENGAGED. LOADING BAY OPENING. ALL WORKERS REPORT TO THE FURNACE.", "thought"],
		["HARLAN", "That's it. The shutter's going up. Warehouse, east wall.", "radio"],
		["HARLAN", "RUN. And don't look back. He never liked it when we left early.", "radio"],
	])
	Game.set_objective("ESCAPE through the loading bay! (warehouse, east wall)")
	_save_checkpoint()
	await get_tree().create_timer(2.0).timeout
	var p := _far_point_within(player.global_position, 18.0, 30.0)
	if not monster.is_active():
		monster.activate(p)
	else:
		monster.reset_to(p, 0.0)
	monster.set_enraged()


func _on_exit_reached() -> void:
	if not Game.finale or _ending or player.dead:
		return
	_ending = true
	player.controls_enabled = false
	monster.deactivate()
	Game.clear_subtitles()
	Sfx.stop_music(0.5)
	if _alarm:
		create_tween().tween_property(_alarm, "volume_db", -60.0, 3.0)
	var tw := hud.fade(1.0, 3.0)
	await tw.finished
	Sfx.play("ending_music", -6.0, 1.0, "Music")
	await get_tree().create_timer(2.0).timeout
	Game.say_lines([
		["YOU", "...Dawn. I'm out. I'm actually out.", "thought"],
		["MARIA", "—finally! This is Maria at dispatch. We've been trying to raise you on the radio all night!", "thought"],
		["MARIA", "Your channel was dead from the moment you went in. Not a word. Are you okay?", "thought"],
		["YOU", "Harlan talked me through it. He was on the radio the whole time.", "thought"],
		["MARIA", "...Harlan? Honey, we don't have anyone named Harlan.", "thought"],
		["???", "See you next shift.", "creepy"],
	])
	while Game.is_talking():
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var notes_found := Game.notes_read.size()
	hud.show_ending(
		"[center][b]KESSLER WORKS[/b]\n\n" +
		"You escaped Plant 9 as the sun came up.\n" +
		"The demolition crew found the loading bay open, the furnace cold, and the card rack by the door holding [color=#c0392b]fifteen[/color] punched time cards.\n\n" +
		"The fifteenth had your name on it.\n\n\n" +
		"[i]Time: %s   ·   Deaths: %d   ·   Documents found: %d / %d[/i]\n\n\n" % [Game.format_time(Game.play_time), Game.deaths, notes_found, NOTES.size()] +
		"[i]Thank you for playing.[/i][/center]")


# ================================================================ scares & ambience
func _process(delta: float) -> void:
	if not _ready_done or _ending:
		return
	_update_glimpse(delta)
	_update_alarm_lights(delta)
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(1.5, 4.0)
		Sfx.play_3d("drip", Vector3(-56, 3, -14), -6.0, randf_range(0.8, 1.2), 18.0)
		if randf() < 0.5:
			Sfx.play_3d("drip", Vector3(randf_range(-30, 50), 6, randf_range(-35, 35)), -10.0, randf_range(0.7, 1.3), 20.0)
	_scare_timer -= delta
	if _scare_timer <= 0.0 and not player.dead:
		_scare_timer = randf_range(22.0, 45.0)
		_random_scare()


func _random_scare() -> void:
	var pp := player.global_position
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(14, 28)
	var roll := randf()
	if roll < 0.3:
		Sfx.play_3d(Sfx.pick("metal_bang", 3), pp + away + Vector3.UP * 4, 2.0, randf_range(0.7, 1.1), 60.0)
	elif roll < 0.5:
		var behind: Vector3 = player.global_basis.z * 2.0
		Sfx.play_3d(Sfx.pick("whisper", 3), pp + behind + Vector3.UP * 1.6, -4.0, randf_range(0.9, 1.05), 8.0)
	elif roll < 0.65:
		Sfx.play_3d("chain_rattle", pp + away * 0.5 + Vector3.UP * 6, -2.0, 1.0, 40.0)
	elif roll < 0.8:
		# a nearby lamp sputters out for a moment
		for l in get_tree().get_nodes_in_group("lamps"):
			if l.is_lit() and l.global_position.distance_to(pp) < 15.0:
				var old: float = l.flicker
				l.flicker = 1.0
				Sfx.play_3d("electric_zap", l.global_position, -6.0)
				get_tree().create_timer(2.5).timeout.connect(func(): l.flicker = old)
				break
	elif not monster.is_active():
		# heavy footsteps somewhere above
		for i in range(5):
			get_tree().create_timer(i * 0.7).timeout.connect(func():
				Sfx.play_3d(Sfx.pick("monster_step", 2), pp + away * 0.4 + Vector3(0, 8, i * 1.2), -2.0, 0.9, 40.0))
	else:
		if Game.flags.get("fifteen") == null and Game.fuses_found >= 2:
			Game.flags["fifteen"] = true
			Game.say("???", "...fifteen...", "creepy", 2.5)
		else:
			Sfx.play_3d(Sfx.pick("metal_bang", 3), pp + away + Vector3.UP * 4, 2.0, 0.8, 60.0)


func _catwalk_scare() -> void:
	if monster.is_active():
		return
	for i in range(6):
		get_tree().create_timer(i * 0.32).timeout.connect(func():
			Sfx.play_3d(Sfx.pick("step_metal", 3), Vector3(-20 + i * 3.0, 5.2, -14.8), 4.0, 0.7, 40.0))
	get_tree().create_timer(2.2).timeout.connect(func():
		Sfx.play_3d("chain_rattle", Vector3(-2, 5.2, -14.8), 0.0, 1.0, 40.0))


func _spawn_glimpse(pos: Vector3) -> void:
	_glimpse = Monster.new()
	_glimpse.phantom = true
	add_child(_glimpse)
	_glimpse.global_position = pos
	var to_player := player.global_position - pos
	_glimpse.visual.rotation.y = atan2(-to_player.x, -to_player.z)
	_glimpse_look = 0.0


func _update_glimpse(delta: float) -> void:
	if _glimpse == null:
		return
	var head: Vector3 = player.get_head_position()
	var target := _glimpse.global_position + Vector3.UP * 2.0
	var to := target - head
	var d := to.length()
	var looking := (-player.camera.global_basis.z).angle_to(to) < deg_to_rad(10)
	if looking:
		_glimpse_look += delta
	if d < 16.0 or _glimpse_look > 0.7 or Game.fuses_found > 0:
		# it's gone the moment you're sure you saw it
		Sfx.play_3d("electric_zap", target, -2.0)
		if _glimpse_look > 0.0 or d < 16.0:
			Sfx.play(Sfx.pick("whisper", 3), -8.0)
			player.add_trauma(0.25)
		_glimpse.queue_free()
		_glimpse = null
	else:
		var to_p := player.global_position - _glimpse.global_position
		_glimpse.visual.rotation.y = atan2(-to_p.x, -to_p.z)


func _update_alarm_lights(delta: float) -> void:
	if not Game.finale:
		return
	_alarm_t += delta
	for i in range(level.alarm_lights.size()):
		var al: SpotLight3D = level.alarm_lights[i]
		al.rotation = Vector3(-0.6, _alarm_t * 4.0 + i * 1.7, 0)


# ================================================================ chase / death
func _on_chase_started() -> void:
	Sfx.play_music("chase_music", 0.6, -2.0)
	if not Game.flags.get("first_chase"):
		Game.flags["first_chase"] = true
		hud.show_hint("RUN! Break line of sight and hide in a locker.", 4.0)


func _on_chase_ended() -> void:
	if Game.finale and monster.enraged and not player.dead:
		return
	Sfx.stop_music(3.0)


func _on_player_died() -> void:
	if _ending:
		return
	Game.deaths += 1
	Game.clear_subtitles()
	hud.flash_damage(1.0)
	await get_tree().create_timer(1.3).timeout
	var tw := hud.fade(1.0, 0.15)
	await tw.finished
	if _ending:
		return
	Sfx.stop_music(0.5)
	hud.show_death(true)
	await get_tree().create_timer(3.2).timeout
	hud.show_death(false)
	player.respawn(Game.checkpoint_pos, Game.checkpoint_yaw)
	var far := monster.far_patrol_point(Game.checkpoint_pos)
	monster.reset_to(far, 8.0 if not Game.finale else 4.0)
	monster.visual.rotation = Vector3.ZERO
	hud.fade(0.0, 1.5)
	if Game.finale:
		get_tree().create_timer(4.0).timeout.connect(func():
			if Game.finale and not _ending:
				monster.set_enraged())


func _save_checkpoint() -> void:
	Game.set_checkpoint(player.global_position + Vector3.UP * 0.1, player.rotation.y)
	hud.show_checkpoint()


# ================================================================ pause / menu
func _unhandled_input(event: InputEvent) -> void:
	if not _ready_done or _ending:
		return
	if event.is_action_pressed("pause") and not hud.note_open and not player.dead:
		_toggle_pause()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused and not Game.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	hud.set_paused(p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.clear_subtitles()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
