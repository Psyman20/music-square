extends Control

# --- Dependencies ---
@onready var settings: Node = $Settings
@onready var sfx: Node = $SoundManager

# --- Screens ---
@onready var menu_screen: Control = $MenuScreen
@onready var game_screen: Control = $GameScreen
@onready var pause_screen: Control = $PauseScreen
@onready var game_over_screen: Control = $GameOverScreen
@onready var tutorial_screen: Control = $TutorialScreen
@onready var transition_overlay: ColorRect = $TransitionOverlay

# --- Menu Nodes ---
@onready var start_button: Button = $MenuScreen/StartButton

# --- Game HUD ---
@onready var score_label: Label = $GameScreen/GameHUD/ScoreLabel
@onready var high_score_label: Label = $GameScreen/GameHUD/HighScoreLabel
@onready var pause_button: Button = $GameScreen/GameHUD/PauseButton
@onready var hearts: Array[Panel] = [
	$GameScreen/GameHUD/LivesContainer/Heart1,
	$GameScreen/GameHUD/LivesContainer/Heart2,
	$GameScreen/GameHUD/LivesContainer/Heart3,
]

# --- Game Board ---
@onready var center_square: Panel = $GameScreen/Board/Center
@onready var up_square: Panel = $GameScreen/Board/Up
@onready var down_square: Panel = $GameScreen/Board/Down
@onready var left_square: Panel = $GameScreen/Board/Left
@onready var right_square: Panel = $GameScreen/Board/Right
@onready var floating_container: Control = $GameScreen/FloatingTextContainer

# --- Pause Nodes ---
@onready var resume_btn: Button = $PauseScreen/PausePanel/ResumeBtn
@onready var restart_btn: Button = $PauseScreen/PausePanel/RestartBtn
@onready var pause_menu_btn: Button = $PauseScreen/PausePanel/MenuBtn

# --- Game Over Nodes ---
@onready var final_score_label: Label = $GameOverScreen/GameOverPanel/FinalScoreLabel
@onready var new_record_badge: Label = $GameOverScreen/GameOverPanel/NewRecordBadge
@onready var go_high_score: Label = $GameOverScreen/GameOverPanel/GameOverHighScore
@onready var stats_label: Label = $GameOverScreen/GameOverPanel/StatsLabel
@onready var revive_btn: Button = $GameOverScreen/GameOverPanel/ReviveBtn
@onready var retry_btn: Button = $GameOverScreen/GameOverPanel/RetryBtn
@onready var leaderboard_btn: Button = $GameOverScreen/GameOverPanel/LeaderboardBtn
@onready var share_score_btn: Button = $GameOverScreen/GameOverPanel/ShareScoreBtn
@onready var rate_app_btn: Button = $GameOverScreen/GameOverPanel/RateAppBtn
@onready var go_menu_btn: Button = $GameOverScreen/GameOverPanel/GameOverMenuBtn

# --- Tutorial Nodes ---
@onready var tutorial_understood_btn: Button = $TutorialScreen/TutorialPanel/TutorialUnderstoodBtn

const CURRENT_VERSION_NAME: String = "1.2.0"
const CURRENT_VERSION_CODE: int = 13

# --- Game State ---
var state: GameSettings.GameState = GameSettings.GameState.MENU
# --- In-Memory Anti-Cheat & Score Security ---
var _score_val: int = 0
var _score_mask: int = 0x4D2C9B8A
var _score_checksum: int = 0
var _decoy_score: int = 0  # HoneyPot: attracts GameGuardian memory scanners
var _tamper_flagged: bool = false

var score: int:
	get:
		return _get_secure_score()
	set(val):
		_set_secure_score(val)
var lives: int = GameSettings.MAX_LIVES
var streak: int = 0
var best_streak_this_game: int = 0
var total_correct: int = 0
var total_swipes: int = 0
var current_target_direction: String = ""
var current_time_limit: float = GameSettings.INITIAL_TIME_LIMIT
var time_left_in_turn: float = GameSettings.INITIAL_TIME_LIMIT
var turns_since_remap: int = 0
# Turns to wait before the next remap — re-rolled after every remap.
var turns_until_remap: int = randi_range(GameSettings.REMAP_INTERVAL_TURNS_MIN, GameSettings.REMAP_INTERVAL_TURNS_MAX)
var _center_scale_locked := false
var _last_target_color: Color = Color(0, 0, 0, 0)
var _has_revived_this_game: bool = false
var _revive_ready_to_resume: bool = false

# --- Floating text labels that persist until the next swipe ---
var _persistent_labels: Array[Label]
# --- Tween tracking ---
var _center_flash_tween: Tween
var _score_bounce_tween: Tween

# --- Juice / visual FX ---
var _ui_theme: Theme
var _base_font: FontFile
var _bg_shader_mat: ShaderMaterial
var _hit_particles: GPUParticles2D
var _ambient_particles: GPUParticles2D
var _particle_dot_tex: ImageTexture

# --- Visual Polish & Juice Overhaul ---
var _audio_pulse: float = 0.0
var _swipe_trail: Control = null
var _trail_points: Array[Dictionary] = [] # Array of {"pos": Vector2, "time": float}
const TRAIL_LIFETIME: float = 0.26
var _board_aura_panel: Control = null
var _board_aura_tier: int = 0 # 0=none, 1=50+ (Electric Cyan), 2=100+ (Blazing Flame), 3=200+ (Mythic Corona)
var _board_aura_time: float = 0.0
var _board_aura_particle_timer: float = 0.0

# --- Detailed Run Breakdown Stats ---
var fastest_reaction_this_game: float = 999.0
var frenzies_triggered_this_game: int = 0
var longest_hold_this_game: float = 0.0
var _turn_start_time: float = 0.0

# --- Input State ---
var touch_start_position := Vector2.ZERO
var is_swiping := false
var active_touch_index := -1

# --- Directions map ---
var direction_squares: Dictionary = {}
var direction_colors: Dictionary = {}

# --- StyleBox for rounded panels ---
var _panel_style: StyleBoxFlat
var _center_panel_style: StyleBoxFlat
var _pause_panel_style: StyleBoxFlat
var _btn_style: StyleBoxFlat
var _menu_btn_style: StyleBoxFlat
var _menu_btn_hover_style: StyleBoxFlat
var _play_btn_style: StyleBoxFlat
var _play_btn_hover_style: StyleBoxFlat
var _story_btn_style: StyleBoxFlat
var _story_btn_hover_style: StyleBoxFlat
var _leaderboard_btn_style: StyleBoxFlat
var _leaderboard_btn_hover_style: StyleBoxFlat
var _dir_square_styles: Dictionary = {}
var _center_live_style: StyleBoxFlat = null
var _combo_bar_fill_style: StyleBoxFlat = null
var _fever_bar_fill_style: StyleBoxFlat = null
var _last_displayed_lives: int = GameSettings.MAX_LIVES
var _heart_throb_tween: Tween
var _lives_bezel_style: StyleBoxFlat
var _song_player: AudioStreamPlayer
var _song_cache: Dictionary = {}
var _unit_heart_pts: PackedVector2Array = PackedVector2Array()
var _last_shader_audio_pulse: float = -1.0
var _last_shader_streak_energy: float = -1.0

# --- Songs / Unlocks UI ---
var _songs_button: Button
var _songs_screen: Control
var _songs_list: VBoxContainer
var _songs_best_label: Label
var _songs_scroll: ScrollContainer

# --- Themes / Unlocks UI ---
var _themes_button: Button
var _themes_screen: Control
var _themes_list: VBoxContainer
var _themes_best_label: Label
var _themes_scroll: ScrollContainer
var _lives_frame: Panel

# --- Options UI ---
var _options_button: Button
var _options_screen: Control
var _options_panel: Panel
var _options_backdrop: ColorRect
var _options_non_zone_controls: Array[Control] = []
var _board_zone_preview_active: bool = false
var _board_zone_preview_timer: float = 0.0
var _board_zone_dragging: bool = false
var _board_zone_preview_tween: Tween
var _music_volume_slider: HSlider
var _music_volume_label: Label
var _board_offset_slider: HSlider
var _board_offset_label: Label
var _haptics_toggle_btn: Button
var _announcer_toggle_btn: Button
var _reset_game_btn: Button
var _reset_confirm_modal: Control
var _tutorial_return_state: GameSettings.GameState = GameSettings.GameState.PLAYING

# --- Dynamic Interactive Walkthrough State ---
const WalkthroughOverlayScript = preload("res://walkthrough_overlay.gd")
var _is_walkthrough_active: bool = false
var _walkthrough_step: int = 0
var _walkthrough_overlay: Control = null
var _walkthrough_frenzy_swipes_done: int = 0
var _walkthrough_advancing: bool = false
var _walkthrough_from_options: bool = false
var _center_squash_tween: Tween = null

# --- Overlay panel drag-scroll state ---
var _overlay_drag_active: bool = false
var _overlay_drag_start_y: float = 0.0
var _overlay_drag_scroll_start: int = 0
var _overlay_drag_is_song: bool = true  # true = songs panel, false = themes panel
const _OVERLAY_TAP_THRESHOLD: float = 8.0  # pixels — below this = tap, above = drag

# --- Power-Up & Frenzy Mode State ---
var powerup_square_dir: String = ""
var powerup_type: String = ""
var is_frenzy_active: bool = false
var frenzy_time_left: float = 0.0
var frenzy_exit_buffer: float = 0.0
var frenzy_special_dir: String = ""
var frenzy_switch_timer: float = 0.0
const FRENZY_SPECIAL_COLOR := Color(1.8, 0.2, 0.85)
var _frenzy_hud_label: Label
var frenzy_charges: int = 0
var _frenzy_charge_label: Label

# --- Overdrive Fever, Timing Chain, Shield & Double-Dash State ---
var fever_meter: float = 0.0
var _fever_bar: ProgressBar = null
var _fever_label: Label = null
var perfect_streak: int = 0
var best_perfect_streak_this_game: int = 0
var has_shield: bool = false
var _shield_hud_label: Label = null
var is_double_turn: bool = false
var double_turn_step: int = 0
var _double_indicator_label: Label = null
var sparks_collected_in_run: int = 0

# --- Combo Multiplier HUD ---
var _combo_container: HBoxContainer
var _combo_label: Label
var _combo_bar: ProgressBar

# --- Achievement Tracking ---
var _frenzy_count_this_game: int = 0
var _fast_swipes_this_game: int = 0
var _remaps_survived_this_game: int = 0
var _lost_heart_this_game: bool = false
var _hold_squares_completed_this_game: int = 0
var _clutch_swipes_this_game: int = 0
var _frenzies_at_max_multiplier: int = 0
var _achievement_toast_queue: Array[Dictionary] = []
var _is_showing_achievement_toast: bool = false
var _high_score_at_run_start: int = 0
var _beaten_high_score_this_run: bool = false
var _unlocked_songs_this_run: Dictionary = {}
var _music_duck_tween: Tween = null

# --- Hold Mechanic State ---
const MAX_HOLD_DURATION := 2.0
var is_hold_turn: bool = false
var is_holding_active: bool = false
var hold_duration: float = 0.0
var _hold_hud_container: Control = null
var _hold_progress_bar: ProgressBar = null
var _hold_pts_label: Label = null
var _hold_indicator_label: Label = null
var _hold_haptic_timer: float = 0.0
var _hold_particle_timer: float = 0.0
var hold_exit_buffer: float = 0.0

# --- Badges UI ---
var _badges_button: Button
var _badges_screen: Control
var _badges_list: VBoxContainer
var _badges_scroll: ScrollContainer

# --- Leaderboard UI ---
var _leaderboard_button: Button

# --- Neon Sparks & Cosmetic Shop / Daily Missions UI ---
var _shop_button: Button
var _menu_sparks_btn: Button
var _menu_sparks_label: Label
var _shop_screen: Control
var _shop_title_label: Label
var _shop_sparks_icon: Control
var _shop_sparks_label: Label
var _shop_tab_buttons: Dictionary = {}
var _shop_active_tab: String = "missions"
var _shop_scroll: ScrollContainer
var _shop_list: VBoxContainer
var _overlay_drag_is_shop: bool = false
var _shop_scrollbar_dragging: bool = false
var _overlay_drag_start_x: float = 0.0
var _mission_run_credited_score: int = 0
var _mission_run_credited_swipes: int = 0
var _mission_run_credited_frenzies: int = 0
var _mission_run_credited_holds: int = 0
var _mission_run_credited_fast: int = 0
var _mission_run_game_counted: bool = false
var _bonus_mission_ad_loading: bool = false
var _go_sparks_label: Label
var _go_double_sparks_btn: Button
var _go_shop_btn: Button

# --- Google Play Update UI ---
var _update_modal: Control
var _update_panel: Panel
var _update_version_badge: Label
var _update_desc_label: Label
var _update_notes_scroll: ScrollContainer
var _update_notes_label: Label
var _update_now_btn: Button
var _update_later_btn: Button
var _pending_update_info: Dictionary = {}
var _has_prompted_update: bool = false

# --- Story Mode & Boss Fight State ---
var _story_button: Button
var _story_screen: Control
var _story_level1_status_label: Label
var _story_level1_preview_ctrl: Control
var _story_level2_status_label: Label
var _story_level2_preview_ctrl: Control
var _story_level2_fight_btn: Button
var _story_level3_status_label: Label
var _story_level3_preview_ctrl: Control
var _story_level3_fight_btn: Button
var _story_last_swiped_dir: String = ""
# --- Level 4 (Phantom Maestro): Melody Sequences, Mirror Curse & Masquerade ---
var _story_level4_status_label: Label
var _story_level4_preview_ctrl: Control
var _story_level4_fight_btn: Button
var _story_l4_sequence: Array[String] = []
var _story_l4_seq_index: int = 0
var _story_l4_mirror_swipes: int = 0
var _story_l4_mirror_pending: bool = false
var _story_l4_turns_until_mirror: int = 4
var _story_l4_true_dir: String = ""
var _story_l4_reveal_left: float = 0.0
var is_story_mode: bool = false
var story_level: int = 1
var story_boss_max_hp: int = 15
var story_boss_hp: int = 15
var story_boss_ghost_hp: float = 15.0
var story_part_max_hp: int = 5
var story_part_hp: Dictionary = {"up": 5, "down": 5, "left": 5, "right": 5}
var story_bomb_dir: String = ""
var story_bomb_dirs: Array[String] = []
var story_boss_enraged: bool = false
var story_victory_animating: bool = false
var story_level_won: bool = false
var _story_boss_hud: Control = null
var _story_boss_name_label: Label = null
var _story_boss_hp_label: Label = null
var _story_boss_canvas: Control = null
var _boss_anim_time: float = 0.0
var _boss_hit_shake: float = 0.0
var _boss_taunt_anim: float = 0.0
var _boss_throw_anim: float = 0.0
var _boss_throw_target_dir: String = ""
var _boss_throw_target_dirs: Array[String] = []
var _boss_death_progress: float = 0.0
var _boss_part_flash: Dictionary = {"up": 0.0, "down": 0.0, "left": 0.0, "right": 0.0}
var _boss_part_recoil: Dictionary = {"up": 0.0, "down": 0.0, "left": 0.0, "right": 0.0}
var _boss_laser_beams: Array[Dictionary] = []
var _boss_explosion_shrapnel: Array[Dictionary] = []
var _boss_explosion_rings: Array[Dictionary] = []


func _ready() -> void:
	_init_secure_score()
	_precompute_unit_heart()
	direction_squares = {
		"up": up_square, "down": down_square,
		"left": left_square, "right": right_square,
	}
	for dir: String in direction_squares:
		direction_squares[dir].set_meta("dir", dir)
	center_square.set_meta("dir", "")
	direction_colors = _get_theme().get("board", {}).duplicate()

	# Sync persisted hit sound pack & announcer voice toggle
	if sfx != null:
		if "active_pack" in sfx:
			sfx.active_pack = settings.selected_sfx_pack
		if "announcer_enabled" in sfx:
			sfx.announcer_enabled = settings.announcer_enabled

	# Create shared styleboxes
	_create_styles()

	# Apply styles to game squares
	_apply_board_styles()
	_apply_board_position()
	_setup_board_symbols()

	# Apply styles to panels
	_apply_panel_styles()

	# Setup button styles
	_setup_button_styles()

	# Connect button signals
	_connect_signals()

	# Background song player (selected unlockable track, looped).
	_setup_song_player()

	# Neon/synthwave visual overhaul: font theme, background shader, glow,
	# ambient particles. Built in code so the .tscn stays untouched.
	_setup_juice()

	# Story Mode UI (STORY MODE button + Level Select overlay + Boss Arena HUD).
	_setup_story_ui()
	_setup_story_boss_arena()

	# Songs / unlocks UI (SONGS button + selection screen).
	_setup_songs_ui()

	# Themes / unlocks UI (THEMES button + selection screen).
	_setup_themes_ui()

	# Cosmetic Shop UI (SHOP button + Neon Sparks balance + Trails/Skins/Sounds shop).
	_setup_shop_ui()

	# Options UI (OPTIONS button + options overlay screen).
	_setup_options_ui()

	# Badges / Achievements UI (BADGES button + overlay screen).
	_setup_badges_ui()

	# Leaderboard UI (LEADERBOARD button on menu).
	_setup_leaderboard_ui()

	# Compact menu button spacing so all 8 buttons fit cleanly and scale across devices
	_layout_menu_buttons()
	if not resized.is_connected(_layout_menu_buttons):
		resized.connect(_layout_menu_buttons)
	if menu_screen != null and not menu_screen.resized.is_connected(_layout_menu_buttons):
		menu_screen.resized.connect(_layout_menu_buttons)

	# Sync existing high score to leaderboard if returning player has a previous record
	if not _tamper_flagged and settings != null and settings.high_score > 0:
		if has_node("/root/LeaderboardManager"):
			get_node("/root/LeaderboardManager").submit_score(settings.high_score)

	# Tutorial visual UI setup
	_setup_tutorial_ui()

	# Google Play store update check UI
	_setup_update_ui()

	# Show menu
	_show_menu()

	# Setup initial state
	_setup_initial_game_state()

	# Check for Google Play updates
	if has_node("/root/UpdateManager"):
		get_node("/root/UpdateManager").update_available.connect(_on_update_available)
		get_node("/root/UpdateManager").check_for_updates()


func _exit_tree() -> void:
	if _song_player != null and is_instance_valid(_song_player):
		_song_player.stop()
		_song_player.stream = null
	_song_cache.clear()


func _precompute_unit_heart() -> void:
	var num_pts := 32
	_unit_heart_pts.resize(num_pts)
	for k in range(num_pts):
		var t := (float(k) / float(num_pts)) * TAU
		var hx := 16.0 * pow(sin(t), 3)
		var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		_unit_heart_pts[k] = Vector2(hx / 16.0, (hy - 4.5) / 16.0)


func _get_theme() -> Dictionary:
	for th: Dictionary in settings.THEMES:
		if str(th.get("id", "")) == settings.selected_theme:
			return th
	return settings.THEMES[0] if settings.THEMES.size() > 0 else {}


func _theme_accent() -> Color:
	return _get_theme().get("accent", Color(1, 1, 1))


func _theme_accent2() -> Color:
	return _get_theme().get("accent2", Color(1.2, 0.25, 0.6))


func _apply_theme_bg_colors() -> void:
	var th: Dictionary = _get_theme()
	var bg: Dictionary = th.get("bg", {})
	if _bg_shader_mat != null:
		for key: String in bg:
			_bg_shader_mat.set_shader_parameter(key, bg[key])
	if _ambient_particles != null and is_instance_valid(_ambient_particles):
		var amat := _ambient_particles.process_material as ParticleProcessMaterial
		if amat != null:
			var sun_c: Color = bg.get("sun_color", th.get("accent", Color(1.0, 0.6, 0.95)))
			amat.color = Color(sun_c.r, sun_c.g, sun_c.b, 0.62)


func _create_styles() -> void:
	# Rounded panel style for game squares — neon border + soft glow shadow
	_panel_style = StyleBoxFlat.new()
	_panel_style.set_corner_radius_all(18)
	_panel_style.set_border_width_all(3)
	_panel_style.set_shadow_size(10)

	# Center panel style — bright border glow
	_center_panel_style = StyleBoxFlat.new()
	_center_panel_style.set_corner_radius_all(20)
	_center_panel_style.set_border_width_all(4)
	_center_panel_style.set_shadow_size(14)

	# Pause / Game Over panel
	_pause_panel_style = StyleBoxFlat.new()
	_pause_panel_style.set_corner_radius_all(24)
	_pause_panel_style.bg_color = Color(0.2, 0.18, 0.3, 0.95)
	_pause_panel_style.set_border_width_all(2)

	# Button style — neon tube: visible glass fill + glowing border
	_btn_style = StyleBoxFlat.new()
	_btn_style.set_corner_radius_all(16)
	_btn_style.bg_color = Color(0.12, 0.09, 0.22, 0.85)
	_btn_style.set_border_width_all(2)
	_btn_style.set_shadow_size(6)

	# Uniform rounded Menu Button style (Missions, Songs, Themes, Shop, Badges, Options)
	_menu_btn_style = StyleBoxFlat.new()
	_menu_btn_style.set_corner_radius_all(16)
	_menu_btn_style.bg_color = Color(1.0, 0.278, 0.341, 0.25)
	_menu_btn_style.set_border_width_all(2)
	_menu_btn_style.set_border_color(Color(1.0, 0.38, 0.46, 0.55))
	_menu_btn_style.set_shadow_color(Color(1.0, 0.278, 0.341, 0.20))
	_menu_btn_style.set_shadow_size(6)

	_menu_btn_hover_style = StyleBoxFlat.new()
	_menu_btn_hover_style.set_corner_radius_all(16)
	_menu_btn_hover_style.bg_color = Color(1.0, 0.278, 0.341, 0.38)
	_menu_btn_hover_style.set_border_width_all(2)
	_menu_btn_hover_style.set_border_color(Color(1.0, 0.65, 0.72, 0.92))
	_menu_btn_hover_style.set_shadow_color(Color(1.0, 0.278, 0.341, 0.42))
	_menu_btn_hover_style.set_shadow_size(10)

	# Rounded Arcade Mode Button style (vibrant electric cyan-blue, distinct from pink menu buttons)
	_play_btn_style = StyleBoxFlat.new()
	_play_btn_style.set_corner_radius_all(16)
	_play_btn_style.bg_color = Color(0.06, 0.58, 0.88, 0.90)
	_play_btn_style.set_border_width_all(2)
	_play_btn_style.set_border_color(Color(0.42, 0.96, 1.0, 0.95))
	_play_btn_style.set_shadow_color(Color(0.08, 0.72, 1.0, 0.52))
	_play_btn_style.set_shadow_size(8)

	_play_btn_hover_style = StyleBoxFlat.new()
	_play_btn_hover_style.set_corner_radius_all(16)
	_play_btn_hover_style.bg_color = Color(0.12, 0.70, 0.96, 0.96)
	_play_btn_hover_style.set_border_width_all(2)
	_play_btn_hover_style.set_border_color(Color(0.75, 0.99, 1.0, 1.0))
	_play_btn_hover_style.set_shadow_color(Color(0.15, 0.85, 1.0, 0.70))
	_play_btn_hover_style.set_shadow_size(12)

	# Rounded Story Mode Button style (vibrant royal violet-gold)
	_story_btn_style = StyleBoxFlat.new()
	_story_btn_style.set_corner_radius_all(16)
	_story_btn_style.bg_color = Color(0.52, 0.14, 0.88, 0.90)
	_story_btn_style.set_border_width_all(2)
	_story_btn_style.set_border_color(Color(1.0, 0.85, 0.32, 0.95))
	_story_btn_style.set_shadow_color(Color(0.58, 0.18, 0.96, 0.52))
	_story_btn_style.set_shadow_size(8)

	_story_btn_hover_style = StyleBoxFlat.new()
	_story_btn_hover_style.set_corner_radius_all(16)
	_story_btn_hover_style.bg_color = Color(0.62, 0.22, 0.96, 0.96)
	_story_btn_hover_style.set_border_width_all(2)
	_story_btn_hover_style.set_border_color(Color(1.0, 0.94, 0.55, 1.0))
	_story_btn_hover_style.set_shadow_color(Color(1.0, 0.82, 0.30, 0.68))
	_story_btn_hover_style.set_shadow_size(12)

	# Rounded Leaderboard Button style
	_leaderboard_btn_style = StyleBoxFlat.new()
	_leaderboard_btn_style.set_corner_radius_all(16)
	_leaderboard_btn_style.bg_color = Color(0.18, 0.80, 0.44, 0.24)
	_leaderboard_btn_style.set_border_width_all(2)
	_leaderboard_btn_style.set_border_color(Color(0.25, 0.90, 0.52, 0.55))
	_leaderboard_btn_style.set_shadow_color(Color(0.18, 0.80, 0.44, 0.20))
	_leaderboard_btn_style.set_shadow_size(6)

	_leaderboard_btn_hover_style = StyleBoxFlat.new()
	_leaderboard_btn_hover_style.set_corner_radius_all(16)
	_leaderboard_btn_hover_style.bg_color = Color(0.18, 0.80, 0.44, 0.36)
	_leaderboard_btn_hover_style.set_border_width_all(2)
	_leaderboard_btn_hover_style.set_border_color(Color(0.45, 1.0, 0.68, 0.92))
	_leaderboard_btn_hover_style.set_shadow_color(Color(0.18, 0.80, 0.44, 0.42))
	_leaderboard_btn_hover_style.set_shadow_size(10)

	_apply_style_colors()

	# Pre-allocate persistent styleboxes for each board square to avoid per-turn allocations
	_dir_square_styles.clear()
	for dir: String in direction_squares:
		var d_style := _panel_style.duplicate() as StyleBoxFlat
		_dir_square_styles[dir] = d_style
		var p: Panel = direction_squares[dir]
		if p != null:
			p.add_theme_stylebox_override("panel", d_style)
	_center_live_style = _center_panel_style.duplicate() as StyleBoxFlat
	if center_square != null:
		center_square.add_theme_stylebox_override("panel", _center_live_style)


func _reset_dir_square_style(style: StyleBoxFlat) -> void:
	style.set_border_width_all(3)
	style.set_border_color(_panel_style.border_color)
	style.set_shadow_color(_panel_style.shadow_color)
	style.set_shadow_size(10)


func _reset_center_square_style(style: StyleBoxFlat) -> void:
	style.set_border_width_all(4)
	style.set_border_color(_center_panel_style.border_color)
	style.set_shadow_color(_center_panel_style.shadow_color)
	style.set_shadow_size(14)


func _apply_style_colors() -> void:
	# Mutate the shared styleboxes IN PLACE so every node holding a reference
	# (scene buttons, menu SONGS/THEMES buttons, overlay BACK buttons, panels)
	# picks up a theme change automatically.
	var accent := _theme_accent()
	_panel_style.set_border_color(Color(accent.r, accent.g, accent.b, 0.45))
	_panel_style.set_shadow_color(Color(accent.r, accent.g, accent.b, 0.18))
	_center_panel_style.set_border_color(Color(accent.r, accent.g, accent.b, 0.85))
	_center_panel_style.set_shadow_color(Color(accent.r, accent.g, accent.b, 0.35))
	_pause_panel_style.set_border_color(Color(accent.r, accent.g, accent.b, 0.1))
	_btn_style.set_border_color(Color(accent.r, accent.g, accent.b, 0.5))
	_btn_style.set_shadow_color(Color(accent.r, accent.g, accent.b, 0.25))


func _apply_board_styles() -> void:
	_apply_board_colors()

	if _center_live_style != null:
		_center_live_style.bg_color = direction_colors["up"]
		center_square.add_theme_stylebox_override("panel", _center_live_style)
	center_square.pivot_offset = Vector2(50, 50)

	for dir: String in direction_squares:
		var p: Panel = direction_squares[dir]
		if p != null and is_instance_valid(p):
			p.pivot_offset = p.size / 2.0
			if _dir_square_styles.has(dir):
				p.add_theme_stylebox_override("panel", _dir_square_styles[dir])

	# Center pivot for the board container so remap pop animates from its center
	var board: Control = $GameScreen/Board
	board.pivot_offset = center_square.position + center_square.size / 2.0


func _get_hud_mid_zone_y() -> float:
	var combo_bottom: float = 158.0
	if _combo_container != null and is_instance_valid(_combo_container):
		combo_bottom = _combo_container.offset_bottom
	var board_top: float = 320.0 + settings.board_vertical_offset
	return (combo_bottom + board_top) / 2.0


func _apply_board_position() -> void:
	var offset: float = settings.board_vertical_offset
	var board: Control = $GameScreen/Board
	if board != null and is_instance_valid(board):
		board.offset_top = -160.0 + offset
		board.offset_bottom = 160.0 + offset

	# When player shifts screen zone UP, smoothly shift top HUD slightly
	# so Combo Bar, Hold Bar, Frenzy HUD, and Board maintain generous margins.
	var up_ratio: float = clampf(-offset / 100.0, 0.0, 1.0) if offset < 0.0 else 0.0
	var hud_up_shift: float = up_ratio * 26.0

	if score_label != null and is_instance_valid(score_label):
		score_label.offset_top = 66.0 - hud_up_shift
		score_label.offset_bottom = 124.0 - hud_up_shift

	if _combo_container != null and is_instance_valid(_combo_container):
		_combo_container.offset_top = 130.0 - hud_up_shift
		_combo_container.offset_bottom = 158.0 - hud_up_shift

	# Re-center any active in-game mid-zone banners or HUD indicators
	var mid_y: float = _get_hud_mid_zone_y()

	if _hold_indicator_label != null and is_instance_valid(_hold_indicator_label):
		_hold_indicator_label.offset_top = mid_y - 15.0
		_hold_indicator_label.offset_bottom = mid_y + 15.0

	if _hold_hud_container != null and is_instance_valid(_hold_hud_container):
		_hold_hud_container.offset_top = mid_y - 28.0
		_hold_hud_container.offset_bottom = mid_y + 28.0

	if _frenzy_hud_label != null and is_instance_valid(_frenzy_hud_label):
		_frenzy_hud_label.offset_top = mid_y - 17.0
		_frenzy_hud_label.offset_bottom = mid_y + 17.0

	if _double_indicator_label != null and is_instance_valid(_double_indicator_label):
		_double_indicator_label.offset_top = mid_y - 16.0
		_double_indicator_label.offset_bottom = mid_y + 16.0

	if _story_boss_canvas != null and is_instance_valid(_story_boss_canvas):
		var boss_bottom: float = clampf(418.0 + minf(0.0, offset * 0.85), 330.0, 425.0)
		_story_boss_canvas.offset_bottom = boss_bottom


func _apply_skin_to_square_style(style: StyleBoxFlat, col: Color, is_center: bool = false) -> void:
	var skin_id: String = settings.selected_skin if settings != null else "classic"
	if skin_id == "wireframe":
		# Dark-glass core with bright glowing neon border
		style.bg_color = Color(col.r * 0.24, col.g * 0.24, col.b * 0.30, 0.94)
		style.set_border_width_all(4 if is_center else 3)
		style.set_border_color(Color(minf(1.5, col.r * 1.35 + 0.15), minf(1.5, col.g * 1.35 + 0.15), minf(1.5, col.b * 1.35 + 0.15), 0.98))
		style.set_shadow_color(Color(col.r, col.g, col.b, 0.65))
		style.set_shadow_size(16 if is_center else 13)
	else:
		style.bg_color = col


func _apply_board_colors() -> void:
	var frenzy_gold := Color(1.35, 1.15, 0.15)

	for dir: String in direction_squares:
		var panel: Panel = direction_squares[dir]
		var style: StyleBoxFlat = _dir_square_styles.get(dir)
		if style == null:
			style = _panel_style.duplicate() as StyleBoxFlat
			_dir_square_styles[dir] = style
			panel.add_theme_stylebox_override("panel", style)
		elif panel.get_theme_stylebox("panel") != style:
			panel.add_theme_stylebox_override("panel", style)
		_reset_dir_square_style(style)
		if is_frenzy_active:
			if dir == frenzy_special_dir:
				style.bg_color = FRENZY_SPECIAL_COLOR
				style.set_border_width_all(4)
				style.set_border_color(Color(2.0, 0.7, 1.3, 0.95))
				style.set_shadow_color(Color(1.8, 0.2, 0.85, 0.75))
				style.set_shadow_size(22)
			else:
				style.bg_color = frenzy_gold
				style.set_border_color(Color(1.5, 1.3, 0.3, 0.9))
				style.set_shadow_color(Color(1.2, 0.9, 0.1, 0.5))
		elif dir == powerup_square_dir and powerup_type != "":
			if powerup_type == "frenzy_boost":
				style.bg_color = Color(0.06, 0.14, 0.24, 0.92)
				style.set_border_width_all(3)
				style.set_border_color(Color(0.2, 0.95, 1.0, 0.95))
				style.set_shadow_color(Color(0.1, 0.8, 1.0, 0.6))
				style.set_shadow_size(14)
			elif powerup_type == "shield":
				style.bg_color = Color(0.05, 0.18, 0.16, 0.94)
				style.set_border_width_all(3)
				style.set_border_color(Color(0.18, 1.0, 0.72, 0.98))
				style.set_shadow_color(Color(0.12, 0.95, 0.65, 0.65))
				style.set_shadow_size(15)
			elif powerup_type == "spark_jackpot":
				style.bg_color = Color(0.22, 0.14, 0.04, 0.94)
				style.set_border_width_all(3)
				style.set_border_color(Color(1.5, 1.15, 0.2, 0.98))
				style.set_shadow_color(Color(1.0, 0.85, 0.15, 0.65))
				style.set_shadow_size(15)
			else:
				# Square has no direction color — dark neutral background with glowing border
				style.bg_color = Color(0.12, 0.10, 0.22, 0.9)
				style.set_border_color(Color(1.5, 1.3, 0.2, 0.9))
				style.set_shadow_color(Color(1.0, 0.8, 0.1, 0.5))
				style.set_shadow_size(12)
		elif is_hold_turn and dir == current_target_direction:
			_apply_skin_to_square_style(style, direction_colors[dir], false)
			style.set_border_width_all(3)
			style.set_border_color(Color(0.2, 0.95, 1.0, 0.95))
			style.set_shadow_color(Color(0.2, 0.9, 1.0, 0.65))
			style.set_shadow_size(16)
		elif is_double_turn and dir == current_target_direction:
			_apply_skin_to_square_style(style, direction_colors[dir], false)
			style.set_border_width_all(3)
			style.set_border_color(Color(1.4, 0.85, 0.2, 0.98))
			style.set_shadow_color(Color(1.2, 0.7, 0.15, 0.65))
			style.set_shadow_size(16)
		elif is_story_mode and story_level == 4:
			_apply_story_level4_square_style(style, dir)
		elif is_story_mode and (dir in story_bomb_dirs or dir == story_bomb_dir):
			_apply_skin_to_square_style(style, direction_colors[dir], false)
			style.set_border_width_all(4)
			if story_level == 3:
				style.set_border_color(Color(1.45, 0.35, 1.85, 0.98))
				style.set_shadow_color(Color(1.05, 0.20, 1.45, 0.80))
			elif story_level == 2:
				style.set_border_color(Color(0.20, 1.55, 0.95, 0.98))
				style.set_shadow_color(Color(0.12, 1.15, 0.75, 0.78))
			else:
				style.set_border_color(Color(1.7, 0.22, 0.25, 0.98))
				style.set_shadow_color(Color(1.3, 0.12, 0.18, 0.78))
			style.set_shadow_size(18)
		else:
			_apply_skin_to_square_style(style, direction_colors[dir], false)
		panel.queue_redraw()

	if center_square != null:
		if _center_live_style == null:
			_center_live_style = _center_panel_style.duplicate() as StyleBoxFlat
			center_square.add_theme_stylebox_override("panel", _center_live_style)
		_reset_center_square_style(_center_live_style)
		var c_target_col: Color = _last_target_color if _last_target_color.a > 0.01 else direction_colors.get("up", Color.WHITE)
		if is_story_mode:
			_center_live_style.bg_color = Color(0.95, 0.97, 1.0, 1.0)
			_center_live_style.set_border_width_all(4)
			_center_live_style.set_border_color(Color(0.55, 0.92, 1.0, 0.98))
			_center_live_style.set_shadow_color(Color(0.65, 0.92, 1.0, 0.68))
			_center_live_style.set_shadow_size(16)
		elif is_frenzy_active:
			_center_live_style.bg_color = frenzy_gold
			_center_live_style.set_border_width_all(3)
			_center_live_style.set_border_color(FRENZY_SPECIAL_COLOR)
			_center_live_style.set_shadow_color(Color(1.8, 0.2, 0.85, 0.5))
			_center_live_style.set_shadow_size(14)
		elif is_hold_turn:
			_apply_skin_to_square_style(_center_live_style, c_target_col, true)
			_center_live_style.set_border_width_all(3)
			_center_live_style.set_border_color(Color(0.2, 0.95, 1.0, 0.95))
			_center_live_style.set_shadow_color(Color(0.2, 0.9, 1.0, 0.65))
			_center_live_style.set_shadow_size(16)
		elif is_double_turn:
			_apply_skin_to_square_style(_center_live_style, c_target_col, true)
			_center_live_style.set_border_width_all(4)
			_center_live_style.set_border_color(Color(1.5, 0.92, 0.2, 0.98))
			_center_live_style.set_shadow_color(Color(1.2, 0.75, 0.15, 0.7))
			_center_live_style.set_shadow_size(16)
		else:
			_apply_skin_to_square_style(_center_live_style, c_target_col, true)
			if has_shield:
				_center_live_style.set_border_width_all(4)
				_center_live_style.set_border_color(Color(0.2, 1.0, 0.75, 0.98))
				_center_live_style.set_shadow_color(Color(0.15, 0.95, 0.7, 0.65))
				_center_live_style.set_shadow_size(16)
		center_square.queue_redraw()


func _setup_board_symbols() -> void:
	var board_squares := [center_square, up_square, down_square, left_square, right_square]
	for square in board_squares:
		if square == null:
			continue
		var callable := Callable(self, "_on_board_square_draw").bind(square)
		if not square.is_connected("draw", callable):
			square.draw.connect(callable)


func _on_board_square_draw(square: Panel) -> void:
	if square == null or not is_instance_valid(square):
		return

	var sq_dir: String = str(square.get_meta("dir", ""))

	# Draw custom cosmetic Square Skin pattern underneath icons/symbols
	_draw_square_skin_overlay(square, sq_dir)

	# Story Mode special icons: White Omni-Center & Boss Hazard (Lv 1 Bombs / Lv 2 Shields / Lv 3 Void Rifts)
	if is_story_mode:
		if square == center_square:
			if story_level == 4:
				_draw_story_maestro_center_emblem(square)
			else:
				_draw_story_white_center_emblem(square)
			return
		if story_level == 4 and sq_dir != "":
			_draw_story_level4_square_overlay(square, sq_dir)
			return
		if sq_dir != "" and (sq_dir in story_bomb_dirs or sq_dir == story_bomb_dir):
			if story_level == 3:
				_draw_story_void_rift_icon(square)
			elif story_level == 2:
				_draw_story_hydra_shield_icon(square)
			else:
				_draw_story_bomb_icon(square)
			return
		if story_level == 2 and sq_dir != "" and not _are_all_boss_parts_destroyed() and int(story_part_hp.get(sq_dir, 1)) <= 0:
			_draw_symbol_on_panel(square, sq_dir)
			_draw_story_hydra_regrow_badge(square)
			return
		if story_level == 3 and sq_dir != "" and not _are_all_boss_parts_destroyed() and int(story_part_hp.get(sq_dir, 1)) <= 0:
			_draw_symbol_on_panel(square, sq_dir)
			_draw_story_void_drain_badge(square)
			return

	# Power-up square icon
	if sq_dir != "" and sq_dir == powerup_square_dir and powerup_type != "" and not is_frenzy_active:
		_draw_powerup_icon(square, powerup_type)
		return

	# Frenzy mode lightning icon on all squares
	if is_frenzy_active:
		_draw_powerup_icon(square, "frenzy")
		return

	var symbol_key := current_target_direction if square == center_square else sq_dir
	if not symbol_key.is_empty():
		_draw_symbol_on_panel(square, symbol_key)

	# Special Hold Square glow and decreasing countdown bar
	if is_hold_turn and not is_frenzy_active:
		if square == center_square or (sq_dir != "" and sq_dir == current_target_direction):
			_draw_hold_ring(square, square == center_square)

	# Double-Dash Rush indicator ring (2x swipe turn)
	if is_double_turn and not is_frenzy_active:
		if square == center_square or (sq_dir != "" and sq_dir == current_target_direction):
			_draw_double_rush_ring(square, square == center_square)

	# Active Aegis Shield halo around center square
	if has_shield and square == center_square and not is_frenzy_active:
		_draw_shield_halo(square)


func _draw_square_skin_overlay(panel: Panel, sq_dir: String) -> void:
	if settings == null:
		return
	var skin_id: String = settings.selected_skin
	if skin_id == "classic":
		return

	var s: Vector2 = panel.size
	var c: Vector2 = s / 2.0
	var base_col: Color
	if panel == center_square:
		base_col = _last_target_color if _last_target_color.a > 0.01 else direction_colors.get("up", Color.WHITE)
	else:
		base_col = direction_colors.get(sq_dir, _theme_accent())

	if skin_id == "wireframe":
		# CYBER GRID: Inner neon wireframe rect + L-shaped corner brackets + edge ticks
		var inset := 11.0
		var wire_col := Color(minf(1.2, base_col.r * 1.3 + 0.2), minf(1.2, base_col.g * 1.3 + 0.2), minf(1.2, base_col.b * 1.3 + 0.2), 0.72)
		panel.draw_rect(Rect2(inset, inset, s.x - inset * 2.0, s.y - inset * 2.0), wire_col, false, 2.0)

		var b_in := 6.0
		var b_len := 13.0
		var b_col := Color(1.0, 1.0, 1.0, 0.85)
		# Top-left
		panel.draw_line(Vector2(b_in, b_in), Vector2(b_in + b_len, b_in), b_col, 2.5)
		panel.draw_line(Vector2(b_in, b_in), Vector2(b_in, b_in + b_len), b_col, 2.5)
		# Top-right
		panel.draw_line(Vector2(s.x - b_in, b_in), Vector2(s.x - b_in - b_len, b_in), b_col, 2.5)
		panel.draw_line(Vector2(s.x - b_in, b_in), Vector2(s.x - b_in, b_in + b_len), b_col, 2.5)
		# Bottom-left
		panel.draw_line(Vector2(b_in, s.y - b_in), Vector2(b_in + b_len, s.y - b_in), b_col, 2.5)
		panel.draw_line(Vector2(b_in, s.y - b_in), Vector2(b_in, s.y - b_in - b_len), b_col, 2.5)
		# Bottom-right
		panel.draw_line(Vector2(s.x - b_in, s.y - b_in), Vector2(s.x - b_in - b_len, s.y - b_in), b_col, 2.5)
		panel.draw_line(Vector2(s.x - b_in, s.y - b_in), Vector2(s.x - b_in, s.y - b_in - b_len), b_col, 2.5)

	elif skin_id == "scanline":
		# RETRO CRT: Horizontal CRT scanlines + glossy top screen highlight + inner screen bezel
		var scan_col := Color(0.02, 0.01, 0.06, 0.28)
		var y_pos := 10.0
		while y_pos < s.y - 8.0:
			panel.draw_line(Vector2(8.0, y_pos), Vector2(s.x - 8.0, y_pos), scan_col, 2.0)
			y_pos += 6.0
		# Glossy arcade tube reflection bar at top
		panel.draw_rect(Rect2(12.0, 7.0, s.x - 24.0, 9.0), Color(1.0, 1.0, 1.0, 0.18), true)
		panel.draw_rect(Rect2(8.0, 8.0, s.x - 16.0, s.y - 16.0), Color(1.0, 1.0, 1.0, 0.22), false, 1.5)

	elif skin_id == "equalizer":
		# BASS REACTOR: 5 animated spectrum analyzer bars bouncing inside the square
		var num_bars := 5
		var total_w := s.x - 24.0
		var gap := 4.0
		var bar_w := (total_w - gap * float(num_bars - 1)) / float(num_bars)
		var max_h := s.y - 24.0
		var t_sec := Time.get_ticks_msec() * 0.008
		var dir_seed := float(sq_dir.hash() % 17)
		for b in range(num_bars):
			var phase: float = t_sec + float(b) * 1.15 + dir_seed
			var wave: float = 0.32 + 0.28 * absf(sin(phase)) + 0.38 * _audio_pulse * (0.6 + 0.4 * cos(phase * 1.7))
			var bh: float = clampf(wave, 0.15, 0.95) * max_h
			var bx := 12.0 + float(b) * (bar_w + gap)
			var by := s.y - 12.0 - bh
			panel.draw_rect(Rect2(bx, by, bar_w, bh), Color(0.04, 0.02, 0.10, 0.26), true)
			panel.draw_rect(Rect2(bx, by, bar_w, bh), Color(1.0, 1.0, 1.0, 0.24), true)
			panel.draw_line(Vector2(bx, by), Vector2(bx + bar_w, by), Color(1.0, 1.0, 1.0, 0.75), 2.5)

	elif skin_id == "diamond":
		# PRISM CORE: Faceted geometric diamond lattice & corner circuit nodes
		var m := 8.0
		var d_pts := PackedVector2Array([
			Vector2(c.x, m),
			Vector2(s.x - m, c.y),
			Vector2(c.x, s.y - m),
			Vector2(m, c.y),
			Vector2(c.x, m),
		])
		panel.draw_polyline(d_pts, Color(0.05, 0.03, 0.12, 0.35), 4.5, true)
		panel.draw_polyline(d_pts, Color(1.0, 1.0, 1.0, 0.45), 1.8, true)
		var c_nodes := [Vector2(14, 14), Vector2(s.x - 14, 14), Vector2(14, s.y - 14), Vector2(s.x - 14, s.y - 14)]
		for cn: Vector2 in c_nodes:
			panel.draw_circle(cn, 3.0, Color(1.0, 1.0, 1.0, 0.55))


func _draw_hold_ring(panel: Panel, _is_center: bool) -> void:
	if panel == null or not is_instance_valid(panel):
		return

	var s := panel.size
	var c := s / 2.0
	var r := 64.0

	# Dynamic color: cyan (start) -> gold (mid) -> radiant plasma orange (max)
	var ratio := clampf(hold_duration / MAX_HOLD_DURATION, 0.0, 1.0) if is_holding_active else 0.0
	var bar_color: Color
	if ratio < 0.5:
		bar_color = Color(0.2, 0.95, 1.0).lerp(Color(1.0, 0.9, 0.15), ratio * 2.0)
	else:
		bar_color = Color(1.0, 0.9, 0.15).lerp(Color(1.0, 0.45, 0.1), (ratio - 0.5) * 2.0)

	# 1. Four corner brackets framing the square
	var b_offset := 54.0
	var b_len := 12.0
	var b_stroke := 3.0
	var b_col := Color(bar_color.r, bar_color.g, bar_color.b, 0.85)

	panel.draw_line(c + Vector2(-b_offset, -b_offset), c + Vector2(-b_offset + b_len, -b_offset), b_col, b_stroke)
	panel.draw_line(c + Vector2(-b_offset, -b_offset), c + Vector2(-b_offset, -b_offset + b_len), b_col, b_stroke)

	panel.draw_line(c + Vector2(b_offset, -b_offset), c + Vector2(b_offset - b_len, -b_offset), b_col, b_stroke)
	panel.draw_line(c + Vector2(b_offset, -b_offset), c + Vector2(b_offset, -b_offset + b_len), b_col, b_stroke)

	panel.draw_line(c + Vector2(-b_offset, b_offset), c + Vector2(-b_offset + b_len, b_offset), b_col, b_stroke)
	panel.draw_line(c + Vector2(-b_offset, b_offset), c + Vector2(-b_offset, b_offset - b_len), b_col, b_stroke)

	panel.draw_line(c + Vector2(b_offset, b_offset), c + Vector2(b_offset - b_len, b_offset), b_col, b_stroke)
	panel.draw_line(c + Vector2(b_offset, b_offset), c + Vector2(b_offset, b_offset - b_len), b_col, b_stroke)

	# 2. Radial decreasing bar around the square (depletes up to 10 seconds)
	var start_angle := -PI * 0.5

	if is_holding_active:
		var time_remaining := maxf(0.0, MAX_HOLD_DURATION - hold_duration)
		var fraction := time_remaining / MAX_HOLD_DURATION
		var end_angle := start_angle + TAU * fraction

		# Background subtle depleted track
		panel.draw_arc(c, r, 0.0, TAU, 48, Color(0.12, 0.10, 0.22, 0.5), 5.0, true)

		if fraction > 0.005:
			# Outer glowing halo
			panel.draw_arc(c, r, start_angle, end_angle, 48, Color(bar_color.r, bar_color.g, bar_color.b, 0.35), 11.0, true)
			# Main active neon bar
			panel.draw_arc(c, r, start_angle, end_angle, 48, bar_color, 5.0, true)

			# Glowing bead on the moving head of the countdown bar
			var head_pos := c + Vector2(cos(end_angle), sin(end_angle)) * r
			panel.draw_circle(head_pos, 7.0, Color(bar_color.r, bar_color.g, bar_color.b, 0.45))
			panel.draw_circle(head_pos, 4.5, Color(1.0, 1.0, 1.0, 0.95))
	else:
		# Waiting for swipe: Pulsing full 360 degree ring
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.06
		var p_radius := r * pulse
		panel.draw_arc(c, p_radius, 0.0, TAU, 48, Color(bar_color.r, bar_color.g, bar_color.b, 0.3), 9.0, true)
		panel.draw_arc(c, p_radius, 0.0, TAU, 48, bar_color, 4.0, true)


func _draw_powerup_icon(panel: Panel, p_type: String) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var panel_size := panel.size
	var center := panel_size / 2.0
	var scale_factor := minf(panel_size.x, panel_size.y) / 100.0

	if p_type == "frenzy":
		# ⚡ Lightning Bolt
		var pts := PackedVector2Array([
			center + Vector2(2, -22) * scale_factor,
			center + Vector2(-14, 2) * scale_factor,
			center + Vector2(-2, 2) * scale_factor,
			center + Vector2(-6, 22) * scale_factor,
			center + Vector2(14, -2) * scale_factor,
			center + Vector2(2, -2) * scale_factor,
		])
		var closed := pts.duplicate()
		closed.append(pts[0])

		var is_special_square: bool = (frenzy_special_dir != "" and str(panel.get_meta("dir", "")) == frenzy_special_dir)
		var outline_color := Color(0.08, 0.06, 0.16, 0.95)
		var fill_color: Color
		var glow_stroke: Color

		if is_special_square:
			fill_color = Color(1.0, 1.0, 1.0, 0.98)
			glow_stroke = Color(2.2, 0.4, 1.3, 0.95)
			var r := 38.0 * scale_factor
			panel.draw_arc(center, r, 0.0, TAU, 32, Color(2.0, 0.4, 1.3, 0.6), 3.5 * scale_factor, true)
		else:
			fill_color = Color(1.0, 0.95, 0.3, 0.95)
			glow_stroke = Color(1.8, 1.4, 0.1, 0.95)

		panel.draw_polyline(closed, outline_color, 6.0 * scale_factor, true)
		panel.draw_polyline(closed, glow_stroke, 3.5 * scale_factor, true)
		panel.draw_colored_polygon(pts, fill_color)
		panel.draw_polyline(closed, outline_color, 1.8 * scale_factor, true)
	elif p_type == "frenzy_boost":
		# +5s Frenzy Time Booster: Pulsing Chrono Halo + Neon Cyan Dial + White Lightning + Gold "+" badge
		var r := 22.0 * scale_factor
		var glow_col := Color(0.2, 0.95, 1.0, 0.95)
		var outline_col := Color(0.08, 0.06, 0.16, 0.95)

		# Outer pulsing halo
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08
		panel.draw_arc(center, r * pulse + 4.0, 0.0, TAU, 32, Color(0.2, 0.95, 1.0, 0.25), 6.0 * scale_factor, true)
		panel.draw_arc(center, r, 0.0, TAU, 32, glow_col, 3.5 * scale_factor, true)

		# Center Lightning Bolt
		var bolt_pts := PackedVector2Array([
			center + Vector2(1, -13) * scale_factor,
			center + Vector2(-8, 1) * scale_factor,
			center + Vector2(-1, 1) * scale_factor,
			center + Vector2(-3, 13) * scale_factor,
			center + Vector2(8, -1) * scale_factor,
			center + Vector2(1, -1) * scale_factor,
		])
		var closed_bolt := bolt_pts.duplicate()
		closed_bolt.append(bolt_pts[0])
		panel.draw_polyline(closed_bolt, outline_col, 4.5 * scale_factor, true)
		panel.draw_colored_polygon(bolt_pts, Color(1.0, 1.0, 1.0, 0.98))
		panel.draw_polyline(closed_bolt, glow_col, 2.0 * scale_factor, true)

		# Gold "+" badge at top right
		var plus_pos := center + Vector2(16, -16) * scale_factor
		panel.draw_line(plus_pos + Vector2(-5, 0) * scale_factor, plus_pos + Vector2(5, 0) * scale_factor, Color(1.0, 0.9, 0.2), 3.5 * scale_factor)
		panel.draw_line(plus_pos + Vector2(0, -5) * scale_factor, plus_pos + Vector2(0, 5) * scale_factor, Color(1.0, 0.9, 0.2), 3.5 * scale_factor)
	elif p_type == "shield":
		# 🛡️ Neon Aegis Shield crest + pulsing emerald-cyan halo
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.009) * 0.08
		var r := 24.0 * scale_factor
		var glow_col := Color(0.18, 1.0, 0.72, 0.95)
		var outline_col := Color(0.06, 0.05, 0.14, 0.95)
		panel.draw_arc(center, r * pulse + 3.0, 0.0, TAU, 32, Color(0.18, 1.0, 0.72, 0.28), 5.0 * scale_factor, true)
		var sh_pts := PackedVector2Array([
			center + Vector2(0, -20) * scale_factor,
			center + Vector2(17, -12) * scale_factor,
			center + Vector2(14, 6) * scale_factor,
			center + Vector2(0, 21) * scale_factor,
			center + Vector2(-14, 6) * scale_factor,
			center + Vector2(-17, -12) * scale_factor,
		])
		var sh_closed := sh_pts.duplicate()
		sh_closed.append(sh_pts[0])
		panel.draw_polyline(sh_closed, outline_col, 5.0 * scale_factor, true)
		panel.draw_colored_polygon(sh_pts, glow_col)
		panel.draw_polyline(sh_closed, Color(1.0, 1.0, 1.0, 0.95), 2.2 * scale_factor, true)
		# Inner core chevron
		panel.draw_line(center + Vector2(-7, -2) * scale_factor, center + Vector2(0, 6) * scale_factor, Color(1, 1, 1, 0.95), 2.8 * scale_factor)
		panel.draw_line(center + Vector2(0, 6) * scale_factor, center + Vector2(7, -2) * scale_factor, Color(1, 1, 1, 0.95), 2.8 * scale_factor)
	elif p_type == "spark_jackpot":
		# 💎 Golden Spark Jackpot: 4-point radiant star-diamond + orbiting gold ring
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.011) * 0.09
		var r := 23.0 * scale_factor
		var gold_col := Color(1.4, 1.1, 0.2, 0.98)
		var outline_col := Color(0.08, 0.05, 0.14, 0.95)
		panel.draw_arc(center, r * pulse + 3.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.15, 0.32), 5.5 * scale_factor, true)
		var dm_pts := PackedVector2Array([
			center + Vector2(0, -21) * scale_factor,
			center + Vector2(7, -7) * scale_factor,
			center + Vector2(21, 0) * scale_factor,
			center + Vector2(7, 7) * scale_factor,
			center + Vector2(0, 21) * scale_factor,
			center + Vector2(-7, 7) * scale_factor,
			center + Vector2(-21, 0) * scale_factor,
			center + Vector2(-7, -7) * scale_factor,
		])
		var dm_closed := dm_pts.duplicate()
		dm_closed.append(dm_pts[0])
		panel.draw_polyline(dm_closed, outline_col, 4.8 * scale_factor, true)
		panel.draw_colored_polygon(dm_pts, gold_col)
		panel.draw_polyline(dm_closed, Color(1.0, 1.0, 0.85, 0.95), 2.0 * scale_factor, true)
		panel.draw_circle(center, 4.5 * scale_factor, Color(1.0, 1.0, 1.0, 0.98))


func _draw_double_rush_ring(panel: Panel, _is_center: bool) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s := panel.size
	var c := s / 2.0
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.015) * 0.06
	var r := 60.0 * pulse
	var col := Color(1.5, 0.92, 0.2, 0.95) if double_turn_step <= 1 else Color(1.8, 0.35, 0.95, 0.98)
	panel.draw_arc(c, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.32), 8.0, true)
	panel.draw_arc(c, r, 0.0, TAU, 40, col, 3.5, true)
	panel.draw_arc(c, r - 7.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.75), 1.8, true)


func _draw_shield_halo(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var c := panel.size / 2.0
	var t_sec := Time.get_ticks_msec() * 0.004
	var r := 58.0 + sin(t_sec * 2.5) * 2.5
	var col := Color(0.18, 1.0, 0.75, 0.88)
	# Octagonal energy barrier around the center square
	var oct := PackedVector2Array()
	for i in range(9):
		var ang := t_sec + float(i) * (TAU / 8.0)
		oct.append(c + Vector2(cos(ang), sin(ang)) * r)
	panel.draw_polyline(oct, Color(0.15, 0.95, 0.7, 0.28), 7.0, true)
	panel.draw_polyline(oct, col, 2.5, true)


func _draw_symbol_on_panel(panel: Panel, color_key: String) -> void:
	var panel_size := panel.size
	var center := panel_size / 2.0
	var scale_factor := minf(panel_size.x, panel_size.y) / 100.0

	var fill_color := Color(1.0, 1.0, 1.0, 0.85)
	var outline_color := Color(0.08, 0.06, 0.16, 0.85)
	var line_width := 2.5 * scale_factor
	var shadow_width := 5.0 * scale_factor

	match color_key:
		"up": # Triangle â–²
			var pts := PackedVector2Array([
				center + Vector2(0, -18) * scale_factor,
				center + Vector2(16, 14) * scale_factor,
				center + Vector2(-16, 14) * scale_factor,
			])
			var closed := pts.duplicate()
			closed.append(pts[0])
			panel.draw_polyline(closed, outline_color, shadow_width, true)
			panel.draw_colored_polygon(pts, fill_color)
			panel.draw_polyline(closed, outline_color, line_width, true)

		"down": # Diamond â—†
			var pts := PackedVector2Array([
				center + Vector2(0, -18) * scale_factor,
				center + Vector2(16, 0) * scale_factor,
				center + Vector2(0, 18) * scale_factor,
				center + Vector2(-16, 0) * scale_factor,
			])
			var closed := pts.duplicate()
			closed.append(pts[0])
			panel.draw_polyline(closed, outline_color, shadow_width, true)
			panel.draw_colored_polygon(pts, fill_color)
			panel.draw_polyline(closed, outline_color, line_width, true)

		"left": # Square â– 
			var pts := PackedVector2Array([
				center + Vector2(-15, -15) * scale_factor,
				center + Vector2(15, -15) * scale_factor,
				center + Vector2(15, 15) * scale_factor,
				center + Vector2(-15, 15) * scale_factor,
			])
			var closed := pts.duplicate()
			closed.append(pts[0])
			panel.draw_polyline(closed, outline_color, shadow_width, true)
			panel.draw_colored_polygon(pts, fill_color)
			panel.draw_polyline(closed, outline_color, line_width, true)

		"right": # Circle â—
			var r := 16.0 * scale_factor
			panel.draw_arc(center, r, 0, TAU, 32, outline_color, shadow_width, true)
			panel.draw_circle(center, r, fill_color)
			panel.draw_arc(center, r, 0, TAU, 32, outline_color, line_width, true)


func _apply_panel_styles() -> void:
	if pause_screen != null:
		pause_screen.z_index = 35
	if game_over_screen != null:
		game_over_screen.z_index = 35
	if tutorial_screen != null:
		tutorial_screen.z_index = 40
	$PauseScreen/PausePanel.add_theme_stylebox_override("panel", _pause_panel_style)
	$PauseScreen/PausePanel.clip_contents = true
	var pause_title := $PauseScreen/PausePanel.get_node_or_null("PauseTitle") as Label
	if pause_title != null:
		pause_title.add_theme_font_size_override("font_size", 28)
	for p_btn: Button in [resume_btn, restart_btn, pause_menu_btn]:
		if p_btn != null and is_instance_valid(p_btn):
			p_btn.add_theme_font_size_override("font_size", 20)
			p_btn.clip_contents = true
	$GameOverScreen/GameOverPanel.add_theme_stylebox_override("panel", _pause_panel_style)
	$GameOverScreen/GameOverPanel.clip_contents = true
	$TutorialScreen/TutorialPanel.add_theme_stylebox_override("panel", _pause_panel_style)
	$TutorialScreen/TutorialPanel.clip_contents = true

	# Tutorial panel slightly darker
	var tut_style := _pause_panel_style.duplicate()
	tut_style.bg_color = Color(0.15, 0.13, 0.25, 0.95)
	$TutorialScreen/TutorialPanel.add_theme_stylebox_override("panel", tut_style)


func _setup_button_styles() -> void:
	var accent := _theme_accent()
	if start_button != null and is_instance_valid(start_button):
		_apply_menu_button_style(start_button, _play_btn_style, _play_btn_hover_style)
	var buttons := [resume_btn, restart_btn, pause_menu_btn, retry_btn, leaderboard_btn, share_score_btn, rate_app_btn, go_menu_btn, pause_button, revive_btn, tutorial_understood_btn]
	for btn: Button in buttons:
		if btn == null or not is_instance_valid(btn):
			continue
		var hover := _btn_style.duplicate()
		hover.set_border_color(Color(accent.r, accent.g, accent.b, 0.9))
		hover.set_shadow_color(Color(accent.r, accent.g, accent.b, 0.6))
		hover.set_shadow_size(10)
		btn.add_theme_stylebox_override("normal", _btn_style)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_menu_button_style(btn: Button, normal_style: StyleBoxFlat = null, hover_style: StyleBoxFlat = null) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var n_style: StyleBoxFlat = normal_style if normal_style != null else _menu_btn_style
	var h_style: StyleBoxFlat = hover_style if hover_style != null else _menu_btn_hover_style
	btn.flat = false
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.add_theme_stylebox_override("normal", n_style)
	btn.add_theme_stylebox_override("hover", h_style)
	btn.add_theme_stylebox_override("pressed", h_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	pause_menu_btn.pressed.connect(_on_go_menu_pressed)
	revive_btn.pressed.connect(_on_revive_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	if leaderboard_btn != null:
		leaderboard_btn.pressed.connect(_on_go_leaderboard_pressed)
	if share_score_btn != null:
		share_score_btn.pressed.connect(_on_share_score_pressed)
	if rate_app_btn != null:
		rate_app_btn.pressed.connect(_on_rate_app_pressed)
	go_menu_btn.pressed.connect(_on_go_menu_pressed)
	if tutorial_understood_btn != null:
		tutorial_understood_btn.pressed.connect(_on_tutorial_understood_pressed)


func _setup_initial_game_state() -> void:
	_init_secure_score()
	lives = settings.MAX_LIVES
	_last_displayed_lives = settings.MAX_LIVES
	_has_revived_this_game = false
	_revive_ready_to_resume = false
	_mission_run_credited_score = 0
	_mission_run_credited_swipes = 0
	_mission_run_credited_frenzies = 0
	_mission_run_credited_holds = 0
	_mission_run_credited_fast = 0
	_mission_run_game_counted = false
	streak = 0
	best_streak_this_game = 0
	total_correct = 0
	total_swipes = 0
	current_time_limit = settings.INITIAL_TIME_LIMIT
	time_left_in_turn = settings.INITIAL_TIME_LIMIT
	turns_since_remap = 0
	turns_until_remap = _roll_remap_interval()
	_center_scale_locked = false
	_last_target_color = Color(0, 0, 0, 0)
	powerup_square_dir = ""
	powerup_type = ""
	frenzy_exit_buffer = 0.0
	frenzy_special_dir = ""
	frenzy_switch_timer = 0.0
	_frenzy_count_this_game = 0
	_fast_swipes_this_game = 0
	_remaps_survived_this_game = 0
	_lost_heart_this_game = false
	_hold_squares_completed_this_game = 0
	_clutch_swipes_this_game = 0
	_frenzies_at_max_multiplier = 0
	fastest_reaction_this_game = 999.0
	frenzies_triggered_this_game = 0
	longest_hold_this_game = 0.0
	_turn_start_time = Time.get_ticks_msec() / 1000.0
	_board_aura_tier = 0
	_board_aura_time = 0.0
	_audio_pulse = 0.0
	_trail_points.clear()
	if _board_aura_panel != null and is_instance_valid(_board_aura_panel):
		_board_aura_panel.queue_redraw()
	is_hold_turn = false
	is_holding_active = false
	hold_duration = 0.0
	hold_exit_buffer = 0.0
	is_double_turn = false
	double_turn_step = 0
	_cleanup_double_turn_ui()
	fever_meter = 0.0
	perfect_streak = 0
	best_perfect_streak_this_game = 0
	has_shield = false
	sparks_collected_in_run = 0
	_high_score_at_run_start = settings.high_score if settings != null else 0
	_beaten_high_score_this_run = false
	_unlocked_songs_this_run.clear()
	_update_shield_ui()
	_cleanup_hold_ui()
	_end_frenzy_mode()
	frenzy_charges = 0
	_update_frenzy_charge_ui()
	_update_lives_display()
	update_score_display()
	_update_combo_hud()
	_update_high_score_display()


# =====================================================
# STATE MANAGEMENT
# =====================================================

func _set_state(new_state: GameSettings.GameState) -> void:
	state = new_state
	var is_tut_from_menu: bool = (state == GameSettings.GameState.TUTORIAL and _tutorial_return_state == GameSettings.GameState.MENU)
	menu_screen.visible = (state == GameSettings.GameState.MENU or is_tut_from_menu)
	game_screen.visible = (state == GameSettings.GameState.PLAYING or state == GameSettings.GameState.PAUSED or state == GameSettings.GameState.GAME_OVER or (state == GameSettings.GameState.TUTORIAL and not is_tut_from_menu))
	pause_screen.visible = (state == GameSettings.GameState.PAUSED)
	game_over_screen.visible = (state == GameSettings.GameState.GAME_OVER)
	tutorial_screen.visible = (state == GameSettings.GameState.TUTORIAL)

	if _walkthrough_overlay != null and is_instance_valid(_walkthrough_overlay):
		_walkthrough_overlay.visible = (state == GameSettings.GameState.PLAYING and _is_walkthrough_active)

	if state == GameSettings.GameState.PAUSED or state == GameSettings.GameState.GAME_OVER or state == GameSettings.GameState.MENU:
		_clear_persistent_labels()

	if state == GameSettings.GameState.GAME_OVER or state == GameSettings.GameState.MENU:
		_end_frenzy_mode()

	# Background-shader speed follows the game state (visual streak juice).
	if state == GameSettings.GameState.PLAYING:
		_update_streak_visuals()
	else:
		_set_bg_shader_speed(0.0)


func _setup_song_player() -> void:
	_song_player = AudioStreamPlayer.new()
	_song_player.name = "SongPlayer"
	_song_player.volume_db = linear_to_db(clampf(settings.music_volume, 0.0001, 1.0))
	_song_player.bus = &"Master"
	add_child(_song_player)
	if sfx != null and sfx.has_signal("voice_started") and not sfx.voice_started.is_connected(_on_voice_started):
		sfx.voice_started.connect(_on_voice_started)
	_play_selected_song()


func _on_voice_started(duration: float) -> void:
	_audio_pulse = minf(1.0, _audio_pulse + 0.55)
	if _song_player == null or settings == null or settings.music_volume <= 0.01:
		return
	if _music_duck_tween != null and _music_duck_tween.is_valid():
		_music_duck_tween.kill()
	var base_db := linear_to_db(clampf(settings.music_volume, 0.0001, 1.0))
	var ducked_db := base_db - 4.5
	_music_duck_tween = create_tween()
	_music_duck_tween.tween_property(_song_player, "volume_db", ducked_db, 0.05)
	_music_duck_tween.tween_interval(maxf(0.2, duration - 0.12))
	_music_duck_tween.tween_property(_song_player, "volume_db", base_db, 0.28)


func _get_song_by_id(song_id: String) -> Dictionary:
	for song: Dictionary in settings.SONGS:
		if str(song.get("id", "")) == song_id:
			return song
	return {}


func _update_music_volume() -> void:
	if _song_player != null:
		_song_player.volume_db = linear_to_db(clampf(settings.music_volume, 0.0001, 1.0))


func _play_selected_song() -> void:
	if _song_player == null:
		return
	_update_music_volume()
	var song: Dictionary = _get_song_by_id(settings.selected_song)
	var path: String = str(song.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		# Fall back to the first (free) song if the selected one is missing.
		var first: Dictionary = settings.SONGS[0]
		path = str(first.get("path", ""))
	var stream: AudioStream = _song_cache.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			return
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_song_cache[path] = stream
	if _song_player.stream != stream or not _song_player.playing:
		_song_player.stream = stream
		if is_inside_tree() and DisplayServer.get_name() != "headless":
			_song_player.play()


func _select_song(song_id: String) -> void:
	settings.selected_song = song_id
	settings.save_data()
	_play_selected_song()
	_refresh_songs_screen()


func _update_streak_visuals() -> void:
	var intensity: float
	if is_frenzy_active:
		intensity = 1.0
	else:
		var max_streak: int = settings.COMBO_HITS_PER_LEVEL * settings.COMBO_MAX_MULTIPLIER
		var ratio := clampf(float(streak) / float(max_streak), 0.0, 1.0)
		intensity = lerpf(0.2, 1.0, ratio)
	_set_bg_shader_speed(intensity)
	_update_board_aura_state()


func _set_bg_shader_speed(intensity: float) -> void:
	if _bg_shader_mat != null:
		_bg_shader_mat.set_shader_parameter("speed", lerpf(0.35, 1.1, intensity))


func _update_board_aura_state() -> void:
	var new_tier: int = 0
	if streak >= 200:
		new_tier = 3
	elif streak >= 100:
		new_tier = 2
	elif streak >= 50:
		new_tier = 1

	if new_tier != _board_aura_tier:
		var prev_tier := _board_aura_tier
		_board_aura_tier = new_tier
		if new_tier > prev_tier and state == settings.GameState.PLAYING:
			# Upgraded to new aura milestone!
			_haptic_celebration()
			var b_center := _get_board_center("")
			var tier_color: Color = Color(0.18, 0.88, 1.0)
			var tier_msg := "⚡ 50 STREAK: ELECTRIC SURGE! ⚡"
			if new_tier == 2:
				tier_color = Color(1.0, 0.45, 0.1)
				tier_msg = "🔥 100 STREAK: BLAZING FLAME! 🔥"
			elif new_tier == 3:
				tier_color = Color(1.0, 0.3, 0.95)
				tier_msg = "✨ 200 STREAK: MYTHIC CORONA! ✨"
			_burst_particles(b_center, tier_color, 24)
			_show_floating_text(tier_msg, b_center + Vector2(0, -185), tier_color)
		if _board_aura_panel != null and is_instance_valid(_board_aura_panel):
			_board_aura_panel.queue_redraw()


# =====================================================
# SONGS / UNLOCKS UI
# =====================================================

func _setup_songs_ui() -> void:
	# --- "SONGS" button under PLAY on the menu screen ---
	_songs_button = Button.new()
	_songs_button.name = "SongsButton"
	_songs_button.text = "SONGS"
	_songs_button.anchor_left = 0.5
	_songs_button.anchor_right = 0.5
	_songs_button.offset_left = -120.0
	_songs_button.offset_right = 120.0
	_songs_button.offset_top = 488.0
	_songs_button.offset_bottom = 536.0
	_songs_button.add_theme_font_size_override("font_size", 25)
	_apply_menu_button_style(_songs_button)
	_songs_button.pressed.connect(_open_songs_screen)
	menu_screen.add_child(_songs_button)

	# --- Songs selection overlay screen ---
	_songs_screen = Control.new()
	_songs_screen.name = "SongsScreen"
	_songs_screen.visible = false
	_songs_screen.anchor_right = 1.0
	_songs_screen.anchor_bottom = 1.0
	_songs_screen.z_index = 50
	add_child(_songs_screen)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.gui_input.connect(_on_songs_backdrop_input)
	_songs_screen.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _pause_panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -280.0
	panel.offset_bottom = 280.0
	panel.gui_input.connect(_on_songs_panel_input)
	_songs_screen.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "SONGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -180.0
	title.offset_right = 180.0
	title.offset_top = 24.0
	title.offset_bottom = 70.0
	panel.add_child(title)

	_songs_best_label = Label.new()
	_songs_best_label.name = "BestLabel"
	_songs_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_songs_best_label.add_theme_font_size_override("font_size", 18)
	_songs_best_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95, 1.0))
	_songs_best_label.anchor_left = 0.5
	_songs_best_label.anchor_right = 0.5
	_songs_best_label.offset_left = -180.0
	_songs_best_label.offset_right = 180.0
	_songs_best_label.offset_top = 70.0
	_songs_best_label.offset_bottom = 94.0
	panel.add_child(_songs_best_label)

	_songs_scroll = ScrollContainer.new()
	_songs_scroll.name = "SongScroll"
	_songs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_songs_scroll.scroll_deadzone = 4
	_songs_scroll.anchor_left = 0.5
	_songs_scroll.anchor_right = 0.5
	_songs_scroll.offset_left = -190.0
	_songs_scroll.offset_right = 190.0
	_songs_scroll.offset_top = 104.0
	_songs_scroll.offset_bottom = 530.0
	panel.add_child(_songs_scroll)

	_songs_list = VBoxContainer.new()
	_songs_list.name = "SongList"
	_songs_list.add_theme_constant_override("separation", 12)
	_songs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_songs_scroll.add_child(_songs_list)


func _on_songs_backdrop_input(event: InputEvent) -> void:
	# Only close on a clean tap — not during/after a drag
	if _overlay_drag_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_songs_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_close_songs_screen()


func _on_songs_panel_input(event: InputEvent) -> void:
	_overlay_handle_panel_input(event, true)


func _on_themes_panel_input(event: InputEvent) -> void:
	_overlay_handle_panel_input(event, false)


func _overlay_handle_panel_input(event: InputEvent, is_song: bool) -> void:
	var scroll: ScrollContainer = _songs_scroll if is_song else _themes_scroll

	# --- Touch ---
	if event is InputEventScreenTouch:
		if event.pressed:
			# Record the finger-down position but don't commit to drag yet.
			# We wait until the finger moves past the tap threshold before scrolling,
			# so that taps on buttons still register as selections.
			_overlay_drag_active = false
			_overlay_drag_is_song = is_song
			_overlay_drag_start_y = event.position.y
			_overlay_drag_scroll_start = scroll.scroll_vertical
		else:
			_overlay_drag_active = false
		# Don't mark handled — let touch-up reach buttons normally.

	elif event is InputEventScreenDrag:
		if _overlay_drag_is_song == is_song:
			var moved: float = abs(event.position.y - _overlay_drag_start_y)
			if moved > _OVERLAY_TAP_THRESHOLD:
				# Commit to scroll mode — from this point all motion is a scroll.
				_overlay_drag_active = true
			if _overlay_drag_active:
				var delta: float = _overlay_drag_start_y - event.position.y
				scroll.scroll_vertical = _overlay_drag_scroll_start + int(delta)
				get_viewport().set_input_as_handled()

	# --- Mouse (editor / desktop testing) ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_overlay_drag_active = false
				_overlay_drag_is_song = is_song
				_overlay_drag_start_y = event.position.y
				_overlay_drag_scroll_start = scroll.scroll_vertical
			else:
				_overlay_drag_active = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.scroll_vertical -= 60
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll.scroll_vertical += 60
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _overlay_drag_is_song == is_song and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var moved: float = abs(event.position.y - _overlay_drag_start_y)
			if moved > _OVERLAY_TAP_THRESHOLD:
				_overlay_drag_active = true
			if _overlay_drag_active:
				var delta: float = _overlay_drag_start_y - event.position.y
				scroll.scroll_vertical = _overlay_drag_scroll_start + int(delta)
				get_viewport().set_input_as_handled()


func _open_songs_screen() -> void:
	_overlay_drag_active = false
	sfx.play("tap")
	_refresh_songs_screen()
	_songs_screen.visible = true


func _close_songs_screen() -> void:
	_overlay_drag_active = false
	sfx.play("tap")
	_songs_screen.visible = false


func _refresh_songs_screen() -> void:
	_update_high_score_display()
	for child in _songs_list.get_children():
		_songs_list.remove_child(child)
		child.queue_free()
	for song: Dictionary in settings.SONGS:
		_songs_list.add_child(_build_song_row(song))


func _build_song_row(song: Dictionary) -> Button:
	var song_id: String = str(song.get("id", ""))
	var song_name: String = str(song.get("name", "?"))
	var unlock: int = int(song.get("unlock_score", 0))
	var unlocked: bool = settings.is_song_unlocked(song)
	var selected: bool = song_id == settings.selected_song

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 20)

	if not unlocked:
		btn.disabled = true
		btn.text = song_name + "\nUNLOCK AT SCORE " + _format_number_with_commas(unlock)
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85, 1.0))
		btn.add_theme_color_override("font_disabled_color", Color(1.0, 0.85, 0.85, 1.0))
		var locked_style := _btn_style.duplicate()
		locked_style.bg_color = Color(0.45, 0.08, 0.10, 0.85)
		locked_style.set_border_color(Color(1.0, 0.3, 0.35, 0.7))
		locked_style.set_shadow_color(Color(0.8, 0.1, 0.15, 0.4))
		locked_style.set_shadow_size(6)
		btn.add_theme_stylebox_override("normal", locked_style)
		btn.add_theme_stylebox_override("disabled", locked_style)
	else:
		btn.text = (">  " + song_name) if selected else song_name
		var text_color := Color(1.0, 0.9, 0.35) if selected else Color(0.9, 0.95, 1.0)
		btn.add_theme_color_override("font_color", text_color)
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		var row_style := _btn_style.duplicate()
		if selected:
			row_style.set_border_color(Color(1.0, 0.85, 0.2, 0.9))
			row_style.set_shadow_color(Color(1.0, 0.8, 0.1, 0.4))
		btn.add_theme_stylebox_override("normal", row_style)
		var r_hover := row_style.duplicate()
		r_hover.set_border_color(Color(1, 1, 1, 0.9))
		r_hover.set_shadow_color(Color(1, 1, 1, 0.5))
		r_hover.set_shadow_size(8)
		btn.add_theme_stylebox_override("hover", r_hover)
		btn.add_theme_stylebox_override("pressed", r_hover)
		btn.pressed.connect(_select_song.bind(song_id))

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


# =====================================================
# THEMES / UNLOCKS UI
# =====================================================

func _setup_themes_ui() -> void:
	# --- "THEMES" button under SONGS on the menu screen ---
	_themes_button = Button.new()
	_themes_button.name = "ThemesButton"
	_themes_button.text = "THEMES"
	_themes_button.anchor_left = 0.5
	_themes_button.anchor_right = 0.5
	_themes_button.offset_left = -120.0
	_themes_button.offset_right = 120.0
	_themes_button.offset_top = 546.0
	_themes_button.offset_bottom = 594.0
	_themes_button.add_theme_font_size_override("font_size", 25)
	_apply_menu_button_style(_themes_button)
	_themes_button.pressed.connect(_open_themes_screen)
	menu_screen.add_child(_themes_button)

	# --- Themes selection overlay screen ---
	_themes_screen = Control.new()
	_themes_screen.name = "ThemesScreen"
	_themes_screen.visible = false
	_themes_screen.anchor_right = 1.0
	_themes_screen.anchor_bottom = 1.0
	_themes_screen.z_index = 50
	add_child(_themes_screen)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.gui_input.connect(_on_themes_backdrop_input)
	_themes_screen.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _pause_panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -280.0
	panel.offset_bottom = 280.0
	panel.gui_input.connect(_on_themes_panel_input)
	_themes_screen.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "THEMES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -180.0
	title.offset_right = 180.0
	title.offset_top = 24.0
	title.offset_bottom = 70.0
	panel.add_child(title)

	_themes_best_label = Label.new()
	_themes_best_label.name = "BestLabel"
	_themes_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_themes_best_label.add_theme_font_size_override("font_size", 18)
	_themes_best_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95, 1.0))
	_themes_best_label.anchor_left = 0.5
	_themes_best_label.anchor_right = 0.5
	_themes_best_label.offset_left = -180.0
	_themes_best_label.offset_right = 180.0
	_themes_best_label.offset_top = 70.0
	_themes_best_label.offset_bottom = 94.0
	panel.add_child(_themes_best_label)

	_themes_scroll = ScrollContainer.new()
	_themes_scroll.name = "ThemeScroll"
	_themes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_themes_scroll.scroll_deadzone = 4
	_themes_scroll.anchor_left = 0.5
	_themes_scroll.anchor_right = 0.5
	_themes_scroll.offset_left = -190.0
	_themes_scroll.offset_right = 190.0
	_themes_scroll.offset_top = 104.0
	_themes_scroll.offset_bottom = 530.0
	panel.add_child(_themes_scroll)

	_themes_list = VBoxContainer.new()
	_themes_list.name = "ThemeList"
	_themes_list.add_theme_constant_override("separation", 12)
	_themes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_themes_scroll.add_child(_themes_list)


func _on_themes_backdrop_input(event: InputEvent) -> void:
	# Only close on a clean tap — not during/after a drag
	if _overlay_drag_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_themes_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_close_themes_screen()


func _open_themes_screen() -> void:
	_overlay_drag_active = false
	sfx.play("tap")
	_refresh_themes_screen()
	_themes_screen.visible = true


func _close_themes_screen() -> void:
	_overlay_drag_active = false
	sfx.play("tap")
	_themes_screen.visible = false


func _refresh_themes_screen() -> void:
	if _themes_best_label != null:
		_themes_best_label.text = "ALL THEMES UNLOCKED"
	for child in _themes_list.get_children():
		_themes_list.remove_child(child)
		child.queue_free()
	for theme_def: Dictionary in settings.THEMES:
		_themes_list.add_child(_build_theme_row(theme_def))


func _build_theme_row(theme_def: Dictionary) -> Button:
	var theme_id: String = str(theme_def.get("id", ""))
	var theme_name: String = str(theme_def.get("name", "?"))
	var subtitle: String = str(theme_def.get("subtitle", ""))
	var unlock: int = int(theme_def.get("unlock_score", 0))
	var unlocked: bool = settings.is_theme_unlocked(theme_def)
	var selected: bool = theme_id == settings.selected_theme
	var accent_col: Color = theme_def.get("accent", Color(0.9, 0.3, 0.6))
	var bg_dict: Dictionary = theme_def.get("bg", {})

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 74)
	btn.clip_contents = true
	btn.text = ""

	if not unlocked:
		btn.disabled = true
		var locked_style := _btn_style.duplicate()
		locked_style.bg_color = Color(0.32, 0.06, 0.10, 0.85)
		locked_style.set_border_color(Color(1.0, 0.3, 0.35, 0.7))
		locked_style.set_shadow_color(Color(0.8, 0.1, 0.15, 0.4))
		locked_style.set_shadow_size(6)
		btn.add_theme_stylebox_override("normal", locked_style)
		btn.add_theme_stylebox_override("disabled", locked_style)
	else:
		var row_style := _btn_style.duplicate()
		var sky_mid: Color = bg_dict.get("sky_mid", Color(0.12, 0.09, 0.22))
		row_style.bg_color = Color(sky_mid.r * 0.85 + 0.04, sky_mid.g * 0.85 + 0.03, sky_mid.b * 0.85 + 0.06, 0.92)
		if selected:
			row_style.set_border_width_all(3)
			row_style.set_border_color(Color(1.0, 0.88, 0.25, 0.98))
			row_style.set_shadow_color(Color(accent_col.r, accent_col.g, accent_col.b, 0.55))
			row_style.set_shadow_size(10)
		else:
			row_style.set_border_width_all(2)
			row_style.set_border_color(Color(accent_col.r, accent_col.g, accent_col.b, 0.72))
			row_style.set_shadow_color(Color(accent_col.r, accent_col.g, accent_col.b, 0.28))
			row_style.set_shadow_size(6)
		btn.add_theme_stylebox_override("normal", row_style)
		var r_hover := row_style.duplicate()
		r_hover.set_border_color(Color(1, 1, 1, 0.95))
		r_hover.set_shadow_color(Color(accent_col.r, accent_col.g, accent_col.b, 0.65))
		r_hover.set_shadow_size(10)
		btn.add_theme_stylebox_override("hover", r_hover)
		btn.add_theme_stylebox_override("pressed", r_hover)
		btn.pressed.connect(_select_theme.bind(theme_id))

	# 1. Left Retro Scene Preview Emblem
	var preview_ctrl := Control.new()
	preview_ctrl.name = "ThemePreview"
	preview_ctrl.position = Vector2(12.0, 13.0)
	preview_ctrl.size = Vector2(48.0, 48.0)
	preview_ctrl.custom_minimum_size = Vector2(48.0, 48.0)
	preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_ctrl.draw.connect(_draw_theme_preview_badge.bind(preview_ctrl, theme_def))
	btn.add_child(preview_ctrl)

	# 2. Title & Retro Subtitle
	var name_lbl := Label.new()
	name_lbl.text = ("> " + theme_name) if selected else theme_name
	name_lbl.anchor_right = 1.0
	name_lbl.offset_left = 70.0
	name_lbl.offset_right = -78.0
	name_lbl.offset_top = 12.0
	name_lbl.offset_bottom = 38.0
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35) if selected else Color(0.96, 0.98, 1.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = ("UNLOCK AT SCORE " + str(unlock)) if not unlocked else subtitle
	sub_lbl.anchor_right = 1.0
	sub_lbl.offset_left = 70.0
	sub_lbl.offset_right = -78.0
	sub_lbl.offset_top = 40.0
	sub_lbl.offset_bottom = 62.0
	sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.96, 0.85))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sub_lbl)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


func _draw_theme_preview_badge(ctrl: Control, theme_def: Dictionary) -> void:
	var s: Vector2 = ctrl.size
	var c: Vector2 = s * 0.5
	var bg_dict: Dictionary = theme_def.get("bg", {})
	var board_dict: Dictionary = theme_def.get("board", {})
	var style_idx: int = int(bg_dict.get("bg_style", 0))
	var sky_top: Color = bg_dict.get("sky_top", Color(0.05, 0.02, 0.14))
	var sky_bot: Color = bg_dict.get("sky_bottom", Color(0.32, 0.06, 0.30))
	var sun_col: Color = bg_dict.get("sun_color", Color(1.0, 0.4, 0.6))
	var grid_col: Color = bg_dict.get("grid_color", Color(0.9, 0.2, 0.8))
	var hor_col: Color = bg_dict.get("horizon_color", Color(0.2, 0.9, 1.0))

	# Circular retro window backdrop
	ctrl.draw_circle(c, 22.0, sky_top.lerp(sky_bot, 0.55))
	var hy: float = c.y + 4.0

	if style_idx == 0:
		# SYNTHWAVE: Outrun sun + wireframe mountain peak
		ctrl.draw_circle(c + Vector2(0, -4), 9.5, sun_col)
		var pk := PackedVector2Array([Vector2(c.x - 16, hy), Vector2(c.x - 5, hy - 9), Vector2(c.x + 3, hy - 3), Vector2(c.x + 11, hy - 10), Vector2(c.x + 17, hy)])
		ctrl.draw_colored_polygon(pk, sky_top)
		ctrl.draw_polyline(pk, hor_col, 1.5, true)
	elif style_idx == 1:
		# OCEAN: Crescent moon + neon waves
		ctrl.draw_circle(c + Vector2(-1, -5), 8.5, sun_col)
		ctrl.draw_circle(c + Vector2(2.5, -7), 7.0, sky_top.lerp(sky_bot, 0.4))
		ctrl.draw_line(Vector2(c.x - 12, hy + 5), Vector2(c.x + 12, hy + 5), grid_col, 1.8)
		ctrl.draw_line(Vector2(c.x - 8, hy + 9), Vector2(c.x + 8, hy + 9), hor_col, 1.8)
	elif style_idx == 2:
		# EMBER: Solar eclipse ring + skyline
		ctrl.draw_arc(c + Vector2(0, -5), 8.5, 0.0, TAU, 24, sun_col, 2.6, true)
		ctrl.draw_circle(c + Vector2(0, -5), 6.2, sky_top)
		ctrl.draw_rect(Rect2(c.x - 13, hy - 6, 5, 6), sky_top, true)
		ctrl.draw_rect(Rect2(c.x + 7, hy - 8, 6, 8), sky_top, true)
	elif style_idx == 3:
		# FOREST: Wireframe holo-diamond + aurora
		var dm := PackedVector2Array([c + Vector2(0, -14), c + Vector2(8, -5), c + Vector2(0, 3), c + Vector2(-8, -5), c + Vector2(0, -14)])
		ctrl.draw_polyline(dm, sun_col, 1.8, true)
		ctrl.draw_line(c + Vector2(0, -14), c + Vector2(0, 3), hor_col, 1.2)
	else:
		# MIDNIGHT: Tilted ringed Saturn planet
		ctrl.draw_circle(c + Vector2(0, -4), 6.5, sun_col)
		ctrl.draw_line(c + Vector2(-13, 0), c + Vector2(13, -8), hor_col, 2.2, true)

	# Horizon laser line
	ctrl.draw_line(Vector2(c.x - 17, hy), Vector2(c.x + 17, hy), grid_col, 1.6)
	# Outer neon ring frame
	ctrl.draw_arc(c, 22.0, 0.0, TAU, 32, grid_col, 2.0, true)

	# 4 mini board color dots on the right side of the button (drawn relative to ctrl)
	var dirs := ["up", "right", "down", "left"]
	for i in range(4):
		var d_col: Color = board_dict.get(dirs[i], Color.WHITE)
		var dx: float = 304.0 + float(i % 2) * 16.0
		var dy: float = 10.0 + float(i >> 1) * 16.0
		ctrl.draw_rect(Rect2(dx, dy, 11.0, 11.0), d_col, true)
		ctrl.draw_rect(Rect2(dx, dy, 11.0, 11.0), Color(1, 1, 1, 0.75), false, 1.0)


# =====================================================
# NEON SPARKS & COSMETIC SHOP UI
# =====================================================

func _format_sparks_compact(n: int) -> String:
	var val: int = maxi(0, n)
	if val < 10000:
		return _format_number_with_commas(val)
	elif val < 1000000:
		var k: float = snappedf(float(val) / 1000.0, 0.1)
		if is_equal_approx(k, roundf(k)):
			return str(int(roundf(k))) + "K"
		return ("%.1f" % k) + "K"
	elif val < 1000000000:
		var m: float = snappedf(float(val) / 1000000.0, 0.1)
		if is_equal_approx(m, roundf(m)):
			return str(int(roundf(m))) + "M"
		return ("%.1f" % m) + "M"
	return "999M+"


func _create_spark_icon(icon_size: float = 20.0, bolt_col: Color = Color(1.0, 0.92, 0.25)) -> Control:
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(icon_size, icon_size)
	ctrl.size = Vector2(icon_size, icon_size)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(_draw_spark_bolt_icon.bind(ctrl, bolt_col))
	return ctrl


func _draw_spark_bolt_icon(ctrl: Control, bolt_col: Color) -> void:
	var s: Vector2 = ctrl.size
	if s.x <= 1.0 or s.y <= 1.0:
		s = ctrl.custom_minimum_size
	var c: Vector2 = s * 0.5
	var r: float = minf(s.x, s.y) * 0.46
	var pts := PackedVector2Array([
		c + Vector2(r * 0.12, -r * 0.98),
		c + Vector2(-r * 0.65, r * 0.08),
		c + Vector2(-r * 0.06, r * 0.08),
		c + Vector2(-r * 0.26, r * 0.98),
		c + Vector2(r * 0.65, -r * 0.08),
		c + Vector2(r * 0.06, -r * 0.08),
	])
	var closed := pts.duplicate()
	closed.append(pts[0])
	var outline_col := Color(0.06, 0.03, 0.14, 0.95)
	var glow_col := Color(bolt_col.r, bolt_col.g, bolt_col.b, 0.55)
	ctrl.draw_polyline(closed, outline_col, maxf(2.0, r * 0.36), true)
	ctrl.draw_polyline(closed, glow_col, maxf(1.5, r * 0.22), true)
	ctrl.draw_colored_polygon(pts, bolt_col.lightened(0.18))


func _draw_shop_item_preview(ctrl: Control, category: String, item_id: String, col: Color, unlocked: bool) -> void:
	var s: Vector2 = ctrl.size
	if s.x <= 1.0 or s.y <= 1.0:
		s = ctrl.custom_minimum_size
	var c: Vector2 = s * 0.5
	var draw_col: Color = col if unlocked else Color(col.r * 0.65, col.g * 0.65, col.b * 0.65, 0.75)

	# Subtle dark badge backing
	ctrl.draw_circle(c, 19.0, Color(0.06, 0.04, 0.14, 0.85))
	ctrl.draw_arc(c, 19.0, 0.0, TAU, 28, Color(draw_col.r, draw_col.g, draw_col.b, 0.65), 1.8, true)

	if category == "trail":
		var pts := PackedVector2Array([
			c + Vector2(-11, 9),
			c + Vector2(-4, -5),
			c + Vector2(4, 4),
			c + Vector2(11, -9),
		])
		if item_id == "rainbow":
			ctrl.draw_line(pts[0], pts[1], Color(1.0, 0.25, 0.45), 3.5, true)
			ctrl.draw_line(pts[1], pts[2], Color(1.0, 0.88, 0.20), 4.0, true)
			ctrl.draw_line(pts[2], pts[3], Color(0.20, 0.95, 1.0), 4.5, true)
		else:
			ctrl.draw_polyline(pts, Color(draw_col.r, draw_col.g, draw_col.b, 0.55), 5.5, true)
			ctrl.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.92), 2.0, true)
		ctrl.draw_circle(pts[3], 3.2, Color(1.0, 1.0, 1.0, 0.95))
	elif category == "skin":
		var sq_rect := Rect2(c.x - 10.0, c.y - 10.0, 20.0, 20.0)
		if item_id == "wireframe":
			ctrl.draw_rect(sq_rect, Color(draw_col.r, draw_col.g, draw_col.b, 0.20), true)
			ctrl.draw_rect(sq_rect, draw_col, false, 2.2)
		elif item_id == "scanline":
			ctrl.draw_rect(sq_rect, draw_col, true)
			ctrl.draw_line(c + Vector2(-8, -4), c + Vector2(8, -4), Color(0, 0, 0, 0.45), 1.5)
			ctrl.draw_line(c + Vector2(-8, 1), c + Vector2(8, 1), Color(0, 0, 0, 0.45), 1.5)
			ctrl.draw_line(c + Vector2(-8, 6), c + Vector2(8, 6), Color(0, 0, 0, 0.45), 1.5)
		elif item_id == "equalizer":
			ctrl.draw_rect(sq_rect, Color(draw_col.r, draw_col.g, draw_col.b, 0.25), true)
			ctrl.draw_rect(sq_rect, draw_col, false, 1.6)
			ctrl.draw_line(c + Vector2(-5, 7), c + Vector2(-5, -1), Color(1, 1, 1, 0.9), 2.5)
			ctrl.draw_line(c + Vector2(0, 7), c + Vector2(0, -6), Color(1, 1, 1, 0.9), 2.5)
			ctrl.draw_line(c + Vector2(5, 7), c + Vector2(5, 1), Color(1, 1, 1, 0.9), 2.5)
		elif item_id == "diamond":
			ctrl.draw_rect(sq_rect, Color(draw_col.r, draw_col.g, draw_col.b, 0.30), true)
			var d_pts := PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0), c + Vector2(0, -9)])
			ctrl.draw_polyline(d_pts, Color(1, 1, 1, 0.9), 1.8, true)
		else:
			ctrl.draw_rect(sq_rect, draw_col, true)
			ctrl.draw_rect(sq_rect, Color(1, 1, 1, 0.8), false, 1.5)
	else:
		# Sound wave bars
		var heights := [6.0, 12.0, 16.0, 10.0, 7.0]
		for i in range(heights.size()):
			var bx: float = c.x - 10.0 + float(i) * 5.0
			var bh: float = heights[i]
			ctrl.draw_line(Vector2(bx, c.y - bh * 0.5), Vector2(bx, c.y + bh * 0.5), draw_col, 2.6)


func _layout_menu_buttons() -> void:
	# Dynamically scale and position the Title and all 8 Menu Buttons so they fit cleanly
	# with generous space between the title and the buttons across any device resolution/aspect ratio.
	var vp_size: Vector2 = size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = get_viewport_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = Vector2(540.0, 960.0)

	var vw: float = maxf(320.0, vp_size.x)
	var vh: float = maxf(640.0, vp_size.y)
	var w_scale: float = vw / 540.0
	var h_scale: float = vh / 960.0
	var ui_scale: float = clampf(minf(w_scale, h_scale), 0.75, 1.30)

	var btn_w: float = roundf(clampf(256.0 * ui_scale, 210.0, vw * 0.74))
	var half_w: float = roundf(btn_w * 0.5)
	var btn_h: float = roundf(clampf(44.0 * h_scale, 38.0, 52.0))
	var btn_gap: float = roundf(clampf(vh * 0.009, 7.0, 13.0))

	var menu_buttons: Array[Button] = [
		_menu_sparks_btn,
		start_button,
		_story_button,
		_songs_button,
		_themes_button,
		_shop_button,
		_badges_button,
		_leaderboard_button,
		_options_button,
	]
	var valid_btns: Array[Button] = []
	for btn: Button in menu_buttons:
		if btn != null and is_instance_valid(btn):
			valid_btns.append(btn)

	var num_btns: int = maxi(1, valid_btns.size())
	var total_btns_h: float = float(num_btns) * btn_h + float(num_btns - 1) * btn_gap

	var title1_h: float = roundf(92.0 * ui_scale)
	var title2_h: float = roundf(114.0 * ui_scale)
	var title_overlap: float = roundf(16.0 * ui_scale)
	var title_block_h: float = title1_h + title2_h - title_overlap

	var bottom_version_reserve: float = roundf(48.0 * ui_scale)
	var usable_h: float = vh - bottom_version_reserve
	var remaining_h: float = maxf(60.0, usable_h - title_block_h - total_btns_h)

	var top_margin: float = roundf(remaining_h * 0.34)
	var title_to_btns_gap: float = roundf(remaining_h * 0.36)

	var title1 := $MenuScreen/TitleLabel as Label
	if title1 != null and is_instance_valid(title1):
		title1.offset_top = top_margin
		title1.offset_bottom = top_margin + title1_h
		title1.add_theme_font_size_override("font_size", int(roundf(62.0 * ui_scale)))
		title1.pivot_offset = Vector2(300.0, title1_h * 0.5)

	var title2_top: float = top_margin + title1_h - title_overlap
	var title2_bottom: float = title2_top + title2_h
	var title2 := $MenuScreen/TitleLabel2 as Label
	if title2 != null and is_instance_valid(title2):
		title2.offset_top = title2_top
		title2.offset_bottom = title2_bottom
		title2.add_theme_font_size_override("font_size", int(roundf(86.0 * ui_scale)))
		title2.pivot_offset = Vector2(300.0, title2_h * 0.5)

	var cur_y: float = roundf(title2_bottom + title_to_btns_gap)
	var std_font_size: int = int(roundf(20.0 * ui_scale))
	var play_font_size: int = int(roundf(16.0 * ui_scale))
	var story_font_size: int = int(roundf(16.0 * ui_scale))
	var lb_font_size: int = int(roundf(16.0 * ui_scale))

	for btn: Button in valid_btns:
		btn.clip_contents = true
		btn.offset_left = -half_w
		btn.offset_right = half_w
		btn.offset_top = cur_y
		btn.offset_bottom = cur_y + btn_h
		if btn == start_button:
			btn.add_theme_font_size_override("font_size", play_font_size)
		elif btn == _story_button:
			btn.add_theme_font_size_override("font_size", story_font_size)
		elif btn == _leaderboard_button:
			btn.add_theme_font_size_override("font_size", lb_font_size)
		elif btn != _menu_sparks_btn:
			btn.add_theme_font_size_override("font_size", std_font_size)
		cur_y += btn_h + btn_gap

	_update_sparks_displays()


func _setup_shop_ui() -> void:
	# 1. Daily Missions & Sparks Button on MenuScreen (same size & rounded look as the rest of the menu buttons)
	_menu_sparks_btn = Button.new()
	_menu_sparks_btn.name = "MenuSparksPill"
	_menu_sparks_btn.text = ""
	_menu_sparks_btn.clip_contents = true
	_menu_sparks_btn.anchor_left = 0.5
	_menu_sparks_btn.anchor_right = 0.5
	_menu_sparks_btn.offset_left = -120.0
	_menu_sparks_btn.offset_right = 120.0
	_menu_sparks_btn.offset_top = 372.0
	_menu_sparks_btn.offset_bottom = 420.0
	_apply_menu_button_style(_menu_sparks_btn)
	_menu_sparks_btn.pressed.connect(_open_missions_screen)

	var pill_hbox := HBoxContainer.new()
	pill_hbox.name = "PillContent"
	pill_hbox.anchor_right = 1.0
	pill_hbox.anchor_bottom = 1.0
	pill_hbox.offset_left = 8.0
	pill_hbox.offset_right = -8.0
	pill_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_hbox.add_theme_constant_override("separation", 5)
	pill_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_sparks_btn.add_child(pill_hbox)

	pill_hbox.add_child(_create_spark_icon(17.0, Color(1.0, 0.92, 0.25)))

	_menu_sparks_label = Label.new()
	_menu_sparks_label.name = "MenuSparksLabel"
	_menu_sparks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_sparks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_sparks_label.add_theme_font_size_override("font_size", 13)
	_menu_sparks_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_menu_sparks_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.14, 1.0))
	_menu_sparks_label.add_theme_constant_override("outline_size", 4)
	_menu_sparks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_hbox.add_child(_menu_sparks_label)

	menu_screen.add_child(_menu_sparks_btn)

	# 2. "SHOP" button on the menu screen
	_shop_button = Button.new()
	_shop_button.name = "ShopButton"
	_shop_button.text = "SHOP"
	_shop_button.anchor_left = 0.5
	_shop_button.anchor_right = 0.5
	_shop_button.offset_left = -120.0
	_shop_button.offset_right = 120.0
	_shop_button.offset_top = 604.0
	_shop_button.offset_bottom = 652.0
	_shop_button.add_theme_font_size_override("font_size", 25)
	_apply_menu_button_style(_shop_button)
	_shop_button.pressed.connect(_open_shop_cosmetics_screen)
	menu_screen.add_child(_shop_button)

	# 3. Shop & Daily Missions overlay screen (matches exact 440px width of Songs/Themes/Badges panels)
	_shop_screen = Control.new()
	_shop_screen.name = "ShopScreen"
	_shop_screen.visible = false
	_shop_screen.anchor_right = 1.0
	_shop_screen.anchor_bottom = 1.0
	_shop_screen.z_index = 55
	add_child(_shop_screen)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.76)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.gui_input.connect(_on_shop_backdrop_input)
	_shop_screen.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _pause_panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -310.0
	panel.offset_bottom = 310.0
	panel.gui_input.connect(_on_shop_panel_input)
	_shop_screen.add_child(panel)

	_shop_title_label = Label.new()
	_shop_title_label.name = "Title"
	_shop_title_label.text = "NEON SHOP"
	_shop_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_title_label.add_theme_font_size_override("font_size", 28)
	_shop_title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	_shop_title_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.22, 1.0))
	_shop_title_label.add_theme_constant_override("outline_size", 8)
	_shop_title_label.anchor_left = 0.5
	_shop_title_label.anchor_right = 0.5
	_shop_title_label.offset_left = -196.0
	_shop_title_label.offset_right = 196.0
	_shop_title_label.offset_top = 16.0
	_shop_title_label.offset_bottom = 54.0
	panel.add_child(_shop_title_label)

	var bal_hbox := HBoxContainer.new()
	bal_hbox.name = "BalanceRow"
	bal_hbox.anchor_left = 0.5
	bal_hbox.anchor_right = 0.5
	bal_hbox.offset_left = -196.0
	bal_hbox.offset_right = 196.0
	bal_hbox.offset_top = 56.0
	bal_hbox.offset_bottom = 84.0
	bal_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bal_hbox.add_theme_constant_override("separation", 6)
	bal_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bal_hbox)

	_shop_sparks_icon = _create_spark_icon(18.0, Color(1.0, 0.92, 0.25))
	bal_hbox.add_child(_shop_sparks_icon)

	_shop_sparks_label = Label.new()
	_shop_sparks_label.name = "SparksBalanceLabel"
	_shop_sparks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_sparks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shop_sparks_label.add_theme_font_size_override("font_size", 14)
	_shop_sparks_label.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
	_shop_sparks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bal_hbox.add_child(_shop_sparks_label)

	# Category Tabs: MISSIONS | TRAILS | SKINS | SOUNDS
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.name = "CategoryTabs"
	tabs_hbox.anchor_left = 0.5
	tabs_hbox.anchor_right = 0.5
	tabs_hbox.offset_left = -194.0
	tabs_hbox.offset_right = 194.0
	tabs_hbox.offset_top = 88.0
	tabs_hbox.offset_bottom = 130.0
	tabs_hbox.add_theme_constant_override("separation", 6)
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(tabs_hbox)

	var tab_defs := [
		{"id": "missions", "label": "MISSIONS"},
		{"id": "trail",    "label": "TRAILS"},
		{"id": "skin",     "label": "SKINS"},
		{"id": "sfx",      "label": "SOUNDS"},
	]
	for t_def: Dictionary in tab_defs:
		var t_id: String = str(t_def["id"])
		var t_btn := Button.new()
		t_btn.name = "Tab_" + t_id
		t_btn.text = str(t_def["label"])
		t_btn.clip_text = true
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 40)
		t_btn.add_theme_font_size_override("font_size", 11)
		t_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		t_btn.pressed.connect(_on_shop_tab_selected.bind(t_id))
		tabs_hbox.add_child(t_btn)
		_shop_tab_buttons[t_id] = t_btn

	_shop_scroll = ScrollContainer.new()
	_shop_scroll.name = "ShopScroll"
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_shop_scroll.scroll_deadzone = 6
	_shop_scroll.anchor_left = 0.5
	_shop_scroll.anchor_right = 0.5
	_shop_scroll.offset_left = -194.0
	_shop_scroll.offset_right = 194.0
	_shop_scroll.offset_top = 140.0
	_shop_scroll.offset_bottom = 550.0
	panel.add_child(_shop_scroll)

	# Style the vertical scrollbar so it is clearly visible and easy to grab/swipe on mobile phones
	var v_bar := _shop_scroll.get_v_scroll_bar()
	if v_bar != null:
		v_bar.custom_minimum_size = Vector2(12, 0)
		v_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb_track := StyleBoxFlat.new()
		sb_track.set_corner_radius_all(6)
		sb_track.bg_color = Color(0.06, 0.04, 0.14, 0.90)
		sb_track.set_border_width_all(1)
		sb_track.set_border_color(Color(0.35, 0.30, 0.55, 0.55))
		sb_track.content_margin_left = 2.0
		sb_track.content_margin_right = 2.0
		var sb_grab := StyleBoxFlat.new()
		sb_grab.set_corner_radius_all(6)
		sb_grab.bg_color = Color(1.0, 0.88, 0.25, 0.90)
		var sb_grab_hl := sb_grab.duplicate()
		sb_grab_hl.bg_color = Color(1.0, 0.96, 0.55, 1.0)
		v_bar.add_theme_stylebox_override("scroll", sb_track)
		v_bar.add_theme_stylebox_override("grabber", sb_grab)
		v_bar.add_theme_stylebox_override("grabber_highlight", sb_grab_hl)
		v_bar.add_theme_stylebox_override("grabber_pressed", sb_grab_hl)

	var shop_margin := MarginContainer.new()
	shop_margin.name = "ShopMargin"
	shop_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_margin.add_theme_constant_override("margin_right", 8)
	_shop_scroll.add_child(shop_margin)

	_shop_list = VBoxContainer.new()
	_shop_list.name = "ShopList"
	_shop_list.add_theme_constant_override("separation", 10)
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_margin.add_child(_shop_list)

	var close_btn := Button.new()
	close_btn.name = "CloseShopBtn"
	close_btn.text = "CLOSE"
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.offset_left = -100.0
	close_btn.offset_right = 100.0
	close_btn.offset_top = 562.0
	close_btn.offset_bottom = 604.0
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	close_btn.add_theme_stylebox_override("normal", _btn_style)
	close_btn.add_theme_stylebox_override("hover", _btn_style)
	close_btn.add_theme_stylebox_override("pressed", _btn_style)
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.pressed.connect(_close_shop_screen)
	panel.add_child(close_btn)

	# 4. Game Over Panel Sparks & Missions/Shop Controls
	_setup_gameover_sparks_ui()
	_update_sparks_displays()


func _setup_gameover_sparks_ui() -> void:
	var go_panel: Panel = $GameOverScreen/GameOverPanel
	if go_panel == null:
		return

	# Expand GameOverPanel slightly to house the Daily Missions status row & Missions/Shop buttons
	go_panel.offset_top = -332.0
	go_panel.offset_bottom = 332.0

	var go_title: Label = $GameOverScreen/GameOverPanel/GameOverTitle
	if go_title != null:
		go_title.offset_top = 14.0
		go_title.offset_bottom = 62.0
	if new_record_badge != null:
		new_record_badge.offset_left = -148.0
		new_record_badge.offset_right = 148.0
		new_record_badge.offset_top = 54.0
		new_record_badge.offset_bottom = 76.0
		new_record_badge.add_theme_font_size_override("font_size", 12)
	if final_score_label != null:
		final_score_label.offset_top = 70.0
		final_score_label.offset_bottom = 134.0
	if go_high_score != null:
		go_high_score.offset_top = 134.0
		go_high_score.offset_bottom = 160.0
		go_high_score.add_theme_font_size_override("font_size", 15)
	if stats_label != null:
		stats_label.offset_top = 164.0
		stats_label.offset_bottom = 242.0

	# Glowing Neon Sparks & Daily Missions Status Row on Game Over
	var go_sparks_hbox := HBoxContainer.new()
	go_sparks_hbox.name = "GameOverSparksRow"
	go_sparks_hbox.anchor_right = 1.0
	go_sparks_hbox.offset_left = 10.0
	go_sparks_hbox.offset_right = -10.0
	go_sparks_hbox.offset_top = 246.0
	go_sparks_hbox.offset_bottom = 276.0
	go_sparks_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	go_sparks_hbox.add_theme_constant_override("separation", 6)
	go_sparks_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go_panel.add_child(go_sparks_hbox)

	go_sparks_hbox.add_child(_create_spark_icon(15.0, Color(1.0, 0.92, 0.25)))

	_go_sparks_label = Label.new()
	_go_sparks_label.name = "GameOverSparksLabel"
	_go_sparks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_sparks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_go_sparks_label.add_theme_font_size_override("font_size", 10)
	_go_sparks_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	_go_sparks_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.16, 1.0))
	_go_sparks_label.add_theme_constant_override("outline_size", 4)
	_go_sparks_label.text = "MISSIONS: 0/3  |  SPARKS: 0"
	go_sparks_hbox.add_child(_go_sparks_label)

	if revive_btn != null:
		revive_btn.offset_top = 282.0
		revive_btn.offset_bottom = 330.0
		revive_btn.clip_contents = true

	# "MISSIONS" button (left side)
	_go_double_sparks_btn = Button.new()
	_go_double_sparks_btn.name = "GameOverMissionsBtn"
	_go_double_sparks_btn.text = "   MISSIONS"
	_go_double_sparks_btn.clip_contents = true
	_go_double_sparks_btn.anchor_left = 0.5
	_go_double_sparks_btn.anchor_right = 0.5
	_go_double_sparks_btn.offset_left = -135.0
	_go_double_sparks_btn.offset_right = -4.0
	_go_double_sparks_btn.offset_top = 338.0
	_go_double_sparks_btn.offset_bottom = 384.0
	_go_double_sparks_btn.add_theme_font_size_override("font_size", 10)
	_go_double_sparks_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))
	_go_double_sparks_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.65))
	_go_double_sparks_btn.add_theme_stylebox_override("normal", _btn_style)
	_go_double_sparks_btn.add_theme_stylebox_override("hover", _btn_style)
	_go_double_sparks_btn.add_theme_stylebox_override("pressed", _btn_style)
	_go_double_sparks_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_go_double_sparks_btn.pressed.connect(_open_missions_screen)
	var dbl_icon := _create_spark_icon(14.0, Color(1.0, 0.92, 0.25))
	dbl_icon.position = Vector2(8.0, 15.0)
	_go_double_sparks_btn.add_child(dbl_icon)
	go_panel.add_child(_go_double_sparks_btn)

	# "NEON SHOP" button (right side)
	_go_shop_btn = Button.new()
	_go_shop_btn.name = "GameOverShopBtn"
	_go_shop_btn.text = "   NEON SHOP"
	_go_shop_btn.clip_contents = true
	_go_shop_btn.anchor_left = 0.5
	_go_shop_btn.anchor_right = 0.5
	_go_shop_btn.offset_left = 4.0
	_go_shop_btn.offset_right = 135.0
	_go_shop_btn.offset_top = 338.0
	_go_shop_btn.offset_bottom = 384.0
	_go_shop_btn.add_theme_font_size_override("font_size", 10)
	_go_shop_btn.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
	_go_shop_btn.add_theme_color_override("font_hover_color", Color(0.65, 1.0, 1.0))
	_go_shop_btn.add_theme_stylebox_override("normal", _btn_style)
	_go_shop_btn.add_theme_stylebox_override("hover", _btn_style)
	_go_shop_btn.add_theme_stylebox_override("pressed", _btn_style)
	_go_shop_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_go_shop_btn.pressed.connect(_open_shop_cosmetics_screen)
	var shop_go_icon := _create_spark_icon(14.0, Color(0.25, 0.95, 1.0))
	shop_go_icon.position = Vector2(8.0, 15.0)
	_go_shop_btn.add_child(shop_go_icon)
	go_panel.add_child(_go_shop_btn)

	if retry_btn != null:
		retry_btn.offset_top = 392.0
		retry_btn.offset_bottom = 440.0
		retry_btn.clip_contents = true
	if leaderboard_btn != null:
		leaderboard_btn.offset_top = 448.0
		leaderboard_btn.offset_bottom = 494.0
		leaderboard_btn.add_theme_font_size_override("font_size", 16)
		leaderboard_btn.clip_contents = true
	if share_score_btn != null:
		share_score_btn.offset_top = 448.0
		share_score_btn.offset_bottom = 494.0
		share_score_btn.add_theme_font_size_override("font_size", 16)
		share_score_btn.clip_contents = true
	if rate_app_btn != null:
		rate_app_btn.offset_top = 502.0
		rate_app_btn.offset_bottom = 546.0
		rate_app_btn.add_theme_font_size_override("font_size", 13)
		rate_app_btn.clip_contents = true
	if go_menu_btn != null:
		go_menu_btn.offset_top = 554.0
		go_menu_btn.offset_bottom = 602.0
		go_menu_btn.add_theme_font_size_override("font_size", 18)
		go_menu_btn.clip_contents = true


func _update_sparks_displays() -> void:
	var sp_compact := _format_sparks_compact(settings.sparks)
	var sp_full := _format_number_with_commas(settings.sparks)
	var m_sum: Dictionary = settings.get_daily_missions_summary()
	var m_done: int = int(m_sum.get("done", 0))
	var m_total: int = int(m_sum.get("total", 3))
	if _menu_sparks_label != null and is_instance_valid(_menu_sparks_label):
		var pill_txt := sp_compact + "  |  MISSIONS " + str(m_done) + "/" + str(m_total)
		_menu_sparks_label.text = pill_txt
		var btn_w: float = 240.0
		if _menu_sparks_btn != null and is_instance_valid(_menu_sparks_btn):
			btn_w = maxf(200.0, _menu_sparks_btn.offset_right - _menu_sparks_btn.offset_left)
		var w_ratio: float = clampf(btn_w / 240.0, 0.85, 1.25)
		var f_size: int = int(roundf(13.0 * w_ratio))
		if pill_txt.length() > 21:
			f_size = int(roundf(11.0 * w_ratio))
		elif pill_txt.length() > 18:
			f_size = int(roundf(12.0 * w_ratio))
		_menu_sparks_label.add_theme_font_size_override("font_size", f_size)
	if _shop_sparks_icon != null and is_instance_valid(_shop_sparks_icon):
		_shop_sparks_icon.visible = true
	if _shop_sparks_label != null and is_instance_valid(_shop_sparks_label):
		var shown_bal := sp_full if settings.sparks < 1000000 else sp_compact
		_shop_sparks_label.text = "BALANCE: " + shown_bal + " SPARKS"
		_shop_sparks_label.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
		_shop_sparks_label.add_theme_font_size_override("font_size", 14)


func _on_shop_backdrop_input(event: InputEvent) -> void:
	if _overlay_drag_active or _shop_scrollbar_dragging:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_shop_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_close_shop_screen()


func _on_shop_panel_input(event: InputEvent) -> void:
	if _shop_scroll == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_shop_scroll.scroll_vertical -= 60
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_shop_scroll.scroll_vertical += 60
			get_viewport().set_input_as_handled()


func _set_shop_scroll_from_bar_y(global_y: float) -> void:
	if _shop_scroll == null or not is_instance_valid(_shop_scroll):
		return
	var v_bar := _shop_scroll.get_v_scroll_bar()
	if v_bar == null:
		return
	var scroll_rect := _shop_scroll.get_global_rect()
	if scroll_rect.size.y <= 1.0:
		return
	var max_scroll: float = maxf(0.0, v_bar.max_value - v_bar.page)
	if max_scroll <= 0.0:
		_shop_scroll.scroll_vertical = 0
		return
	# Account for thumb height so dragging feels 1:1 from top to bottom of the track
	var thumb_ratio: float = clampf(v_bar.page / maxf(1.0, v_bar.max_value), 0.12, 0.85)
	var track_margin: float = scroll_rect.size.y * thumb_ratio * 0.5
	var usable_h: float = maxf(1.0, scroll_rect.size.y - track_margin * 2.0)
	var ratio: float = clampf((global_y - (scroll_rect.position.y + track_margin)) / usable_h, 0.0, 1.0)
	_shop_scroll.scroll_vertical = int(roundf(ratio * max_scroll))


func _cycle_shop_tab(dir_step: int) -> void:
	var order := ["missions", "trail", "skin", "sfx"]
	var idx := order.find(_shop_active_tab)
	if idx == -1:
		idx = 0
	var next_idx := clampi(idx + dir_step, 0, order.size() - 1)
	if next_idx != idx:
		_on_shop_tab_selected(order[next_idx])


func _handle_shop_touch_scroll(event: InputEvent) -> void:
	if _shop_screen == null or not _shop_screen.visible or _shop_scroll == null:
		return

	var scroll_rect := _shop_scroll.get_global_rect()
	# Generous 34px touch target on the right edge of ShopScroll for the mobile side scrollbar
	var bar_zone_left: float = scroll_rect.end.x - 30.0
	var bar_zone_right: float = scroll_rect.end.x + 16.0

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y >= scroll_rect.position.y and event.position.y <= scroll_rect.end.y:
				if event.position.x >= bar_zone_left and event.position.x <= bar_zone_right:
					_shop_scrollbar_dragging = true
					_overlay_drag_active = true
					_overlay_drag_is_shop = false
					_set_shop_scroll_from_bar_y(event.position.y)
					get_viewport().set_input_as_handled()
				elif scroll_rect.has_point(event.position):
					_overlay_drag_active = false
					_shop_scrollbar_dragging = false
					_overlay_drag_is_shop = true
					_overlay_drag_start_x = event.position.x
					_overlay_drag_start_y = event.position.y
					_overlay_drag_scroll_start = _shop_scroll.scroll_vertical
		else:
			if _shop_scrollbar_dragging:
				_shop_scrollbar_dragging = false
				set_deferred("_overlay_drag_active", false)
				get_viewport().set_input_as_handled()
			elif _overlay_drag_is_shop:
				_overlay_drag_is_shop = false
				if _overlay_drag_active:
					set_deferred("_overlay_drag_active", false)
					get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if _shop_scrollbar_dragging:
			_set_shop_scroll_from_bar_y(event.position.y)
			get_viewport().set_input_as_handled()
		elif _overlay_drag_is_shop:
			var dx: float = event.position.x - _overlay_drag_start_x
			var dy: float = event.position.y - _overlay_drag_start_y
			if not _overlay_drag_active and absf(dx) > 64.0 and absf(dx) > absf(dy) * 1.8:
				_overlay_drag_active = true
				_overlay_drag_is_shop = false
				_cycle_shop_tab(-1 if dx > 0.0 else 1)
				get_viewport().set_input_as_handled()
				return
			if absf(dy) > _OVERLAY_TAP_THRESHOLD:
				_overlay_drag_active = true
			if _overlay_drag_active:
				var delta_y: float = _overlay_drag_start_y - event.position.y
				_shop_scroll.scroll_vertical = _overlay_drag_scroll_start + int(delta_y)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.y >= scroll_rect.position.y and event.position.y <= scroll_rect.end.y:
					if event.position.x >= bar_zone_left and event.position.x <= bar_zone_right:
						_shop_scrollbar_dragging = true
						_overlay_drag_active = true
						_overlay_drag_is_shop = false
						_set_shop_scroll_from_bar_y(event.position.y)
						get_viewport().set_input_as_handled()
					elif scroll_rect.has_point(event.position):
						_overlay_drag_active = false
						_shop_scrollbar_dragging = false
						_overlay_drag_is_shop = true
						_overlay_drag_start_x = event.position.x
						_overlay_drag_start_y = event.position.y
						_overlay_drag_scroll_start = _shop_scroll.scroll_vertical
			else:
				if _shop_scrollbar_dragging:
					_shop_scrollbar_dragging = false
					set_deferred("_overlay_drag_active", false)
					get_viewport().set_input_as_handled()
				elif _overlay_drag_is_shop:
					_overlay_drag_is_shop = false
					if _overlay_drag_active:
						set_deferred("_overlay_drag_active", false)
						get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _shop_scrollbar_dragging:
				_set_shop_scroll_from_bar_y(event.position.y)
				get_viewport().set_input_as_handled()
			elif _overlay_drag_is_shop:
				var dx: float = event.position.x - _overlay_drag_start_x
				var dy: float = event.position.y - _overlay_drag_start_y
				if not _overlay_drag_active and absf(dx) > 64.0 and absf(dx) > absf(dy) * 1.8:
					_overlay_drag_active = true
					_overlay_drag_is_shop = false
					_cycle_shop_tab(-1 if dx > 0.0 else 1)
					get_viewport().set_input_as_handled()
					return
				if absf(dy) > _OVERLAY_TAP_THRESHOLD:
					_overlay_drag_active = true
				if _overlay_drag_active:
					var delta_y: float = _overlay_drag_start_y - event.position.y
					_shop_scroll.scroll_vertical = _overlay_drag_scroll_start + int(delta_y)
					get_viewport().set_input_as_handled()


func _open_missions_screen() -> void:
	_shop_active_tab = "missions"
	if _shop_scroll != null:
		_shop_scroll.scroll_vertical = 0
	_open_shop_screen()


func _open_shop_cosmetics_screen() -> void:
	if _shop_active_tab == "missions":
		_shop_active_tab = "trail"
	if _shop_scroll != null:
		_shop_scroll.scroll_vertical = 0
	_open_shop_screen()


func _open_shop_screen() -> void:
	_overlay_drag_active = false
	_shop_scrollbar_dragging = false
	_overlay_drag_is_shop = false
	sfx.play("tap")
	_haptic_tap()
	if not settings.daily_bonus_ad_unlocked and has_node("/root/AdManager"):
		get_node("/root/AdManager").preload_rewarded_ad()
	_refresh_shop_screen()
	if _shop_screen != null:
		_shop_screen.visible = true


func _close_shop_screen() -> void:
	_overlay_drag_active = false
	_shop_scrollbar_dragging = false
	_overlay_drag_is_shop = false
	sfx.play("tap")
	_haptic_tap()
	if _shop_screen != null:
		_shop_screen.visible = false


func _on_shop_tab_selected(tab_id: String) -> void:
	sfx.play("tap")
	_haptic_tap()
	_shop_active_tab = tab_id
	if _shop_scroll != null:
		_shop_scroll.scroll_vertical = 0
	_refresh_shop_screen()


func _refresh_shop_screen() -> void:
	settings.check_and_refresh_daily_missions()
	_update_sparks_displays()

	if _shop_title_label != null and is_instance_valid(_shop_title_label):
		_shop_title_label.text = "DAILY MISSIONS" if _shop_active_tab == "missions" else "NEON SHOP"

	# Style category tabs
	for t_id: String in _shop_tab_buttons:
		var t_btn: Button = _shop_tab_buttons[t_id]
		if t_btn == null or not is_instance_valid(t_btn):
			continue
		var is_active := (t_id == _shop_active_tab)
		var t_style := StyleBoxFlat.new()
		t_style.set_corner_radius_all(12)
		if is_active:
			t_style.bg_color = Color(0.20, 0.14, 0.36, 0.96)
			t_style.set_border_width_all(2)
			t_style.set_border_color(Color(1.0, 0.88, 0.25, 0.95))
			t_style.set_shadow_color(Color(1.0, 0.80, 0.15, 0.45))
			t_style.set_shadow_size(8)
			t_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30))
		else:
			t_style.bg_color = Color(0.08, 0.06, 0.16, 0.80)
			t_style.set_border_width_all(1)
			t_style.set_border_color(Color(0.4, 0.35, 0.55, 0.5))
			t_btn.add_theme_color_override("font_color", Color(0.70, 0.72, 0.85))
		t_btn.add_theme_stylebox_override("normal", t_style)
		t_btn.add_theme_stylebox_override("hover", t_style)
		t_btn.add_theme_stylebox_override("pressed", t_style)

	if _shop_list == null:
		return
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()

	if _shop_active_tab == "missions":
		var info_lbl := Label.new()
		info_lbl.name = "MissionsSubtitle"
		var m_sum: Dictionary = settings.get_daily_missions_summary()
		var m_done: int = int(m_sum.get("done", 0))
		var m_total: int = int(m_sum.get("total", 3))
		info_lbl.text = "COMPLETE DAILY QUESTS FOR SPARKS  (" + str(m_done) + "/" + str(m_total) + " DONE)"
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_lbl.custom_minimum_size = Vector2(0, 20)
		info_lbl.clip_text = true
		info_lbl.add_theme_font_size_override("font_size", 10)
		info_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
		info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_list.add_child(info_lbl)

		for slot_idx in range(mini(4, settings.daily_mission_ids.size())):
			var q_id := str(settings.daily_mission_ids[slot_idx])
			_shop_list.add_child(_build_mission_row(slot_idx, q_id, slot_idx == 3))
	else:
		var items: Array = []
		match _shop_active_tab:
			"trail":
				items = settings.SWIPE_TRAILS
			"skin":
				items = settings.SQUARE_SKINS
			"sfx":
				items = settings.SOUND_PACKS

		for item_def: Dictionary in items:
			_shop_list.add_child(_build_shop_row(_shop_active_tab, item_def))

	# Bottom padding spacer so the last card scrolls cleanly with room to spare
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 14)
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_list.add_child(bottom_pad)


func _build_mission_row(slot_idx: int, q_id: String, is_bonus_slot: bool) -> Button:
	var q_def: Dictionary = settings.get_quest_by_id(q_id)
	var q_name: String = str(q_def.get("name", "DAILY QUEST"))
	var q_desc: String = str(q_def.get("desc", ""))
	var target: int = maxi(1, int(q_def.get("target", 1)))
	var reward: int = int(q_def.get("reward", 100))
	var q_col: Color = q_def.get("color", Color(0.25, 0.95, 1.0))
	var q_icon: String = str(q_def.get("icon", "bolt"))

	var btn := Button.new()
	btn.name = "MissionSlot_" + str(slot_idx)
	btn.text = ""
	btn.clip_contents = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.custom_minimum_size = Vector2(0, 92)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Case 1: 4th Bonus Daily Mission locked behind a Rewarded Ad
	if is_bonus_slot and not settings.daily_bonus_ad_unlocked:
		var locked_style := _btn_style.duplicate()
		locked_style.bg_color = Color(0.17, 0.10, 0.28, 0.94)
		locked_style.set_border_width_all(2)
		locked_style.set_border_color(Color(1.0, 0.82, 0.22, 0.92))
		locked_style.set_shadow_color(Color(1.0, 0.72, 0.12, 0.38))
		locked_style.set_shadow_size(8)
		btn.add_theme_stylebox_override("normal", locked_style)
		var l_hover := locked_style.duplicate()
		l_hover.set_border_color(Color(1.0, 0.95, 0.55, 1.0))
		btn.add_theme_stylebox_override("hover", l_hover)
		btn.add_theme_stylebox_override("pressed", l_hover)
		btn.pressed.connect(_on_unlock_bonus_mission_pressed)

		var bonus_icon_panel := Panel.new()
		bonus_icon_panel.name = "BonusIcon"
		bonus_icon_panel.position = Vector2(12.0, 25.0)
		bonus_icon_panel.size = Vector2(42.0, 42.0)
		bonus_icon_panel.custom_minimum_size = Vector2(42.0, 42.0)
		bonus_icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bonus_icon_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		bonus_icon_panel.draw.connect(func():
			bonus_icon_panel.draw_circle(Vector2(21.0, 21.0), 19.0, Color(0.07, 0.04, 0.15, 0.90))
			bonus_icon_panel.draw_arc(Vector2(21.0, 21.0), 19.0, 0.0, TAU, 28, Color(1.0, 0.85, 0.25, 0.75), 1.8, true)
			_draw_badge_icon(bonus_icon_panel, "star", Color(1.0, 0.88, 0.25))
		)
		btn.add_child(bonus_icon_panel)

		var b_title := Label.new()
		b_title.name = "BonusTitle"
		b_title.text = "EXTRA DAILY MISSION"
		b_title.anchor_right = 1.0
		b_title.offset_left = 64.0
		b_title.offset_right = -114.0
		b_title.offset_top = 8.0
		b_title.offset_bottom = 30.0
		b_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b_title.clip_text = true
		b_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b_title.add_theme_font_size_override("font_size", 13)
		b_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30))
		b_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(b_title)

		var b_rew_hbox := HBoxContainer.new()
		b_rew_hbox.name = "BonusRewardBox"
		b_rew_hbox.anchor_left = 1.0
		b_rew_hbox.anchor_right = 1.0
		b_rew_hbox.offset_left = -112.0
		b_rew_hbox.offset_right = -12.0
		b_rew_hbox.offset_top = 8.0
		b_rew_hbox.offset_bottom = 30.0
		b_rew_hbox.alignment = BoxContainer.ALIGNMENT_END
		b_rew_hbox.add_theme_constant_override("separation", 4)
		b_rew_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(b_rew_hbox)

		b_rew_hbox.add_child(_create_spark_icon(15.0, Color(1.0, 0.92, 0.25)))
		var b_rew_lbl := Label.new()
		b_rew_lbl.text = "+" + str(reward)
		b_rew_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b_rew_lbl.add_theme_font_size_override("font_size", 13)
		b_rew_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))
		b_rew_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_rew_hbox.add_child(b_rew_lbl)

		var b_desc := Label.new()
		b_desc.name = "BonusDesc"
		b_desc.text = "Watch a short ad to unlock 1 extra Daily Mission today!"
		b_desc.anchor_right = 1.0
		b_desc.offset_left = 64.0
		b_desc.offset_right = -12.0
		b_desc.offset_top = 31.0
		b_desc.offset_bottom = 59.0
		b_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		b_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b_desc.clip_text = true
		b_desc.add_theme_font_size_override("font_size", 10)
		b_desc.add_theme_color_override("font_color", Color(0.88, 0.84, 0.96))
		b_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(b_desc)

		var cta_lbl := Label.new()
		cta_lbl.name = "WatchAdCta"
		cta_lbl.text = "LOADING AD..." if _bonus_mission_ad_loading else "[ WATCH AD TO UNLOCK MISSION ]"
		cta_lbl.anchor_right = 1.0
		cta_lbl.offset_left = 64.0
		cta_lbl.offset_right = -12.0
		cta_lbl.offset_top = 62.0
		cta_lbl.offset_bottom = 84.0
		cta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cta_lbl.clip_text = true
		cta_lbl.add_theme_font_size_override("font_size", 11)
		cta_lbl.add_theme_color_override("font_color", Color(0.30, 0.98, 1.0))
		cta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cta_lbl)

		return btn

	# Case 2: Active or Completed Daily Mission
	var completed: bool = settings.is_daily_mission_completed(q_id)
	var cur: int = target if completed else mini(target, settings.get_daily_mission_progress(q_id))

	var row_style := _btn_style.duplicate()
	var title_col := Color(0.95, 0.98, 1.0)
	var desc_col := Color(0.78, 0.82, 0.92)
	var accent_col: Color = Color(0.30, 1.0, 0.55) if completed else q_col

	if completed:
		title_col = Color(0.35, 1.0, 0.60)
		desc_col = Color(0.72, 0.92, 0.80)
		row_style.bg_color = Color(0.07, 0.19, 0.14, 0.92)
		row_style.set_border_width_all(2)
		row_style.set_border_color(Color(0.25, 1.0, 0.55, 0.90))
		row_style.set_shadow_color(Color(0.15, 0.90, 0.45, 0.30))
		row_style.set_shadow_size(6)
	else:
		row_style.bg_color = Color(0.11, 0.09, 0.22, 0.92)
		row_style.set_border_width_all(2)
		row_style.set_border_color(Color(q_col.r, q_col.g, q_col.b, 0.78))

	btn.add_theme_stylebox_override("normal", row_style)
	btn.add_theme_stylebox_override("hover", row_style)
	btn.add_theme_stylebox_override("pressed", row_style)

	# 1. Left Quest Icon (42x42)
	var q_icon_panel := Panel.new()
	q_icon_panel.name = "QuestIcon"
	q_icon_panel.position = Vector2(12.0, 25.0)
	q_icon_panel.size = Vector2(42.0, 42.0)
	q_icon_panel.custom_minimum_size = Vector2(42.0, 42.0)
	q_icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_icon_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	q_icon_panel.draw.connect(func():
		q_icon_panel.draw_circle(Vector2(21.0, 21.0), 19.0, Color(0.06, 0.04, 0.14, 0.88))
		q_icon_panel.draw_arc(Vector2(21.0, 21.0), 19.0, 0.0, TAU, 28, Color(accent_col.r, accent_col.g, accent_col.b, 0.70), 1.8, true)
		_draw_badge_icon(q_icon_panel, q_icon, accent_col)
	)
	btn.add_child(q_icon_panel)

	# 2. Quest Name Label (top-left, clipped cleanly)
	var name_lbl := Label.new()
	name_lbl.name = "QuestName"
	name_lbl.text = ("BONUS: " + q_name) if is_bonus_slot else q_name
	name_lbl.anchor_right = 1.0
	name_lbl.offset_left = 64.0
	name_lbl.offset_right = -114.0
	name_lbl.offset_top = 8.0
	name_lbl.offset_bottom = 30.0
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", title_col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)

	# 3. Top-Right Reward Badge (with procedural vector Spark icon)
	var rew_hbox := HBoxContainer.new()
	rew_hbox.name = "RewardBox"
	rew_hbox.anchor_left = 1.0
	rew_hbox.anchor_right = 1.0
	rew_hbox.offset_left = -112.0
	rew_hbox.offset_right = -12.0
	rew_hbox.offset_top = 8.0
	rew_hbox.offset_bottom = 30.0
	rew_hbox.alignment = BoxContainer.ALIGNMENT_END
	rew_hbox.add_theme_constant_override("separation", 4)
	rew_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(rew_hbox)

	var bolt_col := Color(0.35, 1.0, 0.60) if completed else Color(1.0, 0.92, 0.25)
	rew_hbox.add_child(_create_spark_icon(15.0, bolt_col))

	var rew_lbl := Label.new()
	rew_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rew_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rew_lbl.text = "+" + str(reward)
	rew_lbl.add_theme_font_size_override("font_size", 13)
	rew_lbl.add_theme_color_override("font_color", bolt_col)
	rew_hbox.add_child(rew_lbl)

	# 4. Quest Description Label
	var desc_lbl := Label.new()
	desc_lbl.name = "QuestDesc"
	desc_lbl.text = q_desc
	desc_lbl.anchor_right = 1.0
	desc_lbl.offset_left = 64.0
	desc_lbl.offset_right = -12.0
	desc_lbl.offset_top = 30.0
	desc_lbl.offset_bottom = 60.0
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_text = true
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", desc_col)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(desc_lbl)

	# 5. Progress Bar & Counter Row
	var prog_bar := ProgressBar.new()
	prog_bar.name = "QuestProgress"
	prog_bar.min_value = 0.0
	prog_bar.max_value = float(target)
	prog_bar.value = float(cur)
	prog_bar.show_percentage = false
	prog_bar.anchor_right = 1.0
	prog_bar.offset_left = 64.0
	prog_bar.offset_right = -106.0
	prog_bar.offset_top = 66.0
	prog_bar.offset_bottom = 78.0
	prog_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pb_bg := StyleBoxFlat.new()
	pb_bg.set_corner_radius_all(6)
	pb_bg.bg_color = Color(0.05, 0.04, 0.12, 0.92)
	pb_bg.set_border_width_all(1)
	pb_bg.set_border_color(Color(0.30, 0.26, 0.45, 0.65))
	var pb_fill := StyleBoxFlat.new()
	pb_fill.set_corner_radius_all(6)
	pb_fill.bg_color = accent_col
	prog_bar.add_theme_stylebox_override("background", pb_bg)
	prog_bar.add_theme_stylebox_override("fill", pb_fill)
	btn.add_child(prog_bar)

	var prog_lbl := Label.new()
	prog_lbl.name = "ProgressText"
	prog_lbl.text = "COMPLETED" if completed else (_format_sparks_compact(cur) + " / " + _format_sparks_compact(target))
	prog_lbl.anchor_left = 1.0
	prog_lbl.anchor_right = 1.0
	prog_lbl.offset_left = -100.0
	prog_lbl.offset_right = -12.0
	prog_lbl.offset_top = 61.0
	prog_lbl.offset_bottom = 83.0
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prog_lbl.clip_text = true
	prog_lbl.add_theme_font_size_override("font_size", 10)
	prog_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.60) if completed else Color(0.90, 0.94, 1.0))
	prog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(prog_lbl)

	return btn


func _on_unlock_bonus_mission_pressed() -> void:
	if _overlay_drag_active or settings.daily_bonus_ad_unlocked or _bonus_mission_ad_loading:
		return
	sfx.play("tap")
	_haptic_tap()
	_bonus_mission_ad_loading = true
	_refresh_shop_screen()

	var on_reward := func():
		_bonus_mission_ad_loading = false
		settings.unlock_daily_bonus_mission()
		sfx.play("unlock")
		_haptic_celebration()
		_refresh_shop_screen()

	var on_dismissed := func():
		_bonus_mission_ad_loading = false
		_refresh_shop_screen()

	# Safety fallback in case ad fails silently or gets stuck
	get_tree().create_timer(12.0).timeout.connect(func():
		if _bonus_mission_ad_loading:
			_bonus_mission_ad_loading = false
			if _shop_screen != null and _shop_screen.visible:
				_refresh_shop_screen()
	)

	if has_node("/root/AdManager"):
		get_node("/root/AdManager").show_rewarded_ad(on_reward, on_dismissed)
	else:
		on_reward.call()


func _build_shop_row(category: String, item_def: Dictionary) -> Button:
	var item_id: String = str(item_def.get("id", ""))
	var item_name: String = str(item_def.get("name", "?"))
	var item_desc: String = str(item_def.get("desc", ""))
	var cost: int = int(item_def.get("cost", 0))
	var item_col: Color = item_def.get("color", Color(0.2, 0.95, 1.0))

	var unlocked := false
	var equipped := false
	match category:
		"trail":
			unlocked = settings.is_trail_unlocked(item_id)
			equipped = (settings.selected_trail == item_id)
		"skin":
			unlocked = settings.is_skin_unlocked(item_id)
			equipped = (settings.selected_skin == item_id)
		"sfx":
			unlocked = settings.is_sfx_pack_unlocked(item_id)
			equipped = (settings.selected_sfx_pack == item_id)

	var can_afford: bool = (settings.sparks >= cost)

	# Use empty button text + clip_contents + MOUSE_FILTER_PASS so mobile touch swipes scroll smoothly
	var btn := Button.new()
	btn.name = "ShopItem_" + item_id
	btn.text = ""
	btn.clip_contents = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.custom_minimum_size = Vector2(0, 86)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var row_style := _btn_style.duplicate()
	var title_col := Color(1.0, 1.0, 1.0)
	var desc_col := Color(0.78, 0.80, 0.90)

	if equipped:
		title_col = Color(1.0, 0.92, 0.30)
		desc_col = Color(0.92, 0.88, 0.72)
		row_style.bg_color = Color(0.16, 0.13, 0.28, 0.95)
		row_style.set_border_width_all(2)
		row_style.set_border_color(Color(1.0, 0.85, 0.20, 0.95))
		row_style.set_shadow_color(Color(1.0, 0.80, 0.15, 0.40))
		row_style.set_shadow_size(8)
	elif unlocked:
		title_col = Color(0.92, 0.97, 1.0)
		row_style.bg_color = Color(0.11, 0.09, 0.22, 0.90)
		row_style.set_border_width_all(2)
		row_style.set_border_color(Color(item_col.r, item_col.g, item_col.b, 0.75))
	elif can_afford:
		title_col = Color(0.35, 1.0, 0.60)
		desc_col = Color(0.75, 0.92, 0.82)
		row_style.bg_color = Color(0.07, 0.19, 0.14, 0.92)
		row_style.set_border_width_all(2)
		row_style.set_border_color(Color(0.25, 1.0, 0.55, 0.90))
		row_style.set_shadow_color(Color(0.15, 0.90, 0.45, 0.30))
		row_style.set_shadow_size(6)
	else:
		title_col = Color(0.78, 0.68, 0.82)
		desc_col = Color(0.58, 0.54, 0.66)
		row_style.bg_color = Color(0.12, 0.08, 0.16, 0.80)
		row_style.set_border_width_all(1)
		row_style.set_border_color(Color(0.50, 0.25, 0.38, 0.55))

	btn.add_theme_stylebox_override("normal", row_style)
	var r_hover := row_style.duplicate()
	r_hover.set_border_color(Color(1, 1, 1, 0.9))
	btn.add_theme_stylebox_override("hover", r_hover)
	btn.add_theme_stylebox_override("pressed", r_hover)
	btn.pressed.connect(_on_shop_item_pressed.bind(category, item_id, cost, item_name))

	# 1. Left visual preview icon (42x42)
	var preview_icon := Control.new()
	preview_icon.name = "PreviewIcon"
	preview_icon.position = Vector2(12.0, 22.0)
	preview_icon.size = Vector2(42.0, 42.0)
	preview_icon.custom_minimum_size = Vector2(42.0, 42.0)
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_icon.draw.connect(_draw_shop_item_preview.bind(preview_icon, category, item_id, item_col, unlocked or can_afford))
	btn.add_child(preview_icon)

	# 2. Item Name Label (top-left, clipped cleanly)
	var name_lbl := Label.new()
	name_lbl.name = "ItemName"
	name_lbl.text = item_name
	name_lbl.anchor_right = 1.0
	name_lbl.offset_left = 64.0
	name_lbl.offset_right = -124.0
	name_lbl.offset_top = 10.0
	name_lbl.offset_bottom = 34.0
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", title_col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)

	# 3. Top-Right Status / Cost Badge (with procedural vector Spark icon)
	var status_hbox := HBoxContainer.new()
	status_hbox.name = "StatusBox"
	status_hbox.anchor_left = 1.0
	status_hbox.anchor_right = 1.0
	status_hbox.offset_left = -122.0
	status_hbox.offset_right = -12.0
	status_hbox.offset_top = 10.0
	status_hbox.offset_bottom = 34.0
	status_hbox.alignment = BoxContainer.ALIGNMENT_END
	status_hbox.add_theme_constant_override("separation", 4)
	status_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(status_hbox)

	var status_lbl := Label.new()
	status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if equipped:
		status_lbl.text = "EQUIPPED"
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30))
		status_hbox.add_child(status_lbl)
	elif unlocked:
		status_lbl.text = "EQUIP"
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		status_hbox.add_child(status_lbl)
	else:
		var bolt_c := Color(0.35, 1.0, 0.60) if can_afford else Color(1.0, 0.85, 0.25)
		status_hbox.add_child(_create_spark_icon(15.0, bolt_c))
		status_lbl.text = _format_number_with_commas(cost)
		status_lbl.add_theme_font_size_override("font_size", 13)
		status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.60) if can_afford else Color(0.95, 0.65, 0.72))
		status_hbox.add_child(status_lbl)

	# 4. Description Label (word-wrapped cleanly inside the card width)
	var desc_lbl := Label.new()
	desc_lbl.name = "ItemDesc"
	desc_lbl.text = item_desc
	desc_lbl.anchor_right = 1.0
	desc_lbl.offset_left = 64.0
	desc_lbl.offset_right = -12.0
	desc_lbl.offset_top = 36.0
	desc_lbl.offset_bottom = 78.0
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_text = true
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_constant_override("line_spacing", 1)
	desc_lbl.add_theme_color_override("font_color", desc_col)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(desc_lbl)

	return btn


func _on_shop_item_pressed(category: String, item_id: String, cost: int, item_name: String) -> void:
	if _overlay_drag_active:
		return

	var unlocked := false
	match category:
		"trail":
			unlocked = settings.is_trail_unlocked(item_id)
		"skin":
			unlocked = settings.is_skin_unlocked(item_id)
		"sfx":
			unlocked = settings.is_sfx_pack_unlocked(item_id)

	if unlocked:
		# Equip item immediately
		match category:
			"trail":
				settings.selected_trail = item_id
				sfx.play("tap")
			"skin":
				settings.selected_skin = item_id
				_apply_board_colors()
				sfx.play("tap")
			"sfx":
				settings.selected_sfx_pack = item_id
				if sfx != null and "active_pack" in sfx:
					sfx.active_pack = item_id
				if sfx != null and sfx.has_method("preview_pack"):
					sfx.preview_pack(item_id)
		settings.save_data()
		_haptic_tap()
		_refresh_shop_screen()
		return

	# Item is locked — check if player has enough Neon Sparks
	if settings.sparks < cost:
		# If it's a sound pack, still let them preview how cool it sounds!
		if category == "sfx" and sfx != null and sfx.has_method("preview_pack"):
			sfx.preview_pack(item_id)
		else:
			sfx.play("wrong")
		_haptic_wrong()
		if _shop_sparks_icon != null and is_instance_valid(_shop_sparks_icon):
			_shop_sparks_icon.visible = true
		if _shop_sparks_label != null and is_instance_valid(_shop_sparks_label):
			_shop_sparks_label.text = "NEED " + _format_sparks_compact(cost - settings.sparks) + " MORE SPARKS!"
			_shop_sparks_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.40))
		return

	# Purchase & auto-equip!
	if settings.unlock_cosmetic(category, item_id, cost):
		if category == "skin":
			_apply_board_colors()
		elif category == "sfx":
			if sfx != null and "active_pack" in sfx:
				sfx.active_pack = item_id
		sfx.play("unlock")
		sfx.play_voice("new_unlock", 80, 0.8)
		_haptic_celebration()
		_refresh_shop_screen()
		if _shop_sparks_icon != null and is_instance_valid(_shop_sparks_icon):
			_shop_sparks_icon.visible = false
		if _shop_sparks_label != null and is_instance_valid(_shop_sparks_label):
			_shop_sparks_label.text = "UNLOCKED: " + item_name + "!"
			_shop_sparks_label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.55))


# =====================================================
# OPTIONS UI
# =====================================================

func _setup_options_ui() -> void:
	# --- "OPTIONS" button under LEADERBOARD on the menu screen ---
	_options_button = Button.new()
	_options_button.name = "OptionsButton"
	_options_button.text = "OPTIONS"
	_options_button.anchor_left = 0.5
	_options_button.anchor_right = 0.5
	_options_button.offset_left = -120.0
	_options_button.offset_right = 120.0
	_options_button.offset_top = 778.0
	_options_button.offset_bottom = 826.0
	_options_button.add_theme_font_size_override("font_size", 25)
	_apply_menu_button_style(_options_button)
	_options_button.pressed.connect(_open_options_screen)
	menu_screen.add_child(_options_button)

	# --- Options overlay screen ---
	_options_screen = Control.new()
	_options_screen.name = "OptionsScreen"
	_options_screen.visible = false
	_options_screen.anchor_right = 1.0
	_options_screen.anchor_bottom = 1.0
	_options_screen.z_index = 50
	add_child(_options_screen)

	_options_backdrop = ColorRect.new()
	_options_backdrop.name = "Backdrop"
	_options_backdrop.color = Color(0, 0, 0, 0.72)
	_options_backdrop.anchor_right = 1.0
	_options_backdrop.anchor_bottom = 1.0
	_options_backdrop.gui_input.connect(_on_options_backdrop_input)
	_options_screen.add_child(_options_backdrop)

	_options_panel = Panel.new()
	_options_panel.name = "Panel"
	_options_panel.add_theme_stylebox_override("panel", _pause_panel_style)
	_options_panel.anchor_left = 0.5
	_options_panel.anchor_right = 0.5
	_options_panel.anchor_top = 0.5
	_options_panel.anchor_bottom = 0.5
	_options_panel.offset_left = -220.0
	_options_panel.offset_right = 220.0
	_options_panel.offset_top = -270.0
	_options_panel.offset_bottom = 270.0
	_options_screen.add_child(_options_panel)
	var panel := _options_panel
	_options_non_zone_controls.clear()

	var title := Label.new()
	title.name = "Title"
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -180.0
	title.offset_right = 180.0
	title.offset_top = 18.0
	title.offset_bottom = 58.0
	panel.add_child(title)
	_options_non_zone_controls.append(title)

	var music_title := Label.new()
	music_title.name = "MusicTitle"
	music_title.text = "MUSIC VOLUME"
	music_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_title.add_theme_font_size_override("font_size", 16)
	music_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	music_title.anchor_left = 0.5
	music_title.anchor_right = 0.5
	music_title.offset_left = -180.0
	music_title.offset_right = 180.0
	music_title.offset_top = 64.0
	music_title.offset_bottom = 88.0
	panel.add_child(music_title)
	_options_non_zone_controls.append(music_title)

	_music_volume_slider = HSlider.new()
	_music_volume_slider.name = "MusicVolumeSlider"
	_music_volume_slider.min_value = 0.0
	_music_volume_slider.max_value = 1.0
	_music_volume_slider.step = 0.05
	_music_volume_slider.value = settings.music_volume
	_music_volume_slider.anchor_left = 0.5
	_music_volume_slider.anchor_right = 0.5
	_music_volume_slider.offset_left = -150.0
	_music_volume_slider.offset_right = 150.0
	_music_volume_slider.offset_top = 92.0
	_music_volume_slider.offset_bottom = 118.0
	_music_volume_slider.value_changed.connect(_on_music_volume_changed)
	panel.add_child(_music_volume_slider)
	_options_non_zone_controls.append(_music_volume_slider)

	_music_volume_label = Label.new()
	_music_volume_label.name = "MusicVolumeLabel"
	_music_volume_label.text = str(int(settings.music_volume * 100)) + "%"
	_music_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_music_volume_label.add_theme_font_size_override("font_size", 18)
	_music_volume_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_music_volume_label.anchor_left = 0.5
	_music_volume_label.anchor_right = 0.5
	_music_volume_label.offset_left = -60.0
	_music_volume_label.offset_right = 60.0
	_music_volume_label.offset_top = 120.0
	_music_volume_label.offset_bottom = 144.0
	panel.add_child(_music_volume_label)
	_options_non_zone_controls.append(_music_volume_label)

	# --- SCREEN ZONE / BOARD POSITION (HEIGHT) ---
	var zone_title := Label.new()
	zone_title.name = "ZoneTitle"
	zone_title.text = "SCREEN ZONE (HEIGHT)"
	zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_title.add_theme_font_size_override("font_size", 16)
	zone_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	zone_title.anchor_left = 0.5
	zone_title.anchor_right = 0.5
	zone_title.offset_left = -180.0
	zone_title.offset_right = 180.0
	zone_title.offset_top = 154.0
	zone_title.offset_bottom = 178.0
	panel.add_child(zone_title)

	_board_offset_slider = HSlider.new()
	_board_offset_slider.name = "BoardOffsetSlider"
	_board_offset_slider.min_value = -100.0
	_board_offset_slider.max_value = 120.0
	_board_offset_slider.step = 5.0
	_board_offset_slider.value = settings.board_vertical_offset
	_board_offset_slider.anchor_left = 0.5
	_board_offset_slider.anchor_right = 0.5
	_board_offset_slider.offset_left = -150.0
	_board_offset_slider.offset_right = 150.0
	_board_offset_slider.offset_top = 182.0
	_board_offset_slider.offset_bottom = 208.0
	_board_offset_slider.value_changed.connect(_on_board_offset_changed)
	_board_offset_slider.drag_started.connect(_on_board_offset_drag_started)
	_board_offset_slider.drag_ended.connect(_on_board_offset_drag_ended)
	panel.add_child(_board_offset_slider)

	_board_offset_label = Label.new()
	_board_offset_label.name = "BoardOffsetLabel"
	_board_offset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_offset_label.add_theme_font_size_override("font_size", 16)
	_board_offset_label.anchor_left = 0.5
	_board_offset_label.anchor_right = 0.5
	_board_offset_label.offset_left = -120.0
	_board_offset_label.offset_right = 120.0
	_board_offset_label.offset_top = 210.0
	_board_offset_label.offset_bottom = 232.0
	panel.add_child(_board_offset_label)
	_update_board_offset_label()

	var reset_offset_btn := Button.new()
	reset_offset_btn.name = "ResetOffsetBtn"
	reset_offset_btn.text = "RESET TO CENTER"
	reset_offset_btn.anchor_left = 0.5
	reset_offset_btn.anchor_right = 0.5
	reset_offset_btn.offset_left = -100.0
	reset_offset_btn.offset_right = 100.0
	reset_offset_btn.offset_top = 238.0
	reset_offset_btn.offset_bottom = 268.0
	reset_offset_btn.add_theme_font_size_override("font_size", 13)
	reset_offset_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	reset_offset_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	reset_offset_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var rst_style := _btn_style.duplicate()
	rst_style.bg_color = Color(0.1, 0.16, 0.26, 0.85)
	rst_style.set_border_color(Color(0.3, 0.6, 0.9, 0.6))
	reset_offset_btn.add_theme_stylebox_override("normal", rst_style)
	var rst_hover := rst_style.duplicate()
	rst_hover.set_border_color(Color(0.5, 0.85, 1.0, 1.0))
	reset_offset_btn.add_theme_stylebox_override("hover", rst_hover)
	reset_offset_btn.add_theme_stylebox_override("pressed", rst_hover)
	reset_offset_btn.pressed.connect(_on_reset_board_offset_pressed)
	panel.add_child(reset_offset_btn)
	_options_non_zone_controls.append(reset_offset_btn)

	# --- HAPTIC VIBRATION & VOICE ANNOUNCER TOGGLE BUTTONS (SIDE BY SIDE) ---
	_haptics_toggle_btn = Button.new()
	_haptics_toggle_btn.name = "HapticsToggleBtn"
	_haptics_toggle_btn.anchor_left = 0.5
	_haptics_toggle_btn.anchor_right = 0.5
	_haptics_toggle_btn.offset_left = -188.0
	_haptics_toggle_btn.offset_right = -6.0
	_haptics_toggle_btn.offset_top = 282.0
	_haptics_toggle_btn.offset_bottom = 330.0
	_haptics_toggle_btn.add_theme_font_size_override("font_size", 14)
	_haptics_toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_haptics_toggle_btn.pressed.connect(_on_haptics_toggle_pressed)
	panel.add_child(_haptics_toggle_btn)
	_options_non_zone_controls.append(_haptics_toggle_btn)
	_update_haptics_btn_style()

	_announcer_toggle_btn = Button.new()
	_announcer_toggle_btn.name = "AnnouncerToggleBtn"
	_announcer_toggle_btn.anchor_left = 0.5
	_announcer_toggle_btn.anchor_right = 0.5
	_announcer_toggle_btn.offset_left = 6.0
	_announcer_toggle_btn.offset_right = 188.0
	_announcer_toggle_btn.offset_top = 282.0
	_announcer_toggle_btn.offset_bottom = 330.0
	_announcer_toggle_btn.add_theme_font_size_override("font_size", 14)
	_announcer_toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_announcer_toggle_btn.pressed.connect(_on_announcer_toggle_pressed)
	panel.add_child(_announcer_toggle_btn)
	_options_non_zone_controls.append(_announcer_toggle_btn)
	_update_announcer_btn_style()

	# --- HOW TO PLAY TUTORIAL BUTTON ---
	var how_to_btn := Button.new()
	how_to_btn.name = "HowToPlayBtn"
	how_to_btn.text = "HOW TO PLAY"
	how_to_btn.anchor_left = 0.5
	how_to_btn.anchor_right = 0.5
	how_to_btn.offset_left = -150.0
	how_to_btn.offset_right = 150.0
	how_to_btn.offset_top = 342.0
	how_to_btn.offset_bottom = 390.0
	how_to_btn.add_theme_font_size_override("font_size", 18)
	how_to_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	how_to_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	how_to_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h_style := _btn_style.duplicate()
	h_style.bg_color = Color(0.08, 0.22, 0.35, 0.9)
	h_style.set_border_color(Color(0.2, 0.8, 1.0, 0.85))
	how_to_btn.add_theme_stylebox_override("normal", h_style)
	var h_hover := h_style.duplicate()
	h_hover.set_border_color(Color(1, 1, 1, 1))
	how_to_btn.add_theme_stylebox_override("hover", h_hover)
	how_to_btn.add_theme_stylebox_override("pressed", h_hover)
	how_to_btn.pressed.connect(func():
		_close_options_screen()
		_walkthrough_from_options = true
		_start_dynamic_walkthrough()
	)
	panel.add_child(how_to_btn)
	_options_non_zone_controls.append(how_to_btn)

	# --- RESET GAME PROGRESS BUTTON ---
	_reset_game_btn = Button.new()
	_reset_game_btn.name = "ResetGameBtn"
	_reset_game_btn.text = "RESET GAME DATA"
	_reset_game_btn.anchor_left = 0.5
	_reset_game_btn.anchor_right = 0.5
	_reset_game_btn.offset_left = -150.0
	_reset_game_btn.offset_right = 150.0
	_reset_game_btn.offset_top = 402.0
	_reset_game_btn.offset_bottom = 450.0
	_reset_game_btn.add_theme_font_size_override("font_size", 18)
	_reset_game_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45))
	_reset_game_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.7))
	_reset_game_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var r_style := _btn_style.duplicate()
	r_style.bg_color = Color(0.35, 0.08, 0.12, 0.9)
	r_style.set_border_color(Color(0.9, 0.25, 0.35, 0.8))
	_reset_game_btn.add_theme_stylebox_override("normal", r_style)
	var r_hover := r_style.duplicate()
	r_hover.set_border_color(Color(1.0, 0.5, 0.6, 1.0))
	_reset_game_btn.add_theme_stylebox_override("hover", r_hover)
	_reset_game_btn.add_theme_stylebox_override("pressed", r_hover)
	_reset_game_btn.pressed.connect(_on_reset_game_pressed)
	panel.add_child(_reset_game_btn)
	_options_non_zone_controls.append(_reset_game_btn)

	# --- CLOSE BUTTON ---
	var close_btn := Button.new()
	close_btn.name = "OptionsCloseBtn"
	close_btn.text = "CLOSE"
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.offset_left = -150.0
	close_btn.offset_right = 150.0
	close_btn.offset_top = 462.0
	close_btn.offset_bottom = 510.0
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cls_style := _btn_style.duplicate()
	cls_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	cls_style.set_border_color(Color(0.4, 0.6, 0.8, 0.7))
	close_btn.add_theme_stylebox_override("normal", cls_style)
	var cls_hover := cls_style.duplicate()
	cls_hover.set_border_color(Color(1, 1, 1, 1))
	close_btn.add_theme_stylebox_override("hover", cls_hover)
	close_btn.add_theme_stylebox_override("pressed", cls_hover)
	close_btn.pressed.connect(_close_options_screen)
	panel.add_child(close_btn)
	_options_non_zone_controls.append(close_btn)

	_setup_reset_confirm_modal()


func _setup_reset_confirm_modal() -> void:
	_reset_confirm_modal = Control.new()
	_reset_confirm_modal.name = "ResetConfirmModal"
	_reset_confirm_modal.visible = false
	_reset_confirm_modal.anchor_right = 1.0
	_reset_confirm_modal.anchor_bottom = 1.0
	_reset_confirm_modal.z_index = 60
	_options_screen.add_child(_reset_confirm_modal)

	var confirm_backdrop := ColorRect.new()
	confirm_backdrop.name = "ConfirmBackdrop"
	confirm_backdrop.color = Color(0, 0, 0, 0.6)
	confirm_backdrop.anchor_right = 1.0
	confirm_backdrop.anchor_bottom = 1.0
	_reset_confirm_modal.add_child(confirm_backdrop)

	var confirm_panel := Panel.new()
	confirm_panel.name = "ConfirmPanel"
	var p_style := StyleBoxFlat.new()
	p_style.set_corner_radius_all(20)
	p_style.bg_color = Color(0.18, 0.08, 0.14, 0.98)
	p_style.set_border_width_all(3)
	p_style.set_border_color(Color(1.0, 0.3, 0.35, 0.9))
	p_style.set_shadow_size(12)
	p_style.set_shadow_color(Color(1.0, 0.1, 0.2, 0.4))
	confirm_panel.add_theme_stylebox_override("panel", p_style)
	confirm_panel.anchor_left = 0.5
	confirm_panel.anchor_right = 0.5
	confirm_panel.anchor_top = 0.5
	confirm_panel.anchor_bottom = 0.5
	confirm_panel.offset_left = -200.0
	confirm_panel.offset_right = 200.0
	confirm_panel.offset_top = -140.0
	confirm_panel.offset_bottom = 140.0
	_reset_confirm_modal.add_child(confirm_panel)

	var warn_title := Label.new()
	warn_title.text = "WARNING"
	warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_title.add_theme_font_size_override("font_size", 28)
	warn_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
	warn_title.anchor_left = 0.5
	warn_title.anchor_right = 0.5
	warn_title.offset_left = -160.0
	warn_title.offset_right = 160.0
	warn_title.offset_top = 18.0
	warn_title.offset_bottom = 54.0
	confirm_panel.add_child(warn_title)

	var warn_body := Label.new()
	warn_body.text = "This will erase your high score,\nreset unlocked songs and themes,\nand replay the tutorial.\n\nAre you sure?"
	warn_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warn_body.add_theme_font_size_override("font_size", 14)
	warn_body.add_theme_color_override("font_color", Color(0.95, 0.9, 0.9))
	warn_body.anchor_left = 0.5
	warn_body.anchor_right = 0.5
	warn_body.offset_left = -170.0
	warn_body.offset_right = 170.0
	warn_body.offset_top = 55.0
	warn_body.offset_bottom = 190.0
	confirm_panel.add_child(warn_body)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "CANCEL"
	cancel_btn.anchor_left = 0.5
	cancel_btn.anchor_right = 0.5
	cancel_btn.offset_left = -160.0
	cancel_btn.offset_right = -10.0
	cancel_btn.offset_top = 200.0
	cancel_btn.offset_bottom = 250.0
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	cancel_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var c_style := _btn_style.duplicate()
	c_style.bg_color = Color(0.12, 0.12, 0.2, 0.9)
	cancel_btn.add_theme_stylebox_override("normal", c_style)
	cancel_btn.pressed.connect(_close_reset_confirm_modal)
	confirm_panel.add_child(cancel_btn)

	var delete_btn := Button.new()
	delete_btn.name = "DeleteBtn"
	delete_btn.text = "DELETE"
	delete_btn.anchor_left = 0.5
	delete_btn.anchor_right = 0.5
	delete_btn.offset_left = 10.0
	delete_btn.offset_right = 160.0
	delete_btn.offset_top = 200.0
	delete_btn.offset_bottom = 250.0
	delete_btn.add_theme_font_size_override("font_size", 16)
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
	delete_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var d_style := _btn_style.duplicate()
	d_style.bg_color = Color(0.45, 0.1, 0.15, 0.9)
	d_style.set_border_color(Color(1.0, 0.3, 0.35, 0.9))
	delete_btn.add_theme_stylebox_override("normal", d_style)
	delete_btn.pressed.connect(_execute_reset_game)
	confirm_panel.add_child(delete_btn)


func _on_haptics_toggle_pressed() -> void:
	settings.haptics_enabled = not settings.haptics_enabled
	settings.save_data()
	_update_haptics_btn_style()
	if settings.haptics_enabled:
		_haptic_tap()
	else:
		sfx.play("tap")


func _update_haptics_btn_style() -> void:
	if _haptics_toggle_btn == null or not is_instance_valid(_haptics_toggle_btn):
		return
	if settings.haptics_enabled:
		_haptics_toggle_btn.text = "HAPTICS: ON"
		_haptics_toggle_btn.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55))
		var h_style := _btn_style.duplicate()
		h_style.bg_color = Color(0.08, 0.22, 0.12, 0.9)
		h_style.set_border_color(Color(0.2, 0.9, 0.5, 0.8))
		_haptics_toggle_btn.add_theme_stylebox_override("normal", h_style)
	else:
		_haptics_toggle_btn.text = "HAPTICS: OFF"
		_haptics_toggle_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		var h_style := _btn_style.duplicate()
		h_style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
		h_style.set_border_color(Color(0.4, 0.4, 0.5, 0.6))
		_haptics_toggle_btn.add_theme_stylebox_override("normal", h_style)


func _on_announcer_toggle_pressed() -> void:
	settings.announcer_enabled = not settings.announcer_enabled
	if sfx != null and "announcer_enabled" in sfx:
		sfx.announcer_enabled = settings.announcer_enabled
	settings.save_data()
	_update_announcer_btn_style()
	_haptic_tap()
	if settings.announcer_enabled:
		sfx.play_voice("frenzy_mode", 90, 0.1)
	else:
		if sfx != null and sfx.has_method("stop_voice"):
			sfx.stop_voice()
		sfx.play("tap")


func _update_announcer_btn_style() -> void:
	if _announcer_toggle_btn == null or not is_instance_valid(_announcer_toggle_btn):
		return
	if settings.announcer_enabled:
		_announcer_toggle_btn.text = "ANNOUNCER: ON"
		_announcer_toggle_btn.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55))
		var a_style := _btn_style.duplicate()
		a_style.bg_color = Color(0.08, 0.22, 0.12, 0.9)
		a_style.set_border_color(Color(0.2, 0.9, 0.5, 0.8))
		_announcer_toggle_btn.add_theme_stylebox_override("normal", a_style)
	else:
		_announcer_toggle_btn.text = "ANNOUNCER: OFF"
		_announcer_toggle_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		var a_style := _btn_style.duplicate()
		a_style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
		a_style.set_border_color(Color(0.4, 0.4, 0.5, 0.6))
		_announcer_toggle_btn.add_theme_stylebox_override("normal", a_style)


func _on_reset_game_pressed() -> void:
	sfx.play("tap")
	if _reset_confirm_modal != null:
		_reset_confirm_modal.visible = true


func _close_reset_confirm_modal() -> void:
	sfx.play("tap")
	if _reset_confirm_modal != null:
		_reset_confirm_modal.visible = false


func _execute_reset_game() -> void:
	sfx.play("wrong")
	_haptic_danger()
	settings.reset_game_data()
	sfx.active_pack = settings.selected_sfx_pack
	if "announcer_enabled" in sfx:
		sfx.announcer_enabled = settings.announcer_enabled
	_apply_theme()
	_apply_board_position()
	_play_selected_song()
	_close_reset_confirm_modal()
	_close_options_screen()
	_show_remap_banner("GAME DATA RESET")
	_update_high_score_display()
	_update_sparks_displays()
	frenzy_charges = 0
	_update_frenzy_charge_ui()


func _on_options_backdrop_input(event: InputEvent) -> void:
	if _board_zone_preview_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_options_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_close_options_screen()


func _open_options_screen() -> void:
	sfx.play("tap")
	_exit_board_zone_preview(true)
	_refresh_options_screen()
	_options_screen.visible = true


func _close_options_screen() -> void:
	sfx.play("tap")
	_exit_board_zone_preview(true)
	_options_screen.visible = false
	settings.save_data()
	_set_state(settings.GameState.MENU)


func _refresh_options_screen() -> void:
	if _music_volume_slider != null and is_instance_valid(_music_volume_slider):
		_music_volume_slider.value = settings.music_volume
	if _music_volume_label != null and is_instance_valid(_music_volume_label):
		_music_volume_label.text = str(int(settings.music_volume * 100)) + "%"
	if _board_offset_slider != null and is_instance_valid(_board_offset_slider):
		_board_offset_slider.value = settings.board_vertical_offset
	_update_board_offset_label()
	_update_haptics_btn_style()
	_update_announcer_btn_style()


func _on_music_volume_changed(val: float) -> void:
	settings.music_volume = val
	_update_music_volume()
	if _music_volume_label != null:
		_music_volume_label.text = str(int(val * 100)) + "%"


func _on_board_offset_drag_started() -> void:
	_board_zone_dragging = true
	_enter_board_zone_preview()


func _on_board_offset_drag_ended(_value_changed: bool) -> void:
	_board_zone_dragging = false
	_board_zone_preview_timer = 0.9


func _on_board_offset_changed(val: float) -> void:
	settings.board_vertical_offset = val
	_apply_board_position()
	_update_board_offset_label()
	if _options_screen != null and _options_screen.visible:
		_enter_board_zone_preview()
		if not _board_zone_dragging:
			_board_zone_preview_timer = 1.0


func _on_reset_board_offset_pressed() -> void:
	sfx.play("tap")
	settings.board_vertical_offset = 0.0
	if _board_offset_slider != null and is_instance_valid(_board_offset_slider):
		_board_offset_slider.value = 0.0
	_apply_board_position()
	_update_board_offset_label()
	if _options_screen != null and _options_screen.visible:
		_enter_board_zone_preview()
		_board_zone_dragging = false
		_board_zone_preview_timer = 0.8


func _enter_board_zone_preview() -> void:
	if _options_screen == null or not _options_screen.visible:
		return
	_board_zone_preview_active = true

	# Show game screen and board, hide gameplay HUD
	game_screen.visible = true
	var hud: Control = game_screen.get_node_or_null("GameHUD") as Control
	if hud != null:
		hud.visible = false
	menu_screen.visible = false

	if _board_zone_preview_tween != null and _board_zone_preview_tween.is_valid():
		_board_zone_preview_tween.kill()
	_board_zone_preview_tween = create_tween().set_parallel(true)

	if _options_backdrop != null:
		_board_zone_preview_tween.tween_property(_options_backdrop, "color:a", 0.0, 0.2)
	if _options_panel != null:
		_board_zone_preview_tween.tween_property(_options_panel, "self_modulate:a", 0.0, 0.2)
		_board_zone_preview_tween.tween_property(_options_panel, "offset_top", -490.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_board_zone_preview_tween.tween_property(_options_panel, "offset_bottom", 50.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for ctrl: Control in _options_non_zone_controls:
		if ctrl != null and is_instance_valid(ctrl):
			_board_zone_preview_tween.tween_property(ctrl, "modulate:a", 0.0, 0.15)
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_board_zone_preview(instant: bool = false) -> void:
	_board_zone_preview_active = false
	_board_zone_dragging = false
	_board_zone_preview_timer = 0.0

	if _board_zone_preview_tween != null and _board_zone_preview_tween.is_valid():
		_board_zone_preview_tween.kill()
		_board_zone_preview_tween = null

	var hud: Control = game_screen.get_node_or_null("GameHUD") as Control
	if hud != null:
		hud.visible = true

	if instant:
		if _options_backdrop != null:
			_options_backdrop.color.a = 0.72
		if _options_panel != null:
			_options_panel.self_modulate.a = 1.0
			_options_panel.offset_top = -270.0
			_options_panel.offset_bottom = 270.0
		for ctrl: Control in _options_non_zone_controls:
			if ctrl != null and is_instance_valid(ctrl):
				ctrl.modulate.a = 1.0
				ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
		if state == GameSettings.GameState.MENU:
			menu_screen.visible = true
			game_screen.visible = false
		_update_board_offset_label()
		return

	_board_zone_preview_tween = create_tween().set_parallel(true)
	if _options_backdrop != null:
		_board_zone_preview_tween.tween_property(_options_backdrop, "color:a", 0.72, 0.25)
	if _options_panel != null:
		_board_zone_preview_tween.tween_property(_options_panel, "self_modulate:a", 1.0, 0.25)
		_board_zone_preview_tween.tween_property(_options_panel, "offset_top", -270.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_board_zone_preview_tween.tween_property(_options_panel, "offset_bottom", 270.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for ctrl: Control in _options_non_zone_controls:
		if ctrl != null and is_instance_valid(ctrl):
			_board_zone_preview_tween.tween_property(ctrl, "modulate:a", 1.0, 0.25)
			ctrl.mouse_filter = Control.MOUSE_FILTER_STOP

	_board_zone_preview_tween.chain().tween_callback(func():
		if state == GameSettings.GameState.MENU:
			menu_screen.visible = true
			game_screen.visible = false
		_update_board_offset_label()
	)


func _update_board_offset_label() -> void:
	if _board_offset_label == null or not is_instance_valid(_board_offset_label):
		return
	var offset: float = settings.board_vertical_offset
	var prefix: String = "[LIVE PREVIEW] " if _board_zone_preview_active else ""
	if abs(offset) < 0.1:
		_board_offset_label.text = prefix + "CENTER (DEFAULT)"
		_board_offset_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif offset < 0:
		_board_offset_label.text = prefix + "^ UP " + str(int(abs(offset))) + "px"
		_board_offset_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	else:
		_board_offset_label.text = prefix + "v DOWN " + str(int(offset)) + "px"
		_board_offset_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))


# =====================================================
# TUTORIAL VISUAL UI
# =====================================================

func _setup_tutorial_ui() -> void:
	var content: Control = $TutorialScreen/TutorialPanel.get_node_or_null("TutorialContent") as Control
	if content == null:
		return

	# Clear any previous children
	for child in content.get_children():
		child.queue_free()

	# Vertical Scroll Container allowing all mechanics to be displayed cleanly
	# Vertical Scroll Container allowing all mechanics to be displayed cleanly
	var scroll := ScrollContainer.new()
	scroll.name = "TutorialScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 4
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 8.0
	scroll.offset_right = -8.0
	scroll.offset_top = 0.0
	scroll.offset_bottom = 0.0
	scroll.gui_input.connect(_on_tutorial_scroll_input.bind(scroll))
	content.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "TutorialVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# -------------------------------------------------------------
	# 1. BASIC SWIPES, TIMING TIERS & OVERDRIVE FEVER
	# -------------------------------------------------------------
	var swipe_card := _create_tutorial_card(Color(0.08, 0.12, 0.22, 0.95), Color(0.25, 0.75, 1.0, 0.9), 285.0)
	vbox.add_child(swipe_card)

	var swipe_title := _create_tutorial_card_title("1. SWIPES, TIMING & OVERDRIVE FEVER", Color(0.3, 0.85, 1.0))
	swipe_card.add_child(swipe_title)

	# Visual Direction Matching Diagram (Centered)
	var diag_container := Control.new()
	diag_container.name = "DiagramContainer"
	diag_container.custom_minimum_size = Vector2(160, 110)
	diag_container.anchor_left = 0.5
	diag_container.anchor_right = 0.5
	diag_container.offset_left = -80.0
	diag_container.offset_right = 80.0
	diag_container.offset_top = 34.0
	diag_container.offset_bottom = 144.0
	diag_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swipe_card.add_child(diag_container)

	var diag_center := Vector2(80, 55)
	var sq_sz := Vector2(30, 30)
	var dist := 38.0

	var square_defs := {
		"up": {"pos": diag_center + Vector2(0, -dist), "col": Color(0.88, 0.22, 0.35)},
		"down": {"pos": diag_center + Vector2(0, dist), "col": Color(0.82, 0.72, 0.06)},
		"left": {"pos": diag_center + Vector2(-dist, 0), "col": Color(0.10, 0.70, 0.38)},
		"right": {"pos": diag_center + Vector2(dist, 0), "col": Color(0.12, 0.46, 0.88)},
	}
	for s_key in square_defs:
		var s_data: Dictionary = square_defs[s_key]
		var p := Panel.new()
		p.size = sq_sz
		p.position = (s_data["pos"] as Vector2) - sq_sz / 2.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.bg_color = s_data["col"] as Color
		style.set_border_width_all(2)
		style.set_border_color(Color(1, 1, 1, 0.85))
		p.add_theme_stylebox_override("panel", style)
		diag_container.add_child(p)

	# Center Square (Matching Up)
	var center_p := Panel.new()
	center_p.size = Vector2(34, 34)
	center_p.position = diag_center - center_p.size / 2.0
	center_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c_style := StyleBoxFlat.new()
	c_style.set_corner_radius_all(8)
	c_style.bg_color = Color(0.88, 0.22, 0.35)
	c_style.set_border_width_all(2)
	c_style.set_border_color(Color(1, 1, 1, 1))
	c_style.set_shadow_size(6)
	c_style.set_shadow_color(Color(1, 1, 1, 0.5))
	center_p.add_theme_stylebox_override("panel", c_style)
	diag_container.add_child(center_p)

	var swipe_hint := Label.new()
	swipe_hint.text = "^ SWIPE UP TOWARD MATCHING COLOR! ^"
	swipe_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swipe_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swipe_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swipe_hint.add_theme_font_size_override("font_size", 12)
	swipe_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	swipe_hint.anchor_right = 1.0
	swipe_hint.offset_left = 10.0
	swipe_hint.offset_right = -10.0
	swipe_hint.offset_top = 150.0
	swipe_hint.offset_bottom = 170.0
	swipe_card.add_child(swipe_hint)

	var swipe_desc := _create_tutorial_card_body(
		"* Match center square color to outer direction.\n" +
		"* Instant swipes earn BLAZING! (1.5x) or PERFECT! (1.25x) bonus!\n" +
		"* Last-moment swipes trigger CLUTCH SAVE! bonus points!\n" +
		"* Every swipe charges your ⚡ OVERDRIVE FEVER meter — reach 100% to automatically unleash Overdrive Frenzy!"
	)
	swipe_desc.offset_left = 16.0
	swipe_desc.offset_right = -16.0
	swipe_desc.offset_top = 174.0
	swipe_desc.offset_bottom = 278.0
	swipe_card.add_child(swipe_desc)

	# -------------------------------------------------------------
	# 2. HOLD SQUARES (HOLD MODE)
	# -------------------------------------------------------------
	var hold_card := _create_tutorial_card(Color(0.06, 0.14, 0.24, 0.95), Color(0.2, 0.95, 1.0, 0.9), 195.0)
	vbox.add_child(hold_card)

	var hold_title := _create_tutorial_card_title("2. HOLD SQUARES (HOLD MODE)", Color(0.2, 0.95, 1.0))
	hold_card.add_child(hold_title)

	var hold_icon := Panel.new()
	hold_icon.size = Vector2(44, 44)
	hold_icon.position = Vector2(14, 42)
	hold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hold_icon.draw.connect(func(): _draw_tutorial_hold_icon(hold_icon))
	hold_card.add_child(hold_icon)

	var hold_desc := _create_tutorial_card_body(
		"* When pulsing corner brackets appear on the board:\n" +
		"* Swipe & HOLD your finger in that direction!\n" +
		"* Charge up to 2 SECONDS for MASSIVE points & +22% Fever!\n" +
		"* Auto-completes when charged or upon finger release."
	)
	hold_desc.offset_left = 68.0
	hold_desc.offset_right = -14.0
	hold_desc.offset_top = 36.0
	hold_desc.offset_bottom = 185.0
	hold_card.add_child(hold_desc)

	# -------------------------------------------------------------
	# 3. 2X DOUBLE-DASH RUSH (NEW MECHANIC)
	# -------------------------------------------------------------
	var double_card := _create_tutorial_card(Color(0.18, 0.06, 0.18, 0.95), Color(1.0, 0.35, 0.85, 0.95), 195.0)
	vbox.add_child(double_card)

	var double_title := _create_tutorial_card_title("3. 2X DOUBLE-DASH RUSH", Color(1.0, 0.45, 0.90))
	double_card.add_child(double_title)

	var double_icon := Panel.new()
	double_icon.size = Vector2(44, 44)
	double_icon.position = Vector2(14, 42)
	double_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	double_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	double_icon.draw.connect(func(): _draw_tutorial_double_rush_icon(double_icon))
	double_card.add_child(double_icon)

	var double_desc := _create_tutorial_card_body(
		"* When twin neon rings & ⚡ 2X DOUBLE RUSH! (1/2) appear:\n" +
		"* Swipe the 1st matching square — the center immediately shifts to a 2nd color!\n" +
		"* Swipe the 2nd square (2/2) to detonate a 2.5x SCORE BURST!"
	)
	double_desc.offset_left = 68.0
	double_desc.offset_right = -14.0
	double_desc.offset_top = 36.0
	double_desc.offset_bottom = 185.0
	double_card.add_child(double_desc)

	# -------------------------------------------------------------
	# 4. FRENZY POWER-UP & OVERDRIVE FRENZY
	# -------------------------------------------------------------
	var frenzy_card := _create_tutorial_card(Color(0.18, 0.12, 0.04, 0.95), Color(1.0, 0.85, 0.1, 0.9), 195.0)
	vbox.add_child(frenzy_card)

	var frenzy_title := _create_tutorial_card_title("4. FRENZY POWER-UP & OVERDRIVE", Color(1.0, 0.9, 0.2))
	frenzy_card.add_child(frenzy_title)

	var frenzy_icon := Panel.new()
	frenzy_icon.size = Vector2(44, 44)
	frenzy_icon.position = Vector2(14, 42)
	frenzy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frenzy_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frenzy_icon.draw.connect(func(): _draw_powerup_icon(frenzy_icon, "frenzy"))
	frenzy_card.add_child(frenzy_icon)

	var frenzy_desc := _create_tutorial_card_body(
		"* Swipe the LIGHTNING BOLT or hit 100% Fever for Frenzy!\n" +
		"* No countdown timer limit during Frenzy — swipe freely!\n" +
		"* Dynamic PINK square hops every second for 3x Super Score!\n" +
		"* Combined score multipliers reach up to 12x!"
	)
	frenzy_desc.offset_left = 68.0
	frenzy_desc.offset_right = -14.0
	frenzy_desc.offset_top = 36.0
	frenzy_desc.offset_bottom = 185.0
	frenzy_card.add_child(frenzy_desc)

	# -------------------------------------------------------------
	# 5. FRENZY TIME BOOSTER (+5s STACKABLE)
	# -------------------------------------------------------------
	var boost_card := _create_tutorial_card(Color(0.06, 0.16, 0.22, 0.95), Color(0.2, 0.95, 1.0, 0.95), 195.0)
	vbox.add_child(boost_card)

	var boost_title := _create_tutorial_card_title("5. TIME BOOSTER (+5s CHARGES)", Color(0.2, 0.95, 1.0))
	boost_card.add_child(boost_title)

	var boost_icon := Panel.new()
	boost_icon.size = Vector2(44, 44)
	boost_icon.position = Vector2(14, 42)
	boost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boost_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	boost_icon.draw.connect(func(): _draw_powerup_icon(boost_icon, "frenzy_boost"))
	boost_card.add_child(boost_icon)

	var boost_desc := _create_tutorial_card_body(
		"* Swipe to the CYAN CHRONO BOLT (+) to gain +1 Charge!\n" +
		"* Stacks in your HUD under BEST score (e.g. +5s, +10s, +15s)!\n" +
		"* Entering Frenzy consumes ALL stacked charges, extending\n" +
		"  your Frenzy duration by +5s per charge!"
	)
	boost_desc.offset_left = 68.0
	boost_desc.offset_right = -14.0
	boost_desc.offset_top = 36.0
	boost_desc.offset_bottom = 185.0
	boost_card.add_child(boost_desc)

	# -------------------------------------------------------------
	# 6. AEGIS NEON SHIELD (NEW POWER-UP)
	# -------------------------------------------------------------
	var shield_card := _create_tutorial_card(Color(0.04, 0.18, 0.15, 0.95), Color(0.15, 1.0, 0.78, 0.95), 195.0)
	vbox.add_child(shield_card)

	var shield_title := _create_tutorial_card_title("6. AEGIS NEON SHIELD (BARRIER)", Color(0.2, 1.0, 0.80))
	shield_card.add_child(shield_title)

	var shield_icon := Panel.new()
	shield_icon.size = Vector2(44, 44)
	shield_icon.position = Vector2(14, 42)
	shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	shield_icon.draw.connect(func(): _draw_powerup_icon(shield_icon, "shield"))
	shield_card.add_child(shield_icon)

	var shield_desc := _create_tutorial_card_body(
		"* Swipe the EMERALD SHIELD to activate a protective barrier!\n" +
		"* Surrounds the center square with a rotating octagonal halo.\n" +
		"* Automatically blocks your next wrong swipe or timeout —\n" +
		"  saving BOTH your Heart and your Combo Streak!"
	)
	shield_desc.offset_left = 68.0
	shield_desc.offset_right = -14.0
	shield_desc.offset_top = 36.0
	shield_desc.offset_bottom = 185.0
	shield_card.add_child(shield_desc)

	# -------------------------------------------------------------
	# 7. NEON SPARK JACKPOT (NEW POWER-UP)
	# -------------------------------------------------------------
	var jackpot_card := _create_tutorial_card(Color(0.18, 0.12, 0.08, 0.95), Color(1.0, 0.78, 0.2, 0.95), 185.0)
	vbox.add_child(jackpot_card)

	var jackpot_title := _create_tutorial_card_title("7. NEON SPARK JACKPOT (DIAMOND)", Color(1.0, 0.88, 0.25))
	jackpot_card.add_child(jackpot_title)

	var jackpot_icon := Panel.new()
	jackpot_icon.size = Vector2(44, 44)
	jackpot_icon.position = Vector2(14, 44)
	jackpot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jackpot_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	jackpot_icon.draw.connect(func(): _draw_powerup_icon(jackpot_icon, "spark_jackpot"))
	jackpot_card.add_child(jackpot_icon)

	var jackpot_desc := _create_tutorial_card_body(
		"* 💎 SPARK JACKPOT: Swipe the Golden Diamond to bank\n" +
		"  +5 NEON SPARKS immediately mid-run + 500xMult score!\n" +
		"* 🔥 STREAK MILESTONES: Every 50 Streak also awards\n" +
		"  +3 Bonus Sparks and a massive score burst!"
	)
	jackpot_desc.offset_left = 68.0
	jackpot_desc.offset_right = -14.0
	jackpot_desc.offset_top = 36.0
	jackpot_desc.offset_bottom = 175.0
	jackpot_card.add_child(jackpot_desc)

	# -------------------------------------------------------------
	# 8. SHUFFLE & SURVIVAL CARD
	# -------------------------------------------------------------
	var shuffle_card := _create_tutorial_card(Color(0.14, 0.10, 0.20, 0.95), Color(0.85, 0.5, 1.0, 0.85), 165.0)
	vbox.add_child(shuffle_card)

	var shuffle_title := _create_tutorial_card_title("8. SHUFFLE & EXTRA LIVES", Color(0.9, 0.65, 1.0))
	shuffle_card.add_child(shuffle_title)

	var shuffle_desc := _create_tutorial_card_body(
		"* You start with 3 Hearts. Wrong swipes or timeouts cost 1 life.\n" +
		"* Directions SHUFFLE periodically as score climbs — stay sharp!\n" +
		"* Watch a rewarded ad on Game Over to revive with +3 lives!"
	)
	shuffle_desc.offset_left = 16.0
	shuffle_desc.offset_right = -16.0
	shuffle_desc.offset_top = 36.0
	shuffle_desc.offset_bottom = 155.0
	shuffle_card.add_child(shuffle_desc)

	# -------------------------------------------------------------
	# 9. STORY MODE & BOSS BATTLES
	# -------------------------------------------------------------
	var story_card := _create_tutorial_card(Color(0.10, 0.06, 0.24, 0.95), Color(0.40, 0.92, 1.0, 0.95), 185.0)
	vbox.add_child(story_card)

	var story_tut_title := _create_tutorial_card_title("9. STORY MODE & BOSS BATTLES", Color(0.45, 0.95, 1.0))
	story_card.add_child(story_tut_title)

	var story_tut_desc := _create_tutorial_card_body(
		"* In STORY MODE, the center square is WHITE — swipe it toward ANY color!\n" +
		"* Each color fires a laser at the matching colored Boss body part to drain Boss HP.\n" +
		"* 💣 WATCH OUT FOR BOMBS: The Boss throws a random bomb onto one color each turn. Swiping a bomb costs 1 life! Bombs vanish after a safe swipe."
	)
	story_tut_desc.offset_left = 16.0
	story_tut_desc.offset_right = -16.0
	story_tut_desc.offset_top = 36.0
	story_tut_desc.offset_bottom = 175.0
	story_card.add_child(story_tut_desc)

	# -------------------------------------------------------------
	# 10. PHOTOSENSITIVITY & EPILEPSY WARNING
	# -------------------------------------------------------------
	var warning_card := _create_tutorial_card(Color(0.20, 0.12, 0.06, 0.95), Color(1.0, 0.65, 0.2, 0.9), 160.0)
	vbox.add_child(warning_card)

	var warning_title := _create_tutorial_card_title("⚠ PHOTOSENSITIVITY & EPILEPSY WARNING", Color(1.0, 0.8, 0.25))
	warning_card.add_child(warning_title)

	var warning_desc := _create_tutorial_card_body(
		"* This game contains flashing lights, rapid color transitions, and pulsing visual effects that may trigger discomfort or seizures in individuals with photosensitive epilepsy.\n" +
		"* If you experience dizziness, altered vision, or muscle twitches, immediately discontinue playing and consult a medical professional."
	)
	warning_desc.offset_left = 16.0
	warning_desc.offset_right = -16.0
	warning_desc.offset_top = 36.0
	warning_desc.offset_bottom = 150.0
	warning_card.add_child(warning_desc)

	# Bottom spacer so last card doesn't clip against bottom
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(bottom_spacer)


func _create_tutorial_card(bg_col: Color, border_col: Color, min_height: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, min_height)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(14)
	s.bg_color = bg_col
	s.set_border_width_all(2)
	s.set_border_color(border_col)
	s.set_shadow_size(6)
	s.set_shadow_color(Color(border_col.r, border_col.g, border_col.b, 0.3))
	p.add_theme_stylebox_override("panel", s)
	return p


func _create_tutorial_card_title(title_text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = title_text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.16, 1.0))
	l.add_theme_constant_override("outline_size", 4)
	l.anchor_right = 1.0
	l.offset_left = 10.0
	l.offset_right = -10.0
	l.offset_top = 8.0
	l.offset_bottom = 30.0
	return l


func _create_tutorial_card_body(body_text: String) -> Label:
	var l := Label.new()
	l.text = body_text
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	l.add_theme_constant_override("line_spacing", 4)
	l.anchor_right = 1.0
	l.offset_right = -14.0
	return l


func _draw_tutorial_hold_icon(panel: Panel) -> void:
	var c := panel.size / 2.0
	var r := 19.0
	# Pulsing cyan ring
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08
	panel.draw_arc(c, r * pulse + 3.0, 0.0, TAU, 32, Color(0.2, 0.95, 1.0, 0.25), 4.0, true)
	panel.draw_arc(c, r, 0.0, TAU, 32, Color(0.2, 0.95, 1.0, 0.95), 3.0, true)
	# Corner brackets
	var b := 16.0
	var b_len := 5.0
	var b_col := Color(0.2, 0.95, 1.0, 0.85)
	panel.draw_line(c + Vector2(-b, -b), c + Vector2(-b + b_len, -b), b_col, 2.0)
	panel.draw_line(c + Vector2(-b, -b), c + Vector2(-b, -b + b_len), b_col, 2.0)
	panel.draw_line(c + Vector2(b, -b), c + Vector2(b - b_len, -b), b_col, 2.0)
	panel.draw_line(c + Vector2(b, -b), c + Vector2(b, -b + b_len), b_col, 2.0)
	panel.draw_line(c + Vector2(-b, b), c + Vector2(-b + b_len, b), b_col, 2.0)
	panel.draw_line(c + Vector2(-b, b), c + Vector2(-b, b - b_len), b_col, 2.0)
	panel.draw_line(c + Vector2(b, b), c + Vector2(b - b_len, b), b_col, 2.0)
	panel.draw_line(c + Vector2(b, b), c + Vector2(b, b - b_len), b_col, 2.0)
	# Inner glowing dot
	panel.draw_circle(c, 7.0, Color(0.2, 0.95, 1.0, 0.9))
	panel.draw_circle(c, 4.0, Color(1.0, 1.0, 1.0, 0.95))


func _draw_tutorial_double_rush_icon(panel: Panel) -> void:
	var c := panel.size / 2.0
	var r1 := 18.0
	var r2 := 12.0
	var col_outer := Color(1.0, 0.35, 0.85, 0.95)
	var col_inner := Color(1.0, 0.9, 0.2, 0.95)
	panel.draw_arc(c, r1, 0.0, TAU, 28, col_outer, 2.8, true)
	panel.draw_arc(c, r2, 0.0, TAU, 24, col_inner, 2.2, true)
	# Twin chevrons in center
	var pts1 := PackedVector2Array([c + Vector2(-6, 4), c + Vector2(0, -3), c + Vector2(6, 4)])
	var pts2 := PackedVector2Array([c + Vector2(-6, -1), c + Vector2(0, -8), c + Vector2(6, -1)])
	panel.draw_polyline(pts1, Color.WHITE, 2.2, true)
	panel.draw_polyline(pts2, col_inner, 2.2, true)


var _tutorial_drag_active: bool = false
var _tutorial_drag_start_y: float = 0.0
var _tutorial_drag_scroll_start: int = 0

func _on_tutorial_scroll_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return

	# --- Touch Swipe & Drag ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_tutorial_drag_active = false
			_tutorial_drag_start_y = event.position.y
			_tutorial_drag_scroll_start = scroll.scroll_vertical
		else:
			_tutorial_drag_active = false

	elif event is InputEventScreenDrag:
		var moved := absf(event.position.y - _tutorial_drag_start_y)
		if moved > _OVERLAY_TAP_THRESHOLD:
			_tutorial_drag_active = true
		if _tutorial_drag_active:
			var delta: float = _tutorial_drag_start_y - event.position.y
			scroll.scroll_vertical = _tutorial_drag_scroll_start + int(delta)
			get_viewport().set_input_as_handled()

	# --- Mouse Drag & Wheel (desktop / editor testing) ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_tutorial_drag_active = false
				_tutorial_drag_start_y = event.position.y
				_tutorial_drag_scroll_start = scroll.scroll_vertical
			else:
				_tutorial_drag_active = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.scroll_vertical -= 60
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll.scroll_vertical += 60
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var moved := absf(event.position.y - _tutorial_drag_start_y)
			if moved > _OVERLAY_TAP_THRESHOLD:
				_tutorial_drag_active = true
			if _tutorial_drag_active:
				var delta: float = _tutorial_drag_start_y - event.position.y
				scroll.scroll_vertical = _tutorial_drag_scroll_start + int(delta)
				get_viewport().set_input_as_handled()


# =====================================================
# GOOGLE PLAY UPDATE MODAL
# =====================================================

func _is_overlay_open() -> bool:
	return (_story_screen != null and _story_screen.visible) \
		or (_songs_screen != null and _songs_screen.visible) \
		or (_themes_screen != null and _themes_screen.visible) \
		or (_shop_screen != null and _shop_screen.visible) \
		or (_options_screen != null and _options_screen.visible) \
		or (_badges_screen != null and _badges_screen.visible) \
		or (_update_modal != null and _update_modal.visible)


func _setup_update_ui() -> void:
	_update_modal = Control.new()
	_update_modal.name = "UpdateModal"
	_update_modal.visible = false
	_update_modal.anchor_right = 1.0
	_update_modal.anchor_bottom = 1.0
	_update_modal.z_index = 100
	add_child(_update_modal)

	# Semi-transparent dark blur backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "UpdateBackdrop"
	backdrop.color = Color(0.04, 0.03, 0.08, 0.85)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
			if _update_later_btn != null and _update_later_btn.visible:
				_on_update_later_pressed()
	)
	_update_modal.add_child(backdrop)

	# Centered synthwave modal panel
	_update_panel = Panel.new()
	_update_panel.name = "UpdatePanel"
	_update_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var p_style := StyleBoxFlat.new()
	p_style.set_corner_radius_all(22)
	p_style.bg_color = Color(0.10, 0.08, 0.18, 0.98)
	p_style.set_border_width_all(2)
	p_style.set_border_color(Color(0.25, 1.0, 0.55, 0.95))
	p_style.set_shadow_size(18)
	p_style.set_shadow_color(Color(0.15, 0.95, 0.45, 0.45))
	_update_panel.add_theme_stylebox_override("panel", p_style)

	_update_panel.anchor_left = 0.5
	_update_panel.anchor_right = 0.5
	_update_panel.anchor_top = 0.5
	_update_panel.anchor_bottom = 0.5
	_update_panel.offset_left = -190.0
	_update_panel.offset_right = 190.0
	_update_panel.offset_top = -255.0
	_update_panel.offset_bottom = 255.0
	_update_modal.add_child(_update_panel)

	# Title: UPDATE AVAILABLE
	var title_lbl := Label.new()
	title_lbl.name = "UpdateTitle"
	title_lbl.text = "⚡ UPDATE AVAILABLE ⚡"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
	title_lbl.anchor_right = 1.0
	title_lbl.offset_top = 16.0
	title_lbl.offset_bottom = 44.0
	_update_panel.add_child(title_lbl)

	# Version Badge
	_update_version_badge = Label.new()
	_update_version_badge.name = "UpdateVersionBadge"
	_update_version_badge.text = ""
	_update_version_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_version_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_version_badge.add_theme_font_size_override("font_size", 14)
	_update_version_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_update_version_badge.anchor_right = 1.0
	_update_version_badge.offset_top = 46.0
	_update_version_badge.offset_bottom = 72.0
	_update_panel.add_child(_update_version_badge)

	# Description text
	_update_desc_label = Label.new()
	_update_desc_label.name = "UpdateDesc"
	_update_desc_label.text = "A new update for Music Square is waiting for you on Google Play!\nUpdate now to enjoy the latest songs, tracks, and improvements."
	_update_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_desc_label.add_theme_font_size_override("font_size", 12)
	_update_desc_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	_update_desc_label.offset_left = 18.0
	_update_desc_label.offset_right = 362.0
	_update_desc_label.offset_top = 74.0
	_update_desc_label.offset_bottom = 134.0
	_update_panel.add_child(_update_desc_label)

	# Release Notes Box
	var notes_panel := Panel.new()
	notes_panel.name = "NotesPanel"
	notes_panel.clip_contents = true
	var np_style := StyleBoxFlat.new()
	np_style.set_corner_radius_all(12)
	np_style.bg_color = Color(0.06, 0.05, 0.14, 0.9)
	np_style.set_border_width_all(1)
	np_style.set_border_color(Color(0.3, 0.4, 0.6, 0.5))
	notes_panel.add_theme_stylebox_override("panel", np_style)
	notes_panel.offset_left = 18.0
	notes_panel.offset_right = 362.0
	notes_panel.offset_top = 138.0
	notes_panel.offset_bottom = 358.0
	_update_panel.add_child(notes_panel)

	_update_notes_scroll = ScrollContainer.new()
	_update_notes_scroll.name = "NotesScroll"
	_update_notes_scroll.anchor_right = 1.0
	_update_notes_scroll.anchor_bottom = 1.0
	_update_notes_scroll.offset_left = 10.0
	_update_notes_scroll.offset_right = -10.0
	_update_notes_scroll.offset_top = 8.0
	_update_notes_scroll.offset_bottom = -8.0
	_update_notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_update_notes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	notes_panel.add_child(_update_notes_scroll)

	_update_notes_label = Label.new()
	_update_notes_label.name = "NotesLabel"
	_update_notes_label.text = "• What's New:\n• Exciting new synthwave tracks & visual polish\n• Google Play Games Services leaderboard"
	_update_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_notes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_notes_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_update_notes_label.add_theme_font_size_override("font_size", 12)
	_update_notes_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.98))
	_update_notes_scroll.add_child(_update_notes_label)

	# UPDATE ON GOOGLE PLAY Button
	_update_now_btn = Button.new()
	_update_now_btn.name = "UpdateNowBtn"
	_update_now_btn.text = "UPDATE ON GOOGLE PLAY"
	_update_now_btn.add_theme_font_size_override("font_size", 15)
	_update_now_btn.add_theme_color_override("font_color", Color(0.1, 1.0, 0.45))
	_update_now_btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.75))
	_update_now_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var un_style := _btn_style.duplicate()
	un_style.bg_color = Color(0.08, 0.28, 0.15, 0.95)
	un_style.set_border_color(Color(0.25, 1.0, 0.5, 0.95))
	un_style.set_shadow_color(Color(0.18, 0.95, 0.45, 0.55))
	un_style.set_shadow_size(12)
	_update_now_btn.add_theme_stylebox_override("normal", un_style)

	var un_hover := un_style.duplicate()
	un_hover.bg_color = Color(0.12, 0.38, 0.22, 1.0)
	un_hover.set_border_color(Color(0.4, 1.0, 0.65, 1.0))
	un_hover.set_shadow_size(16)
	_update_now_btn.add_theme_stylebox_override("hover", un_hover)
	_update_now_btn.add_theme_stylebox_override("pressed", un_hover)

	_update_now_btn.offset_left = 22.0
	_update_now_btn.offset_right = 358.0
	_update_now_btn.offset_top = 372.0
	_update_now_btn.offset_bottom = 428.0
	_update_now_btn.pressed.connect(_on_update_now_pressed)
	_update_panel.add_child(_update_now_btn)

	# LATER Button
	_update_later_btn = Button.new()
	_update_later_btn.name = "UpdateLaterBtn"
	_update_later_btn.text = "LATER"
	_update_later_btn.add_theme_font_size_override("font_size", 14)
	_update_later_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_update_later_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_update_later_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var ul_style := _btn_style.duplicate()
	ul_style.bg_color = Color(0.14, 0.12, 0.22, 0.85)
	ul_style.set_border_color(Color(0.35, 0.35, 0.5, 0.6))
	ul_style.set_shadow_size(6)
	_update_later_btn.add_theme_stylebox_override("normal", ul_style)

	var ul_hover := ul_style.duplicate()
	ul_hover.bg_color = Color(0.2, 0.18, 0.3, 0.95)
	ul_hover.set_border_color(Color(0.5, 0.5, 0.7, 0.9))
	_update_later_btn.add_theme_stylebox_override("hover", ul_hover)
	_update_later_btn.add_theme_stylebox_override("pressed", ul_hover)

	_update_later_btn.offset_left = 22.0
	_update_later_btn.offset_right = 358.0
	_update_later_btn.offset_top = 438.0
	_update_later_btn.offset_bottom = 486.0
	_update_later_btn.pressed.connect(_on_update_later_pressed)
	_update_panel.add_child(_update_later_btn)

	# Make version label clickable
	var ver_label: Label = get_node_or_null("MenuScreen/VersionLabel")
	if ver_label != null:
		ver_label.mouse_filter = Control.MOUSE_FILTER_STOP
		ver_label.gui_input.connect(_on_version_label_gui_input)


func _show_update_modal(info: Dictionary) -> void:
	if _update_modal == null or not is_instance_valid(_update_modal):
		return

	_pending_update_info = info
	_has_prompted_update = true

	var remote_version: String = str(info.get("latest_version", "1.1.1"))
	var remote_notes: String = str(info.get("release_notes", ""))
	var remote_msg: String = str(info.get("message", ""))
	var force_update: bool = bool(info.get("force_update", false))

	if _update_version_badge != null and is_instance_valid(_update_version_badge):
		_update_version_badge.text = "v%s  ➔  v%s" % [CURRENT_VERSION_NAME, remote_version]

	if _update_desc_label != null and is_instance_valid(_update_desc_label):
		if not remote_msg.is_empty():
			_update_desc_label.text = remote_msg
		else:
			_update_desc_label.text = "A new update for Music Square is waiting for you on Google Play!\nUpdate now to enjoy the latest songs, tracks, and improvements."

	if _update_notes_label != null and is_instance_valid(_update_notes_label):
		if not remote_notes.is_empty():
			_update_notes_label.text = remote_notes
		else:
			_update_notes_label.text = "• What's New:\n• Exciting new content and improvements on Google Play!"

	if _update_notes_scroll != null and is_instance_valid(_update_notes_scroll):
		_update_notes_scroll.scroll_vertical = 0

	if _update_later_btn != null and is_instance_valid(_update_later_btn):
		_update_later_btn.visible = not force_update

	_update_modal.visible = true
	sfx.play("combo")
	_haptic_celebration()

	# Animated scale punch
	if _update_panel != null and is_instance_valid(_update_panel):
		_update_panel.pivot_offset = _update_panel.size / 2.0
		_update_panel.scale = Vector2(0.8, 0.8)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_update_panel, "scale", Vector2.ONE, 0.22)


func _hide_update_modal() -> void:
	sfx.play("tap")
	_haptic_tap()
	if _update_modal != null and is_instance_valid(_update_modal):
		_update_modal.visible = false


func _on_update_now_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	if has_node("/root/UpdateManager"):
		get_node("/root/UpdateManager").open_store_page()
	else:
		OS.shell_open("https://play.google.com/store/apps/details?id=com.psygames.musicsquare")


func _on_update_later_pressed() -> void:
	if not _pending_update_info.is_empty():
		var r_ver: String = str(_pending_update_info.get("latest_version", ""))
		var r_code: int = int(_pending_update_info.get("version_code", 0))
		settings.dismiss_update(r_ver, r_code)
	_hide_update_modal()


func _on_update_available(info: Dictionary) -> void:
	_pending_update_info = info
	_update_menu_version_badge()

	var force_update: bool = bool(info.get("force_update", false))
	var r_ver: String = str(info.get("latest_version", ""))
	var r_code: int = int(info.get("version_code", 0))

	# If already on the same release version (e.g. 1.1.1 == 1.1.1), don't pop up modal unless forced
	if not force_update and r_ver == CURRENT_VERSION_NAME:
		return

	# If user dismissed this version update previously, do not nag them again
	if not force_update and settings.is_update_dismissed(r_ver, r_code):
		return

	# Display immediately if on menu, haven't prompted this session yet, and no overlay open
	if state == settings.GameState.MENU and not _has_prompted_update and not _is_overlay_open():
		_show_update_modal(info)


func _update_menu_version_badge() -> void:
	var ver_label: Label = get_node_or_null("MenuScreen/VersionLabel")
	if ver_label != null and is_instance_valid(ver_label):
		var r_ver: String = str(_pending_update_info.get("latest_version", ""))
		if not r_ver.is_empty() and r_ver != CURRENT_VERSION_NAME:
			ver_label.text = "v%s • UPDATE AVAILABLE" % CURRENT_VERSION_NAME
			ver_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			ver_label.text = "v%s" % CURRENT_VERSION_NAME
			ver_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85, 0.6))


func _on_version_label_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed):
		if not _pending_update_info.is_empty():
			_show_update_modal(_pending_update_info)
		elif has_node("/root/UpdateManager") and get_node("/root/UpdateManager").is_update_available:
			_show_update_modal(get_node("/root/UpdateManager").latest_version_info)
		else:
			sfx.play("tap")
			_show_remap_banner("VERSION v%s (UP TO DATE)" % CURRENT_VERSION_NAME)


# =====================================================
# DYNAMIC INTERACTIVE WALKTHROUGH CONTROLLER
# =====================================================

func _start_game_with_walkthrough() -> void:
	_setup_initial_game_state()
	_set_state(settings.GameState.PLAYING)
	_update_high_score_display()
	_start_dynamic_walkthrough()


func _start_dynamic_walkthrough() -> void:
	_setup_initial_game_state()
	_set_state(settings.GameState.PLAYING)
	_is_walkthrough_active = true
	_walkthrough_advancing = false
	_walkthrough_frenzy_swipes_done = 0
	hold_exit_buffer = 0.0
	frenzy_exit_buffer = 0.0

	# Instantiate overlay if needed
	if _walkthrough_overlay == null or not is_instance_valid(_walkthrough_overlay):
		_walkthrough_overlay = WalkthroughOverlayScript.new()
		_walkthrough_overlay.name = "WalkthroughOverlay"
		game_screen.add_child(_walkthrough_overlay)
		_walkthrough_overlay.setup(center_square, direction_squares, _make_arcade_font(0.5))
		_walkthrough_overlay.skip_pressed.connect(_on_walkthrough_skip)
		_walkthrough_overlay.start_play_pressed.connect(_on_walkthrough_play_pressed)

	_walkthrough_overlay.visible = true
	_setup_walkthrough_step(1)


func _setup_walkthrough_step(step: int) -> void:
	_walkthrough_step = step
	_walkthrough_advancing = false

	# Clean reset between steps
	_cleanup_hold_ui()
	_cleanup_double_turn_ui()
	is_holding_active = false
	is_hold_turn = false
	is_double_turn = false
	double_turn_step = 0
	powerup_square_dir = ""
	powerup_type = ""
	_clear_persistent_labels()
	time_left_in_turn = current_time_limit
	if _center_squash_tween != null and _center_squash_tween.is_valid():
		_center_squash_tween.kill()
		_center_squash_tween = null
	_center_scale_locked = false
	if center_square != null and is_instance_valid(center_square):
		center_square.scale = Vector2.ONE
	hold_exit_buffer = 0.0
	frenzy_exit_buffer = 0.0

	match step:
		1:
			# Step 1: Color Matching & Blazing Timing
			current_target_direction = "right"
			var col: Color = direction_colors.get("right", Color(0.12, 0.46, 0.88))
			_last_target_color = col
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(1, "right", "[ STEP 1 OF 9 - COLOR MATCH & TIMING ]", "Swipe toward the MATCHING outer square!\nFast swipes trigger BLAZING! (1.5x) & charge Overdrive!", false, false, col)

		2:
			# Step 2: Combos, Multiplier & Overdrive Fever Bar
			current_target_direction = "up"
			var col: Color = direction_colors.get("up", Color(0.88, 0.22, 0.35))
			_last_target_color = col
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(2, "up", "[ STEP 2 OF 9 - STREAKS & OVERDRIVE ]", "Every 5 swipes boosts your MULTIPLIER up to 4x!\nFilling the ⚡ OVERDRIVE bar to 100% triggers Frenzy!", false, false, col)

		3:
			# Step 3: Hold Squares
			current_target_direction = "down"
			var col: Color = direction_colors.get("down", Color(0.82, 0.72, 0.06))
			_last_target_color = col
			is_hold_turn = true
			_setup_hold_turn_indicator()
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(3, "down", "[ STEP 3 OF 9 - HOLD SQUARES ]", "When you see pulsing brackets:\nSWIPE and HOLD your finger until the charge ring fills!", true, false, col)

		4:
			# Step 4: 2x Double-Dash Rush (Rapid 2-Hit Combo)
			current_target_direction = "left"
			is_double_turn = true
			double_turn_step = 1
			var col: Color = direction_colors.get("left", Color(0.10, 0.70, 0.38))
			_last_target_color = col
			_setup_double_turn_indicator()
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(4, "left", "[ STEP 4 OF 9 - 2X DOUBLE-DASH RUSH ]", "Twin rings mean a 2-STEP RUSH! Swipe LEFT (1/2),\nthen immediately swipe the 2nd color for 2.5x points!", false, false, col)

		5:
			# Step 5: Frenzy Power-Up
			if is_frenzy_active:
				_end_frenzy_mode()
			current_target_direction = "up"
			var col: Color = direction_colors.get("up", Color(0.88, 0.22, 0.35))
			_last_target_color = col
			powerup_square_dir = "left"
			powerup_type = "frenzy"
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(5, "left", "[ STEP 5 OF 9 - FRENZY POWER-UP ]", "Swipe into the LIGHTNING square!\nFrenzy unleashes rapid-fire scoring across all squares!", false, false, col)

		6:
			# Step 6: Time Booster (+5s)
			if is_frenzy_active:
				_end_frenzy_mode()
			current_target_direction = "left"
			var col: Color = direction_colors.get("left", Color(0.10, 0.70, 0.38))
			_last_target_color = col
			powerup_square_dir = "right"
			powerup_type = "frenzy_boost"
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(6, "right", "[ STEP 6 OF 9 - TIME BOOSTER ]", "Swipe the CYAN BOOSTER (+) to store +5s extra time!\nBooster charges make your future Frenzy runs last longer!", false, false, col)

		7:
			# Step 7: Aegis Neon Shield (Mistake & Streak Protection)
			if is_frenzy_active:
				_end_frenzy_mode()
			has_shield = false
			_update_shield_ui()
			current_target_direction = "down"
			var col: Color = direction_colors.get("down", Color(0.82, 0.72, 0.06))
			_last_target_color = col
			powerup_square_dir = "up"
			powerup_type = "shield"
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(7, "up", "[ STEP 7 OF 9 - AEGIS NEON SHIELD ]", "Swipe the EMERALD SHIELD to activate a barrier!\nIt absorbs your next mistake or timeout & saves your streak!", false, false, Color(0.15, 1.0, 0.78))

		8:
			# Step 8: Neon Spark Jackpot (+5 Sparks)
			current_target_direction = "up"
			var col: Color = direction_colors.get("up", Color(0.88, 0.22, 0.35))
			_last_target_color = col
			powerup_square_dir = "down"
			powerup_type = "spark_jackpot"
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(8, "down", "[ STEP 8 OF 9 - NEON SPARK JACKPOT ]", "Swipe the GOLDEN DIAMOND for +5 Neon Sparks!\nSpend Sparks in the Shop on Trails, Skins & SFX!", false, false, Color(1.0, 0.85, 0.2))

		9:
			# Step 9: Board Shuffle (Whirlwind 360° spin)
			has_shield = false
			_update_shield_ui()
			_remap_directions()
			current_target_direction = "up"
			var col: Color = direction_colors.get("up", Color(0.88, 0.22, 0.35))
			_last_target_color = col
			_apply_board_colors()
			_pulse_center()
			_walkthrough_overlay.set_step(9, "up", "[ STEP 9 OF 9 - BOARD SHUFFLE ]", "The board spins and colors swap periodically!\nRe-orient and swipe the new matching position!", false, false, col)

		10:
			# Step 10: Ready to Play / Completed Briefing
			if is_frenzy_active:
				_end_frenzy_mode()
			has_shield = false
			_update_shield_ui()
			_apply_board_colors()
			if _walkthrough_from_options:
				_walkthrough_overlay.show_final_step("TUTORIAL COMPLETE!", "You've mastered all mechanics of Music Square!\nTap below or anywhere on screen to return to Options.", "BACK TO OPTIONS")
			else:
				_walkthrough_overlay.show_final_step("YOU'RE READY TO PLAY!", "3 Hearts: Wrong swipes or timing out loses a heart.\nChain Blazing swipes, Shields & Overdrive for massive scores!", "LET'S PLAY!")


func _handle_walkthrough_swipe(direction: String) -> void:
	if _walkthrough_advancing:
		return

	match _walkthrough_step:
		1: # Step 1: Color Match & Blazing Timing
			if direction == current_target_direction:
				_walkthrough_advancing = true
				sfx.play_pitched("correct", 1.08)
				_haptic_tap()
				_add_fever_charge(25.0)
				_burst_particles(_get_board_center(direction), direction_colors.get(direction, Color.WHITE), 14)
				_flash_square(direction, Color.WHITE)
				_walkthrough_overlay.flash_success("BLAZING! 1.5x!")
				_advance_walkthrough()
			else:
				sfx.play("wrong")
				_haptic_wrong()
				_flash_center_red()
				_shake_screen(3.0)
				_walkthrough_overlay.flash_reminder("Swipe toward the matching square!")

		2: # Step 2: Streak, Multiplier & Overdrive Bar
			if direction == current_target_direction:
				_walkthrough_advancing = true
				sfx.play("combo")
				_haptic_tap()
				streak = 5
				_add_fever_charge(35.0)
				_update_combo_hud()
				_update_streak_visuals()
				_burst_particles(_get_board_center(direction), direction_colors.get(direction, Color.WHITE), 14)
				_flash_square(direction, Color(1.5, 0.35, 0.85, 1.0))
				_walkthrough_overlay.flash_success("x2 MULTIPLIER & +FEVER!")
				_advance_walkthrough()
			else:
				sfx.play("wrong")
				_flash_center_red()
				_walkthrough_overlay.flash_reminder("Swipe UP to boost your multiplier!")

		3: # Step 3: Hold Turn
			if direction == current_target_direction:
				_walkthrough_overlay.flash_reminder("HOLD down until the ring fills!")
			else:
				_walkthrough_overlay.flash_reminder("Swipe DOWN and HOLD!")

		4: # Step 4: 2x Double-Dash Rush (1/2 -> 2/2)
			if double_turn_step == 1:
				if direction == current_target_direction:
					double_turn_step = 2
					current_target_direction = "right"
					var next_col: Color = direction_colors.get(current_target_direction, Color(0.12, 0.46, 0.88))
					_last_target_color = next_col
					_apply_board_colors()
					_pulse_center()
					_setup_double_turn_indicator()
					sfx.play_pitched("combo", 1.18)
					_haptic_tap()
					_burst_particles(_get_board_center(direction), direction_colors.get(direction, Color.WHITE), 12)
					_flash_square(direction, Color.WHITE)
					_walkthrough_overlay.set_step(4, "right", "[ STEP 4 OF 9 - 2X RUSH (2/2)! ]", "1ST HIT LOCKED! Center shifted to BLUE —\nnow swipe RIGHT to complete the 2.5x Double Rush!", false, false, next_col)
					_walkthrough_overlay.flash_success("1/2 HIT! NOW SWIPE RIGHT!")
				else:
					sfx.play("wrong")
					_flash_center_red()
					_walkthrough_overlay.flash_reminder("Swipe LEFT for step 1/2!")
			else:
				if direction == current_target_direction:
					_walkthrough_advancing = true
					is_double_turn = false
					double_turn_step = 0
					_cleanup_double_turn_ui()
					center_square.queue_redraw()
					sfx.play_pitched("unlock", 1.15)
					_haptic_celebration()
					_burst_particles(_get_board_center(direction), Color(1.0, 0.4, 0.9), 18)
					_flash_square(direction, Color(1.0, 0.9, 0.2, 0.95))
					_walkthrough_overlay.flash_success("2X RUSH COMPLETE! (2.5x PTS!)")
					_advance_walkthrough()
				else:
					sfx.play("wrong")
					_flash_center_red()
					_walkthrough_overlay.flash_reminder("Swipe RIGHT to finish 2/2!")

		5: # Step 5: Frenzy Power-Up
			if not is_frenzy_active:
				if direction == "left":
					sfx.play("combo")
					_burst_particles(_get_board_center("left"), Color(1.8, 1.4, 0.2), 16)
					_activate_frenzy_mode()
					_walkthrough_frenzy_swipes_done = 0
					_walkthrough_overlay.set_step(5, "", "[ STEP 5 OF 9 - FRENZY ACTIVE! ]", "Frenzy unlocked! Swipe ANY direction for massive points!\nSwipe any square now!", false, true, Color(1.35, 1.15, 0.15))
					_walkthrough_overlay.flash_success("FRENZY UNLEASHED!")
				else:
					_walkthrough_overlay.flash_reminder("Swipe toward the LIGHTNING square!")
			else:
				# Practice rapid frenzy swipe: 1 practice swipe is plenty!
				_walkthrough_advancing = true
				_walkthrough_frenzy_swipes_done += 1
				sfx.play("combo")
				_burst_particles(_get_board_center(direction), Color(1.8, 1.4, 0.2), 16)
				_flash_square(direction, Color.WHITE)
				_walkthrough_overlay.flash_success("FRENZY MASTERED!")
				_end_frenzy_mode()
				frenzy_exit_buffer = 0.0
				_advance_walkthrough()

		6: # Step 6: Time Booster (+5s)
			if direction == "right":
				_walkthrough_advancing = true
				_add_frenzy_charge()
				sfx.play("combo")
				_burst_particles(_get_board_center("right"), Color(0.2, 0.95, 1.0), 14)
				_flash_square("right", Color(0.2, 0.95, 1.0, 0.9))
				_walkthrough_overlay.flash_success("+5s CHARGE STORED!")
				_advance_walkthrough()
			else:
				_walkthrough_overlay.flash_reminder("Swipe toward the BOOSTER square!")

		7: # Step 7: Aegis Neon Shield
			if direction == "up":
				_walkthrough_advancing = true
				has_shield = true
				_update_shield_ui()
				powerup_square_dir = ""
				powerup_type = ""
				if direction_squares.has("up") and is_instance_valid(direction_squares["up"]):
					direction_squares["up"].queue_redraw()
				if center_square != null and is_instance_valid(center_square):
					center_square.queue_redraw()
				sfx.play("shield")
				_haptic_celebration()
				_burst_particles(_get_board_center("up"), Color(0.15, 1.0, 0.78), 18)
				_flash_square("up", Color(0.2, 1.0, 0.85, 0.9))
				_walkthrough_overlay.flash_success("🛡️ SHIELD READY!")
				_advance_walkthrough()
			else:
				_walkthrough_overlay.flash_reminder("Swipe UP toward the EMERALD SHIELD!")

		8: # Step 8: Spark Jackpot (+5 Sparks) & Heart Surge
			if direction == "down":
				_walkthrough_advancing = true
				powerup_square_dir = ""
				powerup_type = ""
				if direction_squares.has("down") and is_instance_valid(direction_squares["down"]):
					direction_squares["down"].queue_redraw()
				sfx.play("unlock")
				_haptic_celebration()
				_burst_particles(_get_board_center("down"), Color(1.0, 0.88, 0.2), 20)
				_flash_square("down", Color(1.0, 0.9, 0.25, 0.9))
				_walkthrough_overlay.flash_success("💎 JACKPOT! +5 SPARKS!")
				_advance_walkthrough()
			else:
				_walkthrough_overlay.flash_reminder("Swipe DOWN toward the GOLDEN DIAMOND!")

		9: # Step 9: Board Shuffle
			if direction == current_target_direction:
				_walkthrough_advancing = true
				sfx.play("unlock")
				_burst_particles(_get_board_center(direction), direction_colors.get(direction, Color.WHITE), 16)
				_flash_square(direction, Color.WHITE)
				_walkthrough_overlay.flash_success("SHUFFLE MASTER!")
				_advance_walkthrough()
			else:
				_walkthrough_overlay.flash_reminder("Look at the center color on new layout!")

		10: # Step 10: Ready to Play Briefing
			_walkthrough_advancing = true
			_finish_walkthrough(false)


func _advance_walkthrough() -> void:
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func():
		if _is_walkthrough_active:
			_setup_walkthrough_step(_walkthrough_step + 1)
	)


func _finish_walkthrough(skipped: bool = false) -> void:
	_is_walkthrough_active = false
	_walkthrough_advancing = false
	_walkthrough_step = 0
	settings.first_play = false
	settings.save_data()

	_cleanup_hold_ui()
	_cleanup_double_turn_ui()
	is_holding_active = false
	is_hold_turn = false
	is_double_turn = false
	double_turn_step = 0
	has_shield = false
	_update_shield_ui()

	if is_frenzy_active:
		_end_frenzy_mode()

	if _walkthrough_overlay != null and is_instance_valid(_walkthrough_overlay):
		_walkthrough_overlay.visible = false
		_walkthrough_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _center_squash_tween != null and _center_squash_tween.is_valid():
		_center_squash_tween.kill()
		_center_squash_tween = null
	_center_scale_locked = false
	if center_square != null and is_instance_valid(center_square):
		center_square.scale = Vector2.ONE

	# If launched from Options, revert directly to Options menu!
	if _walkthrough_from_options:
		_walkthrough_from_options = false
		_set_state(settings.GameState.MENU)
		_open_options_screen()
		return

	# Reset cleanly so practice swipes don't taint real game stats
	_setup_initial_game_state()
	_update_high_score_display()
	update_score_display()
	_update_lives_display()
	_update_combo_hud()
	_update_frenzy_charge_ui()

	if not skipped:
		sfx.play("unlock")
		_show_remap_banner("READY... GO!")
		var tw := create_tween()
		tw.tween_interval(0.65)
		tw.tween_callback(func():
			if state == settings.GameState.PLAYING:
				start_new_turn()
		)
	else:
		start_new_turn()


func _on_walkthrough_skip() -> void:
	sfx.play("tap")
	_haptic_tap()
	_finish_walkthrough(true)


func _on_walkthrough_play_pressed() -> void:
	sfx.play("tap")
	_haptic_celebration()
	_finish_walkthrough(false)


# =====================================================
# ACHIEVEMENTS / BADGES SYSTEM
# =====================================================

func _check_in_game_achievements() -> void:
	# 1. FIRST BLOOD: Score 25,000+ in a single game
	if score >= 25000:
		_try_unlock_achievement("first_blood")

	# 2. UNSTOPPABLE: Reach a 150 streak in a single game
	if streak >= 150 or best_streak_this_game >= 150:
		_try_unlock_achievement("unstoppable")

	# 3. FRENZY FANATIC: Trigger Frenzy 20 times in one game
	if _frenzy_count_this_game >= 20:
		_try_unlock_achievement("frenzy_fanatic")

	# 4. SHARPSHOOTER: 95%+ accuracy with 100+ swipes
	if total_swipes >= 100:
		var acc: float = clampf((float(total_correct) / float(total_swipes)) * 100.0, 0.0, 100.0)
		if acc >= 95.0:
			_try_unlock_achievement("sharpshooter")

	# 5. SPEED DEMON: 35 lightning fast swipes in a game
	if _fast_swipes_this_game >= 35:
		_try_unlock_achievement("speed_demon")

	# 6. COMBO KING: Reach a massive 300 streak in one game
	if streak >= 300 or best_streak_this_game >= 300:
		_try_unlock_achievement("combo_king")

	# 7. UNTOUCHABLE: Score 100,000+ without losing any hearts
	if score >= 100000 and not _lost_heart_this_game and lives == settings.MAX_LIVES:
		_try_unlock_achievement("untouchable")

	# 8. REMAP MASTER: Survive 40 direction remaps in one run
	if _remaps_survived_this_game >= 40:
		_try_unlock_achievement("remap_master")

	# 9. ARCADE LEGEND: Score 1,000,000+ points in a single game
	if score >= 1000000:
		_try_unlock_achievement("arcade_legend")

	# 10. GRANDMASTER: 100% perfect accuracy with 1,000+ swipes
	if total_swipes >= 1000 and total_correct >= 1000 and total_swipes == total_correct:
		_try_unlock_achievement("grandmaster")

	# 11. IRON GRIP: Successfully complete 15 Hold Squares in a game
	if _hold_squares_completed_this_game >= 15:
		_try_unlock_achievement("iron_grip")

	# 12. CLUTCH GENIUS: Score 50 correct swipes in a row with 1 heart left
	if _clutch_swipes_this_game >= 50:
		_try_unlock_achievement("clutch_genius")

	# 13. FEVER PITCH: Trigger 3 Frenzies in a game without dropping 4x Multiplier
	if _frenzies_at_max_multiplier >= 3:
		_try_unlock_achievement("fever_pitch")

	# 14. MARATHON RUNNER: Reach 500 total swipes in a single run
	if total_swipes >= 500:
		_try_unlock_achievement("marathon_runner")

	# 15. MYTHIC SWIPER: Score 2,000,000+ points in a single game
	if score >= 2000000:
		_try_unlock_achievement("mythic_swiper")

	# 16. DEDICATED: Play 50 total games across all sessions
	if settings.games_played >= 50:
		_try_unlock_achievement("dedicated")

	# 17. COMPLETIONIST: Unlock every other badge, song, and theme
	_check_completionist()


func _check_achievements(_accuracy: float = 0.0) -> void:
	_check_in_game_achievements()


func _check_completionist() -> void:
	if settings.is_achievement_unlocked("completionist"):
		return
	var all_unlocked := true
	for s in settings.SONGS:
		if not settings.is_song_unlocked(s):
			all_unlocked = false
			break
	if all_unlocked:
		for t in settings.THEMES:
			if not settings.is_theme_unlocked(t):
				all_unlocked = false
				break
	if all_unlocked:
		for a in settings.ACHIEVEMENTS:
			var a_id = str(a.get("id", ""))
			if a_id != "completionist" and not settings.is_achievement_unlocked(a_id):
				all_unlocked = false
				break
	if all_unlocked:
		_try_unlock_achievement("completionist")


func _try_unlock_achievement(ach_id: String) -> bool:
	if settings.is_achievement_unlocked(ach_id):
		return false
	if settings.unlock_achievement(ach_id):
		for ach: Dictionary in settings.ACHIEVEMENTS:
			if str(ach.get("id", "")) == ach_id:
				_queue_achievement_toast(ach)
				break
		if ach_id != "completionist":
			_check_completionist()
		return true
	return false


func _queue_achievement_toast(ach: Dictionary) -> void:
	_achievement_toast_queue.append(ach)
	if not _is_showing_achievement_toast:
		_process_achievement_toast_queue()


func _process_achievement_toast_queue() -> void:
	if _achievement_toast_queue.is_empty():
		_is_showing_achievement_toast = false
		return

	_is_showing_achievement_toast = true
	var ach: Dictionary = _achievement_toast_queue.pop_front()
	_display_achievement_toast(ach)


func _show_achievement_toast(ach: Dictionary) -> void:
	_queue_achievement_toast(ach)


func _display_achievement_toast(ach: Dictionary) -> void:
	sfx.play("unlock")
	var hdr: String = str(ach.get("header", "BADGE UNLOCKED!"))
	if hdr.begins_with("MISSION"):
		sfx.play_voice("mission_complete", 82, 0.8)
	elif hdr.begins_with("NEW "):
		sfx.play_voice("new_unlock", 80, 0.8)
	else:
		sfx.play_voice("achievement_unlocked", 88, 0.8)
	_haptic_celebration()

	var toast := Panel.new()
	toast.name = "AchievementToast"
	toast.z_index = 200
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -190.0
	toast.offset_right = 190.0

	var target_top := 32.0
	var target_bottom := 110.0
	toast.offset_top = -100.0
	toast.offset_bottom = -22.0
	toast.modulate.a = 0.0

	var toast_style := StyleBoxFlat.new()
	toast_style.set_corner_radius_all(16)
	toast_style.bg_color = Color(0.10, 0.07, 0.20, 0.96)
	toast_style.set_border_width_all(2)
	var ach_color: Color = ach.get("color", Color(1.0, 0.85, 0.2))
	toast_style.set_border_color(Color(ach_color.r, ach_color.g, ach_color.b, 0.9))
	toast_style.set_shadow_size(10)
	toast_style.set_shadow_color(Color(ach_color.r, ach_color.g, ach_color.b, 0.45))
	toast.add_theme_stylebox_override("panel", toast_style)
	add_child(toast)

	# Pictogram frame on the left
	var icon_frame := Panel.new()
	icon_frame.size = Vector2(54, 54)
	icon_frame.position = Vector2(12, 12)
	var frame_style := StyleBoxFlat.new()
	frame_style.set_corner_radius_all(14)
	frame_style.bg_color = Color(0.05, 0.03, 0.12, 0.9)
	frame_style.set_border_width_all(1)
	frame_style.set_border_color(Color(ach_color.r, ach_color.g, ach_color.b, 0.6))
	icon_frame.add_theme_stylebox_override("panel", frame_style)
	toast.add_child(icon_frame)

	# Pictogram vector icon inside frame
	var icon_panel := Panel.new()
	icon_panel.size = Vector2(48, 48)
	icon_panel.position = Vector2(3, 3)
	icon_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var icon_type: String = str(ach.get("icon", "sword"))
	var icon_color: Color = ach_color
	icon_panel.draw.connect(func(): _draw_badge_icon(icon_panel, icon_type, icon_color))
	icon_frame.add_child(icon_panel)

	# Achievement / Mission unlocked header label
	var header := Label.new()
	header.text = str(ach.get("header", "BADGE UNLOCKED!"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", ach_color)
	header.position = Vector2(74, 14)
	header.size = Vector2(294, 18)
	header.clip_text = true
	toast.add_child(header)

	# Achievement name
	var name_label := Label.new()
	name_label.text = str(ach.get("name", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	name_label.anchor_right = 1.0
	name_label.offset_left = 74.0
	name_label.offset_right = -14.0
	name_label.offset_top = 32.0
	name_label.offset_bottom = 54.0
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast.add_child(name_label)

	# Achievement description
	var desc_label := Label.new()
	desc_label.text = str(ach.get("desc", ""))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 0.9))
	desc_label.anchor_right = 1.0
	desc_label.offset_left = 74.0
	desc_label.offset_right = -14.0
	desc_label.offset_top = 54.0
	desc_label.offset_bottom = 72.0
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast.add_child(desc_label)

	# Slide in from top
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "offset_top", target_top, 0.45)
	tween.parallel().tween_property(toast, "offset_bottom", target_bottom, 0.45)
	tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.25)
	# Hold on screen
	tween.tween_interval(2.5)
	# Slide back up and fade out
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "offset_top", -100.0, 0.35)
	tween.parallel().tween_property(toast, "offset_bottom", -22.0, 0.35)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		if is_instance_valid(toast):
			toast.queue_free()
		get_tree().create_timer(0.2).timeout.connect(_process_achievement_toast_queue)
	)


func _draw_badge_icon(panel: Panel, icon_type: String, icon_color: Color) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s := panel.size
	var c := s / 2.0
	var sc := minf(s.x, s.y) / 40.0

	var outline := Color(0.05, 0.03, 0.12, 0.95)
	var glow := Color(icon_color.r * 1.3, icon_color.g * 1.3, icon_color.b * 1.3, 0.9)

	if icon_type == "sword":
		# Blade pointing up
		var pts := PackedVector2Array([
			c + Vector2(0, -16) * sc,    # tip
			c + Vector2(4, -4) * sc,     # right edge upper
			c + Vector2(3, 6) * sc,      # right edge lower
			c + Vector2(6, 8) * sc,      # right crossguard
			c + Vector2(6, 10) * sc,     # right crossguard bottom
			c + Vector2(2, 10) * sc,     # inner right
			c + Vector2(2, 16) * sc,     # handle bottom right
			c + Vector2(-2, 16) * sc,    # handle bottom left
			c + Vector2(-2, 10) * sc,    # inner left
			c + Vector2(-6, 10) * sc,    # left crossguard bottom
			c + Vector2(-6, 8) * sc,     # left crossguard
			c + Vector2(-3, 6) * sc,     # left edge lower
			c + Vector2(-4, -4) * sc,    # left edge upper
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)

	elif icon_type == "flame":
		# Stylized flame
		var pts := PackedVector2Array([
			c + Vector2(0, -16) * sc,    # top tip
			c + Vector2(5, -8) * sc,     # right upper
			c + Vector2(8, -2) * sc,     # right mid outer
			c + Vector2(7, 6) * sc,      # right lower outer
			c + Vector2(4, 12) * sc,     # right bottom
			c + Vector2(1, 14) * sc,     # bottom right
			c + Vector2(0, 10) * sc,     # bottom center (inner dip)
			c + Vector2(-1, 14) * sc,    # bottom left
			c + Vector2(-4, 12) * sc,    # left bottom
			c + Vector2(-7, 6) * sc,     # left lower outer
			c + Vector2(-8, -2) * sc,    # left mid outer
			c + Vector2(-5, -8) * sc,    # left upper
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		# Inner flame core
		var inner := PackedVector2Array([
			c + Vector2(0, -6) * sc,
			c + Vector2(3, 0) * sc,
			c + Vector2(2, 8) * sc,
			c + Vector2(0, 6) * sc,
			c + Vector2(-2, 8) * sc,
			c + Vector2(-3, 0) * sc,
		])
		var inner_closed := inner.duplicate()
		inner_closed.append(inner[0])
		var inner_color := Color(icon_color.r * 1.4, icon_color.g * 1.2, icon_color.b * 0.5, 0.8)
		panel.draw_colored_polygon(inner, inner_color)

	elif icon_type == "bolt":
		# Reuse lightning bolt shape
		var pts := PackedVector2Array([
			c + Vector2(2, -16) * sc,
			c + Vector2(-10, 2) * sc,
			c + Vector2(-2, 2) * sc,
			c + Vector2(-5, 16) * sc,
			c + Vector2(10, -2) * sc,
			c + Vector2(2, -2) * sc,
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)

	elif icon_type == "crosshair":
		# Crosshair / target
		var r_outer := 14.0 * sc
		var r_inner := 6.0 * sc
		var line_w := 2.5 * sc
		var glow_w := 4.0 * sc
		# Outer ring
		panel.draw_arc(c, r_outer, 0, TAU, 32, outline, glow_w + 2.0, true)
		panel.draw_arc(c, r_outer, 0, TAU, 32, glow, glow_w, true)
		panel.draw_arc(c, r_outer, 0, TAU, 32, icon_color, line_w, true)
		# Inner dot
		panel.draw_circle(c, r_inner * 0.5, icon_color)
		# Crosshair lines (top, bottom, left, right)
		var gap := r_inner
		var reach := r_outer + 3.0 * sc
		panel.draw_line(c + Vector2(0, -gap), c + Vector2(0, -reach), icon_color, line_w, true)
		panel.draw_line(c + Vector2(0, gap), c + Vector2(0, reach), icon_color, line_w, true)
		panel.draw_line(c + Vector2(-gap, 0), c + Vector2(-reach, 0), icon_color, line_w, true)
		panel.draw_line(c + Vector2(gap, 0), c + Vector2(reach, 0), icon_color, line_w, true)

	elif icon_type == "hourglass":
		# Hourglass / Speed timer
		var pts := PackedVector2Array([
			c + Vector2(-12, -15) * sc,
			c + Vector2(12, -15) * sc,
			c + Vector2(2, 0) * sc,
			c + Vector2(12, 15) * sc,
			c + Vector2(-12, 15) * sc,
			c + Vector2(-2, 0) * sc,
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		# Top & bottom caps
		panel.draw_line(c + Vector2(-14, -15) * sc, c + Vector2(14, -15) * sc, glow, 2.5 * sc, true)
		panel.draw_line(c + Vector2(-14, 15) * sc, c + Vector2(14, 15) * sc, glow, 2.5 * sc, true)

	elif icon_type == "crown":
		# Royal 3-pointed Crown
		var pts := PackedVector2Array([
			c + Vector2(-14, -6) * sc,  # Left peak
			c + Vector2(-7, -1) * sc,   # Left dip
			c + Vector2(0, -15) * sc,   # Center peak
			c + Vector2(7, -1) * sc,    # Right dip
			c + Vector2(14, -6) * sc,   # Right peak
			c + Vector2(11, 13) * sc,   # Bottom right
			c + Vector2(-11, 13) * sc,  # Bottom left
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		# Jewels on peaks
		panel.draw_circle(c + Vector2(-14, -8) * sc, 2.0 * sc, Color(1, 1, 1, 0.9))
		panel.draw_circle(c + Vector2(0, -17) * sc, 2.5 * sc, Color(1, 1, 1, 0.9))
		panel.draw_circle(c + Vector2(14, -8) * sc, 2.0 * sc, Color(1, 1, 1, 0.9))

	elif icon_type == "shield":
		# Knight Shield
		var pts := PackedVector2Array([
			c + Vector2(0, -15) * sc,
			c + Vector2(13, -15) * sc,
			c + Vector2(13, -2) * sc,
			c + Vector2(10, 8) * sc,
			c + Vector2(0, 16) * sc,   # Bottom point
			c + Vector2(-10, 8) * sc,
			c + Vector2(-13, -2) * sc,
			c + Vector2(-13, -15) * sc,
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		# Inner emblem cross
		panel.draw_line(c + Vector2(0, -10) * sc, c + Vector2(0, 10) * sc, outline, 2.0 * sc, true)
		panel.draw_line(c + Vector2(-8, -4) * sc, c + Vector2(8, -4) * sc, outline, 2.0 * sc, true)

	elif icon_type == "compass":
		# 4-pointed Star Compass
		var pts := PackedVector2Array([
			c + Vector2(0, -16) * sc,   # North
			c + Vector2(3, -3) * sc,
			c + Vector2(16, 0) * sc,    # East
			c + Vector2(3, 3) * sc,
			c + Vector2(0, 16) * sc,    # South
			c + Vector2(-3, 3) * sc,
			c + Vector2(-16, 0) * sc,   # West
			c + Vector2(-3, -3) * sc,
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		# Outer subtle ring
		panel.draw_arc(c, 9.0 * sc, 0, TAU, 24, glow, 1.8 * sc, true)

	elif icon_type == "trophy":
		# Champion Trophy
		var pts := PackedVector2Array([
			c + Vector2(-11, -15) * sc, # Cup top left
			c + Vector2(11, -15) * sc,  # Cup top right
			c + Vector2(9, -2) * sc,    # Cup right
			c + Vector2(3, 6) * sc,     # Stem top right
			c + Vector2(3, 11) * sc,    # Stem bottom right
			c + Vector2(10, 15) * sc,   # Base right
			c + Vector2(-10, 15) * sc,  # Base left
			c + Vector2(-3, 11) * sc,   # Stem bottom left
			c + Vector2(-3, 6) * sc,    # Stem top left
			c + Vector2(-9, -2) * sc,   # Cup left
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		# Handles
		panel.draw_arc(c + Vector2(-10, -8) * sc, 4.0 * sc, PI * 0.5, PI * 1.5, 12, glow, 2.0 * sc, true)
		panel.draw_arc(c + Vector2(10, -8) * sc, 4.0 * sc, -PI * 0.5, PI * 0.5, 12, glow, 2.0 * sc, true)

	elif icon_type == "star":
		# 5-pointed Grandmaster Star
		var pts := PackedVector2Array()
		for i: int in range(10):
			var angle: float = -PI * 0.5 + float(i) * (PI / 5.0)
			var r: float = (15.0 if i % 2 == 0 else 6.5) * sc
			pts.append(c + Vector2(cos(angle), sin(angle)) * r)
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		
	elif icon_type == "diamond":
		# Completionist Diamond
		var pts := PackedVector2Array([
			c + Vector2(0, -16) * sc,
			c + Vector2(14, 0) * sc,
			c + Vector2(0, 16) * sc,
			c + Vector2(-14, 0) * sc,
		])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, outline, 5.0 * sc, true)
		panel.draw_polyline(closed, glow, 2.5 * sc, true)
		panel.draw_colored_polygon(pts, icon_color)
		panel.draw_polyline(closed, outline, 1.2 * sc, true)
		
	elif icon_type == "question":
		# Hidden locked achievement
		panel.draw_arc(c + Vector2(0, -6) * sc, 5.0 * sc, -PI, 0, 16, glow, 2.0 * sc, true)
		panel.draw_line(c + Vector2(5, -6) * sc, c + Vector2(5, -1) * sc, glow, 2.0 * sc, true)
		panel.draw_line(c + Vector2(5, -1) * sc, c + Vector2(0, 3) * sc, glow, 2.0 * sc, true)
		panel.draw_line(c + Vector2(0, 3) * sc, c + Vector2(0, 7) * sc, glow, 2.0 * sc, true)
		panel.draw_circle(c + Vector2(0, 12) * sc, 1.5 * sc, glow)


# =====================================================
# BADGES UI (MENU OVERLAY)
# =====================================================

func _setup_badges_ui() -> void:
	# --- "BADGES" button on the menu screen ---
	_badges_button = Button.new()
	_badges_button.name = "BadgesButton"
	_badges_button.text = "BADGES"
	_badges_button.anchor_left = 0.5
	_badges_button.anchor_right = 0.5
	_badges_button.offset_left = -120.0
	_badges_button.offset_right = 120.0
	_badges_button.offset_top = 662.0
	_badges_button.offset_bottom = 710.0
	_badges_button.add_theme_font_size_override("font_size", 25)
	_apply_menu_button_style(_badges_button)
	_badges_button.pressed.connect(_open_badges_screen)
	menu_screen.add_child(_badges_button)

	# --- Badges overlay screen ---
	_badges_screen = Control.new()
	_badges_screen.name = "BadgesScreen"
	_badges_screen.visible = false
	_badges_screen.anchor_right = 1.0
	_badges_screen.anchor_bottom = 1.0
	_badges_screen.z_index = 50
	add_child(_badges_screen)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.gui_input.connect(_on_badges_backdrop_input)
	_badges_screen.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _pause_panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -280.0
	panel.offset_bottom = 280.0
	_badges_screen.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "BADGES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.02, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -180.0
	title.offset_right = 180.0
	title.offset_top = 24.0
	title.offset_bottom = 70.0
	panel.add_child(title)

	# Progress label
	var progress_label := Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	progress_label.anchor_left = 0.5
	progress_label.anchor_right = 0.5
	progress_label.offset_left = -180.0
	progress_label.offset_right = 180.0
	progress_label.offset_top = 72.0
	progress_label.offset_bottom = 95.0
	panel.add_child(progress_label)

	_badges_scroll = ScrollContainer.new()
	_badges_scroll.name = "BadgesScroll"
	_badges_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_badges_scroll.scroll_deadzone = 4
	_badges_scroll.anchor_left = 0.5
	_badges_scroll.anchor_right = 0.5
	_badges_scroll.offset_left = -200.0
	_badges_scroll.offset_right = 200.0
	_badges_scroll.offset_top = 104.0
	_badges_scroll.offset_bottom = 530.0
	panel.add_child(_badges_scroll)

	_badges_list = VBoxContainer.new()
	_badges_list.name = "BadgesList"
	_badges_list.add_theme_constant_override("separation", 14)
	_badges_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badges_scroll.add_child(_badges_list)


func _open_badges_screen() -> void:
	sfx.play("tap")
	_check_completionist()
	_refresh_badges_screen()
	_badges_screen.visible = true


func _close_badges_screen() -> void:
	sfx.play("tap")
	_badges_screen.visible = false


func _on_badges_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_badges_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_close_badges_screen()


func _refresh_badges_screen() -> void:
	if settings.games_played >= 50:
		_try_unlock_achievement("dedicated")
	_check_completionist()

	# Update progress label
	var progress_lbl := _badges_screen.get_node_or_null("Panel/ProgressLabel")
	if progress_lbl != null:
		var total: int = settings.ACHIEVEMENTS.size()
		var unlocked_count: int = settings.unlocked_achievements.size()
		progress_lbl.text = str(unlocked_count) + " / " + str(total) + " UNLOCKED"

	# Rebuild badge cards
	for child in _badges_list.get_children():
		_badges_list.remove_child(child)
		child.queue_free()

	for ach: Dictionary in settings.ACHIEVEMENTS:
		_badges_list.add_child(_build_badge_card(ach))


func _build_badge_card(ach: Dictionary) -> Panel:
	var ach_id: String = str(ach.get("id", ""))
	var ach_name: String = str(ach.get("name", ""))
	var ach_desc: String = str(ach.get("desc", ""))
	var ach_icon: String = str(ach.get("icon", "sword"))
	var ach_color: Color = ach.get("color", Color(1, 1, 1))
	var is_hidden: bool = ach.get("hidden", false)
	var unlocked: bool = settings.is_achievement_unlocked(ach_id)
	
	if not unlocked and is_hidden:
		ach_name = "???"
		ach_desc = "Unlock all other badges, songs, and themes."
		ach_icon = "question"
		ach_color = Color(0.4, 0.4, 0.4)

	var card := Panel.new()
	card.name = "Badge_" + ach_id
	card.custom_minimum_size = Vector2(0, 98)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(14)
	if unlocked:
		card_style.bg_color = Color(0.12, 0.10, 0.22, 0.9)
		card_style.set_border_width_all(2)
		card_style.set_border_color(Color(ach_color.r, ach_color.g, ach_color.b, 0.8))
		card_style.set_shadow_size(6)
		card_style.set_shadow_color(Color(ach_color.r, ach_color.g, ach_color.b, 0.3))
	else:
		card_style.bg_color = Color(0.08, 0.06, 0.14, 0.7)
		card_style.set_border_width_all(1)
		card_style.set_border_color(Color(0.3, 0.3, 0.4, 0.5))
	card.add_theme_stylebox_override("panel", card_style)

	# Icon panel (left side, centered vertically)
	var icon_panel := Panel.new()
	icon_panel.size = Vector2(48, 48)
	icon_panel.position = Vector2(16, 25)
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var draw_color: Color = ach_color if unlocked else Color(0.35, 0.35, 0.45, 0.6)
	icon_panel.draw.connect(func(): _draw_badge_icon(icon_panel, ach_icon, draw_color))
	card.add_child(icon_panel)

	# Achievement name
	var name_lbl := Label.new()
	name_lbl.text = ach_name
	name_lbl.anchor_right = 1.0
	name_lbl.offset_left = 76.0
	name_lbl.offset_right = -14.0
	name_lbl.offset_top = 10.0
	name_lbl.offset_bottom = 32.0
	name_lbl.add_theme_font_size_override("font_size", 16)
	if unlocked:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	card.add_child(name_lbl)

	# Achievement description
	var desc_lbl := Label.new()
	desc_lbl.text = ach_desc
	desc_lbl.anchor_right = 1.0
	desc_lbl.offset_left = 76.0
	desc_lbl.offset_right = -14.0
	desc_lbl.offset_top = 34.0
	desc_lbl.offset_bottom = 72.0
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_constant_override("line_spacing", 2)
	if unlocked:
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	else:
		desc_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	card.add_child(desc_lbl)

	# Unlocked / Locked status
	var status_lbl := Label.new()
	status_lbl.anchor_right = 1.0
	status_lbl.offset_left = 76.0
	status_lbl.offset_right = -14.0
	status_lbl.offset_top = 74.0
	status_lbl.offset_bottom = 92.0
	status_lbl.add_theme_font_size_override("font_size", 11)
	if unlocked:
		status_lbl.text = "UNLOCKED"
		status_lbl.add_theme_color_override("font_color", ach_color)
	else:
		status_lbl.text = "LOCKED"
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.45))
	card.add_child(status_lbl)

	return card


# =====================================================
# LEADERBOARD UI
# =====================================================

func _setup_leaderboard_ui() -> void:
	if has_node("/root/LeaderboardManager"):
		var lm = get_node("/root/LeaderboardManager")
		if not lm.leaderboard_status_changed.is_connected(_on_leaderboard_status_changed):
			lm.leaderboard_status_changed.connect(_on_leaderboard_status_changed)

	# --- "LEADERBOARD" button on the menu screen ---
	_leaderboard_button = Button.new()
	_leaderboard_button.name = "LeaderboardButton"
	_leaderboard_button.text = "LEADERBOARD"
	_leaderboard_button.anchor_left = 0.5
	_leaderboard_button.anchor_right = 0.5
	_leaderboard_button.offset_left = -120.0
	_leaderboard_button.offset_right = 120.0
	_leaderboard_button.offset_top = 720.0
	_leaderboard_button.offset_bottom = 768.0
	_leaderboard_button.add_theme_font_size_override("font_size", 16)
	_apply_menu_button_style(_leaderboard_button, _leaderboard_btn_style, _leaderboard_btn_hover_style)
	_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	menu_screen.add_child(_leaderboard_button)


func _on_leaderboard_status_changed(message: String) -> void:
	_show_remap_banner(message)


func _on_leaderboard_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	if has_node("/root/LeaderboardManager"):
		var lm = get_node("/root/LeaderboardManager")
		if lm.is_plugin_available:
			lm.show_leaderboard()
		else:
			var hs: int = settings.high_score if settings != null else 0
			_show_remap_banner("HIGH SCORE: %s PTS" % str(hs))
	else:
		var hs: int = settings.high_score if settings != null else 0
		_show_remap_banner("HIGH SCORE: %s PTS" % str(hs))


func _on_go_leaderboard_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	if has_node("/root/LeaderboardManager"):
		var lm = get_node("/root/LeaderboardManager")
		if lm.is_plugin_available:
			lm.show_leaderboard()
		else:
			var hs: int = settings.high_score if settings != null else 0
			_show_remap_banner("HIGH SCORE: %s PTS" % str(hs))
	else:
		var hs: int = settings.high_score if settings != null else 0
		_show_remap_banner("HIGH SCORE: %s PTS" % str(hs))


func _select_theme(theme_id: String) -> void:
	settings.selected_theme = theme_id
	settings.save_data()
	_apply_theme()
	_refresh_themes_screen()


func _apply_theme() -> void:
	# Board square colors (and the symbols' color keying follow direction_colors).
	direction_colors = _get_theme().get("board", {}).duplicate()
	# Background shader palette.
	_apply_theme_bg_colors()
	# Mutate the shared styleboxes in place — buttons/panels update automatically.
	_apply_style_colors()
	# Re-apply the board squares (they hold duplicated, per-square styleboxes).
	_apply_board_styles()
	_apply_board_colors()
	# Re-style the lives bezel (separate stylebox object).
	_apply_lives_bezel()


func _apply_lives_bezel() -> void:
	var accent2 := _theme_accent2()
	_lives_bezel_style = StyleBoxFlat.new()
	_lives_bezel_style.set_corner_radius_all(12)
	_lives_bezel_style.bg_color = Color(0.08, 0.06, 0.18, 0.8)
	_lives_bezel_style.set_border_width_all(2)
	_lives_bezel_style.set_border_color(Color(accent2.r, accent2.g, accent2.b, 0.6))
	_lives_bezel_style.set_shadow_color(Color(accent2.r, accent2.g, accent2.b, 0.35))
	_lives_bezel_style.set_shadow_size(8)
	if _lives_frame != null and is_instance_valid(_lives_frame):
		_lives_frame.add_theme_stylebox_override("panel", _lives_bezel_style)


func _show_menu() -> void:
	is_story_mode = false
	story_victory_animating = false
	story_bomb_dir = ""
	_update_story_hud_visibility()
	_set_state(settings.GameState.MENU)
	_update_sparks_displays()
	if not _pending_update_info.is_empty() and not _has_prompted_update and not _is_overlay_open():
		var force_update: bool = bool(_pending_update_info.get("force_update", false))
		var r_ver: String = str(_pending_update_info.get("latest_version", ""))
		var r_code: int = int(_pending_update_info.get("version_code", 0))
		if force_update or (r_ver != CURRENT_VERSION_NAME and not settings.is_update_dismissed(r_ver, r_code)):
			_show_update_modal(_pending_update_info)


func _start_game() -> void:
	_setup_initial_game_state()
	if is_story_mode:
		_reset_story_boss_state(story_level)
	_update_story_hud_visibility()
	_set_state(settings.GameState.PLAYING)
	_update_high_score_display()

	if is_story_mode:
		start_new_turn()
	elif settings.first_play:
		_walkthrough_from_options = false
		_start_dynamic_walkthrough()
	else:
		start_new_turn()


func _pause_game() -> void:
	_set_state(settings.GameState.PAUSED)


func _resume_game() -> void:
	_set_state(settings.GameState.PLAYING)
	# Reset timer to avoid accumulated delta during pause
	time_left_in_turn = min(time_left_in_turn, current_time_limit)


func _game_over() -> void:
	# Ensure the center square isn't left mid-squash and the shrink-timer lock is released
	center_square.scale = Vector2.ONE
	_center_scale_locked = false

	sfx.play("game_over")
	_set_state(settings.GameState.GAME_OVER)

	var is_new_record: bool = false
	if not _tamper_flagged:
		is_new_record = settings.update_high_score(score, best_streak_this_game)
	if is_new_record:
		sfx.play_voice("new_high_score", 100, 1.2)
		_haptic_celebration()

	# Update Daily Missions progress for this run (incremental if continuing after a revive)
	var mission_sparks_earned: int = 0
	if not _tamper_flagged:
		var delta_score: int = maxi(0, score - _mission_run_credited_score)
		var delta_swipes: int = maxi(0, total_correct - _mission_run_credited_swipes)
		var delta_frenzies: int = maxi(0, frenzies_triggered_this_game - _mission_run_credited_frenzies)
		var delta_holds: int = maxi(0, _hold_squares_completed_this_game - _mission_run_credited_holds)
		var delta_fast: int = maxi(0, _fast_swipes_this_game - _mission_run_credited_fast)
		var count_this_game: bool = not _mission_run_game_counted

		_mission_run_credited_score = score
		_mission_run_credited_swipes = total_correct
		_mission_run_credited_frenzies = frenzies_triggered_this_game
		_mission_run_credited_holds = _hold_squares_completed_this_game
		_mission_run_credited_fast = _fast_swipes_this_game
		if total_correct > 0 or score > 0:
			_mission_run_game_counted = true

		var completed_missions: Array[Dictionary] = settings.update_daily_missions_from_run(
			delta_score,
			delta_swipes,
			best_streak_this_game,
			delta_frenzies,
			delta_holds,
			_remaps_survived_this_game,
			delta_fast,
			count_this_game
		)
		for m_def: Dictionary in completed_missions:
			var m_reward: int = int(m_def.get("reward", 0))
			mission_sparks_earned += m_reward
			_queue_achievement_toast({
				"header": "MISSION COMPLETE!  +" + str(m_reward) + " SPARKS",
				"name": str(m_def.get("name", "DAILY MISSION")),
				"desc": str(m_def.get("desc", "")),
				"icon": str(m_def.get("icon", "bolt")),
				"color": m_def.get("color", Color(1.0, 0.90, 0.25)),
			})

	_update_sparks_displays()
	var m_sum: Dictionary = settings.get_daily_missions_summary()
	var m_done: int = int(m_sum.get("done", 0))
	var m_total: int = int(m_sum.get("total", 3))
	var total_run_sparks_earned: int = mission_sparks_earned + sparks_collected_in_run
	if _go_sparks_label != null and is_instance_valid(_go_sparks_label):
		if total_run_sparks_earned > 0:
			_go_sparks_label.text = "+" + _format_sparks_compact(total_run_sparks_earned) + " SPARKS!  |  TOTAL: " + _format_sparks_compact(settings.sparks)
			_go_sparks_label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.55))
		else:
			_go_sparks_label.text = "MISSIONS: " + str(m_done) + "/" + str(m_total) + "  |  SPARKS: " + _format_sparks_compact(settings.sparks)
			_go_sparks_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	if _go_double_sparks_btn != null and is_instance_valid(_go_double_sparks_btn):
		_go_double_sparks_btn.visible = true
		_go_double_sparks_btn.disabled = false
		_go_double_sparks_btn.text = "   MISSIONS " + str(m_done) + "/" + str(m_total)
		_go_double_sparks_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))

	frenzy_charges = 0
	has_shield = false
	_update_shield_ui()
	if has_node("/root/AdManager"):
		get_node("/root/AdManager").preload_rewarded_ad()
	_update_frenzy_charge_ui()

	# Populate game over screen
	_set_scaled_score_text(final_score_label, 0, 52)
	_update_high_score_display()
	new_record_badge.visible = is_new_record

	var accuracy := 0.0
	if total_swipes > 0:
		accuracy = clampf(float(total_correct) / float(total_swipes) * 100.0, 0.0, 100.0)
	var best_rx_str := ("%.2fs" % fastest_reaction_this_game) if fastest_reaction_this_game < 900.0 else "--"
	var hold_str := ("%.1fs" % longest_hold_this_game) if longest_hold_this_game > 0.0 else "--"
	stats_label.text = "Streak: %d  |  Accuracy: %d%%\nPerfect: %d  |  Fastest: %s\nFrenzies: %d  |  Max Hold: %s" % [
		best_streak_this_game,
		int(round(accuracy)),
		best_perfect_streak_this_game,
		best_rx_str,
		frenzies_triggered_this_game,
		hold_str
	]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_constant_override("line_spacing", 4)
	if _tamper_flagged:
		stats_label.text += "\n[SECURITY: RUN DISQUALIFIED]"

	_board_aura_tier = 0
	if _board_aura_panel != null and is_instance_valid(_board_aura_panel):
		_board_aura_panel.queue_redraw()

	# Animate score count-up
	_animate_score_countup(final_score_label, score, 1.2)

	# Configure revive button (can only revive once per game run)
	_revive_ready_to_resume = false
	_reset_revive_button_ui()

	# Customize Game Over / Victory labels for Story Mode vs Arcade Mode
	var go_title: Label = $GameOverScreen/GameOverPanel/GameOverTitle
	if is_story_mode:
		if story_level_won:
			if go_title != null:
				go_title.text = "BOSS DEFEATED!"
				go_title.add_theme_font_size_override("font_size", 22)
				go_title.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
			if new_record_badge != null:
				new_record_badge.text = "★ LEVEL " + str(story_level) + " COMPLETE! ★"
				new_record_badge.visible = true
			if revive_btn != null:
				revive_btn.visible = false
			if retry_btn != null:
				if story_level == 1:
					retry_btn.text = "NEXT: LEVEL 2"
				elif story_level == 2:
					retry_btn.text = "NEXT: LEVEL 3"
				elif story_level == 3:
					retry_btn.text = "NEXT: LEVEL 4"
				else:
					retry_btn.text = "REPLAY LEVEL " + str(story_level)
				retry_btn.add_theme_font_size_override("font_size", 16)
		else:
			if go_title != null:
				go_title.text = "BOSS WON!"
				go_title.add_theme_font_size_override("font_size", 26)
				go_title.add_theme_color_override("font_color", Color(1.0, 0.28, 0.34))
			if new_record_badge != null:
				var parts_left: int = _get_alive_boss_parts().size()
				if parts_left > 0:
					new_record_badge.text = "PARTS LEFT: " + str(parts_left) + "/4  •  MAIN HP: " + str(story_boss_hp)
				else:
					new_record_badge.text = "BOSS HP LEFT: " + str(story_boss_hp) + " / " + str(story_boss_max_hp)
				new_record_badge.visible = true
			if retry_btn != null:
				retry_btn.text = "RETRY BOSS"
				retry_btn.add_theme_font_size_override("font_size", 18)
	else:
		if go_title != null:
			go_title.text = "GAME OVER"
			go_title.add_theme_font_size_override("font_size", 32)
			go_title.add_theme_color_override("font_color", Color(1.0, 0.278, 0.341))
		if new_record_badge != null:
			new_record_badge.text = "NEW RECORD!"
			new_record_badge.visible = is_new_record
		if retry_btn != null:
			retry_btn.text = "PLAY AGAIN"
			retry_btn.add_theme_font_size_override("font_size", 18)

	# Check achievements (only on legitimate, non-tampered runs)
	if not _tamper_flagged:
		_check_achievements(accuracy)
		if not is_story_mode and score > 0 and has_node("/root/LeaderboardManager"):
			get_node("/root/LeaderboardManager").submit_score(score)


func _restart_game() -> void:
	_revive_ready_to_resume = false
	_fade_transition(_start_game)


func _go_to_menu() -> void:
	_revive_ready_to_resume = false
	_fade_transition(_show_menu)


# =====================================================
# BUTTON CALLBACKS
# =====================================================

func _on_start_pressed() -> void:
	sfx.play("tap")
	is_story_mode = false
	_fade_transition(_start_game)


func _on_pause_pressed() -> void:
	sfx.play("tap")
	_pause_game()


func _on_resume_pressed() -> void:
	sfx.play("tap")
	_resume_game()


func _on_restart_pressed() -> void:
	sfx.play("tap")
	_restart_game()


func _on_go_menu_pressed() -> void:
	sfx.play("tap")
	_go_to_menu()


func _reset_revive_button_ui() -> void:
	if revive_btn == null or not is_instance_valid(revive_btn):
		return
	revive_btn.visible = not _has_revived_this_game
	revive_btn.disabled = false
	revive_btn.text = "WATCH AD (+3 LIVES)"
	revive_btn.add_theme_font_size_override("font_size", 13)
	revive_btn.clip_contents = true
	revive_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	revive_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.6, 1.0))
	revive_btn.pivot_offset = revive_btn.size / 2.0
	revive_btn.scale = Vector2.ONE
	var accent := _theme_accent()
	var hover := _btn_style.duplicate()
	hover.set_border_color(Color(accent.r, accent.g, accent.b, 0.9))
	hover.set_shadow_color(Color(accent.r, accent.g, accent.b, 0.6))
	hover.set_shadow_size(10)
	revive_btn.add_theme_stylebox_override("normal", _btn_style)
	revive_btn.add_theme_stylebox_override("hover", hover)
	revive_btn.add_theme_stylebox_override("pressed", hover)


func _on_revive_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	if _revive_ready_to_resume:
		# Player watched the ad, lives restored, and now taps RESUME GAME
		_has_revived_this_game = true
		_revive_ready_to_resume = false
		if revive_btn != null and is_instance_valid(revive_btn):
			revive_btn.disabled = true
		_fade_transition(_revive_and_continue)
		return

	# First step: User taps to watch the rewarded ad
	if revive_btn != null and is_instance_valid(revive_btn):
		revive_btn.disabled = true
		revive_btn.text = "LOADING AD..."

	# Trigger rewarded ad view / reward callback
	_show_rewarded_ad_and_revive()


func _show_rewarded_ad_and_revive() -> void:
	var on_reward_granted := func():
		_on_revive_reward_granted()

	var on_dismissed_without_reward := func():
		if not _revive_ready_to_resume:
			_reset_revive_button_ui()

	# Safety fallback in case ad fails silently or gets stuck
	get_tree().create_timer(12.0).timeout.connect(func():
		if not _revive_ready_to_resume and state == settings.GameState.GAME_OVER and revive_btn != null and is_instance_valid(revive_btn) and revive_btn.disabled:
			_reset_revive_button_ui()
	)

	if has_node("/root/AdManager"):
		get_node("/root/AdManager").show_rewarded_ad(on_reward_granted, on_dismissed_without_reward)
	else:
		on_reward_granted.call()


func _on_revive_reward_granted() -> void:
	# 1. Restore lives right away so user sees full hearts
	lives = settings.MAX_LIVES
	_last_displayed_lives = 0
	_update_lives_display()

	# Animate all hearts popping back
	for i in range(hearts.size()):
		if hearts[i] != null and is_instance_valid(hearts[i]):
			var heart := hearts[i]
			heart.pivot_offset = heart.size / 2.0
			heart.scale = Vector2(0.2, 0.2)
			var htw := create_tween()
			htw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			htw.tween_property(heart, "scale", Vector2(1.35, 1.35), 0.18 + float(i) * 0.05)
			htw.tween_property(heart, "scale", Vector2.ONE, 0.12)

	# 2. Sound & celebratory cues
	sfx.play("combo")
	_haptic_celebration()

	# 3. Mark ready to resume
	_revive_ready_to_resume = true

	# 4. Transform revive button into RESUME GAME button
	if revive_btn != null and is_instance_valid(revive_btn):
		revive_btn.disabled = false
		revive_btn.text = "RESUME GAME"
		revive_btn.add_theme_font_size_override("font_size", 17)
		revive_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 1.0))
		revive_btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.7, 1.0))

		# Vibrant neon-green button styling
		var resume_style := _btn_style.duplicate()
		resume_style.bg_color = Color(0.06, 0.22, 0.12, 0.92)
		resume_style.set_border_color(Color(0.2, 0.95, 0.45, 0.95))
		resume_style.set_shadow_color(Color(0.15, 0.9, 0.4, 0.55))
		resume_style.set_shadow_size(12)
		revive_btn.add_theme_stylebox_override("normal", resume_style)

		var resume_hover := resume_style.duplicate()
		resume_hover.bg_color = Color(0.10, 0.30, 0.18, 0.95)
		resume_hover.set_border_color(Color(0.4, 1.0, 0.65, 1.0))
		resume_hover.set_shadow_size(16)
		revive_btn.add_theme_stylebox_override("hover", resume_hover)
		revive_btn.add_theme_stylebox_override("pressed", resume_hover)

		# Punch scale animation to highlight button readiness
		revive_btn.pivot_offset = revive_btn.size / 2.0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(revive_btn, "scale", Vector2(1.12, 1.12), 0.15)
		tw.tween_property(revive_btn, "scale", Vector2.ONE, 0.15)


func _revive_and_continue() -> void:
	lives = settings.MAX_LIVES
	_last_displayed_lives = settings.MAX_LIVES
	_update_lives_display()
	_set_state(settings.GameState.PLAYING)
	_show_remap_banner("REVIVED! +3 LIVES")
	sfx.play("combo")
	_haptic_celebration()
	start_new_turn()


func _on_retry_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	if is_story_mode and story_level_won:
		if story_level == 1:
			story_level = 2
		elif story_level == 2:
			story_level = 3
		elif story_level == 3:
			story_level = 4
	_restart_game()


func _on_share_score_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	_share_game_score()


func _on_rate_app_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	_open_google_play_rating()


func _open_google_play_rating() -> void:
	var package_name := "com.psygames.musicsquare"
	var market_url := "market://details?id=" + package_name
	var web_url := "https://play.google.com/store/apps/details?id=" + package_name
	if OS.get_name() == "Android":
		var err := OS.shell_open(market_url)
		if err != OK:
			OS.shell_open(web_url)
	else:
		OS.shell_open(web_url)


func _share_game_score() -> void:
	# Calculate game stats
	var accuracy := 0.0
	if total_swipes > 0:
		accuracy = clampf(float(total_correct) / float(total_swipes) * 100.0, 0.0, 100.0)

	var share_text := "🎵 MUSIC SQUARE 🟩\n"
	share_text += "Score: " + str(score) + " pts!\n"
	share_text += "🔥 Best Streak: " + str(best_streak_this_game) + "\n"
	share_text += "🎯 Accuracy: " + str(int(round(accuracy))) + "% (" + str(total_correct) + "/" + str(total_swipes) + ")\n"
	if score >= settings.high_score and score > 0:
		share_text += "🏆 NEW HIGH SCORE!\n"
	share_text += "#MusicSquare #IndieGame"

	# Capture viewport image screenshot
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	var img: Image = viewport.get_texture().get_image()
	if img != null:
		var screenshot_path := "user://score_share.png"
		img.save_png(screenshot_path)

	# Copy formatted text to clipboard
	DisplayServer.clipboard_set(share_text)

	# Android / OS Native Share Intent via JNI if available
	if OS.get_name() == "Android":
		_android_share_text_and_image(share_text)

	# Show visual toast confirmation
	_show_share_toast()


func _android_share_text_and_image(text_content: String) -> void:
	# Use Android Intent via JNI if engine bridge exists
	if Engine.has_singleton("GodotShare"):
		var share_plugin = Engine.get_singleton("GodotShare")
		if share_plugin.has_method("shareText"):
			share_plugin.shareText("Music Square Score", "My Score", text_content)
			return

	# Fallback using standard OS share or notification


func _show_share_toast() -> void:
	_haptic_celebration()

	var toast := Panel.new()
	toast.name = "ShareToast"
	toast.z_index = 200
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -170.0
	toast.offset_right = 170.0
	var target_top := 35.0
	var target_bottom := 105.0
	toast.offset_top = -90.0
	toast.offset_bottom = -20.0
	toast.modulate.a = 0.0
	var toast_style := StyleBoxFlat.new()
	toast_style.set_corner_radius_all(16)
	toast_style.bg_color = Color(0.1, 0.15, 0.25, 0.95)
	toast_style.set_border_width_all(2)
	toast_style.set_border_color(Color(0.3, 0.9, 1.0, 0.9))
	toast_style.set_shadow_size(8)
	toast_style.set_shadow_color(Color(0.1, 0.6, 0.9, 0.4))
	toast.add_theme_stylebox_override("panel", toast_style)
	add_child(toast)

	var icon_panel := Panel.new()
	icon_panel.size = Vector2(40, 40)
	icon_panel.position = Vector2(12, 15)
	icon_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	icon_panel.draw.connect(func(): _draw_badge_icon(icon_panel, "trophy", Color(0.3, 0.9, 1.0)))
	toast.add_child(icon_panel)

	var header := Label.new()
	header.text = "SCORE COPIED & SAVED!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	header.position = Vector2(58, 8)
	header.size = Vector2(270, 22)
	toast.add_child(header)

	var name_label := Label.new()
	name_label.text = "Ready to paste & share!"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	name_label.position = Vector2(58, 30)
	name_label.size = Vector2(270, 30)
	toast.add_child(name_label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "offset_top", target_top, 0.45)
	tween.parallel().tween_property(toast, "offset_bottom", target_bottom, 0.45)
	tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.2)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "offset_top", -90.0, 0.35)
	tween.parallel().tween_property(toast, "offset_bottom", -20.0, 0.35)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(toast.queue_free)


func _on_tutorial_understood_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	if _tutorial_return_state == GameSettings.GameState.MENU:
		_set_state(settings.GameState.MENU)
	else:
		_set_state(settings.GameState.PLAYING)
		start_new_turn()


# =====================================================
# CORE GAME LOOP & FRENZY POWER-UPS
# =====================================================

func _process_visual_juice(delta: float) -> void:
	# --- Swipe Trail Decay & Redraw ---
	if not _trail_points.is_empty():
		var now := Time.get_ticks_msec() / 1000.0
		while not _trail_points.is_empty() and (now - float(_trail_points[0]["time"])) > TRAIL_LIFETIME:
			_trail_points.pop_front()
		if _swipe_trail != null and is_instance_valid(_swipe_trail):
			_swipe_trail.queue_redraw()

	# --- Board Aura Animation & Ambient Particles ---
	if _board_aura_tier > 0:
		_board_aura_time += delta
		_board_aura_particle_timer += delta
		var p_interval := 0.22
		if _board_aura_tier == 2:
			p_interval = 0.13
		elif _board_aura_tier == 3:
			p_interval = 0.08

		if _board_aura_particle_timer >= p_interval and state == settings.GameState.PLAYING:
			_board_aura_particle_timer = 0.0
			_emit_board_aura_ambient_particle()

		if _board_aura_panel != null and is_instance_valid(_board_aura_panel):
			_board_aura_panel.queue_redraw()

	# --- Music & Beat-Reactive Shader Update ---
	_audio_pulse = maxf(0.0, _audio_pulse - delta * 3.2)
	var bg_pulse: float = _audio_pulse
	if _song_player != null and _song_player.playing:
		bg_pulse = clampf(bg_pulse + sin(_song_player.get_playback_position() * 8.0) * 0.06, 0.0, 1.0)
	if is_frenzy_active:
		bg_pulse = maxf(bg_pulse, 0.70 + sin(Time.get_ticks_msec() * 0.012) * 0.25)

	var streak_energy: float = clampf(float(streak) / 150.0, 0.0, 1.0)
	if is_frenzy_active:
		streak_energy = 1.0

	if _bg_shader_mat != null:
		if absf(bg_pulse - _last_shader_audio_pulse) > 0.002:
			_last_shader_audio_pulse = bg_pulse
			_bg_shader_mat.set_shader_parameter("audio_pulse", bg_pulse)
		if absf(streak_energy - _last_shader_streak_energy) > 0.002:
			_last_shader_streak_energy = streak_energy
			_bg_shader_mat.set_shader_parameter("streak_energy", streak_energy)

	if settings != null and settings.selected_skin == "equalizer" and state == settings.GameState.PLAYING:
		for dir: String in direction_squares:
			var sq_p: Panel = direction_squares[dir]
			if sq_p != null and is_instance_valid(sq_p):
				sq_p.queue_redraw()
		if center_square != null and is_instance_valid(center_square):
			center_square.queue_redraw()

	# --- Live Board Zone Preview Timer ---
	if _board_zone_preview_active and not _board_zone_dragging:
		_board_zone_preview_timer -= delta
		if _board_zone_preview_timer <= 0.0:
			_exit_board_zone_preview()

	# --- Story Mode Boss & Level Select Preview Animations ---
	_process_story_boss_visuals(delta)


func _process(delta: float) -> void:
	# Continuous visual juice processing (swipe trail decay, board aura animations, music-reactive shader)
	_process_visual_juice(delta)

	if state != settings.GameState.PLAYING:
		return

	if is_story_mode and story_victory_animating:
		time_left_in_turn = current_time_limit
		if center_square != null:
			center_square.scale = Vector2.ONE
		return

	if is_holding_active:
		hold_duration += delta
		_hold_haptic_timer += delta
		_hold_particle_timer += delta

		var current_ratio := clampf(hold_duration / MAX_HOLD_DURATION, 0.0, 1.0)
		var current_pts: int = int(50.0 + 1500.0 * pow(current_ratio, 1.5))
		if hold_duration >= 1.9:
			current_pts += 500

		if _hold_progress_bar != null and is_instance_valid(_hold_progress_bar):
			_hold_progress_bar.value = hold_duration

		if _hold_pts_label != null and is_instance_valid(_hold_pts_label):
			var mult := _current_combo_multiplier()
			var new_hold_text: String
			if hold_duration >= 1.9:
				new_hold_text = "⚡ MAXIMUM CHARGE! +" + _format_number_with_commas(current_pts * mult) + " PTS ⚡"
				_hold_pts_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
			else:
				new_hold_text = "HOLD CHARGE: " + str(snappedf(hold_duration, 0.1)) + "s / 2s  |  +" + _format_number_with_commas(current_pts * mult) + " PTS"
			if _hold_pts_label.text != new_hold_text:
				_hold_pts_label.text = new_hold_text

		# Center square dynamic reactor scaling
		if center_square != null and is_instance_valid(center_square):
			var pulse: float = 1.0 + sin(hold_duration * 14.0) * (0.05 + current_ratio * 0.12)
			center_square.scale = Vector2(pulse, pulse)

		# Electric spark particles radiating between center and target square
		if _hold_particle_timer >= 0.15:
			_hold_particle_timer = 0.0
			var target_pos := _get_board_center(current_target_direction)
			var center_pos := _get_board_center("")
			var mid_point := center_pos.lerp(target_pos, randf_range(0.2, 0.85))
			var col: Color = direction_colors.get(current_target_direction, Color(0.2, 0.9, 1.0))
			_burst_particles(mid_point, col, int(2 + current_ratio * 4))

		# Rhythmic haptic tick speeding up as charge builds
		var haptic_interval := lerpf(0.35, 0.12, current_ratio)
		if _hold_haptic_timer >= haptic_interval:
			_hold_haptic_timer = 0.0
			_haptic_tap()

		# Redraw decreasing hold countdown ring every frame
		if center_square != null and is_instance_valid(center_square):
			center_square.queue_redraw()
		if current_target_direction in direction_squares:
			var target_panel: Panel = direction_squares[current_target_direction]
			if target_panel != null and is_instance_valid(target_panel):
				target_panel.queue_redraw()

		# Max hold duration reached!
		if hold_duration >= MAX_HOLD_DURATION:
			_finish_hold_mode()
		return

	if _is_walkthrough_active:
		time_left_in_turn = current_time_limit
		hold_exit_buffer = 0.0
		frenzy_exit_buffer = 0.0
		if is_frenzy_active:
			frenzy_time_left = 15.0
			frenzy_switch_timer += delta
			if frenzy_switch_timer >= 1.0:
				frenzy_switch_timer -= 1.0
				_pick_new_frenzy_special_square()
			if _frenzy_hud_label != null and is_instance_valid(_frenzy_hud_label):
				_frenzy_hud_label.text = "⚡ FRENZY ACTIVE! SWIPE ANY DIRECTION! ⚡"
		return

	if is_frenzy_active:
		hold_exit_buffer = 0.0
		frenzy_exit_buffer = 0.0
		frenzy_time_left -= delta
		frenzy_switch_timer += delta
		if frenzy_switch_timer >= 1.0:
			frenzy_switch_timer -= 1.0
			_pick_new_frenzy_special_square()

		if _frenzy_hud_label != null and is_instance_valid(_frenzy_hud_label):
			var new_frenzy_text := "⚡ FRENZY: " + str(snappedf(maxf(0.0, frenzy_time_left), 0.1)) + "s  |  PINK = 3x! ⚡"
			if _frenzy_hud_label.text != new_frenzy_text:
				_frenzy_hud_label.text = new_frenzy_text

		if center_square != null:
			center_square.scale = Vector2.ONE

		if frenzy_time_left <= 0.0:
			_end_frenzy_mode()
			return
	else:
		if frenzy_exit_buffer > 0.0:
			frenzy_exit_buffer -= delta
			time_left_in_turn = current_time_limit
			return

		if hold_exit_buffer > 0.0:
			hold_exit_buffer -= delta
			time_left_in_turn = current_time_limit
			return

		time_left_in_turn -= delta

		# Update center square shrink (visual timer)
		if not _center_scale_locked:
			var shrink_ratio: float = clampf(time_left_in_turn / current_time_limit, 0.4, 1.0)
			center_square.scale = Vector2(shrink_ratio, shrink_ratio)

		# Redraw animated rings/halos (Hold, Double-Dash, Shield, or pulsing Power-Ups)
		if is_hold_turn or is_double_turn or has_shield:
			if center_square != null and is_instance_valid(center_square):
				center_square.queue_redraw()
			if current_target_direction in direction_squares:
				var target_panel: Panel = direction_squares[current_target_direction]
				if target_panel != null and is_instance_valid(target_panel):
					target_panel.queue_redraw()
		if powerup_square_dir != "" and powerup_square_dir in direction_squares:
			var p_panel: Panel = direction_squares[powerup_square_dir]
			if p_panel != null and is_instance_valid(p_panel):
				p_panel.queue_redraw()
		if is_story_mode:
			if center_square != null and is_instance_valid(center_square):
				center_square.queue_redraw()
			if story_level == 4:
				for l4_dir: String in direction_squares:
					var l4_panel: Panel = direction_squares[l4_dir]
					if l4_panel != null and is_instance_valid(l4_panel):
						l4_panel.queue_redraw()
			for b_dir: String in story_bomb_dirs:
				if b_dir in direction_squares:
					var b_panel: Panel = direction_squares[b_dir]
					if b_panel != null and is_instance_valid(b_panel):
						b_panel.queue_redraw()

		# Timeout check
		if time_left_in_turn <= 0.0:
			_on_turn_timeout()


func _calculate_turn_time_limit(is_hold: bool = false) -> float:
	# Smoothly scales tempo with both score and active streak so gameplay speeds up
	# naturally as the player enters a rhythm flow-state, and breathes back on mistakes.
	var score_reduction: float = (float(score) / 100000.0) * 0.035
	var streak_reduction: float = minf(0.24, float(streak) * 0.0024)
	var total_reduction: float = score_reduction + streak_reduction
	if is_hold:
		return maxf(1.45, 2.35 - total_reduction)
	return maxf(0.62, GameSettings.INITIAL_TIME_LIMIT - total_reduction)


func start_new_turn() -> void:
	if state != settings.GameState.PLAYING:
		return

	# Kill any in-flight center flash tween so its stale restore callback
	# can't overwrite the new target color we're about to set
	if _center_flash_tween is Tween:
		_center_flash_tween.kill()
		_center_flash_tween = null

	if is_story_mode:
		_start_story_turn()
		return

	# 0. Direction remapping for advanced difficulty (only when NOT in frenzy)
	if not is_frenzy_active:
		turns_since_remap += 1
		if score >= settings.REMAP_SCORE_THRESHOLD and turns_since_remap >= turns_until_remap:
			turns_since_remap = 0
			turns_until_remap = _roll_remap_interval()
			_remap_directions()

	# 1. Reset previous turn's uncollected power-up, hold, and double-dash state
	powerup_square_dir = ""
	powerup_type = ""
	_cleanup_hold_ui()
	_cleanup_double_turn_ui()
	is_holding_active = false
	hold_duration = 0.0
	is_double_turn = false
	double_turn_step = 0

	# 2. Dynamic time limit based on score & streak
	current_time_limit = _calculate_turn_time_limit(false)
	time_left_in_turn = current_time_limit
	_turn_start_time = Time.get_ticks_msec() / 1000.0

	# 3. Set new target color
	set_random_center_color()

	# 4. Special Turn Mechanics (MUTUALLY EXCLUSIVE when not in Frenzy)
	is_hold_turn = false
	if not is_frenzy_active:
		var center_color: Color = direction_colors.get(current_target_direction, Color(0, 0, 0, 0))
		var valid_dirs: Array[String] = []
		for d: String in direction_squares:
			if not direction_colors[d].is_equal_approx(center_color):
				valid_dirs.append(d)
		var roll := randf()
		# Roll 1: Frenzy trigger power-up (0.8% rare chance once score >= 100)
		if roll < 0.008 and score >= 100 and valid_dirs.size() > 0:
			powerup_square_dir = valid_dirs.pick_random()
			powerup_type = "frenzy"
		# Roll 2: Frenzy +5s Time Booster (2.2% chance)
		elif roll < 0.030 and valid_dirs.size() > 0:
			powerup_square_dir = valid_dirs.pick_random()
			powerup_type = "frenzy_boost"
		# Roll 3: Aegis Neon Shield (3.0% chance when unshielded)
		elif roll < 0.060 and not has_shield and valid_dirs.size() > 0:
			powerup_square_dir = valid_dirs.pick_random()
			powerup_type = "shield"
		# Roll 4: Neon Spark Jackpot (3.0% chance — instant +5 Sparks & score burst!)
		elif roll < 0.090 and valid_dirs.size() > 0:
			powerup_square_dir = valid_dirs.pick_random()
			powerup_type = "spark_jackpot"
		# Roll 5: Hold & Charge Turn (5.0% chance)
		elif roll < 0.140:
			is_hold_turn = true
			current_time_limit = _calculate_turn_time_limit(true)
			time_left_in_turn = current_time_limit
			_setup_hold_turn_indicator()
		# Roll 6: Double-Dash 2x Rush Turn (5.0% chance once score >= 150)
		elif roll < 0.190 and score >= 150:
			is_double_turn = true
			double_turn_step = 1
			current_time_limit = maxf(0.85, _calculate_turn_time_limit(false) * 1.08)
			time_left_in_turn = current_time_limit
			_setup_double_turn_indicator()

	# 5. Apply board colors and symbols
	_apply_board_colors()

	# 6. Pulse animation on center square
	_pulse_center()


func set_random_center_color() -> void:
	if _center_live_style == null:
		_center_live_style = _center_panel_style.duplicate() as StyleBoxFlat
		center_square.add_theme_stylebox_override("panel", _center_live_style)
	if is_story_mode:
		current_target_direction = ""
		_last_target_color = Color(0.95, 0.97, 1.0, 1.0)
		_center_live_style.bg_color = _last_target_color
		center_square.queue_redraw()
		return
	if is_frenzy_active:
		_center_live_style.bg_color = Color(1.35, 1.15, 0.15)
		center_square.queue_redraw()
		return

	var candidates: Array[String] = []
	for d: String in direction_colors:
		if direction_colors[d] != _last_target_color:
			candidates.append(d)
	if candidates.is_empty():
		for d: String in direction_colors:
			candidates.append(d)

	current_target_direction = candidates.pick_random()
	_last_target_color = direction_colors[current_target_direction]

	_center_live_style.bg_color = _last_target_color
	center_square.queue_redraw()


func _activate_frenzy_mode(from_overdrive: bool = false) -> void:
	is_frenzy_active = true
	hold_exit_buffer = 0.0
	frenzy_exit_buffer = 0.0
	is_swiping = false
	active_touch_index = -1
	_center_scale_locked = false
	var bonus_time: float = float(frenzy_charges) * 5.0
	frenzy_time_left = 5.0 + bonus_time
	var consumed_charges := frenzy_charges
	frenzy_charges = 0
	_update_frenzy_charge_ui()

	frenzy_special_dir = ""
	frenzy_switch_timer = 0.0
	powerup_square_dir = ""
	powerup_type = ""
	is_hold_turn = false
	is_holding_active = false
	is_double_turn = false
	double_turn_step = 0
	_cleanup_hold_ui()
	_cleanup_double_turn_ui()
	_frenzy_count_this_game += 1
	frenzies_triggered_this_game += 1
	_audio_pulse = 1.0
	if _current_combo_multiplier() >= settings.COMBO_MAX_MULTIPLIER:
		_frenzies_at_max_multiplier += 1
	else:
		_frenzies_at_max_multiplier = 0
	_check_in_game_achievements()

	_pick_new_frenzy_special_square()

	sfx.play("combo")
	if from_overdrive:
		sfx.play_voice("overdrive", 85, 1.2)
	else:
		sfx.play_voice("frenzy_mode", 80, 1.2)
	_haptic_frenzy()

	if from_overdrive:
		if consumed_charges > 0:
			_show_remap_banner("🔥 OVERDRIVE FRENZY +" + str(int(bonus_time)) + "s! 🔥")
		else:
			_show_remap_banner("🔥 OVERDRIVE FRENZY! 🔥")
	elif consumed_charges > 0:
		_show_remap_banner("⚡ FRENZY +" + str(int(bonus_time)) + "s BOOSTED! ⚡")
	else:
		_show_remap_banner("⚡ FRENZY MODE! ⚡")

	var hud := $GameScreen/GameHUD
	if hud != null:
		if _frenzy_hud_label == null or not is_instance_valid(_frenzy_hud_label):
			_frenzy_hud_label = Label.new()
			_frenzy_hud_label.name = "FrenzyHUDLabel"
			var arcade_font := _make_arcade_font(0.65)
			if arcade_font != null:
				_frenzy_hud_label.add_theme_font_override("font", arcade_font)
			_frenzy_hud_label.add_theme_font_size_override("font_size", 16)
			_frenzy_hud_label.add_theme_color_override("font_color", Color(1.8, 1.4, 0.2))
			_frenzy_hud_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.25, 1.0))
			_frenzy_hud_label.add_theme_constant_override("outline_size", 6)
			_frenzy_hud_label.add_theme_color_override("font_shadow_color", Color(0.8, 0.1, 0.6, 0.8))
			_frenzy_hud_label.add_theme_constant_override("shadow_offset_y", 3)
			_frenzy_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_frenzy_hud_label.anchor_left = 0.0
			_frenzy_hud_label.anchor_right = 1.0
			_frenzy_hud_label.offset_left = 0.0
			_frenzy_hud_label.offset_right = 0.0
			_frenzy_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
			hud.add_child(_frenzy_hud_label)
		var mid_y: float = _get_hud_mid_zone_y()
		_frenzy_hud_label.offset_top = mid_y - 17.0
		_frenzy_hud_label.offset_bottom = mid_y + 17.0
		_frenzy_hud_label.text = "⚡ FRENZY: " + str(snappedf(frenzy_time_left, 0.1)) + "s  |  PINK = 3x! ⚡"
		_frenzy_hud_label.visible = true

	_apply_board_colors()
	_update_streak_visuals()
	_update_combo_hud()


func _end_frenzy_mode() -> void:
	var was_active := is_frenzy_active
	is_frenzy_active = false
	frenzy_time_left = 0.0
	frenzy_special_dir = ""
	frenzy_switch_timer = 0.0

	if _frenzy_hud_label != null and is_instance_valid(_frenzy_hud_label):
		_frenzy_hud_label.queue_free()
		_frenzy_hud_label = null

	if was_active:
		if _is_walkthrough_active:
			frenzy_exit_buffer = 0.0
			_apply_board_colors()
			return
		frenzy_exit_buffer = 0.6
		_show_remap_banner("FRENZY OVER")
		start_new_turn()
		_update_streak_visuals()
		_update_combo_hud()


func _pick_new_frenzy_special_square() -> void:
	if not is_frenzy_active:
		return

	var dirs: Array[String] = ["up", "down", "left", "right"]
	if frenzy_special_dir != "":
		dirs.erase(frenzy_special_dir)

	dirs.shuffle()
	frenzy_special_dir = dirs[0]
	_apply_board_colors()

	# Visual scale pulse on the newly chosen special square
	if frenzy_special_dir in direction_squares:
		var sq: Panel = direction_squares[frenzy_special_dir]
		if sq != null and is_instance_valid(sq):
			var tw := create_tween()
			tw.tween_property(sq, "scale", Vector2(1.18, 1.18), 0.08)
			tw.tween_property(sq, "scale", Vector2.ONE, 0.12)

	_haptic_tap()


# =====================================================
# DIRECTION REMAPPING (advanced difficulty)
# =====================================================

# Picks how many turns to wait before the next remap.
# Random in [MIN, MAX] inclusive, re-rolled after each remap so the
# player can't count turns to predict the switch.
func _roll_remap_interval() -> int:
	return randi_range(settings.REMAP_INTERVAL_TURNS_MIN, settings.REMAP_INTERVAL_TURNS_MAX)


func _remap_directions() -> void:
	var keys: Array = ["up", "down", "left", "right"]
	var original_colors: Array = []
	for k: String in keys:
		original_colors.append(direction_colors[k])

	# Generate a strict derangement (0 fixed points: every single square gets a new color)
	var new_colors: Array = original_colors.duplicate()
	var found_derangement: bool = false
	var attempts: int = 0

	while not found_derangement and attempts < 40:
		new_colors.shuffle()
		found_derangement = true
		for i in range(keys.size()):
			if new_colors[i].is_equal_approx(original_colors[i]):
				found_derangement = false
				break
		attempts += 1

	# Mathematical guarantee: if random shuffle didn't produce a derangement,
	# cyclic shift by random offset in [1, 2, 3] guarantees 100% true derangement.
	if not found_derangement:
		var shift: int = randi_range(1, keys.size() - 1)
		new_colors.clear()
		for i in range(keys.size()):
			new_colors.append(original_colors[(i + shift) % keys.size()])

	for i in range(keys.size()):
		direction_colors[keys[i]] = new_colors[i]

	_remaps_survived_this_game += 1
	_check_in_game_achievements()

	sfx.play("remap")
	_haptic_shuffle()
	_animate_remap_squares()
	_show_remap_banner("SHUFFLED!")


func _animate_remap_squares() -> void:
	var board: Control = $GameScreen/Board
	if board == null or not is_instance_valid(board):
		_apply_board_colors()
		return

	# Reset all individual squares so they stay flat and intact (no individual spinning)
	for dir: String in direction_squares:
		var panel: Panel = direction_squares[dir]
		if panel != null and is_instance_valid(panel):
			panel.rotation_degrees = 0.0
			panel.scale = Vector2.ONE
	_apply_board_colors()

	# Set pivot to the exact geometric center of the cross board (center_square)
	var board_center: Vector2 = center_square.position + center_square.size / 2.0
	board.pivot_offset = board_center
	board.rotation_degrees = 0.0

	# Randomly choose clockwise (+360°) or counter-clockwise (-360°) spin
	var spin_degrees: float = 360.0 if randf() > 0.5 else -360.0
	var half_spin: float = spin_degrees * 0.5

	var board_tween := create_tween()

	# Phase 1: Accelerate into spin to 180° + scale lift (0.16s)
	board_tween.set_parallel(true)
	board_tween.set_trans(Tween.TRANS_QUAD)
	board_tween.set_ease(Tween.EASE_IN)
	board_tween.tween_property(board, "rotation_degrees", half_spin, 0.16)
	board_tween.tween_property(board, "scale", Vector2(1.12, 1.12), 0.16)

	# Phase 2: Mid-spin at 180°: Ignite new colors & emit vortex spark flares
	board_tween.chain().tween_callback(func():
		if is_instance_valid(board):
			_apply_board_colors()
			for dir: String in direction_squares:
				var p: Panel = direction_squares[dir]
				if p != null and is_instance_valid(p):
					_burst_particles(p.global_position + p.size / 2.0, direction_colors.get(dir, Color.WHITE), 6)
			_burst_particles(center_square.global_position + center_square.size / 2.0, Color.WHITE, 8)
	)

	# Phase 3: Complete 360° spin with elastic overshoot snap & scale settle (0.22s)
	board_tween.chain().set_parallel(true)
	board_tween.set_trans(Tween.TRANS_BACK)
	board_tween.set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board, "rotation_degrees", spin_degrees, 0.22)
	board_tween.tween_property(board, "scale", Vector2.ONE, 0.22)

	# Phase 4: Clean reset
	board_tween.chain().tween_callback(func():
		if is_instance_valid(board):
			board.rotation_degrees = 0.0
			board.scale = Vector2.ONE
			_apply_board_colors()
	)

	# Center target square punch pulse
	if center_square != null and is_instance_valid(center_square):
		center_square.pivot_offset = center_square.size / 2.0
		var c_tween := create_tween()
		c_tween.set_trans(Tween.TRANS_BACK)
		c_tween.set_ease(Tween.EASE_OUT)
		c_tween.tween_property(center_square, "scale", Vector2(1.22, 1.22), 0.16)
		c_tween.tween_property(center_square, "scale", Vector2.ONE, 0.22)


func _show_remap_banner(text: String) -> void:
	var label := Label.new()
	label.text = text
	var banner_fs: int = 24
	if text.length() > 28:
		banner_fs = 15
	elif text.length() > 20:
		banner_fs = 18
	label.add_theme_font_size_override("font_size", banner_fs)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = 12.0
	label.offset_right = -12.0
	label.clip_text = true
	var mid_y: float = _get_hud_mid_zone_y()
	label.offset_top = mid_y - 25.0
	label.offset_bottom = mid_y + 25.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.pivot_offset = Vector2(258, 25)
	label.z_index = 100
	label.scale = Vector2(0.5, 0.5)
	label.modulate.a = 0.0
	floating_container.add_child(label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector2(1, 1), 0.25)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


# =====================================================
# HOLD CHARGE MECHANIC (5% CHANCE TURN)
# =====================================================

func _setup_hold_turn_indicator() -> void:
	if _hold_indicator_label == null or not is_instance_valid(_hold_indicator_label):
		_hold_indicator_label = Label.new()
		_hold_indicator_label.name = "HoldIndicatorLabel"
		_hold_indicator_label.text = "HOLD & CHARGE!"
		_hold_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hold_indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hold_indicator_label.add_theme_font_size_override("font_size", 20)
		_hold_indicator_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		_hold_indicator_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_hold_indicator_label.add_theme_constant_override("shadow_offset_x", 2)
		_hold_indicator_label.add_theme_constant_override("shadow_offset_y", 2)
		_hold_indicator_label.anchor_left = 0.0
		_hold_indicator_label.anchor_right = 1.0
		_hold_indicator_label.offset_left = 0.0
		_hold_indicator_label.offset_right = 0.0
		_hold_indicator_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_hold_indicator_label.z_index = 80
		var hud := $GameScreen/GameHUD
		if hud != null:
			hud.add_child(_hold_indicator_label)

	var mid_y: float = _get_hud_mid_zone_y()
	_hold_indicator_label.offset_top = mid_y - 15.0
	_hold_indicator_label.offset_bottom = mid_y + 15.0
	_hold_indicator_label.visible = true
	# Flash center square to notify player
	var flash_tween := create_tween()
	flash_tween.tween_property(center_square, "scale", Vector2(1.2, 1.2), 0.15)
	flash_tween.tween_property(center_square, "scale", Vector2.ONE, 0.15)


func _create_hold_charging_ui(direction: String) -> void:
	var hud := $GameScreen/GameHUD
	if hud == null:
		return

	if _hold_hud_container != null and is_instance_valid(_hold_hud_container):
		_hold_hud_container.queue_free()

	_hold_hud_container = Control.new()
	_hold_hud_container.name = "HoldHUDContainer"
	_hold_hud_container.anchor_left = 0.0
	_hold_hud_container.anchor_right = 1.0
	_hold_hud_container.offset_left = 0.0
	_hold_hud_container.offset_right = 0.0
	var mid_y: float = _get_hud_mid_zone_y()
	_hold_hud_container.offset_top = mid_y - 28.0
	_hold_hud_container.offset_bottom = mid_y + 28.0
	_hold_hud_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hold_hud_container.z_index = 90
	hud.add_child(_hold_hud_container)

	# Live points & duration label
	_hold_pts_label = Label.new()
	_hold_pts_label.name = "HoldPtsLabel"
	_hold_pts_label.text = "HOLD CHARGE: 0.0s / 2s  |  +50 PTS"
	_hold_pts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_pts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hold_pts_label.add_theme_font_size_override("font_size", 15)
	_hold_pts_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	_hold_pts_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hold_pts_label.add_theme_constant_override("shadow_offset_x", 2)
	_hold_pts_label.add_theme_constant_override("shadow_offset_y", 2)
	_hold_pts_label.anchor_left = 0.0
	_hold_pts_label.anchor_right = 1.0
	_hold_pts_label.offset_left = 0.0
	_hold_pts_label.offset_right = 0.0
	_hold_pts_label.offset_top = 0.0
	_hold_pts_label.offset_bottom = 22.0
	_hold_pts_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hold_hud_container.add_child(_hold_pts_label)

	# Neon Progress Bar
	_hold_progress_bar = ProgressBar.new()
	_hold_progress_bar.name = "HoldProgressBar"
	_hold_progress_bar.min_value = 0.0
	_hold_progress_bar.max_value = MAX_HOLD_DURATION
	_hold_progress_bar.value = 0.0
	_hold_progress_bar.show_percentage = false
	_hold_progress_bar.anchor_left = 0.5
	_hold_progress_bar.anchor_right = 0.5
	_hold_progress_bar.offset_left = -165.0
	_hold_progress_bar.offset_right = 165.0
	_hold_progress_bar.offset_top = 25.0
	_hold_progress_bar.offset_bottom = 39.0
	_hold_progress_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var bar_bg := StyleBoxFlat.new()
	bar_bg.set_corner_radius_all(7)
	bar_bg.bg_color = Color(0.08, 0.06, 0.16, 0.85)
	bar_bg.set_border_width_all(1)
	bar_bg.set_border_color(Color(0.3, 0.3, 0.5, 0.6))
	_hold_progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.set_corner_radius_all(7)
	var fill_col: Color = direction_colors.get(direction, Color(0.2, 0.9, 1.0))
	bar_fill.bg_color = fill_col
	bar_fill.set_shadow_size(6)
	bar_fill.set_shadow_color(Color(fill_col.r, fill_col.g, fill_col.b, 0.6))
	_hold_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	_hold_hud_container.add_child(_hold_progress_bar)

	# Encouragement hint label
	var hint := Label.new()
	hint.name = "HoldHintLabel"
	hint.text = "HOLD UP TO 2 SECONDS FOR MAXIMUM SCORE!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_left = 0.0
	hint.offset_right = 0.0
	hint.offset_top = 42.0
	hint.offset_bottom = 56.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hold_hud_container.add_child(hint)


func _start_hold_mode(direction: String) -> void:
	if is_holding_active or is_frenzy_active:
		return
	total_swipes += 1
	is_holding_active = true
	hold_duration = 0.0
	_hold_haptic_timer = 0.0
	_hold_particle_timer = 0.0
	_center_scale_locked = true

	if _hold_indicator_label != null and is_instance_valid(_hold_indicator_label):
		_hold_indicator_label.visible = false

	_create_hold_charging_ui(direction)

	sfx.play("remap")
	_haptic_tap()


func _finish_hold_mode() -> void:
	if not is_holding_active and not is_hold_turn:
		return

	if _is_walkthrough_active and _walkthrough_step == 3:
		var walkthrough_hold_dur := clampf(hold_duration, 0.0, MAX_HOLD_DURATION)
		is_holding_active = false
		hold_duration = 0.0
		_center_scale_locked = false
		is_swiping = false
		active_touch_index = -1
		hold_exit_buffer = 0.0
		if center_square != null and is_instance_valid(center_square):
			center_square.scale = Vector2.ONE
			center_square.queue_redraw()
		if direction_squares.has("down") and is_instance_valid(direction_squares["down"]):
			direction_squares["down"].queue_redraw()
		_cleanup_hold_ui()

		if walkthrough_hold_dur >= 1.0:
			is_hold_turn = false
			_walkthrough_advancing = true
			sfx.play("unlock")
			_haptic_celebration()
			_burst_particles(_get_board_center("down"), Color(1.0, 0.9, 0.2), 16)
			_flash_square("down", Color(1.0, 0.9, 0.2, 0.9))
			_walkthrough_overlay.flash_success("MAX CHARGE!")
			_advance_walkthrough()
		else:
			# Released too early: keep hold turn active so player can retry immediately
			is_hold_turn = true
			sfx.play("wrong")
			_haptic_wrong()
			_setup_hold_turn_indicator()
			_walkthrough_overlay.flash_reminder("Hold down until the ring fills!")
		return

	var final_dur := clampf(hold_duration, 0.25, MAX_HOLD_DURATION)
	is_holding_active = false
	is_hold_turn = false
	_center_scale_locked = false
	is_swiping = false
	active_touch_index = -1
	hold_exit_buffer = 0.45

	if center_square != null and is_instance_valid(center_square):
		center_square.scale = Vector2.ONE

	# Calculate progressive points (longer hold = exponentially more points)
	var ratio: float = clampf(final_dur / MAX_HOLD_DURATION, 0.05, 1.0)
	var base_pts: int = int(50.0 + 1500.0 * pow(ratio, 1.5))
	var is_max := (final_dur >= 1.9)
	if is_max:
		base_pts += 500
		_hold_squares_completed_this_game += 1

	var mult := _current_combo_multiplier()
	var earned := base_pts * mult
	score += earned
	total_correct += 1
	if total_swipes < total_correct:
		total_swipes = total_correct
	streak += 1
	if streak > best_streak_this_game:
		best_streak_this_game = streak

	if lives == 1:
		_clutch_swipes_this_game += 1
	else:
		_clutch_swipes_this_game = 0

	if final_dur > longest_hold_this_game:
		longest_hold_this_game = final_dur
	_audio_pulse = minf(1.0, _audio_pulse + (0.95 if is_max else 0.7))

	update_score_display()
	_update_combo_hud()
	_update_streak_visuals()

	# Dramatic finishing burst and audio
	var target_pos := _get_board_center(current_target_direction)
	var col: Color = direction_colors.get(current_target_direction, Color(0.2, 0.9, 1.0))
	_burst_particles(target_pos, col, 16 if is_max else 8)
	_burst_particles(_get_board_center(""), Color(1.0, 1.0, 1.0), 10 if is_max else 6)
	_shake_screen(12.0 if is_max else 6.0)

	if is_max:
		sfx.play("unlock")
		sfx.play_voice("max_charge", 65, 1.5)
		_haptic_frenzy()
		_show_persistent_label("MAX CHARGE! +" + str(earned), target_pos, Color(1.0, 0.9, 0.2), true)
	else:
		sfx.play("combo")
		if final_dur >= 2.5:
			_haptic_frenzy()
		else:
			_haptic_combo()
		_show_persistent_label("+" + str(earned) + " (" + str(snappedf(final_dur, 0.1)) + "s HOLD)", target_pos, col, true)

	_cleanup_hold_ui()
	_add_fever_charge(8.0 if is_max else 4.0)
	_check_in_game_achievements()

	# If Overdrive Fever reached 100% from Hold completion, unleash Frenzy!
	if fever_meter >= 100.0 and not is_frenzy_active:
		fever_meter = 0.0
		_activate_frenzy_mode(true)

	# Start next turn immediately so hold color never lingers!
	start_new_turn()


func _cleanup_hold_ui() -> void:
	if _hold_indicator_label != null and is_instance_valid(_hold_indicator_label):
		_hold_indicator_label.queue_free()
		_hold_indicator_label = null
	if _hold_hud_container != null and is_instance_valid(_hold_hud_container):
		_hold_hud_container.queue_free()
		_hold_hud_container = null
	_hold_progress_bar = null
	_hold_pts_label = null


func _setup_double_turn_indicator() -> void:
	if _double_indicator_label == null or not is_instance_valid(_double_indicator_label):
		_double_indicator_label = Label.new()
		_double_indicator_label.name = "DoubleIndicatorLabel"
		var arcade_font := _make_arcade_font(0.6)
		if arcade_font != null:
			_double_indicator_label.add_theme_font_override("font", arcade_font)
		_double_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_double_indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_double_indicator_label.add_theme_font_size_override("font_size", 18)
		_double_indicator_label.add_theme_color_override("font_color", Color(1.5, 0.95, 0.25))
		_double_indicator_label.add_theme_color_override("font_outline_color", Color(0.16, 0.04, 0.22, 1.0))
		_double_indicator_label.add_theme_constant_override("outline_size", 5)
		_double_indicator_label.anchor_left = 0.0
		_double_indicator_label.anchor_right = 1.0
		_double_indicator_label.offset_left = 0.0
		_double_indicator_label.offset_right = 0.0
		_double_indicator_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_double_indicator_label.z_index = 82
		var hud := $GameScreen/GameHUD
		if hud != null:
			hud.add_child(_double_indicator_label)

	var mid_y: float = _get_hud_mid_zone_y()
	_double_indicator_label.offset_top = mid_y - 16.0
	_double_indicator_label.offset_bottom = mid_y + 16.0
	_double_indicator_label.text = "⚡ 2x DOUBLE RUSH! (1/2) ⚡"
	_double_indicator_label.add_theme_color_override("font_color", Color(1.5, 0.95, 0.25))
	_double_indicator_label.visible = true


func _cleanup_double_turn_ui() -> void:
	if _double_indicator_label != null and is_instance_valid(_double_indicator_label):
		_double_indicator_label.queue_free()
		_double_indicator_label = null


# =====================================================
# HAPTICS & VIBRATION PATTERNS
# =====================================================

func _can_vibrate() -> bool:
	return settings.haptics_enabled and is_inside_tree()


func _haptic(duration_msec: int) -> void:
	if _can_vibrate():
		Input.vibrate_handheld(duration_msec)


# Quick crisp micro-pulse for UI buttons
func _haptic_tap() -> void:
	if _can_vibrate():
		Input.vibrate_handheld(25)


# Snappy light feedback on a standard correct swipe
func _haptic_correct() -> void:
	if _can_vibrate():
		Input.vibrate_handheld(35)


# Ascending double-tap for combo level-ups and high streaks
func _haptic_combo() -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(25)
	get_tree().create_timer(0.06).timeout.connect(func():
		if _can_vibrate():
			Input.vibrate_handheld(35)
	)


# Sharp buzz on wrong swipe or turn timeout
func _haptic_wrong() -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(60)
	get_tree().create_timer(0.1).timeout.connect(func():
		if _can_vibrate():
			Input.vibrate_handheld(40)
	)


# Extended heavy rumble when entering Frenzy Mode
func _haptic_frenzy() -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(45)
	get_tree().create_timer(0.08).timeout.connect(func():
		if _can_vibrate():
			Input.vibrate_handheld(65)
			get_tree().create_timer(0.09).timeout.connect(func():
				if _can_vibrate():
					Input.vibrate_handheld(85)
			)
	)


# Rapid rhythmic 3-beat pulse on direction shuffles
func _haptic_shuffle() -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(35)
	get_tree().create_timer(0.07).timeout.connect(func():
		if _can_vibrate():
			Input.vibrate_handheld(35)
			get_tree().create_timer(0.07).timeout.connect(func():
				if _can_vibrate():
					Input.vibrate_handheld(38)
			)
	)


# Staccato celebratory fanfare for new high records and achievement unlocks
func _haptic_celebration() -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(35)
	get_tree().create_timer(0.08).timeout.connect(func():
		if _can_vibrate():
			Input.vibrate_handheld(35)
			get_tree().create_timer(0.08).timeout.connect(func():
				if _can_vibrate():
					Input.vibrate_handheld(70)
			)
	)


# Deep warning buzz for critical game actions (e.g. data reset)
func _haptic_danger() -> void:
	if not _can_vibrate():
		return
	Input.vibrate_handheld(90)


# =====================================================
# INPUT HANDLING
# =====================================================

func _input(event: InputEvent) -> void:
	# Debug shortcut (disabled): press 'G' to get 1000 sparks
	# if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
	# 	settings.add_sparks(1000)
	# 	_update_sparks_displays()
	# 	if _shop_screen != null and _shop_screen.visible:
	# 		_refresh_shop_screen()
	# 	sfx.play("unlock")
	# 	print("[DEBUG] Key G pressed: Added 1000 sparks! Current sparks: ", settings.sparks)

	if _shop_screen != null and _shop_screen.visible:
		_handle_shop_touch_scroll(event)
		return

	# Handle game swipes only during PLAYING state
	if state == settings.GameState.PLAYING:
		_handle_game_input(event)


func _handle_game_input(event: InputEvent) -> void:
	if _is_walkthrough_active:
		hold_exit_buffer = 0.0
		frenzy_exit_buffer = 0.0
		if _walkthrough_step == 10:
			if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
				_finish_walkthrough(false)
				return

	# 0. Block input during post-hold grace cooldown to prevent accidental swipes (never block during Frenzy)
	if hold_exit_buffer > 0.0 and not is_frenzy_active:
		if event is InputEventMouseButton and not event.pressed:
			is_swiping = false
		elif event is InputEventScreenTouch and not event.pressed:
			is_swiping = false
			active_touch_index = -1
		return

	# 1. Release events while active hold is in progress
	if is_holding_active:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_swiping = false
			_finish_hold_mode()
			return
		elif event is InputEventScreenTouch and not event.pressed and event.index == active_touch_index:
			is_swiping = false
			active_touch_index = -1
			_finish_hold_mode()
			return
		elif event.is_action_released("swipe_up") or event.is_action_released("swipe_down") or event.is_action_released("swipe_left") or event.is_action_released("swipe_right"):
			_finish_hold_mode()
			return
		return

	# 2. Continuous drag detection for HOLD turns & motion trail logging
	if not is_swiping:
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			touch_start_position = event.position
			is_swiping = true
			_trail_points.clear()
			_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
		elif event is InputEventScreenDrag:
			active_touch_index = event.index
			touch_start_position = event.position
			is_swiping = true
			_trail_points.clear()
			_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})

	if is_swiping and is_hold_turn and not is_holding_active:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			var drag_vec: Vector2 = event.position - touch_start_position
			var min_drag: float = settings.MIN_SWIPE_LENGTH
			if drag_vec.length_squared() >= min_drag * min_drag:
				var dir := ""
				if abs(drag_vec.x) > abs(drag_vec.y):
					dir = "right" if drag_vec.x > 0 else "left"
				else:
					dir = "down" if drag_vec.y > 0 else "up"

				if dir == current_target_direction:
					_start_hold_mode(dir)
				else:
					total_swipes += 1
					is_swiping = false
					_on_wrong_swipe(dir)
				return

	# 3. Touch start & end detection
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touch_start_position = event.position
				is_swiping = true
				_trail_points.clear()
				_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
			elif is_swiping:
				_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
				is_swiping = false
				_calculate_swipe(event.position)

	elif event is InputEventScreenTouch:
		if event.pressed:
			active_touch_index = event.index
			touch_start_position = event.position
			is_swiping = true
			_trail_points.clear()
			_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
		elif is_swiping and (event.index == active_touch_index or active_touch_index == -1):
			_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
			is_swiping = false
			active_touch_index = -1
			_calculate_swipe(event.position)

	# 4. Keyboard input
	if is_hold_turn and not is_holding_active:
		var key_dir := ""
		if event.is_action_pressed("swipe_up"): key_dir = "up"
		elif event.is_action_pressed("swipe_down"): key_dir = "down"
		elif event.is_action_pressed("swipe_left"): key_dir = "left"
		elif event.is_action_pressed("swipe_right"): key_dir = "right"

		if key_dir != "":
			if key_dir == current_target_direction:
				_start_hold_mode(key_dir)
			else:
				total_swipes += 1
				_on_wrong_swipe(key_dir)
			return

	if event.is_action_pressed("swipe_up"):
		_on_swipe("up")
	elif event.is_action_pressed("swipe_down"):
		_on_swipe("down")
	elif event.is_action_pressed("swipe_left"):
		_on_swipe("left")
	elif event.is_action_pressed("swipe_right"):
		_on_swipe("right")


func _calculate_swipe(end_position: Vector2) -> void:
	var swipe_vector := end_position - touch_start_position
	var min_dist: float = settings.MIN_SWIPE_LENGTH
	if swipe_vector.length_squared() < min_dist * min_dist:
		return

	var swipe_dir := ""
	if abs(swipe_vector.x) > abs(swipe_vector.y):
		swipe_dir = "right" if swipe_vector.x > 0 else "left"
	else:
		swipe_dir = "down" if swipe_vector.y > 0 else "up"

	# Subtle swipe trail spark burst
	var swipe_mid := (touch_start_position + end_position) / 2.0
	var swipe_col: Color = direction_colors.get(swipe_dir, _theme_accent())
	_burst_particles(swipe_mid, swipe_col, 5)

	if is_hold_turn and not is_holding_active:
		if swipe_dir == current_target_direction:
			_start_hold_mode(swipe_dir)
			_finish_hold_mode()
		else:
			total_swipes += 1
			_on_wrong_swipe(swipe_dir)
		return

	_on_swipe(swipe_dir)


func _on_swipe(direction: String) -> void:
	if state != settings.GameState.PLAYING:
		return

	if _is_walkthrough_active:
		_squash_stretch_center(direction)
		_handle_walkthrough_swipe(direction)
		return

	if is_story_mode:
		_on_story_swipe(direction)
		return

	# Ignore swipes during post-frenzy or post-hold grace buffer (never ignore during active Frenzy)
	if not is_frenzy_active and (frenzy_exit_buffer > 0.0 or hold_exit_buffer > 0.0):
		return

	# Clear any point label from the previous turn before showing a new one
	_clear_persistent_labels()

	_squash_stretch_center(direction)

	total_swipes += 1

	var is_powerup_hit := (powerup_square_dir != "" and direction == powerup_square_dir and not is_frenzy_active)

	if is_frenzy_active or direction == current_target_direction or is_powerup_hit:
		var p_type := ""
		if is_powerup_hit:
			p_type = powerup_type
			powerup_square_dir = ""
			powerup_type = ""

		# Activate frenzy mode or apply power-up BEFORE _on_correct_swipe so all styles & flash callbacks evaluate with updated state
		if p_type == "frenzy":
			_activate_frenzy_mode()
		elif p_type == "frenzy_boost":
			_add_frenzy_charge()
		elif p_type == "shield":
			_activate_shield()
		elif p_type == "spark_jackpot":
			_collect_spark_jackpot()

		_on_correct_swipe(direction, is_powerup_hit, p_type)
	else:
		_on_wrong_swipe(direction)


func _on_correct_swipe(swiped_dir: String = "", is_powerup: bool = false, powerup_hit_type: String = "") -> void:
	var is_super_frenzy_hit: bool = (is_frenzy_active and swiped_dir != "" and swiped_dir == frenzy_special_dir)
	var reaction_time: float = (Time.get_ticks_msec() / 1000.0) - _turn_start_time
	var speed_ratio := clampf(time_left_in_turn / maxf(0.1, current_time_limit), 0.0, 1.0)

	# --- Rhythm-Arcade Timing Judgments (BLAZING / PERFECT / CLUTCH SAVE) ---
	var is_blazing: bool = false
	var is_perfect: bool = false
	var is_clutch_save: bool = false

	if not is_frenzy_active and not is_powerup:
		if reaction_time <= 0.28 or speed_ratio >= 0.82:
			is_blazing = true
			perfect_streak += 1
		elif reaction_time <= 0.42 or speed_ratio >= 0.70:
			is_perfect = true
			perfect_streak += 1
		elif time_left_in_turn <= 0.22 or speed_ratio <= 0.16:
			is_clutch_save = true
			perfect_streak = 0
		else:
			perfect_streak = 0
		if perfect_streak > best_perfect_streak_this_game:
			best_perfect_streak_this_game = perfect_streak

	var base_pts: int
	if is_super_frenzy_hit:
		base_pts = 250
	elif is_frenzy_active:
		base_pts = 100
	elif powerup_hit_type == "spark_jackpot":
		base_pts = 500
	elif powerup_hit_type == "shield":
		base_pts = 150
	else:
		base_pts = settings.BASE_CORRECT_POINTS

	var earned: int = base_pts + int(speed_ratio * settings.SPEED_BONUS_MAX)
	if is_blazing:
		earned = int(round(float(earned) * 1.5)) + mini(perfect_streak, 10) * 5
	elif is_perfect:
		earned = int(round(float(earned) * 1.25)) + mini(perfect_streak, 10) * 3
	elif is_clutch_save:
		earned += 40

	streak += 1
	if streak > best_streak_this_game:
		best_streak_this_game = streak

	# Combo multiplier (x1..x4) scales with the current streak.
	var mult := _current_combo_multiplier()
	earned *= mult
	if is_super_frenzy_hit:
		earned *= 3
	elif is_frenzy_active:
		earned *= 2
	elif is_double_turn and double_turn_step == 2 and not is_powerup:
		earned = int(round(float(earned) * 2.5))

	# --- Streak Milestone Rewards (Every 50 Streak!) ---
	var is_streak_milestone: bool = (streak > 0 and streak % 50 == 0)
	if is_streak_milestone:
		var milestone_pts: int = 1000 * mult
		earned += milestone_pts
		if not _tamper_flagged and settings != null:
			settings.add_sparks(3)
			sparks_collected_in_run += 3
			_update_sparks_displays()
		if streak == 100 and not has_shield:
			_activate_shield(true)

	score += earned
	total_correct += 1
	if total_swipes < total_correct:
		total_swipes = total_correct

	# Charge Overdrive Fever Meter (when not currently in Frenzy)
	if not is_frenzy_active:
		var fever_gain: float = 1.2
		if is_blazing:
			fever_gain = 2.5
		elif is_perfect:
			fever_gain = 1.8
		elif is_clutch_save:
			fever_gain = 2.0
		if is_double_turn and double_turn_step == 2:
			fever_gain += 3.5
		_add_fever_charge(fever_gain)

	# Track lightning-fast responses (turn solved in under 0.40s)
	if (current_time_limit - time_left_in_turn) <= 0.40:
		_fast_swipes_this_game += 1

	# Track clutch streak on 1 heart
	if lives == 1:
		_clutch_swipes_this_game += 1
	else:
		_clutch_swipes_this_game = 0

	# Track fastest reaction time this game
	if reaction_time > 0.03 and reaction_time < fastest_reaction_this_game:
		fastest_reaction_this_game = reaction_time

	# Audio pulse impulse for background synthwave shader
	_audio_pulse = minf(1.0, _audio_pulse + (0.85 if is_blazing else 0.65))

	# Combo level-up flash + HUD refresh
	if streak > 0 and streak % settings.COMBO_HITS_PER_LEVEL == 0 and mult <= settings.COMBO_MAX_MULTIPLIER:
		_combo_level_up_flash()
		if streak == settings.COMBO_HITS_PER_LEVEL * (settings.COMBO_MAX_MULTIPLIER - 1):
			sfx.play_voice("combo_max", 62, 2.0)
	_update_combo_hud()
	_update_streak_visuals()

	# --- Announcer Voice Callouts for Streak Milestones & Skill Highlights ---
	if streak > 0 and streak % 100 == 0:
		sfx.play_voice("legendary", 95, 2.0)
		_show_remap_banner("👑 " + str(streak) + " STREAK! LEGENDARY! 👑")
	elif is_streak_milestone:
		sfx.play_voice("godlike", 90, 2.0)
		_show_remap_banner("⚡ " + str(streak) + " STREAK! GODLIKE! +3 SPARKS ⚡")
	elif streak == 25:
		sfx.play_voice("unstoppable", 70, 2.0)
		_show_remap_banner("🔥 25 STREAK! UNSTOPPABLE! 🔥")
	elif is_double_turn and double_turn_step == 2 and not is_powerup:
		sfx.play_voice("double_dash", 58, 1.8)
	elif is_clutch_save:
		sfx.play_voice("clutch_save", 52, 4.0)

	# In-game achievement verification
	_check_in_game_achievements()

	# --- Dynamic Musical Pitch-Shifted Audio & Haptics ---
	var streak_pitch: float = 1.0 + float(streak % 16) * 0.022 + (0.05 if perfect_streak >= 3 else 0.0)
	if powerup_hit_type == "frenzy_boost" or powerup_hit_type == "spark_jackpot":
		sfx.play("unlock")
		_haptic_celebration()
	elif powerup_hit_type == "shield":
		sfx.play("shield")
		_haptic_celebration()
	elif is_super_frenzy_hit:
		sfx.play("unlock")
		_haptic_celebration()
	elif is_frenzy_active or is_powerup:
		sfx.play_pitched("combo", 1.0 + float(streak % 12) * 0.028)
		_haptic_combo()
	else:
		sfx.play_pitched("correct", streak_pitch)
		var is_combo_hit := streak > 0 and streak % 5 == 0
		if is_combo_hit or is_streak_milestone or (is_double_turn and double_turn_step == 2):
			sfx.play_pitched("combo", 1.0 + float(mult - 1) * 0.08)
			_haptic_combo()
		else:
			_haptic_correct()

	# Visual feedback
	var target_dir := swiped_dir if swiped_dir != "" else current_target_direction
	var square_center := _get_board_center(target_dir)

	var popup_text := "+" + _format_number_with_commas(earned)
	if powerup_hit_type == "frenzy_boost":
		popup_text = "⚡ +5s FRENZY CHARGE! ⚡"
	elif powerup_hit_type == "shield":
		popup_text = "🛡️ SHIELD ACTIVE! +" + _format_number_with_commas(earned)
	elif powerup_hit_type == "spark_jackpot":
		popup_text = "💎 +5 SPARKS! +" + _format_number_with_commas(earned)
	elif is_super_frenzy_hit:
		var total_mult := mult * 3
		popup_text = "⚡ SUPER! +" + _format_number_with_commas(earned) + " x" + str(total_mult) + " ⚡"
	elif is_frenzy_active:
		var total_mult := mult * 2
		popup_text += " x" + str(total_mult) + "!"
	elif is_powerup:
		popup_text = "FRENZY!"
	elif is_streak_milestone:
		popup_text = "🔥 " + str(streak) + " STREAK! +3⚡ +" + _format_number_with_commas(earned)
	elif is_double_turn and double_turn_step == 1:
		popup_text = "⚡ 1/2 HIT! +" + _format_number_with_commas(earned)
	elif is_double_turn and double_turn_step == 2:
		popup_text = "⚡ 2x RUSH! +" + _format_number_with_commas(earned) + "!"
	elif is_blazing:
		var chain_tag := (" 🔥x" + str(perfect_streak)) if perfect_streak >= 2 else ""
		popup_text = "BLAZING!" + chain_tag + " +" + _format_number_with_commas(earned)
	elif is_perfect:
		popup_text = "PERFECT! +" + _format_number_with_commas(earned)
	elif is_clutch_save:
		popup_text = "CLUTCH SAVE! +" + _format_number_with_commas(earned)
	elif mult > 1:
		popup_text += " x" + str(mult)

	var popup_color: Color
	if powerup_hit_type == "frenzy_boost":
		popup_color = Color(0.2, 0.95, 1.0, 1.0)
	elif powerup_hit_type == "shield":
		popup_color = Color(0.2, 1.0, 0.75, 1.0)
	elif powerup_hit_type == "spark_jackpot":
		popup_color = Color(1.5, 1.15, 0.2, 1.0)
	elif is_super_frenzy_hit:
		popup_color = FRENZY_SPECIAL_COLOR
	elif is_frenzy_active or is_powerup or is_blazing or (is_double_turn and double_turn_step == 2):
		popup_color = Color(1.8, 1.4, 0.2, 1.0)
	elif is_clutch_save:
		popup_color = Color(0.25, 1.0, 0.55, 1.0)
	else:
		var is_combo_hit := streak > 0 and streak % 5 == 0
		popup_color = Color(1.5, 0.35, 0.85, 1.0) if (is_combo_hit or is_perfect) else Color(0.15, 0.95, 1.0, 1.0)

	var flash_color: Color
	if powerup_hit_type == "frenzy_boost":
		flash_color = Color(0.2, 0.95, 1.0, 0.95)
	elif powerup_hit_type == "shield":
		flash_color = Color(0.2, 1.0, 0.75, 0.95)
	elif powerup_hit_type == "spark_jackpot":
		flash_color = Color(1.5, 1.15, 0.2, 0.95)
	elif is_super_frenzy_hit:
		flash_color = Color(2.0, 0.5, 1.4, 0.9)
	else:
		flash_color = Color(1, 1, 1, 0.65)
	_flash_square(target_dir, flash_color)

	_show_persistent_label(popup_text, square_center, popup_color, is_frenzy_active or is_powerup or is_blazing or (is_double_turn and double_turn_step == 2))

	var particle_color: Color
	if powerup_hit_type == "frenzy_boost":
		particle_color = Color(0.2, 0.95, 1.0)
	elif powerup_hit_type == "shield":
		particle_color = Color(0.2, 1.0, 0.75)
	elif powerup_hit_type == "spark_jackpot":
		particle_color = Color(1.4, 1.05, 0.2)
	elif is_super_frenzy_hit:
		particle_color = FRENZY_SPECIAL_COLOR
	elif is_frenzy_active or is_powerup or is_blazing:
		particle_color = Color(1.2, 0.9, 0.1)
	else:
		particle_color = direction_colors.get(target_dir, Color.WHITE)

	_burst_particles(square_center, particle_color, 16 if is_super_frenzy_hit else (12 if (is_frenzy_active or is_powerup or is_blazing) else 7))
	_burst_at(square_center, particle_color)
	_bounce_label(score_label)

	# If super frenzy square was hit, immediately pick a new random special square and reset the 1s timer!
	if is_super_frenzy_hit:
		_pick_new_frenzy_special_square()
		frenzy_switch_timer = 0.0

	update_score_display()

	# Check if Overdrive Fever Meter hit 100% -> Unleash Overdrive Frenzy!
	if fever_meter >= 100.0 and not is_frenzy_active:
		fever_meter = 0.0
		_activate_frenzy_mode(true)
		start_new_turn()
		return

	# If this was Step 1 of a Double-Dash 2x Rush turn, immediately chain into Step 2!
	if is_double_turn and double_turn_step == 1 and not is_frenzy_active and not is_powerup:
		double_turn_step = 2
		current_time_limit = maxf(0.75, _calculate_turn_time_limit(false))
		time_left_in_turn = current_time_limit
		_turn_start_time = Time.get_ticks_msec() / 1000.0
		set_random_center_color()
		if _double_indicator_label != null and is_instance_valid(_double_indicator_label):
			_double_indicator_label.text = "🔥 2x RUSH! SWIPE SECOND TARGET! (2/2) 🔥"
			_double_indicator_label.add_theme_color_override("font_color", Color(1.8, 0.4, 0.95))
		_apply_board_colors()
		_pulse_center()
		return

	start_new_turn()


func _on_wrong_swipe(_wrong_dir: String) -> void:
	if _is_walkthrough_active:
		sfx.play("wrong")
		_haptic_wrong()
		_flash_center_red()
		_shake_screen(3.0)
		if _walkthrough_overlay != null:
			if _walkthrough_step == 3:
				_walkthrough_overlay.flash_reminder("Swipe DOWN and HOLD!")
			else:
				_walkthrough_overlay.flash_reminder("Swipe toward the matching color!")
		return

	_cleanup_hold_ui()
	_cleanup_double_turn_ui()
	is_holding_active = false
	is_hold_turn = false
	is_double_turn = false
	double_turn_step = 0
	_center_scale_locked = false

	# If Aegis Shield is active, absorb the mistake and protect streak & hearts!
	if has_shield:
		_consume_shield_on_mistake(_get_board_center(_wrong_dir))
		start_new_turn()
		return

	lives -= 1
	_lost_heart_this_game = true
	streak = 0
	perfect_streak = 0
	fever_meter = maxf(0.0, fever_meter - 25.0)
	_clutch_swipes_this_game = 0
	_frenzies_at_max_multiplier = 0
	_update_combo_hud()
	_update_streak_visuals()

	sfx.play("wrong")
	_haptic_wrong()

	# Screen shake
	_shake_screen()

	# Visual feedback
	_flash_center_red()
	_show_floating_text("-1", _get_board_center(_wrong_dir), Color(1, 0.278, 0.341))
	_update_lives_display()

	if lives <= 0:
		_game_over()
	else:
		start_new_turn()


func _on_turn_timeout() -> void:
	total_swipes += 1
	_cleanup_hold_ui()
	_cleanup_double_turn_ui()
	is_holding_active = false
	is_hold_turn = false
	is_double_turn = false
	double_turn_step = 0
	_center_scale_locked = false

	# Story Lv 4 (Phantom Maestro): running out of time breaks the melody & mirror spell
	if is_story_mode and story_level == 4:
		_story_l4_sequence.clear()
		_story_l4_seq_index = 0
		_story_l4_mirror_swipes = 0
		_story_l4_true_dir = ""

	# If Aegis Shield is active, absorb the timeout and protect streak & hearts!
	if has_shield:
		_consume_shield_on_mistake(_get_board_center(""))
		start_new_turn()
		return

	lives -= 1
	_lost_heart_this_game = true
	streak = 0
	perfect_streak = 0
	fever_meter = maxf(0.0, fever_meter - 25.0)
	_clutch_swipes_this_game = 0
	_frenzies_at_max_multiplier = 0
	_update_combo_hud()
	_update_streak_visuals()

	sfx.play("timeout")
	_haptic_wrong()

	_show_floating_text("-1", _get_board_center(""), Color(1, 0.5, 0.5))
	_update_lives_display()

	# Fade center to gray briefly
	_fade_center_gray()

	if lives <= 0:
		_game_over()
	else:
		start_new_turn()


# =====================================================
# UI UPDATES
# =====================================================

func _format_number_with_commas(val: int) -> String:
	var s := str(abs(val))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	if val < 0:
		res = "-" + res
	return res


func _set_scaled_score_text(label: Label, val: int, base_font_size: int = 42) -> void:
	if label == null or not is_instance_valid(label):
		return
	var formatted := _format_number_with_commas(val)
	label.text = formatted
	var len_val := formatted.length()

	var target_font_size := base_font_size
	if base_font_size >= 48:
		# Large labels (e.g. Game Over FinalScoreLabel, base 52)
		if len_val > 10:
			target_font_size = 26
		elif len_val > 7:
			target_font_size = 34
		elif len_val > 5:
			target_font_size = 42
	else:
		# Standard HUD ScoreLabel (base 42)
		if len_val > 10:
			target_font_size = 22
		elif len_val > 7:
			target_font_size = 28
		elif len_val > 5:
			target_font_size = 35

	label.add_theme_font_size_override("font_size", target_font_size)


func _update_high_score_display() -> void:
	var text_val := "BEST: " + _format_number_with_commas(settings.high_score)
	if high_score_label != null and is_instance_valid(high_score_label):
		high_score_label.text = text_val
		if not _beaten_high_score_this_run:
			high_score_label.remove_theme_color_override("font_color")
		if text_val.length() > 15:
			high_score_label.add_theme_font_size_override("font_size", 11)
		elif text_val.length() > 12:
			high_score_label.add_theme_font_size_override("font_size", 12)
		else:
			high_score_label.add_theme_font_size_override("font_size", 14)
	if go_high_score != null and is_instance_valid(go_high_score):
		go_high_score.text = text_val
		if text_val.length() > 15:
			go_high_score.add_theme_font_size_override("font_size", 14)
		elif text_val.length() > 12:
			go_high_score.add_theme_font_size_override("font_size", 16)
		else:
			go_high_score.add_theme_font_size_override("font_size", 18)
	if _songs_best_label != null and is_instance_valid(_songs_best_label):
		_songs_best_label.text = text_val


func _add_frenzy_charge() -> void:
	frenzy_charges += 1
	_add_fever_charge(6.0)
	_update_frenzy_charge_ui(true)
	sfx.play("unlock")
	_haptic_frenzy()
	_show_remap_banner("+5s FRENZY CHARGE!")


func _update_frenzy_charge_ui(animate: bool = false) -> void:
	if _frenzy_charge_label == null or not is_instance_valid(_frenzy_charge_label):
		var hud := $GameScreen/GameHUD
		if hud == null:
			return
		_frenzy_charge_label = Label.new()
		_frenzy_charge_label.name = "FrenzyChargeLabel"
		_frenzy_charge_label.offset_left = 15.0
		_frenzy_charge_label.offset_top = 88.0
		_frenzy_charge_label.offset_right = 165.0
		_frenzy_charge_label.offset_bottom = 110.0
		_frenzy_charge_label.add_theme_font_size_override("font_size", 12)
		_frenzy_charge_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
		_frenzy_charge_label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.16, 1.0))
		_frenzy_charge_label.add_theme_constant_override("outline_size", 4)
		_frenzy_charge_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.6, 0.9, 0.6))
		_frenzy_charge_label.add_theme_constant_override("shadow_offset_y", 2)
		_frenzy_charge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hud.add_child(_frenzy_charge_label)

	if frenzy_charges <= 0:
		_frenzy_charge_label.visible = false
		_frenzy_charge_label.text = ""
	else:
		_frenzy_charge_label.visible = true
		_frenzy_charge_label.text = "⚡ +" + str(frenzy_charges * 5) + "s FRENZY"
		if animate:
			_frenzy_charge_label.pivot_offset = Vector2(0, 11)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_frenzy_charge_label, "scale", Vector2(1.3, 1.3), 0.12)
			tw.tween_property(_frenzy_charge_label, "scale", Vector2.ONE, 0.15)


func _add_fever_charge(amount: float) -> void:
	if is_frenzy_active or amount <= 0.0:
		return
	fever_meter = clampf(fever_meter + amount, 0.0, 100.0)
	_update_combo_hud()


func _activate_shield(silent_banner: bool = false) -> void:
	has_shield = true
	_add_fever_charge(4.0)
	_update_shield_ui(true)
	_apply_board_colors()
	if not silent_banner:
		_show_remap_banner("🛡️ AEGIS SHIELD ACTIVE!")


func _consume_shield_on_mistake(impact_pos: Vector2) -> void:
	has_shield = false
	_update_shield_ui(false)
	sfx.play("shield_break")
	sfx.play_voice("clutch_save", 72, 1.2)
	_haptic_celebration()
	_shake_screen(5.0)
	_burst_particles(impact_pos, Color(0.2, 1.0, 0.75), 18)
	_burst_particles(_get_board_center(""), Color(0.2, 0.95, 1.0), 16)
	_show_remap_banner("🛡️ SHIELD SAVED STREAK!")
	_apply_board_colors()


func _update_shield_ui(animate: bool = false) -> void:
	if _shield_hud_label == null or not is_instance_valid(_shield_hud_label):
		var hud := $GameScreen/GameHUD
		if hud == null:
			return
		_shield_hud_label = Label.new()
		_shield_hud_label.name = "ShieldHUDLabel"
		_shield_hud_label.anchor_left = 1.0
		_shield_hud_label.anchor_right = 1.0
		_shield_hud_label.offset_left = -165.0
		_shield_hud_label.offset_right = -15.0
		_shield_hud_label.offset_top = 88.0
		_shield_hud_label.offset_bottom = 110.0
		_shield_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_shield_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shield_hud_label.add_theme_font_size_override("font_size", 12)
		_shield_hud_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.75))
		_shield_hud_label.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.10, 1.0))
		_shield_hud_label.add_theme_constant_override("outline_size", 4)
		hud.add_child(_shield_hud_label)

	if not has_shield:
		_shield_hud_label.visible = false
		_shield_hud_label.text = ""
	else:
		_shield_hud_label.visible = true
		_shield_hud_label.text = "🛡️ SHIELD READY"
		if animate:
			_shield_hud_label.pivot_offset = Vector2(150, 11)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_shield_hud_label, "scale", Vector2(1.3, 1.3), 0.12)
			tw.tween_property(_shield_hud_label, "scale", Vector2.ONE, 0.15)


func _collect_spark_jackpot() -> void:
	_add_fever_charge(5.0)
	sfx.play_voice("jackpot", 75, 1.2)
	if not _tamper_flagged and settings != null:
		settings.add_sparks(5)
		sparks_collected_in_run += 5
		_update_sparks_displays()
	_show_remap_banner("💎 JACKPOT! +5 NEON SPARKS!")


# =====================================================
# ANTI-CHEAT / IN-MEMORY SCORE INTEGRITY
# =====================================================

func _init_secure_score() -> void:
	_score_mask = (randi() & 0x7FFFFFFF) ^ 0x4D2C9B8A
	_score_val = 0 ^ _score_mask
	_score_checksum = (0 * 37 + 53) ^ _score_mask
	_decoy_score = 0
	_tamper_flagged = false


func _get_secure_score() -> int:
	if _tamper_flagged:
		return 0
	var real_val: int = _score_val ^ _score_mask
	var expected_chk: int = (real_val * 37 + 53) ^ _score_mask
	# Integrity Check 1: In-memory checksum validation
	if _score_checksum != expected_chk:
		_on_tamper_detected("MEM_CHECKSUM_FAIL")
		return 0
	# Integrity Check 2: HoneyPot validation (catches memory editors like GameGuardian)
	if _decoy_score != real_val:
		_on_tamper_detected("HONEYPOT_DECOY_MODIFIED")
		return 0
	return real_val


func _set_secure_score(val: int) -> void:
	if _tamper_flagged:
		return
	val = clampi(val, 0, 999999999)
	# Check honeypot before updating
	var prev_real: int = _score_val ^ _score_mask
	if _decoy_score != prev_real:
		_on_tamper_detected("HONEYPOT_DECOY_MODIFIED")
		return

	# Re-salt with brand-new random mask on every score mutation
	var new_mask: int = (randi() & 0x7FFFFFFF) ^ 0x4D2C9B8A
	_score_mask = new_mask
	_score_val = val ^ new_mask
	_score_checksum = (val * 37 + 53) ^ new_mask
	_decoy_score = val


func _on_tamper_detected(reason: String) -> void:
	if _tamper_flagged:
		return
	_tamper_flagged = true
	_score_val = 0 ^ _score_mask
	_decoy_score = 0
	_score_checksum = (0 * 37 + 53) ^ _score_mask
	_show_remap_banner("INTEGRITY CHECK FAILED")
	print("[SECURITY] Anti-cheat triggered: ", reason)


func update_score_display() -> void:
	_set_scaled_score_text(score_label, score, 42)
	_check_live_score_milestones()


func _check_live_score_milestones() -> void:
	if _is_walkthrough_active or _tamper_flagged or settings == null or state != settings.GameState.PLAYING:
		return

	# 1. Live mid-run High Score beat announcement!
	if _high_score_at_run_start > 0 and score > _high_score_at_run_start:
		if not _beaten_high_score_this_run:
			_beaten_high_score_this_run = true
			sfx.play("unlock")
			sfx.play_voice("new_high_score", 100, 1.5)
			_haptic_celebration()
			_show_remap_banner("🏆 NEW HIGH SCORE! 🏆")
			_burst_particles(_get_board_center(""), Color(1.0, 0.88, 0.2), 20)
		if high_score_label != null and is_instance_valid(high_score_label):
			var live_best_text := "NEW BEST: " + _format_number_with_commas(score)
			high_score_label.text = live_best_text
			high_score_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))

	# 2. Live Song unlock milestone announcement!
	for song: Dictionary in settings.SONGS:
		var u_score: int = int(song.get("unlock_score", 0))
		var s_id: String = str(song.get("id", ""))
		if u_score > 0 and u_score > _high_score_at_run_start and score >= u_score and not _unlocked_songs_this_run.has(s_id):
			_unlocked_songs_this_run[s_id] = true
			_queue_achievement_toast({
				"header": "NEW SONG UNLOCKED!",
				"name": str(song.get("name", "NEW TRACK")),
				"desc": "Reached " + _format_number_with_commas(u_score) + " points!",
				"icon": "star",
				"color": Color(0.25, 0.95, 1.0),
			})


func _update_lives_display() -> void:
	var previous_lives := _last_displayed_lives
	_last_displayed_lives = lives

	# Redraw heart panels with glowing arcade vector drawing
	for i in range(settings.MAX_LIVES):
		if i < hearts.size() and hearts[i] != null:
			hearts[i].queue_redraw()

	# Animated feedback on life changes
	if lives < previous_lives and previous_lives <= settings.MAX_LIVES:
		# Life lost animation
		var lost_idx := lives
		if lost_idx >= 0 and lost_idx < hearts.size() and hearts[lost_idx] != null:
			var heart := hearts[lost_idx]
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(heart, "scale", Vector2(1.35, 1.35), 0.12)
			tw.tween_property(heart, "scale", Vector2.ONE, 0.18)

	elif lives > previous_lives and previous_lives >= 0:
		# Life restored animation
		var gain_idx := lives - 1
		if gain_idx >= 0 and gain_idx < hearts.size() and hearts[gain_idx] != null:
			var heart := hearts[gain_idx]
			heart.scale = Vector2(0.3, 0.3)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(heart, "scale", Vector2(1.4, 1.4), 0.2)
			tw.tween_property(heart, "scale", Vector2.ONE, 0.15)

	# Low health / 1-life heartbeat warning
	_update_critical_life_throb()
	_update_lives_frame_rect()


func _update_critical_life_throb() -> void:
	if _heart_throb_tween != null and _heart_throb_tween.is_valid():
		_heart_throb_tween.kill()
		_heart_throb_tween = null

	if hearts.is_empty() or hearts[0] == null:
		return

	if lives == 1:
		var heart := hearts[0]
		_heart_throb_tween = create_tween().set_loops()
		_heart_throb_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_heart_throb_tween.tween_property(heart, "scale", Vector2(1.2, 1.2), 0.3)
		_heart_throb_tween.tween_property(heart, "scale", Vector2.ONE, 0.3)
	else:
		if hearts[0] != null:
			hearts[0].scale = Vector2.ONE


func _on_heart_draw(index: int) -> void:
	if index < 0 or index >= hearts.size():
		return
	var panel := hearts[index]
	if panel == null:
		return

	var panel_size := panel.size
	var center := panel_size / 2.0
	var is_active := index < lives

	# Parametric heart polygon points (scaled from precomputed _unit_heart_pts)
	var num_pts := _unit_heart_pts.size()
	var heart_pts := PackedVector2Array()
	heart_pts.resize(num_pts)
	var radius := minf(panel_size.x, panel_size.y) * 0.42

	for k in range(num_pts):
		heart_pts[k] = center + _unit_heart_pts[k] * radius

	var closed_pts := heart_pts.duplicate()
	closed_pts.append(heart_pts[0])

	if is_active:
		# Active Arcade Neon Heart
		# 1. Outer Neon Bloom Aura Stroke
		panel.draw_polyline(closed_pts, Color(1.8, 0.25, 0.6, 0.45), 4.0, true)
		# 2. HDR Neon Magenta Fill (> 1.0 bloom for WorldEnvironment glow)
		panel.draw_colored_polygon(heart_pts, Color(1.6, 0.22, 0.48, 1.0))
		# 3. Hot White-Pink Core Outline
		panel.draw_polyline(closed_pts, Color(2.0, 1.5, 1.7, 0.95), 1.8, true)
		# 4. Specular Glass Arc Highlight
		var shine_pos := center + Vector2(-radius * 0.3, -radius * 0.3)
		panel.draw_circle(shine_pos, radius * 0.18, Color(2.2, 2.2, 2.4, 0.85))
	else:
		# Unlit Recessed Arcade Slot
		var bg_rect := Rect2(Vector2.ZERO, panel_size)
		panel.draw_rect(bg_rect, Color(0.08, 0.06, 0.16, 0.6), true)
		# Dim Neon Wireframe
		panel.draw_polyline(closed_pts, Color(0.45, 0.2, 0.65, 0.35), 1.5, true)
		# Core unlit dot
		panel.draw_circle(center, 2.0, Color(0.3, 0.15, 0.4, 0.3))


# =====================================================
# ANIMATIONS & EFFECTS
# =====================================================

func _pulse_center() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(center_square, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(center_square, "scale", Vector2.ONE, 0.12)
	tween.tween_callback(func(): _center_scale_locked = false)


func _squash_stretch_center(direction: String) -> void:
	if center_square == null or not is_instance_valid(center_square):
		return
	if _center_squash_tween != null and _center_squash_tween.is_valid():
		_center_squash_tween.kill()

	_center_scale_locked = true
	var target_scale := Vector2.ONE
	match direction:
		"up", "down":
			target_scale = Vector2(0.75, 1.30)
		"left", "right":
			target_scale = Vector2(1.30, 0.75)

	center_square.scale = target_scale
	_center_squash_tween = create_tween()
	_center_squash_tween.set_trans(Tween.TRANS_QUAD)
	_center_squash_tween.set_ease(Tween.EASE_OUT)
	_center_squash_tween.tween_property(center_square, "scale", Vector2.ONE, 0.16)
	_center_squash_tween.tween_callback(func():
		_center_scale_locked = false
		if center_square != null and is_instance_valid(center_square):
			center_square.scale = Vector2.ONE
	)


func _pulse_label(label: Control, from_s: float, to_s: float, dur: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
	tween.tween_property(label, "scale", Vector2(to_s, to_s), dur)
	tween.tween_property(label, "scale", Vector2(from_s, from_s), dur)


func _bounce_label(label: Control) -> void:
	# Kill any in-flight bounce so rapid swipes don't compound the scale.
	if _score_bounce_tween is Tween and _score_bounce_tween.is_valid():
		_score_bounce_tween.kill()
	# Always bounce from a fixed base scale (never the current, possibly
	# already-inflated scale), preventing the label from growing over time.
	label.scale = Vector2.ONE
	var tween := create_tween()
	_score_bounce_tween = tween
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.2, 0.05)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)


func _shake_screen(strength: float = settings.SCREEN_SHAKE_STRENGTH) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var orig_offset := Vector2.ZERO
	tween.tween_property(game_screen, "position", Vector2(strength, 0), 0.04)
	tween.tween_property(game_screen, "position", Vector2(-strength, 0), 0.04)
	tween.tween_property(game_screen, "position", Vector2(0, strength), 0.04)
	tween.tween_property(game_screen, "position", orig_offset, 0.04)


func _flash_square(direction: String, flash_color: Color) -> void:
	if not direction_squares.has(direction):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	var style: StyleBoxFlat = _dir_square_styles.get(direction)
	if style != null:
		style.bg_color = flash_color
	# Apply flash immediately, then restore via full board refresh so it
	# always matches the CURRENT (not stale) game state — fixes post-Frenzy
	# squares keeping the gold color.
	tween.tween_callback(_apply_board_colors).set_delay(0.08)


func _flash_center_red() -> void:
	# Kill any previous center flash tween so it can't restore a stale color
	if _center_flash_tween is Tween:
		_center_flash_tween.kill()
	var tween := create_tween()
	_center_flash_tween = tween
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	if _center_live_style != null:
		_center_live_style.bg_color = Color(0.8, 0.1, 0.1)
	# Apply red flash immediately, then restore via full board refresh so the
	# center square always reflects the CURRENT game state (not stale Frenzy Gold).
	tween.tween_callback(_apply_board_colors).set_delay(0.15)
	# Clear the tracked reference once the tween has fully finished
	tween.tween_callback(func(): _center_flash_tween = null)


func _fade_center_gray() -> void:
	if _center_live_style != null:
		_center_live_style.bg_color = Color(0.4, 0.35, 0.45)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(center_square, "modulate:a", 0.3, 0.1)
	tween.tween_property(center_square, "modulate:a", 1.0, 0.1)


func _show_floating_text(text: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100
	floating_container.add_child(label)

	# Position and pivot are computed from the label's real (auto-sized) size
	# so it's precisely centered on the target point, not offset by anchors.
	var min_size := label.get_minimum_size()
	label.size = min_size
	label.position = pos - (min_size / 2.0)
	label.pivot_offset = min_size / 2.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	# Flash in place on the square: pop + fade, no upward drift
	tween.parallel().tween_property(label, "scale", Vector2(1.3, 1.3), 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func _show_persistent_label(text: String, pos: Vector2, color: Color, is_combo: bool = false) -> void:
	_clear_persistent_labels()
	var label := Label.new()
	label.text = text
	var font_size := 44 if is_combo else 36
	var outline_sz := 10
	var peak_scale := 1.4 if is_combo else 1.2
	if text.length() > 18:
		font_size = 16
		outline_sz = 5
		peak_scale = 1.08
	elif text.length() > 10:
		font_size = 20
		outline_sz = 6
		peak_scale = 1.12
	elif text.length() > 6:
		font_size = 26
		outline_sz = 8
		peak_scale = 1.18
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.14, 1.0))
	label.add_theme_constant_override("outline_size", outline_sz)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100
	floating_container.add_child(label)

	var min_size := label.get_minimum_size()
	label.size = min_size
	var target_pos := pos - (min_size / 2.0)
	target_pos.x = clampf(target_pos.x, 12.0, maxf(12.0, 528.0 - min_size.x))
	label.position = target_pos
	label.pivot_offset = min_size / 2.0

	label.scale = Vector2(0.2, 0.2)
	label.rotation_degrees = randf_range(-10, 10)
	label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector2(peak_scale, peak_scale), 0.12)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(label, "rotation_degrees", 0.0, 0.12)
	tween.tween_interval(0.15)
	# Fast fade out + float up so symbols on board squares are immediately visible
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(label, "position:y", label.position.y - 25.0, 0.22)
	tween.parallel().tween_property(label, "scale", Vector2(0.85, 0.85), 0.22)
	tween.tween_callback(label.queue_free)

	_persistent_labels.append(label)


func _burst_particles(pos: Vector2, color: Color, count: int = 6) -> void:
	if count <= 0 or floating_container == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	for i in range(count):
		var angle := (TAU / count) * i + randf_range(-0.25, 0.25)
		var dist := randf_range(35, 65)
		var dot := ColorRect.new()
		dot.color = color
		dot.size = Vector2(7, 7)
		dot.position = pos - dot.size / 2.0
		dot.pivot_offset = dot.size / 2.0
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.z_index = 99
		floating_container.add_child(dot)

		var target_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist - dot.size / 2.0
		tween.parallel().tween_property(dot, "position", target_pos, 0.35)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.35)
		tween.parallel().tween_property(dot, "scale", Vector2(0.2, 0.2), 0.35)
		tween.parallel().tween_callback(dot.queue_free).set_delay(0.35)


func _clear_persistent_labels() -> void:
	for label in _persistent_labels:
		if is_instance_valid(label):
			label.queue_free()
	_persistent_labels.clear()

	if floating_container != null:
		for child in floating_container.get_children():
			if child is Label:
				child.queue_free()


func _animate_score_countup(label: Label, target_score: int, duration: float) -> void:
	if label == null or not is_instance_valid(label):
		return
	if target_score <= 0:
		_set_scaled_score_text(label, 0, 52)
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(func(val: int) -> void:
		if is_instance_valid(label):
			_set_scaled_score_text(label, val, 52)
	, 0, target_score, duration)


func _fade_transition(target_function: Callable) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	transition_overlay.visible = true
	transition_overlay.color = Color(0, 0, 0, 0)
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.2)
	tween.tween_callback(target_function)
	tween.tween_property(transition_overlay, "color:a", 0.0, 0.2)
	tween.tween_callback(func(): transition_overlay.visible = false)


func _get_board_center(direction: String) -> Vector2:
	# Return the center of the named board square in floating_container's
	# local coordinate space (FloatingTextContainer fills GameScreen).
	# Falls back to the previous hand-computed position if the node isn't ready.
	var square: Control = center_square
	if direction != "":
		square = direction_squares.get(direction, center_square)
	if square is Control and is_instance_valid(square):
		# Board and FloatingTextContainer are both children of GameScreen.
		# FloatingTextContainer fills GameScreen (full-rect anchors), so its
		# local origin == GameScreen's top-left. The square's position
		# relative to GameScreen is therefore the correct label position.
		var board: Control = $GameScreen/Board
		var board_pos: Vector2 = board.position
		var sq_pos: Vector2 = square.position + square.size / 2.0
		return board_pos + sq_pos
	# Hand-computed fallback (board centered at 270,480 in the 540x960 viewport)
	var center := Vector2(270, 480.0 + settings.board_vertical_offset)
	var offset := Vector2.ZERO
	match direction:
		"up":
			offset = Vector2(0, -110)
		"down":
			offset = Vector2(0, 110)
		"left":
			offset = Vector2(-110, 0)
		"right":
			offset = Vector2(110, 0)
	return center + offset


# =====================================================
# JUICE / NEON VISUAL OVERHAUL
# =====================================================

func _setup_juice() -> void:
	_setup_font_theme()
	_setup_background()
	_setup_glow_environment()
	_setup_particles()
	_style_menu_neon()
	_setup_lives_container()
	_setup_combo_hud()
	_setup_swipe_trail()
	_setup_board_aura()


func _setup_lives_container() -> void:
	var accent2 := _theme_accent2()

	# Arcade HUD module bezel panel style
	_lives_bezel_style = StyleBoxFlat.new()
	_lives_bezel_style.set_corner_radius_all(12)
	_lives_bezel_style.bg_color = Color(0.08, 0.06, 0.18, 0.8)
	_lives_bezel_style.set_border_width_all(2)
	_lives_bezel_style.set_border_color(Color(accent2.r, accent2.g, accent2.b, 0.6))
	_lives_bezel_style.set_shadow_color(Color(accent2.r, accent2.g, accent2.b, 0.35))
	_lives_bezel_style.set_shadow_size(8)

	var lives_container: HBoxContainer = $GameScreen/GameHUD/LivesContainer
	if lives_container == null:
		return

	# Add bezel frame panel behind container if not present
	var hud := $GameScreen/GameHUD
	if hud != null and not hud.has_node("LivesFrame"):
		_lives_frame = Panel.new()
		_lives_frame.name = "LivesFrame"
		_lives_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lives_frame.add_theme_stylebox_override("panel", _lives_bezel_style)
		hud.add_child(_lives_frame)
		hud.move_child(_lives_frame, lives_container.get_index())
	else:
		_lives_frame = hud.get_node_or_null("LivesFrame") as Panel

	# Add arcade "HP" label if not present
	if not lives_container.has_node("LivesLabel"):
		var lbl := Label.new()
		lbl.name = "LivesLabel"
		lbl.text = "HP"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var arcade_font := _make_arcade_font(0.5)
		if arcade_font != null:
			lbl.add_theme_font_override("font", arcade_font)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(1.3, 0.8, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.25, 1.0))
		lbl.add_theme_constant_override("outline_size", 4)
		lives_container.add_child(lbl)
		lives_container.move_child(lbl, 0)

	# Configure hearts for custom neon drawing
	for i in range(hearts.size()):
		var heart := hearts[i]
		if heart == null:
			continue
		heart.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var callable := Callable(self, "_on_heart_draw").bind(i)
		if not heart.is_connected("draw", callable):
			heart.draw.connect(callable)

	await get_tree().process_frame
	if not is_instance_valid(lives_container):
		return
	for heart in hearts:
		if is_instance_valid(heart):
			heart.pivot_offset = heart.size / 2.0
	_update_lives_frame_rect()


func _update_lives_frame_rect() -> void:
	var hud := $GameScreen/GameHUD
	var lives_container: HBoxContainer = $GameScreen/GameHUD/LivesContainer
	if hud == null or lives_container == null:
		return
	var frame: Panel = hud.get_node_or_null("LivesFrame") as Panel
	if frame == null:
		return
	frame.position = lives_container.position - Vector2(8, 4)
	frame.size = lives_container.size + Vector2(16, 8)


func _setup_combo_hud() -> void:
	var hud := $GameScreen/GameHUD
	if hud == null:
		return

	var offset: float = settings.board_vertical_offset
	var up_ratio: float = clampf(-offset / 100.0, 0.0, 1.0) if offset < 0.0 else 0.0
	var hud_up_shift: float = up_ratio * 26.0

	_combo_container = HBoxContainer.new()
	_combo_container.name = "ComboContainer"
	_combo_container.anchor_left = 0.0
	_combo_container.anchor_right = 1.0
	_combo_container.offset_left = 0.0
	_combo_container.offset_right = 0.0
	_combo_container.offset_top = 130.0 - hud_up_shift
	_combo_container.offset_bottom = 158.0 - hud_up_shift
	_combo_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo_container.add_theme_constant_override("separation", 10)
	_combo_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(_combo_container)

	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.text = "x1"
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arcade_font := _make_arcade_font(0.55)
	if arcade_font != null:
		_combo_label.add_theme_font_override("font", arcade_font)
	_combo_label.add_theme_font_size_override("font_size", 24)
	_combo_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 1.0))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_container.add_child(_combo_label)

	_combo_bar = ProgressBar.new()
	_combo_bar.name = "ComboBar"
	_combo_bar.min_value = 0.0
	_combo_bar.max_value = 1.0
	_combo_bar.value = 0.0
	_combo_bar.show_percentage = false
	_combo_bar.custom_minimum_size = Vector2(115, 14)
	_combo_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.set_corner_radius_all(7)
	bg_style.bg_color = Color(0.08, 0.06, 0.18, 0.9)
	bg_style.set_border_width_all(2)
	bg_style.set_border_color(Color(1, 1, 1, 0.25))
	_combo_bar.add_theme_stylebox_override("background", bg_style)

	_combo_bar_fill_style = StyleBoxFlat.new()
	_combo_bar_fill_style.set_corner_radius_all(7)
	_combo_bar_fill_style.bg_color = Color(0.6, 0.9, 1.0)
	_combo_bar.add_theme_stylebox_override("fill", _combo_bar_fill_style)

	_combo_container.add_child(_combo_bar)

	# --- Overdrive / Fever Meter (auto-triggers Frenzy at 100%) ---
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(6, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_container.add_child(sep)

	_fever_label = Label.new()
	_fever_label.name = "FeverLabel"
	_fever_label.text = "⚡0%"
	_fever_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fever_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if arcade_font != null:
		_fever_label.add_theme_font_override("font", arcade_font)
	_fever_label.add_theme_font_size_override("font_size", 14)
	_fever_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	_fever_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.16, 1.0))
	_fever_label.add_theme_constant_override("outline_size", 5)
	_combo_container.add_child(_fever_label)

	_fever_bar = ProgressBar.new()
	_fever_bar.name = "FeverBar"
	_fever_bar.min_value = 0.0
	_fever_bar.max_value = 100.0
	_fever_bar.value = 0.0
	_fever_bar.show_percentage = false
	_fever_bar.custom_minimum_size = Vector2(105, 14)
	_fever_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fever_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fever_bar.add_theme_stylebox_override("background", bg_style.duplicate())

	_fever_bar_fill_style = StyleBoxFlat.new()
	_fever_bar_fill_style.set_corner_radius_all(7)
	_fever_bar_fill_style.bg_color = Color(1.3, 0.85, 0.15)
	_fever_bar.add_theme_stylebox_override("fill", _fever_bar_fill_style)
	_combo_container.add_child(_fever_bar)

	_update_combo_hud()


func _current_combo_multiplier() -> int:
	return clampi(1 + streak / settings.COMBO_HITS_PER_LEVEL, 1, settings.COMBO_MAX_MULTIPLIER)


func _combo_progress() -> float:
	var mult := _current_combo_multiplier()
	if mult >= settings.COMBO_MAX_MULTIPLIER:
		return 1.0
	return float(streak % settings.COMBO_HITS_PER_LEVEL) / float(settings.COMBO_HITS_PER_LEVEL)


func _update_combo_hud() -> void:
	if _combo_label == null or _combo_bar == null:
		return
	var mult := _current_combo_multiplier()
	_combo_label.text = "x" + str(mult)
	_combo_bar.value = _combo_progress()

	# Tier color: cyan -> green -> yellow -> gold.
	var tier_color: Color
	match mult:
		1:
			tier_color = Color(0.6, 0.9, 1.0)
		2:
			tier_color = Color(0.2, 1.0, 0.55)
		3:
			tier_color = Color(1.3, 1.15, 0.15)
		_:
			tier_color = Color(1.6, 0.9, 0.1)

	_combo_label.add_theme_color_override("font_color", tier_color)
	if _combo_bar_fill_style != null:
		_combo_bar_fill_style.bg_color = tier_color

	if _fever_bar != null and is_instance_valid(_fever_bar) and _fever_label != null and is_instance_valid(_fever_label):
		var f_val := 100.0 if is_frenzy_active else clampf(fever_meter, 0.0, 100.0)
		_fever_bar.value = f_val
		var f_col: Color
		if is_frenzy_active:
			_fever_label.text = "⚡MAX!"
			f_col = FRENZY_SPECIAL_COLOR
		elif f_val >= 75.0:
			_fever_label.text = "🔥" + str(int(round(f_val))) + "%"
			f_col = Color(1.6, 0.35, 0.85)
		else:
			_fever_label.text = "⚡" + str(int(round(f_val))) + "%"
			f_col = Color(1.3, 0.9, 0.2)
		_fever_label.add_theme_color_override("font_color", f_col)
		if _fever_bar_fill_style != null:
			_fever_bar_fill_style.bg_color = f_col


func _combo_level_up_flash() -> void:
	if _combo_label == null or not is_instance_valid(_combo_label):
		return
	_combo_label.pivot_offset = _combo_label.size / 2.0
	_combo_label.scale = Vector2(1.7, 1.7)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.3)


func _style_menu_neon() -> void:
	# --- Arcade marquee titles -------------------------------------------
	# Orbitron is a variable font, so embolden it hard for a chunky arcade
	# cabinet weight, spread the tracking, then stack outline + drop shadow
	# so the letters read as raised plastic over the busy background.
	var arcade_font := _make_arcade_font(0.75)

	var title := $MenuScreen/TitleLabel
	if title is Label:
		if arcade_font != null:
			title.add_theme_font_override("font", arcade_font)
		title.add_theme_constant_override("font_size", 66)
		title.add_theme_color_override("font_color", Color(1.35, 1.35, 1.5))
		title.add_theme_color_override("font_outline_color", Color(0.16, 0.02, 0.32, 1.0))
		title.add_theme_constant_override("outline_size", 20)
		title.add_theme_color_override("font_shadow_color", Color(0.55, 0.10, 0.85, 0.85))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 7)
		title.add_theme_constant_override("shadow_outline_size", 10)

	var title2 := $MenuScreen/TitleLabel2
	if title2 is Label:
		if arcade_font != null:
			title2.add_theme_font_override("font", arcade_font)
		title2.add_theme_constant_override("font_size", 92)
		title2.add_theme_color_override("font_color", Color(1.5, 0.30, 0.58))
		title2.add_theme_color_override("font_outline_color", Color(0.20, 0.0, 0.10, 1.0))
		title2.add_theme_constant_override("outline_size", 22)
		title2.add_theme_color_override("font_shadow_color", Color(0.10, 0.85, 0.95, 0.80))
		title2.add_theme_constant_override("shadow_offset_x", 0)
		title2.add_theme_constant_override("shadow_offset_y", 8)
		title2.add_theme_constant_override("shadow_outline_size", 12)

	# Make the titles physically pop: scale-punch in on entry, then breathe.
	_animate_title_popup(title, 0.0)
	_animate_title_popup(title2, 0.12)

	# Neon-tube PLAY button: darker fill + bright legible text on rounded stylebox.
	var play_bg := $MenuScreen/StartButton/StartButtonBg
	if play_bg is ColorRect:
		play_bg.visible = false
	var start_btn := $MenuScreen/StartButton
	if start_btn is Button:
		start_btn.text = "ARCADE MODE"
		start_btn.add_theme_color_override("font_color", Color(1.2, 1.25, 1.35))
		start_btn.add_theme_constant_override("outline_size", 5)
		start_btn.add_theme_color_override("font_outline_color", Color(0.02, 0.10, 0.24, 1.0))
		start_btn.add_theme_font_size_override("font_size", 16)
		start_btn.clip_contents = true
	# Gentle pulsing glow on the rounded PLAY button stylebox to draw the eye.
	if _play_btn_style != null:
		var tw := create_tween().set_loops()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_play_btn_style, "bg_color:a", 0.62, 0.9)
		tw.tween_property(_play_btn_style, "bg_color:a", 0.92, 0.9)


var _arcade_font_cache: Dictionary = {}

func _make_arcade_font(embolden: float) -> FontVariation:
	if embolden in _arcade_font_cache:
		return _arcade_font_cache[embolden]
	# Orbitron ships as a variable font, so we can push weight + tracking
	# procedurally instead of shipping a second file.
	if _base_font == null:
		var font_path := "res://fonts/Orbitron.ttf"
		if ResourceLoader.exists(font_path):
			_base_font = load(font_path)
	if _base_font == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = _base_font
	fv.variation_embolden = embolden
	fv.spacing_glyph = 6  # wide arcade marquee tracking

	# Add system emoji/fallback fonts so emojis and symbols render on all mobile phones (Android/iOS)
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Roboto", "sans-serif"])
	fv.fallbacks.append(sys_font)

	_arcade_font_cache[embolden] = fv
	return fv


func _animate_title_popup(label: Node, delay: float) -> void:
	# Scale-punch the title in from small, overshoot, settle, then idle-breathe
	# so the marquee keeps a subtle life to it.
	if label == null or not (label is Control):
		return
	var ctrl := label as Control
	ctrl.scale = Vector2(0.55, 0.55)
	ctrl.modulate.a = 0.0
	# Layout isn't resolved during _ready(), so wait a frame before reading
	# size for the pivot — otherwise it scales from the wrong origin.
	await get_tree().process_frame
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size / 2.0

	var tw := create_tween().set_parallel(false)
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.28)
	tw.tween_property(ctrl, "scale", Vector2(1.12, 1.12), 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_property(ctrl, "scale", Vector2(1.0, 1.0), 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Idle breathe, forever.
	tw.tween_callback(func() -> void:
		if not is_instance_valid(ctrl):
			return
		var idle := create_tween().set_loops()
		idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.tween_property(ctrl, "scale", Vector2(1.035, 1.035), 1.5)
		idle.tween_property(ctrl, "scale", Vector2(1.0, 1.0), 1.5)
	)


func _setup_font_theme() -> void:
	# Load Orbitron (SIL OFL) and apply it project-wide via a Theme so every
	# Label and Button picks it up without editing the scene.
	if _base_font == null:
		var font_path := "res://fonts/Orbitron.ttf"
		if ResourceLoader.exists(font_path):
			_base_font = load(font_path)
	if _base_font == null:
		return
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Roboto", "sans-serif"])
	if _base_font.fallbacks.is_empty():
		_base_font.fallbacks.append(sys_font)
	_ui_theme = Theme.new()
	_ui_theme.default_font = _base_font
	# Slight letter tracking looks great on Orbitron; done per-label where needed.
	for cls in ["Label", "Button"]:
		_ui_theme.set_font("font", cls, _base_font)
	# Apply to the whole tree from the root Control.
	theme = _ui_theme


func _setup_background() -> void:
	# Swap the flat Background ColorRect for the animated synthwave shader.
	var bg := $Background
	if bg == null:
		return
	var shader_path := "res://shaders/synthwave_bg.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	var shader: Shader = load(shader_path)
	if shader == null:
		return
	_bg_shader_mat = ShaderMaterial.new()
	_bg_shader_mat.shader = shader
	bg.material = _bg_shader_mat
	# Make the ColorRect white so the shader's own colors show unmodulated.
	bg.color = Color(1, 1, 1, 1)
	# Apply the selected theme's background palette to the shader.
	_apply_theme_bg_colors()


func _setup_glow_environment() -> void:
	# 2D glow/bloom so the neon squares and text bleed light.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	# Spread glow across mid levels for a soft neon haze.
	env.set_glow_level(2, 0.3)
	env.set_glow_level(3, 0.7)
	env.set_glow_level(4, 1.0)
	env.set_glow_level(5, 0.5)
	var we := WorldEnvironment.new()
	we.name = "JuiceEnvironment"
	we.environment = env
	add_child(we)


func _setup_particles() -> void:
	# Ambient floating embers drifting up behind the board.
	_ambient_particles = GPUParticles2D.new()
	_ambient_particles.name = "AmbientParticles"
	_ambient_particles.amount = 40
	_ambient_particles.lifetime = 6.0
	_ambient_particles.preprocess = 3.0
	_ambient_particles.position = Vector2(270, 980)
	_ambient_particles.z_index = -1
	var amat := ParticleProcessMaterial.new()
	amat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	amat.emission_box_extents = Vector3(300, 10, 0)
	amat.direction = Vector3(0, -1, 0)
	amat.spread = 20.0
	amat.gravity = Vector3(0, -14, 0)
	amat.initial_velocity_min = 18.0
	amat.initial_velocity_max = 45.0
	amat.scale_min = 1.0
	amat.scale_max = 3.0
	amat.color = Color(1.0, 0.6, 0.95, 0.55)
	var afade := Gradient.new()
	afade.set_color(0, Color(1.0, 0.5, 0.95, 0.0))
	afade.add_point(0.2, Color(1.0, 0.7, 1.0, 0.6))
	afade.set_color(1, Color(0.6, 0.8, 1.0, 0.0))
	var aramp := GradientTexture1D.new()
	aramp.gradient = afade
	amat.color_ramp = aramp
	_ambient_particles.process_material = amat
	_ambient_particles.texture = _make_dot_texture()
	game_screen.add_child(_ambient_particles)
	game_screen.move_child(_ambient_particles, 0)

	# Burst particles fired on correct hits (created once, positioned per hit).
	_hit_particles = GPUParticles2D.new()
	_hit_particles.name = "HitParticles"
	_hit_particles.amount = 28
	_hit_particles.lifetime = 0.8
	_hit_particles.one_shot = true
	_hit_particles.explosiveness = 0.95
	_hit_particles.emitting = false
	_hit_particles.z_index = 60
	var hmat := ParticleProcessMaterial.new()
	hmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	hmat.emission_sphere_radius = 6.0
	hmat.direction = Vector3(0, 0, 0)
	hmat.spread = 180.0
	hmat.gravity = Vector3(0, 220, 0)
	hmat.initial_velocity_min = 120.0
	hmat.initial_velocity_max = 300.0
	hmat.scale_min = 2.0
	hmat.scale_max = 4.5
	hmat.damping_min = 20.0
	hmat.damping_max = 60.0
	var hfade := Gradient.new()
	hfade.set_color(0, Color(1, 1, 1, 1))
	hfade.add_point(0.3, Color(1.0, 0.9, 0.3, 1.0))
	hfade.set_color(1, Color(1.0, 0.4, 0.7, 0.0))
	var hramp := GradientTexture1D.new()
	hramp.gradient = hfade
	hmat.color_ramp = hramp
	_hit_particles.process_material = hmat
	_hit_particles.texture = _make_dot_texture()
	floating_container.add_child(_hit_particles)


func _make_dot_texture() -> ImageTexture:
	# Small soft round dot used for all particles (cached once).
	if _particle_dot_tex != null:
		return _particle_dot_tex
	var tex_size := 16
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var c := Vector2(tex_size / 2.0, tex_size / 2.0)
	for y in range(tex_size):
		for x in range(tex_size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (tex_size / 2.0)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_particle_dot_tex = ImageTexture.create_from_image(img)
	return _particle_dot_tex


func _burst_at(pos: Vector2, color: Color) -> void:
	if _hit_particles == null:
		return
	_hit_particles.position = pos
	_hit_particles.modulate = color
	_hit_particles.restart()
	_hit_particles.emitting = true


func _setup_swipe_trail() -> void:
	if _swipe_trail != null and is_instance_valid(_swipe_trail):
		return
	_swipe_trail = Control.new()
	_swipe_trail.name = "SwipeTrail"
	_swipe_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swipe_trail.z_index = 85
	_swipe_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swipe_trail.draw.connect(_draw_swipe_trail)
	game_screen.add_child(_swipe_trail)


func _draw_swipe_trail() -> void:
	if _trail_points.size() < 2 or _swipe_trail == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var base_col: Color = _theme_accent()
	if current_target_direction in direction_colors:
		base_col = direction_colors[current_target_direction]

	var trail_id: String = settings.selected_trail if settings != null else "neon"
	var n := _trail_points.size()

	for i in range(n - 1):
		var pt0: Dictionary = _trail_points[i]
		var pt1: Dictionary = _trail_points[i + 1]
		var pos0: Vector2 = pt0["pos"]
		var pos1: Vector2 = pt1["pos"]
		var age0: float = (now - float(pt0["time"])) / TRAIL_LIFETIME
		var age1: float = (now - float(pt1["time"])) / TRAIL_LIFETIME
		var alpha: float = clampf(1.0 - (age0 + age1) * 0.5, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var progress: float = float(i) / float(n - 1) # 0 at tail, 1 at tip

		if trail_id == "rainbow":
			# PRISMATIC WAVE: Full-spectrum shifting HSV rainbow ribbon
			var hue := fposmod(progress * 0.9 - now * 2.2, 1.0)
			var r_col := Color.from_hsv(hue, 0.85, 1.0)
			var outer_w := lerpf(6.0, 22.0, progress)
			_swipe_trail.draw_line(pos0, pos1, Color(r_col.r, r_col.g, r_col.b, alpha * 0.55), outer_w, true)
			var mid_w := lerpf(3.0, 11.0, progress)
			_swipe_trail.draw_line(pos0, pos1, Color(r_col.r * 1.3, r_col.g * 1.3, r_col.b * 1.3, alpha * 0.88), mid_w, true)
			var core_w := lerpf(1.2, 4.5, progress)
			_swipe_trail.draw_line(pos0, pos1, Color(1.0, 1.0, 1.0, alpha * 0.95), core_w, true)

		elif trail_id == "electric":
			# THUNDER VOLT: Crackling cyan-gold high-voltage lightning arcs
			var e_outer := Color(0.15, 0.92, 1.0, alpha * 0.50)
			var e_gold := Color(1.0, 0.92, 0.25, alpha * 0.90)
			_swipe_trail.draw_line(pos0, pos1, e_outer, lerpf(5.0, 18.0, progress), true)
			_swipe_trail.draw_line(pos0, pos1, Color(1.0, 1.0, 1.0, alpha * 0.95), lerpf(1.5, 5.0, progress), true)

			# Jagged electric arc along segment
			var seg := pos1 - pos0
			var seg_len := seg.length()
			if seg_len > 2.0:
				var perp := Vector2(-seg.y, seg.x).normalized()
				var jitter := sin(float(i) * 7.3 + now * 45.0) * lerpf(4.0, 13.0, progress)
				var mid_j := (pos0 + pos1) * 0.5 + perp * jitter
				_swipe_trail.draw_line(pos0, mid_j, e_gold, 2.5, true)
				_swipe_trail.draw_line(mid_j, pos1, e_gold, 2.5, true)

		elif trail_id == "plasma":
			# SOLAR FLARE: Blazing crimson-amber fire beam with ember orbs
			var fire_outer := Color(1.0, 0.16, 0.04, alpha * 0.52)
			var fire_mid := Color(1.0, 0.58, 0.08, alpha * 0.85)
			var fire_core := Color(1.0, 0.96, 0.55, alpha * 0.98)
			_swipe_trail.draw_line(pos0, pos1, fire_outer, lerpf(7.0, 24.0, progress), true)
			_swipe_trail.draw_line(pos0, pos1, fire_mid, lerpf(3.5, 12.0, progress), true)
			_swipe_trail.draw_line(pos0, pos1, fire_core, lerpf(1.5, 5.5, progress), true)
			if i % 2 == 0:
				var orb_r := lerpf(2.5, 6.5, progress)
				_swipe_trail.draw_circle(pos1, orb_r * 1.5, Color(1.0, 0.35, 0.05, alpha * 0.4))
				_swipe_trail.draw_circle(pos1, orb_r * 0.7, fire_core)

		elif trail_id == "stardust":
			# GALAXY STARDUST: Cosmic magenta-cyan nebula ribbon with 4-point diamond stars
			var c_nebula := Color(0.65, 0.18, 1.0).lerp(Color(0.15, 0.95, 1.0), progress)
			_swipe_trail.draw_line(pos0, pos1, Color(c_nebula.r, c_nebula.g, c_nebula.b, alpha * 0.50), lerpf(5.0, 20.0, progress), true)
			_swipe_trail.draw_line(pos0, pos1, Color(1.0, 0.85, 1.0, alpha * 0.95), lerpf(1.5, 5.5, progress), true)
			if i % 2 == 0:
				var star_s := lerpf(3.5, 8.5, progress)
				var s_pts := PackedVector2Array([
					pos1 + Vector2(0, -star_s),
					pos1 + Vector2(star_s * 0.35, -star_s * 0.35),
					pos1 + Vector2(star_s, 0),
					pos1 + Vector2(star_s * 0.35, star_s * 0.35),
					pos1 + Vector2(0, star_s),
					pos1 + Vector2(-star_s * 0.35, star_s * 0.35),
					pos1 + Vector2(-star_s, 0),
					pos1 + Vector2(-star_s * 0.35, -star_s * 0.35),
				])
				_swipe_trail.draw_colored_polygon(s_pts, Color(1.0, 1.0, 1.0, alpha * 0.92))

		else:
			# NEON LASER (Default): Outer glowing neon stroke + core white stroke
			var outer_w := lerpf(4.0, 18.0, progress)
			var outer_col := Color(base_col.r, base_col.g, base_col.b, alpha * 0.45)
			_swipe_trail.draw_line(pos0, pos1, outer_col, outer_w, true)

			var core_w := lerpf(1.5, 6.0, progress)
			var core_col := Color(1.0, 1.0, 1.0, alpha * 0.95)
			_swipe_trail.draw_line(pos0, pos1, core_col, core_w, true)

	# Glowing tip cursor
	var tip_pos: Vector2 = _trail_points[n - 1]["pos"]
	var tip_age: float = (now - float(_trail_points[n - 1]["time"])) / TRAIL_LIFETIME
	var tip_alpha: float = clampf(1.0 - tip_age, 0.0, 1.0)
	if tip_alpha > 0.05:
		var tip_col := base_col
		if trail_id == "rainbow":
			tip_col = Color.from_hsv(fposmod(1.0 - now * 2.2, 1.0), 0.85, 1.0)
		elif trail_id == "electric":
			tip_col = Color(1.0, 0.92, 0.25)
		elif trail_id == "plasma":
			tip_col = Color(1.0, 0.48, 0.08)
		elif trail_id == "stardust":
			tip_col = Color(0.75, 0.35, 1.0)
		_swipe_trail.draw_circle(tip_pos, 11.0, Color(tip_col.r, tip_col.g, tip_col.b, tip_alpha * 0.55))
		_swipe_trail.draw_circle(tip_pos, 5.5, Color(1.0, 1.0, 1.0, tip_alpha * 0.95))


func _setup_board_aura() -> void:
	var board: Control = $GameScreen/Board
	if board == null:
		return
	if board.has_node("BoardAura"):
		_board_aura_panel = board.get_node("BoardAura") as Control
		return

	_board_aura_panel = Control.new()
	_board_aura_panel.name = "BoardAura"
	_board_aura_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_aura_panel.z_index = -1
	_board_aura_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_aura_panel.offset_left = -24.0
	_board_aura_panel.offset_top = -24.0
	_board_aura_panel.offset_right = 24.0
	_board_aura_panel.offset_bottom = 24.0
	_board_aura_panel.draw.connect(_draw_board_aura)
	board.add_child(_board_aura_panel)
	board.move_child(_board_aura_panel, 0)


func _draw_board_aura() -> void:
	if _board_aura_tier == 0 or _board_aura_panel == null:
		return
	var s: Vector2 = _board_aura_panel.size

	if _board_aura_tier == 1:
		# Tier 1 (50+ Streak): Electric Surge
		var col := Color(0.18, 0.88, 1.0)
		var pulse := 1.0 + sin(_board_aura_time * 8.0) * 0.06
		_board_aura_panel.draw_rect(Rect2(12, 12, s.x - 24, s.y - 24), Color(col.r, col.g, col.b, 0.25 * pulse), false, 6.0)
		_board_aura_panel.draw_rect(Rect2(16, 16, s.x - 32, s.y - 32), Color(col.r, col.g, col.b, 0.75), false, 2.5)
		_board_aura_panel.draw_rect(Rect2(18, 18, s.x - 36, s.y - 36), Color(1.0, 1.0, 1.0, 0.6), false, 1.0)
		var corners := [Vector2(16, 16), Vector2(s.x - 16, 16), Vector2(16, s.y - 16), Vector2(s.x - 16, s.y - 16)]
		for c_pos: Vector2 in corners:
			_board_aura_panel.draw_circle(c_pos, 4.0, col)
			_board_aura_panel.draw_circle(c_pos, 2.0, Color(1, 1, 1))

	elif _board_aura_tier == 2:
		# Tier 2 (100+ Streak): Blazing Flame
		var col_flame := Color(1.0, 0.32, 0.08)
		var col_amber := Color(1.0, 0.82, 0.15)
		for layer in range(3):
			var wave := sin(_board_aura_time * 9.0 + layer * 1.8) * 3.5
			var m := 10.0 + layer * 5.0 + wave
			var a := (0.35 - layer * 0.08)
			_board_aura_panel.draw_rect(Rect2(m, m, s.x - m * 2.0, s.y - m * 2.0), Color(col_flame.r, col_flame.g, col_flame.b, a), false, 5.0)
		_board_aura_panel.draw_rect(Rect2(16, 16, s.x - 32, s.y - 32), col_amber, false, 3.0)
		_board_aura_panel.draw_rect(Rect2(18, 18, s.x - 36, s.y - 36), Color(1.0, 1.0, 1.0, 0.8), false, 1.2)
		var tab_len := 30.0
		var c_offsets := [
			[Vector2(16, 16), Vector2(16 + tab_len, 16), Vector2(16, 16 + tab_len)],
			[Vector2(s.x - 16, 16), Vector2(s.x - 16 - tab_len, 16), Vector2(s.x - 16, 16 + tab_len)],
			[Vector2(16, s.y - 16), Vector2(16 + tab_len, s.y - 16), Vector2(16, s.y - 16 - tab_len)],
			[Vector2(s.x - 16, s.y - 16), Vector2(s.x - 16 - tab_len, s.y - 16), Vector2(s.x - 16, s.y - 16 - tab_len)],
		]
		for pts: Array in c_offsets:
			_board_aura_panel.draw_line(pts[0], pts[1], col_amber, 3.5)
			_board_aura_panel.draw_line(pts[0], pts[2], col_amber, 3.5)

	elif _board_aura_tier == 3:
		# Tier 3 (200+ Streak): Mythic Prismatic Corona
		var hue := fposmod(_board_aura_time * 0.35, 1.0)
		var col_p1 := Color.from_hsv(hue, 0.9, 1.0)
		var col_p2 := Color.from_hsv(fposmod(hue + 0.33, 1.0), 0.85, 1.0)
		var col_p3 := Color.from_hsv(fposmod(hue + 0.66, 1.0), 0.9, 1.0)

		_board_aura_panel.draw_rect(Rect2(6, 6, s.x - 12, s.y - 12), Color(col_p1.r, col_p1.g, col_p1.b, 0.35), false, 9.0)
		_board_aura_panel.draw_rect(Rect2(12, 12, s.x - 24, s.y - 24), Color(col_p2.r, col_p2.g, col_p2.b, 0.65), false, 4.5)
		_board_aura_panel.draw_rect(Rect2(16, 16, s.x - 32, s.y - 32), Color(col_p3.r, col_p3.g, col_p3.b, 0.9), false, 3.0)
		_board_aura_panel.draw_rect(Rect2(18, 18, s.x - 36, s.y - 36), Color(1.0, 1.0, 1.0, 0.95), false, 1.8)

		var d_size := 8.0
		var c_centers := [Vector2(16, 16), Vector2(s.x - 16, 16), Vector2(16, s.y - 16), Vector2(s.x - 16, s.y - 16)]
		for cc: Vector2 in c_centers:
			var pts := PackedVector2Array([
				cc + Vector2(0, -d_size),
				cc + Vector2(d_size, 0),
				cc + Vector2(0, d_size),
				cc + Vector2(-d_size, 0),
			])
			_board_aura_panel.draw_colored_polygon(pts, Color(1, 1, 1, 0.95))
			_board_aura_panel.draw_circle(cc, d_size * 1.8, Color(col_p1.r, col_p1.g, col_p1.b, 0.45))


func _emit_board_aura_ambient_particle() -> void:
	var center := _get_board_center("")
	var half: float = 160.0
	var edge_pos := Vector2.ZERO
	var side := randi() % 4
	var offset := randf_range(-half, half)
	match side:
		0: edge_pos = center + Vector2(offset, -half) # top
		1: edge_pos = center + Vector2(offset, half)  # bottom
		2: edge_pos = center + Vector2(-half, offset) # left
		3: edge_pos = center + Vector2(half, offset)  # right

	var p_col: Color
	if _board_aura_tier == 1:
		p_col = Color(0.2, 0.9, 1.0)
	elif _board_aura_tier == 2:
		p_col = Color(1.0, 0.45, 0.1)
	else:
		p_col = Color.from_hsv(fposmod(_board_aura_time * 0.4 + randf_range(-0.1, 0.1), 1.0), 0.9, 1.0)
	_burst_particles(edge_pos, p_col, 2)


# =====================================================
# STORY MODE & BOSS FIGHT ARENA
# =====================================================

func _setup_story_ui() -> void:
	# 1. "STORY MODE" button directly under ARCADE MODE on MenuScreen
	_story_button = Button.new()
	_story_button.name = "StoryButton"
	_story_button.text = "STORY MODE"
	_story_button.anchor_left = 0.5
	_story_button.anchor_right = 0.5
	_story_button.offset_left = -128.0
	_story_button.offset_right = 128.0
	_story_button.offset_top = 480.0
	_story_button.offset_bottom = 524.0
	_story_button.clip_contents = true
	_story_button.add_theme_font_size_override("font_size", 16)
	_apply_menu_button_style(_story_button, _story_btn_style, _story_btn_hover_style)
	_story_button.add_theme_color_override("font_color", Color(1.0, 0.98, 1.0, 1.0))
	_story_button.add_theme_constant_override("outline_size", 5)
	_story_button.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.22, 1.0))
	_story_button.pressed.connect(_open_story_screen)
	menu_screen.add_child(_story_button)

	# 2. Story Mode Level Selection Overlay Screen
	_story_screen = Control.new()
	_story_screen.name = "StoryScreen"
	_story_screen.visible = false
	_story_screen.anchor_right = 1.0
	_story_screen.anchor_bottom = 1.0
	_story_screen.z_index = 54
	add_child(_story_screen)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.01, 0.06, 0.78)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.gui_input.connect(_on_story_backdrop_input)
	_story_screen.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _pause_panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -410.0
	panel.offset_bottom = 410.0
	_story_screen.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "STORY MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.22, 1.0))
	title.add_theme_constant_override("outline_size", 7)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -195.0
	title.offset_right = 195.0
	title.offset_top = 12.0
	title.offset_bottom = 42.0
	panel.add_child(title)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = "SWIPE WHITE CENTER TO ANY SAFE COLOR TO ATTACK!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.clip_text = true
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.88, 0.85, 0.98))
	sub.anchor_left = 0.5
	sub.anchor_right = 0.5
	sub.offset_left = -206.0
	sub.offset_right = 206.0
	sub.offset_top = 42.0
	sub.offset_bottom = 60.0
	panel.add_child(sub)

	var locked_btn_style := StyleBoxFlat.new()
	locked_btn_style.set_corner_radius_all(14)
	locked_btn_style.bg_color = Color(0.11, 0.09, 0.18, 0.92)
	locked_btn_style.set_border_width_all(2)
	locked_btn_style.set_border_color(Color(0.38, 0.34, 0.52, 0.75))

	# --- LEVEL 1 BOSS CARD (CHROMA TITAN) ---
	var lvl1_card := Panel.new()
	lvl1_card.name = "Level1Card"
	lvl1_card.clip_contents = true
	lvl1_card.anchor_left = 0.5
	lvl1_card.anchor_right = 0.5
	lvl1_card.offset_left = -194.0
	lvl1_card.offset_right = 194.0
	lvl1_card.offset_top = 64.0
	lvl1_card.offset_bottom = 286.0
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(18)
	card_style.bg_color = Color(0.10, 0.07, 0.22, 0.95)
	card_style.set_border_width_all(3)
	card_style.set_border_color(Color(0.35, 0.92, 1.0, 0.92))
	card_style.set_shadow_color(Color(0.35, 0.85, 1.0, 0.38))
	card_style.set_shadow_size(12)
	lvl1_card.add_theme_stylebox_override("panel", card_style)
	panel.add_child(lvl1_card)

	_story_level1_preview_ctrl = Control.new()
	_story_level1_preview_ctrl.name = "BossPreview"
	_story_level1_preview_ctrl.position = Vector2(10.0, 10.0)
	_story_level1_preview_ctrl.size = Vector2(96.0, 148.0)
	_story_level1_preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_level1_preview_ctrl.draw.connect(_draw_story_level1_preview)
	lvl1_card.add_child(_story_level1_preview_ctrl)

	var lvl1_title := Label.new()
	lvl1_title.name = "Level1Title"
	lvl1_title.text = "LVL 1: CHROMA TITAN"
	lvl1_title.clip_text = true
	lvl1_title.offset_left = 114.0
	lvl1_title.offset_right = 378.0
	lvl1_title.offset_top = 10.0
	lvl1_title.offset_bottom = 32.0
	lvl1_title.add_theme_font_size_override("font_size", 12)
	lvl1_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	lvl1_title.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.18, 1.0))
	lvl1_title.add_theme_constant_override("outline_size", 4)
	lvl1_card.add_child(lvl1_title)

	_story_level1_status_label = Label.new()
	_story_level1_status_label.name = "Level1Status"
	_story_level1_status_label.text = "4 PARTS + 15 HP  •  REWARD: +50⚡"
	_story_level1_status_label.clip_text = true
	_story_level1_status_label.offset_left = 114.0
	_story_level1_status_label.offset_right = 378.0
	_story_level1_status_label.offset_top = 32.0
	_story_level1_status_label.offset_bottom = 50.0
	_story_level1_status_label.add_theme_font_size_override("font_size", 9)
	_story_level1_status_label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.65))
	lvl1_card.add_child(_story_level1_status_label)

	var lvl1_desc := Label.new()
	lvl1_desc.name = "Level1Desc"
	lvl1_desc.text = "• Center is WHITE: swipe to ANY color!\n• Destroy all 4 colored Body Parts first!\n• Then drain the Boss's Main HP!\n• Avoid BOMBS (1 → 2 → 3 Bombs)!"
	lvl1_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lvl1_desc.clip_text = true
	lvl1_desc.offset_left = 114.0
	lvl1_desc.offset_right = 378.0
	lvl1_desc.offset_top = 52.0
	lvl1_desc.offset_bottom = 164.0
	lvl1_desc.add_theme_font_size_override("font_size", 9)
	lvl1_desc.add_theme_constant_override("line_spacing", 2)
	lvl1_desc.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	lvl1_card.add_child(lvl1_desc)

	var fight_btn := Button.new()
	fight_btn.name = "FightBossBtn"
	fight_btn.text = "⚔  FIGHT TITAN  ⚔"
	fight_btn.clip_contents = true
	fight_btn.anchor_left = 0.5
	fight_btn.anchor_right = 0.5
	fight_btn.offset_left = -166.0
	fight_btn.offset_right = 166.0
	fight_btn.offset_top = 168.0
	fight_btn.offset_bottom = 210.0
	fight_btn.add_theme_font_size_override("font_size", 14)
	_apply_menu_button_style(fight_btn, _play_btn_style, _play_btn_hover_style)
	fight_btn.pressed.connect(_on_story_level_selected.bind(1))
	lvl1_card.add_child(fight_btn)

	# --- LEVEL 2 BOSS CARD (CYBER HYDRA — NO BOMBS, REFLECTIVE SHIELDS & REGROWTH) ---
	var lvl2_card := Panel.new()
	lvl2_card.name = "Level2Card"
	lvl2_card.clip_contents = true
	lvl2_card.anchor_left = 0.5
	lvl2_card.anchor_right = 0.5
	lvl2_card.offset_left = -194.0
	lvl2_card.offset_right = 194.0
	lvl2_card.offset_top = 296.0
	lvl2_card.offset_bottom = 518.0
	var hydra_card_style := StyleBoxFlat.new()
	hydra_card_style.set_corner_radius_all(18)
	hydra_card_style.bg_color = Color(0.07, 0.14, 0.18, 0.95)
	hydra_card_style.set_border_width_all(3)
	hydra_card_style.set_border_color(Color(0.22, 1.0, 0.72, 0.92))
	hydra_card_style.set_shadow_color(Color(0.18, 0.95, 0.68, 0.38))
	hydra_card_style.set_shadow_size(12)
	lvl2_card.add_theme_stylebox_override("panel", hydra_card_style)
	panel.add_child(lvl2_card)

	_story_level2_preview_ctrl = Control.new()
	_story_level2_preview_ctrl.name = "BossPreview2"
	_story_level2_preview_ctrl.position = Vector2(10.0, 10.0)
	_story_level2_preview_ctrl.size = Vector2(96.0, 148.0)
	_story_level2_preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_level2_preview_ctrl.draw.connect(_draw_story_level2_preview)
	lvl2_card.add_child(_story_level2_preview_ctrl)

	var lvl2_title := Label.new()
	lvl2_title.name = "Level2Title"
	lvl2_title.text = "LVL 2: CYBER HYDRA"
	lvl2_title.clip_text = true
	lvl2_title.offset_left = 114.0
	lvl2_title.offset_right = 378.0
	lvl2_title.offset_top = 10.0
	lvl2_title.offset_bottom = 32.0
	lvl2_title.add_theme_font_size_override("font_size", 12)
	lvl2_title.add_theme_color_override("font_color", Color(0.30, 1.0, 0.75))
	lvl2_title.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.14, 1.0))
	lvl2_title.add_theme_constant_override("outline_size", 4)
	lvl2_card.add_child(lvl2_title)

	_story_level2_status_label = Label.new()
	_story_level2_status_label.name = "Level2Status"
	_story_level2_status_label.text = "🔒 LOCKED — BEAT LEVEL 1 FIRST!"
	_story_level2_status_label.clip_text = true
	_story_level2_status_label.offset_left = 114.0
	_story_level2_status_label.offset_right = 378.0
	_story_level2_status_label.offset_top = 32.0
	_story_level2_status_label.offset_bottom = 50.0
	_story_level2_status_label.add_theme_font_size_override("font_size", 9)
	_story_level2_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	lvl2_card.add_child(_story_level2_status_label)

	var lvl2_desc := Label.new()
	lvl2_desc.name = "Level2Desc"
	lvl2_desc.text = "• NO BOMBS! Shields block squares!\n• Hit a Shield: -1 Life & Hydra HEALS!\n• Swiping dead heads REGROWS (+2 HP)!\n• Sever all 4 Heads, then drain Main HP!"
	lvl2_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lvl2_desc.clip_text = true
	lvl2_desc.offset_left = 114.0
	lvl2_desc.offset_right = 378.0
	lvl2_desc.offset_top = 52.0
	lvl2_desc.offset_bottom = 164.0
	lvl2_desc.add_theme_font_size_override("font_size", 9)
	lvl2_desc.add_theme_constant_override("line_spacing", 2)
	lvl2_desc.add_theme_color_override("font_color", Color(0.92, 0.98, 0.96))
	lvl2_card.add_child(lvl2_desc)

	_story_level2_fight_btn = Button.new()
	_story_level2_fight_btn.name = "FightHydraBtn"
	_story_level2_fight_btn.text = "⚔  FIGHT HYDRA  ⚔"
	_story_level2_fight_btn.clip_contents = true
	_story_level2_fight_btn.anchor_left = 0.5
	_story_level2_fight_btn.anchor_right = 0.5
	_story_level2_fight_btn.offset_left = -166.0
	_story_level2_fight_btn.offset_right = 166.0
	_story_level2_fight_btn.offset_top = 168.0
	_story_level2_fight_btn.offset_bottom = 210.0
	_story_level2_fight_btn.add_theme_font_size_override("font_size", 14)
	_apply_menu_button_style(_story_level2_fight_btn, _story_btn_style, _story_btn_hover_style)
	_story_level2_fight_btn.add_theme_stylebox_override("disabled", locked_btn_style)
	_story_level2_fight_btn.add_theme_color_override("font_disabled_color", Color(0.70, 0.68, 0.82))
	_story_level2_fight_btn.pressed.connect(_on_story_level_selected.bind(2))
	lvl2_card.add_child(_story_level2_fight_btn)

	# --- LEVEL 3 BOSS CARD (VOID SERAPH — VOID RIFTS & DIMENSIONAL COLOR WARP) ---
	var lvl3_card := Panel.new()
	lvl3_card.name = "Level3Card"
	lvl3_card.clip_contents = true
	lvl3_card.anchor_left = 0.5
	lvl3_card.anchor_right = 0.5
	lvl3_card.offset_left = -194.0
	lvl3_card.offset_right = 194.0
	lvl3_card.offset_top = 528.0
	lvl3_card.offset_bottom = 750.0
	var seraph_card_style := StyleBoxFlat.new()
	seraph_card_style.set_corner_radius_all(18)
	seraph_card_style.bg_color = Color(0.13, 0.06, 0.22, 0.95)
	seraph_card_style.set_border_width_all(3)
	seraph_card_style.set_border_color(Color(0.88, 0.35, 1.0, 0.92))
	seraph_card_style.set_shadow_color(Color(0.82, 0.25, 1.0, 0.38))
	seraph_card_style.set_shadow_size(12)
	lvl3_card.add_theme_stylebox_override("panel", seraph_card_style)
	panel.add_child(lvl3_card)

	_story_level3_preview_ctrl = Control.new()
	_story_level3_preview_ctrl.name = "BossPreview3"
	_story_level3_preview_ctrl.position = Vector2(10.0, 10.0)
	_story_level3_preview_ctrl.size = Vector2(96.0, 148.0)
	_story_level3_preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_level3_preview_ctrl.draw.connect(_draw_story_level3_preview)
	lvl3_card.add_child(_story_level3_preview_ctrl)

	var lvl3_title := Label.new()
	lvl3_title.name = "Level3Title"
	lvl3_title.text = "LVL 3: VOID SERAPH"
	lvl3_title.clip_text = true
	lvl3_title.offset_left = 114.0
	lvl3_title.offset_right = 378.0
	lvl3_title.offset_top = 10.0
	lvl3_title.offset_bottom = 32.0
	lvl3_title.add_theme_font_size_override("font_size", 12)
	lvl3_title.add_theme_color_override("font_color", Color(0.92, 0.55, 1.0))
	lvl3_title.add_theme_color_override("font_outline_color", Color(0.10, 0.03, 0.16, 1.0))
	lvl3_title.add_theme_constant_override("outline_size", 4)
	lvl3_card.add_child(lvl3_title)

	_story_level3_status_label = Label.new()
	_story_level3_status_label.name = "Level3Status"
	_story_level3_status_label.text = "🔒 LOCKED — BEAT LEVEL 2 FIRST!"
	_story_level3_status_label.clip_text = true
	_story_level3_status_label.offset_left = 114.0
	_story_level3_status_label.offset_right = 378.0
	_story_level3_status_label.offset_top = 32.0
	_story_level3_status_label.offset_bottom = 50.0
	_story_level3_status_label.add_theme_font_size_override("font_size", 9)
	_story_level3_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	lvl3_card.add_child(_story_level3_status_label)

	var lvl3_desc := Label.new()
	lvl3_desc.name = "Level3Desc"
	lvl3_desc.text = "• Void Rifts lock last swiped square!\n• Board colors WARP after every attack!\n• Dead wings DRAIN +2 HP to Boss Core!\n• Shatter 4 Wings, then drain Main HP!"
	lvl3_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lvl3_desc.clip_text = true
	lvl3_desc.offset_left = 114.0
	lvl3_desc.offset_right = 378.0
	lvl3_desc.offset_top = 52.0
	lvl3_desc.offset_bottom = 164.0
	lvl3_desc.add_theme_font_size_override("font_size", 9)
	lvl3_desc.add_theme_constant_override("line_spacing", 2)
	lvl3_desc.add_theme_color_override("font_color", Color(0.96, 0.92, 1.0))
	lvl3_card.add_child(lvl3_desc)

	var seraph_btn_style := _story_btn_style.duplicate() as StyleBoxFlat
	seraph_btn_style.bg_color = Color(0.55, 0.14, 0.88, 0.94)
	seraph_btn_style.border_color = Color(1.0, 0.85, 0.35, 0.95)
	seraph_btn_style.shadow_color = Color(0.75, 0.22, 1.0, 0.55)
	var seraph_btn_hover_style := _story_btn_hover_style.duplicate() as StyleBoxFlat
	seraph_btn_hover_style.bg_color = Color(0.68, 0.22, 0.98, 0.98)
	seraph_btn_hover_style.border_color = Color(1.0, 0.92, 0.55, 1.0)
	seraph_btn_hover_style.shadow_color = Color(0.85, 0.35, 1.0, 0.72)

	_story_level3_fight_btn = Button.new()
	_story_level3_fight_btn.name = "FightSeraphBtn"
	_story_level3_fight_btn.text = "⚔  FIGHT SERAPH  ⚔"
	_story_level3_fight_btn.clip_contents = true
	_story_level3_fight_btn.anchor_left = 0.5
	_story_level3_fight_btn.anchor_right = 0.5
	_story_level3_fight_btn.offset_left = -166.0
	_story_level3_fight_btn.offset_right = 166.0
	_story_level3_fight_btn.offset_top = 168.0
	_story_level3_fight_btn.offset_bottom = 210.0
	_story_level3_fight_btn.add_theme_font_size_override("font_size", 14)
	_apply_menu_button_style(_story_level3_fight_btn, seraph_btn_style, seraph_btn_hover_style)
	_story_level3_fight_btn.add_theme_stylebox_override("disabled", locked_btn_style)
	_story_level3_fight_btn.add_theme_color_override("font_disabled_color", Color(0.70, 0.68, 0.82))
	_story_level3_fight_btn.pressed.connect(_on_story_level_selected.bind(3))
	lvl3_card.add_child(_story_level3_fight_btn)

	# --- LEVEL 4 BOSS CARD (PHANTOM MAESTRO — MELODIES, MIRROR CURSE & MASQUERADE) ---
	var lvl4_card := Panel.new()
	lvl4_card.name = "Level4Card"
	lvl4_card.clip_contents = true
	lvl4_card.anchor_left = 0.5
	lvl4_card.anchor_right = 0.5
	lvl4_card.offset_left = -194.0
	lvl4_card.offset_right = 194.0
	var maestro_card_style := StyleBoxFlat.new()
	maestro_card_style.set_corner_radius_all(18)
	maestro_card_style.bg_color = Color(0.17, 0.05, 0.09, 0.95)
	maestro_card_style.set_border_width_all(3)
	maestro_card_style.set_border_color(Color(1.0, 0.72, 0.30, 0.92))
	maestro_card_style.set_shadow_color(Color(1.0, 0.30, 0.40, 0.38))
	maestro_card_style.set_shadow_size(12)
	lvl4_card.add_theme_stylebox_override("panel", maestro_card_style)
	panel.add_child(lvl4_card)

	_story_level4_preview_ctrl = Control.new()
	_story_level4_preview_ctrl.name = "BossPreview4"
	_story_level4_preview_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_level4_preview_ctrl.draw.connect(_draw_story_level4_preview)
	lvl4_card.add_child(_story_level4_preview_ctrl)

	var lvl4_title := Label.new()
	lvl4_title.name = "Level4Title"
	lvl4_title.text = "LVL 4: PHANTOM MAESTRO"
	lvl4_title.clip_text = true
	lvl4_title.add_theme_font_size_override("font_size", 12)
	lvl4_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	lvl4_title.add_theme_color_override("font_outline_color", Color(0.16, 0.03, 0.06, 1.0))
	lvl4_title.add_theme_constant_override("outline_size", 4)
	lvl4_card.add_child(lvl4_title)

	_story_level4_status_label = Label.new()
	_story_level4_status_label.name = "Level4Status"
	_story_level4_status_label.text = "🔒 LOCKED — BEAT LEVEL 3 FIRST!"
	_story_level4_status_label.clip_text = true
	_story_level4_status_label.add_theme_font_size_override("font_size", 9)
	_story_level4_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	lvl4_card.add_child(_story_level4_status_label)

	var lvl4_desc := Label.new()
	lvl4_desc.name = "Level4Desc"
	lvl4_desc.text = "• Play his MELODY: swipe notes 1 → 2 → 3!\n• Wrong note: -1 Life & melody resets!\n• MIRROR curse REVERSES your swipes!\n• Phase 2: remember the TRUE MASK!"
	lvl4_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lvl4_desc.clip_text = true
	lvl4_desc.add_theme_font_size_override("font_size", 9)
	lvl4_desc.add_theme_constant_override("line_spacing", 2)
	lvl4_desc.add_theme_color_override("font_color", Color(1.0, 0.93, 0.90))
	lvl4_card.add_child(lvl4_desc)

	var maestro_btn_style := _story_btn_style.duplicate() as StyleBoxFlat
	maestro_btn_style.bg_color = Color(0.78, 0.16, 0.26, 0.94)
	maestro_btn_style.border_color = Color(1.0, 0.82, 0.38, 0.95)
	maestro_btn_style.shadow_color = Color(1.0, 0.28, 0.35, 0.55)
	var maestro_btn_hover_style := _story_btn_hover_style.duplicate() as StyleBoxFlat
	maestro_btn_hover_style.bg_color = Color(0.92, 0.24, 0.32, 0.98)
	maestro_btn_hover_style.border_color = Color(1.0, 0.90, 0.55, 1.0)
	maestro_btn_hover_style.shadow_color = Color(1.0, 0.40, 0.42, 0.72)

	_story_level4_fight_btn = Button.new()
	_story_level4_fight_btn.name = "FightMaestroBtn"
	_story_level4_fight_btn.text = "⚔  FIGHT MAESTRO  ⚔"
	_story_level4_fight_btn.clip_contents = true
	_apply_menu_button_style(_story_level4_fight_btn, maestro_btn_style, maestro_btn_hover_style)
	_story_level4_fight_btn.add_theme_stylebox_override("disabled", locked_btn_style)
	_story_level4_fight_btn.add_theme_color_override("font_disabled_color", Color(0.70, 0.68, 0.82))
	_story_level4_fight_btn.pressed.connect(_on_story_level_selected.bind(4))
	lvl4_card.add_child(_story_level4_fight_btn)

	# Compact layout so all 4 Boss Cards fit inside the Story panel
	_layout_story_level_cards(panel)

	# --- CLOSE / BACK BUTTON ---
	var back_btn := Button.new()
	back_btn.name = "BackStoryBtn"
	back_btn.text = "BACK"
	back_btn.clip_contents = true
	back_btn.anchor_left = 0.5
	back_btn.anchor_right = 0.5
	back_btn.offset_left = -100.0
	back_btn.offset_right = 100.0
	back_btn.offset_top = 762.0
	back_btn.offset_bottom = 804.0
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	back_btn.add_theme_stylebox_override("normal", _btn_style)
	back_btn.add_theme_stylebox_override("hover", _btn_style)
	back_btn.add_theme_stylebox_override("pressed", _btn_style)
	back_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back_btn.pressed.connect(_close_story_screen)
	panel.add_child(back_btn)


func _on_story_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_story_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_close_story_screen()


func _open_story_screen() -> void:
	sfx.play("tap")
	_haptic_tap()
	_refresh_story_screen()
	_story_screen.visible = true


func _close_story_screen() -> void:
	sfx.play("tap")
	_haptic_tap()
	_story_screen.visible = false


func _refresh_story_screen() -> void:
	var lv1_cleared: bool = settings != null and settings.is_story_level_cleared(1)
	var lv2_cleared: bool = settings != null and settings.is_story_level_cleared(2)
	var lv3_cleared: bool = settings != null and settings.is_story_level_cleared(3)

	if _story_level1_status_label != null and is_instance_valid(_story_level1_status_label):
		if lv1_cleared:
			_story_level1_status_label.text = "★ CLEARED! ★  (REPLAY: +15⚡)"
			_story_level1_status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			_story_level1_status_label.text = "4 PARTS + 15 HP  •  REWARD: +50⚡"
			_story_level1_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))

	if _story_level2_status_label != null and is_instance_valid(_story_level2_status_label):
		if not lv1_cleared:
			_story_level2_status_label.text = "🔒 LOCKED — BEAT LEVEL 1 FIRST!"
			_story_level2_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))
		elif lv2_cleared:
			_story_level2_status_label.text = "★ CLEARED! ★  (REPLAY: +25⚡)"
			_story_level2_status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			_story_level2_status_label.text = "4 HEADS + 18 HP  •  REWARD: +75⚡"
			_story_level2_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	if _story_level2_fight_btn != null and is_instance_valid(_story_level2_fight_btn):
		_story_level2_fight_btn.disabled = not lv1_cleared
		_story_level2_fight_btn.text = "⚔  FIGHT HYDRA  ⚔" if lv1_cleared else "🔒  BEAT LVL 1 TO UNLOCK"

	if _story_level3_status_label != null and is_instance_valid(_story_level3_status_label):
		if not lv2_cleared:
			_story_level3_status_label.text = "🔒 LOCKED — BEAT LEVEL 2 FIRST!"
			_story_level3_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))
		elif lv3_cleared:
			_story_level3_status_label.text = "★ CLEARED! ★  (REPLAY: +40⚡)"
			_story_level3_status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			_story_level3_status_label.text = "4 WINGS + 20 HP  •  REWARD: +100⚡"
			_story_level3_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	if _story_level3_fight_btn != null and is_instance_valid(_story_level3_fight_btn):
		_story_level3_fight_btn.disabled = not lv2_cleared
		_story_level3_fight_btn.text = "⚔  FIGHT SERAPH  ⚔" if lv2_cleared else "🔒  BEAT LVL 2 TO UNLOCK"

	var lv4_cleared: bool = settings != null and settings.is_story_level_cleared(4)
	if _story_level4_status_label != null and is_instance_valid(_story_level4_status_label):
		if not lv3_cleared:
			_story_level4_status_label.text = "🔒 LOCKED — BEAT LEVEL 3 FIRST!"
			_story_level4_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))
		elif lv4_cleared:
			_story_level4_status_label.text = "★ CLEARED! ★  (REPLAY: +60⚡)"
			_story_level4_status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			_story_level4_status_label.text = "4 INSTRUMENTS + 22 HP  •  REWARD: +150⚡"
			_story_level4_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	if _story_level4_fight_btn != null and is_instance_valid(_story_level4_fight_btn):
		_story_level4_fight_btn.disabled = not lv3_cleared
		_story_level4_fight_btn.text = "⚔  FIGHT MAESTRO  ⚔" if lv3_cleared else "🔒  BEAT LVL 3 TO UNLOCK"
	if _story_level4_preview_ctrl != null and is_instance_valid(_story_level4_preview_ctrl):
		_story_level4_preview_ctrl.queue_redraw()

	if _story_level1_preview_ctrl != null and is_instance_valid(_story_level1_preview_ctrl):
		_story_level1_preview_ctrl.queue_redraw()
	if _story_level2_preview_ctrl != null and is_instance_valid(_story_level2_preview_ctrl):
		_story_level2_preview_ctrl.queue_redraw()
	if _story_level3_preview_ctrl != null and is_instance_valid(_story_level3_preview_ctrl):
		_story_level3_preview_ctrl.queue_redraw()


func _on_story_level_selected(level_num: int) -> void:
	if level_num == 2 and (settings == null or not settings.is_story_level_cleared(1)):
		sfx.play("wrong")
		_haptic_wrong()
		return
	if level_num == 3 and (settings == null or not settings.is_story_level_cleared(2)):
		sfx.play("wrong")
		_haptic_wrong()
		return
	if level_num == 4 and (settings == null or not settings.is_story_level_cleared(3)):
		sfx.play("wrong")
		_haptic_wrong()
		return
	sfx.play("tap")
	_haptic_tap()
	_story_screen.visible = false
	is_story_mode = true
	story_level = level_num
	_fade_transition(_start_game)


func _setup_story_boss_arena() -> void:
	if game_screen == null:
		return

	_story_boss_hud = Control.new()
	_story_boss_hud.name = "StoryBossHUD"
	_story_boss_hud.visible = false
	_story_boss_hud.anchor_right = 1.0
	_story_boss_hud.anchor_bottom = 1.0
	_story_boss_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_boss_hud.z_index = 0
	game_screen.add_child(_story_boss_hud)

	_story_boss_name_label = Label.new()
	_story_boss_name_label.name = "BossNameLabel"
	_story_boss_name_label.text = "⚔ LVL 1: CHROMA TITAN (PARTS: 4/4) ⚔"
	_story_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_boss_name_label.clip_text = true
	_story_boss_name_label.add_theme_font_size_override("font_size", 12)
	_story_boss_name_label.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
	_story_boss_name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.16, 1.0))
	_story_boss_name_label.add_theme_constant_override("outline_size", 5)
	_story_boss_name_label.anchor_left = 0.0
	_story_boss_name_label.anchor_right = 1.0
	_story_boss_name_label.offset_left = 16.0
	_story_boss_name_label.offset_right = -16.0
	_story_boss_name_label.offset_top = 52.0
	_story_boss_name_label.offset_bottom = 76.0
	_story_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_boss_hud.add_child(_story_boss_name_label)

	_story_boss_canvas = Control.new()
	_story_boss_canvas.name = "StoryBossCanvas"
	_story_boss_canvas.anchor_left = 0.0
	_story_boss_canvas.anchor_right = 1.0
	_story_boss_canvas.offset_left = 0.0
	_story_boss_canvas.offset_right = 0.0
	_story_boss_canvas.offset_top = 74.0
	var offset: float = settings.board_vertical_offset if settings != null else 0.0
	_story_boss_canvas.offset_bottom = clampf(418.0 + minf(0.0, offset * 0.85), 330.0, 425.0)
	_story_boss_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_boss_canvas.draw.connect(_draw_story_boss_arena)
	_story_boss_hud.add_child(_story_boss_canvas)

	_story_boss_hp_label = Label.new()
	_story_boss_hp_label.name = "BossHPLabel"
	_story_boss_hp_label.text = "🛡️ SHIELDED (15/15) — BREAK 4 PARTS!"
	_story_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_boss_hp_label.clip_text = true
	_story_boss_hp_label.add_theme_font_size_override("font_size", 10)
	_story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_story_boss_hp_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.14, 1.0))
	_story_boss_hp_label.add_theme_constant_override("outline_size", 4)
	_story_boss_hp_label.anchor_left = 0.5
	_story_boss_hp_label.anchor_right = 0.5
	_story_boss_hp_label.offset_left = -204.0
	_story_boss_hp_label.offset_right = 204.0
	_story_boss_hp_label.offset_top = 78.0
	_story_boss_hp_label.offset_bottom = 98.0
	_story_boss_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_boss_hud.add_child(_story_boss_hp_label)


func _update_story_hud_visibility() -> void:
	if score_label != null and is_instance_valid(score_label):
		score_label.visible = not is_story_mode
	if high_score_label != null and is_instance_valid(high_score_label):
		high_score_label.visible = not is_story_mode
	if _combo_container != null and is_instance_valid(_combo_container):
		_combo_container.visible = not is_story_mode
	if _story_boss_hud != null and is_instance_valid(_story_boss_hud):
		_story_boss_hud.visible = is_story_mode


func _are_all_boss_parts_destroyed() -> bool:
	for d: String in ["up", "down", "left", "right"]:
		if int(story_part_hp.get(d, 0)) > 0:
			return false
	return true


func _get_alive_boss_parts() -> Array[String]:
	var alive: Array[String] = []
	for d: String in ["up", "down", "left", "right"]:
		if int(story_part_hp.get(d, 0)) > 0:
			alive.append(d)
	return alive


func _get_story_bomb_count() -> int:
	var broken_count: int = 4 - _get_alive_boss_parts().size()
	if broken_count >= 4:
		return 3
	if broken_count >= 2:
		return 2
	return 1


func _reset_story_boss_state(level_num: int = 1) -> void:
	story_level = level_num
	story_boss_max_hp = 22 if story_level == 4 else (20 if story_level == 3 else (18 if story_level == 2 else 15))
	story_boss_hp = story_boss_max_hp
	story_boss_ghost_hp = float(story_boss_max_hp)
	story_part_max_hp = 5
	story_part_hp = {
		"up": story_part_max_hp,
		"down": story_part_max_hp,
		"left": story_part_max_hp,
		"right": story_part_max_hp,
	}
	direction_colors = _get_theme().get("board", {}).duplicate()
	_story_last_swiped_dir = ""
	_story_l4_sequence.clear()
	_story_l4_seq_index = 0
	_story_l4_mirror_swipes = 0
	_story_l4_mirror_pending = false
	_story_l4_turns_until_mirror = 4
	_story_l4_true_dir = ""
	_story_l4_reveal_left = 0.0
	story_bomb_dir = ""
	story_bomb_dirs.clear()
	story_boss_enraged = false
	story_victory_animating = false
	story_level_won = false
	_boss_anim_time = 0.0
	_boss_hit_shake = 0.0
	_boss_taunt_anim = 0.0
	_boss_throw_anim = 0.0
	_boss_throw_target_dir = ""
	_boss_throw_target_dirs.clear()
	_boss_death_progress = 0.0
	_boss_part_flash = {"up": 0.0, "down": 0.0, "left": 0.0, "right": 0.0}
	_boss_part_recoil = {"up": 0.0, "down": 0.0, "left": 0.0, "right": 0.0}
	_boss_laser_beams.clear()
	_boss_explosion_shrapnel.clear()
	_boss_explosion_rings.clear()
	_update_story_boss_labels()


func _warp_story_level3_colors(avoid_dir: String = "") -> void:
	var dirs: Array[String] = ["up", "down", "left", "right"]
	var old_cols: Dictionary = {}
	var old_hp: Dictionary = {}
	var old_flash: Dictionary = {}
	var old_recoil: Dictionary = {}
	var any_alive: bool = false
	for d: String in dirs:
		old_cols[d] = direction_colors.get(d, Color.WHITE)
		var hp_v: int = int(story_part_hp.get(d, 0))
		old_hp[d] = hp_v
		if hp_v > 0:
			any_alive = true
		old_flash[d] = float(_boss_part_flash.get(d, 0.0))
		old_recoil[d] = float(_boss_part_recoil.get(d, 0.0))

	var chosen_perm: Array[String] = ["left", "up", "right", "down"]
	for _attempt in range(16):
		var candidate: Array[String] = dirs.duplicate()
		candidate.shuffle()
		var is_identity: bool = true
		var has_safe_alive: bool = (not any_alive) or avoid_dir == ""
		for i in range(4):
			if candidate[i] != dirs[i]:
				is_identity = false
			if dirs[i] != avoid_dir and int(old_hp.get(candidate[i], 0)) > 0:
				has_safe_alive = true
		if not is_identity and has_safe_alive:
			chosen_perm = candidate
			break

	if any_alive and avoid_dir != "":
		var check_safe: bool = false
		for i in range(4):
			if dirs[i] != avoid_dir and int(old_hp.get(chosen_perm[i], 0)) > 0:
				check_safe = true
				break
		if not check_safe:
			var avoid_idx: int = dirs.find(avoid_dir)
			var other_idx: int = (avoid_idx + 1) % 4
			var tmp_d: String = chosen_perm[avoid_idx]
			chosen_perm[avoid_idx] = chosen_perm[other_idx]
			chosen_perm[other_idx] = tmp_d

	for i in range(4):
		var dst_d: String = dirs[i]
		var src_d: String = chosen_perm[i]
		direction_colors[dst_d] = old_cols[src_d]
		story_part_hp[dst_d] = old_hp[src_d]
		_boss_part_flash[dst_d] = old_flash[src_d]
		_boss_part_recoil[dst_d] = old_recoil[src_d]


func _update_story_boss_labels() -> void:
	var all_parts_dead := _are_all_boss_parts_destroyed()
	if _story_boss_name_label != null and is_instance_valid(_story_boss_name_label):
		if story_level == 4:
			if all_parts_dead:
				_story_boss_name_label.text = "🎭 PHANTOM MAESTRO — MASK UNVEILED! 🎭"
				_story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.48))
			else:
				var instr_left: int = _get_alive_boss_parts().size()
				_story_boss_name_label.text = "🎭 LVL 4: PHANTOM MAESTRO (INSTR: " + str(instr_left) + "/4) 🎭"
				_story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.38))
		elif story_level == 3:
			if all_parts_dead:
				_story_boss_name_label.text = "🌀 VOID SERAPH — CORE EXPOSED! 🌀"
				_story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.95))
			else:
				var wings_left: int = _get_alive_boss_parts().size()
				_story_boss_name_label.text = "🌀 LVL 3: VOID SERAPH (WINGS: " + str(wings_left) + "/4) 🌀"
				_story_boss_name_label.add_theme_color_override("font_color", Color(0.92, 0.55, 1.0))
		elif story_level == 2:
			if all_parts_dead:
				_story_boss_name_label.text = "🐍 CYBER HYDRA — HEART EXPOSED! 🐍"
				_story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.75))
			else:
				var heads_left: int = _get_alive_boss_parts().size()
				_story_boss_name_label.text = "🐍 LVL 2: CYBER HYDRA (HEADS: " + str(heads_left) + "/4) 🐍"
				_story_boss_name_label.add_theme_color_override("font_color", Color(0.28, 1.0, 0.75))
		else:
			if all_parts_dead:
				_story_boss_name_label.text = "🔥 CHROMA TITAN — CORE EXPOSED! 🔥"
				_story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45))
			else:
				var parts_left: int = _get_alive_boss_parts().size()
				_story_boss_name_label.text = "⚔ LVL 1: CHROMA TITAN (PARTS: " + str(parts_left) + "/4) ⚔"
				_story_boss_name_label.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
	if _story_boss_hp_label != null and is_instance_valid(_story_boss_hp_label):
		if story_level == 4:
			if _story_l4_mirror_swipes > 0:
				_story_boss_hp_label.text = "🪞 MIRROR CURSE x" + str(_story_l4_mirror_swipes) + " — SWIPES REVERSED! 🪞"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
			elif all_parts_dead:
				_story_boss_hp_label.text = "🎭 MAIN HP: " + str(maxi(0, story_boss_hp)) + " / " + str(story_boss_max_hp) + " (FIND THE TRUE MASK!) 🎭"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
			else:
				var instr_left_hp: int = _get_alive_boss_parts().size()
				_story_boss_hp_label.text = "🎵 SHIELDED (" + str(story_boss_hp) + "/" + str(story_boss_max_hp) + ") — SILENCE " + str(instr_left_hp) + " INSTRUMENTS!"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
		elif story_level == 3:
			if all_parts_dead:
				_story_boss_hp_label.text = "🌀 MAIN HP: " + str(maxi(0, story_boss_hp)) + " / " + str(story_boss_max_hp) + " (3 VOID RIFTS!) 🌀"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(0.95, 0.62, 1.0))
			else:
				var wings_left_hp: int = _get_alive_boss_parts().size()
				_story_boss_hp_label.text = "🛡️ SHIELDED (" + str(story_boss_hp) + "/" + str(story_boss_max_hp) + ") — SHATTER " + str(wings_left_hp) + " WINGS!"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(0.95, 0.84, 1.0))
		elif story_level == 2:
			if all_parts_dead:
				_story_boss_hp_label.text = "🐍 MAIN HP: " + str(maxi(0, story_boss_hp)) + " / " + str(story_boss_max_hp) + " (3 SHIELDS!) 🐍"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.78))
			else:
				var heads_left_hp: int = _get_alive_boss_parts().size()
				_story_boss_hp_label.text = "🛡️ SHIELDED (" + str(story_boss_hp) + "/" + str(story_boss_max_hp) + ") — SEVER " + str(heads_left_hp) + " HEADS!"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(0.80, 1.0, 0.92))
		else:
			if all_parts_dead:
				_story_boss_hp_label.text = "🔥 MAIN HP: " + str(maxi(0, story_boss_hp)) + " / " + str(story_boss_max_hp) + " (3 BOMBS!) 🔥"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
			else:
				var parts_left_hp: int = _get_alive_boss_parts().size()
				_story_boss_hp_label.text = "🛡️ SHIELDED (" + str(story_boss_hp) + "/" + str(story_boss_max_hp) + ") — BREAK " + str(parts_left_hp) + " PARTS!"
				_story_boss_hp_label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))


func _start_story_turn() -> void:
	if state != settings.GameState.PLAYING or story_victory_animating:
		return

	# Clean up any special arcade states (Note: Board NEVER rotates in Boss Mode!)
	powerup_square_dir = ""
	powerup_type = ""
	is_hold_turn = false
	is_holding_active = false
	is_double_turn = false
	double_turn_step = 0
	_cleanup_hold_ui()
	_cleanup_double_turn_ui()

	# Calculate turn time limit (slightly faster when all parts are destroyed & core is exposed)
	var hp_missing_ratio: float = clampf(1.0 - float(story_boss_hp) / float(maxi(1, story_boss_max_hp)), 0.0, 1.0)
	var base_limit: float = GameSettings.INITIAL_TIME_LIMIT - hp_missing_ratio * 0.22
	if story_boss_enraged:
		base_limit -= 0.08
	current_time_limit = clampf(base_limit, 0.78, GameSettings.INITIAL_TIME_LIMIT)
	time_left_in_turn = current_time_limit
	_turn_start_time = Time.get_ticks_msec() / 1000.0

	# Center square is ALWAYS White in Story Mode
	set_random_center_color()

	# Level 4 (Phantom Maestro) uses its own Melody / Mirror / Masquerade turn logic
	if story_level == 4:
		_start_story_level4_turn()
		return

	# Spawn 1, 2, or 3 Bombs depending on how many Boss Body Parts are broken!
	# - 0–1 parts broken: 1 Bomb
	# - 2–3 parts broken: 2 Bombs
	# - All 4 parts broken (Phase 2 Enraged): 3 Bombs (only 1 safe square!)
	# Fairness guarantee: Always keep at least 1 alive body part bomb-free in Phase 1!
	var all_dirs: Array[String] = ["up", "down", "left", "right"]
	var alive_parts: Array[String] = _get_alive_boss_parts()
	var bomb_count: int = _get_story_bomb_count()
	var prev_bombs: Array[String] = story_bomb_dirs.duplicate()

	story_bomb_dirs.clear()
	if alive_parts.is_empty():
		# Phase 2 (All 4 parts broken): 3 Hazards -> 1 Safe Square!
		var prev_safe: String = _story_last_swiped_dir if (story_level == 3 and _story_last_swiped_dir != "") else ""
		if prev_safe == "":
			for d: String in all_dirs:
				if d not in prev_bombs:
					prev_safe = d
					break
		var safe_candidates: Array[String] = []
		for d: String in all_dirs:
			if d != prev_safe:
				safe_candidates.append(d)
		var force_move_safe: bool = (story_level == 3) or (randf() < 0.80)
		var safe_dir: String = safe_candidates.pick_random() if (not safe_candidates.is_empty() and force_move_safe) else all_dirs.pick_random()
		for d: String in all_dirs:
			if d != safe_dir:
				story_bomb_dirs.append(d)
	else:
		# Phase 1: Protect 1 alive body part so at least 1 alive part is ALWAYS hazard-free!
		var candidate_alive: Array[String] = []
		if story_level == 3 and _story_last_swiped_dir != "":
			for d: String in alive_parts:
				if d != _story_last_swiped_dir:
					candidate_alive.append(d)
		if candidate_alive.is_empty():
			candidate_alive = alive_parts.duplicate()

		var protected_dir: String = candidate_alive[0]
		if candidate_alive.size() > 1:
			var rotated_alive: Array[String] = []
			for d: String in candidate_alive:
				if d in prev_bombs:
					rotated_alive.append(d)
			if not rotated_alive.is_empty() and randf() < 0.75:
				protected_dir = rotated_alive.pick_random()
			else:
				protected_dir = candidate_alive.pick_random()

		var allowed_bomb_dirs: Array[String] = []
		for d: String in all_dirs:
			if d != protected_dir:
				allowed_bomb_dirs.append(d)
		allowed_bomb_dirs.shuffle()

		var ordered_pool: Array[String] = []
		if story_level == 3 and _story_last_swiped_dir != "" and _story_last_swiped_dir != protected_dir:
			ordered_pool.append(_story_last_swiped_dir)
			for d: String in allowed_bomb_dirs:
				if d != _story_last_swiped_dir:
					ordered_pool.append(d)
		else:
			var fresh_dirs: Array[String] = []
			var repeat_dirs: Array[String] = []
			for d: String in allowed_bomb_dirs:
				if d not in prev_bombs:
					fresh_dirs.append(d)
				else:
					repeat_dirs.append(d)
			if randf() < 0.78:
				ordered_pool.append_array(fresh_dirs)
				ordered_pool.append_array(repeat_dirs)
			else:
				ordered_pool.append_array(allowed_bomb_dirs)

		for i in range(mini(bomb_count, ordered_pool.size())):
			story_bomb_dirs.append(ordered_pool[i])

	story_bomb_dir = story_bomb_dirs[0] if not story_bomb_dirs.is_empty() else ""
	_boss_throw_target_dirs = story_bomb_dirs.duplicate()
	_boss_throw_target_dir = story_bomb_dir
	_boss_throw_anim = 1.0

	_apply_board_colors()
	_pulse_center()


func _on_story_swipe(direction: String) -> void:
	if state != settings.GameState.PLAYING or story_victory_animating:
		return

	_clear_persistent_labels()
	_squash_stretch_center(direction)
	total_swipes += 1

	if story_level == 4:
		_on_story_level4_swipe(direction)
		return

	# Check if player swiped onto any square with a Boss Hazard!
	if direction in story_bomb_dirs or (story_bomb_dir != "" and direction == story_bomb_dir):
		_on_story_bomb_hit(direction)
		return

	# Safe swipe!
	# 1. All active Hazards disappear immediately after a correct swipe!
	if not story_bomb_dirs.is_empty():
		for b_dir: String in story_bomb_dirs:
			var old_bomb_pos := _get_board_center(b_dir)
			_burst_particles(old_bomb_pos, Color(0.75, 0.85, 1.0, 0.7), 4)
		story_bomb_dirs.clear()
	story_bomb_dir = ""

	# 2. Match swiped color with Boss body part & drain HP!
	_on_story_boss_hit(direction)


func _on_story_bomb_hit(bomb_dir: String) -> void:
	var bomb_pos := _get_board_center(bomb_dir)
	story_bomb_dirs.clear()
	story_bomb_dir = ""
	_boss_taunt_anim = 1.0
	_story_last_swiped_dir = bomb_dir

	if story_level == 3:
		# Level 3 (Void Seraph): Void Singularity pull & Dimensional Color Warp!
		_flash_square(bomb_dir, Color(1.55, 0.35, 1.95, 0.98))
		_burst_particles(bomb_pos, Color(1.35, 0.28, 1.85), 26)
		_burst_particles(bomb_pos, Color(1.0, 0.90, 0.35), 14)
		_burst_at(bomb_pos, Color(1.25, 0.25, 1.75))
		_warp_story_level3_colors(bomb_dir)
		_update_story_boss_labels()
	elif story_level == 2:
		# Level 2 (Cyber Hydra): Reflective Shield Counter-Shock & Boss Drain-Heal!
		_flash_square(bomb_dir, Color(0.25, 1.8, 1.1, 0.98))
		_burst_particles(bomb_pos, Color(0.2, 1.5, 0.95), 24)
		_burst_particles(bomb_pos, Color(0.95, 0.35, 1.6), 14)
		_burst_at(bomb_pos, Color(0.2, 1.4, 0.85))

		# Cyber Hydra absorbs the reflected energy to heal itself!
		if _are_all_boss_parts_destroyed():
			story_boss_hp = mini(story_boss_max_hp, story_boss_hp + 2)
		else:
			var cur_h: int = int(story_part_hp.get(bomb_dir, 0))
			if cur_h > 0 and cur_h < story_part_max_hp:
				story_part_hp[bomb_dir] = mini(story_part_max_hp, cur_h + 1)
			else:
				for d_heal: String in ["up", "down", "left", "right"]:
					var dh_val: int = int(story_part_hp.get(d_heal, 0))
					if dh_val > 0 and dh_val < story_part_max_hp:
						story_part_hp[d_heal] = mini(story_part_max_hp, dh_val + 1)
						break
		_update_story_boss_labels()
	else:
		# Level 1 (Chroma Titan): Fiery bomb explosion visuals on the bombed square
		_flash_square(bomb_dir, Color(1.8, 0.25, 0.2, 0.98))
		_burst_particles(bomb_pos, Color(1.5, 0.35, 0.15), 24)
		_burst_particles(bomb_pos, Color(1.0, 0.85, 0.2), 14)
		_burst_at(bomb_pos, Color(1.4, 0.25, 0.2))

	lives -= 1
	_lost_heart_this_game = true
	streak = 0
	perfect_streak = 0
	_audio_pulse = 0.9

	sfx.play("wrong")
	_haptic_danger()
	_shake_screen(14.0)
	_flash_center_red()
	if story_level == 3:
		_show_persistent_label("🌀 VOID RIFT! -1 HP (COLORS WARPED)", bomb_pos, Color(0.95, 0.55, 1.0), true)
	elif story_level == 2:
		_show_persistent_label("🛡️ REFLECT! -1 HP (BOSS HEALED)", bomb_pos, Color(0.28, 1.0, 0.82), true)
	else:
		_show_persistent_label("💥 BOMB! -1 HP", bomb_pos, Color(1.0, 0.3, 0.32), true)
	_update_lives_display()
	_apply_board_colors()

	if lives <= 0:
		_game_over()
	else:
		start_new_turn()


func _on_story_boss_hit(direction: String, dmg: int = 1) -> void:
	dmg = maxi(1, dmg)
	var encore_prefix: String = "🎵 ENCORE! " if dmg > 1 else ""
	_story_last_swiped_dir = direction
	var reaction_time: float = (Time.get_ticks_msec() / 1000.0) - _turn_start_time
	if reaction_time > 0.03 and reaction_time < fastest_reaction_this_game:
		fastest_reaction_this_game = reaction_time
	if (current_time_limit - time_left_in_turn) <= 0.40:
		_fast_swipes_this_game += 1

	streak += 1
	if streak > best_streak_this_game:
		best_streak_this_game = streak
	total_correct += 1

	var mult := _current_combo_multiplier()
	var hit_col: Color = direction_colors.get(direction, Color(0.3, 0.95, 1.0))
	var sq_center := _get_board_center(direction)
	var all_parts_already_dead := _are_all_boss_parts_destroyed()
	var target_dir: String = "core" if all_parts_already_dead else direction
	var boss_part_pos := _get_boss_part_screen_pos(target_dir)
	var canvas_top: float = _story_boss_canvas.offset_top if (_story_boss_canvas != null and is_instance_valid(_story_boss_canvas)) else 74.0
	var canvas_local_pos := boss_part_pos - Vector2(0.0, canvas_top)

	# Spawn colored laser beam from the swiped square to the Boss target!
	_boss_laser_beams.append({
		"from": sq_center,
		"to": boss_part_pos,
		"color": hit_col,
		"age": 0.0,
		"duration": 0.28,
	})

	var part_names := {
		"up": "BELL" if story_level == 4 else ("TOP WING" if story_level == 3 else ("TOP FANG" if story_level == 2 else "HEAD")),
		"down": "DRUM" if story_level == 4 else ("SOLAR HALO" if story_level == 3 else ("LOW FANG" if story_level == 2 else "ARMOR")),
		"left": "HARP" if story_level == 4 else ("LEFT WING" if story_level == 3 else ("LEFT FANG" if story_level == 2 else "CLAW")),
		"right": "HORN" if story_level == 4 else ("RIGHT WING" if story_level == 3 else ("RIGHT FANG" if story_level == 2 else "CANNON")),
	}
	var p_name: String = str(part_names.get(direction, "PART"))
	var streak_pitch: float = 1.0 + float(streak % 14) * 0.024

	# =========================================================
	# PHASE 1: DESTROY ALL 4 BODY PARTS FIRST (MAIN HP SHIELDED)
	# =========================================================
	if not all_parts_already_dead:
		var cur_part_hp: int = int(story_part_hp.get(direction, 0))
		if cur_part_hp > 0:
			cur_part_hp = maxi(0, cur_part_hp - dmg)
			story_part_hp[direction] = cur_part_hp
			var part_destroyed_now: bool = (cur_part_hp <= 0)

			_boss_part_flash[direction] = 1.0
			_boss_part_recoil[direction] = 1.0
			_boss_hit_shake = 1.0 if part_destroyed_now else 0.65
			_audio_pulse = minf(1.0, _audio_pulse + (0.95 if part_destroyed_now else 0.70))
			score += (350 if part_destroyed_now else 150) * mult

			_flash_square(direction, Color(1.0, 1.0, 1.0, 0.8))
			_burst_particles(sq_center, hit_col, 8)
			_burst_particles(boss_part_pos, hit_col.lightened(0.25), 24 if part_destroyed_now else 11)
			_burst_at(boss_part_pos, hit_col)

			if part_destroyed_now:
				_spawn_boss_canvas_explosion(canvas_local_pos, hit_col, 0.95)
				sfx.play_pitched("unlock", 1.12)
				_haptic_frenzy()
				_shake_screen(11.0)
				var verb_broken := "SILENCED" if story_level == 4 else ("SHATTERED" if story_level == 3 else ("SEVERED" if story_level == 2 else "BROKEN"))
				if _are_all_boss_parts_destroyed():
					story_boss_enraged = true
					sfx.play_voice("overdrive", 88, 1.2)
					if story_level == 4:
						_story_l4_sequence.clear()
						_story_l4_seq_index = 0
						_show_remap_banner("🎭 MASK UNVEILED: FIND THE TRUE MASK! 🎭")
					elif story_level == 3:
						_show_remap_banner("🌀 CORE EXPOSED: 3 VOID RIFTS! 🌀")
					elif story_level == 2:
						_show_remap_banner("🐍 HEART EXPOSED: 3 SHIELDS! 🐍")
					else:
						_show_remap_banner("🔥 CORE EXPOSED: 3 BOMBS! 🔥")
					_show_persistent_label("💥 " + p_name + " " + verb_broken + "!", sq_center, Color(1.0, 0.92, 0.25), true)
				else:
					var rem_parts: int = _get_alive_boss_parts().size()
					if story_level == 4 and rem_parts == 3:
						_show_remap_banner("🪞 MIRROR CURSE AWAKENS! 🪞")
					elif rem_parts == 2:
						if story_level == 4:
							_show_remap_banner("⚠️ MAESTRO ENRAGED: 3-NOTE MELODIES! ⚠️")
						elif story_level == 3:
							_show_remap_banner("⚠️ SERAPH ENRAGED: 2 VOID RIFTS! ⚠️")
						elif story_level == 2:
							_show_remap_banner("⚠️ HYDRA ENRAGED: 2 SHIELDS! ⚠️")
						else:
							_show_remap_banner("⚠️ BOSS ENRAGED: 2 BOMBS! ⚠️")
					_show_persistent_label("💥 " + p_name + " " + verb_broken + "! (" + str(rem_parts) + " LEFT)", sq_center, Color(1.0, 0.92, 0.25), true)
			else:
				sfx.play_pitched("correct", streak_pitch)
				_haptic_correct()
				_shake_screen(4.5)
				_show_persistent_label(encore_prefix + p_name + " -" + str(dmg) + " (" + str(cur_part_hp) + "/" + str(story_part_max_hp) + ")", sq_center, hit_col.lightened(0.2), dmg > 1)
		else:
			# Swiped a color whose body part is already destroyed while other parts remain alive!
			if story_level == 4:
				# Level 4 (Phantom Maestro): Silenced instrument notes still count toward the melody
				_boss_part_flash[direction] = 0.35
				sfx.play_pitched("correct", streak_pitch * 0.92)
				_haptic_correct()
				_flash_square(direction, Color(1.0, 0.88, 0.55, 0.6))
				_burst_particles(sq_center, Color(1.0, 0.85, 0.45), 6)
				_show_persistent_label("🎵 NOTE " + str(_story_l4_seq_index) + " ✓", sq_center, Color(1.0, 0.90, 0.55), false)
			elif story_level == 3:
				# Level 3 (Void Seraph): Swiping a shattered wing channels VOID DRAIN (+2 Main HP to Core)!
				story_boss_hp = mini(story_boss_max_hp + 6, story_boss_hp + 2)
				story_boss_ghost_hp = float(story_boss_hp)
				_boss_part_flash["down"] = 1.0
				_boss_taunt_anim = 0.85
				sfx.play_pitched("wrong", 1.18)
				_haptic_wrong()
				_shake_screen(8.0)
				_flash_square(direction, Color(1.45, 0.35, 1.85, 0.85))
				_burst_particles(boss_part_pos, Color(1.35, 0.35, 1.85), 16)
				_show_persistent_label("🌀 VOID DRAIN! CORE +2 HP!", sq_center, Color(0.95, 0.55, 1.0), true)
			elif story_level == 2:
				# Level 2 (Cyber Hydra): Swiping a severed head triggers HYDRA REGROWTH (+2 HP)!
				story_part_hp[direction] = 2
				_boss_part_flash[direction] = 1.0
				_boss_part_recoil[direction] = -0.8
				_boss_taunt_anim = 0.85
				sfx.play_pitched("wrong", 1.15)
				_haptic_wrong()
				_shake_screen(8.0)
				_flash_square(direction, Color(0.25, 1.6, 0.75, 0.85))
				_burst_particles(boss_part_pos, Color(0.25, 1.5, 0.75), 16)
				_show_persistent_label("🐍 HEAD REGROWN! (2/" + str(story_part_max_hp) + ")", sq_center, Color(0.30, 1.0, 0.68), true)
			else:
				_boss_part_flash[direction] = 0.45
				_boss_part_recoil[direction] = 0.35
				sfx.play_pitched("tap", 0.95)
				_haptic_tap()
				_flash_square(direction, Color(0.7, 0.75, 0.85, 0.5))
				_burst_particles(boss_part_pos, Color(0.6, 0.65, 0.75), 5)
				_show_persistent_label("⚡ HIT ACTIVE PARTS!", sq_center, Color(0.85, 0.90, 1.0), false)

		if story_level == 3:
			_warp_story_level3_colors(direction)
		_update_story_boss_labels()
		_apply_board_colors()
		start_new_turn()
		return

	# =========================================================
	# PHASE 2: ALL 4 BODY PARTS DESTROYED -> DRAIN MAIN BOSS HP!
	# =========================================================
	story_boss_hp = maxi(0, story_boss_hp - dmg)
	_boss_part_flash["down"] = 1.0
	_boss_part_flash[direction] = 0.85
	_boss_part_recoil["down"] = 1.0
	_boss_part_recoil[direction] = 0.65
	_boss_hit_shake = 0.85
	_audio_pulse = minf(1.0, _audio_pulse + 0.82)
	score += 220 * mult

	sfx.play_pitched("correct", streak_pitch + 0.08)
	if streak % 5 == 0:
		sfx.play_pitched("combo", 1.10)
		_haptic_combo()
	else:
		_haptic_correct()
	_shake_screen(6.5)

	_flash_square(direction, Color(1.0, 1.0, 1.0, 0.85))
	_burst_particles(sq_center, hit_col, 10)
	_burst_particles(boss_part_pos, hit_col.lightened(0.3), 16)
	_burst_at(boss_part_pos, hit_col)
	_spawn_boss_canvas_explosion(canvas_local_pos, hit_col, 0.45)

	_show_persistent_label(encore_prefix + "🔥 HP -" + str(dmg) + " (" + str(story_boss_hp) + "/" + str(story_boss_max_hp) + ")", sq_center, Color(1.0, 0.88, 0.28), false)

	if story_level == 3 and story_boss_hp > 0:
		_warp_story_level3_colors(direction)
	_update_story_boss_labels()
	_apply_board_colors()

	# Check if Boss is defeated!
	if story_boss_hp <= 0:
		_trigger_story_boss_victory()
		return

	start_new_turn()


func _spawn_boss_canvas_explosion(pos: Vector2, col: Color, intensity: float = 1.0) -> void:
	_boss_explosion_rings.append({
		"pos": pos,
		"color": col,
		"age": 0.0,
		"duration": 0.48 * clampf(intensity, 0.6, 1.5),
		"max_radius": 92.0 * intensity,
	})
	var shard_count: int = maxi(6, int(round(18.0 * intensity)))
	for i in range(shard_count):
		var ang: float = randf() * TAU
		var spd: float = randf_range(75.0, 290.0) * clampf(intensity, 0.65, 1.45)
		var shard_col: Color = col
		var r_pick: float = randf()
		if r_pick < 0.28:
			shard_col = Color(1.0, 0.92, 0.28)
		elif r_pick < 0.52:
			shard_col = Color(1.6, 0.42, 0.15)
		elif r_pick < 0.70:
			shard_col = Color(1.4, 1.4, 1.5)
		_boss_explosion_shrapnel.append({
			"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"rot": randf() * TAU,
			"rot_speed": randf_range(-14.0, 14.0),
			"size": randf_range(5.0, 14.0) * clampf(intensity, 0.75, 1.35),
			"color": shard_col,
			"age": 0.0,
			"duration": randf_range(0.45, 0.95),
		})


func _trigger_story_boss_victory() -> void:
	story_victory_animating = true
	story_level_won = true
	story_bomb_dir = ""
	story_bomb_dirs.clear()
	_boss_throw_target_dirs.clear()
	_center_scale_locked = true
	if center_square != null:
		center_square.scale = Vector2.ONE
	_apply_board_colors()

	# Award Neon Sparks for defeating the Boss (Lv 1: +50/+15, Lv 2: +75/+25, Lv 3: +100/+40)
	var first_clear: bool = false
	if settings != null and not _tamper_flagged:
		first_clear = settings.complete_story_level(story_level)
		var spark_reward: int = 50 if first_clear else 15
		if story_level == 4:
			spark_reward = 150 if first_clear else 60
		elif story_level == 3:
			spark_reward = 100 if first_clear else 40
		elif story_level == 2:
			spark_reward = 75 if first_clear else 25
		settings.add_sparks(spark_reward)
		sparks_collected_in_run += spark_reward
		score += 6500 if story_level == 4 else (5000 if story_level == 3 else (3500 if story_level == 2 else 2500))
		_update_sparks_displays()

	sfx.play("unlock")
	sfx.play_voice("legendary", 98, 0.5)
	_haptic_celebration()
	_shake_screen(18.0)
	if story_level == 4:
		_show_remap_banner("💥 MAESTRO SILENCED! 💥")
	elif story_level == 3:
		_show_remap_banner("💥 SERAPH OBLITERATED! 💥")
	elif story_level == 2:
		_show_remap_banner("💥 HYDRA OBLITERATED! 💥")
	else:
		_show_remap_banner("💥 BOSS OBLITERATED! 💥")

	var canvas_top: float = _story_boss_canvas.offset_top if (_story_boss_canvas != null and is_instance_valid(_story_boss_canvas)) else 74.0
	var boss_center_screen := _get_boss_part_screen_pos("down")
	_spawn_boss_canvas_explosion(boss_center_screen - Vector2(0.0, canvas_top), Color(1.0, 0.85, 0.25), 1.45)

	# Multi-explosion Boss Destruction Sequence over 1.65 seconds
	var dirs := ["up", "left", "right", "down"]
	var death_tw := create_tween()
	death_tw.tween_property(self, "_boss_death_progress", 1.0, 1.50)

	for i in range(10):
		var delay_t: float = float(i) * 0.13
		get_tree().create_timer(delay_t).timeout.connect(func():
			if not is_inside_tree():
				return
			var d_key: String = dirs[i % dirs.size()]
			var p_pos := _get_boss_part_screen_pos(d_key) + Vector2(randf_range(-34.0, 34.0), randf_range(-26.0, 26.0))
			var exp_col: Color = direction_colors.get(d_key, Color(1.0, 0.85, 0.2))
			_boss_part_flash[d_key] = 1.0
			_boss_hit_shake = 1.0
			_spawn_boss_canvas_explosion(p_pos - Vector2(0.0, canvas_top), exp_col, 1.15 if i < 8 else 1.75)
			_burst_particles(p_pos, exp_col, 24)
			_burst_particles(p_pos, Color(1.0, 0.95, 0.4), 16)
			_shake_screen(12.0 if i < 8 else 20.0)
			if i % 2 == 0:
				sfx.play_pitched("combo", 0.88 + float(i) * 0.08)
				_haptic_tap()
		)

	get_tree().create_timer(1.65).timeout.connect(func():
		if not is_inside_tree():
			return
		story_victory_animating = false
		if first_clear:
			if story_level == 4:
				_queue_achievement_toast({
					"header": "STORY LEVEL 4 CLEARED!  +150 SPARKS",
					"name": "PHANTOM MAESTRO SLAYER",
					"desc": "Silenced the Phantom Maestro in Story Mode!",
					"icon": "crown",
					"color": Color(1.0, 0.72, 0.32),
				})
			elif story_level == 3:
				_queue_achievement_toast({
					"header": "STORY LEVEL 3 CLEARED!  +100 SPARKS",
					"name": "VOID SERAPH SLAYER",
					"desc": "Defeated Void Seraph in Story Mode!",
					"icon": "crown",
					"color": Color(0.92, 0.48, 1.0),
				})
			elif story_level == 2:
				_queue_achievement_toast({
					"header": "STORY LEVEL 2 CLEARED!  +75 SPARKS",
					"name": "CYBER HYDRA SLAYER",
					"desc": "Defeated Cyber Hydra in Story Mode!",
					"icon": "crown",
					"color": Color(0.20, 1.0, 0.68),
				})
			else:
				_queue_achievement_toast({
					"header": "STORY LEVEL 1 CLEARED!  +50 SPARKS",
					"name": "CHROMA TITAN SLAYER",
					"desc": "Defeated Chroma Titan in Story Mode!",
					"icon": "crown",
					"color": Color(0.35, 0.95, 1.0),
				})
		_game_over()
	)


func _get_boss_part_screen_pos(direction: String) -> Vector2:
	var canvas_top: float = 74.0
	var canvas_h: float = 344.0
	if _story_boss_canvas != null and is_instance_valid(_story_boss_canvas):
		canvas_top = _story_boss_canvas.offset_top
		canvas_h = maxf(240.0, _story_boss_canvas.offset_bottom - _story_boss_canvas.offset_top)
	var boss_origin := Vector2(270.0, canvas_top + canvas_h * 0.60)
	if story_level == 4:
		match direction:
			"up":
				return boss_origin + Vector2(0.0, -90.0)
			"down":
				return boss_origin + Vector2(0.0, 58.0)
			"left":
				return boss_origin + Vector2(-112.0, -4.0)
			"right":
				return boss_origin + Vector2(112.0, -4.0)
			"core":
				return boss_origin + Vector2(0.0, -30.0)
		return boss_origin
	match direction:
		"up":
			return boss_origin + Vector2(0.0, -72.0)
		"down", "core":
			return boss_origin + Vector2(0.0, 12.0)
		"left":
			return boss_origin + Vector2(-112.0, -4.0)
		"right":
			return boss_origin + Vector2(112.0, -4.0)
	return boss_origin


func _process_story_boss_visuals(delta: float) -> void:
	_boss_anim_time += delta

	# Keep Level Select mini boss previews animated when Story Screen is open
	if _story_screen != null and _story_screen.visible:
		if _story_level1_preview_ctrl != null and is_instance_valid(_story_level1_preview_ctrl):
			_story_level1_preview_ctrl.queue_redraw()
		if _story_level2_preview_ctrl != null and is_instance_valid(_story_level2_preview_ctrl):
			_story_level2_preview_ctrl.queue_redraw()
		if _story_level3_preview_ctrl != null and is_instance_valid(_story_level3_preview_ctrl):
			_story_level3_preview_ctrl.queue_redraw()
		if _story_level4_preview_ctrl != null and is_instance_valid(_story_level4_preview_ctrl):
			_story_level4_preview_ctrl.queue_redraw()

	if not is_story_mode:
		return

	# Level 4 Masquerade: once the brief True Mask reveal ends, hide all squares behind identical masks
	if story_level == 4 and _story_l4_reveal_left > 0.0:
		_story_l4_reveal_left = maxf(0.0, _story_l4_reveal_left - delta)
		if _story_l4_reveal_left <= 0.0:
			_apply_board_colors()

	# Smoothly decay boss animation impulses & trailing ghost HP bar
	story_boss_ghost_hp = move_toward(story_boss_ghost_hp, float(story_boss_hp), delta * 12.0)
	_boss_hit_shake = maxf(0.0, _boss_hit_shake - delta * 4.5)
	_boss_taunt_anim = maxf(0.0, _boss_taunt_anim - delta * 2.5)
	_boss_throw_anim = maxf(0.0, _boss_throw_anim - delta * 3.4)

	for d: String in ["up", "down", "left", "right"]:
		_boss_part_flash[d] = maxf(0.0, float(_boss_part_flash.get(d, 0.0)) - delta * 5.0)
		_boss_part_recoil[d] = maxf(0.0, float(_boss_part_recoil.get(d, 0.0)) - delta * 4.2)

	# Update active laser beams
	var idx: int = _boss_laser_beams.size() - 1
	while idx >= 0:
		var beam: Dictionary = _boss_laser_beams[idx]
		var next_age: float = float(beam.get("age", 0.0)) + delta
		var dur: float = float(beam.get("duration", 0.28))
		if next_age >= dur:
			_boss_laser_beams.remove_at(idx)
		else:
			beam["age"] = next_age
			_boss_laser_beams[idx] = beam
		idx -= 1

	# Update active explosion shockwave rings
	var r_idx: int = _boss_explosion_rings.size() - 1
	while r_idx >= 0:
		var ring: Dictionary = _boss_explosion_rings[r_idx]
		var next_age: float = float(ring.get("age", 0.0)) + delta
		var dur: float = float(ring.get("duration", 0.45))
		if next_age >= dur:
			_boss_explosion_rings.remove_at(r_idx)
		else:
			ring["age"] = next_age
			_boss_explosion_rings[r_idx] = ring
		r_idx -= 1

	# Update active explosion shrapnel shards
	var s_idx: int = _boss_explosion_shrapnel.size() - 1
	while s_idx >= 0:
		var shard: Dictionary = _boss_explosion_shrapnel[s_idx]
		var next_age: float = float(shard.get("age", 0.0)) + delta
		var dur: float = float(shard.get("duration", 0.7))
		if next_age >= dur:
			_boss_explosion_shrapnel.remove_at(s_idx)
		else:
			shard["age"] = next_age
			var vel: Vector2 = shard.get("vel", Vector2.ZERO)
			vel.y += 280.0 * delta
			shard["vel"] = vel
			shard["pos"] = (shard.get("pos", Vector2.ZERO) as Vector2) + vel * delta
			shard["rot"] = float(shard.get("rot", 0.0)) + float(shard.get("rot_speed", 0.0)) * delta
			_boss_explosion_shrapnel[s_idx] = shard
		s_idx -= 1

	if _story_boss_canvas != null and is_instance_valid(_story_boss_canvas):
		_story_boss_canvas.queue_redraw()


func _draw_story_boss_arena() -> void:
	if _story_boss_canvas == null or not is_instance_valid(_story_boss_canvas):
		return

	var c_size: Vector2 = _story_boss_canvas.size
	if c_size.x <= 1.0 or c_size.y <= 1.0:
		c_size = Vector2(540.0, 344.0)
	var canvas_offset := Vector2(0.0, _story_boss_canvas.offset_top)
	var all_parts_dead := _are_all_boss_parts_destroyed()

	# ---------------------------------------------------------
	# 1. BOSS MAIN HP BAR (Shielded until all 4 Body Parts are destroyed!)
	# ---------------------------------------------------------
	var bar_w: float = 420.0
	var bar_h: float = 20.0
	var bar_x: float = (c_size.x - bar_w) * 0.5
	var bar_y: float = 4.0
	var bar_rect := Rect2(bar_x, bar_y, bar_w, bar_h)

	# Outer neon frame glow
	var frame_col := Color(1.0, 0.25, 0.40, 0.95) if all_parts_dead else Color(0.30, 0.92, 1.0, 0.92)
	_story_boss_canvas.draw_rect(Rect2(bar_x - 3.0, bar_y - 3.0, bar_w + 6.0, bar_h + 6.0), Color(frame_col.r, frame_col.g, frame_col.b, 0.28), false, 4.0)
	_story_boss_canvas.draw_rect(bar_rect, Color(0.06, 0.04, 0.14, 0.92), true)

	# Ghost trailing damage bar
	var ghost_ratio: float = clampf(story_boss_ghost_hp / float(maxi(1, story_boss_max_hp)), 0.0, 1.0)
	if ghost_ratio > 0.0:
		_story_boss_canvas.draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, (bar_w - 4.0) * ghost_ratio, bar_h - 4.0), Color(1.0, 0.92, 0.45, 0.85), true)

	# Active Boss HP fill bar
	var hp_ratio: float = clampf(float(story_boss_hp) / float(maxi(1, story_boss_max_hp)), 0.0, 1.0)
	if hp_ratio > 0.0:
		var hp_col := Color(1.0, 0.22, 0.35) if all_parts_dead else Color(0.22, 0.58, 0.88)
		var fill_w: float = (bar_w - 4.0) * hp_ratio
		_story_boss_canvas.draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, fill_w, bar_h - 4.0), hp_col, true)
		# Glossy top highlight strip
		_story_boss_canvas.draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, fill_w, (bar_h - 4.0) * 0.38), Color(1.0, 1.0, 1.0, 0.28), true)

	# Translucent cyan shield stripes across Main HP Bar while any body part is still alive
	if not all_parts_dead:
		var stripe_step: float = 28.0
		var x_cur: float = bar_x + 8.0
		while x_cur < bar_x + bar_w - 8.0:
			_story_boss_canvas.draw_line(
				Vector2(x_cur, bar_y + bar_h - 2.0),
				Vector2(minf(bar_x + bar_w - 2.0, x_cur + 12.0), bar_y + 2.0),
				Color(0.55, 0.98, 1.0, 0.32),
				2.0
			)
			x_cur += stripe_step

	_story_boss_canvas.draw_rect(bar_rect, frame_col, false, 2.2)

	# ---------------------------------------------------------
	# 2. COLOR-MATCHED BODY PART HP BARS UNDER MAIN HP BAR
	# ---------------------------------------------------------
	var part_order := ["left", "up", "down", "right"]
	var pip_w: float = 92.0
	var pip_gap: float = 14.0
	var total_pips_w: float = pip_w * 4.0 + pip_gap * 3.0
	var pip_start_x: float = (c_size.x - total_pips_w) * 0.5
	var pip_y: float = bar_y + bar_h + 7.0
	for i in range(4):
		var p_dir: String = part_order[i]
		var p_col: Color = direction_colors.get(p_dir, Color.WHITE)
		var px: float = pip_start_x + float(i) * (pip_w + pip_gap)
		var p_hp: int = int(story_part_hp.get(p_dir, 0))
		var p_ratio: float = clampf(float(p_hp) / float(maxi(1, story_part_max_hp)), 0.0, 1.0)
		var pip_rect := Rect2(px, pip_y, pip_w, 9.0)
		_story_boss_canvas.draw_rect(pip_rect, Color(0.06, 0.04, 0.14, 0.90), true)
		if p_ratio > 0.0:
			_story_boss_canvas.draw_rect(Rect2(px + 1.0, pip_y + 1.0, (pip_w - 2.0) * p_ratio, 7.0), p_col, true)
			_story_boss_canvas.draw_rect(pip_rect, Color(p_col.r, p_col.g, p_col.b, 0.92), false, 1.6)
		else:
			# Destroyed part indicator
			_story_boss_canvas.draw_rect(pip_rect, Color(0.35, 0.25, 0.35, 0.55), false, 1.2)
			_story_boss_canvas.draw_line(Vector2(px + 4.0, pip_y + 2.0), Vector2(px + pip_w - 4.0, pip_y + 7.0), Color(1.0, 0.25, 0.3, 0.75), 1.6)
			_story_boss_canvas.draw_line(Vector2(px + pip_w - 4.0, pip_y + 2.0), Vector2(px + 4.0, pip_y + 7.0), Color(1.0, 0.25, 0.3, 0.75), 1.6)

	# ---------------------------------------------------------
	# 3. ARTICULATED 4-PART BOSS ("CHROMA TITAN", "CYBER HYDRA", or "VOID SERAPH")
	# ---------------------------------------------------------
	var boss_center := Vector2(c_size.x * 0.5, c_size.y * 0.60)
	if story_level == 4:
		_draw_phantom_maestro_figure(_story_boss_canvas, boss_center, 1.0, false)
	elif story_level == 3:
		_draw_void_seraph_figure(_story_boss_canvas, boss_center, 1.0, false)
	elif story_level == 2:
		_draw_cyber_hydra_figure(_story_boss_canvas, boss_center, 1.0, false)
	else:
		_draw_chroma_titan_figure(_story_boss_canvas, boss_center, 1.0, false)

	# ---------------------------------------------------------
	# 4. BOSS HAZARD PROJECTIONS (Lv 1: Bomb Arcs | Lv 2: Shield Tethers | Lv 3: Void Rift Streams)
	# ---------------------------------------------------------
	if story_level == 4:
		# Conductor's baton launches a glowing music note toward the NEXT note of the melody (Phase 1 only —
		# Phase 2 never reveals the True Mask through projections!)
		if not all_parts_dead and _boss_throw_anim > 0.01 and _story_l4_seq_index < _story_l4_sequence.size():
			var n_dir: String = _story_l4_sequence[_story_l4_seq_index]
			var n_start: Vector2 = boss_center + Vector2(46.0, -40.0)
			var n_end: Vector2 = _get_board_center(n_dir) - canvas_offset
			var n_t: float = 1.0 - _boss_throw_anim
			var n_pt: Vector2 = n_start.lerp(n_end, n_t) + Vector2(0.0, -sin(n_t * PI) * 46.0)
			_story_boss_canvas.draw_circle(n_pt, 13.0, Color(1.0, 0.78, 0.30, 0.40))
			_draw_story_music_note(_story_boss_canvas, n_pt, 1.0, Color(1.0, 0.92, 0.55, 0.98))
	elif story_level == 3:
		var start_p: Vector2 = boss_center + Vector2(0.0, -4.0)
		var pulse_a: float = 0.28 + 0.15 * sin(_boss_anim_time * 10.5)
		for v_dir: String in story_bomb_dirs:
			if v_dir == "":
				continue
			var end_p: Vector2 = _get_board_center(v_dir) - canvas_offset
			_story_boss_canvas.draw_line(start_p, end_p, Color(0.85, 0.25, 1.0, pulse_a), 5.5, true)
			_story_boss_canvas.draw_line(start_p, end_p, Color(1.0, 0.85, 0.35, pulse_a * 1.25), 1.8, true)
			if _boss_throw_anim > 0.01:
				var proj_t: float = 1.0 - _boss_throw_anim
				var pulse_pt: Vector2 = start_p.lerp(end_p, proj_t)
				_story_boss_canvas.draw_circle(pulse_pt, 12.5, Color(0.92, 0.32, 1.0, 0.58))
				_story_boss_canvas.draw_arc(pulse_pt, 9.0, _boss_anim_time * 6.0, _boss_anim_time * 6.0 + PI * 1.5, 14, Color(1.0, 0.92, 0.38, 0.96), 2.5, true)
	elif story_level == 2:
		# Persistent emerald-cyan shield projection beams from Cyber Hydra to shielded squares
		var start_p: Vector2 = boss_center + Vector2(0.0, 6.0)
		var pulse_a: float = 0.26 + 0.14 * sin(_boss_anim_time * 9.0)
		for s_dir: String in story_bomb_dirs:
			if s_dir == "":
				continue
			var end_p: Vector2 = _get_board_center(s_dir) - canvas_offset
			_story_boss_canvas.draw_line(start_p, end_p, Color(0.15, 1.0, 0.72, pulse_a), 5.0, true)
			_story_boss_canvas.draw_line(start_p, end_p, Color(0.75, 1.0, 0.95, pulse_a * 1.4), 1.8, true)
			if _boss_throw_anim > 0.01:
				var proj_t: float = 1.0 - _boss_throw_anim
				var pulse_pt: Vector2 = start_p.lerp(end_p, proj_t)
				_story_boss_canvas.draw_circle(pulse_pt, 12.0, Color(0.20, 1.0, 0.78, 0.55))
				_story_boss_canvas.draw_arc(pulse_pt, 9.0, 0.0, TAU, 6, Color(0.85, 1.0, 0.98, 0.95), 2.4, true)
	elif _boss_throw_anim > 0.01 and not _boss_throw_target_dirs.is_empty():
		var throw_t: float = 1.0 - _boss_throw_anim # 0 -> 1
		var start_p: Vector2 = boss_center + Vector2(0.0, 10.0)
		for t_dir: String in _boss_throw_target_dirs:
			if t_dir == "":
				continue
			var end_p: Vector2 = _get_board_center(t_dir) - canvas_offset
			var arc_p: Vector2 = start_p.lerp(end_p, throw_t) + Vector2(0.0, -sin(throw_t * PI) * 68.0)
			_story_boss_canvas.draw_circle(arc_p, 14.0, Color(1.6, 0.2, 0.25, 0.45))
			_story_boss_canvas.draw_circle(arc_p, 8.5, Color(0.15, 0.12, 0.20, 0.98))
			_story_boss_canvas.draw_arc(arc_p, 8.5, 0.0, TAU, 20, Color(1.6, 0.25, 0.25, 0.95), 2.2, true)
			_story_boss_canvas.draw_circle(arc_p + Vector2(0, -10.0), 4.5, Color(1.0, 0.92, 0.25, 0.98))

	# ---------------------------------------------------------
	# 5. LASER BEAMS (Board Square -> Matching Boss Body Part)
	# ---------------------------------------------------------
	for beam: Dictionary in _boss_laser_beams:
		var age: float = float(beam.get("age", 0.0))
		var dur: float = maxf(0.01, float(beam.get("duration", 0.28)))
		var life_t: float = clampf(1.0 - (age / dur), 0.0, 1.0)
		var from_pt: Vector2 = (beam.get("from", Vector2.ZERO) as Vector2) - canvas_offset
		var to_pt: Vector2 = (beam.get("to", Vector2.ZERO) as Vector2) - canvas_offset
		var b_col: Color = beam.get("color", Color.WHITE)

		# Outer neon bloom beam + inner white-hot core
		_story_boss_canvas.draw_line(from_pt, to_pt, Color(b_col.r, b_col.g, b_col.b, 0.38 * life_t), 22.0 * life_t, true)
		_story_boss_canvas.draw_line(from_pt, to_pt, Color(b_col.r, b_col.g, b_col.b, 0.88 * life_t), 10.0 * life_t, true)
		_story_boss_canvas.draw_line(from_pt, to_pt, Color(1.0, 1.0, 1.0, 0.98 * life_t), 4.0 * life_t, true)

		# Impact shockwave ring at the Boss body part
		var ring_r: float = lerpf(8.0, 38.0, 1.0 - life_t)
		_story_boss_canvas.draw_arc(to_pt, ring_r, 0.0, TAU, 28, Color(b_col.r, b_col.g, b_col.b, 0.85 * life_t), 3.5 * life_t, true)
		_story_boss_canvas.draw_circle(to_pt, 10.0 * life_t, Color(1.0, 1.0, 1.0, 0.95 * life_t))

	# ---------------------------------------------------------
	# 6. BOSS & BODY PART EXPLOSION RINGS AND SHRAPNEL DEBRIS
	# ---------------------------------------------------------
	for ring: Dictionary in _boss_explosion_rings:
		var r_age: float = float(ring.get("age", 0.0))
		var r_dur: float = maxf(0.01, float(ring.get("duration", 0.45)))
		var prog: float = clampf(r_age / r_dur, 0.0, 1.0)
		var fade: float = 1.0 - prog
		var r_pos: Vector2 = ring.get("pos", boss_center)
		var r_col: Color = ring.get("color", Color(1.0, 0.85, 0.25))
		var max_r: float = float(ring.get("max_radius", 90.0))
		var cur_r: float = lerpf(10.0, max_r, prog)
		_story_boss_canvas.draw_circle(r_pos, cur_r * 0.55 * fade, Color(1.5, 1.2, 0.6, 0.55 * fade))
		_story_boss_canvas.draw_arc(r_pos, cur_r, 0.0, TAU, 36, Color(r_col.r, r_col.g, r_col.b, 0.92 * fade), maxf(2.0, 7.0 * fade), true)
		_story_boss_canvas.draw_arc(r_pos, cur_r * 0.72, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.85 * fade), maxf(1.5, 3.5 * fade), true)

	for shard: Dictionary in _boss_explosion_shrapnel:
		var s_age: float = float(shard.get("age", 0.0))
		var s_dur: float = maxf(0.01, float(shard.get("duration", 0.7)))
		var fade: float = clampf(1.0 - (s_age / s_dur), 0.0, 1.0)
		var s_pos: Vector2 = shard.get("pos", boss_center)
		var s_rot: float = float(shard.get("rot", 0.0))
		var s_size: float = float(shard.get("size", 8.0)) * (0.4 + 0.6 * fade)
		var s_col: Color = shard.get("color", Color.WHITE)
		var p1 := s_pos + Vector2(cos(s_rot), sin(s_rot)) * s_size
		var p2 := s_pos + Vector2(cos(s_rot + 2.1), sin(s_rot + 2.1)) * (s_size * 0.85)
		var p3 := s_pos + Vector2(cos(s_rot + 4.2), sin(s_rot + 4.2)) * (s_size * 0.75)
		_story_boss_canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(s_col.r, s_col.g, s_col.b, fade))


func _draw_story_level1_preview() -> void:
	if _story_level1_preview_ctrl == null or not is_instance_valid(_story_level1_preview_ctrl):
		return
	var s: Vector2 = _story_level1_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	# Subtle dark cyber pedestal backdrop
	_story_level1_preview_ctrl.draw_circle(c, 48.0, Color(0.05, 0.03, 0.12, 0.85))
	_story_level1_preview_ctrl.draw_arc(c, 48.0, 0.0, TAU, 36, Color(0.35, 0.90, 1.0, 0.55), 2.0, true)
	_draw_chroma_titan_figure(_story_level1_preview_ctrl, c, 0.36, true)


func _draw_chroma_titan_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	# When the Boss is obliterated at the end of the death sequence, fade/vaporize the chassis completely!
	if not is_preview and _boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and _boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (_boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = _boss_anim_time
	var rage_mult: float = 1.65 if (story_boss_enraged and not is_preview) else 1.0
	var hover_y: float = sin(t * 3.2 * rage_mult) * 7.5 * scale_f
	var breathe: float = 1.0 + sin(t * 6.4 * rage_mult) * 0.035

	var shake_vec := Vector2.ZERO
	if not is_preview and (_boss_hit_shake > 0.01 or _boss_death_progress > 0.01):
		var sh_amp: float = (_boss_hit_shake * 9.0 + _boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(_boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	# Fetch the 4 live board colors for the 4 Boss body parts!
	var col_up: Color = direction_colors.get("up", Color(1.0, 0.25, 0.45))
	var col_down: Color = direction_colors.get("down", Color(1.0, 0.85, 0.20))
	var col_left: Color = direction_colors.get("left", Color(0.20, 0.95, 0.55))
	var col_right: Color = direction_colors.get("right", Color(0.25, 0.65, 1.0))

	var up_dead: bool = (not is_preview and int(story_part_hp.get("up", 1)) <= 0)
	var down_dead: bool = (not is_preview and int(story_part_hp.get("down", 1)) <= 0)
	var left_dead: bool = (not is_preview and int(story_part_hp.get("left", 1)) <= 0)
	var right_dead: bool = (not is_preview and int(story_part_hp.get("right", 1)) <= 0)

	if up_dead:
		col_up = col_up.darkened(0.68)
	if down_dead:
		col_down = col_down.darkened(0.68)
	if left_dead:
		col_left = col_left.darkened(0.68)
	if right_dead:
		col_right = col_right.darkened(0.68)

	if not is_preview:
		var death_glow: float = clampf(_boss_death_progress * 1.4, 0.0, 1.0)
		col_up = col_up.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("up", 0.0)), 0.0, 1.0)))
		col_down = col_down.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("down", 0.0)), 0.0, 1.0)))
		col_left = col_left.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("left", 0.0)), 0.0, 1.0)))
		col_right = col_right.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("right", 0.0)), 0.0, 1.0)))

	# During death sequence, parts fly violently apart!
	var death_split: float = (_boss_death_progress * _boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var dark_armor := Color(0.07, 0.05, 0.16, 0.96)

	# ---------------------------------------------------------
	# A. BACKGROUND HOLOGRAPHIC FORCEFIELD HEX-RING
	# ---------------------------------------------------------
	var aura_col := Color(1.0, 0.22, 0.38, 0.26) if (story_boss_enraged and not is_preview) else Color(0.30, 0.88, 1.0, 0.20)
	var aura_r: float = (94.0 + sin(t * 4.0) * 5.0) * scale_f
	var hex_aura := PackedVector2Array()
	for i in range(7):
		var ang: float = t * 0.55 + float(i) * (TAU / 6.0)
		hex_aura.append(root_pos + Vector2(cos(ang), sin(ang)) * aura_r)
	canvas.draw_polyline(hex_aura, aura_col, maxf(1.5, 3.0 * scale_f), true)

	# Energy tether conduits connecting Torso to Head, Left Arm, and Right Arm
	var rec_up: float = (float(_boss_part_recoil.get("up", 0.0)) * 18.0 * scale_f) if not is_preview else 0.0
	var rec_down: float = (float(_boss_part_recoil.get("down", 0.0)) * 14.0 * scale_f) if not is_preview else 0.0
	var rec_left: float = (float(_boss_part_recoil.get("left", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0
	var rec_right: float = (float(_boss_part_recoil.get("right", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0

	var torso_c: Vector2 = root_pos + Vector2(0.0, 12.0 * scale_f + rec_down + death_split * 0.5)
	var head_c: Vector2 = root_pos + Vector2(0.0, -68.0 * scale_f - rec_up - death_split + sin(t * 4.2) * 3.0 * scale_f)
	var throw_lunge_l: float = sin(_boss_throw_anim * PI) * 18.0 * scale_f if (not is_preview and (_boss_throw_target_dir == "left" or _boss_throw_target_dir == "up")) else 0.0
	var throw_lunge_r: float = sin(_boss_throw_anim * PI) * 18.0 * scale_f if (not is_preview and (_boss_throw_target_dir == "right" or _boss_throw_target_dir == "down")) else 0.0
	var left_c: Vector2 = root_pos + Vector2(-112.0 * scale_f - rec_left - death_split, -4.0 * scale_f + cos(t * 3.6 + 0.8) * 6.5 * scale_f + throw_lunge_l)
	var right_c: Vector2 = root_pos + Vector2(112.0 * scale_f + rec_right + death_split, -4.0 * scale_f + cos(t * 3.6 + 2.4) * 6.5 * scale_f + throw_lunge_r)

	# Plasma shoulder beams
	if _boss_death_progress < 0.25:
		canvas.draw_line(torso_c + Vector2(-42.0, -18.0) * scale_f, left_c + Vector2(26.0, -6.0) * scale_f, Color(col_left.r, col_left.g, col_left.b, 0.55), maxf(2.0, 5.0 * scale_f), true)
		canvas.draw_line(torso_c + Vector2(42.0, -18.0) * scale_f, right_c + Vector2(-26.0, -6.0) * scale_f, Color(col_right.r, col_right.g, col_right.b, 0.55), maxf(2.0, 5.0 * scale_f), true)
		canvas.draw_line(torso_c + Vector2(0.0, -36.0) * scale_f, head_c + Vector2(0.0, 26.0) * scale_f, Color(col_up.r, col_up.g, col_up.b, 0.60), maxf(2.0, 5.5 * scale_f), true)

	# ---------------------------------------------------------
	# B. TORSO / HEX REACTOR CORE ("down" color + Diamond emblem)
	# ---------------------------------------------------------
	var tw_s: float = scale_f * breathe
	var torso_pts := PackedVector2Array([
		torso_c + Vector2(-46.0, -38.0) * tw_s,
		torso_c + Vector2(46.0, -38.0) * tw_s,
		torso_c + Vector2(62.0, -4.0) * tw_s,
		torso_c + Vector2(36.0, 48.0) * tw_s,
		torso_c + Vector2(-36.0, 48.0) * tw_s,
		torso_c + Vector2(-62.0, -4.0) * tw_s,
	])
	var torso_closed := torso_pts.duplicate()
	torso_closed.append(torso_pts[0])
	canvas.draw_colored_polygon(torso_pts, dark_armor)
	canvas.draw_polyline(torso_closed, Color(col_down.r, col_down.g, col_down.b, 0.42), maxf(3.0, 8.5 * scale_f), true)
	canvas.draw_polyline(torso_closed, col_down, maxf(1.8, 3.6 * scale_f), true)

	# Inner armor plates colored with `col_down`
	var inner_torso := PackedVector2Array([
		torso_c + Vector2(-34.0, -28.0) * tw_s,
		torso_c + Vector2(34.0, -28.0) * tw_s,
		torso_c + Vector2(46.0, -2.0) * tw_s,
		torso_c + Vector2(26.0, 36.0) * tw_s,
		torso_c + Vector2(-26.0, 36.0) * tw_s,
		torso_c + Vector2(-46.0, -2.0) * tw_s,
	])
	canvas.draw_colored_polygon(inner_torso, Color(col_down.r, col_down.g, col_down.b, 0.85))

	# Counter-rotating reactor ring & Diamond Core ("down" symbol)
	var core_r: float = 22.0 * tw_s
	canvas.draw_circle(torso_c + Vector2(0, 4.0 * tw_s), core_r, dark_armor)
	canvas.draw_arc(torso_c + Vector2(0, 4.0 * tw_s), core_r, t * 2.5, t * 2.5 + PI * 1.4, 20, Color(1.0, 1.0, 1.0, 0.9), maxf(1.5, 2.8 * scale_f), true)
	var dm_c := torso_c + Vector2(0, 4.0 * tw_s)
	var dm_r: float = 12.5 * tw_s
	var dm_pts := PackedVector2Array([
		dm_c + Vector2(0, -dm_r),
		dm_c + Vector2(dm_r, 0),
		dm_c + Vector2(0, dm_r),
		dm_c + Vector2(-dm_r, 0),
	])
	var core_gem_col: Color = Color(1.5, 0.30, 0.40) if (story_boss_enraged and not is_preview) else col_down.lightened(0.25)
	canvas.draw_colored_polygon(dm_pts, core_gem_col)
	var dm_closed := dm_pts.duplicate()
	dm_closed.append(dm_pts[0])
	canvas.draw_polyline(dm_closed, Color(1.0, 1.0, 1.0, 0.95), maxf(1.2, 2.2 * scale_f), true)

	# ---------------------------------------------------------
	# C. CROWN HELM & LASER VISOR ("up" color + Triangle emblem)
	# ---------------------------------------------------------
	var l_horn := PackedVector2Array([
		head_c + Vector2(-34.0, -8.0) * scale_f,
		head_c + Vector2(-58.0, -42.0) * scale_f,
		head_c + Vector2(-22.0, -26.0) * scale_f,
	])
	var r_horn := PackedVector2Array([
		head_c + Vector2(34.0, -8.0) * scale_f,
		head_c + Vector2(58.0, -42.0) * scale_f,
		head_c + Vector2(22.0, -26.0) * scale_f,
	])
	canvas.draw_colored_polygon(l_horn, col_up)
	canvas.draw_colored_polygon(r_horn, col_up)

	var head_pts := PackedVector2Array([
		head_c + Vector2(0.0, -38.0) * scale_f,
		head_c + Vector2(40.0, -20.0) * scale_f,
		head_c + Vector2(34.0, 22.0) * scale_f,
		head_c + Vector2(0.0, 30.0) * scale_f,
		head_c + Vector2(-34.0, 22.0) * scale_f,
		head_c + Vector2(-40.0, -20.0) * scale_f,
	])
	var head_closed := head_pts.duplicate()
	head_closed.append(head_pts[0])
	canvas.draw_colored_polygon(head_pts, col_up)
	canvas.draw_polyline(head_closed, Color(col_up.r, col_up.g, col_up.b, 0.45), maxf(3.0, 8.0 * scale_f), true)
	canvas.draw_polyline(head_closed, Color(1.0, 1.0, 1.0, 0.35 if up_dead else 0.92), maxf(1.5, 3.0 * scale_f), true)

	var visor_pts := PackedVector2Array([
		head_c + Vector2(-28.0, -4.0) * scale_f,
		head_c + Vector2(28.0, -4.0) * scale_f,
		head_c + Vector2(22.0, 14.0) * scale_f,
		head_c + Vector2(-22.0, 14.0) * scale_f,
	])
	canvas.draw_colored_polygon(visor_pts, dark_armor)

	var eye_col := Color(1.0, 0.2, 0.3) if (story_boss_enraged and not is_preview) else Color(1.0, 0.96, 0.35)
	var eye_slant: float = 4.5 if (story_boss_enraged or _boss_hit_shake > 0.1) else 2.0
	canvas.draw_line(head_c + Vector2(-19.0, 2.0) * scale_f, head_c + Vector2(-6.0, 2.0 + eye_slant) * scale_f, eye_col, maxf(2.0, 4.2 * scale_f), true)
	canvas.draw_line(head_c + Vector2(19.0, 2.0) * scale_f, head_c + Vector2(6.0, 2.0 + eye_slant) * scale_f, eye_col, maxf(2.0, 4.2 * scale_f), true)

	var tri_c := head_c + Vector2(0.0, -17.0 * scale_f)
	var tri_pts := PackedVector2Array([
		tri_c + Vector2(0.0, -10.0) * scale_f,
		tri_c + Vector2(10.0, 8.0) * scale_f,
		tri_c + Vector2(-10.0, 8.0) * scale_f,
	])
	canvas.draw_colored_polygon(tri_pts, Color(1.0, 1.0, 1.0, 0.35 if up_dead else 0.95))
	var tri_closed := tri_pts.duplicate()
	tri_closed.append(tri_pts[0])
	canvas.draw_polyline(tri_closed, dark_armor, maxf(1.2, 2.0 * scale_f), true)

	# ---------------------------------------------------------
	# D. LEFT PLASMA CLAW ARM ("left" color + Square emblem)
	# ---------------------------------------------------------
	var l_arm_pts := PackedVector2Array([
		left_c + Vector2(-28.0, -30.0) * scale_f,
		left_c + Vector2(24.0, -24.0) * scale_f,
		left_c + Vector2(28.0, 18.0) * scale_f,
		left_c + Vector2(-24.0, 24.0) * scale_f,
	])
	var l_arm_closed := l_arm_pts.duplicate()
	l_arm_closed.append(l_arm_pts[0])
	canvas.draw_colored_polygon(l_arm_pts, col_left)
	canvas.draw_polyline(l_arm_closed, Color(col_left.r, col_left.g, col_left.b, 0.45), maxf(3.0, 7.5 * scale_f), true)
	canvas.draw_polyline(l_arm_closed, Color(1.0, 1.0, 1.0, 0.35 if left_dead else 0.9), maxf(1.5, 2.8 * scale_f), true)

	var pinch: float = sin(t * 5.5) * 4.5 * scale_f
	var l_claw1 := PackedVector2Array([
		left_c + Vector2(-20.0, 22.0) * scale_f,
		left_c + Vector2(-10.0, 44.0) * scale_f + Vector2(pinch, 0.0),
		left_c + Vector2(-4.0, 22.0) * scale_f,
	])
	var l_claw2 := PackedVector2Array([
		left_c + Vector2(4.0, 22.0) * scale_f,
		left_c + Vector2(12.0, 44.0) * scale_f - Vector2(pinch, 0.0),
		left_c + Vector2(20.0, 22.0) * scale_f,
	])
	canvas.draw_colored_polygon(l_claw1, Color(1.0, 1.0, 1.0, 0.35 if left_dead else 0.92))
	canvas.draw_colored_polygon(l_claw2, Color(1.0, 1.0, 1.0, 0.35 if left_dead else 0.92))

	var sq_r: float = 10.0 * scale_f
	var sq_rect := Rect2(left_c.x - sq_r, left_c.y - sq_r - 2.0 * scale_f, sq_r * 2.0, sq_r * 2.0)
	canvas.draw_rect(sq_rect, dark_armor, true)
	canvas.draw_rect(Rect2(sq_rect.position + Vector2(2.0, 2.0) * scale_f, sq_rect.size - Vector2(4.0, 4.0) * scale_f), Color(1.0, 1.0, 1.0, 0.35 if left_dead else 0.95), true)

	# ---------------------------------------------------------
	# E. RIGHT ION CANNON ARM ("right" color + Circle emblem)
	# ---------------------------------------------------------
	var r_arm_pts := PackedVector2Array([
		right_c + Vector2(-24.0, -24.0) * scale_f,
		right_c + Vector2(28.0, -30.0) * scale_f,
		right_c + Vector2(24.0, 24.0) * scale_f,
		right_c + Vector2(-28.0, 18.0) * scale_f,
	])
	var r_arm_closed := r_arm_pts.duplicate()
	r_arm_closed.append(r_arm_pts[0])
	canvas.draw_colored_polygon(r_arm_pts, col_right)
	canvas.draw_polyline(r_arm_closed, Color(col_right.r, col_right.g, col_right.b, 0.45), maxf(3.0, 7.5 * scale_f), true)
	canvas.draw_polyline(r_arm_closed, Color(1.0, 1.0, 1.0, 0.35 if right_dead else 0.9), maxf(1.5, 2.8 * scale_f), true)

	var muzzle_rect := Rect2(right_c.x - 14.0 * scale_f, right_c.y + 22.0 * scale_f, 28.0 * scale_f, 16.0 * scale_f)
	canvas.draw_rect(muzzle_rect, dark_armor, true)
	canvas.draw_rect(muzzle_rect, col_right.lightened(0.3), false, maxf(1.2, 2.2 * scale_f))
	var orb_r: float = (6.0 + sin(t * 8.0) * 2.0) * scale_f
	canvas.draw_circle(right_c + Vector2(0.0, 40.0 * scale_f), orb_r, Color(1.0, 1.0, 1.0, 0.35 if right_dead else 0.95))

	var cir_r: float = 11.0 * scale_f
	canvas.draw_circle(right_c + Vector2(0.0, -2.0 * scale_f), cir_r + 2.0 * scale_f, dark_armor)
	canvas.draw_circle(right_c + Vector2(0.0, -2.0 * scale_f), cir_r, Color(1.0, 1.0, 1.0, 0.35 if right_dead else 0.95))


func _draw_story_white_center_emblem(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var pulse: float = 1.0 + sin(_boss_anim_time * 7.0) * 0.08
	var all_parts_dead := _are_all_boss_parts_destroyed()

	# Center prismatic star core
	var star_r: float = 15.0 * sf * pulse
	var inner_r: float = 6.0 * sf * pulse
	var star_pts := PackedVector2Array([
		c + Vector2(0, -star_r),
		c + Vector2(inner_r, -inner_r),
		c + Vector2(star_r, 0),
		c + Vector2(inner_r, inner_r),
		c + Vector2(0, star_r),
		c + Vector2(-inner_r, inner_r),
		c + Vector2(-star_r, 0),
		c + Vector2(-inner_r, -inner_r),
	])
	var dark_outline := Color(0.08, 0.06, 0.18, 0.92)
	var star_closed := star_pts.duplicate()
	star_closed.append(star_pts[0])
	panel.draw_colored_polygon(star_pts, Color(0.95, 0.25, 0.38, 0.95) if all_parts_dead else Color(0.15, 0.22, 0.38, 0.95))
	panel.draw_polyline(star_closed, dark_outline, 2.2 * sf, true)

	# 4 Outward Directional Chevrons colored with the 4 live board colors!
	# In Phase 1, chevrons for already-destroyed parts are dimmed so the player knows which parts still need to be destroyed!
	var dist: float = 29.0 * sf
	var chev_dirs := {
		"up":    [Vector2(0, -dist - 6 * sf), Vector2(9 * sf, -dist + 4 * sf), Vector2(-9 * sf, -dist + 4 * sf)],
		"down":  [Vector2(0, dist + 6 * sf),  Vector2(9 * sf, dist - 4 * sf),  Vector2(-9 * sf, dist - 4 * sf)],
		"left":  [Vector2(-dist - 6 * sf, 0), Vector2(-dist + 4 * sf, -9 * sf), Vector2(-dist + 4 * sf, 9 * sf)],
		"right": [Vector2(dist + 6 * sf, 0),  Vector2(dist - 4 * sf, -9 * sf),  Vector2(dist - 4 * sf, 9 * sf)],
	}
	for d_key: String in chev_dirs:
		if d_key in story_bomb_dirs or d_key == story_bomb_dir:
			continue
		if not all_parts_dead and int(story_part_hp.get(d_key, 0)) <= 0:
			continue
		var col: Color = direction_colors.get(d_key, Color(0.2, 0.8, 1.0))
		var arr: Array = chev_dirs[d_key]
		var pts := PackedVector2Array([c + arr[0], c + arr[1], c + arr[2]])
		var closed := pts.duplicate()
		closed.append(pts[0])
		panel.draw_polyline(closed, dark_outline, 3.8 * sf, true)
		panel.draw_colored_polygon(pts, col)


func _draw_story_bomb_icon(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5 + Vector2(0.0, 4.0)
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time

	# 1. Pulsing crimson danger ring around the bomb
	var pulse: float = 1.0 + sin(t * 14.0) * 0.08
	var ring_r: float = 34.0 * sf * pulse
	panel.draw_arc(s * 0.5, ring_r, 0.0, TAU, 32, Color(1.6, 0.18, 0.22, 0.42), 5.5 * sf, true)
	panel.draw_arc(s * 0.5, ring_r, 0.0, TAU, 32, Color(1.0, 0.90, 0.25, 0.92), 2.2 * sf, true)

	# 2. Bomb Fuse Neck & Curved Burning Fuse
	var neck_rect := Rect2(c.x - 6.0 * sf, c.y - 25.0 * sf, 12.0 * sf, 7.0 * sf)
	panel.draw_rect(neck_rect, Color(0.22, 0.24, 0.32, 0.98), true)
	panel.draw_rect(neck_rect, Color(0.9, 0.95, 1.0, 0.85), false, 1.5 * sf)

	var fuse_pts := PackedVector2Array([
		c + Vector2(0.0, -25.0) * sf,
		c + Vector2(6.0, -33.0) * sf,
		c + Vector2(16.0, -31.0) * sf,
	])
	panel.draw_polyline(fuse_pts, Color(0.85, 0.72, 0.45, 0.98), 3.2 * sf, true)

	# Sputtering Burning Fuse Spark at tip
	var spark_pos: Vector2 = fuse_pts[2] + Vector2(sin(t * 28.0), cos(t * 34.0)) * 1.8 * sf
	var spark_r: float = (6.5 + sin(t * 24.0) * 2.5) * sf
	panel.draw_circle(spark_pos, spark_r * 1.4, Color(1.6, 0.45, 0.1, 0.65))
	panel.draw_circle(spark_pos, spark_r, Color(1.5, 0.95, 0.2, 0.98))
	panel.draw_circle(spark_pos, spark_r * 0.5, Color(1.0, 1.0, 1.0, 1.0))

	# 3. Spherical Dark-Iron Bomb Body
	var bomb_r: float = 20.5 * sf
	panel.draw_circle(c, bomb_r + 2.5 * sf, Color(0.04, 0.02, 0.08, 0.95))
	panel.draw_circle(c, bomb_r, Color(0.14, 0.12, 0.22, 0.98))
	panel.draw_arc(c, bomb_r, 0.0, TAU, 32, Color(1.5, 0.25, 0.30, 0.95), 2.5 * sf, true)

	# Specular highlight arc on top-left of bomb sphere
	panel.draw_circle(c + Vector2(-7.0, -7.0) * sf, 4.5 * sf, Color(1.0, 1.0, 1.0, 0.65))

	# Glowing red hazard "X" / Danger Core on the bomb
	var x_r: float = 7.5 * sf
	var x_col := Color(1.6, 0.22, 0.25, 0.98)
	panel.draw_line(c + Vector2(-x_r, -x_r), c + Vector2(x_r, x_r), x_col, 3.2 * sf, true)
	panel.draw_line(c + Vector2(x_r, -x_r), c + Vector2(-x_r, x_r), x_col, 3.2 * sf, true)


func _draw_story_level2_preview() -> void:
	if _story_level2_preview_ctrl == null or not is_instance_valid(_story_level2_preview_ctrl):
		return
	var s: Vector2 = _story_level2_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	_story_level2_preview_ctrl.draw_circle(c, 46.0, Color(0.03, 0.11, 0.09, 0.88))
	_story_level2_preview_ctrl.draw_arc(c, 46.0, 0.0, TAU, 36, Color(0.20, 1.0, 0.68, 0.62), 2.0, true)
	_draw_cyber_hydra_figure(_story_level2_preview_ctrl, c, 0.34, true)
	if settings == null or not settings.is_story_level_cleared(1):
		_draw_story_locked_overlay(_story_level2_preview_ctrl, c)


func _draw_story_level3_preview() -> void:
	if _story_level3_preview_ctrl == null or not is_instance_valid(_story_level3_preview_ctrl):
		return
	var s: Vector2 = _story_level3_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	_story_level3_preview_ctrl.draw_circle(c, 46.0, Color(0.09, 0.03, 0.15, 0.88))
	_story_level3_preview_ctrl.draw_arc(c, 46.0, 0.0, TAU, 36, Color(0.92, 0.42, 1.0, 0.62), 2.0, true)
	_draw_void_seraph_figure(_story_level3_preview_ctrl, c, 0.34, true)
	if settings == null or not settings.is_story_level_cleared(2):
		_draw_story_locked_overlay(_story_level3_preview_ctrl, c)


func _draw_story_locked_overlay(canvas: Control, c: Vector2) -> void:
	canvas.draw_circle(c, 46.0, Color(0.03, 0.02, 0.08, 0.72))
	canvas.draw_arc(c + Vector2(0.0, -7.0), 8.5, PI, TAU, 16, Color(1.0, 0.88, 0.35, 0.95), 3.0, true)
	var body_rect := Rect2(c.x - 12.0, c.y - 6.0, 24.0, 19.0)
	canvas.draw_rect(body_rect, Color(0.14, 0.10, 0.24, 0.98), true)
	canvas.draw_rect(body_rect, Color(1.0, 0.88, 0.35, 0.96), false, 2.2)
	canvas.draw_circle(c + Vector2(0.0, 2.5), 2.8, Color(1.0, 0.88, 0.35, 0.98))


func _draw_cyber_hydra_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	if not is_preview and _boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and _boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (_boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = _boss_anim_time
	var rage_mult: float = 1.65 if (story_boss_enraged and not is_preview) else 1.0
	var hover_y: float = sin(t * 3.5 * rage_mult) * 7.0 * scale_f
	var breathe: float = 1.0 + sin(t * 6.8 * rage_mult) * 0.04

	var shake_vec := Vector2.ZERO
	if not is_preview and (_boss_hit_shake > 0.01 or _boss_death_progress > 0.01):
		var sh_amp: float = (_boss_hit_shake * 9.0 + _boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(_boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	var col_up: Color = direction_colors.get("up", Color(1.0, 0.25, 0.45))
	var col_down: Color = direction_colors.get("down", Color(1.0, 0.85, 0.20))
	var col_left: Color = direction_colors.get("left", Color(0.20, 0.95, 0.55))
	var col_right: Color = direction_colors.get("right", Color(0.25, 0.65, 1.0))

	var up_dead: bool = (not is_preview and int(story_part_hp.get("up", 1)) <= 0)
	var down_dead: bool = (not is_preview and int(story_part_hp.get("down", 1)) <= 0)
	var left_dead: bool = (not is_preview and int(story_part_hp.get("left", 1)) <= 0)
	var right_dead: bool = (not is_preview and int(story_part_hp.get("right", 1)) <= 0)

	if up_dead:
		col_up = col_up.darkened(0.68)
	if down_dead:
		col_down = col_down.darkened(0.68)
	if left_dead:
		col_left = col_left.darkened(0.68)
	if right_dead:
		col_right = col_right.darkened(0.68)

	if not is_preview:
		var death_glow: float = clampf(_boss_death_progress * 1.4, 0.0, 1.0)
		col_up = col_up.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("up", 0.0)), 0.0, 1.0)))
		col_down = col_down.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("down", 0.0)), 0.0, 1.0)))
		col_left = col_left.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("left", 0.0)), 0.0, 1.0)))
		col_right = col_right.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("right", 0.0)), 0.0, 1.0)))

	var death_split: float = (_boss_death_progress * _boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var dark_armor := Color(0.04, 0.11, 0.10, 0.96)

	# Rotating Double Bio-Hex Aura
	var aura_col := Color(1.0, 0.22, 0.45, 0.28) if (story_boss_enraged and not is_preview) else Color(0.18, 1.0, 0.68, 0.24)
	var aura_r: float = (98.0 + sin(t * 4.2) * 6.0) * scale_f
	var oct_aura := PackedVector2Array()
	for i in range(9):
		var ang: float = -t * 0.65 + float(i) * (TAU / 8.0)
		oct_aura.append(root_pos + Vector2(cos(ang), sin(ang)) * aura_r)
	canvas.draw_polyline(oct_aura, aura_col, maxf(1.5, 3.0 * scale_f), true)

	var rec_up: float = (float(_boss_part_recoil.get("up", 0.0)) * 18.0 * scale_f) if not is_preview else 0.0
	var rec_down: float = (float(_boss_part_recoil.get("down", 0.0)) * 16.0 * scale_f) if not is_preview else 0.0
	var rec_left: float = (float(_boss_part_recoil.get("left", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0
	var rec_right: float = (float(_boss_part_recoil.get("right", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0

	# Central Hydra Heart Reactor
	var heart_c: Vector2 = root_pos + Vector2(0.0, -14.0 * scale_f)
	var head_up_c: Vector2 = root_pos + Vector2(sin(t * 3.8) * 9.0 * scale_f, -76.0 * scale_f - rec_up - death_split)
	var head_down_c: Vector2 = root_pos + Vector2(cos(t * 4.1) * 7.0 * scale_f, 36.0 * scale_f + rec_down + death_split)
	var head_left_c: Vector2 = root_pos + Vector2(-116.0 * scale_f - rec_left - death_split, -6.0 * scale_f + sin(t * 4.4 + 1.1) * 9.0 * scale_f)
	var head_right_c: Vector2 = root_pos + Vector2(116.0 * scale_f + rec_right + death_split, -6.0 * scale_f + sin(t * 4.4 + 2.7) * 9.0 * scale_f)

	# Slithering segmented cyber-serpent necks connecting Hydra Heart to all 4 Fang Heads
	var neck_targets := [
		{"pos": head_up_c, "col": col_up, "dead": up_dead, "bend": Vector2(sin(t * 5.0) * 16.0, -38.0) * scale_f},
		{"pos": head_down_c, "col": col_down, "dead": down_dead, "bend": Vector2(cos(t * 5.0) * 14.0, 14.0) * scale_f},
		{"pos": head_left_c, "col": col_left, "dead": left_dead, "bend": Vector2(-58.0, -24.0 + sin(t * 5.2) * 14.0) * scale_f},
		{"pos": head_right_c, "col": col_right, "dead": right_dead, "bend": Vector2(58.0, -24.0 + cos(t * 5.2) * 14.0) * scale_f},
	]
	if _boss_death_progress < 0.30:
		for nk: Dictionary in neck_targets:
			var p0: Vector2 = heart_c
			var p2: Vector2 = nk["pos"]
			var p1: Vector2 = heart_c + (nk["bend"] as Vector2)
			var n_col: Color = nk["col"]
			var is_d: bool = nk["dead"]
			var pts := PackedVector2Array()
			for s_i in range(7):
				var u: float = float(s_i) / 6.0
				var q0: Vector2 = p0.lerp(p1, u)
				var q1: Vector2 = p1.lerp(p2, u)
				var spine_pt: Vector2 = q0.lerp(q1, u)
				pts.append(spine_pt)
			canvas.draw_polyline(pts, Color(n_col.r, n_col.g, n_col.b, 0.32 if is_d else 0.72), maxf(2.5, 9.0 * scale_f), true)
			canvas.draw_polyline(pts, dark_armor, maxf(1.5, 4.5 * scale_f), true)
			for s_i in range(1, 6):
				canvas.draw_circle(pts[s_i], 4.5 * scale_f, Color(n_col.r, n_col.g, n_col.b, 0.35 if is_d else 0.92))

	# Central Hydra Heart Reactor Core
	var hr_s: float = scale_f * breathe
	var heart_oct := PackedVector2Array()
	for i in range(8):
		var a: float = float(i) * (TAU / 8.0) + PI * 0.125
		heart_oct.append(heart_c + Vector2(cos(a), sin(a)) * (34.0 * hr_s))
	var heart_closed := heart_oct.duplicate()
	heart_closed.append(heart_oct[0])
	canvas.draw_colored_polygon(heart_oct, dark_armor)
	var heart_col := Color(1.0, 0.22, 0.42) if (story_boss_enraged and not is_preview) else Color(0.20, 1.0, 0.68)
	canvas.draw_polyline(heart_closed, heart_col, maxf(1.8, 3.6 * scale_f), true)
	canvas.draw_circle(heart_c, 15.0 * hr_s, Color(heart_col.r, heart_col.g, heart_col.b, 0.88))
	canvas.draw_arc(heart_c, 21.0 * hr_s, -t * 3.2, -t * 3.2 + PI * 1.35, 18, Color(1.0, 1.0, 1.0, 0.92), maxf(1.4, 2.5 * scale_f), true)

	# Helper array to draw all 4 Serpent Fang Heads with their matching board shape emblem
	var heads_data := [
		{"pos": head_up_c, "col": col_up, "dead": up_dead, "shape": "up"},
		{"pos": head_down_c, "col": col_down, "dead": down_dead, "shape": "down"},
		{"pos": head_left_c, "col": col_left, "dead": left_dead, "shape": "left"},
		{"pos": head_right_c, "col": col_right, "dead": right_dead, "shape": "right"},
	]
	var jaw_open: float = (3.5 + sin(t * 7.2) * 2.5) * scale_f
	for hd: Dictionary in heads_data:
		var hc: Vector2 = hd["pos"]
		var hcol: Color = hd["col"]
		var hdead: bool = hd["dead"]
		var hshape: String = hd["shape"]

		# Cobra hood flare fins
		var hood_pts := PackedVector2Array([
			hc + Vector2(0.0, -28.0) * scale_f,
			hc + Vector2(34.0, -10.0) * scale_f,
			hc + Vector2(24.0, 20.0) * scale_f,
			hc + Vector2(0.0, 26.0) * scale_f,
			hc + Vector2(-24.0, 20.0) * scale_f,
			hc + Vector2(-34.0, -10.0) * scale_f,
		])
		var hood_closed := hood_pts.duplicate()
		hood_closed.append(hood_pts[0])
		canvas.draw_colored_polygon(hood_pts, hcol)
		canvas.draw_polyline(hood_closed, Color(1.0, 1.0, 1.0, 0.32 if hdead else 0.90), maxf(1.4, 2.6 * scale_f), true)

		# Inner dark serpent faceplate
		var face_pts := PackedVector2Array([
			hc + Vector2(-20.0, -12.0) * scale_f,
			hc + Vector2(20.0, -12.0) * scale_f,
			hc + Vector2(15.0, 14.0) * scale_f,
			hc + Vector2(-15.0, 14.0) * scale_f,
		])
		canvas.draw_colored_polygon(face_pts, dark_armor)

		# Twin glowing venom fangs at bottom of jaw
		var fang_alpha: float = 0.30 if hdead else 0.96
		var l_fang := PackedVector2Array([
			hc + Vector2(-14.0, 18.0) * scale_f,
			hc + Vector2(-9.0, 32.0) * scale_f + Vector2(0.0, jaw_open),
			hc + Vector2(-5.0, 18.0) * scale_f,
		])
		var r_fang := PackedVector2Array([
			hc + Vector2(5.0, 18.0) * scale_f,
			hc + Vector2(9.0, 32.0) * scale_f + Vector2(0.0, jaw_open),
			hc + Vector2(14.0, 18.0) * scale_f,
		])
		canvas.draw_colored_polygon(l_fang, Color(0.85, 1.0, 0.95, fang_alpha))
		canvas.draw_colored_polygon(r_fang, Color(0.85, 1.0, 0.95, fang_alpha))

		# Slit serpent eyes
		var eye_c := Color(0.25, 1.0, 0.72, fang_alpha) if not story_boss_enraged else Color(1.0, 0.25, 0.38, fang_alpha)
		canvas.draw_line(hc + Vector2(-15.0, -5.0) * scale_f, hc + Vector2(-5.0, -2.0) * scale_f, eye_c, maxf(1.6, 3.2 * scale_f), true)
		canvas.draw_line(hc + Vector2(15.0, -5.0) * scale_f, hc + Vector2(5.0, -2.0) * scale_f, eye_c, maxf(1.6, 3.2 * scale_f), true)

		# Direction shape emblem on forehead/jaw
		var em_c := hc + Vector2(0.0, 5.0 * scale_f)
		var em_col := Color(1.0, 1.0, 1.0, 0.35 if hdead else 0.95)
		match hshape:
			"up":
				var tri := PackedVector2Array([
					em_c + Vector2(0.0, -7.5) * scale_f,
					em_c + Vector2(7.5, 6.0) * scale_f,
					em_c + Vector2(-7.5, 6.0) * scale_f,
				])
				canvas.draw_colored_polygon(tri, em_col)
			"down":
				var dm := PackedVector2Array([
					em_c + Vector2(0.0, -8.0) * scale_f,
					em_c + Vector2(8.0, 0.0) * scale_f,
					em_c + Vector2(0.0, 8.0) * scale_f,
					em_c + Vector2(-8.0, 0.0) * scale_f,
				])
				canvas.draw_colored_polygon(dm, em_col)
			"left":
				var r_s: float = 6.2 * scale_f
				canvas.draw_rect(Rect2(em_c.x - r_s, em_c.y - r_s, r_s * 2.0, r_s * 2.0), em_col, true)
			"right":
				canvas.draw_circle(em_c, 6.8 * scale_f, em_col)


func _draw_story_hydra_shield_icon(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time

	# 1. Rotating Outer Hexagonal Forcefield Barrier
	var pulse: float = 1.0 + sin(t * 11.0) * 0.07
	var hex_r: float = 34.0 * sf * pulse
	var hex_pts := PackedVector2Array()
	for i in range(6):
		var ang: float = t * 1.4 + float(i) * (TAU / 6.0)
		hex_pts.append(c + Vector2(cos(ang), sin(ang)) * hex_r)
	var hex_closed := hex_pts.duplicate()
	hex_closed.append(hex_pts[0])
	panel.draw_colored_polygon(hex_pts, Color(0.04, 0.24, 0.22, 0.78))
	panel.draw_polyline(hex_closed, Color(0.15, 1.0, 0.75, 0.45), 6.0 * sf, true)
	panel.draw_polyline(hex_closed, Color(0.65, 1.0, 0.92, 0.96), 2.5 * sf, true)

	# 2. Inner Crest Shield Silhouette
	var sh_pts := PackedVector2Array([
		c + Vector2(0.0, -21.0) * sf,
		c + Vector2(18.0, -13.0) * sf,
		c + Vector2(15.0, 6.0) * sf,
		c + Vector2(0.0, 22.0) * sf,
		c + Vector2(-15.0, 6.0) * sf,
		c + Vector2(-18.0, -13.0) * sf,
	])
	var sh_closed := sh_pts.duplicate()
	sh_closed.append(sh_pts[0])
	panel.draw_colored_polygon(sh_pts, Color(0.06, 0.14, 0.18, 0.96))
	panel.draw_polyline(sh_closed, Color(0.20, 1.0, 0.72, 0.98), 2.8 * sf, true)

	# 3. Glowing Life-Drain / Reflect Cross-Core inside the Shield
	var cr: float = 8.5 * sf
	var core_col := Color(0.85, 1.0, 0.95, 0.98)
	panel.draw_line(c + Vector2(0.0, -cr), c + Vector2(0.0, cr), core_col, 3.2 * sf, true)
	panel.draw_line(c + Vector2(-cr, 0.0), c + Vector2(cr, 0.0), core_col, 3.2 * sf, true)
	panel.draw_circle(c, 3.5 * sf, Color(0.20, 1.0, 0.72, 1.0))


func _draw_story_hydra_regrow_badge(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time

	# Pulsing bio-green regrowth warning ring on severed head squares
	var r: float = (26.0 + sin(t * 8.0) * 2.5) * sf
	panel.draw_arc(c, r, t * 2.2, t * 2.2 + PI * 1.35, 20, Color(0.25, 1.0, 0.65, 0.88), 3.0 * sf, true)
	panel.draw_arc(c, r, t * 2.2 + PI, t * 2.2 + PI * 1.65, 12, Color(1.0, 0.92, 0.30, 0.85), 2.4 * sf, true)


func _draw_void_seraph_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	if not is_preview and _boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and _boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (_boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = _boss_anim_time
	var rage_mult: float = 1.65 if (story_boss_enraged and not is_preview) else 1.0
	var hover_y: float = sin(t * 3.2 * rage_mult) * 8.0 * scale_f
	var breathe: float = 1.0 + sin(t * 6.5 * rage_mult) * 0.04

	var shake_vec := Vector2.ZERO
	if not is_preview and (_boss_hit_shake > 0.01 or _boss_death_progress > 0.01):
		var sh_amp: float = (_boss_hit_shake * 9.0 + _boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(_boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	var col_up: Color = direction_colors.get("up", Color(1.0, 0.25, 0.45))
	var col_down: Color = direction_colors.get("down", Color(1.0, 0.85, 0.20))
	var col_left: Color = direction_colors.get("left", Color(0.20, 0.95, 0.55))
	var col_right: Color = direction_colors.get("right", Color(0.25, 0.65, 1.0))

	var up_dead: bool = (not is_preview and int(story_part_hp.get("up", 1)) <= 0)
	var down_dead: bool = (not is_preview and int(story_part_hp.get("down", 1)) <= 0)
	var left_dead: bool = (not is_preview and int(story_part_hp.get("left", 1)) <= 0)
	var right_dead: bool = (not is_preview and int(story_part_hp.get("right", 1)) <= 0)

	if up_dead:
		col_up = col_up.darkened(0.68)
	if down_dead:
		col_down = col_down.darkened(0.68)
	if left_dead:
		col_left = col_left.darkened(0.68)
	if right_dead:
		col_right = col_right.darkened(0.68)

	if not is_preview:
		var death_glow: float = clampf(_boss_death_progress * 1.4, 0.0, 1.0)
		col_up = col_up.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("up", 0.0)), 0.0, 1.0)))
		col_down = col_down.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("down", 0.0)), 0.0, 1.0)))
		col_left = col_left.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("left", 0.0)), 0.0, 1.0)))
		col_right = col_right.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get("right", 0.0)), 0.0, 1.0)))

	var death_split: float = (_boss_death_progress * _boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var dark_void := Color(0.07, 0.03, 0.14, 0.96)

	# 1. Counter-rotating Celestial Seraphic Rings
	var ring_col1 := Color(0.92, 0.35, 1.0, 0.32)
	var ring_col2 := Color(1.0, 0.88, 0.35, 0.28)
	canvas.draw_arc(root_pos, 102.0 * scale_f, t * 0.8, t * 0.8 + PI * 1.65, 32, ring_col1, maxf(1.5, 3.2 * scale_f), true)
	canvas.draw_arc(root_pos, 84.0 * scale_f, -t * 1.2, -t * 1.2 + PI * 1.5, 28, ring_col2, maxf(1.4, 2.5 * scale_f), true)

	var rec_up: float = (float(_boss_part_recoil.get("up", 0.0)) * 18.0 * scale_f) if not is_preview else 0.0
	var rec_down: float = (float(_boss_part_recoil.get("down", 0.0)) * 16.0 * scale_f) if not is_preview else 0.0
	var rec_left: float = (float(_boss_part_recoil.get("left", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0
	var rec_right: float = (float(_boss_part_recoil.get("right", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0

	var flap: float = sin(t * 5.2) * 8.0 * scale_f

	# 2. LEFT & RIGHT SERAPHIC PRISM WINGS ("left" and "right" colors)
	var left_c: Vector2 = root_pos + Vector2(-108.0 * scale_f - rec_left - death_split, -6.0 * scale_f + flap)
	var right_c: Vector2 = root_pos + Vector2(108.0 * scale_f + rec_right + death_split, -6.0 * scale_f + flap)
	var up_c: Vector2 = root_pos + Vector2(0.0, -76.0 * scale_f - rec_up - death_split - flap * 0.4)
	var down_c: Vector2 = root_pos + Vector2(0.0, 44.0 * scale_f + rec_down + death_split)

	# Left Wing Feathered Prism Blades
	var l_wing := PackedVector2Array([
		root_pos + Vector2(-34.0, -18.0) * scale_f,
		left_c + Vector2(-38.0, -44.0) * scale_f,
		left_c + Vector2(-18.0, -4.0) * scale_f,
		left_c + Vector2(-42.0, 14.0) * scale_f,
		left_c + Vector2(-10.0, 22.0) * scale_f,
		left_c + Vector2(-24.0, 44.0) * scale_f,
		root_pos + Vector2(-30.0, 16.0) * scale_f,
	])
	var l_closed := l_wing.duplicate()
	l_closed.append(l_wing[0])
	canvas.draw_colored_polygon(l_wing, col_left)
	canvas.draw_polyline(l_closed, Color(1.0, 1.0, 1.0, 0.32 if left_dead else 0.92), maxf(1.5, 2.8 * scale_f), true)
	var l_sq: float = 7.5 * scale_f
	canvas.draw_rect(Rect2(left_c.x - l_sq, left_c.y - l_sq, l_sq * 2.0, l_sq * 2.0), Color(1.0, 1.0, 1.0, 0.35 if left_dead else 0.96), true)

	# Right Wing Feathered Prism Blades
	var r_wing := PackedVector2Array([
		root_pos + Vector2(34.0, -18.0) * scale_f,
		right_c + Vector2(38.0, -44.0) * scale_f,
		right_c + Vector2(18.0, -4.0) * scale_f,
		right_c + Vector2(42.0, 14.0) * scale_f,
		right_c + Vector2(10.0, 22.0) * scale_f,
		right_c + Vector2(24.0, 44.0) * scale_f,
		root_pos + Vector2(30.0, 16.0) * scale_f,
	])
	var r_closed := r_wing.duplicate()
	r_closed.append(r_wing[0])
	canvas.draw_colored_polygon(r_wing, col_right)
	canvas.draw_polyline(r_closed, Color(1.0, 1.0, 1.0, 0.32 if right_dead else 0.92), maxf(1.5, 2.8 * scale_f), true)
	canvas.draw_circle(right_c, 8.0 * scale_f, Color(1.0, 1.0, 1.0, 0.35 if right_dead else 0.96))

	# 3. TOP CROWN CREST WING ("up" color)
	var top_wing := PackedVector2Array([
		up_c + Vector2(0.0, -34.0) * scale_f,
		up_c + Vector2(46.0, -8.0) * scale_f,
		up_c + Vector2(24.0, 22.0) * scale_f,
		up_c + Vector2(0.0, 12.0) * scale_f,
		up_c + Vector2(-24.0, 22.0) * scale_f,
		up_c + Vector2(-46.0, -8.0) * scale_f,
	])
	var top_closed := top_wing.duplicate()
	top_closed.append(top_wing[0])
	canvas.draw_colored_polygon(top_wing, col_up)
	canvas.draw_polyline(top_closed, Color(1.0, 1.0, 1.0, 0.32 if up_dead else 0.92), maxf(1.5, 2.8 * scale_f), true)
	var tri_up := PackedVector2Array([
		up_c + Vector2(0.0, -10.0) * scale_f,
		up_c + Vector2(9.0, 6.0) * scale_f,
		up_c + Vector2(-9.0, 6.0) * scale_f,
	])
	canvas.draw_colored_polygon(tri_up, Color(1.0, 1.0, 1.0, 0.35 if up_dead else 0.96))

	# 4. LOWER SOLAR PENDULUM TAIL ("down" color)
	var low_wing := PackedVector2Array([
		down_c + Vector2(-36.0, -14.0) * scale_f,
		down_c + Vector2(36.0, -14.0) * scale_f,
		down_c + Vector2(22.0, 22.0) * scale_f,
		down_c + Vector2(0.0, 38.0) * scale_f,
		down_c + Vector2(-22.0, 22.0) * scale_f,
	])
	var low_closed := low_wing.duplicate()
	low_closed.append(low_wing[0])
	canvas.draw_colored_polygon(low_wing, col_down)
	canvas.draw_polyline(low_closed, Color(1.0, 1.0, 1.0, 0.32 if down_dead else 0.92), maxf(1.5, 2.8 * scale_f), true)
	var dm_down := PackedVector2Array([
		down_c + Vector2(0.0, -2.0) * scale_f,
		down_c + Vector2(9.0, 7.0) * scale_f,
		down_c + Vector2(0.0, 16.0) * scale_f,
		down_c + Vector2(-9.0, 7.0) * scale_f,
	])
	canvas.draw_colored_polygon(dm_down, Color(1.0, 1.0, 1.0, 0.35 if down_dead else 0.96))

	# 5. CENTRAL ALL-SEEING SERAPHIC SINGULARITY EYE CORE
	var core_s: float = scale_f * breathe
	var eye_outer := PackedVector2Array([
		root_pos + Vector2(-46.0, 0.0) * core_s,
		root_pos + Vector2(-20.0, -26.0) * core_s,
		root_pos + Vector2(20.0, -26.0) * core_s,
		root_pos + Vector2(46.0, 0.0) * core_s,
		root_pos + Vector2(20.0, 26.0) * core_s,
		root_pos + Vector2(-20.0, 26.0) * core_s,
	])
	var eye_closed := eye_outer.duplicate()
	eye_closed.append(eye_outer[0])
	canvas.draw_colored_polygon(eye_outer, dark_void)
	var eye_rim_col := Color(1.0, 0.35, 0.65) if (story_boss_enraged and not is_preview) else Color(1.0, 0.88, 0.38)
	canvas.draw_polyline(eye_closed, eye_rim_col, maxf(1.8, 3.6 * scale_f), true)

	# Iris & Vertical Slit Singularity Pupil
	var iris_col := Color(0.92, 0.32, 1.0, 0.95) if not (story_boss_enraged and not is_preview) else Color(1.0, 0.22, 0.45, 0.98)
	canvas.draw_circle(root_pos, 16.5 * core_s, iris_col)
	canvas.draw_circle(root_pos, 10.0 * core_s, Color(0.04, 0.01, 0.09, 0.98))
	var slit_pts := PackedVector2Array([
		root_pos + Vector2(0.0, -13.0) * core_s,
		root_pos + Vector2(4.0, 0.0) * core_s,
		root_pos + Vector2(0.0, 13.0) * core_s,
		root_pos + Vector2(-4.0, 0.0) * core_s,
	])
	canvas.draw_colored_polygon(slit_pts, Color(1.0, 0.95, 0.65, 0.98))


func _draw_story_void_rift_icon(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time

	# 1. Swirling Outer Accretion Disk
	var pulse: float = 1.0 + sin(t * 12.0) * 0.08
	var outer_r: float = 34.0 * sf * pulse
	panel.draw_circle(c, outer_r, Color(0.05, 0.01, 0.11, 0.88))
	panel.draw_arc(c, outer_r, t * 3.5, t * 3.5 + PI * 1.45, 24, Color(1.35, 0.32, 1.85, 0.95), 4.5 * sf, true)
	panel.draw_arc(c, outer_r * 0.76, -t * 4.8, -t * 4.8 + PI * 1.45, 20, Color(1.0, 0.88, 0.32, 0.95), 3.2 * sf, true)

	# 2. 4 Curved Vortex Spiral Arms
	for i in range(4):
		var base_a: float = -t * 4.2 + float(i) * (TAU / 4.0)
		var p0 := c + Vector2(cos(base_a), sin(base_a)) * (8.0 * sf)
		var p1 := c + Vector2(cos(base_a + 0.55), sin(base_a + 0.55)) * (20.0 * sf)
		var p2 := c + Vector2(cos(base_a + 1.15), sin(base_a + 1.15)) * (31.0 * sf)
		panel.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.95, 0.52, 1.0, 0.92), 2.8 * sf, true)

	# 3. Black Hole Event Horizon Center
	panel.draw_circle(c, 11.5 * sf, Color(0.02, 0.0, 0.05, 1.0))
	panel.draw_arc(c, 11.5 * sf, 0.0, TAU, 24, Color(1.0, 0.92, 0.45, 0.96), 2.2 * sf, true)


func _draw_story_void_drain_badge(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time

	# Swirling violet-gold warning ring on shattered wing squares
	var r: float = (26.0 + sin(t * 9.0) * 2.5) * sf
	panel.draw_arc(c, r, -t * 2.6, -t * 2.6 + PI * 1.35, 20, Color(0.95, 0.42, 1.0, 0.88), 3.0 * sf, true)
	panel.draw_arc(c, r, -t * 2.6 + PI, -t * 2.6 + PI * 1.65, 12, Color(1.0, 0.88, 0.35, 0.85), 2.4 * sf, true)


# =====================================================
# STORY MODE — LEVEL 4: PHANTOM MAESTRO
#   Phase 1: MELODY SEQUENCES (swipe numbered notes in order; final note = ENCORE x2 dmg)
#   Mirror Curse: reverses swipe directions for a whole melody / 3 swipes
#   Phase 2: MASQUERADE (True Mask flashes briefly, then all 4 squares look identical)
# =====================================================

func _layout_story_level_cards(panel: Control) -> void:
	if panel == null:
		return
	var card_h: float = 164.0
	var gap: float = 8.0
	var top0: float = 64.0
	for i in range(4):
		var card := panel.get_node_or_null("Level%dCard" % (i + 1)) as Panel
		if card == null:
			continue
		card.offset_top = top0 + float(i) * (card_h + gap)
		card.offset_bottom = card.offset_top + card_h
		for child in card.get_children():
			if child is Button:
				var b := child as Button
				b.anchor_left = 0.0
				b.anchor_right = 0.0
				b.offset_left = 112.0
				b.offset_right = 378.0
				b.offset_top = 118.0
				b.offset_bottom = 154.0
				b.add_theme_font_size_override("font_size", 13)
			elif child is Label:
				var l := child as Label
				l.offset_left = 114.0
				l.offset_right = 378.0
				var n: String = str(l.name)
				if n.ends_with("Title"):
					l.offset_top = 6.0
					l.offset_bottom = 26.0
				elif n.ends_with("Status"):
					l.offset_top = 26.0
					l.offset_bottom = 42.0
				else:
					l.offset_top = 44.0
					l.offset_bottom = 114.0
			elif child is Control:
				var ctrl := child as Control
				ctrl.position = Vector2(8.0, 8.0)
				ctrl.size = Vector2(96.0, 148.0)


func _story_l4_opposite(dir: String) -> String:
	match dir:
		"up":
			return "down"
		"down":
			return "up"
		"left":
			return "right"
		"right":
			return "left"
	return dir


func _build_story_l4_sequence() -> void:
	var alive: Array[String] = _get_alive_boss_parts()
	_story_l4_sequence.clear()
	_story_l4_seq_index = 0
	if alive.is_empty():
		return
	# 4–3 instruments alive: 2-note melodies | 2–1 alive: 3-note melodies
	var length: int = 2 if alive.size() >= 3 else 3
	# The final (ENCORE) note always lands on a living instrument
	var last_note: String = alive.pick_random()
	var pool: Array[String] = []
	for d: String in ["up", "down", "left", "right"]:
		if d != last_note:
			pool.append(d)
	pool.shuffle()
	for i in range(length - 1):
		_story_l4_sequence.append(pool[i])
	_story_l4_sequence.append(last_note)

	if _story_l4_mirror_pending:
		_story_l4_mirror_pending = false
		_story_l4_mirror_swipes = length
		_show_remap_banner("🪞 MIRROR CURSE: SWIPES REVERSED! 🪞")
		sfx.play_pitched("combo", 0.72)
		_haptic_danger()


func _start_story_level4_turn() -> void:
	story_bomb_dirs.clear()
	story_bomb_dir = ""
	var all_dirs: Array[String] = ["up", "down", "left", "right"]

	if _are_all_boss_parts_destroyed():
		story_boss_enraged = true
		# PHASE 2 — MASQUERADE: pick a new True Mask & flash it briefly before hiding all squares
		if _story_l4_mirror_swipes <= 0:
			_story_l4_turns_until_mirror -= 1
			if _story_l4_turns_until_mirror <= 0:
				_story_l4_mirror_swipes = 3
				_story_l4_turns_until_mirror = randi_range(4, 6)
				_show_remap_banner("🪞 MIRROR CURSE: SWIPES REVERSED! 🪞")
				sfx.play_pitched("combo", 0.72)
				_haptic_danger()
		var prev_true: String = _story_l4_true_dir
		var cands: Array[String] = []
		for d: String in all_dirs:
			if d != prev_true:
				cands.append(d)
		_story_l4_true_dir = cands.pick_random()
		var hp_ratio: float = clampf(float(story_boss_hp) / float(maxi(1, story_boss_max_hp)), 0.0, 1.0)
		# Reveal window shrinks as the Maestro weakens (0.65s -> 0.42s)
		_story_l4_reveal_left = lerpf(0.42, 0.65, hp_ratio)
		current_time_limit += _story_l4_reveal_left + 0.12
	else:
		# PHASE 1 — MELODY: keep the current melody until it's completed or broken
		_story_l4_true_dir = ""
		_story_l4_reveal_left = 0.0
		if _story_l4_sequence.is_empty():
			_build_story_l4_sequence()
		current_time_limit += 0.10

	if _story_l4_mirror_swipes > 0:
		current_time_limit += 0.18
	time_left_in_turn = current_time_limit

	_boss_throw_anim = 1.0
	_update_story_boss_labels()
	_apply_board_colors()
	_pulse_center()


func _on_story_level4_swipe(raw_dir: String) -> void:
	var direction: String = raw_dir
	if _story_l4_mirror_swipes > 0:
		direction = _story_l4_opposite(raw_dir)
		_story_l4_mirror_swipes -= 1

	# PHASE 2 — MASQUERADE
	if _are_all_boss_parts_destroyed():
		if _story_l4_true_dir != "" and direction == _story_l4_true_dir:
			_story_l4_true_dir = ""
			_story_l4_reveal_left = 0.0
			_on_story_boss_hit(direction)
		else:
			_on_story_level4_mistake(direction, true)
		return

	# PHASE 1 — MELODY
	if _story_l4_sequence.is_empty():
		_build_story_l4_sequence()
	if _story_l4_sequence.is_empty():
		return
	var expected: String = _story_l4_sequence[_story_l4_seq_index]
	if direction != expected:
		_on_story_level4_mistake(direction, false)
		return

	_story_l4_seq_index += 1
	var dmg: int = 1
	if _story_l4_seq_index >= _story_l4_sequence.size():
		# Melody complete! Final note strikes as an ENCORE (double damage)
		dmg = 2
		_story_l4_sequence.clear()
		_story_l4_seq_index = 0
		# Predict whether an instrument is silenced by this hit to decide on a Mirror Curse
		var cur_hp: int = int(story_part_hp.get(direction, 0))
		var broken_after: int = 4 - _get_alive_boss_parts().size() + (1 if (cur_hp > 0 and cur_hp <= dmg) else 0)
		if broken_after >= 1 and broken_after < 4 and _story_l4_mirror_swipes <= 0:
			_story_l4_turns_until_mirror -= 1
			if _story_l4_turns_until_mirror <= 0 or randf() < 0.35:
				_story_l4_mirror_pending = true
				_story_l4_turns_until_mirror = 3
	_on_story_boss_hit(direction, dmg)


func _on_story_level4_mistake(direction: String, is_decoy: bool) -> void:
	var pos := _get_board_center(direction)
	var true_dir_was: String = _story_l4_true_dir
	_story_l4_sequence.clear()
	_story_l4_seq_index = 0
	_story_l4_mirror_swipes = 0
	_story_l4_mirror_pending = false
	_story_l4_true_dir = ""
	_story_l4_reveal_left = 0.0
	_story_last_swiped_dir = direction
	_boss_taunt_anim = 1.0

	_flash_square(direction, Color(1.7, 0.25, 0.35, 0.98))
	if is_decoy and true_dir_was != "" and true_dir_was != direction:
		# Briefly show where the True Mask actually was
		_flash_square(true_dir_was, Color(1.6, 1.25, 0.35, 0.9))
	_burst_particles(pos, Color(1.5, 0.3, 0.35), 22)
	_burst_particles(pos, Color(1.0, 0.85, 0.4), 12)
	_burst_at(pos, Color(1.4, 0.25, 0.3))

	lives -= 1
	_lost_heart_this_game = true
	streak = 0
	perfect_streak = 0
	_audio_pulse = 0.9

	sfx.play("wrong")
	_haptic_danger()
	_shake_screen(14.0)
	_flash_center_red()
	if is_decoy:
		_show_persistent_label("🎭 DECOY MASK! -1 HP", pos, Color(1.0, 0.42, 0.50), true)
	else:
		_show_persistent_label("🎻 OFF-KEY! -1 HP (MELODY RESET)", pos, Color(1.0, 0.55, 0.45), true)
	_update_lives_display()
	_update_story_boss_labels()
	_apply_board_colors()

	if lives <= 0:
		_game_over()
	else:
		start_new_turn()


func _apply_story_level4_square_style(style: StyleBoxFlat, dir: String) -> void:
	var col: Color = direction_colors.get(dir, Color.WHITE)
	var gold_highlight: bool = false
	if _are_all_boss_parts_destroyed():
		if _story_l4_reveal_left > 0.0 and dir == _story_l4_true_dir:
			_apply_skin_to_square_style(style, col, false)
			style.set_border_width_all(4)
			style.set_border_color(Color(1.6, 1.25, 0.35, 0.98))
			style.set_shadow_color(Color(1.3, 0.9, 0.2, 0.80))
			style.set_shadow_size(20)
			gold_highlight = true
		else:
			# Identical masquerade squares — colors hidden!
			style.bg_color = Color(0.13, 0.07, 0.17, 0.96)
			style.set_border_width_all(3)
			style.set_border_color(Color(0.75, 0.62, 0.95, 0.85))
			style.set_shadow_color(Color(0.55, 0.30, 0.85, 0.45))
			style.set_shadow_size(10)
	else:
		_apply_skin_to_square_style(style, col, false)
		if int(story_part_hp.get(dir, 0)) <= 0:
			style.bg_color = col.darkened(0.55)
		var note_idx: int = _story_l4_sequence.find(dir)
		if note_idx >= 0 and note_idx == _story_l4_seq_index:
			style.set_border_width_all(4)
			style.set_border_color(Color(1.6, 1.25, 0.35, 0.98))
			style.set_shadow_color(Color(1.3, 0.9, 0.2, 0.78))
			style.set_shadow_size(18)
			gold_highlight = true
		elif note_idx > _story_l4_seq_index:
			style.set_border_width_all(3)
			style.set_border_color(Color(1.0, 0.55, 0.75, 0.88))
			style.set_shadow_color(Color(0.9, 0.3, 0.55, 0.45))
			style.set_shadow_size(10)
	if _story_l4_mirror_swipes > 0 and not gold_highlight:
		style.set_border_width_all(3)
		style.set_border_color(Color(0.85, 0.95, 1.25, 0.95))
		style.set_shadow_color(Color(0.65, 0.85, 1.1, 0.55))
		style.set_shadow_size(12)


func _draw_story_l4_centered_text(canvas: CanvasItem, c: Vector2, txt: String, fs: int, col: Color, outline_col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var t_size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var baseline: Vector2 = Vector2(c.x - t_size.x * 0.5, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	canvas.draw_string_outline(font, baseline, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 6), outline_col)
	canvas.draw_string(font, baseline, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_story_level4_square_overlay(panel: Panel, dir: String) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time

	if _are_all_boss_parts_destroyed():
		# MASQUERADE masks
		var kind: int = 0
		if _story_l4_reveal_left > 0.0:
			kind = 1 if dir == _story_l4_true_dir else 2
		_draw_story_maestro_mask(panel, c, sf * 1.15, kind)
	else:
		var note_idx: int = _story_l4_sequence.find(dir)
		if note_idx >= _story_l4_seq_index and note_idx >= 0:
			var is_next: bool = (note_idx == _story_l4_seq_index)
			var pulse: float = 1.0 + (sin(t * 11.0) * 0.09 if is_next else 0.0)
			var r: float = (27.0 if is_next else 22.0) * sf * pulse
			var ring_col: Color = Color(1.0, 0.85, 0.35, 0.98) if is_next else Color(1.0, 0.55, 0.78, 0.75)
			panel.draw_circle(c, r, Color(0.10, 0.04, 0.10, 0.88 if is_next else 0.70))
			panel.draw_arc(c, r, 0.0, TAU, 32, ring_col, (4.0 if is_next else 2.5) * sf, true)
			if is_next:
				panel.draw_arc(c, r + 6.0 * sf, t * 4.0, t * 4.0 + PI * 1.2, 20, Color(1.0, 0.92, 0.55, 0.65), 2.2 * sf, true)
			var num_col: Color = Color(1.0, 0.95, 0.70, 1.0) if is_next else Color(1.0, 0.80, 0.90, 0.85)
			_draw_story_l4_centered_text(panel, c, str(note_idx + 1), int((30.0 if is_next else 24.0) * sf), num_col, Color(0.10, 0.02, 0.08, 1.0))
			# Tiny music note badge in the corner of the rune
			_draw_story_music_note(panel, c + Vector2(r * 0.85, -r * 0.85), 0.55 * sf, ring_col)
		else:
			_draw_symbol_on_panel(panel, dir)
			if int(story_part_hp.get(dir, 0)) <= 0:
				# Silenced instrument: mute slash
				panel.draw_line(c + Vector2(-20, -20) * sf, c + Vector2(20, 20) * sf, Color(0.10, 0.04, 0.08, 0.85), 6.0 * sf, true)
				panel.draw_line(c + Vector2(-20, -20) * sf, c + Vector2(20, 20) * sf, Color(1.0, 0.45, 0.50, 0.85), 3.0 * sf, true)

	# Mirror Curse: shimmering glass sheen + reversed-arrow badge on every square
	if _story_l4_mirror_swipes > 0:
		var sweep: float = fmod(t * 0.9, 1.6) - 0.3
		var x0: float = s.x * sweep
		panel.draw_line(Vector2(x0, s.y), Vector2(x0 + s.y * 0.6, 0.0), Color(0.85, 0.95, 1.0, 0.30), 10.0 * sf, true)
		panel.draw_line(Vector2(x0 + 14.0 * sf, s.y), Vector2(x0 + 14.0 * sf + s.y * 0.6, 0.0), Color(1.0, 1.0, 1.0, 0.22), 4.0 * sf, true)
		var bc: Vector2 = Vector2(s.x - 16.0 * sf, 16.0 * sf)
		panel.draw_circle(bc, 11.0 * sf, Color(0.08, 0.10, 0.20, 0.85))
		panel.draw_arc(bc, 11.0 * sf, 0.0, TAU, 20, Color(0.80, 0.92, 1.0, 0.95), 1.8 * sf, true)
		var a_col := Color(0.85, 0.95, 1.0, 0.98)
		panel.draw_line(bc + Vector2(-6, -2.5) * sf, bc + Vector2(6, -2.5) * sf, a_col, 1.8 * sf, true)
		panel.draw_line(bc + Vector2(6, -2.5) * sf, bc + Vector2(3, -5.5) * sf, a_col, 1.8 * sf, true)
		panel.draw_line(bc + Vector2(-6, 2.5) * sf, bc + Vector2(6, 2.5) * sf, a_col, 1.8 * sf, true)
		panel.draw_line(bc + Vector2(-6, 2.5) * sf, bc + Vector2(-3, 5.5) * sf, a_col, 1.8 * sf, true)


func _draw_story_maestro_center_emblem(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var s: Vector2 = panel.size
	var c: Vector2 = s * 0.5
	var sf: float = minf(s.x, s.y) / 100.0
	var t: float = _boss_anim_time
	var all_dead := _are_all_boss_parts_destroyed()
	var pulse: float = 1.0 + sin(t * 7.0) * 0.07

	# Mirror Curse halo + reversed double arrows
	if _story_l4_mirror_swipes > 0:
		panel.draw_arc(c, 40.0 * sf, t * 2.0, t * 2.0 + TAU, 36, Color(0.45, 0.65, 1.0, 0.70), 3.5 * sf, true)
		var m_col := Color(0.30, 0.45, 0.85, 0.85)
		panel.draw_line(c + Vector2(0, -34) * sf, c + Vector2(0, 34) * sf, m_col, 2.4 * sf, true)
		panel.draw_line(c + Vector2(-34, 0) * sf, c + Vector2(34, 0) * sf, m_col, 2.4 * sf, true)
		for tip: Vector2 in [Vector2(0, -34), Vector2(0, 34), Vector2(-34, 0), Vector2(34, 0)]:
			var tp: Vector2 = c + tip * sf
			var back: Vector2 = -tip.normalized() * 7.0 * sf
			var side: Vector2 = Vector2(-back.y, back.x) * 0.7
			panel.draw_colored_polygon(PackedVector2Array([tp, tp + back + side, tp + back - side]), m_col)

	# Central conductor's music note
	var note_col: Color = Color(0.85, 0.18, 0.30, 0.96) if all_dead else Color(0.20, 0.10, 0.28, 0.96)
	_draw_story_music_note(panel, c + Vector2(0.0, -4.0 * sf), 2.0 * sf * pulse, note_col)

	# Melody progress pips (Phase 1)
	if not all_dead and not _story_l4_sequence.is_empty():
		var n: int = _story_l4_sequence.size()
		var spacing: float = 12.0 * sf
		var start_x: float = c.x - spacing * float(n - 1) * 0.5
		for i in range(n):
			var pp: Vector2 = Vector2(start_x + spacing * float(i), c.y + 26.0 * sf)
			if i < _story_l4_seq_index:
				panel.draw_circle(pp, 4.2 * sf, Color(1.0, 0.72, 0.18, 0.98))
			elif i == _story_l4_seq_index:
				panel.draw_circle(pp, 4.6 * sf * pulse, Color(1.0, 0.85, 0.35, 0.55))
				panel.draw_arc(pp, 4.6 * sf * pulse, 0.0, TAU, 14, Color(0.55, 0.30, 0.05, 0.98), 1.8 * sf, true)
			else:
				panel.draw_arc(pp, 4.0 * sf, 0.0, TAU, 14, Color(0.35, 0.20, 0.40, 0.85), 1.6 * sf, true)


func _draw_story_music_note(canvas: CanvasItem, pos: Vector2, scale_f: float, col: Color) -> void:
	# Eighth note: tilted head, stem & flag
	var head_c: Vector2 = pos + Vector2(-3.5, 6.0) * scale_f
	var head_pts := PackedVector2Array()
	for i in range(14):
		var a: float = float(i) / 14.0 * TAU
		var p := Vector2(cos(a) * 5.2, sin(a) * 3.8).rotated(-0.45)
		head_pts.append(head_c + p * scale_f)
	canvas.draw_colored_polygon(head_pts, col)
	var stem_bot: Vector2 = head_c + Vector2(4.4, -1.6) * scale_f
	var stem_top: Vector2 = stem_bot + Vector2(0.0, -15.0) * scale_f
	canvas.draw_line(stem_bot, stem_top, col, maxf(1.2, 1.9 * scale_f), true)
	canvas.draw_polyline(PackedVector2Array([
		stem_top,
		stem_top + Vector2(5.0, 4.0) * scale_f,
		stem_top + Vector2(6.0, 9.0) * scale_f,
	]), col, maxf(1.2, 2.0 * scale_f), true)


# kind: 0 = hidden identical mask, 1 = TRUE (gold crown), 2 = revealed decoy, 3 = enraged boss face
func _draw_story_maestro_mask(canvas: CanvasItem, c: Vector2, sf: float, kind: int) -> void:
	var t: float = _boss_anim_time
	var sway: float = sin(t * 2.4) * 0.06
	var face_col: Color
	var rim_col: Color
	var eye_col: Color
	match kind:
		1:
			face_col = Color(1.0, 0.95, 0.85, 0.98)
			rim_col = Color(1.0, 0.78, 0.25, 0.98)
			eye_col = Color(1.0, 0.85, 0.30, 1.0)
		2:
			face_col = Color(0.42, 0.30, 0.52, 0.92)
			rim_col = Color(0.75, 0.35, 0.85, 0.85)
			eye_col = Color(1.0, 0.25, 0.35, 0.95)
		3:
			face_col = Color(0.98, 0.92, 0.90, 0.98)
			rim_col = Color(1.0, 0.30, 0.38, 0.98)
			eye_col = Color(1.0, 0.18, 0.28, 1.0)
		_:
			face_col = Color(0.82, 0.80, 0.92, 0.95)
			rim_col = Color(0.70, 0.60, 0.95, 0.92)
			eye_col = Color(0.65, 0.40, 1.0, 0.75 + 0.2 * sin(t * 5.0))

	# Face outline (oval with pointed chin)
	var face := PackedVector2Array()
	for i in range(22):
		var a: float = float(i) / 22.0 * TAU
		var y_scale: float = 24.0 if sin(a) < 0.0 else 28.0
		var p := Vector2(cos(a) * 20.0, sin(a) * y_scale)
		if sin(a) > 0.6:
			p.x *= 1.0 - (sin(a) - 0.6) * 0.9
		face.append(c + p.rotated(sway) * sf)
	var face_closed := face.duplicate()
	face_closed.append(face[0])
	canvas.draw_colored_polygon(face, face_col)
	canvas.draw_polyline(face_closed, rim_col, maxf(1.2, 2.6 * sf), true)

	# Slanted eye holes
	for side: float in [-1.0, 1.0]:
		var e_c: Vector2 = c + Vector2(8.5 * side, -4.0).rotated(sway) * sf
		var eye := PackedVector2Array([
			e_c + Vector2(-6.0 * side, 1.5).rotated(sway) * sf,
			e_c + Vector2(0.0, -3.5).rotated(sway) * sf,
			e_c + Vector2(6.0 * side, -1.5).rotated(sway) * sf,
			e_c + Vector2(0.0, 3.0).rotated(sway) * sf,
		])
		canvas.draw_colored_polygon(eye, Color(0.06, 0.02, 0.08, 0.98))
		canvas.draw_circle(e_c, 2.0 * sf, eye_col)

	# Mouth
	if kind == 3 or kind == 2:
		canvas.draw_polyline(PackedVector2Array([
			c + Vector2(-7, 12).rotated(sway) * sf,
			c + Vector2(-2, 9).rotated(sway) * sf,
			c + Vector2(2, 13).rotated(sway) * sf,
			c + Vector2(7, 10).rotated(sway) * sf,
		]), Color(0.10, 0.02, 0.06, 0.95), maxf(1.0, 2.0 * sf), true)
	else:
		canvas.draw_arc(c + Vector2(0, 8).rotated(sway) * sf, 6.0 * sf, 0.35, PI - 0.35, 10, Color(0.15, 0.05, 0.12, 0.9), maxf(1.0, 2.0 * sf), true)

	# Crack for decoy / enraged
	if kind == 2 or kind == 3:
		canvas.draw_polyline(PackedVector2Array([
			c + Vector2(4, -24).rotated(sway) * sf,
			c + Vector2(1, -14).rotated(sway) * sf,
			c + Vector2(6, -8).rotated(sway) * sf,
			c + Vector2(3, 0).rotated(sway) * sf,
		]), Color(0.12, 0.02, 0.06, 0.92), maxf(1.0, 1.8 * sf), true)

	# Golden crown on the TRUE mask
	if kind == 1:
		var crown_base: float = -24.0
		var crown := PackedVector2Array([
			c + Vector2(-14, crown_base).rotated(sway) * sf,
			c + Vector2(-16, crown_base - 12).rotated(sway) * sf,
			c + Vector2(-7, crown_base - 5).rotated(sway) * sf,
			c + Vector2(0, crown_base - 15).rotated(sway) * sf,
			c + Vector2(7, crown_base - 5).rotated(sway) * sf,
			c + Vector2(16, crown_base - 12).rotated(sway) * sf,
			c + Vector2(14, crown_base).rotated(sway) * sf,
		])
		canvas.draw_colored_polygon(crown, Color(1.0, 0.80, 0.22, 0.98))
		canvas.draw_circle(c + Vector2(0, crown_base - 15).rotated(sway) * sf, 2.4 * sf, Color(1.0, 0.35, 0.40, 1.0))
	elif kind == 0:
		# Mysterious "?" swirl for hidden masks
		canvas.draw_arc(c, 32.0 * sf, -t * 1.6, -t * 1.6 + PI * 1.3, 20, Color(0.75, 0.55, 1.0, 0.55), 2.2 * sf, true)


func _draw_story_level4_preview() -> void:
	if _story_level4_preview_ctrl == null or not is_instance_valid(_story_level4_preview_ctrl):
		return
	var s: Vector2 = _story_level4_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	_story_level4_preview_ctrl.draw_circle(c, 46.0, Color(0.14, 0.03, 0.07, 0.88))
	_story_level4_preview_ctrl.draw_arc(c, 46.0, 0.0, TAU, 36, Color(1.0, 0.70, 0.30, 0.62), 2.0, true)
	_draw_phantom_maestro_figure(_story_level4_preview_ctrl, c + Vector2(0.0, 4.0), 0.34, true)
	if settings == null or not settings.is_story_level_cleared(3):
		_draw_story_locked_overlay(_story_level4_preview_ctrl, c)


func _draw_phantom_maestro_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	if not is_preview and _boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and _boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (_boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = _boss_anim_time
	var enraged: bool = story_boss_enraged and not is_preview
	var rage_mult: float = 1.65 if enraged else 1.0
	var hover_y: float = sin(t * 2.6 * rage_mult) * 7.0 * scale_f

	var shake_vec := Vector2.ZERO
	if not is_preview and (_boss_hit_shake > 0.01 or _boss_death_progress > 0.01):
		var sh_amp: float = (_boss_hit_shake * 9.0 + _boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(_boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	var cols: Dictionary = {}
	var dead: Dictionary = {}
	var defaults: Dictionary = {
		"up": Color(1.0, 0.25, 0.45), "down": Color(1.0, 0.85, 0.20),
		"left": Color(0.20, 0.95, 0.55), "right": Color(0.25, 0.65, 1.0),
	}
	var death_glow: float = clampf(_boss_death_progress * 1.4, 0.0, 1.0) if not is_preview else 0.0
	for d: String in ["up", "down", "left", "right"]:
		var col: Color = direction_colors.get(d, defaults[d])
		var is_dead: bool = (not is_preview and int(story_part_hp.get(d, 1)) <= 0)
		if is_dead:
			col = col.darkened(0.68)
		if not is_preview:
			col = col.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(_boss_part_flash.get(d, 0.0)), 0.0, 1.0)))
		cols[d] = col
		dead[d] = is_dead

	var death_split: float = (_boss_death_progress * _boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var rec: Dictionary = {}
	for d: String in ["up", "down", "left", "right"]:
		rec[d] = (float(_boss_part_recoil.get(d, 0.0)) * 18.0 * scale_f) if not is_preview else 0.0

	var gold := Color(1.0, 0.78, 0.30, 0.95)
	var lw: float = maxf(1.2, 2.6 * scale_f)

	# 1. Rotating musical staff rings (5 lines) behind the Maestro
	for i in range(5):
		var rr: float = (86.0 + float(i) * 5.0) * scale_f
		var a0: float = t * 0.45 * rage_mult + float(i) * 0.12
		var staff_col := Color(1.0, 0.35, 0.40, 0.22) if enraged else Color(1.0, 0.80, 0.40, 0.18)
		canvas.draw_arc(root_pos + Vector2(0.0, -20.0 * scale_f), rr, a0, a0 + PI * 1.25, 30, staff_col, maxf(1.0, 1.4 * scale_f), true)

	# 2. Flowing phantom cloak with wavy hem
	var wave1: float = sin(t * 3.4) * 6.0 * scale_f
	var wave2: float = sin(t * 3.4 + 1.7) * 6.0 * scale_f
	var cloak := PackedVector2Array([
		root_pos + Vector2(0.0, -64.0) * scale_f,
		root_pos + Vector2(22.0, -56.0) * scale_f,
		root_pos + Vector2(48.0, -18.0) * scale_f,
		root_pos + Vector2(56.0, 38.0) * scale_f + Vector2(0.0, wave1),
		root_pos + Vector2(32.0, 54.0) * scale_f + Vector2(0.0, wave2),
		root_pos + Vector2(12.0, 44.0) * scale_f + Vector2(0.0, wave1),
		root_pos + Vector2(-12.0, 56.0) * scale_f + Vector2(0.0, wave2),
		root_pos + Vector2(-32.0, 46.0) * scale_f + Vector2(0.0, wave1),
		root_pos + Vector2(-56.0, 40.0) * scale_f + Vector2(0.0, wave2),
		root_pos + Vector2(-48.0, -18.0) * scale_f,
		root_pos + Vector2(-22.0, -56.0) * scale_f,
	])
	var cloak_closed := cloak.duplicate()
	cloak_closed.append(cloak[0])
	var cloak_col := Color(0.30, 0.04, 0.10, 0.97) if enraged else Color(0.22, 0.05, 0.13, 0.97)
	canvas.draw_colored_polygon(cloak, cloak_col)
	canvas.draw_polyline(cloak_closed, gold, lw, true)
	# Hood shadow
	canvas.draw_circle(root_pos + Vector2(0.0, -30.0) * scale_f, 30.0 * scale_f, Color(0.05, 0.01, 0.04, 0.92))
	# Gold lapel trim
	canvas.draw_line(root_pos + Vector2(-14.0, 0.0) * scale_f, root_pos + Vector2(0.0, 30.0) * scale_f, gold, lw, true)
	canvas.draw_line(root_pos + Vector2(14.0, 0.0) * scale_f, root_pos + Vector2(0.0, 30.0) * scale_f, gold, lw, true)

	# 3. Porcelain Maestro mask
	_draw_story_maestro_mask(canvas, root_pos + Vector2(0.0, -30.0) * scale_f, 1.25 * scale_f, 3 if enraged else 1)

	# 4. Conducting arm & baton (sweeps harder when launching notes)
	var shoulder: Vector2 = root_pos + Vector2(34.0, -10.0) * scale_f
	var conduct: float = sin(t * 4.2 * rage_mult) * 0.55 + (_boss_throw_anim * 0.9 if not is_preview else 0.0)
	var arm_ang: float = -0.75 - conduct
	var hand: Vector2 = shoulder + Vector2(cos(arm_ang), sin(arm_ang)) * 30.0 * scale_f
	var baton_tip: Vector2 = hand + Vector2(cos(arm_ang - 0.35), sin(arm_ang - 0.35)) * 32.0 * scale_f
	canvas.draw_line(shoulder, hand, cloak_col.lightened(0.15), maxf(2.0, 8.0 * scale_f), true)
	canvas.draw_circle(hand, 5.0 * scale_f, Color(0.95, 0.92, 0.88, 0.98))
	canvas.draw_line(hand, baton_tip, Color(1.0, 1.0, 1.0, 0.98), maxf(1.0, 2.4 * scale_f), true)
	canvas.draw_circle(baton_tip, 4.5 * scale_f, Color(1.0, 0.85, 0.35, 0.55 + 0.35 * absf(sin(t * 6.0))))
	# Off-hand
	var shoulder_l: Vector2 = root_pos + Vector2(-34.0, -10.0) * scale_f
	var hand_l: Vector2 = shoulder_l + Vector2(-22.0, 14.0 + sin(t * 2.2) * 6.0) * scale_f
	canvas.draw_line(shoulder_l, hand_l, cloak_col.lightened(0.15), maxf(2.0, 8.0 * scale_f), true)
	canvas.draw_circle(hand_l, 5.0 * scale_f, Color(0.95, 0.92, 0.88, 0.98))

	# 5. Four floating instruments (BELL / DRUM / HARP / HORN), colored by the live board colors
	var bob1: float = sin(t * 3.0) * 5.0 * scale_f
	var bob2: float = sin(t * 3.0 + 2.0) * 5.0 * scale_f
	var bob3: float = sin(t * 3.0 + 4.0) * 5.0 * scale_f
	var up_c: Vector2 = root_pos + Vector2(0.0, -90.0 * scale_f - float(rec["up"]) - death_split + bob1)
	var down_c: Vector2 = root_pos + Vector2(0.0, 58.0 * scale_f + float(rec["down"]) + death_split + bob2 * 0.5)
	var left_c: Vector2 = root_pos + Vector2(-112.0 * scale_f - float(rec["left"]) - death_split, -4.0 * scale_f + bob2)
	var right_c: Vector2 = root_pos + Vector2(112.0 * scale_f + float(rec["right"]) + death_split, -4.0 * scale_f + bob3)

	# BELL (up) — swinging
	var bell_rot: float = sin(t * 4.5) * 0.28
	var bell_pts_local: Array[Vector2] = [
		Vector2(-6, -18), Vector2(6, -18), Vector2(10, -8), Vector2(12, 6),
		Vector2(20, 14), Vector2(-20, 14), Vector2(-12, 6), Vector2(-10, -8),
	]
	var bell := PackedVector2Array()
	for p: Vector2 in bell_pts_local:
		bell.append(up_c + p.rotated(bell_rot) * scale_f)
	var bell_closed := bell.duplicate()
	bell_closed.append(bell[0])
	canvas.draw_colored_polygon(bell, cols["up"])
	canvas.draw_polyline(bell_closed, Color(1.0, 1.0, 1.0, 0.32 if dead["up"] else 0.92), lw, true)
	canvas.draw_circle(up_c + Vector2(0, -21).rotated(bell_rot) * scale_f, 4.0 * scale_f, gold)
	canvas.draw_circle(up_c + Vector2(sin(t * 4.5 + 0.8) * 4.0, 18).rotated(bell_rot) * scale_f, 4.5 * scale_f, Color(1.0, 1.0, 1.0, 0.35 if dead["up"] else 0.95))

	# DRUM (down)
	var drum_body := PackedVector2Array([
		down_c + Vector2(-26, -8) * scale_f, down_c + Vector2(26, -8) * scale_f,
		down_c + Vector2(24, 14) * scale_f, down_c + Vector2(-24, 14) * scale_f,
	])
	canvas.draw_colored_polygon(drum_body, cols["down"])
	var drum_top := PackedVector2Array()
	for i in range(18):
		var a: float = float(i) / 18.0 * TAU
		drum_top.append(down_c + Vector2(cos(a) * 26.0, -8.0 + sin(a) * 6.0) * scale_f)
	canvas.draw_colored_polygon(drum_top, cols["down"].lightened(0.35))
	var drum_top_closed := drum_top.duplicate()
	drum_top_closed.append(drum_top[0])
	var drum_line := Color(1.0, 1.0, 1.0, 0.32 if dead["down"] else 0.92)
	canvas.draw_polyline(drum_top_closed, drum_line, lw, true)
	canvas.draw_polyline(PackedVector2Array([
		down_c + Vector2(-24, -2) * scale_f, down_c + Vector2(-12, 12) * scale_f, down_c + Vector2(0, -2) * scale_f,
		down_c + Vector2(12, 12) * scale_f, down_c + Vector2(24, -2) * scale_f,
	]), drum_line, maxf(1.0, 1.8 * scale_f), true)
	if not dead["down"]:
		var stick_hit: float = absf(sin(t * 7.0 * rage_mult)) * 8.0
		canvas.draw_line(down_c + Vector2(-30, -26 + stick_hit) * scale_f, down_c + Vector2(-8, -10) * scale_f, gold, maxf(1.0, 2.2 * scale_f), true)
		canvas.draw_line(down_c + Vector2(30, -26 + (8.0 - stick_hit)) * scale_f, down_c + Vector2(8, -10) * scale_f, gold, maxf(1.0, 2.2 * scale_f), true)

	# HARP (left)
	var harp_frame := PackedVector2Array([
		left_c + Vector2(-14, 24) * scale_f, left_c + Vector2(-14, -26) * scale_f,
		left_c + Vector2(4, -20) * scale_f, left_c + Vector2(18, -8) * scale_f,
		left_c + Vector2(18, 24) * scale_f, left_c + Vector2(-14, 24) * scale_f,
	])
	canvas.draw_polyline(harp_frame, cols["left"], maxf(2.0, 6.0 * scale_f), true)
	canvas.draw_polyline(harp_frame, Color(1.0, 1.0, 1.0, 0.25 if dead["left"] else 0.70), maxf(0.8, 1.4 * scale_f), true)
	for i in range(1, 5):
		var sx: float = -14.0 + float(i) * 6.4
		var top_y: float = -26.0 + (sx + 14.0) / 32.0 * 18.0
		var vib: float = (sin(t * 22.0 + float(i)) * 1.2) if not dead["left"] else 0.0
		canvas.draw_line(left_c + Vector2(sx, top_y) * scale_f, left_c + Vector2(sx + vib, 22.0) * scale_f, Color(1.0, 0.95, 0.80, 0.30 if dead["left"] else 0.85), maxf(0.8, 1.2 * scale_f), true)

	# HORN (right)
	var horn := PackedVector2Array([
		right_c + Vector2(-20, -4) * scale_f, right_c + Vector2(4, -9) * scale_f,
		right_c + Vector2(20, -20) * scale_f, right_c + Vector2(20, 20) * scale_f,
		right_c + Vector2(4, 9) * scale_f, right_c + Vector2(-20, 4) * scale_f,
	])
	var horn_closed := horn.duplicate()
	horn_closed.append(horn[0])
	canvas.draw_colored_polygon(horn, cols["right"])
	canvas.draw_polyline(horn_closed, Color(1.0, 1.0, 1.0, 0.32 if dead["right"] else 0.92), lw, true)
	canvas.draw_circle(right_c + Vector2(-23, 0) * scale_f, 4.0 * scale_f, gold)
	canvas.draw_line(right_c + Vector2(20, -20) * scale_f, right_c + Vector2(20, 20) * scale_f, gold, maxf(1.0, 3.0 * scale_f), true)

	# Mute slashes over silenced instruments
	if not is_preview:
		var centers: Dictionary = {"up": up_c, "down": down_c, "left": left_c, "right": right_c}
		for d: String in centers:
			if dead[d]:
				var pc: Vector2 = centers[d]
				canvas.draw_line(pc + Vector2(-18, -18) * scale_f, pc + Vector2(18, 18) * scale_f, Color(1.0, 0.30, 0.38, 0.85), maxf(1.5, 3.0 * scale_f), true)

	# 6. Orbiting music notes
	for i in range(4):
		var a: float = t * 1.1 * rage_mult + float(i) * TAU / 4.0
		var np: Vector2 = root_pos + Vector2(cos(a) * 70.0, sin(a) * 34.0 - 18.0) * scale_f
		var n_col := Color(1.0, 0.40, 0.45, 0.75) if enraged else Color(1.0, 0.88, 0.50, 0.72)
		_draw_story_music_note(canvas, np, 0.85 * scale_f, n_col)
