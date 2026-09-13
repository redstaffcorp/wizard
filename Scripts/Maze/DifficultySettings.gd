class_name DifficultySettings
extends RefCounted

## Central place that controls how the game gets harder as the players
## advance. Tweak these numbers to rebalance difficulty.

class LevelParams:
	extends RefCounted
	var cols: int
	var rows: int
	var loop_chance: float
	var monster_count: int
	var monster_speed_mul: float
	var blaster_unlocked: bool
	var wraith_unlocked: bool
	var hunter_ratio: float

static func for_level(level: int) -> LevelParams:
	var cols: int = clampi(9 + (level - 1) * 2, 9, 19)
	var rows: int = clampi(7 + (level - 1) * 2, 7, 15)
	if cols % 2 == 0:
		cols += 1
	if rows % 2 == 0:
		rows += 1

	# Fewer extra loops at higher levels -> tighter, harder to escape maze.
	var loop_chance: float = clampf(0.28 - 0.02 * level, 0.06, 0.28)
	var monster_count: int = clampi(4 + floori(level * 0.8), 4, 12)
	var speed_mul: float = clampf(1.0 + 0.05 * level, 1.0, 1.8)
	var hunter_ratio: float = clampf(0.2 + 0.05 * level, 0.2, 0.7)

	var p := LevelParams.new()
	p.cols = cols
	p.rows = rows
	p.loop_chance = loop_chance
	p.monster_count = monster_count
	p.monster_speed_mul = speed_mul
	p.blaster_unlocked = level >= 3
	p.wraith_unlocked = level >= 5
	p.hunter_ratio = hunter_ratio
	return p
