class_name AttackAnimation extends Node2D

signal animation_finished

@export var animation: StringName

@export var animation_player: AnimationPlayer


func play() -> void:
	self.animation_player.play(self.animation)


func stop() -> void:
	self.animation_player.stop()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	self.animation_finished.emit()
