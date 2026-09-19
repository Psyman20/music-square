extends Control

## Dynamic Interactive Walkthrough Overlay for Music Square
## Renders animated neon directional arrows, gesture guides (swipes & holds),
## step indicators, instructional cards, and feedback banners.

signal skip_pressed
signal start_play_pressed

var center_square: Panel = null
var direction_squares: Dictionary = {} # "up", "down", "left", "right" -> Panel

var step_index: int = 1 # 1..7
var target_dir: String = "right"
var is_hold: bool = false
var is_frenzy_practice: bool = false
var is_final_step: bool = false
var arcade_font: Font = null

# Child UI nodes
var _card_panel: Panel = null
var _margin_container: MarginContainer = null
var _vbox_container: VBoxContainer = null
var _badge_label: Label = null
var _desc_label: Label = null
var _dots_container: HBoxContainer = null
var _skip_btn: Button = null
var _play_btn: Button = null
var _prompt_label: Label = null
var _dot_panels: Array[Panel] = []

# Animation timers
var _prompt_tween: Tween = null
var _last_vp_size: Vector2 = Vector2.ZERO


func setup(center_sq: Panel, dir_sqs: Dictionary, font: Font = null) -> void:
	center_square = center_sq
	direction_squares = dir_sqs
	arcade_font = font

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_update_card_layout()


func _build_ui() -> void:
	# 1. Skip Button (Positioned at TOP-RIGHT of screen to avoid ANY text overlap)
	_skip_btn = Button.new()
	_skip_btn.name = "WalkthroughSkipBtn"
	_skip_btn.text = "SKIP ⏩"
	_skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_btn.add_theme_font_size_override("font_size", 12)
	_skip_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_skip_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_skip_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if arcade_font != null:
		_skip_btn.add_theme_font_override("font", arcade_font)

	var skip_style := StyleBoxFlat.new()
	skip_style.set_corner_radius_all(8)
	skip_style.bg_color = Color(0.08, 0.16, 0.28, 0.9)
	skip_style.set_border_width_all(1)
	skip_style.set_border_color(Color(0.25, 0.8, 1.0, 0.85))
	skip_style.set_shadow_color(Color(0.2, 0.8, 1.0, 0.3))
	skip_style.set_shadow_size(5)
	_skip_btn.add_theme_stylebox_override("normal", skip_style)

	var skip_hover := skip_style.duplicate() as StyleBoxFlat
	skip_hover.bg_color = Color(0.14, 0.28, 0.45, 0.95)
	skip_hover.set_border_color(Color(1.0, 1.0, 1.0, 0.95))
	_skip_btn.add_theme_stylebox_override("hover", skip_hover)
	_skip_btn.add_theme_stylebox_override("pressed", skip_hover)

	_skip_btn.pressed.connect(func(): skip_pressed.emit())
	add_child(_skip_btn)

	# 2. Main Instruction Card Panel (Positioned cleanly below the board)
	_card_panel = Panel.new()
	_card_panel.name = "WalkthroughCard"
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(16)
	card_style.bg_color = Color(0.05, 0.07, 0.16, 0.95)
	card_style.set_border_width_all(2)
	card_style.set_border_color(Color(0.2, 0.85, 1.0, 0.9))
	card_style.set_shadow_color(Color(0.1, 0.6, 1.0, 0.35))
	card_style.set_shadow_size(14)
	_card_panel.add_theme_stylebox_override("panel", card_style)
	add_child(_card_panel)

	# 3. Inside Card: MarginContainer + VBoxContainer for GUARANTEED non-overlapping layout
	_margin_container = MarginContainer.new()
	_margin_container.name = "CardMargin"
	_margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin_container.add_theme_constant_override("margin_left", 16)
	_margin_container.add_theme_constant_override("margin_right", 16)
	_margin_container.add_theme_constant_override("margin_top", 12)
	_margin_container.add_theme_constant_override("margin_bottom", 12)
	_card_panel.add_child(_margin_container)

	_vbox_container = VBoxContainer.new()
	_vbox_container.name = "CardVBox"
	_vbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox_container.add_theme_constant_override("separation", 8)
	_margin_container.add_child(_vbox_container)

	# 4. Badge Label: [ STEP 1 OF 6 • COLOR MATCH ]
	_badge_label = Label.new()
	_badge_label.name = "BadgeLabel"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 13)
	_badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_badge_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.18, 1.0))
	_badge_label.add_theme_constant_override("outline_size", 4)
	if arcade_font != null:
		_badge_label.add_theme_font_override("font", arcade_font)
	_vbox_container.add_child(_badge_label)

	# 5. Description Body Label
	_desc_label = Label.new()
	_desc_label.name = "DescLabel"
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_desc_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.12, 1.0))
	_desc_label.add_theme_constant_override("outline_size", 4)
	_desc_label.add_theme_constant_override("line_spacing", 3)
	if arcade_font != null:
		_desc_label.add_theme_font_override("font", arcade_font)
	_vbox_container.add_child(_desc_label)

	# 6. Step Progress Indicator Dots (Steps 1-6)
	_dots_container = HBoxContainer.new()
	_dots_container.name = "DotsContainer"
	_dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_container.custom_minimum_size = Vector2(0, 12)
	_dots_container.add_theme_constant_override("separation", 8)
	_vbox_container.add_child(_dots_container)

	_dot_panels.clear()
	for i in range(6):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 6)
		var dot_style := StyleBoxFlat.new()
		dot_style.set_corner_radius_all(3)
		dot_style.bg_color = Color(0.18, 0.22, 0.35, 0.8)
		dot.add_theme_stylebox_override("panel", dot_style)
		_dots_container.add_child(dot)
		_dot_panels.append(dot)

	# 7. Final Step Glowing Action Button: "LET'S PLAY!" or "BACK TO OPTIONS" (Step 7 only)
	_play_btn = Button.new()
	_play_btn.name = "WalkthroughPlayBtn"
	_play_btn.text = "LET'S PLAY! 🚀"
	_play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_play_btn.visible = false
	_play_btn.custom_minimum_size = Vector2(250, 42)
	_play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_btn.add_theme_font_size_override("font_size", 16)
	_play_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	_play_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if arcade_font != null:
		_play_btn.add_theme_font_override("font", arcade_font)

	var play_style := StyleBoxFlat.new()
	play_style.set_corner_radius_all(14)
	play_style.bg_color = Color(0.15, 0.48, 0.32, 0.95)
	play_style.set_border_width_all(3)
	play_style.set_border_color(Color(0.3, 1.0, 0.5, 0.95))
	play_style.set_shadow_color(Color(0.2, 1.0, 0.5, 0.5))
	play_style.set_shadow_size(14)
	_play_btn.add_theme_stylebox_override("normal", play_style)

	var play_hover := play_style.duplicate() as StyleBoxFlat
	play_hover.bg_color = Color(0.2, 0.65, 0.40, 1.0)
	play_hover.set_border_color(Color(1.0, 1.0, 1.0, 1.0))
	_play_btn.add_theme_stylebox_override("hover", play_hover)
	_play_btn.add_theme_stylebox_override("pressed", play_hover)

	_play_btn.pressed.connect(func(): start_play_pressed.emit())
	_vbox_container.add_child(_play_btn)

	# 8. Floating Prompt Banner for Live Feedback (Positioned above the card)
	_prompt_label = Label.new()
	_prompt_label.name = "WalkthroughPromptLabel"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.1, 1.0))
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.visible = false
	if arcade_font != null:
		_prompt_label.add_theme_font_override("font", arcade_font)
	add_child(_prompt_label)


func _update_card_layout() -> void:
	if _card_panel == null or not is_instance_valid(_card_panel):
		return

	var vp_rect := get_viewport_rect()
	var vp_w: float = vp_rect.size.x
	var vp_h: float = vp_rect.size.y
	if vp_w <= 0.0 or vp_h <= 0.0:
		return

	# Overlay covers the entire viewport
	size = vp_rect.size
	global_position = Vector2.ZERO

	# Position Skip Button at top-right (under lives HUD)
	if _skip_btn != null and is_instance_valid(_skip_btn):
		_skip_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var skip_x: float = maxf(10.0, vp_w - 110.0)
		_skip_btn.global_position = Vector2(skip_x, 72.0)
		_skip_btn.size = Vector2(96.0, 30.0)

	# Find bottom of the board squares
	var board_bottom: float = 650.0
	if direction_squares.has("down"):
		var down_sq: Panel = direction_squares["down"]
		if down_sq != null and is_instance_valid(down_sq):
			board_bottom = down_sq.global_position.y + down_sq.size.y

	# Calculate Card dimensions
	var card_w: float = clampf(vp_w - 32.0, 280.0, 500.0)
	var card_h: float = 165.0 if is_final_step else 145.0
	var card_x: float = (vp_w - card_w) / 2.0
	var card_y: float = board_bottom + 14.0
	if card_y + card_h > vp_h - 12.0:
		card_y = vp_h - card_h - 12.0

	_card_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card_panel.size = Vector2(card_w, card_h)
	_card_panel.global_position = Vector2(card_x, card_y)

	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var prompt_w: float = minf(460.0, vp_w - 20.0)
		_prompt_label.size = Vector2(prompt_w, 32.0)
		_prompt_label.global_position = Vector2((vp_w - prompt_w) / 2.0, maxf(10.0, card_y - 36.0))


func set_step(new_step: int, new_target: String, title: String, description: String, hold_mode: bool = false, frenzy_mode: bool = false) -> void:
	step_index = new_step
	target_dir = new_target
	is_hold = hold_mode
	is_frenzy_practice = frenzy_mode
	is_final_step = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _play_btn != null:
		_play_btn.visible = false
	if _dots_container != null:
		_dots_container.visible = true
	if _skip_btn != null:
		_skip_btn.visible = true

	if _badge_label != null:
		_badge_label.text = title
		_badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if not is_frenzy_practice else Color(1.0, 0.35, 0.85))
	if _desc_label != null:
		_desc_label.text = description

	_update_dots(new_step)
	_update_card_layout()
	queue_redraw()


func show_final_step(title: String, description: String, button_text: String = "LET'S PLAY! 🚀") -> void:
	step_index = 7
	target_dir = ""
	is_hold = false
	is_frenzy_practice = false
	is_final_step = true
	# Capture taps anywhere so player can tap screen to immediately proceed
	mouse_filter = Control.MOUSE_FILTER_STOP

	if _badge_label != null:
		_badge_label.text = title
		_badge_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))

	if _desc_label != null:
		_desc_label.text = description

	if _dots_container != null:
		_dots_container.visible = false

	if _skip_btn != null:
		_skip_btn.visible = false

	if _play_btn != null:
		_play_btn.text = button_text
		_play_btn.visible = true
		_play_btn.grab_focus()

	_update_card_layout()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if is_final_step:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			start_play_pressed.emit()
			accept_event()


func _update_dots(active_step: int) -> void:
	for i in range(_dot_panels.size()):
		var dot := _dot_panels[i]
		var style: StyleBoxFlat = dot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if i + 1 == active_step:
			# Active step: glowing cyan pill
			dot.custom_minimum_size = Vector2(28, 6)
			style.bg_color = Color(0.2, 0.95, 1.0, 1.0)
			style.set_shadow_color(Color(0.2, 0.95, 1.0, 0.6))
			style.set_shadow_size(6)
		elif i + 1 < active_step:
			# Completed step: solid calm blue
			dot.custom_minimum_size = Vector2(18, 6)
			style.bg_color = Color(0.3, 0.6, 0.9, 0.9)
			style.set_shadow_size(0)
		else:
			# Future step: dim slate
			dot.custom_minimum_size = Vector2(18, 6)
			style.bg_color = Color(0.16, 0.18, 0.28, 0.6)
			style.set_shadow_size(0)
		dot.add_theme_stylebox_override("panel", style)


func flash_success(text: String) -> void:
	_show_prompt(text, Color(0.2, 1.0, 0.55))


func flash_reminder(text: String) -> void:
	_show_prompt(text, Color(1.0, 0.85, 0.25))


func _show_prompt(text: String, col: Color) -> void:
	if _prompt_label == null:
		return
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()

	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", col)
	_prompt_label.modulate = Color(1, 1, 1, 0)
	_prompt_label.scale = Vector2(0.85, 0.85)
	_prompt_label.pivot_offset = _prompt_label.size / 2.0
	_prompt_label.visible = true

	_prompt_tween = create_tween()
	_prompt_tween.set_parallel(true)
	_prompt_tween.tween_property(_prompt_label, "modulate", Color.WHITE, 0.12)
	_prompt_tween.tween_property(_prompt_label, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_prompt_tween.chain().tween_property(_prompt_label, "scale", Vector2.ONE, 0.15)
	_prompt_tween.chain().tween_interval(1.1)
	_prompt_tween.chain().tween_property(_prompt_label, "modulate", Color(1, 1, 1, 0), 0.25)
	_prompt_tween.chain().tween_callback(func(): _prompt_label.visible = false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_card_layout()


func _process(_delta: float) -> void:
	var vp_size := get_viewport_rect().size
	if vp_size != _last_vp_size:
		_last_vp_size = vp_size
		_update_card_layout()

	# Redraw arrows and gesture trails smoothly at full frame rate
	if visible and not is_final_step and (target_dir != "" or is_frenzy_practice):
		queue_redraw()


func _draw() -> void:
	if is_final_step:
		return
	if center_square == null or not is_instance_valid(center_square):
		return

	var inv_xform: Transform2D = get_global_transform().affine_inverse()
	var c_global: Vector2 = center_square.global_position + center_square.size / 2.0
	var c_local: Vector2 = inv_xform * c_global

	# --- FRENZY PRACTICE MODE: 4 OUTWARD BURSTING ARROWS ---
	if is_frenzy_practice:
		var pulse_f: float = 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.01)
		var gold_col := Color(1.0, 0.85, 0.15, 0.7 * pulse_f)

		for dir: String in ["up", "down", "left", "right"]:
			var p: Panel = direction_squares.get(dir)
			if p != null and is_instance_valid(p):
				var t_local: Vector2 = inv_xform * (p.global_position + p.size / 2.0)
				var d_vec: Vector2 = (t_local - c_local).normalized()
				var p1: Vector2 = c_local + d_vec * 55.0
				var p2: Vector2 = t_local - d_vec * 50.0

				draw_line(p1, p2, gold_col, 8.0 * pulse_f)
				draw_line(p1, p2, Color.WHITE, 3.0 * pulse_f)

				var a_size: float = 16.0 * pulse_f
				var perp: Vector2 = Vector2(-d_vec.y, d_vec.x)
				var tip: Vector2 = p2
				var b1: Vector2 = p2 - d_vec * a_size + perp * (a_size * 0.6)
				var b2: Vector2 = p2 - d_vec * a_size - perp * (a_size * 0.6)
				draw_colored_polygon(PackedVector2Array([tip, b1, b2]), Color.WHITE)
				draw_polyline(PackedVector2Array([b1, tip, b2]), Color(1.0, 0.85, 0.15), 2.5)
		return

	# Normal targeted arrow
	if target_dir == "" or not target_dir in direction_squares:
		return

	var target_panel: Panel = direction_squares.get(target_dir)
	if target_panel == null or not is_instance_valid(target_panel):
		return

	var t_global: Vector2 = target_panel.global_position + target_panel.size / 2.0
	var t_local: Vector2 = inv_xform * t_global

	var dir_vec: Vector2 = (t_local - c_local).normalized()
	var p_start: Vector2 = c_local + dir_vec * 52.0
	var p_end: Vector2 = t_local - dir_vec * 50.0

	var target_color: Color = Color(0.2, 0.95, 1.0)

	# --- 1. NEON DIRECTIONAL ARROW ---
	var pulse: float = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.007)
	var glow_col: Color = target_color
	glow_col.a = 0.45 * pulse

	# Outer neon glow
	draw_line(p_start, p_end, glow_col, 10.0 * pulse)
	# Inner neon core
	draw_line(p_start, p_end, target_color, 4.5 * pulse)
	# White bright center
	draw_line(p_start, p_end, Color.WHITE, 1.8 * pulse)

	# Arrowhead at p_end
	var arrow_size: float = 18.0 * pulse
	var perp: Vector2 = Vector2(-dir_vec.y, dir_vec.x)
	var tip: Vector2 = p_end
	var b1: Vector2 = p_end - dir_norm_safe(dir_vec) * arrow_size + perp * (arrow_size * 0.65)
	var b2: Vector2 = p_end - dir_norm_safe(dir_vec) * arrow_size - perp * (arrow_size * 0.65)

	draw_colored_polygon(PackedVector2Array([tip, b1, b2]), Color.WHITE)
	draw_polyline(PackedVector2Array([b1, tip, b2]), target_color, 3.0)

	# --- 2. GESTURE GUIDE (SWIPE OR HOLD) ---
	if not is_hold:
		# Repeating swipe gesture loop (period 1.25s)
		var cycle: float = fmod(Time.get_ticks_msec() * 0.001, 1.25) / 1.25
		if cycle < 0.72:
			var progress: float = ease_out_cubic(cycle / 0.72)
			var finger_pos: Vector2 = p_start.lerp(p_end, progress)

			# Trailing motion dots
			for i in range(1, 4):
				var trail_prog: float = clampf(progress - float(i) * 0.07, 0.0, 1.0)
				var trail_pos: Vector2 = p_start.lerp(p_end, trail_prog)
				draw_circle(trail_pos, 10.0 - float(i) * 2.5, Color(0.2, 0.95, 1.0, 0.22 - float(i) * 0.05))

			# Main glowing touch circle
			draw_circle(finger_pos, 18.0, Color(0.2, 0.95, 1.0, 0.35))
			draw_circle(finger_pos, 9.0, Color.WHITE)
			draw_arc(finger_pos, 24.0, 0.0, TAU, 32, Color(0.2, 0.95, 1.0, 0.75), 2.5)
	else:
		# Hold gesture: Hand holds target square with pulsing radial charges and ripples
		var hold_cycle: float = fmod(Time.get_ticks_msec() * 0.001, 1.8) / 1.8
		var ring_r: float = 34.0

		# Expanding ripple wave
		var ripple_r: float = ring_r + hold_cycle * 36.0
		var ripple_a: float = (1.0 - hold_cycle) * 0.75
		draw_arc(t_local, ripple_r, 0.0, TAU, 36, Color(0.2, 0.95, 1.0, ripple_a), 2.5)

		# Charging radial ring
		draw_arc(t_local, ring_r, 0.0, TAU, 36, Color(0.12, 0.16, 0.28, 0.5), 5.0)
		draw_arc(t_local, ring_r, -PI * 0.5, -PI * 0.5 + TAU * hold_cycle, 36, Color(1.0, 0.9, 0.2, 0.95), 4.5)

		# Firm touch circle
		draw_circle(t_local, 20.0, Color(0.2, 0.95, 1.0, 0.4))
		draw_circle(t_local, 10.0, Color.WHITE)


func dir_norm_safe(v: Vector2) -> Vector2:
	return v.normalized() if v.length_squared() > 0.001 else Vector2.RIGHT


func ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)
