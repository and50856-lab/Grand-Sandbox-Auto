extends Control

signal vector_changed(value: Vector2)

@export var radius: float = 145.0
@export var knob_radius: float = 58.0

var value: Vector2 = Vector2.ZERO
var active_touch: int = -1
var mouse_active: bool = false
var knob_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 320.0)
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

	# Внешняя площадка.
	draw_circle(
		center,
		radius,
		Color(0.035, 0.045, 0.065, 0.68)
	)

	# Внешняя окантовка.
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		80,
		Color(0.82, 0.88, 0.98, 0.75),
		4.0
	)

	# Внутреннее кольцо.
	draw_arc(
		center,
		radius * 0.62,
		0.0,
		TAU,
		64,
		Color(0.65, 0.76, 0.92, 0.18),
		2.0
	)

	# Ручка.
	draw_circle(
		center + knob_position,
		knob_radius,
		Color(0.18, 0.52, 0.92, 0.95)
	)

	draw_arc(
		center + knob_position,
		knob_radius,
		0.0,
		TAU,
		56,
		Color(0.94, 0.97, 1.0, 0.95),
		3.0
	)

	# Небольшой блик в центре.
	draw_circle(
		center + knob_position,
		knob_radius * 0.18,
		Color(0.8, 0.91, 1.0, 0.22)
	)
