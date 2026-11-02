
extends Node3D

signal room_size_changed(width: float, length: float)

@export_range(2.0, 30.0, 0.5) var initial_width: float = 5.0
@export_range(2.0, 30.0, 0.5) var initial_length: float = 4.0

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

	if width < RoomGeometry.MIN_ROOM_SIZE or width > RoomGeometry.MAX_ROOM_SIZE:
		push_warning("Ширина повинна бути від 2 до 30 метрів.")
		return false

	if length < RoomGeometry.MIN_ROOM_SIZE or length > RoomGeometry.MAX_ROOM_SIZE:
		push_warning("Довжина повинна бути від 2 до 30 метрів.")
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


func set_window_openings(openings: Array[Dictionary]) -> void:
	room_geometry.set_window_openings(openings)

func restore_project_room(size: Vector2, wall: Color, floor_color: Color, records: Array) -> Dictionary:
	var furniture := $FurnitureRoot
	# Existing furniture is being replaced. Other registered validators still apply.
	for validator in room_size_validators:
		if validator != Callable(furniture, "can_resize_room") and validator.is_valid():
			if not validator.call(size.x, size.y):
				return {"ok": false, "error": "Nie można zmienić wymiarów pokoju"}
	var bounds := {"min": -size / 2, "max": size / 2}
	var commit_room := func():
		room_geometry.wall_material.albedo_color = wall
		room_geometry.floor_material.albedo_color = floor_color
		room_geometry.rebuild(size.x, size.y)
		room_size_changed.emit(size.x, size.y)
	return furniture.restore_furniture(records, bounds, commit_room)


func get_project_state() -> Dictionary:
	var size := get_room_size()
	return {
		"version": 1,
		"room": {"width": size.x, "length": size.y,
			"wall_color": _color_channels(room_geometry.wall_material.albedo_color),
			"floor_color": _color_channels(room_geometry.floor_material.albedo_color)},
		"furniture": $FurnitureRoot.get_all_furniture()
	}


func _color_channels(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]
