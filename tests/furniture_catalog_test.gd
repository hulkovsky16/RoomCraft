extends SceneTree

var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	var catalog := system.get_catalog()
	check(catalog.size() == 10, "Ten catalog entries")
	for type_id in catalog:
		var item := system.spawn_furniture(type_id, Vector3.ZERO)
		check(item != null, type_id + ": spawn")
		if item == null:
			continue
		var bounds := AABB(Vector3(-item.size.x / 2, 0, -item.size.z / 2), item.size).grow(0.001)
		var fits := true
		for visual in item.surfaces:
			var actual := visual.transform * visual.get_aabb()
			fits = fits and bounds.encloses(actual)
		check(fits, type_id + ": visible model fits collision bounds")
		check(system.rotate_selected(PI / 4), type_id + ": rotation")
		check(system.move_selected(Vector3(0.1, 0, 0.1)), type_id + ": move")
		check(system.spawn_furniture(type_id, Vector3.ZERO) == null, type_id + ": overlapping duplicate rejected")
		check(not system.move_selected(Vector3(2.45, 0, 0)), type_id + ": wall rejected")
		check(system.get_all_furniture()[0]["type_id"] == type_id, type_id + ": persistence type")
		var surface_material: Material = item.original_materials[0]
		item.set_highlight("invalid")
		item.set_highlight("")
		check(item.surfaces[0].material_overlay == null and item.surfaces[0].material_override == surface_material, type_id + ": original material restored")
		system.begin_move_selected()
		check(system.preview.type_id == type_id and system.preview.size == item.size, type_id + ": matching move preview")
		system.cancel_placement()
		system.delete_selected()
		check(system.get_all_furniture().is_empty(), type_id + ": delete")
	var original_name: String = system.get_catalog()["table"]["name"]
	catalog["table"]["name"] = "modified"
	check(system.get_catalog()["table"]["name"] == original_name, "Catalog returned by copy")
	scene.queue_free()
	await process_frame
	print("Failures: ", failures)
	quit(1 if failures else 0)
