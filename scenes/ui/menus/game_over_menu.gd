extends Menu

signal menu_pressed(previous: Menu)

@export var label: Label


func _ready() -> void:
	self.hide()


func _on_menu_button_pressed() -> void:
	self.hide()
	self.menu_pressed.emit(self)


func _on_player_died() -> void:
	if self.visible:
		return
	self.label.text = "Game Over"
	self.open()
