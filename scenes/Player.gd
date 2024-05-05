class_name Player extends Node2D

signal won
signal died
signal health_changed(health: int)

const MOVE_SPEED := 15.0
const MAX_HEALTH := 3
const HIT_STRESS := 0.5
const HURT_STRESS := 0.5

@export var main: Main
@export var tile_map: TileMap

@export var sprite: AnimatedSprite2D
@export var attacks: Node2D
@export var side_icons: Node2D
@export var camera: Camera2D
@export var hurt_particles: GPUParticles2D
@export var move_sound: AudioStreamPlayer2D
@export var hurt_sound: AudioStreamPlayer2D

@onready var attack_animations = [
	[$Attacks/LeftUp,   $Attacks/Up,   $Attacks/RightUp  ],
	[$Attacks/Left,     null,          $Attacks/Right    ],
	[$Attacks/LeftDown, $Attacks/Down, $Attacks/RightDown],
]

@onready var side_icon_sprites = [
	[null,            $SideIcons/Up,   null            ],
	[$SideIcons/Left, null,            $SideIcons/Right],
	[null,            $SideIcons/Down, null            ],
]

var cellv: Vector2
var side := 1
var side_left := 4
var side_up := 5
var max_room: MapRoom = null

var health := MAX_HEALTH:
	set(value):
		health = value
		self.health_changed.emit(self.health)



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


func draw_move(cellv: Vector2, move: int):
	var abs_cellv := self.cellv + cellv
	var side_icon := self.side_icon_sprites[cellv.y + 1][cellv.x + 1] as AnimatedSprite2D
	if (
		self.tile_map.get_cell_source_id(0, abs_cellv) == self.main.TILE_FLOOR
		and not self.main.enemy_map.has(abs_cellv)
	):
		side_icon.show()
		side_icon.frame = move - 1
	else:
		side_icon.hide()


func draw_moves():
	self.draw_move(Vector2.LEFT, 7 - self.side_left)
	self.draw_move(Vector2.RIGHT, self.side_left)
	self.draw_move(Vector2.UP, 7 - self.side_up)
	self.draw_move(Vector2.DOWN, self.side_up)


func stop_animations():
	for animation in self.attacks.get_children():
		animation.stop()
		animation.visible = false


func hitv(hit_cellv: Vector2 = Vector2()) -> bool:
	var animation: AnimatedSprite2D = self.attack_animations[hit_cellv.y + 1][hit_cellv.x + 1]
	animation.visible = true
	animation.frame = 0
	animation.play()

	var enemy = self.main.enemy_map.get(self.cellv + hit_cellv)
	if enemy != null:
		enemy.hurt(1, (enemy.cellv - self.cellv).normalized())
		self.camera.add_stress(0.5)
		return true
	else:
		return false


func hit(x: int, y: int) -> bool:
	return self.hitv(Vector2(x, y))


func attack(cellv: Vector2) -> bool:
	var attacked := false
	var cells := []

	match side:
		1:
			cells = [cellv]
		2:
			cells = [
				Vector2(-1, -1),
				Vector2(1, 1),
			]
		3:
			cells = [
				Vector2(-1, 1),
				Vector2(1, -1),
			]
		4:
			cells = [
				Vector2(0, -1),
				Vector2(0, 1),
				Vector2(-1, 0),
				Vector2(1, 0),
			]
		5:
			cells = [
				Vector2(-1, -1),
				Vector2(-1, 1),
				Vector2(1, -1),
				Vector2(1, 1),
			]
		6:
			cells = [
				Vector2(-1, -1),
				Vector2(-1, 0),
				Vector2(-1, 1),
				Vector2(1, -1),
				Vector2(1, 0),
				Vector2(1, 1),
			]

	for hit_cellv in cells:
		attacked = self.hitv(hit_cellv) or attacked

	return attacked


func roll(cellv: Vector2) -> bool:
	# Vector must be orthogonal and length 1
	assert(cellv.is_normalized() and (cellv.x == 0 or cellv.y == 0))

	var new_cellv := self.cellv + cellv
	if self.tile_map.get_cell_source_id(0, new_cellv) == self.main.TILE_WIN:
		self.win()
		return false

	if not self.main.is_cell_open(new_cellv):
		return false

	self.stop_animations()

	self.cellv = new_cellv
	var new_room: MapRoom = self.main.get_room(self.cellv)
	if new_room.x >= self.max_room.x and new_room.y >= self.max_room.y:
		self.max_room = new_room

	self.set_sides(cellv)
	self.sprite.frame = self.side - 1

	if self.attack(cellv):
		self.main.animate_enemies = false
	else:
		self.main.animate_enemies = true
		self.stop_animations()

	self.move_sound.pitch_scale = randf() * 0.5 + 0.75
	self.move_sound.play()

	return true


func die():
	self.sprite.visible = false
	self.attacks.visible = false
	self.side_icons.visible = false
	self.stop_animations()

	self.set_process_input(false)

	self.died.emit()


func hurt(amount: int, direction: Vector2):
	self.health -= amount

	self.camera.add_stress(self.HURT_STRESS)
	self.hurt_particles.rotation = direction.angle()
	self.hurt_particles.restart()
	self.hurt_sound.pitch_scale = randf() * 0.5 + 0.75
	self.hurt_sound.play()

	if self.health <= 0:
		self.die()


func win():
	self.won.emit()


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
		self.main.animate_enemies = true
		return true
	return false


func setup():
	self.health = MAX_HEALTH
	self.side = 1
	self.side_left = 4
	self.side_up = 5
	self.sprite.visible = true
	self.attacks.visible = true
	self.side_icons.visible = true
	self.max_room = self.main.rooms[0]
	self.set_process_input(true)
	self.stop_animations()
	self.draw_moves()


func _input(event):
	if self.input(event):
		self.main.update()


func _process(delta):
	self.position = lerp(
		self.position,
		self.tile_map.map_to_local(self.cellv),
		delta * self.MOVE_SPEED
	)


func _on_animation_finished():
	self.stop_animations()
	self.main.animate_enemies = true

