class_name LevelLabel extends Label


func _ready() -> void:
	self.hide()


func _on_level_started(level: int) -> void:
	self.show()
	self.text = "Level %d" % (level + 1)
