# Wallforge — Game Specification

## Status

**Version:** 1.0.0
**Status:** Frozen — Phase 1
**Date:** 2026-09-20

This document is the canonical, frozen rulebook for Wallforge. Phase 2 implements this specification. Any change requires the process defined in `rules.md` and Rule 15: update `game_spec.md`, its rule IDs, and its test catalog.

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
     Col:  0   1   2   3   4   5   6   7   8
Row 0  .   .   .   .   R   .   .   .   .   <- Red goal row
       .   .   .   .   .   .   .   .   .
Row 2  .   .   .   .   .   .   .   .   .
       .   .   .   .   .   .   .   .   .
Row 4  .   .   .   .   .   .   .   .   .
       .   .   .   .   .   .   .   .   .
Row 6  .   .   .   .   .   .   .   .   .
       .   .   .   .   .   .   .   .   .
Row 8  .   .   .   .   B   .   .   .   .   <- Blue goal row

R = Red start (0,4)
B = Blue start (8,4)

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

**R-MOVE-03:** No wall MUST separate the current cell from the destination cell.

**R-MOVE-04:** The destination cell MUST NOT contain the opponent pawn (unless jumping per section 3.5).

**R-MOVE-05:** Movement is unrestricted by direction — a pawn may move backward or sideways.

**R-MOVE-06:** A move counts as the turn single primary action.

#### Wall blocking per direction

For a pawn at (r,c):

| Direction | Destination | Blocked by wall anchors |
|-----------|-------------|------------------------|
| Up | (r-1,c) | H(r-1,c) if r-1 >= 0 |
| Down | (r+1,c) | H(r,c) if r+1 < size |
| Left | (r,c-1) | V(r,c-1) if c-1 >= 0 |
| Right | (r,c+1) | V(r,c) if c+1 < size |

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

**R-WALL-08:** A wall is illegal if it crosses an existing wall of the other orientation at the same midpoint (crossing rule, D-12): H(r,c) and V(r,c) with the same anchor cross.

**R-WALL-09:** Walls that meet end-to-end (e.g., H(r,c) and H(r,c+2)) or form a T/L shape without sharing a midpoint or segment are legal.

**R-WALL-10:** The player MUST have at least one wall remaining in inventory to place a wall.

**R-WALL-11:** A wall is NEVER returned or moved once placed (D-08).

**R-WALL-12:** A wall placement counts as the turn single primary action.

#### Legal touching examples

```
H(r,c) and H(r,c+2):  Legal — end-to-end, no overlap
H(r,c) and V(r,c):    ILLEGAL — crossing at same anchor
H(r,c) and H(r,c+1):  ILLEGAL — overlap (offset by 1)
H(r,c) and H(r,c-1):  ILLEGAL — overlap (offset by 1)
H(r,c) and H(r,c+3):  Legal — no overlap, no crossing
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

**R-NOLEGAL-01:** A player can NEVER be in a state with no legal actions, given the current rules.

**Proof sketch:** If a player has no walls remaining, they must still be able to move. Every cell on the board has at least one adjacent cell. Since path-preservation (R-PATH-01) ensures both players always have a route to their goal, and routes require at least one adjacent cell reachable without walls, the pawn MUST have at least one legal move. Therefore, the union of legal moves and legal wall placements is never empty.

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
| wallCrosses | The wall crosses an existing wall of the other orientation. |
| wallBlocksPath | The wall would leave either player with no route to their goal. |

### 5.2 Deterministic validation precedence

When multiple failures apply, the engine MUST report the first matching failure in this order:

1. matchFinished
2. wrongTurn
3. noWallsRemaining (for wall actions)
4. moveOutOfBoard / wallOutOfBounds (bounds checks)
5. moveNotAdjacent (adjacency check)
6. moveBlockedByWall (wall blocking check)
7. moveOntoPawn / moveIllegalJump (pawn collision/jump checks)
8. wallOverlaps (overlap check)
9. wallCrosses (crossing check)
10. wallBlocksPath (path-preservation check)

Justification: This order starts with the most fundamental constraints (game state, turn ownership) before evaluating action-specific legality, ensuring the most useful error is always reported.

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

```
{"schemaVersion":1,"boardConfig":{"size":9,"wallsPerPlayer":10},"players":["blue","red"],"currentPlayer":"blue","pawnPositions":{"blue":{"row":8,"column":4},"red":{"row":0,"column":4}},"walls":[],"remainingWalls":{"blue":10,"red":10},"turnNumber":0,"status":"inProgress","winner":null}
```

### 7.2 JSON shape - Action

Move: `{"type":"move","destination":{"row":7,"column":4}}`
Wall: `{"type":"wall","orientation":"H","anchor":{"row":0,"column":0}}`

### 7.3 Serialization rules

**R-SERIAL-01:** schemaVersion MUST be included and checked. Unknown versions MUST be rejected as a structured failure.

**R-SERIAL-02:** Malformed or invariant-violating JSON MUST be rejected, never partially applied.

**R-SERIAL-03:** toJson/fromJson round-trips MUST preserve all game state fields exactly.

### 7.4 Example - mid-game state

```
{"schemaVersion":1,"boardConfig":{"size":9,"wallsPerPlayer":10},"players":["blue","red"],"currentPlayer":"red","pawnPositions":{"blue":{"row":7,"column":4},"red":{"row":1,"column":4}},"walls":[{"owner":"blue","orientation":"H","anchor":{"row":3,"column":3}},{"owner":"red","orientation":"V","anchor":{"row":5,"column":2}}],"remainingWalls":{"blue":9,"red":9},"turnNumber":2,"status":"inProgress","winner":null}
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

### Example 4: Move off the board edge

```
Before:
  Blue at (0,4), Red at (8,4)
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

### Example 10: Crossing at same anchor

```
Before:
  Wall: H(3,3) already placed.
  currentPlayer: Blue

Action: W V 3,3

Result: ILLEGAL - wallCrosses
  H(3,3) and V(3,3) share the same anchor and cross at the midpoint.
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
  Blue at (1,4), Red at (8,4)
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
  Blue route: (8,4)->(7,4)->(6,4)->(5,4)->(5,3)->(4,3)->(3,3)->(2,3)->(1,3)->(0,3) - route exists.
  Red route: Red can reach goal - route exists.
  Legal.
```

### Example 18: Path preservation - illegal seal

```
Before:
  Blue at (8,4), Red at (0,4)
  Walls: H(7,3), H(7,4), H(7,5), H(7,6), H(7,7) - line across most of row 7.
  currentPlayer: Blue

Action: W H 7,2

Result: ILLEGAL - wallBlocksPath
  H(7,2) would complete a wall across all of row 7 (cols 2-8).
  Blue at (8,4) would be sealed below row 7 with no route to row 0.
```


---

## 9. Rules Test-Case Catalog

### 9.1 Movement tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-MOVE-001 | R-MOVE-01..06, R-PLAYER-07 | Blue(8,4), Red(0,4), no walls, Blue turn | Blue M 7,4 | Success. Blue(7,4). Red turn. turnNumber=1 |
| T-MOVE-002 | R-MOVE-01..03 | Blue(3,3), Red(0,4), no walls, Blue turn | Blue M 4,3 | Success. Blue(4,3). |
| T-MOVE-003 | R-MOVE-01..02 | Blue(0,0), Red(8,4), Blue turn | Blue M -1,0 | ILLEGAL moveOutOfBoard |
| T-MOVE-004 | R-MOVE-01..02 | Blue(0,0), Red(8,4), Blue turn | Blue M 0,-1 | ILLEGAL moveOutOfBoard |
| T-MOVE-005 | R-MOVE-01..02 | Blue(8,8), Red(0,4), Blue turn | Blue M 8,9 | ILLEGAL moveOutOfBoard |
| T-MOVE-006 | R-MOVE-01..02 | Blue(8,8), Red(0,4), Blue turn | Blue M 9,8 | ILLEGAL moveOutOfBoard |
| T-MOVE-007 | R-MOVE-03, R-WALL-05 | Blue(3,4), Red(0,4), Wall H(3,4), Blue turn | Blue M 4,4 | ILLEGAL moveBlockedByWall |
| T-MOVE-008 | R-MOVE-03, R-WALL-06 | Blue(5,3), Red(0,4), Wall V(5,3), Blue turn | Blue M 5,4 | ILLEGAL moveBlockedByWall |
| T-MOVE-009 | R-MOVE-04 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 4,4 | ILLEGAL moveOntoPawn |
| T-MOVE-010 | R-WIN-01..02 | Blue(1,4), Red(8,4), Blue turn | Blue M 0,4 | Success. finished. winner=Blue |
| T-MOVE-011 | R-TURN-05, R-PLAYER-07 | Blue(8,4), Red(0,4), Blue turn | Red M 1,4 | ILLEGAL wrongTurn |
| T-MOVE-012 | R-WIN-04 | Blue(0,4), game finished | Blue M any | ILLEGAL matchFinished |
| T-MOVE-013 | R-MOVE-05 | Blue(5,5), Red(0,4), Blue turn | Blue M 5,4 | Success (sideways) |
| T-MOVE-014 | R-MOVE-05 | Blue(5,5), Red(0,4), Blue turn | Blue M 4,5 | Success (backward) |

### 9.2 Jump tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-JUMP-001 | R-JUMP-01..02 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 3,4 | Success straight jump. Blue(3,4). |
| T-JUMP-002 | R-JUMP-01,03 | Blue(5,4), Red(4,4), Wall H(3,4), Blue turn | Blue M 4,3 | Success diagonal jump. Blue(4,3). |
| T-JUMP-003 | R-JUMP-01,03 | Blue(5,4), Red(4,4), Wall H(3,4), Blue turn | Blue M 4,5 | Success diagonal jump. Blue(4,5). |
| T-JUMP-004 | R-JUMP-01..02 | Blue(1,4), Red(0,4), no walls, Blue turn | Blue M -1,4 | ILLEGAL straight off-board. Diagonals available. |
| T-JUMP-005 | R-JUMP-01,03 | Blue(1,4), Red(0,4), no walls, Blue turn | Blue M 0,3 | Success diagonal jump. Blue(0,3). Wins. |
| T-JUMP-006 | R-JUMP-01,03 | Blue(1,4), Red(0,4), Wall V(0,3), Blue turn | Blue M 0,3 | ILLEGAL moveBlockedByWall |
| T-JUMP-007 | R-JUMP-01 | Blue(1,4), Red(0,4), no walls, Blue turn | Blue M 0,4 | ILLEGAL moveOntoPawn |
| T-JUMP-008 | R-JUMP-04 | Blue(5,4), Red(4,4), no walls, Blue turn | Blue M 3,4 | turnNumber increments by 1 |

### 9.3 Wall tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-WALL-001 | R-WALL-01..04,10,12 | Blue(8,4), Red(0,4), 10 walls, Blue turn | W H 0,0 | Success. 9 walls left. |
| T-WALL-002 | R-WALL-04 | Blue(8,4), Red(0,4), Blue turn | W H 8,0 | ILLEGAL wallOutOfBounds |
| T-WALL-003 | R-WALL-04 | Blue(8,4), Red(0,4), Blue turn | W V 0,8 | ILLEGAL wallOutOfBounds |
| T-WALL-004 | R-WALL-07 | Wall H(3,3) exists, Blue turn | W H 3,3 | ILLEGAL wallOverlaps |
| T-WALL-005 | R-WALL-07 | Wall H(3,3) exists, Blue turn | W H 3,4 | ILLEGAL wallOverlaps |
| T-WALL-006 | R-WALL-07 | Wall H(3,3) exists, Blue turn | W H 3,5 | Success offset by 2 |
| T-WALL-007 | R-WALL-08 | Wall H(3,3) exists, Blue turn | W V 3,3 | ILLEGAL wallCrosses |
| T-WALL-008 | R-WALL-09 | Wall H(3,3) exists, Blue turn | W V 4,3 | Success T-junction |
| T-WALL-009 | R-WALL-09 | Wall H(3,3) exists, Blue turn | W H 3,5 | Success end-to-end |
| T-WALL-010 | R-WALL-10 | Blue 0 walls, Blue turn | W H 3,3 | ILLEGAL noWallsRemaining |
| T-WALL-011 | R-PATH-01..02 | Blue(8,4), Red(0,4), Blue turn | W H 7,2 (seal row 7) | ILLEGAL wallBlocksPath |
| T-WALL-012 | R-PATH-01 | Blue(8,4), Red(0,4), Wall V(4,4), Blue turn | W V 4,3 | Check path preservation |
| T-WALL-013 | R-PATH-04 | Blue(8,4), Red(0,4), wall rejected | Wall rejected | State unchanged |

### 9.4 Pathfinding tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-PATH-001 | R-PATH-01..03 | Open board, Blue(8,4), Red(0,4) | Check routes | Both have routes. Length=8 each. |
| T-PATH-002 | R-PATH-01 | Blue(8,4), Red(0,4), Wall H(4,4) | Check routes | Both have routes (detour). |
| T-PATH-003 | R-PATH-01 | Blue(8,4), Red(0,4), multiple walls | Check routes | Both have routes (longer path). |
| T-PATH-004 | R-PATH-01 | Blue(8,4), Red(0,4), wall would seal Blue | Check routes | Wall placement illegal. |
| T-PATH-005 | R-PATH-02 | Blue(5,5), Red(4,4), walls near (4,4) | Check routes | Route exists (pawn ignored). |
| T-PATH-006 | R-PATH-05 | Same state, BFS vs DFS | Compare | Same yes/no answer. |

### 9.5 Win tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-WIN-001 | R-WIN-01..02 | Blue(1,4), Red(8,4), Blue turn | Blue M 0,4 | finished, winner=Blue |
| T-WIN-002 | R-WIN-01..02 | Red(7,4), Blue(0,4), Red turn | Red M 8,4 | finished, winner=Red |
| T-WIN-003 | R-WIN-05 | Blue(7,4), Red(1,4), Red turn | Red M 8,4 | Red does NOT win (wrong goal row) |
| T-WIN-004 | R-WIN-04 | Game finished | Any action | ILLEGAL matchFinished |
| T-WIN-005 | R-WIN-01, R-JUMP-01 | Blue(1,4), Red(0,4), Blue turn | Blue M 0,3 (jump) | winner=Blue (goal row via jump) |

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
| T-SERIAL-002 | R-SERIAL-003 | Mid-game GameState | toJson then fromJson | Round-trip preserves all fields |
| T-SERIAL-003 | R-SERIAL-003 | Finished GameState | toJson then fromJson | Preserves status and winner |
| T-SERIAL-004 | R-SERIAL-01 | JSON with schemaVersion=999 | fromJson | Rejected unknown version |
| T-SERIAL-005 | R-SERIAL-02 | Malformed JSON | fromJson | Rejected no partial apply |
| T-SERIAL-006 | R-SERIAL-02 | JSON violating R-STATE-01 | fromJson | Rejected invariant violation |

### 9.8 Determinism tests

| Test ID | Rule IDs | Given | When | Then |
|---------|----------|-------|------|------|
| T-DET-001 | R-ORDER-01..04 | Initial state | Generate legalActions | Moves first, then walls. Canonical order. |
| T-DET-002 | R-ORDER-01 | Initial state | Count moves | 3 (up/left/right; down off-board) |
| T-DET-003 | R-ORDER-01 | Initial state | Count walls | 128 (all slots available) |
| T-DET-004 | R-ORDER-01 | Initial state | Total actions | 3 + 128 = 131 |

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
| R-BOARD-03 | Implicit in all coordinate tests |
| R-BOARD-04 | T-MOVE-001..002 |
| R-BOARD-05 | Implicit in all move tests |
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
| R-JUMP-001 | T-JUMP-001..004 |
| R-JUMP-002 | T-JUMP-001, 004..005 |
| R-JUMP-003 | T-JUMP-002..003, 005..006 |
| R-JUMP-004 | T-JUMP-008 |
| R-JUMP-005 | T-JUMP-001 (implicit) |
| R-WALL-01..06 | T-WALL-001..003 |
| R-WALL-07 | T-WALL-004..006 |
| R-WALL-08 | T-WALL-007 |
| R-WALL-09 | T-WALL-008..009 |
| R-WALL-10 | T-WALL-010 |
| R-WALL-11 | Implicit (no test for moving walls) |
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
| R-WIN-05 | T-WIN-003 |
| R-NOLEGAL-01 | Argument-based (no failing test) |
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
