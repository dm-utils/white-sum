# White Sum

A daily puzzle game in the White series. Tiles numbered 1 to 5 sit on a board under gravity. Swap two neighbouring
tiles or slide one sideways; a row or column of touching tiles that adds up to exactly 10 vanishes. Clear the board in
as few moves as possible.

Status: phase 1 built (rules, solver, generator, tools, a pool of 40 practice sets in three levels, the screen and the
web version). Selecting a tile shows the sums of its row and column. No daily puzzle yet.

- Play version: https://play.whitesum.steefbeest.nl
- Design: `docs/design.md`, decisions in `docs/adr/`, terms in `docs/glossary.md`, rules for code and data in
  `docs/conventions.md`.

## Development

Godot 4.7.2. The shared base White Kit is a git submodule at `addons/white_kit`; clone with submodules:

```bash
git clone --recurse-submodules https://github.com/dm-utils/white-sum.git
# or, after a plain clone:
git submodule update --init
```

Run the tests headless:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/run_tests.tscn
```

Debug screenshots (needs `xvfb`; scenarios in `tools/shots.txt`):

```bash
addons/white_kit/tools/shots.sh run . tools/shots.txt build/shots
```

Measure the generator and build puzzles (see `docs/conventions.md`):

```bash
godot --headless --path . -s res://tools/measure.gd -- --seeds=50 --level=1 --skip-m1
godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=5 --start=0 --out=build/practice_0.json
godot --headless --path . -s res://tools/verify_puzzles.gd -- --file=data/practice.json
```

All rights reserved.
