class_name ProjectileTrap extends Entity

@export var damage := 1
@export var sprite: Sprite2D
@export var projectile_launcher: ProjectileLauncher

## If true, will shoot the turn after an entity enters its line of sight.
## If false, will shoot repeatedly, waiting turns_between_shots between shots.
@export var detect_targets := true
@export var turns_between_shots := 1

var direction: Vector2i
var ready_to_shoot := false
var turns_until_shot: int

func _ready() -> void:
	super._ready()
	self.sprite.rotation += Vector2(self.direction).angle()

	# Hack: ensure there is always a border along the top left edge of the sprite
	if self.direction == Vector2i.RIGHT:
		self.sprite.position += Vector2.RIGHT
	elif self.direction == Vector2i.LEFT:
		self.sprite.position += Vector2.DOWN
	elif self.direction == Vector2i.DOWN:
		self.sprite.position += Vector2.ONE

	self.projectile_launcher.layer = self.layer
	self.projectile_launcher.projectile_hit_target.connect(self._on_projectile_hit_target)


func get_target_entity() -> Entity:
	var target_coords := Globals.main.raycast(self.coords, self.direction)
	var target_entity: Entity = Globals.main.entity_maps[self.layer].get(target_coords)
	if target_entity is Player or target_entity is Enemy:
		return target_entity
	return null


func update() -> void:
	# TODO merge logic with TileTrap
	if self.detect_targets:
		if self.ready_to_shoot:
			self.shoot()
		else:
			if self.get_target_entity() != null:
				self.prepare_shot()
			self.done.emit()
	else:
		if self.turns_until_shot > 0:
			self.turns_until_shot -= 1
			if self.turns_until_shot == 0:
				self.prepare_shot()
			self.done.emit()
		else:
			self.shoot()
			self.turns_until_shot = self.turns_between_shots


func prepare_shot() -> void:
	self.ready_to_shoot = true
	self.projectile_launcher.prepare_shot(self.coords, self.direction)


func shoot() -> void:
	self.ready_to_shoot = false
	self.projectile_launcher.shoot(self.coords, self.direction, self.damage)


func _on_projectile_hit_target() -> void:
	self.done.emit()


func get_texture() -> Texture2D:
	return self.sprite.texture