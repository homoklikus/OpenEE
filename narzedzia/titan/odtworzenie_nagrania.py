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
# etap 53: klasy celów bez nazwy w rejestratorze – vtable EE i AoC (ustalone osobno w każdej grze [P: 658/673 EE, 707/708 AoC])
VT_BUDOWA = ('0x8319f0', '0x84740c')      # EEUGBuildRepair
VT_ZBIERANIE = ('0x831b80', '0x8475a8')   # EEUGGather


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
                     'x': p['x'], 'y': p['y'], 'z': p['z'], 'kurs': math.atan2(-p['m01'], p['m11']), 'hp': p['hp'],
                     'm01': p['m01'], 'm11': p['m11']})   # etap 53: elementy macierzy (odtworz_scenariusz.gd --macierz=1)
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


def opis_budowy(obs, bud, uklad, wyj, do_t=None):
    a = json.load(open(obs)); b = json.load(open(bud)); u = json.load(open(uklad))
    if do_t is not None:   # etap 53: koniec porównania (np. przed zniszczeniem budynku klawiszem Delete)
        a['probki'] = [p for p in a['probki'] if p['t'] <= float(do_t)]
    # etap 53: rejestrator z `nowe_gracza` dopisuje fundament także do obserwacji – jednostki obserwacji = obecne w 1. próbce
    a['jednostki'] = [j for j in a['jednostki'] if j in a['probki'][0]]
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
            if gid in q and any((c['klasa'] or '').endswith(VT_BUDOWA) for c in q[gid]['q']):
                f = fund[0]
                pf = next(r for r in b['probki'] if f in r)[f]
                rozkazy.append({'t_przed': prev, 'kto': gid, 't_proby': q['t'], 'rodzaj': 'budowa', 'cel': f,
                                'fundament': {'id': f, 'typ': pf['typ'], 'X': pf['X'], 'Y': pf['Y'], 'x': pf['x'], 'y': pf['y'],
                                              'z': pf['z'], 'gracz': int(f, 16) >> 24}})
                break
            prev = q['t']
    o = {'nagranie': obs.split('/')[-1] + '+' + bud.split('/')[-1], 'wariant': a.get('wariant', 'ee'), 'T0': T0, 'takt_ms': TAKT_MS, 'jednostki': jedn,
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
            if c and any((cc.get('klasa') or '').endswith(VT_ZBIERANIE) for poz in (c.get('kolejka') or {}).get('poziomy', [])
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
        # EE 673: rejestracja [gracz, 0xAF8, 32] – zasoby od początku wycinka; etap 53: wycinek [gracz, 0xA00, 0x400]
        zas = list(struct.unpack_from('<5i', g, 0 if len(g) < 0x400 else PRODUKCJA_POLA[d.get('wariant', 'ee')]['zywnosc'] - 0xA00))
    o = {'nagranie': nagr.split('/')[-1], 'wariant': d.get('wariant', 'ee'), 'T0': T0, 'takt_ms': TAKT_MS, 'jednostki': jedn, 'zrodla': zrodla, 'rozkazy': rozkazy,
         'koniec_t': seria[-1]['t'], 'zasoby_startowe': {'1': zas} if zas else {}}
    json.dump(o, open(wyj, 'w'), indent=1)
    for q in seria:   # źródła poza porównaniem pozycji (pola x/y obiektów prostych nieznane)
        for z in zrodla:
            q.pop(z['id'], None)
    json.dump({'probki': seria}, open(wyj.replace('.json', '') + '.seria.json', 'w'))
    print(json.dumps({k: v for k, v in o.items() if k != 'jednostki'}, ensure_ascii=False)[:900])


def takt_zegara(t):
    """Etap 54: numer taktu (ułamkowy) z czasu gry. Zegar gry (EEPhysics +0xD0, f32) rośnie co takt o 1500/44 ms
    zaokrąglone do kwantu f32: 34,09375 ms dla 65536…524288 ms (kwant 1/128…1/32) i 34,0625 ms powyżej 524288 ms
    (kwant 1/16) [P: etap 53 – 677/705; etap 54 – 713: 19,8 ms odchyłki przy t = 303189]. Poniżej 65536 ms błąd kwantu
    (≤ 0,001 ms na takt) jest pomijany."""
    a, b = 65536.0, 524288.0
    if t <= a:
        return t / TAKT_MS
    if t <= b:
        return a / TAKT_MS + (t - a) / 34.09375
    return a / TAKT_MS + (b - a) / 34.09375 + (t - b) / 34.0625


def porownaj(ser_p, core_p, pomin=()):
    """Etap 46 (I2): na końcu jedno podsumowanie – pierwszy rozbieżny takt, jednostka, pole, wartości gra/Core,
    ostatnie zdarzenie walki Core przed nim, próbki nieaktualne, tryb RNG i graf."""
    ser = json.load(open(ser_p))['probki']; core = json.load(open(core_p))
    ct = [p[1] for p in core['probki']]
    # etap 54: próbka gry → próbka Core po czasie przeliczonym na siatkę 1500/44 ms modelem zegara gry (takt_zegara):
    # po kilku tysiącach taktów surowy czas próbki odbiega od siatki o ponad pół taktu [P: 713, 715 – 20 ms po 7000
    # taktach]. Dla t ≤ 65536 ms przeliczenie jest tożsamością (wcześniejsze nagrania bez zmian).
    def at(t):
        tc = takt_zegara(t) * TAKT_MS
        i = bisect.bisect_right(ct, tc + 16.0) - 1
        return core['probki'][i] if i >= 0 and abs(core['probki'][i][1] - tc) <= 16.0 else None
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


# Etap 52: produkcja w budynku – przesunięcia pól wg kompilacji [W: AoC 0x5F5F97/0x6394CD, EE 0x5E8908/0x624DF8; P: 677/679]
PRODUKCJA_POLA = {'aoc': {'biezaca': 0x260, 'pozostalo': 0x280, 'pozycja_b': 8, 'zywnosc': 0xAFC, 'populacja': 0xB14},
                  'ee': {'biezaca': 0x25C, 'pozostalo': 0x27C, 'pozycja_b': 4, 'zywnosc': 0xAF8, 'populacja': 0xB10}}
BRAK_TECH = 100000


def stan_produkcji(d, budynek, gracz_od=0xA00):
    """Etap 52: z nagrania (surowe bajty budynku 0…0x700 i gracza od `gracz_od`) – lista (t, bieżąca, licznik, kolejka,
    zasoby[5], populacja) dla każdej próbki."""
    P = PRODUKCJA_POLA[d.get('wariant', 'ee')]
    out = []
    for p in d['probki']:
        b = base64.b64decode(p[budynek]['surowe']['0x0']); g = base64.b64decode(p['gracze']['1'])
        od, do = struct.unpack_from('<ii', b, 0x4C)
        cur = struct.unpack_from('<i', b, P['biezaca'])[0]
        out.append((p['t'], -1 if cur == BRAK_TECH else cur, struct.unpack_from('<i', b, P['pozostalo'])[0],
                    (do - od) // P['pozycja_b'] if od else 0, list(struct.unpack_from('<5i', g, P['zywnosc'] - gracz_od)),
                    struct.unpack_from('<i', g, P['populacja'] - gracz_od)[0]))
    return out


# etap 53: para technologii obywatela (przycisk zamawia 1074; start losuje płeć – AoC 0x5FDDED, EE 0x5EFB91)
PARA_PLCI = {1451: 1074}


def opis_produkcji(nagr, uklad, wyj, globalny=100, dodatkowe=''):
    """Etap 52/53: rozkazy produkcji i anulowania z nagrania (surowe bajty budynku i gracza).
    Budynek = pierwsza jednostka z 1. próbki, w której polach produkcji cokolwiek się dzieje. Rozkaz = próbka, w której
    rośnie liczba pozycji (kolejka + bieżąca, z poprawką na pozycję zakończoną w tym takcie); anulowanie = próbka, w której
    liczba pozycji maleje bez zakończenia (licznik daleko od zera). Technologia przycisku: jedyna technologia startów
    nagrania (1451 → 1074: płeć losuje start); nagranie z kilkoma technologiami nie jest obsługiwane (kolejka w surowych
    bajtach to tylko wskaźniki). Populacja startowa z próbki, składnik globalny limitu z odczytu gry. Nowe jednostki gry
    (rejestrator `nowe_gracza`) – `nowe_gry`: pierwsza próbka (czas, typ, pozycja, kurs, stan, cel).
    `dodatkowe` = "typ:x:y,typ:x:y" – jednostki gracza 1 stojące na mapie od wcześniejszych przebiegów tej samej sesji
    (nie ma ich w układzie scenariusza ani w rejestracji), np. wyprodukowane wcześniej – zajmują miejsca wyjścia."""
    d = json.load(open(nagr)); u = json.load(open(uklad))
    nazwy = {gid: g for g, v in u['grupy'].items() for gid in v['id']}
    P0 = d['probki'][0]
    budynek = None
    for g in d['jednostki']:
        if g not in P0 or '0x0' not in (P0[g].get('surowe') or {}):
            continue
        st = stan_produkcji(d, g)
        if any(x[1] >= 0 or x[3] > 0 for x in st):
            budynek = g
            break
    if budynek is None:
        raise SystemExit('opis_produkcji: w nagraniu nie ma budynku z produkcją')
    seria = _seria(d)
    T0 = seria[0]['t']
    jedn = []
    for gid in d['jednostki']:
        if gid not in seria[0]:
            continue
        q = seria[0][gid]
        jedn.append({'id': gid, 'nazwa': nazwy.get(gid, gid), 'typ': q['typ'], 'gracz': int(gid, 16) >> 24, 'x': q['x'],
                     'y': q['y'], 'z': q['z'], 'kurs': math.atan2(-q['m01'], q['m11']), 'hp': q['hp']})
    for k, e in enumerate(x for x in dodatkowe.split(',') if x):
        ty, x, y = e.split(':')[:3]
        jedn.append({'id': '0x7f%06x' % k, 'nazwa': 'dodatkowa%d' % k, 'typ': int(ty), 'gracz': 1, 'x': float(x), 'y': float(y),
                     'z': None, 'kurs': math.pi, 'hp': None})
    starty = [st[i][1] for i in range(1, len(st)) if st[i][1] >= 0 and (st[i][1] != st[i - 1][1] or st[i][2] > st[i - 1][2])]
    przyciski = sorted({PARA_PLCI.get(t, t) for t in starty})
    if len(przyciski) != 1:
        raise SystemExit(f'opis_produkcji: technologie startów {sorted(set(starty))} – obsługiwana jedna technologia przycisku')
    tech = przyciski[0]
    rozkazy = []
    takt = [0]   # numer taktu próbki liczony od 1. próbki (zegar gry nie jest równomierny – zob. porownaj_produkcje)
    for i in range(1, len(st)):
        takt.append(takt[-1] + max(1, round((st[i][0] - st[i - 1][0]) / TAKT_MS)))
    for i in range(1, len(st)):
        a, b = st[i - 1], st[i]
        na, nb = a[3] + (a[1] >= 0), b[3] + (b[1] >= 0)
        koniec = 1 if (a[1] >= 0 and 0 < a[2] <= 34 and (b[1] < 0 or b[2] > a[2])) else 0   # pozycja zakończona w tym takcie
        delta = nb - na + koniec
        for _ in range(max(0, delta)):
            rozkazy.append({'t_przed': a[0], 'takt_przed': takt[i - 1], 'kto': budynek, 't_proby': b[0], 'rodzaj': 'produkcja', 'tech': tech})
        for _ in range(max(0, -delta)):
            rozkazy.append({'t_przed': a[0], 'takt_przed': takt[i - 1], 'kto': budynek, 't_proby': b[0], 'rodzaj': 'anuluj', 'tech': tech})
    # etap 54: punkt zbiórki – cel EEUGLocation w drugim poziomie kolejki celów budynku (dokładny punkt kliknięcia);
    # rozkaz w próbce, w której punkt się pojawia albo zmienia (punkt obecny już w 1. próbce – rozkaz przed 1. taktem)
    ost_zb = None
    for i, p in enumerate(d['probki']):
        poz = ((p.get(budynek) or {}).get('kolejka') or {}).get('poziomy') or []
        c = poz[1]['cele'] if len(poz) > 1 else []
        pk = tuple(c[0]['punkt'][:2]) if c and c[0].get('klasa') == 'EEUGLocation' else None
        if pk != ost_zb and pk is not None:
            rozkazy.append({'t_przed': d['probki'][max(i - 1, 0)]['t'], 'takt_przed': takt[max(i - 1, 0)], 'kto': budynek,
                            't_proby': p['t'], 'rodzaj': 'zbiorka', 'x': pk[0], 'y': pk[1]})
        ost_zb = pk
    rozkazy.sort(key=lambda r: r['takt_przed'])
    nowe = []
    nowe_seria = []
    for n in d.get('nowe') or []:
        q = next((p[n['id']] for p in d['probki'] if n['id'] in p), None)
        if q is None:
            continue
        nowe_seria.append([[takt[i], p[n['id']]['stan'], p[n['id']]['x'], p[n['id']]['y'],
                            math.atan2(-p[n['id']]['m01'], p[n['id']]['m11'])] for i, p in enumerate(d['probki']) if n['id'] in p])
        cele = [c.get('punkt') for c in ((q.get('kolejka') or {}).get('poziomy') or [{}])[0].get('cele', [])]
        nowe.append({'id': n['id'], 't': n['t'], 'typ': q['typ'], 'x': q['x'], 'y': q['y'],
                     'kurs': math.atan2(-q['m01'], q['m11']), 'stan': q['stan'], 'cele': cele})
    o = {'nagranie': nagr.split('/')[-1], 'wariant': d.get('wariant', 'ee'), 'T0': T0, 'takt_ms': TAKT_MS, 'jednostki': jedn,
         'rozkazy': rozkazy, 'koniec_t': seria[-1]['t'], 'koniec_takt': takt[-1], 'zasoby_startowe': {'1': st[0][4]},
         'populacja': {'1': [st[0][5], int(globalny)]}, 'produkcja': sorted(set(starty) | {tech}),
         'budynki_produkcji': [budynek], 'nowe_gry': nowe}
    json.dump(o, open(wyj, 'w'), indent=1)
    json.dump({'probki': seria, 'produkcja': {budynek: st}, 'nowe_gry': nowe, 'nowe_seria': nowe_seria,
               'rng': [[p['t'], p.get('rng_kroki')] for p in d['probki']]}, open(wyj.replace('.json', '') + '.seria.json', 'w'))
    print(json.dumps({k: v for k, v in o.items() if k != 'jednostki'}, ensure_ascii=False)[:1100])


def porownaj_produkcje(ser_p, core_p):
    """Etap 52/53: próbka po próbce – bieżąca pozycja, licznik, długość kolejki, zasoby i populacja (gra / Core);
    pierwsza rozbieżność i liczba zgodnych próbek. Etap 53: nowe jednostki – gra (pierwsza próbka rejestratora) wobec
    Core: różnica czasu w taktach, typ, pozycja (|Δ| ≤ 0,002), kurs (|Δ| ≤ 0,002 rad), stan początkowy; losowania
    generatora w taktach startu i utworzenia (gdy Core uruchomiono z --rng=1)."""
    ser = json.load(open(ser_p)); core = json.load(open(core_p))
    ct = [p[1] for p in core['probki']]
    zg = n = nieakt = 0; pierwsza = None
    for gid, st in ser['produkcja'].items():
        pop_g = None; pop_ok = False
        # etap 53: dopasowanie po numerze taktu, nie po czasie – zegar gry (EEPhysics +0xD0) powyżej 524288 ms rośnie o
        # 34,0625 ms na takt (kwant f32 = 1/16 ms) zamiast 1500/44 [P: 677_dwa, 705], więc czas próbki rozjeżdża się z siatką
        # Core o 0,03 ms/takt. Pierwsza próbka gry wyznacza takt Core po czasie; kolejne – po liczbie taktów gry.
        i_pocz = None; takt_gry = 0; t_pop = None
        for (t, cur, ms, kol, zas, pop) in st:
            if t_pop is not None:
                takt_gry += max(1, round((t - t_pop) / TAKT_MS))
            t_pop = t
            if i_pocz is None:
                j = bisect.bisect_right(ct, t + 16.0) - 1
                if j < 0:
                    i_pocz = -1          # próbka sprzed pierwszego taktu Core (start od 1. próbki): takt Core = −1
                    continue
                if abs(ct[j] - t) > 16.0:
                    t_pop = None; takt_gry = 0   # poza zakresem Core – szukaj dalej
                    continue
                i_pocz = j
            i = i_pocz + takt_gry
            if i < 0 or i >= len(ct):
                continue
            pc = core['probki'][i][2]
            c = pc.get('prod_' + gid, [-1, 0, 0])
            g_ = (cur, ms if cur >= 0 else 0, kol, zas, pop); k_ = (c[0], c[1] if c[0] >= 0 else 0, c[2], pc.get('zasoby'), pc.get('populacja'))
            n += 1
            if g_ == k_:
                zg += 1; pop_ok = True
            elif pop_ok and g_ == pop_g:
                # próbka nieaktualna rejestratora: gra = poprzednia próbka (zgodna z Core); następna znów jest porównywana
                nieakt += 1; pop_ok = False
            else:
                pop_ok = False
                if pierwsza is None: pierwsza = (t, g_, k_)
            pop_g = g_
    print(f"produkcja: zgodne {zg}/{n}, próbek nieaktualnych rejestratora {nieakt}; pierwsza rozbieżność: {pierwsza}")
    nc = core.get('nowe', [])
    print("nowe jednostki Core (t, typ, x, y, kurs[, stan]):", nc)
    ng = ser.get('nowe_gry') or []
    ok_n = 0
    for k, g in enumerate(ng):
        if k >= len(nc):
            print(f"  nowa {g['id']}: brak w Core"); continue
        c = nc[k]
        dt = round((c[0] - g['t']) / TAKT_MS)
        # etap 54: gdy są przebiegi nowych jednostek – różnica w numerach taktów (zegar gry nie jest równomierny:
        # po kilku tysiącach taktów czas próbki odbiega od siatki 1500/44 ms o ponad pół taktu [P: 713])
        gs_, cs_ = ser.get('nowe_seria') or [], core.get('nowe_seria') or []
        if k < len(gs_) and k < len(cs_) and gs_[k] and cs_[k]:
            dt = (cs_[k][0][0] + 1) - gs_[k][0][0]
        dk = abs((c[4] - g['kurs'] + math.pi) % (2 * math.pi) - math.pi)
        zgodna = dt == 0 and c[1] == g['typ'] and abs(c[2] - g['x']) <= 0.002 and abs(c[3] - g['y']) <= 0.002 and dk <= 0.002 \
            and (len(c) < 6 or c[5] == g['stan'])
        ok_n += zgodna
        print(f"  nowa {g['id']}: gra t={g['t']} typ {g['typ']} ({g['x']:.3f}; {g['y']:.3f}) kurs {g['kurs']:.4f} stan {g['stan']} cele {g['cele']}"
              f" | Core Δt {dt} taktów, typ {c[1]}, ({c[2]:.3f}; {c[3]:.3f}), kurs {c[4]:.4f}, stan {c[5] if len(c) > 5 else '?'} → {'zgodna' if zgodna else 'RÓŻNA'}")
    if ng:
        print(f"nowe jednostki: zgodne {ok_n}/{len(ng)} (Core utworzył {len(nc)})")
    # etap 54: przebieg nowych jednostek co takt (stan, pozycja, kurs; te same progi co `porownaj`: 0,002 pola / rad).
    # Numer taktu gry liczony od 1. próbki nagrania; Core: takt k odpowiada próbce o numerze k + 1 przy --od-startu=0.
    gs, cs = ser.get('nowe_seria') or [], core.get('nowe_seria') or []
    for k, g in enumerate(gs):
        if k >= len(cs) or not cs[k] or not g:
            continue
        przes = cs[k][0][0] - g[0][0]          # różnica numeracji taktów z pierwszej próbki
        cm = {c[0] - przes: c for c in cs[k]}
        zgn = por = 0; pierw = None
        for (tk, stan, x, y, kurs) in g:
            c = cm.get(tk)
            if c is None:
                continue
            por += 1
            dkk = abs((c[4] - kurs + math.pi) % (2 * math.pi) - math.pi)
            if c[1] == stan and abs(c[2] - x) <= 0.002 and abs(c[3] - y) <= 0.002 and dkk <= 0.002:
                zgn += 1
            elif pierw is None:
                pierw = {'takt_od_utworzenia': tk - g[0][0], 'gra': (stan, round(x, 4), round(y, 4), round(kurs, 4)),
                         'core': (c[1], round(c[2], 4), round(c[3], 4), round(c[4], 4))}
        print(f"  przebieg nowej {k}: zgodne {zgn}/{por}; koniec gra ({g[-1][2]:.3f}; {g[-1][3]:.3f}) stan {g[-1][1]}, "
              f"Core ({cs[k][-1][2]:.3f}; {cs[k][-1][3]:.3f}) stan {cs[k][-1][1]}; pierwsza rozbieżność: {pierw}")
    # losowania: takty, w których gra albo Core odbiega od 2 losowań taktu
    rg = {int(round(t)): k for t, k in ser.get('rng', []) if k is not None}
    if rg and core['probki'] and 'rng_n' in core['probki'][0][2]:
        roz = []; por = 0
        zdarzenia = set()
        takt_t = {}                       # etap 54: czas próbki → numer taktu od 1. próbki (jak w porównaniu produkcji)
        for gid, st in ser['produkcja'].items():
            tk = 0
            for j, (a, b) in enumerate(zip(st, st[1:])):
                tk += max(1, round((b[0] - a[0]) / TAKT_MS))
                takt_t[int(round(b[0]))] = tk
                if a[1] != b[1] or b[2] > a[2]:
                    zdarzenia.add(int(round(b[0])))
        for t in sorted(zdarzenia):
            i = (i_pocz + takt_t[t]) if (i_pocz is not None and t in takt_t) else bisect.bisect_right(ct, t + 16.0) - 1
            if i < 0 or i >= len(ct) or t not in rg:
                continue
            por += 1
            if core['probki'][i][2]['rng_n'] != rg[t]:
                roz.append((t, rg[t], core['probki'][i][2]['rng_n']))
        print(f"losowania w taktach startu/utworzenia/anulowania: porównane {por}, różne {len(roz)} (t, gra, Core): {roz[:6]}")
    return zg, n, pierwsza


def porownaj_zbieranie(nagr, core_p, obywatel, drzewo, indeks=1):
    """Etap 51/53: gospodarka zbierania próbka po próbce – drewno gracza, ładunek obywatela (+0x40), ilość (+0x40) i HP
    (+0x3C) drzewa: gra wobec Core (pola próbki `zasoby`, `niesie_<id>`, `zrodla`). Zasoby gracza: wycinek rejestratora
    [gracz, 0xAF8, 32] (EE, etap 51) albo [gracz, 0xA00, 0x400] z przesunięciem gry (etap 53). Etap 54: `indeks` – surowiec
    gracza (drewno 1, kamień 2, złoto 3, żelazo 4); obywatel w próbce bez surowych bajtów jest pomijany."""
    d = json.load(open(nagr)); c = json.load(open(core_p))
    ct = [p[1] for p in c['probki']]
    T0 = c['probki'][0][1]; n = zg = 0; pierwsza = None; gra = core = None
    for p in d['probki']:
        if p['t'] < T0:
            continue
        # etap 54: dopasowanie po numerze taktu (zob. porownaj)
        tc = takt_zegara(p['t']) * TAKT_MS
        i = bisect.bisect_right(ct, tc + 16) - 1
        cp = c['probki'][i][2] if i >= 0 and abs(ct[i] - tc) <= 16 else None
        if not cp or 'zasoby' not in cp or obywatel not in p or 'surowe' not in p[obywatel]:
            continue
        g = base64.b64decode(p['gracze']['1'])
        off = 0 if len(g) < 0x400 else PRODUKCJA_POLA[d.get('wariant', 'ee')]['zywnosc'] - 0xA00
        bc = base64.b64decode(p[obywatel]['surowe']['0x0']); bt = base64.b64decode(p[drzewo]['surowe']['0x0'])
        gra = (struct.unpack_from('<i', g, off + 4 * int(indeks))[0], struct.unpack_from('<i', bc, 0x40)[0], struct.unpack_from('<i', bt, 0x40)[0],
               struct.unpack_from('<i', bt, 0x3C)[0])
        core = (cp['zasoby'][int(indeks)], cp['niesie_' + obywatel], cp['zrodla'][drzewo][1], cp['zrodla'][drzewo][0])
        n += 1
        if gra == core: zg += 1
        elif pierwsza is None: pierwsza = (p['t'], gra, core)
    print(f"zbieranie (surowiec gracza [{indeks}], ładunek, ilość i HP źródła): zgodne {zg}/{n}; pierwsza różnica: {pierwsza}; koniec gra {gra} Core {core}")


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == 'opis':
        opis(a[1], a[2], a[3])
    elif a and a[0] == 'opis_zbierania':
        opis_zbierania(a[1], a[2], a[3], a[4] if len(a) > 4 else None)
    elif a and a[0] == 'opis_produkcji':
        opis_produkcji(a[1], a[2], a[3], int(a[4]) if len(a) > 4 else 100, a[5] if len(a) > 5 else '')
    elif a and a[0] == 'porownaj_zbieranie':
        porownaj_zbieranie(a[1], a[2], a[3], a[4], int(a[5]) if len(a) > 5 else 1)
    elif a and a[0] == 'porownaj_produkcje':
        porownaj_produkcje(a[1], a[2])
    elif a and a[0] == 'opis_budowy':
        opis_budowy(a[1], a[2], a[3], a[4], a[5] if len(a) > 5 else None)
    elif a and a[0] == 'porownaj':
        w = porownaj(a[1], a[2], tuple(int(x) for x in a[3].split(',')) if len(a) > 3 and a[3] else ())
        podsumowanie(json.load(open(a[2])), w)
    else:
        raise SystemExit(__doc__)
