class_name TouchJoystick
extends Node2D

## A drag-anywhere virtual joystick for on-screen movement, replacing the
## old four small D-pad buttons (each just a ~32px hit-circle, which turned
## out to be too fiddly to land a thumb on reliably during real play).
##
## Modeled on the joystick from laci's other Android arcade game
## (FluxLines' entities/Joystick.kt + input/GameplayInputHandler.kt): the
## visible base+knob sit at one fixed anchor point for a stable visual
## reference, but the touch CAPTURE ZONE that can grab/drag it is a whole
## generous screen region (see `capture_rect`, set by TouchControls to
## roughly the left half of the screen) - so the player doesn't need to
## precisely land a finger on the small circle at all, just touch and drag
## anywhere in that region and the knob follows, clamped to `base_radius`.
## Releasing snaps the knob back to center and stops movement.
##
## Output goes through the exact same named actions (move_up/down/left/
## right) the rest of the game already reads via Input.is_action_pressed -
## using Input.action_press()/action_release(), the same mechanism
## TouchScreenButton itself uses internally - so PlayerHuman and everything
## else needs zero changes and still doesn't know or care where input
## came from.

@export var base_radius: float = 55.0
@export var knob_radius: float = 28.0
@export var deadzone: float = 20.0

var anchor: Vector2 = Vector2.ZERO
var capture_rect: Rect2 = Rect2()

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _raw_offset: Vector2 = Vector2.ZERO
var _active_action_x: String = ""
var _active_action_y: String = ""

func _ready() -> void:
	z_index = 6

## Called by TouchControls whenever the viewport size changes, same as the
## other buttons - keeps the joystick anchored a fixed visual distance from
## the bottom-left corner and its capture zone matched to the current
## screen size.
func set_layout(new_anchor: Vector2, new_capture_rect: Rect2) -> void:
	anchor = new_anchor
	capture_rect = new_capture_rect
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Mirror TouchControls' own visibility rule exactly: a real touchscreen
	# or a debug build (for mouse-emulated-touch desktop testing) may use
	# this; a normal release desktop build must not, or mouse clicks in
	# the capture zone (which is most of the left half of the screen)
	# would silently start "moving" the player with no visible joystick
	# on screen at all.
	if not (DisplayServer.is_touchscreen_available() or OS.is_debug_build()):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and capture_rect.has_point(event.position):
				_touch_index = event.index
				_raw_offset = event.position - anchor
				_update_direction()
		elif event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_raw_offset = event.position - anchor
			_update_direction()

func _release() -> void:
	_touch_index = -1
	_raw_offset = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	_clear_actions()
	queue_redraw()

func _clear_actions() -> void:
	if _active_action_x != "":
		Input.action_release(_active_action_x)
		_active_action_x = ""
	if _active_action_y != "":
		Input.action_release(_active_action_y)
		_active_action_y = ""

func _update_direction() -> void:
	var dist: float = _raw_offset.length()
	var clamped: float = minf(dist, base_radius)
	_knob_offset = (_raw_offset.normalized() * clamped) if dist > 0.01 else Vector2.ZERO
	queue_redraw()

	if dist < deadzone:
		_clear_actions()
		return

	# Cardinal-only, matching the grid movement everywhere else in the
	# game (and PlayerHuman.get_desired_direction's own no-diagonals,
	# horizontal-wins-ties rule for the keyboard): pick whichever axis the
	# finger has moved further along, ties going to horizontal.
	var want_x: String = ""
	var want_y: String = ""
	if absf(_raw_offset.x) >= absf(_raw_offset.y):
		want_x = "move_right" if _raw_offset.x > 0.0 else "move_left"
	else:
		want_y = "move_down" if _raw_offset.y > 0.0 else "move_up"

	if want_x != _active_action_x:
		if _active_action_x != "":
			Input.action_release(_active_action_x)
		if want_x != "":
			Input.action_press(want_x)
		_active_action_x = want_x
	if want_y != _active_action_y:
		if _active_action_y != "":
			Input.action_release(_active_action_y)
		if want_y != "":
			Input.action_press(want_y)
		_active_action_y = want_y

func _draw() -> void:
	if capture_rect.size == Vector2.ZERO:
		return # set_layout() hasn't run yet

	# Base ring - a soft, translucent circle so it doesn't visually compete
	# with the maze, plus a faint outline.
	draw_circle(anchor, base_radius, Color(1.0, 1.0, 1.0, 0.12))
	draw_arc(anchor, base_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.4), 2.0)

	var knob_pos: Vector2 = anchor + _knob_offset
	var active: bool = _touch_index != -1

	if _knob_offset.length() > 6.0:
		draw_line(anchor, knob_pos, Color(1.0, 1.0, 1.0, 0.35), 6.0)

	var knob_color: Color = Color(0.85, 0.2, 0.2, 0.9) if active else Color(0.55, 0.15, 0.15, 0.7)
	draw_circle(knob_pos, knob_radius, knob_color)
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 24, Color(0.3, 0.02, 0.02, 0.8), 2.0)
