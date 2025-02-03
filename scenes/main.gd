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

@export var starting_enemies: int
@export var min_enemy_spawn_distance: int  # in tiles (manhattan distance)

@export var enemy_scene: PackedScene
@export var player: Player
@export var tile_map: TileMapLayer
@export var health_map: TileMapLayer

var level := 0
var enemy_count: int
var enemies: Array[Enemy] = []
var enemy_map := {}
var animate_enemies := true


func is_cell_open(coords: Vector2i) -> bool:
	return (
		not self.enemy_map.has(coords)
		and self.tile_map.get_cell_atlas_coords(coords) in self.floor_tiles
		and self.player.coords != coords
	)


func update() -> void:
	for enemy in self.enemies:
		self.enemy_map.erase(enemy.coords)
		enemy.prev_coords = enemy.coords
		enemy.update()
		self.enemy_map[enemy.coords] = enemy

	if self.player.health > 0:
		self.player.draw_moves()

		if len(self.enemies) == 0:
			self.level += 1
			self.new_level()


func place_enemy(coords: Vector2i) -> Enemy:
	var enemy := self.enemy_scene.instantiate() as Enemy
	enemy.main = self
	enemy.tile_map = self.tile_map
	enemy.player = self.player
	enemy.coords = coords
	enemy.prev_coords = coords
	enemy.position = self.tile_map.map_to_local(enemy.coords)
	self.enemies.append(enemy)
	self.enemy_map[enemy.coords] = enemy
	self.add_child(enemy)
	return enemy


func manhattan_distance(v1: Vector2i, v2: Vector2i) -> int:
	return abs(v1.x - v2.x) + abs(v1.y - v2.y)


func spawn_enemies(count: int) -> void:
	var spawn_cells: Array[Vector2i] = []
	for coords in self.get_open_cells():
		if (
			self.is_cell_open(coords)
			and self.manhattan_distance(self.player.coords, coords) >= self.min_enemy_spawn_distance
		):
			spawn_cells.append(coords)

	for i in range(count):
		if len(spawn_cells) == 0:
			push_warning("Not enough space to spawn enemies; stopping with %d spawned out of %d" % [i, count])
			break

		var spawn_coords: Vector2i = spawn_cells.pick_random()
		spawn_cells.erase(spawn_coords)
		self.place_enemy(spawn_coords)


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
	var long_dimension := randi_range(6, 9)
	var short_dimension := randi_range(3, 5)

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
		randi_range(rect1.position.x - rect_size.x, rect1.end.x - 1),
		randi_range(rect1.position.y - rect_size.y, rect1.end.y - 1)
	)
	var rect2 := Rect2i(start, rect_size)

	self.place_rect(rect1)
	self.place_rect(rect2)


func new_game() -> void:
	for enemy in self.enemies:
		enemy.queue_free()
	self.enemies.clear()
	self.enemy_map.clear()

	self.player.setup()
	self.player.camera.position_smoothing_enabled = false
	self.player.camera.force_update_scroll()
	self.player.camera.position_smoothing_enabled = true

	self.animate_enemies = true

	self.enemy_count = self.starting_enemies
	self.level = 0

	self.new_level()


func new_level() -> void:
	self.tile_map.clear()
	self.generate_map()

	self.player.coords = Vector2i(0, 0)
	self.player.position = self.tile_map.map_to_local(self.player.coords)

	self.spawn_enemies(self.starting_enemies + self.level)

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
