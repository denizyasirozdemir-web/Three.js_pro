extends Node
## Sound manager: buses, one-shot 2D/3D sounds, music crossfades, radio voice.

const LOOPS := [
	"amb_drone", "amb_machine", "amb_vent", "steam_hiss", "furnace_roar", "generator_loop",
	"alarm_loop", "monster_breath", "chase_music", "menu_music", "radio_static", "breath_heavy",
	"radio_voice_1", "radio_voice_2", "radio_voice_3", "radio_voice_creepy",
]


var streams := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
var _voice: AudioStreamPlayer
var _voice_static: AudioStreamPlayer
var _voice_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	# every .wav in res://audio (the .import files are listed in exported games too)
	for f in DirAccess.get_files_at("res://audio"):
		if not f.ends_with(".wav.import"):
			continue
		var n := f.trim_suffix(".wav.import")
		var s: AudioStream = load("res://audio/%s.wav" % n)
		# Loop on the shared resource (not a copy) so scenes that reference the .wav loop too.
		if n in LOOPS and s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			_make_loop(s)
		streams[n] = s
	_music_a = _new_player("Music")
	_music_b = _new_player("Music")
	_voice = _new_player("Voice")
	_voice_static = _new_player("Voice")


func _make_loop(s: AudioStreamWAV) -> void:
	var frames := s.data.size()
	match s.format:
		AudioStreamWAV.FORMAT_16_BITS:
			frames /= 2
		AudioStreamWAV.FORMAT_IMA_ADPCM:
			frames *= 2
		AudioStreamWAV.FORMAT_QOA:
			frames = 0
	if s.stereo:
		frames /= 2
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = frames


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") != -1:
		return
	for b in ["Music", "Ambient", "SFX", "World", "Voice"]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, b)
		AudioServer.set_bus_send(idx, "Master")
	# Big industrial reverb for positional sounds.
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.85
	rev.damping = 0.35
	rev.wet = 0.28
	rev.dry = 0.9
	rev.spread = 0.8
	AudioServer.add_bus_effect(AudioServer.get_bus_index("World"), rev)
	# Radio band-pass for the voice bus.
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 1600
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Voice"), bp)
	# Muffle everything a bit when hidden in a locker (enabled on demand).
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 900
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), lp)
	AudioServer.set_bus_effect_enabled(0, 0, false)
	var lim := AudioEffectLimiter.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), lim)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -4.0)


func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(0, 0, on)


func _new_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func get_stream(n: String) -> AudioStream:
	return streams.get(n)


func pick(prefix: String, count: int) -> String:
	return "%s_%d" % [prefix, randi_range(1, count)]


## Fire-and-forget non-positional sound.
func play(n: String, vol_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	if not streams.has(n):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Fire-and-forget positional sound placed in the current scene.
func play_3d(n: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, max_dist := 45.0) -> AudioStreamPlayer3D:
	if not streams.has(n):
		return null
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.unit_size = 6.0
	p.bus = "World"
	p.attenuation_filter_cutoff_hz = 6000
	scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Create a persistent looping positional emitter under `parent`.
func loop_3d(n: String, parent: Node3D, offset := Vector3.ZERO, vol_db := 0.0, max_dist := 30.0, unit := 5.0, start := true) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams.get(n)
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.unit_size = unit
	p.bus = "World"
	p.position = offset
	p.autoplay = start
	parent.add_child(p)
	return p


func loop_2d(n: String, vol_db := 0.0, bus := "Ambient") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = streams.get(n)
	p.volume_db = vol_db
	p.bus = bus
	add_child(p)
	p.play()
	return p


# ------------------------------------------------------------ music
func play_music(n: String, fade := 2.0, vol_db := 0.0) -> void:
	if n == _music_current:
		return
	_music_current = n
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if n != "" and streams.has(n):
		_music_a.stream = streams[n]
		_music_a.volume_db = -50.0
		_music_a.play()
		create_tween().tween_property(_music_a, "volume_db", vol_db, fade)
	if _music_b.playing:
		var t := create_tween()
		t.tween_property(_music_b, "volume_db", -60.0, fade)
		t.tween_callback(_music_b.stop)


func stop_music(fade := 2.0) -> void:
	play_music("", fade)


# ------------------------------------------------------------ radio voice
func play_voice(creepy: bool, duration: float) -> void:
	play("radio_click", -8.0, randf_range(0.9, 1.1), "Voice")
	var n := "radio_voice_creepy" if creepy else "radio_voice_%d" % randi_range(1, 3)
	_voice.stream = streams.get(n)
	_voice.volume_db = -12.0 if not creepy else -8.0
	_voice.pitch_scale = randf_range(0.95, 1.05) if not creepy else 0.85
	_voice.play(randf_range(0.0, 1.0))
	_voice_static.stream = streams.get("radio_static")
	_voice_static.volume_db = -26.0
	_voice_static.play()
	if _voice_tween:
		_voice_tween.kill()
	_voice_tween = create_tween()
	_voice_tween.tween_interval(maxf(duration - 0.6, 0.3))
	_voice_tween.tween_callback(_voice.stop)


func stop_voice() -> void:
	if _voice and _voice.playing:
		_voice.stop()
		play("radio_click", -12.0, 1.2, "Voice")
	if _voice_static:
		_voice_static.stop()


func stop_all() -> void:
	stop_voice()
	for c in get_children():
		if c is AudioStreamPlayer and c != _music_a and c != _music_b and c != _voice and c != _voice_static:
			c.queue_free()
