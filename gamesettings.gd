class_name GameSettings
extends Node

# --- Game States ---
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, TUTORIAL }

# --- Game Tuning Constants ---
const MIN_SWIPE_LENGTH := 50.0
const INITIAL_TIME_LIMIT := 1.5
const MAX_LIVES := 3
const BASE_CORRECT_POINTS := 10
const SPEED_BONUS_MAX := 20
# --- Combo Multiplier ---
const COMBO_MAX_MULTIPLIER := 4    # cap the multiplier at x4
const COMBO_HITS_PER_LEVEL := 5    # correct swipes needed to raise the multiplier by 1
const SCREEN_SHAKE_STRENGTH := 8.0
const SAVE_FILE := "user://music_square_save.json"

# --- Unlockable Background Songs (CC0 by Komiku & Juhani Junkala) ---
# Each entry: name, resource path, and the high score needed to unlock it.
# The first song (score 0) is always unlocked.
const SONGS := [
	{"id": "arcade",    "name": "THE ARCADE GAME",       "path": "res://music/arcade_menu.ogg",  "unlock_score": 0},
	{"id": "jj_title",  "name": "TITLE SCREEN",          "path": "res://music/jj_title.ogg",     "unlock_score": 50000},
	{"id": "battle",    "name": "BATTLE THEME",           "path": "res://music/battle_theme.ogg", "unlock_score": 150000},
	{"id": "jj_level1", "name": "LEVEL 1 - BEGINNING",   "path": "res://music/jj_level1.ogg",    "unlock_score": 400000},
	{"id": "jj_level2", "name": "LEVEL 2 - UNDERGROUND", "path": "res://music/jj_level2.ogg",    "unlock_score": 800000},
	{"id": "jj_level3", "name": "LEVEL 3 - SKY HIGH",    "path": "res://music/jj_level3.ogg",    "unlock_score": 1500000},
]

# --- Direction Remapping (advanced difficulty) ---
const REMAP_SCORE_THRESHOLD := 150
# Remap fires after a random number of turns in this inclusive range,
# re-rolled every time, so the switch never feels predictable.
const REMAP_INTERVAL_TURNS_MIN := 5
const REMAP_INTERVAL_TURNS_MAX := 10

# --- Unlockable Visual Themes ---
# Each theme: id, name, unlock score, board square colors, background shader
# colors, and two accent colors (primary borders/glow + secondary highlights).
# The first theme (score 0) is always unlocked.
const THEMES := [
	{
		"id": "synthwave", "name": "SYNTHWAVE", "unlock_score": 0,
		"board": {
			"up":    Color(0.88, 0.22, 0.35, 1.0),   # Crimson Red
			"down":  Color(0.82, 0.72, 0.06, 1.0),   # Warm Yellow
			"left":  Color(0.10, 0.70, 0.38, 1.0),   # Arcade Green
			"right": Color(0.12, 0.46, 0.88, 1.0),   # Royal Blue
		},
		"bg": {
			"sky_top":    Color(0.05, 0.03, 0.12),
			"sky_mid":    Color(0.14, 0.05, 0.24),
			"sky_bottom": Color(0.28, 0.06, 0.30),
			"grid_color": Color(0.70, 0.15, 0.70),
			"sun_color":  Color(0.85, 0.35, 0.55),
		},
		"accent":  Color(0.90, 0.28, 0.52),
		"accent2": Color(0.65, 0.15, 0.70),
	},
	{
		"id": "ocean", "name": "OCEAN", "unlock_score": 0,
		"board": {
			"up":    Color(0.10, 0.58, 0.68, 1.0),   # Deep Teal
			"down":  Color(0.82, 0.34, 0.20, 1.0),   # Burnt Coral
			"left":  Color(0.10, 0.40, 0.80, 1.0),   # Ocean Blue
			"right": Color(0.62, 0.76, 0.22, 1.0),   # Sea Lime
		},
		"bg": {
			"sky_top":    Color(0.02, 0.04, 0.13),
			"sky_mid":    Color(0.03, 0.08, 0.22),
			"sky_bottom": Color(0.04, 0.14, 0.30),
			"grid_color": Color(0.08, 0.42, 0.62),
			"sun_color":  Color(0.12, 0.58, 0.78),
		},
		"accent":  Color(0.12, 0.60, 0.78),
		"accent2": Color(0.80, 0.34, 0.20),
	},
	{
		"id": "ember", "name": "EMBER", "unlock_score": 0,
		"board": {
			"up":    Color(0.82, 0.16, 0.16, 1.0),   # Deep Crimson
			"down":  Color(0.84, 0.50, 0.06, 1.0),   # Amber
			"left":  Color(0.50, 0.16, 0.78, 1.0),   # Violet (contrast)
			"right": Color(0.82, 0.72, 0.04, 1.0),   # Gold
		},
		"bg": {
			"sky_top":    Color(0.08, 0.02, 0.02),
			"sky_mid":    Color(0.18, 0.05, 0.02),
			"sky_bottom": Color(0.28, 0.08, 0.02),
			"grid_color": Color(0.72, 0.20, 0.04),
			"sun_color":  Color(0.88, 0.45, 0.08),
		},
		"accent":  Color(0.88, 0.38, 0.06),
		"accent2": Color(0.82, 0.16, 0.16),
	},
	{
		"id": "forest", "name": "FOREST", "unlock_score": 0,
		"board": {
			"up":    Color(0.14, 0.55, 0.18, 1.0),   # Forest Green
			"down":  Color(0.62, 0.30, 0.08, 1.0),   # Earth Brown
			"left":  Color(0.22, 0.52, 0.80, 1.0),   # Sky Blue
			"right": Color(0.80, 0.66, 0.12, 1.0),   # Harvest Gold
		},
		"bg": {
			"sky_top":    Color(0.02, 0.07, 0.02),
			"sky_mid":    Color(0.04, 0.12, 0.04),
			"sky_bottom": Color(0.06, 0.18, 0.06),
			"grid_color": Color(0.14, 0.46, 0.18),
			"sun_color":  Color(0.55, 0.70, 0.22),
		},
		"accent":  Color(0.20, 0.62, 0.24),
		"accent2": Color(0.80, 0.66, 0.12),
	},
	{
		"id": "midnight", "name": "MIDNIGHT", "unlock_score": 0,
		"board": {
			"up":    Color(0.44, 0.30, 0.82, 1.0),   # Soft Indigo
			"down":  Color(0.76, 0.36, 0.48, 1.0),   # Dusty Rose
			"left":  Color(0.78, 0.68, 0.28, 1.0),   # Warm Gold
			"right": Color(0.22, 0.60, 0.65, 1.0),   # Muted Teal
		},
		"bg": {
			"sky_top":    Color(0.02, 0.02, 0.08),
			"sky_mid":    Color(0.05, 0.04, 0.16),
			"sky_bottom": Color(0.08, 0.06, 0.24),
			"grid_color": Color(0.28, 0.22, 0.62),
			"sun_color":  Color(0.42, 0.35, 0.80),
		},
		"accent":  Color(0.44, 0.35, 0.82),
		"accent2": Color(0.76, 0.36, 0.48),
	},
]

# --- Achievements / Badges (Ordered by Unlock Difficulty) ---
const ACHIEVEMENTS := [
	{"id": "first_blood",     "name": "FIRST BLOOD",     "desc": "Score 25,000+ points in a single game", "icon": "sword", "color": Color(0.88, 0.22, 0.25)},
	{"id": "dedicated",       "name": "DEDICATED",       "desc": "Play 50 total games across all sessions", "icon": "star", "color": Color(1.0, 0.43, 0.25)},
	{"id": "speed_demon",     "name": "SPEED DEMON",     "desc": "Score 35 lightning swipes (<0.35s) in a game", "icon": "hourglass", "color": Color(0.2, 0.95, 0.65)},
	{"id": "sharpshooter",    "name": "SHARPSHOOTER",    "desc": "95%+ accuracy with 100+ swipes", "icon": "crosshair", "color": Color(0.15, 0.85, 0.9)},
	{"id": "iron_grip",       "name": "IRON GRIP",       "desc": "Complete 15 Hold Squares in a single game", "icon": "shield", "color": Color(0.0, 0.9, 1.0)},
	{"id": "unstoppable",     "name": "UNSTOPPABLE",     "desc": "Reach a 150 streak in one game", "icon": "flame", "color": Color(0.92, 0.55, 0.08)},
	{"id": "untouchable",     "name": "UNTOUCHABLE",     "desc": "Score 100,000+ points with no hearts lost", "icon": "shield", "color": Color(0.3, 0.65, 1.0)},
	{"id": "clutch_genius",   "name": "CLUTCH GENIUS",   "desc": "Score 50 correct swipes in a row on 1 heart", "icon": "flame", "color": Color(1.0, 0.1, 0.27)},
	{"id": "frenzy_fanatic",  "name": "FRENZY FANATIC",  "desc": "Trigger Frenzy 20 times in one game", "icon": "bolt", "color": Color(1.0, 0.85, 0.15)},
	{"id": "remap_master",    "name": "REMAP MASTER",    "desc": "Survive 40 direction remaps in one run", "icon": "compass", "color": Color(0.85, 0.4, 0.95)},
	{"id": "fever_pitch",     "name": "FEVER PITCH",     "desc": "Trigger 3 Frenzies while holding 4x Multiplier", "icon": "bolt", "color": Color(0.83, 0.0, 0.98)},
	{"id": "combo_king",      "name": "COMBO KING",      "desc": "Reach a massive 300 streak in one game", "icon": "crown", "color": Color(1.0, 0.8, 0.1)},
	{"id": "marathon_runner", "name": "MARATHON RUNNER", "desc": "Reach 500 total swipes in a single run", "icon": "hourglass", "color": Color(0.46, 1.0, 0.01)},
	{"id": "arcade_legend",   "name": "ARCADE LEGEND",   "desc": "Score 1,000,000+ points in a single game", "icon": "trophy", "color": Color(1.0, 0.6, 0.15)},
	{"id": "mythic_swiper",   "name": "MYTHIC SWIPER",   "desc": "Score 2,000,000+ points in a single game", "icon": "trophy", "color": Color(1.0, 0.84, 0.0)},
	{"id": "grandmaster",     "name": "GRANDMASTER",     "desc": "100% perfect accuracy with 1,000+ swipes", "icon": "star", "color": Color(0.95, 0.3, 0.75)},
	{"id": "completionist",   "name": "COMPLETIONIST",   "desc": "Unlock every badge, song, and theme", "icon": "diamond", "color": Color(1.0, 1.0, 1.0), "hidden": true},
]

# --- Anti-Tamper Security Keys & Salts ---
const _SAVE_KEY: String = "MS_2026_Secur3#Godot!Swip3_K3y"
const _SALT: String = "MS_Ch3ck$um_S4lt_9981"

# --- Save Data (with In-Memory Obfuscation & Decoys) ---
var _high_score_val: int = 0
var _high_score_mask: int = 0x3F8A1C5D
var _high_score_decoy: int = 0

var high_score: int:
	get:
		var real_val: int = _high_score_val ^ _high_score_mask
		if _high_score_decoy != real_val:
			# Memory scanner modified decoy
			return 0
		return real_val
	set(val):
		var new_mask: int = (randi() & 0x7FFFFFFF) ^ 0x3F8A1C5D
		_high_score_mask = new_mask
		_high_score_val = val ^ new_mask
		_high_score_decoy = val

var _best_streak_val: int = 0
var _best_streak_mask: int = 0x5C2E7A91
var _best_streak_decoy: int = 0

var best_streak: int:
	get:
		var real_val: int = _best_streak_val ^ _best_streak_mask
		if _best_streak_decoy != real_val:
			return 0
		return real_val
	set(val):
		var new_mask: int = (randi() & 0x7FFFFFFF) ^ 0x5C2E7A91
		_best_streak_mask = new_mask
		_best_streak_val = val ^ new_mask
		_best_streak_decoy = val

var games_played: int = 0
var first_play: bool = true
var selected_song: String = "arcade"
var selected_theme: String = "synthwave"
var music_volume: float = 0.8
var haptics_enabled: bool = true
var board_vertical_offset: float = 0.0
var unlocked_achievements: Array = []


func _ready() -> void:
	load_data()


func is_song_unlocked(song: Dictionary) -> bool:
	return high_score >= int(song.get("unlock_score", 0))


func is_theme_unlocked(_theme: Dictionary) -> bool:
	return true


func is_achievement_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked_achievements


func unlock_achievement(achievement_id: String) -> bool:
	if achievement_id in unlocked_achievements:
		return false
	unlocked_achievements.append(achievement_id)
	save_data()
	return true


func _compute_checksum(data: Dictionary) -> String:
	var payload := "%d:%d:%d:%s:%s:%s" % [
		int(data.get("high_score", 0)),
		int(data.get("best_streak", 0)),
		int(data.get("games_played", 0)),
		str(data.get("selected_song", "")),
		str(data.get("selected_theme", "")),
		_SALT
	]
	return payload.sha256_text()


func save_data() -> void:
	var data := {
		"high_score": high_score,
		"best_streak": best_streak,
		"games_played": games_played,
		"first_play": first_play,
		"selected_song": selected_song,
		"selected_theme": selected_theme,
		"music_volume": music_volume,
		"haptics_enabled": haptics_enabled,
		"board_vertical_offset": board_vertical_offset,
		"unlocked_achievements": unlocked_achievements,
	}
	data["_checksum"] = _compute_checksum(data)
	var file := FileAccess.open_encrypted_with_pass(SAVE_FILE, FileAccess.WRITE, _SAVE_KEY)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		return

	var raw_text: String = ""
	var is_encrypted: bool = false

	# Inspect header to detect whether file is encrypted or legacy plaintext
	var test_file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if test_file != null:
		var magic: PackedByteArray = test_file.get_buffer(4)
		test_file.close()
		# Godot encrypted files start with "GDEC" (0x47, 0x44, 0x45, 0x43)
		if magic.size() >= 4 and magic[0] == 0x47 and magic[1] == 0x44 and magic[2] == 0x45 and magic[3] == 0x43:
			is_encrypted = true

	if is_encrypted:
		var enc_file := FileAccess.open_encrypted_with_pass(SAVE_FILE, FileAccess.READ, _SAVE_KEY)
		if enc_file != null:
			raw_text = enc_file.get_as_text()
			enc_file.close()
	else:
		var plain_file := FileAccess.open(SAVE_FILE, FileAccess.READ)
		if plain_file != null:
			raw_text = plain_file.get_as_text()
			plain_file.close()

	if raw_text.is_empty():
		return

	var json := JSON.new()
	var err: Error = json.parse(raw_text)
	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data

		# Checksum integrity verification
		if data.has("_checksum"):
			var expected_chk: String = _compute_checksum(data)
			if str(data["_checksum"]) != expected_chk:
				# Integrity violation! File was tampered with on disk.
				data["high_score"] = 0
				data["best_streak"] = 0

		high_score = int(data.get("high_score", 0))
		best_streak = int(data.get("best_streak", 0))
		games_played = int(data.get("games_played", 0))
		first_play = bool(data.get("first_play", true))
		selected_song = str(data.get("selected_song", "arcade"))
		var song_valid := false
		for s: Dictionary in SONGS:
			if str(s.get("id", "")) == selected_song:
				song_valid = true
				break
		if not song_valid and not SONGS.is_empty():
			selected_song = str(SONGS[0].get("id", ""))
		selected_theme = str(data.get("selected_theme", "synthwave"))
		music_volume = float(data.get("music_volume", 0.8))
		haptics_enabled = bool(data.get("haptics_enabled", true))
		board_vertical_offset = clampf(float(data.get("board_vertical_offset", 0.0)), -100.0, 120.0)
		var raw_achievements: Array = data.get("unlocked_achievements", [])
		unlocked_achievements = []
		for ach_id in raw_achievements:
			unlocked_achievements.append(str(ach_id))

		# Automatically migrate old unencrypted saves to encrypted format
		if not is_encrypted:
			save_data()


func update_high_score(score: int, streak: int) -> bool:
	games_played += 1
	var new_record := false
	if score > high_score:
		high_score = score
		new_record = true
	if streak > best_streak:
		best_streak = streak
		new_record = true
	save_data()
	return new_record


func reset_game_data() -> void:
	high_score = 0
	best_streak = 0
	games_played = 0
	first_play = true
	selected_song = "arcade"
	selected_theme = "synthwave"
	haptics_enabled = true
	board_vertical_offset = 0.0
	unlocked_achievements = []
	save_data()
