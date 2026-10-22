
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


func _on_apply_pressed() -> void:
	if room_controller == null:
		status_label.text = "Помилка: кімнату не знайдено"
		return

	var success: bool = room_controller.set_room_size(
		width_input.value,
		length_input.value
	)

	if success:
		status_label.text = "Розміри оновлено!"
	else:
		status_label.text = "Некоректні розміри кімнати"
