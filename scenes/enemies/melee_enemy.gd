class_name MeleeEnemy extends Enemy

@export var melee_damage := 1


func update() -> void:
	super.update()
	if self.health == 0 or self.main.player.health == 0:
		return
	if not self.melee_attack():
		self.chase_player()


func melee_attack() -> bool:
	if Utility.manhattan_distance(self.coords, self.main.player.coords) > 1:
		return false
	self.face_toward(self.main.player.coords)
	self.main.player.hurt(1, self.main.player.coords - self.coords)
	return true
