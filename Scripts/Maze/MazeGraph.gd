class_name MazeGraph
extends RefCounted

## Wraps an AStar2D graph over the maze cells so both the AI-controlled
## player and the "hunter" monsters can path toward a target, plus a
## couple of small helpers used by wandering monsters.

var data: MazeData
var cell_size: float
var origin: Vector2
var astar: AStar2D = AStar2D.new()

func _init(p_data: MazeData, p_cell_size: float, p_origin: Vector2) -> void:
	data = p_data
	cell_size = p_cell_size
	origin = p_origin
	_build_graph()

func id(cx: int, cy: int) -> int:
	return cy * data.cols + cx

func _build_graph() -> void:
	for cy in range(data.rows):
		for cx in range(data.cols):
			astar.add_point(id(cx, cy), cell_to_world(cx, cy))

	for cy in range(data.rows):
		for cx in range(data.cols):
			if cx + 1 < data.cols and not data.is_blocked(2 * cx + 2, 2 * cy + 1):
				astar.connect_points(id(cx, cy), id(cx + 1, cy))
			if cy + 1 < data.rows and not data.is_blocked(2 * cx + 1, 2 * cy + 2):
				astar.connect_points(id(cx, cy), id(cx, cy + 1))

	var ty: int = data.tunnel_row
	astar.connect_points(id(0, ty), id(data.cols - 1, ty))

func cell_to_world(cx: int, cy: int) -> Vector2:
	return origin + Vector2(cx * cell_size + cell_size / 2.0, cy * cell_size + cell_size / 2.0)

func world_to_cell(world: Vector2) -> Vector2i:
	var local: Vector2 = world - origin
	var cx: int = clampi(int(local.x / cell_size), 0, data.cols - 1)
	var cy: int = clampi(int(local.y / cell_size), 0, data.rows - 1)
	return Vector2i(cx, cy)

func find_path(from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
	var from_cell: Vector2i = world_to_cell(from_world)
	var to_cell: Vector2i = world_to_cell(to_world)
	var id_path: PackedInt64Array = astar.get_id_path(id(from_cell.x, from_cell.y), id(to_cell.x, to_cell.y))
	var result: Array[Vector2] = []
	for point_id in id_path:
		result.append(astar.get_point_position(point_id))
	return result

func random_open_neighbor_dir(cell: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var dirs: Array[Vector2i] = []
	if cell.x + 1 < data.cols and not data.is_blocked(2 * cell.x + 2, 2 * cell.y + 1):
		dirs.append(Vector2i(1, 0))
	if cell.x - 1 >= 0 and not data.is_blocked(2 * cell.x, 2 * cell.y + 1):
		dirs.append(Vector2i(-1, 0))
	if cell.y + 1 < data.rows and not data.is_blocked(2 * cell.x + 1, 2 * cell.y + 2):
		dirs.append(Vector2i(0, 1))
	if cell.y - 1 >= 0 and not data.is_blocked(2 * cell.x + 1, 2 * cell.y):
		dirs.append(Vector2i(0, -1))
	if dirs.size() == 0:
		return Vector2i.ZERO
	return dirs[rng.randi() % dirs.size()]

## Same open-neighbor set as above, but picks whichever one gets closest to
## a target point instead of a random one - used to let otherwise-random
## wanderers (Skulker/Blaster/Wraith) act like they're tracking a player,
## with the odds of doing so controlled by the caller (see
## LevelRoot.tracking_skill).
func greedy_neighbor_dir(cell: Vector2i, toward_world: Vector2) -> Vector2i:
	var dirs: Array[Vector2i] = []
	if cell.x + 1 < data.cols and not data.is_blocked(2 * cell.x + 2, 2 * cell.y + 1):
		dirs.append(Vector2i(1, 0))
	if cell.x - 1 >= 0 and not data.is_blocked(2 * cell.x, 2 * cell.y + 1):
		dirs.append(Vector2i(-1, 0))
	if cell.y + 1 < data.rows and not data.is_blocked(2 * cell.x + 1, 2 * cell.y + 2):
		dirs.append(Vector2i(0, 1))
	if cell.y - 1 >= 0 and not data.is_blocked(2 * cell.x + 1, 2 * cell.y):
		dirs.append(Vector2i(0, -1))
	if dirs.size() == 0:
		return Vector2i.ZERO

	var best: Vector2i = dirs[0]
	var best_dist: float = INF
	for d in dirs:
		var dist: float = cell_to_world(cell.x + d.x, cell.y + d.y).distance_squared_to(toward_world)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best

## Position in the double-resolution Data grid of the wall that sits
## between two orthogonally-adjacent logical cells.
static func _wall_grid_pos(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(a.x + b.x + 1, a.y + b.y + 1)

func is_wall_between(a: Vector2i, b: Vector2i) -> bool:
	var w: Vector2i = _wall_grid_pos(a, b)
	return data.is_blocked(w.x, w.y)

## Edits a single wall at runtime (the strategic wall-building mechanic)
## and keeps the pathfinding graph in sync with it, so AI pathing reacts
## immediately to a wall going up or down.
func set_wall_between(a: Vector2i, b: Vector2i, blocked: bool) -> void:
	var w: Vector2i = _wall_grid_pos(a, b)
	data.set_blocked(w.x, w.y, blocked)

	var id_a: int = id(a.x, a.y)
	var id_b: int = id(b.x, b.y)
	var connected: bool = astar.are_points_connected(id_a, id_b)
	if blocked and connected:
		astar.disconnect_points(id_a, id_b)
	elif not blocked and not connected:
		astar.connect_points(id_a, id_b)

## Would blocking the passage between these two cells cut the maze into
## two unreachable pieces? Probes by temporarily disconnecting the edge and
## checking whether a path still exists some other way (e.g. through a
## loop), then always restores the edge - this never leaves a permanent
## change, it only answers the question. Used to refuse a wall-build that
## would trap a region of the maze.
func would_disconnect(a: Vector2i, b: Vector2i) -> bool:
	var id_a: int = id(a.x, a.y)
	var id_b: int = id(b.x, b.y)
	if not astar.are_points_connected(id_a, id_b):
		return false

	astar.disconnect_points(id_a, id_b)
	var still_reachable: bool = astar.get_id_path(id_a, id_b).size() > 0
	astar.connect_points(id_a, id_b)
	return not still_reachable
