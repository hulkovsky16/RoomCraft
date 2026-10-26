extends Node3D
class_name FurnitureSystem

signal selection_changed(item: FurnitureItem)
signal furniture_changed
signal status_changed(message: String)

const CATALOG := {"table": {"name": "Stół", "size": Vector3(1.4, 0.75, 0.8)}}
const WALL_INSET := 0.05

var selected: FurnitureItem
var preview: FurnitureItem
var moving: FurnitureItem
var candidate_valid := false
var room: Node
var camera: Camera3D


func _ready() -> void:
	room = get_parent()
	camera = get_viewport().get_camera_3d()
	room.add_room_size_validator(can_resize_room)


func get_catalog() -> Dictionary:
	return CATALOG.duplicate(true)


func _make_item(type_id: String) -> FurnitureItem:
	var item := FurnitureItem.new()
	item.type_id = type_id
	item.size = CATALOG[type_id]["size"]
	item.furniture_id = Crypto.new().generate_random_bytes(16).hex_encode()
	add_child(item)
	return item


func spawn_furniture(type_id: String, at: Vector3) -> FurnitureItem:
	if not CATALOG.has(type_id):
		status_changed.emit("Nieznany typ mebla")
		return null
	var item := _make_item(type_id)
	if not is_placement_valid(item, at, 0.0):
		remove_child(item)
		item.queue_free()
		status_changed.emit("Brak miejsca: ściana lub inny mebel")
		return null
	item.position = Vector3(at.x, 0, at.z)
	_select(item)
	furniture_changed.emit()
	return item


func begin_placement(type_id: String) -> void:
	cancel_placement()
	if not CATALOG.has(type_id):
		status_changed.emit("Nieznany typ mebla")
		return
	preview = _make_item(type_id)
	preview.collision_layer = 0
	preview.visible = false
	status_changed.emit("Wskaż miejsce. Kliknij, aby ustawić; Esc — anuluj")


func begin_move_selected() -> void:
	if selected == null:
		status_changed.emit("Najpierw wybierz mebel")
		return
	cancel_placement()
	moving = selected
	preview = _make_item(moving.type_id)
	preview.rotation.y = moving.rotation.y
	preview.collision_layer = 0
	preview.visible = false
	status_changed.emit("Wskaż nowe miejsce; Esc — anuluj")


func cancel_placement() -> void:
	var was_active := preview != null
	if is_instance_valid(preview):
		remove_child(preview)
		preview.queue_free()
	preview = null
	moving = null
	candidate_valid = false
	if was_active:
		status_changed.emit("Anulowano")


func rotate_active(angle: float) -> void:
	if not is_finite(angle):
		return
	if preview != null:
		preview.rotation.y = wrapf(preview.rotation.y + angle, -PI, PI)
	else:
		rotate_selected(angle)


func _select(item: FurnitureItem) -> void:
	if is_instance_valid(selected):
		selected.set_highlight("")
	selected = item
	if selected != null:
		selected.set_highlight("selected")
	selection_changed.emit(selected)


func move_selected(at: Vector3) -> bool:
	if selected == null or not is_placement_valid(selected, at, selected.rotation.y, selected):
		status_changed.emit("Nie można przenieść mebla w to miejsce")
		return false
	selected.position = Vector3(at.x, 0, at.z)
	furniture_changed.emit()
	return true


func rotate_selected(angle: float) -> bool:
	if selected == null or not is_finite(angle):
		return false
	var yaw := wrapf(selected.rotation.y + angle, -PI, PI)
	if not is_placement_valid(selected, selected.position, yaw, selected):
		status_changed.emit("Obrót zablokowany: ściana lub inny mebel")
		return false
	selected.rotation.y = yaw
	furniture_changed.emit()
	return true


func delete_selected() -> void:
	cancel_placement()
	if selected == null:
		return
	var item := selected
	_select(null)
	remove_child(item)
	item.queue_free()
	furniture_changed.emit()
	status_changed.emit("Usunięto mebel")


func get_all_furniture() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item in get_children():
		if item is FurnitureItem and item != preview:
			records.append(item.to_record())
	return records


func _corners(item: FurnitureItem, at: Vector3, yaw: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for offset in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		var point: Vector3 = at + (offset * item.size / 2).rotated(Vector3.UP, yaw)
		result.append(Vector2(point.x, point.z))
	return result


func _inside(points: Array[Vector2], bounds: Dictionary) -> bool:
	var low: Vector2 = bounds["min"] + Vector2.ONE * WALL_INSET
	var high: Vector2 = bounds["max"] - Vector2.ONE * WALL_INSET
	for point in points:
		if point.x < low.x or point.y < low.y or point.x > high.x or point.y > high.y:
			return false
	return true


# Separating axis theorem: oriented footprints, including rotated furniture.
func _overlaps(a: Array[Vector2], b: Array[Vector2]) -> bool:
	for polygon in [a, b]:
		for i in range(2):
			var edge: Vector2 = polygon[i + 1] - polygon[i]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var a_min := INF
			var a_max := -INF
			var b_min := INF
			var b_max := -INF
			for point in a:
				a_min = minf(a_min, point.dot(axis))
				a_max = maxf(a_max, point.dot(axis))
			for point in b:
				b_min = minf(b_min, point.dot(axis))
				b_max = maxf(b_max, point.dot(axis))
			if a_max <= b_min + 0.00001 or b_max <= a_min + 0.00001:
				return false
	return true


func is_placement_valid(item: FurnitureItem, at: Vector3, yaw: float, ignore: FurnitureItem = null) -> bool:
	if not at.is_finite() or not is_finite(yaw):
		return false
	var points := _corners(item, at, yaw)
	if not _inside(points, room.get_floor_bounds()):
		return false
	for other in get_children():
		if other is FurnitureItem and other != item and other != preview and other != ignore:
			if _overlaps(points, _corners(other, other.position, other.rotation.y)):
				return false
	return true


func can_resize_room(width: float, length: float) -> bool:
	var bounds := {"min": Vector2(-width, -length) / 2, "max": Vector2(width, length) / 2}
	for item in get_children():
		if item is FurnitureItem and item != preview and not _inside(_corners(item, item.position, item.rotation.y), bounds):
			status_changed.emit("Najpierw przesuń meble — pokój jest za mały")
			return false
	return true


func _floor_point():
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	# Intersect the floor plane so walls never steal the placement ray.
	return Plane(Vector3.UP, 0).intersects_ray(origin, direction)


func _process(_delta: float) -> void:
	if preview == null or camera == null:
		return
	var point = _floor_point()
	candidate_valid = point != null and get_viewport().gui_get_hovered_control() == null
	preview.visible = point != null
	if point != null:
		preview.position = point
		candidate_valid = candidate_valid and is_placement_valid(preview, point, preview.rotation.y, moving)
	preview.set_highlight("valid" if candidate_valid else "invalid")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				cancel_placement()
				status_changed.emit("Anulowano")
			KEY_T: begin_placement("table")
			KEY_G: begin_move_selected()
			KEY_DELETE: delete_selected()
			KEY_Q, KEY_E:
				var angle := deg_to_rad(-15.0 if event.keycode == KEY_Q else 15.0)
				rotate_active(angle)
			_: return
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if preview != null:
			_process(0)
			if not candidate_valid:
				status_changed.emit("Brak miejsca: ściana lub inny mebel")
				return
			var item := moving if moving != null else preview
			item.position = preview.position
			item.rotation.y = preview.rotation.y
			if moving == null:
				preview.collision_layer = 2
				preview = null
			cancel_placement()
			_select(item)
			furniture_changed.emit()
			status_changed.emit("Ustawiono mebel")
		else:
			var mouse := get_viewport().get_mouse_position()
			var origin := camera.project_ray_origin(mouse)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 100, 2)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			_select(hit.get("collider") as FurnitureItem)
		get_viewport().set_input_as_handled()
