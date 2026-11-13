import json,sys,math
d=json.load(open(sys.argv[1])); P=d['probki']
for a,b in [x.split(':') for x in sys.argv[2:]]:
    A='0x1000'+a; B='0x1000'+b
    mind=(9,None); first_k=None; first_push=None; first_move=None; b0=(P[0][B]['x'],P[0][B]['y']); mind_nk=(9,None)
    for p in P:
        ua,ub=p[A],p[B]; dist=math.hypot(ua['x']-ub['x'],ua['y']-ub['y'])
        if dist<mind[0]: mind=(dist,p['t'])
        k=B in (ua.get('kontakty_lista') or [])
        if not k and dist<mind_nk[0]: mind_nk=(dist,p['t'])
        if k and first_k is None: first_k=(p['t'],round(dist,4),round(ua['x'],3),round(ua['y'],3))
        pu=ua['push']+ub['push']
        if any(abs(v)>0 for v in pu) and first_push is None: first_push=(p['t'],round(dist,4),[round(v,5) for v in pu])
        if first_move is None and (abs(ub['x']-b0[0])>1e-6 or abs(ub['y']-b0[1])>1e-6): first_move=(p['t'],round(dist,4),round(ub['x'],4),round(ub['y'],4))
    e=P[-1]
    print(f"{a}→{b}: pierwszy kontakt {first_k}; min. odległość {round(mind[0],4)} (t={mind[1]}); min. odległość BEZ kontaktu {round(mind_nk[0],4)} (t={mind_nk[1]}); pierwszy push {first_push}; pierwsze przesunięcie {b} {first_move}; koniec A ({e[A]['x']:.3f},{e[A]['y']:.3f}) B ({e[B]['x']:.3f},{e[B]['y']:.3f})")
