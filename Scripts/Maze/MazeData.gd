class_name MazeData
extends RefCounted

## "Double resolution" grid: logical cell (cx,cy) lives at index
## (2*cx+1, 2*cy+1). The cells in between represent whether a wall stands
## between two neighboring cells. This makes maze generation and
## wall-building straightforward. Stored as a flat PackedByteArray (1 =
## blocked) instead of a true 2D array, since GDScript has no native
## multi-dimensional array - is_blocked/set_blocked hide the indexing.

var cols: int = 0
var rows: int = 0
var tunnel_row: int = 0
var blocked: PackedByteArray = PackedByteArray()

var width: int:
	get:
		return 2 * cols + 1

var height: int:
	get:
		return 2 * rows + 1

func _init(p_cols: int = 0, p_rows: int = 0) -> void:
	cols = p_cols
	rows = p_rows
	if p_cols > 0 and p_rows > 0:
		blocked.resize(width * height)
		blocked.fill(1)

func is_blocked(x: int, y: int) -> bool:
	return blocked[y * width + x] != 0

func set_blocked(x: int, y: int, value: bool) -> void:
	blocked[y * width + x] = 1 if value else 0
