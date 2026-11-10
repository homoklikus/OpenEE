"""Etap 41 – badawczy prototyp budowy podsektorów Titan i porównanie z odczytem z gry (narzędzie, nie Core).

Odtwarza z kodu EE: skan pól od (W−1, H−1) w dół (0x424565), flood w prostokącie sektora 19 × 19 po polach o tej
samej wartości siatki regionów (0x41EAE7, goal+0xAC), kolejne id (0x425E8D), punkt reprezentatywny
U2DSparseArrayPointContainer::ComputeCenterPoint(true) (0x42C2D5) i listy sąsiadów (0x4246E8). Reguła łączenia po
przekątnej we floodzie – NIEUSTALONA (warianty: oba / jeden / brak / zero / zero_bez_sektora).

Użycie (dane lokalne, z odczytu Riverlands_MCP `podsektory` i siatki regionów):
  python3 podsektory_porownanie.py <wariant> <siatka_regionow_xH.json> [odczyt_podsektorow.json]
Wynik: liczba podsektorów, zgodność pól / id / punktów / sąsiadów (zbiór i kolejność), pierwsza różnica."""
import json,sys,collections
A=json.load(open(sys.argv[2] if len(sys.argv)>2 else 'obszar_siatka_xH.json')); W=H=280; K=19
REF=json.load(open(sys.argv[3] if len(sys.argv)>3 else 'podsektory_e35_a_pelne.json'))
naroznik=sys.argv[1] if len(sys.argv)>1 else 'oba'
def zbuduj():
    grid=[[0]*H for _ in range(W)]; subs={}; nid=1
    for x in range(W-1,-1,-1):
        for y in range(H-1,-1,-1):
            if grid[x][y] or A[x][y]==0: continue
            si,sj=x//K,y//K; x0,x1=si*K,min(si*K+K-1,W-1); y0,y1=sj*K,min(sj*K+K-1,H-1)
            ar=A[x][y]
            def ok(a,b): return x0<=a<=x1 and y0<=b<=y1 and A[a][b]==ar and grid[a][b]==0
            pts=[(x,y)]; grid[x][y]=nid; st=[(x,y)]
            while st:
                a,b=st.pop()
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
                    q=(a+dx,b+dy)
                    if not ok(*q): continue
                    if dx and dy and naroznik=='oba' and not (ok2(a+dx,b,x0,x1,y0,y1,ar) and ok2(a,b+dy,x0,x1,y0,y1,ar)): continue
                    if dx and dy and naroznik in ('jeden','zero','zero_bez_sektora') and not (ok2(a+dx,b,x0,x1,y0,y1,ar) or ok2(a,b+dy,x0,x1,y0,y1,ar)): continue
                    grid[q[0]][q[1]]=nid; pts.append(q); st.append(q)
            subs[nid]={'id':nid,'sektor':(si,sj),'obszar':ar,'pola':pts}; nid+=1
    return grid,subs
def ok2(a,b,x0,x1,y0,y1,ar):
    if naroznik in ('zero','zero_bez_sektora') and 0<=a<W and 0<=b<H and A[a][b]==0: return True
    if naroznik=='zero_bez_sektora': return 0<=a<W and 0<=b<H and A[a][b]==ar
    return x0<=a<=x1 and y0<=b<=y1 and A[a][b]==ar
grid,subs=zbuduj()
def srodek(pts):
    cols=collections.defaultdict(list)
    for x,y in pts: cols[x].append(y)
    L=[]
    for x in sorted(cols,reverse=True):   # kolumny od ostatniej (0x1005FC87)
        for y in sorted(cols[x]): L.append((x,y))
    import numpy as np
    n=np.float32(len(L)); cx=np.float32(0); cy=np.float32(0)
    for x,y in reversed(L):
        cx=np.float32(cx+np.float32(x)/n); cy=np.float32(cy+np.float32(y)/n)
    c=(int(cx),int(cy))
    if c in set(L): return c
    best=L[-1]; bd=(c[0]-best[0])**2+(c[1]-best[1])**2
    for i in range(len(L)-2,-1,-1):
        d=(c[0]-L[i][0])**2+(c[1]-L[i][1])**2
        if d<=bd: best=L[i]; bd=d
    return best
nb=collections.defaultdict(list)
def link(a,b):
    if b not in nb[a]: nb[a].append(b)
    if a not in nb[b]: nb[b].append(a)
for x in range(W):
    for y in range(H):
        c=grid[x][y]
        if x>0 and grid[x-1][y] not in (c,0): link(c,grid[x-1][y])
        if y>0 and grid[x][y-1] not in (c,0): link(c,grid[x][y-1])
        if x>0 and y>0 and grid[x-1][y-1] not in (c,0): link(c,grid[x-1][y-1])
        if x+1<W and y>0 and grid[x+1][y-1] not in (c,0): link(c,grid[x+1][y-1])
R={s['id']:s for s in REF['podsektory']}
def zb(s): return {(p[0],y) for p in s['pola'] for y in range(p[1],p[2]+1)}
print('liczba: core',len(subs),'gra',REF['podsektorow'])
same_id=same_cells=same_rep=same_nb_set=same_nb_ord=0
for i,s in subs.items():
    r=R.get(i)
    if not r: continue
    same_id+=1
    if set(s['pola'])==zb(r): same_cells+=1
    if list(srodek(s['pola']))==r['punkt_i32']: same_rep+=1
    if set(nb[i])==set(r['sasiedzi']): same_nb_set+=1
    if nb[i]==r['sasiedzi']: same_nb_ord+=1
print(f'naroznik={naroznik}: id wspólne {same_id}, te same pola {same_cells}, ten sam punkt {same_rep}, sąsiedzi (zbiór) {same_nb_set}, (kolejność) {same_nb_ord}')
# diagnostyka pierwszej różnicy
for i in sorted(subs):
    r=R.get(i)
    if r is None or set(subs[i]['pola'])!=zb(r):
        a=set(subs[i]['pola']); b=zb(r) if r else set()
        print('pierwsza różnica id',i,'core n',len(a),'gra n',len(b),'core-gra',sorted(a-b)[:12],'gra-core',sorted(b-a)[:12], 'sektor',subs[i]['sektor'], r and r['sektor'])
        break
