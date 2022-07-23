extends Camera2D
class_name ShakeCamera2D


const MAX_OFFSET := 4.0
const SHAKE_REDUCTION := 0.025

var stress := 0.0
var shake := 0.0
var noise := OpenSimplexNoise.new()


func _ready() -> void:
	self.noise.seed = randi()
	self.noise.octaves = 4
	self.noise.period = 20.0
	self.noise.persistence = 0.8


func _process(delta: float) -> void:
	self.shake = self.stress * self.stress

	var offset := Vector2()
	self.offset_h = self.MAX_OFFSET * self.shake * self.noise.get_noise_1d(OS.get_ticks_msec())
	self.offset_v = self.MAX_OFFSET * self.shake * self.noise.get_noise_1d(OS.get_ticks_msec())

	self.stress = clamp(self.stress - self.SHAKE_REDUCTION, 0.0, 1.0)


func add_stress(amount: float) -> void:
	self.stress = clamp(self.stress + amount, 0.0, 1.0)
