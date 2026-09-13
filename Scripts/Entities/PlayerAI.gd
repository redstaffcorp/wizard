class_name PlayerAI
extends Player

## The CPU-controlled second player. This runs its own simple logic,
## independent from the monster AI classes: it re-targets the nearest
## monster periodically, paths to it through the maze graph, and only
## shoots when roughly lined up with its target along a corridor.

# So a killed Monster can notify "the" AI teammate without a scene lookup.
# Reassigned each level in _ready, same pattern as LevelRoot.current /
# Main.instance.
static var instance: PlayerAI = null

# How far the AI "notices" a monster from. Without this it has perfect,
# instant knowledge of every monster on the whole map and beelines the
# globally nearest one the moment it dies/spawns, which reads as an
# unbeatable aimbot rather than a teammate.
const DETECTION_RADIUS: float = 300.0
const DETECTION_RADIUS_SQ: float = DETECTION_RADIUS * DETECTION_RADIUS

var _path: Array[Vector2] = []
var _repath_timer: float = 0.0
var _target: Node2D = null

func _ready() -> void:
	super._ready()
	instance = self
	body_color = Color(0.3, 0.55, 0.95) # blue
	speed = 115.0
	max_bullets = 1

func get_desired_direction(delta: float) -> Vector2:
	_repath_timer -= delta
	if (_path.size() == 0 or _repath_timer <= 0.0) and maze_ref != null:
		_repick_target()
		_repath_timer = 0.6

	if _path.size() > 0:
		var target: Vector2 = _path[0]
		if global_position.distance_to(target) < 6.0:
			_path.remove_at(0)
			if _path.size() > 0:
				target = _path[0]
		var diff: Vector2 = target - global_position
		if diff.length() < 1.0:
			return Vector2.ZERO
		return Vector2(signf(diff.x), 0.0) if absf(diff.x) > absf(diff.y) else Vector2(0.0, signf(diff.y))
	return Vector2.ZERO

## Priority: 1) once the level is cleared, head for the exit portal and
## leave through it if possible; 2) if hostile, hunt the human instead of
## monsters; 3) if friendly, prioritize whatever monster threatens the
## human (not whichever is closest to us) - reads as "covering" them;
## 4) neutral: just hunt the nearest monster.
func _repick_target() -> void:
	if LevelRoot.current != null and LevelRoot.current.portal_active:
		_target = null
		_path.clear()
		_path.append_array(maze_ref.find_path(global_position, LevelRoot.current.portal_position))
		return

	var human: PlayerHuman = _find_human()

	if GameManager.mood == GameManager.AiMood.HOSTILE and human != null:
		_target = human
		_path.clear()
		_path.append_array(maze_ref.find_path(global_position, human.global_position))
		return

	# Neutral/Friendly, or hostile with no human left to hunt (they were
	# eliminated) - either way, go after monsters instead of standing
	# around doing nothing.
	var ref_point: Vector2 = global_position
	if GameManager.mood == GameManager.AiMood.FRIENDLY and human != null:
		ref_point = human.global_position

	var monsters := get_tree().get_nodes_in_group("monsters")
	var nearest: Node2D = null
	var best: float = INF
	for m in monsters:
		if m is Node2D and is_instance_valid(m):
			var d: float = m.global_position.distance_squared_to(ref_point)
			if d < best:
				best = d
				nearest = m

	if nearest != null and best <= DETECTION_RADIUS_SQ:
		_target = nearest
		_path.clear()
		_path.append_array(maze_ref.find_path(global_position, nearest.global_position))
		return

	# Nothing worth engaging nearby - stick close to the human instead of
	# freezing or wandering off on its own.
	_target = null
	_path.clear()
	if human != null and human.global_position.distance_to(global_position) > 96.0:
		_path.append_array(maze_ref.find_path(global_position, human.global_position))

func _find_human() -> PlayerHuman:
	for n in get_tree().get_nodes_in_group("players"):
		if n is PlayerHuman and is_instance_valid(n):
			return n
	return null

func on_attacked_by_other_player() -> void:
	GameManager.adjust_sympathy(-70.0)

## Called by Monster.kill() before it frees itself, so the sympathy score
## can react to *how* a monster died: did the human bail the AI out of a
## near-death hit, steal the AI's own target, or just happen to be fighting
## alongside it?
func notify_monster_killed(killer_index: int, kill_pos: Vector2, killed: Monster) -> void:
	var human: PlayerHuman = _find_human()
	if human == null:
		return
	var killed_by_human: bool = killer_index == 0

	if killed_by_human and current_hp == 1 and kill_pos.distance_to(global_position) < 90.0:
		GameManager.adjust_sympathy(40.0) # rescued at critical HP
		return

	if killed_by_human and killed == _target:
		GameManager.adjust_sympathy(-6.0) # stole our target
		return

	if global_position.distance_to(human.global_position) < 220.0:
		GameManager.adjust_sympathy(8.0) # fighting side by side

func wants_to_shoot() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var diff: Vector2 = _target.global_position - global_position

	var aligned_x: bool = facing_dir.x != 0.0 and absf(diff.y) < 10.0 and signf(diff.x) == signf(facing_dir.x)
	var aligned_y: bool = facing_dir.y != 0.0 and absf(diff.x) < 10.0 and signf(diff.y) == signf(facing_dir.y)
	return (aligned_x or aligned_y) and diff.length() < DETECTION_RADIUS

func draw_shape() -> void:
	if invulnerable and int(Time.get_ticks_msec() / 100) % 2 == 0:
		return

	# Visibly turns red once hostile, so it's obvious that's dangerous -
	# but friendly vs. neutral look identical, so those have to be read
	# from behavior instead. The star badge is a constant, mood-independent
	# way to tell "the teammate" apart from the human at a glance.
	var color: Color = Color(0.9, 0.25, 0.2) if GameManager.mood == GameManager.AiMood.HOSTILE else body_color
	DrawUtil.draw_wizard(self, color, facing_dir, true)
