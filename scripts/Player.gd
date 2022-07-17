extends Node2D

class_name Player


const MOVE_SPEED := 15.0
const MAX_HEALTH := 3


onready var main: Node2D = get_node(@"/root/Main")
onready var tile_map: TileMap = main.get_node(@"TileMap")
onready var blank_map: TileMap = main.get_node(@"BlankMap")
onready var move_map: TileMap = $MoveMap
onready var hit_map: TileMap = main.get_node(@"HitMap")
onready var health_map: TileMap = main.get_node(@"CanvasLayer/HealthMap")
onready var win_label: Label = main.get_node(@"CanvasLayer/WinLabel")
onready var restart_label: Label = main.get_node(@"CanvasLayer/RestartLabel")
onready var sprite: AnimatedSprite = $Sprite
onready var camera: Camera2D = $Camera2D


var cellv: Vector2
var side := 1
var side_left := 4
var side_up := 5
var health := MAX_HEALTH
var max_room: MapRoom = null


func set_sides(cellv: Vector2):
	var old_side = self.side
	if cellv == Vector2.LEFT:
		self.side = 7 - self.side_left
		self.side_left = old_side
	elif cellv == Vector2.RIGHT:
		self.side = self.side_left
		self.side_left = 7 - old_side
	elif cellv == Vector2.UP:
		self.side = 7 - self.side_up
		self.side_up = old_side
	elif cellv == Vector2.DOWN:
		self.side = self.side_up
		self.side_up = 7 - old_side


func set_neighbor_if_open(
	map: TileMap,
	cellv: Vector2,
	id: int,
	absolute: bool = true
):
	var abs_cellv := self.cellv + cellv
	if self.tile_map.get_cellv(abs_cellv) == self.main.TILE_FLOOR:
		self.blank_map.set_cellv(abs_cellv, 0)
		map.set_cellv(abs_cellv if absolute else cellv, id)


func draw_move(cellv: Vector2, id: int):
	self.set_neighbor_if_open(self.move_map, cellv, id, false)


func draw_moves():
	self.draw_move(Vector2.LEFT, 7 - self.side_left)
	self.draw_move(Vector2.RIGHT, self.side_left)
	self.draw_move(Vector2.UP, 7 - self.side_up)
	self.draw_move(Vector2.DOWN, self.side_up)


func clear_maps():
	self.blank_map.clear()
	self.move_map.clear()
	self.hit_map.clear()


func hitv(cellv: Vector2):
	self.set_neighbor_if_open(self.hit_map, cellv, 0)
	var enemy = self.main.enemy_map.get(self.cellv + cellv)
	if enemy != null:
		enemy.hurt(1)


func hit(x: int, y: int):
	self.hitv(Vector2(x, y))


func attack(cellv: Vector2):
	match side:
		1:
			self.hitv(cellv)
		2:
			self.hit(-1, -1)
			self.hit(1, 1)
		3:
			self.hit(-1, 1)
			self.hit(1, -1)
		4:
			self.hit(0, -1)
			self.hit(0, 1)
			self.hit(-1, 0)
			self.hit(1, 0)
		5:
			self.hit(-1, -1)
			self.hit(-1, 1)
			self.hit(1, -1)
			self.hit(1, 1)
		6:
			self.hit(-1, -1)
			self.hit(-1, 0)
			self.hit(-1, 1)
			self.hit(1, -1)
			self.hit(1, 0)
			self.hit(1, 1)


func roll(cellv: Vector2) -> bool:
	# Vector must be orthogonal and length 1
	assert(cellv.is_normalized() and (cellv.x == 0 or cellv.y == 0))

	var new_cellv := self.cellv + cellv
	if self.tile_map.get_cellv(new_cellv) == self.main.TILE_WIN:
		self.win()
		return false

	if not self.main.is_cell_open(new_cellv):
		return false

	self.clear_maps()

	self.cellv = new_cellv
	var new_room: MapRoom = self.main.get_room(self.cellv)
	if new_room.x >= self.max_room.x and new_room.y >= self.max_room.y:
		self.max_room = new_room

	self.set_sides(cellv)
	self.draw_moves()
	self.sprite.frame = self.side - 1
	self.attack(cellv)

	return true


func die():
	self.sprite.visible = false
	self.restart_label.visible = true
	self.clear_maps()
	self.set_process_input(false)


func hurt(amount: int):
	self.health -= amount
	self.draw_health()
	if self.health <= 0:
		self.die()


func win():
	self.win_label.visible = true
	self.restart_label.visible = true


func input(event) -> bool:
	if event.is_action_pressed("move_left"):
		return self.roll(Vector2.LEFT)
	if event.is_action_pressed("move_right"):
		return self.roll(Vector2.RIGHT)
	if event.is_action_pressed("move_up"):
		return self.roll(Vector2.UP)
	if event.is_action_pressed("move_down"):
		return self.roll(Vector2.DOWN)
	if event.is_action_pressed("wait"):
		return true
	return false


func draw_health():
	for i in range(MAX_HEALTH):
		self.health_map.set_cell(i, 0, 0 if i < health else 1)


func setup():
	self.health = MAX_HEALTH
	self.side = 1
	self.side_left = 4
	self.side_up = 5
	self.sprite.visible = true
	self.restart_label.visible = false
	self.win_label.visible = false
	self.max_room = self.main.rooms[0]
	self.set_process_input(true)
	self.clear_maps()
	self.draw_moves()
	self.draw_health()


func _input(event):
	if self.input(event):
		self.main.update()


func _process(delta):
	self.position = lerp(
		self.position,
		self.tile_map.map_to_world(self.cellv),
		delta * self.MOVE_SPEED
	)
