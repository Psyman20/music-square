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
@onready var share_score_btn: Button = $GameOverScreen/GameOverPanel/ShareScoreBtn
@onready var go_menu_btn: Button = $GameOverScreen/GameOverPanel/GameOverMenuBtn

# --- Tutorial Nodes ---
@onready var tutorial_understood_btn: Button = $TutorialScreen/TutorialPanel/TutorialUnderstoodBtn

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
var _last_displayed_lives: int = GameSettings.MAX_LIVES
var _heart_throb_tween: Tween
var _lives_bezel_style: StyleBoxFlat
var _song_player: AudioStreamPlayer

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
var _reset_game_btn: Button
var _reset_confirm_modal: Control
var _tutorial_return_state: GameSettings.GameState = GameSettings.GameState.PLAYING

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


func _ready() -> void:
	_init_secure_score()
	direction_squares = {
		"up": up_square, "down": down_square,
		"left": left_square, "right": right_square,
	}
	for dir: String in direction_squares:
		direction_squares[dir].set_meta("dir", dir)
	center_square.set_meta("dir", "")
	direction_colors = _get_theme().get("board", {}).duplicate()

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

	# Songs / unlocks UI (SONGS button + selection screen).
	_setup_songs_ui()

	# Themes / unlocks UI (THEMES button + selection screen).
	_setup_themes_ui()

	# Options UI (OPTIONS button + options overlay screen).
	_setup_options_ui()

	# Badges / Achievements UI (BADGES button + overlay screen).
	_setup_badges_ui()

	# Tutorial visual UI setup
	_setup_tutorial_ui()

	# Show menu
	_show_menu()

	# Setup initial state
	_setup_initial_game_state()


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
	if _bg_shader_mat == null:
		return
	var bg: Dictionary = _get_theme().get("bg", {})
	for key: String in bg:
		_bg_shader_mat.set_shader_parameter(key, bg[key])


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

	_apply_style_colors()


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

	_center_panel_style.bg_color = direction_colors["up"]
	center_square.add_theme_stylebox_override("panel", _center_panel_style)
	center_square.pivot_offset = Vector2(50, 50)

	# Center pivot for the board container so remap pop animates from its center
	var board: Control = $GameScreen/Board
	board.pivot_offset = board.size / 2.0


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


func _apply_board_colors() -> void:
	var frenzy_gold := Color(1.35, 1.15, 0.15)

	for dir: String in direction_squares:
		var panel: Panel = direction_squares[dir]
		var style := _panel_style.duplicate()
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
			else:
				# Square has no direction color — dark neutral background with glowing border
				style.bg_color = Color(0.12, 0.10, 0.22, 0.9)
				style.set_border_color(Color(1.5, 1.3, 0.2, 0.9))
				style.set_shadow_color(Color(1.0, 0.8, 0.1, 0.5))
				style.set_shadow_size(12)
		elif is_hold_turn and dir == current_target_direction:
			style.bg_color = direction_colors[dir]
			style.set_border_width_all(3)
			style.set_border_color(Color(0.2, 0.95, 1.0, 0.95))
			style.set_shadow_color(Color(0.2, 0.9, 1.0, 0.65))
			style.set_shadow_size(16)
		else:
			style.bg_color = direction_colors[dir]
		panel.add_theme_stylebox_override("panel", style)
		panel.queue_redraw()

	if center_square != null:
		if is_frenzy_active:
			var c_style := _center_panel_style.duplicate()
			c_style.bg_color = frenzy_gold
			c_style.set_border_width_all(3)
			c_style.set_border_color(FRENZY_SPECIAL_COLOR)
			c_style.set_shadow_color(Color(1.8, 0.2, 0.85, 0.5))
			c_style.set_shadow_size(14)
			center_square.add_theme_stylebox_override("panel", c_style)
		elif is_hold_turn:
			var c_style := _center_panel_style.duplicate()
			c_style.bg_color = _last_target_color
			c_style.set_border_width_all(3)
			c_style.set_border_color(Color(0.2, 0.95, 1.0, 0.95))
			c_style.set_shadow_color(Color(0.2, 0.9, 1.0, 0.65))
			c_style.set_shadow_size(16)
			center_square.add_theme_stylebox_override("panel", c_style)
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
	$PauseScreen/PausePanel.add_theme_stylebox_override("panel", _pause_panel_style)
	$GameOverScreen/GameOverPanel.add_theme_stylebox_override("panel", _pause_panel_style)
	$TutorialScreen/TutorialPanel.add_theme_stylebox_override("panel", _pause_panel_style)

	# Tutorial panel slightly darker
	var tut_style := _pause_panel_style.duplicate()
	tut_style.bg_color = Color(0.15, 0.13, 0.25, 0.95)
	$TutorialScreen/TutorialPanel.add_theme_stylebox_override("panel", tut_style)


func _setup_button_styles() -> void:
	var accent := _theme_accent()
	var buttons := [start_button, resume_btn, restart_btn, pause_menu_btn, retry_btn, share_score_btn, go_menu_btn, pause_button, revive_btn, tutorial_understood_btn]
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


func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	pause_menu_btn.pressed.connect(_on_go_menu_pressed)
	revive_btn.pressed.connect(_on_revive_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	if share_score_btn != null:
		share_score_btn.pressed.connect(_on_share_score_pressed)
	go_menu_btn.pressed.connect(_on_go_menu_pressed)
	if tutorial_understood_btn != null:
		tutorial_understood_btn.pressed.connect(_on_tutorial_understood_pressed)


func _setup_initial_game_state() -> void:
	_init_secure_score()
	lives = settings.MAX_LIVES
	_last_displayed_lives = settings.MAX_LIVES
	_has_revived_this_game = false
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
	_play_selected_song()


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
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_song_player.stream = stream
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
	_songs_button.flat = true
	_songs_button.anchor_left = 0.5
	_songs_button.anchor_right = 0.5
	_songs_button.offset_left = -120.0
	_songs_button.offset_right = 120.0
	_songs_button.offset_top = 545.0
	_songs_button.offset_bottom = 605.0
	_songs_button.add_theme_font_size_override("font_size", 28)
	_songs_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_songs_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_songs_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_songs_button.pressed.connect(_open_songs_screen)
	var songs_bg := ColorRect.new()
	songs_bg.name = "SongsButtonBg"
	songs_bg.anchor_right = 1.0
	songs_bg.anchor_bottom = 1.0
	songs_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	songs_bg.color = Color(1, 0.278, 0.341, 0.25)
	_songs_button.add_child(songs_bg)
	_songs_button.move_child(songs_bg, 0)
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
	_themes_button.flat = true
	_themes_button.anchor_left = 0.5
	_themes_button.anchor_right = 0.5
	_themes_button.offset_left = -120.0
	_themes_button.offset_right = 120.0
	_themes_button.offset_top = 620.0
	_themes_button.offset_bottom = 680.0
	_themes_button.add_theme_font_size_override("font_size", 28)
	_themes_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_themes_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_themes_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_themes_button.pressed.connect(_open_themes_screen)
	var themes_bg := ColorRect.new()
	themes_bg.name = "ThemesButtonBg"
	themes_bg.anchor_right = 1.0
	themes_bg.anchor_bottom = 1.0
	themes_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	themes_bg.color = Color(1, 0.278, 0.341, 0.25)
	_themes_button.add_child(themes_bg)
	_themes_button.move_child(themes_bg, 0)
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
	var unlock: int = int(theme_def.get("unlock_score", 0))
	var unlocked: bool = settings.is_theme_unlocked(theme_def)
	var selected: bool = theme_id == settings.selected_theme

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 20)

	if not unlocked:
		btn.disabled = true
		btn.text = theme_name + "\nUNLOCK AT SCORE " + str(unlock)
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
		btn.text = (">  " + theme_name) if selected else theme_name
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
		btn.pressed.connect(_select_theme.bind(theme_id))

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


# =====================================================
# OPTIONS UI
# =====================================================

func _setup_options_ui() -> void:
	# --- "OPTIONS" button under THEMES on the menu screen ---
	_options_button = Button.new()
	_options_button.name = "OptionsButton"
	_options_button.text = "OPTIONS"
	_options_button.flat = true
	_options_button.anchor_left = 0.5
	_options_button.anchor_right = 0.5
	_options_button.offset_left = -120.0
	_options_button.offset_right = 120.0
	_options_button.offset_top = 695.0
	_options_button.offset_bottom = 755.0
	_options_button.add_theme_font_size_override("font_size", 28)
	_options_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_options_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_options_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_options_button.pressed.connect(_open_options_screen)
	var options_bg := ColorRect.new()
	options_bg.name = "OptionsButtonBg"
	options_bg.anchor_right = 1.0
	options_bg.anchor_bottom = 1.0
	options_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_bg.color = Color(1, 0.278, 0.341, 0.25)
	_options_button.add_child(options_bg)
	_options_button.move_child(options_bg, 0)
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

	# --- HAPTIC VIBRATION TOGGLE BUTTON ---
	_haptics_toggle_btn = Button.new()
	_haptics_toggle_btn.name = "HapticsToggleBtn"
	_haptics_toggle_btn.anchor_left = 0.5
	_haptics_toggle_btn.anchor_right = 0.5
	_haptics_toggle_btn.offset_left = -150.0
	_haptics_toggle_btn.offset_right = 150.0
	_haptics_toggle_btn.offset_top = 282.0
	_haptics_toggle_btn.offset_bottom = 330.0
	_haptics_toggle_btn.add_theme_font_size_override("font_size", 18)
	_haptics_toggle_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_haptics_toggle_btn.pressed.connect(_on_haptics_toggle_pressed)
	panel.add_child(_haptics_toggle_btn)
	_options_non_zone_controls.append(_haptics_toggle_btn)
	_update_haptics_btn_style()

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
		_tutorial_return_state = GameSettings.GameState.MENU
		_setup_tutorial_ui()
		_set_state(settings.GameState.TUTORIAL)
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
	_apply_theme()
	_apply_board_position()
	_play_selected_song()
	_close_reset_confirm_modal()
	_close_options_screen()
	_show_remap_banner("GAME DATA RESET")
	_update_high_score_display()
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
	# 1. BASIC SWIPES CARD
	# -------------------------------------------------------------
	var swipe_card := _create_tutorial_card(Color(0.08, 0.12, 0.22, 0.95), Color(0.25, 0.75, 1.0, 0.9), 260.0)
	vbox.add_child(swipe_card)

	var swipe_title := _create_tutorial_card_title("1. BASIC SWIPES & COMBO", Color(0.3, 0.85, 1.0))
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
		"* Fast swipes award Speed Bonus points before time shrinks!\n" +
		"* Build streaks for up to 4x COMBO multiplier!"
	)
	swipe_desc.offset_left = 16.0
	swipe_desc.offset_right = -16.0
	swipe_desc.offset_top = 174.0
	swipe_desc.offset_bottom = 250.0
	swipe_card.add_child(swipe_desc)

	# -------------------------------------------------------------
	# 2. HOLD SQUARES (NEW MECHANIC)
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
		"* When a glowing countdown ring appears on the board:\n" +
		"* Swipe & HOLD your finger in that direction!\n" +
		"* Charge up to 2 SECONDS for MASSIVE points!\n" +
		"* Auto-completes when charged or upon finger release."
	)
	hold_desc.offset_left = 68.0
	hold_desc.offset_right = -14.0
	hold_desc.offset_top = 36.0
	hold_desc.offset_bottom = 185.0
	hold_card.add_child(hold_desc)

	# -------------------------------------------------------------
	# 3. FRENZY POWER-UP & PINK 3X SQUARE
	# -------------------------------------------------------------
	var frenzy_card := _create_tutorial_card(Color(0.18, 0.12, 0.04, 0.95), Color(1.0, 0.85, 0.1, 0.9), 195.0)
	vbox.add_child(frenzy_card)

	var frenzy_title := _create_tutorial_card_title("3. FRENZY POWER-UP (LIGHTNING)", Color(1.0, 0.9, 0.2))
	frenzy_card.add_child(frenzy_title)

	var frenzy_icon := Panel.new()
	frenzy_icon.size = Vector2(44, 44)
	frenzy_icon.position = Vector2(14, 42)
	frenzy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frenzy_icon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frenzy_icon.draw.connect(func(): _draw_powerup_icon(frenzy_icon, "frenzy"))
	frenzy_card.add_child(frenzy_icon)

	var frenzy_desc := _create_tutorial_card_body(
		"* Swipe toward the LIGHTNING BOLT to trigger 5s Frenzy!\n" +
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
	# 4. FRENZY TIME BOOSTER (+5s STACKABLE - NEW MECHANIC)
	# -------------------------------------------------------------
	var boost_card := _create_tutorial_card(Color(0.06, 0.16, 0.22, 0.95), Color(0.2, 0.95, 1.0, 0.95), 195.0)
	vbox.add_child(boost_card)

	var boost_title := _create_tutorial_card_title("4. TIME BOOSTER (+5s CHARGES)", Color(0.2, 0.95, 1.0))
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
	# 5. SHUFFLE & SURVIVAL CARD
	# -------------------------------------------------------------
	var shuffle_card := _create_tutorial_card(Color(0.14, 0.10, 0.20, 0.95), Color(0.85, 0.5, 1.0, 0.85), 165.0)
	vbox.add_child(shuffle_card)

	var shuffle_title := _create_tutorial_card_title("5. SHUFFLE & EXTRA LIVES", Color(0.9, 0.65, 1.0))
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
	# 6. PHOTOSENSITIVITY & EPILEPSY WARNING
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

	# Achievement unlocked header label
	var header := Label.new()
	header.text = "BADGE UNLOCKED!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", ach_color)
	header.position = Vector2(74, 14)
	header.size = Vector2(294, 18)
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
	# --- "BADGES" button under OPTIONS on the menu screen ---
	_badges_button = Button.new()
	_badges_button.name = "BadgesButton"
	_badges_button.text = "BADGES"
	_badges_button.flat = true
	_badges_button.anchor_left = 0.5
	_badges_button.anchor_right = 0.5
	_badges_button.offset_left = -120.0
	_badges_button.offset_right = 120.0
	_badges_button.offset_top = 770.0
	_badges_button.offset_bottom = 830.0
	_badges_button.add_theme_font_size_override("font_size", 28)
	_badges_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_badges_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_badges_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_badges_button.pressed.connect(_open_badges_screen)
	var badges_bg := ColorRect.new()
	badges_bg.name = "BadgesButtonBg"
	badges_bg.anchor_right = 1.0
	badges_bg.anchor_bottom = 1.0
	badges_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badges_bg.color = Color(1.0, 0.85, 0.15, 0.20)
	_badges_button.add_child(badges_bg)
	_badges_button.move_child(badges_bg, 0)
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
	_set_state(settings.GameState.MENU)


func _start_game() -> void:
	_setup_initial_game_state()
	_set_state(settings.GameState.PLAYING)
	_update_high_score_display()

	if settings.first_play:
		settings.first_play = false
		settings.save_data()
		_set_state(settings.GameState.TUTORIAL)
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
		_haptic_celebration()

	frenzy_charges = 0
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
	stats_label.text = "Streak: %d   |   Accuracy: %d%%\nCorrect: %d / %d   |   Fastest: %s\nFrenzies: %d   |   Max Hold: %s" % [
		best_streak_this_game,
		int(round(accuracy)),
		total_correct,
		total_swipes,
		best_rx_str,
		frenzies_triggered_this_game,
		hold_str
	]
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_constant_override("line_spacing", 4)
	if _tamper_flagged:
		stats_label.text += "\n[SECURITY: RUN DISQUALIFIED]"

	_board_aura_tier = 0
	if _board_aura_panel != null and is_instance_valid(_board_aura_panel):
		_board_aura_panel.queue_redraw()

	# Animate score count-up
	_animate_score_countup(final_score_label, score, 1.2)

	# Configure revive button (can only revive once per game run)
	if revive_btn != null:
		revive_btn.visible = not _has_revived_this_game
		revive_btn.disabled = false

	# Check achievements (only on legitimate, non-tampered runs)
	if not _tamper_flagged:
		_check_achievements(accuracy)


func _restart_game() -> void:
	_fade_transition(_start_game)


func _go_to_menu() -> void:
	_fade_transition(_show_menu)


# =====================================================
# BUTTON CALLBACKS
# =====================================================

func _on_start_pressed() -> void:
	sfx.play("tap")
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


func _on_revive_pressed() -> void:
	sfx.play("tap")
	if revive_btn != null:
		revive_btn.disabled = true
	# Trigger simulated rewarded ad view / reward callback
	_show_rewarded_ad_and_revive()


func _show_rewarded_ad_and_revive() -> void:
	if has_node("/root/AdManager"):
		get_node("/root/AdManager").show_rewarded_ad(func():
			_has_revived_this_game = true
			_fade_transition(_revive_and_continue)
		)
	else:
		_has_revived_this_game = true
		_fade_transition(_revive_and_continue)


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
	_restart_game()


func _on_share_score_pressed() -> void:
	sfx.play("tap")
	_haptic_tap()
	_share_game_score()


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
		_bg_shader_mat.set_shader_parameter("audio_pulse", bg_pulse)
		_bg_shader_mat.set_shader_parameter("streak_energy", streak_energy)

	# --- Live Board Zone Preview Timer ---
	if _board_zone_preview_active and not _board_zone_dragging:
		_board_zone_preview_timer -= delta
		if _board_zone_preview_timer <= 0.0:
			_exit_board_zone_preview()


func _process(delta: float) -> void:
	# Continuous visual juice processing (swipe trail decay, board aura animations, music-reactive shader)
	_process_visual_juice(delta)

	if state != settings.GameState.PLAYING:
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
			if hold_duration >= 1.9:
				_hold_pts_label.text = "⚡ MAXIMUM CHARGE! +" + _format_number_with_commas(current_pts * mult) + " PTS ⚡"
				_hold_pts_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
			else:
				_hold_pts_label.text = "HOLD CHARGE: " + str(snappedf(hold_duration, 0.1)) + "s / 2s  |  +" + _format_number_with_commas(current_pts * mult) + " PTS"

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

	if is_frenzy_active:
		frenzy_time_left -= delta
		frenzy_switch_timer += delta
		if frenzy_switch_timer >= 1.0:
			frenzy_switch_timer -= 1.0
			_pick_new_frenzy_special_square()

		if _frenzy_hud_label != null and is_instance_valid(_frenzy_hud_label):
			_frenzy_hud_label.text = "⚡ FRENZY: " + str(snappedf(maxf(0.0, frenzy_time_left), 0.1)) + "s  |  PINK = 3x! ⚡"

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

		# Redraw hold square pulsing ring if this is a hold turn
		if is_hold_turn:
			if center_square != null and is_instance_valid(center_square):
				center_square.queue_redraw()
			if current_target_direction in direction_squares:
				var target_panel: Panel = direction_squares[current_target_direction]
				if target_panel != null and is_instance_valid(target_panel):
					target_panel.queue_redraw()

		# Timeout check
		if time_left_in_turn <= 0.0:
			_on_turn_timeout()


func start_new_turn() -> void:
	if state != settings.GameState.PLAYING:
		return

	# Kill any in-flight center flash tween so its stale restore callback
	# can't overwrite the new target color we're about to set
	if _center_flash_tween is Tween:
		_center_flash_tween.kill()
		_center_flash_tween = null

	# 0. Direction remapping for advanced difficulty (only when NOT in frenzy)
	if not is_frenzy_active:
		turns_since_remap += 1
		if score >= settings.REMAP_SCORE_THRESHOLD and turns_since_remap >= turns_until_remap:
			turns_since_remap = 0
			turns_until_remap = _roll_remap_interval()
			_remap_directions()

	# 1. Reset previous turn's uncollected power-up and hold state
	powerup_square_dir = ""
	powerup_type = ""
	_cleanup_hold_ui()
	is_holding_active = false
	hold_duration = 0.0

	# 2. Constant time limit
	current_time_limit = settings.INITIAL_TIME_LIMIT
	time_left_in_turn = current_time_limit
	_turn_start_time = Time.get_ticks_msec() / 1000.0

	# 3. Set new target color
	set_random_center_color()

	# 4. Special Turn Mechanics: Frenzy, Frenzy +5s Booster, or Hold Turn (MUTUALLY EXCLUSIVE)
	# Neither can spawn if Frenzy Mode is currently running, and only one special event can appear per turn.
	is_hold_turn = false
	if not is_frenzy_active:
		var roll := randf()
		# Roll 1: Frenzy trigger power-up (~2% chance)
		if roll < 0.02:
			var center_color: Color = direction_colors.get(current_target_direction, Color(0, 0, 0, 0))
			var valid_dirs: Array = direction_squares.keys().filter(
				func(d: String) -> bool:
					return not direction_colors[d].is_equal_approx(center_color)
			)
			if valid_dirs.size() > 0:
				powerup_square_dir = valid_dirs.pick_random()
				powerup_type = "frenzy"
				is_hold_turn = false
		# Roll 2: Frenzy +5s Time Booster (5% chance: roll between 0.02 and 0.07)
		elif roll < 0.07:
			var center_color: Color = direction_colors.get(current_target_direction, Color(0, 0, 0, 0))
			var valid_dirs: Array = direction_squares.keys().filter(
				func(d: String) -> bool:
					return not direction_colors[d].is_equal_approx(center_color)
			)
			if valid_dirs.size() > 0:
				powerup_square_dir = valid_dirs.pick_random()
				powerup_type = "frenzy_boost"
				is_hold_turn = false
		# Roll 3: Hold Turn (5% chance: roll between 0.07 and 0.12)
		elif roll < 0.12:
			is_hold_turn = true
			current_time_limit = 2.4
			time_left_in_turn = current_time_limit
			_setup_hold_turn_indicator()

	# 5. Apply board colors and symbols
	_apply_board_colors()

	# 6. Pulse animation on center square
	_pulse_center()


func set_random_center_color() -> void:
	if is_frenzy_active:
		var frenzy_style := _center_panel_style.duplicate()
		frenzy_style.bg_color = Color(1.35, 1.15, 0.15)
		center_square.add_theme_stylebox_override("panel", frenzy_style)
		center_square.queue_redraw()
		return

	var directions := direction_colors.keys()
	var candidates: Array = directions.filter(func(d): return direction_colors[d] != _last_target_color)
	if candidates.size() > 0:
		directions = candidates

	current_target_direction = directions.pick_random()
	_last_target_color = direction_colors[current_target_direction]

	var style := _center_panel_style.duplicate()
	style.bg_color = _last_target_color
	center_square.add_theme_stylebox_override("panel", style)
	center_square.queue_redraw()


func _activate_frenzy_mode() -> void:
	is_frenzy_active = true
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
	_cleanup_hold_ui()
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
	_haptic_frenzy()

	if consumed_charges > 0:
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
	var colors: Array = direction_colors.values()
	var original := colors.duplicate()

	var attempts := 0
	while attempts < 10:
		colors.shuffle()
		if colors != original:
			break
		attempts += 1

	var keys: Array = direction_colors.keys()
	for i in range(keys.size()):
		direction_colors[keys[i]] = colors[i]

	_remaps_survived_this_game += 1
	_check_in_game_achievements()

	sfx.play("remap")
	_haptic_shuffle()
	_flash_remap_squares()
	_show_remap_banner("SHUFFLED!")


func _flash_remap_squares() -> void:
	# Instant white flash on all four squares...
	for dir: String in direction_squares:
		var panel: Panel = direction_squares[dir]
		var flash_style := _panel_style.duplicate()
		flash_style.bg_color = Color(1, 1, 1, 0.9)
		panel.add_theme_stylebox_override("panel", flash_style)

	# ...then reveal the newly shuffled colors a beat later
	var tween := create_tween()
	tween.tween_callback(_apply_board_colors).set_delay(0.15)

	# Bounce the whole board for extra emphasis
	var board: Control = $GameScreen/Board
	var board_tween := create_tween()
	board_tween.set_trans(Tween.TRANS_BACK)
	board_tween.set_ease(Tween.EASE_OUT)
	board_tween.tween_property(board, "scale", Vector2(1.1, 1.1), 0.12)
	board_tween.tween_property(board, "scale", Vector2.ONE, 0.18)


func _show_remap_banner(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
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
	label.offset_left = 0.0
	label.offset_right = 0.0
	var mid_y: float = _get_hud_mid_zone_y()
	label.offset_top = mid_y - 25.0
	label.offset_bottom = mid_y + 25.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.pivot_offset = Vector2(270, 25)
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
		_hold_indicator_label.text = "⚡ HOLD & CHARGE! ⚡"
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
	_check_in_game_achievements()

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
	# Handle game swipes only during PLAYING state
	if state == settings.GameState.PLAYING:
		_handle_game_input(event)


func _handle_game_input(event: InputEvent) -> void:
	# 0. Block input during post-hold grace cooldown to prevent accidental swipes
	if hold_exit_buffer > 0.0:
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
	if is_swiping and (event is InputEventMouseMotion or event is InputEventScreenDrag):
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
			if is_swiping:
				return
			active_touch_index = event.index
			touch_start_position = event.position
			is_swiping = true
			_trail_points.clear()
			_trail_points.append({"pos": event.position, "time": Time.get_ticks_msec() / 1000.0})
		elif is_swiping and event.index == active_touch_index:
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

	# Ignore swipes during post-frenzy or post-hold grace buffer
	if frenzy_exit_buffer > 0.0 or hold_exit_buffer > 0.0:
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

		# Activate frenzy mode BEFORE _on_correct_swipe so all styles & flash callbacks evaluate with is_frenzy_active == true
		if p_type == "frenzy":
			_activate_frenzy_mode()
		elif p_type == "frenzy_boost":
			_add_frenzy_charge()

		_on_correct_swipe(direction, is_powerup_hit, p_type)
	else:
		_on_wrong_swipe(direction)


func _on_correct_swipe(swiped_dir: String = "", is_powerup: bool = false, powerup_hit_type: String = "") -> void:
	var is_super_frenzy_hit: bool = (is_frenzy_active and swiped_dir != "" and swiped_dir == frenzy_special_dir)

	var speed_ratio := time_left_in_turn / current_time_limit
	var base_pts: int
	if is_super_frenzy_hit:
		base_pts = 250
	elif is_frenzy_active:
		base_pts = 100
	else:
		base_pts = settings.BASE_CORRECT_POINTS

	var earned: int = base_pts + int(speed_ratio * settings.SPEED_BONUS_MAX)

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

	score += earned
	total_correct += 1
	if total_swipes < total_correct:
		total_swipes = total_correct

	# Track lightning-fast responses (turn solved in under 0.40s)
	if (current_time_limit - time_left_in_turn) <= 0.40:
		_fast_swipes_this_game += 1

	# Track clutch streak on 1 heart
	if lives == 1:
		_clutch_swipes_this_game += 1
	else:
		_clutch_swipes_this_game = 0

	# Track fastest reaction time this game
	var reaction_time: float = (Time.get_ticks_msec() / 1000.0) - _turn_start_time
	if reaction_time > 0.03 and reaction_time < fastest_reaction_this_game:
		fastest_reaction_this_game = reaction_time

	# Audio pulse impulse for background synthwave shader
	_audio_pulse = minf(1.0, _audio_pulse + 0.65)

	# Combo level-up flash + HUD refresh
	if streak > 0 and streak % settings.COMBO_HITS_PER_LEVEL == 0 and mult < settings.COMBO_MAX_MULTIPLIER:
		_combo_level_up_flash()
	_update_combo_hud()
	_update_streak_visuals()

	# In-game achievement verification
	_check_in_game_achievements()

	# Sound & Haptics
	if powerup_hit_type == "frenzy_boost":
		sfx.play("unlock")
		_haptic_celebration()
	elif is_super_frenzy_hit:
		sfx.play("unlock")
		_haptic_celebration()
	elif is_frenzy_active or is_powerup:
		sfx.play("combo")
		_haptic_combo()
	else:
		sfx.play("correct")
		var is_combo_hit := streak > 0 and streak % 5 == 0
		if is_combo_hit:
			sfx.play("combo")
			_haptic_combo()
		else:
			_haptic_correct()

	# Visual feedback
	var target_dir := swiped_dir if swiped_dir != "" else current_target_direction
	var square_center := _get_board_center(target_dir)

	var popup_text := "+" + _format_number_with_commas(earned)
	if powerup_hit_type == "frenzy_boost":
		popup_text = "⚡ +5s FRENZY CHARGE! ⚡"
	elif is_super_frenzy_hit:
		var total_mult := mult * 3
		popup_text = "⚡ SUPER! +" + _format_number_with_commas(earned) + " x" + str(total_mult) + " ⚡"
	elif is_frenzy_active:
		var total_mult := mult * 2
		popup_text += " x" + str(total_mult) + "!"
	elif is_powerup:
		popup_text = "FRENZY!"
	elif mult > 1:
		popup_text += " x" + str(mult)

	var popup_color: Color
	if powerup_hit_type == "frenzy_boost":
		popup_color = Color(0.2, 0.95, 1.0, 1.0)
	elif is_super_frenzy_hit:
		popup_color = FRENZY_SPECIAL_COLOR
	elif is_frenzy_active or is_powerup:
		popup_color = Color(1.8, 1.4, 0.2, 1.0)
	else:
		var is_combo_hit := streak > 0 and streak % 5 == 0
		popup_color = Color(1.5, 0.35, 0.85, 1.0) if is_combo_hit else Color(0.15, 0.95, 1.0, 1.0)

	var flash_color: Color
	if powerup_hit_type == "frenzy_boost":
		flash_color = Color(0.2, 0.95, 1.0, 0.95)
	elif is_super_frenzy_hit:
		flash_color = Color(2.0, 0.5, 1.4, 0.9)
	else:
		flash_color = Color(1, 1, 1, 0.6)
	_flash_square(target_dir, flash_color)

	_show_persistent_label(popup_text, square_center, popup_color, is_frenzy_active or is_powerup)

	var particle_color: Color
	if powerup_hit_type == "frenzy_boost":
		particle_color = Color(0.2, 0.95, 1.0)
	elif is_super_frenzy_hit:
		particle_color = FRENZY_SPECIAL_COLOR
	elif is_frenzy_active or is_powerup:
		particle_color = Color(1.2, 0.9, 0.1)
	else:
		particle_color = direction_colors.get(target_dir, Color.WHITE)

	_burst_particles(square_center, particle_color, 16 if is_super_frenzy_hit else (10 if (is_frenzy_active or is_powerup) else 6))
	_burst_at(square_center, particle_color)
	_bounce_label(score_label)

	# If super frenzy square was hit, immediately pick a new random special square and reset the 1s timer!
	if is_super_frenzy_hit:
		_pick_new_frenzy_special_square()
		frenzy_switch_timer = 0.0

	update_score_display()
	start_new_turn()


func _on_wrong_swipe(_wrong_dir: String) -> void:
	_cleanup_hold_ui()
	is_holding_active = false
	is_hold_turn = false
	_center_scale_locked = false

	lives -= 1
	_lost_heart_this_game = true
	streak = 0
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
	is_holding_active = false
	is_hold_turn = false
	_center_scale_locked = false

	lives -= 1
	_lost_heart_this_game = true
	streak = 0
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

	# Parametric heart polygon points
	var num_pts := 32
	var heart_pts := PackedVector2Array()
	heart_pts.resize(num_pts)
	var radius := minf(panel_size.x, panel_size.y) * 0.42

	for k in range(num_pts):
		var t := (k / float(num_pts)) * TAU
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var pt := center + Vector2(x * (radius / 16.0), (y - 5.5) * (radius / 16.0))
		heart_pts[k] = pt

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
	_center_scale_locked = true
	match direction:
		"up", "down":
			center_square.scale = Vector2(0.72, 1.35)
		"left", "right":
			center_square.scale = Vector2(1.35, 0.72)


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
	var panel: Panel = direction_squares[direction]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	var flash_style := _panel_style.duplicate()
	flash_style.bg_color = flash_color
	var captured_panel := panel
	# Apply flash immediately, then restore via full board refresh so it
	# always matches the CURRENT (not stale) game state — fixes post-Frenzy
	# squares keeping the gold color.
	captured_panel.add_theme_stylebox_override("panel", flash_style)
	tween.tween_callback(_apply_board_colors).set_delay(0.08)


func _flash_center_red() -> void:
	# Kill any previous center flash tween so it can't restore a stale color
	if _center_flash_tween is Tween:
		_center_flash_tween.kill()
	var tween := create_tween()
	_center_flash_tween = tween
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	var red_style := _center_panel_style.duplicate()
	red_style.bg_color = Color(0.8, 0.1, 0.1)
	var captured_center := center_square
	# Apply red flash immediately, then restore via full board refresh so the
	# center square always reflects the CURRENT game state (not stale Frenzy Gold).
	captured_center.add_theme_stylebox_override("panel", red_style)
	tween.tween_callback(_apply_board_colors).set_delay(0.15)
	# Clear the tracked reference once the tween has fully finished
	tween.tween_callback(func(): _center_flash_tween = null)


func _fade_center_gray() -> void:
	var gray_style := _center_panel_style.duplicate()
	gray_style.bg_color = Color(0.4, 0.35, 0.45)
	center_square.add_theme_stylebox_override("panel", gray_style)

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
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.14, 1.0))
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100
	floating_container.add_child(label)

	var min_size := label.get_minimum_size()
	label.size = min_size
	label.position = pos - (min_size / 2.0)
	label.pivot_offset = min_size / 2.0

	var peak_scale := 1.4 if is_combo else 1.2
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
	_combo_bar.custom_minimum_size = Vector2(150, 14)
	_combo_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.set_corner_radius_all(7)
	bg_style.bg_color = Color(0.08, 0.06, 0.18, 0.9)
	bg_style.set_border_width_all(2)
	bg_style.set_border_color(Color(1, 1, 1, 0.25))
	_combo_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(7)
	fill_style.bg_color = Color(0.6, 0.9, 1.0)
	_combo_bar.add_theme_stylebox_override("fill", fill_style)

	_combo_container.add_child(_combo_bar)
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
	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(7)
	fill_style.bg_color = tier_color
	_combo_bar.add_theme_stylebox_override("fill", fill_style)


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

	# Neon-tube PLAY button: darker fill + bright legible text.
	var play_bg := $MenuScreen/StartButton/StartButtonBg
	if play_bg is ColorRect:
		play_bg.color = Color(0.85, 0.12, 0.38, 0.9)
	var start_btn := $MenuScreen/StartButton
	if start_btn is Button:
		start_btn.add_theme_color_override("font_color", Color(1.2, 1.2, 1.3))
		start_btn.add_theme_constant_override("outline_size", 6)
		start_btn.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.1, 1.0))
		start_btn.add_theme_constant_override("font_size", 34)
	# Gentle pulsing glow on the PLAY button to draw the eye.
	if play_bg is ColorRect:
		var tw := create_tween().set_loops()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(play_bg, "modulate:a", 0.65, 0.9)
		tw.tween_property(play_bg, "modulate:a", 1.0, 0.9)


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

		# Outer glowing neon stroke
		var outer_w := lerpf(4.0, 18.0, progress)
		var outer_col := Color(base_col.r, base_col.g, base_col.b, alpha * 0.45)
		_swipe_trail.draw_line(pos0, pos1, outer_col, outer_w, true)

		# Core bright white neon stroke
		var core_w := lerpf(1.5, 6.0, progress)
		var core_col := Color(1.0, 1.0, 1.0, alpha * 0.95)
		_swipe_trail.draw_line(pos0, pos1, core_col, core_w, true)

	# Glowing tip cursor
	var tip_pos: Vector2 = _trail_points[n - 1]["pos"]
	var tip_age: float = (now - float(_trail_points[n - 1]["time"])) / TRAIL_LIFETIME
	var tip_alpha: float = clampf(1.0 - tip_age, 0.0, 1.0)
	if tip_alpha > 0.05:
		_swipe_trail.draw_circle(tip_pos, 10.0, Color(base_col.r, base_col.g, base_col.b, tip_alpha * 0.5))
		_swipe_trail.draw_circle(tip_pos, 5.0, Color(1.0, 1.0, 1.0, tip_alpha * 0.95))


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
