class_name SkulkerMonster
extends Monster

## Base wandering monster: picks a random open direction at every
## intersection. Slow and simple, present from level 1. Lore-wise: small
## vermin that infest a newly-opened asteroid tunnel - the mining crew's
## most common, least dangerous nuisance.

var _dir: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _retarget_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_rng.randomize()
	body_color = Color(0.95, 0.55, 0.15) # orange
	score_value = 100

func _physics_process(delta: float) -> void:
	if LevelRoot.current == null or not LevelRoot.current.action_started:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	_retarget_timer -= delta

	var cell: Vector2i = maze_ref.world_to_cell(global_position)
	var cell_center: Vector2 = maze_ref.cell_to_world(cell.x, cell.y)
	var at_center: bool = global_position.distance_to(cell_center) < 4.0

	if _dir == Vector2i.ZERO or (at_center and _retarget_timer <= 0.0):
		_dir = _pick_dir(cell)
		_retarget_timer = 0.15

	var dir_v := Vector2(_dir.x, _dir.y)
	velocity = dir_v * speed + lane_centering_velocity(dir_v)
	move_and_slide()
	wrap_if_needed()
	queue_redraw()

## Random most of the time, but with rising odds (LevelRoot.tracking_skill)
## of instead picking the neighbor that closes distance to a player.
func _pick_dir(cell: Vector2i) -> Vector2i:
	var skill: float = LevelRoot.current.tracking_skill if LevelRoot.current != null else 0.0
	if skill > 0.0 and _rng.randf() < skill:
		var target := find_nearest_player()
		if target != null:
			return maze_ref.greedy_neighbor_dir(cell, target.global_position)
	return maze_ref.random_open_neighbor_dir(cell, _rng)

func draw_shape() -> void:
	var trim := body_color.darkened(0.4)
	var dark := body_color.darkened(0.55)

	# A small rear abdomen segment, drawn behind the thorax - reads as a
	# scuttling bug/grub rather than a bare polygon.
	draw_colored_polygon(DrawUtil.offset_points(DrawUtil.regular_polygon(6, 6.0), Vector2(0, 7)), dark)

	draw_colored_polygon(DrawUtil.regular_polygon(7, 11.0), body_color)

	# Three pairs of thin jointed legs splayed to the sides.
	for i in range(3):
		var ly: float = -4.0 + i * 4.0
		draw_line(Vector2(-9, ly), Vector2(-15, ly + 3.0), trim, 1.6)
		draw_line(Vector2(9, ly), Vector2(15, ly + 3.0), trim, 1.6)

	# Antennae.
	draw_line(Vector2(-4, -10), Vector2(-7, -15), trim, 1.6)
	draw_line(Vector2(4, -10), Vector2(7, -15), trim, 1.6)
	draw_circle(Vector2(-7, -15), 1.4, trim)
	draw_circle(Vector2(7, -15), 1.4, trim)

	# Glowing insectoid eyes instead of a human-style face - reads as
	# "alien vermin" rather than a cartoon critter.
	DrawUtil.draw_glow_eyes(self, velocity, Color(1.0, 0.85, 0.3), -6.0, 4.0, 1.8)
