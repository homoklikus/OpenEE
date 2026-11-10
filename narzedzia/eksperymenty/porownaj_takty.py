"""Etap 37 – porównanie stanu jednostki co takt: gra (próbki nagrania Riverlands_MCP) ↔ Core (przejścia zapisane przez
godot/testy/eksperymenty/odtworz_e35.gd). Dane wejściowe są lokalne (nie trafiają do repozytorium).
Użycie: porownaj_takty.py NAGRANIE.json CORE.json ID_JEDNOSTKI [CZAS_OD]
Takty bez próbki w nagraniu (luki) pomijane. Wynik: pierwszy takt z innym stanem albo pozycją > 0,002 (pozycja Core z przejścia –
sprawdzana tylko w taktach przejść Core)."""
import json,sys,bisect
rek, core, ident = sys.argv[1], sys.argv[2], sys.argv[3]
od = float(sys.argv[4]) if len(sys.argv) > 4 else 0
d=json.load(open(rek)); w=json.load(open(core))
TAKT=1500.0/44.0
g={}
for p in d['probki']:
    u=p.get(ident)
    if u: g[p['t']]=(u['stan'],u['x'],u['y'])
gt=sorted(g)
c=[(x[0],x[1],x[3],x[4]) for x in w['przejscia']]
ct=[x[0] for x in c]
def core_at(t):
    i=bisect.bisect_right(ct,t+16.0)-1
    return c[i] if i>=0 else None
n=0; bad=None; nieaktualne=[]
for j,t in enumerate(gt):
    if t < od or t < ct[0]: continue
    cs=core_at(t)
    if cs is None: continue
    n+=1
    s,x,y=g[t]
    if s!=cs[1]:
        # próbka nieaktualna: stan jak w poprzedniej próbce, następna próbka znów zgodna z Core [W: rejestrator czyta
        # pamięć w trakcie taktu – pominiete_niespojne w nagraniu]
        if j>0 and j+1<len(gt) and g[gt[j-1]][0]==s and core_at(gt[j+1]) and g[gt[j+1]][0]==core_at(gt[j+1])[1]:
            nieaktualne.append(t); continue
        bad=(t,'stan',s,cs[1]); break
    if abs(cs[0]-t)<=16.0 and (abs(x-cs[2])>0.002 or abs(y-cs[3])>0.002): bad=(t,'pozycja',(round(x,4),round(y,4)),(round(cs[2],4),round(cs[3],4))); break
koniec = ct[-1]
print(f"porównanych taktów: {n}; ostatni takt Core {koniec:.0f}; próbki nieaktualne: {nieaktualne}; pierwsza różnica: {bad}")
if bad:
    t=bad[0]; i=gt.index(t)
    for tt in gt[max(0,i-3):i+4]:
        print('  gra',tt,g[tt][0],'%.4f %.4f'%g[tt][1:],'| core',core_at(tt)[1])
