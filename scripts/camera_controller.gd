extends Camera3D

@export var target := Vector3(0, 1, 0)
@export var distance := 8.0
@export var min_distance := 2.0
@export var max_distance := 20.0
@export var rotation_sensitivity := 0.008
@export var zoom_factor := 0.12
@export var pan_sensitivity := 0.002
@export var flight_speed := 4.0
@export var flight_boost := 3.0

var yaw := 0.7
var pitch := 0.55
var rotating := false
var panning := false
var free_flight := false
var flight_keys: Dictionary = {}
const FLIGHT_KEYS := [KEY_W, KEY_S, KEY_A, KEY_D, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT]


func _ready() -> void:
	_update_camera()
	get_parent().room_size_changed.connect(_on_room_resized)


func _on_room_resized(width: float, length: float) -> void:
	max_distance = maxf(20.0, Vector2(width, length).length() + 8.0)
	if not free_flight:
		distance = maxf(8.0, maxf(width, length) * 1.2)
		_update_camera()


func _editing_text() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or focused is SpinBox


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		flight_keys.clear()
		rotating = false
		panning = false


func _process(delta: float) -> void:
	if _editing_text():
		flight_keys.clear()
		return
	var sideways := float(flight_keys.has(KEY_D)) - float(flight_keys.has(KEY_A))
	var forward := float(flight_keys.has(KEY_W)) - float(flight_keys.has(KEY_S))
	var vertical := float(flight_keys.has(KEY_PAGEUP)) - float(flight_keys.has(KEY_PAGEDOWN))
	# Horizontal WASD flight never dives toward the floor or changes the pitch.
	var direction := Vector3(cos(yaw), 0, -sin(yaw)) * sideways + Vector3(-sin(yaw), 0, -cos(yaw)) * forward + Vector3.UP * vertical
	if direction.is_zero_approx():
		return
	free_flight = true
	var speed := flight_speed * (flight_boost if flight_keys.has(KEY_SHIFT) else 1.0)
	_move_flight(direction.normalized() * speed * delta)


func _move_flight(movement: Vector3) -> void:
	var next := global_position + movement
	next.y = clampf(next.y, 0.2, 15.0)
	# Bound travel around the room, rather than moving an invisible orbit pivot.
	var center := Vector3(0, 1, 0)
	next = center + (next - center).limit_length(max_distance)
	next.y = maxf(0.2, next.y)
	global_position = next


func reset_view() -> void:
	flight_keys.clear()
	free_flight = false
	rotating = false
	panning = false
	target = Vector3(0, 1, 0)
	var room_size: Vector2 = get_parent().get_room_size()
	distance = maxf(8.0, maxf(room_size.x, room_size.y) * 1.2)
	yaw = 0.7
	pitch = 0.55
	_update_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in FLIGHT_KEYS:
			if not event.pressed:
				flight_keys.erase(key)
			elif not _editing_text():
				flight_keys[key] = true
			if key != KEY_SHIFT and not _editing_text():
				get_viewport().set_input_as_handled()
			return
		if key == KEY_R and event.pressed and not event.echo and not _editing_text():
			reset_view()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = false
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false
	if get_viewport().gui_get_hovered_control() != null or _editing_text():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var sign_value := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if free_flight:
				_move_flight(-global_transform.basis.z * sign_value * 0.6)
			else:
				distance = clampf(distance * (1.0 - sign_value * zoom_factor), min_distance, max_distance)
				_update_camera()
	elif event is InputEventMouseMotion:
		# A missing button-up event must not leave a drag latched.
		rotating = rotating and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		panning = panning and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
		if rotating:
			yaw = wrapf(yaw - event.relative.x * rotation_sensitivity, -PI, PI)
			pitch += event.relative.y * rotation_sensitivity
			pitch = clampf(pitch, -1.35 if free_flight else 0.1, 1.35)
			_update_camera()
		elif panning:
			var movement: Vector3 = (-global_transform.basis.x * event.relative.x + global_transform.basis.y * event.relative.y) * distance * pan_sensitivity
			if free_flight:
				_move_flight(movement)
			else:
				target += movement
				target = Vector3.ZERO + target.limit_length(8.0)
				_update_camera()


func _update_camera() -> void:
	if free_flight:
		# In flight, RMB changes orientation around the camera itself.
		rotation = Vector3(-pitch, yaw, 0)
		return
	var horizontal := distance * cos(pitch)
	global_position = target + Vector3(horizontal * sin(yaw), distance * sin(pitch), horizontal * cos(yaw))
	look_at(target, Vector3.UP)
