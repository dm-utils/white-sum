extends RefCounted
## Rules of design 2: the six examples, runs, canonical form, fast vs reference, notation, attempt and record.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_examples()
	_runs()
	_canonical()
	_random_agreement()
	_traced()
	_invariants()
	_notation()
	_attempt()


static func mk(rows: Array) -> SumBoard:
	var b := SumBoard.create(str(rows[0]).length(), rows.size())
	b.start = b.from_rows(PackedStringArray(rows))
	return b


func _play(b: SumBoard, s: PackedByteArray, token: String) -> PackedByteArray:
	return b.step(s, b.decode_move(token))


## Random stable state: random column heights and values, then resolved.
static func random_state(b: SumBoard, rng: WhiteRng, min_tiles: int, max_tiles: int) -> PackedByteArray:
	while true:
		var s := PackedByteArray()
		s.resize(b.w * b.h)
		for x in b.w:
			for y in rng.range_int(0, b.h):
				s[y * b.w + x] = rng.range_int(1, 5)
		s = b.resolve(s)
		var n := b.count_tiles(s)
		if n >= min_tiles and n <= max_tiles:
			return s
	return PackedByteArray()


func _examples() -> void:
	var b := mk([".2..", "2433"])
	_check.call(b.is_stable(b.start), "example 1 start is stable (row 1 is over)")
	var s := _play(b, b.start, "UB1")
	_check.call(b.render(s) == "....\n.4..", "example 1: the swap makes row 1 a ten, the 4 falls")
	b = mk(["23.5", "4153"])
	_check.call(b.is_stable(b.start), "example 2 start is stable")
	s = _play(b, b.start, "LD2")
	_check.call(b.render(s) == "....\n41.3", "example 2: row 2 and column C vanish together")
	var r := b.step_traced(b.start, b.decode_move("LD2"))
	var vanishes: Array = r.steps.filter(func(st: Dictionary) -> bool: return st.kind == "vanish")
	_check.call(vanishes.size() == 1 and Array(vanishes[0].cells) == [2, 4, 5, 6],
			"example 2: one vanish step with A2, B2, C2 and C1")
	b = mk(["....5", "33452"])
	_check.call(b.is_stable(b.start), "example 3 start is stable (row 1 is over)")
	s = _play(b, b.start, "LE2")
	_check.call(b.render(s) == ".....\n....2", "example 3: column D vanishes, then the row 3 + 3 + 4")
	b = mk(["3432.", "11214"])
	_check.call(b.is_stable(b.start), "example 4 start is stable (row 2 is over)")
	s = _play(b, b.start, "RD2")
	_check.call(b.render(s) == "....2\n11214", "example 4: the slide splits the over row")
	b = mk(["..5.", "..1.", "2534"])
	_check.call(b.is_stable(b.start), "example 5 start is stable")
	s = _play(b, b.start, "RC1")
	_check.call(b.render(s) == "....\n....\n25.3", "example 5: the swap makes column C a ten")
	s = _play(b, s, "LD1")
	_check.call(b.is_solved(s), "example 5: RC1 LD1 empties the board")
	var single := true
	for m in b.legal_moves(b.start):
		if b.is_solved(b.step(b.start, m)):
			single = false
	_check.call(single, "example 5: no single move empties the board")
	var e6 := mk(["......", "222222"])
	_check.call(e6.is_stable(e6.start) and e6.is_dead_end(e6.start) and e6.legal_moves(e6.start).is_empty(),
			"example 6 is stable and a dead end")
	for rows in [[".2..", "2433"], ["23.5", "4153"], ["....5", "33452"], ["3432.", "11214"], ["..5.", "..1.", "2534"]]:
		var eb := mk(rows)
		_check.call(not eb.is_dead_end(eb.start), "no dead end at the start of examples 1-5")


func _runs() -> void:
	var b := mk(["3432.", "11214"])
	var rr := b.row_runs(b.start)
	_check.call(rr.size() == 2 and Array(rr[0]) == [0, 1, 2, 3, 4] and Array(rr[1]) == [5, 6, 7, 8],
			"example 4 row runs: A1..E1 then A2..D2")
	var cr := b.col_runs(b.start)
	_check.call(cr.size() == 5 and Array(cr[0]) == [0, 5] and Array(cr[4]) == [4], "example 4 column runs: one per column")
	var once := true
	for i in b.w * b.h:
		if b.start[i] == 0:
			continue
		var in_rows := 0
		for run in rr:
			in_rows += 1 if run.has(i) else 0
		var in_cols := 0
		for run in cr:
			in_cols += 1 if run.has(i) else 0
		once = once and in_rows == 1 and in_cols == 1
	_check.call(once, "every tile is in exactly one row run and one column run")
	_check.call(b.run_total(b.start, rr[0]) == 9 and b.run_total(b.start, rr[1]) == 12, "run totals")
	_check.call(b.over_runs(b.start) == 1, "example 4 has one over run")
	_check.call(b.tens(b.start).is_empty(), "example 4 start has no ten")
	var gap := mk(["2.3", "333"])
	_check.call(gap.row_runs(gap.start).size() == 3, "a gap splits a row into two runs")
	# helper for the selection totals: sum of the run through a cell
	_check.call(b.run_totals_at(b.start, 2) == Vector2i(9, 5), "run totals at C1: row 9, column 5")
	_check.call(b.run_totals_at(b.start, 7) == Vector2i(12, 5), "run totals at C2: row 12, column 5")
	_check.call(b.run_totals_at(b.start, 4) == Vector2i(9, 4), "run totals at E1: row 9, column 4")
	var e := mk(["3.", "21"])
	_check.call(e.run_totals_at(e.start, 2) == Vector2i(3, 5), "run totals at A2 with a gap beside it")
	_check.call(e.run_totals_at(e.start, 1) == Vector2i(3, 1), "run totals at B1")
	_check.call(e.run_totals_at(e.start, 3) == Vector2i(0, 0) and e.row_run_of(e.start, 3).is_empty(),
			"run totals of an empty cell are zero")
	var loose := mk(["5.", ".5", "5."])
	_check.call(loose.col_runs(loose.start).size() == 3 and loose.tens(loose.start).is_empty(),
			"on an unsettled board a gap splits a column run")
	var tn := mk(["5.", "5."])
	_check.call(Array(tn.tens(tn.start)) == [0, 2], "tens lists a column ten, sorted")


func _canonical() -> void:
	var b := mk(["...", "11.", "121"])
	var c := func(t: String) -> int: return b.canonical(b.start, b.decode_move(t))
	_check.call(c.call("DB2") == b.decode_move("UB1"), "D over a tile becomes U at the lower cell")
	_check.call(c.call("LC1") == b.decode_move("RB1"), "L over a tile becomes R at the left cell")
	_check.call(c.call("RA2") == -1, "swap of equal values is ignored")
	_check.call(c.call("RA3") == -1, "move from an empty cell is ignored")
	_check.call(c.call("LA1") == -1, "move off the board is ignored")
	_check.call(c.call("UA3") == -1 and c.call("UB2") == -1, "up from the top row or into an empty cell is ignored")
	var s := mk(["..5.", "..1.", "2534"])
	var d := func(t: String) -> int: return s.canonical(s.start, s.decode_move(t))
	_check.call(d.call("LD1") == s.decode_move("RC1"), "L over a tile is the swap at the left cell")
	_check.call(d.call("LC2") == s.decode_move("LC2"), "L into an empty cell stays a slide")
	_check.call(d.call("UD1") == -1, "U into an empty cell is ignored")
	_check.call(d.call("DC2") == s.decode_move("UC1"), "D swap is spelled as U from the lower cell")
	_check.call(d.call("DB1") == -1 and d.call("RD1") == -1, "D at the floor and R at the edge are ignored")
	_check.call(s.apply(s.start, s.decode_move("RD1")) == null, "apply returns null for an ignored action")
	var before: PackedByteArray = s.start.duplicate()
	s.apply(s.start, s.decode_move("RB1"))
	_check.call(s.start == before, "apply does not modify its argument")
	var ok := true
	for m in s.legal_moves(s.start):
		if s.canonical(s.start, m) != m:
			ok = false
	_check.call(ok, "legal moves are canonical")


func _random_agreement() -> void:
	var rng := WhiteRng.new(12345)
	var b := SumBoard.create(6, 7)
	var bad := 0
	var n := 0
	for k in 10000:
		var s := random_state(b, rng, 6, 30)
		var moves := b.legal_moves(s)
		if moves.is_empty():
			continue
		var m := moves[rng.range_int(0, moves.size() - 1)]
		var f := b.step(s, m)
		n += 1
		if not b.is_stable(f) or f != b.step_reference(s, m) or b.step_traced(s, m).state != f:
			bad += 1
	_check.call(n >= 9000, "random pairs were tested")
	_check.call(bad == 0, "step is stable and equals step_reference and step_traced on random pairs")
	var w := SumBoard.create(3, 5)
	bad = 0
	for k in 2000:
		var s := random_state(w, rng, 3, 14)
		for m in w.legal_moves(s):
			if w.step(s, m) != w.step_reference(s, m):
				bad += 1
	_check.call(bad == 0, "fast and reference agree on every move of narrow boards")


func _traced() -> void:
	var b := mk(["....5", "33452"])
	var r := b.step_traced(b.start, b.decode_move("LE2"))
	var vanishes: Array = r.steps.filter(func(st: Dictionary) -> bool: return st.kind == "vanish")
	_check.call(vanishes.size() == 2, "example 3 yields exactly two vanish steps")
	_check.call(r.steps[0].kind == "slide", "traced steps start with the slide")
	var s := mk([".2..", "2433"])
	var t := s.step_traced(s.start, s.decode_move("UB1"))
	_check.call(t.steps[0].kind == "swap" and t.steps[1].kind == "vanish" and t.steps[2].kind == "fall",
			"swap, vanish, fall in order")
	var u := mk(["3.", "2.", "4."])
	var f := u.step_traced(u.start, u.decode_move("RA2"))
	_check.call(f.steps[0].kind == "slide" and f.steps[1].kind == "fall"
			and f.state == u.step(u.start, u.decode_move("RA2")), "slide then fall, traced state equals step")


func _invariants() -> void:
	var rng := WhiteRng.new(99)
	var b := SumBoard.create(5, 6)
	var ok := true
	for _k in 500:
		var s := random_state(b, rng, 6, 24)
		var moves := b.legal_moves(s)
		if moves.is_empty():
			continue
		var f := b.step(s, moves[rng.range_int(0, moves.size() - 1)])
		if b.count_tiles(f) > b.count_tiles(s) or _total(f) > _total(s):
			ok = false
	_check.call(ok, "tiles never appear and the board total never grows")
	var a := PackedByteArray([2, 3, 0])
	var c := PackedByteArray([2, 3, 0])
	var d := {a: 1}
	_check.call(d.has(c), "equal packed arrays hit the same dictionary key")
	var bd := mk(["..5.", "..1.", "2534"])
	_check.call(SumBoard.from_dict(bd.to_dict(bd.start)).start == bd.start, "from_dict(to_dict) round-trips")
	_check.call(bd.to_dict(bd.start).rows == ["..5.", "..1.", "2534"], "to_dict gives top-first rows")


func _total(s: PackedByteArray) -> int:
	var n := 0
	for v in s:
		n += v
	return n


func _notation() -> void:
	var b := SumBoard.create(8, 9)
	var rx := RegEx.create_from_string("^[RLUD][A-H][1-9]$")
	var ok := true
	for m in 8 * 9 * 4:
		var t := b.encode_move(m)
		if rx.search(t) == null or b.decode_move(t) != m:
			ok = false
	_check.call(ok, "encode and decode round-trip every code on 8x9 with valid tokens")
	for t in ["rb1", "XB1", "RJ1", "RB0", "RB", "RB10"]:
		_check.call(b.decode_move(t) == null, "decode_move rejects " + t)
	var s := SumBoard.create(4, 3)
	_check.call(s.decode_move("RE1") == null and s.decode_move("RA4") == null, "decode_move rejects cells off the board")
	_check.call(b.move_len() == 3, "tokens have three characters")


func _attempt() -> void:
	var b := mk(["..5.", "..1.", "2534"])
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	a.apply_record("RA1zRC1LD1")
	_check.call(a.solved() and a.count() == 2 and a.moves_made == 3, "record RA1zRC1LD1: solved, count 2 in final-only")
	var e := WhiteAttempt.new(b, WhiteAttempt.CountMode.EVERY_MOVE)
	e.apply_record("RA1zRC1LD1")
	_check.call(e.count() == 3, "record RA1zRC1LD1 counts 3 in every-move mode")
	_check.call(e.record == "RA1zRC1LD1", "record is replayed to the same text")
	var f := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	_check.call(not f.play(b.decode_move("RD1")) and f.record == "", "ignored action is not counted or recorded")
	_check.call(not f.undo() and not f.restart(), "impossible undo and restart are ignored")
	f.play(b.decode_move("RC1"))
	f.play(b.decode_move("LD1"))
	_check.call(f.solved() and not f.play(b.decode_move("RA1")), "after solving every action is ignored")
	var g := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	g.play(b.decode_move("RA1"))
	_check.call(g.count() == 1, "one move counts one")
	g.undo()
	_check.call(g.count() == 0 and g.moves_made == 1, "undo lowers the count, moves_made keeps everything")
	g.play(b.decode_move("RC1"))
	g.restart()
	_check.call(g.count() == 0 and g.state == b.start, "restart sets the count to 0")
	var h := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var k := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	h.apply_record("LD1zRC1")
	k.apply_record("RC1zRC1")
	_check.call(h.state == k.state, "LD1 plays like RC1")
