class_name EntityInfo extends Control

@export var name_label: Label
@export var entity_icon: TextureRect
@export var health_container: Control
@export var health_label: Label
@export var melee_attack_info: AttackInfo
@export var ranged_attack_info: AttackInfo
@export var turns_until_action_container: Control
@export var turns_until_action_label: Label
@export var move_direction_icon: TextureRect
@export var separator: Separator

@export var all_directions_texture: Texture2D
@export var orthogonal_directions_texture: Texture2D
@export var diagonal_directions_texture: Texture2D
@export var no_directions_texture: Texture2D


func get_texture_for_directions(directions: Utility.Directions) -> Texture2D:
	match directions:
		Utility.Directions.NONE:
			return self.no_directions_texture
		Utility.Directions.ORTHOGONAL:
			return self.orthogonal_directions_texture
		Utility.Directions.DIAGONAL:
			return self.diagonal_directions_texture
		Utility.Directions.ALL:
			return self.all_directions_texture
	assert(false, "Unexpected directions: %s" % str(directions))
	return null


func show_turns_until_action(turns_until_action: int, turns_between_actions: int) -> void:
	if turns_between_actions > 0:
		self.turns_until_action_container.show()
		self.turns_until_action_label.text = "%d/%d" % [
			turns_until_action, turns_between_actions
		]
	elif turns_until_action > 0:
		self.turns_until_action_container.show()
		self.turns_until_action_label.text = str(turns_until_action)


func show_entity_info(entity: Entity) -> void:
	self.health_container.hide()
	self.melee_attack_info.hide()
	self.ranged_attack_info.hide()
	self.turns_until_action_container.hide()

	self.name_label.text = entity.display_name
	self.entity_icon.texture = entity.get_texture()
	self.health_label.text = "%d/%d" % [entity.health, entity.max_health]

	if entity is FighterEnemy:
		self.health_container.show()
		var fighter: FighterEnemy = entity
		var attack_direction_texture := self.get_texture_for_directions(fighter.attack_directions)
		self.melee_attack_info.show_attack_info(fighter.melee_damage, attack_direction_texture)
		self.ranged_attack_info.show_attack_info(fighter.ranged_damage, attack_direction_texture)
		self.show_turns_until_action(fighter.turns_until_action, fighter.turns_between_actions)
		self.move_direction_icon.texture = self.get_texture_for_directions(fighter.move_directions)
	elif entity is Player:
		self.health_container.show()
		self.move_direction_icon.texture = self.get_texture_for_directions(Utility.Directions.ORTHOGONAL)
	elif entity is ProjectileTrap or entity is TileTrap:
		self.move_direction_icon.texture = self.get_texture_for_directions(Utility.Directions.NONE)
		if entity is ProjectileTrap:
			var projectile_trap: ProjectileTrap = entity
			self.ranged_attack_info.show_attack_info(
				projectile_trap.damage,
				self.get_texture_for_directions(Utility.Directions.ORTHOGONAL)
			)
			if not projectile_trap.detect_targets:
				self.show_turns_until_action(
					projectile_trap.turns_until_shot,
					projectile_trap.turns_between_shots
				)
		elif entity is TileTrap:
			var tile_trap: TileTrap = entity
			self.melee_attack_info.show_attack_info(
				tile_trap.damage,
				self.get_texture_for_directions(Utility.Directions.NONE)
			)
			if not tile_trap.detect_targets:
				self.show_turns_until_action(
					tile_trap.turns_until_activation,
					tile_trap.turns_between_activations
				)