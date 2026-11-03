extends SceneTree

const Store = preload("res://scripts/project_store.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "user://roomcraft-test-%d.json" % OS.get_process_id()
	var room = load("res://scenes/Room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.set_room_size(8, 6)
	room.room_geometry.wall_material.albedo_color = Color.CORAL
	var furniture: FurnitureSystem = room.get_node("FurnitureRoot")
	var table := furniture.spawn_furniture("table", Vector3(3, 0, 0))
	check(table != null, "Place table outside default room bounds")
	if table == null:
		quit(1)
		return
	furniture.spawn_on_surface("table_lamp", table.furniture_id, Vector2(0.3, 0))
	furniture.spawn_window("FrontWall", 0)
	var expected: Dictionary = room.get_project_state()
	check(expected.furniture.size() == 3, "Place supported decor and a window")
	check(Store.save_project(path, room) == OK, "Save scene")
	check(Store.save_project(path, room) == OK, "Overwrite existing project")
	room.free()
	room = load("res://scenes/Room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	check(Store.load_project(path, room).ok, "Load into fresh scene")
	check(room.get_project_state() == expected, "Recover dimensions, appearance, IDs and placement")
	var invalid := expected.duplicate(true)
	invalid.room.width = 3
	invalid.room.wall_color = [0, 1, 0, 1]
	for contents in [JSON.stringify(invalid), "{", "{}", "null"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(contents)
		file.close()
		check(not Store.load_project(path, room).ok, "Reject invalid project")
		check(room.get_project_state() == expected, "Keep original scene")
	DirAccess.remove_absolute(path)
	check(not Store.load_project(path, room).ok, "Missing file")
	room.free()
	quit(1 if failures else 0)
