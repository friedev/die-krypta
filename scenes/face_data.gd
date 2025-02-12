class_name FaceData extends Resource

# TODO typed dictionary Vector2i -> PipType
@export var pip_types := {
	Vector2i(-1, -1): null,
	Vector2i(-1,  0): null,
	Vector2i(-1, +1): null,
	Vector2i( 0, -1): null,
	Vector2i( 0,  0): null,
	Vector2i( 0, +1): null,
	Vector2i(+1, -1): null,
	Vector2i(+1,  0): null,
	Vector2i(+1, +1): null,
}