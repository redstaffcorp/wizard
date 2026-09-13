class_name TouchControls
extends CanvasLayer

## On-screen touch controls for a mobile build: a drag-anywhere virtual
## joystick bottom-left for movement (see TouchJoystick.gd - replaced the
## old fixed four-button D-pad, which turned out to be too fiddly to hit
## reliably on a real phone) plus a 3-button cluster bottom-right (shoot/
## wall/bomb) arranged in an arc so one right thumb reaches all three
## without moving. Every button is a TouchScreenButton bound to one of the
## named input actions GameManager already registers (_setup_input_actions)
## - gameplay code (PlayerHuman, etc.) just polls Input.is_action_pressed/
## is_action_just_pressed like it always did and doesn't know or care
## whether a press came from a key, a touch button, or the joystick.
##
## Each TouchScreenButton carries no texture of its own - it's purely an
## invisible hit region (a Shape2D) - and a sibling TouchGlyph node draws
## the visible look on top, so the touch region and the art can be
## sized/positioned independently. VisibilityMode = TOUCHSCREEN_ONLY on
## every button, plus hiding the whole layer when no touchscreen is
## present, keeps this completely out of the way during normal
## keyboard/mouse development and testing.

var _btn_by_action: Dictionary = {}
var _glyph_by_action: Dictionary = {}
var _joystick: TouchJoystick

func _ready() -> void:
	layer = 5
	# Real touchscreens always get the controls. On a debug run without one
	# (e.g. testing in the Godot editor on a desktop PC) show them too, so
	# the layout/wiring can be clicked through with a mouse -
	# project.godot has "Emulate Touch From Mouse" on, which makes a click
	# behave like a tap for TouchScreenButton. A release desktop build
	# (OS.is_debug_build() == false) stays clean/hidden either way.
	visible = DisplayServer.is_touchscreen_available() or OS.is_debug_build()

	_joystick = TouchJoystick.new()
	add_child(_joystick)

	_add_button("shoot_p1", TouchGlyph.GlyphKind.SHOOT, 48.0)
	_add_button("alter_wall", TouchGlyph.GlyphKind.WALL, 32.0)
	_add_button("place_bomb", TouchGlyph.GlyphKind.BOMB, 32.0)

	_layout_buttons()
	get_viewport().size_changed.connect(_layout_buttons)

func _add_button(action: String, kind: TouchGlyph.GlyphKind, radius: float) -> void:
	var btn := TouchScreenButton.new()
	btn.action = action
	btn.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	var shape := CircleShape2D.new()
	shape.radius = radius
	btn.shape = shape
	add_child(btn)

	var glyph := TouchGlyph.new()
	glyph.kind = kind
	glyph.radius = radius
	add_child(glyph)

	_btn_by_action[action] = btn
	_glyph_by_action[action] = glyph

## Fixed screen-space layout, recomputed whenever the viewport size changes
## (window resize, or just a different device aspect ratio - the project
## uses canvas_items/expand stretch, so this is the same visible-rect size
## Main._fit_camera_to_maze already reads) so the cluster always sits the
## same visual distance from the bottom-left/bottom-right corners instead
## of drifting off-screen.
func _layout_buttons() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size

	# Fixed visual anchor near where the old D-pad center used to be, but
	# the actual grab/drag capture zone is generous - roughly the left half
	# of the screen - so the player doesn't need to precisely land a thumb
	# on the small ring at all, just touch and drag anywhere over there.
	# Stops short of the screen's midline so it can never overlap the
	# shoot/wall/bomb cluster on the right.
	var joystick_anchor := Vector2(110, size.y - 130)
	var joystick_capture := Rect2(0, 0, size.x * 0.55, size.y)
	_joystick.set_layout(joystick_anchor, joystick_capture)

	var shoot_pos := Vector2(size.x - 90, size.y - 100)
	_place("shoot_p1", shoot_pos)
	_place("alter_wall", shoot_pos + Vector2(-90, -55))
	_place("place_bomb", shoot_pos + Vector2(-10, -100))

func _place(action: String, pos: Vector2) -> void:
	if not _btn_by_action.has(action):
		return
	_btn_by_action[action].position = pos
	_glyph_by_action[action].position = pos
