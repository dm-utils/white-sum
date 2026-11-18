# 0003 Moves and gravity as in White Tally

Status: accepted (2026-11-18)

## Context

White Sum needs a move set. White Tally's (swap two neighbouring different tiles, or slide a tile sideways into an
empty cell, under gravity) is built, tested and has been tried in its look-and-feel prototype. The series should feel
like one family on the same screen, and the developer can reuse code only when the moves are the same.

## Decision

- White Sum uses White Tally's board model and moves unchanged: gravity down; swap of two orthogonal neighbours with
  different values; slide left or right into an empty cell, after which the tile falls; equal-value swaps, vertical
  moves into empty cells and moves off the board are ignored; the canonical form and the three-character tokens
  (`RC1`) are White Tally's.
- Resolution is settle, find tens, vanish the union, repeat (design 2.5).

## Alternatives considered

- **No gravity, tiles stay where they are** (islands on a tray): makes the connected-component rule possible, but every
  move moves one tile one cell, so solutions get long, the branching factor is high, and there are no chains. Rejected.
- **Slides only** (no swaps): fewer moves per position (faster exact par), but the swap is the move that changes a row
  total while keeping the column, and the other way round, which is the core trade-off of the ten rule. Rejected.
- **Tilt the whole board** (four moves): that is White Drift's move; two games with the same move would compete.
  Rejected.
- **Free placement** (pick any top tile and drop it on any column): resembles sorting puzzles and makes every tile
  reachable in one move, removing most planning. Rejected.

## Consequences

- The rules core (`canonical`, `legal_moves`, `_move_only`, settle) and the reverse moves of the generator are copied
  from White Tally (ADR 0006); only finding what vanishes and the insertion step change.
- Players of White Tally know the controls already; the board view input mode is the kit's `CELL_MOVES`.
- Branching is similar to White Tally's (about 25 to 35 moves per position), so exact par must be bought with lower
  par bands and fewer tiles (ADR 0004).
