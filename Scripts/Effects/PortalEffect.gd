class_name PortalEffect
extends Area2D

## Appears once all monsters on a level are cleared. Either player can walk
## into it to advance to the next (harder) level.

var _t: float = 0.0

func _ready() -> void:
	z_index = 4
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(6, true) # Layer 6 = portal
	set_collision_mask_value(2, true)  # detect players
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 22.0
	add_child(shape)
	body_entered.connect(_on_entered)

func _on_entered(body: Node) -> void:
	if body is Player:
		if LevelRoot.current != null:
			LevelRoot.current.on_portal_entered()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse: float = 0.7 + 0.3 * sin(_t * 4.0)
	var c := Color(0.3, 0.9, 0.9, 0.85)
	for i in range(3):
		var r: float = (14.0 + i * 6.0) * pulse
		draw_arc(Vector2.ZERO, r, _t * (2.0 + i), _t * (2.0 + i) + TAU * 0.75, 20, c, 3.0)
	draw_circle(Vector2.ZERO, 6.0, c)
