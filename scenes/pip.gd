class_name Pip extends Node2D

@export var background_color: Color

@export var pip_type: PipType:
	set(value):
		pip_type = value
		if self.pip_type != null:
			self.show()
			var color: Color
			# Ensure the pip color isn't the same as the background color
			if self.pip_type.color == self.background_color:
				# Show a black pip on a white background, or white on any other
				# background
				if self.background_color == Color.WHITE:
					color = Color.BLACK
				else:
					color = Color.WHITE
			else:
				color = self.pip_type.color
			self.sprite.modulate = color
		else:
			self.hide()

@export var sprite: Sprite2D