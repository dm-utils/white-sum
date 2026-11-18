# Glossary

Terms used in the code, the design (`docs/design.md`) and the ADRs. Code names in brackets. Terms shared by the whole
series (attempt, record, count mode, progress file, seed text, tile view, ...) are defined in White Kit's glossary
(`addons/white_kit/docs/glossary.md`); they are repeated here only where White Sum adds something. Terms marked
[later] belong to phases after phase 1.

| Term | Meaning |
|---|---|
| Attempt (`WhiteAttempt`) | One player's go at one puzzle, from White Kit, with a `SumBoard` as rules. |
| Beam prefilter | A cheap beam search (width 30) before the exact search; a line shorter than the par band rejects the candidate at once, otherwise it is the starting line of the exact search. |
| Beam search (`SumSolver.beam`) | Search that keeps the best few states per depth; prefilter, and fallback when the exact search hits its budget. |
| Best route | The stored solution (`path`), shown as an animation after solving. |
| Board (`SumBoard`) | Board size, start position and the rules (moves, settling, tens); implements `WhiteRules`. |
| Breaking reverse move | The reverse move in an insertion step that turns the inserted ten into a stable predecessor. |
| Canonical move | The single spelling of a move: horizontal swap as `R` from the left cell, vertical swap as `U` from the lower cell, slide as `R` or `L` from the moving tile. As White Tally. |
| Cell name | Upper-case column letter plus row digit, `A1` bottom-left. |
| Chain | A resolution with more than one wave: after a wave, falling tiles or a gap or join in a row form a new ten. |
| Chain insertion | Generator step that inserts two tens so that, forward, one vanishes and the other becomes a ten again. |
| Column run | A maximal set of vertically touching tiles in one column; on a settled board the whole stack. |
| Column ten | A column run with total 10. |
| Count | The number shown: moves on the current line in phase 1 (`FINAL_ONLY`); [later] every move for daily puzzles. |
| Cross | A tile that is part of a row ten and a column ten in the same wave; removed once, together with both tens. |
| Daily set | [later] The three puzzles of one Dutch calendar day. |
| Dead end | A non-empty board without any move. Reported on the message line. |
| Exact par (`exact`) | Par proven minimal because the exact search completed within budget. |
| Expansion | One solver step: generating the children of one position. The solver budget counts expansions. |
| Fallback | The generator's nearest candidate when none fits the level; marked `"fallback": true`. |
| Game id | `white-sum`; first part of the seed texts. |
| Gap | An empty cell inside a row, between tiles. A gap splits a row into separate runs; closing it joins them. |
| Greedy gap | Filter: the greedy bot must not solve the puzzle in fewer than par plus this number of moves. |
| Greedy (`SumSolver.greedy`) | A bot that always plays the move removing the most tiles and gives up when none removes anything. |
| Ignored action | Input that is not a move or is a no-op (for example swapping equal values). Not counted, not recorded. |
| Insertion step | Generator step: insert a ten backwards (row or column), then apply a breaking reverse move. |
| Level | Easy (0), medium (1) or hard (2); each has its own board size, generator settings and par band. |
| Look and feel | Phase 1: playable pool puzzles to test controls, animations, readability and the ten rule; no date binding or strict scoring. |
| Move | A swap or a slide. Every move changes the board and counts. |
| Move code | Integer `cell index * 4 + direction` (`R=0, L=1, D=2, U=3`). |
| Move token | Three upper-case characters for one move: direction, column letter, row digit (`RC1`). |
| Numeral | The digit 1 to 5 drawn on a tile; the primary signal of its value. |
| Over run | A run whose total is larger than 10. Does not vanish; must be split by a gap or changed by a swap. |
| Par | The fewest moves found by the solver; exact unless the puzzle says `exact: false`. |
| Par band | The range of par a generated puzzle must fall in for its level. |
| Pool | The precomputed puzzles of phase 1: 40 sets of three levels in `data/practice.json`. |
| Quiet step | Generator step: a reverse move after which, forward, nothing vanishes. |
| Record | Kit action string: move tokens, `z` undo, `r` restart, e.g. `RA1zRC1LD1`. |
| Resolution | What follows a move: settle, then waves of vanishing tens with settling in between, until stable. |
| Reverse building | The generator method: start from an empty board and build the puzzle backwards with verified reverse steps. |
| Row run | A maximal set of horizontally touching tiles in one row, ending at an empty cell or the edge on both sides. |
| Row ten | A row run with total 10. |
| Run | A row run or a column run. |
| Run totals at a cell (`SumBoard.run_totals_at`) | The totals of the row run and the column run through one cell; the sums shown when a tile is selected (phase 1b). |
| Selection totals | The two total pills (and bands) the board view shows for the selected tile: the sum of its row run and of its column run (`SumBoardView.selection_marks`). |
| Settle | Let every tile fall straight down in its column. |
| Share line | [later] One line with the day's counts and pars, e.g. `White Sum #12 · 4/6/9 moves (par 3/5/7)`. |
| Short run | A run whose total is smaller than 10. Does not vanish. |
| Slide | Move a tile sideways into an empty neighbouring cell; it then falls. |
| Solver (`SumSolver`) | Iterative deepening search with a transposition table that computes par and a solution path. |
| Stable | Settled and without tens. Every start position and every position after a move is stable. |
| State | `PackedByteArray` of `w * h` cells, value 0 (empty) or 1 to 5, index `y * w + x` with `y` upwards. |
| Swap | Exchange two neighbouring tiles with different values. |
| Target (`SumBoard.TARGET`) | The total that makes a run vanish: 10. |
| Ten | A run whose total is exactly 10. All tens of a board vanish together in one wave. |
| Tile | A square with a value from 1 to 5, shown as a numeral. |
| Total | The sum of the values in a run. |
| Total pill | The small rounded label with a run's total, placed in the empty cell after the run (or on the edge seam). |
| Trial | The measurement run (`tools/measure.gd`): phase 1 checks P1-P4, [later] full gates before date binding. |
| Upper bound (`upper`, `U`) | Number of reverse steps the generator used; the length of a known solution and a maximum for par. |
| View step | Kit step for the board view (`move` or `vanish`); `SumBoardView.to_view_steps` converts the traced step into these. |
| Wave | One round of removing the union of all tens at the same time. |
| White Kit | The shared base of the White puzzle games, a submodule at `addons/white_kit`. |
