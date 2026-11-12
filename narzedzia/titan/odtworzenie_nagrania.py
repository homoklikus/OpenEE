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
  opis_budowy <obserwacja.json> <budowa.json> <uklad.json> <wyjście_opis.json>
      Etap 50: rozkaz budowy obywatela (cel EEUGBuildRepair, vtable 0x8319F0 – rejestrator nie dekoduje celu).
      Obserwacja od startu (sam obywatel) + rejestracja budowy uruchomiona po wykryciu fundamentu (obywatel + fundament).
      Rozkaz = pierwsza próbka obserwacji z celem 0x8319F0; fundament (typ, kotwica X/Y, HP 1) tworzony w tym takcie.
      Seria: próbki obserwacji uzupełnione o próbki rejestracji budowy w tych samych chwilach.
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


def opis_budowy(obs, bud, uklad, wyj):
    a = json.load(open(obs)); b = json.load(open(bud)); u = json.load(open(uklad))
    nazwy = {gid: g for g, v in u['grupy'].items() for gid in v['id']}
    sa, sb = _seria(a), _seria(b)
    fund = [j for j in b['jednostki'] if j not in a['jednostki']]
    tb = {q['t']: q for q in sb}
    for q in sa:   # próbki fundamentu w tych samych chwilach
        for j in fund:
            if q['t'] in tb and j in tb[q['t']]:
                q[j] = tb[q['t']][j]
    T0 = sa[0]['t']
    jedn, rozkazy = [], []
    for gid in a['jednostki']:
        p = sa[0][gid]
        jedn.append({'id': gid, 'nazwa': nazwy.get(gid, gid), 'typ': p['typ'], 'gracz': int(gid, 16) >> 24, 'x': p['x'],
                     'y': p['y'], 'z': p['z'], 'kurs': math.atan2(-p['m01'], p['m11']), 'hp': p['hp']})
        prev = T0
        for q in sa:
            if gid in q and any((c['klasa'] or '').endswith('0x8319f0') for c in q[gid]['q']):
                f = fund[0]
                pf = next(r for r in b['probki'] if f in r)[f]
                rozkazy.append({'t_przed': prev, 'kto': gid, 't_proby': q['t'], 'rodzaj': 'budowa', 'cel': f,
                                'fundament': {'id': f, 'typ': pf['typ'], 'X': pf['X'], 'Y': pf['Y'], 'x': pf['x'], 'y': pf['y'],
                                              'z': pf['z'], 'gracz': int(f, 16) >> 24}})
                break
            prev = q['t']
    o = {'nagranie': obs.split('/')[-1] + '+' + bud.split('/')[-1], 'T0': T0, 'takt_ms': TAKT_MS, 'jednostki': jedn,
         'rozkazy': rozkazy, 'koniec_t': sa[-1]['t'], 'pozniejsze': fund}
    json.dump(o, open(wyj, 'w'), indent=1)
    json.dump({'probki': sa}, open(wyj.replace('.json', '') + '.seria.json', 'w'))
    print(json.dumps({k: v for k, v in o.items() if k != 'jednostki'}, ensure_ascii=False)[:800])


def opis_zbierania(nagr, uklad, wyj, od_t=None):
    """Etap 51: rozkaz zbierania (cel EEUGGather, vtable 0x831B80). Źródła (obiekty Świata – rejestrator nie zna ich pól
    x/y) dostają pozycję z kotwicy X/Y (+0x1C/+0x20) i ilość z +0x40; punkt pracy = ostatni punkt pierwszej trasy po
    rozkazie (miejsce kliknięcia rzucone na obwód – [H]); zasoby gracza z próbki (EEPlayer +0xAF8)."""
    d = json.load(open(nagr)); u = json.load(open(uklad))
    if od_t is not None:   # odtworzenie od chwili od_t (stan jednostek z tej próbki; wcześniejsze rozkazy pominięte)
        d['probki'] = [p for p in d['probki'] if p['t'] >= float(od_t)]
    nazwy = {gid: g for g, v in u['grupy'].items() for gid in v['id']}
    seria = _seria(d)
    T0 = seria[0]['t']
    p0 = d['probki'][0]
    jedn, zrodla, rozkazy = [], [], []
    for gid in d['jednostki']:
        surowe = base64.b64decode(p0[gid]['surowe']['0x0'])
        if int(gid, 16) >> 24 == 0:
            X, Y = struct.unpack_from('<ii', surowe, 0x1C)
            zrodla.append({'id': gid, 'typ': p0[gid]['typ'], 'X': X, 'Y': Y, 'hp': struct.unpack_from('<i', surowe, 0x3C)[0],
                           'ilosc': struct.unpack_from('<i', surowe, 0x40)[0]})
            continue
        q = seria[0][gid]
        jedn.append({'id': gid, 'nazwa': nazwy.get(gid, gid), 'typ': q['typ'], 'gracz': int(gid, 16) >> 24, 'x': q['x'],
                     'y': q['y'], 'z': q['z'], 'kurs': math.atan2(-q['m01'], q['m11']), 'hp': q['hp']})
    for gid in d['jednostki']:
        if int(gid, 16) >> 24 != 1:
            continue
        prev = T0
        for i, p in enumerate(d['probki']):
            c = p.get(gid)
            if c and any((cc.get('klasa') or '').endswith('0x831b80') for poz in (c.get('kolejka') or {}).get('poziomy', [])
                         for cc in (poz.get('cele') or [])):
                pkt = next((q[gid]['trasa'][-1] for q in d['probki'][i:i + 20] if q.get(gid, {}).get('trasa')), None)
                rozkazy.append({'t_przed': prev, 'kto': gid, 't_proby': p['t'], 'rodzaj': 'zbieranie', 'x': pkt[0], 'y': pkt[1],
                                'zrodla': [z['id'] for z in zrodla]})
                break
            prev = p['t']
    znane = set()   # rozkazy ruchu (EEUGLocation z pochodzeniem 1) – jak w opis()
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
                if c['pochodzenie'] == 1 and k not in znane and (c['klasa'] or '') == 'EEUGLocation':
                    znane.add(k)
                    rozkazy.append({'t_przed': prev_t if prev_t is not None else T0, 'kto': gid, 'utworzony': c['utworzony'],
                                    't_proby': q['t'], 'rodzaj': 'ruch', 'x': c['punkt'][0], 'y': c['punkt'][1], 'kat': c.get('kat')})
            prev_t = q['t']
    rozkazy.sort(key=lambda r: r['t_przed'])
    zas = None
    if 'gracze' in p0:
        g = base64.b64decode(p0['gracze']['1'])
        zas = list(struct.unpack_from('<5i', g, 0))
    o = {'nagranie': nagr.split('/')[-1], 'T0': T0, 'takt_ms': TAKT_MS, 'jednostki': jedn, 'zrodla': zrodla, 'rozkazy': rozkazy,
         'koniec_t': seria[-1]['t'], 'zasoby_startowe': {'1': zas} if zas else {}}
    json.dump(o, open(wyj, 'w'), indent=1)
    for q in seria:   # źródła poza porównaniem pozycji (pola x/y obiektów prostych nieznane)
        for z in zrodla:
            q.pop(z['id'], None)
    json.dump({'probki': seria}, open(wyj.replace('.json', '') + '.seria.json', 'w'))
    print(json.dumps({k: v for k, v in o.items() if k != 'jednostki'}, ensure_ascii=False)[:900])


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
            # etap 50: próbka „nieaktualna” tylko przy zgodnym kursie – wcześniej kurs nieruchomej jednostki nie był
            # sprawdzany i obrót bez ruchu (658: kurs na budynek w 4002) chował się w próbkach nieaktualnych
            dk = lambda k1, k2: abs((k1 - k2 + math.pi) % (2 * math.pi) - math.pi) <= 0.002
            if (not ok_s and j > 0 and g[j - 1][1]['stan'] == u['stan'] and j + 1 < len(g)
                    and dk(kurs(u), ck) and abs(u['x'] - cx) <= 0.002 and abs(u['y'] - cy) <= 0.002):
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
                        and abs(cp[2][gid][2] - u['y']) <= 0.002 and dk(kurs(u), cp[2][gid][3]) and nast and gid in nast[2]
                        and nast[2][gid][0] == g[j + 1][1]['stan'] and abs(nast[2][gid][1] - g[j + 1][1]['x']) <= 0.002
                        and abs(nast[2][gid][2] - g[j + 1][1]['y']) <= 0.002):
                    stale += 1; continue
                # etap 49: próbka rozdarta – rejestrator czyta pola jednostki kolejno w czasie działania gry, więc
                # stan/kurs mogą być już z bieżącego taktu, a pozycja jeszcze z poprzedniego [P: 649 dom 3v1, t=47386 –
                # stan 5002 z taktu, pozycja = próbka 47352, następna próbka znów zgodna co do 0,0001]
                if (cp and gid in cp[2] and not roz['hp'][0] and (u['stan'] == cs or u['stan'] == cp[2][gid][0])
                        and (dk(kurs(u), ck) or dk(kurs(u), cp[2][gid][3]))
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
    elif a and a[0] == 'opis_zbierania':
        opis_zbierania(a[1], a[2], a[3], a[4] if len(a) > 4 else None)
    elif a and a[0] == 'opis_budowy':
        opis_budowy(a[1], a[2], a[3], a[4])
    elif a and a[0] == 'porownaj':
        w = porownaj(a[1], a[2], tuple(int(x) for x in a[3].split(',')) if len(a) > 3 and a[3] else ())
        podsumowanie(json.load(open(a[2])), w)
    else:
        raise SystemExit(__doc__)
