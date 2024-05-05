class_name Enemy extends Node2D

const MOVE_SPEED := 15.0

@export var sprite: Sprite2D
@export var hurt_particles: GPUParticles2D
@export var death_sound: AudioStreamPlayer2D

var main: Main
var tile_map: TileMap
var player: Player

var prev_cellv: Vector2
var cellv: Vector2
var room: MapRoom


func movev(cellv: Vector2) -> bool:
	var new_cellv := self.cellv + cellv
	if not self.main.is_cell_open(new_cellv):
		return false
	self.cellv = new_cellv
	return true


func move(x: int, y: int) -> bool:
	return self.movev(Vector2(x, y))


func chase_player():
	var dy := player.cellv.y - self.cellv.y
	var dx := player.cellv.x - self.cellv.x
	var x_dir := int(dx / max(1, abs(dx)))
	var y_dir := int(dy / max(1, abs(dy)))
	var x_first = abs(dx) > abs(dy) or (abs(dx) == abs(dy) and randi() % 2 == 0)
	if x_first:
		self.move(x_dir, 0) or self.move(0, y_dir)
	else:
		self.move(0, y_dir) or self.move(x_dir, 0)


# Checks if the player is in or past this enemy's room, or within one cell of it
func is_player_in_room():
	if self.room == null:
		return true
	if self.player.max_room == null:
		return (
			self.player.cellv.x >= self.room.x - 1
			and self.player.cellv.y >= self.room.y - 1
		)
	return (
		self.player.max_room.x >= self.room.x
		and self.player.max_room.y >= self.room.y
	)


func update():
	if (self.player.cellv - self.cellv).length() == 1.0:
		self.player.hurt(1, (self.player.cellv - self.cellv).normalized())
	elif self.is_player_in_room():
		self.chase_player()


func die():
	self.main.enemy_map.erase(self.cellv)
	self.main.enemies.erase(self)
	self.sprite.visible = false
	self.prev_cellv = self.cellv

	self.death_sound.pitch_scale = randf() + 0.75
	self.death_sound.play()


func hurt(amount: int, direction: Vector2 = Vector2()):
	self.hurt_particles.rotation = direction.angle()
	self.hurt_particles.restart()

	self.die()


func _ready():
	assert(self.main != null)
	assert(self.tile_map != null)
	assert(self.player != null)

	self.room = null

func _process(delta):
	self.position = lerp(
		self.position,
		self.tile_map.map_to_local(
			self.cellv
			if self.main.animate_enemies
			else self.prev_cellv
		),
		delta * self.MOVE_SPEED
	)


func _on_DeathSound_finished():
	self.queue_free()
