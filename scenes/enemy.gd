class_name Enemy extends Node2D

signal died(enemy: Enemy)

@export var move_speed: float

@export var sprite: Sprite2D
@export var hurt_particles: GPUParticles2D
@export var death_sound: AudioStreamPlayer2D

var main: Main
var tile_map: TileMapLayer
var player: Player

var prev_coords: Vector2i
var coords: Vector2i


func movev(coords: Vector2i) -> bool:
	var new_coords := self.coords + coords
	if not self.main.is_cell_open(new_coords):
		return false
	self.coords = new_coords
	return true


func move(x: int, y: int) -> bool:
	return self.movev(Vector2i(x, y))


func chase_player() -> void:
	var dy := player.coords.y - self.coords.y
	var dx := player.coords.x - self.coords.x
	var x_dir := int(dx / maxi(1, absi(dx)))
	var y_dir := int(dy / maxi(1, absi(dy)))
	var x_first := absi(dx) > absi(dy) or (absi(dx) == absi(dy) and randi() % 2 == 0)
	if x_first:
		self.move(x_dir, 0) or self.move(0, y_dir)
	else:
		self.move(0, y_dir) or self.move(x_dir, 0)


func update() -> void:
	if (self.player.coords - self.coords).length() == 1.0:
		self.player.hurt(1, self.player.coords - self.coords)
	else:
		self.chase_player()


func die() -> void:
	self.main.enemy_map.erase(self.coords)
	self.main.enemies.erase(self)
	self.sprite.visible = false
	self.prev_coords = self.coords

	self.death_sound.pitch_scale = randf() + 0.75
	self.death_sound.play()

	self.died.emit(self)


func hurt(amount: int, direction := Vector2i()) -> void:
	self.hurt_particles.rotation = Vector2(direction).angle()
	self.hurt_particles.restart()

	self.die()


func _ready() -> void:
	assert(self.main != null)
	assert(self.tile_map != null)
	assert(self.player != null)


func _process(delta: float) -> void:
	self.position = self.position.lerp(
		self.tile_map.map_to_local(
			self.coords
			if self.main.animate_enemies
			else self.prev_coords
		),
		delta * self.move_speed
	)


func _on_DeathSound_finished() -> void:
	self.queue_free()
