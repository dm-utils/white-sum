# 0005 Numerals on calm tiles, no links

Status: accepted (2026-11-18)

## Context

The look must be flat, abstract, dark and calm like the rest of the series and readable on a phone. White Tally shows
values as pips and gives each value its own colour, because its groups are made of equal values; its test noted that
pips on rounded squares read as dice faces. In White Sum different values work together in one run, and the player has
to add them up quickly.

## Decision

- Each tile shows its value as a large numeral (52% of the cell), light on a dark tile.
- One cool hue for all tiles, slightly lighter for higher values (five small steps). Colour is a quiet hint, not a
  grouping signal.
- No link bars between tiles: a run is a straight line of touching tiles, readable from the gaps.
- Vanishing is a quiet fade and shrink; no particles, flashes or score pop-ups. No fruit, sweets, gems, coins or dice.

## Alternatives considered

- **Pips** (as White Tally): counting pips to add them up is slow, and the dice association gets stronger with five
  values. Rejected.
- **A distinct colour per value**: suggests that equal colours belong together, which is White Tally's rule, not this
  one. Rejected.
- **Link bars between all touching tiles of a run**: every pair of neighbours would be linked (all tiles in a row
  touch), so the bars carry no information and add clutter. Rejected.
- **Show the total of every run on the board**: helps reading, but takes the arithmetic away and clutters the board.
  Not in phase 1; an open question for the look-and-feel test (design 15).
- **Bar lengths or dot rows instead of numerals**: harder to add up than digits for the age group. Rejected.

## Consequences

- The board view only needs a body and a face hook (kit `WhiteTileView`); no link drawing.
- Readability at 360x640 is an acceptance criterion; the font size is a tunable value in `ui/board_view.gd`.
- The series keeps one visual family (same board, spacing, radius, timings) while each game has its own tile marks.
