class_name Projectile extends Node2D

@export var speed: float

var target_position: Vector2
var target_entity: Entity


func _process(delta: float) -> void:
	if self.target_entity != null:
		self.target_position = self.target_entity.global_position
	self.rotation = self.global_position.angle_to_point(self.target_position)
	self.global_position = self.global_position.move_toward(self.target_position, self.speed * delta)
	if self.global_position.is_equal_approx(self.target_position):
		self.queue_free()