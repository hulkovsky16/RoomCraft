extends Control
## Główne menu RoomCraft: nowy projekt z nazwą, wczytanie zapisanego projektu, ustawienia i wyjście.
## Wybór projektu przechodzi do scenes/Room.tscn.

const ROOM_SCENE := "res://scenes/Room.tscn"

var _main_panel: VBoxContainer
var _new_panel: VBoxContainer
var _projects_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _project_list: VBoxContainer
var _name_edit: LineEdit
var _name_error: Label
var _status_label: Label
var _fullscreen_check: CheckBox
var _hints_check: CheckBox
var _file_dialog: FileDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuState.ensure_projects_dir()

	var background := ColorRect.new()
	background.color = Color(0.1, 0.12, 0.15)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	UiStyle.style_panel(panel)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title := Label.new()
	title.text = "RoomCraft"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiStyle.ACCENT)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Projektowanie pokoju w 3D"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	_build_main_panel(content)
	_build_new_panel(content)
	_build_projects_panel(content)
	_build_settings_panel(content)
	_build_file_dialog()
	_show_panel(_main_panel)


func _build_main_panel(parent: Control) -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 8)
	parent.add_child(_main_panel)

	_main_panel.add_child(UiStyle.make_button("Nowy projekt", "new", _on_new_project_pressed))
	_main_panel.add_child(UiStyle.make_button("Wczytaj projekt", "open", _on_load_projects_pressed))
	_main_panel.add_child(UiStyle.make_button("Ustawienia", "settings", _on_settings_pressed))
	_main_panel.add_child(UiStyle.make_button("Wyjdź", "exit", _on_quit))

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(340, 0)
	_status_label.add_theme_color_override("font_color", UiStyle.ERROR_COLOR)
	_main_panel.add_child(_status_label)


func _build_new_panel(parent: Control) -> void:
	_new_panel = VBoxContainer.new()
	_new_panel.add_theme_constant_override("separation", 8)
	_new_panel.visible = false
	parent.add_child(_new_panel)

	_new_panel.add_child(_header("Nowy projekt"))

	var hint := Label.new()
	hint.text = "Podaj nazwę projektu:"
	_new_panel.add_child(hint)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Mój pokój"
	_name_edit.max_length = MenuState.MAX_NAME_LENGTH
	_name_edit.custom_minimum_size = Vector2(340, 0)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_new_confirmed())
	_new_panel.add_child(_name_edit)

	_name_error = Label.new()
	_name_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_error.custom_minimum_size = Vector2(340, 0)
	_name_error.add_theme_color_override("font_color", UiStyle.ERROR_COLOR)
	_new_panel.add_child(_name_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_new_panel.add_child(buttons)
	var create := UiStyle.make_button("Utwórz", "new", _on_new_confirmed)
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(create)
	var cancel := UiStyle.make_button("Anuluj", "", _show_panel.bind(_main_panel))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel)


func _build_projects_panel(parent: Control) -> void:
	_projects_panel = VBoxContainer.new()
	_projects_panel.add_theme_constant_override("separation", 8)
	_projects_panel.visible = false
	parent.add_child(_projects_panel)

	_projects_panel.add_child(_header("Wczytaj projekt"))
	var folder := ProjectSettings.globalize_path(MenuState.PROJECTS_DIR)
	var location := Label.new()
	location.text = "Folder zapisu: " + folder
	location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location.custom_minimum_size.x = 340
	_projects_panel.add_child(location)
	_projects_panel.add_child(UiStyle.make_button("Otwórz folder projektów", "open", func() -> void:
		OS.shell_open(folder)))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_projects_panel.add_child(scroll)

	_project_list = VBoxContainer.new()
	_project_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_project_list)

	_projects_panel.add_child(UiStyle.make_button("Wybierz plik na dysku…", "open", _on_pick_file_pressed))
	_projects_panel.add_child(UiStyle.make_button("Wstecz", "", _show_panel.bind(_main_panel)))


func _build_settings_panel(parent: Control) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 10)
	_settings_panel.visible = false
	parent.add_child(_settings_panel)

	_settings_panel.add_child(_header("Ustawienia"))

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Pełny ekran"
	_fullscreen_check.focus_mode = Control.FOCUS_NONE
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_settings_panel.add_child(_fullscreen_check)

	_hints_check = CheckBox.new()
	_hints_check.text = "Pokazuj podpowiedzi sterowania"
	_hints_check.focus_mode = Control.FOCUS_NONE
	_hints_check.button_pressed = MenuState.show_hints
	_hints_check.toggled.connect(_on_hints_toggled)
	_settings_panel.add_child(_hints_check)

	_settings_panel.add_child(UiStyle.make_button("Wstecz", "", _show_panel.bind(_main_panel)))


func _build_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = "Wczytaj projekt z pliku"
	_file_dialog.filters = PackedStringArray(["*.json ; Projekt RoomCraft"])
	_file_dialog.file_selected.connect(_open_project)
	add_child(_file_dialog)


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", UiStyle.ACCENT)
	return label


func _show_panel(panel: Control) -> void:
	_status_label.text = ""
	_main_panel.visible = panel == _main_panel
	_new_panel.visible = panel == _new_panel
	_projects_panel.visible = panel == _projects_panel
	_settings_panel.visible = panel == _settings_panel


# ---------- nowy projekt ----------

func _on_new_project_pressed() -> void:
	_name_edit.text = ""
	_name_error.text = ""
	_show_panel(_new_panel)
	_name_edit.grab_focus()


func _on_new_confirmed() -> void:
	var project_name := _name_edit.text.strip_edges()
	var problem := MenuState.check_project_name(project_name)
	if problem != "":
		_name_error.text = problem
		return
	MenuState.pending_project_path = ""
	MenuState.pending_new_name = project_name
	_open_room()


# ---------- wczytywanie ----------

func _on_load_projects_pressed() -> void:
	_refresh_project_list()
	_show_panel(_projects_panel)


func _refresh_project_list() -> void:
	for child in _project_list.get_children():
		_project_list.remove_child(child)
		child.queue_free()
	var paths := MenuState.list_projects()
	if paths.is_empty():
		var empty := Label.new()
		empty.text = "Brak zapisanych projektów. Utwórz nowy projekt."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_project_list.add_child(empty)
		return
	for path in paths:
		var project_name := path.get_file().get_basename()
		var button := UiStyle.make_button(project_name, "open", _open_project.bind(path))
		button.tooltip_text = ProjectSettings.globalize_path(path)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_project_list.add_child(button)


func _on_pick_file_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.75)


func _open_project(path: String) -> void:
	MenuState.pending_new_name = ""
	MenuState.pending_project_path = path
	_open_room()


func _open_room() -> void:
	var error := get_tree().change_scene_to_file(ROOM_SCENE)
	if error != OK:
		_show_panel(_main_panel)
		_status_label.text = "Nie udało się otworzyć pokoju (kod %d)" % error


# ---------- ustawienia i wyjście ----------

func _on_settings_pressed() -> void:
	_show_panel(_settings_panel)


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_hints_toggled(on: bool) -> void:
	MenuState.show_hints = on


func _on_quit() -> void:
	get_tree().quit()
