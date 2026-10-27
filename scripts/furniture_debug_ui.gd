extends CanvasLayer

var thumbnails: Dictionary = {}
var catalog_data: Dictionary = {}
var catalog_list: ItemList
var furniture: FurnitureSystem
var angle_label: Label


func _ready() -> void:
	var system: FurnitureSystem = get_parent().get_node("FurnitureRoot")
	furniture = system
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -320
	panel.offset_right = -12
	panel.offset_top = 12
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "Katalog — %d modeli" % system.get_catalog().size()
	content.add_child(title)
	var catalog := system.get_catalog()
	catalog_data = catalog
	var categories := OptionButton.new()
	categories.name = "CatalogCategory"
	categories.focus_mode = Control.FOCUS_NONE
	for category in ["Wszystko", "Meble", "Dekoracje", "Kuchnia", "Łazienka", "Okna"]:
		categories.add_item(category)
	content.add_child(categories)
	var list := ItemList.new()
	list.name = "FurnitureCatalog"
	list.custom_minimum_size = Vector2(300, 260)
	catalog_list = list
	list.max_text_lines = 2
	list.max_columns = 2
	list.fixed_column_width = 140
	list.fixed_icon_size = Vector2i(120, 84)
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.focus_mode = Control.FOCUS_NONE
	content.add_child(list)
	for type_id in catalog:
		var thumbnail := FurnitureThumbnail.new()
		add_child(thumbnail)
		thumbnail.setup(type_id, catalog[type_id]["size"])
		thumbnails[type_id] = thumbnail.get_texture()
	_populate("Wszystko")
	categories.item_selected.connect(func(index): _populate(categories.get_item_text(index)))
	list.item_clicked.connect(func(index, _at, button):
		if button == MOUSE_BUTTON_LEFT:
			system.begin_placement(list.get_item_metadata(index)))
	for entry in [["Przenieś (G)", system.begin_move_selected], ["Obróć w lewo (Q)", system.rotate_active.bind(deg_to_rad(-15))], ["Obróć w prawo (E)", system.rotate_active.bind(deg_to_rad(15))], ["Wyrównaj do ścian (F)", system.align_active], ["Usuń (Delete)", system.delete_selected], ["Anuluj (Esc)", system.cancel_placement]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		if entry[0].begins_with("Obróć"):
			var direction := -1.0 if entry[0].contains("lewo") else 1.0
			var source := "ui_left" if direction < 0 else "ui_right"
			button.name = "RotateLeft" if direction < 0 else "RotateRight"
			button.button_down.connect(system.start_rotation.bind(source, direction))
			button.button_up.connect(system.stop_rotation.bind(source))
			button.mouse_exited.connect(system.stop_rotation.bind(source))
		else:
			button.pressed.connect(entry[1])
		content.add_child(button)
	var selection := Label.new()
	selection.text = "Wybrano: —"
	selection.custom_minimum_size.x = 300
	selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(selection)
	system.selection_changed.connect(func(item): selection.text = "Wybrano: " + (catalog[item.type_id]["name"] if item != null else "—"))
	angle_label = Label.new()
	content.add_child(angle_label)
	var status := Label.new()
	status.text = "Wybierz mebel z katalogu, potem kliknij podłogę"
	status.custom_minimum_size.x = 300
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	system.status_changed.connect(func(message): status.text = message)
	var help := Label.new()
	help.text = "WASD — lot; Shift — szybciej\nPgUp / PgDn — góra / dół\nPPM — obrót; R — widok pokoju\nKółko — zoom; ŚPM — ruch\nQ/E — obrót; F — wyrównanie"
	content.add_child(help)


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
		catalog_list.set_item_tooltip(index, "%s\n%.2f × %.2f × %.2f m\n%s" % [data["name"], dimensions.x, dimensions.y, dimensions.z, placement])


func _process(_delta: float) -> void:
	if angle_label == null:
		return
	var item := furniture.preview if furniture.preview != null else furniture.selected
	angle_label.text = "Kąt: %.1f°" % fposmod(rad_to_deg(item.rotation.y), 360.0) if item != null else "Kąt: —"
