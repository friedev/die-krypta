class_name FighterEnemy extends Enemy

@export var melee_damage: int
@export var ranged_damage: int
@export var turns_between_actions: int
@export var can_move_orthogonal: bool
@export var can_move_diagonal: bool
@export var can_attack_orthogonal: bool
@export var can_attack_diagonal: bool
@export var projectile_scene: PackedScene

var ready_to_shoot := false
var shoot_direction: Vector2i

var move_directions: Array[Vector2i]
var attack_directions: Array[Vector2i]
var turns_until_action: int


func _ready() -> void:
	super._ready()
	self.turns_until_action = self.turns_between_actions
	if self.can_move_diagonal:
		self.move_directions += Utility.diagonal_directions
	if self.can_move_orthogonal:
		self.move_directions += Utility.orthogonal_directions
	if self.can_attack_diagonal:
		self.attack_directions += Utility.diagonal_directions
	if self.can_attack_orthogonal:
		self.attack_directions += Utility.orthogonal_directions


func update() -> void:
	super.update()
	if self.health == 0 or self.main.player.health == 0:
		return
	if self.turns_until_action > 0:
		self.turns_until_action -= 1
		return
	if self.act():
		self.turns_until_action = self.turns_between_actions


func act() -> bool:
	if self.ready_to_shoot:
		self.shoot()
		return true
	if self.melee_damage > self.ranged_damage and self.melee_attack():
		return true
	if self.ranged_damage > 0 and self.line_up_shot():
		return true
	if self.chase_player():
		return true
	return false


func melee_attack() -> bool:
	if not self.main.player.coords - self.coords in self.attack_directions:
		return false
	self.face_toward(self.main.player.coords)
	self.main.player.hurt(self.melee_damage, self.main.player.coords - self.coords)
	return true


func chase_player() -> bool:
	var best_coords := self.coords
	var best_distance := Utility.manhattan_distance(self.coords, self.main.player.coords)
	for move_direction in self.move_directions:
		var new_coords := self.coords + move_direction
		if self.main.is_cell_open(new_coords):
			var new_distance := Utility.manhattan_distance(new_coords, self.main.player.coords)
			if new_distance < best_distance:
				best_coords = new_coords
				best_distance = new_distance
	if best_coords != self.coords:
		self.move(best_coords)
		return true
	return false


func get_direction_to(p1: Vector2i, p2: Vector2i, directions: Array[Vector2i]) -> Vector2i:
	for direction in directions:
		if Utility.is_same_direction(p2 - p1, direction):
			return direction
	return Vector2i.ZERO


func raycast(start: Vector2i, direction: Vector2i) -> Vector2i:
	var p := start + direction
	while self.main.is_cell_open(p):
		p += direction
	return p


func has_line_of_sight(start: Vector2i, end: Vector2i, direction: Vector2i) -> bool:
	# p2 is assumed to be an occupied cell
	return self.raycast(start, direction) == end


func find_line_of_sight(start: Vector2i, end: Vector2i, directions: Array[Vector2i]) -> Vector2i:
	# p2 is assumed to be an occupied cell
	for direction in directions:
		if self.has_line_of_sight(start, end, direction):
			return direction
	return Vector2i.ZERO
	

func prepare_shot() -> void:
	self.face_toward(self.main.player.coords)
	self.shoot_direction = self.get_direction_to(self.coords, self.main.player.coords, self.attack_directions)
	assert(self.shoot_direction != Vector2i.ZERO)
	self.ready_to_shoot = true
	self.aim_line.add_point(Vector2.ZERO)
	self.aim_line.add_point(
		self.main.tile_map.map_to_local(self.main.player.coords - self.coords)
		- Vector2(self.main.tile_map.tile_set.tile_size) * 0.5
	)


func shoot() -> void:
	var projectile := self.projectile_scene.instantiate() as Projectile

	var target_coords := self.raycast(self.coords, self.shoot_direction)
	var target_entity: Entity = self.main.entity_map.get(target_coords)
	if target_entity != null:
		target_entity.hurt(self.ranged_damage, target_coords - self.coords)
		projectile.target_entity = target_entity
	else:
		projectile.target_position = self.main.tile_map.map_to_local(target_coords)

	projectile.global_position = self.global_position
	SignalBus.node_spawned.emit(projectile)

	self.ready_to_shoot = false
	self.aim_line.clear_points()


func line_up_shot() -> bool:
	if self.find_line_of_sight(
		self.coords,
		self.main.player.coords,
		self.attack_directions
	) != Vector2i.ZERO:
		self.prepare_shot()
		return true

	for move_direction in self.move_directions:
		var p := self.coords + move_direction
		if self.main.is_cell_open(p):
			var attack_direction := self.find_line_of_sight(p, self.main.player.coords, self.attack_directions)
			if attack_direction != Vector2i.ZERO and self.move(p):
				self.prepare_shot()
				return true

	return false
