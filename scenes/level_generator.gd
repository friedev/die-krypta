class_name LevelGenerator extends Resource

@export var astar_region := Rect2i(-32, -32, 64, 64)

@export var min_rects: int
@export var min_floors: int
@export var min_rect_length: int
@export var max_rect_length: int
@export var max_rect_floors: int
@export var max_rect_tries := 50

@export var starting_difficulty: int
@export var difficulty_per_level: int
@export var min_enemy_spawn_distance := 3  # in tiles (manhattan distance)
@export var max_enemy_tries := 10

@export var min_traps: int
@export var max_traps: int
@export var max_trap_tries := 10

@export var enemy_scenes: Array[PackedScene]
@export var trap_scenes: Array[PackedScene]


func generate_level() -> void:
	self.generate_map()
	Globals.main.player.coords = Globals.main.get_center_floors().pick_random()
	var difficulty := self.starting_difficulty + Globals.main.level * self.difficulty_per_level
	self.spawn_enemies(difficulty)
	var trap_count := randi_range(min_traps, max_traps)
	self.place_traps(trap_count)


func generate_map() -> void:
	Globals.main.astar.clear()
	Globals.main.astar.region = self.astar_region
	Globals.main.astar.update()
	Globals.main.astar.fill_solid_region(Globals.main.astar.region)

	var rects: Array[Rect2i] = []
	var floor_count := 0
	var tries := 0
	var current_bounds := Rect2i(0, 0, 0, 0)
	while (
		not (floor_count >= self.min_floors and len(rects) >= self.min_rects)
		and tries < self.max_rect_tries
	):
		var side1 := randi_range(self.min_rect_length, self.max_rect_length)
		@warning_ignore("integer_division")
		var side2 := randi_range(
			self.min_rect_length,
			clampi(
				self.max_rect_floors / side1,
				self.min_rect_length,
				self.max_rect_length
			)
		)

		var rect_size: Vector2i
		var long_x := randi() % 2 == 0
		if long_x:
			rect_size = Vector2i(side1, side2)
		else:
			rect_size = Vector2i(side2, side1)

		# Ensure the rectangle is placed inside the A* region
		var min_start := Vector2i(
			Globals.main.astar.region.position.x + 1,
			Globals.main.astar.region.position.y + 1,
		)
		var max_start := Vector2i(
			Globals.main.astar.region.end.x - rect_size.x - 1,
			Globals.main.astar.region.end.y - rect_size.y - 1,
		)
		var bounded_min_start: Vector2i
		var bounded_max_start: Vector2i
		if len(rects) == 0:
			# Place starting rectangle near the center of the A* region to avoid
			# running up against the region bounds early in generation
			bounded_min_start = Globals.main.astar.region.get_center() - Vector2i(rect_size * 0.5)
			bounded_max_start = bounded_min_start
		else:
			bounded_min_start = Vector2i(
				current_bounds.position.x - rect_size.x + 1,
				current_bounds.position.y - rect_size.y + 1,
			)
			bounded_max_start = Vector2i(
				current_bounds.end.x - 1,
				current_bounds.end.y - 1,
			)
		min_start = bounded_min_start.max(min_start)
		max_start = bounded_max_start.min(max_start)
		var start := Vector2i(
			randi_range(min_start.x, max_start.x),
			randi_range(min_start.y, max_start.y),
		)
		var new_rect := Rect2i(start, rect_size)
		assert(
			Globals.main.astar.region.encloses(new_rect),
			"Rectangle %s outside of A* region %s"
			% [str(new_rect), str(Globals.main.astar.region)]
		)

		var use_rect := false
		if len(rects) != 0:
			# The new rect must intersect at least one existing rect to be
			# accessible
			for rect in rects:
				if new_rect.intersects(rect):
					# Don't use rects that entirely enclose or duplicate others
					# Makes for less interesting layouts
					if new_rect.encloses(rect) or rect.encloses(new_rect):
						break
					use_rect = true
					break
		else:
			use_rect = true
		
		if use_rect:
			var floors_added := Globals.main.place_rect(new_rect)
			if floors_added > 0:
				floor_count += floors_added
				rects.append(new_rect)
				current_bounds = current_bounds.merge(new_rect)
				tries = 0
				continue
		tries += 1

	# print("Generated %d rects with %d floors" % [len(rects), floor_count, tries])
	if tries >= self.max_rect_tries:
		push_warning("Giving up on level generation after %d tries" % tries)


func spawn_enemies(max_difficulty: int) -> void:
	var spawn_cells: Array[Vector2i] = []
	for coords in Globals.main.get_open_cells():
		if (
			Globals.main.is_cell_open(coords)
			and Utility.manhattan_distance(Globals.main.player.coords, coords) >= self.min_enemy_spawn_distance
		):
			spawn_cells.append(coords)

	var difficulty := 0
	while difficulty < max_difficulty:
		if len(spawn_cells) == 0:
			push_warning(
                "Not enough space to spawn enemies; stopping at %d difficulty out of %d max"
                % [difficulty, max_difficulty]
            )
			break

		var spawn_coords := spawn_cells[randi() % len(spawn_cells)]

		# TODO more efficient way of choosing enemies with deterministic time
		# complexity and without churning through bad choices
		var tries := 0
		var enemy: Enemy = null
		while (
            (enemy == null or difficulty + enemy.difficulty > max_difficulty)
            and tries < self.max_enemy_tries
        ):
			tries += 1
			if enemy != null:
				enemy.queue_free()
			var enemy_scene := self.enemy_scenes[randi() % len(self.enemy_scenes)]
			enemy = enemy_scene.instantiate()

		if difficulty + enemy.difficulty <= max_difficulty:
			Globals.main.place_entity(enemy, spawn_coords)
			spawn_cells.erase(spawn_coords)
			difficulty += enemy.difficulty
		else:
			break


func place_traps(trap_count: int) -> void:
	var exposed_walls := Globals.main.get_exposed_walls()
	var floors := Globals.main.get_floors()
	var tries := 0
	var traps_placed := 0
	while traps_placed < trap_count and tries < self.max_trap_tries:
		tries += 1
		var trap: Entity = self.trap_scenes[randi() % len(self.trap_scenes)].instantiate()

		if trap is ProjectileTrap:
			var projectile_trap: ProjectileTrap = trap
			if len(exposed_walls) == 0:
				continue
			var coords := exposed_walls[randi() % len(exposed_walls)]
			Globals.main.set_wall(coords, false)

			var adjacent_floor_directions: Array[Vector2i] = []
			for direction in Utility.orthogonal_directions:
				if Globals.main.is_floor(coords + direction):
					adjacent_floor_directions.append(direction)
			var direction := adjacent_floor_directions[randi() % len(adjacent_floor_directions)]

			projectile_trap.direction = direction
			Globals.main.place_entity(projectile_trap, coords)
			exposed_walls.erase(coords)
		elif trap is SpikeTrap:
			if len(floors) == 0:
				continue
			var coords := floors[randi() % len(floors)]
			Globals.main.place_entity(trap, coords)
			floors.erase(coords)
		else:
			assert(false, "Unknown trap type")
		traps_placed += 1

