class_name HealthContainer extends Control

@export var health_icon_template: TextureRect


func set_health(health: int, max_health: int) -> void:
	if max_health != self.get_child_count():
		pass
	for i in len(self.get_child_count()):
		self.get_child(i).set_full(i < health)


func _on_player_health_changed(health: int, max_health: int) -> void:
	self.set_health(health, max_health)
