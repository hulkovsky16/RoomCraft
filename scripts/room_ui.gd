
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
	if not is_finite(width) or not is_finite(length) or width < 3 or width > 10 or length < 3 or length > 10:
		status_label.text = "Podaj liczby od 3 do 10 m (np. 5,5)"
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
