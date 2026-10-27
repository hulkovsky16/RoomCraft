extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	var table := system.spawn_furniture("table", Vector3.ZERO, "", 0.3)
	system.spawn_on_surface("table_lamp", table.furniture_id, Vector2(0.3, 0))
	system.spawn_window("FrontWall", 0)
	var records := system.get_all_furniture()
	var decoded: Array = JSON.parse_string(JSON.stringify(records))
	decoded.reverse()
	check(system.restore_furniture(decoded).ok, "JSON round trip, child before support")
	for record in records:
		var item := system._find_item(record.id)
		check(item != null and item.to_record() == record, "Preserve ID, pose, placement and support")
	check(scene.room_geometry.window_openings.size() == 1, "Window opening restored")
	system._select(system._find_item(table.furniture_id))
	system.begin_move_selected()
	var selected := system.selected
	var preview := system.preview
	var before := system.get_all_furniture()
	var bad_inputs: Array = [null, {}, [null], [{}]]
	var invalid := decoded.duplicate(true)
	invalid.append(invalid[0].duplicate(true))
	bad_inputs.append(invalid)
	for field in ["id", "type_id", "position", "rotation_y", "placement", "wall_id", "support_id"]:
		invalid = decoded.duplicate(true)
		invalid[0][field] = false
		bad_inputs.append(invalid)
	for value in [NAN, INF, "0.2"]:
		invalid = decoded.duplicate(true)
		invalid[0].rotation_y = value
		bad_inputs.append(invalid)
	for change in [{"type_id": "missing"}, {"position": [100, 0, 0]}, {"position": [0, NAN, 0]}, {"support_id": "missing"}]:
		invalid = records.duplicate(true)
		invalid[1].merge(change, true)
		bad_inputs.append(invalid)
	invalid = records.duplicate(true)
	invalid[0].support_id = invalid[1].id
	bad_inputs.append(invalid)
	invalid = records.duplicate(true)
	var duplicate: Dictionary = invalid[0].duplicate(true)
	duplicate.id = "overlapping-copy"
	invalid.append(duplicate)
	bad_inputs.append(invalid)
	for i in range(bad_inputs.size()):
		check(not system.restore_furniture(bad_inputs[i]).ok, "Reject invalid data %d" % i)
		check(system.get_all_furniture() == before and system.selected == selected and system.preview == preview, "Failure is atomic %d" % i)
	check(system.restore_furniture([]).ok, "Empty layout clears furniture")
	check(system.get_all_furniture().is_empty() and system.preview == null and system.selected == null, "Clear also cancels editing")
	check(scene.room_geometry.window_openings.is_empty(), "Clear restores solid walls")
	var legacy: Dictionary = records[0].duplicate(true)
	for field in ["placement", "wall_id", "support_id"]:
		legacy.erase(field)
	check(system.restore_furniture([legacy]).ok, "Legacy floor records supported")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
