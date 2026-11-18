"""Independent White Sum oracle. grid[y][x], y=0 bottom. Rules from design.md section 2 only."""
import json, random, sys

def parse(rows):
    h=len(rows); w=len(rows[0])
    return [[0 if rows[h-1-y][x]=='.' else int(rows[h-1-y][x]) for x in range(w)] for y in range(h)]

def render(g):
    return ["".join('.' if v==0 else str(v) for v in row) for row in reversed(g)]

def settle(g):
    h=len(g); w=len(g[0])
    n=[[0]*w for _ in range(h)]
    for x in range(w):
        col=[g[y][x] for y in range(h) if g[y][x]]
        for y,v in enumerate(col): n[y][x]=v
    return n

def tens(g):
    h=len(g); w=len(g[0]); gone=set()
    for y in range(h):
        x=0
        while x<w:
            if g[y][x]==0: x+=1; continue
            x1=x
            while x1<w and g[y][x1]: x1+=1
            if sum(g[y][x:x1])==10: gone.update((y,xx) for xx in range(x,x1))
            x=x1
    for x in range(w):
        y=0
        while y<h:
            if g[y][x]==0: y+=1; continue
            y1=y
            while y1<h and g[y1][x]: y1+=1
            if sum(g[yy][x] for yy in range(y,y1))==10: gone.update((yy,x) for yy in range(y,y1))
            y=y1
    return gone

def resolve(g, trace=None):
    g=settle(g)
    waves=0
    while True:
        t=tens(g)
        if not t: return g,waves
        waves+=1
        g=[r[:] for r in g]
        for (y,x) in t: g[y][x]=0
        g=settle(g)

def move(g,x,y,d):
    """d in R L D U; returns (grid,waves) or None when ignored"""
    h=len(g); w=len(g[0])
    dx,dy={'R':(1,0),'L':(-1,0),'D':(0,-1),'U':(0,1)}[d]
    nx,ny=x+dx,y+dy
    if not(0<=x<w and 0<=y<h) or g[y][x]==0: return None
    if not(0<=nx<w and 0<=ny<h): return None
    s=g[y][x]; t=g[ny][nx]
    if t==s: return None
    if t==0 and dy!=0: return None
    n=[r[:] for r in g]
    n[y][x]=t; n[ny][nx]=s
    return resolve(n)

def canon_token(g,tok):
    d=tok[0]; x=ord(tok[1])-65; y=int(tok[2])-1
    return d,x,y

def legal(g):
    h=len(g); w=len(g[0]); out=set()
    for y in range(h):
        for x in range(w):
            for d in 'RLDU':
                if move(g,x,y,d) is not None:
                    dx,dy={'R':(1,0),'L':(-1,0),'D':(0,-1),'U':(0,1)}[d]
                    if g[y+dy][x+dx] and d in 'LD':
                        out.add((x+dx,y+dy,'R' if d=='L' else 'U'))
                    else: out.add((x,y,d))
    return out

def play(g,path):
    for i in range(0,len(path),3):
        d,x,y=canon_token(g,path[i:i+3])
        r=move(g,x,y,d)
        if r is None: return None
        g=r[0]
    return g

def empty(g): return all(v==0 for r in g for v in r)
def total_tiles(g): return sum(1 for r in g for v in r if v)
