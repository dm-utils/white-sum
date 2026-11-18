"""Random and biased vectors for the oracle tests. Run extra_vectors.py (it imports this); python3 -B in this folder."""
import json,random
from oracle import *
random.seed(20261118)
cases=[]
def add(name,rows,x,y,d):
    g=parse(rows); r=move(g,x,y,d)
    cases.append({"name":name,"rows":rows,"x":x,"y":y,"d":d,"res":None if r is None else render(r[0]),"waves":None if r is None else r[1]})
# hand examples
add("run of 11 never vanishes", ["5.6.","1...","4..."],0,0,'R') if False else None
add("swap makes 10 row",["...","2 4 4".replace(' ','')],0,0,'R')
add("over row 12 stays",["....","2352"],0,0,'R')
add("row 10 plus extra 11",["1..","941"],0,0,'R')
add("two tens in one row 5+5 gap 4+3+3",["5555.","....."],3,0,'R') if False else None
add("two tens in one row", ["55.433","12345"],4,0,'L') if False else None
add("cross", ["23.5","4153"],3,1,'L')
add("chain", ["....5","33452"],4,1,'L')
add("slide splits over", ["34320","11214".replace('0','.')],3,1,'R') if False else None
add("ex4", ["3432.","11214"],3,1,'R')
add("ex1", [".2..","2433"],1,0,'U')
add("equal swap", ["22"],0,0,'R')
add("U into empty", ["2.","1."],0,1,'U') if False else None
add("D off board", ["2."],0,0,'D')
add("empty source", ["2."],1,0,'R')
# random
def rnd_stable(w,h,n):
    while True:
        g=[[0]*w for _ in range(h)]
        for _ in range(n):
            x=random.randrange(w)
            col=sum(1 for y in range(h) if g[y][x])
            if col<h: g[col][x]=random.randint(1,5)
        r,_=resolve(g)
        return r
for i in range(300):
    w=random.choice([2,3,4,5,6,7,8]); h=random.choice([2,3,4,5,6,7,9]); n=random.randint(1,w*h)
    g=rnd_stable(w,h,n)
    if empty(g): continue
    for (x,y) in [(random.randrange(w),random.randrange(h)) for _ in range(6)]:
        d=random.choice('RLDU')
        add("rnd%d"%i,render(g),x,y,d)

print(len(cases), sum(1 for c in cases if c and c['res'] is not None), sum(1 for c in cases if c and c['waves'] and c['waves']>1))
# biased: keep moves that vanish something, prefer chains
extra=0; chains=0; crosses=0
for i in range(200000):
    w=random.choice([4,5,6,7,8]); h=random.choice([3,4,5,6,9]); n=random.randint(4,w*h//2+3)
    g=rnd_stable(w,h,n)
    if empty(g): continue
    x=random.randrange(w); y=random.randrange(h); d=random.choice('RLU')
    r=move(g,x,y,d)
    if r is None: continue
    nt=total_tiles(g)-total_tiles(r[0])
    if nt==0: continue
    # cross: tens in first wave share a tile
    g2=[row[:] for row in g]; 
    if r[1]<2 and random.random()<0.9: continue
    add("vanish%d"%i,render(g),x,y,d); extra+=1; chains+= r[1]>1
    if extra>=400: break

print("extra",extra,"chains",chains)
keep=[c for c in cases if c and resolve(parse(c["rows"]))[0]==parse(c["rows"])]
# drop most plain random no-vanish cases to keep the file small
import random as R
keep=[c for c in keep if c["name"].startswith("vanish") or c["res"] is None and R.random()<0.15 or c["res"] is not None and R.random()<0.3 or not c["name"].startswith(("rnd","vanish"))]
json.dump(keep,open("oracle_vectors.tmp.json","w"),separators=(",",":"))
print("kept",len(keep),"ignored",sum(1 for c in keep if c["res"] is None),"multi",sum(1 for c in keep if c["waves"] and c["waves"]>1))
