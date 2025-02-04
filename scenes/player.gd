class_name Player extends Entity

signal moved

@export var move_speed: float
@export var hit_stress: float
@export var hurt_stress: float

@export var sprite: AnimatedSprite2D
@export var attacks: Node2D
@export var side_icons: Node2D
@export var camera: ShakeCamera
@export var hurt_particles: GPUParticles2D
@export var move_sound: AudioStreamPlayer2D
@export var hurt_sound: AudioStreamPlayer2D
@export var move_timer: Timer

# TODO typed dictionary Vector2i -> AnimatedSprite2D
@onready var attack_animations := {
	Vector2i(-1, -1): $Attacks/LeftUp,
	Vector2i(-1,  0): $Attacks/Left,
	Vector2i(-1,  1): $Attacks/LeftDown,
	Vector2i( 0, -1): $Attacks/Up,
	Vector2i( 0,  1): $Attacks/Down,
	Vector2i( 1, -1): $Attacks/RightUp,
	Vector2i( 1,  0): $Attacks/Right,
	Vector2i( 1,  1): $Attacks/RightDown,
}

# TODO typed dictionary Vector2i -> AnimatedSprite2D
@onready var side_icon_sprites := {
	Vector2i.LEFT: $SideIcons/Left,
	Vector2i.UP: $SideIcons/Up,
	Vector2i.DOWN: $SideIcons/Down,
	Vector2i.RIGHT: $SideIcons/Right,
}

var side := 1
var side_left := 4
var side_up := 5
var last_action: StringName


func set_sides(coords: Vector2i) -> void:
	var old_side := self.side
	if coords == Vector2i.LEFT:
		self.side = 7 - self.side_left
		self.side_left = old_side
	elif coords == Vector2i.RIGHT:
		self.side = self.side_left
		self.side_left = 7 - old_side
	elif coords == Vector2i.UP:
		self.side = 7 - self.side_up
		self.side_up = old_side
	elif coords == Vector2i.DOWN:
		self.side = self.side_up
		self.side_up = 7 - old_side


func draw_move(coords: Vector2i, move: int) -> void:
	var abs_coords := self.coords + coords
	var side_icon := self.side_icon_sprites[coords] as AnimatedSprite2D
	if self.main.is_cell_open(abs_coords):
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


func hit(hit_coords := Vector2i()) -> bool:
	var animation := self.attack_animations[hit_coords] as AnimatedSprite2D
	animation.visible = true
	animation.frame = 0
	animation.play()

	var hit_entity: Entity = self.main.entity_map.get(self.coords + hit_coords)
	if hit_entity != null:
		hit_entity.hurt(1, (hit_entity.coords - self.coords))
		self.camera.shake += self.hit_stress
		return true
	else:
		return false


func attack(coords: Vector2i) -> bool:
	var attacked := false
	var cells: Array[Vector2i] = []

	match side:
		1:
			cells = [coords]
		2:
			cells = [
				Vector2i(-1, -1),
				Vector2i( 1,  1),
			]
		3:
			cells = [
				Vector2i(-1,  1),
				Vector2i( 1, -1),
			]
		4:
			cells = [
				Vector2i( 0, -1),
				Vector2i( 0,  1),
				Vector2i(-1,  0),
				Vector2i( 1,  0),
			]
		5:
			cells = [
				Vector2i(-1, -1),
				Vector2i(-1,  1),
				Vector2i( 1, -1),
				Vector2i( 1,  1),
			]
		6:
			cells = [
				Vector2i(-1, -1),
				Vector2i(-1,  0),
				Vector2i(-1,  1),
				Vector2i( 1, -1),
				Vector2i( 1,  0),
				Vector2i( 1,  1),
			]

	for hit_coords in cells:
		attacked = self.hit(hit_coords) or attacked

	return attacked


func roll(coords: Vector2i) -> bool:
	# Vector must be orthogonal and length 1
	assert(coords.length() == 1 and (coords.x == 0 or coords.y == 0))

	var new_coords := self.coords + coords

	if not self.main.is_cell_open(new_coords):
		return false

	self.stop_animations()

	self.coords = new_coords

	self.set_sides(coords)
	self.sprite.frame = self.side - 1

	if self.attack(coords):
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
	if target == self.coords:
		return self.wait()

	# Try to move along the axis of greater distance toward the target
	# Failing that, move along the axis of lesser distance
	var delta := target - self.coords
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

	super.die()


func hurt(amount: int, direction: Vector2i) -> void:
	self.camera.shake += self.hurt_stress
	self.hurt_particles.rotation = Vector2(direction).angle()
	self.hurt_particles.restart()
	self.hurt_sound.pitch_scale = randf() * 0.5 + 0.75
	self.hurt_sound.play()

	super.hurt(amount, direction)


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
				self.main.tile_map.local_to_map(self.main.tile_map.get_local_mouse_position())
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
	super.setup()

	self.side = 1
	self.side_left = 4
	self.side_up = 5
	self.show()
	self.sprite.show()
	self.attacks.show()
	for attack_animation in self.attack_animations.values():
		attack_animation.hide()
	self.side_icons.show()
	self.set_process_input(true)
	self.stop_animations()


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
		self.main.tile_map.map_to_local(self.coords),
		delta * self.move_speed
	)


func _on_animation_finished() -> void:
	self.stop_animations()
	self.main.animate_enemies = true
