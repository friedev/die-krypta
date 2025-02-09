class_name Entity extends Node2D

signal health_changed(health: int)
signal died(entity: Entity)
signal done

@export var max_health := 1
@export var layer := Main.Layer.MAIN

var coords: Vector2i:
	set(value):
		if Globals.main.entity_maps[self.layer].get(self.coords) == self:
			if self.layer == Main.ASTAR_LAYER:
				Globals.main.astar.set_point_solid(self.coords, false)
			Globals.main.entity_maps[self.layer].erase(self.coords)
		coords = value
		assert(not Globals.main.entity_maps[self.layer].has(self.coords))
		Globals.main.entity_maps[self.layer][self.coords] = self
		if self.layer == Main.ASTAR_LAYER:
			Globals.main.astar.set_point_solid(self.coords, true)

var health: int:
	set(value):
		health = clampi(value, 0, self.max_health)
		self.health_changed.emit(self.health)
		if self.health == 0:
			self.die()


func _ready() -> void:
	assert(Globals.main != null)


func setup() -> void:
	assert(self.max_health > 0)
	self.health = self.max_health


func update() -> void:
	self.done.emit()


func die() -> void:
	Globals.main.entity_maps[self.layer].erase(self.coords)
	if self.layer == Main.ASTAR_LAYER:
		Globals.main.astar.set_point_solid(self.coords, false)
	self.died.emit(self)


func hurt(amount: int, direction: Vector2i) -> void:
	self.health -= amount
