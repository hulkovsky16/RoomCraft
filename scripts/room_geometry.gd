
extends Node3D
class_name RoomGeometry

const MIN_ROOM_SIZE := 2.0
const MAX_ROOM_SIZE := 30.0

const WALL_HEIGHT: float = 2.7
const WALL_THICKNESS: float = 0.1
const FLOOR_THICKNESS: float = 0.1

var room_width: float = 5.0
var room_length: float = 4.0

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var window_openings: Array[Dictionary] = []


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
	if width < MIN_ROOM_SIZE or width > MAX_ROOM_SIZE:
		push_error("Width must be between 2 and 30 meters.")
		return

	if length < MIN_ROOM_SIZE or length > MAX_ROOM_SIZE:
		push_error("Length must be between 2 and 30 meters.")
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

	_build_wall("FrontWall", room_width, Vector3(0, 0, -room_length / 2), 0)
	_build_wall("BackWall", room_width, Vector3(0, 0, room_length / 2), PI)
	_build_wall("LeftWall", room_length, Vector3(-room_width / 2, 0, 0), PI / 2)
	_build_wall("RightWall", room_length, Vector3(room_width / 2, 0, 0), -PI / 2)


func set_window_openings(openings: Array[Dictionary]) -> void:
	if window_openings == openings:
		return
	window_openings = openings.duplicate(true)
	rebuild(room_width, room_length)


func _build_wall(wall_name: String, span: float, at: Vector3, yaw: float) -> void:
	var wall := Node3D.new()
	wall.name = wall_name
	wall.position = at
	wall.rotation.y = yaw
	add_child(wall)
	var horizontal: Array[float] = [-span / 2, span / 2]
	var vertical: Array[float] = [0.0, WALL_HEIGHT]
	var holes: Array[Rect2] = []
	for opening in window_openings:
		if opening["wall"] != wall_name:
			continue
		var hole := Rect2(opening["center"] - opening["width"] / 2, opening["bottom"], opening["width"], opening["height"])
		holes.append(hole)
		for edge in [hole.position.x, hole.end.x]:
			if edge > -span / 2 and edge < span / 2 and not horizontal.has(edge):
				horizontal.append(edge)
		for edge in [hole.position.y, hole.end.y]:
			if edge > 0 and edge < WALL_HEIGHT and not vertical.has(edge):
				vertical.append(edge)
	horizontal.sort()
	vertical.sort()
	for x in range(horizontal.size() - 1):
		for y in range(vertical.size() - 1):
			var center := Vector2((horizontal[x] + horizontal[x + 1]) / 2, (vertical[y] + vertical[y + 1]) / 2)
			var empty := false
			for hole in holes:
				if hole.has_point(center):
					empty = true
			if not empty:
				_create_box("Segment_%d_%d" % [x,y], Vector3(horizontal[x + 1] - horizontal[x], vertical[y + 1] - vertical[y], WALL_THICKNESS), Vector3(center.x, center.y, 0), wall_material, wall)


func _create_box(
	object_name: String,
	box_size: Vector3,
	box_position: Vector3,
	material: Material,
	parent: Node3D = self
) -> void:
	var body := StaticBody3D.new()
	body.name = object_name
	body.position = box_position
	parent.add_child(body)

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
