class_name WardenMonster
extends Monster

## The tough monster that guards a resource cache. Doesn't wander - it
## stands watch over its spawn point (anchor) and only leaves it to chase
## off a player who gets close, returning once they retreat. Takes 3 hits
## to put down and doesn't count toward clearing the level, since the loot
## it guards is optional. Lore-wise: a heavily armored alien that has
## staked a claim on a rich ore deposit and won't give it up quietly.

func get_max_monster_hp() -> int:
	return 3

func get_counts_toward_clear() -> bool:
	return false

var anchor: Vector2 = Vector2.ZERO

const GUARD_RADIUS: float = 260.0

var _path: Array[Vector2] = []
var _repath_timer: float = 0.0

func _ready() -> void:
	super._ready()
	body_color = Color(0.55, 0.1, 0.18) # dark red, bulky
	score_value = 500
	speed = 75.0

func _physics_process(delta: float) -> void:
	if LevelRoot.current == null or not LevelRoot.current.action_started:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	_repath_timer -= delta
	if _path.size() == 0 or _repath_timer <= 0.0:
		_repath()
		_repath_timer = 0.5

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

func _repath() -> void:
	var nearest := find_nearest_player()
	var goal: Vector2 = anchor
	if nearest != null and nearest.global_position.distance_to(anchor) < GUARD_RADIUS:
		goal = nearest.global_position # an intruder got close to the loot - drive them off

	_path.clear()
	if maze_ref != null:
		_path.append_array(maze_ref.find_path(global_position, goal))

## Note on sizing: the maze's corridors are only 32px tall/wide between
## walls (LevelRoot._build_walls uses CELL_SIZE/2 per wall-grid unit), so
## everything here stays within about +/-15px of center - an earlier pass
## at this shape (17px body radius, tusks, HP pips floating at y=-30) blew
## way past that and stuck out of the tunnels it patrols (same class of
## bug the player's space-suit redesign had before it was scaled down).
func draw_shape() -> void:
	var trim := body_color.darkened(0.35)
	draw_colored_polygon(DrawUtil.regular_polygon(8, 13.0), body_color)

	# Armor ridge plates along the back - reads as a heavily armored guard.
	draw_rect(Rect2(-9, -13, 6, 3), trim)
	draw_rect(Rect2(3, -13, 6, 3), trim)

	# Two tusks - a cheap way to read as "bulky guard/tank", to go with it
	# being the toughest, slowest-to-provoke monster type.
	draw_line(Vector2(-7, -1), Vector2(-11, 6), trim, 2.5)
	draw_line(Vector2(7, -1), Vector2(11, 6), trim, 2.5)

	DrawUtil.draw_glow_eyes(self, velocity, Color(1.0, 0.65, 0.15), -6.0, 5.5, 2.2)

	# Small HP pips, kept on the body (not floating above it) so they never
	# poke into a wall.
	for i in range(_current_monster_hp):
		draw_circle(Vector2(-8 + i * 8, -9), 1.8, Color.WHITE)
