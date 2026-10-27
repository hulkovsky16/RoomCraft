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
	var table := system.spawn_furniture("table", Vector3.ZERO)
	var lamp := system.spawn_on_surface("table_lamp", table.furniture_id, Vector2(-0.3,-0.12))
	var target := table.position + Vector3(-0.09,0.75,0.075)
	check(system._overlaps(system._corners(lamp,lamp.position,0),system._corners(lamp,target,0)), "Reproduces overlapping invisible boxes")
	var second := system.spawn_on_surface("table_lamp", table.furniture_id, Vector2(-0.09,0.09))
	check(second != null, "Separate circular lamps fit despite overlapping boxes")
	check(system.spawn_on_surface("table_lamp", table.furniture_id, Vector2(-0.28,-0.1)) == null, "Actual shade and base penetration still blocked")
	if second != null:
		check(system.rotate_selected(deg_to_rad(17)), "Close lamps can rotate without box obstruction")
	check(scene.set_room_size(6,5), "Resize accepts precise decor arrangement")
	var plant := system.spawn_on_surface("potted_plant", table.furniture_id, Vector2(0.35,0))
	await physics_frame
	await physics_frame
	var gap := plant.position + Vector3(0.14,0,0.14)
	var ray := PhysicsRayQueryParameters3D.create(gap + Vector3(0,1,0),gap - Vector3(0,0.1,0),2)
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.get("collider") == table, "Ray passes between plant details to the actual tabletop")
	ray = PhysicsRayQueryParameters3D.create(plant.position + Vector3(0,0.1,1),plant.position + Vector3(0,0.1,-1),2)
	check(scene.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == plant, "Ray still selects visible pot")
	# Independent oracle: compare narrow-phase GJK to Godot's convex physics queries.
	var types := ["table_lamp","potted_plant","flowers"]
	var offsets := [Vector3.ZERO,Vector3(0.1,0,0.05),Vector3(0.21,0,0.21),Vector3(0.29,0,0),Vector3(0.18,0.1,0.14),Vector3(0.08,0.3,0),Vector3(0,0.8,0),Vector3(0.4,0,0.4)]
	var comparisons := 0
	var mismatches := 0
	for a_type in types:
		for b_type in types:
			var a := system._make_item(a_type)
			var b := system._make_item(b_type)
			a.position = Vector3(0,3,0)
			a.collision_layer = 0
			b.collision_layer = 4
			for index in range(offsets.size()):
				b.position = a.position + offsets[index]
				b.rotation.y = index * 0.37
				await physics_frame
				await physics_frame
				var physics_hit := false
				for part in a.get_children():
					if not part is CollisionShape3D:
						continue
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = part.shape
					query.transform = a.global_transform
					query.collision_mask = 4
					query.margin = 0
					if not scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
						physics_hit = true
						break
				var actual := DecorCollision.overlaps(a,a.position,0,b,b.position,b.rotation.y)
				comparisons += 1
				if actual != physics_hit:
					mismatches += 1
					print("MISMATCH ",a_type," / ",b_type," ",offsets[index]," actual=",actual," physics=",physics_hit)
			a.free()
			b.free()
	check(mismatches == 0, "Narrow phase matches independent physics in %d cases" % comparisons)
	scene.queue_free()
	await process_frame
	print("Failures: ",failures)
	quit(1 if failures else 0)
