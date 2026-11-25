
extends Control

@onready var width_input: LineEdit = $SettingsPanel/Content/WidthInput
@onready var length_input: LineEdit = $SettingsPanel/Content/LengthInput
@onready var status_label: Label = $SettingsPanel/Content/StatusLabel
@onready var apply_button: Button = $SettingsPanel/Content/ApplyButton

var room_controller: Node


func _ready() -> void:
	var current: Node = get_parent()

	while current != null:
		if current.has_method("set_room_size"):
			room_controller = current
			break
		current = current.get_parent()

	var camera: Camera3D = room_controller.get_node("Camera3D")
	var sensitivity_label := Label.new()
	sensitivity_label.text = "Czułość kamery: 1.00×"
	$SettingsPanel/Content.add_child(sensitivity_label)
	var sensitivity := HSlider.new()
	sensitivity.name = "CameraSensitivity"
	sensitivity.min_value = 0.25
	sensitivity.max_value = 3.0
	sensitivity.step = 0.05
	sensitivity.value = 1.0
	sensitivity.focus_mode = Control.FOCUS_NONE
	sensitivity.tooltip_text = "Szybkość obrotu kamery myszą"
	$SettingsPanel/Content.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value):
		camera.rotation_sensitivity = 0.008 * value
		sensitivity_label.text = "Czułość kamery: %.2f×" % value)
	apply_button.pressed.connect(_on_apply_pressed)
	width_input.text_submitted.connect(func(_text): _on_apply_pressed())
	length_input.text_submitted.connect(func(_text): _on_apply_pressed())
	apply_button.focus_mode = Control.FOCUS_NONE
	if room_controller != null:
		room_controller.room_size_changed.connect(_sync_room_size)


func _sync_room_size(width: float, length: float) -> void:
	width_input.text = String.num(width, 3)
	length_input.text = String.num(length, 3)


func _on_apply_pressed() -> void:
	if room_controller == null:
		status_label.text = "Помилка: кімнату не знайдено"
		return
	var width: float = width_input.read_value()
	var length: float = length_input.read_value()
	if not is_finite(width) or not is_finite(length) or width < RoomGeometry.MIN_ROOM_SIZE or width > RoomGeometry.MAX_ROOM_SIZE or length < RoomGeometry.MIN_ROOM_SIZE or length > RoomGeometry.MAX_ROOM_SIZE:
		status_label.text = "Podaj liczby od 2 do 30 m (np. 5,5)"
		return
	var success: bool = room_controller.set_room_size(width, length)

	if success:
		status_label.text = "Wymiary zaktualizowane"
	else:
		status_label.text = "Brak miejsca dla mebli lub okien"
		var dimensions: Vector2 = room_controller.get_room_size()
		_sync_room_size(dimensions.x, dimensions.y)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
