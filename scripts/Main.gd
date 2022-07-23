extends Node2D
class_name Main


const TILE_EMPTY := -1
const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_WIN := 2

const ROOM_COUNT := 10
const ROOM_WIDTH_MIN := 2
const ROOM_HEIGHT_MIN := 2
const ROOM_WIDTH_RANGE := 6
const ROOM_HEIGHT_RANGE := 6
const ROOM_ENEMY_MIN := 3
const ROOM_ENEMY_RANGE := 3

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")


onready var player: Player = $Player
onready var tile_map: TileMap = $TileMap


var rooms := []
var enemies := []
var enemy_map := {}
var animate_enemies := true


func is_cell_open(cellv: Vector2) -> bool:
	return (
		not self.enemy_map.has(cellv)
		and self.tile_map.get_cellv(cellv) == self.TILE_FLOOR
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
		self.player.clear_maps()
		self.player.draw_moves()


func place_enemy(cellv: Vector2) -> Enemy:
	var enemy: Enemy = self.ENEMY_SCENE.instance()
	enemy.cellv = cellv
	enemy.prev_cellv = cellv
	enemy.position = self.tile_map.map_to_world(enemy.cellv)
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


func fill_map(id: int):
	for x in range(self.MAP_WIDTH):
		for y in range(self.MAP_HEIGHT):
			self.tile_map.set_cell(x, y, id)


func generate_map():
	var x := 1
	var y := 1
	while len(self.rooms) < self.ROOM_COUNT:
		var room_width := randi() % self.ROOM_WIDTH_RANGE + self.ROOM_WIDTH_MIN
		var room_height := randi() % self.ROOM_HEIGHT_RANGE + self.ROOM_HEIGHT_MIN
		var room := MapRoom.new(x, y, room_width, room_height)

		# Check if room will fit
		var valid := true
		# Should be x - 1 and y - 1 for a general algorithm
		for x2 in range(x, x + room_width + 2):
			for y2 in range(y, y + room_height + 2):
				if self.tile_map.get_cell(x2, y2) == self.TILE_FLOOR:
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
					if self.tile_map.get_cell(x2, y2) == self.TILE_EMPTY:
						self.tile_map.set_cell(x2, y2, self.TILE_WALL)
				else:
					self.tile_map.set_cell(x2, y2, self.TILE_FLOOR)

		# Create door to previous room
		if len(self.rooms) > 1:
			if self.tile_map.get_cell(x - 2, y) == self.TILE_FLOOR:
				var max_dy := 0
				for dy in range(room_height + 1):
					max_dy = dy
					if self.tile_map.get_cell(x - 2, y + dy) == self.TILE_WALL:
						break
				self.tile_map.set_cell(x - 1, y + randi() % max_dy, self.TILE_FLOOR)
			else:
				var max_dx := 0
				for dx in range(room_width + 1):
					max_dx = dx
					if self.tile_map.get_cell(x + dx, y - 2) == self.TILE_WALL:
						break
				self.tile_map.set_cell(x + randi() % max_dx, y - 1, self.TILE_FLOOR)

		# Place win tile
		if len(self.rooms) == self.ROOM_COUNT:
			self.tile_map.set_cell(x + room_width, y + room_height, self.TILE_WIN)
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
	self.player.position = self.tile_map.map_to_world(self.player.cellv)
	self.player.setup()
	self.player.camera.smoothing_enabled = false
	self.player.camera.force_update_scroll()
	self.player.camera.smoothing_enabled = true

	for room_idx in range(1, ROOM_COUNT):
		var room: MapRoom = rooms[room_idx]
		var enemy_count := randi() % ROOM_ENEMY_RANGE + ROOM_ENEMY_MIN
		for _enemy_idx in range(enemy_count):
			self.spawn_room_enemy(room)

	self.animate_enemies = true


func _ready():
	self.setup()


func _input(event):
	if event.is_action_pressed("restart"):
		self.setup()
	elif event.is_action_pressed("exit"):
		if OS.get_name() == "HTML5":
			self.setup()
		else:
			get_tree().quit()
