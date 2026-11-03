extends SceneTree

var failures := 0


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	var geometry: RoomGeometry = scene.get_node("RoomGeometry")
	check(system.spawn_furniture("window", Vector3.ZERO) == null, "Window cannot be placed on floor")
	check(system.spawn_window("unknown", 0) == null, "Unknown wall rejected")
	check(system.spawn_window("FrontWall", INF) == null, "Invalid offset rejected")
	check(system.spawn_window("FrontWall", 2.2) == null, "Window cannot cross corner")
	check(system.spawn_window("FrontWall", 0, 2.0) == null, "Window cannot cross ceiling")
	check(system.spawn_window("FrontWall", 0, -0.2) == null, "Window cannot cross floor")
	var window := system.spawn_window("FrontWall", 0)
	check(window != null and window.position == Vector3(0, 1, -2), "Window attaches to wall")
	check(geometry.window_openings.size() == 1, "Wall opening registered")
	check(system.spawn_window("FrontWall", 0.2) == null, "Overlapping windows rejected")
	check(not system.rotate_selected(PI / 4), "Wall rotation cannot detach window")
	check(not system.move_selected(Vector3.ZERO), "Window cannot move off wall")
	check(system.move_selected(Vector3(0.4, 0.9, -2)), "Move window along wall")
	var bounds := AABB(Vector3(-window.size.x / 2, 0, -window.size.z / 2), window.size).grow(0.001)
	var fits := true
	for visual in window.surfaces:
		fits = fits and bounds.encloses(visual.transform * visual.get_aabb())
	check(fits, "Frame and glass inside declared dimensions")
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0.4, 1.4, -1), Vector3(0.4, 1.4, -3), 1)
	check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Opening is a real gap in wall collision")
	var record: Dictionary = system.get_all_furniture()[0]
	check(record["wall_id"] == "FrontWall" and record["placement"] == "wall" and is_equal_approx(record["position"][1], 0.9), "Wall and elevation recorded for persistence")
	check(scene.set_room_size(6, 6), "Resize with attached window")
	check(window.position == Vector3(0.4, 0.9, -3), "Window follows resized wall")
	system.begin_move_selected()
	system.preview.wall_id = "LeftWall"
	system.preview.position = Vector3(-3, 1, 0)
	system.cancel_placement()
	check(window.wall_id == "FrontWall" and window.position.z == -3, "Cancel preserves window and opening")
	var second := system.spawn_window("FrontWall", 2.0)
	check(second != null, "Multiple windows on one wall")
	check(not scene.set_room_size(4, 6), "Resize cannot clip attached window")
	system.delete_selected()
	check(geometry.window_openings.size() == 1, "Delete removes one opening only")
	for wall in ["BackWall", "LeftWall", "RightWall"]:
		var added := system.spawn_window(wall, 0)
		check(added != null, "Attach to " + wall)
		system.delete_selected()
	system._select(window)
	system.delete_selected()
	await physics_frame
	await physics_frame
	ray = PhysicsRayQueryParameters3D.create(Vector3(0.4, 1.4, -2), Vector3(0.4, 1.4, -4), 1)
	check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Deleting last window restores solid wall")
	# Low cabinets fit below a window; tall units intersect its frame.
	var low := system.spawn_furniture("kitchen_cabinet", Vector3(0, 0, -2.64))
	check(low != null, "Cabinet below sill fits")
	window = system.spawn_window("FrontWall", 0, 1.0)
	check(window != null, "Window above cabinet is allowed")
	system._select(low)
	system.delete_selected()
	check(system.spawn_furniture("fridge", Vector3(0, 0, -2.59)) == null, "Tall furniture intersects frame and is rejected")
	scene.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
