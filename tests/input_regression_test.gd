extends SceneTree

var viewport: SubViewport
var failures := 0


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func key(code: int, pressed: bool, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.unicode = unicode_value
	event.pressed = pressed
	viewport.push_input(event, true)


func type_into(field: LineEdit, value: String) -> void:
	field.grab_focus()
	field.select_all()
	for character in value:
		key(character.to_upper().unicode_at(0), true, character.unicode_at(0))
		key(character.to_upper().unicode_at(0), false)
		await process_frame


func mouse_button(at: Vector2, index: int, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	viewport.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = index
	event.pressed = pressed
	viewport.push_input(event, true)


func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	mouse_button(at, MOUSE_BUTTON_LEFT, true)
	mouse_button(at, MOUSE_BUTTON_LEFT, false)


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
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	camera.set_process(false)
	system.set_process(false)
	for pair in [["6", "5"], ["8", "7"], ["3", "4"], ["10", "10"], ["6,5", "4.5"], ["5.25", "3,75"]]:
		await type_into(ui.width_input, pair[0])
		await type_into(ui.length_input, pair[1])
		click(ui.apply_button)
		var expected := Vector2(float(pair[0].replace(",", ".")), float(pair[1].replace(",", ".")))
		check(scene.get_room_size().is_equal_approx(expected), "Real key input repeated resize " + str(pair))
	await type_into(ui.width_input, "6a!b+2")
	check(ui.width_input.text == "62", "Letters and expression operators blocked on typing")
	await type_into(ui.width_input, "6,,..5")
	check(ui.width_input.text == "6,5", "Only one decimal separator accepted")
	ui.width_input.text = ""
	ui.width_input.insert_text_at_caret("a7.2!+z")
	# insert_text_at_caret is programmatic and does not emit the native paste signal.
	ui.width_input.text_changed.emit(ui.width_input.text)
	await process_frame
	check(ui.width_input.text == "7.2", "Inserted or pasted text sanitized")
	ui.width_input.text = ""
	var before: Vector2 = scene.get_room_size()
	click(ui.apply_button)
	check(scene.get_room_size() == before, "Empty dimensions rejected")
	await type_into(ui.width_input, "31")
	click(ui.apply_button)
	check(scene.get_room_size() == before, "Out of range dimensions rejected")
	await type_into(ui.width_input, "5")
	await type_into(ui.length_input, "4")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	check(scene.get_room_size() == Vector2(5, 4), "Enter applies valid dimensions after errors")
	# Move first, then rotate: the camera must rotate in place, without orbit jumps.
	var start: Vector3 = camera.position
	key(KEY_W, true)
	camera._process(0.5)
	key(KEY_W, false)
	check(is_equal_approx(camera.position.y, start.y), "WASD flight preserves height")
	var after_flight: Vector3 = camera.position
	mouse_button(Vector2(640,400), MOUSE_BUTTON_RIGHT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(660,410)
	motion.relative = Vector2(50,20)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	viewport.push_input(motion, true)
	check(camera.position.is_equal_approx(after_flight), "RMB after flight rotates in place")
	check(is_zero_approx(camera.rotation.z), "Camera remains level without roll")
	# Missing release must not leave rotation active.
	motion.button_mask = 0
	viewport.push_input(motion, true)
	var angle: Vector3 = camera.rotation
	viewport.push_input(motion, true)
	check(camera.rotation == angle and not camera.rotating, "Mouse motion without held RMB does not rotate")
	mouse_button(Vector2(640,400), MOUSE_BUTTON_WHEEL_UP, true)
	check(camera.position.distance_to(after_flight) <= 0.601, "Flight wheel moves a short step without orbit teleport")
	key(KEY_D, true)
	camera._process(100)
	key(KEY_D, false)
	check(camera.position.distance_to(Vector3(0,1,0)) <= camera.max_distance + 0.001, "Flight cannot drift arbitrarily far from room")
	key(KEY_R, true)
	key(KEY_R, false)
	check(not camera.free_flight and camera.position.is_equal_approx(start), "R restores original room overview")
	var table := system.spawn_furniture("table", Vector3.ZERO)
	key(KEY_E, true)
	check(is_equal_approx(table.rotation.y, deg_to_rad(15)), "Rotation tap retains 15 degree step")
	for i in range(10):
		system._process_rotation(0.1)
	check(table.rotation.y > deg_to_rad(70), "Holding E continuously rotates object")
	key(KEY_E, false)
	var yaw := table.rotation.y
	system._process_rotation(0.5)
	check(is_equal_approx(table.rotation.y, yaw), "Releasing E stops rotation")
	var left: Button = scene.get_node("FurnitureDebugUI").find_child("RotateLeft", true, false)
	mouse_button(left.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	for i in range(6):
		system._process_rotation(0.1)
	mouse_button(left.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, false)
	check(table.rotation.y < yaw - deg_to_rad(35), "Holding UI rotation button rotates continuously")
	yaw = table.rotation.y
	system._process_rotation(0.5)
	check(is_equal_approx(table.rotation.y, yaw), "UI release stops rotation")
	system.begin_placement("chair")
	system.start_rotation("test", 1)
	for i in range(6): system._process_rotation(0.1)
	check(system.preview.rotation.y > deg_to_rad(35), "Holding rotates placement preview")
	system.cancel_placement()
	check(system.rotation_holds.is_empty(), "Cancel clears rotation hold")
	system._select(table)
	table.rotation.y = 0
	check(system.move_selected(Vector3(0, 0, 1.4)), "Move near wall for rotation collision test")
	system.start_rotation("test", 1)
	for i in range(30): system._process_rotation(0.1)
	check(system.is_placement_valid(table, table.position, table.rotation.y, table), "Held rotation cannot cross wall")
	check(table.rotation.y < PI / 2, "Rotation stops at collision instead of skipping over it")
	system._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(system.rotation_holds.is_empty(), "Focus loss stops rotation")
	scene.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
