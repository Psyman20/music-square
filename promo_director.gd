extends Control
class_name PromoDirector

const PromoEqualizerScript = preload("res://promo_equalizer.gd")
const PromoTouchIndicatorScript = preload("res://promo_touch_indicator.gd")

@export var is_landscape: bool = true

# Timeline state (32s high-energy v1.2.1 marketing trailer)
var elapsed: float = 0.0
var target_duration: float = 32.0

# References
@onready var main_node: Node = $SubViewportContainer/SubViewport/Main
@onready var viewport_container: Control = $SubViewportContainer
@onready var bg_rect: ColorRect = $Background
@onready var feature_card: Panel = $FeatureCard
@onready var feature_icon: Label = $FeatureCard/IconLabel
@onready var feature_title: Label = $FeatureCard/TitleLabel
@onready var feature_desc: Label = $FeatureCard/DescLabel
@onready var equalizer: Control = $Equalizer
@onready var intro_overlay: Control = $IntroOverlay
@onready var outro_overlay: Control = $OutroOverlay
@onready var leaderboard_card: Control = $LeaderboardCard

# Left-side / HUD nodes
var score_heading_label: Label = null
var live_score_label: Label = null
var streak_heading_label: Label = null
var live_streak_label: Label = null
var mult_heading_label: Label = null
var live_mult_label: Label = null

# Bot & timeline state
var touch_indicator: Control = null
var swipe_timer: float = 0.0
var is_gameplay_started: bool = false
var current_feature_idx: int = -1
var feature_tween: Tween = null
var current_theme_idx: int = -1
var _story_screen_opened: bool = false
var _active_boss_stage: int = 0
var _maestro_finisher_triggered: bool = false
var _themes_arcade_started: bool = false
var _orig_viewport_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	if has_node("LeftPanel/ScoreHeading"):
		score_heading_label = get_node("LeftPanel/ScoreHeading")
	if has_node("LeftPanel/ScoreValue"):
		live_score_label = get_node("LeftPanel/ScoreValue")
	if has_node("LeftPanel/StreakHeading"):
		streak_heading_label = get_node("LeftPanel/StreakHeading")
	if has_node("LeftPanel/StreakValue"):
		live_streak_label = get_node("LeftPanel/StreakValue")
	if has_node("LeftPanel/MultiplierHeading"):
		mult_heading_label = get_node("LeftPanel/MultiplierHeading")
	if has_node("LeftPanel/MultiplierValue"):
		live_mult_label = get_node("LeftPanel/MultiplierValue")
	elif has_node("TopHeader/ScoreValue"):
		live_score_label = get_node("TopHeader/ScoreValue")

	if viewport_container != null:
		viewport_container.pivot_offset = viewport_container.size * 0.5
		_orig_viewport_scale = viewport_container.scale

	# Upgrade Intro & Outro copy dynamically for v1.2.1
	var intro_sub := get_node_or_null("IntroOverlay/IntroBox/SubTitle") as Label
	if intro_sub != null:
		intro_sub.text = "SWIPE TO THE BEAT  •  CONQUER 4 BOSSES"
	var outro_sub := get_node_or_null("OutroOverlay/OutroBox/SubCta") as Label
	if outro_sub != null:
		outro_sub.text = "ARCADE MODE  •  4 STORY BOSSES  •  BOSS RUSH"

	# Setup touch indicator inside Main scene
	touch_indicator = PromoTouchIndicatorScript.new()
	touch_indicator.name = "PromoTouchIndicator"
	main_node.add_child(touch_indicator)

	# Configure Main game settings for a rich showcase save state (all cosmetics & 3-star cards visible!)
	var s: Node = main_node.get_node("Settings")
	s.first_play = false
	s.selected_song = "battle"
	s.selected_theme = "synthwave"
	s.selected_trail = "rainbow"
	s.selected_skin = "equalizer"
	s.selected_sfx_pack = "dream_chord"
	s.story_levels_cleared = [1, 2, 3, 4]
	s.story_level_stars = {"1": 3, "2": 3, "3": 3, "4": 3}
	s.story_level_best_time = {"1": 21.4, "2": 29.8, "3": 38.2, "4": 46.5}
	s.story_boss_rush_cleared = true
	s.story_boss_rush_best_time = 134.2
	s.unlocked_trails = ["neon", "rainbow", "electric", "plasma", "stardust", "venom", "void_vortex", "melody_notes"]
	s.unlocked_skins = ["classic", "wireframe", "scanline", "equalizer", "diamond", "titan_armor"]
	s.unlocked_sfx_packs = ["classic", "chiptune", "cyber_click", "dream_chord", "plasma_zap", "opera_chime"]
	if main_node.sfx != null:
		main_node.sfx.active_pack = "dream_chord"

	# Attach synthwave background shader
	var shader_p := "res://shaders/trailer_bg.gdshader"
	if bg_rect != null and ResourceLoader.exists(shader_p):
		var shader: Shader = load(shader_p)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("speed", 0.55)
		bg_rect.material = mat

	if intro_overlay != null:
		intro_overlay.modulate.a = 1.0
	if outro_overlay != null:
		outro_overlay.modulate.a = 0.0
		outro_overlay.visible = false
	if leaderboard_card != null:
		leaderboard_card.modulate.a = 0.0
		leaderboard_card.visible = false
	if feature_card != null:
		feature_card.modulate.a = 0.0
	if main_node.has_node("TutorialScreen"):
		main_node.get_node("TutorialScreen").visible = false

	print("[PromoDirector] Initialized v1.2.1 marketing trailer. Landscape: ", is_landscape)


func _process(delta: float) -> void:
	elapsed += delta

	# Keep showcase gameplay alive & responsive
	if is_gameplay_started and not _story_screen_opened and not _maestro_finisher_triggered:
		main_node.lives = 3
		main_node.time_left_in_turn = 2.0
		main_node.frenzy_exit_buffer = 0.0
		main_node.hold_exit_buffer = 0.0

	_update_hud_display()

	# ====================================================
	# v1.2.1 HIGH-ENERGY MARKETING STORYBOARD (32.0s)
	# ====================================================

	# [0.0s - 1.8s]: Instant Hook
	if elapsed < 1.8:
		if current_feature_idx != 0:
			_show_feature(0, "🎵", "MUSIC SQUARE", "Lightning-fast neon rhythm action + epic Boss Battles!")

	# [1.8s]: Launch Arcade Mode
	elif elapsed >= 1.8 and not is_gameplay_started:
		is_gameplay_started = true
		_start_arcade_showcase()

	# [1.8s - 6.2s]: Arcade Mode Rhythm & Combos
	elif elapsed >= 1.8 and elapsed < 6.2:
		if current_feature_idx != 1 and elapsed >= 2.2:
			_show_feature(1, "⚡", "ARCADE RHYTHM", "Match neon colors at lightning speed for 4X combos!")
		_process_arcade_bot_swipes(delta, 0.28)

	# [6.2s - 10.2s]: FRENZY MODE Climax
	elif elapsed >= 6.2 and elapsed < 10.2:
		if current_feature_idx != 2:
			_trigger_frenzy_climax()
		_process_arcade_bot_swipes(delta, 0.17)

	# [10.2s - 12.6s]: Scrollable Story Mode & Boss Rush Reveal
	elif elapsed >= 10.2 and elapsed < 12.6:
		if not _story_screen_opened:
			_open_story_mode_showcase()
		# Smoothly scroll down through the 4 Boss Cards to reveal Boss Rush Gauntlet!
		var scroll: ScrollContainer = main_node.get("_story_scroll")
		if scroll != null and is_instance_valid(scroll):
			var scroll_t: float = clampf((elapsed - 10.7) / 1.5, 0.0, 1.0)
			scroll.scroll_vertical = int(scroll_t * 320.0)

	# [12.6s - 16.0s]: BOSS 1 — CHROMA TITAN (with TITAN ARMOR skin)
	elif elapsed >= 12.6 and elapsed < 16.0:
		if _active_boss_stage != 1:
			_launch_boss_showcase(1, "titan_armor", "electric", "cyber_click", "🤖", "LVL 1: CHROMA TITAN", "Dodge escalating bombs & shatter all 4 armored parts!")
		_process_story_bot_swipes(delta, 0.34)

	# [16.0s - 19.4s]: BOSS 2 — CYBER HYDRA (with VENOM MATRIX trail)
	elif elapsed >= 16.0 and elapsed < 19.4:
		if _active_boss_stage != 2:
			_launch_boss_showcase(2, "wireframe", "venom", "plasma_zap", "🐍", "LVL 2: CYBER HYDRA", "Outplay reflective shields & sever all 4 regenerating fangs!")
		_process_story_bot_swipes(delta, 0.34)

	# [19.4s - 22.8s]: BOSS 3 — VOID SERAPH (with VOID VORTEX trail)
	elif elapsed >= 19.4 and elapsed < 22.8:
		if _active_boss_stage != 3:
			_launch_boss_showcase(3, "diamond", "void_vortex", "dream_chord", "🌀", "LVL 3: VOID SERAPH", "Survive Void Rifts & dimensional color warps every turn!")
		_process_story_bot_swipes(delta, 0.34)

	# [22.8s - 27.6s]: BOSS 4 — PHANTOM MAESTRO + BOSS OBLITERATION!
	elif elapsed >= 22.8 and elapsed < 27.6:
		if _active_boss_stage != 4:
			_launch_boss_showcase(4, "equalizer", "melody_notes", "opera_chime", "🎭", "LVL 4: PHANTOM MAESTRO", "Play his melody notes, beat the Mirror Curse & unmask him!")
		# At 25.4s, trigger the dramatic Phase 2 Masquerade True Mask finishing blow & multi-explosion!
		if elapsed >= 25.4 and not _maestro_finisher_triggered:
			_trigger_maestro_obliteration()
		elif not _maestro_finisher_triggered:
			_process_story_bot_swipes(delta, 0.36)

	# [27.6s - 29.6s]: Unlockable Themes & Boss Rush Hype
	elif elapsed >= 27.6 and elapsed < 29.6:
		if not _themes_arcade_started:
			_start_themes_flash_showcase()
		_process_theme_switches()
		_process_arcade_bot_swipes(delta, 0.24)

	# [29.6s - 32.0s]: Punchy Outro Call to Action
	elif elapsed >= 29.6:
		if current_feature_idx != 9:
			_show_outro_cta()

	if elapsed >= target_duration:
		print("[PromoDirector] Finished v1.2.1 promo video (32.0s). Exiting...")
		get_tree().quit()


func _punch_viewport() -> void:
	if viewport_container == null:
		return
	var tw := create_tween()
	tw.tween_property(viewport_container, "scale", _orig_viewport_scale * 1.035, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(viewport_container, "scale", _orig_viewport_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_bg(col: Color) -> void:
	if bg_rect == null:
		return
	var tw := create_tween()
	var orig_col: Color = bg_rect.color
	tw.tween_property(bg_rect, "color", col, 0.07)
	tw.tween_property(bg_rect, "color", orig_col, 0.28)


func _start_arcade_showcase() -> void:
	if intro_overlay != null:
		var t := create_tween()
		t.tween_property(intro_overlay, "modulate:a", 0.0, 0.35)
		t.tween_callback(func(): intro_overlay.visible = false)

	var s: Node = main_node.get_node("Settings")
	s.first_play = false
	main_node.set("_is_walkthrough_active", false)
	main_node.set("is_story_mode", false)
	main_node.set("is_boss_rush", false)
	main_node.call("_start_game")
	equalizer.bump(1.1)
	_punch_viewport()


func _trigger_frenzy_climax() -> void:
	current_feature_idx = 2
	_show_feature(2, "🔥", "FRENZY & OVERDRIVE", "Electric 4X lightning bursts, speed combos & announcer hype!")
	main_node.call("_activate_frenzy_mode")
	equalizer.bump(1.6)
	_punch_viewport()
	_flash_bg(Color(0.95, 0.72, 0.12, 1.0))


func _open_story_mode_showcase() -> void:
	_story_screen_opened = true
	main_node.set("is_frenzy_active", false)
	main_node.call("_show_menu")
	main_node.call("_open_story_screen")
	_show_feature(3, "⚔", "STORY MODE & BOSS RUSH", "4 unique bosses, 3-Star Mastery, Boss Cosmetics & Gauntlet!")
	equalizer.bump(1.2)
	_punch_viewport()


func _launch_boss_showcase(lvl: int, skin_id: String, trail_id: String, sfx_pack: String, icon_s: String, title_s: String, desc_s: String) -> void:
	_story_screen_opened = false
	_active_boss_stage = lvl
	if main_node.get("_story_screen") != null:
		main_node.get("_story_screen").visible = false

	var s: Node = main_node.get_node("Settings")
	s.selected_skin = skin_id
	s.selected_trail = trail_id
	s.selected_sfx_pack = sfx_pack
	if main_node.sfx != null:
		main_node.sfx.active_pack = sfx_pack

	main_node.set("is_story_mode", true)
	main_node.set("is_boss_rush", lvl == 4)
	main_node.set("story_level", lvl)
	main_node.call("_start_game")

	# Pre-damage 1 part slightly so the audience immediately sees a juicy part-shatter explosion!
	if lvl == 1:
		main_node.story_part_hp["up"] = 2
	elif lvl == 2:
		main_node.story_part_hp["left"] = 2
	elif lvl == 3:
		main_node.story_part_hp["right"] = 2
	elif lvl == 4:
		main_node.story_part_hp["up"] = 2
		main_node.story_part_hp["left"] = 2

	_show_feature(3 + lvl, icon_s, title_s, desc_s)
	equalizer.bump(1.4)
	_punch_viewport()
	_flash_bg(Color(0.55, 0.15, 0.85, 1.0) if lvl == 3 else Color(0.85, 0.22, 0.35, 1.0))
	swipe_timer = 0.28


func _trigger_maestro_obliteration() -> void:
	_maestro_finisher_triggered = true
	for d: String in ["up", "down", "left", "right"]:
		main_node.story_part_hp[d] = 0
	main_node.story_boss_hp = 1
	main_node._story_l4_mirror_swipes = 0
	main_node._story_l4_turns_until_mirror = 10
	main_node.call("start_new_turn")
	var true_dir: String = str(main_node.get("_story_l4_true_dir"))
	if true_dir == "":
		true_dir = "up"
	_execute_swipe_with_visual(true_dir)
	_show_feature(8, "💥", "BOSS OBLITERATED!", "Conquer all 4 bosses to unlock exclusive skins, trails & Boss Rush!")
	equalizer.bump(2.0)
	_punch_viewport()
	_flash_bg(Color(1.0, 0.85, 0.25, 1.0))


func _start_themes_flash_showcase() -> void:
	_themes_arcade_started = true
	_maestro_finisher_triggered = false
	main_node.set("story_victory_animating", false)
	main_node.set("is_story_mode", false)
	main_node.set("is_boss_rush", false)
	var s: Node = main_node.get_node("Settings")
	s.selected_trail = "rainbow"
	s.selected_skin = "diamond"
	main_node.call("_start_game")
	main_node.call("_activate_frenzy_mode")
	_show_feature(8, "🎨", "5 NEON THEMES & GEAR", "Synthwave, Ocean, Ember, Forest & Midnight + Boss Cosmetics!")
	equalizer.bump(1.3)
	_punch_viewport()


func _process_arcade_bot_swipes(delta: float, interval: float) -> void:
	if not is_gameplay_started:
		return
	if main_node.get("state") != main_node.get("settings").GameState.PLAYING:
		return
	swipe_timer -= delta
	if swipe_timer <= 0.0:
		swipe_timer = interval
		var target_dir: String = str(main_node.get("current_target_direction"))
		if bool(main_node.get("is_frenzy_active")):
			var dirs: Array[String] = ["up", "right", "down", "left"]
			var frenzy_special: String = str(main_node.get("frenzy_special_dir"))
			target_dir = frenzy_special if (frenzy_special != "" and randf() < 0.65) else dirs[randi() % dirs.size()]
		elif target_dir == "":
			target_dir = "up"
		_execute_swipe_with_visual(target_dir)


func _process_story_bot_swipes(delta: float, interval: float) -> void:
	if main_node.get("state") != main_node.get("settings").GameState.PLAYING:
		return
	if bool(main_node.get("story_victory_animating")):
		return
	swipe_timer -= delta
	if swipe_timer > 0.0:
		return
	swipe_timer = interval

	var lvl: int = int(main_node.get("story_level"))
	var pick_dir: String = ""
	if lvl == 4:
		var seq: Array = main_node.get("_story_l4_sequence")
		var idx: int = int(main_node.get("_story_l4_seq_index"))
		if main_node.call("_are_all_boss_parts_destroyed"):
			pick_dir = str(main_node.get("_story_l4_true_dir"))
		elif seq != null and idx < seq.size():
			pick_dir = str(seq[idx])
		if int(main_node.get("_story_l4_mirror_swipes")) > 0 and pick_dir != "":
			pick_dir = str(main_node.call("_story_l4_opposite", pick_dir))
	else:
		var bombs: Array = main_node.get("story_bomb_dirs")
		var alive: Array = main_node.call("_get_alive_boss_parts")
		for d: String in alive:
			if not (d in bombs):
				pick_dir = d
				break
		if pick_dir == "":
			for d: String in ["up", "down", "left", "right"]:
				if not (d in bombs):
					pick_dir = d
					break

	if pick_dir == "":
		pick_dir = "up"
	_execute_swipe_with_visual(pick_dir)


func _execute_swipe_with_visual(dir: String) -> void:
	var center_p: Vector2 = _get_center_pos()
	var target_p: Vector2 = _get_square_pos(dir)
	if touch_indicator != null:
		touch_indicator.play_swipe(center_p, target_p, 0.13)
	main_node.call("_on_swipe", dir)
	if bool(main_node.get("is_frenzy_active")):
		main_node.score += 8500
	equalizer.bump(0.85)


func _process_theme_switches() -> void:
	var themes: Array[String] = ["ocean", "ember", "forest", "midnight", "synthwave"]
	var theme_phase: int = int((elapsed - 27.6) / 0.40)
	if theme_phase >= 0 and theme_phase < themes.size() and theme_phase != current_theme_idx:
		current_theme_idx = theme_phase
		var t_name: String = themes[theme_phase]
		main_node.call("_select_theme", t_name)
		main_node.call("_apply_theme")
		main_node.call("_apply_theme_bg_colors")
		equalizer.bump(1.0)


func _show_outro_cta() -> void:
	current_feature_idx = 9
	if feature_card != null:
		var t_fc := create_tween()
		t_fc.tween_property(feature_card, "modulate:a", 0.0, 0.25)
	if outro_overlay != null:
		outro_overlay.visible = true
		outro_overlay.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(outro_overlay, "modulate:a", 1.0, 0.45)

	var song_player: AudioStreamPlayer = main_node.get("_song_player")
	if song_player != null:
		var t_vol := create_tween()
		t_vol.tween_property(song_player, "volume_db", -36.0, 2.2)


func _show_feature(idx: int, icon_str: String, title_str: String, desc_str: String) -> void:
	current_feature_idx = idx
	if feature_card == null:
		return
	if feature_tween != null and feature_tween.is_valid():
		feature_tween.kill()

	feature_icon.text = icon_str
	feature_title.text = title_str
	feature_desc.text = desc_str

	feature_card.visible = true
	feature_card.scale = Vector2(0.88, 0.88)
	feature_card.modulate.a = 0.0

	feature_tween = create_tween()
	feature_tween.set_parallel(true)
	feature_tween.tween_property(feature_card, "modulate:a", 1.0, 0.28)
	feature_tween.tween_property(feature_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_hud_display() -> void:
	var in_story: bool = bool(main_node.get("is_story_mode"))
	if in_story:
		var lvl: int = int(main_node.get("story_level"))
		var boss_names := {1: "TITAN", 2: "HYDRA", 3: "SERAPH", 4: "MAESTRO"}
		if score_heading_label != null:
			score_heading_label.text = "ACTIVE BOSS"
		if live_score_label != null:
			live_score_label.text = str(boss_names.get(lvl, "BOSS"))
		if streak_heading_label != null:
			streak_heading_label.text = "BOSS PARTS"
		if live_streak_label != null:
			var parts_alive: int = main_node.call("_get_alive_boss_parts").size()
			live_streak_label.text = "%d / 4" % parts_alive
		if mult_heading_label != null:
			mult_heading_label.text = "MAIN HP"
		if live_mult_label != null:
			live_mult_label.text = "%d / %d" % [int(main_node.get("story_boss_hp")), int(main_node.get("story_boss_max_hp"))]
	else:
		if score_heading_label != null:
			score_heading_label.text = "LIVE SCORE"
		if live_score_label != null:
			live_score_label.text = "%d" % int(main_node.get("score"))
		if streak_heading_label != null:
			streak_heading_label.text = "STREAK"
		if live_streak_label != null:
			live_streak_label.text = "x%d" % int(main_node.get("streak"))
		if mult_heading_label != null:
			mult_heading_label.text = "MULTIPLIER"
		if live_mult_label != null:
			if bool(main_node.get("is_frenzy_active")):
				live_mult_label.text = "4X FRENZY!"
			else:
				live_mult_label.text = "%dX COMBO" % int(main_node.call("_current_combo_multiplier"))


func _get_center_pos() -> Vector2:
	var c_sq: Panel = main_node.get_node_or_null("GameScreen/Board/Center")
	if c_sq != null:
		return c_sq.position + c_sq.size / 2.0
	return Vector2(270, 480)


func _get_square_pos(dir: String) -> Vector2:
	var map: Dictionary = {
		"up": "GameScreen/Board/Up",
		"down": "GameScreen/Board/Down",
		"left": "GameScreen/Board/Left",
		"right": "GameScreen/Board/Right",
	}
	var path: String = map.get(dir, "")
	if path != "":
		var sq: Panel = main_node.get_node_or_null(path)
		if sq != null:
			return sq.position + sq.size / 2.0
	return Vector2(270, 480)
