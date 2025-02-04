class_name Enemy extends Entity

signal done

@export var difficulty: int
@export var move_speed: float

@export var sprite: Sprite2D
@export var aim_line: Line2D
@export var hurt_particles: GPUParticles2D
@export var death_sound: AudioStreamPlayer2D

var player: Player

var prev_coords: Vector2i


func face_toward(target: Vector2i) -> void:
	if target.x > self.coords.x:
		self.sprite.flip_h = true
	elif target.x < self.coords.x:
		self.sprite.flip_h = false


func move(new_coords: Vector2i) -> bool:
	if not self.main.is_cell_open(new_coords):
		return false

	self.face_toward(coords)

	self.coords = new_coords

	return true


# To be overridden
func update() -> void:
	self.prev_coords = self.coords
	self.done.emit()


func die() -> void:
	# TODO instead of disabling the node, queue_free it immediately and spawn a
	# "death effect" node to handle particles and sound
	self.remove_from_group("enemies")
	self.sprite.visible = false
	self.prev_coords = self.coords
	self.aim_line.hide()

	self.death_sound.pitch_scale = randf() + 0.75
	self.death_sound.play()

	super.die()


func hurt(amount: int, direction := Vector2i()) -> void:
	self.hurt_particles.rotation = Vector2(direction).angle()
	self.hurt_particles.restart()

	super.hurt(amount, direction)


func _ready() -> void:
	self.setup()


func _process(delta: float) -> void:
	self.position = self.position.lerp(
		self.main.tile_map.map_to_local(self.coords),
		delta * self.move_speed
	)


func _on_DeathSound_finished() -> void:
	self.queue_free()
