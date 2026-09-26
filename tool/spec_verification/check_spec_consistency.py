#!/usr/bin/env python3
"""
Independent acceptance checker for Wallforge game_spec.md.

Usage:  python3 tool/spec_verification/check_spec_consistency.py [path/to/game_spec.md]
Exit code 0 only if the spec is internally consistent AND agrees with this reference engine.

It (1) parses game_spec.md, (2) executes the test catalog rows, worked examples and the
scripted game against an independent reference engine, (3) checks IDs / coverage matrix,
JSON samples, decision log and required content. It never trusts the spec's own claims.
Do NOT weaken this checker to make the spec pass; fix the spec (or report a checker bug
with a minimal reproduction).
"""
import json, re, sys
from collections import deque

PATH = sys.argv[1] if len(sys.argv) > 1 else "game_spec.md"
TEXT = open(PATH, encoding="utf-8-sig").read()
FIND = []
def bad(where, msg): FIND.append(f"[{where}] {msg}")

# ------------------------------------------------------------------ reference engine
class S:
    def __init__(s, n=9, wpp=10, bp=None, rp=None, walls=None, tn=0, rem=None, done=False, winner=None):
        s.n, s.wpp = n, wpp
        s.bp = bp or (n-1, n//2); s.rp = rp or (0, n//2)
        s.walls = list(walls or [])            # (orientation, r, c)
        s.tn, s.done, s.winner = tn, done, winner
        s.rem = rem or {"blue": wpp, "red": wpp}
    def cp(s): return "blue" if s.tn % 2 == 0 else "red"
    def pos(s, p): return s.bp if p == "blue" else s.rp
    def opp(s, p): return "red" if p == "blue" else "blue"
    def goal(s, p): return 0 if p == "blue" else s.n-1

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
def wall_shape_problem(walls, w, n):
    # v2.0.0 rule change (owner-approved): same-anchor, opposite-orientation
    # walls MAY coexist (a "+" crossing is legal). Same-orientation overlap
    # (offset <= 1 along the wall's own axis) remains illegal. "wallCrosses"
    # is retired; no candidate can ever produce it. Any T-WALL catalog row
    # whose Then still expects "wallCrosses" is stale spec content that must
    # be rewritten (either to a legal outcome, or replaced by an overlap case).
    o, r, c = w
    if not (0 <= r <= n-2 and 0 <= c <= n-2): return "wallOutOfBounds"
    for o2, r2, c2 in walls:
        if o2 == o and ((o == "H" and r2 == r and abs(c2-c) <= 1) or (o == "V" and c2 == c and abs(r2-r) <= 1)): return "wallOverlaps"
    return None
def jump_targets(s, p):
    """legal jump destinations for player p (straight if available else diagonals)"""
    me, op, n = s.pos(p), s.pos(s.opp(p)), s.n
    if op not in nbrs(me, n): return []
    b = blocked_edges(s.walls)
    if edge(me, op) in b: return []
    dr, dc = op[0]-me[0], op[1]-me[1]
    beyond = (op[0]+dr, op[1]+dc)
    if 0 <= beyond[0] < n and 0 <= beyond[1] < n and edge(op, beyond) not in b: return [beyond]
    out = []
    for pr, pc in ((-dc, dr), (dc, -dr)):
        t = (op[0]+pr, op[1]+pc)
        if 0 <= t[0] < n and 0 <= t[1] < n and edge(op, t) not in b: out.append(t)
    return out
def legal_moves(s, p):
    me, op, b = s.pos(p), s.pos(s.opp(p)), blocked_edges(s.walls)
    res = [v for v in nbrs(me, s.n) if v != op and edge(me, v) not in b]
    res += jump_targets(s, p)
    return sorted(set(res))
def validate(s, actor, kind, arg):
    """taxonomy per spec section 5 / D-18 (as required by the Phase 1.2/1.3 prompts)"""
    if s.done: return "matchFinished"
    if actor != s.cp(): return "wrongTurn"
    n = s.n
    if kind == "move":
        me, op, b = s.pos(actor), s.pos(s.opp(actor)), blocked_edges(s.walls)
        d = arg
        if not (0 <= d[0] < n and 0 <= d[1] < n): return "moveOutOfBoard"
        if d in nbrs(me, n):
            if edge(me, d) in b: return "moveBlockedByWall"
            if d == op: return "moveOntoPawn"
            return None
        dr, dc = d[0]-me[0], d[1]-me[1]
        adj = op in nbrs(me, n) and edge(me, op) not in b
        jump_shaped = adj and (
            d == (op[0]+(op[0]-me[0]), op[1]+(op[1]-me[1])) or
            (abs(d[0]-op[0]) + abs(d[1]-op[1]) == 1 and d != me))
        if jump_shaped:
            return None if d in jump_targets(s, actor) else "moveIllegalJump"
        return "moveNotAdjacent"
    if kind == "wall":
        if s.rem[actor] <= 0: return "noWallsRemaining"
        pr = wall_shape_problem(s.walls, arg, n)
        if pr: return pr
        tw = s.walls + [arg]
        if route_len(s.bp, 0, n, tw) is None or route_len(s.rp, n-1, n, tw) is None: return "wallBlocksPath"
        return None
    return "moveNotAdjacent"
def apply(s, actor, kind, arg):
    t = S(s.n, s.wpp, s.bp, s.rp, s.walls, s.tn, dict(s.rem), s.done, s.winner)
    if kind == "wall": t.walls.append(arg); t.rem[actor] -= 1
    else:
        if actor == "blue": t.bp = arg
        else: t.rp = arg
        if arg[0] == t.goal(actor): t.done, t.winner = True, actor
    t.tn += 1; return t
def state_problems(s, allow_goal_pawn=False):
    P = []; n = s.n
    for p in ("blue", "red"):
        r, c = s.pos(p)
        if not (0 <= r < n and 0 <= c < n): P.append(f"{p} pawn off board {s.pos(p)}")
    if s.bp == s.rp: P.append("pawns on the same cell")
    if not s.done and not allow_goal_pawn:
        if s.bp[0] == 0: P.append(f"Blue pawn on its goal row {s.bp} while game in progress")
        if s.rp[0] == n-1: P.append(f"Red pawn on its goal row {s.rp} while game in progress")
    ws = []
    for w in s.walls:
        pr = wall_shape_problem(ws, w, n)
        if pr: P.append(f"pre-existing walls are not a legal set ({w}: {pr})")
        ws.append(w)
    if not P:
        if route_len(s.bp, 0, n, s.walls) is None: P.append("Blue has no route")
        if route_len(s.rp, n-1, n, s.walls) is None: P.append("Red has no route")
    return P

# ------------------------------------------------------------------ parsing helpers
def section(title_regex, text=TEXT):
    m = re.search(r"^## " + title_regex + r".*?$", text, re.M)
    if not m: return ""
    rest = text[m.end():]; m2 = re.search(r"^## ", rest, re.M)
    return rest[:m2.start()] if m2 else rest
def expand_ids(s, prefix_hint=None):
    """expand 'R-WALL-01..06, 10' / 'T-MOVE-001, 003..006' style lists"""
    out, prefix, width = [], prefix_hint, None
    for tok in re.split(r"[,;]\s*|\s+and\s+", s):
        tok = tok.strip()
        m = re.match(r"^((?:R|T)-[A-Z]+-)(\d+)(?:\.\.(\d+))?", tok)
        if m: prefix, a, b = m.group(1), m.group(2), m.group(3); width = len(a)
        else:
            m = re.match(r"^(\d+)(?:\.\.(\d+))?", tok)
            if not m or not prefix: continue
            a, b = m.group(1), m.group(2); width = len(a)
        lo = int(a); hi = int(b) if b else lo
        for k in range(lo, hi+1): out.append(f"{prefix}{k:0{width}d}")
    return out
def cells(s): return [(int(a), int(b)) for a, b in re.findall(r"\((-?\d+),\s*(-?\d+)\)", s)]
def parse_walls(s):
    w = [(o, int(r), int(c)) for o, r, c in re.findall(r"\b([HV])\((\d+),(\d+)\)", s)]
    w += [(o, int(r), int(c)) for r, c, o in re.findall(r"\((\d+),(\d+),'([HV])'\)", s)]
    return w
def parse_action(s):
    m = re.search(r"\b(Blue|Red)?\s*M\s+(-?\d+),(-?\d+)", s)
    if m: return (m.group(1) or "").lower() or None, "move", (int(m.group(2)), int(m.group(3)))
    m = re.search(r"\b(Blue|Red)?\s*W\s+([HV])\s+(\d+),(\d+)", s)
    if m: return (m.group(1) or "").lower() or None, "wall", (m.group(2), int(m.group(3)), int(m.group(4)))
    return None
REASONS = ["matchFinished","wrongTurn","moveOutOfBoard","moveNotAdjacent","moveBlockedByWall","moveOntoPawn",
           "moveIllegalJump","noWallsRemaining","wallOutOfBounds","wallOverlaps","wallCrosses","wallBlocksPath"]
def reason_in(s):
    for r in REASONS:
        if r in s: return r
    return None
def build_state(given, actor):
    if "size=" in given: return None
    bm = re.search(r"Blue\((-?\d+),(-?\d+)\)", given); rm = re.search(r"Red\((-?\d+),(-?\d+)\)", given)
    bp = (int(bm.group(1)), int(bm.group(2))) if bm else None
    rp = (int(rm.group(1)), int(rm.group(2))) if rm else None
    walls = parse_walls(given)
    tn = None
    m = re.search(r"turn(?:Number)?\s*=\s*(\d+)", given)
    if m: tn = int(m.group(1))
    elif re.search(r"Red turn", given): tn = 1
    elif re.search(r"Blue turn", given): tn = 0
    elif actor == "red": tn = 1
    else: tn = 0
    done = "finished" in given.lower()
    st = S(bp=bp, rp=rp, walls=walls, tn=tn, done=done)
    m = re.search(r"Blue\s+(\d+)\s+walls", given)
    if m: st.rem["blue"] = int(m.group(1))
    st.rem["blue"] -= 0
    return st

# ------------------------------------------------------------------ 1. rule IDs & coverage matrix
defined = set(re.findall(r"\*\*(R-[A-Z]+-\d+)[^*]*:\*\*", TEXT)) | set(re.findall(r"^\|\s*(R-STATE-\d+)\s*\|", TEXT, re.M))
cat = section(r"9\."); mat = section(r"10\.")
tests = {}
for line in cat.splitlines():
    if line.startswith("| T-"):
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cols) >= 5: tests[cols[0]] = cols
for tid, cols in tests.items():
    for rid in expand_ids(cols[1]):
        if rid not in defined: bad("catalog", f"{tid} cites rule {rid} which is not defined in the spec")
covered = set()
for line in mat.splitlines():
    if not line.startswith("| R-"): continue
    a, b = [c.strip() for c in line.strip().strip("|").split("|", 1)]
    rids = expand_ids(a)
    if not rids: bad("matrix", f"cannot parse rule id(s) in matrix row: {a}")
    for rid in rids:
        if rid not in defined: bad("matrix", f"matrix lists {rid} which is not a defined rule (wrong ID format?)")
        covered.add(rid)
    if re.search(r"implicit|argument-based|structural|n/a", b, re.I): bad("matrix", f"{a}: 'implicit/argument-based' coverage is not allowed - needs an explicit test")
    for tid in expand_ids(b, "T-"):
        pass
    for m in re.finditer(r"\b(T-[A-Z]+-\d+)(?:\.\.(\d+))?", b):
        pass
    for tid in expand_ids(b):
        if tid not in tests: bad("matrix", f"{a}: cites test {tid} which does not exist in the catalog")
for rid in sorted(defined - covered): bad("matrix", f"rule {rid} is defined but missing from the coverage matrix")
if "R-NOLEGAL-01" in defined and not any(True for t in tests.values() if "R-NOLEGAL-01" in expand_ids(t[1])):
    bad("matrix", "R-NOLEGAL-01 has no catalog test row (a property/fuzz test row is required)")

# ------------------------------------------------------------------ 2. execute catalog rows
second_anchor_seen = set()
def anchor_dir(a, b, walls):
    """return list of (direction, is_second_anchor) for walls blocking edge a-b"""
    (r1,c1),(r2,c2) = a, b; out = []
    for o, r, c in walls:
        one = {edge(*x) for x in ([((r,c),(r+1,c)), ((r,c+1),(r+1,c+1))] if o == "H" else [((r,c),(r,c+1)), ((r+1,c),(r+1,c+1))])}
        if edge(a, b) in one:
            if o == "H": first = (min(r1,r2) == r and c1 == c)          # H(r,c) is the 'first' anchor for column c
            else:        first = (min(c1,c2) == c and r1 == r)
            out.append((("H" if o == "H" else "V"), not first))
    return out
for tid, cols in tests.items():
    given, when, then = cols[2], cols[3], cols[4]
    if "finished" in given.lower() and "any" in when.lower(): continue
    act = parse_action(when)
    actor = act[0] if act else None
    st = build_state(given, actor)
    if st is None: continue
    if re.search(r"(?<!\d)0 walls", given): st.rem["blue"] = 0
    if act is None and not re.search(r"Blue\(|Red\(|Wall", given): continue
    if not st.done:
        for p in state_problems(st): bad(tid, f"Given is not a legal in-progress state: {p}")
    if act and not st.done:
        who = actor or st.cp()
        got = validate(st, who, act[1], act[2])
        want = reason_in(then)
        if want and got != want: bad(tid, f"Then says {want} but reference engine says {got or 'legal'}")
        if not want and got: bad(tid, f"action is illegal per reference engine ({got}) but Then does not name a failure reason: '{then[:70]}'")
        if act[1] == "move" and got == "moveBlockedByWall":
            me = st.pos(who)
            for d, sec in anchor_dir(me, act[2], st.walls): 
                if sec: second_anchor_seen.add((tuple(act[2][i]-me[i] for i in (0,1)), d))
        m = re.search(r"Blue\((\d+),(\d+)\)", then)
        if got is None and act[1] == "move" and m and who == "blue":
            if act[2] != (int(m.group(1)), int(m.group(2))): bad(tid, "Then final Blue cell disagrees with the action destination")
    if not act and "Blue(" in given and re.search(r"length\s*=\s*(\d+)", then):
        pass
# length claims in catalog (PATH rows)
for tid, cols in tests.items():
    if not tid.startswith("T-PATH"): continue
    given, then = cols[2], cols[4]
    st = build_state(given, None)
    if st is None: continue
    m1 = re.search(r"Blue length\s*=\s*(\d+)", then); m2 = re.search(r"Red length\s*=\s*(\d+)", then)
    if m1 and route_len(st.bp, 0, st.n, st.walls) != int(m1.group(1)): bad(tid, f"Blue length is {route_len(st.bp,0,st.n,st.walls)}, spec says {m1.group(1)}")
    if m2 and route_len(st.rp, st.n-1, st.n, st.walls) != int(m2.group(1)): bad(tid, f"Red length is {route_len(st.rp,st.n-1,st.n,st.walls)}, spec says {m2.group(1)}")
    if re.search(r"multiple walls|walls near|wall rejected", given, re.I): bad(tid, "Given is vague (walls not listed explicitly)")
for tid in ("T-WALL-013","T-DET-001"):
    if tid in tests and re.search(r"wall rejected|Canonical order\.$|Moves first, then walls\. Canonical order", tests[tid][2]+" "+tests[tid][4]):
        bad(tid, "Given/Then is vague - must list exact walls/cells and exact expected actions")

# ------------------------------------------------------------------ 3. worked examples
ex = section(r"8\.")
for m in re.finditer(r"^### (Example \d+[a-z]?):.*?\n```(.*?)```", ex, re.M | re.S):
    name, body = m.group(1), m.group(2)
    before = body.split("Action")[0]
    am = re.search(r"Action(?: \(by (Blue|Red)\))?:\s*(.*)", body)
    if not am: continue
    act = parse_action(am.group(2)); 
    if not act: continue
    actor = (am.group(1) or "").lower() or None
    bm = re.search(r"Blue at \((\d+),(\d+)\)", before); rm = re.search(r"Red at \((\d+),(\d+)\)", before)
    walls = []
    for ln in before.splitlines():
        if re.search(r"\b[Ww]alls?\b\s*:", ln): walls += parse_walls(ln.split(":",1)[1].split("—")[0].split(" - ")[0])
    cpm = re.search(r"currentPlayer:\s*(Blue|Red)", before); tnm = re.search(r"turnNumber:\s*(\d+)", before)
    tn = int(tnm.group(1)) if tnm else (1 if (cpm and cpm.group(1) == "Red") else 0)
    st = S(bp=(int(bm.group(1)), int(bm.group(2))) if bm else None, rp=(int(rm.group(1)), int(rm.group(2))) if rm else None, walls=walls, tn=tn)
    hm = re.search(r"Blue has (\d+) wall", before)
    if hm: st.rem["blue"] = int(hm.group(1))
    for p in state_problems(st): bad(name, f"'Before' is not a legal in-progress state: {p}")
    who = actor or st.cp()
    got = validate(st, who, act[1], act[2])
    rm2 = re.search(r"Result:\s*ILLEGAL\s*-\s*(\w+)", body)
    if rm2 and got != rm2.group(1): bad(name, f"Result says {rm2.group(1)}, reference engine says {got or 'legal'}")
    if not rm2 and got: bad(name, f"example shows a legal action but reference engine says {got}")
    if act[1] == "move" and got == "moveBlockedByWall":
        me = st.pos(who)
        for d, sec in anchor_dir(me, act[2], st.walls):
            if sec: second_anchor_seen.add((tuple(act[2][i]-me[i] for i in (0,1)), d))
    if "route" in body and act[1] == "wall" and not got:
        tw = st.walls + [act[2]]
        for who2, goal in (("Blue", 0), ("Red", st.n-1)):
            lm = re.search(who2 + r" route:.*?\(length (\d+)\)", body)
            if lm and route_len(st.pos(who2.lower()), goal, st.n, tw) != int(lm.group(1)):
                bad(name, f"{who2} route length is {route_len(st.pos(who2.lower()), goal, st.n, tw)}, spec says {lm.group(1)}")
        for rt in re.findall(r"route:\s*((?:\(\d+,\d+\)\s*(?:->|→)\s*)+\(\d+,\d+\))", body):
            path = cells(rt); b = blocked_edges(tw)
            for a2, b2 in zip(path, path[1:]):
                if b2 not in nbrs(a2, st.n) or edge(a2, b2) in b: bad(name, f"listed route uses a blocked/non-adjacent step {a2}->{b2}")
need = {((1,0),"H"),((-1,0),"H"),((0,-1),"V"),((0,1),"V")}
got_dirs = {(d, o) for d, o in second_anchor_seen}
for want in sorted(need):
    if want not in got_dirs: bad("coverage", f"no catalog test/worked example where the SECOND anchor alone blocks a move in direction {want[0]} ({want[1]} wall)")
edge_case = False
for tid, cols in tests.items():
    if re.search(r"\(\d+,8\)|\(8,\d+\)", cols[2]) and "moveBlockedByWall" in cols[4]: edge_case = True
if not edge_case: bad("coverage", "no board-edge blocking test (e.g. pawn in the last column blocked by the only existing anchor)")

# ------------------------------------------------------------------ 4. scripted game
sg = section(r"15\.")
st = S(); n_actions = 0; fine = True
for m in re.finditer(r"^\s*(\d+)\.\s+(Blue|Red)\s+(M\s+\d+,\d+|W\s+[HV]\s+\d+,\d+)", sg, re.M):
    k, who, a = int(m.group(1)), m.group(2).lower(), m.group(3)
    act = parse_action(a); n_actions += 1
    if k != n_actions: bad("scripted game", f"action numbering jumps at {k}")
    got = validate(st, who, act[1], act[2])
    if got: bad("scripted game", f"action {k} ({who} {a}) is ILLEGAL: {got}  (Blue {st.bp}, Red {st.rp}, tn={st.tn})"); fine = False; break
    st = apply(st, who, act[1], act[2])
if n_actions == 0: bad("scripted game", "no scripted game found")
elif fine:
    if not st.done: bad("scripted game", "game does not end in a win")
    m = re.search(r"winner:\s*(Blue|Red)", sg)
    if m and st.winner != m.group(1).lower(): bad("scripted game", f"claims winner {m.group(1)} but engine winner is {st.winner}")
    if n_actions < 12: bad("scripted game", "must have at least 12 actions")
    scripted_final = st

# ------------------------------------------------------------------ 5. JSON blocks
def check_json(obj, where):
    try:
        n, wpp = obj["boardConfig"]["size"], obj["boardConfig"]["wallsPerPlayer"]
        bp = (obj["pawnPositions"]["blue"]["row"], obj["pawnPositions"]["blue"]["column"])
        rp = (obj["pawnPositions"]["red"]["row"], obj["pawnPositions"]["red"]["column"])
        walls = [(w["orientation"], w["anchor"]["row"], w["anchor"]["column"]) for w in obj["walls"]]
        owners = [w["owner"] for w in obj["walls"]]
        tn, status, winner, cur = obj["turnNumber"], obj["status"], obj["winner"], obj["currentPlayer"]
        rem = obj["remainingWalls"]
    except Exception as e: bad(where, f"JSON does not match the documented shape: {e!r}"); return
    s = S(n, wpp, bp, rp, walls, tn, dict(rem), status == "finished", winner)
    for p in state_problems(s, allow_goal_pawn=(status == "finished")): bad(where, p)
    if cur != s.cp(): bad(where, f"currentPlayer={cur} contradicts R-STATE-05 for turnNumber={tn}")
    for p in ("blue", "red"):
        if rem[p] + owners.count(p) != wpp: bad(where, f"R-STATE-02 violated for {p}")
    if (winner is not None) != (status == "finished"): bad(where, "R-STATE-03 violated")
    if status == "finished" and pos_row(s, winner) != s.goal(winner): bad(where, "winner is not on its goal row")
    for p, start in (("blue", (n-1, n//2)), ("red", (0, n//2))):
        acts = (tn+1)//2 if p == "blue" else tn//2
        moves = acts - owners.count(p)
        cur_pos = s.pos(p); dist = abs(cur_pos[0]-start[0]) + abs(cur_pos[1]-start[1])
        if moves < 0 or dist > 2*moves: bad(where, f"{p} pawn at {cur_pos} is unreachable: only {moves} move action(s) available (walls placed: {owners.count(p)}, actions: {acts})")
def pos_row(s, p): return s.pos(p)[0]
jsec = section(r"7\.") + section(r"16\.")
found_json = 0
for m in re.finditer(r"```\s*\n?(\{.*?\})\s*```", jsec, re.S):
    raw = m.group(1); found_json += 1
    try: obj = json.loads(raw)
    except Exception as e: bad("JSON sample", f"not valid JSON ({e.msg}); e.g. placeholder like [...]"); continue
    if "boardConfig" in obj: check_json(obj, "JSON sample")
if not re.search(r'"status"\s*:\s*"finished"', jsec): bad("JSON sample", "no finished-state JSON sample")

# ------------------------------------------------------------------ 6. decision log / open questions / misc content
dl = section(r"11\.")
rows = dict((m.group(1), m.group(2)) for m in re.finditer(r"^\|\s*(D-\d+)\s*\|\s*(.*?)\s*\|", dl, re.M))
kw = {"D-01":["9"],"D-02":["coordinate"],"D-03":["Blue","Red"],"D-04":["start"],"D-05":["goal"],"D-06":["first"],"D-07":["one"],"D-08":["10"],
      "D-09":["2"],"D-10":["anchor"],"D-11":["overlap"],"D-12":["cross"],"D-13":["path"],"D-14":["jump"],"D-15":["win"],"D-16":["draw"],"D-17":["order"],"D-18":["moveIllegalJump"]}
for d, words in kw.items():
    if d not in rows: bad("decision log", f"{d} missing"); continue
    for w in words:
        if w.lower() not in rows[d].lower(): bad("decision log", f"{d} does not match the owner decision (expected to mention '{w}'): {rows[d][:80]}")
if len(set(rows.values())) != len(rows): bad("decision log", "duplicate decision text (e.g. 'Blue moves first' listed twice)")
for d in set(re.findall(r"\((D-\d+)\)", TEXT)):
    if d not in rows: bad("decision log", f"rule text cites {d} which is not in the decision log")
oq = section(r"12\.")
if not re.search(r"option", oq, re.I) or not re.search(r"recommend|default", oq, re.I): bad("open questions", "open questions need options, consequences and a recommended default")
if re.search(r"Q-02", oq) and "Resolved" not in oq: bad("open questions", "Q-02 is stale")
s52 = section(r"5\.")
if "moveIllegalJump" not in s52 or not re.search(r"jump[- ]shape|classif", s52, re.I): bad("§5", "taxonomy section does not define how destinations are classified (step / jump-shaped / other)")
nl = section(r"3\.")
m = re.search(r"### 3\.9.*?(?=### 3\.10)", nl, re.S); nlt = m.group(0) if m else ""
for w in ("component", "invariant", "straight jump", "property"):
    if w not in nlt.lower(): bad("R-NOLEGAL-01", f"justification/property-test requirement must mention '{w}' (see Phase 1.3 prompt §2.6)")
if "the opponent" in nlt.lower() and "not occupied by the opponent" in nlt.lower(): bad("R-NOLEGAL-01", "proof still claims the first route cell is a plain legal step (it may be the opponent's cell -> jump case)")
if re.search(r"No wall MUST separate", TEXT): bad("R-MOVE-03", "still uses the ambiguous 'No wall MUST separate' wording")
if re.search(r"Row\s+0:.*Red goal", TEXT) or re.search(r"Row\s+8:.*Blue goal", TEXT): bad("§3.1", "board diagram goal labels are backwards")
s0 = S()
init_moves = len(legal_moves(s0, "blue"))
init_walls = sum(1 for o in "HV" for r in range(8) for c in range(8) if validate(s0, "blue", "wall", (o, r, c)) is None)
if (init_moves, init_walls) != (3, 128): bad("reference", f"sanity: initial counts {init_moves}/{init_walls}")

# ------------------------------------------------------------------ report
print(f"Checked {PATH}: {len(tests)} catalog rows, {len(defined)} rule IDs, {len(covered)} in matrix.")
if FIND:
    print(f"\n{len(FIND)} PROBLEM(S):")
    for f in FIND: print(" -", f)
    sys.exit(1)
print("OK: spec is consistent with the reference engine.")
