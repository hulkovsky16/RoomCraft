
extends Camera3D

@export var target: Vector3 = Vector3(0, 1, 0)
@export var distance: float = 8.0
@export var min_distance: float = 2.0
@export var max_distance: float = 20.0
@export var rotation_sensitivity: float = 0.008
@export var zoom_factor: float = 0.12
@export var pan_sensitivity: float = 0.002
@export var flight_speed: float = 4.0
@export var flight_boost: float = 3.0

var yaw: float = 0.7
var pitch: float = 0.55
var rotating := false
var panning := false
var flight_keys: Dictionary = {}
const FLIGHT_KEYS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT]


func _ready() -> void:
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
	var sideways := float(flight_keys.has(KEY_RIGHT)) - float(flight_keys.has(KEY_LEFT))
	var forward := float(flight_keys.has(KEY_UP)) - float(flight_keys.has(KEY_DOWN))
	var vertical := float(flight_keys.has(KEY_PAGEUP)) - float(flight_keys.has(KEY_PAGEDOWN))
	var direction := global_transform.basis.x * sideways - global_transform.basis.z * forward + Vector3.UP * vertical
	if direction.is_zero_approx():
		return
	var speed := flight_speed * (flight_boost if flight_keys.has(KEY_SHIFT) else 1.0)
	var movement := direction.normalized() * speed * delta
	# Keep the camera above the floor while allowing flight through the room.
	movement.y = maxf(movement.y, 0.2 - global_position.y)
	target += movement
	_update_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key in FLIGHT_KEYS:
			if not event.pressed:
				flight_keys.erase(key)
			elif not _editing_text():
				flight_keys[key] = true
			if key != KEY_SHIFT and not _editing_text():
				get_viewport().set_input_as_handled()
			return
	# Always release a drag, even when the pointer moves over a UI panel.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = false
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false
	if get_viewport().gui_get_hovered_control() != null:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed

		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed

		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance *= 1.0 - zoom_factor
				distance = clampf(distance, min_distance, max_distance)
				_update_camera()

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance *= 1.0 + zoom_factor
				distance = clampf(distance, min_distance, max_distance)
				_update_camera()

	elif event is InputEventMouseMotion:
		if rotating:
			yaw -= event.relative.x * rotation_sensitivity
			pitch += event.relative.y * rotation_sensitivity
			pitch = clampf(pitch, 0.1, 1.4)
			_update_camera()

		elif panning:
			var pan_amount := distance * pan_sensitivity
			target -= global_transform.basis.x * event.relative.x * pan_amount
			target += global_transform.basis.y * event.relative.y * pan_amount
			_update_camera()

	elif event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_R:
			target = Vector3(0, 1, 0)
			distance = 8.0
			yaw = 0.7
			pitch = 0.55
			_update_camera()


func _update_camera() -> void:
	var horizontal := distance * cos(pitch)

	var offset := Vector3(
		horizontal * sin(yaw),
		distance * sin(pitch),
		horizontal * cos(yaw)
	)

	global_position = target + offset
	look_at(target, Vector3.UP)
