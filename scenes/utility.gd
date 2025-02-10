class_name Utility extends Object

enum Directions {
	NONE,
	ORTHOGONAL,
	DIAGONAL,
	ALL,
}

const orthogonal_directions: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.RIGHT,
]

const diagonal_directions: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(-1, +1),
	Vector2i(+1, -1),
	Vector2i(+1, +1),
]

const all_directions := orthogonal_directions + diagonal_directions


static func directions_to_vectors(directions: Directions) -> Array[Vector2i]:
	match directions:
		Directions.NONE:
			return []
		Directions.ORTHOGONAL:
			return orthogonal_directions
		Directions.DIAGONAL:
			return diagonal_directions
		Directions.ALL:
			return all_directions
	assert(false, "Unexpected directions: %s" % str(directions))
	return []


static func has_orthogonal(directions: Directions) -> bool:
	return directions in [Directions.ORTHOGONAL, Directions.ALL]


static func has_diagonal(directions: Directions) -> bool:
	return directions in [Directions.DIAGONAL, Directions.ALL]


static func manhattan_distance(v1: Vector2i, v2: Vector2i) -> int:
	return abs(v1.x - v2.x) + abs(v1.y - v2.y)


static func is_same_direction(p1: Vector2i, p2: Vector2i) -> bool:
	return is_equal_approx(Vector2(p1).angle(), Vector2(p2).angle())