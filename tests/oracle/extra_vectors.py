"""Adds multi-ten, cross and long-run cases and writes ../data/oracle_vectors.json."""
import json,random
from oracle import *
import gen_vectors as vec
random.seed(7)
def runs_row(g,y):
    w=len(g[0]);out=[];x=0
    while x<w:
        if g[y][x]==0:x+=1;continue
        x1=x
        while x1<w and g[y][x1]:x1+=1
        out.append((x,x1));x=x1
    return out
def first_wave(g2):
    g=settle(g2);return tens(g),g
found={"multirow":[], "cross":[], "overSub":[]}
for i in range(400000):
    w=random.choice([6,7,8]);h=random.choice([2,3,4]);n=random.randint(5,w*h)
    g=vec.rnd_stable(w,h,n)
    if empty(g):continue
    x=random.randrange(w);y=random.randrange(h);d=random.choice('RLU')
    r=move(g,x,y,d)
    if r is None:continue
    # recompute first wave
    dx,dy={'R':(1,0),'L':(-1,0),'D':(0,-1),'U':(0,1)}[d]
    n_=[row[:] for row in g];s=g[y][x];t=g[y+dy][x+dx];n_[y][x]=t;n_[y+dy][x+dx]=s
    T,gs=first_wave(n_)
    if not T:continue
    rows={}
    for (yy,xx) in T: rows.setdefault(yy,[]).append(xx)
    cols={}
    for (yy,xx) in T: cols.setdefault(xx,[]).append(yy)
    # multirow: some row with two separate tens
    for yy,xs in rows.items():
        segs=[rs for rs in runs_row(gs,yy) if sum(gs[yy][rs[0]:rs[1]])==10]
        if len(segs)>=2 and len(found["multirow"])<12: found["multirow"].append((g,x,y,d))
    # cross
    rowt=set();colt=set()
    for yy in range(h):
        for rs in runs_row(gs,yy):
            if sum(gs[yy][rs[0]:rs[1]])==10: rowt.update((yy,xx) for xx in range(*rs))
    for xx in range(w):
        col=[gs[yy][xx] for yy in range(h)]
        c=sum(col)
        if c==10 and all(col[:col.index(0)] if 0 in col else col): colt.update((yy,xx) for yy in range(h) if gs[yy][xx])
    if rowt&colt and len(found["cross"])<12: found["cross"].append((g,x,y,d))
print({k:len(v) for k,v in found.items()})
extra=[]
for k,v in found.items():
    for (g,x,y,d) in v:
        r=move(g,x,y,d)
        extra.append({"name":k,"rows":render(g),"x":x,"y":y,"d":d,"res":render(r[0]),"waves":r[1]})
# hand cases: over run with a sub-run of ten stays; long runs
for rows,x,y,d in [(["21341."],0,0,'R'),(["12341","....."],0,0,'R')]:
    pass
hand=[(["....1","12341"],4,1,'L'),(["12351","....."],0,0,'R'),(["11111111"],0,0,'R'),(["1","1","1","1","1","1","1","1","1"],0,0,'R'),(["5.","5."],0,0,'R'),(["55","12"],0,1,'U')]
for rows,x,y,d in hand:
    g=parse(rows)
    if resolve(g)[0]!=g: print("unstable",rows);continue
    r=move(g,x,y,d)
    extra.append({"name":"hand","rows":rows,"x":x,"y":y,"d":d,"res":None if r is None else render(r[0]),"waves":None if r is None else r[1]})
base=json.load(open("oracle_vectors.tmp.json"))
json.dump(base+extra,open("../data/oracle_vectors.json","w"),separators=(",",":"))
print(len(base),len(extra))
