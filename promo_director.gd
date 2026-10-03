extends Control
class_name PromoDirector

const PromoEqualizerScript = preload("res://promo_equalizer.gd")
const PromoTouchIndicatorScript = preload("res://promo_touch_indicator.gd")

@export var is_landscape: bool = true

# Timeline state
var elapsed: float = 0.0
var target_duration: float = 28.0

# References
@onready var main_node: Node = $SubViewportContainer/SubViewport/Main
@onready var bg_rect: ColorRect = $Background
@onready var feature_card: Panel = $FeatureCard
@onready var feature_icon: Label = $FeatureCard/IconLabel
@onready var feature_title: Label = $FeatureCard/TitleLabel
@onready var feature_desc: Label = $FeatureCard/DescLabel
@onready var equalizer: Control = $Equalizer
@onready var intro_overlay: Control = $IntroOverlay
@onready var outro_overlay: Control = $OutroOverlay
@onready var leaderboard_card: Control = $LeaderboardCard

# Left-side / HUD nodes (in landscape)
var live_score_label: Label = null
var live_streak_label: Label = null
var live_mult_label: Label = null

# Swiping & Bot state
var touch_indicator: Control = null
var swipe_timer: float = 0.0
var is_gameplay_started: bool = false
var is_scripted_hold_active: bool = false
var hold_end_time: float = 0.0
var current_feature_idx: int = -1
var feature_tween: Tween = null
var current_theme_idx: int = 0

# Orbitron font
var orbitron_font: FontFile = preload("res://fonts/Orbitron.ttf")

func _ready() -> void:
	# Find HUD labels if present
	if has_node("LeftPanel/ScoreValue"):
		live_score_label = get_node("LeftPanel/ScoreValue")
	if has_node("LeftPanel/StreakValue"):
		live_streak_label = get_node("LeftPanel/StreakValue")
	if has_node("LeftPanel/MultiplierValue"):
		live_mult_label = get_node("LeftPanel/MultiplierValue")
	elif has_node("TopHeader/ScoreValue"):
		live_score_label = get_node("TopHeader/ScoreValue")

	# Setup touch indicator inside Main scene
	touch_indicator = PromoTouchIndicatorScript.new()
	touch_indicator.name = "PromoTouchIndicator"
	main_node.add_child(touch_indicator)

	# Configure Main game settings for promo
	var s: Node = main_node.get_node("Settings")
	s.first_play = false
	s.selected_song = "battle"
	s.selected_theme = "synthwave"

	# Attach synthwave background shader
	var shader_p := "res://shaders/trailer_bg.gdshader"
	if bg_rect != null and ResourceLoader.exists(shader_p):
		var shader: Shader = load(shader_p)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("speed", 0.45)
		bg_rect.material = mat

	# Set initial overlays
	if intro_overlay != null:
		intro_overlay.modulate.a = 1.0
	if outro_overlay != null:
		outro_overlay.modulate.a = 0.0
		outro_overlay.visible = false
	if leaderboard_card != null:
		leaderboard_card.modulate.a = 0.0
		leaderboard_card.visible = false

	# Initial feature card hidden offscreen
	if feature_card != null:
		feature_card.modulate.a = 0.0

	# Hide tutorial if any
	if main_node.has_node("TutorialScreen"):
		main_node.get_node("TutorialScreen").visible = false

	print("[PromoDirector] Initialized promo recording. Mode landscape: ", is_landscape)

func _process(delta: float) -> void:
	elapsed += delta

	# Keep gameplay alive, streak active, and never trigger premature game-over
	if is_gameplay_started:
		main_node.lives = 3
		main_node.time_left_in_turn = 2.0
		main_node.frenzy_exit_buffer = 0.0
		main_node.hold_exit_buffer = 0.0
		if main_node.get("state") != main_node.get("settings").GameState.PLAYING:
			main_node.call("_start_game")

	# Update real-time HUD displays
	_update_hud_display()

	# ----------------------------------------------------
	# Storyboard Timeline
	# ----------------------------------------------------

	# [0.0s - 2.5s]: Intro Hook
	if elapsed < 2.5:
		if current_feature_idx != 0:
			_show_feature(0, "🎮", "LIGHTNING REFLEXES", "Match the neon target color & swipe before time expires!")

	# [2.5s]: Transition to gameplay
	elif elapsed >= 2.5 and not is_gameplay_started:
		is_gameplay_started = true
		_start_trailer_gameplay()

	# [2.5s - 9.2s]: Rapid gameplay combo build
	elif elapsed >= 2.5 and elapsed < 9.2:
		if current_feature_idx != 1 and elapsed >= 3.5:
			_show_feature(1, "🔥", "BUILD YOUR COMBO", "Chain perfect swipes to trigger massive score multipliers!")
		_process_bot_swipes(delta, 0.32)

	# [9.2s - 12.6s]: Hold & Charge mechanic showcase
	elif elapsed >= 9.2 and elapsed < 12.6:
		if current_feature_idx != 2:
			_show_feature(2, "⚡", "HOLD & CHARGE", "Press and hold glowing nodes for intense high-score bursts!")
		_process_hold_sequence()

	# [12.6s - 18.6s]: Frenzy Mode Climax
	elif elapsed >= 12.6 and elapsed < 18.6:
		if current_feature_idx != 3:
			_trigger_frenzy_climax()
		_process_bot_swipes(delta, 0.20)

	# [18.6s - 22.8s]: Custom Themes showcase
	elif elapsed >= 18.6 and elapsed < 22.8:
		if current_feature_idx != 4:
			_show_feature(4, "🎨", "NEON THEMES", "Unlock Synthwave, Ocean Teal, Ember Crimson & Midnight Violet!")
		_process_theme_switches()
		_process_bot_swipes(delta, 0.30)

	# [22.8s - 25.2s]: Global Leaderboard showcase
	elif elapsed >= 22.8 and elapsed < 25.2:
		if current_feature_idx != 5:
			_show_leaderboard_showcase()
		_process_bot_swipes(delta, 0.32)

	# [25.2s - 28.0s]: Outro Call to Action
	elif elapsed >= 25.2:
		if current_feature_idx != 6:
			_show_outro_cta()

	# End at 28.0s
	if elapsed >= target_duration:
		print("[PromoDirector] Finished promo video duration (28.0s). Exiting engine...")
		get_tree().quit()

func _start_trailer_gameplay() -> void:
	# Fade out intro overlay
	if intro_overlay != null:
		var t := create_tween()
		t.tween_property(intro_overlay, "modulate:a", 0.0, 0.45)
		t.tween_callback(func(): intro_overlay.visible = false)

	var s: Node = main_node.get_node("Settings")
	s.first_play = false
	main_node.set("_is_walkthrough_active", false)

	# Start game
	main_node.call("_start_game")
	equalizer.bump(1.0)

func _process_bot_swipes(delta: float, interval: float) -> void:
	if not is_gameplay_started or is_scripted_hold_active:
		return

	# If main is not in playing state, ensure it is playing
	if main_node.get("state") != main_node.get("settings").GameState.PLAYING:
		return

	# Handle hold turn automatically if generated naturally
	if bool(main_node.get("is_hold_turn")) and not is_scripted_hold_active:
		_process_hold_sequence()
		return

	swipe_timer -= delta
	if swipe_timer <= 0.0:
		swipe_timer = interval

		var target_dir: String = str(main_node.get("current_target_direction"))
		# If frenzy is active, swipe any valid direction or special dir
		if bool(main_node.get("is_frenzy_active")):
			var dirs: Array[String] = ["up", "right", "down", "left"]
			var frenzy_special: String = str(main_node.get("frenzy_special_dir"))
			if frenzy_special != "" and randf() < 0.6:
				target_dir = frenzy_special
			else:
				target_dir = dirs[randi() % dirs.size()]
		elif target_dir == "":
			target_dir = "up"

		_execute_swipe_with_visual(target_dir)

func _execute_swipe_with_visual(dir: String) -> void:
	var center_p: Vector2 = _get_center_pos()
	var target_p: Vector2 = _get_square_pos(dir)

	# Play animated touch gesture
	if touch_indicator != null:
		touch_indicator.play_swipe(center_p, target_p, 0.14)

	# Execute swipe on game logic
	main_node.call("_on_swipe", dir)

	# In Frenzy mode, accelerate score progression for trailer excitement
	if bool(main_node.get("is_frenzy_active")):
		main_node.score += 7500

	# Bump equalizer
	equalizer.bump(0.7)

func _process_hold_sequence() -> void:
	if not is_scripted_hold_active:
		is_scripted_hold_active = true
		hold_end_time = elapsed + 2.1

		var dir: String = str(main_node.get("current_target_direction"))
		if dir == "":
			dir = "up"

		# Trigger hold in game logic
		main_node.set("is_hold_turn", true)
		main_node.call("_start_hold_mode", dir)

		# Start touch indicator hold animation
		var center_p: Vector2 = _get_center_pos()
		if touch_indicator != null:
			touch_indicator.start_hold(center_p)

		equalizer.bump(0.8)
	else:
		# Keep charging hold
		if elapsed >= hold_end_time:
			is_scripted_hold_active = false
			# Finish hold
			main_node.call("_finish_hold_mode")
			if touch_indicator != null:
				touch_indicator.end_hold()
			equalizer.bump(1.4)
			swipe_timer = 0.35

func _trigger_frenzy_climax() -> void:
	current_feature_idx = 3
	_show_feature(3, "⚡", "⚡ FRENZY MODE ACTIVATED ⚡", "4X Multiplier! Electric lightning bursts & blazing speed!")

	# Activate frenzy in game
	main_node.call("_activate_frenzy_mode")
	equalizer.bump(1.5)

	# Visual flash on director background
	var t := create_tween()
	var orig_color: Color = bg_rect.color
	t.tween_property(bg_rect, "color", Color(0.9, 0.7, 0.1, 1.0), 0.08)
	t.tween_property(bg_rect, "color", orig_color, 0.25)

func _process_theme_switches() -> void:
	var themes: Array[String] = ["ocean", "ember", "midnight", "synthwave"]
	var theme_phase: int = int((elapsed - 18.6) / 1.0)
	if theme_phase >= 0 and theme_phase < themes.size() and theme_phase != current_theme_idx:
		current_theme_idx = theme_phase
		var t_name: String = themes[theme_phase]
		main_node.call("_select_theme", t_name)
		main_node.call("_apply_theme")
		main_node.call("_apply_theme_bg_colors")
		equalizer.bump(0.9)

func _show_leaderboard_showcase() -> void:
	current_feature_idx = 5
	_show_feature(5, "🏆", "GLOBAL LEADERBOARDS", "Compete worldwide on Google Play Games services!")
	if leaderboard_card != null:
		leaderboard_card.visible = true
		leaderboard_card.modulate.a = 0.0
		leaderboard_card.position.y += 40.0
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(leaderboard_card, "modulate:a", 1.0, 0.4)
		t.tween_property(leaderboard_card, "position:y", leaderboard_card.position.y - 40.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_outro_cta() -> void:
	current_feature_idx = 6
	if leaderboard_card != null and leaderboard_card.visible:
		var t_lb := create_tween()
		t_lb.tween_property(leaderboard_card, "modulate:a", 0.0, 0.3)
		t_lb.tween_callback(func(): leaderboard_card.visible = false)

	if feature_card != null:
		var t_fc := create_tween()
		t_fc.tween_property(feature_card, "modulate:a", 0.0, 0.3)

	if outro_overlay != null:
		outro_overlay.visible = true
		outro_overlay.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(outro_overlay, "modulate:a", 1.0, 0.5)

	# Fade music volume gently toward end
	var song_player: AudioStreamPlayer = main_node.get("_song_player")
	if song_player != null:
		var t_vol := create_tween()
		t_vol.tween_property(song_player, "volume_db", -36.0, 2.5)

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
	feature_card.scale = Vector2(0.9, 0.9)
	feature_card.modulate.a = 0.0

	feature_tween = create_tween()
	feature_tween.set_parallel(true)
	feature_tween.tween_property(feature_card, "modulate:a", 1.0, 0.35)
	feature_tween.tween_property(feature_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_hud_display() -> void:
	if live_score_label != null:
		var sc: int = int(main_node.get("score"))
		live_score_label.text = "%d" % sc
	if live_streak_label != null:
		var st: int = int(main_node.get("streak"))
		live_streak_label.text = "x%d" % st
	if live_mult_label != null:
		var is_frenzy: bool = bool(main_node.get("is_frenzy_active"))
		if is_frenzy:
			live_mult_label.text = "4X FRENZY!"
		else:
			var mult: int = int(main_node.call("_current_combo_multiplier"))
			live_mult_label.text = "%dX COMBO" % mult

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
