#!/usr/bin/env python3
"""
Generates golden test vectors for the Wallforge Dart engine from an INDEPENDENT reference
engine that implements game_spec.md (v1.0.4).

    python3 tool/spec_verification/gen_engine_vectors.py > test/fixtures/engine_vectors.json

The output is deterministic (fixed seeds). The Dart engine MUST reproduce every vector:
  - replaying `actions` from GameState.initial(config) must never fail,
  - at every checkpoint the engine state serialised with toJson() must equal `state`,
    legalActions() must equal `legal` (same actions, same canonical order),
    and validate() of every candidate must give the code in `candidates`.
Do not edit or regenerate the vectors to make tests pass. If you believe a vector is wrong,
report a minimal reproduction and the spec rule ID that contradicts it.
"""
import json, random, sys
from collections import deque

# ------------------------------------------------------------------ reference engine (spec v1.0.4)
def edge(a, b): return tuple(sorted((a, b)))
def blocked_edges(walls):
    e = set()
    for o, r, c in walls:
        if o == "H": e |= {edge((r,c),(r+1,c)), edge((r,c+1),(r+1,c+1))}
        else:        e |= {edge((r,c),(r,c+1)), edge((r+1,c),(r+1,c+1))}
    return e
def nbrs(p, n):
    r, c = p
    return [(r+dr, c+dc) for dr, dc in ((-1,0),(1,0),(0,-1),(0,1)) if 0 <= r+dr < n and 0 <= c+dc < n]
def route_len(start, goal_row, n, walls):
    b = blocked_edges(walls); seen = {start: 0}; q = deque([start])
    while q:
        u = q.popleft()
        if u[0] == goal_row: return seen[u]
        for v in nbrs(u, n):
            if v not in seen and edge(u, v) not in b: seen[v] = seen[u]+1; q.append(v)
    return None

class G:
    def __init__(s, n, wpp):
        s.n, s.wpp = n, wpp
        s.pos = {"blue": (n-1, n//2), "red": (0, n//2)}
        s.walls = []            # (orientation, r, c)
        s.owners = []           # owner per wall, same order
        s.tn = 0; s.done = False; s.winner = None
    def cp(s): return "blue" if s.tn % 2 == 0 else "red"
    def opp(s, p): return "red" if p == "blue" else "blue"
    def rem(s, p): return s.wpp - s.owners.count(p)
    def goal(s, p): return 0 if p == "blue" else s.n-1
    def json(s):
        return {
            "schemaVersion": 1,
            "boardConfig": {"size": s.n, "wallsPerPlayer": s.wpp},
            "players": ["blue", "red"],
            "currentPlayer": s.cp(),
            "pawnPositions": {p: {"row": s.pos[p][0], "column": s.pos[p][1]} for p in ("blue", "red")},
            "walls": [{"owner": ow, "orientation": o, "anchor": {"row": r, "column": c}} for (o, r, c), ow in zip(s.walls, s.owners)],
            "remainingWalls": {"blue": s.rem("blue"), "red": s.rem("red")},
            "turnNumber": s.tn,
            "status": "finished" if s.done else "inProgress",
            "winner": s.winner,
        }

def wall_shape_problem(walls, w, n):
    o, r, c = w
    if not (0 <= r <= n-2 and 0 <= c <= n-2): return "wallOutOfBounds"
    for o2, r2, c2 in walls:
        if o2 == o and ((o == "H" and r2 == r and abs(c2-c) <= 1) or (o == "V" and c2 == c and abs(r2-r) <= 1)): return "wallOverlaps"
    for o2, r2, c2 in walls:
        if o2 != o and (r2, c2) == (r, c): return "wallCrosses"
    return None
def jump_targets(g, p):
    me, op, n = g.pos[p], g.pos[g.opp(p)], g.n
    if op not in nbrs(me, n): return []
    b = blocked_edges(g.walls)
    if edge(me, op) in b: return []
    dr, dc = op[0]-me[0], op[1]-me[1]
    beyond = (op[0]+dr, op[1]+dc)
    if 0 <= beyond[0] < n and 0 <= beyond[1] < n and edge(op, beyond) not in b: return [beyond]
    out = []
    for pr, pc in ((-dc, dr), (dc, -dr)):
        t = (op[0]+pr, op[1]+pc)
        if 0 <= t[0] < n and 0 <= t[1] < n and edge(op, t) not in b: out.append(t)
    return out
def legal_moves(g, p):
    me, op, b = g.pos[p], g.pos[g.opp(p)], blocked_edges(g.walls)
    res = [v for v in nbrs(me, g.n) if v != op and edge(me, v) not in b]
    res += jump_targets(g, p)
    return sorted(set(res))
def validate(g, actor, kind, arg):
    """spec section 5.2 (D-18 classification)"""
    if g.done: return "matchFinished"
    if actor != g.cp(): return "wrongTurn"
    n = g.n
    if kind == "move":
        me, op, b = g.pos[actor], g.pos[g.opp(actor)], blocked_edges(g.walls)
        d = arg
        if not (0 <= d[0] < n and 0 <= d[1] < n): return "moveOutOfBoard"
        if d in nbrs(me, n):
            if edge(me, d) in b: return "moveBlockedByWall"
            if d == op: return "moveOntoPawn"
            return None
        adj = op in nbrs(me, n) and edge(me, op) not in b
        jump_shaped = adj and (d == (op[0]+(op[0]-me[0]), op[1]+(op[1]-me[1])) or
                               (abs(d[0]-op[0]) + abs(d[1]-op[1]) == 1 and d != me))
        if jump_shaped: return None if d in jump_targets(g, actor) else "moveIllegalJump"
        return "moveNotAdjacent"
    if g.rem(actor) <= 0: return "noWallsRemaining"
    pr = wall_shape_problem(g.walls, arg, n)
    if pr: return pr
    tw = g.walls + [arg]
    if route_len(g.pos["blue"], 0, n, tw) is None or route_len(g.pos["red"], n-1, n, tw) is None: return "wallBlocksPath"
    return None
def legal_actions(g):
    if g.done: return []
    p = g.cp()
    acts = [("move", d) for d in legal_moves(g, p)]
    for o in "HV":
        for r in range(g.n-1):
            for c in range(g.n-1):
                if validate(g, p, "wall", (o, r, c)) is None: acts.append(("wall", (o, r, c)))
    return acts
def apply(g, kind, arg):
    p = g.cp()
    if kind == "wall": g.walls.append(arg); g.owners.append(p)
    else:
        g.pos[p] = arg
        if arg[0] == g.goal(p): g.done, g.winner = True, p
    g.tn += 1
def note(kind, arg): return f"M {arg[0]},{arg[1]}" if kind == "move" else f"W {arg[0]} {arg[1]},{arg[2]}"

REASONS = ["matchFinished","wrongTurn","moveOutOfBoard","moveNotAdjacent","moveBlockedByWall","moveOntoPawn",
           "moveIllegalJump","noWallsRemaining","wallOutOfBounds","wallOverlaps","wallCrosses","wallBlocksPath"]
CODE = {None: "."} | {r: chr(ord("a")+i) for i, r in enumerate(REASONS)}

def candidates(n):
    c = [("move", (r, cc)) for r in range(n) for cc in range(n)]
    c += [("move", d) for d in [(-1,0),(0,-1),(n,0),(0,n),(-1,-1),(n,n)]]
    for o in "HV":
        c += [("wall", (o, r, cc)) for r in range(n) for cc in range(n)]
    c += [("wall", ("H", -1, 0)), ("wall", ("V", 0, -1))]
    return c

def play(n, wpp, seed, max_plies, wall_prob, checkpoint_every, max_checkpoints, greedy=0.8):
    rnd = random.Random(seed); g = G(n, wpp); actions = []; cps = []
    cands = candidates(n)
    def checkpoint():
        la = legal_actions(g); actor = g.cp()
        cps.append({"ply": g.tn, "state": g.json(), "legal": [note(k, a) for k, a in la],
                    "candidates": "".join(CODE[validate(g, actor, k, a)] for k, a in cands)})
    checkpoint()
    while not g.done and g.tn < max_plies:
        la = legal_actions(g)
        assert la, "reference engine found an empty legal action list (R-NOLEGAL-01 violated?)"
        p = g.cp(); walls = [x for x in la if x[0] == "wall"]; moves = [x for x in la if x[0] == "move"]
        if walls and rnd.random() < wall_prob: k, a = rnd.choice(walls)
        else:
            def after(d):
                h = g.pos[p]; return abs(d[0]-g.goal(p))
            best = min(after(m[1]) for m in moves); good = [m for m in moves if after(m[1]) == best]
            k, a = rnd.choice(good if rnd.random() < greedy else moves)
        apply(g, k, a); actions.append(note(k, a))
        if g.done or (g.tn % checkpoint_every == 0 and len(cps) < max_checkpoints): checkpoint()
    if cps[-1]["ply"] != g.tn: checkpoint()
    return {"config": {"size": n, "wallsPerPlayer": wpp}, "seed": seed, "actions": actions, "checkpoints": cps}

def main():
    games = []
    plan = [(9, 10, 30, 0.30, 6, 14, 0.8), (9, 10, 20, 0.55, 8, 14, 0.5), (9, 6, 10, 0.60, 8, 14, 0.4), (7, 8, 14, 0.30, 5, 12, 0.8), (7, 8, 8, 0.6, 6, 12, 0.5), (5, 5, 14, 0.30, 4, 12, 0.8), (5, 5, 8, 0.6, 5, 12, 0.5), (5, 0, 3, 0.0, 3, 8, 0.8), (5, 1, 3, 0.5, 3, 8, 0.8), (7, 3, 4, 0.5, 4, 10, 0.6)]
    seed = 1000
    for n, wpp, count, wp, every, maxcp, gr in plan:
        for _ in range(count):
            seed += 1; games.append(play(n, wpp, seed, 320, wp, every, maxcp, gr))
    out = {"specVersion": "1.0.4", "reasons": REASONS, "codes": {"legal": ".", **{r: CODE[r] for r in REASONS}},
           "candidateOrder": "moves: every on-board cell row-major, then (-1,0),(0,-1),(n,0),(0,n),(-1,-1),(n,n); "
                             "walls: H at every (r,c) in 0..n-1 row-major, then V likewise, then H(-1,0), V(0,-1). "
                             "Each candidate is validated for the CURRENT player of the checkpoint state.",
           "notation": {"move": "M row,col", "wall": "W H|V row,col"}, "games": games}
    json.dump(out, sys.stdout, separators=(",", ":"))
main()
