class_name WallSegment
extends StaticBody2D

## A single maze wall - reskinned as a chunk of solid asteroid rock (the
## game's lore: every level is a fresh asteroid, riddled with tunnels the
## mining crew has already cleared, and these are the rock still standing
## between them). Adjacent blocked cells are merged into runs by LevelRoot
## before instancing these, so the wall/collider count stays low even on
## the largest mazes.

var size_px: Vector2 = Vector2(28, 28)
var wall_color: Color = Color(0.42, 0.35, 0.3) # rock grey-brown

var _craters: Array = [] # Array[Dictionary] {pos: Vector2, r: float}
var _veins: Array = [] # Array[PackedVector2Array]

func _ready() -> void:
	# Walls use Godot's default layer 1, which every mover already
	# collides with (see MazeActor), so nothing extra to configure.
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size_px
	add_child(shape)
	z_index = 1
	_generate_rock_texture()

## Precomputes crater/ore-vein positions once per instance (not every
## _draw() call, which would flicker/waste work) - seeded off this
## segment's own instance ID so identically-sized walls don't all render
## as literal copies of each other.
func _generate_rock_texture() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()
	var half: Vector2 = size_px / 2.0

	var crater_count: int = clampi(int(size_px.x * size_px.y / 500.0), 1, 6)
	for i in range(crater_count):
		var pos := Vector2(
			rng.randf_range(-half.x + 3.0, half.x - 3.0),
			rng.randf_range(-half.y + 3.0, half.y - 3.0),
		)
		_craters.append({"pos": pos, "r": rng.randf_range(2.0, 5.0)})

	# Thin lighter mineral streaks running through the rock - the reason
	# this asteroid is worth mining out in the first place.
	var vein_count: int = clampi(int(size_px.x * size_px.y / 900.0), 0, 3)
	for i in range(vein_count):
		var cur := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		var pts := PackedVector2Array([cur])
		for s in range(rng.randi_range(2, 4)):
			cur += Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
			cur.x = clampf(cur.x, -half.x, half.x)
			cur.y = clampf(cur.y, -half.y, half.y)
			pts.append(cur)
		_veins.append(pts)

func _draw() -> void:
	var rect := Rect2(-size_px / 2.0, size_px)
	draw_rect(rect, wall_color, true)

	for c in _craters:
		draw_circle(c["pos"], c["r"], wall_color.darkened(0.28))
	for v in _veins:
		draw_polyline(v, Color(0.45, 0.85, 0.75, 0.55), 1.4)

	draw_rect(rect, wall_color.darkened(0.5), false, 2.0)
