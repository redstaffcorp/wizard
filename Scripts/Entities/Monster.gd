class_name Monster
extends MazeActor

## Base for all enemy types. None of these are meant to resemble any
## existing game's characters - they're original names/shapes/colors:
## Skulker (wanderer), Hunter (chaser), Blaster (ranged), Wraith (phaser).

var score_value: int = 100
var body_color: Color = Color.ORANGE_RED
var last_hit_by_player: int = 0
var phasing: bool = false

var _current_monster_hp: int = 0

func _ready() -> void:
	super._ready()
	set_collision_layer_value(3, true) # Layer 3 = monsters
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 10.0
	add_child(shape)

	var touch := Area2D.new()
	touch.collision_layer = 0
	touch.collision_mask = 0
	touch.set_collision_mask_value(2, true) # detect players
	var tshape := CollisionShape2D.new()
	tshape.shape = CircleShape2D.new()
	tshape.shape.radius = 12.0
	touch.add_child(tshape)
	touch.body_entered.connect(_on_touch)
	add_child(touch)

	add_to_group("monsters")
	_current_monster_hp = get_max_monster_hp()

## Overridable so a tougher type (see WardenMonster) can take more than one
## hit to put down without every other monster having to know or care
## about HP at all. GDScript has no virtual-property override, so this is
## a method every subclass with non-default HP overrides.
func get_max_monster_hp() -> int:
	return 1

## Whether killing this monster counts toward opening the exit portal.
## Resource-guardian monsters don't - the loot they guard is optional, so
## the level must stay clearable without touching it.
func get_counts_toward_clear() -> bool:
	return true

func _on_touch(body: Node) -> void:
	if body is Player:
		body.hit(false, 2)

## Player bullets deal damage instead of an instant kill, so a multi-HP
## monster can survive a hit. Still dies in one shot for every type with
## the default 1 HP.
func take_damage(amount: int, by_player_index: int) -> void:
	last_hit_by_player = by_player_index
	_current_monster_hp -= amount
	if _current_monster_hp <= 0:
		kill()
	else:
		EffectsFactory.spawn_spark(get_parent(), global_position)

## Shared by the wandering monster types so they can occasionally home in
## on a player instead of always moving randomly.
func find_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var best: float = INF
	for n in get_tree().get_nodes_in_group("players"):
		if n is Node2D and is_instance_valid(n):
			var d: float = n.global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				nearest = n
	return nearest

func kill() -> void:
	SoundManager.play_monster_death()
	if is_instance_valid(PlayerAI.instance):
		PlayerAI.instance.notify_monster_killed(last_hit_by_player, global_position, self)
	EffectsFactory.spawn_death(get_parent(), global_position, body_color)
	GameManager.add_score(last_hit_by_player, score_value)
	var root := LevelRoot.current
	queue_free()
	if root != null:
		root.on_monster_killed(self)
