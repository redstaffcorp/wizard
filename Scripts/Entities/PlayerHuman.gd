class_name PlayerHuman
extends Player

## The human player. Reads named input actions (set up in code by
## GameManager) rather than raw keys, so a future on-screen joystick for a
## mobile build can drive the same actions without any changes here.

func _ready() -> void:
	super._ready()
	body_color = Color(0.25, 0.9, 0.35) # green
	speed = 130.0
	max_bullets = 1

func get_desired_direction(_delta: float) -> Vector2:
	if Input.is_action_just_pressed("alter_wall"):
		_try_alter_wall()
	if Input.is_action_just_pressed("place_bomb"):
		_try_place_bomb()

	var x: float = 0.0
	var y: float = 0.0
	if Input.is_action_pressed("move_left"): x -= 1.0
	if Input.is_action_pressed("move_right"): x += 1.0
	if Input.is_action_pressed("move_up"): y -= 1.0
	if Input.is_action_pressed("move_down"): y += 1.0

	# Cardinal-only movement (no diagonals), horizontal takes priority.
	if x != 0.0:
		return Vector2(signf(x), 0.0)
	if y != 0.0:
		return Vector2(0.0, signf(y))
	return Vector2.ZERO

func wants_to_shoot() -> bool:
	return Input.is_action_pressed("shoot_p1")

## Builds a wall between the cell we're standing in and the one we're
## facing if it's open, or knocks it down if it's already a wall - one
## button doubles as both tools, costing one resource either way. LevelRoot
## decides whether the edit is actually allowed (enough resources, and
## never a build that would trap a region of the maze).
func _try_alter_wall() -> void:
	if maze_ref == null:
		return
	var cell: Vector2i = maze_ref.world_to_cell(global_position)
	var neighbor: Vector2i = cell + Vector2i(int(facing_dir.x), int(facing_dir.y))
	if LevelRoot.current != null:
		LevelRoot.current.try_alter_wall(player_index, cell, neighbor)

## Drops a bomb at the player's own current cell (Bomberman-style, snapped
## to the cell center) rather than the faced cell like the wall tool -
## spends one bomb resource up front; LevelRoot.detonate_bomb does the
## actual damage/wall-break once the fuse runs out.
func _try_place_bomb() -> void:
	if maze_ref == null or LevelRoot.current == null:
		return
	if not GameManager.spend_bomb_resource(player_index):
		return

	var cell: Vector2i = maze_ref.world_to_cell(global_position)
	var bomb := Bomb.new()
	bomb.owner_index = player_index
	get_parent().add_child(bomb)
	bomb.global_position = maze_ref.cell_to_world(cell.x, cell.y)
	SoundManager.play_bomb_place()
