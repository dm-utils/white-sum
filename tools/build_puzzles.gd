extends WhitePrecompute
## Precomputes puzzles so a phone never has to search.
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 [--start=0] --out=build/practice.json
## Practice seed: "white-sum-practice|<i>|<level>". Output {"<i>": [easy, medium, hard]}, puzzle format design 6.3.


func _game_id() -> String:
	return SumGame.GAME_ID


func _generate(seed_value: int, level: int) -> Dictionary:
	return SumGenerator.to_json(SumGenerator.generate(seed_value, level))


func _summary(puzzles: Array) -> String:
	var par := []
	var exact := []
	var upper := []
	var fb := false
	for p in puzzles:
		par.append(p.par)
		exact.append(p.exact)
		upper.append(p.upper)
		fb = fb or p.has("fallback")
	return " par %s exact %s upper %s%s" % [par, exact, upper, " FALLBACK" if fb else ""]
