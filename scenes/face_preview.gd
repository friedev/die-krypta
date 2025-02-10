class_name FacePreview extends Node2D

const INVALID_FACE := -1

@export var sprite: AnimatedSprite2D

var face := self.INVALID_FACE:
	set(value):
		face = value
		sprite.frame = self.face - 1

var previous_faces: Array[int] = []


func push_face(number: int) -> void:
	self.previous_faces.push_back(self.face)
	self.face = number


func pop_face() -> bool:
	if len(self.previous_faces) > 0:
		self.face = self.previous_faces.pop_back()
		return true
	return false