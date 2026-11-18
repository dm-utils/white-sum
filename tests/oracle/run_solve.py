import json,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
P=json.load(open("../../data/practice.json"))
lv=int(sys.argv[1]); ks=sorted(P,key=int)
def one(k):
    p=P[k][lv]; w,h=p["board"]["n"]
    inp=f'{w} {h} {"".join(p["board"]["rows"])} {p["par"]+1}\n'
    out=subprocess.run(["./solve"],input=inp,capture_output=True,text=True,timeout=3000).stdout.split()
    return k,p["par"],int(out[0]),int(out[1])
bad=0;tot=0
with ThreadPoolExecutor(4) as ex:
    for k,par,res,e in ex.map(one,ks):
        tot+=e
        if res!=par: bad+=1; print("MISMATCH set",k,"lv",lv,"par",par,"solver",res)
print("level",lv,"mismatches",bad,"expansions",tot)
