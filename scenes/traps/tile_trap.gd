class_name SpikeTrap extends Entity

@export var damage := 1
@export var target_layer := Main.Layer.MAIN

@export var inactive_sprite: Sprite2D
@export var active_sprite: Sprite2D
@export var activate_sound: RandomPitchSound

## If true, will activate the turn after an entity enters its line of sight.
## If false, will activate and deactive repeatedly, waiting turns_between_activations
## between activations.
@export var detect_targets := true
@export var turns_between_activations := 1

var active := false:
	set(value):
		active = value
		self.inactive_sprite.visible = not active
		self.active_sprite.visible = active

var randomize_cycle := true
var ready_to_activate := false
var turns_until_activation: int


func _ready() -> void:
	if not self.detect_targets:
		if self.turns_between_activations == 0:
			self.active = true
		elif self.randomize_cycle:
			self.turns_until_activation = randi_range(0, self.turns_between_activations)
			self.active = self.turns_until_activation == self.turns_between_activations
		else:
			self.active = false
			self.turns_until_activation = self.turns_between_activations - 1
	else:
		self.active = false


func get_target_entity() -> Entity:
	return Globals.main.entity_maps[self.target_layer].get(self.coords)


func update() -> void:
	self.active = false
	# TODO merge logic with ProjectileTrap
	if self.detect_targets:
		if self.ready_to_activate:
			self.activate()
		else:
			if self.get_target_entity() != null:
				self.prepare()
	else:
		if self.turns_until_activation > 0:
			self.turns_until_activation -= 1
			if self.turns_until_activation == 0:
				self.prepare()
		else:
			self.activate()
			self.turns_until_activation = self.turns_between_activations
	self.done.emit()


func activate() -> void:
	self.active = true
	var target_entity := self.get_target_entity()
	if target_entity != null:
		target_entity.hurt(self.damage, Vector2i.ZERO)
	self.activate_sound.randomize_and_play()
	self.ready_to_activate = false


func prepare() -> void:
	self.ready_to_activate = true
