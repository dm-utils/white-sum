# 0001 What vanishes: maximal row and column runs that add up to 10

Status: accepted (2026-11-18)

## Context

The owner's idea: like White Tally, but an orthogonally connected group vanishes when the sum of its values is exactly
a target number (proposal: 10). With tiles of different values, "group" needs a new definition. It must be exact and
deterministic (one possible outcome for every board), easy to explain to a ten-year-old in 30 seconds, cheap to compute
in the solver's inner loop, and different enough from White Tally to be a game of its own. The board keeps White
Tally's gravity and moves (ADR 0003).

## Decision

- A **run** is a maximal set of touching tiles in one row (row run) or in one column (column run). On a settled board a
  column run is the whole stack.
- A run whose values add up to exactly 10 is a **ten**. After every move and settle, all tens vanish together; a tile in
  a row ten and a column ten (a cross) is removed once. Then settle and repeat (chains).
- Runs with a larger total (over) or a smaller total (short) never vanish, and no part of them does.
- Rule text for players: "A row or column of touching tiles that adds up to exactly 10 vanishes."

## Alternatives considered

- **A connected component of all non-empty tiles** (any values): under gravity every non-empty column touches its
  neighbours along the floor, so the board is one component until a whole column empties; vanishing would depend only
  on the board total. Degenerate. Rejected.
- **Any connected subset that adds up to 10** (polyomino of any shape): many overlapping subsets, so the outcome needs
  priority rules (largest first? leftmost?) that a player cannot apply at a glance, and finding all subsets is
  exponential. Rejected.
- **Same-colour components whose values add up to 10** (tiles carry a colour and a value): precise, but two attributes
  per tile hurt readability, and the game becomes "White Tally with weights". Rejected.
- **Rows only** (no column runs): keeps the board total a multiple of 10 after every wave, but loses the column drop
  ("put the 5 on the 5", design Example 3) and the cross (Example 2), which give the rule its depth. Rejected.
- **Runs of a fixed length** (for example exactly three tiles adding to 10): an extra condition to remember; maximal
  runs already exclude single tiles because the largest value is 5. Rejected.
- **Remove only one ten per wave, chosen by a priority** instead of the union: needs an order rule and makes crosses
  confusing. Rejected; the union is unique.

## Consequences

- The set of tens of a board is unique; resolution is deterministic without any ordering rule.
- Over runs are the counterpart of White Tally's overfull groups: more is not better, and opening a gap is a tool.
- Because of crosses the board total is not an invariant; there is no cheap solvability test. The generator builds
  solvable puzzles backwards (ADR 0004), so none is needed.
- Finding tens is linear in the board size (one pass over rows, one over columns), cheap enough for the solver.
- Distinct from White Tally: straight lines instead of shapes, mixed values instead of equal ones, adding up instead
  of counting (design 2.9). The phase 1 look-and-feel test checks whether this is fun or feels like homework.
