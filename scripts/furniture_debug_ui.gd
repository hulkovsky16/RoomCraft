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
	title.text = "Meble — prototyp"
	content.add_child(title)
	for entry in [["Dodaj stół (T)", system.begin_placement.bind("table")], ["Przenieś (G)", system.begin_move_selected], ["Obróć w lewo (Q)", system.rotate_active.bind(deg_to_rad(-15))], ["Obróć w prawo (E)", system.rotate_active.bind(deg_to_rad(15))], ["Usuń (Delete)", system.delete_selected], ["Anuluj (Esc)", system.cancel_placement]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		content.add_child(button)
	var selection := Label.new()
	selection.text = "Wybrano: —"
	content.add_child(selection)
	system.selection_changed.connect(func(item): selection.text = "Wybrano: " + ("Stół" if item != null else "—"))
	var status := Label.new()
	status.text = "Dodaj stół, potem kliknij podłogę"
	status.custom_minimum_size.x = 300
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	system.status_changed.connect(func(message): status.text = message)
	var help := Label.new()
	help.text = "Kamera: PPM — obrót, ŚPM — ruch\nKółko — zoom; R — reset\nMeble: LPM — wybór / zatwierdzenie"
	content.add_child(help)
