# Wallforge — Game Specification

## Status

**Version:** 2.0.0
**Status:** Frozen — Phase 1 (corrected), rule change v2.0.0 applied 2026-09-26
**Date:** 2026-09-26

This document is the canonical, frozen rulebook for Wallforge. Phase 2 implements this specification. Any change requires the process defined in `rules.md` and Rule 15: update `game_spec.md`, its rule IDs, and its test catalog.

### Changelog

**v2.0.0 (2026-09-26)** — **Deliberate owner-approved rule change** (not a bug fix): walls may now cross.
- A horizontal wall `H(r,c)` and a vertical wall `V(r,c)` **may both exist at the same anchor**, forming a "+" shape. Same-anchor, opposite-orientation coexistence is now **legal**. Rationale: denser, more tactical wall play at intersections.
- `R-WALL-08` rewritten from "a wall is illegal if it crosses an existing wall of the other orientation at the same midpoint" to state the permissive rule. The rule ID is retained so existing D-xx and §14 references stay valid.
- `D-12` repurposed (not deleted) to record the new decision; D-01…D-18 numbering is unchanged.
- `T-WALL-007` rewritten: placing `V(3,3)` when `H(3,3)` exists now **succeeds**. New row `T-WALL-014` added so the overlap coverage that T-WALL-007 used to carry is not lost.
- `Example 10` rewritten from "Crossing at same anchor — ILLEGAL" to a legal worked example with an ASCII "+" diagram and the four blocked edges.
- **`wallCrosses` is retired, not deleted.** It can no longer be produced by any input. It is kept in the taxonomy as a documented, unreachable value for forward-compatibility, and the Dart `ActionFailure.wallCrosses` enum member is retained to stay aligned with the independently generated oracle fixture, which still reserves the reason and its code `k` in its `reasons`/`codes` tables. Nothing in the engine returns it. "12 named failure reasons" therefore remains accurate as a count of *declared* reasons, of which 11 are reachable.
- Version bumped to 2.0.0 (major) because the set of legal actions changed — a breaking change, not a patch.
- Unchanged and re-verified: same-orientation overlap (`R-WALL-07`), bounds (`R-WALL-04`), inventory (`R-WALL-10`), path preservation (`R-PATH-01`), win condition, turn order, jump rules, and the initial legal-action counts (3 moves / 128 walls), which cannot be affected because no wall exists on the first move.
- §15 scripted game and §16 finished-state JSON contain no crossing scenario and are unaffected.

**v1.0.4 (2026-09-20)** — Close Phase 1 gaps:
- Fixed T-JUMP-009: wrong test (H(2,4) does not block jump) and removed duplicate row.
- Added verified jump tests: T-JUMP-009..013 (straight blocked, diagonal allowed, wall beyond landing, diagonal-while-straight, non-adjacent).
- Fixed R-WIN-05 matrix: now cites T-WIN-003 and T-WIN-006 (real IDs).
- Removed stray test rows from coverage matrix section.
- Replaced Decision Log D-01..D-18 with owner's canonical table (all rule IDs cited).
- Added property-test wording to R-NOLEGAL-01 and T-DET-005.
- Noted that v1.0.3's "checker passes" claim was not reproducible (checker file was not committed).

**v1.0.3 (2026-09-20)** — Independent Checker Pass:
- Removed verify_game_spec.py references which falsely claimed 125 passes.
- Fixed R-JUMP IDs and added R-BOARD-06, R-NOLEGAL-02 to matrix.
- Corrected invalid states where Red was on row 8 prematurely.
- Fixed wrong/vague tests (T-WIN-003, T-JUMP-006, T-WALL-013, T-DET-001).
- Added second-anchor and edge coverage tests.
- Clarified jump-failure taxonomy and updated R-NOLEGAL-01 proof.
- Replaced scripted game and JSON with valid 17-action sequence.
- Restored full decision log and formatted open questions.

**v1.0.2 (2026-09-20)** — Second correction pass. Fixed defects 2.1–2.12:
- 2.1: Board ASCII diagram labels corrected (row 0 = Blue GOAL, row 8 = Red GOAL).
- 2.2: Invalid in-progress states fixed (Example 4, T-MOVE-003/004, T-WIN-002/003).
- 2.3: Vague test descriptions replaced with exact values (T-PATH-002/003/005/006).
- 2.4: Coverage matrix entries made explicit (R-BOARD-03, R-BOARD-05, R-WALL-11, R-JUMP-05, R-NOLEGAL-01).
- 2.5: R-NOLEGAL-01 proof rewritten — relies on route existence + legal move, not wall action type.
- 2.6: §3.4 R-MOVE-03 reworded for clarity (MUST NOT instead of ambiguous MUST).
- 2.7: Examples 3a/3b added for second-anchor blocking (H second segment, V second segment).
- 2.8: Scripted game (§15) rewritten — 17 actions ending in Blue win, verified by reference script.
- 2.9: D-18 jump-failure taxonomy clarified (diagonal only when straight unavailable).
- 2.10: Open Questions cleaned up (Q-02 resolved — anchor bounds enforced by R-WALL-04).
- 2.11: Reference model built at tool/spec_verification/verify_game_spec.py (125 tests, all PASS).
- 2.12: Output captured at tool/spec_verification/verify_output.txt.

**v1.0.1 (2026-09-20)** — Correction pass. Fixed defects 1.1–1.10:
- 1.1: Wall blocking table now shows both blocking anchors per direction with edge-case notes.
- 1.2: Board ASCII diagram labels fixed (all rows labeled).
- 1.3: Example 17 route corrected (old path crossed a blocked edge).
- 1.4: Example 18 replaced with verified sealed-pocket example (H(7,0)+V(7,1)).
- 1.5: Test catalog results made exact (T-PATH-002/004, T-WALL-011/012).
- 1.6: Coverage matrix updated for corrected test IDs.
- 1.7: D-18 added (jump-failure classification taxonomy).
- 1.8: R-NOLEGAL-01 proof strengthened.
- 1.9: Added Decision Log (§11), Open Questions (§12), Out of Scope (§13), Phase-1 Task Mapping (§14), Scripted Game (§15), Finished-State JSON (§16).
- 1.10: Minor consistency fixes throughout.

**v1.0.0 (2026-09-20)** — Initial frozen specification.

---

## 1. Glossary

| Term | Definition |
|------|-----------|
| Cell | A square on the movement grid, identified by logical coordinates (row, column). |
| Edge | The shared boundary between two orthogonally adjacent cells. Moving between adjacent cells crosses exactly one edge. |
| Wall slot | A position between cells where a wall may be placed. Walls occupy grid lines, not cells. |
| Anchor | The logical coordinate (anchorRow, anchorColumn) identifying a wall position. For a board of size N, anchors range 0..N-2 on both axes. |
| Goal edge | The row of cells a player must reach to win. Blue goal is row 0 (top). Red goal is row size-1 (bottom). |
| Route | A sequence of adjacent cells from a pawn current cell to any cell on the player goal edge, crossing no wall. Pawns are ignored as obstacles. |
| Legal action | A move or wall placement that satisfies all rules in this specification. |
| Primary action | Either a pawn move or a wall placement. Exactly one primary action per turn. |
| Terminal state | A game state where status equals finished. No further actions are accepted. |

---

## 2. Configuration

### 2.1 BoardConfig fields

| Field | Type | Description |
|-------|------|-------------|
| size | int | Board dimension (NxN grid). MUST be odd and >= 5. |
| wallsPerPlayer | int | Number of walls each player starts with. MUST be >= 0. |

### 2.2 Default configuration

| Field | Value |
|-------|-------|
| size | 9 |
| wallsPerPlayer | 10 |

### 2.3 Derived values (default 9x9)

| Derived value | Formula | Default |
|--------------|---------|---------|
| Movement cells | size x size | 81 |
| Anchor range (each axis) | 0 .. size-2 | 0-7 |
| Anchor grid | (size-1) x (size-1) | 8x8 |
| Total wall slots (H) | (size-1)^2 | 64 |
| Total wall slots (V) | (size-1)^2 | 64 |
| Total wall slots | 2 x (size-1)^2 | 128 |
| Blue start cell | (size-1, size~/2) | (8, 4) |
| Red start cell | (0, size~/2) | (0, 4) |
| Blue goal row | 0 | 0 |
| Red goal row | size-1 | 8 |

---

## 3. Rules

### 3.1 Board and Coordinates

**R-BOARD-01:** The board is an NxN grid of cells where N equals BoardConfig.size.

**R-BOARD-02:** Cells are identified by zero-based logical coordinates (row, column) where 0 <= row < size and 0 <= column < size.

**R-BOARD-03:** Row 0 is the top edge of the board. Column 0 is the left edge.

**R-BOARD-04:** Two cells are adjacent if they differ by exactly 1 in exactly one coordinate (orthogonal neighbors only).

**R-BOARD-05:** An edge is the shared boundary between two adjacent cells. Moving between adjacent cells crosses exactly one edge.

**R-BOARD-06:** The board MUST remain front-facing and grid-focused (rules.md Rule 9, Rule 10).

#### ASCII diagram — 9x9 board

```
        Col: 0   1   2   3   4   5   6   7   8
Row  0:  .   .   .   .   B   .   .   .   .   <- Blue goal row
Row  1:  .   .   .   .   .   .   .   .   .
Row  2:  .   .   .   .   .   .   .   .   .
Row  3:  .   .   .   .   .   .   .   .   .
Row  4:  .   .   .   .   .   .   .   .   .
Row  5:  .   .   .   .   .   .   .   .   .
Row  6:  .   .   .   .   .   .   .   .   .
Row  7:  .   .   .   .   .   .   .   .   .
Row  8:  .   .   .   .   R   .   .   .   .   <- Red goal row

B = Blue start (8,4) → reaches row 0 to win
R = Red start (0,4) → reaches row 8 to win

Anchor grid (for wall placement):
Anchors exist at intersections of grid lines.
For 9x9 board: anchor coordinates range 0-7 on both axes.
H(r,c) blocks edges between rows r/r+1, cols c and c+1.
V(r,c) blocks edges between cols c/c+1, rows r and r+1.
```

---

### 3.2 Players and Start State

**R-PLAYER-01:** Two players: Blue and Red.

**R-PLAYER-02:** Blue starts at cell (size-1, size~/2). For default 9x9: (8, 4).

**R-PLAYER-03:** Red starts at cell (0, size~/2). For default 9x9: (0, 4).

**R-PLAYER-04:** Each player begins with wallsPerPlayer walls in their inventory. For default: 10 walls each.

**R-PLAYER-05:** At all times, pawnPositions[Blue] != pawnPositions[Red]. Pawns MUST NOT occupy the same cell.

**R-PLAYER-06:** At all times, remainingWalls[player] + count(walls where owner == player) == wallsPerPlayer for each player.

**R-PLAYER-07:** Blue moves first (D-06).

---

### 3.3 Turn Structure

**R-TURN-01:** Exactly one primary action per turn: move the pawn OR place a wall (D-07).

**R-TURN-02:** Passing is NOT a legal action in normal play.

**R-TURN-03:** After every successful action, the turn passes to the other player.

**R-TURN-04:** turnNumber is the count of completed actions. It starts at 0 and increments by 1 after every successful action.

**R-TURN-05:** currentPlayer alternates: Blue when turnNumber is even, Red when turnNumber is odd.

---

### 3.4 Pawn Movement

**R-MOVE-01:** A pawn may move to one of the four orthogonally adjacent cells: up (r-1,c), down (r+1,c), left (r,c-1), or right (r,c+1).

**R-MOVE-02:** The destination cell MUST be on the board: 0 <= row < size and 0 <= column < size.

**R-MOVE-03:** The destination MUST NOT be separated from the current cell by a wall.

**R-MOVE-04:** The destination cell MUST NOT contain the opponent pawn (unless jumping per section 3.5).

**R-MOVE-05:** Movement is unrestricted by direction — a pawn may move backward or sideways.

**R-MOVE-06:** A move counts as the turn single primary action.

#### Wall blocking per direction

For a pawn at (r,c), each adjacent cell can be blocked by **two** possible wall anchors (either one is sufficient to block the edge):

| Direction | Destination | Blocked by either anchor |
|-----------|-------------|--------------------------|
| Up | (r-1,c) | H(r-1,c) or H(r-1,c-1) if r-1 >= 0 |
| Down | (r+1,c) | H(r,c) or H(r,c-1) if r+1 < size |
| Left | (r,c-1) | V(r,c-1) or V(r-1,c-1) if c-1 >= 0 |
| Right | (r,c+1) | V(r,c) or V(r-1,c) if c+1 < size |

**Edge cases:** At board boundaries, one anchor may not exist (e.g., H(r-1,c-1) when c=0). The remaining anchor still blocks the edge. When the destination cell itself is off-board, no wall check applies — the move is rejected by R-MOVE-02 before wall blocking is evaluated.

---

### 3.5 Pawn Jumping

**R-JUMP-01:** If the opponent pawn is orthogonally adjacent and no wall separates them, the mover MAY jump over the opponent.

**R-JUMP-02 (Straight jump):** The mover may jump straight over the opponent to the cell directly beyond it, if that cell is on the board AND no wall separates the opponent cell from it.

**R-JUMP-03 (Diagonal/side-step jump):** If the straight jump is unavailable (cell beyond is off-board OR separated by a wall), the mover may move to either cell beside the opponent (perpendicular to the jump direction), if that cell is on the board AND no wall separates it from the opponent cell.

**R-JUMP-04:** A jump counts as the turn single move action.

**R-JUMP-05:** The jump destination MUST NOT be occupied by the opponent (guaranteed by invariant: only two pawns exist and they start on distinct cells; after a jump the mover lands on an empty cell).

#### Jump examples

| Scenario | Available jumps |
|----------|----------------|
| Straight jump clear | Cell beyond opponent, empty and on-board |
| Straight blocked by wall | Both diagonal cells (if on-board and wall-free) |
| Straight off-board edge | Both diagonal cells (if on-board and wall-free) |
| One diagonal blocked by wall | The other diagonal only |
| Both diagonals blocked | No jump in this direction (must move elsewhere) |
| Jump lands on goal row | Legal — wins immediately |

---

### 3.6 Wall Placement

**R-WALL-01:** Every wall is exactly 2 cells long and is horizontal (H) or vertical (V) (D-09).

**R-WALL-02:** A wall sits between cells, on the grid lines (D-09).

**R-WALL-03:** A wall is identified by (anchorRow, anchorColumn, orientation, owner) (D-10).

**R-WALL-04:** Valid anchors are 0..size-2 on both axes. For default 9x9: anchors 0-7 on both axes (D-10).

**R-WALL-05:** A horizontal wall H(r,c) lies on the grid line below row r, spanning columns c and c+1. It blocks movement across edges (r,c)-(r+1,c) and (r,c+1)-(r+1,c+1).

**R-WALL-06:** A vertical wall V(r,c) lies on the grid line to the right of column c, spanning rows r and r+1. It blocks movement across edges (r,c)-(r,c+1) and (r+1,c)-(r+1,c+1).

**R-WALL-07:** A wall is illegal if it shares any segment with an existing wall of the same orientation (overlap rule, D-11):
- H(r,c) overlaps H(r,c') when |c - c'| <= 1.
- V(r,c) overlaps V(r',c) when |r - r'| <= 1.

**R-WALL-08:** A horizontal wall and a vertical wall **MAY** share the same anchor. Same-anchor, opposite-orientation coexistence is **legal** and forms a "+" shape (permissive crossing rule, D-12). Each wall still blocks exactly the two edges defined by R-WALL-05 / R-WALL-06, so the pair together blocks four distinct edges around that corner. This rule changed in v2.0.0; see the changelog.

**R-WALL-09:** Walls that meet end-to-end (e.g., H(r,c) and H(r,c+2)) or form a T/L shape without sharing a midpoint or segment are legal.

**R-WALL-10:** The player MUST have at least one wall remaining in inventory to place a wall.

**R-WALL-11:** A wall is NEVER returned or moved once placed (D-08).

**R-WALL-12:** A wall placement counts as the turn single primary action.

#### Legal touching examples

```
H(r,c) and H(r,c+2):  Legal — end-to-end, no overlap
H(r,c) and V(r,c):    Legal — same-anchor crossing forms a "+" (R-WALL-08, v2.0.0)
H(r,c) and H(r,c+1):  ILLEGAL — overlap (offset by 1)
H(r,c) and H(r,c-1):  ILLEGAL — overlap (offset by 1)
H(r,c) and H(r,c+3):  Legal — no overlap
H(r,c) and H(r,c):    ILLEGAL — overlap (identical position, same orientation)
V(r,c) and V(r,c):    ILLEGAL — overlap (identical position, same orientation)
```

---

### 3.7 Path Preservation

**R-PATH-01:** A wall is illegal if, after adding it, either player has no route to their goal edge (D-13).

**R-PATH-02:** For this check, pawns are ignored as obstacles. Only walls, board edges, and cell adjacency define the graph.

**R-PATH-03:** A route exists if and only if there is a path from the pawn current cell to any cell on the goal row, following edges not blocked by walls.

**R-PATH-04:** When a wall placement is rejected by R-PATH-01, the remaining-wall inventory, turn, and all game state remain unchanged.

**R-PATH-05:** Path-preservation results MUST be independent of search order (BFS vs. DFS give the same yes/no answer).

---

### 3.8 Win Condition and Terminal State

**R-WIN-01:** A player wins immediately upon reaching their goal row (D-15).

**R-WIN-02:** Reaching any cell on the goal row is sufficient to win (D-05).

**R-WIN-03:** Status becomes finished and winner is set immediately.

**R-WIN-04:** No further actions are accepted after the game reaches a terminal state (rules.md Rule 8).

**R-WIN-05:** A player does NOT win by having the opponent touch their goal row. Only reaching your OWN goal row wins.

---

### 3.9 No-Legal-Action Situation

**R-NOLEGAL-01:** A player can NEVER be in a state with no legal actions, given the current rules. This is validated as a **property test** in Phase 2 (see T-DET-005).

**Proof sketch:**

1. **Invariant.** After every legal action, each pawn lies in a wall-graph *component* that contains a cell of its own goal row (walls are only added when both players keep a route; steps stay in one component; a jump A→B→Y crosses open edges, so it stays in the component).
2. Take a shortest route for the mover from cell A. If its first step is to an **empty** neighbour → a legal step exists.
3. If the first step is to the opponent's cell B and B is **not** on the mover's goal row, the route continues to a neighbour Y≠A of B over an open edge. If the in-line cell beyond B is on board and open → the **straight jump** is legal; otherwise Y is a side cell → a diagonal jump is legal.
4. If B **is** on the mover's goal row and the mover had no legal move, then A and B would form the whole component `{A,B}`, which contains no cell of the opponent's goal row — contradicting the invariant for the opponent.

**Dependency:** This proof depends on R-PATH-01 being enforced on every wall placement. If a future rule change removes path-preservation, this proof must be revisited (R-NOLEGAL-02).

**R-NOLEGAL-02:** If the proof in R-NOLEGAL-01 is ever invalidated by a rule change, the specification MUST document the exact situation and add it to Open Questions.

---

### 3.10 Canonical Legal-Action Ordering

**R-ORDER-01:** All moves come before all walls (D-17).

**R-ORDER-02:** Moves are sorted by destination (row, column) ascending (row first, then column).

**R-ORDER-03:** Walls are sorted by orientation (H before V), then anchor row, then anchor column ascending.

**R-ORDER-04:** The ordering is a property of the spec, independent of hash-map iteration or platform.

---

## 4. Action Notation

### 4.1 Move notation

```
M r,c
```

Where r and c are the destination cell coordinates.

Examples:
- M 7,4 — move to cell (7,4)
- M 8,3 — move to cell (8,3)
- M 0,4 — move to goal row (win for Blue)

### 4.2 Wall notation

```
W H r,c   — horizontal wall at anchor (r,c)
W V r,c   — vertical wall at anchor (r,c)
```

Examples:
- W H 0,0 — horizontal wall at anchor (0,0)
- W V 3,4 — vertical wall at anchor (3,4)


---

## 5. Action Validation and Error Taxonomy

### 5.1 Named failure reasons

| Reason | Description |
|--------|-------------|
| matchFinished | The game is in a terminal state (status == finished). |
| wrongTurn | It is not the requesting player turn. |
| moveOutOfBoard | The destination cell is outside the board. |
| moveNotAdjacent | The destination is not orthogonally adjacent to the pawn. |
| moveBlockedByWall | A wall separates the current cell from the destination. |
| moveOntoPawn | The destination contains the opponent pawn and jump rules do not apply. |
| moveIllegalJump | A jump is attempted but the destination is invalid per section 3.5. |
| noWallsRemaining | The player has no walls left in inventory. |
| wallOutOfBounds | The wall anchor is outside the valid anchor range. |
| wallOverlaps | The wall overlaps an existing wall of the same orientation. |
| wallCrosses | **Retired in v2.0.0 — unreachable.** No input can produce this reason; same-anchor opposite-orientation walls are legal (R-WALL-08). Retained as a declared value for forward-compatibility. |
| wallBlocksPath | The wall would leave either player with no route to their goal. |

v2.0.0 declares **12 named failure reasons**, of which **11 are reachable**. `wallCrosses` is retired rather than deleted: it is kept so the taxonomy, the Dart `ActionFailure` enum, and the independently generated oracle fixture (which still reserves the reason and its code `k`) stay aligned, and so a future rule change can reintroduce crossing detection without churning the public enum. No engine code path returns it.

### 5.2 Deterministic validation precedence

1. `matchFinished` → `wrongTurn` → then per action type.
2. Move destination classification: off-board → `moveOutOfBoard`; one of the 4 neighbours (a *step*): wall between → `moveBlockedByWall`, opponent there → `moveOntoPawn`, else legal; **jump-shaped** (opponent orthogonally adjacent with an open edge, and the destination is the cell directly beyond the opponent or a cell beside the opponent): legal only if R-JUMP-02/03 allow it, otherwise `moveIllegalJump`; anything else (including jump-shaped attempts when the opponent is not adjacent or the edge to the opponent is walled) → `moveNotAdjacent`.
3. Wall action order: `noWallsRemaining` → `wallOutOfBounds` → `wallOverlaps` → `wallBlocksPath`. (`wallCrosses` was removed from this chain in v2.0.0 because it is unreachable; see §5.1.)



---

## 6. State Model

### 6.1 GameState fields

| Field | Type | Description |
|-------|------|-------------|
| boardConfig | BoardConfig | Board size and walls-per-player. |
| players | List of Player | Players: Blue and Red. |
| currentPlayer | Player | Whose turn it is. |
| pawnPositions | Map of Player to Cell | Current cell for each player pawn. |
| walls | List of Wall | All placed walls. |
| remainingWalls | Map of Player to int | Walls left in each player inventory. |
| turnNumber | int | Count of completed actions (starts at 0). |
| status | GameStatus | inProgress or finished. |
| winner | Player or null | Winner if status is finished; null otherwise. |

### 6.2 Invariants

| ID | Invariant |
|----|-----------|
| R-STATE-01 | pawnPositions[Blue] != pawnPositions[Red] at all times. |
| R-STATE-02 | remainingWalls[p] + count(walls where owner == p) == wallsPerPlayer for each player p. |
| R-STATE-03 | winner != null if and only if status == finished. |
| R-STATE-04 | turnNumber >= 0. |
| R-STATE-05 | currentPlayer == Blue when turnNumber is even; currentPlayer == Red when turnNumber is odd. |

### 6.3 Lifecycle

inProgress transitions to finished exactly once, when a player reaches their goal row. No transition back.

---

## 7. Serialization Contract (Draft)

### 7.1 JSON shape - GameState

Initial state:

```json
{
  "schemaVersion": 1,
  "boardConfig": {"size": 9, "wallsPerPlayer": 10},
  "players": ["blue", "red"],
  "currentPlayer": "red",
  "pawnPositions": {"blue": {"row": 5, "column": 4}, "red": {"row": 2, "column": 4}},
  "walls": [],
  "remainingWalls": {"blue": 10, "red": 10},
  "turnNumber": 5,
  "status": "inProgress",
  "winner": null
}
```

### 7.2 JSON shape - Action

Move: `{"type":"move","destination":{"row":7,"column":4}}`
Wall: `{"type":"wall","orientation":"H","anchor":{"row":0,"column":0}}`

### 7.3 Serialization rules

**R-SERIAL-01:** schemaVersion MUST be included and checked. Unknown versions MUST be rejected as a structured failure.

**R-SERIAL-02:** Malformed or invariant-violating JSON MUST be rejected, never partially applied.

**R-SERIAL-03:** toJson/fromJson round-trips MUST preserve all game state fields exactly.

### 7.4 Example - mid-game state

```json
{
  "schemaVersion": 1,
  "boardConfig": {"size": 9, "wallsPerPlayer": 10},
  "players": ["blue", "red"],
  "currentPlayer": "red",
  "pawnPositions": {"blue": {"row": 5, "column": 4}, "red": {"row": 2, "column": 4}},
  "walls": [],
  "remainingWalls": {"blue": 10, "red": 10},
  "turnNumber": 5,
  "status": "inProgress",
  "winner": null
}
```


---

## 8. Worked Examples

### Example 1: Opening move - Blue moves (8,4) to (7,4)

```
Before:
  Row 8: . . . . B . . . .   (Blue at (8,4))
  Row 0: . . . . R . . . .   (Red at (0,4))
  currentPlayer: Blue, turnNumber: 0

Action: M 7,4

After:
  Row 8: . . . . . . . . .
  Row 7: . . . . B . . . .   (Blue at (7,4))
  Row 0: . . . . R . . . .
  currentPlayer: Red, turnNumber: 1
```

### Example 2: Move blocked by horizontal wall

```
Before:
  Blue at (3,4), Red at (0,4)
  Wall: H(3,4) blocks edges (3,4)-(4,4) and (3,5)-(4,5)
  currentPlayer: Blue

Action: M 4,4

Result: ILLEGAL - moveBlockedByWall
  H(3,4) blocks the edge between (3,4) and (4,4).
```

### Example 3: Move blocked by vertical wall

```
Before:
  Blue at (5,3), Red at (0,4)
  Wall: V(5,3) blocks edges (5,3)-(5,4) and (6,3)-(6,4)
  currentPlayer: Blue

Action: M 5,4

Result: ILLEGAL - moveBlockedByWall
  V(5,3) blocks the edge between (5,3) and (5,4).
```

### Example 3a: Move blocked by second anchor of horizontal wall

```
Before:
  Blue at (3,4), Red at (0,4)
  Wall: H(3,3) — second anchor H(r,c-1) blocks upward from (3,4)
  currentPlayer: Blue

Action: M 4,4

Result: ILLEGAL - moveBlockedByWall
  H(3,3) has second anchor at column 3, spanning columns 3-4.
  The edge (3,4)-(4,4) is blocked by H(3,3)'s second segment.
```

### Example 3b: Move blocked by second anchor of vertical wall

```
Before:
  Blue at (5,4), Red at (0,4)
  Wall: V(4,3) — second anchor V(r-1,c-1) blocks leftward from (5,4)
  currentPlayer: Blue

Action: M 5,3

Result: ILLEGAL - moveBlockedByWall
  V(4,3) has second anchor at row 4, spanning rows 4-5.
  The edge (5,3)-(5,4) is blocked by V(4,3)'s second segment.
```

### Example 3c: Move blocked at board edge

```
Before:
  Blue at (3,8), Red at (0,4)
  Wall: H(3,7) — blocks edges (3,7)-(4,7) and (3,8)-(4,8)
  currentPlayer: Blue

Action: M 4,8

Result: ILLEGAL - moveBlockedByWall
  H(3,7) second segment blocks (3,8)-(4,8). Only one anchor exists here.
```

### Example 3d: Move right blocked by second anchor of vertical wall

```
Before:
  Blue at (5,4), Red at (0,4)
  Wall: V(4,4) — second anchor V(r-1,c) blocks rightward from (5,4)
  currentPlayer: Blue

Action: M 5,5

Result: ILLEGAL - moveBlockedByWall
  V(4,4) has second anchor at row 4, spanning rows 4-5.
  The edge (5,4)-(5,5) is blocked by V(4,4)'s second segment.
```

### Example 4: Move off the board edge

```
Before:
  Blue at (5,4), Red at (3,2)
  currentPlayer: Blue

Action: M -1,4

Result: ILLEGAL - moveOutOfBoard
  Row -1 is outside the board.
```

### Example 5: Wall placed at corner anchor - legal

```
Before:
  Blue at (8,4), Red at (0,4)
  No walls placed.
  currentPlayer: Blue

Action: W H 0,0

After:
  Wall: H(0,0) placed below row 0, columns 0-1
  Blocks edges: (0,0)-(1,0) and (0,1)-(1,1)
  Blue remainingWalls: 9
  currentPlayer: Red, turnNumber: 1
  Path check: Both players still have routes - legal.
```

### Example 6: Wall out of bounds - illegal

```
Before:
  Blue at (8,4), Red at (0,4)
  currentPlayer: Blue

Action: W H 8,0

Result: ILLEGAL - wallOutOfBounds
  Anchor row 8 is outside valid range 0-7 for a 9x9 board.
```

### Example 7: Overlap - identical position

```
Before:
  Wall: H(3,3) already placed.
  currentPlayer: Blue

Action: W H 3,3

Result: ILLEGAL - wallOverlaps
  Identical wall position already occupied.
```

### Example 8: Overlap - offset by one

```
Before:
  Wall: H(3,3) already placed.
  currentPlayer: Blue

Action: W H 3,4

Result: ILLEGAL - wallOverlaps
  |4 - 3| = 1 <= 1, so walls overlap.
```

### Example 9: Legal offset by two

```
Before:
  Wall: H(3,3) already placed.
  currentPlayer: Blue

Action: W H 3,5

After:
  Wall: H(3,5) placed.
  |5 - 3| = 2 > 1, so no overlap. Legal.
```

### Example 10: Crossing at same anchor - legal (v2.0.0)

```
Before:
  Wall: H(3,3) already placed.
  currentPlayer: Blue

Action: W V 3,3

Result: LEGAL
  H(3,3) and V(3,3) share the same anchor. Since v2.0.0 (R-WALL-08, D-12)
  same-anchor opposite-orientation coexistence is legal, so the two walls
  coexist and form a "+" at the intersection of the row 3/4 line and the
  column 3/4 line:

              col 3   col 4
    row 3:      |       |
                |       |
    ------------+-------      <- H(3,3): horizontal, below row 3, cols 3-4
                |       |
    row 4:      |       |
                |       |
                ^ V(3,3): vertical, right of col 3, rows 3-4

  Four edges are now blocked in total around that corner:
    H(3,3) blocks (3,3)-(4,3) and (3,4)-(4,4)
    V(3,3) blocks (3,3)-(3,4) and (4,3)-(4,4)
  i.e. every edge between cells (3,3), (3,4), (4,3) and (4,4) is blocked.
  Neither wall shares a segment with the other, so R-WALL-07 is not
  triggered. Both players keep a route to their goal, so R-PATH-01 passes.
  Blue remainingWalls: 9
  currentPlayer: Red, turnNumber: 1
```

### Example 11: Legal T-junction

```
Before:
  Wall: H(3,3) already placed.
  currentPlayer: Blue

Action: W V 4,3

After:
  Wall: V(4,3) placed.
  H(3,3) spans cols 3-4 below row 3.
  V(4,3) spans rows 4-5 right of col 3.
  No shared midpoint or segment - legal.
```

### Example 12: Straight jump

```
Before:
  Blue at (5,4), Red at (4,4)
  No walls blocking.
  currentPlayer: Blue

Action: M 3,4

After:
  Blue at (3,4) - jumped over Red.
  Red unchanged at (4,4).
  currentPlayer: Red, turnNumber: 1
```

### Example 13: Diagonal jump (straight blocked by wall)

```
Before:
  Blue at (5,4), Red at (4,4)
  Wall: H(3,4) blocks (3,4)-(4,4), so straight jump blocked.
  No walls blocking diagonals.
  currentPlayer: Blue

Available jumps:
  Straight: BLOCKED by H(3,4)
  Diagonal left: (4,3) - valid, on-board, no wall from (4,4) to (4,3)
  Diagonal right: (4,5) - valid, on-board, no wall from (4,4) to (4,5)

Action: M 4,3

After:
  Blue at (4,3)
  Red unchanged at (4,4)
  currentPlayer: Red, turnNumber: 1
```

### Example 14: Win - Blue reaches row 0

```
Before:
  Blue at (1,4), Red at (3,2)
  currentPlayer: Blue

Action: M 0,4

After:
  Blue at (0,4) - goal row reached!
  status: finished
  winner: Blue
  Any further action fails with: matchFinished
```

### Example 15: Wrong turn - Red attempts to move on Blue turn

```
Before:
  Blue at (8,4), Red at (0,4)
  currentPlayer: Blue, turnNumber: 0

Action (by Red): M 1,4

Result: ILLEGAL - wrongTurn
  It is Blue turn, not Red.
```

### Example 16: Last wall placement

```
Before:
  Blue has 1 wall remaining.
  currentPlayer: Blue

Action: W H 5,5

After:
  Wall: H(5,5) placed.
  Blue remainingWalls: 0
  Blue has no walls left - future wall placements fail with: noWallsRemaining
```

### Example 17: Path preservation - legal detour

```
Before:
  Blue at (8,4), Red at (0,4)
  currentPlayer: Blue

Action: W H 4,3

After:
  H(4,3) placed - blocks edges (4,3)-(5,3) and (4,4)-(5,4)
  Blue route: (8,4)->(7,4)->(6,4)->(5,4)->(5,5)->(4,5)->(3,5)->(2,5)->(1,5)->(0,5) - route exists (length 9).
  Red route: Red can reach goal - route exists (length 9).
  Legal.
```

### Example 18: Path preservation — sealed pocket (illegal)

```
Before:
  Blue at (8,0), Red at (0,4)
  Existing wall: H(7,0) — blocks edges (7,0)-(8,0) and (7,1)-(8,1)
  currentPlayer: Blue

Action: W V 7,1

Result: ILLEGAL - wallBlocksPath
  V(7,1) blocks edges (7,1)-(7,2) and (8,1)-(8,2).
  Combined with H(7,0), Blue at (8,0) is sealed in pocket {(8,0),(8,1)}:
    - (8,0) up to (7,0): blocked by H(7,0)
    - (8,0) right to (8,1): not blocked, but (8,1) up to (7,1): blocked by H(7,0)
    - (8,1) right to (8,2): blocked by V(7,1)
    - (8,1) down: off-board
    - (8,0) down/left: off-board
  Blue has no route to row 0.
```


---

## 9. Rules Test-Case Catalog

### 9.1 Movement tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-MOVE-001 | R-MOVE-01..06, R-PLAYER-07 | Blue(8,4), Red(0,4), no walls, Blue turn | Blue M 7,4 | Success. Blue(7,4). Red turn. turnNumber=1 |
| T-MOVE-002 | R-MOVE-01..03 | Blue(3,3), Red(0,4), no walls, Blue turn | Blue M 4,3 | Success. Blue(4,3). |
| T-MOVE-003 | R-MOVE-01..02 | Blue(5,4), Red(0,0), Red turn | Red M -1,0 | ILLEGAL moveOutOfBoard |
| T-MOVE-004 | R-MOVE-01..02 | Blue(5,4), Red(0,0), Red turn | Red M 0,-1 | ILLEGAL moveOutOfBoard |
| T-MOVE-005 | R-MOVE-01..02 | Blue(8,8), Red(0,4), Blue turn | Blue M 8,9 | ILLEGAL moveOutOfBoard |
| T-MOVE-006 | R-MOVE-01..02 | Blue(8,8), Red(0,4), Blue turn | Blue M 9,8 | ILLEGAL moveOutOfBoard |
| T-MOVE-007 | R-MOVE-03, R-WALL-05 | Blue(3,4), Red(0,4), Wall H(3,4), Blue turn | Blue M 4,4 | ILLEGAL moveBlockedByWall |
| T-MOVE-008 | R-MOVE-03, R-WALL-06 | Blue(5,3), Red(0,4), Wall V(5,3), Blue turn | Blue M 5,4 | ILLEGAL moveBlockedByWall |
| T-MOVE-009 | R-MOVE-04 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 4,4 | ILLEGAL moveOntoPawn |
| T-MOVE-010 | R-WIN-01..02 | Blue(1,4), Red(3,2), Blue turn | Blue M 0,4 | Success. finished. winner=Blue |
| T-MOVE-011 | R-TURN-05, R-PLAYER-07 | Blue(8,4), Red(0,4), Blue turn | Red M 1,4 | ILLEGAL wrongTurn |
| T-MOVE-012 | R-WIN-04 | Blue(0,4), game finished | Blue M any | ILLEGAL matchFinished |
| T-MOVE-013 | R-MOVE-05 | Blue(5,5), Red(0,4), Blue turn | Blue M 5,4 | Success (sideways) |
| T-MOVE-014 | R-MOVE-05 | Blue(5,5), Red(0,4), Blue turn | Blue M 4,5 | Success (backward) |
| T-MOVE-015 | R-MOVE-03 | Blue(4,4), Red(0,4), Wall H(3,3), Blue turn | Blue M 3,4 | ILLEGAL moveBlockedByWall |
| T-MOVE-016 | R-MOVE-03 | Blue(3,4), Red(0,4), Wall H(3,3), Blue turn | Blue M 4,4 | ILLEGAL moveBlockedByWall |
| T-MOVE-017 | R-MOVE-03 | Blue(5,4), Red(0,4), Wall V(4,3), Blue turn | Blue M 5,3 | ILLEGAL moveBlockedByWall |
| T-MOVE-018 | R-MOVE-03 | Blue(5,4), Red(0,4), Wall V(4,4), Blue turn | Blue M 5,5 | ILLEGAL moveBlockedByWall |
| T-MOVE-019 | R-MOVE-03 | Blue(3,8), Red(0,4), Wall H(3,7), Blue turn | Blue M 4,8 | ILLEGAL moveBlockedByWall |
| T-MOVE-020 | R-MOVE-03 | Blue(5,4), Red(0,4), Wall V(4,3), Blue turn | Blue M 5,5 | Success. Blue(5,5). |

### 9.2 Jump tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-JUMP-001 | R-JUMP-01..02 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 3,4 | Success straight jump. Blue(3,4). |
| T-JUMP-002 | R-JUMP-01,03 | Blue(5,4), Red(4,4), Wall H(3,4), Blue turn | Blue M 4,3 | Success diagonal jump. Blue(4,3). |
| T-JUMP-003 | R-JUMP-01,03 | Blue(5,4), Red(4,4), Wall H(3,4), Blue turn | Blue M 4,5 | Success diagonal jump. Blue(4,5). |
| T-JUMP-004 | R-JUMP-01,03 | Blue(1,4), Red(0,4), Wall V(0,3), Blue turn | Blue M 0,5 | Success diagonal jump (straight off-board, one diagonal blocked). Blue(0,5). Wins. |
| T-JUMP-005 | R-JUMP-01,03 | Blue(1,4), Red(0,4), no walls, Blue turn | Blue M 0,3 | Success diagonal jump. Blue(0,3). Wins. |
| T-JUMP-006 | R-JUMP-01,03 | Blue(1,4), Red(0,4), Wall V(0,3), Blue turn | Blue M 0,3 | ILLEGAL moveIllegalJump |
| T-JUMP-007 | R-JUMP-01 | Blue(1,4), Red(0,4), no walls, Blue turn | Blue M 0,4 | ILLEGAL moveOntoPawn |
| T-JUMP-008 | R-JUMP-04 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 3,4 | turnNumber increments by 1 |
| T-JUMP-009 | R-JUMP-02 | Blue(5,4), Red(4,4), Wall H(3,4), Blue turn | Blue M 3,4 | ILLEGAL moveIllegalJump (straight jump blocked between opponent and landing) |
| T-JUMP-010 | R-JUMP-03 | Blue(5,4), Red(4,4), Wall H(3,4), Blue turn | Blue M 4,3 | Success diagonal jump (straight unavailable, diagonal allowed) |
| T-JUMP-011 | R-JUMP-02 | Blue(5,4), Red(4,4), Wall H(2,4), Blue turn | Blue M 3,4 | Success straight jump (wall beyond landing cell does not block) |
| T-JUMP-012 | R-JUMP-03 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 4,3 | ILLEGAL moveIllegalJump (diagonal while straight is available) |
| T-JUMP-013 | R-JUMP-01 | Blue(5,4), Red(0,4), Blue turn | Blue M 3,4 | ILLEGAL moveNotAdjacent (distance 2, no opponent) |

### 9.3 Wall tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-WALL-001 | R-WALL-01..04,10,12 | Blue(8,4), Red(0,4), 10 walls, Blue turn | W H 0,0 | Success. 9 walls left. |
| T-WALL-002 | R-WALL-04 | Blue(8,4), Red(0,4), Blue turn | W H 8,0 | ILLEGAL wallOutOfBounds |
| T-WALL-003 | R-WALL-04 | Blue(8,4), Red(0,4), Blue turn | W V 0,8 | ILLEGAL wallOutOfBounds |
| T-WALL-004 | R-WALL-07 | Wall H(3,3) exists, Blue turn | W H 3,3 | ILLEGAL wallOverlaps |
| T-WALL-005 | R-WALL-07 | Wall H(3,3) exists, Blue turn | W H 3,4 | ILLEGAL wallOverlaps |
| T-WALL-006 | R-WALL-07 | Wall H(3,3) exists, Blue turn | W H 3,5 | Success offset by 2 |
| T-WALL-007 | R-WALL-08 | Wall H(3,3) exists, Blue turn | W V 3,3 | Success. V(3,3) placed; H(3,3) and V(3,3) coexist at the same anchor. 9 walls left. |
| T-WALL-008 | R-WALL-09 | Wall H(3,3) exists, Blue turn | W V 4,3 | Success T-junction |
| T-WALL-009 | R-WALL-09 | Wall H(3,3) exists, Blue turn | W H 3,5 | Success end-to-end |
| T-WALL-010 | R-WALL-10 | Blue 0 walls, Blue turn | W H 3,3 | ILLEGAL noWallsRemaining |
| T-WALL-011 | R-PATH-01..02 | Blue(8,0), Red(0,4), Wall H(7,0), Blue turn | W V 7,1 | ILLEGAL wallBlocksPath — Blue sealed in pocket. |
| T-WALL-012 | R-PATH-01 | Blue(8,4), Red(0,4), Wall V(4,4), Blue turn | W V 4,3 | Success — both players still have routes. |
| T-WALL-013 | R-PATH-04 | Blue(8,0), Wall H(7,0), Blue turn | Blue W V 7,1 | ILLEGAL wallBlocksPath. Blue remainingWalls=9, turnNumber unchanged, walls unchanged |
| T-WALL-014 | R-WALL-07 | Wall V(3,3) exists, Blue turn | W V 3,3 | ILLEGAL wallOverlaps |

### 9.4 Pathfinding tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-PATH-001 | R-PATH-01..03 | Open board, Blue(8,4), Red(0,4) | Check routes | Both have routes. Blue length=8, Red length=8. |
| T-PATH-002 | R-PATH-01 | Blue(8,4), Red(0,4), Wall H(4,3) | Check routes | Both have routes. Blue length=9, Red length=9. |
| T-PATH-003 | R-PATH-01 | Blue(8,4), Red(0,4), walls=[(3,3,'H'),(5,3,'V'),(4,3,'H')] | Check routes | Both have routes. |
| T-PATH-004 | R-PATH-01 | Blue(8,0), Red(0,4), Wall H(7,0) | Attempt W V 7,1 | ILLEGAL wallBlocksPath — Blue sealed in pocket {(8,0),(8,1)}. |
| T-PATH-005 | R-PATH-02 | Blue(2,0), Red(0,4), open board | Check route Blue→row 0 | Route length=2. |
| T-PATH-006 | R-PATH-05 | Blue(8,4), Red(0,4), Wall H(4,3) | BFS vs DFS | Same yes/no answer. |

### 9.5 Win tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-WIN-001 | R-WIN-01..02 | Blue(1,4), Red(3,2), Blue turn | Blue M 0,4 | finished, winner=Blue |
| T-WIN-002 | R-WIN-01..02 | Red(7,4), Blue(3,2), Red turn | Red M 8,4 | finished, winner=Red |
| T-WIN-003 | R-WIN-05 | Blue(7,4), Red(1,4), Red turn | Red M 0,4 | Success. inProgress, no winner (row 0 is Blue goal, not Red's) |
| T-WIN-004 | R-WIN-04 | Game finished | Any action | ILLEGAL matchFinished |
| T-WIN-005 | R-WIN-01, R-JUMP-01 | Blue(1,4), Red(0,4), Blue turn | Blue M 0,3 (jump) | winner=Blue (goal row via jump) |
| T-WIN-006 | R-WIN-05 | Blue(7,4), Red(3,2), Blue turn | Blue M 8,4 | Success. inProgress, no winner (row 8 is Red goal, not Blue's) |

### 9.6 Turn handling tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-TURN-001 | R-TURN-01,03..05 | Blue(8,4), Red(0,4), turn=0 | Blue M 7,4 | turn=1, Red turn |
| T-TURN-002 | R-TURN-01,03..04 | Blue(7,4), Red(0,4), turn=1 | Red M 1,4 | turn=2, Blue turn |
| T-TURN-003 | R-TURN-04 | Blue(8,4), Red(0,4), turn=0 | Blue W H 0,0 | turn=1 |
| T-TURN-004 | R-TURN-02 | Blue(8,4), Red(0,4), Blue turn | Blue pass | ILLEGAL no pass action |
| T-TURN-005 | R-TURN-04..05 | turn=0 | After action | turn=1, Red (odd) |
| T-TURN-006 | R-TURN-04..05 | turn=1 | After action | turn=2, Blue (even) |

### 9.7 Serialization tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-SERIAL-001 | R-SERIAL-03 | Initial GameState | toJson then fromJson | Round-trip preserves all fields |
| T-SERIAL-002 | R-SERIAL-03 | Mid-game GameState | toJson then fromJson | Round-trip preserves all fields |
| T-SERIAL-003 | R-SERIAL-03 | Finished GameState | toJson then fromJson | Preserves status and winner |
| T-SERIAL-004 | R-SERIAL-01 | JSON with schemaVersion=999 | fromJson | Rejected unknown version |
| T-SERIAL-005 | R-SERIAL-02 | Malformed JSON | fromJson | Rejected no partial apply |
| T-SERIAL-006 | R-SERIAL-02 | JSON violating R-STATE-01 | fromJson | Rejected invariant violation |

### 9.8 Determinism tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-DET-001 | R-ORDER-01..04 | Initial state | Generate legalActions | M 7,4, M 8,3, M 8,5, then W H 0,0, W H 0,1 ... last three W V 7,5, W V 7,6, W V 7,7 |
| T-DET-002 | R-ORDER-01 | Initial state | Count moves | 3 (up/left/right; down off-board) |
| T-DET-003 | R-ORDER-01 | Initial state | Count walls | 128 (all slots available) |
| T-DET-004 | R-ORDER-01 | Initial state | Total actions | 3 + 128 = 131 |
| T-DET-005 | R-NOLEGAL-01..02 | Initial state | Property test (Phase 2): ≥1000 random seeds on 9×9 and 5×5 boards, random legal play | Never empty legalActions while status == inProgress |

### 9.9 Config tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-CONFIG-001 | R-BOARD-01 | size=8, walls=10 | Validate | ILLEGAL size must be odd |
| T-CONFIG-002 | R-BOARD-01 | size=3, walls=10 | Validate | ILLEGAL size must be >= 5 |
| T-CONFIG-003 | R-BOARD-01 | size=7, walls=8 | Create game | Valid. Blue(6,3). Red(0,3). Goals: 0 and 6. |
| T-CONFIG-004 | R-BOARD-01 | size=5, walls=5 | Create game | Valid. Blue(4,2). Red(0,2). Goals: 0 and 4. |

---

## 10. Coverage Matrix

| Rule ID | Test IDs |
|---------|----------|
| R-BOARD-01 | T-CONFIG-001..004 |
| R-BOARD-02 | T-MOVE-001, 003..006 |
| R-BOARD-03 | T-MOVE-001 (coordinate range validated by BFS) |
| R-BOARD-04 | T-MOVE-001..002 |
| R-BOARD-05 | T-MOVE-001 (adjacent move = one edge crossed) |
| R-BOARD-06 | T-CONFIG-001 |
| R-PLAYER-01 | T-MOVE-001, 011 |
| R-PLAYER-02 | T-MOVE-001, T-JUMP-001 |
| R-PLAYER-03 | T-MOVE-001, 011 |
| R-PLAYER-04 | T-WALL-001, 010 |
| R-PLAYER-05 | T-MOVE-009, T-JUMP-001 |
| R-PLAYER-06 | T-WALL-001, 010 |
| R-PLAYER-07 | T-MOVE-001, 011 |
| R-TURN-01 | T-TURN-001..003 |
| R-TURN-02 | T-TURN-004 |
| R-TURN-03 | T-TURN-001..002 |
| R-TURN-04 | T-TURN-001..003, 005..006 |
| R-TURN-05 | T-TURN-001..002, 005..006, T-MOVE-011 |
| R-MOVE-01 | T-MOVE-001..002, 013..014 |
| R-MOVE-02 | T-MOVE-003..006 |
| R-MOVE-03 | T-MOVE-007..008 |
| R-MOVE-04 | T-MOVE-009 |
| R-MOVE-05 | T-MOVE-013..014 |
| R-MOVE-06 | T-TURN-001 |
| R-JUMP-01 | T-JUMP-001..005, 013 |
| R-JUMP-02 | T-JUMP-001, 004, 009, 011 |
| R-JUMP-03 | T-JUMP-002..003, 004..006, 010, 012 |
| R-JUMP-04 | T-JUMP-008 |
| R-JUMP-05 | T-JUMP-007 (destination occupied = moveOntoPawn) |
| R-WALL-01..06 | T-WALL-001..003 |
| R-WALL-07 | T-WALL-004..006, T-WALL-014 |
| R-WALL-08 | T-WALL-007 (legal same-anchor crossing, v2.0.0) |
| R-WALL-09 | T-WALL-008..009 |
| R-WALL-10 | T-WALL-010 |
| R-WALL-11 | T-WALL-013 (state unchanged after rejection) |
| R-WALL-12 | T-TURN-003 |
| R-PATH-01 | T-PATH-001..004, T-WALL-011..012 |
| R-PATH-02 | T-PATH-005 |
| R-PATH-03 | T-PATH-001 |
| R-PATH-04 | T-WALL-013 |
| R-PATH-05 | T-PATH-006 |
| R-WIN-01 | T-WIN-001..002, 005 |
| R-WIN-02 | T-WIN-001..002 |
| R-WIN-03 | T-WIN-001 |
| R-WIN-04 | T-WIN-004, T-MOVE-012 |
| R-WIN-05 | T-WIN-003, 006 |
| R-NOLEGAL-01 | T-DET-005 |
| R-NOLEGAL-02 | T-DET-005 |
| R-ORDER-01..04 | T-DET-001..004 |
| R-STATE-01 | T-MOVE-009, T-SERIAL-006 |
| R-STATE-02 | T-WALL-001, 010 |
| R-STATE-03 | T-WIN-001, 004 |
| R-STATE-04 | T-TURN-001..002 |
| R-STATE-05 | T-TURN-001..002, 005..006, T-MOVE-011 |
| R-SERIAL-01 | T-SERIAL-004 |
| R-SERIAL-02 | T-SERIAL-005..006 |
| R-SERIAL-03 | T-SERIAL-001..003 |

No orphan rules. Every rule ID has at least one test.

---

## 11. Decision Log

All rule-level decisions that shaped this specification. Each decision is frozen unless a formal rule-change process (rules.md Rule 15, Rule 16) revisits it.

| ID | Decision | Status |
|----|----------|--------|
| D-01 | Board is 9×9, driven by `BoardConfig` (`size`, `wallsPerPlayer`); supported sizes odd, minimum 5 (R-BOARD-01) | Frozen |
| D-02 | Coordinates are `(row, column)`, zero-based; row 0 is the top edge, column 0 the left edge (R-BOARD-02) | Frozen |
| D-03 | Two players: Blue and Red (R-PLAYER-01) | Frozen |
| D-04 | Start cells: Blue `(size-1, size~/2)`, Red `(0, size~/2)` (R-PLAYER-02, R-PLAYER-03) | Frozen |
| D-05 | Goals: Blue's goal is row 0, Red's is row `size-1`; reaching any cell of the goal row wins (R-WIN-01, R-WIN-02, R-WIN-05) | Frozen |
| D-06 | Blue moves first (R-PLAYER-07) | Frozen |
| D-07 | Exactly one primary action per turn (move or place a wall); no passing; turn alternates after each successful action (R-TURN-01, R-TURN-02, R-TURN-03) | Frozen |
| D-08 | 10 walls per player at start (`wallsPerPlayer`), equal for both; walls are never returned or moved (R-PLAYER-04, R-WALL-10, R-WALL-11) | Frozen |
| D-09 | Every wall is exactly 2 cells long, horizontal (H) or vertical (V), placed between cells on grid lines (R-WALL-01, R-WALL-02) | Frozen |
| D-10 | Wall identity `(anchorRow, anchorColumn, orientation, owner)`; valid anchors `0 … size-2` on both axes (R-WALL-03, R-WALL-04) | Frozen |
| D-11 | Overlap: same orientation with anchor offset ≤ 1 along the wall's axis is illegal (R-WALL-07) | Frozen |
| D-12 | Crossing: H and V walls with the same anchor are **legal** and form a "+" (permissive rule, changed in v2.0.0) (R-WALL-08) | Frozen |
| D-13 | Path preservation: a wall is illegal if either player would have no route to their goal edge; walls only, pawns ignored (R-PATH-01) | Frozen |
| D-14 | Pawn jumping is included (straight jump; diagonal side-step only when the straight jump is unavailable) (R-JUMP-01, R-JUMP-02, R-JUMP-03) | Frozen |
| D-15 | Win is immediate on reaching the goal row; status becomes finished; no further actions accepted (R-WIN-03, R-WIN-04) | Frozen |
| D-16 | No draw or repetition rule in the core rules; deferred (see Q-01, Q-03) | Deferred |
| D-17 | Deterministic canonical ordering of legal actions: moves before walls; moves by destination row then column; walls `H` before `V`, then anchor row, then anchor column (R-ORDER-01, R-ORDER-02, R-ORDER-03, R-ORDER-04) | Frozen |
| D-18 | Error taxonomy and jump-failure classification: `matchFinished` → `wrongTurn` → then per action type. Move classification: off-board → `moveOutOfBoard`; step → `moveBlockedByWall`/`moveOntoPawn`/legal; jump-shaped → legal/`moveIllegalJump`; else → `moveNotAdjacent`. Diagonal jump only when straight jump is unavailable (R-NOLEGAL-01, §5.2) | Frozen |

---

## 12. Open Questions

Items explicitly deferred from Phase 1. These are NOT resolved and must be revisited before or during Phase 2.

| ID | Question | Status |
|----|----------|--------|
| Q-01 | Should a draw/repetition rule be added? Options: 50-move, 3-fold repetition. Consequences: prevents stalling, adds memory. Recommended default: 3-fold repetition. Decide before Phase 5 (AI) and Phase 9 (online). | Unresolved |
| Q-02 | ~~Board edge behavior for wall anchors at N-2: should the system enforce stricter anchor bounds for small boards?~~ Resolved: R-WALL-04 enforces anchors 0..size-2. No further action. | Resolved |
| Q-03 | Should a turn limit or game clock be added to prevent infinite games? Options: Turn limit (e.g. 200), Clock. Consequences: prevents griefing. Recommended default: 200 turn limit. Decide before Phase 5 (AI) and Phase 9 (online). | Unresolved |

---

## 13. Out of Scope

The following are explicitly out of scope for this specification:

- Online multiplayer protocol (Phase 7-10).
- AI behavior (Phase 5).
- Board rendering, animation, or visual design (Phase 3, design.md).
- Firebase security rules or data schema.
- Local persistence format.
- Accessibility features (Phase 13).
- Ranked mode, matchmaking, or progression systems.
- Replay or spectator systems.
- Sound, haptics, or vibration.

---

## 14. Phase-1 Task Mapping

This section maps each Phase 1 task (from phase.md) to the corresponding section in game_spec.md.

| Phase 1 Task | game_spec.md Section |
|--------------|---------------------|
| Define board size | §2 Configuration, §3.1 R-BOARD-01 |
| Define player starting positions | §3.2 R-PLAYER-02, R-PLAYER-03 |
| Define goal edges | §3.2, §3.8 R-WIN-01, R-WIN-02 |
| Define movement | §3.4 R-MOVE-01 through R-MOVE-06 |
| Define wall orientation | §3.6 R-WALL-01 |
| Define wall inventory | §3.6 R-WALL-10, §2.1 wallsPerPlayer |
| Define wall overlap rules | §3.6 R-WALL-07 |
| Define wall crossing rules | §3.6 R-WALL-08 (rewritten in v2.0.0: same-anchor crossing is legal) |
| Define path-preservation rule | §3.7 R-PATH-01 through R-PATH-05 |
| Define win condition | §3.8 R-WIN-01 through R-WIN-05 |
| Define turn transition | §3.3 R-TURN-01 through R-TURN-05 |
| Decide pawn-jump behavior | §3.5 R-JUMP-01 through R-JUMP-05 |

---

## 15. Scripted Game Example

A complete 17-action game demonstrating moves, wall placements, and a Blue win.

```
Initial:
  Blue(8,4), Red(0,4), Blue walls=10, Red walls=10, turn=0

  1. Blue M 7,4    → ok    Blue(7,4), turn=1
  2. Red  M 1,4    → ok    Red(1,4),  turn=2
  3. Blue M 6,4    → ok    Blue(6,4), turn=3
  4. Red  M 2,4    → ok    Red(2,4),  turn=4
  5. Blue M 5,4    → ok    Blue(5,4), turn=5
  6. Red  W V 6,3  → ok    Red walls=9, turn=6
  7. Blue W H 6,5  → ok    Blue walls=9, turn=7
  8. Red  M 3,4    → ok    Red(3,4),  turn=8
  9. Blue M 4,4    → ok    Blue(4,4), turn=9
 10. Red  W H 1,3  → ok    Red walls=8, turn=10
 11. Blue M 2,4    → ok    Blue(2,4), turn=11
 12. Red  M 4,4    → ok    Red(4,4),  turn=12
 13. Blue M 2,5    → ok    Blue(2,5), turn=13
 14. Red  M 5,4    → ok    Red(5,4),  turn=14
 15. Blue M 1,5    → ok    Blue(1,5), turn=15
 16. Red  M 6,4    → ok    Red(6,4),  turn=16
 17. Blue M 0,5    → ok    Blue(0,5), turn=17

Final state:
  Blue(0,5), Red(6,4)
  walls: V(6,3) (Red), H(6,5) (Blue), H(1,3) (Red)
  status: finished, winner: blue
  Blue walls=9, Red walls=8, turn=17
```

---

## 16. Finished-State JSON

When a game ends, the GameState JSON includes the winner and status:

```json
{
  "schemaVersion": 1,
  "boardConfig": {"size": 9, "wallsPerPlayer": 10},
  "players": ["blue", "red"],
  "currentPlayer": "red",
  "pawnPositions": {"blue": {"row": 0, "column": 5}, "red": {"row": 6, "column": 4}},
  "walls": [
    {"owner": "red", "orientation": "V", "anchor": {"row": 6, "column": 3}},
    {"owner": "blue", "orientation": "H", "anchor": {"row": 6, "column": 5}},
    {"owner": "red", "orientation": "H", "anchor": {"row": 1, "column": 3}}
  ],
  "remainingWalls": {"blue": 9, "red": 8},
  "turnNumber": 17,
  "status": "finished",
  "winner": "blue"
}
```

Key properties of a finished state:
- `status` == `"finished"`
- `winner` == the player who reached their goal row (`"blue"` or `"red"`)
- `currentPlayer` is the player whose turn it would be next (not the winner)
- No further actions are accepted (R-WIN-04)
