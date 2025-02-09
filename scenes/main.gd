class_name Main extends Node2D

signal level_started(level: int)

const TILE_UNDEFINED := Vector2i(-1, -1)

var floor_tiles: Array[Vector2i] = [
	Vector2i(4, 5),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(7, 5),
]

var wall_tiles: Array[Vector2i] = [
	Vector2i(0, 2),
	Vector2i(1, 2),
]

var full_heart := Vector2i(78, 37)
var broken_heart := Vector2i(80, 37)

enum Layer {
	MAIN,
	FLOOR,
}

const ASTAR_LAYER := Layer.MAIN

@export var level_generator: LevelGenerator

@export var player: Player
@export var tile_map: TileMapLayer
@export var health_map: TileMapLayer

var ready_for_input := false
var level := 0
# TODO typed dictionary Vector2i -> Entity
var entity_maps: Array[Dictionary] = []
var entity_queue: Array[Entity] = []
var entity_index := 0
var astar := AStarGrid2D.new()


func _enter_tree() -> void:
	Globals.main = self
	for layer in Layer:
		self.entity_maps.append({})


func _ready() -> void:
	SignalBus.node_spawned.connect(self._on_node_spawned)


func is_cell_open(coords: Vector2i) -> bool:
	return not self.astar.is_point_solid(coords)


func update() -> void:
	self.entity_index = 0
	self.update_next_entity()


func update_next_entity() -> void:
	while self.entity_index < len(self.entity_queue) and self.entity_queue[self.entity_index] == null:
		self.entity_index += 1
	
	if self.entity_index < len(self.entity_queue):
		var enemy := self.entity_queue[self.entity_index]
		self.entity_index += 1
		enemy.update()
	else:
		self.end_turn()


func _on_entity_died(entity: Entity) -> void:
	self.entity_queue[self.entity_queue.find(entity)] = null


func _on_entity_done() -> void:
	self.update_next_entity()


func update_entity_order() -> void:
	var order := 0
	for entity in self.entity_queue:
		if entity != null:
			entity.order = order
			order += 1



func end_turn() -> void:
	self.update_entity_order()
	self.ready_for_input = true
	if self.player.health > 0:
		for entity in self.entity_queue:
			if entity != null and entity is Enemy:
				self.player.draw_moves()
				return
		self.level += 1
		self.new_level()


func raycast(start: Vector2i, direction: Vector2i) -> Vector2i:
	var p := start + direction
	while self.is_cell_open(p):
		p += direction
	return p


func place_entity(entity: Entity, coords: Vector2i) -> void:
	entity.coords = coords
	entity.position = self.tile_map.map_to_local(entity.coords)
	entity.done.connect(self._on_entity_done)
	self.entity_queue.append(entity)
	entity.died.connect(self._on_entity_died)
	self.add_child(entity)


func is_wall(coords: Vector2i) -> bool:
	return self.tile_map.get_cell_atlas_coords(coords) in self.wall_tiles


func is_floor(coords: Vector2i) -> bool:
	return self.tile_map.get_cell_atlas_coords(coords) in self.floor_tiles


func is_undefined(coords: Vector2i) -> bool:
	return self.tile_map.get_cell_atlas_coords(coords) == self.TILE_UNDEFINED


func get_floors() -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var floors: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_floor(coords):
			floors.append(coords)
	return floors


func get_open_cells() -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var open_cells: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_cell_open(coords):
			open_cells.append(coords)
	return open_cells


## Get each wall that is adjacent to a floor
func get_exposed_walls(directions := Utility.orthogonal_directions) -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var exposed_walls: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_wall(coords):
			for direction in directions:
				if self.is_floor(coords + direction):
					exposed_walls.append(coords)
					break
	return exposed_walls


## Get floors that aren't adjacent to any walls
func get_center_floors(directions := Utility.orthogonal_directions) -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var center_floors: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_floor(coords):
			for direction in directions:
				if self.is_wall(coords + direction):
					continue
			center_floors.append(coords)
	return center_floors


func set_wall(coords: Vector2i, wall: bool) -> void:
	var tiles := self.wall_tiles if wall else self.floor_tiles
	self.astar.set_point_solid(coords, wall)
	self.tile_map.set_cell(coords, 0, tiles.pick_random())


func place_rect(rect: Rect2i) -> int:
	var floor_count := 0
	var walled_rect := rect.grow(1)
	for x in range(walled_rect.position.x, walled_rect.end.x):
		for y in range(walled_rect.position.y, walled_rect.end.y):
			var coords := Vector2i(x, y)
			if rect.has_point(coords):
				if not self.is_floor(coords):
					self.set_wall(coords, false)
					floor_count += 1
			elif self.is_undefined(coords):
				self.set_wall(coords, true)
			else:
				continue
	return floor_count


# Print the current A* grid to the output (for debugging)
func print_astar() -> void:
	print()
	for y in range(self.astar.region.position.y, self.astar.region.end.y):
		var line := ""
		for x in range(self.astar.region.position.x, self.astar.region.end.x):
			if self.astar.is_point_solid(Vector2i(x, y)):
				line += "# "
			else:
				line += ". "
		print(line)
	print()


func new_game() -> void:
	self.player.setup()
	self.level = 0
	self.new_level()


func new_level() -> void:
	self.get_tree().call_group("enemies", "queue_free")
	self.get_tree().call_group("traps", "queue_free")

	self.tile_map.clear()
	for entity_map in self.entity_maps:
		entity_map.clear()
	self.entity_queue.clear()

	self.level_generator.generate_level()

	self.update_entity_order()

	self.player.position = self.tile_map.map_to_local(self.player.coords)
	self.player.camera.position_smoothing_enabled = false
	self.player.camera.force_update_scroll()
	self.player.camera.position_smoothing_enabled = true
	self.player.draw_moves()

	self.level_started.emit(self.level)

	self.ready_for_input = true


func _on_player_health_changed(health: int) -> void:
	self.health_map.clear()
	for i in range(self.player.max_health):
		self.health_map.set_cell(
			Vector2i(i, 0),
			0,
			self.full_heart if i < health else self.broken_heart
		)


func _on_player_done() -> void:
	self.update()


func _on_main_menu_play_pressed(previous: Menu) -> void:
	self.new_game()


func _on_node_spawned(node: Node) -> void:
	self.add_child(node)
