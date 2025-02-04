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
@export var player: Player
@export var tile_map: TileMapLayer
@export var health_map: TileMapLayer

var level := 0
# TODO typed dictionary Vector2i -> Entity
var entity_map := {}
var animate_enemies := true


func _ready() -> void:
	SignalBus.node_spawned.connect(self._on_node_spawned)


func is_cell_open(coords: Vector2i) -> bool:
	return (
		not self.entity_map.has(coords)
		and self.tile_map.get_cell_atlas_coords(coords) in self.floor_tiles
	)


func update() -> void:
	self.get_tree().call_group("enemies", "update")

	if self.player.health > 0:
		if self.get_tree().get_node_count_in_group("enemies") == 0:
			self.level += 1
			self.new_level()
		else:
			self.player.draw_moves()


func place_enemy(enemy: Enemy, coords: Vector2i) -> Enemy:
	enemy.main = self
	enemy.coords = coords
	enemy.prev_coords = coords
	enemy.position = self.tile_map.map_to_local(enemy.coords)
	self.add_child(enemy)
	return enemy


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

		var spawn_coords: Vector2i = spawn_cells.pick_random()

		# TODO more efficient way of choosing enemies with deterministic time
		# complexity and without churning through bad choices
		var tries := 0
		var max_tries := 10
		var enemy: Enemy = null
		while (enemy == null or difficulty + enemy.difficulty > max_difficulty) and tries < max_tries:
			tries += 1
			if enemy != null:
				enemy.queue_free()
			enemy = self.enemy_scenes.pick_random().instantiate() as Enemy

		if difficulty + enemy.difficulty <= max_difficulty:
			self.place_enemy(enemy, spawn_coords)
			spawn_cells.erase(spawn_coords)
			difficulty += enemy.difficulty
		else:
			break


func get_open_cells() -> Array[Vector2i]:
	var used_cells := self.tile_map.get_used_cells()
	var open_cells: Array[Vector2i] = []
	for coords in used_cells:
		if self.is_cell_open(coords):
			open_cells.append(coords)
	return open_cells


func place_rect(rect: Rect2i) -> void:
	var walled_rect := rect.grow(1)
	for x in range(walled_rect.position.x, walled_rect.end.x):
		for y in range(walled_rect.position.y, walled_rect.end.y):
			var p := Vector2i(x, y)
			var atlas_coords: Vector2i
			if rect.has_point(p):
				atlas_coords = self.floor_tiles.pick_random()
			elif self.tile_map.get_cell_atlas_coords(p) == self.TILE_EMPTY:
				atlas_coords = self.wall_tiles.pick_random()
			else:
				continue
			self.tile_map.set_cell(Vector2i(x, y), 0, atlas_coords)



func generate_map() -> void:
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

	long_dimension = randi_range(6, 9)
	short_dimension = randi_range(3, 5)

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


func new_game() -> void:
	self.get_tree().call_group("enemies", "queue_free")

	self.player.setup()

	self.animate_enemies = true

	self.level = 0

	self.new_level()


func new_level() -> void:
	self.tile_map.clear()
	self.entity_map.clear()
	self.generate_map()

	self.player.coords = Vector2i.ZERO
	self.player.position = self.tile_map.map_to_local(self.player.coords)

	self.player.camera.position_smoothing_enabled = false
	self.player.camera.force_update_scroll()
	self.player.camera.position_smoothing_enabled = true

	self.spawn_enemies(self.starting_difficulty + self.level * self.difficulty_per_level)

	self.player.draw_moves()

	self.level_started.emit(self.level)


func _on_player_health_changed(health: int) -> void:
	self.health_map.clear()
	for i in range(self.player.max_health):
		self.health_map.set_cell(Vector2i(i, 0), 0, Vector2i(0 if i < health else 1, 0))


func _on_player_moved() -> void:
	self.update()


func _on_main_menu_play_pressed(previous: Menu) -> void:
	self.new_game()


func _on_node_spawned(node: Node) -> void:
	self.add_child(node)
