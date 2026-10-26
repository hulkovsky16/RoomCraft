extends SubViewport
class_name FurnitureThumbnail


func setup(type_id: String, dimensions: Vector3) -> void:
	size = Vector2i(144, 100)
	own_world_3d = true
	transparent_bg = true
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	var item := FurnitureItem.new()
	item.type_id = type_id
	item.size = dimensions
	add_child(item)
	item.collision_layer = 0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(dimensions.y, Vector2(dimensions.x, dimensions.z).length()) * 1.45
	add_child(camera)
	var center := Vector3(0, dimensions.y / 2, 0)
	camera.position = center + Vector3(3, 2.2, 4)
	camera.look_at(center)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	world_environment.environment = environment
	add_child(world_environment)
