class_name MazeActor
extends CharacterBody2D

## Common base for anything that moves around inside the maze (players and
## monsters): physical collision with walls, warp-tunnel wraparound,
## lane-centering assist, and a shared draw hook so every actor is just a
## simple colored shape. GDScript has no "abstract" keyword, so
## draw_shape() below is just a no-op that every leaf subclass overrides.

var maze_ref: MazeGraph = null

@export var speed: float = 120.0

func _ready() -> void:
	collision_layer = 0
	set_collision_mask_value(1, true) # Layer 1 = walls, everyone collides with them physically.

func wrap_if_needed() -> void:
	if maze_ref == null:
		return
	var left_bound: float = maze_ref.origin.x
	var right_bound: float = maze_ref.origin.x + maze_ref.data.cols * maze_ref.cell_size
	var tunnel_y: float = maze_ref.cell_to_world(0, maze_ref.data.tunnel_row).y

	if absf(global_position.y - tunnel_y) < maze_ref.cell_size * 0.5:
		if global_position.x < left_bound - 2.0:
			global_position = Vector2(right_bound - 2.0, global_position.y)
		elif global_position.x > right_bound + 2.0:
			global_position = Vector2(left_bound + 2.0, global_position.y)

## Corridors are only a little wider than an actor's collision shape, so
## moving purely on raw input/velocity makes it very easy to clip a corner
## and get stuck. This gently pulls the actor toward the centerline of the
## corridor it's currently in (perpendicular to its direction of travel),
## the same trick classic maze-chase games use so movement feels forgiving
## instead of pixel-perfect.
func lane_centering_velocity(dir: Vector2, gain: float = 8.0) -> Vector2:
	if maze_ref == null or dir == Vector2.ZERO:
		return Vector2.ZERO
	var cell: Vector2i = maze_ref.world_to_cell(global_position)
	var center: Vector2 = maze_ref.cell_to_world(cell.x, cell.y)
	var correction := Vector2.ZERO
	if dir.x != 0.0:
		correction.y = (center.y - global_position.y) * gain
	elif dir.y != 0.0:
		correction.x = (center.x - global_position.x) * gain
	return correction

func _draw() -> void:
	draw_shape()

func draw_shape() -> void:
	pass
