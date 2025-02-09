class_name Main extends Node2D

signal level_started(level: int)

const TILE_EMPTY := Vector2i(-1, -1)

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

@export var starting_difficulty: int
@export var difficulty_per_level: int
@export var min_enemy_spawn_distance: int  # in tiles (manhattan distance)

@export var enemy_scenes: Array[PackedScene]
@export var trap_scenes: Array[PackedScene]
@export var player: Player
@export var tile_map: TileMapLayer
@export var health_map: TileMapLayer

var ready_for_input := true
var level := 0
# TODO typed dictionary Vector2i -> Entity
var entity_map := {}
var entity_queue: Array[Entity] = []
var entity_index := 0
var astar := AStarGrid2D.new()


func _enter_tree() -> void:
	Globals.main = self


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


func end_turn() -> void:
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


func spawn_enemies(max_difficulty: int) -> void:
	var spawn_cells: Array[Vector2i] = []
	for coords in self.get_open_cells():
		if (
			self.is_cell_open(coords)
			and Utility.manhattan_distance(self.player.coords, coords) >= self.min_enemy_spawn_distance
		):
			spawn_cells.append(coords)

	var difficulty := 0
	while difficulty < max_difficulty:
		if len(spawn_cells) == 0:
			push_warning("Not enough space to spawn enemies; stopping at %d difficulty out of %d max" % [difficulty, max_difficulty])
			break

		var spawn_coords := spawn_cells[randi() % len(spawn_cells)]

		# TODO more efficient way of choosing enemies with deterministic time
		# complexity and without churning through bad choices
		var tries := 0
		var max_tries := 10
		var enemy: Enemy = null
		while (enemy == null or difficulty + enemy.difficulty > max_difficulty) and tries < max_tries:
			tries += 1
			if enemy != null:
				enemy.queue_free()
			var enemy_scene := self.enemy_scenes[randi() % len(self.enemy_scenes)]
			enemy = enemy_scene.instantiate()

		if difficulty + enemy.difficulty <= max_difficulty:
			self.place_entity(enemy, spawn_coords)
			spawn_cells.erase(spawn_coords)
			difficulty += enemy.difficulty
		else:
			break


func place_traps(trap_count: int) -> void:
	var exposed_walls := self.get_exposed_walls()
	for i in range(trap_count):
		var coords := exposed_walls[randi() % len(exposed_walls)]
		self.set_wall(coords, false)

		var adjacent_floor_directions: Array[Vector2i] = []
		for direction in Utility.orthogonal_directions:
			if self.is_floor(coords + direction):
				adjacent_floor_directions.append(direction)
		var direction := adjacent_floor_directions[randi() % len(adjacent_floor_directions)]

		var trap: ProjectileTrap = self.trap_scenes[randi() % len(self.trap_scenes)].instantiate()
		trap.direction = direction
		self.place_entity(trap, coords)
		exposed_walls.erase(coords)


func is_wall(coords: Vector2i) -> bool:
	return self.tile_map.get_cell_atlas_coords(coords) in self.wall_tiles


func is_floor(coords: Vector2i) -> bool:
	return self.tile_map.get_cell_atlas_coords(coords) in self.floor_tiles


func get_open_cells() -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var open_cells: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_cell_open(coords):
			open_cells.append(coords)
	return open_cells


func get_exposed_walls() -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var exposed_walls: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_wall(coords):
			for direction in Utility.orthogonal_directions:
				if self.is_floor(coords + direction):
					exposed_walls.append(coords)
					break
	return exposed_walls


func set_wall(coords: Vector2i, wall: bool) -> void:
	var tiles := self.wall_tiles if wall else self.floor_tiles
	self.astar.set_point_solid(coords, wall)
	self.tile_map.set_cell(coords, 0, tiles.pick_random())


func place_rect(rect: Rect2i) -> void:
	var walled_rect := rect.grow(1)
	for x in range(walled_rect.position.x, walled_rect.end.x):
		for y in range(walled_rect.position.y, walled_rect.end.y):
			var coords := Vector2i(x, y)
			if rect.has_point(coords):
				self.set_wall(coords, false)
			elif self.tile_map.get_cell_atlas_coords(coords) == self.TILE_EMPTY:
				self.set_wall(coords, true)
			else:
				continue


func generate_map() -> void:
	self.astar.clear()
	self.astar.region = Rect2i(-16, -16, 32, 32)
	self.astar.update()
	self.astar.fill_solid_region(self.astar.region)

	var long_dimension := randi_range(6, 8)
	var short_dimension := randi_range(4, 6)

	var rect_size: Vector2i
	var long_x := randi() % 2 == 0

	if long_x:
		rect_size = Vector2i(long_dimension, short_dimension)
	else:
		rect_size = Vector2i(short_dimension, long_dimension)

	var start := Vector2i(
		randi_range(-rect_size.x + 1, -1),
		randi_range(-rect_size.y + 1, -1)
	)
	var rect1 := Rect2i(start, rect_size)

	long_dimension = randi_range(6, 8)
	short_dimension = randi_range(4, 6)

	long_x = not long_x
	if long_x:
		rect_size = Vector2i(long_dimension, short_dimension)
	else:
		rect_size = Vector2i(short_dimension, long_dimension)

	start = Vector2i(
		randi_range(rect1.position.x - rect_size.x + 1, rect1.end.x - 1),
		randi_range(rect1.position.y - rect_size.y + 1, rect1.end.y - 1)
	)
	var rect2 := Rect2i(start, rect_size)

	self.place_rect(rect1)
	self.place_rect(rect2)


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
	self.entity_map.clear()
	self.entity_queue.clear()

	self.generate_map()

	self.player.coords = Vector2i.ZERO
	self.player.position = self.tile_map.map_to_local(self.player.coords)

	self.player.camera.position_smoothing_enabled = false
	self.player.camera.force_update_scroll()
	self.player.camera.position_smoothing_enabled = true

	self.spawn_enemies(self.starting_difficulty + self.level * self.difficulty_per_level)
	self.place_traps(randi_range(0, 4))

	self.player.draw_moves()

	self.level_started.emit(self.level)

	self.ready_for_input = true


func _on_player_health_changed(health: int) -> void:
	self.health_map.clear()
	for i in range(self.player.max_health):
		self.health_map.set_cell(Vector2i(i, 0), 0, Vector2i(0 if i < health else 1, 0))


func _on_player_done() -> void:
	self.update()


func _on_main_menu_play_pressed(previous: Menu) -> void:
	self.new_game()


func _on_node_spawned(node: Node) -> void:
	self.add_child(node)
