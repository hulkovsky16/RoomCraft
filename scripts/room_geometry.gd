
extends Node3D
class_name RoomGeometry

const WALL_HEIGHT: float = 2.7
const WALL_THICKNESS: float = 0.1
const FLOOR_THICKNESS: float = 0.1

var room_width: float = 5.0
var room_length: float = 4.0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D


func _process(_delta: float) -> void:
	# Cutaway view: hide only walls between the camera and the interior.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var local_camera := to_local(camera.global_position)
	for wall_name in ["LeftWall", "RightWall", "FrontWall", "BackWall"]:
		var wall := get_node_or_null(NodePath(wall_name)) as Node3D
		if wall == null:
			continue
		match wall_name:
			"LeftWall": wall.visible = local_camera.x >= -room_width / 2
			"RightWall": wall.visible = local_camera.x <= room_width / 2
			"FrontWall": wall.visible = local_camera.z >= -room_length / 2
			"BackWall": wall.visible = local_camera.z <= room_length / 2


func _ready() -> void:
	_create_materials()
	rebuild(room_width, room_length)


func _create_materials() -> void:
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.68, 0.59, 0.46)
	floor_material.roughness = 0.85

	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.88, 0.87, 0.83)
	wall_material.roughness = 0.9
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func rebuild(width: float, length: float) -> void:
	if width < 3.0 or width > 10.0:
		push_error("Width must be between 3 and 10 meters.")
		return

	if length < 3.0 or length > 10.0:
		push_error("Length must be between 3 and 10 meters.")
		return

	room_width = width
	room_length = length

	for child in get_children():
		remove_child(child)
		child.queue_free()

	_create_box(
		"Floor",
		Vector3(room_width, FLOOR_THICKNESS, room_length),
		Vector3(0, -FLOOR_THICKNESS / 2.0, 0),
		floor_material
	)

	var half_width := room_width / 2.0
	var half_length := room_length / 2.0

	_create_box(
		"LeftWall",
		Vector3(WALL_THICKNESS, WALL_HEIGHT, room_length),
		Vector3(-half_width, WALL_HEIGHT / 2.0, 0),
		wall_material
	)

	_create_box(
		"RightWall",
		Vector3(WALL_THICKNESS, WALL_HEIGHT, room_length),
		Vector3(half_width, WALL_HEIGHT / 2.0, 0),
		wall_material
	)

	_create_box(
		"FrontWall",
		Vector3(room_width, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(0, WALL_HEIGHT / 2.0, -half_length),
		wall_material
	)

	_create_box(
		"BackWall",
		Vector3(room_width, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(0, WALL_HEIGHT / 2.0, half_length),
		wall_material
	)


func _create_box(
	object_name: String,
	box_size: Vector3,
	box_position: Vector3,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = object_name
	body.position = box_position
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)


func get_room_size() -> Vector2:
	return Vector2(room_width, room_length)


func get_floor_bounds() -> Dictionary:
	return {
		"min": Vector2(-room_width / 2.0, -room_length / 2.0),
		"max": Vector2(room_width / 2.0, room_length / 2.0)
	}
