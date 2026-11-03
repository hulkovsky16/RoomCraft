extends RefCounted
class_name DecorCollision

const EPS := 0.000001

# Convex-part narrow phase; empty space inside the overall box stays usable.
static func overlaps(a: FurnitureItem, at: Vector3, yaw: float, b: FurnitureItem, bt: Vector3, byaw: float) -> bool:
	var ta := Transform3D(Basis(Vector3.UP, yaw), at)
	var tb := Transform3D(Basis(Vector3.UP, byaw), bt)
	for i in range(a.surfaces.size()):
		var ap := ta * a.surfaces[i].transform
		var bounds_a := ap * a.surfaces[i].get_aabb()
		for j in range(b.surfaces.size()):
			var bp := tb * b.surfaces[j].transform
			var bounds_b := bp * b.surfaces[j].get_aabb()
			if bounds_a.grow(-EPS).intersects(bounds_b.grow(-EPS)) and _gjk(a.collision_vertices[i], ap, b.collision_vertices[j], bp):
				return true
	return false

static func _support(vertices: PackedVector3Array, transform: Transform3D, direction: Vector3) -> Vector3:
	var local := transform.basis.transposed() * direction
	var best := vertices[0]
	var score := best.dot(local)
	for vertex in vertices:
		var candidate := vertex.dot(local)
		if candidate > score:
			score = candidate
			best = vertex
	return transform * best

static func _difference(a: PackedVector3Array, ta: Transform3D, b: PackedVector3Array, tb: Transform3D, direction: Vector3) -> Vector3:
	return _support(a, ta, direction) - _support(b, tb, -direction)

static func _line(a: Vector3, b: Vector3) -> Dictionary:
	var ab := b - a
	var ao := -a
	if ab.dot(ao) <= 0:
		return {"points": [a], "direction": ao}
	var direction := ab.cross(ao).cross(ab)
	if direction.length_squared() < EPS * EPS:
		direction = ab.cross(Vector3.RIGHT)
		if direction.length_squared() < EPS * EPS:
			direction = ab.cross(Vector3.UP)
	return {"points": [a, b], "direction": direction}

static func _triangle(a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	var ab := b - a
	var ac := c - a
	var ao := -a
	var normal := ab.cross(ac)
	if normal.cross(ac).dot(ao) > 0:
		return _line(a, c) if ac.dot(ao) > 0 else _line(a, b)
	if ab.cross(normal).dot(ao) > 0:
		return _line(a, b)
	if normal.dot(ao) >= 0:
		return {"points": [a, b, c], "direction": normal}
	return {"points": [a, c, b], "direction": -normal}

static func _simplex(points: Array) -> Dictionary:
	var a: Vector3 = points[0]
	if points.size() == 2:
		return _line(a, points[1])
	if points.size() == 3:
		return _triangle(a, points[1], points[2])
	var b: Vector3 = points[1]
	var c: Vector3 = points[2]
	var d: Vector3 = points[3]
	for face in [[b, c, d], [c, d, b], [d, b, c]]:
		var normal: Vector3 = (face[0] - a).cross(face[1] - a)
		if normal.dot(face[2] - a) > 0:
			normal = -normal
		if normal.dot(-a) > 0:
			return _triangle(a, face[0], face[1])
	return {"hit": true}

static func _gjk(a: PackedVector3Array, ta: Transform3D, b: PackedVector3Array, tb: Transform3D) -> bool:
	var direction := tb.origin - ta.origin
	if direction.length_squared() < EPS * EPS:
		direction = Vector3.RIGHT
	var points: Array = [_difference(a, ta, b, tb, direction)]
	direction = -points[0]
	for iteration in range(64):
		if direction.length_squared() < EPS * EPS:
			return false
		direction = direction.normalized()
		var point := _difference(a, ta, b, tb, direction)
		if point.dot(direction) <= EPS:
			return false
		points.push_front(point)
		var result := _simplex(points)
		if result.get("hit", false):
			return true
		points = result["points"]
		direction = result["direction"]
	return true # Fail closed on numerical non-convergence.
