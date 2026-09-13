class_name WallSegment
extends StaticBody2D

## A single maze wall. Adjacent blocked cells are merged into runs by
## LevelRoot before instancing these, so the wall/collider count stays low
## even on the largest mazes.

var size_px: Vector2 = Vector2(28, 28)
var wall_color: Color = Color(0.16, 0.55, 0.9)

func _ready() -> void:
	# Walls use Godot's default layer 1, which every mover already
	# collides with (see MazeActor), so nothing extra to configure.
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size_px
	add_child(shape)
	z_index = 1

func _draw() -> void:
	var rect := Rect2(-size_px / 2.0, size_px)
	draw_rect(rect, wall_color, true)
	draw_rect(rect, wall_color.darkened(0.4), false, 2.0)
