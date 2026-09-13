class_name MazeGenerator
extends RefCounted

## Procedural maze generator: a recursive-backtracker carves a perfect
## maze, then a configurable fraction of remaining inner walls are knocked
## down to create loops/open areas (fewer loops = harder, tighter maze at
## higher difficulty). A single horizontal "warp tunnel" row lets actors
## wrap from one side of the maze to the other, echoing classic arcade
## maze games.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func generate(cols: int, rows: int, extra_loop_chance: float, rng_seed: int) -> MazeData:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var data := MazeData.new(cols, rows)

	var visited := {}
	var stack: Array[Vector2i] = []
	var start := Vector2i(rng.randi() % cols, rng.randi() % rows)
	visited[start] = true
	data.set_blocked(2 * start.x + 1, 2 * start.y + 1, false)
	stack.append(start)

	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = []
		for d in DIRS:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < cols and n.y >= 0 and n.y < rows and not visited.has(n):
				options.append(d)
		if options.size() == 0:
			stack.pop_back()
			continue
		var dir: Vector2i = options[rng.randi() % options.size()]
		var next: Vector2i = cur + dir
		var wx: int = 2 * cur.x + 1 + dir.x
		var wy: int = 2 * cur.y + 1 + dir.y
		data.set_blocked(wx, wy, false)
		data.set_blocked(2 * next.x + 1, 2 * next.y + 1, false)
		visited[next] = true
		stack.append(next)

	# Extra loops for variety / difficulty tuning.
	for cx in range(cols):
		for cy in range(rows):
			if cx + 1 < cols:
				var wx: int = 2 * cx + 2
				var wy: int = 2 * cy + 1
				if data.is_blocked(wx, wy) and rng.randf() < extra_loop_chance:
					data.set_blocked(wx, wy, false)
			if cy + 1 < rows:
				var wx2: int = 2 * cx + 1
				var wy2: int = 2 * cy + 2
				if data.is_blocked(wx2, wy2) and rng.randf() < extra_loop_chance:
					data.set_blocked(wx2, wy2, false)

	# A few open rectangular rooms scattered in, for variety - not every
	# maze should be pure 1-wide corridors.
	_carve_open_rooms(data, cols, rows, rng)

	var tunnel_cell_row: int = rows / 2
	data.tunnel_row = tunnel_cell_row
	var ty: int = 2 * tunnel_cell_row + 1
	data.set_blocked(0, ty, false)
	data.set_blocked(data.width - 1, ty, false)

	return data

static func _carve_open_rooms(data: MazeData, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	var room_count: int = rng.randi_range(0, 2) # "sometimes" - not guaranteed every level
	for r in range(room_count):
		var rw: int = rng.randi_range(2, 3)
		var rh: int = rng.randi_range(2, 3)

		var max_start_x: int = cols - rw - 1
		var max_start_y: int = rows - rh - 1
		if max_start_x < 1 or max_start_y < 1:
			continue

		var start_x: int = 1 + (rng.randi() % max_start_x)
		var start_y: int = 1 + (rng.randi() % max_start_y)

		for cx in range(start_x, start_x + rw):
			for cy in range(start_y, start_y + rh):
				data.set_blocked(2 * cx + 1, 2 * cy + 1, false)
				if cx + 1 < start_x + rw:
					data.set_blocked(2 * cx + 2, 2 * cy + 1, false)
				if cy + 1 < start_y + rh:
					data.set_blocked(2 * cx + 1, 2 * cy + 2, false)
