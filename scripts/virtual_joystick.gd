extends Control

signal vector_changed(value: Vector2)

@export var radius: float = 145.0
@export var knob_radius: float = 62.0

var value: Vector2 = Vector2.ZERO
var active_touch: int = -1
var mouse_active: bool = false
var knob_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(340.0, 340.0)

	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0

	offset_left = 28.0
	offset_top = -360.0
	offset_right = 368.0
	offset_bottom = -20.0

	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_touch == -1:
				active_touch = event.index
				_update_stick(event.position)
		elif event.index == active_touch:
			active_touch = -1
			_reset_stick()

	elif event is InputEventScreenDrag:
		if event.index == active_touch:
			_update_stick(event.position)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_active = event.pressed

			if mouse_active:
				_update_stick(event.position)
			else:
				_reset_stick()

	elif event is InputEventMouseMotion and mouse_active:
		_update_stick(event.position)


func _update_stick(pointer_position: Vector2) -> void:
	var center := size * 0.5
	var offset := pointer_position - center

	if offset.length() > radius:
		offset = offset.normalized() * radius

	knob_position = offset
	value = (offset / radius).limit_length(1.0)

	vector_changed.emit(value)
	queue_redraw()


func _reset_stick() -> void:
	value = Vector2.ZERO
	knob_position = Vector2.ZERO

	vector_changed.emit(value)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5

	# Основная полупрозрачная площадка.
	draw_circle(
		center,
		radius,
		Color(0.025, 0.04, 0.065, 0.76)
	)

	# Внешняя окантовка.
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		96,
		Color(0.82, 0.90, 1.0, 0.82),
		4.0
	)

	# Внутреннее кольцо.
	draw_arc(
		center,
		radius * 0.62,
		0.0,
		TAU,
		72,
		Color(0.65, 0.78, 0.95, 0.25),
		2.0
	)

	# Центральная отметка.
	draw_circle(
		center,
		5.0,
		Color(0.85, 0.92, 1.0, 0.28)
	)

	# Ручка стика.
	draw_circle(
		center + knob_position,
		knob_radius,
		Color(0.13, 0.43, 0.82, 0.96)
	)

	draw_arc(
		center + knob_position,
		knob_radius,
		0.0,
		TAU,
		64,
		Color(0.94, 0.97, 1.0, 0.98),
		3.5
	)

	# Блик.
	draw_circle(
		center + knob_position + Vector2(-knob_radius * 0.22, -knob_radius * 0.25),
		knob_radius * 0.22,
		Color(0.9, 0.96, 1.0, 0.22)
	)
