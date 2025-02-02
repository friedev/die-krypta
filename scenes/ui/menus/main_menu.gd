extends Menu

signal play_pressed(previous: Menu)
signal options_pressed(previous: Menu)
signal credits_pressed(previous: Menu)

@export var quit_button: Button
@export var version_label: Label


func _ready() -> void:
	self.quit_button.visible = OS.get_name() != "Web"
	self.version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	self.open()


func open(previous: Menu = null) -> void:
	super.open()


func _on_play_button_pressed() -> void:
	self.close()
	self.play_pressed.emit(self)


func _on_options_button_pressed() -> void:
	self.hide()
	self.options_pressed.emit(self)


func _on_credits_button_pressed() -> void:
	self.hide()
	self.credits_pressed.emit(self)


func _on_quit_button_pressed() -> void:
	self.get_tree().quit()
