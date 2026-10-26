extends SceneTree
var failures := 0
var test_viewport: SubViewport
var mouse_at := Vector2.ZERO
func check(ok: bool, label: String):
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
# Local viewport events keep tests independent of the physical desktop pointer.
func point_mouse(at: Vector2):
	var motion := InputEventMouseMotion.new()
	mouse_at = at
	motion.position = at
	motion.global_position = at
	test_viewport.push_input(motion, true)
	await process_frame
func click():
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = mouse_at
	test_viewport.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	test_viewport.push_input(event, true)
func run():
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.own_world_3d = true
	test_viewport.gui_disable_input = false
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	system.begin_placement("table")
	await point_mouse(system.camera.unproject_position(Vector3.ZERO))
	for i in range(5): await process_frame
	check(system.candidate_valid, "Floor ray yields valid placement")
	click()
	await physics_frame
	check(system.get_all_furniture().size() == 1, "Mouse click commits placement")
	system._select(null)
	await point_mouse(system.camera.unproject_position(Vector3(0, 0.7, 0)))
	for i in range(5): await process_frame
	click()
	check(system.selected != null, "Mouse click selects table")
	if system.selected != null:
		system.begin_move_selected()
		await point_mouse(system.camera.unproject_position(Vector3(1, 0, 0.6)))
		for i in range(5): await process_frame
		click()
		check(system.selected.position.distance_to(Vector3(1,0,0.6)) < 0.05, "Mouse move commits new position")
	system.begin_placement("table")
	await point_mouse(Vector2(80, 80))
	for i in range(5): await process_frame
	check(not system.candidate_valid, "UI panel blocks placement")
	system.cancel_placement()
	var catalog: ItemList = scene.get_node("FurnitureDebugUI").find_child("FurnitureCatalog", true, false)
	for index in [1, 1, 25]:
		catalog.select(index)
		catalog.ensure_current_is_visible()
		for i in range(3): await process_frame
		await point_mouse(catalog.global_position + catalog.get_item_rect(index).get_center() - Vector2(0, catalog.get_v_scroll_bar().value))
		for i in range(3): await process_frame
		click()
		check(system.preview != null and system.preview.type_id == system.get_catalog().keys()[index], "Catalog click starts correct preview: " + str(index))
		system.cancel_placement()
	var category: OptionButton = scene.get_node("FurnitureDebugUI").find_child("CatalogCategory", true, false)
	category.select(3)
	category.item_selected.emit(3)
	check(catalog.item_count == 6, "Kitchen filter contains six items")
	category.select(4)
	category.item_selected.emit(4)
	check(catalog.item_count == 5, "Bathroom filter contains five items")
	category.select(5)
	category.item_selected.emit(5)
	check(catalog.item_count == 1 and catalog.get_item_metadata(0) == "window", "Window filter")
	for i in range(3): await process_frame
	await point_mouse(catalog.global_position + catalog.get_item_rect(0).get_center())
	for i in range(3): await process_frame
	click()
	check(system.preview != null and system.preview.type_id == "window", "Window picked from filtered catalog")
	await point_mouse(system.camera.unproject_position(Vector3(0, 1.55, -2)))
	for i in range(5): await process_frame
	check(system.candidate_valid and system.preview.wall_id == "FrontWall", "Window preview snaps to visible wall")
	click()
	await physics_frame
	check(system.selected != null and system.selected.type_id == "window", "Click installs window")
	system.begin_move_selected()
	await point_mouse(system.camera.unproject_position(Vector3(-2.5, 1.55, 0)))
	for i in range(5): await process_frame
	check(system.candidate_valid and system.preview.wall_id == "LeftWall", "Window can move to another wall")
	click()
	check(system.selected != null and system.selected.wall_id == "LeftWall", "Window transfer committed")
	system.delete_selected()
	check(scene.get_node("RoomGeometry").window_openings.is_empty(), "Delete from UI restores wall")
	category.select(0)
	category.item_selected.emit(0)
	system.spawn_furniture("table", Vector3(-0.8,0,0))
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	test_viewport.get_texture().get_image().save_png("user://furniture_preview.png")
	print("Failures: ", failures)
	quit(1 if failures else 0)
