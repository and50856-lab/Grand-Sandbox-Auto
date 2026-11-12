extends Control

signal value_changed(value: Vector2)

@export var radius := 82.0
@export var knob_radius := 34.0

var value := Vector2.ZERO
var active_touch := -1
var mouse_active := false
var knob_position := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(190, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_update_stick(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			_reset_stick()

	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_stick(event.position)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
	value = offset / radius
	value_changed.emit(value)
	queue_redraw()

func _reset_stick() -> void:
	value = Vector2.ZERO
	knob_position = Vector2.ZERO
	value_changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5

	draw_circle(center, radius, Color(0.04, 0.05, 0.07, 0.48))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.8, 0.85, 0.95, 0.65), 3.0)
	draw_circle(center + knob_position, knob_radius, Color(0.25, 0.65, 1.0, 0.85))
	draw_arc(center + knob_position, knob_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 2.0)
