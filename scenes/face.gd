class_name Face extends Node2D

@export var face_data: FaceData:
	set(value):
		face_data = value
		for direction in self.pips:
			self.pips[direction].pip_type = self.face_data.pip_types.get(direction)

# TODO typed dictionary Vector2i -> Pip
@onready var pips := {
	Vector2i(-1, -1): $LeftUp,
	Vector2i(-1,  0): $Left,
	Vector2i(-1, +1): $LeftDown,
	Vector2i( 0, -1): $Up,
	Vector2i( 0,  0): $Center,
	Vector2i( 0, +1): $Down,
	Vector2i(+1, -1): $RightUp,
	Vector2i(+1,  0): $Right,
	Vector2i(+1, +1): $RightDown,
}


func _ready() -> void:
	if self.face_data != null:
		self.face_data = self.face_data