extends CanvasLayer
## Interfejs mebli i wykończenia pokoju (uczestnik 3).
## Nazwy węzłów FurnitureDebugUI, FurnitureCatalog, CatalogCategory, RotateLeft i RotateRight
## są używane przez testy, więc nie należy ich zmieniać.

const CATEGORIES := ["Wszystko", "Meble", "Dekoracje", "Kuchnia", "Łazienka", "Okna"]

var thumbnails: Dictionary = {}
var catalog_data: Dictionary = {}
var catalog_list: ItemList
var furniture: FurnitureSystem
var room

var _title_label: Label
var _props_label: Label
var _status_label: Label
var _hints_label: Label
var _wall_picker: ColorPickerButton
var _floor_picker: ColorPickerButton
var _sun_slider: HSlider
var _ambient_slider: HSlider
var _sun: DirectionalLight3D
var _environment: Environment


func _ready() -> void:
	room = get_parent()
	var system: FurnitureSystem = get_parent().get_node("FurnitureRoot")
	furniture = system
	catalog_data = system.get_catalog()
	system.status_changed.connect(_on_status)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_side_panel(root)
	_build_bottom_bar(root)
	_build_hints(root)

	room.room_size_changed.connect(_sync_style_from_room)
	# Кімната ще не готова (її _ready виконується після нашого), тому синхронізуємо відкладено.
	call_deferred("_sync_style_from_room")
	_on_status("Wybierz mebel z katalogu, potem kliknij podłogę")


func _process(_delta: float) -> void:
	_refresh_props()


# ---------- budowa interfejsu ----------

func _build_side_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	UiStyle.style_panel(panel)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -340
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = -110
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	_title_label = _heading("Katalog")
	content.add_child(_title_label)

	var category := OptionButton.new()
	category.name = "CatalogCategory"
	category.focus_mode = Control.FOCUS_NONE
	for entry in CATEGORIES:
		category.add_item(entry)
	category.item_selected.connect(func(index: int) -> void: _populate(category.get_item_text(index)))
	content.add_child(category)

	catalog_list = ItemList.new()
	catalog_list.name = "FurnitureCatalog"
	catalog_list.custom_minimum_size = Vector2(300, 260)
	catalog_list.max_text_lines = 2
	catalog_list.max_columns = 2
	catalog_list.fixed_column_width = 140
	catalog_list.fixed_icon_size = Vector2i(120, 84)
	catalog_list.icon_mode = ItemList.ICON_MODE_TOP
	catalog_list.focus_mode = Control.FOCUS_NONE
	catalog_list.item_clicked.connect(_on_catalog_clicked)
	content.add_child(catalog_list)

	for type_id in catalog_data:
		var thumbnail := FurnitureThumbnail.new()
		add_child(thumbnail)
		thumbnail.setup(type_id, catalog_data[type_id]["size"])
		thumbnails[type_id] = thumbnail.get_texture()
	_title_label.text = "Katalog — %d modeli" % catalog_data.size()
	_populate("Wszystko")

	content.add_child(HSeparator.new())
	content.add_child(_heading("Wybrany przedmiot"))
	_props_label = Label.new()
	_props_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_props_label.custom_minimum_size = Vector2(300, 0)
	content.add_child(_props_label)

	content.add_child(HSeparator.new())
	content.add_child(_heading("Wykończenie"))
	_wall_picker = ColorPickerButton.new()
	_wall_picker.color_changed.connect(_on_wall_color)
	content.add_child(_row("Kolor ścian", _wall_picker))
	_floor_picker = ColorPickerButton.new()
	_floor_picker.color_changed.connect(_on_floor_color)
	content.add_child(_row("Kolor podłogi", _floor_picker))
	_sun_slider = _slider(0.0, 3.0, 0.05)
	_sun_slider.value_changed.connect(_on_sun_changed)
	content.add_child(_row("Światło główne", _sun_slider))
	_ambient_slider = _slider(0.0, 2.0, 0.05)
	_ambient_slider.value_changed.connect(_on_ambient_changed)
	content.add_child(_row("Światło otoczenia", _ambient_slider))


func _build_bottom_bar(root: Control) -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -400
	column.offset_right = 400
	column.offset_top = -100
	column.offset_bottom = -12
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status_label)

	var bar := PanelContainer.new()
	UiStyle.style_panel(bar)
	column.add_child(bar)

	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 6)
	bar.add_child(toolbar)

	toolbar.add_child(_tool_button("Wybierz", "select", "Kliknij mebel, aby go zaznaczyć", _on_select_pressed))
	toolbar.add_child(_tool_button("Przenieś", "move", "Przenieś zaznaczony mebel (G)", _on_move_pressed))
	toolbar.add_child(_rotate_button("Obróć ←", "rotate_left", "RotateLeft", "ui_left", -1.0))
	toolbar.add_child(_rotate_button("Obróć →", "rotate_right", "RotateRight", "ui_right", 1.0))
	toolbar.add_child(_tool_button("Wyrównaj", "align", "Wyrównaj do ścian (F)", _on_align_pressed))
	toolbar.add_child(_tool_button("Usuń", "delete", "Usuń zaznaczony mebel (Delete)", _on_delete_pressed))
	toolbar.add_child(_tool_button("Anuluj", "cancel", "Anuluj ustawianie (Esc)", _on_cancel_pressed))


func _build_hints(root: Control) -> void:
	_hints_label = Label.new()
	_hints_label.text = "WASD — lot  •  Shift — szybciej  •  PgUp/PgDn — góra/dół  •  PPM — obrót kamery  •  ŚPM — przesunięcie  •  Kółko — zoom  •  R — widok pokoju\nKatalog: kliknij miniaturę, potem podłogę  •  G — przenieś  •  Q/E — obrót  •  F — wyrównanie  •  Delete — usuń"
	_hints_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hints_label.offset_left = -280
	_hints_label.offset_right = 280
	_hints_label.offset_top = 12
	_hints_label.visible = MenuState.show_hints
	root.add_child(_hints_label)


func _tool_button(text: String, icon_name: String, tooltip: String, handler: Callable) -> Button:
	var button := UiStyle.make_button(text, icon_name, handler)
	button.tooltip_text = tooltip
	return button


func _rotate_button(text: String, icon_name: String, node_name: String, source: String, direction: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = "Przytrzymaj, aby obracać płynnie"
	UiStyle.style_button(button, icon_name)
	button.button_down.connect(furniture.start_rotation.bind(source, direction))
	button.button_up.connect(furniture.stop_rotation.bind(source))
	button.mouse_exited.connect(furniture.stop_rotation.bind(source))
	return button


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiStyle.ACCENT)
	return label


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	return row


func _slider(min_value: float, max_value: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(130, 0)
	return slider


# ---------- katalog ----------

func _populate(category: String) -> void:
	catalog_list.clear()
	for type_id in catalog_data:
		var data: Dictionary = catalog_data[type_id]
		if category != "Wszystko" and data.get("category", "Meble") != category:
			continue
		var index := catalog_list.add_item(data["name"], thumbnails[type_id])
		catalog_list.set_item_metadata(index, type_id)
		var dimensions: Vector3 = data["size"]
		var placement := "Ściana" if data.get("placement", "floor") == "wall" else "Podłoga"
		if data.get("stackable", false):
			placement = "Podłoga lub dozwolony blat"
		if data.get("surface", false):
			placement += " / blat na dekoracje"
		catalog_list.set_item_tooltip(index, "%s\n%.2f × %.2f × %.2f m\n%s" % [data["name"], dimensions.x, dimensions.y, dimensions.z, placement])


func _on_catalog_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		furniture.begin_placement(catalog_list.get_item_metadata(index))


# ---------- przyciski paska narzędzi ----------

func _on_select_pressed() -> void:
	furniture.cancel_placement()
	_on_status("Tryb wyboru: kliknij mebel, aby go zaznaczyć")


func _on_move_pressed() -> void:
	if _require_selection("Najpierw zaznacz mebel, który chcesz przenieść"):
		furniture.begin_move_selected()


func _on_align_pressed() -> void:
	if not furniture.align_active():
		_show_error("Nie ma czego wyrównać — najpierw zaznacz mebel")


func _on_delete_pressed() -> void:
	if _require_selection("Najpierw zaznacz mebel, który chcesz usunąć"):
		furniture.delete_selected()


func _on_cancel_pressed() -> void:
	furniture.cancel_placement()
	_on_status("Anulowano ustawianie")


func _require_selection(message: String) -> bool:
	if furniture.selected == null:
		_show_error(message)
		return false
	return true


# ---------- panel właściwości ----------

func _refresh_props() -> void:
	var item: FurnitureItem = furniture.preview if furniture.preview != null else furniture.selected
	if item == null:
		_props_label.text = "Nic nie zaznaczono."
		return
	var info: Dictionary = catalog_data.get(item.type_id, {})
	var prefix := "Podgląd: " if item == furniture.preview else ""
	var place := "na podłodze"
	if item.placement == "wall":
		place = "na ścianie"
	if item.support_id != "":
		place = "na meblu"
	var degrees := fposmod(rad_to_deg(item.rotation.y), 360.0)
	_props_label.text = "%s%s\nID: %s\nPołożenie: x %.2f, y %.2f, z %.2f m\nObrót: %.0f°\nUmieszczenie: %s" % [
		prefix,
		info.get("name", item.type_id),
		item.furniture_id.substr(0, 8),
		item.position.x,
		item.position.y,
		item.position.z,
		degrees,
		place,
	]


# ---------- wykończenie pokoju ----------

func _sync_style_from_room() -> void:
	var geometry = room.room_geometry
	if geometry == null:
		return
	_wall_picker.color = geometry.wall_material.albedo_color
	_floor_picker.color = geometry.floor_material.albedo_color
	_sun = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	_environment = world.environment if world != null else null
	if _sun != null:
		_sun_slider.value = _sun.light_energy
	if _environment != null:
		_ambient_slider.value = _environment.ambient_light_energy


func _on_wall_color(color: Color) -> void:
	room.room_geometry.wall_material.albedo_color = color


func _on_floor_color(color: Color) -> void:
	room.room_geometry.floor_material.albedo_color = color


func _on_sun_changed(value: float) -> void:
	if _sun != null:
		_sun.light_energy = value


func _on_ambient_changed(value: float) -> void:
	if _environment != null:
		_environment.ambient_light_energy = value


# ---------- komunikaty ----------

func _on_status(message: String) -> void:
	_status_label.remove_theme_color_override("font_color")
	_status_label.text = message


func _show_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", UiStyle.ERROR_COLOR)
