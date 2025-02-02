class_name Player extends Node2D

signal won
signal died
signal health_changed(health: int)
signal moved

@export var move_speed: float
@export var max_health: int
@export var hit_stress: float
@export var hurt_stress: float

@export var main: Main
@export var tile_map: TileMapLayer

@export var sprite: AnimatedSprite2D
@export var attacks: Node2D
@export var side_icons: Node2D
@export var camera: ShakeCamera
@export var hurt_particles: GPUParticles2D
@export var move_sound: AudioStreamPlayer2D
@export var hurt_sound: AudioStreamPlayer2D
@export var move_timer: Timer

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

var cellv: Vector2i
var side := 1
var side_left := 4
var side_up := 5
var max_room: MapRoom = null
var last_action: StringName

var health: int:
	set(value):
		health = value
		self.health_changed.emit(self.health)


func set_sides(cellv: Vector2i) -> void:
	var old_side := self.side
	if cellv == Vector2i.LEFT:
		self.side = 7 - self.side_left
		self.side_left = old_side
	elif cellv == Vector2i.RIGHT:
		self.side = self.side_left
		self.side_left = 7 - old_side
	elif cellv == Vector2i.UP:
		self.side = 7 - self.side_up
		self.side_up = old_side
	elif cellv == Vector2i.DOWN:
		self.side = self.side_up
		self.side_up = 7 - old_side


func draw_move(cellv: Vector2i, move: int) -> void:
	var abs_cellv := self.cellv + cellv
	var side_icon := self.side_icon_sprites[cellv.y + 1][cellv.x + 1] as AnimatedSprite2D
	if (
		self.tile_map.get_cell_source_id(abs_cellv) == self.main.TILE_FLOOR
		and not self.main.enemy_map.has(abs_cellv)
	):
		side_icon.show()
		side_icon.frame = move - 1
	else:
		side_icon.hide()


func draw_moves() -> void:
	self.draw_move(Vector2i.LEFT, 7 - self.side_left)
	self.draw_move(Vector2i.RIGHT, self.side_left)
	self.draw_move(Vector2i.UP, 7 - self.side_up)
	self.draw_move(Vector2i.DOWN, self.side_up)


func stop_animations() -> void:
	for animation: AnimatedSprite2D in self.attacks.get_children():
		animation.stop()
		animation.visible = false


func hitv(hit_cellv := Vector2i()) -> bool:
	var animation := self.attack_animations[hit_cellv.y + 1][hit_cellv.x + 1] as AnimatedSprite2D
	animation.visible = true
	animation.frame = 0
	animation.play()

	var enemy := self.main.enemy_map.get(self.cellv + hit_cellv) as Enemy
	if enemy != null:
		enemy.hurt(1, (enemy.cellv - self.cellv))
		self.camera.shake += self.hit_stress
		return true
	else:
		return false


func attack(cellv: Vector2i) -> bool:
	var attacked := false
	var cells: Array[Vector2i] = []

	match side:
		1:
			cells = [cellv]
		2:
			cells = [
				Vector2i(-1, -1),
				Vector2i(1, 1),
			]
		3:
			cells = [
				Vector2i(-1, 1),
				Vector2i(1, -1),
			]
		4:
			cells = [
				Vector2i(0, -1),
				Vector2i(0, 1),
				Vector2i(-1, 0),
				Vector2i(1, 0),
			]
		5:
			cells = [
				Vector2i(-1, -1),
				Vector2i(-1, 1),
				Vector2i(1, -1),
				Vector2i(1, 1),
			]
		6:
			cells = [
				Vector2i(-1, -1),
				Vector2i(-1, 0),
				Vector2i(-1, 1),
				Vector2i(1, -1),
				Vector2i(1, 0),
				Vector2i(1, 1),
			]

	for hit_cellv in cells:
		attacked = self.hitv(hit_cellv) or attacked

	return attacked


func roll(cellv: Vector2i) -> bool:
	# Vector must be orthogonal and length 1
	assert(cellv.length() == 1 and (cellv.x == 0 or cellv.y == 0))

	var new_cellv := self.cellv + cellv
	if self.tile_map.get_cell_source_id(new_cellv) == self.main.TILE_WIN:
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


func wait() -> bool:
	self.main.animate_enemies = true
	return true


func roll_toward(target: Vector2i) -> bool:
	if target == self.cellv:
		return self.wait()

	# Try to move along the axis of greater distance toward the target
	# Failing that, move along the axis of lesser distance
	var delta := target - self.cellv
	var x_direction := Vector2i(clampi(delta.x, -1, 1), 0)
	var y_direction := Vector2i(0, clampi(delta.y, -1, 1))
	var direction_priority: Array[Vector2i]
	if delta.abs().x >= delta.abs().y:
		direction_priority = [x_direction, y_direction]
	else:
		direction_priority = [y_direction, x_direction]

	for direction in direction_priority:
		if direction != Vector2i.ZERO and self.roll(direction):
			return true
	return false


func die() -> void:
	self.sprite.hide()
	self.attacks.hide()
	self.side_icons.hide()
	self.stop_animations()

	self.set_process_input(false)

	self.died.emit()


func hurt(amount: int, direction: Vector2i) -> void:
	self.health -= amount

	self.camera.shake += self.hurt_stress
	self.hurt_particles.rotation = Vector2(direction).angle()
	self.hurt_particles.restart()
	self.hurt_sound.pitch_scale = randf() * 0.5 + 0.75
	self.hurt_sound.play()

	if self.health <= 0:
		self.die()


func win() -> void:
	self.won.emit()


func handle_input(action: StringName) -> void:
	if Globals.is_menu_open:
		return

	var success: bool
	match action:
		&"move_left":
			success = self.roll(Vector2i.LEFT)
		&"move_right":
			success = self.roll(Vector2i.RIGHT)
		&"move_up":
			success = self.roll(Vector2i.UP)
		&"move_down":
			success = self.roll(Vector2i.DOWN)
		&"wait":
			success = self.wait()
		&"mouse_move":
			success = self.roll_toward(
				self.tile_map.local_to_map(self.tile_map.get_local_mouse_position())
			)
		_:
			push_error("Unknown action %s" % action)
			success = false

	if success:
		self.moved.emit()

	self.last_action = action
	self.move_timer.start()


func _on_move_timer_timeout() -> void:
	# If the last action is still held down, repeat it
	if Input.is_action_pressed(self.last_action):
		self.handle_input(self.last_action)
		self.move_timer.start()


func setup() -> void:
	self.health = self.max_health
	self.side = 1
	self.side_left = 4
	self.side_up = 5
	self.show()
	self.sprite.show()
	self.attacks.show()
	self.side_icons.show()
	self.max_room = self.main.rooms[0]
	self.set_process_input(true)
	self.stop_animations()
	self.draw_moves()


func _input(event: InputEvent) -> void:
	var action_order: Array[StringName] = [
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
		&"wait",
		&"mouse_move"
	]
	for action in action_order:
		if event.is_action_pressed(action):
			self.handle_input(action)
			break


func _process(delta: float) -> void:
	self.position = self.position.lerp(
		self.tile_map.map_to_local(self.cellv),
		delta * self.move_speed
	)


func _on_animation_finished() -> void:
	self.stop_animations()
	self.main.animate_enemies = true
