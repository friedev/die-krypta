class_name Enemy extends Entity

@export var difficulty: int
@export var move_speed: float

@export var sprite: Sprite2D
@export var hurt_particles: GPUParticles2D
@export var death_sound: RandomPitchSound
@export var damage_sound: RandomPitchSound

var player: Player

var prev_coords: Vector2i


func face_toward(target: Vector2i) -> void:
	if target.x > self.coords.x:
		self.sprite.flip_h = true
		self.sprite.offset.x = +1
	elif target.x < self.coords.x:
		self.sprite.flip_h = false
		self.sprite.offset.x = 0


func move(new_coords: Vector2i) -> bool:
	if not Globals.main.is_cell_open(new_coords):
		return false

	self.face_toward(new_coords)

	self.coords = new_coords

	return true


func update() -> void:
	self.prev_coords = self.coords
	self.done.emit()


func die() -> void:
	# TODO instead of disabling the node, queue_free it immediately and spawn a
	# "death effect" node to handle particles and sound
	self.remove_from_group("enemies")
	self.sprite.visible = false
	self.prev_coords = self.coords

	self.death_sound.randomize_and_play()

	super.die()


func hurt(amount: int, direction := Vector2i()) -> void:
	assert(amount > 0)
	self.hurt_particles.rotation = Vector2(direction).angle()
	self.hurt_particles.restart()

	super.hurt(amount, direction)
	if self.health > 0:
		self.damage_sound.play()


func _ready() -> void:
	self.prev_coords = coords
	self.setup()


func _process(delta: float) -> void:
	self.position = self.position.lerp(
		Globals.main.tile_map.map_to_local(self.coords),
		delta * self.move_speed
	)


func _on_DeathSound_finished() -> void:
	self.queue_free()
