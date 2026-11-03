extends SceneTree

var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	check(system.camera != null, "Camera available for picking")
	var table := system.spawn_furniture("table", Vector3.ZERO)
	check(table != null, "Spawn table on floor")
	check(system.spawn_furniture("table", Vector3.ZERO) == null, "Reject overlap")
	check(system.spawn_furniture("missing", Vector3.ZERO) == null, "Reject unknown type")
	check(system.spawn_furniture("table", Vector3(2.4, 0, 0)) == null, "Reject wall overlap")
	check(not system.move_selected(Vector3(INF, 0, 0)), "Reject nonfinite position")
	check(system.rotate_selected(PI / 4), "Rotate table at center")
	var second := system.spawn_furniture("table", Vector3(0, 0, 1.4))
	check(second != null, "Spawn second separate table")
	check(not system.move_selected(Vector3(0, 0, 0.2)), "Reject overlap with rotated table")
	check(not system.rotate_selected(PI / 2), "Reject rotation through wall")
	check(is_zero_approx(second.rotation.y), "Rejected rotation preserves transform")
	check(not scene.set_room_size(3, 3), "Reject shrink containing furniture outside bounds")
	check(scene.get_room_size() == Vector2(5, 4), "Rejected resize preserves room")
	system.begin_move_selected()
	system.preview.position = Vector3(20, 0, 20)
	system.cancel_placement()
	check(second.position == Vector3(0, 0, 1.4), "Cancelled move preserves original position")
	system.begin_placement("table")
	check(system.get_all_furniture().size() == 2, "Preview excluded from persistence")
	system.cancel_placement()
	var records := system.get_all_furniture()
	check(records[0]["id"] != records[1]["id"], "Unique stable identifiers")
	check(records[0].has("rotation_y") and records[0].has("type_id"), "Persistence record contains type and yaw")
	system.delete_selected()
	check(system.get_all_furniture().size() == 1 and system.selected == null, "Delete clears selection")
	check(scene.set_room_size(3, 3), "Resize succeeds when furniture fits")
	# Two edge-touching tables fit, but a real overlap does not.
	system._select(table)
	system.delete_selected()
	scene.set_room_size(5, 4)
	system.spawn_furniture("table", Vector3(-0.7, 0, 0))
	check(system.spawn_furniture("table", Vector3(0.7, 0, 0)) != null, "Touching edges allowed")
	check(not system.move_selected(Vector3(0.69, 0, 0)), "Small actual overlap rejected")
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(-0.7, 3, 0), Vector3(-0.7, -1, 0), 2)
	check(not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Furniture collision supports picking")
	scene.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
