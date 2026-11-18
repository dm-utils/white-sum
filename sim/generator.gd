class_name SumGenerator
extends RefCounted
## Reverse-building puzzle generator: grows a board backwards from empty by inserting tens, so every puzzle is
## solvable and the number of reverse steps bounds par. Draws only from WhiteRng seeded with the seed.

const RETRIES := 50

# gap -1: no greedy filter; i/q/row_k/col_k ranges inclusive; band par range inclusive; chain and col in percent
const LEVELS: Array[Dictionary] = [
	{"w": 5, "h": 5, "i": [2, 3], "q": [0, 1], "chain": 0, "col": 25, "row_k": [2, 3], "col_k": [2, 3],
		"values": 3, "over": 1, "gap": -1, "band": [2, 3], "candidates": 400, "beam": 30, "budget": 100000},
	{"w": 6, "h": 6, "i": [3, 4], "q": [1, 2], "chain": 25, "col": 30, "row_k": [2, 4], "col_k": [3, 4],
		"values": 4, "over": 1, "gap": 1, "band": [4, 5], "candidates": 800, "beam": 30, "budget": 400000},
	{"w": 6, "h": 6, "i": [4, 6], "q": [1, 3], "chain": 35, "col": 30, "row_k": [3, 4], "col_k": [3, 4],
		"values": 4, "over": 2, "gap": 1, "band": [6, 7], "candidates": 1500, "beam": 30, "budget": 1000000},
]


## {"board": SumBoard, "par", "exact", "upper", "path", "tried", "fallback"}
static func generate(seed_value: int, level: int) -> Dictionary:
	return generate_with(seed_value, LEVELS[level])


static func generate_with(seed_value: int, cfg: Dictionary) -> Dictionary:
	var rng := WhiteRng.new(seed_value)
	var board := SumBoard.create(cfg.w, cfg.h)
	var band: Array = cfg.band
	var fb := {}
	var fb_key := []
	var tried := 0
	for t in cfg.candidates:
		tried += 1
		var cand := _candidate(board, rng, cfg)
		if cand.is_empty():
			continue
		var start: PackedByteArray = cand.start
		var path: PackedInt32Array = cand.path
		var upper := path.size()
		if upper < band[0] or not _cheap_ok(board, start, cfg):
			continue
		# cheap beam first: a line below the band proves par is too low, no need to search
		var sol_path := path
		var bm := SumSolver.beam(board, start, cfg.beam, upper - 1)
		if not bm.is_empty():
			if bm.size() < band[0]:
				continue
			sol_path = bm
		var r := SumSolver.solve(board, start, sol_path, cfg.budget)
		var par: int = r.par
		var res := {"start": start, "par": par, "exact": r.exact, "upper": upper, "path": r.path}
		var dist := maxi(0, maxi(band[0] - par, par - band[1]))
		var key := [dist, 0 if r.exact else 1, board.count_tiles(start)]
		if fb.is_empty() or _less(key, fb_key):
			fb = res
			fb_key = key
		# phase 1 accepts bounded par
		if dist > 0:
			continue
		if cfg.gap >= 0:
			var g := SumSolver.greedy(board, start, 3 * upper)
			if g.solved and g.moves < par + cfg.gap:
				continue
		return _result(board, res, tried, false)
	if fb.is_empty():
		return _result(board, {"start": board.start, "par": 0, "exact": false, "upper": 0,
				"path": PackedInt32Array()}, tried, true)
	return _result(board, fb, tried, true)


static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


static func _result(board: SumBoard, res: Dictionary, tried: int, fallback: bool) -> Dictionary:
	board.start = res.start
	return {"board": board, "par": res.par, "exact": res.exact, "upper": res.upper, "path": res.path,
			"tried": tried, "fallback": fallback}


## The puzzle object of design 6.3.
static func to_json(result: Dictionary) -> Dictionary:
	var b: SumBoard = result.board
	var tokens := ""
	for m in result.path:
		tokens += b.encode_move(m)
	var d := {"board": b.to_dict(b.start), "par": result.par, "exact": result.exact, "upper": result.upper,
			"path": tokens}
	if result.fallback:
		d["fallback"] = true
	return d


static func _cheap_ok(board: SumBoard, s: PackedByteArray, cfg: Dictionary) -> bool:
	if board.is_solved(s) or not board.is_stable(s):
		return false
	var seen := {}
	for v in s:
		if v != 0:
			seen[v] = true
	if seen.size() < cfg.values:
		return false
	return board.over_runs(s) >= cfg.over


# --- building ----------------------------------------------------------------------------------------------------

# {"start", "path"} or {} when a step fails all its retries
static func _candidate(board: SumBoard, rng: WhiteRng, cfg: Dictionary) -> Dictionary:
	var n_ins := rng.range_int(cfg.i[0], cfg.i[1])
	var n_quiet := rng.range_int(cfg.q[0], cfg.q[1])
	var rest: Array = []
	for k in n_ins - 1:
		rest.append(0)
	for k in n_quiet:
		rest.append(1)
	rng.shuffle(rest)
	var steps: Array = [0]
	steps.append_array(rest)
	var c := PackedByteArray()
	c.resize(board.w * board.h)
	var rev := PackedInt32Array() # forward moves, last executed step first
	for kind in steps:
		var out := {}
		for r in RETRIES:
			out = _quiet_step(board, rng, c) if kind == 1 else _insert_step(board, rng, c, cfg)
			if not out.is_empty():
				break
		if out.is_empty():
			return {}
		c = out.p
		rev.append(out.m)
	rev.reverse()
	return {"start": c, "path": rev}


static func _heights(board: SumBoard, s: PackedByteArray) -> PackedInt32Array:
	var hs := PackedInt32Array()
	hs.resize(board.w)
	for x in board.w:
		var n := 0
		while n < board.h and s[n * board.w + x] != 0:
			n += 1
		hs[x] = n
	return hs


## k values in 1..5 adding up to 10, shuffled.
static func ten_values(rng: WhiteRng, k: int) -> Array:
	var vals: Array = []
	var sum := 0
	for j in k - 1:
		var r := SumBoard.TARGET - sum
		var left := k - 1 - j
		var v := rng.range_int(maxi(1, r - 5 * left), mini(5, r - left))
		vals.append(v)
		sum += v
	vals.append(SumBoard.TARGET - sum)
	rng.shuffle(vals)
	return vals


# {"state", "cells", "row", "y", "c0", "k"} or {}; cells ascending
static func _insert_ten(board: SumBoard, rng: WhiteRng, b: PackedByteArray, cfg: Dictionary) -> Dictionary:
	var w := board.w
	var s := b.duplicate()
	var cells := PackedInt32Array()
	if rng.range_int(0, 99) < cfg.col:
		var k := rng.range_int(cfg.col_k[0], mini(cfg.col_k[1], board.h))
		var vals := ten_values(rng, k)
		var hs := _heights(board, b)
		var empty: Array = []
		for x in w:
			if hs[x] == 0:
				empty.append(x)
		if empty.is_empty():
			return {}
		var cx: int = empty[rng.range_int(0, empty.size() - 1)]
		for y in k:
			s[y * w + cx] = vals[y]
			cells.append(y * w + cx)
		return {"state": s, "cells": cells, "row": false, "y": 0, "c0": cx, "k": 1}
	var k := rng.range_int(cfg.row_k[0], mini(cfg.row_k[1], w))
	var c0 := rng.range_int(0, w - k)
	var vals := ten_values(rng, k)
	var hs := _heights(board, b)
	var hmin := board.h
	for x in range(c0, c0 + k):
		if hs[x] + 1 > board.h:
			return {}
		hmin = mini(hmin, hs[x])
	var y := rng.range_int(0, hmin)
	# maximal: an old tile beside the new run would join it
	if (c0 > 0 and b[y * w + c0 - 1] != 0) or (c0 + k < w and b[y * w + c0 + k] != 0):
		return {}
	for j in k:
		var x := c0 + j
		for yy in range(hs[x] - 1, y - 1, -1):
			s[(yy + 1) * w + x] = s[yy * w + x]
		s[y * w + x] = vals[j]
		cells.append(y * w + x)
	return {"state": s, "cells": cells, "row": true, "y": y, "c0": c0, "k": k}


# true when cells are exactly one maximal row run or column run of s with total TARGET
static func _is_ten(board: SumBoard, s: PackedByteArray, cells: PackedInt32Array) -> bool:
	if cells.is_empty() or board.run_total(s, cells) != SumBoard.TARGET:
		return false
	return board.row_run_of(s, cells[0]) == cells or board.col_run_of(s, cells[0]) == cells


static func _insert_step(board: SumBoard, rng: WhiteRng, c: PackedByteArray, cfg: Dictionary) -> Dictionary:
	var x: PackedByteArray
	if rng.range_int(0, 99) < cfg.chain:
		var t2 := _insert_ten(board, rng, c, cfg)
		if t2.is_empty() or not _is_ten(board, t2.state, t2.cells) or board.resolve(t2.state) != c:
			return {}
		var t1 := _insert_ten(board, rng, t2.state, cfg)
		if t1.is_empty():
			return {}
		x = t1.state
		if not _is_ten(board, x, t1.cells):
			return {}
		# where the t2 tiles ended up after t1 pushed columns up
		var moved := PackedInt32Array()
		for cell in t2.cells:
			var cx: int = cell % board.w
			var cy: int = cell / board.w
			if t1.row and cx >= t1.c0 and cx < t1.c0 + t1.k and cy >= t1.y:
				cy += 1
			moved.append(cy * board.w + cx)
		moved.sort()
		if _is_ten(board, x, moved):
			return {}
	else:
		var t := _insert_ten(board, rng, c, cfg)
		if t.is_empty() or not _is_ten(board, t.state, t.cells):
			return {}
		x = t.state
	if board.resolve(x) != c:
		return {}
	return _reverse_move(board, rng, x, c, false)


static func _quiet_step(board: SumBoard, rng: WhiteRng, c: PackedByteArray) -> Dictionary:
	return _reverse_move(board, rng, c, c, true)


# {"p", "m"}: a stable predecessor of x with a forward move reaching t, picked uniformly among the valid ones
static func _reverse_move(board: SumBoard, rng: WhiteRng, x: PackedByteArray, t: PackedByteArray,
		quiet: bool) -> Dictionary:
	var w := board.w
	var cands: Array = [] # [p, m]
	for y in board.h:
		for cx in w:
			var i := y * w + cx
			var v := x[i]
			if v == 0:
				continue
			if cx + 1 < w and x[i + 1] != 0 and x[i + 1] != v:
				var p := x.duplicate()
				p[i] = x[i + 1]
				p[i + 1] = v
				cands.append([p, i * 4 + SumBoard.Dir.R])
			if y + 1 < board.h and x[i + w] != 0 and x[i + w] != v:
				var p := x.duplicate()
				p[i] = x[i + w]
				p[i + w] = v
				cands.append([p, i * 4 + SumBoard.Dir.U])
	var hs := _heights(board, x)
	for xs in w: # x' of the spec
		if hs[xs] < 1:
			continue
		for xd in [xs - 1, xs + 1]:
			if xd < 0 or xd >= w or hs[xd] + 1 > board.h:
				continue
			var top := (hs[xs] - 1) * w + xs
			var v := x[top]
			for y in range(maxi(0, hs[xs] - 1), hs[xd] + 1):
				var p := x.duplicate()
				p[top] = 0
				for yy in range(hs[xd] - 1, y - 1, -1):
					p[(yy + 1) * w + xd] = p[yy * w + xd]
				p[y * w + xd] = v
				cands.append([p, (y * w + xd) * 4 + (SumBoard.Dir.R if xs == xd + 1 else SumBoard.Dir.L)])
	while not cands.is_empty():
		var j := rng.range_int(0, cands.size() - 1)
		var cand: Array = cands[j]
		cands[j] = cands[cands.size() - 1]
		cands.resize(cands.size() - 1)
		var p: PackedByteArray = cand[0]
		if quiet and p == t:
			continue
		if board.is_stable(p) and board.step(p, cand[1]) == t:
			return {"p": p, "m": cand[1]}
	return {}
