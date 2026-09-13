class_name WraithMonster
extends Monster

## Wanders normally, but periodically turns translucent and passes
## straight through walls for a short burst before returning to normal.
## Unlocked from level 5 onward - the "escape artist" of the bunch.
## Lore-wise: a living seam of the asteroid's own mineral vein, spectral
## enough to phase through the surrounding rock at will.

var _dir: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _retarget_timer: float = 0.0
var _phase_timer: float = 0.0
var _phase_cooldown: float = 4.0

func _ready() -> void:
	super._ready()
	_rng.randomize()
	body_color = Color(0.72, 0.8, 0.95) # pale icy blue-grey - a "mineral spirit"
	score_value = 300
	speed = 100.0

func _physics_process(delta: float) -> void:
	if LevelRoot.current == null or not LevelRoot.current.action_started:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	_retarget_timer -= delta
	_phase_cooldown -= delta

	if phasing:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			phasing = false
			set_collision_mask_value(1, true)
			modulate = Color(1, 1, 1, 1)
	elif _phase_cooldown <= 0.0:
		phasing = true
		_phase_timer = 1.2
		_phase_cooldown = 5.0
		set_collision_mask_value(1, false) # pass through walls briefly
		modulate = Color(1, 1, 1, 0.45)

	var cell: Vector2i = maze_ref.world_to_cell(global_position)
	var cell_center: Vector2 = maze_ref.cell_to_world(cell.x, cell.y)
	var at_center: bool = global_position.distance_to(cell_center) < 4.0

	if phasing:
		if _dir == Vector2i.ZERO:
			_dir = Vector2i(1, 0)
	elif _dir == Vector2i.ZERO or (at_center and _retarget_timer <= 0.0):
		_dir = _pick_dir(cell)
		_retarget_timer = 0.2

	var dir_v := Vector2(_dir.x, _dir.y)
	velocity = dir_v * speed * (1.4 if phasing else 1.0) + (Vector2.ZERO if phasing else lane_centering_velocity(dir_v))
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
	var pts := DrawUtil.ghost_shape(13.0)
	draw_colored_polygon(pts, body_color)

	# A couple of jagged crystal shards on top - ties the "phases through
	# rock" trick to the asteroid's own minerals instead of reading as a
	# generic ghost. Kept short (tip at y=-16) so they don't poke past the
	# 32px-tall corridors - see the sizing note on WardenMonster.draw_shape.
	var shard_color: Color = body_color.lightened(0.2)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -12), Vector2(-3, -16), Vector2(-1, -12)]), shard_color)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -12), Vector2(5, -16.3), Vector2(7, -12)]), shard_color)

	var look: Vector2 = Vector2(_dir.x, _dir.y) if _dir != Vector2i.ZERO else velocity
	if phasing:
		# No sclera while phased through walls - hollow glowing eyes read
		# as "ghostly" rather than "has an ordinary face" right when it's
		# doing its signature trick.
		DrawUtil.draw_glow_eyes(self, look, Color(0.85, 0.95, 1.0))
	else:
		DrawUtil.draw_face(self, look, -4.0, 4.5)
