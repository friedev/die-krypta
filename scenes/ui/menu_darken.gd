extends CanvasModulate


func _ready() -> void:
	SignalBus.menu_opened.connect(self._on_menu_opened)


func _on_menu_opened(open: bool) -> void:
	self.visible = open