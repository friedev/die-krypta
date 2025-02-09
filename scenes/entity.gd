class_name Entity extends Node2D

signal health_changed(health: int)
signal died(entity: Entity)
signal done

@export var max_health := 1
@export var layer := Main.Layer.MAIN
@export var order_label: Label

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

var order: int:
	set(value):
		order = value
		if self.order_label != null:
			self.order_label.text = str(order + 1)


func _ready() -> void:
	assert(Globals.main != null)
	if self.order_label != null:
		self.order_label.hide()


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


func _input(event: InputEvent) -> void:
	if self.order_label != null:
		if event.is_action_pressed("show_order"):
			self.order_label.show()
		elif event.is_action_released("show_order"):
			self.order_label.hide()
