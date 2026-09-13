class_name Player
extends MazeActor

## Base for both the human-controlled and the AI-controlled character.
## Neither looks like anything from the original arcade game: both are
## drawn as a stocky space-suit miner with a heavy cannon (see
## DrawUtil.draw_space_miner), still just primitive shapes composed in
## code, no external art assets. Movement reads through
## get_desired_direction()/wants_to_shoot() so input can later come from
## touch controls without touching this class.

@export var player_index: int = 0 # 0 = P1 (human), 1 = P2 (CPU)
var body_color: Color = Color.LIME_GREEN
var facing_dir: Vector2 = Vector2.DOWN
var spawn_point: Vector2 = Vector2.ZERO
var invulnerable: bool = false
var current_hp: int = 0

var shoot_cooldown: float = 0.32
# Only one of this shooter's own bullets may be in flight at once - no
# spamming a second shot until the first has hit something or expired.
var max_bullets: int = 1

var _shoot_timer: float = 0.0
var _invuln_timer: float = 0.0
var _active_bullets: Array[Bullet] = []

func _ready() -> void:
	super._ready()
	set_collision_layer_value(2, true) # Layer 2 = players
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 11.0
	add_child(shape)
	add_to_group("players")
	current_hp = GameManager.MAX_HP
	GameManager.set_hp(player_index, current_hp)

func _physics_process(delta: float) -> void:
	if LevelRoot.current == null or not LevelRoot.current.action_started:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	if _shoot_timer > 0.0:
		_shoot_timer -= delta
	if invulnerable:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			invulnerable = false

	var dir: Vector2 = get_desired_direction(delta)
	if dir != Vector2.ZERO:
		facing_dir = dir

	velocity = dir * speed + lane_centering_velocity(dir)
	move_and_slide()
	wrap_if_needed()

	_active_bullets = _active_bullets.filter(func(b): return is_instance_valid(b))
	if wants_to_shoot() and _shoot_timer <= 0.0 and _active_bullets.size() < max_bullets:
		_active_bullets.append(_fire_bullet())
		_shoot_timer = shoot_cooldown

	queue_redraw()

func get_desired_direction(_delta: float) -> Vector2:
	return Vector2.ZERO

func wants_to_shoot() -> bool:
	return false

func _fire_bullet() -> Bullet:
	SoundManager.play_shoot()
	var bullet := Bullet.new()
	bullet.direction = facing_dir
	bullet.from_player = true
	bullet.owner_index = player_index
	get_parent().add_child(bullet)
	bullet.global_position = global_position + facing_dir * 18.0
	return bullet

func hit(by_other_player: bool = false, damage: int = 1) -> void:
	if invulnerable:
		return
	SoundManager.play_player_hit()
	if by_other_player:
		on_attacked_by_other_player()

	current_hp -= damage
	GameManager.set_hp(player_index, maxi(current_hp, 0))

	if current_hp > 0:
		# Survived the hit: short i-frame only, no life lost, no respawn.
		invulnerable = true
		_invuln_timer = 0.5
		EffectsFactory.spawn_spark(get_parent(), global_position)
		return

	EffectsFactory.spawn_death(get_parent(), global_position, body_color)
	var eliminated: bool = GameManager.lose_life(player_index)
	if not eliminated:
		respawn_at(spawn_point)
	else:
		queue_free()

## Hook for subclasses (the AI teammate turning hostile after being shot by
## the human). No-op by default.
func on_attacked_by_other_player() -> void:
	pass

func respawn_at(pos: Vector2) -> void:
	global_position = pos
	invulnerable = true
	_invuln_timer = 1.6
	current_hp = GameManager.MAX_HP
	GameManager.set_hp(player_index, current_hp)
	EffectsFactory.spawn_materialize(get_parent(), pos, body_color)

func draw_shape() -> void:
	if invulnerable and int(Time.get_ticks_msec() / 100) % 2 == 0:
		return # blink while invulnerable

	DrawUtil.draw_space_miner(self, body_color, facing_dir)
