class_name MapRoom


var x: int
var y: int
var width: int
var height: int
var x_end: int
var y_end: int


func _init(x, y, width, height):
	self.x = x
	self.y = y
	self.width = width
	self.height = height

	self.x_end = self.x + self.width
	self.y_end = self.y + self.height
