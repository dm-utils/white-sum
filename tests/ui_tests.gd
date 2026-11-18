extends RefCounted
## UI logic that needs no screen: layout, gestures, keys, animation phases, the view's state handling, the run totals
## of the selected tile, texts and the main screen in practice mode (design 10, 13.1 UI).

const VANISH_TOTAL := 0.18 + 0.06 ## kit vanish_time + vanish_pause

var _check: Callable
var _node: Node
var _moves: Array = []
var _made: Array = []


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_layout()
	_gestures()
	_phases()
	_view_steps()
	_view_moves()
	_view_ignored()
	_example_moves()
	_tap_tap()
	_keyboard()
	_pointer()
	_run_marks()
	_selection()
	_texts()
	_safe_area()
	await _screen()
	for v in _made:
		v.free()


func _mk(rows: Array) -> SumBoard:
	return preload("res://tests/rules_tests.gd").mk(rows)


func _view(rows: Array) -> Array:
	var b := _mk(rows)
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var v := SumBoardView.new()
	v.size = Vector2(720, 720)
	v.show_attempt(a)
	_moves = []
	_made.append(v)
	v.move_chosen.connect(func(c: int) -> void: _moves.append(c))
	return [v, a, b]


func _drain(v: SumBoardView) -> int:
	var frames := 0
	while v.busy() and frames < 400:
		v._process(0.05)
		frames += 1
	return frames


func _layout() -> void:
	var lay := WhiteTileView.layout(Vector2(660, 800), 6, 7, 0.3)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	_check.call(cell == floorf(cell) and cell * 6 <= 660 and cell * 7 <= 800,
			"layout: whole-pixel cells that fit the area")
	_check.call(is_equal_approx(o.x, (660 - 6 * cell) / 2.0) and is_equal_approx(o.y, (800 - 7 * cell) / 2.0),
			"layout: board centred")
	var a1 := SumBoardView.cell_at(o + Vector2(cell * 0.5, cell * 6.5), lay, 6, 7)
	var top_right := SumBoardView.cell_at(o + Vector2(cell * 5.5, cell * 0.5), lay, 6, 7)
	_check.call(a1 == 0, "cell_at: bottom-left on screen is A1 (index 0)")
	_check.call(top_right == 6 * 7 - 1, "cell_at: top-right on screen is the last cell (y counts upwards)")
	_check.call(SumBoardView.cell_at(o - Vector2(1, 1), lay, 6, 7) == -1, "cell_at: outside the board is -1")
	var tall := WhiteTileView.layout(Vector2(300, 1000), 5, 6, 0.3)
	_check.call(tall.cell * 5 <= 300, "layout: the narrow side decides")


func _gestures() -> void:
	_check.call(SumBoardView.drag_dir(Vector2(30, 5)) == SumBoard.Dir.R, "drag right is R")
	_check.call(SumBoardView.drag_dir(Vector2(5, 30)) == SumBoard.Dir.D, "drag down on screen is D")
	_check.call(SumBoardView.drag_dir(Vector2(5, -30)) == SumBoard.Dir.U, "drag up on screen is U")
	_check.call(SumBoardView.neighbour_dir(5, 9, 4) == SumBoard.Dir.U, "neighbour above (index + w)")
	_check.call(SumBoardView.neighbour_dir(5, 10, 4) == -1, "diagonal is no neighbour")
	_check.call(SumBoardView.neighbour_dir(3, 4, 4) == -1, "end of row and start of next row are no neighbours")
	_check.call(SumBoardView.key_dir(KEY_W) == SumBoard.Dir.U and SumBoardView.key_dir(KEY_DOWN) == SumBoard.Dir.D,
			"keys: WASD and arrows")
	_check.call(SumBoardView.step_cell(0, SumBoard.Dir.L, 4, 3) == 0, "cursor stops at the edge")
	_check.call(SumBoardView.step_cell(5, SumBoard.Dir.U, 4, 3) == 9, "cursor up adds a row")


func _kinds(phases: Array) -> Array:
	var out := []
	for p in phases:
		out.append(p.kind)
	return out


func _ids(b: SumBoard) -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(b.w * b.h)
	for i in ids.size():
		ids[i] = i if b.start[i] != 0 else -1
	return ids


func _phases() -> void:
	# example 3: slide, wave 1, fall, wave 2
	var b := _mk(["....5", "33452"])
	var tr := b.step_traced(b.start, b.decode_move("LE2"))
	var built := WhiteTileView.build_phases(5, _ids(b), SumBoardView.to_view_steps(tr.steps), VANISH_TOTAL)
	var kinds := _kinds(built.phases)
	_check.call(kinds.count("vanish") == 2 and kinds[0] == "move" and kinds[kinds.size() - 1] == "vanish",
			"chain (example 3): slide, then two waves of vanishing one after another")
	var ok := true
	for i in b.w * b.h:
		var id: int = built.ids[i]
		ok = ok and ((id >= 0) == (tr.state[i] != 0))
		ok = ok and (id < 0 or b.start[id] == tr.state[i])
	_check.call(ok, "phase ids end on the cells and values of the resolved state")
	_check.call(built.phases[0].dur == SumBoardView.SLIDE_TIME, "slide lasts 100 ms")
	_check.call(is_equal_approx(built.phases[1].dur, VANISH_TOTAL), "vanish is a fade plus a short pause")
	# example 2: cross, one vanish of four tiles at once
	var b2 := _mk(["23.5", "4153"])
	var tr2 := b2.step_traced(b2.start, b2.decode_move("LD2"))
	var steps2 := SumBoardView.to_view_steps(tr2.steps)
	var vanish_cells := 0
	for s in steps2:
		if s.kind == "vanish":
			vanish_cells += s.cells.size()
	_check.call(vanish_cells == 4, "cross (example 2): the row ten and the column ten vanish together")
	var built2 := WhiteTileView.build_phases(4, _ids(b2), steps2, VANISH_TOTAL)
	_check.call(_kinds(built2.phases).count("vanish") == 1, "cross: a single vanish phase")


func _view_steps() -> void:
	var b := _mk([".2..", "2433"])
	var steps := SumBoardView.to_view_steps(b.step_traced(b.start, b.decode_move("UB1")).steps)
	_check.call(steps[0].kind == "move" and steps[0].moves == [[1, 5], [5, 1]]
			and steps[0].time == SumBoardView.SWAP_TIME and steps[0].ease,
			"to_view_steps: a swap is an eased move of 120 ms in both directions")
	_check.call(steps[1].kind == "vanish" and steps[1].cells == PackedInt32Array([0, 1, 2, 3]),
			"to_view_steps: the swap of example 1 is followed by the vanish of row 1")
	var b2 := _mk(["2..", "3.."])
	var s2 := SumBoardView.to_view_steps(b2.step_traced(b2.start, b2.decode_move("RA2")).steps)
	_check.call(s2.size() == 2 and s2[0].kind == "move" and s2[0].time == SumBoardView.SLIDE_TIME and s2[0].ease,
			"to_view_steps: a slide is an eased move of 100 ms")
	_check.call(s2[1].kind == "move" and s2[1].speed == SumBoardView.FALL_SPEED and not s2[1].has("ease"),
			"to_view_steps: a fall moves at constant speed")


func _view_moves() -> void:
	var r := _view(["....5", "33452"])
	var v: SumBoardView = r[0]
	var a: WhiteAttempt = r[1]
	var b: SumBoard = r[2]
	var done := [0]
	v.finished.connect(func() -> void: done[0] += 1)
	a.play(b.decode_move("LE2"))
	v.update_attempt(a)
	_check.call(v.busy(), "a move starts an animation")
	_check.call(v.state() == a.state, "the view's logical state is the attempt's state at once")
	_check.call(_drain(v) > 3, "the chain takes several frames")
	_check.call(not v.busy() and done[0] == 1, "the animation ends once and signals it")
	# undo and restart show the state at once
	a.undo()
	v.update_attempt(a)
	_check.call(not v.busy() and v.state() == a.state and v.state() == b.start, "undo shows the start at once")
	a.play(b.decode_move("LE2"))
	v.update_attempt(a)
	a.restart()
	v.update_attempt(a)
	_check.call(not v.busy() and v.state() == b.start, "restart during an animation shows the start at once")
	# a move during an animation jumps the running one to its end
	var pool_board: SumBoard = SumGame.store().practice_set(0)[1].board
	var r2 := _view(Array(pool_board.render(pool_board.start).split("\n")))
	var v2: SumBoardView = r2[0]
	var a2: WhiteAttempt = r2[1]
	var b2: SumBoard = r2[2]
	a2.play(b2.legal_moves(a2.state)[0])
	v2.update_attempt(a2)
	a2.play(b2.legal_moves(a2.state)[0])
	v2.update_attempt(a2)
	_drain(v2)
	_check.call(v2.state() == a2.state, "two moves in a row end on the attempt's state")


func _view_ignored() -> void:
	var r := _view(["22", "32"])
	var v: SumBoardView = r[0]
	_check.call(v._cell_move(2, SumBoard.Dir.R) == -1, "swap of equal values is ignored")
	_check.call(v._shake_id >= 0, "an ignored move shakes the source tile")
	_check.call(v._cell_move(1, SumBoard.Dir.R) == -1, "move off the board is ignored")
	_check.call(v._cell_move(0, SumBoard.Dir.U) == 0 * 4 + SumBoard.Dir.U,
			"swap upwards from the lower cell stays as it is")
	_check.call(v._cell_move(2, SumBoard.Dir.D) == 0 * 4 + SumBoard.Dir.U,
			"swap downwards becomes U from the lower cell")
	var r2 := _view(["2.", "32"])
	var v2: SumBoardView = r2[0]
	_check.call(v2._cell_move(3, SumBoard.Dir.L) == -1 and v2._shake_id == -1,
			"move from an empty cell is ignored without a shake")
	_check.call(v2._cell_move(1, SumBoard.Dir.U) == -1, "lifting a tile into an empty cell is ignored")
	_check.call(v2._cell_move(2, SumBoard.Dir.R) == 2 * 4 + SumBoard.Dir.R, "slide into an empty cell is a move")
	_check.call(_moves.is_empty(), "_cell_move itself emits nothing")


## The moves of design examples 1-4 as the player makes them (swipe, tap-tap), in canonical form.
func _example_moves() -> void:
	var r1 := _view([".2..", "2433"])
	var v1: SumBoardView = r1[0]
	_check.call(v1._cell_move(5, SumBoard.Dir.D) == 1 * 4 + SumBoard.Dir.U, "example 1: B2 swiped down is U at B1")
	var r2 := _view(["23.5", "4153"])
	var v2: SumBoardView = r2[0]
	_check.call(v2._cell_move(7, SumBoard.Dir.L) == 7 * 4 + SumBoard.Dir.L, "example 2: D2 swiped left is a slide")
	var r3 := _view(["....5", "33452"])
	var v3: SumBoardView = r3[0]
	_check.call(v3._cell_move(9, SumBoard.Dir.L) == 9 * 4 + SumBoard.Dir.L, "example 3: E2 swiped left is a slide")
	var r4 := _view(["3432.", "11214"])
	var v4: SumBoardView = r4[0]
	v4._tap(8)
	v4._tap(9)
	_check.call(_moves == [8 * 4 + SumBoard.Dir.R], "example 4: tap D2 then the empty E2 slides right")
	var a: WhiteAttempt = r4[1]
	a.play(_moves[0])
	_check.call(a.record == "RD2", "the record from the UI holds the canonical token")
	var r1b := _view([".2..", "2433"])
	var v1b: SumBoardView = r1b[0]
	v1b._tap(5)
	v1b._tap(1)
	_check.call(_moves == [1 * 4 + SumBoard.Dir.U], "example 1: tap B2 then B1 gives U at B1")
	_moves.clear()
	v1b._tap(1)
	v1b._tap(5)
	_check.call(_moves == [1 * 4 + SumBoard.Dir.U], "example 1: tap B1 then B2 gives the same swap")


func _tap_tap() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: SumBoardView = r[0]
	var b: SumBoard = r[2]
	v._tap(5)
	_check.call(v.selected() == -1, "tap on an empty cell selects nothing")
	v._tap(3)
	_check.call(v.selected() == 3, "tap on a tile selects it")
	v._tap(3)
	_check.call(v.selected() == -1, "tap on the selected tile deselects")
	v._tap(3)
	v._tap(0)
	_check.call(_moves == [b.canonical(b.start, 3 * 4 + SumBoard.Dir.D)] and v.selected() == -1,
			"tap on a neighbour tile makes the swap and clears the selection")
	_moves.clear()
	v._tap(3)
	v._tap(2)
	_check.call(v.selected() == 2 and _moves.is_empty(), "tap on a far tile selects that one instead")
	v._tap(8)
	_check.call(v.selected() == -1, "tap on a far empty cell deselects")
	v._tap(4)
	v._tap(5)
	_check.call(_moves == [4 * 4 + SumBoard.Dir.R], "tap on an empty neighbour slides")


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _keyboard() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: SumBoardView = r[0]
	_check.call(v.key_move(_key(KEY_RIGHT)) == null, "first arrow only shows the cursor")
	v.key_move(_key(KEY_RIGHT))
	v.key_move(_key(KEY_UP))
	_check.call(v._cursor == 4, "arrows move the cursor (B2)")
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.selected() == 4, "space grabs the tile under the cursor")
	_check.call(v.key_move(_key(KEY_ESCAPE)) == null and v.selected() == -1, "escape releases the grab")
	v.key_move(_key(KEY_ENTER))
	var code: Variant = v.key_move(_key(KEY_LEFT))
	_check.call(code == 3 * 4 + SumBoard.Dir.R, "grab + left on B2 over A2 gives the canonical swap R at A2")
	_check.call(v.selected() == -1, "a move releases the grab")
	var r2 := _view(["2.", "2."])
	var v2: SumBoardView = r2[0]
	v2.key_move(_key(KEY_UP))
	v2.key_move(_key(KEY_SPACE))
	_check.call(v2.key_move(_key(KEY_UP)) == null, "grab + move off the board is ignored")
	_check.call(v2._shake_id >= 0 and v2.selected() == 0, "an ignored key move shakes and keeps the grab")


func _mouse(pressed: bool, p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	return e


func _motion(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	return e


func _pointer() -> void:
	var r := _view(["3..", "42.", "233"])
	var v: SumBoardView = r[0]
	var lay := WhiteTileView.layout(v.size, 3, 3, 0.3)
	var cell: float = lay.cell
	var o: Vector2 = lay.origin
	var a2 := o + Vector2(cell * 0.5, cell * 1.5)
	v._gui_input(_mouse(true, a2))
	v._gui_input(_motion(a2 + Vector2(cell * 0.2, 0)))
	_check.call(_moves.is_empty(), "a short drag does not fire yet")
	v._gui_input(_motion(a2 + Vector2(cell * 0.45, 3)))
	_check.call(_moves == [3 * 4 + SumBoard.Dir.R], "a drag of 40% of a cell fires the swipe (swap A2 right)")
	v._gui_input(_mouse(false, a2 + Vector2(cell * 0.9, 0)))
	_check.call(_moves.size() == 1, "one gesture fires only once")
	_moves.clear()
	v._gui_input(_mouse(true, a2))
	v._gui_input(_mouse(false, a2 + Vector2(2, 2)))
	_check.call(v.selected() == 3, "a press and release on one tile is a tap and selects it")
	v.input_enabled = false
	v._gui_input(_mouse(true, a2))
	v._gui_input(_motion(a2 + Vector2(cell, 0)))
	_check.call(_moves.size() == 0, "no input while the view is locked")


func _run_marks() -> void:
	# example 4 start: row 2 is A2..D2 (12), column A is 3 + 1
	var b := _mk(["3432.", "11214"])
	var m := SumBoardView.run_marks(b, b.start, 5)
	_check.call(m.row_total == 12 and m.col_total == 4, "run marks: totals of the row and the column through A2")
	_check.call(m.row == PackedInt32Array([5, 6, 7, 8]) and m.col == PackedInt32Array([0, 5]),
			"run marks: the cells of both runs")
	_check.call(m.row_anchor == Vector2(4, 1), "run marks: the row total sits in the empty cell after the run")
	_check.call(m.col_anchor == Vector2(0, 1.5), "run marks: a column to the top edge puts its total on the seam")
	var e := SumBoardView.run_marks(b, b.start, 4)
	_check.call(e.row_total == 9 and e.row_anchor == Vector2(4.5, 0),
			"run marks: a row over the full width puts its total on the right seam")
	_check.call(e.col_total == 4 and e.col_anchor == Vector2(4, 1),
			"run marks: the column total sits in the cell above the stack")
	_check.call(SumBoardView.run_marks(b, b.start, 9).is_empty(), "run marks: an empty cell has none")
	# a row that ends at the right edge but starts after the left edge: total goes to the left
	var b2 := _mk(["...", ".23", "145"])
	var m2 := SumBoardView.run_marks(b2, b2.start, 4)
	_check.call(m2.row_anchor == Vector2(0, 1), "run marks: a run at the right edge puts its total on its left")
	# every tile of the pool starts: totals agree with the board, anchors are empty cells or seams on the board
	var agree := true
	var anchors := true
	var store := SumGame.store()
	for i in range(0, store.practice_count(), 7):
		for p: Dictionary in store.practice_set(i):
			var pb: SumBoard = p.board
			for c in pb.w * pb.h:
				if pb.start[c] == 0:
					continue
				var marks := SumBoardView.run_marks(pb, pb.start, c)
				var t := pb.run_totals_at(pb.start, c)
				agree = agree and marks.row_total == t.x and marks.col_total == t.y
				for key in ["row_anchor", "col_anchor"]:
					var an: Vector2 = marks[key]
					anchors = anchors and an.x >= -0.5 and an.x <= pb.w - 0.5 and an.y >= -0.5 and an.y <= pb.h - 0.5
					if an == an.floor():
						anchors = anchors and pb.start[int(an.y) * pb.w + int(an.x)] == 0
	_check.call(agree, "run marks: totals equal run_totals_at on pool tiles")
	_check.call(anchors, "run marks: a total never covers a tile")


func _selection() -> void:
	var r := _view(["3432.", "11214"])
	var v: SumBoardView = r[0]
	_check.call(v.selection_marks().is_empty(), "no selection: no totals")
	v._tap(5)
	var m := v.selection_marks()
	_check.call(not m.is_empty() and m.row_total == 12 and m.col_total == 4,
			"tap-tap selection shows the totals of its row and column")
	v._tap(5)
	_check.call(v.selection_marks().is_empty(), "deselecting hides the totals")
	v.key_move(_key(KEY_UP))
	v.key_move(_key(KEY_SPACE))
	_check.call(v.selection_marks().is_empty() == (v.selected() < 0) and v.selected() == 0,
			"keyboard grab shows the totals too")
	v.key_move(_key(KEY_ESCAPE))
	_check.call(v.selection_marks().is_empty(), "releasing the grab hides the totals")
	# a move clears the selection and hides the totals while the animation runs
	var a: WhiteAttempt = r[1]
	v._tap(8)
	v._tap(9)
	a.play(_moves[0])
	v.update_attempt(a)
	_check.call(v.selected() == -1 and v.selection_marks().is_empty(), "a move clears the selection and the totals")
	_drain(v)
	# the totals follow the shown state, not the start
	var r2 := _view(["4...", "3433", "2423"])
	var v2: SumBoardView = r2[0]
	var a2: WhiteAttempt = r2[1]
	var b2: SumBoard = r2[2]
	a2.play(b2.legal_moves(a2.state)[0])
	v2.update_attempt(a2)
	_drain(v2)
	var cell := -1
	for i in v2.state().size():
		if v2.state()[i] != 0:
			cell = i
			break
	if cell >= 0:
		v2._tap(cell)
		var t := b2.run_totals_at(v2.state(), cell)
		_check.call(v2.selection_marks().row_total == t.x and v2.selection_marks().col_total == t.y,
				"totals describe the board as it is shown")


func _texts() -> void:
	var nl: Dictionary = SumStrings.TEXT.nl
	var en: Dictionary = SumStrings.TEXT.en
	_check.call(nl.keys() == en.keys(), "Dutch and English define the same keys")
	var present := true
	for key in ["count", "count_final", "solved", "perfect", "hint", "dead_end", "best_route", "share_line"]:
		present = present and nl.has(key)
	_check.call(present, "all keys of design 10.6 are present")
	var fmt_ok := true
	for lang in ["nl", "en"]:
		var t: Dictionary = SumStrings.TEXT[lang]
		fmt_ok = fmt_ok and str(t.count_final) % 3 != "" and str(t.solved) % [3, 2, "0:10"] != ""
	_check.call(fmt_ok, "format texts take their arguments")


func _safe_area() -> void:
	var i := WhiteSafeArea.from_rects(Rect2(0, 80, 1080, 2200), Vector2(1080, 2400), Vector2(720, 1280))
	_check.call(is_equal_approx(i.top, 80.0 * 1280.0 / 2400.0), "safe area: top inset in viewport units")
	_check.call(WhiteSafeArea.parse("40,20,30,10").right == 30.0, "safe area: debug override")


func _screen() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	await _node.get_tree().process_frame
	_check.call(m.practice and not m.mode_btn.visible, "the screen opens on a practice set without a mode button")
	_check.call(m.puzzles.size() == 3 and m.tabs.size() == 3, "three levels on the tabs")
	_check.call(m.counter.text == WhiteText.t("count_final") % 0 and m.par_label.text != "",
			"counter (final count) and par are shown")
	_check.call(m.message.text == WhiteText.t("hint"), "the hint shows before the first move")
	var p: Dictionary = m.puzzles[0]
	var first: int = p.path[0]
	m._on_move(first)
	var a: WhiteAttempt = m.attempts[0]
	_check.call(a.count() == 1 and m.counter.text == WhiteText.t("count_final") % 1, "a move raises the counter")
	m._on_undo()
	_check.call(a.count() == 0 and a.record.ends_with("z"), "undo lowers the counter and is recorded")
	var count := 0
	for code in p.path:
		m._on_move(code)
		count += 1
	_check.call(a.solved() and a.count() == int(p.par), "playing the stored path solves level 0 in par moves")
	m._on_debug_extra()
	_check.call(m.next_btn.visible and m.best_btn.visible and not m.undo_btn.visible,
			"solved: Next and Best route, no Undo")
	_check.call(m.message.text.contains(str(p.par)), "the solved message shows count and par")
	var tokens := a.record.replace("z", "")
	var canonical := true
	for k in range(0, tokens.length(), 3):
		canonical = canonical and tokens[k] in ["R", "L", "U"]
	_check.call(canonical, "records written from the UI hold only canonical tokens")
	m._next()
	_check.call(m.level == 1 and not m.attempts[1].solved(), "Next goes to the next level")
	m.level = 2
	m._show_level()
	var before: int = m.practice_index
	m._next()
	_check.call(m.practice_index == before + 1 and m.level == 0, "Next after hard goes to the next set, easy")
	m._on_restart()
	_check.call(m.attempts[0].count() == 0, "restart sets the counter to 0")
	# dead end notice on example 6, only after a move was made, gone after undo
	var dead := _mk(["......", "222222"])
	var da := WhiteAttempt.new(dead, WhiteAttempt.CountMode.FINAL_ONLY)
	m.view.show_attempt(da)
	_check.call(m._play_message(da) == "", "no dead-end notice before a move")
	da.moves_made = 1
	_check.call(m._play_message(da) == WhiteText.t("dead_end"), "dead-end notice on a board without a move (example 6)")
	var wide: Dictionary = m._insets_for(Vector2(2276, 1280))
	_check.call(wide.left == 778 and wide.right == 778 and wide.top == 24,
			"wide screen: the column is at most 720 px, centred")
	_check.call(m._insets_for(Vector2(720, 1280)).left == 24, "phone width: normal margins")
	WhiteText.lang = "en"
	m._refresh()
	_check.call(m.undo_btn.text == WhiteText.t("undo") and m.best_btn.text == "Best route",
			"English texts on the screen")
	WhiteText.lang = "nl"
	m._refresh()
	_check.call(m.best_btn.text == "Beste route", "Dutch texts on the screen")
	m.queue_free()
