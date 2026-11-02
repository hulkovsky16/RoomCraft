extends RefCounted

static func save_project(path: String, room: Node) -> Error:
	var temporary := path + ".tmp-" + ResourceUID.id_to_text(ResourceUID.create_id()).trim_prefix("uid://")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(JSON.stringify(room.get_project_state(), "\t", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	if not written:
		error = ERR_FILE_CANT_WRITE
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func load_project(path: String, room: Node) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": error_string(FileAccess.get_open_error())}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"ok": false, "error": "Nieprawidłowy JSON, wiersz %d" % json.get_error_line()}
	var data: Variant = json.data
	if not data is Dictionary or not _number(data.get("version")) or data.version != 1:
		return {"ok": false, "error": "Nieobsługiwana wersja projektu"}
	var settings: Variant = data.get("room")
	if not settings is Dictionary or not data.get("furniture") is Array:
		return {"ok": false, "error": "Brak danych pokoju lub mebli"}
	for key in ["width", "length"]:
		var value: Variant = settings.get(key)
		if not _number(value) or value < RoomGeometry.MIN_ROOM_SIZE or value > RoomGeometry.MAX_ROOM_SIZE:
			return {"ok": false, "error": "Nieprawidłowe wymiary pokoju"}
	for key in ["wall_color", "floor_color"]:
		var channels: Variant = settings.get(key)
		if not channels is Array or channels.size() != 4:
			return {"ok": false, "error": "Nieprawidłowy kolor"}
		for channel in channels:
			if not _number(channel) or channel < 0 or channel > 1:
				return {"ok": false, "error": "Nieprawidłowy kolor"}
	return room.restore_project_room(Vector2(settings.width, settings.length),
		_color(settings.wall_color), _color(settings.floor_color), data.furniture)


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _color(channels: Array) -> Color:
	return Color(channels[0], channels[1], channels[2], channels[3])
