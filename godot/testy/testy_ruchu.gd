class_name TestyRuchuEE
extends RefCounted
## Testy etapu 9 (docs/MECHANIKA_RUCHU_EE.md, raporty/archiwum/RAPORT_RUCH_GRUPOWY_EE.md): reguły zaznaczania EE, szyk grupy, trasy
## oktylowe, kolejka Shift + PPM, zastępowanie rozkazów, ruch grupy w terenie otwartym i przez przesmyk, przenikanie
## jednostek, omijanie budynków, rozkaz do terenu nieosiągalnego, stan animacji. Mapy syntetyczne; dane odniesienia
## – trajektorie zmierzone w oryginale (Testy_MCP/ee_ruch, pozycje startowe i końcowe – liczby, bez zasobów gry).

var t
const L := MapaNawigacji.LAD
const G := MapaNawigacji.GLEBOKA

# Pomiar EE (e9_G5, e9_G10): [id, start, koniec] – obywatele, rozkaz ruchu grupy w terenie otwartym.
const EE_G5 := [[14, Vector2(28.500, 94.500), Vector2(37.623, 102.903)], [15, Vector2(29.500, 94.500), Vector2(38.047, 102.447)],
	[16, Vector2(30.500, 94.500), Vector2(38.495, 102.001)], [17, Vector2(31.500, 94.500), Vector2(38.900, 101.530)],
	[18, Vector2(32.500, 94.500), Vector2(39.297, 101.052)]]
const EE_G10 := [[19, Vector2(48.500, 75.500), Vector2(57.636, 84.403)], [20, Vector2(49.500, 75.500), Vector2(58.064, 83.946)],
	[21, Vector2(50.500, 75.500), Vector2(58.492, 83.488)], [22, Vector2(51.500, 75.500), Vector2(58.925, 83.038)],
	[23, Vector2(52.500, 75.500), Vector2(59.325, 82.544)], [24, Vector2(48.500, 76.500), Vector2(57.180, 83.934)],
	[25, Vector2(49.500, 76.500), Vector2(57.595, 83.504)], [26, Vector2(50.500, 76.500), Vector2(58.016, 83.108)],
	[27, Vector2(51.500, 76.500), Vector2(58.444, 82.645)], [28, Vector2(52.500, 76.500), Vector2(58.873, 82.188)]]


func _init(runner) -> void:
	t = runner


func _mapa(wiersze: Array, pd: int = 1) -> MapaNawigacji:
	var h := wiersze.size(); var w := String(wiersze[0]).length()
	var kat := PackedByteArray(); kat.resize(w * h)
	for r in h:
		for c in w:
			kat[r * w + c] = G if String(wiersze[r])[c] == "~" else L
	return MapaNawigacji.z_tablic(h, w, kat, PackedFloat32Array(), pd)


func _otwarta(n: int) -> MapaNawigacji:
	var w: Array = []
	for i in n: w.append(".".repeat(n))
	return _mapa(w)


func _jedn(sym: Symulacja, p: Vector2, speed := 0.5, kurs := 0.0) -> int:
	var d := JednostkaSym.DaneJednostki.new()
	d.typ = 32; d.pozycja = p; d.kurs = kurs
	return sym.dodaj_jednostke(d, {"Name": "obywatel", "Speed": speed, "Idle turning speed": 6.0,
		"Moving turning speed": 8.0, "Circle selection size": 0.3, "Size in formation": 0.625})


func _wszystkie_stoja(sym: Symulacja) -> bool:
	for j in sym.lista():
		if j.w_ruchu(): return false
	return true


func _do_konca(sym: Symulacja, maks := 4000) -> int:
	var n := 0
	while n < maks and (n == 0 or not _wszystkie_stoja(sym)):
		sym.krok(); n += 1
	return n


func uruchom() -> void:
	_zaznaczanie()
	_szyk()
	_szyk_ee()
	_trasy()
	_ruch_grupy()
	_przesmyk()
	_przenikanie()
	_budynek()
	_kolejka_i_zastapienie()
	_nieosiagalny()


func _zaznaczanie() -> void:
	var z := ZaznaczenieEE.new()
	z.klik(3); var a := z.ids.duplicate()
	z.klik(5); var b := z.ids.duplicate()
	z.klik(7, "shift"); var c := z.ids.duplicate()
	z.klik(7, "shift"); var d := z.ids.duplicate()
	z.klik(5, "ctrl"); var e := z.ids.duplicate()
	z.klik(-1, "shift"); var f := z.ids.duplicate()
	z.klik(-1); var g := z.ids.duplicate()
	t._ok("E9 zaznaczanie: LPM zastępuje, Shift dodaje (bez odznaczania), Ctrl usuwa, LPM na terenie czyści",
		a == [3] and b == [5] and c == [5, 7] and d == [5, 7] and e == [7] and f == [7] and g == [],
		[a, b, c, d, e, f, g])
	z.ramka([1, 2, 3]); var r1 := z.ids.duplicate()
	z.ramka([3, 4], "shift"); var r2 := z.ids.duplicate()
	z.ramka([1, 4], "ctrl"); var r3 := z.ids.duplicate()
	z.ramka([]); var r4 := z.ids.duplicate()
	t._ok("E9 zaznaczanie: ramka zastępuje, Shift + ramka dodaje, Ctrl + ramka usuwa",
		r1 == [1, 2, 3] and r2 == [1, 2, 3, 4] and r3 == [2, 3] and r4 == [], [r1, r2, r3, r4])
	# ramka – punkt jednostki w prostokącie ekranu (rzut testowy: x → px, wysokość ignorowana)
	var sym := Symulacja.new(_otwarta(20))
	var ids: Array = []
	for i in 50: ids.append(_jedn(sym, Vector2(2.5 + (i % 10) * 0.7, 3.5 + (i / 10) * 0.7)))
	var rzut := func(p: Vector3) -> Vector2:
		var m := UkladEE.mapa(p); return Vector2(m.x * 100.0, m.y * 100.0)
	var w := ZaznaczenieEE.w_prostokacie(sym, Rect2(0, 0, 2000, 2000), rzut)
	var w2 := ZaznaczenieEE.w_prostokacie(sym, Rect2(200, 300, 130, 60), rzut)
	t._ok("E9 zaznaczanie: ramka obejmuje 50 jednostek (brak limitu ≤ 50 jak w EE), wybór wg punktu jednostki",
		w.size() == 50 and w2 == [ids[0], ids[1]], [w.size(), w2])


func _szyk() -> void:
	var cel := Vector2(20, 20)
	var j1 := FormacjaEE.rozmiesc([[4, Vector2(10, 20), 0.625]], cel)
	t._ok("E9 szyk: pojedyncza jednostka – dokładnie punkt rozkazu", j1[4] == cel, j1)
	var g: Array = []
	for i in 10: g.append([100 - i, Vector2(10 + (i % 5), 19 + i / 5), 0.625])
	var m := FormacjaEE.rozmiesc(g, cel)
	var f := (cel - Vector2(12, 19.5)).normalized(); var lewo := Vector2(-f.y, f.x)
	var ok := true
	var ids := m.keys(); ids.sort()
	for k in 10:
		var r := k / 5; var c := k % 5
		var oczek := cel - f * (r * 0.625) + lewo * ((2 - c) * 0.625)
		if m[ids[k]].distance_to(oczek) > 1e-4: ok = false
	t._ok("E9 szyk: 10 jednostek → 2 rzędy × 5, pierwszy rząd w punkcie rozkazu, odstęp „Size in formation”, id rosnąco od lewej",
		ok, m)
	var g7: Array = []
	for i in 7: g7.append([i, Vector2(10, 10 + i), 0.625])
	var m7 := FormacjaEE.rozmiesc(g7, Vector2(20, 13))
	var sr: Vector2 = (m7[5] + m7[6]) * 0.5
	var f7 := (Vector2(20, 13) - Vector2(10, 13)).normalized()
	t._ok("E9 szyk: niepełny ostatni rząd wyśrodkowany za pierwszym", sr.distance_to(Vector2(20, 13) - f7 * 0.625) < 1e-4, m7)
	var gm: Array = [[1, Vector2(0, 0), 0.625], [2, Vector2(1, 0), 0.77]]
	var mm := FormacjaEE.rozmiesc(gm, Vector2(5, 5))
	t._ok("E9 szyk: grupa mieszana – odstęp = największy „Size in formation”", absf(mm[1].distance_to(mm[2]) - 0.77) < 1e-4, mm)


## Porównanie liczbowe z oryginałem: miejsca końcowe obliczone z pozycji startowych EE vs zmierzone w EE.
func _szyk_ee() -> void:
	for dane in [["G5", EE_G5, 1], ["G10", EE_G10, 2]]:
		var lista: Array = dane[1]
		var s0 := Vector2.ZERO; var s1 := Vector2.ZERO
		var wej: Array = []
		for e in lista:
			s0 += e[1]; s1 += e[2]; wej.append([e[0], e[1], 0.625])
		s0 /= lista.size(); s1 /= lista.size()
		var f := (s1 - s0).normalized()
		# punkt rozkazu (kliknięcie) nie jest zapisany – odtworzony ze środka szyku: pierwszy rząd przed środkiem
		var cel := s1 + f * ((int(dane[2]) - 1) * 0.5 * 0.625)
		var m := FormacjaEE.rozmiesc(wej, cel)
		var suma := 0.0; var maks := 0.0
		for e in lista:
			var d: float = m[e[0]].distance_to(e[2]); suma += d * d; maks = maxf(maks, d)
		var rms := sqrt(suma / lista.size())
		t._ok("E9 zgodność z EE: szyk %s – miejsca jednostek jak w pomiarze oryginału (RMS ≤ 0,06 pola)" % dane[0],
			rms <= 0.06, "RMS %.3f, maks %.3f" % [rms, maks])


func _trasy() -> void:
	var m := _otwarta(20)
	var s := Sciezki.new(m); s.oktylowe = true
	var pol := PolitykaRuchu.new()
	var w := s.znajdz(Vector2(2.5, 2.5), Vector2(12.5, 5.5), pol)
	var ok: bool = w.ok and w.sciezka.size() == 2
	if ok:
		var d1: Vector2 = w.sciezka[0] - Vector2(2.5, 2.5)
		var d2: Vector2 = w.sciezka[1] - w.sciezka[0]
		ok = d1.is_equal_approx(Vector2(3, 3)) and absf(d2.y) < 1e-5 and d2.x > 0
	t._ok("E9 trasy: odcinki oktylowe przez środki pól – najpierw przekątna, potem prosto (jak w EE)", ok, w.sciezka)
	var w2 := s.znajdz(Vector2(2.5, 2.5), Vector2(12.7, 5.2), pol)
	t._ok("E9 trasy: ostatni odcinek do dokładnego punktu celu",
		w2.ok and w2.sciezka[w2.sciezka.size() - 1] == Vector2(12.7, 5.2) and w2.sciezka[0] == Vector2(5.5, 5.5), w2.sciezka)
	var dl_okt := 0.0; var a := Vector2(2.5, 2.5)
	for p in w.sciezka: dl_okt += a.distance_to(p); a = p
	t._ok("E9 trasy: długość trasy oktylowej = odległość oktylowa (bez objazdów)",
		absf(dl_okt - (3.0 * sqrt(2.0) + 7.0)) < 1e-3, dl_okt)


func _ruch_grupy() -> void:
	var sym := Symulacja.new(_otwarta(40))
	var ids: Array = []
	for i in 10: ids.append(_jedn(sym, Vector2(5.5 + (i % 5), 5.5 + i / 5)))
	var szybki := _jedn(sym, Vector2(7.5, 8.5), 0.8)
	ids.append(szybki)
	sym.rozkaz_grupy(ids, Vector2(25.5, 20.5))
	sym.krok()
	var ruszyly := 0
	for id in ids:
		if sym.jednostki[id].w_ruchu(): ruszyly += 1
	var t_konca := {}
	var anim_ok := true
	var n := 0
	while n < 3000 and not _wszystkie_stoja(sym):
		sym.krok(); n += 1
		for e in sym.zdarzenia:
			if e.typ == "stop": t_konca[e.id] = n
		for id in ids:
			var j: JednostkaSym = sym.jednostki[id]
			if j.ruch == JednostkaSym.Ruch.IDZIE and j.pozycja != j.pozycja_poprz and j.stan_animacji != "ruch": anim_ok = false
	var na_miejscu := true
	for id in ids:
		var j: JednostkaSym = sym.jednostki[id]
		if j.pozycja.distance_to(j.miejsce_w_szyku) > 0.06 or j.stan_animacji != "bezczynnosc": na_miejscu = false
	t._ok("E9 ruch grupy: wszystkie jednostki ruszają w tym samym takcie, każda kończy na swoim miejscu szyku",
		ruszyly == ids.size() and na_miejscu, [ruszyly, n])
	var j0: JednostkaSym = sym.jednostki[ids[0]]
	t._ok("E9 ruch grupy: prędkość własna jednostki (bez wyrównania w grupie) – szybsza dochodzi wcześniej",
		t_konca.get(szybki, 99999) < t_konca.get(ids[0], 0) and absf(j0.predkosc - 0.5 * Symulacja.MNOZNIK_PREDKOSCI) < 1e-6,
		[t_konca.get(szybki), t_konca.get(ids[0])])
	t._ok("E9 animacja: stan „ruch” podczas przemieszczania, „bezczynność” po dojściu", anim_ok)
	var poz: Array = []
	for id in ids: poz.append(sym.jednostki[id].pozycja)
	var dmin := INF
	for a in poz.size():
		for b in range(a + 1, poz.size()): dmin = minf(dmin, poz[a].distance_to(poz[b]))
	t._ok("E9 ruch grupy: końcowy rozstaw ≥ 0,6 pola (szyk, nie stos)", dmin >= 0.6, dmin)


func _przesmyk() -> void:
	# rzeka w kolumnach 9–11, bród szerokości 1 pola w wierszu 10
	var kat := PackedByteArray(); kat.resize(400)
	for r in 20:
		for c in 20:
			kat[r * 20 + c] = G if (c >= 9 and c <= 11 and r != 10) else L
	var mp := MapaNawigacji.z_tablic(20, 20, kat, PackedFloat32Array(), 1)
	var sym := Symulacja.new(mp)
	var ids: Array = []
	for i in 10: ids.append(_jedn(sym, Vector2(2.5 + (i % 5), 3.5 + i / 5)))
	sym.rozkaz_grupy(ids, Vector2(16.5, 16.5))
	var w_wodzie := false
	var n := 0
	var kolumna_brodu := true
	while n < 4000 and (n == 0 or not _wszystkie_stoja(sym)):
		sym.krok(); n += 1
		for id in ids:
			var j: JednostkaSym = sym.jednostki[id]
			var k := mp.komorka(j.pozycja)
			if kat[k.y * 20 + k.x] == G: w_wodzie = true
			if j.pozycja.x > 9.2 and j.pozycja.x < 11.8 and absf(j.pozycja.y - 10.5) > 0.01: kolumna_brodu = false
	var po_drugiej := 0
	for id in ids:
		if sym.jednostki[id].pozycja.x > 12: po_drugiej += 1
	t._ok("E9 przesmyk: grupa przechodzi przez bród szerokości 1 pola (bez wejścia w głęboką wodę)",
		po_drugiej == 10 and not w_wodzie, [po_drugiej, w_wodzie, n])
	t._ok("E9 przesmyk: w brodzie jednostki idą jedną linią przez środki pól (x,5) – jak w EE", kolumna_brodu)


func _przenikanie() -> void:
	var sym := Symulacja.new(_otwarta(40))
	var a: Array = []; var b: Array = []
	for i in 5: a.append(_jedn(sym, Vector2(5.5, 15.5 + i)))
	for i in 5: b.append(_jedn(sym, Vector2(25.5, 15.5 + i), 0.5, PI))
	sym.rozkaz_grupy(a, Vector2(25.5, 17.5))
	sym.rozkaz_grupy(b, Vector2(5.5, 17.5))
	var zatrzymania := 0
	var n := 0
	var dmin := INF
	while n < 4000 and (n == 0 or not _wszystkie_stoja(sym)):
		sym.krok(); n += 1
		for e in sym.zdarzenia:
			if e.typ == "stop" and e.powod != "cel osiągnięty": zatrzymania += 1
		for i in a:
			for k in b: dmin = minf(dmin, sym.jednostki[i].pozycja.distance_to(sym.jednostki[k].pozycja))
	# czas ≈ droga / prędkość (+ obrót i dojście do miejsc w szyku) – bez czekania na drugą grupę
	var oczek := 20.0 / (0.5 * Symulacja.MNOZNIK_PREDKOSCI)
	t._ok("E9 kolizje: grupy idące naprzeciw przenikają się bez zatrzymań i objazdów (jak w EE: min. odległość < 0,1)",
		zatrzymania == 0 and dmin < 0.1 and absf(n * Symulacja.KROK - oczek) < 0.1 * oczek + 0.5, [zatrzymania, dmin, n * Symulacja.KROK, oczek])


func _budynek() -> void:
	var m := _otwarta(30)
	m.dodaj_przeszkode(Vector2(15, 15), 0.5 * 2.0)       # „Size of collider” 2 → obrys 2 × 2 pola
	var sym := Symulacja.new(m)
	var ids: Array = []
	for i in 5: ids.append(_jedn(sym, Vector2(8.5, 13.5 + i)))
	sym.rozkaz_grupy(ids, Vector2(22.5, 15.5))
	var w_budynku := false
	var n := 0
	while n < 4000 and (n == 0 or not _wszystkie_stoja(sym)):
		sym.krok(); n += 1
		for id in ids:
			var p: Vector2 = sym.jednostki[id].pozycja
			if p.x > 14.05 and p.x < 15.95 and p.y > 14.05 and p.y < 15.95: w_budynku = true
	var blok := 0
	for y in range(13, 17):
		for x in range(13, 17):
			if not m.przechodnia(Vector2i(x, y), PolitykaRuchu.new()): blok += 1
	t._ok("E9 budynki: obrys „Size of collider” 2 = 2 × 2 pola, jednostki nie przechodzą przez budynek",
		blok == 4 and not w_budynku, [blok, w_budynku])


func _kolejka_i_zastapienie() -> void:
	var sym := Symulacja.new(_otwarta(30))
	var id := _jedn(sym, Vector2(5.5, 5.5))
	sym.rozkaz_ruchu(id, Vector2(12.5, 5.5))
	sym.krok()
	sym.rozkaz_ruchu(id, Vector2(12.5, 12.5), true)
	var przez_a := false
	var n := 0
	while n < 3000 and (n < 2 or sym.jednostki[id].w_ruchu()):
		sym.krok(); n += 1
		if sym.jednostki[id].pozycja.distance_to(Vector2(12.5, 5.5)) < 0.06: przez_a = true
	var j: JednostkaSym = sym.jednostki[id]
	t._ok("E9 kolejka: Shift + PPM – jednostka dochodzi do punktu A, potem idzie do B (jak w EE)",
		przez_a and j.pozycja.distance_to(Vector2(12.5, 12.5)) < 0.06, [przez_a, j.pozycja])
	var sym2 := Symulacja.new(_otwarta(30))
	var ids: Array = [_jedn(sym2, Vector2(5.5, 5.5)), _jedn(sym2, Vector2(6.5, 5.5))]
	sym2.rozkaz_grupy(ids, Vector2(20.5, 5.5))
	for i in 20: sym2.krok()
	sym2.rozkaz_grupy(ids, Vector2(5.5, 20.5))
	_do_konca(sym2)
	var ok := true
	for i in ids:
		var jj: JednostkaSym = sym2.jednostki[i]
		if jj.pozycja.distance_to(jj.miejsce_w_szyku) > 0.06 or jj.pozycja.y < 19.0: ok = false
	t._ok("E9 rozkazy: nowy rozkaz zastępuje poprzedni w trakcie ruchu (bez dojścia do starego celu)", ok)


func _nieosiagalny() -> void:
	var kat := PackedByteArray(); kat.resize(400)
	for r in 20:
		for c in 20:
			kat[r * 20 + c] = G if c >= 12 else L
	var m := MapaNawigacji.z_tablic(20, 20, kat, PackedFloat32Array(), 1)
	var sym := Symulacja.new(m)
	var ids: Array = []
	for i in 3: ids.append(_jedn(sym, Vector2(3.5, 8.5 + i)))
	sym.rozkaz_grupy(ids, Vector2(15.5, 9.5))
	_do_konca(sym)
	var ok := true
	for i in ids:
		var p: Vector2 = sym.jednostki[i].pozycja
		if p.x < 10.9 or p.x > 12.0: ok = false
	t._ok("E9 rozkazy: cel w wodzie – jednostki stają na najbliższych osiągalnych polach przy brzegu", ok,
		ids.map(func(i): return sym.jednostki[i].pozycja))
