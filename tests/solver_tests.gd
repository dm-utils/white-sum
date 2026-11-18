extends RefCounted
## Solver, generator and determinism (design 5.4, 5.5, 13.1).

const SMALL := {"w": 4, "h": 3, "i": [2, 3], "q": [0, 1], "chain": 20, "col": 30, "row_k": [2, 3], "col_k": [2, 3],
	"values": 1, "over": 0, "gap": -1, "band": [1, 8], "candidates": 60, "beam": 30, "budget": 200000}

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_example_5()
	_beam_greedy()
	_small_boards_against_bfs()
	_ten_values()
	_row_insertion_is_maximal()
	_generator()
	_levels()
	_no_forbidden_rng()


func _ex5() -> SumBoard:
	return preload("res://tests/rules_tests.gd").mk(["..5.", "..1.", "2534"])


func _example_5() -> void:
	var b := _ex5()
	var up := PackedInt32Array([b.decode_move("RC1"), b.decode_move("LD1")])
	var r := SumSolver.solve(b, b.start, up, 1000)
	_check.call(r.par == 2 and r.exact and not r.capped, "solve: example 5 has exact par 2")
	_check.call(_clears(b, r.path) and r.path.size() == 2, "solve: the returned path empties the board")
	var c := SumSolver.solve(b, b.start, up, 0)
	_check.call(c.capped and not c.exact and c.par == 2, "solve: zero budget is capped, bounded, par from upper path")
	var s := b.step(b.start, b.decode_move("RC1"))
	var d := SumSolver.solve(b, s, PackedInt32Array([b.decode_move("LD1")]), 1000)
	_check.call(d.par == 1 and d.exact, "solve: upper path of one move is returned as exact")


func _clears(b: SumBoard, path: PackedInt32Array) -> bool:
	var s := b.start
	for m in path:
		var n: Variant = b.apply(s, m)
		if n == null:
			return false
		s = n
	return b.is_solved(s)


func _beam_greedy() -> void:
	var b := _ex5()
	var p := SumSolver.beam(b, b.start, 50, 3)
	_check.call(p.size() == 2 and _clears(b, p), "beam finds the two-move solution")
	_check.call(SumSolver.beam(b, b.start, 50, 1).is_empty(), "beam returns nothing when the depth is too small")
	var g := SumSolver.greedy(b, b.start, 6)
	_check.call(g.solved and g.moves == 2, "greedy solves example 5 in two moves")
	var dead := SumBoard.create(6, 2)
	dead.start = dead.from_rows(PackedStringArray(["......", "222222"]))
	var h := SumSolver.greedy(dead, dead.start, 6)
	_check.call(not h.solved and h.moves == 0, "greedy gives up when nothing can be removed")


# plain bfs over reachable states, test helper
func _bfs(b: SumBoard) -> int:
	var seen := {b.start: true}
	var level: Array = [b.start]
	var depth := 0
	while not level.is_empty():
		var next: Array = []
		for s in level:
			if b.is_solved(s):
				return depth
			for m in b.legal_moves(s):
				var c := b.step(s, m)
				if not seen.has(c):
					seen[c] = true
					next.append(c)
		level = next
		depth += 1
	return -1


func _small_boards_against_bfs() -> void:
	var found := 0
	var agree := 0
	var sd := 0
	while found < 20 and sd < 400:
		var r := SumGenerator.generate_with(WhiteSeed.fnv1a64("white-sum-test|%d" % sd), SMALL)
		sd += 1
		var b: SumBoard = r.board
		if b.count_tiles(b.start) > 8 or r.fallback or r.par == 0:
			continue
		found += 1
		var truth := _bfs(b)
		if truth == r.par and r.exact:
			agree += 1
	_check.call(found == 20, "twenty small boards found for the bfs comparison")
	_check.call(agree == found, "solver par equals breadth-first search on small boards")


func _ten_values() -> void:
	var ok := true
	for k in range(2, 6):
		for sd in 1000:
			var rng := WhiteRng.new(WhiteSeed.fnv1a64("white-sum-test|tv|%d|%d" % [k, sd]))
			var vals := SumGenerator.ten_values(rng, k)
			var sum := 0
			for v in vals:
				ok = ok and v >= 1 and v <= 5
				sum += v
			ok = ok and vals.size() == k and sum == 10
	_check.call(ok, "ten values: k in 2..5, values 1..5, total 10, over 1000 seeds each")
	var two := SumGenerator.ten_values(WhiteRng.new(5), 2)
	_check.call(two == [5, 5], "a ten of two tiles is always 5 + 5")


func _row_insertion_is_maximal() -> void:
	var rules := preload("res://tests/rules_tests.gd")
	var b := SumBoard.create(6, 6)
	var rng := WhiteRng.new(777)
	var cfg := {"col": 0, "row_k": [2, 4], "col_k": [2, 3]}
	var made := 0
	var ok := true
	for k in 1000:
		var base := rules.random_state(b, rng, 4, 20)
		var t := SumGenerator._insert_ten(b, rng, base, cfg)
		if t.is_empty():
			continue
		made += 1
		var cells: PackedInt32Array = t.cells
		ok = ok and b.row_run_of(t.state, cells[0]) == cells and b.run_total(t.state, cells) == 10
	_check.call(made >= 100, "enough row insertions were made")
	_check.call(ok, "a row ten insertion never joins an old tile to the new run")


func _generator() -> void:
	var a := SumGenerator.generate(WhiteSeed.fnv1a64("white-sum-test|det"), 0)
	var b := SumGenerator.generate(WhiteSeed.fnv1a64("white-sum-test|det"), 0)
	_check.call(SumGenerator.to_json(a) == SumGenerator.to_json(b), "generate twice gives the same puzzle")
	var ok := true
	for sd in 6:
		var r := SumGenerator.generate_with(WhiteSeed.fnv1a64("white-sum-test|g%d" % sd), SMALL)
		var bd: SumBoard = r.board
		ok = ok and bd.is_stable(bd.start) and not bd.is_solved(bd.start) and _clears(bd, r.path) \
				and r.path.size() == r.par and r.par <= r.upper
	_check.call(ok, "generated start is stable and its path empties the board in par moves, par <= upper")
	var j := SumGenerator.to_json(a)
	var conv := SumBoard.from_dict(j.board)
	_check.call(conv.start == (a.board as SumBoard).start and j.path.length() == 3 * j.par, "puzzle json converts back")


func _levels() -> void:
	# easy and medium take well under a second; hard is covered by the pool tests
	var ok := true
	var in_band := true
	for level in 2:
		var r := SumGenerator.generate(WhiteSeed.practice("white-sum", 0, level), level)
		var bd: SumBoard = r.board
		ok = ok and bd.is_stable(bd.start) and _clears(bd, r.path) and r.path.size() == r.par and r.par <= r.upper
		var band: Array = SumGenerator.LEVELS[level].band
		in_band = in_band and (r.fallback or (r.par >= band[0] and r.par <= band[1]))
	_check.call(ok, "pool seed of set 0 gives a valid easy and medium puzzle")
	_check.call(in_band, "set 0 puzzles are in their band unless flagged fallback")
	var bands: Array = []
	for lv in SumGenerator.LEVELS:
		bands.append(lv.band)
	_check.call(bands[0][1] <= bands[1][0] and bands[1][1] <= bands[2][0], "par bands share at most their end value")


func _no_forbidden_rng() -> void:
	var bad := false
	var d := DirAccess.open("res://sim")
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var t := FileAccess.get_file_as_string("res://sim/" + f)
		for w in ["RandomNumberGenerator", "randi(", "randf(", "randomize(", "next_float"]:
			if t.contains(w):
				bad = true
	_check.call(not bad, "sim/ uses no engine randomness")
