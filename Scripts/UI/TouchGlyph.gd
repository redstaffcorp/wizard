class_name TouchGlyph
extends Node2D

## Pure visual for one on-screen touch control - a simple placeholder
## shape drawn in code (same "no external art assets" style as the rest of
## the game), sitting on top of its own invisible TouchScreenButton hit
## area (see TouchControls) so the look and the touch region can be tuned
## independently. Never receives input itself.

enum GlyphKind { ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT, SHOOT, WALL, BOMB }

var kind: GlyphKind = GlyphKind.ARROW_UP
var radius: float = 40.0

func _draw() -> void:
	var bg := Color(1, 1, 1, 0.16)
	var outline := Color(1, 1, 1, 0.55)
	draw_circle(Vector2.ZERO, radius, bg)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, outline, 2.0)

	match kind:
		GlyphKind.ARROW_UP:
			draw_colored_polygon(DrawUtil.regular_polygon(3, radius * 0.45, -PI / 2.0), outline)
		GlyphKind.ARROW_DOWN:
			draw_colored_polygon(DrawUtil.regular_polygon(3, radius * 0.45, PI / 2.0), outline)
		GlyphKind.ARROW_LEFT:
			draw_colored_polygon(DrawUtil.regular_polygon(3, radius * 0.45, PI), outline)
		GlyphKind.ARROW_RIGHT:
			draw_colored_polygon(DrawUtil.regular_polygon(3, radius * 0.45, 0.0), outline)
		GlyphKind.SHOOT:
			# Same bullet color as Bullet's own draw, for a visual "this
			# button fires that" association.
			draw_rect(Rect2(-radius * 0.4, -radius * 0.12, radius * 0.8, radius * 0.24), Color(1.0, 0.95, 0.2), true)
		GlyphKind.WALL:
			# Same gold-brick tone as ResourcePickup/WallSegment, so it
			# reads as "the wall tool" at a glance.
			var r := Rect2(-radius * 0.4, -radius * 0.28, radius * 0.8, radius * 0.56)
			draw_rect(r, Color(0.75, 0.55, 0.05), true)
			draw_rect(r, Color(0.3, 0.2, 0.02), false, 2.0)
		GlyphKind.BOMB:
			draw_circle(Vector2(0, radius * 0.06), radius * 0.32, Color(0.15, 0.15, 0.15))
			draw_line(Vector2(0, -radius * 0.26), Vector2(radius * 0.2, -radius * 0.42), Color(1.0, 0.6, 0.1), 2.0)
