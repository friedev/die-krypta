class_name ProjectileLauncher extends Node

signal projectile_hit_target

@export var projectile_scene: PackedScene
@export var aim_line: Line2D


func prepare_shot(from_coords: Vector2i, direction: Vector2i) -> void:
	var target_coords := Globals.main.raycast(from_coords, direction)
	self.aim_line.add_point(Vector2.ZERO)
	self.aim_line.add_point(
		Globals.main.tile_map.map_to_local(target_coords - from_coords)
		- Vector2(Globals.main.tile_map.tile_set.tile_size) * 0.5
	)


func shoot(from_coords: Vector2i, direction: Vector2i, damage: int) -> void:
	var projectile := self.projectile_scene.instantiate() as Projectile

	var target_coords := Globals.main.raycast(from_coords, direction)
	var target_entity: Entity = Globals.main.entity_map.get(target_coords)
	if target_entity != null:
		projectile.target_entity = target_entity
	else:
		projectile.target_position = Globals.main.tile_map.map_to_local(target_coords)

	projectile.damage = damage
	projectile.global_position = self.global_position
	projectile.hit_target.connect(self._on_projectile_hit_target)
	SignalBus.node_spawned.emit(projectile)

	self.aim_line.clear_points()


func _on_projectile_hit_target() -> void:
	self.projectile_hit_target.emit()
