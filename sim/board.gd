class_name SumBoard
extends WhiteRules
## Board, moves and resolution. State: PackedByteArray w * h, index y * w + x, y up, 0 empty or 1..5.
## A row run or column run of touching tiles vanishes when its total is TARGET.
## Move code m = i * 4 + d, d in R 0, L 1, D 2, U 3. Token: direction, column letter, row digit ("RB1").

enum Dir { R, L, D, U }

const DIR_LETTERS := "RLDU"
const TARGET := 10
const GLYPHS := ".12345"

var w := 0
var h := 0
var start := PackedByteArray()

# scratch for marking cells, stamp avoids clearing
var _seen := PackedInt32Array()
var _stamp := 0


static func create(width: int, height: int) -> SumBoard:
	var b := SumBoard.new()
	b.w = width
	b.h = height
	b.start = PackedByteArray()
	b.start.resize(width * height)
	b._seen.resize(width * height)
	return b


static func from_dict(d: Dictionary) -> SumBoard:
	var n: Array = d.n
	var b := SumBoard.create(int(n[0]), int(n[1]))
	var rows := PackedStringArray()
	for r in d.rows:
		rows.append(str(r))
	b.start = b.from_rows(rows)
	return b


func to_dict(state: PackedByteArray) -> Dictionary:
	return {"n": [w, h], "rows": Array(render(state).split("\n"))}


## Rows top first, chars ".12345".
func from_rows(rows: PackedStringArray) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(w * h)
	for ry in h:
		var y := h - 1 - ry
		for x in w:
			var c := GLYPHS.find(rows[ry][x])
			s[y * w + x] = maxi(c, 0)
	return s


func render(state: PackedByteArray) -> String:
	var rows := PackedStringArray()
	for ry in h:
		var y := h - 1 - ry
		var line := ""
		for x in w:
			var v := state[y * w + x]
			line += "." if v == 0 else str(v)
		rows.append(line)
	return "\n".join(rows)


func cell_name(i: int) -> String:
	return char(65 + i % w) + str(i / w + 1)


# --- White Kit interface -----------------------------------------------------------------------------------------

func start_state() -> Variant:
	return start


func apply(state: Variant, move: Variant) -> Variant:
	if not move is int:
		return null
	var c := canonical(state, move)
	return null if c < 0 else step(state, c)


func is_solved(state: Variant) -> bool:
	for v in (state as PackedByteArray):
		if v != 0:
			return false
	return true


func move_len() -> int:
	return 3


func encode_move(move: Variant) -> String:
	var m: int = move
	return DIR_LETTERS[m & 3] + cell_name(m >> 2)


func decode_move(token: String) -> Variant:
	if token.length() != 3:
		return null
	var d := DIR_LETTERS.find(token[0])
	var x := token.unicode_at(1) - 65
	var y := token.unicode_at(2) - 49
	if d < 0 or x < 0 or x >= w or y < 0 or y >= h:
		return null
	return (y * w + x) * 4 + d


# --- rules -------------------------------------------------------------------------------------------------------

## Canonical code of m in this state, -1 when the move is ignored.
func canonical(state: PackedByteArray, m: int) -> int:
	var i := m >> 2
	var d := m & 3
	if i < 0 or i >= w * h or state[i] == 0:
		return -1
	var x := i % w
	var y := i / w
	var j := 0
	match d:
		Dir.R:
			if x + 1 >= w:
				return -1
			j = i + 1
		Dir.L:
			if x == 0:
				return -1
			j = i - 1
		Dir.D:
			if y == 0:
				return -1
			j = i - w
		_:
			if y + 1 >= h:
				return -1
			j = i + w
	var t := state[j]
	if t == state[i]:
		return -1
	if t != 0:
		match d:
			Dir.R:
				return m
			Dir.L:
				return j * 4 + Dir.R
			Dir.D:
				return j * 4 + Dir.U
			_:
				return m
	if d == Dir.R or d == Dir.L:
		return m
	return -1


## All canonical codes, ascending.
func legal_moves(state: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			var v := state[i]
			if v == 0:
				continue
			if x + 1 < w:
				var t := state[i + 1]
				if t != v:
					out.append(i * 4 + Dir.R)
			if x > 0 and state[i - 1] == 0:
				out.append(i * 4 + Dir.L)
			if y + 1 < h:
				var t := state[i + w]
				if t != 0 and t != v:
					out.append(i * 4 + Dir.U)
	return out


func count_tiles(state: PackedByteArray) -> int:
	var n := 0
	for v in state:
		if v != 0:
			n += 1
	return n


func is_dead_end(state: PackedByteArray) -> bool:
	return not is_solved(state) and legal_moves(state).is_empty()


## Moves tiles of a canonical move, no settling. Returns [col_a, col_b].
func _move_only(s: PackedByteArray, m: int) -> Vector2i:
	var i := m >> 2
	var x := i % w
	match m & 3:
		Dir.R:
			var j := i + 1
			if s[j] == 0:
				s[j] = s[i]
				s[i] = 0
			else:
				var t := s[j]
				s[j] = s[i]
				s[i] = t
			return Vector2i(x, x + 1)
		Dir.L:
			s[i - 1] = s[i]
			s[i] = 0
			return Vector2i(x, x - 1)
		_:
			var j := i + w
			var t := s[j]
			s[j] = s[i]
			s[i] = t
			return Vector2i(x, x)


## Legal canonical move plus full resolution (fast: only touched columns are settled, only changed rows scanned).
func step(state: PackedByteArray, m: int) -> PackedByteArray:
	var s := state.duplicate()
	var cols := _move_only(s, m)
	var ymin := PackedInt32Array()
	ymin.resize(w)
	ymin.fill(h)
	ymin[cols.x] = 0
	ymin[cols.y] = 0
	_waves(s, ymin)
	return s


## Settle and resolve everything (used for arbitrary boards).
func resolve(state: PackedByteArray) -> PackedByteArray:
	var s := state.duplicate()
	var ymin := PackedInt32Array()
	ymin.resize(w)
	ymin.fill(0)
	_waves(s, ymin)
	return s


# ymin[x]: lowest row that changed in column x (h = untouched); cells below are a settled stack
func _waves(s: PackedByteArray, ymin: PackedInt32Array) -> void:
	var w := self.w
	var h := self.h
	while true:
		var lo := h
		# settle touched columns
		for x in w:
			var y0 := ymin[x]
			if y0 >= h:
				continue
			lo = mini(lo, y0)
			var wr := y0
			for y in range(y0, h):
				var v := s[y * w + x]
				if v != 0:
					if wr != y:
						s[wr * w + x] = v
						s[y * w + x] = 0
					wr += 1
		_stamp += 1
		var gone := PackedInt32Array()
		# column tens: a settled column run is the whole stack
		for x in w:
			if ymin[x] >= h:
				continue
			var sum := 0
			var n := 0
			while n < h and s[n * w + x] != 0:
				sum += s[n * w + x]
				n += 1
			if sum == TARGET:
				for y in n:
					var i := y * w + x
					_seen[i] = _stamp
					gone.append(i)
		# row tens: rows below the lowest changed cell are as before
		for y in range(lo, h):
			var any := false
			var x := 0
			while x < w:
				if s[y * w + x] == 0:
					x += 1
					continue
				any = true
				var x0 := x
				var sum := 0
				while x < w and s[y * w + x] != 0:
					sum += s[y * w + x]
					x += 1
				if sum == TARGET:
					for xx in range(x0, x):
						var i := y * w + xx
						if _seen[i] != _stamp:
							_seen[i] = _stamp
							gone.append(i)
			if not any:
				break
		if gone.is_empty():
			return
		ymin.fill(h)
		for i in gone:
			s[i] = 0
			var x := i % w
			ymin[x] = mini(ymin[x], i / w)


## Every tile falls straight down.
func settle(state: PackedByteArray) -> PackedByteArray:
	var s := state.duplicate()
	for x in w:
		var wr := 0
		for y in h:
			var v := s[y * w + x]
			if v != 0:
				s[y * w + x] = 0
				s[wr * w + x] = v
				wr += 1
	return s


## Every maximal horizontal run, cells left to right, rows bottom first.
func row_runs(state: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for y in h:
		var run := PackedInt32Array()
		for x in w:
			var i := y * w + x
			if state[i] != 0:
				run.append(i)
			elif not run.is_empty():
				out.append(run)
				run = PackedInt32Array()
		if not run.is_empty():
			out.append(run)
	return out


## Every maximal vertical run, cells bottom up, columns left first.
func col_runs(state: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for x in w:
		var run := PackedInt32Array()
		for y in h:
			var i := y * w + x
			if state[i] != 0:
				run.append(i)
			elif not run.is_empty():
				out.append(run)
				run = PackedInt32Array()
		if not run.is_empty():
			out.append(run)
	return out


## Cells of the row run through cell i, empty when i is empty.
func row_run_of(state: PackedByteArray, i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if state[i] == 0:
		return out
	var y := i / w
	var x0 := i % w
	while x0 > 0 and state[y * w + x0 - 1] != 0:
		x0 -= 1
	var x := x0
	while x < w and state[y * w + x] != 0:
		out.append(y * w + x)
		x += 1
	return out


## Cells of the column run through cell i, empty when i is empty.
func col_run_of(state: PackedByteArray, i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if state[i] == 0:
		return out
	var x := i % w
	var y0 := i / w
	while y0 > 0 and state[(y0 - 1) * w + x] != 0:
		y0 -= 1
	var y := y0
	while y < h and state[y * w + x] != 0:
		out.append(y * w + x)
		y += 1
	return out


## Totals of the row run and the column run through cell i as (row, column); (0, 0) for an empty cell.
func run_totals_at(state: PackedByteArray, i: int) -> Vector2i:
	return Vector2i(run_total(state, row_run_of(state, i)), run_total(state, col_run_of(state, i)))


func run_total(state: PackedByteArray, cells: PackedInt32Array) -> int:
	var n := 0
	for i in cells:
		n += state[i]
	return n


## Sorted union of the cells of all tens (row and column runs with total TARGET).
func tens(state: PackedByteArray) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for runs in [row_runs(state), col_runs(state)]:
		for run: PackedInt32Array in runs:
			if run_total(state, run) == TARGET:
				for i in run:
					if not cells.has(i):
						cells.append(i)
	cells.sort()
	return cells


## Number of row and column runs with a total above TARGET.
func over_runs(state: PackedByteArray) -> int:
	var n := 0
	for runs in [row_runs(state), col_runs(state)]:
		for run: PackedInt32Array in runs:
			if run_total(state, run) > TARGET:
				n += 1
	return n


func is_settled(state: PackedByteArray) -> bool:
	return settle(state) == state


func is_stable(state: PackedByteArray) -> bool:
	return is_settled(state) and tens(state).is_empty()


## Same result as step(), written plainly: whole-board settle and scan each wave.
func step_reference(state: PackedByteArray, m: int) -> PackedByteArray:
	var s := state.duplicate()
	_move_only(s, m)
	while true:
		s = settle(s)
		var cells := tens(s)
		if cells.is_empty():
			return s
		for i in cells:
			s[i] = 0
	return s


## Result plus animation steps: swap/slide, then per settle fall, per wave vanish.
func step_traced(state: PackedByteArray, m: int) -> Dictionary:
	var s := state.duplicate()
	var steps: Array = []
	var i := m >> 2
	var j := i + 1 if (m & 3) == Dir.R else i - 1 if (m & 3) == Dir.L else i + w
	if s[j] == 0:
		steps.append({"kind": "slide", "from": i, "to": j})
	else:
		steps.append({"kind": "swap", "a": i, "b": j})
	_move_only(s, m)
	while true:
		var moves: Array = []
		for x in w:
			var wr := 0
			for y in h:
				var c := y * w + x
				var v := s[c]
				if v != 0:
					if wr != y:
						moves.append([c, wr * w + x])
						s[wr * w + x] = v
						s[c] = 0
					wr += 1
		if not moves.is_empty():
			steps.append({"kind": "fall", "moves": moves})
		var cells := tens(s)
		if cells.is_empty():
			break
		for c in cells:
			s[c] = 0
		steps.append({"kind": "vanish", "cells": cells})
	return {"state": s, "steps": steps}
