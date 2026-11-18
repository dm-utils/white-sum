extends RefCounted
## Every shipped puzzle is re-checked (design 13.1 Pool); full re-solving is tools/verify_puzzles.gd.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	var store := SumGame.store()
	_check.call(store.practice_count() == 40, "the pool has 40 sets")
	var all_ok := true
	var sizes_ok := true
	var fallbacks := 0
	var exact := [0, 0, 0]
	for i in store.practice_count():
		var set := store.practice_set(i)
		sizes_ok = sizes_ok and set.size() == 3
		for level in set.size():
			var p: Dictionary = set[level]
			var why := _problem(p, level)
			if not why.is_empty():
				all_ok = false
				print("pool set %d level %d: %s" % [i, level, why])
			fallbacks += 1 if p.fallback else 0
			exact[level] += 1 if p.exact else 0
	_check.call(sizes_ok, "every set has three puzzles")
	_check.call(all_ok, "every pool puzzle is stable, in band and cleared by its path in par moves")
	_check.call(fallbacks <= 2, "at most two flagged fallback puzzles in the pool")
	_check.call(exact[0] == 40 and exact[1] == 40, "easy and medium puzzles of the pool have exact par")
	var pars := [[], [], []]
	for i in store.practice_count():
		for level in 3:
			pars[level].append(store.practice_set(i)[level].par)
	_check.call(_median(pars[0]) < _median(pars[1]) and _median(pars[1]) < _median(pars[2]),
			"median par of the pool increases with the level")


func _median(a: Array) -> int:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _problem(p: Dictionary, level: int) -> String:
	var b: SumBoard = p.board
	var s := b.start
	if b.is_solved(s) or not b.is_stable(s):
		return "start is empty or not stable"
	var band: Array = SumGenerator.LEVELS[level].band
	if not p.fallback and (p.par < band[0] or p.par > band[1]):
		return "par %d outside the band" % p.par
	if p.par > p.upper or p.path.size() != p.par:
		return "par, upper or path length inconsistent"
	for m in p.path:
		var n: Variant = b.apply(s, m)
		if n == null:
			return "path has an ignored move"
		s = n
	return "" if b.is_solved(s) else "path does not empty the board"
