class_name AttackInfo extends Control

@export var damage_label: Label
@export var direction_icon: TextureRect

func show_attack_info(damage: int, direction_texture: Texture) -> void:
	if damage > 0:
		self.show()
		self.damage_label.text = str(damage)
		self.direction_icon.texture = direction_texture
