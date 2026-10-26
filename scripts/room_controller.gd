
extends Node3D

signal room_size_changed(width: float, length: float)

@export_range(3.0, 10.0, 0.5) var initial_width: float = 5.0
@export_range(3.0, 10.0, 0.5) var initial_length: float = 4.0

@onready var room_geometry: RoomGeometry = $RoomGeometry

var room_size_validators: Array[Callable] = []


func add_room_size_validator(validator: Callable) -> void:
	if not room_size_validators.has(validator):
		room_size_validators.append(validator)


func _ready() -> void:
	set_room_size(initial_width, initial_length)


func set_room_size(width: float, length: float) -> bool:
	if not is_finite(width) or not is_finite(length):
		push_warning("Введено некоректні розміри.")
		return false

	if width < 3.0 or width > 10.0:
		push_warning("Ширина повинна бути від 3 до 10 метрів.")
		return false

	if length < 3.0 or length > 10.0:
		push_warning("Довжина повинна бути від 3 до 10 метрів.")
		return false

	for validator in room_size_validators:
		if validator.is_valid() and not validator.call(width, length):
			return false
	room_geometry.rebuild(width, length)
	room_size_changed.emit(width, length)
	return true


func get_room_size() -> Vector2:
	return room_geometry.get_room_size()


func get_floor_bounds() -> Dictionary:
	return room_geometry.get_floor_bounds()
