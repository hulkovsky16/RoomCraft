extends LineEdit


func _ready() -> void:
	virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	text_changed.connect(_filter_text)


func _filter_text(_raw: String) -> void:
	var raw := text
	var clean := ""
	var separator := false
	var new_caret := 0
	for i in range(raw.length()):
		var character := raw[i]
		var allowed := character >= "0" and character <= "9"
		if character in [".", ","] and not separator:
			allowed = true
			separator = true
		if allowed:
			clean += character
			if i < caret_column:
				new_caret += 1
	if clean != raw:
		text = clean
		caret_column = new_caret


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.unicode > 0:
		if event.ctrl_pressed or event.meta_pressed:
			return
		var character := String.chr(event.unicode)
		if not ((character >= "0" and character <= "9") or character in [".", ","]):
			accept_event()
		elif character in [".", ","]:
			var remaining := text
			if has_selection():
				remaining = text.substr(0, get_selection_from_column()) + text.substr(get_selection_to_column())
			if remaining.contains(".") or remaining.contains(","):
				accept_event()


func read_value() -> float:
	for character in text:
		if not ((character >= "0" and character <= "9") or character in [".", ","]):
			return NAN
	var normalized := text.replace(",", ".")
	if not normalized.is_valid_float():
		return NAN
	return normalized.to_float()
