extends RefCounted
## Vectors from an independent Python oracle (rules of design 2 only): hand cases and random boards with the
## expected resolved board, ignored moves and wave counts. Regenerate only from the oracle, never from SumBoard.

const FILE := "res://tests/data/oracle_vectors.json"

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	_check.call(parsed is Array and parsed.size() > 500, "oracle vector file loads with more than 500 cases")
	if not parsed is Array:
		return
	var bad_result := 0
	var bad_ignore := 0
	var bad_traced := 0
	var bad_waves := 0
	var played := 0
	var multi := 0
	for c: Dictionary in parsed:
		var rows: Array = c.rows
		var b := SumBoard.create(str(rows[0]).length(), rows.size())
		b.start = b.from_rows(PackedStringArray(rows))
		var d: int = SumBoard.DIR_LETTERS.find(str(c.d))
		var m := (int(c.y) * b.w + int(c.x)) * 4 + d
		var canon := b.canonical(b.start, m)
		var applied: Variant = b.apply(b.start, m)
		if c.res == null:
			if canon >= 0 or applied != null:
				bad_ignore += 1
			continue
		played += 1
		if canon < 0 or applied == null:
			bad_ignore += 1
			continue
		var want := "\n".join(PackedStringArray(c.res))
		if b.render(applied) != want or b.render(b.step_reference(b.start, canon)) != want:
			bad_result += 1
		var tr := b.step_traced(b.start, canon)
		if b.render(tr.state) != want:
			bad_traced += 1
		var waves := 0
		for st: Dictionary in tr.steps:
			waves += 1 if st.kind == "vanish" else 0
		if waves != int(c.waves):
			bad_waves += 1
		multi += 1 if waves > 1 else 0
	_check.call(played > 200, "oracle vectors: more than 200 played moves")
	_check.call(multi > 20, "oracle vectors: more than 20 chains")
	_check.call(bad_ignore == 0, "oracle vectors: ignored and legal moves agree")
	_check.call(bad_result == 0, "oracle vectors: step and step_reference give the oracle board")
	_check.call(bad_traced == 0, "oracle vectors: step_traced gives the oracle board")
	_check.call(bad_waves == 0, "oracle vectors: number of vanish steps equals the oracle's waves")
