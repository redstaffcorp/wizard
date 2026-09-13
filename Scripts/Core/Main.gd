class_name Main
extends Node2D

## Entry point scene script. Owns the camera, the HUD, and drives level
## start / level-clear transitions.

static var instance: Main = null

var _level_root: LevelRoot
var _hud: Hud
var _touch_controls: TouchControls
var _camera: Camera2D
var _busy: bool = false
var _game_over_shown: bool = false

func _ready() -> void:
	instance = self
	GameManager.reset_game()

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	_hud = Hud.new()
	add_child(_hud)

	_touch_controls = TouchControls.new()
	add_child(_touch_controls)

	_level_root = LevelRoot.new()
	add_child(_level_root)

	_start_level()

func _start_level() -> void:
	_level_root.build_level(GameManager.level)
	_fit_camera_to_maze()
	_hud.show_level_banner(GameManager.level)

	# Everything stays frozen (see action_started checks in Player / the
	# monster classes) until the "READY?" banner has had time to be read.
	var ready_timer := get_tree().create_timer(1.5)
	ready_timer.timeout.connect(func():
		if _level_root != null:
			_level_root.action_started = true
	)

func _fit_camera_to_maze() -> void:
	var data: MazeData = _level_root.data
	var w: float = data.cols * LevelRoot.CELL_SIZE
	var h: float = data.rows * LevelRoot.CELL_SIZE
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var zoom_x: float = w / viewport.x
	var zoom_y: float = h / viewport.y
	var z: float = maxf(zoom_x, zoom_y) * 1.15
	z = maxf(z, 1.0)
	_camera.zoom = Vector2(1.0 / z, 1.0 / z)
	_camera.position = Vector2.ZERO

func complete_level() -> void:
	if _busy:
		return
	_busy = true
	GameManager.next_level()
	var timer := get_tree().create_timer(0.8)
	timer.timeout.connect(func():
		_busy = false
		_start_level()
	)

func _process(_delta: float) -> void:
	if not _game_over_shown and GameManager.is_game_over():
		_game_over_shown = true
		SoundManager.play_game_over()
		_hud.show_game_over()
	elif _game_over_shown and Input.is_action_just_pressed("shoot_p1"):
		_restart_game()

func _restart_game() -> void:
	_game_over_shown = false
	_busy = false
	GameManager.reset_game()
	_start_level()
