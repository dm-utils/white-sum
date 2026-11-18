extends SceneTree
## Phase 1 trial (design 5.7).
##   godot --headless --path . -s res://tools/measure.gd -- [--seeds=50] [--level=N] [--skip-m1] [--m1-only] [--from=0]
##       [--budget=N]
## M1: step() and solver throughput. M2: per level over the trial seeds, prints the figures and checks P1, P2, P3.
## Run the levels in separate processes (at most three at a time) with --level=N --skip-m1.

const NAMES := ["easy", "medium", "hard"]


func _init() -> void:
	var seeds := 50
	var only := -1
	var m1 := true
	var m1_only := false
	var first := 0
	var budget := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			only = int(a.get_slice("=", 1))
		elif a.begins_with("--from="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--budget="):
			budget = int(a.get_slice("=", 1))
		elif a == "--skip-m1":
			m1 = false
		elif a == "--m1-only":
			m1_only = true
	if m1:
		_m1()
	if m1_only:
		quit(0)
		return
	var medians := []
	var total_s := 0.0
	var ok := true
	for level in 3:
		if only >= 0 and level != only:
			continue
		var r := _m2(level, seeds, budget, first)
		medians.append(r.par_median)
		total_s += r.total_s
		ok = ok and r.ok
	if only < 0:
		var inc: bool = medians[0] < medians[1] and medians[1] < medians[2]
		print("P2 median par strictly increasing %s (%s)" % ["ok" if inc else "FAIL", medians])
		print("P3 estimate for 40 sets: %.0f s on one process, %.0f s on 3, %.0f s on 8 (from %.0f s per %d seeds x 3 levels)" % [
			total_s * 40.0 / seeds, total_s * 40.0 / seeds / 3.0, total_s * 40.0 / seeds / 8.0, total_s, seeds])
		ok = ok and inc
	print("trial " + ("ok" if ok else "FAILED"))
	quit(0 if ok else 1)


func _m1() -> void:
	var b := SumBoard.create(6, 6)
	var rng := WhiteRng.new(7)
	var states: Array = []
	var rules := preload("res://tests/rules_tests.gd")
	var moves_total := 0
	while states.size() < 200:
		var s: PackedByteArray = rules.random_state(b, rng, 14, 18)
		var mv := b.legal_moves(s)
		if not mv.is_empty():
			states.append([s, mv])
			moves_total += mv.size()
	var n := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3000000:
		for e in states:
			for m in e[1]:
				b.step(e[0], m)
				n += 1
	print("M1 step(): %.0f per second (6x6, 14-18 tiles)" % (n / ((Time.get_ticks_usec() - t0) / 1e6)))
	print("M1 legal moves per position: %.1f (6x6, 14-18 tiles)" % (moves_total / float(states.size())))
	# a hard pool puzzle with a capped budget keeps the sample long enough
	var p: Dictionary = SumGame.store().practice_set(0)[2]
	var pb: SumBoard = p.board
	var t1 := Time.get_ticks_usec()
	var sol := SumSolver.solve(pb, pb.start, p.path, 20000)
	var dt := (Time.get_ticks_usec() - t1) / 1e6
	print("M1 solver: %.0f expansions per second (%d expansions)" % [sol.expansions / maxf(dt, 1e-6), sol.expansions])


# {"chain": bool, "cross": bool} of one solution line, replayed from the traced steps
func _line_kinds(b: SumBoard, path: PackedInt32Array) -> Dictionary:
	var s := b.start
	var chain := false
	var cross := false
	for m in path:
		var tr := b.step_traced(s, m)
		var g := s.duplicate()
		var waves := 0
		for st in tr.steps:
			match st.kind:
				"swap":
					var t := g[st.a]
					g[st.a] = g[st.b]
					g[st.b] = t
				"slide":
					g[st.to] = g[st.from]
					g[st.from] = 0
				"fall":
					for mv in st.moves:
						g[mv[1]] = g[mv[0]]
						g[mv[0]] = 0
				"vanish":
					waves += 1
					for c in b.row_runs(g):
						if b.run_total(g, c) != SumBoard.TARGET:
							continue
						for d in b.col_runs(g):
							if b.run_total(g, d) != SumBoard.TARGET:
								continue
							for i in c:
								if d.has(i):
									cross = true
					for i in st.cells:
						g[i] = 0
		chain = chain or waves > 1
		s = tr.state
	return {"chain": chain, "cross": cross}


func _m2(level: int, seeds: int, budget: int, first: int) -> Dictionary:
	var cfg: Dictionary = SumGenerator.LEVELS[level].duplicate()
	if budget >= 0:
		cfg.budget = budget
	var pars := PackedInt32Array()
	var uppers := PackedInt32Array()
	var tiles := PackedInt32Array()
	var tried := PackedInt32Array()
	var times := PackedFloat64Array()
	var fallback := 0
	var exact := 0
	var chains := 0
	var crosses := 0
	var total := 0.0
	for n in range(first, first + seeds):
		var t0 := Time.get_ticks_usec()
		var r := SumGenerator.generate_with(WhiteSeed.fnv1a64("white-sum-trial|%d|%d" % [n, level]), cfg)
		var dt := (Time.get_ticks_usec() - t0) / 1e6
		total += dt
		times.append(dt)
		var b: SumBoard = r.board
		pars.append(r.par)
		uppers.append(r.upper)
		tiles.append(b.count_tiles(b.start))
		tried.append(r.tried)
		fallback += 1 if r.fallback else 0
		var kinds := _line_kinds(b, r.path)
		chains += 1 if kinds.chain else 0
		crosses += 1 if kinds.cross else 0
		print("  %s seed %d: par %d upper %d exact %s tried %d fallback %s tiles %d chain %s cross %s %.1f s" % [
			NAMES[level], n, r.par, r.upper, r.exact, r.tried, r.fallback, b.count_tiles(b.start), kinds.chain,
			kinds.cross, dt])
		exact += 1 if r.exact else 0
	var nonfb := seeds - fallback
	var need := ceili(seeds * 0.8)
	print("M2 %-6s board %dx%d  non-fallback %d/%d  exact %d/%d  chain %d/%d  cross %d/%d  tiles med %d  U med %d  par med %d (%s)  tried med %d max %d  build s med %.1f max %.1f total %.0f" % [
		NAMES[level], cfg.w, cfg.h, nonfb, seeds, exact, seeds, chains, seeds, crosses, seeds, _median_i(tiles),
		_median_i(uppers), _median_i(pars), _spread(pars), _median_i(tried), _max_i(tried), _median_f(times),
		_max_f(times), total])
	var ok := nonfb >= need
	print("P1 %s: %d of %d non-fallback (need %d)" % [NAMES[level], nonfb, seeds, need])
	print("P4 %s: exact %d of %d" % [NAMES[level], exact, seeds])
	return {"ok": ok, "par_median": _median_i(pars), "total_s": total}


func _spread(a: PackedInt32Array) -> String:
	var d := {}
	for v in a:
		d[v] = d.get(v, 0) + 1
	var keys := d.keys()
	keys.sort()
	return " ".join(keys.map(func(k: int) -> String: return "%d:%d" % [k, d[k]]))


func _median_i(a: PackedInt32Array) -> int:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _max_i(a: PackedInt32Array) -> int:
	return Array(a).max()


func _median_f(a: PackedFloat64Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _max_f(a: PackedFloat64Array) -> float:
	return Array(a).max()
