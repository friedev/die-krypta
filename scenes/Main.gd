class_name Main extends Node2D

const TILE_EMPTY := -1
const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_WIN := 2

@export var room_count: int
@export var room_width_min: int
@export var room_height_min: int
@export var room_width_max: int
@export var room_height_max: int
@export var room_enemy_min: int
@export var room_enemy_max: int

@export var enemy_scene: PackedScene
@export var player: Player
@export var tile_map: TileMap
@export var health_map: TileMap
@export var win_label: Label
@export var restart_label: Label

var rooms: Array[MapRoom] = []
var enemies: Array[Enemy] = []
var enemy_map := {}
var animate_enemies := true


func is_cell_open(cellv: Vector2) -> bool:
	return (
		not self.enemy_map.has(cellv)
		and self.tile_map.get_cell_source_id(0, cellv) == self.TILE_FLOOR
		and self.player.cellv != cellv
	)


func get_room(cellv: Vector2) -> MapRoom:
	# TODO optimize
	for room in self.rooms:
		if (
			room.x - 1 <= cellv.x
			and cellv.x <= room.x_end
			and room.y - 1 <= cellv.y
			and cellv.y <= room.y_end
		):
			return room
	return null


func update():
	for enemy in self.enemies:
		self.enemy_map.erase(enemy.cellv)
		enemy.prev_cellv = enemy.cellv
		enemy.update()
		self.enemy_map[enemy.cellv] = enemy

	if self.player.health > 0:
		self.player.draw_moves()


func place_enemy(cellv: Vector2) -> Enemy:
	var enemy := self.enemy_scene.instantiate() as Enemy
	enemy.main = self
	enemy.tile_map = self.tile_map
	enemy.player = self.player
	enemy.cellv = cellv
	enemy.prev_cellv = cellv
	enemy.position = self.tile_map.map_to_local(enemy.cellv)
	self.enemies.append(enemy)
	self.enemy_map[enemy.cellv] = enemy
	self.add_child(enemy)
	return enemy


func spawn_room_enemy(room: MapRoom):
	var cellv := Vector2(
		room.x + randi() % (room.width + 1),
		room.y + randi() % (room.height + 1)
	)

	while not self.is_cell_open(cellv):
		cellv = Vector2(
			room.x + randi() % (room.width + 1),
			room.y + randi() % (room.height + 1)
		)

	var enemy := self.place_enemy(cellv)
	enemy.room = room


func find_open_cell() -> Vector2:
	var open_cells := self.tile_map.get_used_cells_by_id(self.TILE_FLOOR)
	return open_cells[randi() % len(open_cells)]


func generate_map():
	var x := 1
	var y := 1
	while len(self.rooms) < self.room_count:
		var room_width := randi_range(self.room_width_min, self.room_width_max)
		var room_height := randi_range(self.room_height_min, self.room_height_max)
		var room := MapRoom.new(x, y, room_width, room_height)

		# Check if room will fit
		var valid := true
		# Should be x - 1 and y - 1 for a general algorithm
		for x2 in range(x, x + room_width + 2):
			for y2 in range(y, y + room_height + 2):
				if self.tile_map.get_cell_source_id(0, Vector2i(x2, y2)) == self.TILE_FLOOR:
					valid = false
					break
			if not valid:
				break
		if not valid:
			continue

		# Place room
		self.rooms.append(room)
		for x2 in range(x - 1, x + room_width + 2):
			for y2 in range(y - 1, y + room_height + 2):
				if (
					x2 == x - 1
					or x2 == x + room_width + 1
					or y2 == y - 1
					or y2 == y + room_height + 1
				):
					if self.tile_map.get_cell_source_id(0, Vector2i(x2, y2)) == self.TILE_EMPTY:
						self.tile_map.set_cell(0, Vector2i(x2, y2), self.TILE_WALL, Vector2i.ZERO)
				else:
					self.tile_map.set_cell(0, Vector2i(x2, y2), self.TILE_FLOOR, Vector2i.ZERO)

		# Create door to previous room
		if len(self.rooms) > 1:
			if self.tile_map.get_cell_source_id(0, Vector2i(x - 2, y)) == self.TILE_FLOOR:
				var max_dy := 0
				for dy in range(room_height + 1):
					max_dy = dy
					if self.tile_map.get_cell_source_id(0, Vector2i(x - 2, y + dy)) == self.TILE_WALL:
						break
				self.tile_map.set_cell(0, Vector2i(x - 1, y + randi() % max_dy), self.TILE_FLOOR, Vector2i.ZERO)
			else:
				var max_dx := 0
				for dx in range(room_width + 1):
					max_dx = dx
					if self.tile_map.get_cell_source_id(0, Vector2i(x + dx, y - 2)) == self.TILE_WALL:
						break
				self.tile_map.set_cell(0, Vector2i(x + randi() % max_dx, y - 1), self.TILE_FLOOR, Vector2i.ZERO)

		# Place win tile
		if len(self.rooms) == self.room_count:
			self.tile_map.set_cell(0, Vector2i(x + room_width, y + room_height), self.TILE_WIN, Vector2i.ZERO)
			break

		# Advance pointer to next room
		if randi() % 2 == 0:
			x += randi() % room_width
			y += room_height + 2
		else:
			x += room_width + 2
			y += randi() % room_height


func setup():
	randomize()

	for enemy in self.enemies:
		enemy.queue_free()
	self.enemies.clear()
	self.enemy_map.clear()
	self.rooms.clear()

	self.tile_map.clear()
	self.generate_map()

	self.player.cellv = Vector2(1, 1)
	self.player.position = self.tile_map.map_to_local(self.player.cellv)
	self.player.setup()
	self.player.camera.position_smoothing_enabled = false
	self.player.camera.force_update_scroll()
	self.player.camera.position_smoothing_enabled = true

	for room_idx in range(1, self.room_count):
		var room: MapRoom = rooms[room_idx]
		var enemy_count := randi_range(self.room_enemy_min, self.room_enemy_max)
		for _enemy_idx in range(enemy_count):
			self.spawn_room_enemy(room)

	self.animate_enemies = true

	self.restart_label.hide()
	self.win_label.hide()


func _ready():
	self.setup()


func _input(event):
	if event.is_action_pressed(&"restart"):
		self.setup()
	elif event.is_action_pressed(&"exit"):
		if OS.get_name() == "HTML5":
			self.setup()
		else:
			self.get_tree().quit()


func _on_player_died() -> void:
	self.restart_label.show()


func _on_player_won() -> void:
	self.win_label.show()


func _on_player_health_changed(health: int) -> void:
	self.health_map.clear()
	for i in range(self.player.max_health):
		self.health_map.set_cell(0, Vector2i(i, 0), 0 if i < health else 1, Vector2i.ZERO)
