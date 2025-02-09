class_name FighterEnemy extends Enemy

@export var melee_damage: int
@export var ranged_damage: int
@export var turns_between_actions: int
@export var can_move_orthogonal: bool
@export var can_move_diagonal: bool
@export var can_attack_orthogonal: bool
@export var can_attack_diagonal: bool

var ready_to_shoot := false
var shoot_direction: Vector2i

var move_directions: Array[Vector2i]
var attack_directions: Array[Vector2i]
var turns_until_action: int
var animation_playing := false

func _ready() -> void:
	super._ready()
	self.projectile_launcher.projectile_hit_target.connect(self._on_projectile_hit_target)
	self.orthogonal_attack.animation_finished.connect(self._on_melee_attack_animation_finished)
	self.diagonal_attack.animation_finished.connect(self._on_melee_attack_animation_finished)
	self.projectile_launcher.layer = self.layer
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
	self.prev_coords = self.coords
	if self.health == 0 or Globals.main.player.health == 0:
		pass
	elif self.turns_until_action > 0:
		self.turns_until_action -= 1
	elif self.act():
		self.turns_until_action = self.turns_between_actions
	if not self.animation_playing:
		self.done.emit()


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
	var attack_direction := Globals.main.player.coords - self.coords
	if not attack_direction in self.attack_directions:
		return false
	self.face_toward(Globals.main.player.coords)
	var attack_animation: AnimatedSprite2D
	if attack_direction in Utility.orthogonal_directions:
		attack_animation = self.orthogonal_attack
		attack_animation.rotation = Vector2(attack_direction).angle()
	elif attack_direction in Utility.diagonal_directions:
		attack_animation = self.diagonal_attack
		attack_animation.rotation = Vector2(1, -1).angle_to(Vector2(attack_direction))
	else:
		assert(false, "Unexpected attack direction: %s" % str(attack_direction))
	attack_animation.position = Vector2(attack_direction * Globals.main.tile_map.tile_set.tile_size)
	attack_animation.play()
	self.animation_playing = true
	return true


func _on_melee_attack_animation_finished() -> void:
	self.animation_playing = false
	Globals.main.player.hurt(self.melee_damage, Globals.main.player.coords - self.coords)
	self.done.emit()


# Move along the shortest path toward the player
func chase_player() -> bool:
	# Configure A* pathfinding
	assert(self.layer == Main.ASTAR_LAYER)
	var heuristic: AStarGrid2D.Heuristic
	if self.can_move_diagonal:
		Globals.main.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
		heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	else:
		Globals.main.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	Globals.main.astar.default_compute_heuristic = heuristic
	Globals.main.astar.default_estimate_heuristic = heuristic

	# Set source and destination as not solid
	# (AStarGrid2D can't pathfind to/from solid points)
	Globals.main.astar.set_point_solid(self.coords, false)
	Globals.main.astar.set_point_solid(Globals.main.player.coords, false)

	# Calculate path
	var path := Globals.main.astar.get_id_path(self.coords, Globals.main.player.coords, true)

	# Set source and destination as solid again
	Globals.main.astar.set_point_solid(self.coords, true)
	Globals.main.astar.set_point_solid(Globals.main.player.coords, true)

	# Attempt to move to the first point along the path
	return len(path) > 1 and self.move(path[1])


func get_direction_to(p1: Vector2i, p2: Vector2i, directions: Array[Vector2i]) -> Vector2i:
	for direction in directions:
		if Utility.is_same_direction(p2 - p1, direction):
			return direction
	return Vector2i.ZERO


func has_line_of_sight(start: Vector2i, end: Vector2i, direction: Vector2i) -> bool:
	# p2 is assumed to be an occupied cell
	return Globals.main.raycast(start, direction) == end


func find_line_of_sight(start: Vector2i, end: Vector2i, directions: Array[Vector2i]) -> Vector2i:
	# p2 is assumed to be an occupied cell
	for direction in directions:
		if self.has_line_of_sight(start, end, direction):
			return direction
	return Vector2i.ZERO
	

func prepare_shot() -> void:
	self.face_toward(Globals.main.player.coords)
	self.shoot_direction = self.get_direction_to(self.coords, Globals.main.player.coords, self.attack_directions)
	assert(self.shoot_direction != Vector2i.ZERO)
	self.ready_to_shoot = true
	self.projectile_launcher.prepare_shot(self.coords, self.shoot_direction)


func shoot() -> void:
	self.ready_to_shoot = false
	self.projectile_launcher.shoot(self.coords, self.shoot_direction, self.ranged_damage)
	self.animation_playing = true


func _on_projectile_hit_target() -> void:
	self.animation_playing = false
	self.done.emit()


func line_up_shot() -> bool:
	if self.find_line_of_sight(
		self.coords,
		Globals.main.player.coords,
		self.attack_directions
	) != Vector2i.ZERO:
		self.prepare_shot()
		return true

	for move_direction in self.move_directions:
		var p := self.coords + move_direction
		if Globals.main.is_cell_open(p):
			var attack_direction := self.find_line_of_sight(p, Globals.main.player.coords, self.attack_directions)
			if attack_direction != Vector2i.ZERO and self.move(p):
				self.prepare_shot()
				return true

	return false


func die() -> void:
	if self.projectile_launcher != null:
		self.projectile_launcher.hide()
	super.die()