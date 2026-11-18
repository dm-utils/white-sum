# 0006 White Kit for the shell, a copy of White Tally's rules core, precomputed puzzles

Status: accepted (2026-11-18)

## Context

White Kit provides the screen, attempt and record, puzzle store, precompute tool, test runner and CI template. Kit
0.3.0 (kit ADR 0007) adds a tile view base class, safe area, maximum content width and screenshot tools. White Tally's
`sim/` holds a working board with the same moves and gravity, a solver and a generator. The kit decided not to share
rules, solvers or generators between games (hot paths, game-specific differences, White Tally's puzzles must stay
byte-identical).

## Decision

- White Sum pins White Kit: `v0.2.0` during phase 1a (rules, solver, generator, pool; nothing from 0.3.0 is needed),
  `v0.3.0` from phase 1b (screen, view, play version).
- `sim/board.gd`, `sim/solver.gd`, `sim/generator.gd` and `sim/game.gd` start as a copy of White Tally's, renamed and
  adapted (design 5). The copy is recorded in the first commit; fixes to the copied parts are checked in both games.
- The board view extends `WhiteTileView` (`CELL_MOVES`); the screen extends `WhiteDayScreen` in practice-only mode.
- Puzzles are precomputed with `WhitePrecompute` and shipped in `data/practice.json`; the game never searches.
- Records follow the kit grammar with three-character tokens; phase 1 counts `FINAL_ONLY`, the daily puzzle later
  `EVERY_MOVE`, through the kit hook.

## Alternatives considered

- **Write the rules core from scratch**: the same code with new bugs; White Tally's core has an independent oracle test
  and a tested canonical form. Rejected.
- **A shared rules module in the kit**: rejected by the kit (ADR 0007 there): different vanish rules, hot paths behind
  callbacks, and White Tally's migration risk.
- **Copy White Tally's board view instead of using the kit's base class**: duplicates about 600 lines and the desktop
  and safe-area fixes. Rejected.
- **Generate puzzles on the device**: the solver takes seconds to minutes per puzzle on a desktop. Rejected.
- **Wait for kit 0.3.0 before starting**: delays the rules and the trial, which are the riskiest part. Rejected; phase
  1a runs on 0.2.0.

## Consequences

- Phase 1a can start at once and in parallel with the kit 0.3.0 work; phase 1b waits for the `v0.3.0` tag.
- Two copies of the rules core exist (Tally, Sum). Conventions require a cross-check for fixes.
- The repository is public, so all puzzles and solutions are readable; acceptable until a server provides daily
  puzzles.
