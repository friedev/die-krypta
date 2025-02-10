class_name InfoBox extends Control

@export var info_container: Control
@export var entity_info_scene: PackedScene

var entity_info_nodes: Array[EntityInfo]

func _ready() -> void:
	self.hide()
	for layer in Main.Layer:
		var entity_info: EntityInfo = self.entity_info_scene.instantiate()
		self.info_container.add_child(entity_info)
		self.entity_info_nodes.append(entity_info)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var coords := Globals.main.get_mouse_coords()
		var i := 0
		for layer in Main.Layer.values():
			var entity: Entity = Globals.main.entity_maps[layer].get(coords)
			if entity != null:
				self.show()
				var entity_info := self.entity_info_nodes[i]
				entity_info.show()
				entity_info.show_entity_info(entity)
				entity_info.separator.hide()
				if i > 0:
					self.entity_info_nodes[i - 1].separator.show()
				i += 1

		# If at least one node was hovered over, that means we updated the info
		# box. Hide the rest of the entity info nodes.
		#
		# If no entities were hovered over, keep displaying the info box's
		# existing contents. (Allows the player to hover over the box and read
		# tooltips.)
		if i > 0:
			while i < len(self.entity_info_nodes):
				entity_info_nodes[i].hide()
				i += 1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		self.hide()


func _on_player_done() -> void:
	self.hide()
