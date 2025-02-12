class_name Dice extends RefCounted

var face_center: int  ## The face pointing "outward", towards the camera.
var face_left: int
var face_up: int

func copy_from(other: Dice) -> void:
	self.face_center = other.face_center
	self.face_left = other.face_left
	self.face_up = other.face_up


## Adjust the faces of the die as if it were rolled in the given direction.
func roll(direction: Vector2i) -> void:
	var old_face_center := self.face_center
	if direction == Vector2i.LEFT:
		self.face_center = 7 - self.face_left
		self.face_left = old_face_center
	elif direction == Vector2i.RIGHT:
		self.face_center = self.face_left
		self.face_left = 7 - old_face_center
	elif direction == Vector2i.UP:
		self.face_center = 7 - self.face_up
		self.face_up = old_face_center
	elif direction == Vector2i.DOWN:
		self.face_center = self.face_up
		self.face_up = 7 - old_face_center
	else:
		assert(false, "Unexpected direction: %s" % str(direction))