extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func click():
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = root.get_mouse_position()
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
func run():
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	system.begin_placement("table")
	root.warp_mouse(system.camera.unproject_position(Vector3.ZERO))
	for i in range(5): await process_frame
	check(system.candidate_valid, "Floor ray yields valid placement")
	click()
	await physics_frame
	check(system.get_all_furniture().size() == 1, "Mouse click commits placement")
	system._select(null)
	root.warp_mouse(system.camera.unproject_position(Vector3(0, 0.7, 0)))
	for i in range(5): await process_frame
	click()
	check(system.selected != null, "Mouse click selects table")
	if system.selected != null:
		system.begin_move_selected()
		root.warp_mouse(system.camera.unproject_position(Vector3(1, 0, 0.6)))
		for i in range(5): await process_frame
		click()
		check(system.selected.position.distance_to(Vector3(1,0,0.6)) < 0.05, "Mouse move commits new position")
	system.begin_placement("table")
	root.warp_mouse(Vector2(80, 80))
	for i in range(5): await process_frame
	check(not system.candidate_valid, "UI panel blocks placement")
	system.cancel_placement()
	system.spawn_furniture("table", Vector3(-0.8,0,0))
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://furniture_preview.png")
	print("Failures: ", failures)
	quit(1 if failures else 0)
