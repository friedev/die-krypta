class_name DicePreview extends Node2D

signal move_requested(coords: Vector2i)

@export var face_preview_scene: PackedScene
# Gray is more readable than translucent
@export var path_modulate := Color(0.5, 0.5, 0.5)

# TODO typed dictionary Vector2i -> FacePreview
@onready var face_previews := {
	Vector2i.LEFT: $Left,
	Vector2i.UP: $Up,
	Vector2i.DOWN: $Down,
	Vector2i.RIGHT: $Right,
}

var base_coords: Vector2i
var base_dice := Dice.new()

var coords: Vector2i:
	set(value):
		coords = value
		self.update_position()

var dice := Dice.new()

var path: Array[Vector2i] = []
# TODO typed dictionary Vector2i -> FacePreview
var face_preview_path := {}

var dragging := false
var dragged := false


func get_face_data(face_index: int) -> FaceData:
	return Globals.main.player.get_face_data(face_index)


func update_position() -> void:
	self.position = Vector2(
		Globals.main.tile_map.tile_set.tile_size
		* (self.coords - self.base_coords)
	)


func set_base_state(new_base_coords: Vector2i, new_base_dice: Dice) -> void:
	self.base_coords = new_base_coords
	self.base_dice.copy_from(new_base_dice)
	self.update_position()


func reset_to_base_state() -> void:
	self.coords = self.base_coords
	self.dice.copy_from(self.base_dice)
	self.path.clear()
	for face_preview in self.face_preview_path.values():
		face_preview.queue_free()
	self.face_preview_path.clear()
	self.draw_faces()


func draw_face(direction: Vector2i, face_index: int) -> void:
	var face_preview: FacePreview = self.face_previews[direction]

	# Don't draw on top of the previous cell in the path, since it'll be the
	# same face, or it's die itself
	var move_coords := self.coords + direction
	if self.is_previous_cell_in_path(move_coords):
		face_preview.hide()
		return

	face_preview.show()
	face_preview.face_data = self.get_face_data(face_index)

	# When previewing a path, preview faces on all floor cells, even if they are
	# *currently* occupied by other entities
	# Otherwise, only preview legal moves
	if self.coords == self.base_coords:
		face_preview.visible = Globals.main.is_cell_open(move_coords)
	else:
		face_preview.visible = Globals.main.is_floor(move_coords)


func draw_faces() -> void:
	self.show()
	self.draw_face(Vector2i.LEFT, 7 - self.dice.face_left)
	self.draw_face(Vector2i.RIGHT, self.dice.face_left)
	self.draw_face(Vector2i.UP, 7 - self.dice.face_up)
	self.draw_face(Vector2i.DOWN, self.dice.face_up)


func is_previous_cell_in_path(test_coords: Vector2i) -> bool:
	return (
		(len(self.path) > 1 and test_coords == self.path[len(self.path) - 2])
		or (len(self.path) == 1 and test_coords == self.base_coords)
	)


func roll(direction: Vector2i) -> bool:
	var new_coords := self.coords + direction
	if not Globals.main.is_floor(new_coords):
		return false

	self.coords = new_coords
	self.dice.roll(direction)

	# If you backtrack to the cell you just came from, erase the path back to
	# that point
	var face_preview: FacePreview
	if self.is_previous_cell_in_path(new_coords):
		# If you backtrack from a cell that was also part of the path even
		# further back, show the previously covered-up face
		var old_coords: Vector2i = self.path.pop_back()
		face_preview = self.face_preview_path[old_coords]
		if not face_preview.pop_face():
			face_preview.queue_free()
			face_preview = null
			self.face_preview_path.erase(old_coords)
	else:
		self.path.append(new_coords)
		var new_face_data := self.get_face_data(self.dice.face_center)

		# If you plot out a path that crosses itself, show only the most recent
		# face on the overlapping spot, but keep track of the replaced face
		face_preview = self.face_preview_path.get(new_coords)
		if face_preview != null:
			face_preview.push_face(new_face_data)
		else:
			face_preview = self.face_preview_scene.instantiate()
			face_preview.modulate = self.path_modulate
			face_preview.global_position = self.global_position
			face_preview.face_data = new_face_data
			self.face_preview_path[new_coords] = face_preview
			SignalBus.node_spawned.emit(face_preview)

	self.draw_faces()
	return true


func start_mouse_preview(mouse_coords: Vector2i) -> void:
	var path_to_mouse := Globals.main.player.find_path_to(mouse_coords)
	if len(path_to_mouse) > 0:
		self.reset_to_base_state()
		for next_coords in path_to_mouse:
			# Skip rolling to a cell if we'rea already there
			# Refuse to preview into walls and undefined cells
			if next_coords != self.coords and Globals.main.is_floor(next_coords):
				self.roll(next_coords - self.coords)


func update_mouse_preview(mouse_coords: Vector2i) -> void:
	var relative := mouse_coords - self.coords
	while relative != Vector2i.ZERO:
		self.dragged = true
		var direction: Vector2i
		# Go toward the mouse coords in the direction that currently has the
		# most extreme magnitude
		if abs(relative.x) > abs(relative.y):
			direction = Vector2i(signi(relative.x), 0)
		else:
			direction = Vector2i(0, signi(relative.y))
		
		if self.roll(direction):
			relative = mouse_coords - self.coords
		else:
			# Give up if we run into a wall
			break


func request_follow_path() -> void:
	if len(self.path) > 0:
		self.move_requested.emit(self.path[0])


func confirm_follow_path() -> void:
	# We moved to the first cell on the path, so delete it (and its sprite)
	var move_coords: Vector2i = self.path.pop_front()
	var face_preview: FacePreview = self.face_preview_path.get(move_coords)
	if face_preview != null:
		face_preview.queue_free()
	self.face_preview_path.erase(move_coords)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and self.dragging:
		self.update_mouse_preview(Globals.main.get_mouse_coords())
	elif event.is_action_pressed("preview_mouse"):
		var mouse_coords := Globals.main.get_mouse_coords()
		self.dragging = true
		self.dragged = false
		# Click the die to reset the preview
		if mouse_coords == self.base_coords:
			self.reset_to_base_state()
		# If you start dragging from the last cell on the path, continue it
		# Otherwise, pathfind to the clicked cell and go from there.
		elif mouse_coords != self.coords:
			self.start_mouse_preview(mouse_coords)
			self.dragged = true
	elif event.is_action_released("preview_mouse"):
		self.dragging = false
		# If you simply click the last cell on the path, take that as a
		# "confirmation" to start following the path
		if (
			not self.dragged
			and Globals.main.get_mouse_coords() == self.coords
			and self.coords != self.base_coords
		):
			self.request_follow_path()
	elif event.is_action_pressed("preview_move_left"):
		self.roll(Vector2i.LEFT)
	elif event.is_action_pressed("preview_move_right"):
		self.roll(Vector2i.RIGHT)
	elif event.is_action_pressed("preview_move_up"):
		self.roll(Vector2i.UP)
	elif event.is_action_pressed("preview_move_down"):
		self.roll(Vector2i.DOWN)
	elif event.is_action_pressed("reset_preview"):
		self.reset_to_base_state()
	elif event.is_action_pressed("follow_preview_path"):
		self.request_follow_path()
