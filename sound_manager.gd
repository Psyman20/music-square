extends Node

signal voice_started(duration: float)

# Synthesized sound effects using AudioStreamGenerator + Cyber-Arcade Announcer Voices
var _players: Dictionary = {}
var _voice_player: AudioStreamPlayer
var _voice_streams: Dictionary = {}
var _current_voice_priority: int = 0
var _current_voice_start_msec: int = 0
var _last_voice_played_msec: Dictionary = {}
var active_pack: String = "classic"
var announcer_enabled: bool = true

const VOICE_FILES := [
	"new_high_score",
	"achievement_unlocked",
	"mission_complete",
	"new_unlock",
	"combo_max",
	"unstoppable",
	"godlike",
	"legendary",
	"frenzy_mode",
	"overdrive",
	"double_dash",
	"max_charge",
	"clutch_save",
	"jackpot",
]


func _ready() -> void:
	# Pre-generate all sound effects and setup announcer voice player
	_generate_all_sounds()
	_setup_voice_announcer()


func _setup_voice_announcer() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoiceAnnouncerPlayer"
	_voice_player.bus = &"Master"
	_voice_player.volume_db = 1.5
	add_child(_voice_player)
	for v_name: String in VOICE_FILES:
		var path := "res://voices/" + v_name + ".ogg"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = false
			if stream != null:
				_voice_streams[v_name] = stream


func play_voice(voice_name: String, priority: int = 50, cooldown_sec: float = 1.2) -> void:
	if not announcer_enabled or _voice_player == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = _voice_streams.get(voice_name)
	if stream == null:
		var path := "res://voices/" + voice_name + ".ogg"
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = false
			if stream != null:
				_voice_streams[voice_name] = stream
	if stream == null:
		return

	var now_msec := Time.get_ticks_msec()
	var last_msec: int = int(_last_voice_played_msec.get(voice_name, -99999))
	if float(now_msec - last_msec) < cooldown_sec * 1000.0:
		return

	if _voice_player.playing:
		var elapsed_msec := now_msec - _current_voice_start_msec
		if priority < _current_voice_priority and elapsed_msec < 1400:
			return
		if priority == _current_voice_priority and elapsed_msec < 350:
			return

	_last_voice_played_msec[voice_name] = now_msec
	_current_voice_priority = priority
	_current_voice_start_msec = now_msec
	_voice_player.stream = stream
	_voice_player.pitch_scale = 1.0
	_voice_player.play()
	voice_started.emit(maxf(0.5, stream.get_length()))


func stop_voice() -> void:
	if _voice_player != null and is_instance_valid(_voice_player) and _voice_player.playing:
		_voice_player.stop()
	_current_voice_priority = 0


func play(sound_name: String) -> void:
	play_pitched(sound_name, 1.0)


func play_pitched(sound_name: String, pitch: float = 1.0) -> void:
	var clamped_pitch := clampf(pitch, 0.5, 2.2)
	if sound_name == "correct":
		var pack_key := "correct_" + active_pack
		if _players.has(pack_key):
			var p: AudioStreamPlayer = _players[pack_key]
			p.pitch_scale = clamped_pitch
			p.play()
			return
	var player: AudioStreamPlayer = _players.get(sound_name)
	if player != null:
		player.pitch_scale = clamped_pitch
		player.play()


func preview_pack(pack_id: String) -> void:
	var pack_key := "correct_" + pack_id
	if _players.has(pack_key):
		var p: AudioStreamPlayer = _players[pack_key]
		p.pitch_scale = 1.0
		p.play()
	else:
		play("correct")


func _exit_tree() -> void:
	if _voice_player != null and is_instance_valid(_voice_player):
		_voice_player.stop()
		_voice_player.stream = null
	_voice_streams.clear()
	for k in _players:
		var p: AudioStreamPlayer = _players[k]
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null
	_players.clear()


func _generate_all_sounds() -> void:
	_generate_sound("correct_classic", _make_correct_sfx)
	# Share the classic stream for default "correct" key without regenerating PCM buffer
	if _players.has("correct_classic"):
		var base_player: AudioStreamPlayer = _players["correct_classic"]
		var alias_player := AudioStreamPlayer.new()
		alias_player.bus = &"Master"
		alias_player.stream = base_player.stream
		add_child(alias_player)
		_players["correct"] = alias_player
	_generate_sound("correct_chiptune", _make_correct_chiptune_sfx)
	_generate_sound("correct_cyber_click", _make_correct_cyber_click_sfx)
	_generate_sound("correct_dream_chord", _make_correct_dream_chord_sfx)
	_generate_sound("correct_plasma_zap", _make_correct_plasma_zap_sfx)
	_generate_sound("wrong", _make_wrong_sfx)
	_generate_sound("timeout", _make_timeout_sfx)
	_generate_sound("combo", _make_combo_sfx)
	_generate_sound("game_over", _make_game_over_sfx)
	_generate_sound("tap", _make_tap_sfx)
	_generate_sound("remap", _make_remap_sfx)
	_generate_sound("unlock", _make_unlock_sfx)
	_generate_sound("shield", _make_shield_sfx)
	_generate_sound("shield_break", _make_shield_break_sfx)


func _generate_sound(sound_name: String, generator: Callable) -> void:
	var sample_rate := 44100
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)

	var data: PackedVector2Array = generator.call(sample_rate)
	var wav_stream := _convert_to_wav(data, sample_rate)
	player.stream = wav_stream

	_players[sound_name] = player


func _convert_to_wav(data: PackedVector2Array, sample_rate: int) -> AudioStreamWAV:
	var byte_data := PackedByteArray()
	byte_data.resize(data.size() * 4) # 16-bit stereo = 4 bytes per frame

	for i in range(data.size()):
		var sample_l := int(clampf(data[i].x, -1.0, 1.0) * 32767.0)
		var sample_r := int(clampf(data[i].y, -1.0, 1.0) * 32767.0)

		# Store 16-bit PCM little-endian
		byte_data.encode_s16(i * 4, sample_l)
		byte_data.encode_s16(i * 4 + 2, sample_r)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav


func _make_correct_sfx(sr: int) -> PackedVector2Array:
	var length := 0.12
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var envelope := 1.0 - (t / length)
		var freq := 800.0 + t * 2000.0  # Rising pitch
		var val := sin(2.0 * PI * freq * t) * envelope * 0.3
		data[i] = Vector2(val, val)

	return data


func _make_correct_chiptune_sfx(sr: int) -> PackedVector2Array:
	# 8-Bit Arcade: Crisp square-wave 3-step coin/jump arpeggio (C6 -> E6 -> G6)
	var length := 0.14
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)
	var notes := [1046.50, 1318.51, 1567.98]

	for i in range(samples):
		var t := float(i) / sr
		var step_idx := mini(int((t / length) * 3.0), 2)
		var freq: float = notes[step_idx]
		var env := pow(1.0 - (t / length), 0.75)
		var sq := 1.0 if sin(2.0 * PI * freq * t) >= 0.0 else -1.0
		var sub := sin(2.0 * PI * (freq * 0.5) * t) * 0.3
		var val := (sq * 0.7 + sub) * env * 0.24
		data[i] = Vector2(val, val)

	return data


func _make_correct_cyber_click_sfx(sr: int) -> PackedVector2Array:
	# Mech Switch: Tactile high-tech transient click + punchy sub-bass thump + bell ping
	var length := 0.11
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		# Ultra-fast mechanical switch transient (first 12ms)
		var click_env := exp(-t * 220.0)
		var click_wave := sin(2.0 * PI * 3200.0 * t) * 0.6 + sin(2.0 * PI * 4800.0 * t) * 0.4
		# Warm punchy body
		var body_env := exp(-t * 38.0)
		var body_freq := 260.0 - t * 1200.0
		var body_wave := sin(2.0 * PI * maxf(90.0, body_freq) * t)
		# Crisp metallic overtone
		var ping_env := exp(-t * 28.0)
		var ping_wave := sin(2.0 * PI * 1480.0 * t) * 0.35
		var val := (click_wave * click_env * 0.55 + body_wave * body_env * 0.5 + ping_wave * ping_env) * 0.36
		data[i] = Vector2(val, val)

	return data


func _make_correct_dream_chord_sfx(sr: int) -> PackedVector2Array:
	# Synth Chord: Lush polyphonic synthwave major-7th pluck with stereo chorus detune
	var length := 0.22
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)
	# F5 Major 7th chord (F5, A5, C6, E6)
	var freqs := [698.46, 880.0, 1046.50, 1318.51]

	for i in range(samples):
		var t := float(i) / sr
		var env := pow(1.0 - (t / length), 1.6)
		var attack := clampf(t / 0.008, 0.0, 1.0)
		var l_sum := 0.0
		var r_sum := 0.0
		for f in freqs:
			# Rich saw-like harmonic blend with slight stereo detune
			var fl: float = f * 0.997
			var fr: float = f * 1.003
			l_sum += sin(2.0 * PI * fl * t) * 0.65 + sin(4.0 * PI * fl * t) * 0.25
			r_sum += sin(2.0 * PI * fr * t) * 0.65 + sin(4.0 * PI * fr * t) * 0.25
		var scale := attack * env * 0.11
		data[i] = Vector2(l_sum * scale, r_sum * scale)

	return data


func _make_correct_plasma_zap_sfx(sr: int) -> PackedVector2Array:
	# Plasma Laser: Sci-fi resonant frequency sweep with harmonic FM shimmer
	var length := 0.15
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	var phase := 0.0
	for i in range(samples):
		var t := float(i) / sr
		var progress := t / length
		var env := pow(1.0 - progress, 1.2)
		# Fast upward then downward sci-fi pitch bend
		var freq := 1800.0 - pow(progress, 0.55) * 1350.0 + sin(progress * PI) * 450.0
		var fm_mod := sin(2.0 * PI * 95.0 * t) * 180.0
		phase += (freq + fm_mod) / float(sr)
		var wave := sin(2.0 * PI * phase) * 0.75 + sin(4.0 * PI * phase) * 0.25
		var pan := 0.5 + 0.35 * sin(progress * PI * 2.0)
		var val := wave * env * 0.30
		data[i] = Vector2(val * (1.0 - pan * 0.3), val * (0.7 + pan * 0.3))

	return data


func _make_wrong_sfx(sr: int) -> PackedVector2Array:
	var length := 0.25
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var envelope := 1.0 - (t / length)
		var freq := 200.0 - t * 100.0  # Low descending buzz
		var val := sin(2.0 * PI * freq * t) * envelope * 0.4
		data[i] = Vector2(val, val)

	return data


func _make_timeout_sfx(sr: int) -> PackedVector2Array:
	var length := 0.3
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var envelope := (1.0 - t / length) * 0.8
		var freq := 500.0 - t * 400.0
		var val := sin(2.0 * PI * freq * t) * envelope * 0.25
		data[i] = Vector2(val, val)

	return data


func _make_combo_sfx(sr: int) -> PackedVector2Array:
	var length := 0.3
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var envelope := (1.0 - t / length) * 0.7
		# Triple ascending chime
		var phase1 := sin(2.0 * PI * 800.0 * t)
		var phase2 := sin(2.0 * PI * 1200.0 * t)
		var phase3 := sin(2.0 * PI * 1600.0 * t)
		var val := (phase1 + phase2 + phase3) / 3.0 * envelope * 0.25
		data[i] = Vector2(val, val)

	return data


func _make_game_over_sfx(sr: int) -> PackedVector2Array:
	var length := 0.8
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var envelope := (1.0 - t / length) * 0.6
		# Descending sad tone
		var freq := 600.0 - t * 500.0
		var val := sin(2.0 * PI * freq * t) * envelope * 0.3
		# Add a second harmonic for richness
		val += sin(2.0 * PI * freq * 0.5 * t) * envelope * 0.15
		data[i] = Vector2(val, val)

	return data


func _make_tap_sfx(sr: int) -> PackedVector2Array:
	var length := 0.06
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var envelope := 1.0 - (t / length)
		var val := sin(2.0 * PI * 1000.0 * t) * envelope * 0.15
		data[i] = Vector2(val, val)

	return data


func _make_remap_sfx(sr: int) -> PackedVector2Array:
	var length := 0.4
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	for i in range(samples):
		var t := float(i) / sr
		var progress := t / length
		var envelope := sin(PI * progress) * 0.35  # rise then fall
		var freq := 300.0 + progress * 900.0  # sweeping up
		var tremolo := 0.7 + 0.3 * sin(2.0 * PI * 18.0 * t)  # fast wobble
		var val := sin(2.0 * PI * freq * t) * envelope * tremolo
		data[i] = Vector2(val, val)

	return data


func _make_unlock_sfx(sr: int) -> PackedVector2Array:
	var length := 0.55
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)

	# 4-note ascending fanfare / chime (C5 -> E5 -> G5 -> C6) with sparkle harmonics
	var note_freqs := [523.25, 659.25, 783.99, 1046.50]
	var note_starts := [0.0, 0.09, 0.18, 0.27]

	for i in range(samples):
		var t := float(i) / sr
		var total_val := 0.0

		for n in range(4):
			var n_start: float = note_starts[n]
			if t >= n_start:
				var dt: float = t - n_start
				var note_dur := 0.28 if n == 3 else 0.18
				var env := clampf(1.0 - (dt / note_dur), 0.0, 1.0)
				env = env * env # Quadratic decay for crisp bell response
				var f: float = note_freqs[n]
				# Fundamental + 2nd harmonic (octave) + 3rd harmonic for bright shimmer
				var wave := sin(2.0 * PI * f * dt) * 0.6 + sin(4.0 * PI * f * dt) * 0.25 + sin(6.0 * PI * f * dt) * 0.15
				total_val += wave * env * 0.22

		data[i] = Vector2(total_val, total_val)

	return data


func _make_shield_sfx(sr: int) -> PackedVector2Array:
	# Crystalline sci-fi barrier activation hum + harmonic shimmer
	var length := 0.28
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)
	for i in range(samples):
		var t := float(i) / sr
		var env := sin((t / length) * PI)
		var f1 := 440.0 + (t / length) * 440.0
		var f2 := 659.25 + (t / length) * 659.25
		var shimmer := sin(2.0 * PI * 32.0 * t) * 0.25 + 0.75
		var val := (sin(2.0 * PI * f1 * t) * 0.55 + sin(2.0 * PI * f2 * t) * 0.45) * env * shimmer * 0.28
		data[i] = Vector2(val * 0.95, val * 1.05)
	return data


func _make_shield_break_sfx(sr: int) -> PackedVector2Array:
	# Energetic barrier deflection / shatter chime + sub-punch
	var length := 0.32
	var samples := int(sr * length)
	var data := PackedVector2Array()
	data.resize(samples)
	for i in range(samples):
		var t := float(i) / sr
		var env := pow(1.0 - (t / length), 1.4)
		var sub_f := 280.0 * exp(-t * 9.0) + 55.0
		var sub := sin(2.0 * PI * sub_f * t) * 0.55
		var bell := (sin(2.0 * PI * 1174.66 * t) + sin(2.0 * PI * 1567.98 * t) * 0.7) * exp(-t * 11.0) * 0.45
		var val := (sub + bell) * env * 0.34
		data[i] = Vector2(val, val)
	return data
