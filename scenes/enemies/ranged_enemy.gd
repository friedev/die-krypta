class_name RangedEnemy extends Enemy

@export var ranged_damage := 1
@export var projectile_scene: PackedScene

var ready_to_shoot := false
var shoot_direction: Vector2i


func update() -> void:
	super.update()
	if self.health == 0 or self.main.player.health == 0:
		return
	if self.ready_to_shoot:
		self.shoot()
	elif not self.line_up_shot():
		self.chase_player()


func get_direction(p1: Vector2i, p2: Vector2i) -> Vector2i:
	assert(p1 != p2)
	if p1.x == p2.x:
		if p1.y > p2.y:
			return Vector2.UP
		else:
			return Vector2.DOWN
	else:
		assert(p1.y == p2.y)
		if p1.x > p2.x:
			return Vector2.LEFT
		else:
			return Vector2.RIGHT


func check_line_of_sight(p1: Vector2i, p2: Vector2i) -> bool:
	assert(p1 != p2)
	var line_of_sight: bool
	if p1.x == p2.x:
		line_of_sight = true
		var start_y := p1.y + 1 if p2.y > p1.y else p1.y - 1
		for y in range(start_y, p2.y):
			if not self.main.is_cell_open(Vector2i(p1.x, y)):
				line_of_sight = false
				break

		if line_of_sight:
			return true

	if p1.y == p2.y:
		line_of_sight = true
		var start_x := p1.x + 1 if p2.x > p1.x else p1.x - 1
		for x in range(start_x, p2.x):
			if not self.main.is_cell_open(Vector2i(x, p1.y)):
				line_of_sight = false
				break

		if line_of_sight:
			return true
	
	return false


func prepare_shot() -> void:
	self.face_toward(self.main.player.coords)
	self.shoot_direction = self.get_direction(self.coords, self.main.player.coords)
	self.ready_to_shoot = true
	self.aim_line.add_point(Vector2.ZERO)
	self.aim_line.add_point(
		self.main.tile_map.map_to_local(self.main.player.coords - self.coords)
		- Vector2(self.main.tile_map.tile_set.tile_size) * 0.5
	)


func get_projectile_collision() -> Vector2i:
	var p := self.coords + self.shoot_direction
	while self.main.is_cell_open(p):
		p += self.shoot_direction
	return p


func shoot() -> void:
	var projectile := self.projectile_scene.instantiate() as Projectile

	var target_coords := self.get_projectile_collision()
	var target_entity: Entity = self.main.entity_map.get(target_coords)
	if target_entity != null:
		target_entity.hurt(1, target_coords - self.coords)
		projectile.target_entity = target_entity
	else:
		projectile.target_position = self.main.tile_map.map_to_local(target_coords)

	projectile.global_position = self.global_position
	SignalBus.node_spawned.emit(projectile)

	self.ready_to_shoot = false
	self.aim_line.clear_points()


func line_up_shot() -> bool:
	if self.check_line_of_sight(self.coords, self.main.player.coords):
		self.prepare_shot()
		return true

	for direction in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	] as Array[Vector2i]:
		var p := self.coords + direction
		if (
			self.main.is_cell_open(p)
			and self.check_line_of_sight(p, self.main.player.coords)
			and self.move(p)
		):
			self.prepare_shot()
			return true

	return false
