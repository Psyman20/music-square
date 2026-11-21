class_name StoryBossRenderer
extends RefCounted

## Procedural vector renderer for Story Mode bosses, arena HUD bars,
## board hazard/mechanic overlays, and level select previews.

var main: Node


func _init(main_node: Node) -> void:
	main = main_node


func _draw_story_boss_rush_preview() -> void:
	if main._story_boss_rush_preview_ctrl == null or not is_instance_valid(main._story_boss_rush_preview_ctrl):
		return
	var ctrl: Control = main._story_boss_rush_preview_ctrl
	var s: Vector2 = ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	var t: float = main._boss_anim_time
	ctrl.draw_circle(c, 46.0, Color(0.16, 0.04, 0.06, 0.92))
	ctrl.draw_arc(c, 46.0, t * 1.4, t * 1.4 + PI * 1.6, 36, Color(1.0, 0.78, 0.22, 0.85), 2.5, true)
	ctrl.draw_arc(c, 38.0, -t * 2.0, -t * 2.0 + PI * 1.4, 32, Color(1.0, 0.25, 0.38, 0.75), 2.0, true)

	# 4 colored boss orbs orbiting a golden gauntlet crown
	var orb_cols := [
		Color(0.35, 0.92, 1.0),
		Color(0.22, 1.0, 0.72),
		Color(0.92, 0.42, 1.0),
		Color(1.0, 0.72, 0.30),
	]
	for i in range(4):
		var ang: float = t * 1.8 + float(i) * (TAU / 4.0)
		var op: Vector2 = c + Vector2(cos(ang) * 26.0, sin(ang) * 26.0)
		ctrl.draw_circle(op, 6.5, Color(orb_cols[i].r, orb_cols[i].g, orb_cols[i].b, 0.35))
		ctrl.draw_circle(op, 4.0, orb_cols[i])

	# Central Golden Crown
	var crown := PackedVector2Array([
		c + Vector2(-15, 9),
		c + Vector2(-18, -8),
		c + Vector2(-8, 0),
		c + Vector2(0, -14),
		c + Vector2(8, 0),
		c + Vector2(18, -8),
		c + Vector2(15, 9),
	])
	ctrl.draw_colored_polygon(crown, Color(1.0, 0.84, 0.24, 0.98))
	var crown_closed := crown.duplicate()
	crown_closed.append(crown[0])
	ctrl.draw_polyline(crown_closed, Color(1.0, 0.98, 0.85, 0.95), 1.8, true)

	if main.settings == null or not main.settings.is_story_level_cleared(4):
		_draw_story_locked_overlay(ctrl, c)

func _draw_story_boss_arena() -> void:
	if main._story_boss_canvas == null or not is_instance_valid(main._story_boss_canvas):
		return

	var c_size: Vector2 = main._story_boss_canvas.size
	if c_size.x <= 1.0 or c_size.y <= 1.0:
		c_size = Vector2(540.0, 344.0)
	var canvas_offset := Vector2(0.0, main._story_boss_canvas.offset_top)
	var all_parts_dead: bool = main._are_all_boss_parts_destroyed()

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
	main._story_boss_canvas.draw_rect(Rect2(bar_x - 3.0, bar_y - 3.0, bar_w + 6.0, bar_h + 6.0), Color(frame_col.r, frame_col.g, frame_col.b, 0.28), false, 4.0)
	main._story_boss_canvas.draw_rect(bar_rect, Color(0.06, 0.04, 0.14, 0.92), true)

	# Ghost trailing damage bar
	var ghost_ratio: float = clampf(main.story_boss_ghost_hp / float(maxi(1, main.story_boss_max_hp)), 0.0, 1.0)
	if ghost_ratio > 0.0:
		main._story_boss_canvas.draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, (bar_w - 4.0) * ghost_ratio, bar_h - 4.0), Color(1.0, 0.92, 0.45, 0.85), true)

	# Active Boss HP fill bar
	var hp_ratio: float = clampf(float(main.story_boss_hp) / float(maxi(1, main.story_boss_max_hp)), 0.0, 1.0)
	if hp_ratio > 0.0:
		var hp_col := Color(1.0, 0.22, 0.35) if all_parts_dead else Color(0.22, 0.58, 0.88)
		var fill_w: float = (bar_w - 4.0) * hp_ratio
		main._story_boss_canvas.draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, fill_w, bar_h - 4.0), hp_col, true)
		# Glossy top highlight strip
		main._story_boss_canvas.draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, fill_w, (bar_h - 4.0) * 0.38), Color(1.0, 1.0, 1.0, 0.28), true)

	# Translucent cyan shield stripes across Main HP Bar while any body part is still alive
	if not all_parts_dead:
		var stripe_step: float = 28.0
		var x_cur: float = bar_x + 8.0
		while x_cur < bar_x + bar_w - 8.0:
			main._story_boss_canvas.draw_line(
				Vector2(x_cur, bar_y + bar_h - 2.0),
				Vector2(minf(bar_x + bar_w - 2.0, x_cur + 12.0), bar_y + 2.0),
				Color(0.55, 0.98, 1.0, 0.32),
				2.0
			)
			x_cur += stripe_step

	main._story_boss_canvas.draw_rect(bar_rect, frame_col, false, 2.2)

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
		var p_col: Color = main.direction_colors.get(p_dir, Color.WHITE)
		var px: float = pip_start_x + float(i) * (pip_w + pip_gap)
		var p_hp: int = int(main.story_part_hp.get(p_dir, 0))
		var p_ratio: float = clampf(float(p_hp) / float(maxi(1, main.story_part_max_hp)), 0.0, 1.0)
		var pip_rect := Rect2(px, pip_y, pip_w, 9.0)
		main._story_boss_canvas.draw_rect(pip_rect, Color(0.06, 0.04, 0.14, 0.90), true)
		if p_ratio > 0.0:
			main._story_boss_canvas.draw_rect(Rect2(px + 1.0, pip_y + 1.0, (pip_w - 2.0) * p_ratio, 7.0), p_col, true)
			main._story_boss_canvas.draw_rect(pip_rect, Color(p_col.r, p_col.g, p_col.b, 0.92), false, 1.6)
		else:
			# Destroyed part indicator
			main._story_boss_canvas.draw_rect(pip_rect, Color(0.35, 0.25, 0.35, 0.55), false, 1.2)
			main._story_boss_canvas.draw_line(Vector2(px + 4.0, pip_y + 2.0), Vector2(px + pip_w - 4.0, pip_y + 7.0), Color(1.0, 0.25, 0.3, 0.75), 1.6)
			main._story_boss_canvas.draw_line(Vector2(px + pip_w - 4.0, pip_y + 2.0), Vector2(px + 4.0, pip_y + 7.0), Color(1.0, 0.25, 0.3, 0.75), 1.6)

	# ---------------------------------------------------------
	# 3. ARTICULATED 4-PART BOSS ("CHROMA TITAN", "CYBER HYDRA", or "VOID SERAPH")
	# ---------------------------------------------------------
	var boss_center := Vector2(c_size.x * 0.5, c_size.y * 0.60)
	if main.story_level == 4:
		_draw_phantom_maestro_figure(main._story_boss_canvas, boss_center, 1.0, false)
	elif main.story_level == 3:
		_draw_void_seraph_figure(main._story_boss_canvas, boss_center, 1.0, false)
	elif main.story_level == 2:
		_draw_cyber_hydra_figure(main._story_boss_canvas, boss_center, 1.0, false)
	else:
		_draw_chroma_titan_figure(main._story_boss_canvas, boss_center, 1.0, false)

	# ---------------------------------------------------------
	# 4. BOSS HAZARD PROJECTIONS (Lv 1: Bomb Arcs | Lv 2: Shield Tethers | Lv 3: Void Rift Streams)
	# ---------------------------------------------------------
	if main.story_level == 4:
		# Conductor's baton launches a glowing music note toward the NEXT note of the melody (Phase 1 only —
		# Phase 2 never reveals the True Mask through projections!)
		if not all_parts_dead and main._boss_throw_anim > 0.01 and main._story_l4_seq_index < main._story_l4_sequence.size():
			var n_dir: String = main._story_l4_sequence[main._story_l4_seq_index]
			var n_start: Vector2 = boss_center + Vector2(46.0, -40.0)
			var n_end: Vector2 = main._get_board_center(n_dir) - canvas_offset
			var n_t: float = 1.0 - main._boss_throw_anim
			var n_pt: Vector2 = n_start.lerp(n_end, n_t) + Vector2(0.0, -sin(n_t * PI) * 46.0)
			main._story_boss_canvas.draw_circle(n_pt, 13.0, Color(1.0, 0.78, 0.30, 0.40))
			_draw_story_music_note(main._story_boss_canvas, n_pt, 1.0, Color(1.0, 0.92, 0.55, 0.98))
	elif main.story_level == 3:
		var start_p: Vector2 = boss_center + Vector2(0.0, -4.0)
		var pulse_a: float = 0.28 + 0.15 * sin(main._boss_anim_time * 10.5)
		for v_dir: String in main.story_bomb_dirs:
			if v_dir == "":
				continue
			var end_p: Vector2 = main._get_board_center(v_dir) - canvas_offset
			main._story_boss_canvas.draw_line(start_p, end_p, Color(0.85, 0.25, 1.0, pulse_a), 5.5, true)
			main._story_boss_canvas.draw_line(start_p, end_p, Color(1.0, 0.85, 0.35, pulse_a * 1.25), 1.8, true)
			if main._boss_throw_anim > 0.01:
				var proj_t: float = 1.0 - main._boss_throw_anim
				var pulse_pt: Vector2 = start_p.lerp(end_p, proj_t)
				main._story_boss_canvas.draw_circle(pulse_pt, 12.5, Color(0.92, 0.32, 1.0, 0.58))
				main._story_boss_canvas.draw_arc(pulse_pt, 9.0, main._boss_anim_time * 6.0, main._boss_anim_time * 6.0 + PI * 1.5, 14, Color(1.0, 0.92, 0.38, 0.96), 2.5, true)
	elif main.story_level == 2:
		# Persistent emerald-cyan shield projection beams from Cyber Hydra to shielded squares
		var start_p: Vector2 = boss_center + Vector2(0.0, 6.0)
		var pulse_a: float = 0.26 + 0.14 * sin(main._boss_anim_time * 9.0)
		for s_dir: String in main.story_bomb_dirs:
			if s_dir == "":
				continue
			var end_p: Vector2 = main._get_board_center(s_dir) - canvas_offset
			main._story_boss_canvas.draw_line(start_p, end_p, Color(0.15, 1.0, 0.72, pulse_a), 5.0, true)
			main._story_boss_canvas.draw_line(start_p, end_p, Color(0.75, 1.0, 0.95, pulse_a * 1.4), 1.8, true)
			if main._boss_throw_anim > 0.01:
				var proj_t: float = 1.0 - main._boss_throw_anim
				var pulse_pt: Vector2 = start_p.lerp(end_p, proj_t)
				main._story_boss_canvas.draw_circle(pulse_pt, 12.0, Color(0.20, 1.0, 0.78, 0.55))
				main._story_boss_canvas.draw_arc(pulse_pt, 9.0, 0.0, TAU, 6, Color(0.85, 1.0, 0.98, 0.95), 2.4, true)
	elif main._boss_throw_anim > 0.01 and not main._boss_throw_target_dirs.is_empty():
		var throw_t: float = 1.0 - main._boss_throw_anim # 0 -> 1
		var start_p: Vector2 = boss_center + Vector2(0.0, 10.0)
		for t_dir: String in main._boss_throw_target_dirs:
			if t_dir == "":
				continue
			var end_p: Vector2 = main._get_board_center(t_dir) - canvas_offset
			var arc_p: Vector2 = start_p.lerp(end_p, throw_t) + Vector2(0.0, -sin(throw_t * PI) * 68.0)
			main._story_boss_canvas.draw_circle(arc_p, 14.0, Color(1.6, 0.2, 0.25, 0.45))
			main._story_boss_canvas.draw_circle(arc_p, 8.5, Color(0.15, 0.12, 0.20, 0.98))
			main._story_boss_canvas.draw_arc(arc_p, 8.5, 0.0, TAU, 20, Color(1.6, 0.25, 0.25, 0.95), 2.2, true)
			main._story_boss_canvas.draw_circle(arc_p + Vector2(0, -10.0), 4.5, Color(1.0, 0.92, 0.25, 0.98))

	# ---------------------------------------------------------
	# 5. LASER BEAMS (Board Square -> Matching Boss Body Part)
	# ---------------------------------------------------------
	for beam: Dictionary in main._boss_laser_beams:
		var age: float = float(beam.get("age", 0.0))
		var dur: float = maxf(0.01, float(beam.get("duration", 0.28)))
		var life_t: float = clampf(1.0 - (age / dur), 0.0, 1.0)
		var from_pt: Vector2 = (beam.get("from", Vector2.ZERO) as Vector2) - canvas_offset
		var to_pt: Vector2 = (beam.get("to", Vector2.ZERO) as Vector2) - canvas_offset
		var b_col: Color = beam.get("color", Color.WHITE)

		# Outer neon bloom beam + inner white-hot core
		main._story_boss_canvas.draw_line(from_pt, to_pt, Color(b_col.r, b_col.g, b_col.b, 0.38 * life_t), 22.0 * life_t, true)
		main._story_boss_canvas.draw_line(from_pt, to_pt, Color(b_col.r, b_col.g, b_col.b, 0.88 * life_t), 10.0 * life_t, true)
		main._story_boss_canvas.draw_line(from_pt, to_pt, Color(1.0, 1.0, 1.0, 0.98 * life_t), 4.0 * life_t, true)

		# Impact shockwave ring at the Boss body part
		var ring_r: float = lerpf(8.0, 38.0, 1.0 - life_t)
		main._story_boss_canvas.draw_arc(to_pt, ring_r, 0.0, TAU, 28, Color(b_col.r, b_col.g, b_col.b, 0.85 * life_t), 3.5 * life_t, true)
		main._story_boss_canvas.draw_circle(to_pt, 10.0 * life_t, Color(1.0, 1.0, 1.0, 0.95 * life_t))

	# ---------------------------------------------------------
	# 6. BOSS & BODY PART EXPLOSION RINGS AND SHRAPNEL DEBRIS
	# ---------------------------------------------------------
	for ring: Dictionary in main._boss_explosion_rings:
		var r_age: float = float(ring.get("age", 0.0))
		var r_dur: float = maxf(0.01, float(ring.get("duration", 0.45)))
		var prog: float = clampf(r_age / r_dur, 0.0, 1.0)
		var fade: float = 1.0 - prog
		var r_pos: Vector2 = ring.get("pos", boss_center)
		var r_col: Color = ring.get("color", Color(1.0, 0.85, 0.25))
		var max_r: float = float(ring.get("max_radius", 90.0))
		var cur_r: float = lerpf(10.0, max_r, prog)
		main._story_boss_canvas.draw_circle(r_pos, cur_r * 0.55 * fade, Color(1.5, 1.2, 0.6, 0.55 * fade))
		main._story_boss_canvas.draw_arc(r_pos, cur_r, 0.0, TAU, 36, Color(r_col.r, r_col.g, r_col.b, 0.92 * fade), maxf(2.0, 7.0 * fade), true)
		main._story_boss_canvas.draw_arc(r_pos, cur_r * 0.72, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.85 * fade), maxf(1.5, 3.5 * fade), true)

	for shard: Dictionary in main._boss_explosion_shrapnel:
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
		main._story_boss_canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(s_col.r, s_col.g, s_col.b, fade))


func _draw_story_level1_preview() -> void:
	if main._story_level1_preview_ctrl == null or not is_instance_valid(main._story_level1_preview_ctrl):
		return
	var s: Vector2 = main._story_level1_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	# Subtle dark cyber pedestal backdrop
	main._story_level1_preview_ctrl.draw_circle(c, 48.0, Color(0.05, 0.03, 0.12, 0.85))
	main._story_level1_preview_ctrl.draw_arc(c, 48.0, 0.0, TAU, 36, Color(0.35, 0.90, 1.0, 0.55), 2.0, true)
	_draw_chroma_titan_figure(main._story_level1_preview_ctrl, c, 0.36, true)


func _draw_chroma_titan_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	# When the Boss is obliterated at the end of the death sequence, fade/vaporize the chassis completely!
	if not is_preview and main._boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and main._boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (main._boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = main._boss_anim_time
	var rage_mult: float = 1.65 if (main.story_boss_enraged and not is_preview) else 1.0
	var hover_y: float = sin(t * 3.2 * rage_mult) * 7.5 * scale_f
	var breathe: float = 1.0 + sin(t * 6.4 * rage_mult) * 0.035

	var shake_vec := Vector2.ZERO
	if not is_preview and (main._boss_hit_shake > 0.01 or main._boss_death_progress > 0.01):
		var sh_amp: float = (main._boss_hit_shake * 9.0 + main._boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(main._boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	# Fetch the 4 live board colors for the 4 Boss body parts!
	var col_up: Color = main.direction_colors.get("up", Color(1.0, 0.25, 0.45))
	var col_down: Color = main.direction_colors.get("down", Color(1.0, 0.85, 0.20))
	var col_left: Color = main.direction_colors.get("left", Color(0.20, 0.95, 0.55))
	var col_right: Color = main.direction_colors.get("right", Color(0.25, 0.65, 1.0))

	var up_dead: bool = (not is_preview and int(main.story_part_hp.get("up", 1)) <= 0)
	var down_dead: bool = (not is_preview and int(main.story_part_hp.get("down", 1)) <= 0)
	var left_dead: bool = (not is_preview and int(main.story_part_hp.get("left", 1)) <= 0)
	var right_dead: bool = (not is_preview and int(main.story_part_hp.get("right", 1)) <= 0)

	if up_dead:
		col_up = col_up.darkened(0.68)
	if down_dead:
		col_down = col_down.darkened(0.68)
	if left_dead:
		col_left = col_left.darkened(0.68)
	if right_dead:
		col_right = col_right.darkened(0.68)

	if not is_preview:
		var death_glow: float = clampf(main._boss_death_progress * 1.4, 0.0, 1.0)
		col_up = col_up.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("up", 0.0)), 0.0, 1.0)))
		col_down = col_down.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("down", 0.0)), 0.0, 1.0)))
		col_left = col_left.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("left", 0.0)), 0.0, 1.0)))
		col_right = col_right.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("right", 0.0)), 0.0, 1.0)))

	# During death sequence, parts fly violently apart!
	var death_split: float = (main._boss_death_progress * main._boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var dark_armor := Color(0.07, 0.05, 0.16, 0.96)

	# ---------------------------------------------------------
	# A. BACKGROUND HOLOGRAPHIC FORCEFIELD HEX-RING
	# ---------------------------------------------------------
	var aura_col := Color(1.0, 0.22, 0.38, 0.26) if (main.story_boss_enraged and not is_preview) else Color(0.30, 0.88, 1.0, 0.20)
	var aura_r: float = (94.0 + sin(t * 4.0) * 5.0) * scale_f
	var hex_aura := PackedVector2Array()
	for i in range(7):
		var ang: float = t * 0.55 + float(i) * (TAU / 6.0)
		hex_aura.append(root_pos + Vector2(cos(ang), sin(ang)) * aura_r)
	canvas.draw_polyline(hex_aura, aura_col, maxf(1.5, 3.0 * scale_f), true)

	# Energy tether conduits connecting Torso to Head, Left Arm, and Right Arm
	var rec_up: float = (float(main._boss_part_recoil.get("up", 0.0)) * 18.0 * scale_f) if not is_preview else 0.0
	var rec_down: float = (float(main._boss_part_recoil.get("down", 0.0)) * 14.0 * scale_f) if not is_preview else 0.0
	var rec_left: float = (float(main._boss_part_recoil.get("left", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0
	var rec_right: float = (float(main._boss_part_recoil.get("right", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0

	var torso_c: Vector2 = root_pos + Vector2(0.0, 12.0 * scale_f + rec_down + death_split * 0.5)
	var head_c: Vector2 = root_pos + Vector2(0.0, -68.0 * scale_f - rec_up - death_split + sin(t * 4.2) * 3.0 * scale_f)
	var throw_lunge_l: float = sin(main._boss_throw_anim * PI) * 18.0 * scale_f if (not is_preview and (main._boss_throw_target_dir == "left" or main._boss_throw_target_dir == "up")) else 0.0
	var throw_lunge_r: float = sin(main._boss_throw_anim * PI) * 18.0 * scale_f if (not is_preview and (main._boss_throw_target_dir == "right" or main._boss_throw_target_dir == "down")) else 0.0
	var left_c: Vector2 = root_pos + Vector2(-112.0 * scale_f - rec_left - death_split, -4.0 * scale_f + cos(t * 3.6 + 0.8) * 6.5 * scale_f + throw_lunge_l)
	var right_c: Vector2 = root_pos + Vector2(112.0 * scale_f + rec_right + death_split, -4.0 * scale_f + cos(t * 3.6 + 2.4) * 6.5 * scale_f + throw_lunge_r)

	# Plasma shoulder beams
	if main._boss_death_progress < 0.25:
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
	var core_gem_col: Color = Color(1.5, 0.30, 0.40) if (main.story_boss_enraged and not is_preview) else col_down.lightened(0.25)
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

	var eye_col := Color(1.0, 0.2, 0.3) if (main.story_boss_enraged and not is_preview) else Color(1.0, 0.96, 0.35)
	var eye_slant: float = 4.5 if (main.story_boss_enraged or main._boss_hit_shake > 0.1) else 2.0
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
	var pulse: float = 1.0 + sin(main._boss_anim_time * 7.0) * 0.08
	var all_parts_dead: bool = main._are_all_boss_parts_destroyed()

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
		if d_key in main.story_bomb_dirs or d_key == main.story_bomb_dir:
			continue
		if not all_parts_dead and int(main.story_part_hp.get(d_key, 0)) <= 0:
			continue
		var col: Color = main.direction_colors.get(d_key, Color(0.2, 0.8, 1.0))
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
	var t: float = main._boss_anim_time

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
	if main._story_level2_preview_ctrl == null or not is_instance_valid(main._story_level2_preview_ctrl):
		return
	var s: Vector2 = main._story_level2_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	main._story_level2_preview_ctrl.draw_circle(c, 46.0, Color(0.03, 0.11, 0.09, 0.88))
	main._story_level2_preview_ctrl.draw_arc(c, 46.0, 0.0, TAU, 36, Color(0.20, 1.0, 0.68, 0.62), 2.0, true)
	_draw_cyber_hydra_figure(main._story_level2_preview_ctrl, c, 0.34, true)
	if main.settings == null or not main.settings.is_story_level_cleared(1):
		_draw_story_locked_overlay(main._story_level2_preview_ctrl, c)


func _draw_story_level3_preview() -> void:
	if main._story_level3_preview_ctrl == null or not is_instance_valid(main._story_level3_preview_ctrl):
		return
	var s: Vector2 = main._story_level3_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	main._story_level3_preview_ctrl.draw_circle(c, 46.0, Color(0.09, 0.03, 0.15, 0.88))
	main._story_level3_preview_ctrl.draw_arc(c, 46.0, 0.0, TAU, 36, Color(0.92, 0.42, 1.0, 0.62), 2.0, true)
	_draw_void_seraph_figure(main._story_level3_preview_ctrl, c, 0.34, true)
	if main.settings == null or not main.settings.is_story_level_cleared(2):
		_draw_story_locked_overlay(main._story_level3_preview_ctrl, c)


func _draw_story_locked_overlay(canvas: Control, c: Vector2) -> void:
	canvas.draw_circle(c, 46.0, Color(0.03, 0.02, 0.08, 0.72))
	canvas.draw_arc(c + Vector2(0.0, -7.0), 8.5, PI, TAU, 16, Color(1.0, 0.88, 0.35, 0.95), 3.0, true)
	var body_rect := Rect2(c.x - 12.0, c.y - 6.0, 24.0, 19.0)
	canvas.draw_rect(body_rect, Color(0.14, 0.10, 0.24, 0.98), true)
	canvas.draw_rect(body_rect, Color(1.0, 0.88, 0.35, 0.96), false, 2.2)
	canvas.draw_circle(c + Vector2(0.0, 2.5), 2.8, Color(1.0, 0.88, 0.35, 0.98))


func _draw_cyber_hydra_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	if not is_preview and main._boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and main._boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (main._boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = main._boss_anim_time
	var rage_mult: float = 1.65 if (main.story_boss_enraged and not is_preview) else 1.0
	var hover_y: float = sin(t * 3.5 * rage_mult) * 7.0 * scale_f
	var breathe: float = 1.0 + sin(t * 6.8 * rage_mult) * 0.04

	var shake_vec := Vector2.ZERO
	if not is_preview and (main._boss_hit_shake > 0.01 or main._boss_death_progress > 0.01):
		var sh_amp: float = (main._boss_hit_shake * 9.0 + main._boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(main._boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	var col_up: Color = main.direction_colors.get("up", Color(1.0, 0.25, 0.45))
	var col_down: Color = main.direction_colors.get("down", Color(1.0, 0.85, 0.20))
	var col_left: Color = main.direction_colors.get("left", Color(0.20, 0.95, 0.55))
	var col_right: Color = main.direction_colors.get("right", Color(0.25, 0.65, 1.0))

	var up_dead: bool = (not is_preview and int(main.story_part_hp.get("up", 1)) <= 0)
	var down_dead: bool = (not is_preview and int(main.story_part_hp.get("down", 1)) <= 0)
	var left_dead: bool = (not is_preview and int(main.story_part_hp.get("left", 1)) <= 0)
	var right_dead: bool = (not is_preview and int(main.story_part_hp.get("right", 1)) <= 0)

	if up_dead:
		col_up = col_up.darkened(0.68)
	if down_dead:
		col_down = col_down.darkened(0.68)
	if left_dead:
		col_left = col_left.darkened(0.68)
	if right_dead:
		col_right = col_right.darkened(0.68)

	if not is_preview:
		var death_glow: float = clampf(main._boss_death_progress * 1.4, 0.0, 1.0)
		col_up = col_up.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("up", 0.0)), 0.0, 1.0)))
		col_down = col_down.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("down", 0.0)), 0.0, 1.0)))
		col_left = col_left.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("left", 0.0)), 0.0, 1.0)))
		col_right = col_right.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("right", 0.0)), 0.0, 1.0)))

	var death_split: float = (main._boss_death_progress * main._boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var dark_armor := Color(0.04, 0.11, 0.10, 0.96)

	# Rotating Double Bio-Hex Aura
	var aura_col := Color(1.0, 0.22, 0.45, 0.28) if (main.story_boss_enraged and not is_preview) else Color(0.18, 1.0, 0.68, 0.24)
	var aura_r: float = (98.0 + sin(t * 4.2) * 6.0) * scale_f
	var oct_aura := PackedVector2Array()
	for i in range(9):
		var ang: float = -t * 0.65 + float(i) * (TAU / 8.0)
		oct_aura.append(root_pos + Vector2(cos(ang), sin(ang)) * aura_r)
	canvas.draw_polyline(oct_aura, aura_col, maxf(1.5, 3.0 * scale_f), true)

	var rec_up: float = (float(main._boss_part_recoil.get("up", 0.0)) * 18.0 * scale_f) if not is_preview else 0.0
	var rec_down: float = (float(main._boss_part_recoil.get("down", 0.0)) * 16.0 * scale_f) if not is_preview else 0.0
	var rec_left: float = (float(main._boss_part_recoil.get("left", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0
	var rec_right: float = (float(main._boss_part_recoil.get("right", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0

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
	if main._boss_death_progress < 0.30:
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
	var heart_col := Color(1.0, 0.22, 0.42) if (main.story_boss_enraged and not is_preview) else Color(0.20, 1.0, 0.68)
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
		var eye_c := Color(0.25, 1.0, 0.72, fang_alpha) if not main.story_boss_enraged else Color(1.0, 0.25, 0.38, fang_alpha)
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
	var t: float = main._boss_anim_time

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
	var t: float = main._boss_anim_time

	# Pulsing bio-green regrowth warning ring on severed head squares
	var r: float = (26.0 + sin(t * 8.0) * 2.5) * sf
	panel.draw_arc(c, r, t * 2.2, t * 2.2 + PI * 1.35, 20, Color(0.25, 1.0, 0.65, 0.88), 3.0 * sf, true)
	panel.draw_arc(c, r, t * 2.2 + PI, t * 2.2 + PI * 1.65, 12, Color(1.0, 0.92, 0.30, 0.85), 2.4 * sf, true)


func _draw_void_seraph_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	if not is_preview and main._boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and main._boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (main._boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = main._boss_anim_time
	var rage_mult: float = 1.65 if (main.story_boss_enraged and not is_preview) else 1.0
	var hover_y: float = sin(t * 3.2 * rage_mult) * 8.0 * scale_f
	var breathe: float = 1.0 + sin(t * 6.5 * rage_mult) * 0.04

	var shake_vec := Vector2.ZERO
	if not is_preview and (main._boss_hit_shake > 0.01 or main._boss_death_progress > 0.01):
		var sh_amp: float = (main._boss_hit_shake * 9.0 + main._boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(main._boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	var col_up: Color = main.direction_colors.get("up", Color(1.0, 0.25, 0.45))
	var col_down: Color = main.direction_colors.get("down", Color(1.0, 0.85, 0.20))
	var col_left: Color = main.direction_colors.get("left", Color(0.20, 0.95, 0.55))
	var col_right: Color = main.direction_colors.get("right", Color(0.25, 0.65, 1.0))

	var up_dead: bool = (not is_preview and int(main.story_part_hp.get("up", 1)) <= 0)
	var down_dead: bool = (not is_preview and int(main.story_part_hp.get("down", 1)) <= 0)
	var left_dead: bool = (not is_preview and int(main.story_part_hp.get("left", 1)) <= 0)
	var right_dead: bool = (not is_preview and int(main.story_part_hp.get("right", 1)) <= 0)

	if up_dead:
		col_up = col_up.darkened(0.68)
	if down_dead:
		col_down = col_down.darkened(0.68)
	if left_dead:
		col_left = col_left.darkened(0.68)
	if right_dead:
		col_right = col_right.darkened(0.68)

	if not is_preview:
		var death_glow: float = clampf(main._boss_death_progress * 1.4, 0.0, 1.0)
		col_up = col_up.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("up", 0.0)), 0.0, 1.0)))
		col_down = col_down.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("down", 0.0)), 0.0, 1.0)))
		col_left = col_left.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("left", 0.0)), 0.0, 1.0)))
		col_right = col_right.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get("right", 0.0)), 0.0, 1.0)))

	var death_split: float = (main._boss_death_progress * main._boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var dark_void := Color(0.07, 0.03, 0.14, 0.96)

	# 1. Counter-rotating Celestial Seraphic Rings
	var ring_col1 := Color(0.92, 0.35, 1.0, 0.32)
	var ring_col2 := Color(1.0, 0.88, 0.35, 0.28)
	canvas.draw_arc(root_pos, 102.0 * scale_f, t * 0.8, t * 0.8 + PI * 1.65, 32, ring_col1, maxf(1.5, 3.2 * scale_f), true)
	canvas.draw_arc(root_pos, 84.0 * scale_f, -t * 1.2, -t * 1.2 + PI * 1.5, 28, ring_col2, maxf(1.4, 2.5 * scale_f), true)

	var rec_up: float = (float(main._boss_part_recoil.get("up", 0.0)) * 18.0 * scale_f) if not is_preview else 0.0
	var rec_down: float = (float(main._boss_part_recoil.get("down", 0.0)) * 16.0 * scale_f) if not is_preview else 0.0
	var rec_left: float = (float(main._boss_part_recoil.get("left", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0
	var rec_right: float = (float(main._boss_part_recoil.get("right", 0.0)) * 22.0 * scale_f) if not is_preview else 0.0

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
	var eye_rim_col := Color(1.0, 0.35, 0.65) if (main.story_boss_enraged and not is_preview) else Color(1.0, 0.88, 0.38)
	canvas.draw_polyline(eye_closed, eye_rim_col, maxf(1.8, 3.6 * scale_f), true)

	# Iris & Vertical Slit Singularity Pupil
	var iris_col := Color(0.92, 0.32, 1.0, 0.95) if not (main.story_boss_enraged and not is_preview) else Color(1.0, 0.22, 0.45, 0.98)
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
	var t: float = main._boss_anim_time

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
	var t: float = main._boss_anim_time

	# Swirling violet-gold warning ring on shattered wing squares
	var r: float = (26.0 + sin(t * 9.0) * 2.5) * sf
	panel.draw_arc(c, r, -t * 2.6, -t * 2.6 + PI * 1.35, 20, Color(0.95, 0.42, 1.0, 0.88), 3.0 * sf, true)
	panel.draw_arc(c, r, -t * 2.6 + PI, -t * 2.6 + PI * 1.65, 12, Color(1.0, 0.88, 0.35, 0.85), 2.4 * sf, true)


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
	var t: float = main._boss_anim_time

	if main._are_all_boss_parts_destroyed():
		# MASQUERADE masks
		var kind: int = 0
		if main._story_l4_reveal_left > 0.0:
			kind = 1 if dir == main._story_l4_true_dir else 2
		_draw_story_maestro_mask(panel, c, sf * 1.15, kind)
	else:
		var note_idx: int = main._story_l4_sequence.find(dir)
		if note_idx >= main._story_l4_seq_index and note_idx >= 0:
			var is_next: bool = (note_idx == main._story_l4_seq_index)
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
			main._draw_symbol_on_panel(panel, dir)
			if int(main.story_part_hp.get(dir, 0)) <= 0:
				# Silenced instrument: mute slash
				panel.draw_line(c + Vector2(-20, -20) * sf, c + Vector2(20, 20) * sf, Color(0.10, 0.04, 0.08, 0.85), 6.0 * sf, true)
				panel.draw_line(c + Vector2(-20, -20) * sf, c + Vector2(20, 20) * sf, Color(1.0, 0.45, 0.50, 0.85), 3.0 * sf, true)

	# Mirror Curse: shimmering glass sheen + reversed-arrow badge on every square
	if main._story_l4_mirror_swipes > 0:
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
	var t: float = main._boss_anim_time
	var all_dead: bool = main._are_all_boss_parts_destroyed()
	var pulse: float = 1.0 + sin(t * 7.0) * 0.07

	# Mirror Curse halo + reversed double arrows
	if main._story_l4_mirror_swipes > 0:
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
	if not all_dead and not main._story_l4_sequence.is_empty():
		var n: int = main._story_l4_sequence.size()
		var spacing: float = 12.0 * sf
		var start_x: float = c.x - spacing * float(n - 1) * 0.5
		for i in range(n):
			var pp: Vector2 = Vector2(start_x + spacing * float(i), c.y + 26.0 * sf)
			if i < main._story_l4_seq_index:
				panel.draw_circle(pp, 4.2 * sf, Color(1.0, 0.72, 0.18, 0.98))
			elif i == main._story_l4_seq_index:
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
	var t: float = main._boss_anim_time
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
	if main._story_level4_preview_ctrl == null or not is_instance_valid(main._story_level4_preview_ctrl):
		return
	var s: Vector2 = main._story_level4_preview_ctrl.size
	var c: Vector2 = Vector2(s.x * 0.5, s.y * 0.54)
	main._story_level4_preview_ctrl.draw_circle(c, 46.0, Color(0.14, 0.03, 0.07, 0.88))
	main._story_level4_preview_ctrl.draw_arc(c, 46.0, 0.0, TAU, 36, Color(1.0, 0.70, 0.30, 0.62), 2.0, true)
	_draw_phantom_maestro_figure(main._story_level4_preview_ctrl, c + Vector2(0.0, 4.0), 0.34, true)
	if main.settings == null or not main.settings.is_story_level_cleared(3):
		_draw_story_locked_overlay(main._story_level4_preview_ctrl, c)


func _draw_phantom_maestro_figure(canvas: Control, origin: Vector2, scale_f: float = 1.0, is_preview: bool = false) -> void:
	if not is_preview and main._boss_death_progress > 0.88:
		return

	var death_scale: float = 1.0
	if not is_preview and main._boss_death_progress > 0.60:
		death_scale = clampf(1.0 - (main._boss_death_progress - 0.60) / 0.28, 0.0, 1.0)
	scale_f *= death_scale

	var t: float = main._boss_anim_time
	var enraged: bool = main.story_boss_enraged and not is_preview
	var rage_mult: float = 1.65 if enraged else 1.0
	var hover_y: float = sin(t * 2.6 * rage_mult) * 7.0 * scale_f

	var shake_vec := Vector2.ZERO
	if not is_preview and (main._boss_hit_shake > 0.01 or main._boss_death_progress > 0.01):
		var sh_amp: float = (main._boss_hit_shake * 9.0 + main._boss_death_progress * 24.0) * scale_f
		shake_vec = Vector2(randf_range(-sh_amp, sh_amp), randf_range(-sh_amp, sh_amp))

	var taunt_hop: float = -sin(main._boss_taunt_anim * PI * 2.0) * 14.0 * scale_f if not is_preview else 0.0
	var root_pos: Vector2 = origin + Vector2(0.0, hover_y + taunt_hop) + shake_vec

	var cols: Dictionary = {}
	var dead: Dictionary = {}
	var defaults: Dictionary = {
		"up": Color(1.0, 0.25, 0.45), "down": Color(1.0, 0.85, 0.20),
		"left": Color(0.20, 0.95, 0.55), "right": Color(0.25, 0.65, 1.0),
	}
	var death_glow: float = clampf(main._boss_death_progress * 1.4, 0.0, 1.0) if not is_preview else 0.0
	for d: String in ["up", "down", "left", "right"]:
		var col: Color = main.direction_colors.get(d, defaults[d])
		var is_dead: bool = (not is_preview and int(main.story_part_hp.get(d, 1)) <= 0)
		if is_dead:
			col = col.darkened(0.68)
		if not is_preview:
			col = col.lerp(Color(2.0, 2.0, 2.2), maxf(death_glow, clampf(float(main._boss_part_flash.get(d, 0.0)), 0.0, 1.0)))
		cols[d] = col
		dead[d] = is_dead

	var death_split: float = (main._boss_death_progress * main._boss_death_progress * 145.0 * scale_f) if not is_preview else 0.0
	var rec: Dictionary = {}
	for d: String in ["up", "down", "left", "right"]:
		rec[d] = (float(main._boss_part_recoil.get(d, 0.0)) * 18.0 * scale_f) if not is_preview else 0.0

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
	var conduct: float = sin(t * 4.2 * rage_mult) * 0.55 + (main._boss_throw_anim * 0.9 if not is_preview else 0.0)
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
