class_name LevelRoot
extends Node2D

## Builds and owns everything for one maze level: walls, both players,
## monsters, and the exit portal that appears once every monster is
## cleared. Rebuilt from scratch each level with harder parameters.

static var current: LevelRoot = null

const CELL_SIZE: float = 64.0

var data: MazeData
var graph: MazeGraph

var _monsters_remaining: int = 0
var _portal_spawned: bool = false

# Gated during the "READY?" pause at the start of a level so
# players/monsters don't move until the intro finishes.
var action_started: bool = false

# Seconds of actual play on the current level (frozen during the "READY?"
# pause, reset every level). Drives tracking_skill, so otherwise-random
# monsters (Skulker/Blaster/Wraith) start out genuinely dumb and gradually
# start homing in on a player the longer you take on a level - dawdling
# gets punished.
var level_time: float = 0.0
const SKILL_RAMP_SECONDS: float = 45.0
const MAX_TRACKING_SKILL: float = 0.75 # never a perfect Hunter clone

var tracking_skill: float:
	get:
		return clampf(level_time / SKILL_RAMP_SECONDS, 0.0, 1.0) * MAX_TRACKING_SKILL

# Two independent guarded resource caches - one for wall-editing, one for
# bombs - each spawns every *_RESOURCE_SPAWN_INTERVAL seconds of play
# (never more than one of its own kind on the maze at a time). Separate
# timers/flags on purpose so a wall cache and a bomb cache can both be out
# on the map simultaneously; the bomb timer starts already half-elapsed so
# the two don't always pop in lockstep.
const RESOURCE_SPAWN_INTERVAL: float = 25.0
var _wall_resource_timer: float = 0.0
var _wall_resource_active: bool = false
const BOMB_RESOURCE_SPAWN_INTERVAL: float = 25.0
var _bomb_resource_timer: float = RESOURCE_SPAWN_INTERVAL / 2.0
var _bomb_resource_active: bool = false
var _origin: Vector2 = Vector2.ZERO

var portal_active: bool:
	get:
		return _portal_spawned

var portal_position: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if not action_started:
		return
	level_time += delta

	if not _wall_resource_active:
		_wall_resource_timer += delta
		if _wall_resource_timer >= RESOURCE_SPAWN_INTERVAL:
			_wall_resource_timer = 0.0
			_spawn_wall_resource_cache()

	if not _bomb_resource_active:
		_bomb_resource_timer += delta
		if _bomb_resource_timer >= BOMB_RESOURCE_SPAWN_INTERVAL:
			_bomb_resource_timer = 0.0
			_spawn_bomb_resource_cache()

func _ready() -> void:
	current = self

func build_level(level: int) -> void:
	current = self
	for c in get_children():
		c.queue_free()
	_portal_spawned = false
	action_started = false
	level_time = 0.0
	_wall_resource_timer = 0.0
	_wall_resource_active = false
	_bomb_resource_timer = RESOURCE_SPAWN_INTERVAL / 2.0
	_bomb_resource_active = false
	GameManager.reset_level_resources()

	var pars := DifficultySettings.for_level(level)
	var rng_seed: int = Time.get_ticks_usec() ^ (level * 7919)
	data = MazeGenerator.generate(pars.cols, pars.rows, pars.loop_chance, rng_seed)

	var maze_pixel_size := Vector2(data.cols * CELL_SIZE, data.rows * CELL_SIZE)
	var origin: Vector2 = -maze_pixel_size / 2.0
	_origin = origin
	graph = MazeGraph.new(data, CELL_SIZE, origin)

	_build_walls(origin)
	_spawn_players()
	_spawn_monsters(pars)

	EffectsFactory.spawn_materialize(self, Vector2.ZERO, Color.WHITE)

## Builds one WallSegment per maximal wall block instead of one per
## occupied cell/row. Two passes: first collapse each row into horizontal
## runs (as before), then grow each run downward through identical runs on
## the rows below so a straight vertical stretch becomes a single tall
## rectangle too - otherwise it renders as a stack of single-cell segments,
## each with its own border, which shows up as a wall that looks "broken"
## into little squares next to horizontal walls that look like one solid
## bar. A run is represented as Vector2i(start, end) (end exclusive) since
## GDScript has no native tuple type; "consumed" runs per row are tracked
## with a Dictionary used as a set.
func _build_walls(origin: Vector2) -> void:
	var half: float = CELL_SIZE / 2.0
	var w: int = data.width
	var h: int = data.height

	var runs_by_row: Array = [] # Array[Array[Vector2i]]
	for y in range(h):
		var runs: Array[Vector2i] = []
		var run_start: int = -1
		for x in range(w + 1):
			var is_blocked: bool = x < w and data.is_blocked(x, y)
			if is_blocked and run_start == -1:
				run_start = x
			if (not is_blocked or x == w) and run_start != -1:
				runs.append(Vector2i(run_start, x))
				run_start = -1
		runs_by_row.append(runs)

	var consumed: Array = [] # Array[Dictionary] (Vector2i -> true)
	for y in range(h):
		consumed.append({})

	for y in range(h):
		for run in runs_by_row[y]:
			if consumed[y].has(run):
				continue

			var y_end: int = y + 1
			while y_end < h and runs_by_row[y_end].has(run) and not consumed[y_end].has(run):
				consumed[y_end][run] = true
				y_end += 1

			var run_len: int = run.y - run.x
			var row_span: int = y_end - y
			var wall := WallSegment.new()
			wall.size_px = Vector2(run_len * half, row_span * half)
			add_child(wall)
			# Grid index i is centered at i*half (see MazeGraph.cell_to_world),
			# so a run of cells [start .. start+len-1] is centered at
			# (start + (len-1)/2) * half - NOT (start + len/2).
			var center_x_offset: float = (run.x + (run_len - 1) / 2.0) * half
			var center_y_offset: float = (y + (row_span - 1) / 2.0) * half
			wall.position = origin + Vector2(center_x_offset, center_y_offset)

func _spawn_players() -> void:
	var p1_spawn: Vector2 = graph.cell_to_world(0, 0)
	var p2_spawn: Vector2 = graph.cell_to_world(data.cols - 1, 0)

	var p1 := PlayerHuman.new()
	p1.player_index = 0
	p1.maze_ref = graph
	p1.spawn_point = p1_spawn
	add_child(p1)
	p1.global_position = p1_spawn

	var p2 := PlayerAI.new()
	p2.player_index = 1
	p2.maze_ref = graph
	p2.spawn_point = p2_spawn
	add_child(p2)
	p2.global_position = p2_spawn

func _spawn_monsters(pars: DifficultySettings.LevelParams) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var far_cells: Array[Vector2i] = []
	for cy in range(data.rows):
		for cx in range(data.cols):
			if cx > data.cols / 2 - 2 and cy > 1:
				far_cells.append(Vector2i(cx, cy))

	for i in range(pars.monster_count):
		var m: Monster
		var roll: float = rng.randf()
		if pars.wraith_unlocked and roll < 0.15:
			m = WraithMonster.new()
		elif pars.blaster_unlocked and roll < 0.35:
			m = BlasterMonster.new()
		elif roll < pars.hunter_ratio:
			m = HunterMonster.new()
		else:
			m = SkulkerMonster.new()

		m.maze_ref = graph
		add_child(m)
		m.speed *= pars.monster_speed_mul

		var cell: Vector2i = far_cells[rng.randi() % far_cells.size()] if far_cells.size() > 0 else Vector2i(data.cols - 1, data.rows - 1)
		m.global_position = graph.cell_to_world(cell.x, cell.y)
	_monsters_remaining = pars.monster_count

func on_monster_killed(m: Monster) -> void:
	if not m.get_counts_toward_clear():
		return # resource guardians don't gate the exit
	_monsters_remaining -= 1
	if _monsters_remaining <= 0 and not _portal_spawned:
		_portal_spawned = true
		SoundManager.play_portal()
		var portal_cell := Vector2i(data.cols / 2, data.rows / 2)
		portal_position = graph.cell_to_world(portal_cell.x, portal_cell.y)
		EffectsFactory.spawn_portal(self, portal_position)

func on_portal_entered() -> void:
	if Main.instance != null:
		Main.instance.complete_level()

func _spawn_wall_resource_cache() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cx: int = rng.randi() % data.cols
	var cy: int = rng.randi() % data.rows
	var pos: Vector2 = graph.cell_to_world(cx, cy)

	var pickup := ResourcePickup.new()
	pickup.kind = ResourcePickup.ResourceKind.WALL
	add_child(pickup)
	pickup.global_position = pos

	var warden := WardenMonster.new()
	warden.maze_ref = graph
	warden.anchor = pos
	add_child(warden)
	warden.global_position = pos

	SoundManager.play_resource_spawn()
	_wall_resource_active = true

## Same idea as the wall cache above, guarded by a different monster type
## (SentryMonster - a stationary shooter instead of a chaser), on its own
## independent timer/flag so it can be out on the map at the same time as a
## wall cache.
func _spawn_bomb_resource_cache() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cx: int = rng.randi() % data.cols
	var cy: int = rng.randi() % data.rows
	var pos: Vector2 = graph.cell_to_world(cx, cy)

	var pickup := ResourcePickup.new()
	pickup.kind = ResourcePickup.ResourceKind.BOMB
	add_child(pickup)
	pickup.global_position = pos

	var sentry := SentryMonster.new()
	sentry.maze_ref = graph
	add_child(sentry)
	sentry.global_position = pos

	SoundManager.play_resource_spawn()
	_bomb_resource_active = true

## Called by ResourcePickup when a player walks into it. Sharing rule: if
## the AI teammate isn't hostile toward you, the pickup is treated as a
## shared find and refills both of you - there's no way for grabbing it to
## read as "stealing" unless you're already fighting each other, in which
## case it's winner-takes-it.
func on_resource_collected(player_index: int, kind: ResourcePickup.ResourceKind) -> void:
	SoundManager.play_resource_pickup()
	var hostile: bool = GameManager.mood == GameManager.AiMood.HOSTILE

	if kind == ResourcePickup.ResourceKind.WALL:
		_wall_resource_active = false
		if hostile:
			GameManager.refill_resources(player_index)
		else:
			GameManager.refill_all_resources()
			GameManager.adjust_sympathy(10.0)
	else: # Bomb
		_bomb_resource_active = false
		if hostile:
			GameManager.refill_bomb_resources(player_index)
		else:
			GameManager.refill_all_bomb_resources()
			GameManager.adjust_sympathy(10.0)

## The strategic wall-editing action: toggles the wall directly between
## cell_a (where the player is standing) and cell_b (the cell they're
## facing), spending one resource. Breaking a wall only ever adds a
## connection, so it's always safe; building one is refused if it would
## cut the maze into an unreachable piece (see MazeGraph.would_disconnect)
## - there is deliberately no way to trap yourself, the AI, or a monster
## behind a wall you put up.
func try_alter_wall(player_index: int, cell_a: Vector2i, cell_b: Vector2i) -> bool:
	if graph == null:
		return false
	if cell_b.x < 0 or cell_b.x >= data.cols or cell_b.y < 0 or cell_b.y >= data.rows:
		return false # facing the outer boundary - nothing to edit there

	var currently_blocked: bool = graph.is_wall_between(cell_a, cell_b)

	if not currently_blocked and graph.would_disconnect(cell_a, cell_b):
		return false

	if not GameManager.spend_resource(player_index):
		return false

	graph.set_wall_between(cell_a, cell_b, not currently_blocked)
	_rebuild_wall_visuals()
	SoundManager.play_wall_alter()
	return true

func _rebuild_wall_visuals() -> void:
	for c in get_children():
		if c is WallSegment:
			c.queue_free()
	_build_walls(_origin)

## The bomb payoff: damages anyone standing in the blast (players take 2
## HP, same tier as a monster's touch; monsters take 3 - enough to
## one-shot even a 3-HP guardian, so a bomb is the hard counter to a
## Warden/Sentry turtling on its cache). Does NOT touch walls - a bomb is
## purely an area-damage tool, not a wall-editing shortcut (that's what
## the dedicated wall resource/try_alter_wall is for).
##
## A target only takes damage if it's both within `radius` AND has a clear
## line of sight to the blast center (_has_line_of_sight) - plain distance
## alone let a bomb hit someone standing right behind a wall in the next
## cell over, which reads as the wall doing nothing. A straight-line
## raycast against the wall collision layer is enough here since blast
## radius (90px) never reaches past one cell (CELL_SIZE 64px) anyway.
func detonate_bomb(pos: Vector2, owner_index: int, radius: float) -> void:
	SoundManager.play_explosion()
	EffectsFactory.spawn_death(self, pos, Color(1.0, 0.55, 0.1))

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	for n in get_tree().get_nodes_in_group("players"):
		if n is Player and is_instance_valid(n) and n.global_position.distance_to(pos) <= radius and _has_line_of_sight(space_state, pos, n.global_position):
			n.hit(n.player_index != owner_index, 2)
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and is_instance_valid(n) and n.global_position.distance_to(pos) <= radius and _has_line_of_sight(space_state, pos, n.global_position):
			n.take_damage(3, owner_index)

## True if nothing on the wall collision layer sits between `from` and
## `to` - walls are the only thing on layer 1 that a straight blast-radius
## check could otherwise ignore (see detonate_bomb).
func _has_line_of_sight(space_state: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1) # layer 1 = walls only
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()
