# White Sum - design

Status: phase 1a built (rules, solver, generator, tools, pool; trial in 5.9); phase 1b built (screen, board view, play
version; deviations in 14.3). Later phases are designed in outline and marked **[later]**; they are not built in phase 1.
This document describes the game as it must be built. Decisions with their trade-offs are in `docs/adr/`; terms are
defined in `docs/glossary.md`; code and test rules are in `docs/conventions.md`.

White Sum is built on the shared base White Kit (`dm-utils/white-kit`, installed as a git submodule at
`res://addons/white_kit/`, design in that repository's `docs/design.md`). Phase 1a pins kit `v0.2.0`; phase 1b pins
`v0.3.0`, which adds the tile view base class, the safe area, the maximum content width and the screenshot tools
(kit design section 14). Its rules engine, solver and generator start as a copy of White Tally's `sim/` and are
adapted (ADR 0006). Section 7 lists exactly what White Sum uses from the kit.

## 1. Purpose and phases

White Sum is a puzzle game for players aged 10 and up and adults, intended to become a daily puzzle. The board holds
tiles numbered 1 to 5 under gravity. A row segment or a column of touching tiles vanishes only when its numbers add up
to exactly 10. The player clears the board in as few moves as possible. No new tiles ever appear.

### 1.1 Phase 1: look and feel

Phase 1 tests how the game looks and feels. It answers:

1. Can a new player apply the ten rule (touching tiles in a row or a column, total exactly 10) after a 30-second
   explanation?
2. Does adding up stay pleasant, or does it feel like homework? Is reading a run's total quick enough on a phone?
3. Are there "aha" moments: opening a gap to split an over row, a drop that completes a column, a cross where a row and
   a column vanish together, a chain?
4. Are tiles, numerals, swaps, slides, falls, vanishing and chains easy to read and pleasant to watch, on a phone and on
   a PC?

In scope:

- Playable puzzles in three levels (easy, medium, hard) from a precomputed pool of 40 sets (6.3), not tied to dates.
- Free choice: level tabs, Next (next level, after hard the next set), Undo, Restart.
- Controls for touch, mouse and keyboard (10.4).
- Animations of swap, slide, fall, vanish and chain (10.2).
- Readability of numerals and runs (10.1); a calm, flat, dark look in the series style.
- Run totals of the selected tile (10.1): when a tile is selected (tap-tap or keyboard grab) the screen shows the sum of
  the touching row run and column run through it. Decision of the owner, 2026-11-18; the first version of this design
  left run totals out of phase 1.
- Moves and par shown simply (3.1, `FINAL_ONLY`); no strict scoring.
- Dutch and English.
- Web version on GitHub Pages at https://play.white-sum.steefbeest.nl, usable in portrait on a phone and on a desktop
  (maximum content width, kit 0.3.0).
- The rules engine, generator and solver needed to fill the pool (section 5), with a trial (5.7).

Out of scope for phase 1 (designed below where marked **[later]**): binding puzzles to dates, the first day and puzzle
numbers, the share line, daily counting (every move counts), saved daily progress, the full trial with strict gates,
accounts, leaderboards, a server, art, sound, Android/Windows builds, a puzzle archive, run totals other than those of
the selected tile (for example for every run at once, or while dragging).

### 1.2 Later phases

See section 12. Phase 2 turns the pool into a daily puzzle: three puzzles per Dutch calendar day, identical for
everyone, with puzzle numbers, a share line and `EVERY_MOVE` counting. The design already allows it: the kit's
`_count_mode(is_practice)` gives `EVERY_MOVE` for the day and `FINAL_ONLY` for practice, with one record format.

## 2. Rules

### 2.1 Board and coordinates

- A rectangular board of `w x h` cells, side view, gravity pulls down. `w` is 2 to 8, `h` is 2 to 9 (generated
  boards are larger; small sizes occur in tests and examples).
- Coordinates as White Tally: `x` grows to the right (`0 .. w-1`), `y` grows **upwards** (`0 .. h-1`), `(0, 0)` is the
  bottom-left cell. Cell index `i = y * w + x`.
- Cell names: column letter `A, B, C, ...` for `x = 0, 1, 2, ...` and row digit `1, 2, 3, ...` for
  `y = 0, 1, 2, ...`. `A1` is the bottom-left cell. Upper case only (kit record grammar).
- Each cell is empty or holds one tile.

### 2.2 Tiles

- A tile has a value from 1 to 5. Tiles never change value and are never created.
- Two cells are neighbours when they share an edge (left, right, above, below). Diagonals are not neighbours.
- The target total is `TARGET = 10` (`SumBoard.TARGET`, a constant; ADR 0002).

### 2.3 Runs and tens

- A **row run** is a maximal set of horizontally consecutive non-empty cells in one row: it ends at an empty cell or at
  the board edge on both sides. A single tile with empty cells (or edges) left and right is a row run of length 1.
- A **column run** is a maximal set of vertically consecutive non-empty cells in one column. On a settled board (2.5)
  every column holds one stack from the floor up, so its column run is the whole stack.
- Every tile belongs to exactly one row run and exactly one column run.
- The **total** of a run is the sum of its values.
- A run is a **ten** when its total is exactly `TARGET` (10). A run with a larger total is **over**; a smaller total is
  **short**. Over and short runs never vanish, and neither does any part of them.
- A run of length 1 is never a ten (the largest value is 5).

### 2.4 Moves

Exactly White Tally's move set (ADR 0003). A move is given by a source cell `(x, y)` and a direction `d` in `R`, `L`,
`U`, `D`. The target cell is the neighbour in that direction. The first matching rule decides:

| Situation | Result |
|---|---|
| The source cell is empty | Not a move: ignored. |
| The target is outside the board | Not a move: ignored. |
| The target holds a tile with the **same** value | No-op: ignored. |
| The target holds a tile with a **different** value | **Swap**: the two tiles exchange cells. |
| The target is empty and `d` is `R` or `L` | **Slide**: the tile moves into the target cell (and then falls, 2.5). |
| The target is empty and `d` is `U` or `D` | Not a move: ignored. |

- Every swap of two different values is allowed, also one after which nothing vanishes. It counts as a move.
- A slide always changes the board, so it always counts.
- An ignored action is not counted, not recorded and creates no undo step (`WhiteRules.apply` returns `null`). The
  board view shakes the source tile.
- After the board is empty (solved), every action is ignored (kit attempt).

Canonical form (records, solver, generator), as White Tally:

| Move | Canonical source | Canonical direction |
|---|---|---|
| Horizontal swap | the left cell of the pair | `R` |
| Vertical swap | the lower cell of the pair | `U` |
| Slide | the moving tile | `R` or `L` |

`D` never occurs in canonical form, `L` is always a slide, `U` always a swap, `R` a swap or a slide. Player input is
converted to canonical form before it is played.

Effect of a swap on totals: a horizontal swap inside a row run keeps that run's total and changes the two column
totals; a vertical swap keeps the column total and changes the two row runs. A slide moves a tile to another column and
can open a gap in a row (splitting a row run) or close one (joining two).

### 2.5 Resolution: settle, vanish, chain

After a move the board is resolved:

1. **Settle.** Every tile falls straight down in its own column until it rests on the floor or on another tile.
2. **Find.** On the settled board, find all tens: every row run and every column run whose total is exactly 10.
3. If there are none, resolution ends.
4. **Vanish.** Remove the union of the cells of all tens found in step 2 at the same time. This is one **wave**. A tile
   that belongs to a row ten and a column ten (a **cross**) is removed once.
5. Go to step 1.

Notes:

- Runs are maximal, so the set of tens of a board is unique; there is no choice and no ordering question.
- A **chain** is a resolution with more than one wave: tiles that fell, or rows that were split or joined by the
  vanishing, form a new ten.
- Resolution always ends: every wave removes at least two tiles.
- A board after resolution is **stable**: settled and without tens. Every start position is stable.

### 2.6 Goal and invariants

- The puzzle is solved when the board is empty.
- Without crosses every wave removes a multiple of 10 from the board's total; a cross removes less (two tens sharing a
  tile of value `v` remove `20 - v`). The board total is therefore not an invariant, and there is no simple counting
  test for solvability. The generator guarantees solvability by construction (5.4).
- No tiles are ever added. Every puzzle is a closed problem with a best solution.

### 2.7 Examples

Examples are drawn with the top row first, row numbers on the left and column letters on top; `.` is empty.
`SumBoard.render()` produces the same rows without labels and spaces (for example `..5.`). Every example below is also
a regression test.

**Example 1 - a vertical swap completes a row.** Board `4 x 2`, move `UB1` (swap `B1` and `B2`).

```
start                 after the swap          after wave 1 and settling
   A B C D               A B C D                 A B C D
2  . 2 . .            2  . 4 . .              2  . . . .
1  2 4 3 3            1  2 2 3 3              1  . 4 . .
```

At the start row 1 totals 12 (over) and column `B` totals 6. The swap keeps column `B` at 6 but changes row 1 to
2 + 2 + 3 + 3 = 10: a ten. It vanishes; the 4 at `B2` falls to `B1`.

**Example 2 - a cross: a row and a column vanish together.** Board `4 x 2`, move `LD2` (slide `D2` left).

```
start                 after the slide         after wave 1
   A B C D               A B C D                 A B C D
2  2 3 . 5            2  2 3 5 .              2  . . . .
1  4 1 5 3            1  4 1 5 3              1  4 1 . 3
```

The 5 slides into the empty `C2` and rests on `C1`. Now row 2 is the run 2 + 3 + 5 = 10 and column `C` is the stack
5 + 5 = 10. Both are tens; their union (`A2`, `B2`, `C2`, `C1`) vanishes in one wave. Row 1 is then split by the gap
at `C1` into 4 + 1 = 5 and 3: no further ten.

**Example 3 - chain: a column ten opens a gap.** Board `5 x 2`, move `LE2` (slide `E2` left).

```
start               after the slide       wave 1, settle       wave 2, settle
   A B C D E           A B C D E            A B C D E            A B C D E
2  . . . . 5        2  . . . 5 .         2  . . . . .         2  . . . . .
1  3 3 4 5 2        1  3 3 4 5 2         1  3 3 4 . 2         1  . . . . 2
```

Row 1 totals 17 (over) at the start. The slide lands the 5 on `D1`: column `D` is 5 + 5 = 10 and vanishes. The gap at
`D1` splits row 1 into 3 + 3 + 4 = 10 and 2: wave 2 removes `A1`, `B1`, `C1`.

**Example 4 - an over row split by a slide.** Board `5 x 2`, move `RD2` (slide `D2` right).

```
start               after the slide       after wave 1
   A B C D E           A B C D E             A B C D E
2  3 4 3 2 .        2  3 4 3 . 2          2  . . . . 2
1  1 1 2 1 4        1  1 1 2 1 4          1  1 1 2 1 4
```

Row 2 totals 12 (over); nothing vanishes. Sliding the 2 out of the row leaves `D2` empty (it rests on `E1` at `E2`).
Row 2 now has the runs 3 + 4 + 3 = 10 and 2: the ten vanishes. Row 1 totals 9 and column `E` 6: no further ten.

**Example 5 - a complete puzzle (par 2).** Board `4 x 3`.

```
   A B C D
3  . . 5 .
2  . . 1 .
1  2 5 3 4
```

Solution `RC1 LD1`: the swap of `C1` and `D1` makes column `C` the stack 4 + 1 + 5 = 10 (row 1 totals 14, not a ten);
the column vanishes and leaves row 1 as 2 + 5, gap, 3. Sliding `D1` left lands the 3 on `C1`: row 1 is 2 + 5 + 3 = 10
and vanishes. No single move empties the board (every move was checked: at most one ten vanishes, never all tiles),
so par is 2. Section 5.4 shows how the generator builds this puzzle.

**Example 6 - no move left.** Board `6 x 2`.

```
   A B C D E F
2  . . . . . .
1  2 2 2 2 2 2
```

Row 1 totals 12 (over). Every swap is between equal values (no-op), no tile has an empty cell beside it, and `U` into
an empty cell is not a move. The board cannot change: a dead end (2.8).

### 2.8 Dead ends

As White Tally: a position is a **dead end** when the board is not empty and there is no move. The message line then
shows the dead-end text (10.5); undo and restart stay available. Positions that still have moves but can no longer be
cleared are not detected in phase 1.

### 2.9 How White Sum differs from White Tally

White Sum shares White Tally's board, gravity and moves on purpose (one control scheme for the series, a tested rules
core to copy). The puzzle is different:

| | White Tally | White Sum |
|---|---|---|
| What vanishes | a group of equal values whose size equals the value | a maximal row or column run whose numbers add up to 10 |
| Tiles | 2, 3, 4, colour-coded, gathered by kind | 1 to 5, mixed; different values work together |
| Shape | any connected shape | straight lines only (rows and columns) |
| Key skill | counting group sizes, keeping groups apart | adding up, opening and closing gaps, using column stacks |
| Typical "aha" | breaking an overfull group | splitting an over row with a gap; a cross of row and column |

## 3. Counting, undo, restart and par

### 3.1 Phase 1: simple counting

- Every puzzle is played as a kit practice attempt (`WhiteAttempt.CountMode.FINAL_ONLY`): the counter shows the moves
  from the start position to the current position; undo lowers it by one, restart sets it to 0. Par is shown next to
  it. When the board is empty the message line shows the count, par and the clock.
- Undo and restart are unlimited, possible only with history and before solving.
- Nothing is strict in phase 1: no score across puzzles, nothing shared, puzzles replayable at will.

### 3.2 [later] Daily counting

| Mode | Used for | Count (`count()`) |
|---|---|---|
| `EVERY_MOVE` | Daily puzzles | Every move made in the attempt, including undone and restarted ones. |
| `FINAL_ONLY` | Practice | Moves on the current line; when solved, the length of the final solution. |

The record (section 8) is the same in both modes. The screen hook `_count_mode(is_practice)` returns `FINAL_ONLY` when
`is_practice`, else `EVERY_MOVE`; in phase 1 every attempt is a practice attempt.

### 3.3 Par

- Par is the fewest moves found by the solver (5.5). `exact` true means proven minimal; `exact` false means a
  best-found upper bound (allowed in phase 1 for every level; ADR 0004).
- With bounded par a player can finish below par; the solved message then shows the lower count.
- Par is shown during play.

## 4. Levels

Each level has its own generator parameters (`SumGenerator.LEVELS`). The values below are the **starting values**; the
developer adjusts them in the trial (5.7) within the stated ranges and records the outcome in 5.9.

| Parameter | Easy (0) | Medium (1) | Hard (2) | Allowed range |
|---|---|---|---|---|
| Board `w x h` | 5x5 | 6x6 | 6x6 | 5x5, 5x6, 6x6, 6x7 |
| Insertion steps `I` | 2-3 | 3-4 | 4-6 | +-2 on either bound, at least 1 |
| Quiet steps `Q` | 0-1 | 1-2 | 1-3 | 0-4 |
| Chain insertion chance (percent) | 0 | 25 | 35 | 0-50 |
| Column ten chance (percent of insertions) | 25 | 30 | 30 | 0-60 |
| Tiles per inserted row ten | 2-3 | 2-4 | 3-4 | 2-5 |
| Tiles per inserted column ten | 2-3 | 3-4 | 3-4 | 2-5, at most `h` |
| Different values present (at least) | 3 | 4 | 4 | 2-5 |
| Over runs at start (at least) | 1 | 1 | 2 | 0-3 |
| Greedy gap (5.6) | none | 1 | 1 | none-3 |
| Par band | 2-3 | 4-5 | 6-7 | bands may share at most their end value |
| Candidates tried | 400 | 800 | 1500 | up to 4000 |
| Beam width of the prefilter | 30 | 30 | 30 | 10-200 |
| Solver budget (expansions) | 100 000 | 400 000 | 1 000 000 | up to 3 000 000 |

- The upper bound `U` of a candidate is `I + Q` (one reverse move per step). Par is at most `U`.
- The bands are deliberately lower than White Tally's (3-5 / 5-8 / 8-12): difficulty comes from adding up and from
  gaps, not from long lines, and short lines keep exact par within reach (ADR 0004).

## 5. Rules engine, generator and solver

All code in this section lives in `sim/`, is pure (no nodes, no floats, no time, no `user://`) and is shared by the
game, the build tools and the tests. It starts as a copy of White Tally's `sim/board.gd`, `sim/solver.gd` and
`sim/generator.gd` at White Tally's phase 1 commit; the differences are listed per section. A bug later found in the
copied parts of White Tally (canonical form, legal moves, reverse moves, solver) is checked here too, and the other way
round.

### 5.1 State

- A state is a `PackedByteArray` of length `w * h`, index `i = y * w + x`, value `0` (empty) or `1` to `5`.
- Board size and start position belong to the `SumBoard` instance, not to the state.
- States are used directly as `Dictionary` keys (Godot 4 hashes packed arrays by content), as in White Tally.

### 5.2 Moves in code

- Move code `m = i * 4 + d`, `d` in `R = 0, L = 1, D = 2, U = 3` (White Tally's codes).
- Move token: three characters, direction letter, column letter, row digit (`RB1`); `move_len() == 3`; board limit
  `w <= 8`, `h <= 9`.

### 5.3 `SumBoard` (`sim/board.gd`)

`SumBoard extends WhiteRules`. Same interface as `TallyBoard` (White Tally design 5.3), with runs instead of groups:

```
class_name SumBoard extends WhiteRules
const TARGET := 10
const GLYPHS := ".12345"
var w: int
var h: int
var start: PackedByteArray

static func create(w: int, h: int) -> SumBoard
static func from_dict(d: Dictionary) -> SumBoard                 # {"n": [w, h], "rows": [...]}
func to_dict(state: PackedByteArray) -> Dictionary
func from_rows(rows: PackedStringArray) -> PackedByteArray       # rows top first, chars ".12345"
func render(state: PackedByteArray) -> String
func cell_name(i: int) -> String

# White Kit interface
func start_state() -> Variant
func apply(state: Variant, move: Variant) -> Variant             # canonicalise; null if ignored, else step()
func is_solved(state: Variant) -> bool
func move_len() -> int                                           # 3
func encode_move(move: Variant) -> String
func decode_move(token: String) -> Variant

# Rules
func canonical(state, m: int) -> int                    # as TallyBoard
func legal_moves(state) -> PackedInt32Array             # as TallyBoard
func step(state, m: int) -> PackedByteArray             # fast
func step_reference(state, m: int) -> PackedByteArray   # straightforward
func step_traced(state, m: int) -> Dictionary           # result plus animation steps
func resolve(state) -> PackedByteArray
func settle(state) -> PackedByteArray
func row_runs(state) -> Array[PackedInt32Array]         # every row run, cells left to right, rows bottom first
func col_runs(state) -> Array[PackedInt32Array]         # every column run, cells bottom up, columns left first
func tens(state) -> PackedInt32Array                    # sorted union of the cells of all tens
func run_total(state, cells: PackedInt32Array) -> int
func row_run_of(state, i: int) -> PackedInt32Array      # cells of the row run through cell i, empty if i is empty
func col_run_of(state, i: int) -> PackedInt32Array      # cells of the column run through cell i, empty if i is empty
func run_totals_at(state, i: int) -> Vector2i           # (row total, column total) through cell i, (0, 0) if empty
func is_stable(state) -> bool                           # settled and tens() empty
func over_runs(state) -> int                            # number of row and column runs with total > TARGET
func is_dead_end(state) -> bool
func count_tiles(state) -> int
```

- `row_run_of`, `col_run_of` and `run_totals_at` are an addition for the selection totals the owner wants in phase 1b
  (the sums of the row and the column through the selected tile); `SumBoardView` reads them for the shown state.
- `canonical`, `legal_moves`, `_move_only`, `settle`, `apply`, `encode_move`, `decode_move`, `is_dead_end` and
  `count_tiles` are White Tally's code unchanged (tile values 1-5 instead of 2-4 make no difference to them).
- `step()` (fast): `_move_only`, then waves. Per wave: settle only the touched columns (White Tally's `ymin` logic),
  then find tens only among runs that can have changed: the column runs of touched columns, and the row runs of every
  row at or above the lowest changed row of any touched column, restricted to segments that contain a cell of a touched
  column or a cell next to one. A simpler correct variant is allowed when it is fast enough (M1 in 5.7): scan all row
  runs of rows `>= min(ymin)` and the column runs of touched columns. Remove the union, mark the columns of removed
  cells as touched from the lowest removed row, repeat.
- `step_reference()`: `_move_only`, then loop: `settle` the whole board, `tens()` on the whole board, stop when empty,
  else clear the union.
- Both must return identical states for every stable state and every canonical move; the tests enforce this on random
  states (as White Tally).
- `step_traced()` returns `{"state": result, "steps": [...]}` exactly in White Tally's format: `{"kind": "swap", "a",
  "b"}` or `{"kind": "slide", "from", "to"}`, then per settle `{"kind": "fall", "moves": [[from, to], ...]}` (omitted
  if nothing falls), per wave `{"kind": "vanish", "cells": [...]}` (sorted union). Its `state` equals `step()`.
- Random stable states for tests: fill each column from the bottom with a random height and random values 1-5 (seeded
  `WhiteRng`), then `resolve()`.

There is no `SumAttempt` class: the game uses `WhiteAttempt` directly with a `SumBoard` as rules.

### 5.4 Generator: reverse building (`SumGenerator`, `sim/generator.gd`)

White Tally's reverse-building generator (its design 5.4, ADR 0003 there) with tens instead of groups (ADR 0004 here).
It starts from an empty board and builds the puzzle backwards, so every puzzle is solvable by construction and the
number of reverse steps is an upper bound `U` for par.

```
static func generate(seed_value: int, level: int) -> Dictionary
static func generate_with(seed_value: int, cfg: Dictionary) -> Dictionary
# returns {"board": SumBoard (start set), "par": int, "exact": bool, "upper": int,
#          "path": PackedInt32Array, "tried": int, "fallback": bool}
static func to_json(result: Dictionary) -> Dictionary   # the puzzle object of 6.3
```

**Input.** A 64-bit seed (6.1) and a level. `WhiteRng.new(seed_value)`; only `range_int` and `shuffle` are used.
Percent chances: `rng.range_int(0, 99) < percent`.

**Candidate loop.** As White Tally: for `t = 0 .. candidates - 1` (the PRNG stream continues): draw `I` and `Q`; one
insertion step first, then the remaining `I - 1` insertion steps and `Q` quiet steps in an order shuffled with
`rng.shuffle`; execute them backwards from the empty board (each step retried up to 50 times with fresh draws; if all
fail, the candidate is rejected); then the filters (5.6).

**Insertion step.** With the level's chain chance a chain insertion, otherwise a single insertion, followed by a
breaking reverse move.

- *Single insertion.* Insert one ten into `C`, giving `X` (below). Require: the inserted cells form exactly one ten in
  `X` (they are exactly one maximal row run or one maximal column run with total 10), and `resolve(X) == C`.
- *Chain insertion.* Insert a ten `T2` into `C` giving `Y` (requirements as a single insertion), then insert a ten `T1`
  into `Y` giving `X`. Track where `T2`'s cells are in `X` (a row insertion of `T1` at row `y1` moves every cell of `T2`
  in a spanned column at height `>= y1` up by one; a column insertion moves nothing). Require: in `X` those cells are
  no longer exactly one ten (pushed apart, or extended by a neighbouring `T1` tile), `T1` is exactly one ten, and
  `resolve(X) == C`. Forward this is a chain: `T1` vanishes, tiles fall or a gap opens, `T2` becomes a ten again.
- *Breaking reverse move.* As White Tally: from `X`, pick a reverse move giving a stable `P` with `step(P, m) == C`.

**Drawing the values of a ten** with `k` tiles (`2 <= k <= 5`): for `j = 0 .. k - 2`: `r = 10 - (sum so far)`,
`lo = max(1, r - 5 * (k - 1 - j))`, `hi = min(5, r - (k - 1 - j))`, value `range_int(lo, hi)`; the last value is the
remainder (always 1 to 5). Then `rng.shuffle` the list. (With `k = 2` this is always 5 + 5.)

**Inserting a row ten** of `k` tiles into a settled board `B`:

1. Draw `k` from the level's row range (capped at `w`), the start column `c0` in `0 .. w - k`, and the values.
2. The row `y` must satisfy, for every spanned column `c = c0 .. c0 + k - 1`: `y <= height_B(c)` (the new tile rests on
   the stack or the floor after the stack is pushed up) and `height_B(c) + 1 <= h`. Draw `y` uniformly in
   `0 .. min(height_B(c))`; when some spanned column is full, the insertion fails.
3. In every spanned column the tiles at heights `>= y` move up by one; the new tile goes to `y`.
4. Maximality: the cells `(c0 - 1, y)` and `(c0 + k, y)` must be empty or off the board in `X`; otherwise the
   insertion fails (the run would include an old tile, which would then vanish too).
5. Verify by forward simulation as required by the step. The construction only proposes; `resolve()` decides.

**Inserting a column ten** of `k` tiles: choose uniformly among the empty columns of `B` (none: the insertion fails);
the stack gets the drawn values from the floor up (`k <= h`). Its row neighbours may join row runs; the forward check
rejects a candidate where that creates another ten.

Each insertion is a row ten or, with the level's column ten chance, a column ten.

**Reverse moves** from a board `X` towards a required forward result `T`: exactly White Tally's (reverse swap of two
different values; reverse slide of the top tile of a column into a neighbouring column at every allowed height), in
White Tally's enumeration order, picked uniformly among the valid ones by sampling without replacement. Valid: `P` is
stable (`is_stable`, i.e. no tens) and `step(P, m) == T`. Quiet steps as White Tally (`X = T = C`, `P != C`).

**Example (Example 5 in 2.7, built backwards).**

```
empty         insert row ten   reverse slide    insert column ten   reverse swap
              (X)              (P)              (X)                 (P = start)
. . . .       . . . .          . . . .          . . 5 .             . . 5 .
. . . .       . . . .          . . . .          . . 1 .             . . 1 .
. . . .       2 5 3 .          2 5 . 3          2 5 4 3             2 5 3 4
                               forward: LD1                         forward: RC1
```

The row ten `2 5 3` is maximal because `D1` is empty. The column ten `4 1 5` goes into the empty column `C`; row 1 of
`X` totals 14, so only the column vanishes and `resolve(X)` gives the previous board. `path = RC1 LD1`, `U = 2`.

**Fallback.** As White Tally: when no candidate passes, return the one nearest to the par band (distance of par to
the band; ties: `exact` true first, then fewer tiles) with `fallback = true`.

### 5.5 Solver (`SumSolver`, `sim/solver.gd`)

White Tally's solver (its design 5.5) unchanged apart from the board class:

```
static func solve(board: SumBoard, state: PackedByteArray, upper_path: PackedInt32Array,
		max_expansions: int) -> Dictionary
# {"par": int, "exact": bool, "path": PackedInt32Array, "expansions": int, "capped": bool}
static func beam(board: SumBoard, state: PackedByteArray, width: int, max_depth: int) -> PackedInt32Array
static func greedy(board: SumBoard, state: PackedByteArray, max_moves: int) -> Dictionary
```

- `solve`: iterative deepening depth-first search with a transposition table (`table[state] = r` means "not clearable
  within `r` moves"), kept across iterations and capped at 4 000 000 entries; children ordered by fewest tiles left,
  then ascending move code; at `r == 1` only children that empty the board; one expansion per node whose children are
  generated; capped at `max_expansions`. Without a cap: exact. With a cap: `exact = false`, then
  `beam(board, state, 200, U - 1)` may shorten the known line.
- `beam` and `greedy` as White Tally.
- All limits are counts, never time.

Measures that keep exact par within reach (lessons of White Tally's trial, its design 5.9):

1. Lower par bands and fewer tiles (section 4): the cost of the last, exhaustive iteration grows with branching to the
   power `par - 2`; par 6 with about 25 moves per position is in the order of 400 000 expansions, par 8 would be 600
   times more.
2. The beam prefilter is part of the design (White Tally added it during its trial): see 5.6 step 4.
3. The exact search runs only for candidates that passed every cheap check and the prefilter, so in practice about one
   full search per accepted puzzle.
4. The pool is built in parallel processes (6.4); the time check P3 is wall-clock time on one desktop with up to 8
   processes.
5. M1 (5.7) is measured first; when `step()` is slower than 30 000 calls per second on the hard board with 16 tiles,
   the developer profiles and speeds up `step()` before the trial (for example by narrowing the row scan of 5.3).

### 5.6 Filters

A candidate is accepted when all of the following hold, in this order (cheap checks first):

1. The start position is stable and not empty.
2. `U >= band minimum`.
3. At least the level's number of different values, and at least the level's number of over runs (`over_runs`).
4. Beam prefilter: `b = beam(board, start, beam width, U - 1)`. When `b` is not empty and shorter than the band
   minimum, reject (par is too low). Otherwise the known line is `b` when not empty, else the generator's path.
5. `solve(board, start, known line, budget)`.
6. Par lies in the band.
7. **[later]** `exact` is true (phase 2, per level, gate B in 5.8).
8. Greedy gap: `greedy(board, start, 3 * U)` does not solve the puzzle in fewer than `par + gap` moves (a greedy
   failure passes). Level "none" skips this filter.

Every candidate that reaches step 5 is a fallback candidate (5.4).

### 5.7 Phase 1 trial

Before UI work the developer builds `SumBoard`, `SumSolver` and `SumGenerator` with their tests, then
`tools/measure.gd`, and runs the trial.

- M1 throughput: `step()` calls per second on random stable 6x6 boards with 14-18 tiles; solver expansions per second;
  average number of legal moves per position.
- M2 per level, 50 seeds (`WhiteSeed.fnv1a64("white-sum-trial|<n>|<level>")`, `n = 0 .. 49`): candidates tried,
  fallback count, tiles at start, `U`, par, share of `exact`, share of chains and crosses in the stored solutions, build
  time per puzzle (median, max).

Done when, for every level:

| Check | Requirement | If not met |
|---|---|---|
| P1 | At least 40 of 50 seeds give a non-fallback puzzle. | Adjust `I`, `Q`; then the run lengths; then lower the over-run minimum; then the greedy gap. |
| P2 | Median par strictly increases easy < medium < hard. | Shift bands or `I`/`Q`. |
| P3 | Building the pool (6.3, 40 sets) takes at most 2 hours wall-clock on a desktop with up to 8 parallel processes. | Lower solver budgets (par may then be bounded). |
| P4 | Reported, not a gate in phase 1: share of `exact` per level. Target: easy and medium 100%, hard at least 50%. | Below target: report; the architect decides before phase 2. |

Adjust only within the ranges of section 4. If P1-P3 cannot be met within the ranges, stop and report to the project
lead.

### 5.8 [later] Full trial for the daily puzzle

Before puzzles are bound to dates: 200 seeds per level and M3 (build time of 60 days = 180 puzzles), gates in order:

| Gate | Requirement | If not met |
|---|---|---|
| A | Easy and medium: at least 95% of accepted puzzles `exact`. | Raise the budget (max 3 000 000); then smaller boards or lower bands. |
| B | Hard: at least 80% `exact`, solver p95 at most 120 s. | Hard ships bounded par. |
| C | At least 20% of candidates accepted per level. | Adjust `I`, `Q`, run lengths, over-run minimum, greedy gap. |
| D | Median par strictly increases, and median hard >= p75 medium. | Shift bands or `I`/`Q`. |
| E | M3 at most 2 hours. | Lower budgets while keeping A and B. |

### 5.9 Trial results

Phase 1a, 2026-11-18, Godot 4.7.2, kit `v0.2.0`, one desktop (8 cores, shared with other work; at most 3 Godot
processes of this project at a time). Seeds `white-sum-trial|<n>|<level>`, `n = 0 .. 49`.

**Settings.** The starting values of section 4 passed P1-P3 unchanged; nothing was adjusted. Implementation of the
level table: `SumGenerator.LEVELS` (keys `col` = column ten chance, `row_k`, `col_k`, `over`, `beam`).

**M1** (6x6, 14-18 random stable tiles): `step()` 82 000 calls per second (limit 30 000, no tuning needed; the simple
variant of 5.3 is used: all row runs from the lowest changed row, column runs of touched columns); 26.8 legal moves
per position on average; solver 2 500 expansions per second (hard pool puzzle, 20 000 expansions). The exhaustive
iteration of a par-6 hard puzzle therefore takes tens of seconds.

**M2** (50 seeds per level):

| | Easy 5x5 | Medium 6x6 | Hard 6x6 |
|---|---|---|---|
| Non-fallback puzzles | 50 | 50 | 50 |
| Candidates tried (median / max) | 1 / 4 | 3 / 17 | 57 / 417 |
| Tiles at start (median) | 7 | 13 | 20 |
| `U` (median) | 3 | 5 | 8 |
| Par (median) | 2 | 4 | 6 |
| Par spread | 2: 33, 3: 17 | 4: 45, 5: 5 | 6: 50 |
| Exact par | 50 of 50 | 50 of 50 | 50 of 50 |
| Stored solution has a chain | 13 of 50 | 29 of 50 | 34 of 50 |
| Stored solution has a cross | 0 of 50 | 0 of 50 | 0 of 50 |
| Build time per puzzle (median / max) | < 0.1 s / < 0.1 s | 0.2 s / 27 s | 50 s / 230 s |

Sum of the build times of the 150 puzzles: 3 360 s on one process.

**Checks.**

| Check | Result |
|---|---|
| P1 | Met: 50 of 50 non-fallback on every level (need 40). |
| P2 | Met: median par 2 < 4 < 6. |
| P3 | Met: the 40-set pool took 28 minutes wall-clock on 2 processes (20 sets each, other work running on the machine); estimated 19 minutes on 3 and 7 on 8 processes from the summed build times. Limit 2 hours. |
| P4 | Reported: exact 100% on all three levels (target easy and medium 100%, hard at least 50%). |

**Pool** (`data/practice.json`, 40 sets): all 120 puzzles non-fallback and exact; easy par 2 or 3 (median 2, 5-9
tiles), medium par 4 or 5 (median 4, 9-19 tiles), hard par 6 only (median 6, 14-26 tiles). `tools/verify_puzzles.gd`
re-solved all 40 sets without a mismatch.

**Findings for later phases.**

- Crosses: no stored solution contains a cross. By construction every insertion step makes exactly one ten (5.4), and
  the stored line is the generator's line or a shorter line found by the beam or the solver. Crosses (Example 2) still
  occur in play, but the generator does not aim for them. A "cross insertion" (two tens that share a tile) would need
  an architect decision.
- Hard par is always 6: the band 6-7 holds only the lower value. A hard puzzle with `U` 8 or 9 is usually solved in
  6, so the bounded and exact lines coincide. Spread inside a level is narrow (easy 2-3, medium 4-5).
- Hard is the only costly level (median 50 s, worst 230 s per puzzle). Exact par holds for all of it at budget
  1 000 000; the gates of 5.8 (hard exact at least 80%, p95 at most 120 s) look reachable, p95 is not measured yet.
- Easy puzzles are small (median 7 tiles, 5 at the smallest); the three-values and one-over-run minimums hold.

**Deviations from the design text.**

- Fallback candidates are those that reach the exact search (5.6, last line); a candidate rejected by the beam
  prefilter or by `U` below the band minimum is never a fallback. A candidate that no step produces gives the empty
  fallback (`par` 0), as in White Tally. No fallback occurred in the trial or the pool.
- A row ten insertion also checks the two cells beside the new run directly (5.4 step 4); `_is_ten` then confirms it.
- `SumGenerator.ten_values` is public so the tests can call it; the unit tests draw one easy and one medium puzzle and
  leave the hard one to the pool tests (35 s).
- `tools/measure.gd` has `--m1-only` and prints chain and cross shares; run the levels in separate processes.

## 6. Precomputed puzzles

### 6.1 Seeds

- Game id `white-sum`. Pool seed `WhiteSeed.practice("white-sum", i, level)` (seed text `white-sum-practice|<i>|<level>`).
- **[later]** Daily seed `WhiteSeed.daily("white-sum", date, level)`.
- A seed only reproduces a puzzle with the same generator code; the puzzle JSON is the portable form.

### 6.2 Why precomputed

The solver takes seconds to minutes per puzzle on a desktop and far longer in a phone browser. Puzzles are built ahead
of time and shipped; the game only loads, never searches (ADR 0006).

### 6.3 Files and format

- Phase 1: one pool, `data/practice.json`: `{"<i>": [easy, medium, hard]}`, 40 sets. No `data/daily.json` in phase 1.
- **[later]** `data/daily.json`: `{"<YYYY-MM-DD>": [easy, medium, hard]}`.
- Loaded with `WhitePuzzleStore.new("res://data/daily.json", "res://data/practice.json", convert)`; `convert` gives
  `{"board": SumBoard.from_dict(raw.board), "par", "exact", "upper", "path"}` (path as a `PackedInt32Array`).
- Puzzle object (Example 5):

```json
{
  "board": {"n": [4, 3], "rows": ["..5.", "..1.", "2534"]},
  "par": 2,
  "exact": true,
  "upper": 2,
  "path": "RC1LD1"
}
```

| Field | Meaning |
|---|---|
| `board.n` | `[w, h]` |
| `board.rows` | `h` strings of `w` characters `.12345`, top row first (as `render()`) |
| `par` | Fewest moves found by the solver |
| `exact` | `true` if par is proven minimal |
| `upper` | `U`, the generator's number of reverse steps |
| `path` | One solution of length `par`, concatenated three-character tokens |
| `fallback` | Present and `true` only for a fallback puzzle |

### 6.4 Build tools

- `tools/build_puzzles.gd` extends `WhitePrecompute`: `_game_id()` returns `"white-sum"`; `_generate(seed_value,
  level)` returns `SumGenerator.to_json(SumGenerator.generate(seed_value, level))`; `_summary(puzzles)` prints
  ` par <list> exact <list> upper <list>` and ` FALLBACK` when any puzzle has `fallback`.
- Pool build in parallel, for example 8 processes of 5 sets each:
  `--practice=5 --start=<0,5,...,35> --out=build/practice_<k>.json`, then
  `--merge=build/practice_<k>.json --into=build/practice.json` for `k = 0 .. 7`, verify, copy to `data/`
  (conventions, Puzzle data).
- `tools/verify_puzzles.gd` (`extends SceneTree`): `--file=<json>` re-solves every puzzle with its level's budget and
  checks `par`, `exact` and that `path` empties the board; prints one line per key; exit 1 on any mismatch.
- `tools/measure.gd`: the trial (5.7), `-- --seeds=50 [--level=N]`.

### 6.5 Game constants

`sim/game.gd`, `class_name SumGame`: `GAME_ID := "white-sum"`, `DAILY := "res://data/daily.json"`,
`PRACTICE := "res://data/practice.json"`, `store()` returning one lazily created `WhitePuzzleStore` with the converter
of 6.3. **[later]** `FIRST_DAY`.

### 6.6 Known trade-off

The repository is public, so all puzzles and a solution for each are readable. No issue in phase 1; from the
leaderboard phase the server provides the daily puzzle.

## 7. White Kit usage

| # | Need | Kit part | How White Sum uses it |
|---|---|---|---|
| K1 | Dutch calendar day, puzzle number | `WhiteDaily` | **[later]** Through `WhiteDayScreen`. |
| K2 | PRNG and seed hash | `WhiteRng`, `WhiteSeed` | Generator, tests, trial. |
| K3 | Puzzle loading | `WhitePuzzleStore` | `SumGame.store()`. |
| K4 | Rules, attempt, record, count modes | `WhiteRules`, `WhiteAttempt` | `SumBoard extends WhiteRules`, `move_len() == 3`; `WhiteAttempt.new(board, FINAL_ONLY)` in phase 1. |
| K5 | Saved progress | `WhiteProgress` | Phase 1: language only. **[later]** daily records. |
| K6 | Clock, share line | `WhiteFormat` | Phase 1: clock. **[later]** share line. |
| K7 | Texts NL/EN | `WhiteText` | `SumStrings.TEXT` (10.6). |
| K8 | Screen | `WhiteDayScreen`, `WhiteTheme`, `WhiteUi` | `ui/main.gd` (10.3). |
| K9 | Board view | `WhiteTileView` (kit 0.3.0) | `SumBoardView extends WhiteTileView`, `CELL_MOVES` (10.1-10.4). |
| K10 | Safe area, maximum width | `WhiteSafeArea`, `_use_safe_area()`, `_max_content_width()` (kit 0.3.0) | true and 720. |
| K11 | Tests, precompute, CI, screenshots | `WhiteTestRunner`, `WhitePrecompute`, `templates/ci.yml`, `tools/shots.sh` | As White Tally; screenshots from `tools/shots.txt` (11). |

No kit changes are requested beyond kit 0.3.0 as designed.

## 8. Attempt and record

`WhiteAttempt` with `SumBoard` as rules. Record per kit grammar: move tokens `R`/`L`/`U` + column letter + row digit,
canonical (for example `RC1`); `z` undo; `r` restart. `apply` canonicalises, so a non-canonical token replays to the
same state. Example on Example 5: `RA1zRC1LD1` = swap at `A1`, undo, swap at `C1`, slide at `D1`; solved;
`FINAL_ONLY` count 2, `EVERY_MOVE` count 3.

In phase 1 the record is used by the debug mode (`--keys`) and tests. **[later]** Save and replay format.

## 9. Saved progress

Phase 1: the kit saves only the language, in `user://progress.json`. **[later]** Daily progress through
`WhiteDayScreen`.

## 10. User interface

Godot 4.7.2, GL Compatibility, portrait 720x1280 design size (stretch `canvas_items`, aspect `expand`). All drawing in
code, no image assets. Screen colours and fonts from `WhiteTheme`.

### 10.1 Look

Abstract, flat, dark and calm, in the series style. Numerals, not pips (ADR 0005).

| Element | Presentation |
|---|---|
| Board | `WhiteTileView` defaults: flat rounded rectangle `#232933`, grid lines `#2C333F`. |
| Tile | Flat rounded square (radius 18% of the cell, gap 8%). No gradients, outlines or shadows. |
| Tile colour | One cool hue, slightly lighter for higher values: 1 `#3A465C`, 2 `#43516A`, 3 `#4C5C78`, 4 `#566886`, 5 `#607494`. The steps are small on purpose: the numeral carries the value; colour is a quiet hint, not a grouping signal. |
| Numeral | The value as a digit, `#F2F4F8`, font size `0.52 * cell * scale`, default theme font, centred horizontally and vertically on the tile; alpha follows the tile. |
| Links | None. Runs are straight lines of touching tiles and read from the gaps; no bars are drawn. |
| Selection / cursor | Kit defaults: 4 px outline in `WhiteTheme.ACCENT`, solid for selection, dashed for the cursor. |
| Run totals of the selection | While a tile is selected and no animation runs: the row run and the column run through it get a faint band (white at 10% alpha, rounded, 4% of a cell beyond the end tiles) and one **total pill** each: a rounded pill of 0.74 x 0.44 cells, fill `#1B1F26`, 2 px line (white at 55%), the total as digits (`#E6E9EF`, font 0.30 cell). The row's pill sits in the empty cell right after the run (a maximal run is always followed by an empty cell or the edge); when the run reaches the right edge it goes to the empty cell before the run; when the run spans the full width it sits on the right seam of the end tile. The column's pill sits in the empty cell above the stack, or on the top seam of the top tile when the stack reaches the top of the board. No colour for over or short: the player compares the number with 10 themselves. The totals describe the shown board and disappear with the selection (a move, a deselect, Esc) and while an animation runs. |

Look-alike risk (ADR 0005): no fruit, sweets, gems, coins or dice faces; no sparkles, particles, flashes, screen shake,
combo texts or score pop-ups; no lives, boosters or level maps. A vanish is a quiet fade.

All values are members or constants at the top of `ui/board_view.gd`, so they can be tuned after the look-and-feel
test without touching logic.

`SumBoardView.run_marks(board, state, cell)` (static, tested) returns a dictionary with `row` and `col` (cells of the
runs), `row_total`, `col_total`, `row_anchor` and `col_anchor` (pill centres in cell units, `y` up), or an empty
dictionary for an empty cell; `selection_marks()` applies it to the selected cell of the shown state. The totals equal
`SumBoard.run_totals_at` (tested on pool boards).

### 10.2 Animation

As White Tally, through kit view steps (kit design 14.4):

| Trace step (`step_traced`) | View step |
|---|---|
| `swap` `a`, `b` | `{"kind": "move", "moves": [[a, b], [b, a]], "time": 0.12, "ease": true}` |
| `slide` `from`, `to` | `{"kind": "move", "moves": [[from, to]], "time": 0.10, "ease": true}` |
| `fall` `moves` | `{"kind": "move", "moves": moves, "speed": 16.0}` |
| `vanish` `cells` | `{"kind": "vanish", "cells": cells}` (180 ms fade and shrink to 70%, 60 ms pause) |

- `SumBoardView.to_view_steps(steps: Array) -> Array` (static, tested) does this mapping.
- `update_attempt(a)`: when the record ends with a move token and history is not empty, decode it and call
  `animate(to_view_steps(board.step_traced(a.history.back(), code).steps), a.history.back())`; after undo or restart
  (`z` or `r`), `show_values(a.state)`. The attempt is updated at once; the animation is presentation only. A new move
  during an animation first finishes it (kit).
- Ignored action: the kit shakes the source tile.

### 10.3 Screen (`ui/main.gd extends WhiteDayScreen`)

Phase 1 uses the kit screen in practice mode only, as White Tally: title and language button (mode button hidden),
subtitle with the set number, three level tabs, counter, par and clock, the board, message line, buttons Undo,
Restart, Best route (when solved), Next.

| Hook | White Sum |
|---|---|
| `_game_id()` | `SumGame.GAME_ID` |
| `_game_title()` | `"WHITE SUM"` |
| `_first_day()` | Phase 1: `WhiteDaily.today()` (placeholder, never shown). **[later]** `SumGame.FIRST_DAY`. |
| `_texts()` | `SumStrings.TEXT` |
| `_practice_only()` | true (phase 1) |
| `_load_day(date)` | Phase 1: `[]`. **[later]** `SumGame.store().day(date)` |
| `_load_practice(index)` | `SumGame.store().practice_set(index)` |
| `_practice_count()` | `SumGame.store().practice_count()` |
| `_count_mode(is_practice)` | `FINAL_ONLY` if `is_practice`, else `EVERY_MOVE` |
| `_new_attempt(puzzle, mode)` | `WhiteAttempt.new(puzzle.board, mode)` |
| `_make_view()` | a `SumBoardView`; `move_chosen` connected to `_on_move`, `finished` to a refresh (as White Tally) |
| `_view_show(a)` | `view.show_attempt(a)` (`show_cells` of the board size and state) |
| `_view_clear()` | `view.clear()` |
| `_view_update(a)` | `view.update_attempt(a)` (10.2) |
| `_extra_buttons()` | `[best_btn]`: Best route animates the stored `path` from the start without changing the attempt; sets `_replaying` while it runs (White Tally's `_show_best`) |
| `_hint_text()` | `t("hint")` |
| `_play_message(a)` | dead-end notice (2.8), empty while the view is busy |
| `_key_move(event)` | `view.key_move(event)` |
| `_on_debug_extra()` | `--sel=<cell>` selects a cell; `--best` plays the stored path |
| `_max_content_width()` | 720 |
| `_use_safe_area()` | true |

### 10.4 Input

`SumBoardView extends WhiteTileView` with `input_mode = CELL_MOVES`; everything as White Tally 10.4 (swipe on a tile,
tap-tap, keyboard cursor and grab), provided by the kit. A swipe shows no totals (it is a move at once); tap-tap and the
keyboard grab select a tile and show its totals (10.1). `_resolve_cell_move(cell, dir)` returns
`board.canonical(shown(), cell * 4 + dir)`. Debug: kit screenshot mode plus `--sel` and `--safe`.

### 10.5 Messages

| When | Message line |
|---|---|
| No move made yet | `hint` |
| Solved | `solved` with count, par and clock, plus `perfect` when count equals par |
| Not solved, dead end | `dead_end` |
| Otherwise | empty |

### 10.6 Texts (`ui/strings.gd`, `class_name SumStrings`)

| Key | Dutch | English |
|---|---|---|
| `count` | Zetten: %d | Moves: %d |
| `count_final` | Zetten in oplossing: %d | Moves in solution: %d |
| `solved` | Leeg in %d zetten (par %d) · %s | Cleared in %d moves (par %d) · %s |
| `perfect` | Precies par! | Exactly par! |
| `hint` | Wissel of schuif stenen. Een rij of kolom aaneengesloten stenen die samen precies 10 is, verdwijnt. | Swap or slide tiles. A row or column of touching tiles that adds up to exactly 10 vanishes. |
| `dead_end` | Geen zet meer mogelijk. Neem terug of begin opnieuw. | No move left. Undo or restart. |
| `best_route` | Beste route | Best route |
| `share_line` | White Sum #%d · %s zetten (par %s) | White Sum #%d · %s moves (par %s) |

### 10.7 [later] Share line

`White Sum #12 · 4/6/9 moves (par 3/5/7)` (Dutch `zetten`), unsolved levels as `-`, built by `WhiteFormat.day_line`.
No moves, no time, no board.

## 11. Build and deployment

- Phase 1a: `.github/workflows/ci.yml` with the kit template's checkout, pin check, `setup-godot`, import, kit tests
  and game tests (no export yet).
- Phase 1b: the full kit 0.3.0 template: plus debug screenshots from `tools/shots.txt`, Web export (release,
  single-threaded) as artifact, Pages deploy on `develop`.
- `tools/shots.txt` (phase 1b):

```
easy 720x1280 --practice --level=0
medium 720x1280 --practice --level=1 --lang=en
hard 720x1280 --practice --level=2
selected 720x1280 --practice --level=1 --sel=7
selected-edge 720x1280 --practice --level=1 --sel=8
selected-hard 720x1280 --practice --level=2 --sel=13
midgame 720x1280 --practice --level=2 --keys=RA2LD5
solved 720x1280 --practice --level=0 --best
phone-safe-area 720x1280 --practice --level=1 --safe=40,80,40,60
small 360x640 --practice --level=1 --sel=7
desktop 1280x720 --practice --level=1
wide 1900x1000 --practice --level=2
```

`selected` shows both totals in empty cells, `selected-edge` a column reaching the top of the board (pill on the
seam).

- Export preset `exclude_filter="tests/*,tools/*,addons/white_kit/tests/*,addons/white_kit/tools/*"`.
- On `develop` the Web build is published to https://play.white-sum.steefbeest.nl (custom domain: Pages setting plus a
  DNS record in the existing zone, as for the other games; no CNAME file, the Pages source is the workflow).
- No Android or Windows builds in phase 1. No `LICENSE` file (all rights reserved).

## 12. Roadmap

| Phase | Content |
|---|---|
| 1 | Look and feel: rules, generator, solver, precomputed pool in three levels, controls, animations, readability, NL/EN, play version. |
| 2 | Daily puzzle: three puzzles per Dutch day, first day and numbers, share line, `EVERY_MOVE`, saved daily progress, full trial (5.8). |
| 3 | Tuning from play tests: levels, bands, scoring, par visibility, more run-total helpers, dead-end reporting, possibly another target. |
| 4 | Version 1 finish: look, sound, statistics, Android. |
| 5 | st33f-engine: daily seed or puzzle from the server, results, leaderboards, friends, accounts (owner approval for players aged 10-15). |
| 6 | Competitions; player feedback triage. |

## 13. Acceptance criteria

### 13.1 Phase 1

Rules (`SumBoard`)
- Examples 1-6 in 2.7 give exactly the shown boards (compared with `render()`); Example 3 through `step_traced()`
  yields exactly two `vanish` steps; Example 2's single `vanish` step holds exactly `A2`, `B2`, `C2`, `C1`.
- `row_runs` and `col_runs` on the start of Example 4: row runs `[A1..E1]`, `[A2..D2]`; column runs one per column;
  every tile is in exactly one row run and one column run.
- Equal-value swaps, moves from an empty cell, moves off the board and `U`/`D` into an empty cell are ignored
  (`canonical()` -1, `apply()` null); canonicalisation as White Tally (a `D` move onto a different tile below gives `U`
  from that lower cell; an `L` move onto a different tile on the left gives `R` from that left cell; an `L` move into
  an empty cell stays `L`).
- For 10 000 random (stable state, legal move) pairs: `step()` is stable, `step()` equals `step_reference()` and
  `step_traced().state`; `apply()` does not modify its argument.
- `is_dead_end` is true for Example 6 and false for the starts of Examples 1-5.
- Tokens round-trip on an 8x9 board, match `^[RLUD][A-H][1-9]$`; `decode_move` returns null for `rb1`, `XB1`, `RJ1`,
  `RB0` and cells off the board. `from_dict(to_dict(state))` round-trips. Two equal `PackedByteArray`s hit the same
  `Dictionary` entry.
- An independent oracle written in the test (plain loops, no code shared with `SumBoard`) agrees with `step()` on 300
  random stable boards for every legal move.

Generator and solver
- `generate(seed, level)` twice gives identical rows, par, exact, upper and path.
- Every generated start is stable; replaying `path` empties the board in exactly `par` moves; `par <= upper`.
- Example 5 with `upper_path = RC1 LD1`: `solve` returns par 2, `exact` true; with `max_expansions = 0`: `capped`
  true, `exact` false, par 2.
- On 20 small generated boards (`w <= 4`, `h <= 3`, at most 8 tiles, test level) the solver's par equals a plain
  breadth-first search over all reachable states (test helper).
- Drawing ten values: for every `k` in 2..5 and 1000 seeds the values are in 1..5 and add up to 10.
- Row ten insertion never produces a run that includes an old tile (maximality, 5.4 step 4), checked on 1000 random
  insertions.
- No file in `sim/` uses `RandomNumberGenerator`, `randi(`, `randf(`, `randomize(` or `next_float`.
- Trial checks P1-P3 met and P1-P4 recorded in 5.9.

Pool
- Every puzzle in `data/practice.json` converts through the store; its start is stable; `par` lies in the level band
  unless `fallback` is set; `path` empties the board in exactly `par` moves; 40 sets of three.
- `tools/verify_puzzles.gd` confirms par and exact for every pool puzzle (run before committing data).

Attempt and record
- `FINAL_ONLY`: undo lowers the count, restart sets it to 0, `moves_made` counts everything; record `RA1zRC1LD1` on
  Example 5: solved, count 2 (3 in `EVERY_MOVE`); ignored actions change neither count nor record; `apply_record`
  reproduces state, record, `moves_made` and `count()`.
- A non-canonical token replays like its canonical form: on the start of Example 5, `LD1` (the 4 at `D1` towards the
  3 at `C1`, a swap) gives the same state as `RC1`.

UI and deployment (tests, screenshots or manual)
- The game opens directly on a pool set (no mode button); tabs switch levels; Next goes to the next level and after
  hard to the next set.
- Swipe, tap-tap and keyboard perform the moves of Examples 1-4 on the example boards; records written from the UI
  contain only canonical tokens; an ignored move shakes the tile and changes nothing.
- `to_view_steps` maps every trace step kind as in 10.2; swap, slide, fall, vanish and chain animate in that order; a
  move during an animation snaps it to its end.
- Numerals are readable at 360x640; all five values are distinguishable in greyscale by their numeral.
- No particles, flashes, screen shake or pop-up texts.
- Counter reads `count_final`, par is shown, solved message with count, par and clock.
- Dead-end message on Example 6, gone after undo.
- Dutch and English complete; the language choice survives a reload.
- With a tile selected (tap-tap or keyboard grab) the totals of its row run and column run are shown at the run ends;
  they equal `run_totals_at`, never cover a tile, and vanish with the selection and during animations.
- On 1280x720 and 1900x1000 the screen is a centred column at most 720 wide with the board as large as on a phone
  (`desktop` and `wide` shots); on 720x1280 and 360x640 it fills the width.
- CI on `develop` green (pin, kit tests, game tests, screenshots); https://play.white-sum.steefbeest.nl loads and plays
  on a phone and on a PC.

### 13.2 [later] Phase 2

- `EVERY_MOVE`: undo and restart never lower the count.
- Every date from the first day to the last built date has three puzzles in `data/daily.json`; `exact` per gates A-B.
- Reload keeps a partly played day; share line `White Sum #<n> · a/b/c moves (par p/q/r)` with `-` for unsolved levels.

## 14. Developer work

### 14.1 Phase 1a: rules, solver, generator, tools, pool (kit `v0.2.0`)

Does not wait for kit 0.3.0.

1. Repository setup: `project.godot` (Godot 4.7.2, GL Compatibility, 720x1280, stretch `canvas_items`/`expand`, Web
   single-threaded), kit submodule at `v0.2.0`, `export_presets.cfg` with the exclude filter, `tests/run_tests.tscn`
   (`extends WhiteTestRunner`), CI of section 11 (phase 1a part). The README is already written; keep it current.
2. Copy White Tally's `sim/board.gd`, `sim/solver.gd`, `sim/generator.gd`, `sim/game.gd` and their rules and solver
   tests; rename classes (`Sum*`); adapt the board to runs and tens (5.3), the generator to ten insertion (5.4), the
   game constants (6.5). Examples of 2.7 as tests, the independent oracle, the step agreement test.
3. Solver tests (5.5, 13.1), generator tests.
4. `tools/measure.gd`; run M1 first (5.5 item 5), then the trial; record 5.9.
5. `tools/build_puzzles.gd`, `tools/verify_puzzles.gd`; build the pool in parallel (6.4), verify, commit
   `data/practice.json`; pool tests.

Done when: all tests green in CI, P1-P3 met, P4 reported, the pool verified. Done 2026-11-18 (5.9).

### 14.2 Phase 1b: screen, board view, play version (kit `v0.3.0`)

Needs the kit tag `v0.3.0` (kit design 14).

1. Pin `v0.3.0`; kit threshold from its template.
2. `ui/strings.gd` (10.6), `ui/board_view.gd` (`SumBoardView extends WhiteTileView`: look of 10.1 through the drawing
   hooks, `_resolve_cell_move`, `show_attempt`, `update_attempt`, `to_view_steps`), `ui/main.gd` and `ui/main.tscn`
   (10.3), Best route and the dead-end notice.
3. UI tests (as White Tally's `ui_tests.gd`, adapted): open, tabs, Next, undo/restart, counter texts, input on the
   example boards, `to_view_steps`, max width.
4. `tools/shots.txt` and the full CI template; Pages on `develop`.

Done when: 13.1 is met (including the play version on the custom domain). Built 2026-11-18, see 14.3.

### 14.3 Phase 1b: as built

Kit `v0.3.0` (764 kit checks), 225 game checks. `ui/main.gd`, `ui/main.tscn`, `ui/board_view.gd`, `ui/strings.gd`,
`tests/ui_tests.gd`, `tools/shots.txt` and the full kit CI template (screenshots, Web export, Pages) are in.

Deviations and additions:

- Selection totals (10.1) were added by decision of the owner; the design had kept them out of phase 1. The look (band
  and pill, anchor rules) is the developer's choice within that decision and can be tuned in the constants at the top of
  `ui/board_view.gd`.
- `project.godot` got `run/main_scene` (needed for the screenshot scenarios).
- No links are drawn between tiles; the `_draw_links` hook draws the bands and total pills of the selection, because it
  is the only hook between the tile bodies and the numerals.
- The screenshot scenarios `selected-edge`, `selected-hard` and `midgame` were added to the list of section 11.

## 15. Open points

- Phase 1 look-and-feel test: is the gentle colour ramp helpful or noise; are the totals of the selected tile enough,
  or do players want run totals for every run, or while dragging? Selection totals are built (10.1); more is decided
  after the test.
- Phase 2: first day, final scoring rules, full trial gates.
- Later: whether value 6 or another target (for example 12) gives more depth; whether dead ends beyond "no move left"
  are reported.
- The trial may change board sizes and bands within section 4; outside them is an architect decision.
