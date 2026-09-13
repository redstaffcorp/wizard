class_name Bomb
extends Node2D

## The payoff of the bomb resource: dropped at the player's feet (see
## PlayerHuman._try_place_bomb), sits and blinks through a short fuse, then
## hands off to LevelRoot.detonate_bomb for the actual damage/wall-break
## and removes itself. Deliberately has no collision of its own - it
## doesn't block movement, it just counts down.

var owner_index: int = 0
var fuse_time: float = 1.6
var blast_radius: float = 90.0

var _timer: float

func _ready() -> void:
	_timer = fuse_time
	z_index = 2

func _process(delta: float) -> void:
	_timer -= delta
	queue_redraw()
	if _timer <= 0.0:
		if LevelRoot.current != null:
			LevelRoot.current.detonate_bomb(global_position, owner_index, blast_radius)
		queue_free()

func _draw() -> void:
	# Blinks faster as the fuse runs down toward zero.
	var t: float = maxf(_timer, 0.0)
	var blink_rate: float = lerpf(2.0, 10.0, 1.0 - t / fuse_time)
	var lit: bool = int(Time.get_ticks_msec() / (1000.0 / blink_rate / 2.0)) % 2 == 0

	draw_circle(Vector2.ZERO, 10.0, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.25, 0.1) if lit else Color(0.4, 0.1, 0.05), false, 2.0)
	if lit:
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.8, 0.2))
