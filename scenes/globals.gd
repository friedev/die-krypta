extends Node

var is_menu_open: bool:
    set(value):
        is_menu_open = value
        SignalBus.menu_opened.emit(self.is_menu_open)
