class_name Menu extends Control

signal opened
signal closed

@export var default_focus: Control
@export var can_go_back := true

var previous: Menu


func _ready() -> void:
	self.hide()


func open(previous: Menu = null) -> void:
	if self.visible:
		return
	self.previous = previous
	self.show()
	if self.default_focus != null:
		self.default_focus.grab_focus()
	Globals.is_menu_open = true
	self.opened.emit()


func close() -> void:
	if not self.visible:
		return
	self.hide()
	if self.can_go_back and self.previous != null:
		self.previous.open()
	else:
		Globals.is_menu_open = false
	self.closed.emit()


func _input(event: InputEvent) -> void:
	if (
		self.can_go_back
		and self.visible
		and event.is_action_pressed(&"ui_cancel")
	):
		self.close()
