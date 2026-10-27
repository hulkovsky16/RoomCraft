extends Node3D
class_name FurnitureSystem

signal selection_changed(item: FurnitureItem)
signal furniture_changed
signal status_changed(message: String)

const CATALOG := {
	"table": {"name": "Stół", "size": Vector3(1.4, 0.75, 0.8)},
	"chair": {"name": "Krzesło", "size": Vector3(0.5, 0.9, 0.55)},
	"sofa": {"name": "Sofa", "size": Vector3(2.0, 0.85, 0.9)},
	"armchair": {"name": "Fotel", "size": Vector3(0.9, 0.85, 0.85)},
	"bed": {"name": "Łóżko", "size": Vector3(1.6, 0.95, 2.1)},
	"wardrobe": {"name": "Szafa", "size": Vector3(1.2, 2.0, 0.6)},
	"bookshelf": {"name": "Regał", "size": Vector3(0.8, 1.8, 0.35)},
	"desk": {"name": "Biurko", "size": Vector3(1.2, 0.75, 0.6)},
	"nightstand": {"name": "Szafka nocna", "size": Vector3(0.45, 0.5, 0.4)},
	"coffee_table": {"name": "Stolik kawowy", "size": Vector3(1.0, 0.4, 0.6)},
	"window": {"name": "Okno", "size": Vector3(1.2, 1.1, 0.16), "category": "Okna", "placement": "wall"},
	"tv_console": {"name": "Telewizor + RTV", "size": Vector3(1.4, 1.25, 0.4), "category": "Dekoracje"},
	"plant": {"name": "Roślina", "size": Vector3(0.65, 1.3, 0.65), "category": "Dekoracje"},
	"flowers": {"name": "Kwiaty", "size": Vector3(0.45, 0.7, 0.45), "category": "Dekoracje"},
	"floor_lamp": {"name": "Lampa", "size": Vector3(0.45, 1.65, 0.45), "category": "Dekoracje"},
	"kitchen_cabinet": {"name": "Szafka", "size": Vector3(0.6, 0.9, 0.6), "category": "Kuchnia"},
	"kitchen_sink": {"name": "Zlew", "size": Vector3(0.8, 1.15, 0.6), "category": "Kuchnia"},
	"cooker": {"name": "Kuchenka", "size": Vector3(0.6, 0.9, 0.6), "category": "Kuchnia"},
	"fridge": {"name": "Lodówka", "size": Vector3(0.7, 1.85, 0.7), "category": "Kuchnia"},
	"dishwasher": {"name": "Zmywarka", "size": Vector3(0.6, 0.85, 0.6), "category": "Kuchnia"},
	"kitchen_island": {"name": "Wyspa", "size": Vector3(1.5, 0.9, 0.8), "category": "Kuchnia"},
	"bathtub": {"name": "Wanna", "size": Vector3(0.8, 0.6, 1.7), "category": "Łazienka"},
	"toilet": {"name": "Toaleta", "size": Vector3(0.42, 0.8, 0.7), "category": "Łazienka"},
	"bathroom_vanity": {"name": "Umywalka", "size": Vector3(0.7, 1.05, 0.5), "category": "Łazienka"},
	"shower": {"name": "Prysznic", "size": Vector3(0.9, 2.1, 0.9), "category": "Łazienka"},
	"washing_machine": {"name": "Pralka", "size": Vector3(0.6, 0.85, 0.6), "category": "Łazienka"},
}
const WALL_INSET := 0.05

var selected: FurnitureItem
var preview: FurnitureItem
var moving: FurnitureItem
var candidate_valid := false
var room: Node
var camera: Camera3D
var rotation_holds: Dictionary = {}
var rotation_hold_time := 0.0
const ROTATION_SPEED := 90.0


func _ready() -> void:
	room = get_parent()
	camera = get_viewport().get_camera_3d()
	room.add_room_size_validator(can_resize_room)
	room.room_size_changed.connect(_on_room_resized)
	furniture_changed.connect(_sync_windows)


func get_catalog() -> Dictionary:
	return CATALOG.duplicate(true)


func _make_item(type_id: String) -> FurnitureItem:
	var item := FurnitureItem.new()
	item.type_id = type_id
	item.size = CATALOG[type_id]["size"]
	item.placement = CATALOG[type_id].get("placement", "floor")
	item.furniture_id = Crypto.new().generate_random_bytes(16).hex_encode()
	add_child(item)
	return item


func spawn_furniture(type_id: String, at: Vector3) -> FurnitureItem:
	if not CATALOG.has(type_id):
		status_changed.emit("Nieznany typ mebla")
		return null
	if CATALOG[type_id].get("placement", "floor") == "wall":
		status_changed.emit("Okno wymaga ściany: użyj katalogu lub spawn_window")
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
	status_changed.emit("Dodano: " + str(CATALOG[item.type_id]["name"]))
	return item


func spawn_window(wall: String, offset: float, bottom: float = 1.0) -> FurnitureItem:
	if not wall in ["FrontWall", "BackWall", "LeftWall", "RightWall"] or not is_finite(offset) or not is_finite(bottom):
		return null
	var item := _make_item("window")
	item.wall_id = wall
	item.rotation.y = _wall_yaw(wall)
	var at := _wall_position(wall, offset, bottom, room.get_floor_bounds())
	if not is_placement_valid(item, at, item.rotation.y):
		remove_child(item)
		item.queue_free()
		return null
	item.position = at
	_select(item)
	furniture_changed.emit()
	status_changed.emit("Dodano: " + str(CATALOG[item.type_id]["name"]))
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
	if preview.placement == "wall":
		status_changed.emit("Wskaż widoczną ścianę. Kliknij, aby wstawić okno; Esc — anuluj")


func begin_move_selected() -> void:
	if selected == null:
		status_changed.emit("Najpierw wybierz mebel")
		return
	cancel_placement()
	moving = selected
	preview = _make_item(moving.type_id)
	preview.rotation.y = moving.rotation.y
	preview.wall_id = moving.wall_id
	preview.collision_layer = 0
	preview.visible = false
	status_changed.emit("Wskaż nowe miejsce; Esc — anuluj")


func cancel_placement() -> void:
	stop_all_rotation()
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
		if preview.placement == "wall":
			status_changed.emit("Okno obraca się automatycznie do ściany")
			return
		preview.rotation.y = wrapf(preview.rotation.y + angle, -PI, PI)
	else:
		rotate_selected(angle)


func _select(item: FurnitureItem) -> void:
	stop_all_rotation()
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
	selected.position = at if selected.placement == "wall" else Vector3(at.x, 0, at.z)
	furniture_changed.emit()
	return true


func rotate_selected(angle: float) -> bool:
	if selected == null or not is_finite(angle):
		return false
	if selected.placement == "wall":
		status_changed.emit("Okno obraca się automatycznie do ściany")
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
	if item.placement == "floor":
		at.y = 0
	var points := _corners(item, at, yaw)
	if not _fits_room(item, at, yaw, room.get_floor_bounds()):
		return false
	for other in get_children():
		if other is FurnitureItem and other != item and other != preview and other != ignore:
			if _vertical_overlap(item, at, other, other.position) and _overlaps(points, _corners(other, other.position, other.rotation.y)):
				return false
	return true


func _vertical_overlap(a: FurnitureItem, at: Vector3, b: FurnitureItem, bt: Vector3) -> bool:
	return at.y < bt.y + b.size.y - 0.00001 and bt.y < at.y + a.size.y - 0.00001


func _fits_room(item: FurnitureItem, at: Vector3, yaw: float, bounds: Dictionary) -> bool:
	if item.placement != "wall":
		return _inside(_corners(item, at, yaw), bounds)
	if not item.wall_id in ["FrontWall", "BackWall", "LeftWall", "RightWall"]:
		return false
	if at.y < 0.15 or at.y + item.size.y > RoomGeometry.WALL_HEIGHT - 0.1:
		return false
	if absf(wrapf(yaw - _wall_yaw(item.wall_id), -PI, PI)) > 0.001:
		return false
	var offset := _wall_offset(item.wall_id, at)
	if at.distance_to(_wall_position(item.wall_id, offset, at.y, bounds)) > 0.001:
		return false
	var maximum: Vector2 = bounds["max"]
	var half_span := maximum.x if item.wall_id in ["FrontWall", "BackWall"] else maximum.y
	return absf(offset) + item.size.x / 2 <= half_span - 0.1


func _wall_yaw(wall: String) -> float:
	return {"FrontWall": 0.0, "BackWall": PI, "LeftWall": PI / 2, "RightWall": -PI / 2}.get(wall, 0.0)


func _wall_offset(wall: String, at: Vector3) -> float:
	return at.x if wall in ["FrontWall", "BackWall"] else at.z


func _wall_position(wall: String, offset: float, bottom: float, bounds: Dictionary) -> Vector3:
	var low: Vector2 = bounds["min"]
	var high: Vector2 = bounds["max"]
	match wall:
		"FrontWall": return Vector3(offset, bottom, low.y)
		"BackWall": return Vector3(offset, bottom, high.y)
		"LeftWall": return Vector3(low.x, bottom, offset)
		_: return Vector3(high.x, bottom, offset)


func can_resize_room(width: float, length: float) -> bool:
	var bounds := {"min": Vector2(-width, -length) / 2, "max": Vector2(width, length) / 2}
	var items: Array[FurnitureItem] = []
	var positions: Array[Vector3] = []
	for item in get_children():
		if not item is FurnitureItem or item == preview:
			continue
		var at: Vector3 = item.position
		if item.placement == "wall":
			at = _wall_position(item.wall_id, _wall_offset(item.wall_id, at), at.y, bounds)
		if not _fits_room(item, at, item.rotation.y, bounds):
			status_changed.emit("Najpierw przesuń meble — pokój jest za mały")
			return false
		for i in range(items.size()):
			if _vertical_overlap(item, at, items[i], positions[i]) and _overlaps(_corners(item, at, item.rotation.y), _corners(items[i], positions[i], items[i].rotation.y)):
				status_changed.emit("Zmiana rozmiaru powoduje kolizję z oknem")
				return false
		items.append(item)
		positions.append(at)
	return true


func _on_room_resized(_width: float, _length: float) -> void:
	for item in get_children():
		if item is FurnitureItem and item != preview and item.placement == "wall":
			item.position = _wall_position(item.wall_id, _wall_offset(item.wall_id, item.position), item.position.y, room.get_floor_bounds())
	_sync_windows()


func _sync_windows() -> void:
	var openings: Array[Dictionary] = []
	for item in get_children():
		if item is FurnitureItem and item != preview and item.type_id == "window":
			var local_center: Vector3 = item.position.rotated(Vector3.UP, -item.rotation.y)
			openings.append({"wall": item.wall_id, "center": local_center.x, "bottom": item.position.y, "width": item.size.x, "height": item.size.y})
	room.set_window_openings(openings)


func _wall_point() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var bounds: Dictionary = room.get_floor_bounds()
	var best: Dictionary = {}
	var nearest := INF
	for wall in ["FrontWall", "BackWall", "LeftWall", "RightWall"]:
		var center := _wall_position(wall, 0, 0, bounds)
		var normal := Vector3.FORWARD.rotated(Vector3.UP, _wall_yaw(wall))
		# Ignore cutaway walls on the camera side, matching the room view.
		if (origin - center).dot(normal) > 0:
			continue
		var hit = Plane(normal, normal.dot(center)).intersects_ray(origin, direction)
		if hit == null or hit.y < 0 or hit.y > RoomGeometry.WALL_HEIGHT:
			continue
		var offset := _wall_offset(wall, hit)
		var high: Vector2 = bounds["max"]
		var half_span := high.x if wall in ["FrontWall", "BackWall"] else high.y
		if absf(offset) > half_span:
			continue
		var distance: float = origin.distance_to(hit)
		if distance < nearest:
			nearest = distance
			best = {"wall": wall, "position": _wall_position(wall, snappedf(offset, 0.05), snappedf(hit.y - preview.size.y / 2, 0.05), bounds)}
	return best


func _floor_point():
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	# Intersect the floor plane so walls never steal the placement ray.
	return Plane(Vector3.UP, 0).intersects_ray(origin, direction)


func _process(_delta: float) -> void:
	_process_rotation(_delta)
	if camera != null:
		for item in get_children():
			if item is FurnitureItem and item != preview and item.placement == "wall":
				var normal := Vector3.FORWARD.rotated(Vector3.UP, item.rotation.y)
				item.visible = (camera.position - item.position).dot(normal) <= 0
				item.collision_layer = 2 if item.visible else 0
	if preview == null or camera == null:
		return
	var point = _floor_point()
	if preview.placement == "wall":
		var wall_hit := _wall_point()
		point = wall_hit.get("position")
		if not wall_hit.is_empty():
			preview.wall_id = wall_hit["wall"]
			preview.rotation.y = _wall_yaw(preview.wall_id)
	candidate_valid = point != null and get_viewport().gui_get_hovered_control() == null
	preview.visible = point != null
	if point != null:
		preview.position = point
		candidate_valid = candidate_valid and is_placement_valid(preview, point, preview.rotation.y, moving)
	preview.set_highlight("valid" if candidate_valid else "invalid")


func start_rotation(source: String, direction: float) -> void:
	var item := preview if preview != null else selected
	if item == null:
		return
	if item.placement == "wall":
		status_changed.emit("Okno obraca się automatycznie do ściany")
		return
	if rotation_holds.has(source):
		return
	rotation_holds[source] = direction
	rotation_hold_time = 0.0
	# A tap goes to an absolute grid angle, repairing offsets left by a hold.
	var step := deg_to_rad(15.0)
	var angle := item.rotation.y
	var snapped := (floorf((angle + 0.00001) / step) + 1) * step if direction > 0 else (ceilf((angle - 0.00001) / step) - 1) * step
	_set_active_angle(snapped)


func _set_active_angle(angle: float) -> bool:
	var item := preview if preview != null else selected
	if item == null or item.placement == "wall":
		return false
	var difference := wrapf(angle - item.rotation.y, -PI, PI)
	if item == preview:
		item.rotation.y = wrapf(angle, -PI, PI)
		return true
	# Check the whole sweep; alignment must not jump across an obstacle.
	var steps := maxi(1, ceili(absf(difference) / deg_to_rad(1)))
	for i in range(1, steps + 1):
		if not is_placement_valid(item, item.position, item.rotation.y + difference * float(i) / steps, item):
			status_changed.emit("Wyrównanie zablokowane: ściana lub inny mebel")
			return false
	item.rotation.y = wrapf(angle, -PI, PI)
	furniture_changed.emit()
	return true


func align_active() -> bool:
	stop_all_rotation()
	var item := preview if preview != null else selected
	if item == null:
		status_changed.emit("Najpierw wybierz mebel")
		return false
	if item.placement == "wall":
		status_changed.emit("Okno jest już wyrównane do ściany")
		return true
	return _set_active_angle(snappedf(item.rotation.y, PI / 2))


func stop_rotation(source: String) -> void:
	rotation_holds.erase(source)


func stop_all_rotation() -> void:
	rotation_holds.clear()
	rotation_hold_time = 0.0


func _process_rotation(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		stop_all_rotation()
		return
	if rotation_holds.is_empty():
		return
	var before := rotation_hold_time
	rotation_hold_time += delta
	var active_delta := maxf(0, rotation_hold_time - 0.25) - maxf(0, before - 0.25)
	var direction := 0.0
	for value in rotation_holds.values():
		direction += value
	var remaining := deg_to_rad(ROTATION_SPEED * minf(active_delta, 0.1) * clampf(direction, -1, 1))
	# Small validated steps prevent a long frame from jumping over a collision.
	while absf(remaining) > 0.00001:
		var step := clampf(remaining, -deg_to_rad(2), deg_to_rad(2))
		rotate_active(step)
		remaining -= step


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		stop_all_rotation()


func _input(event: InputEvent) -> void:
	# Releases must be observed even when UI consumes the event.
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_Q:
			stop_rotation("key_q")
		if event.keycode == KEY_E:
			stop_rotation("key_e")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				cancel_placement()
				status_changed.emit("Anulowano")
			KEY_T: begin_placement("table")
			KEY_G: begin_move_selected()
			KEY_DELETE: delete_selected()
			KEY_F: align_active()
			KEY_Q, KEY_E:
				start_rotation("key_q" if event.keycode == KEY_Q else "key_e", -1.0 if event.keycode == KEY_Q else 1.0)
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
			item.wall_id = preview.wall_id
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
