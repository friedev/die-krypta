class_name Entity extends Node2D

signal health_changed(health: int)
signal died(entity: Entity)

@export var max_health := 1
@export var main: Main

var coords: Vector2i:
	set(value):
		if self.main.entity_map.get(self.coords) == self:
			self.main.entity_map.erase(self.coords)
		coords = value
		assert(not self.main.entity_map.has(self.coords))
		self.main.entity_map[self.coords] = self

var health: int:
	set(value):
		health = clampi(value, 0, self.max_health)
		self.health_changed.emit(self.health)
		if self.health == 0:
			self.die()


func _ready() -> void:
	assert(self.main != null)


func setup() -> void:
	assert(self.max_health > 0)
	self.health = self.max_health


func die() -> void:
	self.main.entity_map.erase(self.coords)
	self.died.emit(self)


func hurt(amount: int, direction: Vector2i) -> void:
	self.health -= amount
