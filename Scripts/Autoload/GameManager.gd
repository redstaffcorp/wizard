extends Node

## Global game state: score, lives, current level, and named input actions.
## Actions are registered in code (instead of hand-edited project.godot
## [input] entries) so a future virtual-joystick / touch button UI for a
## mobile port can just call Input.action_press/action_release on these
## same action names without touching gameplay code.
##
## This script is registered as an autoload named "GameManager" in
## project.godot, so it's reached directly by that name from anywhere -
## no manual singleton/".instance" bookkeeping needed like the old C#
## version required.

var level: int = 1
var score_p1: int = 0
var score_p2: int = 0
var lives_p1: int = 3
var lives_p2: int = 3

const MAX_HP: int = 3
var hp_p1: int = MAX_HP
var hp_p2: int = MAX_HP

# Spent to build or break a wall segment (see LevelRoot.try_alter_wall).
# Refilled by collecting a guarded resource pickup; reset to full at the
# start of every level along with the maze itself.
const MAX_RESOURCES: int = 3
var resources_p1: int = MAX_RESOURCES
var resources_p2: int = MAX_RESOURCES

# Same idea, separate pool: spent to place a bomb (see
# LevelRoot.detonate_bomb / PlayerHuman.try_place_bomb). Kept distinct from
# the wall-editing pool so a player has to choose which kind of guarded
# cache is worth going after.
const MAX_BOMB_RESOURCES: int = 3
var bomb_resources_p1: int = MAX_BOMB_RESOURCES
var bomb_resources_p2: int = MAX_BOMB_RESOURCES

# The AI teammate's relationship with the human, expressed as a continuous
# score rather than a single permanent switch. Nudged up or down by
# gameplay events (see PlayerAI) and bucketed into three behavior bands.
# Deliberately not surfaced anywhere in the HUD - the player is meant to
# read the AI's mood from what it does, not from a number.
enum AiMood { FRIENDLY, NEUTRAL, HOSTILE }

const FRIENDLY_THRESHOLD: float = 30.0
const HOSTILE_THRESHOLD: float = -30.0

var sympathy: float = 0.0
var mood: AiMood = AiMood.NEUTRAL

signal score_changed
signal lives_changed
signal hp_changed
signal mood_changed
signal resources_changed

func _ready() -> void:
	_setup_input_actions()

func _setup_input_actions() -> void:
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("shoot_p1", [KEY_SPACE, KEY_CTRL])
	_add_action("alter_wall", [KEY_E])
	_add_action("place_bomb", [KEY_Q])

func _add_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action_name, ev)

func add_score(player_index: int, points: int) -> void:
	if player_index == 0:
		score_p1 += points
	else:
		score_p2 += points
	score_changed.emit()

## Returns true if that player is permanently out of lives.
func lose_life(player_index: int) -> bool:
	if player_index == 0:
		lives_p1 -= 1
	else:
		lives_p2 -= 1
	lives_changed.emit()
	return lives_p1 <= 0 if player_index == 0 else lives_p2 <= 0

func set_hp(player_index: int, hp: int) -> void:
	if player_index == 0:
		hp_p1 = hp
	else:
		hp_p2 = hp
	hp_changed.emit()

## False if that player is already out of resources - the action that
## asked for this should then do nothing at all.
func spend_resource(player_index: int) -> bool:
	if player_index == 0:
		if resources_p1 <= 0:
			return false
		resources_p1 -= 1
	else:
		if resources_p2 <= 0:
			return false
		resources_p2 -= 1
	resources_changed.emit()
	return true

func refill_resources(player_index: int) -> void:
	if player_index == 0:
		resources_p1 = MAX_RESOURCES
	else:
		resources_p2 = MAX_RESOURCES
	resources_changed.emit()

func refill_all_resources() -> void:
	resources_p1 = MAX_RESOURCES
	resources_p2 = MAX_RESOURCES
	resources_changed.emit()

func spend_bomb_resource(player_index: int) -> bool:
	if player_index == 0:
		if bomb_resources_p1 <= 0:
			return false
		bomb_resources_p1 -= 1
	else:
		if bomb_resources_p2 <= 0:
			return false
		bomb_resources_p2 -= 1
	resources_changed.emit()
	return true

func refill_bomb_resources(player_index: int) -> void:
	if player_index == 0:
		bomb_resources_p1 = MAX_BOMB_RESOURCES
	else:
		bomb_resources_p2 = MAX_BOMB_RESOURCES
	resources_changed.emit()

func refill_all_bomb_resources() -> void:
	bomb_resources_p1 = MAX_BOMB_RESOURCES
	bomb_resources_p2 = MAX_BOMB_RESOURCES
	resources_changed.emit()

## Called at the start of every level - a new maze gets a fresh resource
## allowance rather than carrying a possibly-depleted one over from
## whatever the previous layout demanded.
func reset_level_resources() -> void:
	refill_all_resources()
	refill_all_bomb_resources()

func adjust_sympathy(delta: float) -> void:
	sympathy = clampf(sympathy + delta, -100.0, 100.0)
	var new_mood: AiMood = AiMood.FRIENDLY if sympathy >= FRIENDLY_THRESHOLD \
		else (AiMood.HOSTILE if sympathy <= HOSTILE_THRESHOLD else AiMood.NEUTRAL)
	if new_mood != mood:
		mood = new_mood
		mood_changed.emit()

## The human is the actual player; the AI teammate running out of lives
## just means it's gone for the rest of the run (see Player.hit) - it
## doesn't keep the game going by itself.
func is_game_over() -> bool:
	return lives_p1 <= 0

func reset_game() -> void:
	level = 1
	score_p1 = 0
	score_p2 = 0
	lives_p1 = 3
	lives_p2 = 3
	hp_p1 = MAX_HP
	hp_p2 = MAX_HP
	resources_p1 = MAX_RESOURCES
	resources_p2 = MAX_RESOURCES
	bomb_resources_p1 = MAX_BOMB_RESOURCES
	bomb_resources_p2 = MAX_BOMB_RESOURCES
	sympathy = 0.0
	mood = AiMood.NEUTRAL
	score_changed.emit()
	lives_changed.emit()
	hp_changed.emit()
	mood_changed.emit()
	resources_changed.emit()

func next_level() -> void:
	level += 1
