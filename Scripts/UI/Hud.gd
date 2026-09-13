class_name Hud
extends CanvasLayer

## Minimal on-screen UI: scores/lives/level for both players, plus a
## centered banner for "LEVEL n / READY?" and "GAME OVER".

var _p1_label: Label
var _p2_label: Label
var _level_label: Label
var _banner_label: Label

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_p1_label = _make_label(Vector2(16, 10), "P1 SCORE: 0  LIVES: 3")
	_p2_label = _make_label(Vector2(16, 36), "CPU SCORE: 0  LIVES: 3")
	_level_label = _make_label(Vector2(16, 62), "LEVEL 1")
	root.add_child(_p1_label)
	root.add_child(_p2_label)
	root.add_child(_level_label)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.visible = false
	_banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_label.add_theme_font_size_override("font_size", 40)
	root.add_child(_banner_label)

	GameManager.score_changed.connect(_update_labels)
	GameManager.lives_changed.connect(_update_labels)
	GameManager.hp_changed.connect(_update_labels)
	GameManager.resources_changed.connect(_update_labels)
	_update_labels()

static func _make_label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	return l

func _update_labels() -> void:
	var gm := GameManager
	_p1_label.text = "P1 SCORE: %d  LIVES: %d  HP: %s  RES: %d/%d  BOMB: %d/%d" % [
		gm.score_p1, maxi(gm.lives_p1, 0), _hearts(gm.hp_p1),
		gm.resources_p1, GameManager.MAX_RESOURCES,
		gm.bomb_resources_p1, GameManager.MAX_BOMB_RESOURCES,
	]
	_p2_label.text = "CPU SCORE: %d  LIVES: %d  HP: %s  RES: %d/%d  BOMB: %d/%d" % [
		gm.score_p2, maxi(gm.lives_p2, 0), _hearts(gm.hp_p2),
		gm.resources_p2, GameManager.MAX_RESOURCES,
		gm.bomb_resources_p2, GameManager.MAX_BOMB_RESOURCES,
	]
	_level_label.text = "LEVEL %d" % gm.level

static func _hearts(hp: int) -> String:
	hp = clampi(hp, 0, GameManager.MAX_HP)
	return "♥".repeat(hp) + "♡".repeat(GameManager.MAX_HP - hp)

func show_level_banner(level: int) -> void:
	SoundManager.play_level_start()
	_update_labels()
	_banner_label.text = "LEVEL %d\nREADY?" % level
	_banner_label.visible = true
	await get_tree().create_timer(1.4).timeout
	_banner_label.visible = false

func show_game_over() -> void:
	_banner_label.text = "GAME OVER\nPress SHOOT to restart"
	_banner_label.visible = true
