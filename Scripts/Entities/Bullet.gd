class_name Bullet
extends Area2D

## A simple projectile. Player shots and enemy shots are the same class
## with different collision filters and colors, drawn as a small colored
## bar - no sprite art required.

var direction: Vector2 = Vector2.RIGHT
var from_player: bool = true
var owner_index: int = 0

@export var speed: float = 340.0
@export var max_distance: float = 520.0

var _start: Vector2

func _ready() -> void:
	_start = global_position
	monitoring = true
	collision_layer = 0
	collision_mask = 0

	if from_player:
		set_collision_layer_value(4, true) # Layer 4 = player bullets
		set_collision_mask_value(1, true)  # walls
		set_collision_mask_value(3, true)  # monsters
		set_collision_mask_value(2, true)  # players (friendly fire, like the original arcade game)
	else:
		set_collision_layer_value(5, true) # Layer 5 = enemy bullets
		set_collision_mask_value(1, true)  # walls
		set_collision_mask_value(2, true)  # players

	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 4)
	add_child(shape)
	rotation = direction.angle()
	z_index = 2
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(_start) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is WallSegment:
		EffectsFactory.spawn_spark(get_parent(), global_position)
		queue_free()
	elif from_player and body is Monster:
		body.take_damage(1, owner_index)
		queue_free()
	elif from_player and body is Player and body.player_index != owner_index:
		body.hit(true, 1) # friendly fire - can turn the AI hostile
		queue_free()
	elif not from_player and body is Player:
		body.hit(false, 1)
		queue_free()

func _draw() -> void:
	var c: Color = Color(1.0, 0.95, 0.2) if from_player else Color(0.95, 0.2, 0.75)
	draw_rect(Rect2(-6, -2, 12, 4), c, true)
