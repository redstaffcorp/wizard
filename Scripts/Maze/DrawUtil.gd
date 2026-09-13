class_name DrawUtil
extends RefCounted

## Small helper for drawing more developed placeholder character/creature
## shapes. Still no external art assets - everything is primitive shapes
## composed in code (draw_colored_polygon/draw_circle/etc.) - but built up
## from several parts (body + eyes + a signature detail) instead of a bare
## single polygon, so each actor reads as a distinct little character
## instead of just "a colored blob."

## Vertex 0 points exactly at angle "rotation" (radians), so passing a
## facing direction's .angle() makes the shape point that way.
static func regular_polygon(sides: int, radius: float, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(sides)
	for i in range(sides):
		var a: float = rotation + i * TAU / sides
		pts[i] = Vector2(cos(a), sin(a)) * radius
	return pts

## A rounded-top, wavy-bottomed silhouette - the classic "ghost" outline -
## used for the phasing Wraith. `bumps` feet sit along the scalloped hem.
static func ghost_shape(radius: float, bumps: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var top_segments := 10
	for i in range(top_segments + 1):
		var a: float = PI + i * PI / top_segments # sweeps from left, over the top, to right
		pts.append(Vector2(cos(a), sin(a)) * radius)
	# Zigzag hem along the bottom, right side back to the left, alternating
	# a deep "foot" and a shallow "notch" between feet.
	var skirt_y: float = radius * 0.75
	var notch_y: float = radius * 0.25
	var total_points: int = bumps * 2
	for i in range(1, total_points):
		var t: float = float(i) / total_points
		var x: float = radius - t * 2.0 * radius
		var y: float = skirt_y if i % 2 == 1 else notch_y
		pts.append(Vector2(x, y))
	return pts

## A pair of round eyes with pupils shifted toward `look_dir`, drawn onto
## whatever CanvasItem is currently inside its own _draw() (pass `self`).
## Falls back to looking straight down when there's no clear direction
## (e.g. a monster standing still), so faces never look dead-center/blank.
## `intensity` scales how far the pupils shift (1.0 = fully committed to
## look_dir, 0.0 = dead-center) - a character that's always deliberately
## pathing somewhere (like the AI teammate) reads as permanently
## laser-focused/intense at full intensity, so it can be dialed down to
## look calmer without changing the eyes' size or spacing.
static func draw_face(ci: CanvasItem, look_dir: Vector2, y: float = -3.0, spacing: float = 5.0, eye_r: float = 3.2, pupil_r: float = 1.5, intensity: float = 1.0) -> void:
	var d: Vector2 = look_dir.normalized() if look_dir.length() > 0.5 else Vector2.DOWN
	var pupil_shift: Vector2 = d * (eye_r - pupil_r) * 0.75 * intensity
	var left := Vector2(-spacing, y)
	var right := Vector2(spacing, y)
	ci.draw_circle(left, eye_r, Color.WHITE)
	ci.draw_circle(right, eye_r, Color.WHITE)
	ci.draw_circle(left + pupil_shift, pupil_r, Color.BLACK)
	ci.draw_circle(right + pupil_shift, pupil_r, Color.BLACK)

## Hollow/glowing eyes (no white sclera, just a bright pupil) for the
## Wraith while it's translucent and phasing through walls - reads as
## "ghostly" rather than "has a face".
static func draw_glow_eyes(ci: CanvasItem, look_dir: Vector2, glow: Color, y: float = -2.0, spacing: float = 4.5, r: float = 2.0) -> void:
	var d: Vector2 = look_dir.normalized() if look_dir.length() > 0.5 else Vector2.DOWN
	var shift: Vector2 = d * 1.5
	ci.draw_circle(Vector2(-spacing, y) + shift, r, glow)
	ci.draw_circle(Vector2(spacing, y) + shift, r, glow)

## A small wizard-hat-and-robe figure for the two player characters -
## fixed upright (the hat/robe never rotate) so it always stays readable;
## only the eyes shift to hint at facing_dir. `badge` marks the AI
## teammate: a small soft round pin on the chest (not a sharp star -
## that read as a hero medal/sheriff badge, too "badass") tells it apart
## from the human at a glance, and its eyes track its target more gently
## (lower look intensity, plus a small smile) so it reads as a relaxed
## companion rather than a permanently locked-on, all-business hunter -
## since unlike the human it's always deliberately pathing somewhere,
## full-intensity eyes made it look far more intense/determined than
## intended.
static func draw_wizard(ci: CanvasItem, color: Color, facing: Vector2, badge: bool = false) -> void:
	var trim: Color = color.darkened(0.4)

	# Robe: a rounded trapezoid, wider at the feet.
	var robe := PackedVector2Array([
		Vector2(-6, -7), Vector2(6, -7),
		Vector2(11, 13), Vector2(-11, 13),
	])
	ci.draw_colored_polygon(robe, color)

	# Hat: a tall triangle with a small brim, always pointing straight up.
	var hat := PackedVector2Array([
		Vector2(-8, -7), Vector2(8, -7), Vector2(0, -25),
	])
	ci.draw_colored_polygon(hat, trim)
	ci.draw_rect(Rect2(-10, -8, 20, 3), trim)

	if badge:
		var pin_center := Vector2(0, 6)
		ci.draw_circle(pin_center, 3.2, Color(1.0, 0.78, 0.85))
		ci.draw_arc(pin_center, 3.2, 0.0, TAU, 16, Color(0.85, 0.55, 0.6), 1.0)
		draw_face(ci, facing, -3.0, 4.0, 3.0, 1.4, 0.45)
		# A small friendly smile, only on the companion - it's the detail
		# that most says "relaxed sidekick" rather than "focused hunter".
		var smile := PackedVector2Array()
		for i in range(6):
			var t: float = float(i) / 5.0
			var sx: float = lerpf(-3.0, 3.0, t)
			smile.append(Vector2(sx, 2.0 + sin(t * PI) * 2.0))
		ci.draw_polyline(smile, trim, 1.2)
	else:
		draw_face(ci, facing, -3.0, 4.0, 3.0, 1.4)
