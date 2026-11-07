class_name TestyEtapu13
extends RefCounted
## Testy etapu 13 (RAPORT_ETAP_13.md):
##  * scenariusz kampanii wybierany numerem z listy kampanii (campaigns/*_scenariolist.txt), nie przetłumaczonym
##    tytułem – dane syntetyczne PL/EN i (jeśli są) obie instalacje: polska społecznościowa i angielska referencyjna;
##  * domyślny scenariusz scen testowych z definicji gry (dane/gry.json „kampania_testowa”) dla EE i AoC;
##  * model prędkości (docs/MECHANIKA_PREDKOSCI_EE.md): Speed = pola na sekundę czasu gry; normalna szybkość = 1,461 ms
##    czasu gry na 1 ms rzeczywisty (licznik A_GRA+0xD0 w obu grach) – Symulacja.MNOZNIK_PREDKOSCI; 1,706 z etapu 12 było
##    artefaktem metody (maksimum próbek), nie mechaniką;
##  * kolizje (docs/KOLIZJE_JEDNOSTEK_EE.md): jednostki idące przenikają się (brak unikania lokalnego), jednostka
##    w ruchu omija pole jednostki stojącej – zgodnie z pomiarami obu gier.

var t


func _init(runner) -> void:
	t = runner


class _Archiwum:
	extends RefCounted
	var wpisy := {}
	var dane := {}

	func czytaj(k: String) -> PackedByteArray:
		return dane.get(k, PackedByteArray())


func _lista(nazwy: Array) -> PackedByteArray:
	var b := PackedByteArray()
	for n in nazwy:
		var s: PackedByteArray = String(n).to_ascii_buffer()
		var p := b.size()
		b.resize(p + 4)
		b.encode_u32(p, s.size() + 1)
		b.append_array(s)
		b.append(0)
	return b


func _syntetyczne() -> void:
	var en := _Archiwum.new()
	var nazwy_en := ["Soldiers for Rome.scn", "Restoring the Republic.scn", "The Gallic Wars.scn"]
	en.wpisy["campaigns/een1ve1s_scenariolist.txt"] = []
	en.dane["campaigns/een1ve1s_scenariolist.txt"] = _lista(nazwy_en)
	for n in nazwy_en:
		en.wpisy["scenarios/een1ve1s_" + String(n).to_lower()] = []
	var pl := _Archiwum.new()
	var nazwy_pl := ["Zolnierze dla Rzymu.scn", "Przywrocenie Republiki.scn", "Wojny Galijskie.scn"]
	pl.wpisy["campaigns/een1ve1s_scenariolist.txt"] = []
	pl.dane["campaigns/een1ve1s_scenariolist.txt"] = _lista(nazwy_pl)
	for n in nazwy_pl:
		pl.wpisy["scenarios/een1ve1s_" + String(n).to_lower()] = []
	var le := GryEE.scenariusze_kampanii(en)
	var lp := GryEE.scenariusze_kampanii(pl)
	t._ok("E13 scenariusz: lista kampanii EN – 3 pozycje z kluczami wpisów", le.size() == 3 and le.all(func(x): return x.klucz != ""), le)
	t._ok("E13 scenariusz: lista kampanii PL – te same numery, inne klucze (tytuł tłumaczony)",
		lp.size() == 3 and lp[0].nr == le[0].nr and lp[0].klucz != le[0].klucz and lp[2].klucz == "scenarios/een1ve1s_wojny galijskie.scn", lp)
	var bez := _Archiwum.new()
	t._ok("E13 scenariusz: archiwum bez listy kampanii → pusta lista (bez wyjątku)", GryEE.scenariusze_kampanii(bez).is_empty())


func _definicje(K: Node) -> void:
	for gra in ["ee", "aoc"]:
		var kt: Dictionary = GryEE.definicja(gra, K.katalog_openee).get("kampania_testowa", {})
		var kat: Array = GryEE.katalogi_kampanii(gra, K.katalog_openee)
		t._ok("E13 scenariusz: %s – kampania testowa (plik + numer) w definicji gry" % gra.to_upper(),
			String(kt.get("plik", "")).ends_with(".ssa") and int(kt.get("nr", 0)) >= 1 and not kat.is_empty(), kt)


func _instalacje(K: Node) -> void:
	var inst := []
	for n in ["spolecznosciowa", "referencyjna"]:
		if K.instalacje.has(n) and GryEE.dostepna("ee", K.instalacje[n], K.katalog_openee):
			inst.append(n)
	if inst.size() < 2:
		t._pomin(["E13 scenariusz: kampania testowa EE – ten sam scenariusz w obu językach instalacji",
			"E13 scenariusz: kampania testowa AoC – ten sam scenariusz w obu językach instalacji"],
			"wymaga instalacji polskiej (społecznościowej) i angielskiej (referencyjnej)")
		return
	for gra in ["ee", "aoc"]:
		var kt: Dictionary = GryEE.definicja(gra, K.katalog_openee).get("kampania_testowa", {})
		var wyn := []
		for n in inst:
			var ak := GryEE.archiwum_kampanii(gra, String(kt.plik), K.instalacje[n], K.katalog_openee)
			var a := ArchiwumSSA.new()
			if ak.has("blad") or a.otworz(String(K.instalacje[n]).path_join(ak.rel)) != OK:
				wyn.append({"inst": n, "blad": ak.get("blad", "archiwum")})
				continue
			var lista := GryEE.scenariusze_kampanii(a)
			var nr := int(kt.nr)
			if nr > lista.size() or lista[nr - 1].klucz == "":
				wyn.append({"inst": n, "blad": "brak pozycji %d" % nr})
				continue
			var s := ScenariuszEE.new()
			var ok: bool = s.wczytaj(a.czytaj(lista[nr - 1].klucz)) and s.czytaj_teren()
			wyn.append({"inst": n, "tytul": lista[nr - 1].nazwa, "mapa": [s.teren.A, s.teren.B] if ok else null,
				"pozycji": lista.size()})
		var zgodne: bool = wyn.size() == 2 and not wyn[0].has("blad") and not wyn[1].has("blad") \
			and wyn[0].mapa == wyn[1].mapa and wyn[0].pozycji == wyn[1].pozycji and wyn[0].tytul != wyn[1].tytul
		t._ok("E13 scenariusz: kampania testowa %s – ten sam scenariusz w obu językach instalacji" % gra.to_upper(), zgodne, wyn)


func _mapa_plaska(w: int, h: int) -> MapaNawigacji:
	var kat := PackedByteArray(); kat.resize(w * h); kat.fill(MapaNawigacji.LAD)
	return MapaNawigacji.z_tablic(h, w, kat, PackedFloat32Array(), 1)


func _jedn(sym: Symulacja, p: Vector2) -> int:
	var d := JednostkaSym.DaneJednostki.new()
	d.typ = 32; d.pozycja = p; d.kurs = 0.0
	return sym.dodaj_jednostke(d, {"Name": "Citizen", "Speed": 0.5, "Idle turning speed": 12.2, "Moving turning speed": 14.0,
		"Circle selection size": 0.3, "Size in formation": 0.625})


func _do_konca(sym: Symulacja, ids: Array, slad: Dictionary = {}) -> void:
	for n in 2000:
		sym.krok()
		var ruch := false
		for id in ids:
			var j: JednostkaSym = sym.jednostki[id]
			if slad.has(id): (slad[id] as Array).append(j.pozycja)
			ruch = ruch or j.w_ruchu()
		if not ruch and n > 2: return


static func _odl_min(a: Array, b) -> float:
	var m := INF
	for k in a.size():
		var q: Vector2 = b[k] if b is Array else b
		m = minf(m, (a[k] as Vector2).distance_to(q))
	return m


func _kolizje() -> void:
	# 1. jednostka w ruchu i jednostka stojąca na jej trasie (zadania 329/331: EE i AoC – objazd, d_min 0,66)
	var sym := Symulacja.new(_mapa_plaska(14, 8))
	var a := _jedn(sym, Vector2(1.5, 3.5))
	var b := _jedn(sym, Vector2(6.5, 3.5))
	sym.rozkaz_ruchu(a, Vector2(11.5, 3.5))
	var sl := {a: []}
	_do_konca(sym, [a], sl)
	var ja: JednostkaSym = sym.jednostki[a]
	var dmin := _odl_min(sl[a], Vector2(6.5, 3.5))
	t._ok("E13 kolizje: jednostka w ruchu omija pole jednostki stojącej (trasa obchodzi pole, cel osiągnięty)",
		Symulacja.OMIJANIE_STOJACYCH and dmin >= 0.5 and ja.pozycja.distance_to(Vector2(11.5, 3.5)) < 0.06
		and (sym.jednostki[b] as JednostkaSym).pozycja == Vector2(6.5, 3.5), [dmin, ja.pozycja])
	# 2. dwie jednostki naprzeciw w tym samym takcie – przenikanie, prosto, bez zatrzymań (zad. 268/280: d_min 0,03–0,05)
	var s2 := Symulacja.new(_mapa_plaska(14, 8))
	var p := _jedn(s2, Vector2(1.5, 3.5)); var q := _jedn(s2, Vector2(11.5, 3.5))
	s2.rozkaz_ruchu(p, Vector2(11.5, 3.5)); s2.rozkaz_ruchu(q, Vector2(1.5, 3.5))
	var sl2 := {p: [], q: []}
	_do_konca(s2, [p, q], sl2)
	var odch := 0.0
	for v in sl2[p] + sl2[q]: odch = maxf(odch, absf((v as Vector2).y - 3.5))
	t._ok("E13 kolizje: jednostki idące naprzeciw przenikają się (bez objazdu i zatrzymania)",
		_odl_min(sl2[p], sl2[q]) < 0.1 and odch < 1e-3 and sl2[p].size() < int(10.0 / (0.5 * Symulacja.MNOZNIK_PREDKOSCI) / Symulacja.KROK) + 20,
		[_odl_min(sl2[p], sl2[q]), odch, sl2[p].size()])
	# 3. grupa: współtowarzysze z tym samym rozkazem nie są przeszkodą (start w jednym takcie, zad. 270/282)
	var s3 := Symulacja.new(_mapa_plaska(16, 10))
	var g := [_jedn(s3, Vector2(2.5, 4.5)), _jedn(s3, Vector2(3.5, 4.5)), _jedn(s3, Vector2(4.5, 4.5))]
	s3.rozkaz_grupy(g, Vector2(12.5, 4.5))
	s3.krok()
	var bez_objazdu := true
	for id in g:
		var j: JednostkaSym = s3.jednostki[id]
		bez_objazdu = bez_objazdu and j.sciezka.size() <= 2
	t._ok("E13 kolizje: rozkaz grupy – jednostki tej samej grupy nie blokują sobie tras", bez_objazdu,
		g.map(func(i): return (s3.jednostki[i] as JednostkaSym).sciezka))
	# 4. stojące jednostki zamykają jedyne przejście – trasa bez nich zamiast odrzucenia rozkazu [H]
	var kat := PackedByteArray(); kat.resize(9 * 5); kat.fill(MapaNawigacji.LAD)
	for r in 5:
		if r != 2: kat[r * 9 + 4] = MapaNawigacji.KLIF
	var s4 := Symulacja.new(MapaNawigacji.z_tablic(5, 9, kat, PackedFloat32Array(), 1))
	var u := _jedn(s4, Vector2(1.5, 2.5)); _jedn(s4, Vector2(4.5, 2.5))
	s4.rozkaz_ruchu(u, Vector2(7.5, 2.5))
	_do_konca(s4, [u])
	t._ok("E13 kolizje: przejście zamknięte stojącą jednostką – rozkaz wykonany (przenikanie) [H]",
		(s4.jednostki[u] as JednostkaSym).pozycja.distance_to(Vector2(7.5, 2.5)) < 0.06, (s4.jednostki[u] as JednostkaSym).pozycja)


func _predkosc(K: Node) -> void:
	var f := FileAccess.open(String(K.katalog_openee).path_join("dane/mechaniki_ee_aoc.json"), FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
	var m: Dictionary = d.get("mechaniki", {})
	var z: Dictionary = m.get("zegar_gry_na_sekunde", {})
	t._ok("E13 prędkość: MNOZNIK_PREDKOSCI = tempo zegara gry (ms gry / ms rzeczywisty) zmierzone w EE i AoC",
		z.get("zakres") == "obie" and absf(float(z.get("ee", 0)) - float(z.get("aoc", 0))) < 0.002
		and absf(Symulacja.MNOZNIK_PREDKOSCI - float(z.get("ee", 0))) < 0.005, z)
	var mn: Dictionary = m.get("mnoznik_predkosci_scenariusz", {})
	t._ok("E13 prędkość: brak mnożnika zależnego od scenariusza (1,706 wycofane jako artefakt próbkowania)",
		mn.is_empty() or mn.get("ee") == null, mn)
	var pr: Dictionary = m.get("modyfikator_predkosci_blitzkrieg", {})
	t._ok("E13 prędkość: dodatek +0,15 pola/s gry (scenariusz z „Blitzkriegu”) udokumentowany jako [N] przyczyny, bez implementacji",
		is_equal_approx(float(pr.get("ee", 0)), 0.15) and pr.get("openee") == null, pr)


func uruchom(K: Node) -> void:
	_kolizje()
	_predkosc(K)
	_syntetyczne()
	_definicje(K)
	_instalacje(K)
