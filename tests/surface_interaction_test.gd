extends SceneTree

var failures := 0
var viewport: SubViewport
var mouse_at := Vector2.ZERO


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:
		failures += 1


func point_at(point: Vector2) -> void:
	mouse_at = point
	var event := InputEventMouseMotion.new()
	event.position = point
	viewport.push_input(event,true)
	for frame in range(4): await process_frame


func click() -> void:
	var event := InputEventMouseButton.new()
	event.position = mouse_at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event,true)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.gui_disable_input = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	var camera: Camera3D = scene.get_node("Camera3D")
	var stand := system.spawn_furniture("nightstand",Vector3.ZERO)
	var washer := system.spawn_furniture("washing_machine",Vector3(1.1,0,0))
	var cooker := system.spawn_furniture("cooker",Vector3(-1.2,0,0))
	await physics_frame
	await physics_frame
	system.begin_placement("flowers")
	await point_at(camera.unproject_position(Vector3(0,0.5,-0.015)))
	check(system.candidate_valid and system.preview.support_id == stand.furniture_id, "Mouse detects nightstand top")
	check(is_equal_approx(system.preview.position.y,0.5), "Preview snaps to top height")
	click()
	var flowers := system.selected
	check(flowers != null and flowers.type_id == "flowers" and flowers.support_id == stand.furniture_id, "Click places flowers on nightstand")
	await physics_frame
	await physics_frame
	system._select(null)
	await point_at(camera.unproject_position(flowers.position + Vector3(0,0.4,0)))
	click()
	check(system.selected == flowers, "Decor selectable independently of support")
	system.begin_move_selected()
	await point_at(camera.unproject_position(Vector3(1.1,0.85,-0.015)))
	check(system.candidate_valid and system.preview.support_id == washer.furniture_id, "Move preview detects another top")
	click()
	check(flowers.support_id == washer.furniture_id and is_equal_approx(flowers.position.y,0.85), "Mouse transfers decor to washing machine")
	system.begin_move_selected()
	await point_at(camera.unproject_position(Vector3(0,0,1.1)))
	check(system.candidate_valid and system.preview.support_id.is_empty(), "Preview can return to floor")
	click()
	check(absf(flowers.position.y) < 0.001 and flowers.support_id.is_empty(), "Click returns decor to floor")
	system.begin_placement("table_lamp")
	await point_at(camera.unproject_position(Vector3(-1.2,0.9,0)))
	check(not system.candidate_valid, "Cooker top rejected by mouse placement")
	system.cancel_placement()
	var lamp := system.spawn_on_surface("table_lamp",washer.furniture_id)
	check(lamp != null, "Lamp on washer for group move")
	system._select(washer)
	system.begin_move_selected()
	await point_at(camera.unproject_position(Vector3(1.1,0,1.1)))
	check(system.candidate_valid and system.preview_attached.size() == 1, "Loaded support has valid group preview")
	click()
	check(lamp.position.distance_to(washer.position + Vector3(0,0.85,-0.015)) < 0.001, "Mouse move carries lamp with support")
	await physics_frame
	await physics_frame
	system.begin_placement("potted_plant")
	await point_at(camera.unproject_position(lamp.position + Vector3(0,0.45,0)))
	check(not system.candidate_valid, "Cannot stack on decor")
	system.cancel_placement()
	system._select(cooker)
	system.delete_selected()
	system._select(null)
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("user://RoomCraft-surfaces-test.png")
	print("Failures: ",failures)
	quit(1 if failures else 0)
