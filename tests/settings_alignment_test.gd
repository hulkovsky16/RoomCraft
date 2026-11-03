extends SceneTree

var failures := 0


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.gui_disable_input = false
	viewport.own_world_3d = true
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	var ui = scene.get_node("UILayer/RoomUI")
	var camera = scene.get_node("Camera3D")
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	camera.set_process(false)
	system.set_process(false)
	ui.width_input.text = "2"
	ui.length_input.text = "2"
	ui._on_apply_pressed()
	check(scene.get_room_size() == Vector2(2,2), "Minimum 2 x 2 accepted through UI")
	ui.width_input.text = "30"
	ui.length_input.text = "30"
	ui._on_apply_pressed()
	check(scene.get_room_size() == Vector2(30,30), "Maximum 30 x 30 accepted through UI")
	check(camera.max_distance > 42 and camera.distance >= 36, "Camera adapts to large room")
	ui.width_input.text = "1.9"
	ui._on_apply_pressed()
	check(scene.get_room_size() == Vector2(30,30), "Below new minimum rejected")
	ui.width_input.text = "30.1"
	ui._on_apply_pressed()
	check(scene.get_room_size() == Vector2(30,30), "Above new maximum rejected")
	check(system.spawn_window("FrontWall",14) != null, "Window attaches near edge of large room")
	check(not scene.set_room_size(2,2), "Shrinking cannot clip attached windows")
	system.delete_selected()
	scene.set_room_size(5,4)
	var slider: HSlider = ui.find_child("CameraSensitivity", true, false)
	slider.value = 0.25
	check(is_equal_approx(camera.rotation_sensitivity, 0.002), "Sensitivity slider changes camera setting")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640,400)
	motion.relative = Vector2(10,0)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	camera.reset_view()
	camera.rotating = true
	camera._input(motion)
	var low_delta: float = absf(camera.yaw - 0.7)
	slider.value = 3.0
	camera.reset_view()
	camera.rotating = true
	camera._input(motion)
	check(is_equal_approx(absf(camera.yaw - 0.7), low_delta * 12), "Mouse response respects sensitivity range")
	camera.reset_view()
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.physical_keycode = KEY_W
	key.pressed = true
	viewport.push_input(key,true)
	var start: Vector3 = camera.position
	camera._process(0.25)
	key.pressed = false
	viewport.push_input(key,true)
	check(camera.position.distance_to(start) > 0.9, "Physical WASD works across keyboard layouts")
	key.physical_keycode = KEY_UP
	key.keycode = KEY_UP
	key.pressed = true
	viewport.push_input(key,true)
	start = camera.position
	camera._process(0.25)
	check(camera.position == start, "Arrow keys no longer move camera")
	key.pressed = false
	viewport.push_input(key,true)
	var table := system.spawn_furniture("table",Vector3.ZERO)
	for case in [[38.0,1.0,45.0],[38.0,-1.0,30.0],[-38.0,1.0,-30.0],[-38.0,-1.0,-45.0],[45.0,1.0,60.0],[179.0,1.0,-180.0]]:
		table.rotation.y = deg_to_rad(case[0])
		system.start_rotation("test",case[1])
		system.stop_rotation("test")
		check(is_equal_approx(table.rotation.y,deg_to_rad(case[2])), "Tap snaps absolute angle: " + str(case))
	table.rotation.y = deg_to_rad(88)
	check(system.align_active() and is_equal_approx(table.rotation.y,PI/2), "Align to 90 degree room axis")
	table.rotation.y = deg_to_rad(-2)
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	key.pressed = true
	viewport.push_input(key,true)
	check(is_zero_approx(table.rotation.y), "F aligns selected object to zero")
	key.pressed = false
	viewport.push_input(key,true)
	table.rotation.y = deg_to_rad(30)
	var flowers := system.spawn_furniture("flowers",Vector3(0.85,0,0.55))
	check(flowers != null, "Obstacle fits beside rotated object")
	system._select(table)
	check(not system.align_active() and is_equal_approx(table.rotation.y,deg_to_rad(30)), "Blocked alignment preserves original angle")
	system.begin_placement("chair")
	system.preview.rotation.y = deg_to_rad(103)
	check(system.align_active() and is_equal_approx(system.preview.rotation.y,PI/2), "Preview can align before placement")
	system.cancel_placement()
	scene.queue_free()
	await process_frame
	print("Failures: ",failures)
	quit(1 if failures else 0)
