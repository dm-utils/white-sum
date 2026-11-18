class_name SumBoardView
extends WhiteTileView
## Draws the board and animates moves (design 10). Mechanics, input and animation come from WhiteTileView;
## this class holds the look (calm tiles with numerals, no links), the run totals of the selected tile and the
## mapping of SumBoard.step_traced to view steps.

const TILE_COLORS := {
	1: Color("3A465C"),
	2: Color("43516A"),
	3: Color("4C5C78"),
	4: Color("566886"),
	5: Color("607494"),
}
const NUMERAL := Color("F2F4F8")
const NUMERAL_SIZE := 0.52 ## font size in cells
const NUMERAL_BASE := 0.36 ## baseline below the tile centre, in font sizes (digits sit on the cap height)
const SWAP_TIME := 0.12
const SLIDE_TIME := 0.10
const FALL_SPEED := 16.0 ## cells per second
const BAND_COLOR := Color(1.0, 1.0, 1.0, 0.10) ## tint over the runs through the selected tile
const BAND_GROW := 0.04 ## band beyond the end tiles, in cells
const TOTAL_FILL := Color("1B1F26")
const TOTAL_LINE := Color(1.0, 1.0, 1.0, 0.55)
const TOTAL_TEXT := Color("E6E9EF")
const TOTAL_W := 0.74 ## total pill, in cells
const TOTAL_H := 0.44
const TOTAL_FONT := 0.30

var board: SumBoard


# --- steps -------------------------------------------------------------------------------------------------------

## View steps for the steps of SumBoard.step_traced.
static func to_view_steps(traced: Array) -> Array:
	var out: Array = []
	for s in traced:
		match str(s.kind):
			"swap":
				out.append({"kind": "move", "moves": [[s.a, s.b], [s.b, s.a]], "time": SWAP_TIME, "ease": true})
			"slide":
				out.append({"kind": "move", "moves": [[s.from, s.to]], "time": SLIDE_TIME, "ease": true})
			"fall":
				out.append({"kind": "move", "moves": s.moves, "speed": FALL_SPEED})
			"vanish":
				out.append({"kind": "vanish", "cells": s.cells})
	return out


# --- run totals of the selected tile (design 10.1) --------------------------------------------------------------

## The row run and the column run through a cell with their totals, and where to put the total of each: the anchor is
## the centre of the pill in cell units (y up), in the empty cell beyond the run end, or on the seam of the end tile
## when the run touches the board edge. Empty dictionary for an empty cell.
static func run_marks(b: SumBoard, state: PackedByteArray, cell: int) -> Dictionary:
	var row := b.row_run_of(state, cell)
	var col := b.col_run_of(state, cell)
	if row.is_empty():
		return {}
	var first := row[0]
	var last := row[row.size() - 1]
	var y := first / b.w
	var row_anchor := Vector2(last % b.w + 1.0, y)
	if last % b.w + 1 >= b.w:
		row_anchor = Vector2(first % b.w - 1.0, y) if first % b.w > 0 else Vector2(last % b.w + 0.5, y)
	var top := col[col.size() - 1]
	var col_anchor := Vector2(top % b.w, top / b.w + 1.0)
	if top / b.w + 1 >= b.h:
		col_anchor = Vector2(top % b.w, top / b.w + 0.5)
	return {
		"row": row, "col": col,
		"row_total": b.run_total(state, row), "col_total": b.run_total(state, col),
		"row_anchor": row_anchor, "col_anchor": col_anchor,
	}


## Run marks of the selected tile (tap-tap selection or keyboard grab); empty when nothing is selected or while
## an animation runs.
func selection_marks() -> Dictionary:
	var sel := selected()
	if sel < 0 or busy() or board == null:
		return {}
	return run_marks(board, shown(), sel)


# --- state -------------------------------------------------------------------------------------------------------

## Shows the attempt's state at once (no animation).
func show_attempt(a: WhiteAttempt) -> void:
	board = a.rules as SumBoard
	show_cells(board.w, board.h, a.state)


func clear() -> void:
	board = null
	super.clear()


## After a move: animates it; after undo or restart: shows the state at once.
func update_attempt(a: WhiteAttempt) -> void:
	var rec := a.record
	var is_move := rec.length() >= 3 and rec.right(1).is_valid_int() and not a.history.is_empty()
	var code: Variant = board.decode_move(rec.right(3)) if is_move else null
	finish_animation()
	if code == null:
		show_values(a.state)
		return
	var before: PackedByteArray = a.history.back()
	if before != shown():
		show_values(before)
	play_move(code)


## Animates a canonical move from the shown state (also used by Best route).
func play_move(code: int) -> void:
	finish_animation()
	animate(to_view_steps(board.step_traced(shown(), code).steps))


func show_state(s: PackedByteArray) -> void:
	finish_animation()
	show_values(s)


func state() -> PackedByteArray:
	return shown()


# --- hooks -------------------------------------------------------------------------------------------------------

func _resolve_cell_move(cell: int, dir: int) -> int:
	return board.canonical(shown(), cell * 4 + dir)


func _draw_tile_body(rect: Rect2, value: int, alpha: float) -> void:
	var col: Color = TILE_COLORS[value]
	col.a = alpha
	_box.bg_color = col
	_box.set_corner_radius_all(int(cell_px * tile_radius))
	draw_style_box(_box, rect)


func _draw_tile_face(rect: Rect2, value: int, alpha: float, scale_f: float) -> void:
	var font := get_theme_default_font()
	var fs := maxi(int(NUMERAL_SIZE * cell_px * scale_f), 1)
	var s := font.get_string_size(str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var col := NUMERAL
	col.a = alpha
	var c := rect.get_center()
	var at := Vector2(c.x - s.x / 2.0, c.y + fs * NUMERAL_BASE)
	draw_string(font, at, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Bands over the runs through the selected tile and their totals; nothing during an animation.
func _draw_links(_tiles: Array) -> void:
	var marks := selection_marks()
	if marks.is_empty():
		return
	var lay := layout(size, grid_w, grid_h, fit)
	var o: Vector2 = lay.origin + _nudge_offset()
	for key in ["row", "col"]:
		var cells: PackedInt32Array = marks[key]
		var r := _cell_rect(cells[0], o, cell_px).merge(_cell_rect(cells[cells.size() - 1], o, cell_px))
		_box.bg_color = BAND_COLOR
		_box.set_corner_radius_all(int(cell_px * tile_radius))
		draw_style_box(_box, r.grow(cell_px * BAND_GROW))
	for key in ["row", "col"]:
		_draw_total(marks[key + "_anchor"], int(marks[key + "_total"]), o)


func _draw_total(anchor: Vector2, total: int, o: Vector2) -> void:
	var c := o + Vector2(anchor.x + 0.5, grid_h - 1.0 - anchor.y + 0.5) * cell_px
	var size_px := Vector2(TOTAL_W, TOTAL_H) * cell_px
	var r := Rect2(c - size_px / 2.0, size_px)
	_box.bg_color = TOTAL_FILL
	_box.border_color = TOTAL_LINE
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(int(r.size.y / 2.0))
	draw_style_box(_box, r)
	_box.set_border_width_all(0)
	var font := get_theme_default_font()
	var fs := maxi(int(TOTAL_FONT * cell_px), 1)
	var s := font.get_string_size(str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := Vector2(c.x - s.x / 2.0, c.y + fs * NUMERAL_BASE)
	draw_string(font, at, str(total), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TOTAL_TEXT)
