extends Node

# Synthesized sound effects using AudioStreamGenerator
# No external audio files needed
var _players: Dictionary = {}


func _ready() -> void:
	# Pre-generate all sound effects
	_generate_all_sounds()


func play(sound_name: String) -> void:
	var player: AudioStreamPlayer = _players.get(sound_name)
	if player != null:
		player.play()


func _generate_all_sounds() -> void:
	_generate_sound("correct", _make_correct_sfx)
	_generate_sound("wrong", _make_wrong_sfx)
	_generate_sound("timeout", _make_timeout_sfx)
	_generate_sound("combo", _make_combo_sfx)
	_generate_sound("game_over", _make_game_over_sfx)
	_generate_sound("tap", _make_tap_sfx)
	_generate_sound("remap", _make_remap_sfx)
	_generate_sound("unlock", _make_unlock_sfx)


func _generate_sound(sound_name: String, generator: Callable) -> void:
	var sample_rate := 44100
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
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
