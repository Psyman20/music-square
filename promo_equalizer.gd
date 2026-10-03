extends Control
class_name PromoEqualizer

@export var bar_count: int = 16
@export var bar_width: float = 8.0
@export var bar_gap: float = 6.0
@export var max_height: float = 70.0
@export var is_vertical_layout: bool = false

var bar_heights: Array[float] = []
var bar_targets: Array[float] = []
var pulse_energy: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	bar_heights.resize(bar_count)
	bar_targets.resize(bar_count)
	for i in range(bar_count):
		bar_heights[i] = 10.0
		bar_targets[i] = 10.0

func _process(delta: float) -> void:
	_time += delta * 7.0
	pulse_energy = maxf(0.0, pulse_energy - delta * 2.5)

	# Generate lively rhythm wave values
	for i in range(bar_count):
		var freq := 0.8 + float(i) * 0.4
		var wave1 := sin(_time * freq + float(i) * 0.7) * 0.5 + 0.5
		var wave2 := cos(_time * 1.7 - float(i) * 0.3) * 0.5 + 0.5
		var center_weight := 1.0 - absf(float(i) - float(bar_count) / 2.0) / (float(bar_count) / 2.0) * 0.35
		var target := (wave1 * 0.6 + wave2 * 0.4 + pulse_energy * 0.9) * max_height * center_weight
		bar_targets[i] = clampf(target, 6.0, max_height)
		# Smooth interpolation
		bar_heights[i] = lerpf(bar_heights[i], bar_targets[i], delta * 18.0)

	queue_redraw()

func bump(amount: float = 1.0) -> void:
	pulse_energy = clampf(pulse_energy + amount, 0.0, 1.5)

func _draw() -> void:
	var total_w := float(bar_count) * bar_width + float(bar_count - 1) * bar_gap
	var start_x := (size.x - total_w) / 2.0 if size.x > total_w else 0.0
	var base_y := size.y

	for i in range(bar_count):
		var x := start_x + float(i) * (bar_width + bar_gap)
		var h := bar_heights[i]
		var y := base_y - h

		var frac := float(i) / float(bar_count)
		var col := Color(0.1, 0.85, 1.0).lerp(Color(1.0, 0.2, 0.65), frac)
		# Top highlight dot
		var col_top := Color(1.0, 1.0, 1.0, 0.9)

		# Draw bar
		draw_rect(Rect2(x, y, bar_width, h), col)
		# Glowing cap
		draw_rect(Rect2(x, y - 3.0, bar_width, 2.0), col_top)
