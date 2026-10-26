extends StaticBody3D
class_name FurnitureItem

var furniture_id: String
var type_id := "table"
var size := Vector3(1.4, 0.75, 0.8)
var surfaces: Array[MeshInstance3D] = []
var material := StandardMaterial3D.new()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	material.albedo_color = Color("a87545")
	_add_box(Vector3(size.x, 0.08, size.z), Vector3(0, size.y - 0.04, 0))
	for x in [-1, 1]:
		for z in [-1, 1]:
			_add_box(Vector3(0.08, size.y - 0.08, 0.08), Vector3(x * (size.x / 2 - 0.09), (size.y - 0.08) / 2, z * (size.z / 2 - 0.09)))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2
	add_child(shape)


func _add_box(dimensions: Vector3, offset: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	visual.mesh = box
	visual.position = offset
	visual.material_override = material
	add_child(visual)
	surfaces.append(visual)


func set_highlight(state: String) -> void:
	match state:
		"valid": material.albedo_color = Color("53d889")
		"invalid": material.albedo_color = Color("ef6262")
		"selected": material.albedo_color = Color("efc85b")
		_: material.albedo_color = Color("a87545")


func to_record() -> Dictionary:
	return {"id": furniture_id, "type_id": type_id,
		"position": [position.x, position.y, position.z], "rotation_y": rotation.y}
