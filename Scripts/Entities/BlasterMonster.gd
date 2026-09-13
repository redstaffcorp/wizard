class_name BlasterMonster
extends Monster

## Wanders like the Skulker, but periodically checks for a clear, straight
## line of sight to a player along a corridor and fires a bullet. Unlocked
## from level 3 onward.

var _dir: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _retarget_timer: float = 0.0
var _shoot_cooldown: float = 1.0
var _active_bullet: Bullet = null # only one of our own bullets in flight at a time
var _aim_dir: Vector2 = Vector2.DOWN # last shot direction, for the barrel/face when standing still

func _ready() -> void:
	super._ready()
	_rng.randomize()
	body_color = Color(0.65, 0.25, 0.85) # purple
	score_value = 200
	speed = 90.0

func _physics_process(delta: float) -> void:
	if LevelRoot.current == null or not LevelRoot.current.action_started:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	_retarget_timer -= delta
	_shoot_cooldown -= delta

	var cell: Vector2i = maze_ref.world_to_cell(global_position)
	var cell_center: Vector2 = maze_ref.cell_to_world(cell.x, cell.y)
	var at_center: bool = global_position.distance_to(cell_center) < 4.0

	if _dir == Vector2i.ZERO or (at_center and _retarget_timer <= 0.0):
		_dir = _pick_dir(cell)
		_retarget_timer = 0.6

	var dir_v := Vector2(_dir.x, _dir.y)
	velocity = dir_v * speed + lane_centering_velocity(dir_v)
	move_and_slide()
	wrap_if_needed()

	if _shoot_cooldown <= 0.0 and at_center and not is_instance_valid(_active_bullet):
		_try_shoot_at_player()

	queue_redraw()

func _try_shoot_at_player() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for p_node in players:
		if not (p_node is Player) or not is_instance_valid(p_node):
			continue
		var p: Player = p_node

		var diff: Vector2 = p.global_position - global_position
		var dir := Vector2.ZERO
		if absf(diff.y) < 8.0 and absf(diff.x) > 8.0:
			dir = Vector2(signf(diff.x), 0.0)
		elif absf(diff.x) < 8.0 and absf(diff.y) > 8.0:
			dir = Vector2(0.0, signf(diff.y))
		if dir == Vector2.ZERO:
			continue

		var space_state := get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(global_position, p.global_position)
		query.collision_mask = (1 << 0) | (1 << 1) # walls + players
		var result := space_state.intersect_ray(query)
		if result.size() > 0 and result["collider"] is Player:
			SoundManager.play_enemy_shoot()
			var bullet := Bullet.new()
			bullet.direction = dir
			bullet.from_player = false
			get_parent().add_child(bullet)
			bullet.global_position = global_position + dir * 16.0
			_active_bullet = bullet
			_shoot_cooldown = 2.2
			_aim_dir = dir
			break

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
	draw_colored_polygon(DrawUtil.regular_polygon(6, 14.0), body_color)
	var look: Vector2 = velocity if velocity.length() > 0.5 else _aim_dir
	# A short barrel nub pointing the way it last fired/is moving, so its
	# "I shoot at range" role reads even while it's standing still.
	var trim := body_color.darkened(0.4)
	var barrel_dir: Vector2 = look.normalized() if look.length() > 0.01 else Vector2.DOWN
	draw_line(Vector2.ZERO, barrel_dir * 18.0, trim, 3.0)
	DrawUtil.draw_face(self, look)
