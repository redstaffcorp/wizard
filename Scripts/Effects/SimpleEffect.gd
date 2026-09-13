class_name SimpleEffect
extends Node2D

## A tiny, self-contained visual effect (no particle assets, no textures):
## it draws itself for a short duration and then frees itself. Used for
## bullet impacts, deaths and spawn "materialize" pops.

enum Kind { SPARK, DEATH, MATERIALIZE }

var _kind: Kind
var _color: Color
var _t: float = 0.0
var _duration: float

func _init(kind: Kind = Kind.SPARK, color: Color = Color.WHITE) -> void:
	_kind = kind
	_color = color
	_duration = 0.2 if kind == Kind.SPARK else (0.45 if kind == Kind.DEATH else 0.5)

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f: float = _t / _duration
	match _kind:
		Kind.SPARK:
			var r: float = lerpf(2.0, 14.0, f)
			draw_circle(Vector2.ZERO, r, Color(_color, 1.0 - f))
		Kind.DEATH:
			for i in range(8):
				var a: float = i * TAU / 8.0
				var r: float = lerpf(2.0, 26.0, f)
				var p := Vector2(cos(a), sin(a)) * r
				draw_circle(p, lerpf(5.0, 0.5, f), Color(_color, 1.0 - f))
		Kind.MATERIALIZE:
			var r2: float = lerpf(28.0, 4.0, f)
			draw_arc(Vector2.ZERO, r2, 0.0, TAU, 24, Color(_color, 1.0 - f * 0.4), 3.0)
