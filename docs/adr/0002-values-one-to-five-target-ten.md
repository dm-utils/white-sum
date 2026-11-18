# 0002 Tile values 1 to 5, target 10

Status: accepted (2026-11-18)

## Context

The ten rule (ADR 0001) needs a range of tile values and a target. The choice decides how long typical runs are, how
much mental arithmetic a move needs, how many different tens exist, and whether single tiles could ever vanish.

## Decision

- Tile values 1, 2, 3, 4, 5. Target 10, as a constant (`SumBoard.TARGET`) so later phases can try another target
  without changing the code structure.
- Typical tens have 2 to 4 tiles (5 + 5, 4 + 3 + 3, 2 + 3 + 1 + 4). A single tile never vanishes.

## Alternatives considered

- **Values 1 to 9**: most tens become pairs (1 + 9, 2 + 8, ...), so the puzzle turns into "find the partner" and runs of
  three or four, where the planning happens, are rare. Rejected.
- **Values 1 to 3**: tens need four to ten tiles, longer than many rows; boards would be large and dense. Rejected.
- **Values 1 to 6** (dice range): one more value to read and a stronger association with dice, which the White Tally
  test flagged as a look risk. Rejected for phase 1; kept as an option for later (design 15).
- **Target varying per puzzle or per level** (8, 10, 12): one more thing to read before every puzzle; 10 is the number
  children already practise ("make ten"). Rejected for phase 1; the constant keeps it open.

## Consequences

- Arithmetic stays within "make ten" for young players; the five values fit numerals that are readable on a phone.
- The generator draws tens as compositions of 10 into 2 to 5 parts of 1 to 5 (design 5.4).
- Value colours are not needed for grouping; the look uses numerals with a gentle colour ramp (ADR 0005).
