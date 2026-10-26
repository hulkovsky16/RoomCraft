
extends Control

@onready var width_input: SpinBox = $SettingsPanel/Content/WidthInput
@onready var length_input: SpinBox = $SettingsPanel/Content/LengthInput
@onready var status_label: Label = $SettingsPanel/Content/StatusLabel
@onready var apply_button: Button = $SettingsPanel/Content/ApplyButton

var room_controller: Node


func _ready() -> void:
	width_input.min_value = 3.0
	width_input.max_value = 10.0
	width_input.step = 0.5
	width_input.value = 5.0

	length_input.min_value = 3.0
	length_input.max_value = 10.0
	length_input.step = 0.5
	length_input.value = 4.0

	var current: Node = get_parent()

	while current != null:
		if current.has_method("set_room_size"):
			room_controller = current
			break
		current = current.get_parent()

	apply_button.pressed.connect(_on_apply_pressed)
	# Keep focus changes from committing one field after the room signal resets it.
	apply_button.focus_mode = Control.FOCUS_NONE
	if room_controller != null:
		room_controller.room_size_changed.connect(_sync_room_size)


func _sync_room_size(width: float, length: float) -> void:
	width_input.value = width
	length_input.value = length


func _on_apply_pressed() -> void:
	if room_controller == null:
		status_label.text = "Помилка: кімнату не знайдено"
		return
	# SpinBox text and its numeric value can differ until editing is committed.
	# Commit both before set_room_size emits the signal that rewrites the fields.
	width_input.apply()
	length_input.apply()

	var success: bool = room_controller.set_room_size(
		width_input.value,
		length_input.value
	)

	if success:
		status_label.text = "Wymiary zaktualizowane"
	else:
		status_label.text = "Brak miejsca dla mebli lub okien"
		var dimensions: Vector2 = room_controller.get_room_size()
		_sync_room_size(dimensions.x, dimensions.y)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
