extends Camera2D
class_name ShakeCamera


const MAX_OFFSET := 4.0
const SHAKE_REDUCTION := 0.025

var stress := 0.0
var shake := 0.0
var noise := FastNoiseLite.new()


func _ready() -> void:
	self.noise.seed = randi()
	self.noise.fractal_octaves = 4
	self.noise.frequency = 1.0 / 20.0
#	self.noise.persistence = 0.8


func _process(delta: float) -> void:
	self.shake = self.stress * self.stress

	var offset := Vector2()
	self.drag_horizontal_offset = self.MAX_OFFSET * self.shake * self.noise.get_noise_1d(Time.get_ticks_msec())
	self.drag_vertical_offset = self.MAX_OFFSET * self.shake * self.noise.get_noise_1d(Time.get_ticks_msec())

	self.stress = clamp(self.stress - self.SHAKE_REDUCTION, 0.0, 1.0)


func add_stress(amount: float) -> void:
	self.stress = clamp(amount, 0.0, 1.0)
