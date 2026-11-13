#!/usr/bin/env python3
"""Eksperyment Fable: symulacja list kontaktów z nagrania wg dwóch reguł okna (EE: nowa pozycja, AoC: stara pozycja)
i porównanie z listami zmierzonymi w grze. Użycie: kontakty.py NAGRANIE.json [--szczegoly]"""
import json, sys, math
R_TYPU = {102: 1.0, 422: 0.5, 37: 1.0}   # „Size of collider” dbobjects; R = s (s ≥ 1) albo max(0,5; s/2)
def R(typ):
    s = R_TYPU[typ]; return s if s >= 1.0 else max(0.5, s * 0.5)
def okno(x, y, r):
    return (math.floor(x - r), math.floor(x + r), math.floor(y - r), math.floor(y + r))
d = json.load(open(sys.argv[1])); P = d['probki']; ids = d['jednostki']
print('wariant', d.get('wariant'), 'próbek', len(P), 'luki', d.get('luki_taktow'))
stan = {reg: {i: set(P[0][i].get('kontakty_lista') or []) for i in ids} for reg in ('nowa', 'stara')}
zle = {'nowa': None, 'stara': None}; nz = {'nowa': 0, 'stara': 0}; zmiany = []; rozne = 0
for a, b in zip(P, P[1:]):
    for i in ids:
        ua, ub = a[i], b[i]
        if (ua['X'], ua['Y']) == (ub['X'], ub['Y']): continue
        r = R(ub['typ'])
        wn, ws = okno(ub['x'], ub['y'], r), okno(ua['x'], ua['y'], r)
        zb = {}
        for reg, w in (('nowa', wn), ('stara', ws)):
            S = stan[reg]
            for o in S[i]: S[o].discard(i)
            S[i] = set()
            for o in ids:
                if o == i: continue
                uo = b[o]
                if w[0] <= uo['X'] <= w[1] and w[2] <= uo['Y'] <= w[3]:
                    S[i].add(o); S[o].add(i)
            zb[reg] = sorted(S[i])
        obs = sorted(ub.get('kontakty_lista') or [])
        if zb['nowa'] != zb['stara']: rozne += 1
        zmiany.append((b['t'], i, ub['typ'], (ua['X'], ua['Y']), (ub['X'], ub['Y']), round(ua['x'], 4), round(ua['y'], 4), round(ub['x'], 4), round(ub['y'], 4), wn, ws, zb['nowa'], zb['stara'], obs))
    for reg in ('nowa', 'stara'):
        for i in ids:
            if sorted(stan[reg][i]) != sorted(b[i].get('kontakty_lista') or []):
                nz[reg] += 1
                if zle[reg] is None: zle[reg] = (b['t'], i, sorted(stan[reg][i]), sorted(b[i].get('kontakty_lista') or []))
print('zmian pola:', len(zmiany), '; z różnym wynikiem reguł:', rozne)
for reg, n in (('nowa', 'EE: okno od NOWEJ pozycji'), ('stara', 'AoC: okno od STAREJ pozycji')):
    print(f'reguła {n}: niezgodnych (próbka, jednostka) {nz[reg]}; pierwsza: {zle[reg]}')
if '--szczegoly' in sys.argv:
    for z in zmiany:
        if z[11] != z[12] or '--wszystkie' in sys.argv:
            print(z[0], z[1][-3:], 'typ', z[2], z[3], '→', z[4], 'stara', z[5:7], 'nowa', z[7:9], 'okno_n', z[9], 'okno_s', z[10], '| EE', [x[-3:] for x in z[11]], 'AoC', [x[-3:] for x in z[12]], 'GRA', [x[-3:] for x in z[13]])
