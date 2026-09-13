class_name ResourcePickup
extends Area2D

## A gold gem sitting under a guardian monster's watch (WardenMonster for
## the wall-editing pool, SentryMonster for the bomb pool - see
## LevelRoot.spawn_wall_resource_cache/spawn_bomb_resource_cache). Looks
## identical either way; kind is what tells LevelRoot which resource pool
## to refill. Walking into it refills that pool - shared between both
## players unless the AI teammate is currently hostile (see
## LevelRoot.on_resource_collected).

enum ResourceKind { WALL, BOMB }
var kind: ResourceKind = ResourceKind.WALL

func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true) # players
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 14.0
	add_child(shape)
	z_index = 2
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if LevelRoot.current != null:
		LevelRoot.current.on_resource_collected(body.player_index, kind)
	queue_free()

func _draw() -> void:
	var outer := DrawUtil.regular_polygon(4, 12.0, PI / 4.0)
	var inner := DrawUtil.regular_polygon(4, 6.0, PI / 4.0)
	draw_colored_polygon(outer, Color(0.75, 0.55, 0.05)) # darker gold base
	draw_colored_polygon(inner, Color(1.0, 0.92, 0.4))   # bright gold core
