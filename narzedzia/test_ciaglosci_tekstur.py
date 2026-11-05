#!/usr/bin/env python3
"""Etap 3: ciągłość krawędzi wariantów tekstur terenu przy regule silnika (N = 1 + W·(r mod H) + (W−1−(c mod W)))
z różnymi odbiciami obrazu oraz przy regule etapu 2. Wynik: wyniki/test_ciaglosci_tekstur.json (mniejszy koszt = ciąglej)."""
import sys,os,json; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from eeformaty.ssa import ArchiwumSSA
from eeformaty.sst import czytaj_sst, rgba_z_tga
from eeformaty import db
ref=sys.argv[1] if len(sys.argv)>1 else os.path.expanduser('~/mnt/Empire Earth Gold')   # użycie: <skrypt> <instalacja EE>
ee=ArchiwumSSA(ref+'/Empire Earth/Data/data.ssa')
rek=db.dekoduj(ee.czytaj('db/dbterrain.dat'),'dbterrain'); rek=rek['rekordy'] if isinstance(rek,dict) else rek
def obraz(k):
    b=ee.czytaj(k); im=czytaj_sst(b)['obrazy'][0]
    return np.frombuffer(rgba_z_tga(im),np.uint8).reshape(im['h'],im['w'],4)[:,:,:3].astype(float)
wyn=[]
for r in rek:
    W,H=r.get('Tyles on X axis'),r.get('Tiles on Y axis'); p=r.get('Pathname') or ''
    if not p or W*H<4 or W*H>16 or r.get('ID',-1)<0: continue
    base=p.replace('\\','/').lower()
    if not base.startswith('textures/'): base='textures/'+base
    base=base.rsplit('.',1)[0]
    try: im={k:obraz((base+'_%d.sst'%k).replace('/','\\')) for k in range(1,W*H+1)}
    except Exception as e: continue
    def koszt(F, flipH, flipV, ukl):
        def t(rr,cc):
            a=im[F(rr,cc)]
            if flipH: a=a[:,::-1]
            if flipV: a=a[::-1]
            return a
        s=0;n=0
        for rr in range(2*H):
            for cc in range(2*W):
                A=t(rr,cc); B=t(rr,cc+1); C=t(rr+1,cc)
                s+=np.abs(A[:,-1]-B[:,0]).mean()
                if ukl=='silnik': s+=np.abs(A[0]-C[-1]).mean()   # v maleje z r: góra A styka się z dołem C
                else: s+=np.abs(A[-1]-C[0]).mean()
                n+=2
        return s/n
    Fs=lambda rr,cc: 1+W*(rr%H)+(W-1-(cc%W))
    Fo=lambda rr,cc: 1+W*(rr%H)+(cc%W)
    wyn.append((r['ID'],r['Name'],W,H,
       round(koszt(Fs,0,0,'silnik'),1),round(koszt(Fs,1,0,'silnik'),1),round(koszt(Fs,0,1,'silnik'),1),round(koszt(Fs,1,1,'silnik'),1),
       round(koszt(Fo,0,0,'naiw'),1)))
print('ID nazwa W H | silnik: bez, odbH, odbV, obie | etap2')
for w in wyn: print(*w)
json.dump({'kolumny':['ID','nazwa','W','H','silnik_bez_odbicia','silnik_odbicie_poziome','silnik_odbicie_pionowe','silnik_oba','etap2'],'wiersze':wyn},open('wyniki/test_ciaglosci_tekstur.json','w'),ensure_ascii=False,indent=0)
