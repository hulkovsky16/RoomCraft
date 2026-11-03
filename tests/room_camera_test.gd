extends SceneTree

var failures := 0
var viewport: SubViewport


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func key_event(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	viewport.push_input(event, true)


func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	viewport.own_world_3d = true
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	var ui = scene.get_node("UILayer/RoomUI")
	var camera = scene.get_node("Camera3D")
	var furniture: FurnitureSystem = scene.get_node("FurnitureRoot")
	for dimensions in [Vector2(6, 5), Vector2(8, 7), Vector2(5, 4)]:
		ui.width_input.grab_focus()
		ui.width_input.text = str(dimensions.x)
		ui.length_input.text = str(dimensions.y)
		click(ui.apply_button)
		await process_frame
		check(scene.get_room_size() == dimensions, "Typed resize applied repeatedly: " + str(dimensions))
		check(viewport.gui_get_focus_owner() == null, "Apply releases field focus")
	# Resize with furniture and a window, including a rejected resize and recovery.
	var table := furniture.spawn_furniture("table", Vector3(1.5, 0, 0))
	var window := furniture.spawn_window("FrontWall", 0)
	ui.width_input.text = "3"
	ui.length_input.text = "3"
	click(ui.apply_button)
	check(scene.get_room_size() == Vector2(5, 4), "Occupied room rejects invalid shrink")
	check(ui.width_input.read_value() == 5 and ui.length_input.read_value() == 4, "Rejected resize restores displayed dimensions")
	ui.width_input.text = "7"
	ui.length_input.text = "6"
	click(ui.apply_button)
	check(scene.get_room_size() == Vector2(7, 6), "Resize still works after rejection")
	check(is_equal_approx(window.position.z, -3) and table.position.x == 1.5, "Resize preserves furniture and moves attached window")
	camera.set_process(false)
	var start: Vector3 = camera.position
	key_event(KEY_W, true)
	camera._process(0.25)
	key_event(KEY_W, false)
	check(camera.position.distance_to(start) > 0.9, "W flies camera forward")
	var stopped: Vector3 = camera.position
	camera._process(0.25)
	check(camera.position == stopped, "Release stops flight")
	key_event(KEY_S, true)
	camera._process(0.25)
	key_event(KEY_S, false)
	check(camera.position.distance_to(start) < 0.001, "S flies backward")
	key_event(KEY_D, true)
	camera._process(0.25)
	key_event(KEY_D, false)
	check(camera.position.distance_to(start) > 0.9, "D strafes")
	key_event(KEY_A, true)
	camera._process(0.25)
	key_event(KEY_A, false)
	check(camera.position.distance_to(start) < 0.001, "A strafes back")
	key_event(KEY_PAGEUP, true)
	camera._process(0.25)
	key_event(KEY_PAGEUP, false)
	check(is_equal_approx(camera.position.y, start.y + 1), "Page Up ascends")
	key_event(KEY_PAGEDOWN, true)
	camera._process(0.25)
	key_event(KEY_PAGEDOWN, false)
	check(camera.position.distance_to(start) < 0.001, "Page Down descends")
	key_event(KEY_SHIFT, true)
	key_event(KEY_D, true)
	camera._process(0.25)
	key_event(KEY_D, false)
	key_event(KEY_SHIFT, false)
	check(is_equal_approx(camera.position.distance_to(start), 3.0), "Shift boosts speed threefold")
	start = camera.position
	ui.width_input.grab_focus()
	key_event(KEY_W, true)
	camera._process(0.25)
	key_event(KEY_W, false)
	check(camera.position == start, "WASD does not fly while editing dimensions")
	ui.width_input.release_focus()
	key_event(KEY_D, true)
	camera._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	camera._process(0.25)
	check(camera.position == start, "Focus loss clears held movement")
	key_event(KEY_PAGEDOWN, true)
	camera._process(10)
	key_event(KEY_PAGEDOWN, false)
	check(camera.position.y >= 0.1999, "Flight stays above the floor")
	scene.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
