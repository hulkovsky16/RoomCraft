extends SceneTree

var failures := 0


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	var stand := system.spawn_furniture("nightstand", Vector3.ZERO)
	var flowers := system.spawn_on_surface("flowers", stand.furniture_id)
	check(flowers != null, "Flowers fit nightstand by pot footprint")
	check(is_equal_approx(flowers.position.y, 0.5), "Flowers sit exactly on top")
	check(flowers.support_id == stand.furniture_id, "Support relationship recorded")
	check(system.spawn_on_surface("table_lamp", stand.furniture_id) == null, "Decor cannot overlap on same top")
	check(system.spawn_on_surface("chair", stand.furniture_id) == null, "Furniture cannot be stacked")
	check(system.spawn_on_surface("floor_lamp", stand.furniture_id) == null, "Floor lamp cannot be stacked")
	check(system.spawn_on_surface("flowers", flowers.furniture_id) == null, "Decor cannot support another object")
	check(system.spawn_furniture("table_lamp", Vector3(1, 1, 0)) == null, "Unsupported floating position rejected")
	check(system.spawn_furniture("table_lamp", Vector3(1, 1, 0), "missing") == null, "Missing support rejected")
	var original := flowers.position
	check(not system.move_selected(original + Vector3(0.2, 0, 0)), "Pot cannot hang over edge")
	system._select(stand)
	system.delete_selected()
	check(system.get_all_furniture().size() == 2 and system.selected == stand, "Loaded support cannot be deleted")
	check(system.move_selected(Vector3(-1,0,0)), "Move loaded nightstand")
	check(flowers.position.is_equal_approx(original + Vector3(-1,0,0)), "Decor follows moved support")
	system.begin_move_selected()
	check(system.preview_attached.size() == 1, "Moving support previews attached decor")
	check(system.is_placement_valid(system.preview, Vector3(0,0,0), 0, stand), "Preview ignores original group")
	check(system.get_all_furniture().size() == 2, "Attached preview ghosts not persisted")
	system.cancel_placement()
	check(flowers.position.is_equal_approx(original + Vector3(-1,0,0)), "Cancel preserves attached positions")
	var washer := system.spawn_furniture("washing_machine", Vector3(1,0,0))
	system._select(flowers)
	check(system.move_selected(Vector3(1,0.85,-0.015), washer.furniture_id), "Transfer flowers to washing machine")
	check(flowers.support_id == washer.furniture_id, "Transfer changes support reference")
	var record := flowers.to_record()
	check(record["support_id"] == washer.furniture_id and is_equal_approx(record["position"][1],0.85), "Persistence includes support and elevation")
	check(system.move_selected(Vector3(0,0,1)), "Decor can return to floor")
	check(flowers.support_id.is_empty() and is_zero_approx(flowers.position.y), "Floor transfer clears support")
	system.delete_selected()
	system._select(stand)
	system.delete_selected()
	system._select(washer)
	system.delete_selected()
	var table := system.spawn_furniture("table", Vector3.ZERO)
	var lamp := system.spawn_on_surface("table_lamp",table.furniture_id,Vector2(0.4,0))
	check(lamp != null, "Lamp can sit off-center on table")
	var relative := lamp.position - table.position
	system._select(table)
	check(system.rotate_selected(PI/2), "Rotate loaded table")
	check(lamp.position.is_equal_approx(table.position + relative.rotated(Vector3.UP, PI/2)), "Decor rotates around support")
	check(is_equal_approx(lamp.rotation.y, PI/2), "Decor orientation follows support")
	system._select(lamp)
	check(system.rotate_selected(PI/4), "Decor rotates independently on a wide top")
	system.delete_selected()
	system._select(table)
	system.delete_selected()
	stand = system.spawn_furniture("nightstand", Vector3.ZERO)
	flowers = system.spawn_on_surface("flowers",stand.furniture_id)
	var window := system.spawn_window("FrontWall",0,0.65)
	check(window != null, "Window above target support location")
	system._select(stand)
	check(not system.move_selected(Vector3(0,0,-1.7)), "Group move blocked by attached decor hitting window")
	check(stand.position == Vector3.ZERO and flowers.position.y == 0.5, "Failed group move changes nothing")
	system._select(flowers)
	check(system.rotate_selected(PI/4), "Round pot fits narrow top at any rotation")
	system.delete_selected()
	system._select(stand)
	system.delete_selected()
	system._select(window)
	system.delete_selected()
	var cooker := system.spawn_furniture("cooker",Vector3.ZERO)
	check(system.spawn_on_surface("flowers",cooker.furniture_id) == null, "Cooker is not a permitted support")
	system.delete_selected()
	var fridge := system.spawn_furniture("fridge",Vector3.ZERO)
	check(system.spawn_on_surface("table_lamp",fridge.furniture_id) != null, "Suitable tall top accepts small decor")
	# Above-ceiling poses are rejected even with a valid support ID.
	check(system.spawn_furniture("flowers",Vector3(0,2.2,0),fridge.furniture_id) == null, "Incorrect height rejected")
	scene.queue_free()
	await process_frame
	print("Failures: ",failures)
	quit(1 if failures else 0)
