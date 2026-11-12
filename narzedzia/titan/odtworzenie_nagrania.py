#!/usr/bin/env python3
"""Etap 43 – wspólne odtwarzanie nagrań MCP w Core (dowolny układ czystej mapy) i porównanie co takt.

  opis <nagranie.json> <uklad.json> <wyjście_opis.json>
      Z nagrania Riverlands_MCP (`walka_rejestruj_*`) i układu z generatora (`<scenariusz>.uklad.json`) tworzy opis
      odtworzenia: T0 (czas 1. próbki), jednostki (id, typ, gracz, pozycja, z (zapis scenariusza) i kurs z 1. próbki: kurs = atan2(−m01, m11)),
      rozkazy gracza – każdy nowy cel kolejki z pochodzeniem 1 (+0x1C) jednostki gracza 1; czas rozkazu = ostatnia
      próbka przed pierwszą próbką z tym celem (konwencja odtworz_e35). Obok – seria (wyciąg próbek z HP i kolejką).
  porownaj <seria.json> <core.json> [pomijane_stany]
      Porównanie wszystkich jednostek co próbkę: stan .tai, HP, pozycja (|Δ| > 0,002), kurs (|Δ| > 0,002 rad), cel.
      Próbka nieaktualna rejestratora (gra = poprzednia próbka, następna znów zgodna) liczona osobno – nie jest różnicą.
      Etap 49: także próbka rozdarta (stan z bieżącego taktu, pozycja z poprzedniego; następna zgodna).
Dane (nagrania, scenariusze) są lokalne."""
import base64, bisect, json, math, struct, sys

TAKT_MS = 1500.0 / 44.0


def _seria(d):
    out = []
    for p in d['probki']:
        q = {'t': p['t']}
        for j in d['jednostki']:
            u = p.get(j)
            if not u:
                continue
            hp = None
            r = (u.get('surowe') or {}).get('0x0')
            if r:
                hp = struct.unpack_from('<i', base64.b64decode(r), 0x3C)[0]
            kq = u.get('kolejka') or {}
            q[j] = {'stan': u['stan'], 'x': u['x'], 'y': u['y'], 'z': u.get('z'), 'm01': u['m01'], 'm11': u['m11'], 'v': u['v'], 'w': u['w'],
                    'tryb': u['tryb'], 'cel': u['cel'], 'hp': hp, 'typ': u.get('typ'), 'kontakty': u.get('kontakty'),
                    'push': u.get('push'), 'k248': u.get('k248'),
                    'q': [{'klasa': c.get('klasa'), 'cel': c.get('cel_id'), 'punkt': c.get('punkt'), 'pochodzenie': c.get('pochodzenie_1C'), 'kat': c.get('kat'),
                           'numer': c.get('numer'), 'utworzony': c.get('czas_utworzenia')}
                          for poz in kq.get('poziomy', []) for c in (poz.get('cele') or [])]}
        out.append(q)
    return out


def opis(nagr, uklad, wyj):
    d = json.load(open(nagr)); u = json.load(open(uklad))
    nazwy = {}
    for g, v in u['grupy'].items():
        for i, gid in enumerate(v['id']):
            nazwy[gid] = g if len(v['id']) == 1 else f'{g}{i + 1}'
    seria = _seria(d)
    T0 = seria[0]['t']
    jedn = []
    for gid in sorted(d['jednostki'], key=lambda s: int(s, 16)):
        p = next((q[gid] for q in seria if gid in q), None)
        if not p:
            continue
        jedn.append({'id': gid, 'nazwa': nazwy.get(gid, gid), 'typ': p['typ'], 'gracz': int(gid, 16) >> 24,
                     'x': p['x'], 'y': p['y'], 'z': p['z'], 'kurs': math.atan2(-p['m01'], p['m11']), 'hp': p['hp']})
    rozkazy, znane = [], set()
    for gid in d['jednostki']:
        if int(gid, 16) >> 24 != 1:
            continue
        prev_t = None
        for q in seria:
            u_ = q.get(gid)
            if not u_:
                continue
            for c in u_['q']:
                k = (c['numer'], c['utworzony'])
                if c['pochodzenie'] == 1 and k not in znane:
                    znane.add(k)
                    r = {'t_przed': prev_t if prev_t is not None else T0, 'kto': gid, 'utworzony': c['utworzony'],
                         't_proby': q['t']}
                    if (c['klasa'] or '').endswith('AttackUnit'):
                        r.update(rodzaj='atak', cel=c['cel'])
                    else:
                        r.update(rodzaj='ruch', x=c['punkt'][0], y=c['punkt'][1], kat=c.get('kat'))   # +0x2C kurs końcowy
                    rozkazy.append(r)
            prev_t = q['t']
    rozkazy.sort(key=lambda r: r['t_przed'])
    o = {'nagranie': nagr.split('/')[-1], 'T0': T0, 'takt_ms': TAKT_MS, 'jednostki': jedn, 'rozkazy': rozkazy,
         'koniec_t': seria[-1]['t']}
    json.dump(o, open(wyj, 'w'), indent=1)
    json.dump({'probki': seria}, open(wyj.replace('.json', '') + '.seria.json', 'w'))
    print(json.dumps({k: v for k, v in o.items() if k != 'jednostki'}, ensure_ascii=False)[:800])
    print('jednostki:', [(j['nazwa'], j['id'], j['typ']) for j in jedn])


def porownaj(ser_p, core_p, pomin=()):
    """Etap 46 (I2): na końcu jedno podsumowanie – pierwszy rozbieżny takt, jednostka, pole, wartości gra/Core,
    ostatnie zdarzenie walki Core przed nim, próbki nieaktualne, tryb RNG i graf."""
    ser = json.load(open(ser_p))['probki']; core = json.load(open(core_p))
    ct = [p[1] for p in core['probki']]
    def at(t):
        i = bisect.bisect_right(ct, t + 16.0) - 1
        return core['probki'][i] if i >= 0 and abs(core['probki'][i][1] - t) <= 16.0 else None
    def kurs(u): return math.atan2(-u['m01'], u['m11'])
    wynik = {}
    for gid in core['ids']:
        g = [(q['t'], q[gid]) for q in ser if gid in q]
        n = stale = rozdarte = 0; zg = 0; pierwsze = {}
        for j, (t, u) in enumerate(g):
            c = at(t)
            if not c or gid not in c[2]:
                continue
            cs, cx, cy, ck, ch, cc = c[2][gid][:6]
            n += 1
            ok_s = u['stan'] == cs or (u['stan'] in pomin and cs == 5000)
            if not ok_s and j > 0 and g[j - 1][1]['stan'] == u['stan'] and j + 1 < len(g):
                c2 = at(g[j + 1][0])
                if c2 and gid in c2[2] and c2[2][gid][0] == g[j + 1][1]['stan']:
                    stale += 1; continue
            roz = {'stan': (not ok_s, (u['stan'], cs)),
                   'hp': (u['hp'] is not None and u['hp'] != ch, (u['hp'], ch)),
                   'poz': (abs(u['x'] - cx) > 0.002 or abs(u['y'] - cy) > 0.002, ((round(u['x'], 4), round(u['y'], 4)), (round(cx, 4), round(cy, 4)))),
                   'kurs': (abs((kurs(u) - ck + math.pi) % (2 * math.pi) - math.pi) > 0.002, (round(kurs(u), 4), round(ck, 4)))}
            if any(b for b, _ in roz.values()):
                # próbka spóźniona rejestratora: gra = stan Core z poprzedniego taktu (pozycja i stan), następna zgodna
                cp = at(t - TAKT_MS)
                nast = at(g[j + 1][0]) if j + 1 < len(g) else None
                if (cp and gid in cp[2] and cp[2][gid][0] == u['stan'] and abs(cp[2][gid][1] - u['x']) <= 0.002
                        and abs(cp[2][gid][2] - u['y']) <= 0.002 and nast and gid in nast[2]
                        and nast[2][gid][0] == g[j + 1][1]['stan'] and abs(nast[2][gid][1] - g[j + 1][1]['x']) <= 0.002
                        and abs(nast[2][gid][2] - g[j + 1][1]['y']) <= 0.002):
                    stale += 1; continue
                # etap 49: próbka rozdarta – rejestrator czyta pola jednostki kolejno w czasie działania gry, więc
                # stan/kurs mogą być już z bieżącego taktu, a pozycja jeszcze z poprzedniego [P: 649 dom 3v1, t=47386 –
                # stan 5002 z taktu, pozycja = próbka 47352, następna próbka znów zgodna co do 0,0001]
                if (cp and gid in cp[2] and not roz['hp'][0] and (u['stan'] == cs or u['stan'] == cp[2][gid][0])
                        and abs(cp[2][gid][1] - u['x']) <= 0.002 and abs(cp[2][gid][2] - u['y']) <= 0.002
                        and nast and gid in nast[2] and nast[2][gid][0] == g[j + 1][1]['stan']
                        and abs(nast[2][gid][1] - g[j + 1][1]['x']) <= 0.002 and abs(nast[2][gid][2] - g[j + 1][1]['y']) <= 0.002):
                    stale += 1; rozdarte += 1; continue
            for k, (b, val) in roz.items():
                if b and k not in pierwsze:
                    pierwsze[k] = (t, val)
            if not pierwsze:
                zg += 1
        wynik[gid] = {'probek': n, 'zgodnych_do_1_roznicy': zg, 'nieaktualne': stale, 'rozdarte': rozdarte, 'pierwsze': pierwsze}
        print(f"{gid} ({core['ids'][gid]}): próbek {n}, zgodnych do 1. różnicy {zg}, nieaktualnych {stale} (w tym rozdartych {rozdarte}); " +
              '; '.join(f"{k} t={v[0]} gra/Core {v[1]}" for k, v in sorted(pierwsze.items(), key=lambda kv: kv[1][0])))
    return wynik


def podsumowanie(core, wynik):
    naj = None
    for gid, w in wynik.items():
        for pole, (t, val) in w['pierwsze'].items():
            if naj is None or t < naj[0]:
                naj = (t, gid, pole, val)
    nieakt = sum(w['nieaktualne'] for w in wynik.values())
    tryb = core.get('tryb_rng', 'nieznany (plik sprzed etapu 46)')
    graf = core.get('graf_autonomiczny', core.get('graf', -1) not in (-1, None))
    if naj is None:
        print(f"PODSUMOWANIE: brak rozbieżności; próbek nieaktualnych rejestratora {nieakt}; RNG: {tryb}; graf autonomiczny: {graf}")
        return
    t, gid, pole, val = naj
    ost = None
    for z in core.get('zdarzenia', []):
        tz = z.get('takt') if isinstance(z, dict) else None
        if tz is not None and core['probki'] and core['probki'][0][1] - TAKT_MS + TAKT_MS * (tz + 1) <= t:
            ost = z
    print(f"PODSUMOWANIE: 1. rozbieżność t={t} jednostka {gid} ({core['ids'].get(gid, '?')}) pole {pole}: gra/Core {val}; "
          f"ostatnie zdarzenie walki Core przed nią: {ost}; próbek nieaktualnych {nieakt}; RNG: {tryb}"
          + (" (zgodność wymaga stanu generatora z gry – nie jest odtworzeniem autonomicznym)" if tryb.startswith('z_nagrania') else '')
          + f"; graf autonomiczny: {graf}")


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == 'opis':
        opis(a[1], a[2], a[3])
    elif a and a[0] == 'porownaj':
        w = porownaj(a[1], a[2], tuple(int(x) for x in a[3].split(',')) if len(a) > 3 and a[3] else ())
        podsumowanie(json.load(open(a[2])), w)
    else:
        raise SystemExit(__doc__)
