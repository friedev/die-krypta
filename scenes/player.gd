class_name Player extends Entity

const action_order: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"wait",
	&"mouse_move"
]

@export var move_speed: float
@export var hit_stress: float
@export var hurt_stress: float

@export var sprite: AnimatedSprite2D
@export var attacks: Node2D
@export var dice_preview: DicePreview
@export var camera: ShakeCamera
@export var hurt_particles: GPUParticles2D
@export var move_sound: RandomPitchSound
@export var hurt_sound: RandomPitchSound
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

var dice := Dice.new()
var last_action: StringName
var animation_playing := false


func stop_animations() -> void:
	for animation: AnimatedSprite2D in self.attacks.get_children():
		animation.stop()
		animation.visible = false
	self.animation_playing = false


func hit(hit_coords := Vector2i()) -> bool:
	var animation := self.attack_animations[hit_coords] as AnimatedSprite2D
	animation.visible = true
	animation.frame = 0
	animation.play()

	var hit_entity: Entity = Globals.main.entity_maps[self.layer].get(self.coords + hit_coords)
	if hit_entity != null and hit_entity is Enemy:
		hit_entity.hurt(1, (hit_entity.coords - self.coords))
		self.camera.shake += self.hit_stress
		return true
	else:
		return false


func attack(direction: Vector2i) -> bool:
	var attacked := false
	var cells: Array[Vector2i] = []

	match self.dice.face_center:
		1:
			cells = [direction]
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


func roll(direction: Vector2i) -> bool:
	assert(direction in Utility.orthogonal_directions, "Direction must be orthogonal")

	var new_coords := self.coords + direction

	if not Globals.main.is_cell_open(new_coords):
		return false

	self.stop_animations()

	self.coords = new_coords

	self.dice.roll(direction)
	self.sprite.frame = self.dice.face_center - 1

	if self.attack(direction):
		self.animation_playing = true
	else:
		self.stop_animations()

	self.move_sound.randomize_and_play()

	return true


func wait() -> bool:
	return true


func roll_toward(target: Vector2i) -> bool:
	# Click on yourself to skip your turn
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


func find_path_to(target: Vector2i) -> Array[Vector2i]:
	if not Globals.main.astar.is_in_boundsv(target) or target == self.coords:
		return []

	# Configure A* pathfinding
	assert(self.layer == Main.ASTAR_LAYER)
	Globals.main.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	Globals.main.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	Globals.main.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

	# Set source and destination as not solid
	# (AStarGrid2D can't pathfind to/from solid points)
	Globals.main.astar.set_point_solid(self.coords, false)
	var target_solid := Globals.main.astar.is_point_solid(target)
	Globals.main.astar.set_point_solid(target, false)

	# Calculate path
	var path := Globals.main.astar.get_id_path(self.coords, target, true)

	# Restore solidity of source and destination
	Globals.main.astar.set_point_solid(self.coords, true)
	Globals.main.astar.set_point_solid(target, target_solid)

	return path


func die() -> void:
	self.sprite.hide()
	self.attacks.hide()
	self.dice_preview.hide()
	self.stop_animations()

	self.set_process_input(false)

	super.die()


func hurt(amount: int, direction: Vector2i) -> void:
	self.camera.shake += self.hurt_stress
	self.hurt_particles.rotation = Vector2(direction).angle()
	self.hurt_particles.restart()
	self.hurt_sound.randomize_and_play()

	super.hurt(amount, direction)


func can_act() -> bool:
	return not Globals.is_menu_open and Globals.main.ready_for_input


func end_turn() -> void:
	Globals.main.ready_for_input = false
	self.dice_preview.hide()
	if not self.animation_playing:
		self.done.emit()


func handle_input(action: StringName) -> void:
	if not self.can_act():
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
				Globals.main.tile_map.local_to_map(Globals.main.tile_map.get_local_mouse_position())
			)
		_:
			push_error("Unknown action %s" % action)
			success = false

	if success:
		self.dice_preview.reset_to_base_state()
		self.end_turn()

	self.last_action = action
	self.move_timer.start()


func _on_move_timer_timeout() -> void:
	# If the last action is still held down, repeat it
	if Input.is_action_pressed(self.last_action):
		self.handle_input(self.last_action)
		self.move_timer.start()


func setup() -> void:
	super.setup()

	self.dice.face_center = 1
	self.dice.face_left = 4
	self.dice.face_up = 5

	self.show()
	self.sprite.show()
	self.attacks.show()
	for attack_animation in self.attack_animations.values():
		attack_animation.hide()
	self.set_process_input(true)
	self.stop_animations()


func _unhandled_input(event: InputEvent) -> void:
	for action in self.action_order:
		if event.is_action_pressed(action, false, true):
			self.handle_input(action)
			break


func _process(delta: float) -> void:
	self.position = self.position.lerp(
		Globals.main.tile_map.map_to_local(self.coords),
		delta * self.move_speed
	)


func _on_animation_finished() -> void:
	self.stop_animations()
	self.done.emit()


func get_texture() -> Texture2D:
	return self.sprite.sprite_frames.get_frame_texture(
		self.sprite.animation, self.sprite.frame
	)


func _on_level_started(level: int) -> void:
	self.health += 1
	self.position = Globals.main.tile_map.map_to_local(self.coords)
	self.camera.position_smoothing_enabled = false
	self.camera.force_update_scroll()
	self.camera.position_smoothing_enabled = true
	self.dice_preview.set_base_state(self.coords, self.dice)
	self.dice_preview.reset_to_base_state()


func _on_dice_preview_move_requested(new_coords: Vector2i) -> void:
	# Be careful to keep this roughly in sync with handle_input
	if self.can_act():
		var direction := new_coords - self.coords
		if self.roll(direction):
			# DON'T call reset_to_base_state() here; preserve the path
			# Instead, remove the first cell on the path (the one we just rolled to)
			self.dice_preview.confirm_follow_path()
			self.end_turn()


func _on_turn_started() -> void:
	self.dice_preview.set_base_state(self.coords, self.dice)
	if len(self.dice_preview.path) == 0:
		self.dice_preview.reset_to_base_state()
	else:
		self.dice_preview.draw_faces()