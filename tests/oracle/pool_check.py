import json,collections
from oracle import *
P=json.load(open("../../data/practice.json"))
bands={0:(2,3),1:(4,5),2:(6,7)}
print("keys",len(P),sorted(P,key=int)[:3],sorted(P,key=int)[-1])
seen=collections.defaultdict(list); bad=0
stats=collections.defaultdict(list)
for k in sorted(P,key=int):
    assert len(P[k])==3,k
    for lv,p in enumerate(P[k]):
        g=parse(p["board"]["rows"]); w,h=p["board"]["n"]
        assert len(g)==h and len(g[0])==w
        errs=[]
        if resolve(g)[0]!=g: errs.append("unstable")
        if empty(g): errs.append("empty")
        path=p["path"]
        if len(path)%3: errs.append("pathlen")
        gg=g
        for i in range(0,len(path),3):
            tok=path[i:i+3]; d,x,y=canon_token(gg,tok)
            r=move(gg,x,y,d)
            if r is None: errs.append("ignored move %s at %d"%(tok,i//3)); break
            gg=r[0]
            if empty(gg) and i+3<len(path): errs.append("empty before end")
        else:
            if not empty(gg): errs.append("not empty")
        if len(path)//3!=p["par"]: errs.append("par!=len")
        if not(bands[lv][0]<=p["par"]<=bands[lv][1]): errs.append("band")
        if p["par"]>p["upper"]: errs.append("par>upper")
        if p.get("fallback"): errs.append("fallback")
        if not p["exact"]: errs.append("notexact")
        if (w,h)!=((5,5),(6,6),(6,6))[lv]: errs.append("size %s"%[(w,h)])
        vals=len({v for r in g for v in r if v})
        stats[lv].append((p["par"],total_tiles(g),vals))
        seen[tuple(p["board"]["rows"])].append((k,lv))
        if errs: bad+=1; print("set",k,"lv",lv,errs)
dup={b:v for b,v in seen.items() if len(v)>1}
print("problems",bad,"duplicates",len(dup)); 
for b,v in dup.items(): print(v)
for lv in range(3):
    pars=[s[0] for s in stats[lv]]; t=[s[1] for s in stats[lv]]
    print("lv",lv,"par",{p:pars.count(p) for p in set(pars)},"tiles",min(t),max(t),"minvals",min(s[2] for s in stats[lv]))
# per set ascending
asc=sum(1 for k in P if P[k][0]["par"]<=P[k][1]["par"]<=P[k][2]["par"] and P[k][0]["par"]<P[k][2]["par"])
print("sets ascending",asc)
# per-set tiles ascending
print("tiles asc",sum(1 for k in P if total_tiles(parse(P[k][0]["board"]["rows"]))<total_tiles(parse(P[k][1]["board"]["rows"]))<total_tiles(parse(P[k][2]["board"]["rows"]))))
# also symmetric/mirror duplicates
def mirror(rows): return tuple(r[::-1] for r in rows)
ms=[b for b in seen if mirror(b) in seen and mirror(b)!=b]
print("mirror dupes",len(ms)//2)
