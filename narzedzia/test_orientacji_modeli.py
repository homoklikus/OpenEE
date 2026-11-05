#!/usr/bin/env python3
"""Etap 3: orientacja modeli – czy oś modelu muru po obrocie macierzą GETransformation rekordu (lub polem angle)
pokrywa się z kierunkiem do sąsiedniego segmentu muru. Wynik: wyniki/test_orientacji_modeli.json."""
import sys,math,struct,collections,json; sys.path.insert(0,'cache/_proba')
import sys,os,struct,math,json; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from eeformaty.ssa import ArchiwumSSA
from eeformaty import scn, gracze, db, cem
ref=sys.argv[1] if len(sys.argv)>1 else os.path.expanduser('~/mnt/Empire Earth Gold')   # użycie: <skrypt> <instalacja EE>
aoc=ArchiwumSSA(ref+'/Empire Earth - The Art of Conquest/Data/data.ssa')
def tab(n):
    r=db.dekoduj(aoc.czytaj('db/%s.dat'%n),n); return r['rekordy'] if isinstance(r,dict) else r
obj={int(r['ID']):r for r in tab('dbobjects')}; gra={int(r['ID']):r for r in tab('dbgraphics')}
cache={}
def os_modelu(tid):
    o=obj.get(tid); g=gra.get(int(o.get('Graphic ID',-1))) if o else None
    if not g or not g.get('Model path'): return None
    p='models\\'+g['Model path'].split('\\')[-1].lower()+'.cem' if '\\' in g['Model path'] else 'models\\'+g['Model path'].lower()+'.cem'
    k=g['Model path'].lower().replace('/','\\')+'.cem'
    if k in cache: return cache[k]
    try: m=cem.czytaj_cem(aoc.czytaj(k))
    except Exception as e: cache[k]=None; return None
    v=np.array(m['klatki'][0]['wierzcholki'] if m['wersja']==(2,0) else [0]*8).reshape(-1,8) if m['wersja']==(2,0) else None
    if v is None: cache[k]=None; return None
    xy=v[:,:2]-v[:,:2].mean(0); w,e=np.linalg.eigh(xy.T@xy); ax=e[:,1]; cache[k]=(ax, w[1]/max(w[0],1e-9)); return cache[k]
def kat(a,b):
    c=abs(np.dot(a,b))/np.linalg.norm(a)/np.linalg.norm(b); return math.degrees(math.acos(min(1,c)))
def scen(path_ssa, part, gra_dir):
    a=ArchiwumSSA(ref+'/%s/Data/Campaigns/%s'%(gra_dir,path_ssa))
    k=[x for x in a.wpisy if x.endswith('.scn') and part in x][0]
    kw=scn.kawalki(a.czytaj(k)); c5=[c for c in kw if c['tag']==5][0]
    return gracze.czytaj(scn.maybe_unpack(c5['surowe']), c5['minor'])

import numpy as np
def info(tid):
    o=obj.get(tid); g=gra.get(int(o.get('Graphic ID',-1))) if o else None
    return (o or {}).get('Name','?'), (g or {}).get('Model path','')
wynik={}
EEA=ArchiwumSSA(ref+'/Empire Earth/Data/data.ssa')
for nazwa,(s,p,gd) in {'EE Troja':('EETheGreeks.ssa','trojan','Empire Earth'),'AoC Rzym':('AOCRoman.ssa','soldiers','Empire Earth - The Art of Conquest')}.items():
    G=scen(s,p,gd)
    sc=[]; kat_mat_vs_angle=collections.defaultdict(list)
    for gr in G:
        for u in gr['jednostki']:
            if not u.get('valid') or 'transform' not in u: continue
            t=struct.unpack('<16f',u['transform']); m=math.atan2(t[4],t[0]); ut=int(obj.get(u['type'],{}).get('Unit type',-1))
            kat_mat_vs_angle[ut].append(abs(math.remainder(m-u['angle'],2*math.pi)))
            nm,mp=info(u['type'])
            if 'Wall' in nm and 'Gate' not in nm: sc.append((np.array([t[3],t[7]]),np.array([[t[0],t[1]],[t[4],t[5]]]),u['type'],u['angle']))
    ax_n={}
    for tid in set(x[2] for x in sc):
        nm,mp=info(tid); k=mp.lower().replace('/','\\')+'.cem'
        try:
            mm=cem.czytaj_cem(aoc.czytaj(k) if k in aoc else EEA.czytaj(k)); v=np.array(mm['klatki'][0]['wierzcholki']).reshape(-1,8)[:,:2] if mm['wersja']==(2,0) else None
            if v is None:   # 1.3: punkty klatki 0
                v=None
            xy=v-v.mean(0); w,e=np.linalg.eigh(xy.T@xy); ax_n[tid]=(e[:,1],float(w[1]/max(w[0],1e-9)),k)
        except Exception as ex: ax_n[tid]=(None,0,k+' '+repr(ex)[:40])
    h=collections.defaultdict(list)
    for i,(p0,R,tid,an) in enumerate(sc):
        ax,ratio,k=ax_n[tid]
        if ax is None or ratio<1.3: continue
        odl=[(np.linalg.norm(q-p0),q) for j,(q,_,_,_) in enumerate(sc) if j!=i and 0.2<np.linalg.norm(q-p0)<3]
        if not odl: continue
        d=min(odl,key=lambda x:x[0])[1]-p0
        ukos=abs(d[0])>0.2 and abs(d[1])>0.2
        for nmh,vv in (('R·a',R@ax),('Rt·a',R.T@ax),('R·lustroY(a)',R@(ax*[1,-1])),('rot(angle)·a',np.array([[math.cos(an),-math.sin(an)],[math.sin(an),math.cos(an)]])@ax),('bez_obrotu',ax)):
            h[nmh+(' ukosne' if ukos else ' osiowe')].append(kat(vv,d))
    wynik[nazwa]={'mat_vs_angle_mediana_st(Unit type)':{k:round(math.degrees(float(np.median(v))),2) for k,v in kat_mat_vs_angle.items()},
                 'osie_modeli_murow':{str(k):(round(v[1],1),v[2]) for k,v in ax_n.items()},
                 'zgodnosc_osi_z_kierunkiem_muru':{k:{'n':len(v),'mediana_st':round(float(np.median(v)),1),'<15st':sum(1 for x in v if x<15)} for k,v in sorted(h.items())}}
print(json.dumps(wynik,indent=1,ensure_ascii=False))
json.dump(wynik,open('wyniki/test_orientacji_modeli.json','w'),indent=1,ensure_ascii=False)
