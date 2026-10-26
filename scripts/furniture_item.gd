extends StaticBody3D
class_name FurnitureItem

var furniture_id: String
var type_id := "table"
var size := Vector3(1.4, 0.75, 0.8)
var surfaces: Array[MeshInstance3D] = []
var original_materials: Array[Material] = []
var material := StandardMaterial3D.new()
const WOOD := Color("a87545")
const DARK_WOOD := Color("5e4432")
const FABRIC := Color("507e87")
const CUSHION := Color("7ca3a4")
const LINEN := Color("e4ded1")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	material.roughness = 0.8
	_build_model()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2
	add_child(shape)


func _add_box(dimensions: Vector3, offset: Vector3, color: Color = WOOD) -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	visual.mesh = box
	visual.position = offset
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = color
	surface_material.roughness = 0.8
	visual.material_override = surface_material
	add_child(visual)
	surfaces.append(visual)
	original_materials.append(surface_material)


func set_highlight(state: String) -> void:
	match state:
		"valid": material.albedo_color = Color("53d889")
		"invalid": material.albedo_color = Color("ef6262")
		"selected": material.albedo_color = Color("efc85b")
		_: pass
	for i in range(surfaces.size()):
		surfaces[i].material_override = material if state in ["valid", "invalid", "selected"] else original_materials[i]


func _legs(height: float, thickness: float = 0.08) -> void:
	for x in [-1, 1]:
		for z in [-1, 1]:
			_add_box(Vector3(thickness, height, thickness), Vector3(x * (size.x / 2 - thickness), height / 2, z * (size.z / 2 - thickness)), DARK_WOOD)


func _build_model() -> void:
	match type_id:
		"table", "coffee_table":
			_add_box(Vector3(size.x, 0.08, size.z), Vector3(0, size.y - 0.04, 0))
			_legs(size.y - 0.08)
		"chair":
			_legs(0.42, 0.05)
			_add_box(Vector3(size.x, 0.08, size.z), Vector3(0, 0.46, 0), CUSHION)
			_add_box(Vector3(size.x, 0.4, 0.06), Vector3(0, 0.7, -size.z / 2 + 0.03))
		"sofa", "armchair":
			_legs(0.12)
			_add_box(Vector3(size.x, 0.22, size.z), Vector3(0, 0.23, 0), FABRIC)
			_add_box(Vector3(size.x, size.y - 0.34, 0.16), Vector3(0, (size.y + 0.34) / 2, -size.z / 2 + 0.08), FABRIC)
			for side in [-1, 1]:
				_add_box(Vector3(0.14, 0.3, size.z - 0.16), Vector3(side * (size.x / 2 - 0.07), 0.49, 0.08), FABRIC)
			var seats := 2 if type_id == "sofa" else 1
			var seat_width := (size.x - 0.3) / seats
			for i in range(seats):
				_add_box(Vector3(seat_width - 0.01, 0.12, size.z - 0.18), Vector3(-(size.x - 0.3) / 2 + seat_width * (i + 0.5), 0.4, 0.08), CUSHION)
		"bed":
			_legs(0.18)
			_add_box(Vector3(size.x, 0.18, size.z), Vector3(0, 0.27, 0), DARK_WOOD)
			_add_box(Vector3(size.x - 0.08, 0.18, size.z - 0.12), Vector3(0, 0.45, 0.02), LINEN)
			_add_box(Vector3(size.x, size.y - 0.36, 0.08), Vector3(0, (size.y + 0.36) / 2, -size.z / 2 + 0.04))
			_add_box(Vector3(size.x - 0.08, 0.04, 1.2), Vector3(0, 0.56, 0.37), FABRIC)
			for side in [-1, 1]:
				_add_box(Vector3(0.6, 0.1, 0.35), Vector3(side * 0.38, 0.59, -0.65), LINEN)
		"wardrobe":
			_add_box(Vector3(size.x, size.y, size.z - 0.04), Vector3(0, size.y / 2, -0.02), DARK_WOOD)
			for side in [-1, 1]:
				_add_box(Vector3(size.x / 2 - 0.015, size.y - 0.06, 0.025), Vector3(side * size.x / 4, size.y / 2, size.z / 2 - 0.0275))
				_add_box(Vector3(0.025, 0.18, 0.015), Vector3(side * 0.06, 1.0, size.z / 2 - 0.0075), Color("d3c9b0"))
		"bookshelf":
			for side in [-1, 1]:
				_add_box(Vector3(0.045, size.y, size.z), Vector3(side * (size.x / 2 - 0.0225), size.y / 2, 0))
			_add_box(Vector3(size.x - 0.09, size.y, 0.025), Vector3(0, size.y / 2, -size.z / 2 + 0.0125), DARK_WOOD)
			for i in range(5):
				_add_box(Vector3(size.x - 0.09, 0.04, size.z), Vector3(0, 0.02 + i * (size.y - 0.04) / 4, 0))
			for i in range(5):
				_add_box(Vector3(0.07, 0.25 + (i % 2) * 0.04, 0.2), Vector3(-0.25 + i * 0.09, 0.48 + (0.25 + (i % 2) * 0.04) / 2, 0.015), [FABRIC, LINEN, Color("b86c55")][i % 3])
		"desk":
			_add_box(Vector3(size.x, 0.06, size.z), Vector3(0, size.y - 0.03, 0))
			for z in [-1, 1]:
				_add_box(Vector3(0.06, size.y - 0.06, 0.06), Vector3(-size.x / 2 + 0.06, (size.y - 0.06) / 2, z * (size.z / 2 - 0.06)), DARK_WOOD)
			_add_box(Vector3(0.35, size.y - 0.06, size.z - 0.06), Vector3(size.x / 2 - 0.2, (size.y - 0.06) / 2, 0), DARK_WOOD)
			for i in range(3):
				_add_box(Vector3(0.33, 0.19, 0.025), Vector3(size.x / 2 - 0.2, 0.13 + i * 0.22, size.z / 2 - 0.025))
				_add_box(Vector3(0.12, 0.02, 0.012), Vector3(size.x / 2 - 0.2, 0.13 + i * 0.22, size.z / 2 - 0.006), LINEN)
		"nightstand":
			_legs(0.08, 0.04)
			_add_box(Vector3(size.x, size.y - 0.08, size.z - 0.03), Vector3(0, (size.y + 0.08) / 2, -0.015), DARK_WOOD)
			for i in range(2):
				_add_box(Vector3(size.x - 0.025, 0.18, 0.02), Vector3(0, 0.18 + i * 0.2, size.z / 2 - 0.02))
				_add_box(Vector3(0.1, 0.02, 0.01), Vector3(0, 0.18 + i * 0.2, size.z / 2 - 0.005), LINEN)


func to_record() -> Dictionary:
	return {"id": furniture_id, "type_id": type_id,
		"position": [position.x, position.y, position.z], "rotation_y": rotation.y}
