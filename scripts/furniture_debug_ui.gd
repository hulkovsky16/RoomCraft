extends CanvasLayer


func _ready() -> void:
	var system: FurnitureSystem = get_parent().get_node("FurnitureRoot")
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -320
	panel.offset_right = -12
	panel.offset_top = 12
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "Katalog mebli — 10 modeli"
	content.add_child(title)
	var catalog := system.get_catalog()
	var type_ids: Array = catalog.keys()
	var list := ItemList.new()
	list.name = "FurnitureCatalog"
	list.custom_minimum_size = Vector2(300, 300)
	list.max_columns = 2
	list.fixed_column_width = 140
	list.fixed_icon_size = Vector2i(120, 84)
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.focus_mode = Control.FOCUS_NONE
	content.add_child(list)
	for type_id in type_ids:
		var thumbnail := FurnitureThumbnail.new()
		add_child(thumbnail)
		thumbnail.setup(type_id, catalog[type_id]["size"])
		var index := list.add_item(catalog[type_id]["name"], thumbnail.get_texture())
		var dimensions: Vector3 = catalog[type_id]["size"]
		list.set_item_tooltip(index, "%s\n%.2f × %.2f × %.2f m (szer. × wys. × gł.)" % [catalog[type_id]["name"], dimensions.x, dimensions.y, dimensions.z])
	# item_clicked also fires when adding the same type again.
	list.item_clicked.connect(func(index, _at, button):
		if button == MOUSE_BUTTON_LEFT:
			system.begin_placement(type_ids[index]))
	for entry in [["Przenieś (G)", system.begin_move_selected], ["Obróć w lewo (Q)", system.rotate_active.bind(deg_to_rad(-15))], ["Obróć w prawo (E)", system.rotate_active.bind(deg_to_rad(15))], ["Usuń (Delete)", system.delete_selected], ["Anuluj (Esc)", system.cancel_placement]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		content.add_child(button)
	var selection := Label.new()
	selection.text = "Wybrano: —"
	content.add_child(selection)
	system.selection_changed.connect(func(item): selection.text = "Wybrano: " + (catalog[item.type_id]["name"] if item != null else "—"))
	var status := Label.new()
	status.text = "Wybierz mebel z katalogu, potem kliknij podłogę"
	status.custom_minimum_size.x = 300
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	system.status_changed.connect(func(message): status.text = message)
	var help := Label.new()
	help.text = "Kamera: PPM — obrót, ŚPM — ruch\nKółko — zoom; R — reset\nMeble: LPM — wybór / zatwierdzenie"
	content.add_child(help)
