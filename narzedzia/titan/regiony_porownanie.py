"""Etap 42 – badawczy prototyp siatki regionów Titan (0x4240D3 → 0x42A66D, dostępność 0x41B9C9) i porównanie z grą.

Odtworzenie z kodu EE (analiza statyczna, etap 42):
  * start: pola od (N−1, N−1), x malejąco (zewnętrznie), y malejąco; pole z obszarem (0x41C537) i bez etykiety;
  * etykiety kolejne od 1 w kolejności startów [P – 0 inwersji w odczycie];
  * flood: 4 boki (0x42B96A, pamięć podręczna bez historii), przekątne – gdy flaga maszyny +0x1C = 1 tylko przy
    dostępnym co najmniej jednym boku, gdy 0 – bez warunku;
  * pierwsze pole (0x41BF51) ustala klasę regionu: obszar (+0xDA) i rodzaj obszaru (+0xD8) oraz tryb +0x94:
      obszar 1: pole 0xA → 7/8/9 (wysokość = 0 / < 0 / > 0), inaczej 1; obiekt klasy 3 na polu ≠ 1 → 4 (flaga 0);
                pierwsza jednostka blokująca → 0xC (flaga 0; 0xE gdy klasa 0x19, 0xD gdy typ+0x612);
      obszar 2: 2 / 0xA / 0xB (wysokość 0 / < 0 / > 0); obszar 4: 6 (flaga 0); obszar 3: 3 (flaga 0);
  * kolejne pola: ten sam obszar (rodzaj i id) i warunek trybu (tabela 0x41C235);
  * warunek brzegu rombu (x + y = E0 / E1, |y − x| = E2) ⇔ rodzaj obszaru 4.
Wysokość: siatka 0x917CB8 albo bajt +0x14 pola (0x425632). vt+0x58 jednostki złożonej = bajt +0x345 (0x5F3487) –
nieodczytany, przyjęte 0 [H].

Użycie: python3 regiony_porownanie.py <regiony_wejscie.json> <podsektory_odczyt.json>
"""
import json, sys, collections
from collections import deque

w = json.load(open(sys.argv[1])); ref = json.load(open(sys.argv[2]))['podsektory']
N = w['N']; KP = w['rodzaj_pola']; H14 = w['bajt14']; OB = w['obszar']; ORK = w['obszary_rodzaj_id']
WYS = w['siatka_wys']; JED = {int(k): v for k, v in w['jednostki'].items()}; TYP = w['typy']
E0, E1, E2 = 139, 419, 140   # [P] z położenia pól obszarów rodzaju 4 (e35_a); w grze map+0x1816EC/F0/F4

def h(i): return WYS[i] if WYS else H14[i]
def cls(i):
    if KP[i] == 1: return 0
    return 1 if any(TYP.get(u[4], [0])[0] == 3 for u in JED.get(i, [])) else 0
def jedn(i):
    for u in JED.get(i, []):
        t = TYP.get(u[4], [0, 0, 0, 0]); yield u, t   # t = [+0x568, +0x600, +0x4B4, +0x612]
def blokujaca(u, t): return (t[1] or t[2] == 0x19) and (u[1] > 0 or t[2] == 1)
def brzeg(x, y): return x + y == E0 or y - x == E2 or x + y == E1 or x - y == E2

class Region:
    def __init__(s, i):
        a = OB[i]; s.obszar = a; s.rk = ORK[a][0]; s.flaga = 1; s.uid = None; s.gr = None
        k = KP[i]; hh = h(i)
        if s.rk == 1:
            s.tryb = (8 if hh < 0 else 9 if hh > 0 else 7) if k == 0xA else 1
            if cls(i): s.tryb = 4; s.flaga = 0
            else:
                for u, t in jedn(i):
                    if blokujaca(u, t):
                        s.uid = u[0]; s.gr = u[2]; s.tryb = 0xC; s.flaga = 0
                        if t[2] == 0x19: s.tryb = 0xE
                        elif t[3]: s.tryb = 0xD
                        break
        elif s.rk == 2: s.tryb = 0xA if hh < 0 else 0xB if hh > 0 else 2
        elif s.rk == 4: s.tryb = 6; s.flaga = 0
        elif s.rk == 3: s.tryb = 3; s.flaga = 0
        else: s.tryb = 0
    def dost(s, x, y):
        if not (0 <= x < N and 0 <= y < N): return False
        i = x * N + y
        if KP[i] == -1 or OB[i] != s.obszar: return False
        k, hh, T = KP[i], h(i), s.tryb
        bez_blok = lambda: not any(blokujaca(u, t) for u, t in jedn(i))
        if T == 1: ok = k != 0xA and not cls(i) and bez_blok()
        elif T == 2: ok = k == 1 and hh == 0
        elif T == 3: ok = k == 9
        elif T == 4: ok = bool(cls(i))
        elif T == 6: ok = True
        elif T in (7, 8, 9): ok = k == 0xA and ((hh == 0) if T == 7 else (hh < 0) if T == 8 else (hh > 0)) and not cls(i) and bez_blok()
        elif T == 0xA: ok = k == 1 and hh < 0
        elif T == 0xB: ok = k == 1 and hh > 0
        elif T in (0xC, 0xE):
            if cls(i): ok = False
            else:
                uid = None
                for u, t in jedn(i):
                    if not (u[1] > 0 or t[2] == 1): continue
                    if T == 0xE and t[2] == 0x19 and u[2] == s.gr: uid = u[0]; break
                    if t[1] or t[2] == 0x19: uid = u[0]; break
                ok = uid == s.uid
        elif T == 0xD:
            ok = False
            if not cls(i):
                for u, t in jedn(i):
                    if t[3] and u[1] > 0 and t[2] != 0x19 and u[2] == s.gr: ok = True; break
                    if blokujaca(u, t): break
        else: ok = False
        return ok and (brzeg(x, y) == (s.rk == 4))

def zbuduj():
    lab = [0] * (N * N); nr = 0; regiony = {}
    for x in range(N - 1, -1, -1):
        for y in range(N - 1, -1, -1):
            i = x * N + y
            if KP[i] == -1 or not OB[i] or lab[i]: continue
            nr += 1; R = Region(i); regiony[nr] = R
            lab[i] = nr; q = deque([(x, y)])
            while q:
                a, b = q.popleft()
                d = {(dx, dy): R.dost(a + dx, b + dy) for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1))}
                for (dx, dy), ok in d.items():
                    j = (a + dx) * N + b + dy
                    if ok and not lab[j]: lab[j] = nr; q.append((a + dx, b + dy))
                for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    if R.flaga and not (d[(dx, 0)] or d[(0, dy)]): continue
                    if R.dost(a + dx, b + dy):
                        j = (a + dx) * N + b + dy
                        if not lab[j]: lab[j] = nr; q.append((a + dx, b + dy))
    return lab, regiony

lab, regiony = zbuduj()
g = [0] * (N * N); rk_ref = {}
for p in ref:
    rk_ref[p['w4c'][1]] = p['rodzaj']
    for x, y0, y1 in p['pola']:
        for y in range(y0, y1 + 1): g[x * N + y] = p['w4c'][1]
pola = [i for i in range(N * N) if g[i]]
zg = sum(1 for i in pola if lab[i] == g[i])
print(f'regiony: OpenEE {len(regiony)} (etykiety {min(regiony)}..{max(regiony)}), gra {len(set(g)) - 1} (1..{max(g)})')
print(f'pola z podsektorem: {len(pola)}, zgodne etykiety {zg}, różne {len(pola) - zg}')
rozn = [i for i in pola if lab[i] != g[i]]
roz_rodz = collections.Counter(rk_ref.get(g[i]) for i in rozn)
print('różnice wg rodzaju regionu gry:', dict(roz_rodz))
tz = sum(1 for r, R in regiony.items() if rk_ref.get(r) is not None and rk_ref[r] == R.tryb)
print(f'rodzaj regionu zgodny: {tz} z {len(rk_ref)}')
for i in sorted(rozn, key=lambda i: (-(i // N), -(i % N)))[:8]:
    x, y = divmod(i, N)
    print(' pierwsza różnica', (x, y), 'OpenEE', lab[i], 'gra', g[i], 'rodzaj gra', rk_ref.get(g[i]), 'pole', KP[i], 'h', h(i), 'obszar', OB[i], ORK[OB[i]], 'jedn', JED.get(i))
json.dump([[lab[x * N + y] for y in range(N)] for x in range(N)], open('/tmp/e42_regiony_openee.json', 'w'))
