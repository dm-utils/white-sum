# 0004 Reverse-building generator with tens; par exact where feasible, bands chosen for it

Status: accepted (2026-11-18)

## Context

White Sum needs puzzles that are solvable, of a controlled difficulty, with a par. White Tally's reverse-building
generator guarantees solvability and an upper bound; its trial (White Tally design 5.9) showed:

- The generator's own line was about twice the true par, so many candidates were needed for the hard band, and a beam
  prefilter (added during the trial) was necessary to reject candidates whose par is too low without a full search.
- The exact search managed about 1 800 expansions per second; hard puzzles (par 8 to 10, 24 tiles) were bounded for all
  50 seeds at the budget that kept the pool build under two hours. Easy and medium (par 3 to 6) were exact.

The cost of proving par is roughly the branching factor to the power `par - 2`. White Sum's branching is similar to
White Tally's (same moves). There is no useful admissible lower bound for an A* style search: one move can clear many
tiles through chains and crosses.

## Decision

- Generator: White Tally's reverse building with tens. An insertion step inserts a row ten (a maximal row run of new
  tiles at one height, adding up to 10) or a column ten (a new stack in an empty column), verifies by forward
  simulation, then applies a breaking reverse move. Chain insertions and quiet steps as White Tally. Specification:
  design 5.4.
- Solver: White Tally's iterative deepening search with a transposition table, beam fallback and greedy bot,
  unchanged. Par is exact when the search completes within budget, otherwise bounded (`exact: false`). Phase 1 accepts
  bounded par for every level; phase 2 decides per level through gates (design 5.8).
- Exactness is designed in rather than hoped for:
  - lower par bands than White Tally (2-3 / 4-5 / 6-7) and boards of 5x5 and 6x6 with fewer tiles; difficulty comes
    from adding up, gaps and crosses;
  - the beam prefilter is part of the specified filter order (design 5.6), and the exact search runs only on candidates
    that passed every cheap check;
  - the pool is built in up to 8 parallel processes; the time limit is wall-clock;
  - throughput is measured first (M1) with a threshold that triggers profiling before the trial;
  - exactness per level is reported in the trial (P4) with a target, so the decision for phase 2 rests on numbers.

## Alternatives considered

- **Forward generation (random boards) plus search**: random boards are rarely clearable (every tile must end in a ten),
  and proving unsolvability needs a complete search. Rejected.
- **Par = generator upper bound `U`**: free, but often far above the true par. Rejected.
- **Always bounded par (beam only)**: cheap, but "exactly par" loses meaning for a daily puzzle. Allowed in phase 1,
  not as a design target.
- **IDA* with a heuristic**: no admissible heuristic of useful strength exists for this rule (a single move can clear
  the board through a chain). Rejected.
- **An offline solver in another language** (for example Python or a native extension) for speed: a second
  implementation of the rules that must stay identical, and the tests in Godot would no longer prove the published
  par. Rejected for phase 1; revisit if phase 2 gate B fails.
- **White Tally's bands (3-5 / 5-8 / 8-12)**: hard would be bounded for nearly every puzzle. Rejected.

## Consequences

- Every puzzle is solvable by construction; `upper` and one solution path are stored.
- Easy and medium are expected exact; hard (par 6-7) is expected exact for par 6 and partly bounded for par 7; the
  trial measures it.
- If the medians do not increase with the lower bands, the trial adjusts `I`/`Q` and boards within the ranges of
  design section 4.
- The generator and solver are copies of White Tally's with known behaviour; fixes are shared both ways (ADR 0006).
