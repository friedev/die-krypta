class_name FacePreview extends Face

var previous_faces: Array[FaceData] = []

func push_face(new_face_data: FaceData) -> void:
	self.previous_faces.push_back(self.face_data)
	self.face_data = new_face_data


func pop_face() -> bool:
	if len(self.previous_faces) > 0:
		self.face_data = self.previous_faces.pop_back()
		return true
	return false
