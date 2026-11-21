class_name StoryManager
extends Node

## Manages Story Mode UI (Scrollable 4 Boss Cards + Boss Rush Card),
## Boss Combat Loops (Levels 1–4), 3-Star Mastery Ratings, Boss Rush Gauntlet,
## and Dynamic Boss Music.

const BOSS_MUSIC_PATHS := {
	1: "res://music/battle_theme.ogg",
	2: "res://music/jj_level1.ogg",
	3: "res://music/jj_level2.ogg",
	4: "res://music/jj_level3.ogg",
}

const STORY_TARGET_TIMES := {
	1: 40.0,
	2: 50.0,
	3: 60.0,
	4: 75.0,
}

var main: Node
var renderer: StoryBossRenderer


func setup(main_node: Node) -> void:
	main = main_node
	renderer = StoryBossRenderer.new(main_node)


func format_time(sec: float) -> String:
	var total := maxf(0.0, sec)
	var mins := int(total) / 60
	var rem := total - float(mins * 60)
	if mins > 0:
		return "%d:%04.1f" % [mins, rem]
	return "%.1fs" % rem


func format_stars_text(stars: int) -> String:
	var s := clampi(stars, 0, 3)
	var out := ""
	for i in range(3):
		out += "★" if i < s else "☆"
	return out


# =====================================================
# DYNAMIC BOSS MUSIC
# =====================================================

func play_boss_music(level_num: int, enraged: bool = false) -> void:
	if main == null or main._song_player == null:
		return
	main._update_music_volume()
	var path: String = str(BOSS_MUSIC_PATHS.get(level_num, "res://music/battle_theme.ogg"))
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = main._song_cache.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			return
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		main._song_cache[path] = stream
	main._song_player.pitch_scale = 1.06 if enraged else 1.0
	if main._song_player.stream != stream or not main._song_player.playing:
		main._song_player.stream = stream
		if main.is_inside_tree() and DisplayServer.get_name() != "headless":
			main._song_player.play()


func set_boss_music_enraged(enraged: bool) -> void:
	if main == null or main._song_player == null:
		return
	main._song_player.pitch_scale = 1.06 if enraged else 1.0


func restore_normal_music() -> void:
	if main == null or main._song_player == null:
		return
	main._song_player.pitch_scale = 1.0
	main._play_selected_song()


# =====================================================
# STORY MODE UI (SCROLLABLE CARDS + 3-STAR + BOSS RUSH)
# =====================================================

func setup_story_ui() -> void:
	# 1. "STORY MODE" button directly under ARCADE MODE on MenuScreen
	main._story_button = Button.new()
	main._story_button.name = "StoryButton"
	main._story_button.text = "STORY MODE"
	main._story_button.anchor_left = 0.5
	main._story_button.anchor_right = 0.5
	main._story_button.offset_left = -128.0
	main._story_button.offset_right = 128.0
	main._story_button.offset_top = 480.0
	main._story_button.offset_bottom = 524.0
	main._story_button.clip_contents = true
	main._story_button.add_theme_font_size_override("font_size", 16)
	main._apply_menu_button_style(main._story_button, main._story_btn_style, main._story_btn_hover_style)
	main._story_button.add_theme_color_override("font_color", Color(1.0, 0.98, 1.0, 1.0))
	main._story_button.add_theme_constant_override("outline_size", 5)
	main._story_button.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.22, 1.0))
	main._story_button.pressed.connect(main._open_story_screen)
	main.menu_screen.add_child(main._story_button)

	# 2. Story Mode Level Selection Overlay Screen
	main._story_screen = Control.new()
	main._story_screen.name = "StoryScreen"
	main._story_screen.visible = false
	main._story_screen.anchor_right = 1.0
	main._story_screen.anchor_bottom = 1.0
	main._story_screen.z_index = 54
	main.add_child(main._story_screen)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.01, 0.06, 0.78)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.gui_input.connect(main._on_story_backdrop_input)
	main._story_screen.add_child(backdrop)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", main._pause_panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -410.0
	panel.offset_bottom = 410.0
	main._story_screen.add_child(panel)

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
	sub.text = "★ 0/12 STARS  •  SWIPE WHITE CENTER TO ATTACK!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.clip_text = true
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.95, 0.90, 0.60))
	sub.anchor_left = 0.5
	sub.anchor_right = 0.5
	sub.offset_left = -206.0
	sub.offset_right = 206.0
	sub.offset_top = 42.0
	sub.offset_bottom = 58.0
	panel.add_child(sub)
	main._story_subtitle_label = sub

	# ScrollContainer so all 4 Boss Cards + Boss Rush Card breathe cleanly & support future bosses!
	var scroll := ScrollContainer.new()
	scroll.name = "StoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 4
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.offset_left = -202.0
	scroll.offset_right = 202.0
	scroll.offset_top = 62.0
	scroll.offset_bottom = 754.0
	panel.add_child(scroll)
	main._story_scroll = scroll

	var vbox := VBoxContainer.new()
	vbox.name = "StoryList"
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var locked_btn_style := StyleBoxFlat.new()
	locked_btn_style.set_corner_radius_all(14)
	locked_btn_style.bg_color = Color(0.11, 0.09, 0.18, 0.92)
	locked_btn_style.set_border_width_all(2)
	locked_btn_style.set_border_color(Color(0.38, 0.34, 0.52, 0.75))

	# --- LEVEL 1 BOSS CARD (CHROMA TITAN) ---
	var card1 := _create_boss_card(
		"Level1Card", "BossPreview", "Level1Title", "Level1Stars", "Level1Status", "Level1Desc", "FightBossBtn",
		"LVL 1: CHROMA TITAN",
		"4 PARTS + 15 HP  •  +50⚡ + TITAN SKIN",
		"• Center is WHITE: swipe to ANY color!\n• Destroy all 4 colored Body Parts first!\n• Then drain the Boss's Main HP!\n• Avoid BOMBS (1 → 2 → 3 Bombs)!",
		"⚔  FIGHT TITAN  ⚔",
		Color(0.10, 0.07, 0.22, 0.95), Color(0.35, 0.92, 1.0, 0.92), Color(1.0, 0.95, 0.35),
		main._play_btn_style, main._play_btn_hover_style, locked_btn_style,
		renderer._draw_story_level1_preview, main._on_story_level_selected.bind(1)
	)
	vbox.add_child(card1["card"])
	main._story_level1_preview_ctrl = card1["preview"]
	main._story_level1_stars_label = card1["stars"]
	main._story_level1_status_label = card1["status"]

	# --- LEVEL 2 BOSS CARD (CYBER HYDRA) ---
	var card2 := _create_boss_card(
		"Level2Card", "BossPreview2", "Level2Title", "Level2Stars", "Level2Status", "Level2Desc", "FightHydraBtn",
		"LVL 2: CYBER HYDRA",
		"🔒 LOCKED — BEAT LEVEL 1 FIRST!",
		"• NO BOMBS! Shields block squares!\n• Hit a Shield: -1 Life & Hydra HEALS!\n• Swiping dead heads REGROWS (+2 HP)!\n• Sever all 4 Heads, then drain Main HP!",
		"⚔  FIGHT HYDRA  ⚔",
		Color(0.07, 0.14, 0.18, 0.95), Color(0.22, 1.0, 0.72, 0.92), Color(0.30, 1.0, 0.75),
		main._story_btn_style, main._story_btn_hover_style, locked_btn_style,
		renderer._draw_story_level2_preview, main._on_story_level_selected.bind(2)
	)
	vbox.add_child(card2["card"])
	main._story_level2_preview_ctrl = card2["preview"]
	main._story_level2_stars_label = card2["stars"]
	main._story_level2_status_label = card2["status"]
	main._story_level2_fight_btn = card2["btn"]

	# --- LEVEL 3 BOSS CARD (VOID SERAPH) ---
	var seraph_btn_style := main._story_btn_style.duplicate() as StyleBoxFlat
	seraph_btn_style.bg_color = Color(0.55, 0.14, 0.88, 0.94)
	seraph_btn_style.border_color = Color(1.0, 0.85, 0.35, 0.95)
	seraph_btn_style.shadow_color = Color(0.75, 0.22, 1.0, 0.55)
	var seraph_btn_hover_style := main._story_btn_hover_style.duplicate() as StyleBoxFlat
	seraph_btn_hover_style.bg_color = Color(0.68, 0.22, 0.98, 0.98)
	seraph_btn_hover_style.border_color = Color(1.0, 0.92, 0.55, 1.0)
	seraph_btn_hover_style.shadow_color = Color(0.85, 0.35, 1.0, 0.72)

	var card3 := _create_boss_card(
		"Level3Card", "BossPreview3", "Level3Title", "Level3Stars", "Level3Status", "Level3Desc", "FightSeraphBtn",
		"LVL 3: VOID SERAPH",
		"🔒 LOCKED — BEAT LEVEL 2 FIRST!",
		"• Void Rifts lock last swiped square!\n• Board colors WARP after every attack!\n• Dead wings DRAIN +2 HP to Boss Core!\n• Shatter 4 Wings, then drain Main HP!",
		"⚔  FIGHT SERAPH  ⚔",
		Color(0.13, 0.06, 0.22, 0.95), Color(0.88, 0.35, 1.0, 0.92), Color(0.92, 0.55, 1.0),
		seraph_btn_style, seraph_btn_hover_style, locked_btn_style,
		renderer._draw_story_level3_preview, main._on_story_level_selected.bind(3)
	)
	vbox.add_child(card3["card"])
	main._story_level3_preview_ctrl = card3["preview"]
	main._story_level3_stars_label = card3["stars"]
	main._story_level3_status_label = card3["status"]
	main._story_level3_fight_btn = card3["btn"]

	# --- LEVEL 4 BOSS CARD (PHANTOM MAESTRO) ---
	var maestro_btn_style := main._story_btn_style.duplicate() as StyleBoxFlat
	maestro_btn_style.bg_color = Color(0.78, 0.16, 0.26, 0.94)
	maestro_btn_style.border_color = Color(1.0, 0.82, 0.38, 0.95)
	maestro_btn_style.shadow_color = Color(1.0, 0.28, 0.35, 0.55)
	var maestro_btn_hover_style := main._story_btn_hover_style.duplicate() as StyleBoxFlat
	maestro_btn_hover_style.bg_color = Color(0.92, 0.24, 0.32, 0.98)
	maestro_btn_hover_style.border_color = Color(1.0, 0.90, 0.55, 1.0)
	maestro_btn_hover_style.shadow_color = Color(1.0, 0.40, 0.42, 0.72)

	var card4 := _create_boss_card(
		"Level4Card", "BossPreview4", "Level4Title", "Level4Stars", "Level4Status", "Level4Desc", "FightMaestroBtn",
		"LVL 4: PHANTOM MAESTRO",
		"🔒 LOCKED — BEAT LEVEL 3 FIRST!",
		"• Play his MELODY: swipe notes 1 → 2 → 3!\n• Wrong note: -1 Life & melody resets!\n• MIRROR curse REVERSES your swipes!\n• Phase 2: remember the TRUE MASK!",
		"⚔  FIGHT MAESTRO  ⚔",
		Color(0.17, 0.05, 0.09, 0.95), Color(1.0, 0.72, 0.30, 0.92), Color(1.0, 0.78, 0.35),
		maestro_btn_style, maestro_btn_hover_style, locked_btn_style,
		renderer._draw_story_level4_preview, main._on_story_level_selected.bind(4)
	)
	vbox.add_child(card4["card"])
	main._story_level4_preview_ctrl = card4["preview"]
	main._story_level4_stars_label = card4["stars"]
	main._story_level4_status_label = card4["status"]
	main._story_level4_fight_btn = card4["btn"]

	# --- BOSS RUSH GAUNTLET CARD (UNLOCKS AFTER LEVEL 4) ---
	var rush_btn_style := main._story_btn_style.duplicate() as StyleBoxFlat
	rush_btn_style.bg_color = Color(0.82, 0.46, 0.08, 0.96)
	rush_btn_style.border_color = Color(1.0, 0.92, 0.35, 0.98)
	rush_btn_style.shadow_color = Color(1.0, 0.65, 0.12, 0.60)
	var rush_btn_hover_style := main._story_btn_hover_style.duplicate() as StyleBoxFlat
	rush_btn_hover_style.bg_color = Color(0.95, 0.58, 0.14, 0.98)
	rush_btn_hover_style.border_color = Color(1.0, 1.0, 0.65, 1.0)
	rush_btn_hover_style.shadow_color = Color(1.0, 0.78, 0.25, 0.78)

	var card_rush := _create_boss_card(
		"BossRushCard", "BossRushPreview", "BossRushTitle", "BossRushStars", "BossRushStatus", "BossRushDesc", "FightBossRushBtn",
		"🔥 BOSS RUSH GAUNTLET",
		"🔒 LOCKED — BEAT LEVEL 4 FIRST!",
		"• Fight ALL 4 Bosses back-to-back!\n• Single 3-Heart bar (+1 Heart per Boss)!\n• Race the clock for your Best Time!\n• Clear Reward: +250⚡ (+100⚡ replay)!",
		"⚔  START BOSS RUSH  ⚔",
		Color(0.20, 0.08, 0.04, 0.96), Color(1.0, 0.80, 0.22, 0.96), Color(1.0, 0.88, 0.28),
		rush_btn_style, rush_btn_hover_style, locked_btn_style,
		renderer._draw_story_boss_rush_preview, start_boss_rush
	)
	vbox.add_child(card_rush["card"])
	main._story_boss_rush_preview_ctrl = card_rush["preview"]
	main._story_boss_rush_stars_label = card_rush["stars"]
	main._story_boss_rush_status_label = card_rush["status"]
	main._story_boss_rush_fight_btn = card_rush["btn"]

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
	back_btn.add_theme_stylebox_override("normal", main._btn_style)
	back_btn.add_theme_stylebox_override("hover", main._btn_style)
	back_btn.add_theme_stylebox_override("pressed", main._btn_style)
	back_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back_btn.pressed.connect(main._close_story_screen)
	panel.add_child(back_btn)


func _create_boss_card(
	card_name: String, preview_name: String, title_name: String, stars_name: String,
	status_name: String, desc_name: String, btn_name: String,
	title_txt: String, status_txt: String, desc_txt: String, btn_txt: String,
	bg_col: Color, border_col: Color, title_col: Color,
	btn_style: StyleBox, btn_hover_style: StyleBox, locked_btn_style: StyleBox,
	preview_draw_cb: Callable, btn_pressed_cb: Callable
) -> Dictionary:
	var card := Panel.new()
	card.name = card_name
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(388.0, 184.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var c_style := StyleBoxFlat.new()
	c_style.set_corner_radius_all(18)
	c_style.bg_color = bg_col
	c_style.set_border_width_all(3)
	c_style.set_border_color(border_col)
	c_style.set_shadow_color(Color(border_col.r, border_col.g, border_col.b, 0.35))
	c_style.set_shadow_size(10)
	card.add_theme_stylebox_override("panel", c_style)

	var preview := Control.new()
	preview.name = preview_name
	preview.position = Vector2(8.0, 14.0)
	preview.size = Vector2(96.0, 156.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(preview_draw_cb)
	card.add_child(preview)

	var title_lbl := Label.new()
	title_lbl.name = title_name
	title_lbl.text = title_txt
	title_lbl.clip_text = true
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.offset_left = 112.0
	title_lbl.offset_right = 312.0
	title_lbl.offset_top = 8.0
	title_lbl.offset_bottom = 28.0
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", title_col)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.14, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 4)
	card.add_child(title_lbl)

	var stars_lbl := Label.new()
	stars_lbl.name = stars_name
	stars_lbl.text = "☆☆☆"
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars_lbl.clip_text = true
	stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_lbl.offset_left = 308.0
	stars_lbl.offset_right = 382.0
	stars_lbl.offset_top = 7.0
	stars_lbl.offset_bottom = 28.0
	stars_lbl.add_theme_font_size_override("font_size", 12)
	stars_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	card.add_child(stars_lbl)

	var status_lbl := Label.new()
	status_lbl.name = status_name
	status_lbl.text = status_txt
	status_lbl.clip_text = true
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_lbl.offset_left = 112.0
	status_lbl.offset_right = 382.0
	status_lbl.offset_top = 29.0
	status_lbl.offset_bottom = 46.0
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	card.add_child(status_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = desc_name
	desc_lbl.text = desc_txt
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.clip_text = true
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.offset_left = 112.0
	desc_lbl.offset_right = 382.0
	desc_lbl.offset_top = 48.0
	desc_lbl.offset_bottom = 128.0
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_constant_override("line_spacing", 2)
	desc_lbl.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	card.add_child(desc_lbl)

	var btn := Button.new()
	btn.name = btn_name
	btn.text = btn_txt
	btn.clip_contents = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.offset_left = 112.0
	btn.offset_right = 380.0
	btn.offset_top = 136.0
	btn.offset_bottom = 172.0
	btn.add_theme_font_size_override("font_size", 13)
	main._apply_menu_button_style(btn, btn_style, btn_hover_style)
	btn.add_theme_stylebox_override("disabled", locked_btn_style)
	btn.add_theme_color_override("font_disabled_color", Color(0.70, 0.68, 0.82))
	btn.pressed.connect(btn_pressed_cb)
	card.add_child(btn)

	return {
		"card": card,
		"preview": preview,
		"stars": stars_lbl,
		"status": status_lbl,
		"btn": btn,
	}


func refresh_story_screen() -> void:
	var s: Node = main.settings
	var lv1_cleared: bool = s != null and s.is_story_level_cleared(1)
	var lv2_cleared: bool = s != null and s.is_story_level_cleared(2)
	var lv3_cleared: bool = s != null and s.is_story_level_cleared(3)
	var lv4_cleared: bool = s != null and s.is_story_level_cleared(4)
	var total_stars: int = s.get_story_total_stars() if s != null else 0

	if main._story_subtitle_label != null and is_instance_valid(main._story_subtitle_label):
		main._story_subtitle_label.text = "★ %d/12 STARS  •  SWIPE WHITE CENTER TO ATTACK!" % total_stars

	# Level 1
	_update_card_status(
		1, true, lv1_cleared,
		main._story_level1_stars_label, main._story_level1_status_label, null,
		"4 PARTS + 15 HP • +50⚡ + SKIN", "+15⚡", "", ""
	)
	# Level 2
	_update_card_status(
		2, lv1_cleared, lv2_cleared,
		main._story_level2_stars_label, main._story_level2_status_label, main._story_level2_fight_btn,
		"4 HEADS + 18 HP • +75⚡ + TRAIL", "+25⚡",
		"⚔  FIGHT HYDRA  ⚔", "🔒  BEAT LVL 1 TO UNLOCK"
	)
	# Level 3
	_update_card_status(
		3, lv2_cleared, lv3_cleared,
		main._story_level3_stars_label, main._story_level3_status_label, main._story_level3_fight_btn,
		"4 WINGS + 20 HP • +100⚡ + TRAIL", "+40⚡",
		"⚔  FIGHT SERAPH  ⚔", "🔒  BEAT LVL 2 TO UNLOCK"
	)
	# Level 4
	_update_card_status(
		4, lv3_cleared, lv4_cleared,
		main._story_level4_stars_label, main._story_level4_status_label, main._story_level4_fight_btn,
		"4 INSTR + 22 HP • +150⚡ + 2 GEAR", "+60⚡",
		"⚔  FIGHT MAESTRO  ⚔", "🔒  BEAT LVL 3 TO UNLOCK"
	)

	# Boss Rush Card
	var rush_cleared: bool = s != null and s.story_boss_rush_cleared
	var rush_best: float = s.story_boss_rush_best_time if s != null else 0.0
	if main._story_boss_rush_stars_label != null and is_instance_valid(main._story_boss_rush_stars_label):
		main._story_boss_rush_stars_label.text = "👑" if rush_cleared else ("⚔" if lv4_cleared else "🔒")
	if main._story_boss_rush_status_label != null and is_instance_valid(main._story_boss_rush_status_label):
		if not lv4_cleared:
			main._story_boss_rush_status_label.text = "🔒 LOCKED — BEAT LEVEL 4 FIRST!"
			main._story_boss_rush_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))
		elif rush_cleared:
			var best_str := ("BEST: " + format_time(rush_best) + " • ") if rush_best > 0.0 else ""
			main._story_boss_rush_status_label.text = "★ CLEARED! ★ " + best_str + "+100⚡"
			main._story_boss_rush_status_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			main._story_boss_rush_status_label.text = "4 BOSSES BACK-TO-BACK • +250⚡"
			main._story_boss_rush_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	if main._story_boss_rush_fight_btn != null and is_instance_valid(main._story_boss_rush_fight_btn):
		main._story_boss_rush_fight_btn.disabled = not lv4_cleared
		main._story_boss_rush_fight_btn.text = "⚔  START BOSS RUSH  ⚔" if lv4_cleared else "🔒  BEAT LVL 4 TO UNLOCK"

	for ctrl in [
		main._story_level1_preview_ctrl,
		main._story_level2_preview_ctrl,
		main._story_level3_preview_ctrl,
		main._story_level4_preview_ctrl,
		main._story_boss_rush_preview_ctrl,
	]:
		if ctrl != null and is_instance_valid(ctrl):
			ctrl.queue_redraw()


func _update_card_status(
	lvl: int, unlocked: bool, cleared: bool,
	stars_lbl: Label, status_lbl: Label, fight_btn: Button,
	unclear_txt: String, replay_sparks: String,
	unlocked_btn_txt: String, locked_btn_txt: String
) -> void:
	var s: Node = main.settings
	var stars: int = s.get_story_level_stars(lvl) if s != null else 0
	var best_t: float = s.get_story_level_best_time(lvl) if s != null else 0.0

	if stars_lbl != null and is_instance_valid(stars_lbl):
		if not unlocked:
			stars_lbl.text = "🔒"
			stars_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.80))
		else:
			stars_lbl.text = format_stars_text(stars)
			stars_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25) if stars > 0 else Color(0.65, 0.65, 0.78))

	if status_lbl != null and is_instance_valid(status_lbl):
		if not unlocked:
			status_lbl.text = "🔒 LOCKED — BEAT LEVEL %d FIRST!" % (lvl - 1)
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))
		elif cleared:
			var t_str := ("⏱ " + format_time(best_t) + " • ") if best_t > 0.0 else ""
			status_lbl.text = "★ CLEARED! ★ " + t_str + "REPLAY: " + replay_sparks
			status_lbl.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		else:
			status_lbl.text = unclear_txt
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))

	if fight_btn != null and is_instance_valid(fight_btn):
		fight_btn.disabled = not unlocked
		fight_btn.text = unlocked_btn_txt if unlocked else locked_btn_txt


func on_story_level_selected(level_num: int) -> void:
	if level_num == 2 and (main.settings == null or not main.settings.is_story_level_cleared(1)):
		main.sfx.play("wrong")
		main._haptic_wrong()
		return
	if level_num == 3 and (main.settings == null or not main.settings.is_story_level_cleared(2)):
		main.sfx.play("wrong")
		main._haptic_wrong()
		return
	if level_num == 4 and (main.settings == null or not main.settings.is_story_level_cleared(3)):
		main.sfx.play("wrong")
		main._haptic_wrong()
		return
	main.sfx.play("tap")
	main._haptic_tap()
	main._story_screen.visible = false
	main.is_story_mode = true
	main.is_boss_rush = false
	main.story_level = level_num
	main._fade_transition(main._start_game)


func start_boss_rush() -> void:
	if main.settings == null or not main.settings.is_story_level_cleared(4):
		main.sfx.play("wrong")
		main._haptic_wrong()
		return
	main.sfx.play("tap")
	main._haptic_tap()
	main._story_screen.visible = false
	main.is_story_mode = true
	main.is_boss_rush = true
	main.story_boss_rush_elapsed = 0.0
	main.story_level = 1
	main._fade_transition(main._start_game)


# =====================================================
# BOSS ARENA SETUP & STATE MANAGEMENT
# =====================================================

func setup_story_boss_arena() -> void:
	if main.game_screen == null:
		return

	main._story_boss_hud = Control.new()
	main._story_boss_hud.name = "StoryBossHUD"
	main._story_boss_hud.visible = false
	main._story_boss_hud.anchor_right = 1.0
	main._story_boss_hud.anchor_bottom = 1.0
	main._story_boss_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._story_boss_hud.z_index = 0
	main.game_screen.add_child(main._story_boss_hud)

	main._story_boss_name_label = Label.new()
	main._story_boss_name_label.name = "BossNameLabel"
	main._story_boss_name_label.text = "⚔ LVL 1: CHROMA TITAN (PARTS: 4/4) ⚔"
	main._story_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main._story_boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main._story_boss_name_label.clip_text = true
	main._story_boss_name_label.add_theme_font_size_override("font_size", 12)
	main._story_boss_name_label.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
	main._story_boss_name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.16, 1.0))
	main._story_boss_name_label.add_theme_constant_override("outline_size", 5)
	main._story_boss_name_label.anchor_left = 0.0
	main._story_boss_name_label.anchor_right = 1.0
	main._story_boss_name_label.offset_left = 16.0
	main._story_boss_name_label.offset_right = -16.0
	main._story_boss_name_label.offset_top = 52.0
	main._story_boss_name_label.offset_bottom = 76.0
	main._story_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._story_boss_hud.add_child(main._story_boss_name_label)

	main._story_boss_canvas = Control.new()
	main._story_boss_canvas.name = "StoryBossCanvas"
	main._story_boss_canvas.anchor_left = 0.0
	main._story_boss_canvas.anchor_right = 1.0
	main._story_boss_canvas.offset_left = 0.0
	main._story_boss_canvas.offset_right = 0.0
	main._story_boss_canvas.offset_top = 74.0
	var offset: float = main.settings.board_vertical_offset if main.settings != null else 0.0
	main._story_boss_canvas.offset_bottom = clampf(418.0 + minf(0.0, offset * 0.85), 330.0, 425.0)
	main._story_boss_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._story_boss_canvas.draw.connect(renderer._draw_story_boss_arena)
	main._story_boss_hud.add_child(main._story_boss_canvas)

	main._story_boss_hp_label = Label.new()
	main._story_boss_hp_label.name = "BossHPLabel"
	main._story_boss_hp_label.text = "🛡️ SHIELDED (15/15) — BREAK 4 PARTS!"
	main._story_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main._story_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main._story_boss_hp_label.clip_text = true
	main._story_boss_hp_label.add_theme_font_size_override("font_size", 10)
	main._story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	main._story_boss_hp_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.14, 1.0))
	main._story_boss_hp_label.add_theme_constant_override("outline_size", 4)
	main._story_boss_hp_label.anchor_left = 0.5
	main._story_boss_hp_label.anchor_right = 0.5
	main._story_boss_hp_label.offset_left = -204.0
	main._story_boss_hp_label.offset_right = 204.0
	main._story_boss_hp_label.offset_top = 78.0
	main._story_boss_hp_label.offset_bottom = 98.0
	main._story_boss_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._story_boss_hud.add_child(main._story_boss_hp_label)


func update_story_hud_visibility() -> void:
	if main.score_label != null and is_instance_valid(main.score_label):
		main.score_label.visible = not main.is_story_mode
	if main.high_score_label != null and is_instance_valid(main.high_score_label):
		main.high_score_label.visible = not main.is_story_mode
	if main._combo_container != null and is_instance_valid(main._combo_container):
		main._combo_container.visible = not main.is_story_mode
	if main._story_boss_hud != null and is_instance_valid(main._story_boss_hud):
		main._story_boss_hud.visible = main.is_story_mode


func are_all_boss_parts_destroyed() -> bool:
	for d: String in ["up", "down", "left", "right"]:
		if int(main.story_part_hp.get(d, 0)) > 0:
			return false
	return true


func get_alive_boss_parts() -> Array[String]:
	var alive: Array[String] = []
	for d: String in ["up", "down", "left", "right"]:
		if int(main.story_part_hp.get(d, 0)) > 0:
			alive.append(d)
	return alive


func get_story_bomb_count() -> int:
	var broken_count: int = 4 - get_alive_boss_parts().size()
	if broken_count >= 4:
		return 3
	if broken_count >= 2:
		return 2
	return 1


func reset_story_boss_state(level_num: int = 1, keep_rush_timer: bool = false) -> void:
	main.story_level = level_num
	main.story_boss_max_hp = 22 if level_num == 4 else (20 if level_num == 3 else (18 if level_num == 2 else 15))
	main.story_boss_hp = main.story_boss_max_hp
	main.story_boss_ghost_hp = float(main.story_boss_max_hp)
	main.story_part_max_hp = 5
	main.story_part_hp = {
		"up": main.story_part_max_hp,
		"down": main.story_part_max_hp,
		"left": main.story_part_max_hp,
		"right": main.story_part_max_hp,
	}
	main.direction_colors = main._get_theme().get("board", {}).duplicate()
	main._story_last_swiped_dir = ""
	main._story_l4_sequence.clear()
	main._story_l4_seq_index = 0
	main._story_l4_mirror_swipes = 0
	main._story_l4_mirror_pending = false
	main._story_l4_turns_until_mirror = 4
	main._story_l4_true_dir = ""
	main._story_l4_reveal_left = 0.0
	main.story_bomb_dir = ""
	main.story_bomb_dirs.clear()
	main.story_boss_enraged = false
	main.story_victory_animating = false
	main.story_level_won = false
	main.story_fight_elapsed = 0.0
	if not keep_rush_timer:
		main.story_boss_rush_elapsed = 0.0
		main.story_last_stars_earned = 0
		main.story_last_unlocked_cosmetics.clear()
	main._boss_anim_time = 0.0
	main._boss_hit_shake = 0.0
	main._boss_taunt_anim = 0.0
	main._boss_throw_anim = 0.0
	main._boss_throw_target_dir = ""
	main._boss_throw_target_dirs.clear()
	main._boss_death_progress = 0.0
	main._boss_part_flash = {"up": 0.0, "down": 0.0, "left": 0.0, "right": 0.0}
	main._boss_part_recoil = {"up": 0.0, "down": 0.0, "left": 0.0, "right": 0.0}
	main._boss_laser_beams.clear()
	main._boss_explosion_shrapnel.clear()
	main._boss_explosion_rings.clear()
	play_boss_music(level_num, false)
	update_story_boss_labels()


func warp_story_level3_colors(avoid_dir: String = "") -> void:
	var dirs: Array[String] = ["up", "down", "left", "right"]
	var old_cols: Dictionary = {}
	var old_hp: Dictionary = {}
	var old_flash: Dictionary = {}
	var old_recoil: Dictionary = {}
	var any_alive: bool = false
	for d: String in dirs:
		old_cols[d] = main.direction_colors.get(d, Color.WHITE)
		var hp_v: int = int(main.story_part_hp.get(d, 0))
		old_hp[d] = hp_v
		if hp_v > 0:
			any_alive = true
		old_flash[d] = float(main._boss_part_flash.get(d, 0.0))
		old_recoil[d] = float(main._boss_part_recoil.get(d, 0.0))

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
		main.direction_colors[dst_d] = old_cols[src_d]
		main.story_part_hp[dst_d] = old_hp[src_d]
		main._boss_part_flash[dst_d] = old_flash[src_d]
		main._boss_part_recoil[dst_d] = old_recoil[src_d]


func update_story_boss_labels() -> void:
	var all_parts_dead := are_all_boss_parts_destroyed()
	var rush_prefix: String = ("[RUSH %d/4] " % main.story_level) if main.is_boss_rush else ""
	if main._story_boss_name_label != null and is_instance_valid(main._story_boss_name_label):
		if main.story_level == 4:
			if all_parts_dead:
				main._story_boss_name_label.text = rush_prefix + "🎭 PHANTOM MAESTRO — MASK UNVEILED! 🎭"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.48))
			else:
				var instr_left: int = get_alive_boss_parts().size()
				main._story_boss_name_label.text = rush_prefix + "🎭 LVL 4: PHANTOM MAESTRO (INSTR: " + str(instr_left) + "/4) 🎭"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.38))
		elif main.story_level == 3:
			if all_parts_dead:
				main._story_boss_name_label.text = rush_prefix + "🌀 VOID SERAPH — CORE EXPOSED! 🌀"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.95))
			else:
				var wings_left: int = get_alive_boss_parts().size()
				main._story_boss_name_label.text = rush_prefix + "🌀 LVL 3: VOID SERAPH (WINGS: " + str(wings_left) + "/4) 🌀"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(0.92, 0.55, 1.0))
		elif main.story_level == 2:
			if all_parts_dead:
				main._story_boss_name_label.text = rush_prefix + "🐍 CYBER HYDRA — HEART EXPOSED! 🐍"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.75))
			else:
				var heads_left: int = get_alive_boss_parts().size()
				main._story_boss_name_label.text = rush_prefix + "🐍 LVL 2: CYBER HYDRA (HEADS: " + str(heads_left) + "/4) 🐍"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(0.28, 1.0, 0.75))
		else:
			if all_parts_dead:
				main._story_boss_name_label.text = rush_prefix + "🔥 CHROMA TITAN — CORE EXPOSED! 🔥"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45))
			else:
				var parts_left: int = get_alive_boss_parts().size()
				main._story_boss_name_label.text = rush_prefix + "⚔ LVL 1: CHROMA TITAN (PARTS: " + str(parts_left) + "/4) ⚔"
				main._story_boss_name_label.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))

	if main._story_boss_hp_label != null and is_instance_valid(main._story_boss_hp_label):
		if main.story_level == 4:
			if main._story_l4_mirror_swipes > 0:
				main._story_boss_hp_label.text = "🪞 MIRROR CURSE x" + str(main._story_l4_mirror_swipes) + " — SWIPES REVERSED! 🪞"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
			elif all_parts_dead:
				main._story_boss_hp_label.text = "🎭 MAIN HP: " + str(maxi(0, main.story_boss_hp)) + " / " + str(main.story_boss_max_hp) + " (FIND THE TRUE MASK!) 🎭"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
			else:
				var instr_left_hp: int = get_alive_boss_parts().size()
				main._story_boss_hp_label.text = "🎵 SHIELDED (" + str(main.story_boss_hp) + "/" + str(main.story_boss_max_hp) + ") — SILENCE " + str(instr_left_hp) + " INSTRUMENTS!"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
		elif main.story_level == 3:
			if all_parts_dead:
				main._story_boss_hp_label.text = "🌀 MAIN HP: " + str(maxi(0, main.story_boss_hp)) + " / " + str(main.story_boss_max_hp) + " (3 VOID RIFTS!) 🌀"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(0.95, 0.62, 1.0))
			else:
				var wings_left_hp: int = get_alive_boss_parts().size()
				main._story_boss_hp_label.text = "🛡️ SHIELDED (" + str(main.story_boss_hp) + "/" + str(main.story_boss_max_hp) + ") — SHATTER " + str(wings_left_hp) + " WINGS!"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(0.95, 0.84, 1.0))
		elif main.story_level == 2:
			if all_parts_dead:
				main._story_boss_hp_label.text = "🐍 MAIN HP: " + str(maxi(0, main.story_boss_hp)) + " / " + str(main.story_boss_max_hp) + " (3 SHIELDS!) 🐍"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.78))
			else:
				var heads_left_hp: int = get_alive_boss_parts().size()
				main._story_boss_hp_label.text = "🛡️ SHIELDED (" + str(main.story_boss_hp) + "/" + str(main.story_boss_max_hp) + ") — SEVER " + str(heads_left_hp) + " HEADS!"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(0.80, 1.0, 0.92))
		else:
			if all_parts_dead:
				main._story_boss_hp_label.text = "🔥 MAIN HP: " + str(maxi(0, main.story_boss_hp)) + " / " + str(main.story_boss_max_hp) + " (3 BOMBS!) 🔥"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
			else:
				var parts_left_hp: int = get_alive_boss_parts().size()
				main._story_boss_hp_label.text = "🛡️ SHIELDED (" + str(main.story_boss_hp) + "/" + str(main.story_boss_max_hp) + ") — BREAK " + str(parts_left_hp) + " PARTS!"
				main._story_boss_hp_label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))


# =====================================================
# STORY MODE TURN & COMBAT LOOP
# =====================================================

func start_story_turn() -> void:
	if main.state != main.settings.GameState.PLAYING or main.story_victory_animating:
		return

	main.powerup_square_dir = ""
	main.powerup_type = ""
	main.is_hold_turn = false
	main.is_holding_active = false
	main.is_double_turn = false
	main.double_turn_step = 0
	main._cleanup_hold_ui()
	main._cleanup_double_turn_ui()

	var hp_missing_ratio: float = clampf(1.0 - float(main.story_boss_hp) / float(maxi(1, main.story_boss_max_hp)), 0.0, 1.0)
	var base_limit: float = GameSettings.INITIAL_TIME_LIMIT - hp_missing_ratio * 0.22
	if main.story_boss_enraged:
		base_limit -= 0.08
	main.current_time_limit = clampf(base_limit, 0.78, GameSettings.INITIAL_TIME_LIMIT)
	main.time_left_in_turn = main.current_time_limit
	main._turn_start_time = Time.get_ticks_msec() / 1000.0

	main.set_random_center_color()

	if main.story_level == 4:
		_start_story_level4_turn()
		return

	var all_dirs: Array[String] = ["up", "down", "left", "right"]
	var alive_parts: Array[String] = get_alive_boss_parts()
	var bomb_count: int = get_story_bomb_count()
	var prev_bombs: Array[String] = main.story_bomb_dirs.duplicate()

	main.story_bomb_dirs.clear()
	if alive_parts.is_empty():
		var prev_safe: String = main._story_last_swiped_dir if (main.story_level == 3 and main._story_last_swiped_dir != "") else ""
		if prev_safe == "":
			for d: String in all_dirs:
				if d not in prev_bombs:
					prev_safe = d
					break
		var safe_candidates: Array[String] = []
		for d: String in all_dirs:
			if d != prev_safe:
				safe_candidates.append(d)
		var force_move_safe: bool = (main.story_level == 3) or (randf() < 0.80)
		var safe_dir: String = safe_candidates.pick_random() if (not safe_candidates.is_empty() and force_move_safe) else all_dirs.pick_random()
		for d: String in all_dirs:
			if d != safe_dir:
				main.story_bomb_dirs.append(d)
	else:
		var candidate_alive: Array[String] = []
		if main.story_level == 3 and main._story_last_swiped_dir != "":
			for d: String in alive_parts:
				if d != main._story_last_swiped_dir:
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
		if main.story_level == 3 and main._story_last_swiped_dir != "" and main._story_last_swiped_dir != protected_dir:
			ordered_pool.append(main._story_last_swiped_dir)
			for d: String in allowed_bomb_dirs:
				if d != main._story_last_swiped_dir:
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
			main.story_bomb_dirs.append(ordered_pool[i])

	main.story_bomb_dir = main.story_bomb_dirs[0] if not main.story_bomb_dirs.is_empty() else ""
	main._boss_throw_target_dirs = main.story_bomb_dirs.duplicate()
	main._boss_throw_target_dir = main.story_bomb_dir
	main._boss_throw_anim = 1.0

	main._apply_board_colors()
	main._pulse_center()


func on_story_swipe(direction: String) -> void:
	if main.state != main.settings.GameState.PLAYING or main.story_victory_animating:
		return

	main._clear_persistent_labels()
	main._squash_stretch_center(direction)
	main.total_swipes += 1

	if main.story_level == 4:
		_on_story_level4_swipe(direction)
		return

	if direction in main.story_bomb_dirs or (main.story_bomb_dir != "" and direction == main.story_bomb_dir):
		on_story_bomb_hit(direction)
		return

	if not main.story_bomb_dirs.is_empty():
		for b_dir: String in main.story_bomb_dirs:
			var old_bomb_pos: Vector2 = main._get_board_center(b_dir)
			main._burst_particles(old_bomb_pos, Color(0.75, 0.85, 1.0, 0.7), 4)
		main.story_bomb_dirs.clear()
	main.story_bomb_dir = ""

	on_story_boss_hit(direction)


func on_story_bomb_hit(bomb_dir: String) -> void:
	var bomb_pos: Vector2 = main._get_board_center(bomb_dir)
	main.story_bomb_dirs.clear()
	main.story_bomb_dir = ""
	main._boss_taunt_anim = 1.0
	main._story_last_swiped_dir = bomb_dir

	if main.story_level == 3:
		main._flash_square(bomb_dir, Color(1.55, 0.35, 1.95, 0.98))
		main._burst_particles(bomb_pos, Color(1.35, 0.28, 1.85), 26)
		main._burst_particles(bomb_pos, Color(1.0, 0.90, 0.35), 14)
		main._burst_at(bomb_pos, Color(1.25, 0.25, 1.75))
		warp_story_level3_colors(bomb_dir)
		update_story_boss_labels()
	elif main.story_level == 2:
		main._flash_square(bomb_dir, Color(0.25, 1.8, 1.1, 0.98))
		main._burst_particles(bomb_pos, Color(0.2, 1.5, 0.95), 24)
		main._burst_particles(bomb_pos, Color(0.95, 0.35, 1.6), 14)
		main._burst_at(bomb_pos, Color(0.2, 1.4, 0.85))
		if are_all_boss_parts_destroyed():
			main.story_boss_hp = mini(main.story_boss_max_hp, main.story_boss_hp + 2)
		else:
			var cur_h: int = int(main.story_part_hp.get(bomb_dir, 0))
			if cur_h > 0 and cur_h < main.story_part_max_hp:
				main.story_part_hp[bomb_dir] = mini(main.story_part_max_hp, cur_h + 1)
			else:
				for d_heal: String in ["up", "down", "left", "right"]:
					var dh_val: int = int(main.story_part_hp.get(d_heal, 0))
					if dh_val > 0 and dh_val < main.story_part_max_hp:
						main.story_part_hp[d_heal] = mini(main.story_part_max_hp, dh_val + 1)
						break
		update_story_boss_labels()
	else:
		main._flash_square(bomb_dir, Color(1.8, 0.25, 0.2, 0.98))
		main._burst_particles(bomb_pos, Color(1.5, 0.35, 0.15), 24)
		main._burst_particles(bomb_pos, Color(1.0, 0.85, 0.2), 14)
		main._burst_at(bomb_pos, Color(1.4, 0.25, 0.2))

	main.lives -= 1
	main._lost_heart_this_game = true
	main.streak = 0
	main.perfect_streak = 0
	main._audio_pulse = 0.9

	main.sfx.play("wrong")
	main._haptic_danger()
	main._shake_screen(14.0)
	main._flash_center_red()
	if main.story_level == 3:
		main._show_persistent_label("🌀 VOID RIFT! -1 HP (COLORS WARPED)", bomb_pos, Color(0.95, 0.55, 1.0), true)
	elif main.story_level == 2:
		main._show_persistent_label("🛡️ REFLECT! -1 HP (BOSS HEALED)", bomb_pos, Color(0.28, 1.0, 0.82), true)
	else:
		main._show_persistent_label("💥 BOMB! -1 HP", bomb_pos, Color(1.0, 0.3, 0.32), true)
	main._update_lives_display()
	main._apply_board_colors()

	if main.lives <= 0:
		main._game_over()
	else:
		main.start_new_turn()


func on_story_boss_hit(direction: String, dmg: int = 1) -> void:
	dmg = maxi(1, dmg)
	var encore_prefix: String = "🎵 ENCORE! " if dmg > 1 else ""
	main._story_last_swiped_dir = direction
	var reaction_time: float = (Time.get_ticks_msec() / 1000.0) - main._turn_start_time
	if reaction_time > 0.03 and reaction_time < main.fastest_reaction_this_game:
		main.fastest_reaction_this_game = reaction_time
	if (main.current_time_limit - main.time_left_in_turn) <= 0.40:
		main._fast_swipes_this_game += 1

	main.streak += 1
	if main.streak > main.best_streak_this_game:
		main.best_streak_this_game = main.streak
	main.total_correct += 1

	var mult: int = main._current_combo_multiplier()
	var hit_col: Color = main.direction_colors.get(direction, Color(0.3, 0.95, 1.0))
	var sq_center: Vector2 = main._get_board_center(direction)
	var all_parts_already_dead := are_all_boss_parts_destroyed()
	var target_dir: String = "core" if all_parts_already_dead else direction
	var boss_part_pos := get_boss_part_screen_pos(target_dir)
	var canvas_top: float = main._story_boss_canvas.offset_top if (main._story_boss_canvas != null and is_instance_valid(main._story_boss_canvas)) else 74.0
	var canvas_local_pos := boss_part_pos - Vector2(0.0, canvas_top)

	main._boss_laser_beams.append({
		"from": sq_center,
		"to": boss_part_pos,
		"color": hit_col,
		"age": 0.0,
		"duration": 0.28,
	})

	var part_names := {
		"up": "BELL" if main.story_level == 4 else ("TOP WING" if main.story_level == 3 else ("TOP FANG" if main.story_level == 2 else "HEAD")),
		"down": "DRUM" if main.story_level == 4 else ("SOLAR HALO" if main.story_level == 3 else ("LOW FANG" if main.story_level == 2 else "ARMOR")),
		"left": "HARP" if main.story_level == 4 else ("LEFT WING" if main.story_level == 3 else ("LEFT FANG" if main.story_level == 2 else "CLAW")),
		"right": "HORN" if main.story_level == 4 else ("RIGHT WING" if main.story_level == 3 else ("RIGHT FANG" if main.story_level == 2 else "CANNON")),
	}
	var p_name: String = str(part_names.get(direction, "PART"))
	var streak_pitch: float = 1.0 + float(main.streak % 14) * 0.024

	# PHASE 1: DESTROY ALL 4 BODY PARTS FIRST
	if not all_parts_already_dead:
		var cur_part_hp: int = int(main.story_part_hp.get(direction, 0))
		if cur_part_hp > 0:
			cur_part_hp = maxi(0, cur_part_hp - dmg)
			main.story_part_hp[direction] = cur_part_hp
			var part_destroyed_now: bool = (cur_part_hp <= 0)

			main._boss_part_flash[direction] = 1.0
			main._boss_part_recoil[direction] = 1.0
			main._boss_hit_shake = 1.0 if part_destroyed_now else 0.65
			main._audio_pulse = minf(1.0, main._audio_pulse + (0.95 if part_destroyed_now else 0.70))
			main.score += (350 if part_destroyed_now else 150) * mult

			main._flash_square(direction, Color(1.0, 1.0, 1.0, 0.8))
			main._burst_particles(sq_center, hit_col, 8)
			main._burst_particles(boss_part_pos, hit_col.lightened(0.25), 24 if part_destroyed_now else 11)
			main._burst_at(boss_part_pos, hit_col)

			if part_destroyed_now:
				spawn_boss_canvas_explosion(canvas_local_pos, hit_col, 0.95)
				main.sfx.play_pitched("unlock", 1.12)
				main._haptic_frenzy()
				main._shake_screen(11.0)
				var verb_broken := "SILENCED" if main.story_level == 4 else ("SHATTERED" if main.story_level == 3 else ("SEVERED" if main.story_level == 2 else "BROKEN"))
				if are_all_boss_parts_destroyed():
					main.story_boss_enraged = true
					set_boss_music_enraged(true)
					main.sfx.play_voice("overdrive", 88, 1.2)
					if main.story_level == 4:
						main._story_l4_sequence.clear()
						main._story_l4_seq_index = 0
						main._show_remap_banner("🎭 MASK UNVEILED: FIND THE TRUE MASK! 🎭")
					elif main.story_level == 3:
						main._show_remap_banner("🌀 CORE EXPOSED: 3 VOID RIFTS! 🌀")
					elif main.story_level == 2:
						main._show_remap_banner("🐍 HEART EXPOSED: 3 SHIELDS! 🐍")
					else:
						main._show_remap_banner("🔥 CORE EXPOSED: 3 BOMBS! 🔥")
					main._show_persistent_label("💥 " + p_name + " " + verb_broken + "!", sq_center, Color(1.0, 0.92, 0.25), true)
				else:
					var rem_parts: int = get_alive_boss_parts().size()
					if main.story_level == 4 and rem_parts == 3:
						main._show_remap_banner("🪞 MIRROR CURSE AWAKENS! 🪞")
					elif rem_parts == 2:
						if main.story_level == 4:
							main._show_remap_banner("⚠️ MAESTRO ENRAGED: 3-NOTE MELODIES! ⚠️")
						elif main.story_level == 3:
							main._show_remap_banner("⚠️ SERAPH ENRAGED: 2 VOID RIFTS! ⚠️")
						elif main.story_level == 2:
							main._show_remap_banner("⚠️ HYDRA ENRAGED: 2 SHIELDS! ⚠️")
						else:
							main._show_remap_banner("⚠️ BOSS ENRAGED: 2 BOMBS! ⚠️")
					main._show_persistent_label("💥 " + p_name + " " + verb_broken + "! (" + str(rem_parts) + " LEFT)", sq_center, Color(1.0, 0.92, 0.25), true)
			else:
				main.sfx.play_pitched("correct", streak_pitch)
				main._haptic_correct()
				main._shake_screen(4.5)
				main._show_persistent_label(encore_prefix + p_name + " -" + str(dmg) + " (" + str(cur_part_hp) + "/" + str(main.story_part_max_hp) + ")", sq_center, hit_col.lightened(0.2), dmg > 1)
		else:
			if main.story_level == 4:
				main._boss_part_flash[direction] = 0.35
				main.sfx.play_pitched("correct", streak_pitch * 0.92)
				main._haptic_correct()
				main._flash_square(direction, Color(1.0, 0.88, 0.55, 0.6))
				main._burst_particles(sq_center, Color(1.0, 0.85, 0.45), 6)
				main._show_persistent_label("🎵 NOTE " + str(main._story_l4_seq_index) + " ✓", sq_center, Color(1.0, 0.90, 0.55), false)
			elif main.story_level == 3:
				main.story_boss_hp = mini(main.story_boss_max_hp + 6, main.story_boss_hp + 2)
				main.story_boss_ghost_hp = float(main.story_boss_hp)
				main._boss_part_flash["down"] = 1.0
				main._boss_taunt_anim = 0.85
				main.sfx.play_pitched("wrong", 1.18)
				main._haptic_wrong()
				main._shake_screen(8.0)
				main._flash_square(direction, Color(1.45, 0.35, 1.85, 0.85))
				main._burst_particles(boss_part_pos, Color(1.35, 0.35, 1.85), 16)
				main._show_persistent_label("🌀 VOID DRAIN! CORE +2 HP!", sq_center, Color(0.95, 0.55, 1.0), true)
			elif main.story_level == 2:
				main.story_part_hp[direction] = 2
				main._boss_part_flash[direction] = 1.0
				main._boss_part_recoil[direction] = -0.8
				main._boss_taunt_anim = 0.85
				main.sfx.play_pitched("wrong", 1.15)
				main._haptic_wrong()
				main._shake_screen(8.0)
				main._flash_square(direction, Color(0.25, 1.6, 0.75, 0.85))
				main._burst_particles(boss_part_pos, Color(0.25, 1.5, 0.75), 16)
				main._show_persistent_label("🐍 HEAD REGROWN! (2/" + str(main.story_part_max_hp) + ")", sq_center, Color(0.30, 1.0, 0.68), true)
			else:
				main._boss_part_flash[direction] = 0.45
				main._boss_part_recoil[direction] = 0.35
				main.sfx.play_pitched("tap", 0.95)
				main._haptic_tap()
				main._flash_square(direction, Color(0.7, 0.75, 0.85, 0.5))
				main._burst_particles(boss_part_pos, Color(0.6, 0.65, 0.75), 5)
				main._show_persistent_label("⚡ HIT ACTIVE PARTS!", sq_center, Color(0.85, 0.90, 1.0), false)

		if main.story_level == 3:
			warp_story_level3_colors(direction)
		update_story_boss_labels()
		main._apply_board_colors()
		main.start_new_turn()
		return

	# PHASE 2: ALL 4 BODY PARTS DESTROYED -> DRAIN MAIN BOSS HP
	main.story_boss_hp = maxi(0, main.story_boss_hp - dmg)
	main._boss_part_flash["down"] = 1.0
	main._boss_part_flash[direction] = 0.85
	main._boss_part_recoil["down"] = 1.0
	main._boss_part_recoil[direction] = 0.65
	main._boss_hit_shake = 0.85
	main._audio_pulse = minf(1.0, main._audio_pulse + 0.82)
	main.score += 220 * mult

	main.sfx.play_pitched("correct", streak_pitch + 0.08)
	if main.streak % 5 == 0:
		main.sfx.play_pitched("combo", 1.10)
		main._haptic_combo()
	else:
		main._haptic_correct()
	main._shake_screen(6.5)

	main._flash_square(direction, Color(1.0, 1.0, 1.0, 0.85))
	main._burst_particles(sq_center, hit_col, 10)
	main._burst_particles(boss_part_pos, hit_col.lightened(0.3), 16)
	main._burst_at(boss_part_pos, hit_col)
	spawn_boss_canvas_explosion(canvas_local_pos, hit_col, 0.45)

	main._show_persistent_label(encore_prefix + "🔥 HP -" + str(dmg) + " (" + str(main.story_boss_hp) + "/" + str(main.story_boss_max_hp) + ")", sq_center, Color(1.0, 0.88, 0.28), false)

	if main.story_level == 3 and main.story_boss_hp > 0:
		warp_story_level3_colors(direction)
	update_story_boss_labels()
	main._apply_board_colors()

	if main.story_boss_hp <= 0:
		trigger_story_boss_victory()
		return

	main.start_new_turn()


func spawn_boss_canvas_explosion(pos: Vector2, col: Color, intensity: float = 1.0) -> void:
	main._boss_explosion_rings.append({
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
		main._boss_explosion_shrapnel.append({
			"pos": pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"rot": randf() * TAU,
			"rot_speed": randf_range(-14.0, 14.0),
			"size": randf_range(5.0, 14.0) * clampf(intensity, 0.75, 1.35),
			"color": shard_col,
			"age": 0.0,
			"duration": randf_range(0.45, 0.95),
		})


func trigger_story_boss_victory() -> void:
	main.story_victory_animating = true
	main.story_bomb_dir = ""
	main.story_bomb_dirs.clear()
	main._boss_throw_target_dirs.clear()
	main._center_scale_locked = true
	if main.center_square != null:
		main.center_square.scale = Vector2.ONE
	main._apply_board_colors()

	# --- BOSS RUSH INTERMEDIATE STAGE (Levels 1, 2, 3 -> Advance to Next Boss!) ---
	if main.is_boss_rush and main.story_level < 4:
		var cleared_lvl: int = main.story_level
		main.score += 2000 * cleared_lvl
		main.sfx.play("unlock")
		main._haptic_celebration()
		main._shake_screen(15.0)
		var healed: bool = main.lives < GameSettings.MAX_LIVES
		if healed:
			main.lives = mini(GameSettings.MAX_LIVES, main.lives + 1)
			main._update_lives_display()
		var banner_txt: String = "⚡ BOSS %d/4 DOWN!%s NEXT BOSS! ⚡" % [cleared_lvl, " +1 HEART —" if healed else ""]
		main._show_remap_banner(banner_txt)
		_play_boss_explosion_sequence(1.30, func():
			if not main.is_inside_tree():
				return
			main._center_scale_locked = false
			reset_story_boss_state(cleared_lvl + 1, true)
			main.start_new_turn()
		)
		return

	# --- FINAL VICTORY (Standard Story Level OR Boss Rush Level 4 Clear) ---
	main.story_level_won = true
	var first_clear: bool = false
	var unlocked_cosmetics: Array[String] = []
	var stars_earned: int = 1

	if main.is_boss_rush:
		if main.settings != null and not main._tamper_flagged:
			var rush_res: Dictionary = main.settings.record_boss_rush_clear(main.story_boss_rush_elapsed)
			first_clear = bool(rush_res.get("first_clear", false))
			var rush_sparks: int = 250 if first_clear else 100
			main.settings.add_sparks(rush_sparks)
			main.sparks_collected_in_run += rush_sparks
			main.score += 12000
			main._update_sparks_displays()
		main.story_last_stars_earned = 3
		main.sfx.play("unlock")
		main.sfx.play_voice("legendary", 98, 0.5)
		main._haptic_celebration()
		main._shake_screen(18.0)
		main._show_remap_banner("👑 BOSS RUSH CONQUERED! 👑")
	else:
		var target_t: float = float(STORY_TARGET_TIMES.get(main.story_level, 60.0))
		var fast_clear: bool = main.story_fight_elapsed <= target_t
		var no_hit: bool = not main._lost_heart_this_game
		stars_earned = 1 + (1 if fast_clear else 0) + (1 if no_hit else 0)
		main.story_last_stars_earned = stars_earned

		if main.settings != null and not main._tamper_flagged:
			var res: Dictionary = main.settings.record_story_level_result(main.story_level, main.story_fight_elapsed, stars_earned)
			first_clear = bool(res.get("first_clear", false))
			unlocked_cosmetics = res.get("unlocked_cosmetics", [])
			main.story_last_unlocked_cosmetics = unlocked_cosmetics.duplicate()
			var spark_reward: int = 50 if first_clear else 15
			if main.story_level == 4:
				spark_reward = 150 if first_clear else 60
			elif main.story_level == 3:
				spark_reward = 100 if first_clear else 40
			elif main.story_level == 2:
				spark_reward = 75 if first_clear else 25
			main.settings.add_sparks(spark_reward)
			main.sparks_collected_in_run += spark_reward
			main.score += 6500 if main.story_level == 4 else (5000 if main.story_level == 3 else (3500 if main.story_level == 2 else 2500))
			main._update_sparks_displays()

		main.sfx.play("unlock")
		main.sfx.play_voice("legendary", 98, 0.5)
		main._haptic_celebration()
		main._shake_screen(18.0)
		if main.story_level == 4:
			main._show_remap_banner("💥 MAESTRO SILENCED! 💥")
		elif main.story_level == 3:
			main._show_remap_banner("💥 SERAPH OBLITERATED! 💥")
		elif main.story_level == 2:
			main._show_remap_banner("💥 HYDRA OBLITERATED! 💥")
		else:
			main._show_remap_banner("💥 BOSS OBLITERATED! 💥")

	_play_boss_explosion_sequence(1.65, func():
		if not main.is_inside_tree():
			return
		main.story_victory_animating = false
		if main.is_boss_rush and first_clear:
			main._queue_achievement_toast({
				"header": "BOSS RUSH CONQUERED!  +250 SPARKS",
				"name": "GAUNTLET CHAMPION",
				"desc": "Defeated all 4 Bosses back-to-back in " + format_time(main.story_boss_rush_elapsed) + "!",
				"icon": "crown",
				"color": Color(1.0, 0.85, 0.22),
			})
		elif first_clear:
			var cosmetic_note := (" + " + unlocked_cosmetics[0]) if not unlocked_cosmetics.is_empty() else ""
			if main.story_level == 4:
				main._queue_achievement_toast({
					"header": "STORY LEVEL 4 CLEARED!  +150 SPARKS",
					"name": "PHANTOM MAESTRO SLAYER",
					"desc": "Unlocked PHANTOM NOTES & OPERA CHIME!",
					"icon": "crown",
					"color": Color(1.0, 0.72, 0.32),
				})
			elif main.story_level == 3:
				main._queue_achievement_toast({
					"header": "STORY LEVEL 3 CLEARED!  +100 SPARKS",
					"name": "VOID SERAPH SLAYER",
					"desc": "Defeated Void Seraph" + cosmetic_note + "!",
					"icon": "crown",
					"color": Color(0.92, 0.48, 1.0),
				})
			elif main.story_level == 2:
				main._queue_achievement_toast({
					"header": "STORY LEVEL 2 CLEARED!  +75 SPARKS",
					"name": "CYBER HYDRA SLAYER",
					"desc": "Defeated Cyber Hydra" + cosmetic_note + "!",
					"icon": "crown",
					"color": Color(0.20, 1.0, 0.68),
				})
			else:
				main._queue_achievement_toast({
					"header": "STORY LEVEL 1 CLEARED!  +50 SPARKS",
					"name": "CHROMA TITAN SLAYER",
					"desc": "Defeated Chroma Titan" + cosmetic_note + "!",
					"icon": "crown",
					"color": Color(0.35, 0.95, 1.0),
				})
		main._game_over()
	)


func _play_boss_explosion_sequence(total_sec: float, on_complete: Callable) -> void:
	var canvas_top: float = main._story_boss_canvas.offset_top if (main._story_boss_canvas != null and is_instance_valid(main._story_boss_canvas)) else 74.0
	var boss_center_screen := get_boss_part_screen_pos("down")
	spawn_boss_canvas_explosion(boss_center_screen - Vector2(0.0, canvas_top), Color(1.0, 0.85, 0.25), 1.45)

	var dirs := ["up", "left", "right", "down"]
	var death_tw := main.create_tween()
	death_tw.tween_property(main, "_boss_death_progress", 1.0, maxf(0.5, total_sec - 0.15))

	var burst_count := 8 if total_sec < 1.5 else 10
	for i in range(burst_count):
		var delay_t: float = float(i) * 0.13
		main.get_tree().create_timer(delay_t).timeout.connect(func():
			if not main.is_inside_tree():
				return
			var d_key: String = dirs[i % dirs.size()]
			var p_pos := get_boss_part_screen_pos(d_key) + Vector2(randf_range(-34.0, 34.0), randf_range(-26.0, 26.0))
			var exp_col: Color = main.direction_colors.get(d_key, Color(1.0, 0.85, 0.2))
			main._boss_part_flash[d_key] = 1.0
			main._boss_hit_shake = 1.0
			spawn_boss_canvas_explosion(p_pos - Vector2(0.0, canvas_top), exp_col, 1.15 if i < burst_count - 2 else 1.75)
			main._burst_particles(p_pos, exp_col, 24)
			main._burst_particles(p_pos, Color(1.0, 0.95, 0.4), 16)
			main._shake_screen(12.0 if i < burst_count - 2 else 20.0)
			if i % 2 == 0:
				main.sfx.play_pitched("combo", 0.88 + float(i) * 0.08)
				main._haptic_tap()
		)

	main.get_tree().create_timer(total_sec).timeout.connect(on_complete)


func get_boss_part_screen_pos(direction: String) -> Vector2:
	var canvas_top: float = 74.0
	var canvas_h: float = 344.0
	if main._story_boss_canvas != null and is_instance_valid(main._story_boss_canvas):
		canvas_top = main._story_boss_canvas.offset_top
		canvas_h = maxf(240.0, main._story_boss_canvas.offset_bottom - main._story_boss_canvas.offset_top)
	var boss_origin := Vector2(270.0, canvas_top + canvas_h * 0.60)
	if main.story_level == 4:
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


func process_story_boss_visuals(delta: float) -> void:
	main._boss_anim_time += delta

	if main._story_screen != null and main._story_screen.visible:
		for ctrl in [
			main._story_level1_preview_ctrl,
			main._story_level2_preview_ctrl,
			main._story_level3_preview_ctrl,
			main._story_level4_preview_ctrl,
			main._story_boss_rush_preview_ctrl,
		]:
			if ctrl != null and is_instance_valid(ctrl):
				ctrl.queue_redraw()

	if not main.is_story_mode:
		return

	if main.state == main.settings.GameState.PLAYING and not main.story_victory_animating:
		main.story_fight_elapsed += delta
		if main.is_boss_rush:
			main.story_boss_rush_elapsed += delta

	if main.story_level == 4 and main._story_l4_reveal_left > 0.0:
		main._story_l4_reveal_left = maxf(0.0, main._story_l4_reveal_left - delta)
		if main._story_l4_reveal_left <= 0.0:
			main._apply_board_colors()

	main.story_boss_ghost_hp = move_toward(main.story_boss_ghost_hp, float(main.story_boss_hp), delta * 12.0)
	main._boss_hit_shake = maxf(0.0, main._boss_hit_shake - delta * 4.5)
	main._boss_taunt_anim = maxf(0.0, main._boss_taunt_anim - delta * 2.5)
	main._boss_throw_anim = maxf(0.0, main._boss_throw_anim - delta * 3.4)

	for d: String in ["up", "down", "left", "right"]:
		main._boss_part_flash[d] = maxf(0.0, float(main._boss_part_flash.get(d, 0.0)) - delta * 5.0)
		main._boss_part_recoil[d] = maxf(0.0, float(main._boss_part_recoil.get(d, 0.0)) - delta * 4.2)

	var idx: int = main._boss_laser_beams.size() - 1
	while idx >= 0:
		var beam: Dictionary = main._boss_laser_beams[idx]
		var next_age: float = float(beam.get("age", 0.0)) + delta
		var dur: float = float(beam.get("duration", 0.28))
		if next_age >= dur:
			main._boss_laser_beams.remove_at(idx)
		else:
			beam["age"] = next_age
			main._boss_laser_beams[idx] = beam
		idx -= 1

	var r_idx: int = main._boss_explosion_rings.size() - 1
	while r_idx >= 0:
		var ring: Dictionary = main._boss_explosion_rings[r_idx]
		var next_age: float = float(ring.get("age", 0.0)) + delta
		var dur: float = float(ring.get("duration", 0.45))
		if next_age >= dur:
			main._boss_explosion_rings.remove_at(r_idx)
		else:
			ring["age"] = next_age
			main._boss_explosion_rings[r_idx] = ring
		r_idx -= 1

	var s_idx: int = main._boss_explosion_shrapnel.size() - 1
	while s_idx >= 0:
		var shard: Dictionary = main._boss_explosion_shrapnel[s_idx]
		var next_age: float = float(shard.get("age", 0.0)) + delta
		var dur: float = float(shard.get("duration", 0.7))
		if next_age >= dur:
			main._boss_explosion_shrapnel.remove_at(s_idx)
		else:
			shard["age"] = next_age
			var vel: Vector2 = shard.get("vel", Vector2.ZERO)
			vel.y += 280.0 * delta
			shard["vel"] = vel
			shard["pos"] = (shard.get("pos", Vector2.ZERO) as Vector2) + vel * delta
			shard["rot"] = float(shard.get("rot", 0.0)) + float(shard.get("rot_speed", 0.0)) * delta
			main._boss_explosion_shrapnel[s_idx] = shard
		s_idx -= 1

	if main._story_boss_canvas != null and is_instance_valid(main._story_boss_canvas):
		main._story_boss_canvas.queue_redraw()


# =====================================================
# LEVEL 4: PHANTOM MAESTRO LOGIC
# =====================================================

func story_l4_opposite(dir: String) -> String:
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
	var alive: Array[String] = get_alive_boss_parts()
	main._story_l4_sequence.clear()
	main._story_l4_seq_index = 0
	if alive.is_empty():
		return
	var length: int = 2 if alive.size() >= 3 else 3
	var last_note: String = alive.pick_random()
	var pool: Array[String] = []
	for d: String in ["up", "down", "left", "right"]:
		if d != last_note:
			pool.append(d)
	pool.shuffle()
	for i in range(length - 1):
		main._story_l4_sequence.append(pool[i])
	main._story_l4_sequence.append(last_note)

	if main._story_l4_mirror_pending:
		main._story_l4_mirror_pending = false
		main._story_l4_mirror_swipes = length
		main._show_remap_banner("🪞 MIRROR CURSE: SWIPES REVERSED! 🪞")
		main.sfx.play_pitched("combo", 0.72)
		main._haptic_danger()


func _start_story_level4_turn() -> void:
	main.story_bomb_dirs.clear()
	main.story_bomb_dir = ""
	var all_dirs: Array[String] = ["up", "down", "left", "right"]

	if are_all_boss_parts_destroyed():
		main.story_boss_enraged = true
		set_boss_music_enraged(true)
		if main._story_l4_mirror_swipes <= 0:
			main._story_l4_turns_until_mirror -= 1
			if main._story_l4_turns_until_mirror <= 0:
				main._story_l4_mirror_swipes = 3
				main._story_l4_turns_until_mirror = randi_range(4, 6)
				main._show_remap_banner("🪞 MIRROR CURSE: SWIPES REVERSED! 🪞")
				main.sfx.play_pitched("combo", 0.72)
				main._haptic_danger()
		var prev_true: String = main._story_l4_true_dir
		var cands: Array[String] = []
		for d: String in all_dirs:
			if d != prev_true:
				cands.append(d)
		main._story_l4_true_dir = cands.pick_random()
		var hp_ratio: float = clampf(float(main.story_boss_hp) / float(maxi(1, main.story_boss_max_hp)), 0.0, 1.0)
		main._story_l4_reveal_left = lerpf(0.42, 0.65, hp_ratio)
		main.current_time_limit += main._story_l4_reveal_left + 0.12
	else:
		main._story_l4_true_dir = ""
		main._story_l4_reveal_left = 0.0
		if main._story_l4_sequence.is_empty():
			_build_story_l4_sequence()
		main.current_time_limit += 0.10

	if main._story_l4_mirror_swipes > 0:
		main.current_time_limit += 0.18
	main.time_left_in_turn = main.current_time_limit

	main._boss_throw_anim = 1.0
	update_story_boss_labels()
	main._apply_board_colors()
	main._pulse_center()


func _on_story_level4_swipe(raw_dir: String) -> void:
	var direction: String = raw_dir
	if main._story_l4_mirror_swipes > 0:
		direction = story_l4_opposite(raw_dir)
		main._story_l4_mirror_swipes -= 1

	if are_all_boss_parts_destroyed():
		if main._story_l4_true_dir != "" and direction == main._story_l4_true_dir:
			main._story_l4_true_dir = ""
			main._story_l4_reveal_left = 0.0
			on_story_boss_hit(direction)
		else:
			_on_story_level4_mistake(direction, true)
		return

	if main._story_l4_sequence.is_empty():
		_build_story_l4_sequence()
	if main._story_l4_sequence.is_empty():
		return
	var expected: String = main._story_l4_sequence[main._story_l4_seq_index]
	if direction != expected:
		_on_story_level4_mistake(direction, false)
		return

	main._story_l4_seq_index += 1
	var dmg: int = 1
	if main._story_l4_seq_index >= main._story_l4_sequence.size():
		dmg = 2
		main._story_l4_sequence.clear()
		main._story_l4_seq_index = 0
		var cur_hp: int = int(main.story_part_hp.get(direction, 0))
		var broken_after: int = 4 - get_alive_boss_parts().size() + (1 if (cur_hp > 0 and cur_hp <= dmg) else 0)
		if broken_after >= 1 and broken_after < 4 and main._story_l4_mirror_swipes <= 0:
			main._story_l4_turns_until_mirror -= 1
			if main._story_l4_turns_until_mirror <= 0 or randf() < 0.35:
				main._story_l4_mirror_pending = true
				main._story_l4_turns_until_mirror = 3
	on_story_boss_hit(direction, dmg)


func _on_story_level4_mistake(direction: String, is_decoy: bool) -> void:
	var pos: Vector2 = main._get_board_center(direction)
	var true_dir_was: String = main._story_l4_true_dir
	main._story_l4_sequence.clear()
	main._story_l4_seq_index = 0
	main._story_l4_mirror_swipes = 0
	main._story_l4_mirror_pending = false
	main._story_l4_true_dir = ""
	main._story_l4_reveal_left = 0.0
	main._story_last_swiped_dir = direction
	main._boss_taunt_anim = 1.0

	main._flash_square(direction, Color(1.7, 0.25, 0.35, 0.98))
	if is_decoy and true_dir_was != "" and true_dir_was != direction:
		main._flash_square(true_dir_was, Color(1.6, 1.25, 0.35, 0.9))
	main._burst_particles(pos, Color(1.5, 0.3, 0.35), 22)
	main._burst_particles(pos, Color(1.0, 0.85, 0.4), 12)
	main._burst_at(pos, Color(1.4, 0.25, 0.3))

	main.lives -= 1
	main._lost_heart_this_game = true
	main.streak = 0
	main.perfect_streak = 0
	main._audio_pulse = 0.9

	main.sfx.play("wrong")
	main._haptic_danger()
	main._shake_screen(14.0)
	main._flash_center_red()
	if is_decoy:
		main._show_persistent_label("🎭 DECOY MASK! -1 HP", pos, Color(1.0, 0.42, 0.50), true)
	else:
		main._show_persistent_label("🎻 OFF-KEY! -1 HP (MELODY RESET)", pos, Color(1.0, 0.55, 0.45), true)
	main._update_lives_display()
	update_story_boss_labels()
	main._apply_board_colors()

	if main.lives <= 0:
		main._game_over()
	else:
		main.start_new_turn()


func apply_story_level4_square_style(style: StyleBoxFlat, dir: String) -> void:
	var col: Color = main.direction_colors.get(dir, Color.WHITE)
	var gold_highlight: bool = false
	if are_all_boss_parts_destroyed():
		if main._story_l4_reveal_left > 0.0 and dir == main._story_l4_true_dir:
			main._apply_skin_to_square_style(style, col, false)
			style.set_border_width_all(4)
			style.set_border_color(Color(1.6, 1.25, 0.35, 0.98))
			style.set_shadow_color(Color(1.3, 0.9, 0.2, 0.80))
			style.set_shadow_size(20)
			gold_highlight = true
		else:
			style.bg_color = Color(0.13, 0.07, 0.17, 0.96)
			style.set_border_width_all(3)
			style.set_border_color(Color(0.75, 0.62, 0.95, 0.85))
			style.set_shadow_color(Color(0.55, 0.30, 0.85, 0.45))
			style.set_shadow_size(10)
	else:
		main._apply_skin_to_square_style(style, col, false)
		if int(main.story_part_hp.get(dir, 0)) <= 0:
			style.bg_color = col.darkened(0.55)
		var note_idx: int = main._story_l4_sequence.find(dir)
		if note_idx >= 0 and note_idx == main._story_l4_seq_index:
			style.set_border_width_all(4)
			style.set_border_color(Color(1.6, 1.25, 0.35, 0.98))
			style.set_shadow_color(Color(1.3, 0.9, 0.2, 0.78))
			style.set_shadow_size(18)
			gold_highlight = true
		elif note_idx > main._story_l4_seq_index:
			style.set_border_width_all(3)
			style.set_border_color(Color(1.0, 0.55, 0.75, 0.88))
			style.set_shadow_color(Color(0.9, 0.3, 0.55, 0.45))
			style.set_shadow_size(10)
	if main._story_l4_mirror_swipes > 0 and not gold_highlight:
		style.set_border_width_all(3)
		style.set_border_color(Color(0.85, 0.95, 1.25, 0.95))
		style.set_shadow_color(Color(0.65, 0.85, 1.1, 0.55))
		style.set_shadow_size(12)
