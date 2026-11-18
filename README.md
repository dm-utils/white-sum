# White Sum

A daily puzzle game in the White series. Tiles numbered 1 to 5 sit on a board under gravity. Swap two neighbouring
tiles or slide one sideways; a row or column of touching tiles that adds up to exactly 10 vanishes. Clear the board in
as few moves as possible.

Status: phase 1 (look and feel) designed. Practice puzzles in three levels; no daily puzzle yet.

- Play version (from phase 1b): https://play.whitesum.steefbeest.nl
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

All rights reserved.
