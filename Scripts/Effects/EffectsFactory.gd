class_name EffectsFactory
extends RefCounted

## Convenience spawners so gameplay code doesn't need to know about the
## effect node types directly.

static func spawn_spark(parent: Node, pos: Vector2) -> void:
	var fx := SimpleEffect.new(SimpleEffect.Kind.SPARK, Color.WHITE)
	parent.add_child(fx)
	fx.global_position = pos

static func spawn_death(parent: Node, pos: Vector2, color: Color) -> void:
	var fx := SimpleEffect.new(SimpleEffect.Kind.DEATH, color)
	parent.add_child(fx)
	fx.global_position = pos

static func spawn_materialize(parent: Node, pos: Vector2, color: Color) -> void:
	var fx := SimpleEffect.new(SimpleEffect.Kind.MATERIALIZE, color)
	parent.add_child(fx)
	fx.global_position = pos

static func spawn_portal(parent: Node, pos: Vector2) -> void:
	# Unlike the other effects, this one is a physics object (an Area2D
	# with a CollisionShape2D child) and it's spawned from
	# LevelRoot.on_monster_killed, which itself usually runs from inside a
	# bullet's collision callback (Bullet._on_body_entered). Adding a
	# collision shape to the tree while the physics server is still
	# flushing that step's queries throws "Can't change this state while
	# flushing queries" - deferring both calls to the next idle frame
	# sidesteps that entirely.
	var fx := PortalEffect.new()
	parent.call_deferred("add_child", fx)
	fx.call_deferred("set_global_position", pos)
