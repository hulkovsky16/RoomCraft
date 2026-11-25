extends CanvasLayer
## Menu w pokoju: zapis zmian, powrót do menu głównego oraz otwarcie projektu lub nowego projektu z menu.
## Podłączony do węzła InGameMenu w scenes/Room.tscn (węzeł nadrzędny to Room).

const ProjectStore = preload("res://scripts/project_store.gd")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

var room
var _confirm: ConfirmationDialog
var _error: AcceptDialog
var _toast: Label
var _toast_timer: Timer


func _ready() -> void:
	layer = 10
	room = get_parent()
	MenuState.current_project_path = ""
	_build_buttons()
	_build_dialogs()

	if MenuState.pending_new_name != "":
		var new_name := MenuState.pending_new_name
		MenuState.pending_new_name = ""
		# Odłożone, aby pokój zdążył zbudować geometrię przed zapisem.
		call_deferred("_save_to", MenuState.project_path_for(new_name), "Utworzono projekt: %s" % new_name)
	elif MenuState.pending_project_path != "":
		var path := MenuState.pending_project_path
		MenuState.pending_project_path = ""
		call_deferred("_load_project", path)


func _build_buttons() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	column.offset_left = 12
	column.offset_top = -100
	column.offset_right = 200
	column.offset_bottom = -12
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(UiStyle.make_button("Zapisz zmiany", "save", _on_save_pressed))
	column.add_child(UiStyle.make_button("Menu główne", "home", _on_menu_pressed))

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.offset_left = 12
	_toast.offset_top = -130
	_toast.offset_right = 700
	_toast.offset_bottom = -104
	_toast.add_theme_color_override("font_color", UiStyle.ACCENT)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 3.0
	_toast_timer.timeout.connect(func() -> void: _toast.text = "")
	add_child(_toast_timer)


func _build_dialogs() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Menu główne"
	_confirm.dialog_text = "Wrócić do menu głównego? Niezapisane zmiany zostaną utracone."
	_confirm.ok_button_text = "Tak, wróć"
	_confirm.cancel_button_text = "Zostań"
	_confirm.confirmed.connect(_go_to_main_menu)
	add_child(_confirm)

	_error = AcceptDialog.new()
	_error.title = "Błąd"
	add_child(_error)


func _on_save_pressed() -> void:
	_save_to(MenuState.current_project_path, "Zapisano projekt: %s" % _project_name(MenuState.current_project_path))


func _on_menu_pressed() -> void:
	_confirm.popup_centered()


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _load_project(path: String) -> void:
	var result = ProjectStore.load_project(path, room)
	if result.ok:
		MenuState.current_project_path = path
		_show_toast("Wczytano projekt: %s" % _project_name(path))
	else:
		_show_error("Nie udało się wczytać projektu: %s" % str(result.error))


func _save_to(path: String, success_text: String) -> void:
	if path == "":
		_show_error("Nie ma otwartego projektu. Otwórz lub utwórz projekt w menu głównym.")
		return
	var error := ProjectStore.save_project(path, room)
	if error == OK:
		MenuState.current_project_path = path
		_show_toast(success_text)
	else:
		_show_error("Nie udało się zapisać projektu: %s" % error_string(error))


func _project_name(path: String) -> String:
	return path.get_file().get_basename()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_timer.start()


func _show_error(text: String) -> void:
	_error.dialog_text = text
	_error.popup_centered()
