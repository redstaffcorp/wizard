class_name HunterMonster
extends Monster

## Chases the nearest player through the maze using the shared pathfinding
## graph. More dangerous than the Skulker but still blind to walls it
## can't path around. Lore-wise: a real predator living in the tunnels,
## not just vermin - the reason the asteroid needs "pacifying" before the
## crew can mine it safely.

var _path: Array[Vector2] = []
var _repath_timer: float = 0.0

func _ready() -> void:
	super._ready()
	body_color = Color(0.9, 0.15, 0.2) # red
	score_value = 150

func _physics_process(delta: float) -> void:
	if LevelRoot.current == null or not LevelRoot.current.action_started:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	_repath_timer -= delta
	if _path.size() == 0 or _repath_timer <= 0.0:
		_repath_to_nearest_player()
		_repath_timer = 0.7

	var dir := Vector2.ZERO
	if _path.size() > 0:
		var target: Vector2 = _path[0]
		if global_position.distance_to(target) < 6.0:
			_path.remove_at(0)
			if _path.size() > 0:
				target = _path[0]
		var diff: Vector2 = target - global_position
		if diff.length() > 1.0:
			dir = Vector2(signf(diff.x), 0.0) if absf(diff.x) > absf(diff.y) else Vector2(0.0, signf(diff.y))

	velocity = dir * speed + lane_centering_velocity(dir)
	move_and_slide()
	wrap_if_needed()
	queue_redraw()

func _repath_to_nearest_player() -> void:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var best: float = INF
	for pn in players:
		if pn is Node2D and is_instance_valid(pn):
			var d: float = pn.global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				nearest = pn
	_path.clear()
	if nearest != null and maze_ref != null:
		_path.append_array(maze_ref.find_path(global_position, nearest.global_position))

func draw_shape() -> void:
	var trim := body_color.darkened(0.45)
	draw_colored_polygon(DrawUtil.regular_polygon(5, 13.0, -PI / 2.0), body_color)

	# Dorsal spikes along the back ridge - reads as a predator stalking the
	# tunnels, not just a colored pentagon.
	draw_line(Vector2(-4, -12), Vector2(-4, -15.5), trim, 1.8)
	draw_line(Vector2(0, -13), Vector2(0, -16.3), trim, 1.8)
	draw_line(Vector2(4, -12), Vector2(4, -15.5), trim, 1.8)

	# A whip-tail trailing away from its direction of travel.
	var tail_dir: Vector2 = -velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
	draw_line(Vector2.ZERO, tail_dir * 9.0, trim, 2.0)

	# Angled "eyebrows" over the eyes - a quick, cheap way to read as
	# aggressive, matching that this is the one that relentlessly chases.
	draw_line(Vector2(-8, -6.5), Vector2(-2.5, -4.5), trim, 1.8)
	draw_line(Vector2(8, -6.5), Vector2(2.5, -4.5), trim, 1.8)

	DrawUtil.draw_glow_eyes(self, velocity, Color(1.0, 0.25, 0.2), -3.0, 5.0, 1.8)
