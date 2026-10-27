extends "res://tests/surface_interaction_test.gd"


func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.gui_disable_input = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/Room.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	var system: FurnitureSystem = scene.get_node("FurnitureRoot")
	var camera = scene.get_node("Camera3D")
	camera.distance = 3.7
	camera.target = Vector3(0,0.7,0)
	camera.pitch = 0.85
	camera._update_camera()
	var table := system.spawn_furniture("table",Vector3.ZERO)
	system.spawn_on_surface("table_lamp",table.furniture_id,Vector2(-0.3,-0.12))
	system.spawn_on_surface("potted_plant",table.furniture_id,Vector2(0.35,-0.05))
	await physics_frame
	await physics_frame
	system.begin_placement("table_lamp")
	await point_at(camera.unproject_position(Vector3(-0.09,0.75,0.075)))
	check(system.candidate_valid, "Mouse placement accepts visible space between decorations")
	check(system.preview.support_id == table.furniture_id, "Ray selects real tabletop rather than empty collision box")
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("user://RoomCraft-precise-decor.png")
	click()
	check(system.get_all_furniture().size() == 4, "Click commits close decoration")
	await physics_frame
	await physics_frame
	system.begin_placement("table_lamp")
	await point_at(camera.unproject_position(Vector3(-0.3,1.2,-0.135)))
	check(not system.candidate_valid, "Hovering on actual occupied lamp remains invalid")
	system.cancel_placement()
	print("Failures: ",failures)
	quit(1 if failures else 0)
