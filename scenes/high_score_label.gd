class_name HighScoreLabel extends Label

const CONFIG_PATH := "user://scores.cfg"
const SECTION := "scores"
const KEY := "high_score"

var config := ConfigFile.new()
var high_score: int:
	set(value):
		if value > self.high_score:
			self.modulate = Color.GOLD
		high_score = value
		if self.high_score > 0:
			self.text = "Best: %d" % self.high_score
		else:
			self.text = ""
		self.config.set_value(self.SECTION, self.KEY, self.high_score)


func _ready() -> void:
	if self.config.load(self.CONFIG_PATH) == OK:
		self.high_score = self.config.get_value(self.SECTION, self.KEY)
	else:
		self.high_score = 0
	self.hide()
	SignalBus.menu_opened.connect(self._on_menu_opened)


func _on_player_died(_entity: Entity) -> void:
	self.high_score = maxi(self.high_score, Globals.main.level + 1)
	print(self.high_score)
	self.config.save(self.CONFIG_PATH)


func _on_menu_opened(open: bool) -> void:
	self.visible = open

func _on_main_level_started(level:int) -> void:
	self.modulate = Color(0.5, 0.5, 0.5)
