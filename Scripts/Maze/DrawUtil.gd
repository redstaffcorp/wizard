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

## Shifts every vertex of a point array by `delta` - lets a creature glue a
## second body part (an abdomen segment, a shell plate) together from the
## same regular_polygon() helper without hand-computing offset vertices.
static func offset_points(pts: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = pts[i] + delta
	return out

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

## A stocky space-suit miner figure for the two player characters, heavy
## cannon included - replaced the earlier wizard-hat-and-robe look at
## laci's request for something "vagány" (cool/badass) with visible
## hardware. The suit body stays upright (readable at a glance, same as
## the old robe did), but the weapon and the helmet's HUD eye-lights both
## swing to point at `facing`, so the character visibly "aims" wherever
## it's headed instead of just standing there. `badge` marks the AI
## teammate: pale pink shoulder trim (kept soft rather than a sharp
## marking, per the earlier "too badass" feedback on this same character)
## and warm pink HUD eyes instead of the human's cyan ones - color is the
## only difference, so the two stay instantly tellable apart without
## either one looking more "serious" than the other.
## Everything below is sized to stay within about +/-15px of center in
## every direction, including the weapon at full reach - the maze's
## corridors are only 32px tall/wide between walls (see
## LevelRoot._build_walls: CELL_SIZE/2 per wall-grid unit), so anything
## bigger visibly pokes into the wall above/below/beside the player as it
## moves. The first version of this shape (a wide round helmet plus a
## 22px-long gun barrel) blew well past that budget and stuck out of the
## corridor - this version is the same design, just scaled back down to
## actually fit the tunnels it has to move through.
static func draw_space_miner(ci: CanvasItem, color: Color, facing: Vector2, badge: bool = false) -> void:
	var trim: Color = color.darkened(0.35)
	var dark: Color = color.darkened(0.6)
	var forward: Vector2 = facing.normalized() if facing.length() > 0.1 else Vector2.DOWN
	var right: Vector2 = forward.rotated(PI / 2.0)

	# Life-support tank peeking out from behind the torso.
	var pack := PackedVector2Array([
		Vector2(-6, 1), Vector2(6, 1), Vector2(5, 10), Vector2(-5, 10),
	])
	ci.draw_colored_polygon(pack, dark)

	# Bulky suit torso - squarer/heavier than a robe, sized to look armored.
	var torso := PackedVector2Array([
		Vector2(-8, -5), Vector2(8, -5),
		Vector2(10, 10), Vector2(-10, 10),
	])
	ci.draw_colored_polygon(torso, color)

	# Shoulder pads - pale pink on the teammate, the suit's own trim color
	# on the human, so the silhouette alone tells them apart at a glance.
	var shoulder_color: Color = Color(1.0, 0.75, 0.82) if badge else trim
	ci.draw_rect(Rect2(-11, -6, 6, 5), shoulder_color)
	ci.draw_rect(Rect2(5, -6, 6, 5), shoulder_color)

	# Chest control panel with a couple of status lights - flavor, no
	# gameplay meaning.
	ci.draw_rect(Rect2(-3, 2, 6, 4), dark)
	ci.draw_circle(Vector2(-1.5, 4), 0.9, Color(0.3, 1.0, 0.4))
	ci.draw_circle(Vector2(1.5, 4), 0.9, Color(1.0, 0.75, 0.2))

	# Helmet: a round dome, a dark tinted visor, and glowing HUD eye-lights
	# inside it that shift toward facing_dir instead of a normal face -
	# nobody can see through a real space helmet, so this reads as an
	# in-visor display rather than eyes.
	ci.draw_circle(Vector2(0, -9), 6.0, Color(0.82, 0.84, 0.88))
	ci.draw_arc(Vector2(0, -9), 6.0, 0.0, TAU, 20, trim, 1.3)
	var visor_center := Vector2(0, -8.7)
	ci.draw_colored_polygon(PackedVector2Array([
		visor_center + Vector2(-4.4, -1.8), visor_center + Vector2(4.4, -1.8),
		visor_center + Vector2(3.7, 3.2), visor_center + Vector2(-3.7, 3.2),
	]), Color(0.05, 0.08, 0.1))
	var glow: Color = Color(1.0, 0.55, 0.75) if badge else Color(0.3, 0.9, 1.0)
	draw_glow_eyes(ci, facing, glow, -8.7, 2.1, 1.05)

	# Heavy weapon, held forward and always pointing along facing_dir - a
	# chunky cannon rather than a raised hand, since "nehéz fegyver" was
	# specifically asked for. Drawn last so it always sits on top of the
	# suit/arm.
	var grip: Vector2 = Vector2(0, 3) + right * 6.0
	var barrel_len: float = 10.0
	var barrel_w: float = 3.6
	var b1: Vector2 = grip + right * barrel_w * 0.5
	var b2: Vector2 = grip - right * barrel_w * 0.5
	var b3: Vector2 = b2 + forward * barrel_len
	var b4: Vector2 = b1 + forward * barrel_len
	ci.draw_colored_polygon(PackedVector2Array([b1, b2, b3, b4]), dark)
	ci.draw_circle(grip + right * (barrel_w * 0.5 + 1.2), 2.4, trim) # stock/handle
	ci.draw_circle(grip + forward * barrel_len, 1.7, Color(1.0, 0.7, 0.2)) # muzzle glow
