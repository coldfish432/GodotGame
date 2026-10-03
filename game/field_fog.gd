class_name FieldFog
extends RefCounted

## What the player has mapped, not what the player can see.
##
## This is a knowledge layer only: nothing in the 3D view is dimmed, hidden or
## covered. The world renders exactly as it did before. What fog gates is the
## minimap — unwalked ground is simply not drawn, and a device, vault or
## extraction beacon does not appear on it until the player has been near
## enough to have found it.
##
## Deliberately not rendered fog in the world. Attacks resolve through a
## telegraphed danger circle the player has to read and step out of, so
## obscuring ground the player is fighting on would trade a fairness guarantee
## for atmosphere. It is also not a vision radius: a cell stays mapped for the
## rest of the segment once walked, so this is exploration memory, not sight.
##
## The idea is borrowed from 贪婪洞窟, where a floor is unknown until walked and
## the stairs have to be found — see 贪婪洞窟地图设计调研.md §3.2.

const CELL := 3.0
## Generous on purpose: roughly what the follow camera already shows, so the
## map fills in with what the player has genuinely looked at rather than
## trailing a narrow smear behind them.
const REVEAL_RADIUS := 26.0

var origin: Vector2
var columns: int
var rows: int

var _revealed: PackedByteArray
var _revealed_count := 0

func setup(min_bound: Vector2, max_bound: Vector2) -> void:
	origin = min_bound
	columns = maxi(1, int(ceil((max_bound.x - min_bound.x) / CELL)))
	rows = maxi(1, int(ceil((max_bound.y - min_bound.y) / CELL)))
	_revealed = PackedByteArray()
	_revealed.resize(columns * rows)
	_revealed.fill(0)
	_revealed_count = 0

func reveal(point: Vector3, radius: float = REVEAL_RADIUS) -> void:
	if _revealed.is_empty(): return
	var span := int(ceil(radius / CELL))
	var centre_column := int((point.x - origin.x) / CELL)
	var centre_row := int((point.z - origin.y) / CELL)
	var here := Vector2(point.x, point.z)
	for row in range(maxi(0, centre_row - span), mini(rows, centre_row + span + 1)):
		for column in range(maxi(0, centre_column - span), mini(columns, centre_column + span + 1)):
			var index := row * columns + column
			if _revealed[index] != 0: continue
			var cell_centre := Vector2(origin.x + (column + 0.5) * CELL, origin.y + (row + 0.5) * CELL)
			if cell_centre.distance_to(here) > radius: continue
			_revealed[index] = 1
			_revealed_count += 1

func is_revealed(x: float, z: float) -> bool:
	if _revealed.is_empty(): return true
	var column := int((x - origin.x) / CELL)
	var row := int((z - origin.y) / CELL)
	# Anything off the grid counts as mapped: the alternative is a marker that
	# can never be drawn because it sits a metre outside the sampled bounds.
	if column < 0 or row < 0 or column >= columns or row >= rows: return true
	return _revealed[row * columns + column] != 0

func is_point_revealed(point: Vector3) -> bool:
	return is_revealed(point.x, point.z)

func revealed_fraction() -> float:
	if _revealed.is_empty(): return 1.0
	return float(_revealed_count) / float(_revealed.size())

func reveal_all() -> void:
	if _revealed.is_empty(): return
	_revealed.fill(1)
	_revealed_count = _revealed.size()

func revealed_cells() -> int:
	return _revealed_count
