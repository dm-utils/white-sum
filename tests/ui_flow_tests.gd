extends RefCounted
## Independent UI checks: pill geometry on pool and played boards, input thresholds, screen flows (selection,
## undo, restart, Next, tabs), keyboard through the screen, texts in both languages, content width and safe area.

const TILE := 0.84 ## tile side in cells (1 - tile_gap)

var _check: Callable
var _node: Node
var _made: Array = []
var _moves: Array = []


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_pill_geometry()
	_swipe_thresholds()
	await _screen_flows()
	_content_width()
	for v in _made:
		v.free()


func _mk(rows: Array) -> SumBoard:
	return preload("res://tests/rules_tests.gd").mk(rows)


func _view(rows: Array) -> SumBoardView:
	var b := _mk(rows)
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var v := SumBoardView.new()
	v.size = Vector2(720, 720)
	v.show_attempt(a)
	_moves = []
	_made.append(v)
	v.move_chosen.connect(func(c: int) -> void: _moves.append(c))
	return v


func _pill_rect(anchor: Vector2) -> Rect2:
	var s := Vector2(SumBoardView.TOTAL_W, SumBoardView.TOTAL_H)
	return Rect2(anchor + Vector2(0.5, 0.5) - s / 2.0, s)


func _tile_rects(b: SumBoard, s: PackedByteArray) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in s.size():
		if s[i] != 0:
			out.append(Rect2(Vector2(i % b.w + 0.5 - TILE / 2.0, i / b.w + 0.5 - TILE / 2.0), Vector2(TILE, TILE)))
	return out


## Boards to probe: pool starts and states a few random legal moves later.
func _probe_states() -> Array:
	var out: Array = []
	var rng := WhiteRng.new(99)
	var store := SumGame.store()
	for i in store.practice_count():
		for p: Dictionary in store.practice_set(i):
			var b: SumBoard = p.board
			var s: PackedByteArray = b.start
			out.append([b, s])
			for k in 3:
				var moves := b.legal_moves(s)
				if moves.is_empty():
					break
				s = b.step(s, moves[rng.range_int(0, moves.size() - 1)])
				if b.is_solved(s):
					break
				out.append([b, s])
	return out


func _pill_geometry() -> void:
	var inside_overlap := 0
	var pills_collide := 0
	var wrong_total := 0
	var seam_overlap := 0
	var seam_total := 0
	var off_board := 0
	for pair in _probe_states():
		var b: SumBoard = pair[0]
		var s: PackedByteArray = pair[1]
		var tiles := _tile_rects(b, s)
		var board := Rect2(Vector2.ZERO, Vector2(b.w, b.h))
		for c in b.w * b.h:
			if s[c] == 0:
				continue
			var m := SumBoardView.run_marks(b, s, c)
			var t := b.run_totals_at(s, c)
			wrong_total += 0 if m.row_total == t.x and m.col_total == t.y else 1
			var rr := _pill_rect(m.row_anchor)
			var cr := _pill_rect(m.col_anchor)
			pills_collide += 1 if rr.intersects(cr) else 0
			for key in ["row_anchor", "col_anchor"]:
				var an: Vector2 = m[key]
				var r := _pill_rect(an)
				var on_seam := an != an.floor()
				var hit := false
				for tr in tiles:
					hit = hit or r.intersects(tr)
				if on_seam:
					seam_total += 1
					seam_overlap += 1 if hit else 0
				else:
					inside_overlap += 1 if hit else 0
					off_board += 0 if board.encloses(r) else 1
	_check.call(wrong_total == 0, "pill totals equal the oracle sums on pool and played boards")
	_check.call(inside_overlap == 0, "a pill in an empty cell never overlaps a tile (pool and played boards)")
	_check.call(off_board == 0, "a pill in an empty cell lies inside the board")
	_check.call(pills_collide == 0, "the row pill and the column pill never overlap")
	_check.call(seam_total > 0, "seam pills occur on probed boards (%d, %d overlap a tile)" % [seam_total, seam_overlap])


func _swipe_thresholds() -> void:
	var v := _view(["3..", "42.", "233"])
	var lay := WhiteTileView.layout(v.size, 3, 3, 0.3)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	var a2 := o + Vector2(cell * 0.5, cell * 1.5)
	var ev := func(pressed: bool, p: Vector2) -> InputEventMouseButton:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		return e
	var mo := func(p: Vector2) -> InputEventMouseMotion:
		var e := InputEventMouseMotion.new()
		e.position = p
		return e
	v._gui_input(ev.call(true, a2))
	v._gui_input(mo.call(a2 + Vector2(cell * 0.39, 0)))
	_check.call(_moves.is_empty(), "swipe: 39% of a cell does not fire")
	v._gui_input(mo.call(a2 + Vector2(cell * 0.41, 0)))
	_check.call(_moves.size() == 1, "swipe: 41% of a cell fires")
	v._gui_input(ev.call(false, a2))
	# vertical swipe up on A2 swaps with A3 (canonical U at A2); down swaps with A1 (U at A1)
	_moves.clear()
	v._gui_input(ev.call(true, a2))
	v._gui_input(mo.call(a2 + Vector2(2, -cell * 0.5)))
	_check.call(_moves == [3 * 4 + SumBoard.Dir.U], "swipe up on A2 is the canonical swap U at A2")
	v._gui_input(ev.call(false, a2))
	_moves.clear()
	v._gui_input(ev.call(true, a2))
	v._gui_input(mo.call(a2 + Vector2(2, cell * 0.5)))
	_check.call(_moves == [0 * 4 + SumBoard.Dir.U], "swipe down on A2 is the canonical swap U at A1")
	v._gui_input(ev.call(false, a2))
	# release after a short drag: 24 px or more is a swipe, less is a tap
	_moves.clear()
	v._gui_input(ev.call(true, a2))
	v._gui_input(ev.call(false, a2 + Vector2(26, 0)))
	_check.call(_moves.size() == 1 and v.selected() == -1, "release after a drag of 26 px is a swipe, not a tap")
	_moves.clear()
	v._gui_input(ev.call(true, a2))
	v._gui_input(ev.call(false, a2 + Vector2(10, 0)))
	_check.call(_moves.is_empty() and v.selected() == 3, "release after a drag of 10 px is a tap")
	v._tap(3)
	# press on an empty cell and drag: nothing, no shake
	var empty_cell := o + Vector2(cell * 2.5, cell * 0.5)
	v._shake_id = -1
	v._gui_input(ev.call(true, empty_cell))
	v._gui_input(mo.call(empty_cell + Vector2(cell, 0)))
	v._gui_input(ev.call(false, empty_cell + Vector2(cell, 0)))
	_check.call(_moves.is_empty() and v._shake_id == -1, "dragging from an empty cell does nothing")
	# press outside the board
	v._gui_input(ev.call(true, Vector2(1, 1)))
	v._gui_input(mo.call(Vector2(200, 1)))
	v._gui_input(ev.call(false, Vector2(200, 1)))
	_check.call(_moves.is_empty(), "dragging from outside the board does nothing")
	# swipe of an equal pair is ignored and shakes
	var eq := _view(["22"])
	var elay := WhiteTileView.layout(eq.size, 2, 1, 0.3)
	var ecell: float = elay.cell
	var p0: Vector2 = elay.origin + Vector2(ecell * 0.5, ecell * 0.5)
	eq._gui_input(ev.call(true, p0))
	eq._gui_input(mo.call(p0 + Vector2(ecell * 0.5, 0)))
	_check.call(_moves.is_empty() and eq._shake_id >= 0, "swipe onto an equal tile is ignored and shakes")


func _first_tile(s: PackedByteArray) -> int:
	for i in s.size():
		if s[i] != 0:
			return i
	return -1


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _screen_flows() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	await _node.get_tree().process_frame
	var v: SumBoardView = m.view
	# selection goes away on tab switch, undo, restart and Next
	v._tap(_first_tile(m.attempts[0].state))
	_check.call(v.selected() >= 0, "flow: a tap selects a tile")
	m._pick_level(1)
	_check.call(v.selected() == -1 and v.selection_marks().is_empty(), "flow: switching level clears the selection")
	var p: Dictionary = m.puzzles[1]
	m._on_move(p.path[0])
	v._process(5.0)
	v._tap(_first_tile(v.shown()))
	m._on_undo()
	_check.call(v.selected() == -1 and v.selection_marks().is_empty(), "flow: undo clears the selection")
	m._on_move(p.path[0])
	v._process(5.0)
	v._tap(_first_tile(v.shown()))
	m._on_restart()
	_check.call(v.selected() == -1 and m.attempts[1].count() == 0, "flow: restart clears the selection, count 0")
	v._tap(_first_tile(v.shown()))
	m._next()
	_check.call(v.selected() == -1 and m.level == 2, "flow: Next clears the selection")
	# ignored action: no count, no record, no undo step
	m._pick_level(0)
	var a: WhiteAttempt = m.attempts[0]
	var b: SumBoard = a.rules
	var ignored := -1
	for i in b.start.size():
		if b.start[i] == 0 and b.canonical(a.state, i * 4) < 0:
			ignored = i * 4
			break
	var before_rec := a.record
	m._on_move(ignored)
	_check.call(a.count() == 0 and a.record == before_rec and a.history.is_empty(),
			"flow: an ignored move changes neither count, record nor history")
	# counter text, undo/restart, level isolation
	m._on_move(m.puzzles[0].path[0])
	_check.call(m.counter.text == WhiteText.t("count_final") % 1, "flow: counter after one move")
	m._pick_level(1)
	_check.call(m.counter.text == WhiteText.t("count_final") % 0, "flow: another level has its own count")
	m._pick_level(0)
	_check.call(m.counter.text == WhiteText.t("count_final") % 1, "flow: back on level 0 the move is kept")
	m._on_undo()
	m._on_undo()
	_check.call(m.counter.text == WhiteText.t("count_final") % 0 and not a.record.ends_with("zz"),
			"flow: undo without history changes nothing (no extra z)")
	# keyboard through the screen: z undo, r restart, WASD grab and move
	m._on_move(m.puzzles[0].path[0])
	v._process(5.0)
	m._unhandled_input(_key(KEY_Z))
	_check.call(a.count() == 0, "flow: key Z undoes")
	m._on_move(m.puzzles[0].path[0])
	v._process(5.0)
	m._unhandled_input(_key(KEY_R))
	_check.call(a.count() == 0, "flow: key R restarts")
	m._unhandled_input(_key(KEY_BACKSPACE))
	_check.call(a.count() == 0, "flow: Backspace with nothing to undo is harmless")
	# solved: Best route and Next, then a move does nothing, undo is hidden
	for code in m.puzzles[0].path:
		m._on_move(code)
		v._process(5.0)
	_check.call(a.solved() and m.best_btn.visible and m.next_btn.visible, "flow: solved shows Best route and Next")
	var rec := a.record
	m._on_move(m.puzzles[0].path[0])
	_check.call(a.record == rec, "flow: no move after solving")
	m._show_best()
	_check.call(m._replaying and not v.input_enabled, "flow: Best route locks input while it runs")
	m._on_move(m.puzzles[0].path[0])
	m._on_undo()
	_check.call(a.record == rec, "flow: no move or undo during Best route")
	m._replaying = false
	v.input_enabled = true
	# dead end appears after a move and goes after undo: example 6 style board via the attempt
	var dead := _mk(["2.....", "222222"])
	var da := WhiteAttempt.new(dead, WhiteAttempt.CountMode.FINAL_ONLY)
	m.view.show_attempt(da)
	_check.call(dead.is_dead_end(da.state) == false, "flow: a board with a legal move is no dead end")
	var dead2 := _mk(["......", "222222"])
	_check.call(dead2.is_dead_end(dead2.start), "flow: all-equal row is a dead end")
	# languages
	for lang in ["en", "nl"]:
		WhiteText.lang = lang
		m._refresh()
		var t: Dictionary = SumStrings.TEXT[lang]
		_check.call(m.best_btn.text == t.best_route, "flow: %s Best route label" % lang)
		_check.call(m.counter.text == str(t.count_final) % a.count(), "flow: %s counter text" % lang)
		_check.call(m.message.text.contains(str(m.puzzles[0].par)), "flow: %s solved message holds par" % lang)
	m._toggle_lang()
	m._toggle_lang()
	m.queue_free()
	await _node.get_tree().process_frame


func _content_width() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_made.append(m)
	var ok_max := true
	var ok_sym := true
	var ok_phone := true
	for sz in [Vector2(360, 640), Vector2(720, 1280), Vector2(800, 600), Vector2(1280, 720), Vector2(1900, 1000),
			Vector2(2276, 1280), Vector2(5000, 1280)]:
		var ins: Dictionary = m._insets_for(sz)
		var content: float = sz.x - ins.left - ins.right
		ok_max = ok_max and content <= 720.0
		ok_sym = ok_sym and ins.left == ins.right
		if sz.x <= 744:
			ok_phone = ok_phone and ins.left == WhiteTheme.MARGIN and content == sz.x - 2.0 * WhiteTheme.MARGIN
	_check.call(ok_max, "content width never above 720 (360 to 5000 wide)")
	_check.call(ok_sym, "content column is centred")
	_check.call(ok_phone, "phone widths fill the width minus the margins")
