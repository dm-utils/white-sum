# White Sum - design

Status: phase 1a built (rules, solver, generator, tools, pool; trial in 5.9); phase 1b built (screen, board view, play
version; deviations in 14.3). iOS test build through TestFlight designed (section 16, ADR 0007), not built yet. Later
phases are designed in outline and marked **[later]**; they are not built in phase 1.
This document describes the game as it must be built. Decisions with their trade-offs are in `docs/adr/`; terms are
defined in `docs/glossary.md`; code and test rules are in `docs/conventions.md`. Store texts are drafted in
`docs/store-listing.md`.

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
- An iOS test build of the phase 1 content for iPhone, built, signed and uploaded by GitHub Actions without a Mac, and
  distributed through TestFlight to the owner (internal) and to external testers (public link). Decision of the owner,
  2026-11-19 (section 16, ADR 0007).

Out of scope for phase 1 (designed below where marked **[later]**): binding puzzles to dates, the first day and puzzle
numbers, the share line, daily counting (every move counts), saved daily progress, the full trial with strict gates,
accounts, leaderboards, a server, art, sound, Android/Windows builds, an App Store release of the iOS app (16.10), an
iPad layout (16.6), a puzzle archive, run totals other than those of the selected tile (for example for every run at
once, or while dragging).

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
| K12 | Godot and export templates in CI | `ci/setup-godot` | `ci.yml`, and the `export` job of `ios.yml` (16.8), unchanged. |

No kit changes are requested beyond kit 0.3.0 as designed. The iOS build (section 16) needs none either; the only
conditional kit change (macOS support in `setup-godot`) is the fallback of ADR 0007 and would be requested in
`dm-utils/white-kit`, never made in `addons/white_kit`.

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
- iOS: a separate workflow `.github/workflows/ios.yml`, started by hand or by a `v<version>` tag, exports, signs and
  uploads a TestFlight build (section 16, ADR 0007). It never runs on an ordinary push.
- No Android or Windows builds in phase 1. No `LICENSE` file (all rights reserved).

## 12. Roadmap

| Phase | Content |
|---|---|
| 1 | Look and feel: rules, generator, solver, precomputed pool in three levels, controls, animations, readability, NL/EN, play version; iOS test build through TestFlight (section 16). |
| 2 | Daily puzzle: three puzzles per Dutch day, first day and numbers, share line, `EVERY_MOVE`, saved daily progress, full trial (5.8). |
| 3 | Tuning from play tests: levels, bands, scoring, par visibility, more run-total helpers, dead-end reporting, possibly another target. |
| 4 | Version 1 finish: look, sound, statistics, Android, App Store release of the iOS app (16.10). |
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

iOS build: section 16.11.

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

### 14.4 iOS build

See 16.9.

## 15. Open points

- Phase 1 look-and-feel test: is the gentle colour ramp helpful or noise; are the totals of the selected tile enough,
  or do players want run totals for every run, or while dragging? Selection totals are built (10.1); more is decided
  after the test.
- Phase 2: first day, final scoring rules, full trial gates.
- Later: whether value 6 or another target (for example 12) gives more depth; whether dead ends beyond "no move left"
  are reported.
- The trial may change board sizes and bands within section 4; outside them is an architect decision.
- iOS (section 16): assumption I1 (Linux export of the Xcode project) is verified in the first developer step; if it
  fails, the kit fallback of ADR 0007 applies. Owner decisions still open: the TestFlight feedback address, the
  copyright line, whether "White Sum" is still free as an App Store name, and (before an App Store release) the EU
  trader status. The privacy pages on the promo site (repository `pulse`) are needed before external testing.

## 16. iOS build (TestFlight)

Designed 2026-11-19 (ADR 0007). Scope: the phase 1 content exactly as on the web, on iPhone, distributed through
TestFlight to the owner (internal group) and to external testers (public link). Everything is built, signed and
uploaded by GitHub Actions; no step needs a Mac. An App Store release is a later step (16.10); nothing here has to be
redone for it.

### 16.1 Assumptions

| # | Assumption | If wrong |
|---|---|---|
| I1 | Godot 4.7.2 on Linux exports an iOS Xcode project when `application/export_project_only` is true, and only warns that the `.ipa` can be built on macOS only. | Fallback of ADR 0007 decision 6: macOS support in the kit action `setup-godot` (a White Kit card and release); the export moves into the macOS job. |
| I2 | The export templates archive that `setup-godot` installs contains the iOS template. | Same fallback. |
| I3 | The GitHub runner image `macos-26` has Xcode 26 with the iOS 26 SDK, which App Store Connect requires for new uploads. | Use the newest macOS image that has the required SDK; step B2 fails loudly otherwise. |
| I4 | The game sends nothing over the network. Checked 2026-11-19: no `HTTPRequest`, `HTTPClient`, `StreamPeer*`, `WebSocket*`, `PacketPeer*`, `OS.shell_open` or `JavaScriptBridge` in the game or in White Kit; the only file written is `user://progress.json` (the language). | 16.7 and the privacy answers in `docs/store-listing.md` must be redone. |
| I5 | The option names in 16.3 are Godot 4.7.2's. Godot renames iOS options between minor versions. | Use the 4.7.2 option with the same meaning and record the name in 16.12. |

### 16.2 Files

| File | Change |
|---|---|
| `export_presets.cfg` | New preset `[preset.1]` "iOS" (16.3). The Web preset `[preset.0]` stays unchanged. |
| `export/.gdignore` | New, empty: keeps the icon PNGs out of the import and therefore out of the Web export. |
| `export/ios/icons/icon_<n>.png` | New: generated app icons (16.5), committed. |
| `tools/ios_icons.gd` | New: icon and blank launch image generator (`extends SceneTree`, headless). |
| `export/ios/blank.png` | New: transparent 64x64 launch image (16.6), committed. |
| `tests/ios_tests.gd` | New: preset and icon checks (16.11 A), registered in the game's test runner. |
| `.github/workflows/ios.yml` | New: the iOS workflow (16.8). Owned by the game, not from the kit template. |
| `.github/workflows/ci.yml` | Only `MIN_CHECKS` raised by the new checks. |
| `.gitignore` | Add `*.p12`, `*.p8`, `*.mobileprovision`, `*.cer`, `*.csr`, `*.key` (signing material never enters git). |
| `README.md` | Short section "iOS": what the workflow does, how to start it, the names of the secrets (never values). |

If the exporter cannot read files below a folder with `.gdignore` (found in step 1 of 16.9), remove `export/.gdignore`
and add `export/*` to the exclude filter of both presets instead.

### 16.3 Export preset "iOS"

Preset header:

```
[preset.1]

name="iOS"
platform="iOS"
runnable=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter="tests/*,tools/*,addons/white_kit/tests/*,addons/white_kit/tools/*"
export_path="build/ios/WhiteSum.ipa"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
```

`include_filter="*.json"` is required: the pool `data/practice.json` must be in the package, as on the web. The export
file name `WhiteSum` (no space) becomes the Xcode project and scheme name.

Options (`[preset.1.options]`); options not listed keep Godot's default:

| Option | Value | Reason |
|---|---|---|
| `custom_template/debug`, `custom_template/release` | `""` | Official templates from `setup-godot`. |
| `architectures/arm64` | true | The only iOS architecture. |
| `application/app_store_team_id` | `""` in git | Godot does not export without it; the `export` job writes `vars.APPLE_TEAM_ID` (16.8 E6). |
| `application/export_method_debug` | Development | Not used by the workflow. |
| `application/export_method_release` | App Store | |
| `application/code_sign_identity_debug` | `"Apple Development"` | Not used. |
| `application/code_sign_identity_release` | `"Apple Distribution"` | Also passed to `xcodebuild` (B5). |
| `application/provisioning_profile_uuid_debug`, `..._release` | `""` | `xcodebuild` gets the profile from the workflow (B5). |
| `application/bundle_identifier` | `"nl.steefbeest.whitesum"` | Owner's choice. |
| `application/signature` (if present) | `""` | |
| `application/short_version` | `""` in git | CI writes `config/version` (E6): `CFBundleShortVersionString`. |
| `application/version` | `""` in git | CI writes the run number (E6): `CFBundleVersion`. |
| `application/min_ios_version` | `"16.0"` | See below. |
| `application/targeted_device_family` | iPhone (value 0) | 16.6. |
| `application/export_project_only` | true | Export on Linux (ADR 0007). |
| `application/generate_simulator_library_if_missing` (if present) | false | Needs macOS tools; no simulator build. |
| `application/icon_interpolation` | Lanczos | Only used when an icon size has no exact file. |
| `application/additional_plist_content` | 16.4 | |
| `capabilities/*` | all false or empty | No Wi-Fi, push, Game Center or other capability. |
| `user_data/accessible_from_files_app` | false | Nothing for the player there. |
| `user_data/accessible_from_itunes_sharing` | false | |
| `privacy/*_usage_description` | `""` | No camera, microphone, photo library or location. |
| `privacy/tracking_enabled` | false | 16.7. |
| `privacy/tracking_domains` | empty | |
| `privacy/collected_data/*` | all off | 16.7. |
| `privacy/*_access_reasons` (required-reason APIs) | Godot defaults | The engine's own reasons; the game adds no such API. |
| `icons/*` | `res://export/ios/icons/icon_<n>.png` with `n` = the option's size | 16.5. Every icon option the 4.7.2 preset offers is set (dark and tinted variants excepted). |
| `storyboard/use_custom_bg_color` | true | 16.6. |
| `storyboard/custom_bg_color` | `Color(0.106, 0.122, 0.149, 1)` (`#1B1F26`) | Same as `boot_splash/bg_color`. |
| `storyboard/custom_image@2x`, `storyboard/custom_image@3x` | `res://export/ios/blank.png` | Transparent 64x64 file (16.6). An empty option makes Godot write its own logo splash. |

Minimum iOS version 16.0: runs on every iPhone from the iPhone 8 (2017) on, which covers the owner and the test group,
and stays inside the deployment range of Xcode 26. If Godot 4.7.2's default `min_ios_version` is higher than 16.0, use
Godot's default instead (the engine may need it) and record it in 16.12. Alternative 15.0 (adds iPhone 6s, 7 and the
first SE): rejected for now because nobody can test on iOS 15; lowering it later is a one-line change.

`project.godot` needs no change. Kept as they are: `display/window/handheld/orientation=1` (portrait),
`boot_splash/show_image=false`, `boot_splash/bg_color` `#1B1F26`, `rendering/textures/vram_compression/import_etc2_astc=true`,
and the iOS defaults `display/window/ios/hide_home_indicator`, `hide_status_bar`, `suppress_ui_gesture` and
`allow_high_refresh_rate` (all true; not written to the file because they are defaults).

`application/config/version` must be one to three dot-separated integers (`0.1.0` now); Apple rejects other forms. It
is raised by hand for a new TestFlight version line (for example `0.2.0` after the look-and-feel changes); the build
number never needs a hand edit.

### 16.4 Info.plist

Godot writes bundle id, versions, display name (from `config/name`: "White Sum"), orientations, device family,
minimum iOS version and the privacy manifest from the preset. `application/additional_plist_content` adds:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
<key>CFBundleLocalizations</key>
<array>
	<string>en</string>
	<string>nl</string>
</array>
```

- `ITSAppUsesNonExemptEncryption = false`: the app uses no encryption of its own (no network, no encrypted files,
  `encrypt_pck` false). App Store Connect then asks no export compliance question for each build.
- `CFBundleLocalizations`: the Dutch and English texts live in `SumStrings`, which iOS cannot detect; the key makes the
  App Store list both languages. Inside the game the kit's language button stays the way to switch.

If Godot 4.7.2 already writes one of these keys itself, leave it out here; check V in 16.8 requires every key exactly
once.

### 16.5 App icons

Source: `icon.svg` (128x128, a dark rounded square with three tiles). iOS applies its own rounded mask and rejects an
App Store icon with an alpha channel, so the iOS icons are full, opaque squares.

`tools/ios_icons.gd` (`godot --headless --path . -s res://tools/ios_icons.gd`):

- `static func render(n: int) -> Image`: `Image.load_svg_from_string(<text of res://icon.svg>, n / 128.0)` renders the
  SVG at `n x n`; the result is blended onto an `n x n` image filled with `#1B1F26` (the SVG's own background colour,
  so the SVG's transparent rounded corners become a full square), then converted to `Image.FORMAT_RGB8`. Every size is
  rendered directly from the SVG; nothing is scaled down from 1024.
- The main part writes `res://export/ios/icons/icon_<n>.png` for every size below and prints one line per file.
- Deterministic for the pinned Godot version (same rasteriser); the tests rely on it (A2).

Sizes in pixels: 1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20. This covers both a single-size asset
catalog (1024 only) and the older per-device list, whichever the 4.7.2 preset offers. iPad sizes (167, 152, 76) are
generated for completeness even though the build is iPhone only. Dark and tinted variants (iOS 18) stay empty; iOS
derives them. **[later]** own variants.

When `icon.svg` changes, run the tool and commit the PNGs; test A2 fails until then.

### 16.6 Devices, orientation, launch screen, safe area

- **iPhone only** (`targeted_device_family` iPhone). The game is a portrait 720-wide column; on an iPad it would be a
  narrow strip on a large screen, would need its own App Store screenshots (13-inch) and an iPad layout check. iPads
  can still install the iPhone app and run it in iPhone compatibility mode. Alternative "iPhone and iPad": rejected for
  now; **[later]** with a tablet layout.
- **Portrait only**: `display/window/handheld/orientation=1` gives `UISupportedInterfaceOrientations` =
  `UIInterfaceOrientationPortrait` only; no upside down.
- **Launch screen**: Godot's generated storyboard with background `#1B1F26`; the image view shows `export/ios/blank.png`,
  a transparent 64x64 file written by `tools/ios_icons.gd` (an empty `custom_image` option would make Godot copy its
  logo splash into `SplashImage.imageset`); the boot splash shows no image on the same colour. From the tap on the icon to the first frame the screen is one dark colour: no white flash,
  no Godot logo.
- **Safe area**: the screen already uses the kit's `WhiteSafeArea` (`_use_safe_area()` true, 10.3), which reads
  `DisplayServer.get_display_safe_area()`; on an iPhone that excludes the notch or Dynamic Island and the home
  indicator area. The status bar is hidden (Godot default). No code change; verified on a device (C4).
- **System gestures**: `suppress_ui_gesture` (default true) defers the system gestures at the screen edges, so a swipe
  on a bottom-row tile does not send the app home; `hide_home_indicator` (default true).
- **Renderer**: GL Compatibility as on the web; ETC2/ASTC import is already on. The game draws everything in code.

### 16.7 Privacy, tracking, encryption

- The app collects no data in Apple's sense (data that leaves the device): no network code (I4), no analytics, no ads,
  no crash reporter of its own, no accounts. The language choice stays on the device in `user://progress.json`.
- App Privacy in App Store Connect: **Data Not Collected**; tracking: no.
- Privacy manifest (`PrivacyInfo.xcprivacy`, written by Godot from the preset): `NSPrivacyTracking` false, no
  tracking domains, no collected data types; the engine's required-reason API entries as Godot writes them.
- Encryption: `ITSAppUsesNonExemptEncryption` false (16.4).
- Privacy policy text and URLs: `docs/store-listing.md` sections 6 and 7. The policy must be online before the first
  external TestFlight build is submitted. The promo site (repository `pulse`, `apps/white-sum-site` and the shared
  `packages/puzzle-site`) describes only the browser version today; adding the app privacy pages there is a follow-up
  outside this repository.
- Re-check this section before any feature with network access (phase 5).

### 16.8 Workflow `.github/workflows/ios.yml`

Triggers, guards and shared settings:

```yaml
name: iOS
on:
  workflow_dispatch:
    inputs:
      signing:
        description: "Sign the build (false: unsigned compile check, no secrets needed)"
        type: boolean
        default: true
      upload:
        description: "Upload to TestFlight (only with signing)"
        type: boolean
        default: true
  push:
    tags: ["v*"]
concurrency:
  group: ios
  cancel-in-progress: false
permissions:
  contents: read
```

- Both jobs have `if: github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/main' ||
  startsWith(github.ref, 'refs/tags/v')`.
- On a tag push the inputs are empty: signing and upload are on (`github.event_name == 'push' || inputs.signing`, and
  the same for upload together with signing).
- One `ios` concurrency group, never cancelled: runs queue, so build numbers reach App Store Connect in order.

Variables and secrets (values only in GitHub settings, never in the repository or in logs):

| Name | Kind | Content |
|---|---|---|
| `APPLE_TEAM_ID` | repository variable | The 10-character Team ID (an identifier, not a credential). |
| `IOS_DIST_CERT_P12_BASE64` | secret in environment `testflight` | Base64 of the `.p12` holding the Apple Distribution certificate and its private key. |
| `IOS_DIST_CERT_PASSWORD` | secret, `testflight` | Password of that `.p12`. |
| `IOS_PROFILE_BASE64` | secret, `testflight` | Base64 of the App Store Connect provisioning profile (`.mobileprovision`). |
| `ASC_KEY_ID` | secret, `testflight` | Key ID of the App Store Connect API team key. |
| `ASC_ISSUER_ID` | secret, `testflight` | Issuer ID of the App Store Connect API keys. |
| `ASC_KEY_P8_BASE64` | secret, `testflight` | Base64 of `AuthKey_<key id>.p8`. |

The environment `testflight` allows deployments only from `develop`, `main` and tags `v*`. The keychain password is
random per run (`openssl rand -hex 24`), not a secret.

**Job `export`** (`ubuntu-24.04`, timeout 30 minutes; no secrets):

| # | Step | Detail |
|---|---|---|
| E1 | Checkout | `actions/checkout@v6` with `submodules: true`. |
| E2 | Kit pin | The same step as in `ci.yml`. |
| E3 | Godot | `uses: ./addons/white_kit/ci/setup-godot` (unchanged). |
| E4 | Import and tests | Import, kit tests and game tests with the same commands and thresholds as `ci.yml` (`MIN_CHECKS` equal in both files). |
| E5 | Version | `version` = the value of `config/version` in `project.godot`; must match `^[0-9]+(\.[0-9]+){0,2}$`. On a tag push the tag must equal `v<version>`, else fail here. `build` = `github.run_number`. Both go to the step summary and to job outputs. |
| E6 | Fill the preset | In the runner's working copy of `export_presets.cfg` replace `application/short_version=""`, `application/version=""` and `application/app_store_team_id=""` by the version, the build and `vars.APPLE_TEAM_ID`. Each of the three lines must occur exactly once before the replacement (fail otherwise); the team id must match `^[A-Z0-9]{10}$`. Nothing is committed. |
| E7 | Export | `mkdir -p build/ios && touch build/.gdignore`; `timeout 600 godot --headless --path . --export-release "iOS" build/ios/WhiteSum.ipa`. Then require `build/ios/WhiteSum.xcodeproj/project.pbxproj` and at least one `.pck` below `build/ios`; list the tree two levels deep in the summary. |
| E8 | Artifact | `tar -czf build/ios-project.tgz -C build ios` (keeps permissions and links); upload as `ios-project`, retention 1 day. |

**Job `build`** (`macos-26`, `needs: export`, `environment: testflight`, timeout 45 minutes). Shell steps use
`set -euo pipefail`. Secrets enter as step `env`, are decoded into files under `$RUNNER_TEMP` and are never printed.
Steps marked "signing" are skipped in the unsigned mode.

| # | Step | Detail |
|---|---|---|
| B1 | Project | Download `ios-project`; `tar -xzf` into `build/`. |
| B2 | Xcode | Select the newest `/Applications/Xcode_26*.app` (`sort -V`) with `sudo xcode-select -s`; `xcodebuild -version` to the summary. None found: fail. |
| B3 | Certificate (signing) | Decode the `.p12`. Create `$RUNNER_TEMP/ios.keychain-db` with the random password, unlock it, set a 6-hour lock timeout; `security import` the `.p12` with `-T /usr/bin/codesign -T /usr/bin/security`; `security set-key-partition-list -S apple-tool:,apple: -k <password>`; add the keychain to the user search list (keeping the existing ones). `security find-identity -v -p codesigning <keychain>` must show exactly one valid identity whose name starts with `Apple Distribution`. If it shows none because the chain is incomplete, import Apple's WWDR intermediate certificate (G3, https://www.apple.com/certificateauthority/) and check again. |
| B4 | Profile (signing) | Decode the profile; `security cms -D -i <file>` into a plist; read `UUID`, `Name`, `TeamIdentifier:0`, `ExpirationDate` and `Entitlements:application-identifier` with `PlistBuddy`. Require `application-identifier` = `<team>.nl.steefbeest.whitesum` and `TeamIdentifier:0` = `APPLE_TEAM_ID`. Expired: fail. Expires within 30 days: `::warning::` with the date. Copy it as `<UUID>.mobileprovision` into both `~/Library/MobileDevice/Provisioning Profiles/` and `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (Xcode 16 and later read the second). |
| B5 | Archive | `xcodebuild archive -project build/ios/WhiteSum.xcodeproj -scheme WhiteSum -configuration Release -destination 'generic/platform=iOS' -archivePath build/ios/WhiteSum.xcarchive`, with signing: `CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=<team> CODE_SIGN_IDENTITY="Apple Distribution" PROVISIONING_PROFILE_SPECIFIER=<UUID> OTHER_CODE_SIGN_FLAGS="--keychain <keychain>"`; without signing: `CODE_SIGNING_ALLOWED=NO`. Output to `build/ios/archive.log`; on failure print its last 200 lines. If `xcodebuild -list` shows another scheme name, use that one and record it in 16.12. |
| B6 | Export options (signing) | Write `build/ios/ExportOptions.plist` with `PlistBuddy`: `method` = `app-store-connect`, `teamID` = team, `signingStyle` = `manual`, `signingCertificate` = `Apple Distribution`, `provisioningProfiles` = dictionary {`nl.steefbeest.whitesum`: `<UUID>`}, `uploadSymbols` = true, `manageAppVersionAndBuildNumber` = false, `destination` = `export`. |
| B7 | IPA (signing) | `xcodebuild -exportArchive -archivePath build/ios/WhiteSum.xcarchive -exportPath build/ios/export -exportOptionsPlist build/ios/ExportOptions.plist`, output to `build/ios/export.log`; exactly one `build/ios/export/*.ipa` must result. |
| V | Verify | On the app bundle (from the IPA with signing, from `WhiteSum.xcarchive/Products/Applications/*.app` without), each item failing the job: `CFBundleIdentifier` = `nl.steefbeest.whitesum`; `CFBundleShortVersionString` and `CFBundleVersion` = E5's version and build; `CFBundleDisplayName` (or `CFBundleName` when absent) = `White Sum`; `MinimumOSVersion` = the value of 16.3; `UIDeviceFamily` = `[1]`; `UISupportedInterfaceOrientations` = `[UIInterfaceOrientationPortrait]`, and any `UISupportedInterfaceOrientations~ipad` holds nothing else; `ITSAppUsesNonExemptEncryption` = false; `CFBundleLocalizations` = `[en, nl]`; each of these keys occurs exactly once in the Info.plist (`plutil -convert xml1`, then count); a `PrivacyInfo.xcprivacy` exists with `NSPrivacyTracking` false and `NSPrivacyCollectedDataTypes` empty or absent; a `.pck` is inside the bundle; every PNG in the exported `SplashImage.imageset` is at most 64x64 and has alpha; every PNG in the exported project's `AppIcon.appiconset` reports `hasAlpha: no` (`sips -g hasAlpha`) and one of them is 1024x1024. With signing also: `codesign --verify --deep --strict` passes; the entitlements (`codesign -d --entitlements -`) have `get-task-allow` false; the UUID of `embedded.mobileprovision` equals B4's. Results as a table in the summary. |
| U | Upload (signing and upload) | Write the `.p8` to `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`; `xcrun altool --upload-app --type ios --file <ipa> --apiKey <ASC_KEY_ID> --apiIssuer <ASC_ISSUER_ID>`; a non-zero exit fails the job. Summary: `Uploaded White Sum <version> (<build>)`. Fallback if `--upload-app` no longer exists in the selected Xcode: set `destination` = `upload` in B6 and pass `-authenticationKeyPath <p8> -authenticationKeyID <id> -authenticationKeyIssuerID <issuer>` to B7; record the switch in 16.12. |
| L | Logs on failure | `if: failure()`: upload `build/ios/*.log` as artifact `ios-logs`, retention 7 days (they hold no secrets). |
| C | Cleanup | `if: always()`: `security delete-keychain <keychain>`; remove both installed profile copies, the `.p8`, the decoded `.p12` and profile files. |

No IPA, archive or signed binary is kept as an artifact: the repository is public and TestFlight is the distribution
channel.

The owner's Apple-side setup (certificate created with `openssl` on Linux, profile, app record, API key, secrets,
tester groups) happens on the Apple and GitHub websites; its results are exactly the variable and secrets above.

### 16.9 Developer work

1. Spike for I1 and I5: add the preset, put a dummy team id (`ABCDE12345`) and versions into a scratch copy of the
   preset, and run the Linux export of E7 locally. Pass: `build/ios/WhiteSum.xcodeproj` exists and the exit code is 0.
   Note the 4.7.2 option names (icons, storyboard, privacy, simulator library) and the default `min_ios_version`.
   Fail: stop and report to the project lead (kit fallback, ADR 0007 decision 6). Never commit the dummy team id.
2. `tools/ios_icons.gd`, `export/.gdignore`; generate and commit the icons (16.5).
3. Preset `[preset.1]` "iOS" (16.3), in the editor or by hand; `git diff` shows no change inside `[preset.0]`.
4. `tests/ios_tests.gd` (16.11 A), `.gitignore` additions; raise `MIN_CHECKS` in `ci.yml` and use the same number in
   `ios.yml`.
5. `ios.yml` (16.8). First run on `develop` with `signing` false: needs no secrets; E1-E8, B1, B2, B5 and V must pass.
6. When the owner reports the account and secrets ready: a run with `signing` true and `upload` false, then one with
   `upload` true.
7. README section "iOS"; fill 16.12.

Done when: 16.11 A and B are met and the first build is in TestFlight. Group C is the device test by the owner and
the tester.

### 16.10 [later] App Store release

Not part of this work. Needed then: the store texts of `docs/store-listing.md` entered in both languages; the privacy
pages online; App Privacy "Data Not Collected"; the age rating questionnaire; screenshots for the 6.9-inch iPhone
(1320x2868 or 1290x2796 portrait). The kit's `shots.sh` caps scenarios at 1920x1440, so these screenshots need either
a kit change that raises its virtual screen (a White Kit card) or another capture route. Then the EU trader status
declaration and a review submission of a build from a `v<version>` tag. With an individual account the App Store page
shows the owner's legal name as seller, and a trader declaration publishes contact details in the EU; both are the
owner's decision before release.

### 16.11 Acceptance criteria

**A. Automated, every CI run on Linux** (`tests/ios_tests.gd`, counted in `MIN_CHECKS`):

- A1 `export_presets.cfg` (read with `ConfigFile`) has exactly one preset with `platform="iOS"`, named `iOS`, with:
  `export_path` `build/ios/WhiteSum.ipa`; `include_filter` containing `*.json`; `exclude_filter` equal to the Web
  preset's; `encrypt_pck` false; bundle id `nl.steefbeest.whitesum`; `targeted_device_family` iPhone;
  `export_project_only` true; `export_method_release` App Store; `code_sign_identity_release` `Apple Distribution`;
  `min_ios_version` as in 16.3; `app_store_team_id`, `short_version` and `version` empty (no team id and no hand
  version in git); `additional_plist_content` containing `ITSAppUsesNonExemptEncryption` followed by `<false/>` and
  `CFBundleLocalizations` with `en` and `nl`; `privacy/tracking_enabled` false; storyboard custom background on with
  colour `#1B1F26`; every non-empty `icons/*` option points to an existing file under `res://export/ios/icons/`, and
  the 1024 option is set.
- A2 The 13 icon files of 16.5 exist; each loads as `n x n`; format `FORMAT_RGB8` and `detect_alpha()` is
  `ALPHA_NONE`; the corner pixels `(0, 0)` and `(n-1, n-1)` are `#1B1F26` (each channel within 1/255); for `n` in 1024,
  180 and 120 the pixels equal `render(n)` of `tools/ios_icons.gd` (icons up to date with `icon.svg`).
- A3 The Web preset is unchanged (name, platform, export path, filters, options) and the Web export in `ci.yml` stays
  green.
- A4 `git ls-files` contains no `*.p12`, `*.p8`, `*.mobileprovision`, `*.cer`, `*.csr` or `*.key` file (tester).

**B. Workflow** (tester runs it or inspects the workflow and run logs):

- B1 A push to `develop` or a pull request does not start `ios.yml`; `ci.yml` differs only in `MIN_CHECKS`.
- B2 A manual run on `develop` with `signing` false is green without any secret; the summary shows version `0.1.0`,
  the build number and the Xcode 26 version; V passes its unsigned checks.
- B3 A manual run from any other branch skips both jobs.
- B4 A tag that is not `v<config/version>` fails in E5; the `build` job does not run.
- B5 A run with `signing` true and `upload` false is green including the signing checks of V; there is no IPA artifact;
  no secret value appears in the log.
- B6 A run with `upload` true is green, and the build `0.1.0 (<run number>)` appears in TestFlight in App Store Connect
  without "Missing Compliance".
- B7 Step C (cleanup) has `if: always()` and deletes the keychain, profiles, `.p8` and `.p12`; on a failed run it shows
  as executed.
- B8 Consecutive uploads have increasing build numbers. Re-running a job whose upload already succeeded fails in U
  with a duplicate build message (expected; start a new run).

**C. Device** (the owner and the tester, iPhone, through TestFlight):

- C1 Installs through TestFlight; the home screen shows the White Sum icon as a full square under the iOS mask, without
  light or dark corner artefacts; the label reads "White Sum".
- C2 Cold start: one dark `#1B1F26` screen from launch to the first frame, no white flash, no logo; the game opens on a
  pool set.
- C3 Turning the phone does not rotate the game.
- C4 On an iPhone with a notch or Dynamic Island: title, tabs, counter, board, message line and buttons are fully
  visible; nothing sits under the island, the status area or the home indicator. The same on an iPhone without a notch
  when one is available.
- C5 Swipe, tap-tap with selection totals, Undo, Restart, Next and Best route behave as in the web version; a swipe on
  a bottom-row tile does not leave the app.
- C6 The language choice survives closing the app from the app switcher.
- C7 With flight mode on, everything works.
- C8 After switching to another app and back, the same puzzle and position are shown.
- C9 The app never asks for a permission or for tracking consent.
- C10 An external tester outside the team installs the app through the public link after the beta review.

**D. Store texts** (tester, on `docs/store-listing.md`): name and subtitle at most 30 characters, promotional text at
most 170, keywords at most 100 and without the words of the app name, description at most 4000; no feature promised
that phase 1 does not have (no daily puzzle, no leaderboards); both languages say the same.

### 16.12 As built

Filled in 2026-11-19 from the local Linux spike (Godot 4.7.2, official templates); the macOS job has not run yet.

- I1 holds: `--export-release "iOS"` with `export_project_only` exits 0 on Linux; the only message is the warning
  that the `.ipa` can be built on macOS only. I2 holds (`ios.zip` in the templates). I3 is open until the first CI run.
- Default `min_ios_version` of 4.7.2 is 15.0; the preset sets 16.0 (design value). Scheme name: `WhiteSum`
  (`xcshareddata/xcschemes/WhiteSum.xcscheme`). Xcode version: to be filled after the first CI run.
- Icons: 4.7.2 has no per-device size list of 13 but these options: `icon_1024x1024`, `app_store_1024x1024`,
  `ios_128x128`, `ios_136x136`, `ios_192x192`, `ipad_152x152`, `ipad_167x167`, `iphone_120x120`, `iphone_180x180`,
  `notification_40x40|60x60|76x76|114x114`, `settings_58x58|87x87`, `spotlight_80x80|120x120`. Sizes 114, 128, 136 and
  192 are not in the list of 16.5, so the tool also renders them (17 files in all); an unset option would be scaled
  from the alpha-carrying `icon.svg`. Sizes 20 and 29 are generated but no option uses them. File names are
  `icon_<n>.png`; the options `icon_1024x1024` and `app_store_1024x1024` both point to `icon_1024.png`.
- Enums in the file: `export_method_*` 0 App Store, 1 Development; `targeted_device_family` 0 iPhone;
  `icon_interpolation` 4 Lanczos. Not set, so at Godot's defaults: `capabilities/*`, `privacy/collected_data/*`, the
  usage descriptions and access reasons. `generate_simulator_library_if_missing` does not exist in 4.7.2.
- Godot 4.7.2 already writes `ITSAppUsesNonExemptEncryption` = false itself, so `additional_plist_content` holds only
  `CFBundleLocalizations` (16.4); `tests/ios_tests.gd` fails if the key is added again.
- `export/.gdignore` works: the exported `.pck` holds no icon PNGs and `data/practice.json` is in it; the Web export is
  unchanged.
- Exported project: device family `"1"`, deployment target 16.0, all icons in `AppIcon.appiconset` RGB without alpha, launch
  storyboard colour #1B1F26, `PrivacyInfo.xcprivacy` with `NSPrivacyTracking` false.
- Godot prints "Property not found: application/boot_splash/fullsize" during the iOS export; harmless.
- Unsigned run without the repository variable: `ios.yml` uses the placeholder team id `ABCDE12345` (Godot needs one);
  with signing it fails when `APPLE_TEAM_ID` is missing.
- Launch image (review finding): with empty `storyboard/custom_image@2x|3x` Godot 4.7.2 writes its logo splash
  (800x600) into `SplashImage.imageset`. Both options now point to `res://export/ios/blank.png` (transparent 64x64,
  written by `tools/ios_icons.gd`); the export then holds 64x64 transparent splash files. `tests/ios_tests.gd` checks
  both options and that the file is up to date; the Verify step of `ios.yml` checks the exported splash PNGs.
- Empty usage descriptions: Godot 4.7.2 always writes `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` and
  `NSMicrophoneUsageDescription` (empty strings when the `privacy/*_usage_description` options are empty); no option
  omits them. Left as is; if App Store Connect warns on upload, the fix is a `plutil -remove` step on the exported
  Info.plist before the archive.
- `ios.yml` build job: `environment: testflight` is also used with signing=false, so the environment must exist with a
  deployment rule for develop, main and `v*`. The profile expiry date is parsed with BSD `date -j`, verified on macOS
  only.
