extends Node3D
class_name FurnitureSystem

signal selection_changed(item: FurnitureItem)
signal furniture_changed
signal status_changed(message: String)

const CATALOG := {
	"table": {"name": "Stół", "size": Vector3(1.4, 0.75, 0.8), "surface": true},
	"chair": {"name": "Krzesło", "size": Vector3(0.5, 0.9, 0.55)},
	"sofa": {"name": "Sofa", "size": Vector3(2.0, 0.85, 0.9)},
	"armchair": {"name": "Fotel", "size": Vector3(0.9, 0.85, 0.85)},
	"bed": {"name": "Łóżko", "size": Vector3(1.6, 0.95, 2.1)},
	"wardrobe": {"name": "Szafa", "size": Vector3(1.2, 2.0, 0.6)},
	"bookshelf": {"name": "Regał", "size": Vector3(0.8, 1.8, 0.35)},
	"desk": {"name": "Biurko", "size": Vector3(1.2, 0.75, 0.6), "surface": true},
	"nightstand": {"name": "Szafka nocna", "size": Vector3(0.45, 0.5, 0.4), "surface": true},
	"coffee_table": {"name": "Stolik kawowy", "size": Vector3(1.0, 0.4, 0.6), "surface": true},
	"window": {"name": "Okno", "size": Vector3(1.2, 1.1, 0.16), "category": "Okna", "placement": "wall"},
	"tv_console": {"name": "Telewizor + RTV", "size": Vector3(1.4, 1.25, 0.4), "category": "Dekoracje"},
	"plant": {"name": "Roślina", "size": Vector3(0.65, 1.3, 0.65), "category": "Dekoracje"},
	"flowers": {"name": "Kwiaty", "size": Vector3(0.45, 0.7, 0.45), "category": "Dekoracje", "stackable": true, "round_base": true, "footprint": Vector2(0.32, 0.32)},
	"floor_lamp": {"name": "Lampa", "size": Vector3(0.45, 1.65, 0.45), "category": "Dekoracje"},
	"kitchen_cabinet": {"name": "Szafka", "size": Vector3(0.6, 0.9, 0.6), "category": "Kuchnia", "surface": true},
	"kitchen_sink": {"name": "Zlew", "size": Vector3(0.8, 1.15, 0.6), "category": "Kuchnia"},
	"cooker": {"name": "Kuchenka", "size": Vector3(0.6, 0.9, 0.6), "category": "Kuchnia"},
	"fridge": {"name": "Lodówka", "size": Vector3(0.7, 1.85, 0.7), "category": "Kuchnia", "surface": true},
	"dishwasher": {"name": "Zmywarka", "size": Vector3(0.6, 0.85, 0.6), "category": "Kuchnia", "surface": true},
	"kitchen_island": {"name": "Wyspa", "size": Vector3(1.5, 0.9, 0.8), "category": "Kuchnia", "surface": true},
	"bathtub": {"name": "Wanna", "size": Vector3(0.8, 0.6, 1.7), "category": "Łazienka"},
	"toilet": {"name": "Toaleta", "size": Vector3(0.42, 0.8, 0.7), "category": "Łazienka"},
	"bathroom_vanity": {"name": "Umywalka", "size": Vector3(0.7, 1.05, 0.5), "category": "Łazienka"},
	"shower": {"name": "Prysznic", "size": Vector3(0.9, 2.1, 0.9), "category": "Łazienka"},
	"washing_machine": {"name": "Pralka", "size": Vector3(0.6, 0.85, 0.6), "category": "Łazienka", "surface": true},
	"table_lamp": {"name": "Lampka stołowa", "size": Vector3(0.28, 0.45, 0.28), "category": "Dekoracje", "stackable": true, "round_base": true, "footprint": Vector2(0.25, 0.25)},
	"potted_plant": {"name": "Mała roślina", "size": Vector3(0.3, 0.55, 0.3), "category": "Dekoracje", "stackable": true, "round_base": true, "footprint": Vector2(0.25, 0.25)},
}
const WALL_INSET := 0.05

var selected: FurnitureItem
var preview: FurnitureItem
var moving: FurnitureItem
var preview_attached: Array[FurnitureItem] = []
var candidate_valid := false
var placement_error := ""
var last_preview_message := ""
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


func _find_item(id: String) -> FurnitureItem:
	if id.is_empty():
		return null
	for child in get_children():
		if child is FurnitureItem and child != preview and child.furniture_id == id:
			return child
	return null


func _supported_by(support: FurnitureItem) -> Array[FurnitureItem]:
	var items: Array[FurnitureItem] = []
	for child in get_children():
		if child is FurnitureItem and child != preview and child.support_id == support.furniture_id:
			items.append(child)
	return items


func _surface_size(support: FurnitureItem) -> Vector2:
	# Inset from edges and handles; all allowed providers have a solid top here.
	return Vector2(support.size.x - 0.04, support.size.z - 0.06)


func _footprint(item: FurnitureItem) -> Vector2:
	return CATALOG[item.type_id].get("footprint", Vector2(item.size.x, item.size.z))


func _supported_pose(item: FurnitureItem, pose: Dictionary, poses: Dictionary, imported: Dictionary = {}) -> bool:
	var at: Vector3 = pose["position"]
	var support_id: String = pose["support_id"]
	if item.placement == "wall":
		return support_id.is_empty()
	if support_id.is_empty():
		return absf(at.y) < 0.0001
	if not CATALOG[item.type_id].get("stackable", false):
		return false
	var support: FurnitureItem = imported.get(support_id) if not imported.is_empty() else _find_item(support_id)
	if support == null or support == item or not CATALOG[support.type_id].get("surface", false):
		return false
	if not support.support_id.is_empty():
		return false
	var support_at: Vector3 = support.position
	var support_yaw: float = support.rotation.y
	if poses.has(support):
		support_at = poses[support]["position"]
		support_yaw = poses[support]["yaw"]
	if absf(at.y - support_at.y - support.size.y) > 0.0001:
		return false
	var half := _surface_size(support) / 2
	var footprint := _footprint(item)
	if CATALOG[item.type_id].get("round_base", false):
		var center := (at - support_at).rotated(Vector3.UP, -support_yaw)
		var radius := footprint.x / 2
		return absf(center.x) + radius <= half.x + 0.0001 and absf(center.z + 0.015) + radius <= half.y + 0.0001
	for x in [-1, 1]:
		for z in [-1, 1]:
			var corner := at + Vector3(x * footprint.x / 2, 0, z * footprint.y / 2).rotated(Vector3.UP, pose["yaw"])
			var local := (corner - support_at).rotated(Vector3.UP, -support_yaw)
			if absf(local.x) > half.x + 0.0001 or absf(local.z + 0.015) > half.y + 0.0001:
				return false
	return true


func _proposed_poses(item: FurnitureItem, at: Vector3, yaw: float, support_id: String) -> Dictionary:
	var poses := {item: {"position": at, "yaw": yaw, "support_id": support_id}}
	var change := yaw - item.rotation.y
	for attached in _supported_by(item):
		poses[attached] = {"position": at + (attached.position - item.position).rotated(Vector3.UP, change), "yaw": attached.rotation.y + change, "support_id": attached.support_id}
	return poses


func _can_transform(item: FurnitureItem, at: Vector3, yaw: float, support_id: String, wall_id: String = "") -> bool:
	if not at.is_finite() or not is_finite(yaw):
		return false
	var poses := _proposed_poses(item, at, yaw, support_id)
	for candidate in poses:
		var pose: Dictionary = poses[candidate]
		if not _fits_room(candidate, pose["position"], pose["yaw"], room.get_floor_bounds(), wall_id if candidate == item else ""):
			placement_error = "Przedmiot wychodzi poza pokój"
			return false
		if not _supported_pose(candidate, pose, poses):
			placement_error = "Brak pełnego podparcia lub niedozwolony blat"
			return false
		for other in get_children():
			if not other is FurnitureItem or other == preview or other == candidate:
				continue
			var other_at: Vector3 = poses[other]["position"] if poses.has(other) else other.position
			var other_yaw: float = poses[other]["yaw"] if poses.has(other) else other.rotation.y
			if _objects_overlap(candidate, pose["position"], pose["yaw"], other, other_at, other_yaw):
				placement_error = "Kolizja z: " + str(CATALOG[other.type_id]["name"])
				return false
	return true


func _apply_transform(item: FurnitureItem, at: Vector3, yaw: float, support_id: String) -> void:
	var poses := _proposed_poses(item, at, yaw, support_id)
	for candidate in poses:
		candidate.position = poses[candidate]["position"]
		candidate.rotation.y = poses[candidate]["yaw"]
		candidate.support_id = poses[candidate]["support_id"]


func spawn_on_surface(type_id: String, support_id: String, offset: Vector2 = Vector2.ZERO) -> FurnitureItem:
	var support := _find_item(support_id)
	if support == null:
		return null
	var at := support.position + Vector3(offset.x, support.size.y, offset.y - 0.015).rotated(Vector3.UP, support.rotation.y)
	return spawn_furniture(type_id, at, support_id, support.rotation.y)


func _new_item(type_id: String) -> FurnitureItem:
	var item := FurnitureItem.new()
	item.type_id = type_id
	item.size = CATALOG[type_id]["size"]
	item.placement = CATALOG[type_id].get("placement", "floor")
	item.precise_collision = CATALOG[type_id].get("stackable", false)
	item.furniture_id = Crypto.new().generate_random_bytes(16).hex_encode()
	return item


func _make_item(type_id: String) -> FurnitureItem:
	var item := _new_item(type_id)
	add_child(item)
	return item


func spawn_furniture(type_id: String, at: Vector3, support_id: String = "", yaw: float = 0.0) -> FurnitureItem:
	if not CATALOG.has(type_id):
		status_changed.emit("Nieznany typ mebla")
		return null
	if CATALOG[type_id].get("placement", "floor") == "wall":
		status_changed.emit("Okno wymaga ściany: użyj katalogu lub spawn_window")
		return null
	var item := _make_item(type_id)
	item.support_id = support_id
	if not is_placement_valid(item, at, yaw):
		remove_child(item)
		item.queue_free()
		status_changed.emit("Brak miejsca: ściana lub inny mebel")
		return null
	item.position = at
	item.rotation.y = yaw
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
	if CATALOG[type_id].get("stackable", false):
		status_changed.emit("Wskaż podłogę lub blat mebla; zielony kolor pozwala ustawić")
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
	preview.support_id = moving.support_id
	for attached in _supported_by(moving):
		var ghost := _new_item(attached.type_id)
		preview.add_child(ghost)
		ghost.position = (attached.position - moving.position).rotated(Vector3.UP, -moving.rotation.y)
		ghost.rotation.y = attached.rotation.y - moving.rotation.y
		ghost.collision_layer = 0
		preview_attached.append(ghost)
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
	preview_attached.clear()
	moving = null
	candidate_valid = false
	last_preview_message = ""
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


func move_selected(at: Vector3, support_id: String = "") -> bool:
	if selected == null:
		return false
	var next_support := support_id
	if next_support.is_empty() and at.y > 0.001 and selected.placement != "wall":
		next_support = selected.support_id
	if not _can_transform(selected, at, selected.rotation.y, next_support):
		status_changed.emit("Nie można przenieść: brak podparcia lub kolizja")
		return false
	_apply_transform(selected, at, selected.rotation.y, next_support)
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
	_apply_transform(selected, selected.position, yaw, selected.support_id)
	furniture_changed.emit()
	return true


func delete_selected() -> void:
	cancel_placement()
	if selected == null:
		return
	var item := selected
	if not _supported_by(item).is_empty():
		status_changed.emit("Najpierw przenieś lub usuń przedmioty z blatu")
		return
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
	var subject := ignore if ignore != null else item
	return _can_transform(subject, at, yaw, item.support_id, item.wall_id)


func _vertical_overlap(a: FurnitureItem, at: Vector3, b: FurnitureItem, bt: Vector3) -> bool:
	return at.y < bt.y + b.size.y - 0.00001 and bt.y < at.y + a.size.y - 0.00001


func _fits_room(item: FurnitureItem, at: Vector3, yaw: float, bounds: Dictionary, wall_override: String = "") -> bool:
	if item.placement != "wall":
		return at.y >= -0.0001 and at.y + item.size.y <= RoomGeometry.WALL_HEIGHT + 0.0001 and _inside(_corners(item, at, yaw), bounds)
	var wall := item.wall_id if wall_override.is_empty() else wall_override
	if not wall in ["FrontWall", "BackWall", "LeftWall", "RightWall"]:
		return false
	if at.y < 0.15 or at.y + item.size.y > RoomGeometry.WALL_HEIGHT - 0.1:
		return false
	if absf(wrapf(yaw - _wall_yaw(wall), -PI, PI)) > 0.001:
		return false
	var offset := _wall_offset(wall, at)
	if at.distance_to(_wall_position(wall, offset, at.y, bounds)) > 0.001:
		return false
	var maximum: Vector2 = bounds["max"]
	var half_span := maximum.x if wall in ["FrontWall", "BackWall"] else maximum.y
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
			if _objects_overlap(item, at, item.rotation.y, items[i], positions[i], items[i].rotation.y):
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


func _surface_point() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 200, 2)
	var excluded: Array[RID] = []
	if moving != null:
		excluded.append(moving.get_rid())
		for attached in _supported_by(moving):
			excluded.append(attached.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": _floor_point(), "support_id": "", "top": true}
	var support := hit["collider"] as FurnitureItem
	if support == null:
		return {"position": null, "support_id": "", "top": false}
	var at: Vector3 = hit["position"]
	at.y = support.position.y + support.size.y
	var local := (at - support.position).rotated(Vector3.UP, -support.rotation.y)
	var footprint := _footprint(preview)
	var relative_yaw := preview.rotation.y - support.rotation.y
	var c := absf(cos(relative_yaw))
	var s := absf(sin(relative_yaw))
	var extent := Vector2(c * footprint.x + s * footprint.y, s * footprint.x + c * footprint.y) / 2
	if CATALOG[preview.type_id].get("round_base", false):
		extent = footprint / 2
	var available := _surface_size(support) / 2 - extent
	if available.x >= 0 and available.y >= 0:
		local.x = clampf(local.x, -available.x, available.x)
		local.z = clampf(local.z, -available.y - 0.015, available.y - 0.015)
		at = support.position + local.rotated(Vector3.UP, support.rotation.y)
	return {"position": at, "support_id": support.furniture_id, "top": hit["normal"].y > 0.5}


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
	var top_valid := true
	if CATALOG[preview.type_id].get("stackable", false):
		var surface_hit := _surface_point()
		point = surface_hit["position"]
		preview.support_id = surface_hit["support_id"]
		top_valid = surface_hit["top"]
	else:
		preview.support_id = ""
	if preview.placement == "wall":
		var wall_hit := _wall_point()
		point = wall_hit.get("position")
		if not wall_hit.is_empty():
			preview.wall_id = wall_hit["wall"]
			preview.rotation.y = _wall_yaw(preview.wall_id)
	candidate_valid = point != null and top_valid and get_viewport().gui_get_hovered_control() == null
	preview.visible = point != null
	if point != null:
		preview.position = point
		candidate_valid = candidate_valid and is_placement_valid(preview, point, preview.rotation.y, moving)
	preview.set_highlight("valid" if candidate_valid else "invalid")
	for attached in preview_attached:
		attached.set_highlight("valid" if candidate_valid else "invalid")
	if get_viewport().gui_get_hovered_control() == null:
		var message := "Można ustawić — kliknij LPM" if candidate_valid else placement_error
		if point == null:
			message = "Wskaż podłogę lub powierzchnię"
		elif not top_valid:
			message = "Wskaż blat od góry"
		if message != last_preview_message:
			last_preview_message = message
			status_changed.emit(message)


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
	_apply_transform(item, item.position, wrapf(angle, -PI, PI), item.support_id)
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
				status_changed.emit(last_preview_message)
				return
			var item := moving if moving != null else preview
			item.wall_id = preview.wall_id
			_apply_transform(item, preview.position, preview.rotation.y, preview.support_id)
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


func _objects_overlap(a: FurnitureItem, at: Vector3, yaw: float, b: FurnitureItem, bt: Vector3, byaw: float) -> bool:
	if not _vertical_overlap(a, at, b, bt) or not _overlaps(_corners(a, at, yaw), _corners(b, bt, byaw)):
		return false
	if a.precise_collision and b.precise_collision:
		return DecorCollision.overlaps(a, at, yaw, b, bt, byaw)
	return true


# Persistence boundary: replaces furniture in the current room, never parses files.
# All validation happens in a hidden staging container before the live scene changes.
func restore_furniture(records: Variant, target_bounds: Dictionary = {}, commit_room: Callable = Callable()) -> Dictionary:
	var bounds: Dictionary = room.get_floor_bounds() if target_bounds.is_empty() else target_bounds
	if not records is Array:
		return {"ok": false, "error": "Furniture must be an array"}
	var stage := Node3D.new()
	stage.visible = false
	add_child(stage)
	var imported: Dictionary = {}
	var error := ""
	for record in records:
		if not record is Dictionary:
			error = "Each furniture record must be an object"
			break
		var valid := true
		for field in ["id", "type_id"]:
			if not record.get(field) is String or record[field].is_empty():
				valid = false
		for field in ["placement", "wall_id", "support_id"]:
			if record.has(field) and not record[field] is String:
				valid = false
		var coordinates: Variant = record.get("position")
		if not coordinates is Array or coordinates.size() != 3:
			valid = false
		else:
			for value in coordinates:
				if not _record_number(value):
					valid = false
		if not _record_number(record.get("rotation_y")):
			valid = false
		if not valid:
			error = "Invalid furniture fields"
			break
		if not CATALOG.has(record["type_id"]) or imported.has(record["id"]):
			error = "Unknown furniture type or duplicate ID"
			break
		var item := _new_item(record["type_id"])
		item.furniture_id = record["id"]
		item.support_id = record.get("support_id", "")
		item.wall_id = record.get("wall_id", "")
		item.position = Vector3(coordinates[0], coordinates[1], coordinates[2])
		item.rotation.y = record["rotation_y"]
		stage.add_child(item)
		item.collision_layer = 0
		imported[item.furniture_id] = item
		if record.get("placement", item.placement) != item.placement or (item.placement == "floor" and not item.wall_id.is_empty()):
			error = "Placement does not match furniture type"
			break
	if error.is_empty():
		var items := imported.values()
		for i in range(items.size()):
			var item: FurnitureItem = items[i]
			var pose := {"position": item.position, "yaw": item.rotation.y, "support_id": item.support_id}
			if not item.position.is_finite() or not is_finite(item.rotation.y) or not _fits_room(item, item.position, item.rotation.y, bounds) or not _supported_pose(item, pose, {}, imported):
				error = "Invalid position or support: " + item.furniture_id
				break
			for j in range(i):
				var other: FurnitureItem = items[j]
				if _objects_overlap(item, item.position, item.rotation.y, other, other.position, other.rotation.y):
					error = "Furniture overlaps: " + item.furniture_id
					break
			if not error.is_empty():
				break
	if not error.is_empty():
		stage.free()
		return {"ok": false, "error": error}
	cancel_placement()
	_select(null)
	for child in get_children():
		if child is FurnitureItem:
			remove_child(child)
			child.queue_free()
	for item in imported.values():
		# Keep room-local coordinates; staging container has an identity transform.
		item.reparent(self, false)
		item.collision_layer = 2
	stage.free()
	if commit_room.is_valid():
		commit_room.call()
	furniture_changed.emit()
	status_changed.emit("Wczytano wyposażenie pokoju")
	return {"ok": true, "error": ""}


func _record_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
