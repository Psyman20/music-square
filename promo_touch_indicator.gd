extends Control
class_name PromoTouchIndicator

var current_pos: Vector2 = Vector2.ZERO
var touch_alpha: float = 0.0
var touch_radius: float = 24.0
var is_active: bool = false
var is_holding: bool = false
var hold_energy: float = 0.0
var trail_points: Array[Vector2] = []
var ripple_radius: float = 0.0
var ripple_alpha: float = 0.0

var _tween: Tween = null
var _ripple_tween: Tween = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	if is_holding:
		hold_energy += delta * 2.0
		queue_redraw()
	elif is_active or ripple_alpha > 0.01:
		queue_redraw()

func play_swipe(from_pos: Vector2, to_pos: Vector2, duration: float = 0.16) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	is_holding = false
	is_active = true
	touch_alpha = 0.9
	current_pos = from_pos
	trail_points.clear()
	trail_points.append(from_pos)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "current_pos", to_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(p: Vector2):
		trail_points.append(p)
		if trail_points.size() > 8:
			trail_points.pop_front()
	, from_pos, to_pos, duration)

	_tween.chain().tween_property(self, "touch_alpha", 0.0, 0.12)
	_tween.tween_callback(func():
		is_active = false
		trail_points.clear()
		_spawn_ripple(to_pos, 42.0)
	)

func start_hold(pos: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	current_pos = pos
	is_active = true
	is_holding = true
	touch_alpha = 0.95
	hold_energy = 0.0
	trail_points.clear()

func end_hold() -> void:
	is_holding = false
	_spawn_ripple(current_pos, 65.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "touch_alpha", 0.0, 0.15)
	_tween.tween_callback(func(): is_active = false)

func _spawn_ripple(pos: Vector2, max_rad: float) -> void:
	if _ripple_tween != null and _ripple_tween.is_valid():
		_ripple_tween.kill()
	ripple_radius = 18.0
	ripple_alpha = 0.85
	_ripple_tween = create_tween()
	_ripple_tween.set_parallel(true)
	_ripple_tween.tween_property(self, "ripple_radius", max_rad, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ripple_tween.tween_property(self, "ripple_alpha", 0.0, 0.25)

func _draw() -> void:
	# Draw swipe motion trail
	if trail_points.size() >= 2:
		for i in range(trail_points.size() - 1):
			var frac := float(i) / float(trail_points.size())
			var col := Color(0.2, 0.95, 1.0, frac * touch_alpha * 0.7)
			var width := 8.0 * frac + 2.0
			draw_line(trail_points[i], trail_points[i + 1], col, width)

	# Draw arrival / release ripple
	if ripple_alpha > 0.01:
		draw_arc(current_pos, ripple_radius, 0.0, TAU, 32, Color(1.0, 0.35, 0.75, ripple_alpha), 3.0, true)

	# Draw main finger touch circle
	if is_active and touch_alpha > 0.01:
		var base_color := Color(1.0, 1.0, 1.0, touch_alpha * 0.9)
		var glow_color := Color(0.15, 0.85, 1.0, touch_alpha * 0.5)

		# Outer soft glow
		draw_circle(current_pos, touch_radius + 8.0, glow_color)
		# Inner ring
		draw_arc(current_pos, touch_radius, 0.0, TAU, 32, base_color, 3.5, true)
		# Center bright dot
		draw_circle(current_pos, touch_radius * 0.45, base_color)

		# Holding charging sparks / arcs
		if is_holding:
			var pulse := 1.0 + sin(hold_energy * 10.0) * 0.15
			var charge_col := Color(1.0, 0.85, 0.2, touch_alpha * 0.8)
			draw_arc(current_pos, (touch_radius + 14.0) * pulse, 0.0, TAU, 36, charge_col, 2.5, true)
			# Small electric burst lines
			for a in range(4):
				var angle := a * (PI / 2.0) + hold_energy * 5.0
				var p1 := current_pos + Vector2(cos(angle), sin(angle)) * (touch_radius + 16.0)
				var p2 := current_pos + Vector2(cos(angle), sin(angle)) * (touch_radius + 24.0)
				draw_line(p1, p2, Color(1.0, 0.9, 0.3, touch_alpha * 0.9), 2.0)
