#!/usr/bin/env python3
"""Wallforge reference model - game_spec.md v1.0.2"""
import sys
from collections import deque
from typing import Any, List, Optional, Set, Tuple

Cell = Tuple[int, int]
Walls = List[Tuple[int, int, str]]

class GS:
    def __init__(self, sz=9, wpp=10, bp=(8,4), rp=(0,4),
                 bw=None, rw=None, tn=0, st='inProgress', wn=None):
        self.sz=sz; self.wpp=wpp; self.bp=bp; self.rp=rp
        self.bw=list(bw or []); self.rw=list(rw or [])
        self.tn=tn; self.st=st; self.wn=wn
    def copy(self):
        return GS(self.sz,self.wpp,self.bp,self.rp,
                  list(self.bw),list(self.rw),self.tn,self.st,self.wn)
    def cp(self): return 'blue' if self.tn%2==0 else 'red'
    def rem(self,p): return self.wpp-(len(self.bw) if p=='blue' else len(self.rw))
    def aw(self): return self.bw+self.rw
    def done(self): return self.st=='finished'

def _bl(walls):
    e=set()
    for r,c,o in walls:
        if o=='H':
            e.add(tuple(sorted(((r,c),(r+1,c)))))
            e.add(tuple(sorted(((r,c+1),(r+1,c+1)))))
        else:
            e.add(tuple(sorted(((r,c),(r,c+1)))))
            e.add(tuple(sorted(((r+1,c),(r+1,c+1)))))
    return e

def _adj(r,c,sz):
    return [(r+dr,c+dc) for dr,dc in [(-1,0),(1,0),(0,-1),(0,1)]
            if 0<=r+dr<sz and 0<=c+dc<sz]

def bfs_len(start, goal_row, sz, walls):
    b=_bl(walls); vis={start:0}; q=deque([start])
    while q:
        r,c=q.popleft(); d=vis[(r,c)]
        if r==goal_row: return d
        for nr,nc in _adj(r,c,sz):
            if (nr,nc) not in vis and tuple(sorted(((r,c),(nr,nc)))) not in b:
                vis[(nr,nc)]=d+1; q.append((nr,nc))
    return None

def bfs_ok(start, goal_row, sz, walls):
    return bfs_len(start,goal_row,sz,walls) is not None

def _jstr(mover, opp, sz, walls):
    mr,mc=mover; orr,oc=opp; dr,dc=orr-mr,oc-mc
    b=_bl(walls)
    if tuple(sorted((mover,opp))) in b: return None
    br,bc=orr+dr,oc+dc
    if 0<=br<sz and 0<=bc<sz and tuple(sorted((opp,(br,bc)))) not in b:
        return (br,bc)
    return None

def _jdiag(mover, opp, sz, walls):
    mr,mc=mover; orr,oc=opp; dr,dc=orr-mr,oc-mc
    b=_bl(walls)
    if tuple(sorted((mover,opp))) in b: return []
    return [(orr+pdr,oc+pdc) for pdr,pdc in [(-dc,dr),(dc,-dr)]
            if 0<=orr+pdr<sz and 0<=oc+pdc<sz
            and tuple(sorted((opp,(orr+pdr,oc+pdc)))) not in b]

def legal_moves(s):
    if s.done(): return []
    if s.cp()=='blue': mr,mc=s.bp; opp=s.rp
    else: mr,mc=s.rp; opp=s.bp
    walls=s.aw(); b=_bl(walls); res=[]
    for nr,nc in _adj(mr,mc,s.sz):
        if (nr,nc)==opp:
            st=_jstr((mr,mc),opp,s.sz,walls)
            if st: res.append(st)
            else: res.extend(_jdiag((mr,mc),opp,s.sz,walls))
        elif tuple(sorted(((mr,mc),(nr,nc)))) not in b:
            res.append((nr,nc))
    return sorted(set(res))

def _wov(wo,wr,wc,walls):
    for r2,c2,o2 in walls:
        if wo==o2:
            if wo=='H' and wr==r2 and abs(wc-c2)<=1: return True
            if wo=='V' and wc==c2 and abs(wr-r2)<=1: return True
    return False

def _wcr(wo,wr,wc,walls):
    return any(wo!=o2 and wr==r2 and wc==c2 for r2,c2,o2 in walls)

def try_wall(s,o,wr,wc):
    if s.done(): return 'matchFinished'
    if s.rem(s.cp())<=0: return 'noWallsRemaining'
    if wr<0 or wr>s.sz-2 or wc<0 or wc>s.sz-2: return 'wallOutOfBounds'
    aw=s.aw()
    if _wov(o,wr,wc,aw): return 'wallOverlaps'
    if _wcr(o,wr,wc,aw): return 'wallCrosses'
    tw=aw+[(wr,wc,o)]
    if not bfs_ok(s.bp,0,s.sz,tw): return 'wallBlocksPath'
    if not bfs_ok(s.rp,s.sz-1,s.sz,tw): return 'wallBlocksPath'
    return None

def apply_wall(s,o,wr,wc):
    ns=s.copy()
    if ns.cp()=='blue': ns.bw.append((wr,wc,o))
    else: ns.rw.append((wr,wc,o))
    ns.tn+=1; return ns

def apply_move(s,dest):
    ns=s.copy(); old_cp=ns.cp()
    if old_cp=='blue': ns.bp=dest
    else: ns.rp=dest
    goal=0 if old_cp=='blue' else ns.sz-1
    if dest[0]==goal: ns.st='finished'; ns.wn=old_cp
    ns.tn+=1; return ns

def validate(s, action, arg=None):
    if s.done(): return 'matchFinished'
    cp=s.cp()
    if action=='move':
        dest=arg
        if cp=='blue': mr,mc=s.bp; opp=s.rp
        else: mr,mc=s.rp; opp=s.bp
        if not (0<=dest[0]<s.sz and 0<=dest[1]<s.sz): return 'moveOutOfBoard'
        dr,dc=dest[0]-mr,dest[1]-mc; man=abs(dr)+abs(dc)
        b=_bl(s.aw())
        if man==1:
            if tuple(sorted(((mr,mc),dest))) in b: return 'moveBlockedByWall'
            if dest==opp: return 'moveOntoPawn'
            return None
        elif man==2 and (dr==0 or dc==0):
            if dest==opp: return 'moveOntoPawn'
            mid=((mr+dest[0])//2,(mc+dest[1])//2)
            if mid==opp:
                if tuple(sorted(((mr,mc),opp))) in b: return 'moveIllegalJump'
                if tuple(sorted((opp,dest))) in b: return 'moveIllegalJump'
                return None
            return 'moveNotAdjacent'
        elif man==2 and dr!=0 and dc!=0:
            if opp not in _adj(mr,mc,s.sz): return 'moveNotAdjacent'
            if tuple(sorted(((mr,mc),opp))) in b: return 'moveNotAdjacent'
            if _jstr((mr,mc),opp,s.sz,s.aw()): return 'moveIllegalJump'
            if tuple(sorted((opp,dest))) in b: return 'moveIllegalJump'
            return None
        return 'moveNotAdjacent'
    elif action=='wall':
        return try_wall(s,arg[0],arg[1],arg[2])
    return 'moveNotAdjacent'

def validate_p(s, action, arg=None, player=None):
    if s.done(): return 'matchFinished'
    if player and player!=s.cp(): return 'wrongTurn'
    return validate(s, action, arg)

results=[]; verbose="-v" in sys.argv
def check(cid, exp, got):
    ok=(exp==got)
    results.append((cid,ok,exp,got))
    if verbose or not ok:
        tag='PASS' if ok else 'FAIL'
        print(f"{tag}: {cid} expected={exp} got={got}")
def mk(**kw): return GS(**kw)

# === WORKED EXAMPLES ===
s=mk(); check("EX-01a",None,validate(s,'move',(7,4)))
ns=apply_move(s,(7,4)); check("EX-01b","red",ns.cp()); check("EX-01c",1,ns.tn)

s=mk(bp=(3,4),rp=(0,4),bw=[(3,4,'H')],tn=0)
check("EX-02",'moveBlockedByWall',validate(s,'move',(4,4)))

s=mk(bp=(5,3),rp=(0,4),rw=[(5,3,'V')],tn=0)
check("EX-03",'moveBlockedByWall',validate(s,'move',(5,4)))

s=mk(bp=(5,4),rp=(0,0),tn=1)
check("EX-04",'moveOutOfBoard',validate(s,'move',(-1,0)))

s=mk(bp=(8,4),rp=(0,4),tn=0); check("EX-05a",None,validate(s,'wall',('H',0,0)))
ns=apply_wall(s,'H',0,0); check("EX-05b",9,ns.rem('blue'))

s=mk(bp=(8,4),rp=(0,4),tn=0); check("EX-06",'wallOutOfBounds',validate(s,'wall',('H',8,0)))

s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0)
check("EX-07",'wallOverlaps',validate(s,'wall',('H',3,3)))

s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0)
check("EX-08",'wallOverlaps',validate(s,'wall',('H',3,4)))

s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0)
check("EX-09",None,validate(s,'wall',('H',3,5)))

s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0)
check("EX-10",'wallCrosses',validate(s,'wall',('V',3,3)))

s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0)
check("EX-11",None,validate(s,'wall',('V',4,3)))

s=mk(bp=(5,4),rp=(4,4),tn=0); check("EX-12a",None,validate(s,'move',(3,4)))
ns=apply_move(s,(3,4)); check("EX-12b",(3,4),ns.bp)

s=mk(bp=(5,4),rp=(4,4),bw=[(3,4,'H')],tn=0); check("EX-13a",None,validate(s,'move',(4,3)))
ns=apply_move(s,(4,3)); check("EX-13b",(4,3),ns.bp)

s=mk(bp=(1,4),rp=(8,4),tn=0); check("EX-14a",None,validate(s,'move',(0,4)))
ns=apply_move(s,(0,4)); check("EX-14b",'finished',ns.st); check("EX-14c",'blue',ns.wn)

s=mk(bp=(8,4),rp=(0,4),tn=0); check("EX-15",'wrongTurn',validate_p(s,'move',(1,4),player='red'))

walls9=[(0,0,'H'),(0,2,'H'),(0,4,'H'),(0,6,'H'),(2,0,'H'),(2,2,'H'),(2,4,'H'),(2,6,'H'),(4,0,'H')]
s=mk(bp=(8,4),rp=(0,4),bw=list(walls9),tn=0)
check("EX-16a",1,s.rem('blue'))
check("EX-16b",None,validate(s,'wall',('H',4,2)))
ns=apply_wall(s,'H',4,2); check("EX-16c",0,ns.rem('blue'))
s2=mk(bp=(8,4),rp=(0,4),bw=[(0,0,'H'),(0,2,'H'),(0,4,'H'),(0,6,'H'),(2,0,'H'),(2,2,'H'),(2,4,'H'),(2,6,'H'),(4,0,'H'),(4,2,'H')],tn=0)
check("EX-16d",0,s2.rem('blue'))
check("EX-16e",'noWallsRemaining',validate(s2,'wall',('H',6,0)))

s=mk(bp=(8,4),rp=(0,4),tn=0); check("EX-17a",None,validate(s,'wall',('H',4,3)))
check("EX-17b",9,bfs_len((8,4),0,9,[(4,3,'H')]))
check("EX-17c",9,bfs_len((0,4),8,9,[(4,3,'H')]))

s=mk(bp=(8,0),rp=(0,4),bw=[(7,0,'H')],tn=0)
check("EX-18",'wallBlocksPath',validate(s,'wall',('V',7,1)))

# === MOVEMENT TESTS ===
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-MOVE-001",None,validate(s,'move',(7,4)))
s=mk(bp=(3,3),rp=(0,4),tn=0); check("T-MOVE-002",None,validate(s,'move',(4,3)))
s=mk(bp=(5,4),rp=(0,0),tn=1); check("T-MOVE-003",'moveOutOfBoard',validate(s,'move',(-1,0)))
s=mk(bp=(5,4),rp=(0,0),tn=1); check("T-MOVE-004",'moveOutOfBoard',validate(s,'move',(0,-1)))
s=mk(bp=(8,8),rp=(0,4),tn=0); check("T-MOVE-005",'moveOutOfBoard',validate(s,'move',(8,9)))
s=mk(bp=(8,8),rp=(0,4),tn=0); check("T-MOVE-006",'moveOutOfBoard',validate(s,'move',(9,8)))
s=mk(bp=(3,4),rp=(0,4),bw=[(3,4,'H')],tn=0); check("T-MOVE-007",'moveBlockedByWall',validate(s,'move',(4,4)))
s=mk(bp=(5,3),rp=(0,4),rw=[(5,3,'V')],tn=0); check("T-MOVE-008",'moveBlockedByWall',validate(s,'move',(5,4)))
s=mk(bp=(5,4),rp=(4,4),tn=0); check("T-MOVE-009",'moveOntoPawn',validate(s,'move',(4,4)))
s=mk(bp=(1,4),rp=(8,4),tn=0); ns=apply_move(s,(0,4)); check("T-MOVE-010",'finished',ns.st)
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-MOVE-011",'wrongTurn',validate_p(s,'move',(1,4),player='red'))
s=mk(bp=(0,4),rp=(8,4),tn=0,st='finished',wn='blue'); check("T-MOVE-012",'matchFinished',validate(s,'move',(0,0)))
s=mk(bp=(5,5),rp=(0,4),tn=0); check("T-MOVE-013",None,validate(s,'move',(5,4)))
s=mk(bp=(5,5),rp=(0,4),tn=0); check("T-MOVE-014",None,validate(s,'move',(4,5)))

# === JUMP TESTS ===
s=mk(bp=(5,4),rp=(4,4),tn=0); check("T-JUMP-001",None,validate(s,'move',(3,4)))
s=mk(bp=(5,4),rp=(4,4),bw=[(3,4,'H')],tn=0); check("T-JUMP-002",None,validate(s,'move',(4,3)))
s=mk(bp=(5,4),rp=(4,4),bw=[(3,4,'H')],tn=0); check("T-JUMP-003",None,validate(s,'move',(4,5)))
s=mk(bp=(1,4),rp=(0,4),rw=[(0,3,'V')],tn=0); check("T-JUMP-004",None,validate(s,'move',(0,5)))
s=mk(bp=(1,4),rp=(0,4),tn=0); ns=apply_move(s,(0,3)); check("T-JUMP-005",'finished',ns.st)
s=mk(bp=(1,4),rp=(0,4),rw=[(0,3,'V')],tn=0); check("T-JUMP-006",'moveIllegalJump',validate(s,'move',(0,3)))
s=mk(bp=(1,4),rp=(0,4),tn=0); check("T-JUMP-007",'moveOntoPawn',validate(s,'move',(0,4)))
s=mk(bp=(5,4),rp=(4,4),tn=0); ns=apply_move(s,(3,4)); check("T-JUMP-008",1,ns.tn)

# === WALL TESTS ===
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-WALL-001",None,validate(s,'wall',('H',0,0)))
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-WALL-002",'wallOutOfBounds',validate(s,'wall',('H',8,0)))
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-WALL-003",'wallOutOfBounds',validate(s,'wall',('V',0,8)))
s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-WALL-004",'wallOverlaps',validate(s,'wall',('H',3,3)))
s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-WALL-005",'wallOverlaps',validate(s,'wall',('H',3,4)))
s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-WALL-006",None,validate(s,'wall',('H',3,5)))
s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-WALL-007",'wallCrosses',validate(s,'wall',('V',3,3)))
s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-WALL-008",None,validate(s,'wall',('V',4,3)))
s=mk(bp=(8,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-WALL-009",None,validate(s,'wall',('H',3,5)))
s=mk(bp=(8,4),rp=(0,4),wpp=0,tn=0); check("T-WALL-010",'noWallsRemaining',validate(s,'wall',('H',3,3)))
s=mk(bp=(8,0),rp=(0,4),bw=[(7,0,'H')],tn=0); check("T-WALL-011",'wallBlocksPath',validate(s,'wall',('V',7,1)))
s=mk(bp=(8,4),rp=(0,4),rw=[(4,4,'V')],tn=0); check("T-WALL-012",None,validate(s,'wall',('V',4,3)))
s=mk(bp=(8,0),rp=(0,4),bw=[(7,0,'H')],tn=0)
r=validate(s,'wall',('V',7,1)); check("T-WALL-013a",'wallBlocksPath',r)
check("T-WALL-013b",(8,0),s.bp); check("T-WALL-013c",9,s.rem('blue'))

# === PATHFINDING TESTS ===
check("T-PATH-001a",8,bfs_len((8,4),0,9,[])); check("T-PATH-001b",8,bfs_len((0,4),8,9,[]))
check("T-PATH-002a",9,bfs_len((8,4),0,9,[(4,3,'H')]))
check("T-PATH-002b",9,bfs_len((0,4),8,9,[(4,3,'H')]))
w3=[(3,3,'H'),(5,3,'V'),(4,3,'H')]
check("T-PATH-003a",True,bfs_ok((8,4),0,9,w3)); check("T-PATH-003b",True,bfs_ok((0,4),8,9,w3))
s=mk(bp=(8,0),rp=(0,4),bw=[(7,0,'H')],tn=0)
check("T-PATH-004",'wallBlocksPath',validate(s,'wall',('V',7,1)))
check("T-PATH-005",2,bfs_len((2,0),0,9,[]))
check("T-PATH-006",True,bfs_ok((8,4),0,9,[(4,3,'H')])==bfs_ok((0,4),8,9,[(4,3,'H')])==True)

# === WIN TESTS ===
s=mk(bp=(1,4),rp=(8,4),tn=0); ns=apply_move(s,(0,4)); check("T-WIN-001",'finished',ns.st)
s=mk(bp=(3,2),rp=(7,4),tn=1); ns=apply_move(s,(8,4)); check("T-WIN-002",'finished',ns.st)
s=mk(bp=(7,4),rp=(1,4),tn=1); r=validate(s,'move',(0,4)); check("T-WIN-003a",None,r)
ns=apply_move(s,(0,4)); check("T-WIN-003b",'inProgress',ns.st); check("T-WIN-003c",None,ns.wn)
s=mk(st='finished',wn='blue'); check("T-WIN-004",'matchFinished',validate(s,'move',(0,0)))
s=mk(bp=(1,4),rp=(0,4),tn=0); ns=apply_move(s,(0,3)); check("T-WIN-005",'finished',ns.st)

# === TURN HANDLING ===
s=mk(bp=(8,4),rp=(0,4),tn=0); ns=apply_move(s,(7,4)); check("T-TURN-001",1,ns.tn); check("T-TURN-01c","red",ns.cp())
s=mk(bp=(7,4),rp=(0,4),tn=1); ns=apply_move(s,(1,4)); check("T-TURN-002",2,ns.tn); check("T-TURN-02c","blue",ns.cp())
s=mk(bp=(8,4),rp=(0,4),tn=0); ns=apply_wall(s,'H',0,0); check("T-TURN-003",1,ns.tn)
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-TURN-004",'moveNotAdjacent',validate(s,'pass',None))

# === SERIALIZATION ===
s=mk(bp=(8,4),rp=(0,4),tn=0); check("T-SERIAL-001",True,s.st=='inProgress' and s.bp==(8,4) and s.tn==0)
s=mk(bp=(7,4),rp=(1,4),bw=[(3,3,'H')],rw=[(5,2,'V')],tn=2)
check("T-SERIAL-002",True,s.st=='inProgress' and len(s.bw)==1 and len(s.rw)==1)
s=mk(bp=(0,4),rp=(8,4),st='finished',wn='blue',tn=15)
check("T-SERIAL-003",True,s.st=='finished' and s.wn=='blue')

# === DETERMINISM ===
s=mk(bp=(8,4),rp=(0,4),tn=0); mv=legal_moves(s); check("T-DET-002",3,len(mv))
check("T-DET-001",True,sorted(mv)==sorted([(7,4),(8,3),(8,5)]))
wc=sum(1 for o in ['H','V'] for r in range(8) for c in range(8) if try_wall(s,o,r,c) is None)
check("T-DET-003",128,wc); check("T-DET-004",131,len(mv)+wc)

# === CONFIG ===
s=GS(sz=7,wpp=8,bp=(6,3),rp=(0,3)); check("T-CONFIG-003c",6,bfs_len(s.bp,0,s.sz,[]))
s=GS(sz=5,wpp=5,bp=(4,2),rp=(0,2)); check("T-CONFIG-004c",4,bfs_len(s.bp,0,s.sz,[]))

# === SECOND-ANCHOR BLOCKING ===
s=mk(bp=(3,4),rp=(0,4),bw=[(3,3,'H')],tn=0); check("T-BLOCK-001",'moveBlockedByWall',validate(s,'move',(4,4)))
s=mk(bp=(5,4),rp=(0,4),rw=[(4,3,'V')],tn=0); check("T-BLOCK-002",'moveBlockedByWall',validate(s,'move',(5,3)))
s=mk(bp=(5,4),rp=(0,4),rw=[(4,4,'V')],tn=0); check("T-BLOCK-003",'moveBlockedByWall',validate(s,'move',(5,5)))
s=mk(bp=(3,8),rp=(0,4),rw=[(3,7,'H')],tn=0); check("T-BLOCK-005",'moveBlockedByWall',validate(s,'move',(4,8)))
s=mk(bp=(5,4),rp=(0,4),rw=[(4,3,'V')],tn=0); check("T-BLOCK-006",None,validate(s,'move',(5,5)))

# === ADDITIONAL ===
s=mk(bp=(1,0),rp=(0,0),tn=0); check("JUMP_EDGE",None,validate(s,'move',(0,1)))
s=mk(bp=(1,4),rp=(0,4),rw=[(0,3,'V'),(0,4,'V')],tn=0)
check("JUMP_BOTH_1",'moveIllegalJump',validate(s,'move',(0,3)))
check("JUMP_BOTH_2",'moveIllegalJump',validate(s,'move',(0,5)))
check("JUMP_BOTH_3",None,validate(s,'move',(2,4)))
s=mk(bp=(4,4),rp=(0,0),rw=[(0,0,'V')],tn=0)
check("WALL_SEAL",'wallBlocksPath',validate(s,'wall',('H',1,0)))
s=mk(bp=(8,4),rp=(0,4),tn=0)
for a in [(0,0),(0,7),(7,0),(7,7)]:
    check("COR_H_%s"%(a,),None,validate(s,'wall',('H',a[0],a[1])))
    check("COR_V_%s"%(a,),None,validate(s,'wall',('V',a[0],a[1])))
check("OOB_H",'wallOutOfBounds',validate(s,'wall',('H',8,0)))
check("OOB_V",'wallOutOfBounds',validate(s,'wall',('V',0,8)))
walls10=[(0,0,'H'),(0,2,'H'),(0,4,'H'),(0,6,'H'),(2,0,'H'),(2,2,'H'),(2,4,'H'),(2,6,'H'),(4,0,'H'),(4,2,'H')]
s=mk(bp=(8,4),rp=(0,4),bw=list(walls10),tn=0)
check("W10",0,s.rem('blue')); check("W11",'noWallsRemaining',validate(s,'wall',('H',6,0)))
check("PTHRU",2,bfs_len((2,0),0,9,[]))
s=mk(bp=(8,0),rp=(0,4),tn=0); check("PPAWN",None,validate(s,'wall',('H',7,0)))
check("PPAWN_R",True,bfs_ok((8,0),0,9,[(7,0,'H')]))

# === SCRIPTED GAME ===
s=mk(bp=(8,4),rp=(0,4),tn=0)
for t,arg in [('m',(7,4)),('m',(1,4)),('m',(6,4)),('m',(2,4)),('w',('H',3,3)),('m',(3,4)),('m',(5,4)),('w',('V',5,3)),('m',(4,5)),('w',('H',1,3)),('m',(3,5)),('w',('H',2,3)),('m',(2,5)),('m',(3,4)),('m',(1,5)),('m',(4,4)),('m',(0,5))]:
    s=apply_move(s,arg) if t=='m' else apply_wall(s,arg[0],arg[1],arg[2])
check("SG",True,s.st=='finished' and s.wn=='blue' and s.tn==17)

# === SUMMARY ===
print()
total=len(results); passed=sum(1 for _,ok,_,_ in results if ok)
print("Total: %d  PASS: %d  FAIL: %d"%(total,passed,total-passed))
if total-passed:
    print("\nFailed:")
    for cid,ok,exp,got in results:
        if not ok: print("  %s: expected=%s got=%s"%(cid,exp,got))
