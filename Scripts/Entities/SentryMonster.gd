class_name SentryMonster
extends Monster

## The guardian for a bomb-resource cache. Mechanically the opposite of
## WardenMonster on purpose - it never moves, so it can't be kited away
## from its cache, and it fights back at range instead of by chasing:
## whenever a player lines up along a clear straight corridor, it shoots
## (same raycast line-of-sight trick as BlasterMonster). Takes 3 hits to
## put down and doesn't count toward clearing the level, since the loot it
## guards is optional. Lore-wise: a rooted, plant-like alien that anchors
## itself over a deposit and defends it at range instead of chasing.

func get_max_monster_hp() -> int:
	return 3

func get_counts_toward_clear() -> bool:
	return false

var _shoot_cooldown: float = 1.0
var _active_bullet: Bullet = null # only one of our own bullets in flight at a time
var _aim_dir: Vector2 = Vector2.DOWN # last shot direction, so the turret barrel has somewhere to point

func _ready() -> void:
	super._ready()
	body_color = Color(0.1, 0.55, 0.55) # teal
	score_value = 400
	speed = 0.0

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	if LevelRoot.current == null or not LevelRoot.current.action_started:
		queue_redraw()
		return

	_shoot_cooldown -= delta
	if _shoot_cooldown <= 0.0 and not is_instance_valid(_active_bullet):
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
			_shoot_cooldown = 1.8
			_aim_dir = dir
			break

## See the sizing note on WardenMonster.draw_shape() - the corridors are
## only 32px tall/wide, so this stays within about +/-15px including the
## barrel at full reach (the original 16px body + 19px barrel + HP pips at
## y=-28 badly overshot that).
func draw_shape() -> void:
	var trim := body_color.darkened(0.4)

	# Root tendrils anchoring it to the rock - reinforces that it never
	# moves, unlike every other monster type.
	draw_line(Vector2(-6, 9), Vector2(-9, 14), trim, 2.0)
	draw_line(Vector2(6, 9), Vector2(9, 14), trim, 2.0)
	draw_line(Vector2(0, 10), Vector2(0, 15), trim, 2.0)

	draw_colored_polygon(DrawUtil.regular_polygon(4, 12.0, PI / 4.0), body_color)

	# A turret barrel pointing the way it last fired - never moves, so this
	# is the only cue for "this is an aimed, ranged guardian".
	draw_line(Vector2.ZERO, _aim_dir * 11.0, trim, 3.2)
	draw_circle(_aim_dir * 11.0, 1.8, Color(0.4, 1.0, 0.9))

	DrawUtil.draw_glow_eyes(self, _aim_dir, Color(0.4, 1.0, 0.9), -6.0, 5.0, 2.0)

	# Small HP pips, kept on the body instead of floating above it.
	for i in range(_current_monster_hp):
		draw_circle(Vector2(-8 + i * 8, -8), 1.8, Color.WHITE)
