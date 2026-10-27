extends StaticBody3D
class_name FurnitureItem

var furniture_id: String
var type_id := "table"
var placement := "floor"
var wall_id := ""
var support_id := ""
var size := Vector3(1.4, 0.75, 0.8)
var surfaces: Array[MeshInstance3D] = []
var original_materials: Array[Material] = []
var collision_vertices: Array[PackedVector3Array] = []
var precise_collision := false
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
	if precise_collision:
		for i in range(surfaces.size()):
			var points := PackedVector3Array()
			for vertex in collision_vertices[i]:
				points.append(surfaces[i].transform * vertex)
			var shape := ConvexPolygonShape3D.new()
			shape.points = points
			var collision := CollisionShape3D.new()
			collision.shape = shape
			add_child(collision)
		return
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
	collision_vertices.append(visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])


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
		_:
			_build_interior_model()


func to_record() -> Dictionary:
	return {"id": furniture_id, "type_id": type_id,
		"position": [position.x, position.y, position.z], "rotation_y": rotation.y,
		"placement": placement, "wall_id": wall_id, "support_id": support_id}


const WHITE := Color("ece9e2")
const METAL := Color("a9b4be")
const BLACK := Color("202b35")
const GREEN := Color("417c4d")


func _add_round(radius: float, height: float, at: Vector3, color: Color, top_radius: float = -1.0, rotation_x: float = 0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	_add_mesh(mesh, at, color, Vector3(rotation_x, 0, 0))


func _add_ellipsoid(dimensions: Vector3, at: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var visual := _add_mesh(mesh, at, color)
	visual.scale = dimensions


func _add_mesh(mesh: Mesh, at: Vector3, color: Color, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	visual.rotation = angles
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.65
	if color.a < 1.0:
		surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = surface
	add_child(visual)
	surfaces.append(visual)
	original_materials.append(surface)
	collision_vertices.append(visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return visual


func _glass(dimensions: Vector3, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add_mesh(mesh, at, Color(0.55, 0.82, 0.91, 0.22))


func _cabinet(width: float, height: float, depth: float) -> void:
	_add_box(Vector3(width - 0.04, 0.08, depth - 0.04), Vector3(0, 0.04, 0), BLACK)
	_add_box(Vector3(width, height - 0.12, depth - 0.025), Vector3(0, (height + 0.04) / 2, -0.0125), WHITE)
	_add_box(Vector3(width, 0.04, depth), Vector3(0, height - 0.02, 0), WOOD)
	for side in [-1, 1]:
		_add_box(Vector3(width / 2 - 0.015, height - 0.18, 0.015), Vector3(side * width / 4, height / 2, depth / 2 - 0.02), CUSHION)
		_add_box(Vector3(0.07, 0.018, 0.02), Vector3(side * width / 4, height - 0.16, depth / 2 - 0.01), METAL)


func _basin(width: float, depth: float, bottom: float, height: float) -> void:
	_add_box(Vector3(width, 0.03, depth), Vector3(0, bottom + 0.015, 0.02), METAL)
	for side in [-1, 1]:
		_add_box(Vector3(0.04, height, depth), Vector3(side * (width / 2 - 0.02), bottom + height / 2, 0.02), WHITE)
		_add_box(Vector3(width - 0.08, height, 0.04), Vector3(0, bottom + height / 2, 0.02 + side * (depth / 2 - 0.02)), WHITE)
	_add_round(0.025, 0.005, Vector3(0, bottom + 0.033, 0.02), BLACK)


func _tap(base: float, z: float) -> void:
	_add_round(0.018, 0.2, Vector3(0, base + 0.1, z), METAL)
	_add_box(Vector3(0.035, 0.025, 0.13), Vector3(0, base + 0.19, z + 0.05), METAL)


func _build_interior_model() -> void:
	match type_id:
		"window":
			for side in [-1, 1]:
				_add_box(Vector3(0.065, size.y, 0.12), Vector3(side * (size.x / 2 - 0.0325), size.y / 2, 0), WHITE)
				_add_box(Vector3(size.x - 0.13, 0.065, 0.12), Vector3(0, size.y / 2 + side * (size.y / 2 - 0.0325), 0), WHITE)
			_add_box(Vector3(0.045, size.y - 0.13, 0.1), Vector3(0, size.y / 2, 0), WHITE)
			_add_box(Vector3(size.x, 0.035, size.z), Vector3(0, 0.0175, 0), WHITE)
			_glass(Vector3(size.x - 0.13, size.y - 0.13, 0.008), Vector3(0, size.y / 2, 0))
		"tv_console":
			_cabinet(size.x, 0.45, size.z)
			_add_box(Vector3(0.5, 0.035, 0.22), Vector3(0, 0.47, 0), BLACK)
			_add_box(Vector3(0.08, 0.14, 0.055), Vector3(0, 0.54, 0), BLACK)
			_add_box(Vector3(1.2, 0.65, 0.06), Vector3(0, 0.925, 0), BLACK)
			_add_box(Vector3(1.14, 0.59, 0.008), Vector3(0, 0.925, 0.034), Color("335c75"))
		"plant", "flowers":
			var pot_height := 0.32 if type_id == "plant" else 0.23
			_add_round(size.x * 0.24, pot_height, Vector3(0, pot_height / 2, 0), Color("bb8066"), size.x * 0.34)
			_add_round(size.x * 0.31, 0.01, Vector3(0, pot_height - 0.01, 0), DARK_WOOD)
			if type_id == "plant":
				_add_round(0.025, 0.85, Vector3(0, 0.745, 0), DARK_WOOD)
				for i in range(7):
					var angle := i * 2.4
					_add_ellipsoid(Vector3(0.3, 0.13, 0.25), Vector3(cos(angle) * 0.15, 0.51 + i * 0.115, sin(angle) * 0.15), GREEN.lightened(i * 0.025))
			else:
				for i in range(5):
					var at := Vector3(cos(i * 2.4) * 0.12, 0, sin(i * 2.4) * 0.12)
					_add_round(0.007, 0.35, at + Vector3(0, 0.4, 0), GREEN)
					_add_ellipsoid(Vector3(0.13, 0.13, 0.13), at + Vector3(0, 0.6 + (i % 2) * 0.03, 0), Color("e5a1ac"))
		"table_lamp":
			_add_round(0.12, 0.035, Vector3(0, 0.0175, 0), BLACK)
			_add_round(0.012, 0.28, Vector3(0, 0.17, 0), METAL)
			_add_round(0.14, 0.16, Vector3(0, 0.37, 0), LINEN, 0.09)
		"potted_plant":
			_add_round(0.085, 0.16, Vector3(0, 0.08, 0), WHITE, 0.12)
			_add_round(0.11, 0.008, Vector3(0, 0.155, 0), DARK_WOOD)
			_add_round(0.008, 0.22, Vector3(0, 0.27, 0), GREEN)
			for i in range(6):
				_add_ellipsoid(Vector3(0.16, 0.08, 0.1), Vector3(cos(i * 2.4) * 0.065, 0.25 + i * 0.045, sin(i * 2.4) * 0.065), GREEN.lightened(i * 0.03))
		"floor_lamp":
			_add_round(0.2, 0.035, Vector3(0, 0.0175, 0), BLACK)
			_add_round(0.018, 1.35, Vector3(0, 0.7, 0), METAL)
			_add_round(0.225, 0.3, Vector3(0, 1.5, 0), LINEN, 0.13)
		"kitchen_cabinet", "kitchen_island":
			_cabinet(size.x, size.y, size.z)
		"kitchen_sink", "bathroom_vanity":
			var top := 0.9 if type_id == "kitchen_sink" else 0.8
			_cabinet(size.x, top - 0.1, size.z)
			_basin(size.x - 0.08, size.z - 0.12, top - 0.1, 0.1)
			_tap(top, -size.z / 2 + 0.055)
		"cooker":
			_add_box(Vector3(size.x, 0.86, size.z), Vector3(0, 0.43, 0), WHITE)
			_add_box(Vector3(0.6, 0.04, 0.6), Vector3(0, 0.88, 0), BLACK)
			for x in [-1, 1]:
				for z in [-1, 1]:
					_add_round(0.09, 0.008, Vector3(x * 0.145, 0.895, z * 0.145), METAL)
			_add_box(Vector3(0.48, 0.42, 0.012), Vector3(0, 0.39, 0.294), BLACK)
			_add_box(Vector3(0.42, 0.026, 0.025), Vector3(0, 0.65, 0.2875), METAL)
			for i in range(4):
				_add_round(0.025, 0.015, Vector3(-0.18 + i * 0.12, 0.77, 0.29), BLACK, -1, PI / 2)
		"fridge":
			_add_box(Vector3(size.x, size.y, size.z - 0.03), Vector3(0, size.y / 2, -0.015), METAL)
			_add_box(Vector3(size.x - 0.02, 1.16, 0.02), Vector3(0, 1.24, size.z / 2 - 0.02), WHITE)
			_add_box(Vector3(size.x - 0.02, 0.6, 0.02), Vector3(0, 0.32, size.z / 2 - 0.02), WHITE)
			for y in [0.45, 0.9]:
				_add_box(Vector3(0.025, 0.25, 0.02), Vector3(-0.26, y, size.z / 2 - 0.01), BLACK)
		"dishwasher", "washing_machine":
			_add_box(Vector3(size.x, size.y, size.z - 0.03), Vector3(0, size.y / 2, -0.015), WHITE)
			_add_box(Vector3(0.56, 0.1, 0.02), Vector3(0, 0.77, 0.28), METAL)
			_add_box(Vector3(0.12, 0.045, 0.01), Vector3(0.12, 0.77, 0.295), BLACK)
			if type_id == "washing_machine":
				_add_round(0.21, 0.02, Vector3(0, 0.4, 0.28), METAL, -1, PI / 2)
				_add_round(0.16, 0.012, Vector3(0, 0.4, 0.294), Color("344e62"), -1, PI / 2)
			else:
				_add_box(Vector3(0.55, 0.58, 0.025), Vector3(0, 0.36, 0.28), METAL)
				_add_box(Vector3(0.26, 0.025, 0.015), Vector3(0, 0.65, 0.2925), BLACK)
		"bathtub":
			_basin(size.x, size.z - 0.04, 0.1, 0.5)
		"toilet":
			_add_box(Vector3(0.38, 0.5, 0.15), Vector3(0, 0.55, -0.275), WHITE)
			_add_ellipsoid(Vector3(0.28, 0.4, 0.4), Vector3(0, 0.2, 0.05), WHITE)
			_add_ellipsoid(Vector3(0.42, 0.16, 0.52), Vector3(0, 0.42, 0.08), WHITE)
			_add_ellipsoid(Vector3(0.27, 0.015, 0.35), Vector3(0, 0.5, 0.08), BLACK)
			_add_box(Vector3(0.06, 0.012, 0.04), Vector3(0, 0.794, -0.275), METAL)
		"shower":
			_add_box(Vector3(0.9, 0.1, 0.9), Vector3(0, 0.05, 0), WHITE)
			for side in [-1, 1]:
				_add_box(Vector3(0.025, 2, 0.025), Vector3(side * 0.43, 1.1, 0.43), METAL)
			_glass(Vector3(0.015, 2, 0.84), Vector3(-0.43, 1.1, 0))
			_glass(Vector3(0.015, 2, 0.84), Vector3(0.43, 1.1, 0))
			_glass(Vector3(0.84, 2, 0.015), Vector3(0, 1.1, 0.43))
			_add_box(Vector3(0.9, 2, 0.025), Vector3(0, 1.1, -0.4375), WHITE)
			_add_round(0.018, 1.35, Vector3(0, 1.2, -0.39), METAL)
			_add_round(0.09, 0.02, Vector3(0, 1.89, -0.29), METAL)
