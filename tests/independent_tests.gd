extends RefCounted
## Independent checks: a naive oracle written from the rules text (design 2), sharing no code with SumBoard.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_own_examples()
	_oracle_agreement()


# --- naive oracle: grid[x][y], y up -----------------------------------------------------------------------------

func _o_parse(rows: Array) -> Array:
	var h := rows.size()
	var w := str(rows[0]).length()
	var g := []
	for x in w:
		var col := []
		for y in h:
			var c := str(rows[h - 1 - y])[x]
			col.append(0 if c == "." else int(c))
		g.append(col)
	return g


func _o_render(g: Array) -> String:
	var lines := []
	var h: int = g[0].size()
	for ry in h:
		var s := ""
		for x in g.size():
			var v: int = g[x][h - 1 - ry]
			s += "." if v == 0 else str(v)
		lines.append(s)
	return "\n".join(lines)


func _o_resolve(g: Array) -> Array:
	var w := g.size()
	var h: int = g[0].size()
	while true:
		for x in w:
			var col := []
			for v in g[x]:
				if v != 0:
					col.append(v)
			while col.size() < h:
				col.append(0)
			g[x] = col
		var gone := {}
		# every maximal horizontal run, then every maximal vertical run
		for y in h:
			var x := 0
			while x < w:
				if g[x][y] == 0:
					x += 1
					continue
				var x1 := x
				var sum := 0
				while x1 < w and g[x1][y] != 0:
					sum += g[x1][y]
					x1 += 1
				if sum == 10:
					for xx in range(x, x1):
						gone[Vector2i(xx, y)] = true
				x = x1
		for x in w:
			var y := 0
			while y < h:
				if g[x][y] == 0:
					y += 1
					continue
				var y1 := y
				var sum := 0
				while y1 < h and g[x][y1] != 0:
					sum += g[x][y1]
					y1 += 1
				if sum == 10:
					for yy in range(y, y1):
						gone[Vector2i(x, yy)] = true
				y = y1
		if gone.is_empty():
			return g
		for c in gone:
			g[c.x][c.y] = 0
	return g


## Oracle move from (x, y) by (dx, dy); null when ignored, else the resolved grid.
func _o_move(g: Array, x: int, y: int, dx: int, dy: int) -> Variant:
	var w := g.size()
	var h: int = g[0].size()
	var nx := x + dx
	var ny := y + dy
	if x < 0 or x >= w or y < 0 or y >= h or g[x][y] == 0:
		return null
	if nx < 0 or nx >= w or ny < 0 or ny >= h:
		return null
	var src: int = g[x][y]
	var tgt: int = g[nx][ny]
	if tgt == src:
		return null
	if tgt == 0 and dy != 0:
		return null
	var n := g.duplicate(true)
	n[x][y] = tgt
	n[nx][ny] = src
	return _o_resolve(n)


func _o_grid_of(b: SumBoard, s: PackedByteArray) -> Array:
	var g := []
	for x in b.w:
		var col := []
		for y in b.h:
			col.append(int(s[y * b.w + x]))
		g.append(col)
	return g


func _o_legal(g: Array) -> int:
	var n := 0
	for x in g.size():
		for y in g[0].size():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var tx: int = x + d.x
				var ty: int = y + d.y
				var swap: bool = tx >= 0 and tx < g.size() and ty >= 0 and ty < g[0].size() and g[tx][ty] != 0
				if swap and (d.x < 0 or d.y < 0):
					continue # same swap counted from the other side
				if _o_move(g, x, y, d.x, d.y) != null:
					n += 1
	return n


func _mk(rows: Array) -> SumBoard:
	return preload("res://tests/rules_tests.gd").mk(rows)


func _own_examples() -> void:
	var ex2 := ["23.5", "4153"]
	var r: Variant = _o_move(_o_parse(ex2), 3, 1, -1, 0)
	_check.call(r != null and _o_render(r) == "....\n41.3", "oracle: example 2 cross")
	var col: SumBoard = _mk(["1.", "2.", "3.", "4."])
	_check.call(Array(col.tens(col.start)) == [0, 2, 4, 6], "a column of 1, 2, 3, 4 is a ten of four tiles")
	_check.call(_o_render(_o_resolve(_o_parse(["1.", "2.", "3.", "4."]))) == "..\n..\n..\n..",
			"oracle: the same column vanishes")
	var over: SumBoard = _mk(["444."])
	_check.call(over.tens(over.start).is_empty() and over.over_runs(over.start) == 1, "an over row vanishes in no part")
	var join: SumBoard = _mk(["...", "5.5"])
	_check.call(join.is_stable(join.start), "5 and 5 with a gap are two short runs")
	_check.call(join.is_solved(join.step(join.start, join.decode_move("RA1"))), "sliding closes the gap and the ten vanishes")
	var two: SumBoard = _mk(["5.5.", "5.5."])
	_check.call(two.resolve(two.start) == two.from_rows(PackedStringArray(["....", "...."])),
			"two column tens vanish in one wave")
	_check.call(_o_render(_o_resolve(_o_parse(["5.5.", "5.5."]))) == "....\n....", "oracle: the same two columns vanish")


func _oracle_agreement() -> void:
	var rules := preload("res://tests/rules_tests.gd")
	var rng := WhiteRng.new(4242)
	var boards := [SumBoard.create(6, 6), SumBoard.create(5, 5), SumBoard.create(4, 3)]
	var tested := 0
	var bad := 0
	var legal_bad := 0
	for n in 300:
		var b: SumBoard = boards[n % 3]
		var s := rules.random_state(b, rng, 3, 22)
		var g := _o_grid_of(b, s)
		if _o_legal(g) != b.legal_moves(s).size():
			legal_bad += 1
		for i in b.w * b.h:
			for d in 4:
				var o: Variant = _o_move(g.duplicate(true), i % b.w, i / b.w, [1, -1, 0, 0][d], [0, 0, -1, 1][d])
				var c := b.canonical(s, i * 4 + d)
				if (o == null) != (c < 0):
					bad += 1
				elif o != null:
					tested += 1
					if _o_render(o) != b.render(b.step(s, c)):
						bad += 1
	_check.call(tested > 3000, "the oracle compared thousands of legal moves")
	_check.call(bad == 0, "oracle and SumBoard agree on legality and result for every move of 300 random boards")
	_check.call(legal_bad == 0, "oracle and legal_moves count the same moves")
