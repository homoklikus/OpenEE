extends SceneTree
## Testy integracji GDExtension OpenEE Core (etap 28), osobno od głównego zestawu (uruchom_testy.gd, 324 testy):
##   godot --headless --path godot --script res://testy/testy_gdextension.gd
## Przepływ: GDScript → GDExtension → OpenEE Core C++ → GDExtension → GDScript. Bez obliczeń ruchu w GDScript.
## Wynik: PASS / FAIL / SKIP osobno (SKIP ≠ PASS). Kod wyjścia: 0 – brak błędów, 1 – błędy.

var zal := 0
var niezal := 0
var pomin := 0


func _wynik(nazwa: String, ok: bool, szczegoly: String = "") -> void:
	if ok:
		zal += 1
	else:
		niezal += 1
	print(("PASS  " if ok else "FAIL  ") + nazwa + ("" if szczegoly == "" else "  – " + szczegoly))


func _skip(nazwa: String, powod: String) -> void:
	pomin += 1
	print("SKIP  " + nazwa + "  – " + powod)


func _f32(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, v)
	return b


func _initialize() -> void:
	# autoloady (Konfiguracja – ścieżki instalacji) są gotowe dopiero w pierwszej klatce
	process_frame.connect(_testy, CONNECT_ONE_SHOT)


func _testy() -> void:
	var katalog := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	_wynik("klasa OpenEESymulacja zarejestrowana (biblioteka załadowana przez Godot)", CoreCpp.dostepny(),
		"" if CoreCpp.dostepny() else "zbuduj cpp/ (docs/cpp/BUDOWANIE.md) i uruchom godot --import")
	if not CoreCpp.dostepny():
		_koniec()
		return
	var sym: Object = CoreCpp.nowa_symulacja()
	print("      ", sym.wersja())
	# brak DLL: czytelny błąd, świat się nie tworzy
	var r: Dictionary = sym.zaladuj_tablice("/nieistniejacy/Low-Level Engine.dll")
	_wynik("brak DLL – błąd zamiast tablic", not r["ok"] and str(r["komunikat"]).contains("Nie znaleziono"), r["komunikat"])
	_wynik("bez tablic nie można utworzyć świata", not sym.utworz_swiat("ee"))
	# tryb przybliżony: działa, ale jest oznaczony jako niezgodny
	sym.uzyj_tablic_przyblizonych()
	_wynik("tryb przybliżony oznaczony jako niezgodny", sym.utworz_swiat("ee") and not sym.diagnostyka()["tablice_zgodne"])
	_test_mapy(sym)
	var przypadki := CoreCpp.wczytaj_przypadki(katalog)
	_wynik("przypadki syntetyczne wczytane", przypadki.size() == 9, str(przypadki.size()))
	var dll := CoreCpp.znajdz_dll("ee", root.get_node_or_null("Konfiguracja"))
	if dll == "":
		_skip("tablice z oryginalnej DLL i przypadki S1–S7 przez GDExtension", "nie znaleziono Low-Level Engine.dll (--dll=… albo OPENEE_INSTALACJA)")
		_koniec()
		return
	r = sym.zaladuj_tablice(dll)
	_wynik("wczytanie tablic z DLL użytkownika", r["ok"], "%s – %s" % [r["wariant"] if r["ok"] else r["komunikat"], dll])
	if not r["ok"]:
		_koniec()
		return
	var pola: PackedStringArray = sym.pola_migawki()
	for p in przypadki:
		var id := CoreCpp.uruchom_przypadek(sym, p)
		var ocz: Array = p["oczekiwane"]
		var po_taktach := {}
		for o in ocz:
			po_taktach[int(o["takt"])] = o
		var rozbiezny := -1
		var opis := ""
		var koniec := -1
		for t in range(1, int(p["koniec_takt"]) + 5):
			sym.takt(1)
			var m: PackedFloat64Array = sym.migawka()
			var w := {}
			for i in pola.size():
				w[pola[i]] = m[i]
			if po_taktach.has(t) and rozbiezny < 0:
				var o: Dictionary = po_taktach[t]
				for k in [["x", "x"], ["y", "y"], ["v", "v"], ["omega", "omega"], ["kurs", "kurs"]]:
					if _f32(w[k[0]]) != _f32(o[k[1]]):
						rozbiezny = t
						opis = "%s: oczekiwano %.9f, jest %.9f" % [k[0], o[k[1]], w[k[0]]]
						break
				if rozbiezny < 0 and (int(w["stan"]) != int(o["stan"]) or int(w["zdjete_punkty"]) != int(o["punkt"])):
					rozbiezny = t
					opis = "stan/punkt"
			if int(w["stan"]) == 5001:
				koniec = t
				break
		_wynik("%s przez GDExtension (bitowo f32, koniec %d)" % [p["nazwa"], koniec],
			rozbiezny < 0 and koniec == int(p["koniec_takt"]),
			"" if rozbiezny < 0 else "pierwszy rozbieżny takt %d: %s" % [rozbiezny, opis])
	# wsadowe takty: jedno wywołanie na wiele taktów = te same wyniki
	CoreCpp.uruchom_przypadek(sym, przypadki[4])
	sym.takt(100)
	var a: PackedFloat64Array = sym.migawka()
	CoreCpp.uruchom_przypadek(sym, przypadki[4])
	for i in 100:
		sym.takt(1)
	_wynik("takt(100) == 100 × takt(1)", a == sym.migawka())
	# etap 29: rozkaz z A* w Core, przeszkoda, kolejka Shift, dwie jednostki
	sym.utworz_swiat("ee")
	for y in range(6, 15):
		sym.ustaw_przejezdnosc(14, y, false)
	var par: Dictionary = przypadki[0]["parametry"]
	var ja_id: int = sym.dodaj_jednostke(par, 10.5, 10.5, 0.0)
	var jb_id: int = sym.dodaj_jednostke(par, 20.5, 10.5, 0.0)
	sym.rozkaz_ruchu(ja_id, 17.5, 10.5, null, false)
	sym.rozkaz_ruchu(ja_id, 17.5, 13.5, null, true)
	sym.rozkaz_ruchu(jb_id, 20.5, 13.5, null, false)
	var weszla := false
	for i in 1500:
		sym.takt(1)
		var j: Dictionary = sym.jednostka(ja_id)
		if int(floor(j["x"])) == 14 and int(floor(j["y"])) >= 6 and int(floor(j["y"])) <= 14:
			weszla = true
	var ja: Dictionary = sym.jednostka(ja_id)
	var jb: Dictionary = sym.jednostka(jb_id)
	_wynik("rozkaz + A* w Core: objazd ściany i drugi cel z Shift", not weszla and ja["stan"] == 5000 and absf(ja["x"] - 17.5) < 0.06 and absf(ja["y"] - 13.5) < 0.06,
		"A (%.3f, %.3f) stan %d, B (%.3f, %.3f) stan %d, A* iteracji %d" % [ja["x"], ja["y"], ja["stan"], jb["x"], jb["y"], jb["stan"], sym.diagnostyka()["astar_iteracje"]])
	var d: Dictionary = sym.diagnostyka()
	_wynik("diagnostyka: tablice zgodne, RNG liczy losowania", d["tablice_zgodne"] and int(d["rng_losowania"]) > 0,
		"rng %d, losowań %d, nieobsługiwanych zdarzeń %d" % [d["rng_stan"], d["rng_losowania"], d["zdarzenia_nieobslugiwane"]])
	_test_walki(sym)
	_test_potyczki(dll)
	_test_etapu37(dll)
	_test_etapu38(dll)
	_test_etapu39(dll)
	_test_etapu40(dll)
	_test_etapu41(dll)
	_test_etapu42(dll)
	_test_etapu43(dll)
	_test_etapu44(dll)
	_test_etapu45(dll)
	_test_etapu46(dll)
	_test_etapu47(dll)
	_test_etapu48(dll)
	_test_etapu49(dll)
	_test_etapu50(dll)
	_test_etapu51(dll)
	_test_etapu52(dll)
	_test_etapu53(dll)
	_koniec()


# etap 30: mapa SCN → Core (MapaTitan). Interpretacja wyłącznie w Core; GDScript przekazuje surowe tablice.
func _test_mapy(sym: Object) -> void:
	var A := 3
	var B := 3
	var T := 2 * A * B + A + B
	var V := 2 * A * B + 3 * A + 3 * B + 1
	var tex := PackedByteArray(); tex.resize(T); tex.fill(3)
	var fl := PackedByteArray(); fl.resize(T)
	var f10 := PackedFloat32Array(); f10.resize(T)
	var wys := PackedFloat32Array(); wys.resize(V)
	tex[5] = 26; fl[5] = 1; f10[5] = -0.6      # pole nr 5 w kolejności rombu: woda głęboka
	var info: Dictionary = sym.wczytaj_mape_scn(A, B, tex, fl, f10, wys, {3: 0, 26: 0})
	_wynik("mapa SCN → Core: romb i linie brzegu", info["ok"] and info["szerokosc"] == 6 and info["brzeg_s1"] == 2 and info["brzeg_s2"] == 8 and info["brzeg_d"] == 3, str(info))
	# pole nr 5: wiersze 0: (2..3), 1: (1..4) → indeksy 0–1, 2–5 → pole 5 = (4, 1)
	_wynik("mapa SCN → Core: teren komórek (reguła Titan w Core)", sym.mapa_teren(4, 1) == 1 and sym.mapa_teren(2, 1) == 0 and sym.mapa_teren(0, 0) == -1,
		"(4,1)=%d (2,1)=%d (0,0)=%d" % [sym.mapa_teren(4, 1), sym.mapa_teren(2, 1), sym.mapa_teren(0, 0)])
	sym.dodaj_obiekt_mapy({"id": 0x1000001, "typ": 34, "gracz": 1, "X": 2, "Y": 2, "kwadrat": 2, "blokuje": true})
	var dozw := PackedByteArray([1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0])
	var ok: bool = sym.utworz_swiat_na_mapie("ee", dozw)
	_wynik("świat Core na mapie: woda, obiekt 2×2 i brzeg nieprzejezdne", ok and not sym.pole_przejezdne(4, 1) and not sym.pole_przejezdne(3, 3) and not sym.pole_przejezdne(2, 0) and sym.pole_przejezdne(3, 1),
		"(4,1) %s (3,3) %s (2,0) %s (3,1) %s" % [sym.pole_przejezdne(4, 1), sym.pole_przejezdne(3, 3), sym.pole_przejezdne(2, 0), sym.pole_przejezdne(3, 1)])
	var scn := OS.get_environment("OPENEE_SCN_TEST")
	if scn == "":
		_skip("mapa prawdziwego scenariusza przez importer GDScript → Core", "OPENEE_SCN_TEST nie ustawione (plik gry – lokalnie)")
		return
	var s := ScenariuszEE.new()
	var bajty := FileAccess.get_file_as_bytes(scn)
	if not s.wczytaj(bajty) or not s.czytaj_teren():
		_wynik("mapa prawdziwego scenariusza: odczyt SCN", false, s.blad)
		return
	var rodz := {}
	var rj = JSON.parse_string(OS.get_environment("OPENEE_RODZINY_TEST")) if OS.get_environment("OPENEE_RODZINY_TEST") != "" else {}
	for k in rj:
		rodz[int(k)] = int(rj[k])
	var t: Dictionary = s.teren
	var i2: Dictionary = sym.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
	var oczek := OS.get_environment("OPENEE_SKROT_MAPY_TEST")
	_wynik("mapa prawdziwego scenariusza: GDScript → Core = ten sam skrót co ścieżka CTest", i2["ok"] and (oczek == "" or i2["skrot"] == oczek),
		"%s, skrót %s, oczekiwany %s" % [str(i2.get("szerokosc", -1)), i2.get("skrot", "?"), oczek])


func _test_walki(sym: Object) -> void:
	# etap 31: walka liczona w Core; Godot tylko podaje dane (gwardia EE, tablice gwardii z odczytu 566) i czyta migawki
	sym.utworz_swiat("ee")
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5}
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		tr[["08", "0C", "10"][i]] = {13: f}
	var mn := []
	for i in 16:
		mn.append([1, 1, 1, 1, 1, 1])
	var ok: bool = sym.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
		[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var a: int = sym.dodaj_jednostke(p, 10.5, 10.5, 0.0)
	var b: int = sym.dodaj_jednostke(p, 13.5, 11.0, 0.0)
	ok = ok and sym.ustaw_walke(a, 1, true, g, 215) and sym.ustaw_walke(b, 5, false, g, 215)
	sym.takt(1400)
	var wybory := 0
	var smierci := 0
	for e in sym.zdarzenia_walki():
		wybory += 1 if e["rodzaj"] == "wybor_celu" else 0
		smierci += 1 if e["rodzaj"] == "smierc" else 0
	var wa: Dictionary = sym.walka(a)
	var wb: Dictionary = sym.walka(b)
	_wynik("walka w Core przez GDExtension: wybór celu, podejście, ataki, śmierć (jak core_walka_swiat)", ok and wybory == 2 and smierci == 1 and wb["hp"] == 0 and wa["hp"] == 103,
		"wybory %d, śmierci %d, HP %d / %d" % [wybory, smierci, wa.get("hp", -1), wb.get("hp", -1)])


# etap 36: warstwa potyczki (SymulacjaCore) – model widoku nad Core, bez własnej symulacji. Te same rozkazy w tych samych
# taktach → ten sam przebieg (skrót stanu, kolejność zdarzeń); rozkaz ruchu przerywa atak; zwłoki niewybieralne.
func _potyczka_core(dll: String) -> SymulacjaCore:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		tr[["08", "0C", "10"][i]] = {13: f}
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
		[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
	c.ustaw_wrogow(1, 5, true); c.ustaw_wrogow(5, 1, true)
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5}
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var s := SymulacjaCore.new(c, null)
	for gr in [1, 5]:
		for i in 3:
			var id: int = c.dodaj_jednostke(p, 10.5 + 2 * i, 16.5 if gr == 1 else 10.5, PI if gr == 1 else 0.0)
			c.ustaw_walke(id, gr, gr == 1, g, 215)
			s.zarejestruj(id, gr, 422, 0.3)
	return s


func _przebieg_potyczki(dll: String) -> Dictionary:
	var s := _potyczka_core(dll)
	var wlasne: Array = []; var wrogie: Array = []
	for id in s.jednostki: (wlasne if s.gracz_jednostki[id] == 1 else wrogie).append(id)
	var zd := PackedStringArray()
	var wynik := ""
	var przyjete := 0
	for t in 5000:
		if t == 1: s.rozkaz_grupy(wlasne, Vector2(12.5, 13.5))
		if t == 60: przyjete = s.rozkaz_ataku_grupy(wlasne, wrogie[0])
		s.krok()
		for e in s.zdarzenia:
			if e.typ == "walka": zd.append("%d:%s:%d:%d:%d" % [e.takt, e.rodzaj, e.kto, e.cel, e.wartosc])
		if s.liczba_zywych(5) == 0: wynik = "wygrana"
		elif s.liczba_zywych(1) == 0: wynik = "przegrana"
		if wynik != "": break
	return {"wynik": wynik, "takt": s.takt, "skrot": s.skrot_stanu(), "zd": zd, "przyjete": przyjete, "sym": s, "wrogie": wrogie, "wlasne": wlasne}


func _test_potyczki(dll: String) -> void:
	var a := _przebieg_potyczki(dll)
	var b := _przebieg_potyczki(dll)
	var smierci := 0
	var porzadek := true
	var ostatnie_trafienie := {}
	for z in a.zd:
		var c: PackedStringArray = String(z).split(":")
		if c[1] == "smierc":
			smierci += 1
			if int(ostatnie_trafienie.get(c[2], 1 << 30)) > int(c[0]): porzadek = false   # śmierć nie przed trafieniem
		if c[1] == "trafienie": ostatnie_trafienie[c[3]] = int(c[0])
	_wynik("potyczka przez SymulacjaCore: rozkazy gracza → Core, walka do rozstrzygnięcia", a.wynik != "" and a.przyjete == 3 and smierci >= 3 and porzadek,
		"wynik %s w takcie %d, przyjęte rozkazy ataku %d, śmierci %d, zdarzeń %d" % [a.wynik, a.takt, a.przyjete, smierci, a.zd.size()])
	_wynik("potyczka deterministyczna: dwa przebiegi – ten sam skrót stanu i ta sama kolejność zdarzeń", a.skrot == b.skrot and a.zd == b.zd and a.takt == b.takt,
		"%s / %s, takt %d / %d" % [a.skrot, b.skrot, a.takt, b.takt])
	var s: SymulacjaCore = a.sym
	var martwe := s.jednostki.keys().filter(func(i): return not s.zywa(i))
	var lista_bez_martwych := true
	for j in s.lista(): lista_bez_martwych = lista_bez_martwych and s.zywa(j.id)
	_wynik("zwłoki: poza listą wyboru, nie są celem PPM, rozkazy do nich odrzucane", not martwe.is_empty() and lista_bez_martwych
		and not s.czy_wrog(1, martwe[0]) and s.rozkaz_ataku_grupy(s.jednostki.keys(), martwe[0]) == 0,
		"martwych %d" % martwe.size())
	# rozkaz ruchu przerywa atak (zwykły PPM: kolejka celów czyszczona – Swiat::rozkaz_ruchu, 0x5EAE25)
	var s2 := _potyczka_core(dll)
	var w2: Array = []; var e2: Array = []
	for id in s2.jednostki: (w2 if s2.gracz_jednostki[id] == 1 else e2).append(id)
	s2.rozkaz_ataku_grupy([w2[0]], e2[0])
	var sekw: Array = []
	for i in 5:
		s2.krok(); sekw.append(s2.stan[w2[0]])
	# etap 36 [P: 619/620]: rozkaz ataku → 2016 InitialAttackState, w tym samym takcie 2012; dalej 2013, 2024, 8000, 2015
	_wynik("rozkaz ataku gracza: sekwencja stanów jak w grze (619/620): 2012, 2013, 2024, 8000, 2015", sekw == [2012, 2013, 2024, 8000, 2015], str(sekw))
	var mial_cel: int = s2.cel_walki[w2[0]]
	s2.rozkaz_grupy([w2[0]], Vector2(10.5, 18.5)); s2.krok()
	var obcy := s2.rozkaz_ataku_grupy([e2[1]], w2[0])   # jednostki wroga nie przyjmują rozkazów gracza lokalnego
	_wynik("rozkaz ruchu przerywa atak; rozkazy tylko dla jednostek gracza lokalnego", mial_cel == e2[0] and s2.cel_walki[w2[0]] == 0 and obcy == 0,
		"cel przed %d, po %d, rozkaz dla wroga przyjęty %d" % [mial_cel, s2.cel_walki[w2[0]], obcy])


# etap 37: kąt szyku PPM (0x64138B) i mapa celów nieosiągalnych (0x5E8651 / 0x5EC9BB – 30 s, te same pola)
func _test_etapu37(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var g: int = c.dodaj_jednostke(p, 10.5, 16.5, 0.0)
	# 616 [P]: jednostka stoi w (164,5; 118,5), PPM w (159,2415; 106,4529) → kąt celu 2,7300477 (kolejka MCP „kat”);
	# te same różnice współrzędnych w świecie syntetycznym
	var k: float = c.kat_rozkazu([g], 10.5 - 5.2585, 16.5 - 12.0471)
	_wynik("kąt szyku PPM (0x64138B): pomiar 616 – 2,7300477", absf(k - 2.7300477027893066) < 2e-6, "%.7f" % k)
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		tr[["08", "0C", "10"][i]] = {13: f}
	var f36 := PackedFloat32Array(); f36.resize(64); f36[48] = 2.8
	tr["10"][36] = f36
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
		[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
	c.ustaw_wrogow(1, 5, true); c.ustaw_wrogow(5, 1, true)
	var gw := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5}
	var ob := {"atak": 5.0, "zasieg_max": 2.0, "pole_widzenia": 3.0, "przeladowanie_ms": 2000, "klasa_trafienia": 36,
		"rodzina_ataku": 38, "rozmiar": 0.3, "punktowy": 0, "szukanie_ms": 2000, "pole_ac": 0.5, "typ_jednostki": 6}
	c.ustaw_walke(g, 1, true, gw, 215)
	var pc := p.duplicate(); pc.rozmiar = 0.3
	var o: int = c.dodaj_jednostke(pc, 10.5, 12.5, 0.0)
	c.ustaw_walke(o, 5, false, ob, 65)
	c.ustaw_przejezdnosc(10, 12, false)          # obywatel na polu nieprzejezdnym (jak drzewa w e35_a)
	c.rozkaz_ataku(g, o)
	var poprz := 0; var ost8000 := -1; var porzucenia: Array = []; var wybory: Array = []
	for t in 5200:
		c.takt(1)
		var st := 0
		for d in c.stan_jednostek():
			if int(d.id) == g: st = int(d.stan)
		var ms := t * 1500.0 / 44.0
		if st == 8000: ost8000 = int(ms)
		if st == 5000 and poprz == 2025: porzucenia.append([int(ms), ost8000])
		if poprz == 5000 and st == 2013: wybory.append(int(ms))
		poprz = st
	var ok := porzucenia.size() >= 2 and wybory.size() >= 1
	var odstep: int = (int(wybory[0]) - int(porzucenia[0][1])) if ok else -1
	_wynik("cel nieosiągalny: porzucenie, ponowny wybór AI dopiero po 30 s od ostatniego PrepareToMove (0x62CD76)",
		ok and odstep >= 30000 and odstep < 30000 + 2400, "porzucenia %s, wybory %s, odstęp %d ms" % [str(porzucenia.slice(0, 3)), str(wybory.slice(0, 3)), odstep])


func _koniec() -> void:
	print("WYNIK GDExtension: %d zaliczonych, %d niezaliczonych, %d pominiętych" % [zal, niezal, pomin])
	quit(1 if niezal > 0 else 0)


# etap 38: regeneracja HP 0x625B47 (bohater 173 – +2 HP co 30 taktów [P: kod + 619]) oraz obrót trybu 1 do celu
# EEUGLocation (rozkaz ruchu w trakcie ataku [P: 622, takt 86682]).
func _test_etapu38(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var p := {"a": 2.0, "vmax": 0.8, "alfa": 6.98132, "wmax": 6.98132, "rozmiar": 0.55, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var b: int = c.dodaj_jednostke(p, 10.5, 10.5, 0.0)
	c.ustaw_walke(b, 5, false, {"regeneracja": 2, "regeneracja_ms": 898, "hp_max": 1235, "ai_szuka_wrogow": 0}, 1221)
	c.ustaw_modyfikator_wysokosci(true)
	var hp: Array = []
	for t in 61:
		c.takt(1)
		for d in c.stan_jednostek():
			if int(d.id) == b and (hp.is_empty() or int(d.hp) != int(hp[-1][1])): hp.append([t + 1, int(d.hp)])
	# 898 − 34·k ≤ 0 przy k = 27 (takt 27: −20) → +2; potem co 30 taktów (1000 − 29·34 = 14 > 0, takt 30: −20)
	_wynik("regeneracja HP (0x625B47): +2 w takcie 27 i 57, odliczanie +0x290 co 34 ms", hp == [[1, 1221], [27, 1223], [57, 1225]], str(hp))
	c.ustaw_walke(b, 5, false, {"regeneracja": 2, "hp_max": 1235}, 1235)
	c.takt(1)
	var pelne := 0
	for d in c.stan_jednostek():
		if int(d.id) == b: pelne = int(d.hp)
	_wynik("regeneracja nie przekracza HP max (min z +0x144)", pelne == 1235, str(pelne))
	var e: int = c.ustaw_efekty_obszaru({"szablony": [{"id": 1, "typ": 5, "ksztalt": 1, "relacja": 2, "rozmiar": 3.0, "maks_morale": 2, "zestaw": [422]}],
		"budynki": [{"typ": 37, "gracz": 5, "pole": [12, 12], "rozmiar": 1, "srodek": [12.5, 12.5], "efekty": [1]}]})
	c.odtworz_efekty_obszaru()
	_wynik("efekty obszarowe ze słownika (format narzędzia efekty_obszaru.py)", e == 1, str(e))


# etap 39: zajętość miejsca podejścia 0x63234D – druga gwardia omija miejsce zajęte przez pierwszą
# [W: kod; P: 619 – wybór (164,5; 105,025) zamiast (163,975; 105,025) przy gwardii w (163,918; 105,037)]
func _test_etapu39(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	c.ustaw_wrogow(1, 5, true); c.ustaw_wrogow(5, 1, true)
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var gw := {"atak": 15.0, "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000, "klasa_trafienia": 13,
		"rodzina_ataku": 48, "luk_ataku": 0.3490658700466156, "rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000,
		"pole_ac": 0.6000000238418579, "typ_jednostki": 5, "ai_szuka_wrogow": 0}
	var ph := p.duplicate(); ph.rozmiar = 0.55
	var h: int = c.dodaj_jednostke(ph, 14.5, 14.5, 0.0)
	c.ustaw_walke(h, 5, false, {"rozmiar": 0.55, "pole_ac": 0.8, "hp_max": 1235, "ai_szuka_wrogow": 0}, 1235)
	var a: int = c.dodaj_jednostke(p, 13.918, 15.037, 0.0)   # stoi na miejscu (13,975; 15,025)
	c.ustaw_walke(a, 1, true, gw, 215)
	var k: int = c.dodaj_jednostke(p, 12.5, 28.5, 0.0)
	c.ustaw_walke(k, 1, true, gw, 215)
	c.rozkaz_ataku(k, h)
	var punkt := Vector2.ZERO
	for t in 6:
		c.takt(1)
		for e in c.walka(k).get("kolejka", []):
			if str(e.rodzaj) == "EEUGAttackUnit": punkt = Vector2(float(e.x), float(e.y))
	_wynik("zajętość miejsca podejścia (0x63234D): zajęte (13,975; 15,025) pominięte → (14,5; 15,025)",
		absf(punkt.x - 14.5) < 1e-4 and absf(punkt.y - 15.025) < 1e-4, str(punkt))


# etap 40: graf podsektorów (A* 0x4A5807, wynik 0x4A26E3) i osiągalność 0x62D696. Graf syntetyczny o układzie z 619
# (start → podsektor pośredni → podsektor celu, cel nie jest sąsiadem startu) – test mechanizmu, nie zgodności z Titan.
func _test_etapu40(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	c.ustaw_wrogow(1, 5, true); c.ustaw_wrogow(5, 1, true)
	# trzy podsektory: 1 (y 20–29), 2 (y 10–19), 3 (y 0–9); 1 i 3 nie są sąsiadami
	var ps := []
	for i in 3:
		var pola := []
		for x in range(0, 30): pola.append([x, 20 - 10 * i, 29 - 10 * i])
		var sas: Array = [[2], [1, 3], [2]][i]
		ps.append({"id": i + 1, "sektor": [0, 2 - i, i], "rodzaj": 1, "punkt_i32": [7, 25 - 10 * i], "sasiedzi": sas, "pola": pola})
	_wynik("graf podsektorów ze słownika (tryb diagnostyczny)", c.ustaw_graf_podsektorow({"podsektory": ps}) == 3)
	_wynik("A* grafu 0x4A5807: ścieżka od celu do startu [3, 2, 1]", c.sciezka_grafu(10, 25, 10, 5) == [3, 2, 1], str(c.sciezka_grafu(10, 25, 10, 5)))
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var gw := {"atak": 15.0, "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000, "klasa_trafienia": 13,
		"rodzina_ataku": 48, "luk_ataku": 0.3490658700466156, "rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000,
		"pole_ac": 0.6000000238418579, "typ_jednostki": 5, "ai_szuka_wrogow": 0}
	var h: int = c.dodaj_jednostke(p, 10.5, 5.5, 0.0)
	c.ustaw_walke(h, 5, false, {"rozmiar": 0.55, "pole_ac": 0.8, "hp_max": 1235, "ai_szuka_wrogow": 0}, 1235)
	var k: int = c.dodaj_jednostke(p, 10.5, 25.5, 0.0)
	c.ustaw_walke(k, 1, true, gw, 215)
	c.rozkaz_ataku(k, h)
	var q := ""
	for t in 5:
		c.takt(1)
		if q == "":
			var kk := ""
			for e in c.walka(k).get("kolejka", []): kk += "%s(%.1f,%.1f);" % [str(e.rodzaj).substr(4, 3), float(e.x), float(e.y)]
			if kk.begins_with("Loc"): q = kk
	_wynik("0x4A26E3: punkt +0x32 podsektora celu przed EEUGAttackUnit (ścieżka 3 podsektorów)", q.begins_with("Loc(7.5,5.5);Att"), q)
	# 0x62D696: atakujący na polu nieprzejezdnym (otoczony) – A* Bounded bez wyniku bliskiego celowi → fałsz → porzucenie
	var c2: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c2.zaladuj_tablice(dll)["ok"]: c2.uzyj_tablic_przyblizonych()
	c2.utworz_swiat("ee")
	c2.ustaw_wrogow(1, 5, true); c2.ustaw_wrogow(5, 1, true)
	for dx in range(-1, 2):
		for dy in range(-1, 2): c2.ustaw_przejezdnosc(10 + dx, 25 + dy, false)
	var h2: int = c2.dodaj_jednostke(p, 10.5, 10.5, 0.0)
	c2.ustaw_walke(h2, 5, false, {"rozmiar": 0.55, "pole_ac": 0.8, "hp_max": 1235, "ai_szuka_wrogow": 0}, 1235)
	var k2: int = c2.dodaj_jednostke(p, 10.5, 25.5, 0.0)
	c2.ustaw_walke(k2, 1, true, gw, 215)
	c2.rozkaz_ataku(k2, h2)
	var stany := []
	for t in 40:
		c2.takt(1)
		var st: int = int(c2.jednostka(k2)["stan"])
		if stany.is_empty() or stany[-1] != st: stany.append(st)
	_wynik("0x62D696: atakujący otoczony przeszkodami – 9006 → 5001 → 5002 → 2025 → 5000 (cel porzucony)",
		stany.slice(stany.find(9006), stany.find(9006) + 5) == [9006, 5001, 5002, 2025, 5000] and c2.walka(k2).get("kolejka", []).is_empty(), str(stany))


# etap 41: graf z przydziału pól – punkty reprezentatywne (0x42C2D5) i sąsiedzi (0x4246E8) liczone w Core.
# Przydział syntetyczny: 1 = kolumny 0–4, 2 = kolumny 5–9 (wiersze 0–9), 3 = pole (10, 0) styczne po przekątnej z 2.
func _test_etapu41(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var W := 12
	var H := 12
	var a := PackedInt32Array(); a.resize(W * H)
	for x in 10:
		for y in 10: a[x * H + y] = 1 if x < 5 else 2
	a[10 * H + 10] = 3   # (10, 10) – styk po przekątnej z (9, 9)
	_wynik("graf z przydziału pól: 3 podsektory, źródło jawne", c.zbuduj_graf_z_przydzialu(a, W, H, 19) == 3 and str(c.diagnostyka()["graf_zrodlo"]) == "Core z przydziału pól", str(c.diagnostyka()["graf_zrodlo"]))
	_wynik("sąsiedzi 0x4246E8 (także po przekątnej) i ścieżka grafu", c.sciezka_grafu(1, 1, 10, 10) == [3, 2, 1], str(c.sciezka_grafu(1, 1, 10, 10)))


# etap 42: regiony 0x4240D3 i flood podsektorów 0x42AA10 z flagą przekątnej z rodzaju regionu (0x41EAE7).
func _wejscie_syntetyczne(rodzaj_obszaru: int) -> Dictionary:
	# 6 × 6, wszystkie pola lądu (rodzaj 1, wysokość 0) w obszarze 1; dwie części stykające się tylko narożnikiem:
	# pola (1,1) i (2,2) należą do obiektu blokującego (gdy rodzaj obszaru 1 → region trybu 0xC), reszta – zwykły ląd.
	var N := 6
	var rp := []; var h := []; var ob := []
	for i in N * N:
		rp.append(1); h.append(0); ob.append(1)
	var jed := {str(1 * N + 1): [["0x2000001", 100, 2, "0x831fd8", "0xT"]], str(2 * N + 2): [["0x2000001", 100, 2, "0x831fd8", "0xT"]]}
	return {"N": N, "rodzaj_pola": rp, "bajt14": h, "obszar": ob, "obszary_rodzaj_id": [null, [rodzaj_obszaru, 1]],
		"jednostki": jed, "typy": {"0xT": [0, 1, 0, 0]}, "brzeg": [-100, -100, -100]}


func _test_etapu42(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var w := _wejscie_syntetyczne(1)
	var r: Dictionary = c.zbuduj_graf_z_wejscia(w, 19)
	var reg: PackedInt32Array = r.get("regiony", PackedInt32Array())
	var prz: PackedInt32Array = r.get("przydzial", PackedInt32Array())
	# obiekt blokujący: region trybu 0xC (flaga 0) łączy (1,1)–(2,2) po przekątnej mimo obcych boków; ląd – jeden region
	var ok_reg: bool = reg.size() == 36 and reg[1 * 6 + 1] == reg[2 * 6 + 2] and reg[1 * 6 + 1] != reg[0] and r.get("regionow", 0) == 2
	_wynik("regiony 0x4240D3: obiekt blokujący = osobny region, przekątna bez warunku boku (tryb 0xC)", ok_reg, str(r.get("regionow")))
	_wynik("podsektory 0x42AA10: flaga przekątnej z rodzaju regionu (rodzaj 12 → jeden podsektor narożny)",
		prz.size() == 36 and prz[1 * 6 + 1] == prz[2 * 6 + 2] and r.get("podsektorow", 0) == 2 and str(c.diagnostyka()["graf_zrodlo"]) == "Core z wejścia mapy",
		"%s / %s" % [str(r.get("podsektorow")), str(c.diagnostyka()["graf_zrodlo"])])
	var plik := OS.get_environment("OPENEE_REGIONY_TEST")
	var ref_plik := OS.get_environment("OPENEE_PODSEKTORY_TEST")
	if plik == "" or ref_plik == "":
		_skip("regiony i podsektory e35_a z wejścia mapy (39 480 pól)", "OPENEE_REGIONY_TEST / OPENEE_PODSEKTORY_TEST nie ustawione (dane z gry – lokalnie)")
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(plik))
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ref_plik))
	var rr: Dictionary = c.zbuduj_graf_z_wejscia(d, 19)
	var N: int = d["N"]
	var p2: PackedInt32Array = rr["przydzial"]
	var r2: PackedInt32Array = rr["regiony"]
	var zg_reg := 0; var zg_pod := 0; var pol := 0
	for s in ref["podsektory"]:
		for run in s["pola"]:
			for y in range(int(run[1]), int(run[2]) + 1):
				var i: int = int(run[0]) * N + y
				pol += 1
				if r2[i] == int(s["w4c"][1]): zg_reg += 1
				if p2[i] == int(s["id"]): zg_pod += 1
	_wynik("e35_a z wejścia mapy: siatka regionów i przydział podsektorów = odczyt gry", pol > 0 and zg_reg == pol and zg_pod == pol,
		"pól %d, regiony %d, podsektory %d, podsektorów %d" % [pol, zg_reg, zg_pod, rr["podsektorow"]])
	# bez siatki obszarów z gry – obszary z rodzajów pól w Core (model z pomiaru)
	d.erase("obszar"); d.erase("obszary_rodzaj_id")
	var r3: Dictionary = c.zbuduj_graf_z_wejscia(d, 19)
	var p3: PackedInt32Array = r3["przydzial"]
	var zg3 := 0
	for s in ref["podsektory"]:
		for run in s["pola"]:
			for y in range(int(run[1]), int(run[2]) + 1):
				if p3[int(run[0]) * N + y] == int(s["id"]): zg3 += 1
	_wynik("e35_a: obszary z rodzajów pól (Core) → ten sam przydział podsektorów", not r3["obszary_z_gry"] and r3["obszarow"] == 43 and zg3 == pol,
		"obszarów %d, zgodnych pól %d/%d" % [r3["obszarow"], zg3, pol])


# etap 43: klasyfikacja pól z mapy SCN (Tile::SetKind 0x516E8C, bajt +0x14 wody 0x426577), z zapisu scenariusza,
# punkty reprezentatywne (iloraz w precyzji x87).
func _test_etapu43(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	var A := 3
	var B := 3
	var T := 2 * A * B + A + B
	var V := 2 * A * B + 3 * A + 3 * B + 1
	var tex := PackedByteArray(); tex.resize(T); tex.fill(3)
	var fl := PackedByteArray(); fl.resize(T)
	var f10 := PackedFloat32Array(); f10.resize(T)
	var wys := PackedFloat32Array(); wys.resize(V)
	f10[5] = -0.6                     # pole (4, 1): f10 < −0,75·0,408248 → woda głęboka (1)
	f10[6] = -0.1                     # pole (0, 2): płytko, narożniki ≥ 0 (4 z 4) → rodzina tekstury
	tex[7] = 16                       # pole (1, 2): rodzina 6; f10 < 0, narożniki ≥ 0 (4 z 4) → rodzina tekstury
	f10[7] = -0.1
	c.wczytaj_mape_scn(A, B, tex, fl, f10, wys, {3: 0, 16: 6})
	var m: Dictionary = c.wejscie_regionow_z_mapy()
	var N: int = m.get("N", 0)
	var rp: Array = m.get("rodzaj_pola", [])
	# etap 44: (0, 2) leży na brzegu rombu – 0x512FB0 przebieg 2 liczy pola spoza mapy jak klif (≥ 3 z 4) → 9
	_wynik("klasyfikacja pól 0x516E8C/0x512FB0: głęboka woda, płytka z narożnikami ≥ 0, brzeg rombu → klif",
		N == 6 and int(rp[4 * N + 1]) == 1 and int(rp[0 * N + 2]) == 9 and int(rp[1 * N + 2]) == 6 and int(rp[0]) == -1,
		"(4,1)=%s (0,2)=%s (1,2)=%s" % [str(rp[4 * N + 1]) if rp.size() > 0 else "?", str(rp[0 * N + 2]) if rp.size() > 0 else "?", str(rp[1 * N + 2]) if rp.size() > 0 else "?"])
	var hb: Array = m.get("bajt14", [])
	_wynik("bajt +0x14 wody (0x4282B8/0x426577): pole wody z lądem obok < 0", hb.size() == 36 and int(hb[4 * N + 1]) < 0, str(hb[4 * N + 1]) if hb.size() > 0 else "?")
	c.utworz_swiat("ee")
	var u: int = c.dodaj_jednostke({"a": 2.0, "vmax": 0.6, "alfa": 12.2, "wmax": 13.9, "rozmiar": 0.5}, 2.5, 2.5, 0.0)
	_wynik("wysokość z zapisu scenariusza (ustaw_z)", c.ustaw_z(u, 1.837) and not c.ustaw_z(9999, 0.0), "")
	var plik := OS.get_environment("OPENEE_REGIONY_TEST")
	var ref_plik := OS.get_environment("OPENEE_PODSEKTORY_TEST")
	var scn := OS.get_environment("OPENEE_SCN_TEST_E35")
	if plik == "" or ref_plik == "":
		_skip("punkty reprezentatywne e35_a 1857/1857", "OPENEE_REGIONY_TEST / OPENEE_PODSEKTORY_TEST nie ustawione")
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(plik))
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ref_plik))
	var c2: Object = CoreCpp.nowa_symulacja()
	c2.uzyj_tablic_przyblizonych(); c2.utworz_swiat("ee")
	c2.zbuduj_graf_z_wejscia(d, 19)
	var pk := 0
	for sp in ref["podsektory"]:
		var q: Dictionary = c2.podsektor(int(sp["id"]))
		if q.get("punkt", []) == [int(sp["punkt_i32"][0]), int(sp["punkt_i32"][1])]: pk += 1
	_wynik("punkty reprezentatywne e35_a (iloraz x87, suma f32) = gra", pk == ref["podsektory"].size(), "%d/%d" % [pk, ref["podsektory"].size()])
	if scn == "":
		_skip("klasyfikacja pól e35_a z SCN vs odczyt gry", "OPENEE_SCN_TEST_E35 nie ustawione (plik scenariusza – lokalnie)")
		return
	var s3 := ScenariuszEE.new()
	if not s3.wczytaj(FileAccess.get_file_as_bytes(scn)) or not s3.czytaj_teren():
		_wynik("klasyfikacja e35_a: odczyt SCN", false, s3.blad); return
	var rodz := {}
	var rj = JSON.parse_string(OS.get_environment("OPENEE_RODZINY_TEST")) if OS.get_environment("OPENEE_RODZINY_TEST") != "" else {}
	for k in rj: rodz[int(k)] = int(rj[k])
	var t3: Dictionary = s3.teren
	var c3: Object = CoreCpp.nowa_symulacja()
	c3.wczytaj_mape_scn(t3["A"], t3["B"], t3["teren"], t3["flagi"], t3["f10"], t3["wysokosc"], rodz)
	var m3: Dictionary = c3.wejscie_regionow_z_mapy()
	var zr := 0; var zw := 0; var nw := 0
	for i in m3["rodzaj_pola"].size():
		var g0 := int(d["rodzaj_pola"][i])
		if g0 == -1: continue
		if int(m3["rodzaj_pola"][i]) == g0: zr += 1
		if g0 == 1 or g0 == 10:
			nw += 1
			if signi(int(m3["bajt14"][i])) == signi(int(d["bajt14"][i])): zw += 1
	# etap 44: klify z kodu 0x51241D/0x512FB0 (teren domyślny, wysokości narożników, tekstury klifu) – 39 480/39 480;
	# znak +0x14 wody zależy od rodzajów pól (S1/S2), więc rośnie z 19 595 do 19 605 (raporty/archiwum/RAPORT_ETAP_44 § 3)
	_wynik("klasyfikacja e35_a z SCN: rodzaj pola 39 480/39 480, znak +0x14 wody 19 605/19 610", zr == 39480 and zw == 19605 and nw == 19610,
		"rodzaj %d, znak wody %d/%d" % [zr, zw, nw])


# etap 44: śmierć z danych typu (Generic Death.tai, 0x61B677/0x62462B/0x5FB218), rejestracja obiektów SCN na polach
# (dodaj_obiekty_scn, zestaw 9 dbunitset → +0x612) i graf e35_a wyłącznie z SCN i baz gry
func _test_etapu44(dll: String) -> void:
	var sym: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not sym.zaladuj_tablice(dll)["ok"]: sym.uzyj_tablic_przyblizonych()
	sym.utworz_swiat("ee")
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		tr[["08", "0C", "10"][i]] = {13: f}
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	sym.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
		[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5,
		"smierc_klatki": 24, "smierc_ms_klatki": 102, "rozklad_ms": 40000, "zasoby": 0}
	# gwardia (dbgraphics 265: 24 klatki × 102 ms, Rotting time 40 s) – pomiar 631/633/634: 72 / 1 / 1177 taktów [P];
	# obywatel (dbgraphics 54: 17 klatek × 94 ms, Rotting time 40 s) – pomiar 638: 47 / 1 / 1177 taktów [P]
	var gw := _czasy_smierci(sym, g, 24, 102)
	var sym2: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not sym2.zaladuj_tablice(dll)["ok"]: sym2.uzyj_tablic_przyblizonych()
	sym2.utworz_swiat("ee")
	sym2.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
		[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
	var ob_ := _czasy_smierci(sym2, g, 17, 94)
	_wynik("śmierć z danych typu: gwardia 72/1/1177, obywatel 47/1/1177 taktów (6000/6001/6002, pomiary 631–634, 638)",
		gw == [72, 1, 1177] and ob_ == [47, 1, 1177], "gwardia %s, obywatel %s" % [str(gw), str(ob_)])
	# rejestracja obiektów na polach: mapa 4 × 4 (romb), obiekt 2 × 2 i dwa jednopolowe na tym samym polu
	var c: Object = CoreCpp.nowa_symulacja()
	var A := 4
	var B := 4
	var T := 2 * A * B + A + B
	var V := 2 * A * B + 3 * A + 3 * B + 1
	var tex := PackedByteArray(); tex.resize(T); tex.fill(3)
	var fl := PackedByteArray(); fl.resize(T)
	var f10 := PackedFloat32Array(); f10.resize(T)
	var wys := PackedFloat32Array(); wys.resize(V)
	c.wczytaj_mape_scn(A, B, tex, fl, f10, wys, {3: 0})
	var ob := [{"id": 0x100, "gracz": 0, "X": 4, "Y": 4, "typ": 467, "kwadrat": 2, "hp": 7000, "zasob": 0, "budynek": 1, "unit_type": 2},
		{"id": 0x101, "gracz": 1, "X": 4, "Y": 4, "typ": 32, "kwadrat": 1, "hp": 65, "zasob": 0, "budynek": 0, "unit_type": 6}]
	var zs := [{"ID": 9, "obiekty": [468, -1], "rodziny": [0, 0], "dolacz": 10, "wyklucz": -1},
		{"ID": 10, "obiekty": [467], "rodziny": [0], "dolacz": -1, "wyklucz": -1}]
	var m: Dictionary = c.wejscie_regionow_z_scn(ob, zs)
	var N: int = m.get("N", 0)
	var j: Dictionary = m.get("jednostki", {})
	var l44: Array = j.get(str(4 * N + 4), [])
	var l55: Array = j.get(str(5 * N + 5), [])
	var ty: Dictionary = m.get("typy", {})
	_wynik("obiekty SCN na polach: obszar n × n, wstawianie na początek listy, +0x612 z zestawu 9 (przez zestaw dołączony)",
		l44.size() == 2 and String(l44[0][0]) == "0x101" and String(l44[1][0]) == "0x100" and l55.size() == 1 and
		ty.get("typ:467", []) == [0, 1, 2, 1] and ty.get("typ:32", []) == [0, 0, 6, 0],
		"(4,4) %s (5,5) %s typy %s" % [str(l44), str(l55), str(ty)])
	var scn := OS.get_environment("OPENEE_SCN_TEST_E35")
	var ref_plik := OS.get_environment("OPENEE_PODSEKTORY_TEST")
	if scn == "" or ref_plik == "":
		_skip("graf e35_a wyłącznie z SCN i baz gry", "OPENEE_SCN_TEST_E35 / OPENEE_PODSEKTORY_TEST nie ustawione")
		return
	var Z = root.get_node("Zasoby")
	var s := ScenariuszEE.new()
	if not s.wczytaj(FileAccess.get_file_as_bytes(scn)) or not s.czytaj_teren() or not s.czytaj_graczy(root.get_node("Konfiguracja").katalog_openee):
		_wynik("graf e35_a z SCN: odczyt", false, s.blad); return
	var rodz := {}
	for r in Z.tabela("dbterrain"):
		if int(r["ID"]) >= 0 and int(r["ID"]) < 256: rodz[int(r["ID"])] = int(r.get("Terrain family", 0))
	var c2: Object = CoreCpp.nowa_symulacja()
	c2.uzyj_tablic_przyblizonych()
	var t3 := s.teren
	c2.wczytaj_mape_scn(t3["A"], t3["B"], t3["teren"], t3["flagi"], t3["f10"], t3["wysokosc"], rodz)
	c2.utworz_swiat("ee")
	var we: Dictionary = ObiektyScnCore.wejscie(c2, s, Z)
	var w: Dictionary = c2.zbuduj_graf_z_wejscia(we, int(we.get("komorka", 0)))
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ref_plik))
	var pk := 0; var sk := 0
	for sp in ref["podsektory"]:
		var q: Dictionary = c2.podsektor(int(sp["id"]))
		if q.get("punkt", []) == [int(sp["punkt_i32"][0]), int(sp["punkt_i32"][1])]: pk += 1
		if q.get("sasiedzi", []) == sp["sasiedzi"].map(func(v): return int(v) if v != null else -1): sk += 1
	_wynik("graf e35_a wyłącznie z SCN i baz gry: 43 obszary, 1135 regionów, 1857 podsektorów, punkty i sąsiedzi 1857/1857",
		int(w.get("obszarow", 0)) == 43 and int(w.get("regionow", 0)) == 1135 and int(w.get("podsektorow", 0)) == 1857 and pk == 1857 and sk == 1857,
		"obszary %d, regiony %d, podsektory %d, punkty %d, sąsiedzi %d" % [int(w.get("obszarow", 0)), int(w.get("regionow", 0)), int(w.get("podsektorow", 0)), pk, sk])
	# etap 46 – dynamiczny graf (0x4288A7 → 0x4A36F3 → 0x4A3641): usunięcie budynku zgłasza zmianę, przebudowa raz po terminie
	var bud := ""
	for k in we["jednostki"]:
		for e in we["jednostki"][k]:
			var tf: Array = we["typy"].get(e[4], [])
			if tf.size() == 4 and int(tf[1]) == 1: bud = e[0]; break
		if bud != "": break
	var d0: Dictionary = c2.diagnostyka()
	var usun: bool = bud != "" and c2.usun_obiekt_mapy(bud.hex_to_int())
	var d1: Dictionary = c2.diagnostyka()
	c2.takt(1)
	var d2: Dictionary = c2.diagnostyka()
	c2.takt(10)
	var d3: Dictionary = c2.diagnostyka()
	_wynik("dynamiczny graf: usunięcie budynku → zgłoszenie (+0xD8, +0xD4 = teraz + 1 ms), jedna przebudowa po terminie, nie co takt",
		usun and bool(d1.get("przebudowa_zaplanowana")) and int(d1.get("wersja_grafu")) == int(d0.get("wersja_grafu"))
		and int(d2.get("przebudowy_grafu")) == 1 and int(d2.get("wersja_grafu")) == int(d0.get("wersja_grafu")) + 1
		and int(d3.get("przebudowy_grafu")) == 1 and not bool(d3.get("przebudowa_zaplanowana")),
		"obiekt %s, wersje %d → %d → %d, przebudowy %d" % [bud, int(d0.get("wersja_grafu", -1)), int(d2.get("wersja_grafu", -1)), int(d3.get("wersja_grafu", -1)), int(d3.get("przebudowy_grafu", -1))])


func _test_etapu45(dll: String) -> void:
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		tr[["08", "0C", "10"][i]] = {13: f}
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5,
		"smierc_klatki": 24, "smierc_ms_klatki": 102, "rozklad_ms": 40000, "zasoby": 0}
	var nowa := func() -> Object:
		var c: Object = CoreCpp.nowa_symulacja()
		if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
		c.utworz_swiat("ee")
		c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
			[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
		return c
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	# 1) kolejka fizyki 0x918DDC: dodanie na koniec, usunięcie w takcie po wejściu w Dead (6003); śmierć = tryb 2, v = 0
	var c: Object = nowa.call()
	var b: int = c.dodaj_jednostke(p, 13.5, 11.0, 0.0)
	var a: int = c.dodaj_jednostke(p, 10.5, 10.5, 0.0)
	c.ustaw_walke(a, 1, true, g, 215); c.ustaw_walke(b, 5, false, g, 215)
	var k0: Array = c.kolejka_fizyki()
	var tryb_smierci := -1
	var v_smierci := -1.0
	var t6003 := -1
	var po: Array = []
	for k in 3000:
		c.takt(1)
		var j: Dictionary = c.jednostka(b)
		if int(j.stan) == 6000 and tryb_smierci < 0: tryb_smierci = int(j.tryb); v_smierci = float(j.v)
		if int(j.stan) == 6003 and t6003 < 0:
			t6003 = k
			if not (c.kolejka_fizyki() as Array).has(b): t6003 = -2   # usunięcie za wcześnie
		elif t6003 >= 0 and k == t6003 + 1:
			po = c.kolejka_fizyki(); break
	_wynik("kolejka fizyki: kolejność dodania, usunięcie w takcie po 6003 (0x530913/0x53066A), śmierć = tryb 2 i v = 0 (0x54DDFF)",
		k0 == [b, a] and po == [a] and tryb_smierci == 2 and v_smierci == 0.0, "k0 %s, po %s, tryb %d, v %.3f, 6003 %d" % [str(k0), str(po), tryb_smierci, v_smierci, t6003])
	# 2) FleeDanger obywatela (0x620687): to samo pole co atakujący → oktant 1 (UMArcTan2(0, 0) = +π/2), odległość
	# fistp(3 · 1,5) = 4; stan generatora gry przed taktem 62215 (638) = 132607946 → n = 3, b = 0 → kierunek 7 (+4, −4)
	var c2: Object = nowa.call()
	var po_ := p.duplicate(); po_["a"] = 1.2; po_["vmax"] = 0.5
	var ob := g.duplicate(); ob["pole_widzenia"] = 3.0; ob["ai_szuka_wrogow"] = 0
	var cit: int = c2.dodaj_jednostke(po_, 10.5, 10.5, 0.0)
	var grd: int = c2.dodaj_jednostke(p, 10.5, 10.97, 3.14159)
	c2.ustaw_walke(grd, 1, true, g, 215); c2.ustaw_walke(cit, 5, false, ob, 65)
	var skr_ok: bool = c2.ustaw_skrypt_jednostki(cit, "Citizen") and not c2.ustaw_skrypt_jednostki(cit, "nieznany")
	c2.ustaw_skrypt_jednostki(cit, "Citizen")
	c2.rozkaz_ataku(grd, cit)
	var cel := Vector2(-1, -1)
	for k in 400:
		c2.ustaw_stan_rng(132607946)
		c2.takt(1)
		var w: Dictionary = c2.walka(cit)
		if int(c2.jednostka(cit).stan) == 8000:
			for e in w.get("kolejka", []): cel = Vector2(float(e.x), float(e.y))
			break
	_wynik("obywatel: FleeDanger po trafieniu w Idle – cel EEUGLocation (14,5; 6,5) jak w 638 (kierunek 7, odległość 4)",
		skr_ok and cel.is_equal_approx(Vector2(14.5, 6.5)), "cel %s" % str(cel))


func _test_etapu46(dll: String) -> void:
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		var f8 := PackedFloat32Array(); f8.resize(64); f8[48] = [0.714, 1.0, 1.4][i]
		tr[["08", "0C", "10"][i]] = {13: f, 8: f8}
	var nowa := func() -> Object:
		var c: Object = CoreCpp.nowa_symulacja()
		if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
		c.utworz_swiat("ee")
		c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
			[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
		return c
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var pb := {"a": 2.0, "vmax": 0.8, "alfa": 6.98132, "wmax": 6.98132, "rozmiar": 0.55, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5}
	var gs := g.duplicate(); gs["ai_szuka_wrogow"] = 0; gs["hp_max"] = 215
	var bh := {"atak": 14.0, "pancerz": [3, 0, 3, 0, 0, 0], "zasieg_max": 0.6, "pole_widzenia": 6.0, "przeladowanie_ms": 2000,
		"rodzaj_ataku": 5, "wiersz_celu": 5, "klasa_trafienia": 8, "rodzina_ataku": 55, "luk_ataku": 0.3490658700466156, "rozmiar": 0.55,
		"punktowy": 1, "szukanie_ms": 1000, "pole_ac": 0.8, "typ_bazy": 173, "typ_jednostki": 13, "ai_szuka_wrogow": 0,
		"leczenie_hp": 50, "leczenie_prog": 1.0, "leczenie_zasieg": 4.0, "leczenie_okres": 1.0, "leczone_typy": [422], "reakcja_underattack": 1}
	var stany := func(c: Object, id: int, n: int) -> Array:
		var w := []
		for k in n:
			c.takt(1)
			var j: Dictionary = c.jednostka(id)
			w.append(int(j.stan))
		return w
	# 1) cykl leczenia [P: 644 – 16000 → 16002 → 16001, +50 HP co 30 taktów od wejścia w 16001, przy pełnym HP 2025 → 5000]
	var c: Object = nowa.call()
	var h: int = c.dodaj_jednostke(pb, 10.5, 10.5, 0.0)
	var a: int = c.dodaj_jednostke(p, 10.5, 13.0, 0.0)
	c.ustaw_walke(h, 1, true, bh, 1235); c.ustaw_walke(a, 1, true, gs, 150)
	c.ustaw_skrypt_jednostki(h, "Military Healer Prophet")
	var sek := []
	var hp_t := {}
	var e := -1
	for k in 140:
		c.takt(1)
		var st := int(c.jednostka(h).stan)
		if sek.is_empty() or sek[-1] != st: sek.append(st)
		if st == 16001 and e < 0: e = k
		var hp := -1
		for d in c.stan_jednostek():
			if int(d.id) == a: hp = int(d.get("hp", -1))
		if not hp_t.has(hp): hp_t[hp] = k
	var ok1: bool = sek.slice(0, 6) == [16000, 16002, 16001, 2025, 5000, 16000] and hp_t.get(200, -1) == e + 29 and hp_t.get(215, -1) == e + 58
	_wynik("Healer.tai: 16000 → 16002 → 16001, +50 HP po 30 i 59 taktach, pełne HP → 2025 → 5000 (644)", ok1,
		"stany %s, 16001 w %d, HP 200 w %d, 215 w %d" % [str(sek.slice(0, 8)), e, hp_t.get(200, -1), hp_t.get(215, -1)])
	# 2) dwóch rannych o równym HP – wybór od końca kolejki (0x620A68) [P: 644 bohater2 – 0x1000857 po 0x1000856]
	var c2: Object = nowa.call()
	var h2: int = c2.dodaj_jednostke(pb, 10.5, 10.5, 0.0)
	var a1: int = c2.dodaj_jednostke(p, 8.5, 12.5, 0.0)
	var a2: int = c2.dodaj_jednostke(p, 12.5, 12.5, 0.0)
	c2.ustaw_walke(h2, 1, true, bh, 1235); c2.ustaw_walke(a1, 1, true, gs, 199); c2.ustaw_walke(a2, 1, true, gs, 199)
	c2.ustaw_skrypt_jednostki(h2, "Military Healer Prophet")
	c2.takt(1)
	var cel2 := 0
	for q in c2.walka(h2).get("kolejka", []): cel2 = int(q.cel)
	_wynik("Healer.tai: dwóch rannych (199/215) – cel z końca kolejki fizyki (0x620A68)", cel2 == a2, "cel %d (a1 %d, a2 %d)" % [cel2, a1, a2])
	# 3) TakeDamage w Idle → UnderAttack (EEUC z 2018) → 5001 → 2025 → 5000 [P: 619, t = 79045]
	var c3: Object = nowa.call()
	c3.ustaw_wrogow(1, 5, true); c3.ustaw_wrogow(5, 1, true)
	var hb: int = c3.dodaj_jednostke(pb, 10.5, 10.5, 0.0)
	var wg: int = c3.dodaj_jednostke(p, 10.5, 11.2, 3.14159)
	var bh5 := bh.duplicate(); bh5["leczenie_okres"] = 0.0
	c3.ustaw_walke(hb, 5, false, bh5, 1235); c3.ustaw_walke(wg, 1, true, g, 215)
	c3.ustaw_skrypt_jednostki(hb, "Military Healer Prophet")
	c3.rozkaz_ataku(wg, hb)
	var s3 := []
	for k in 200:
		c3.takt(1)
		var st := int(c3.jednostka(hb).stan)
		if s3.is_empty() or s3[-1] != st: s3.append(st)
		if s3.size() >= 4: break
	_wynik("TakeDamage w Idle: UnderAttack (EEUC z 2018) → ReacquireGoal 5001 → 2025 → 5000 (619)", s3 == [5000, 5001, 2025, 5000], str(s3))
	# 4) I1/I3: migawka diagnostyczna i powtarzalność – dwa identyczne światy, 300 taktów → identyczne migawki
	var migawki := []
	for powt in 2:
		var cx: Object = nowa.call()
		cx.ustaw_wrogow(1, 5, true); cx.ustaw_wrogow(5, 1, true)
		var x1: int = cx.dodaj_jednostke(p, 10.5, 13.5, 0.0)
		var x2: int = cx.dodaj_jednostke(p, 10.5, 10.5, 0.0)
		cx.ustaw_walke(x1, 1, true, g, 215); cx.ustaw_walke(x2, 5, false, g, 215)
		cx.rozkaz_ataku(x1, x2)
		cx.takt(300)
		migawki.append(JSON.stringify(cx.migawka_diagnostyczna(true)))
	_wynik("migawka diagnostyczna (takt, jednostki, kolejka fizyki, RNG, wersja grafu) i powtarzalność przebiegu (2 × 300 taktów)",
		migawki[0] == migawki[1] and migawki[0].contains("kolejka_fizyki") and migawki[0].contains("rng_stan"), migawki[0].substr(0, 120))
	# 5) I3: leczony ginie w trakcie leczenia → HealeeDestroyed → 2025 (bez błędów odwołań)
	var c5: Object = nowa.call()
	c5.ustaw_wrogow(1, 5, true); c5.ustaw_wrogow(5, 1, true)
	var h5: int = c5.dodaj_jednostke(pb, 10.5, 10.5, 0.0)
	var a5: int = c5.dodaj_jednostke(p, 10.5, 12.5, 0.0)
	var w5: int = c5.dodaj_jednostke(p, 10.5, 13.2, 3.14159)
	c5.ustaw_walke(h5, 1, true, bh, 1235); c5.ustaw_walke(a5, 1, true, gs, 20); c5.ustaw_walke(w5, 5, false, g, 215)
	c5.ustaw_skrypt_jednostki(h5, "Military Healer Prophet")
	c5.rozkaz_ataku(w5, a5)
	var s5 := []
	for k in 400:
		c5.takt(1)
		var st := int(c5.jednostka(h5).stan)
		if s5.is_empty() or s5[-1] != st: s5.append(st)
		if int(c5.jednostka(a5).stan) >= 6000 and st == 5000 and s5.has(16001): break
	_wynik("leczony ginie podczas leczenia: HealUnit → 2025 → 5000 bez zawieszenia (I3)", s5.has(16001) and s5.has(2025) and s5[-1] == 5000, str(s5))


## Czasy stanów 6000/6001/6002 celu (takty) przy sekwencji umierania `klatki` × `ms` (etap 44).
func _czasy_smierci(sym: Object, g: Dictionary, klatki: int, ms: int) -> Array:
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var gc := g.duplicate(); gc["smierc_klatki"] = klatki; gc["smierc_ms_klatki"] = ms
	# kolejność listy: cel przed atakującym (jak w nagraniach – lista od końca 0x547AAD)
	var b: int = sym.dodaj_jednostke(p, 13.5, 11.0, 0.0)
	var a: int = sym.dodaj_jednostke(p, 10.5, 10.5, 0.0)
	sym.ustaw_walke(a, 1, true, g, 215); sym.ustaw_walke(b, 5, false, gc, 215)
	var wejscia := {}
	var prev := -1
	for k in 3000:
		sym.takt(1)
		var st := -1
		for d in sym.stan_jednostek():
			if int(d.id) == b: st = int(d.stan)
		if st != prev and st >= 6000: wejscia[st] = k
		prev = st
	return [int(wejscia.get(6001, -1)) - int(wejscia.get(6000, 0)), int(wejscia.get(6002, -1)) - int(wejscia.get(6001, 0)),
		int(wejscia.get(6003, -1)) - int(wejscia.get(6002, 0))]


## Etap 47: budynek jako obiekt Core przez GDExtension – dodanie (HP, blokada pola), rozkaz ataku, śmierć (Dying,
## kolejka fizyki, zapadanie się), zwolnienie pola i przyrostowa przebudowa sektora grafu, restart (nowy świat).
func _test_etapu47(dll: String) -> void:
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		var f3 := PackedFloat32Array(); f3.resize(64); f3[48] = [0.23562, 0.33, 0.462][i]
		tr[["08", "0C", "10"][i]] = {13: f, 3: f3}
	var nowa := func() -> Object:
		var c: Object = CoreCpp.nowa_symulacja()
		if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
		c.utworz_swiat("ee")
		c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
			[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
		return c
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5,
		"ai_szuka_wrogow": 0}
	var dom := {"gracz": 5, "typ": 37, "X": 10, "Y": 10, "kwadrat": 1, "x": 10.5, "y": 10.5, "z": 0.0, "hp": 21, "hp_max": 500,
		"pole_widzenia": 2.0, "wiersz_celu": 3, "rodzaj_ataku": 3, "klasa_trafienia": 3, "rodzina_ataku": 9, "rozmiar": 1.0,
		"typ_jednostki": 2, "typ_bazy": 37, "rozklad_ms": 2000, "blokuje": 1, "id_mapy": "0x500", "w_siatce": 0}
	var c: Object = nowa.call()
	var a: int = c.dodaj_jednostke(p, 10.5, 13.0, 3.14159265)
	c.ustaw_walke(a, 1, true, g, 215)
	var b: int = c.dodaj_budynek(dom)
	var j0: Dictionary = c.jednostka(b)
	var ok0: bool = b > 0 and bool(j0.get("budynek", false)) and not bool(j0.get("w_fizyce", true)) and int(j0.get("hp", 0)) == 21 \
		and not c.pole_przejezdne(10, 10) and int(c.blokady_pola(10, 10)) == 1
	_wynik("budynek Core: HP, poza kolejką fizyki, blokada pola", ok0, JSON.stringify(j0))
	var przyjety: bool = c.rozkaz_ataku(a, b)
	var stany := []
	var smierc := -1; var w_fiz := false; var przej := false
	for k in 900:
		c.takt(1)
		var j: Dictionary = c.jednostka(b)
		if stany.is_empty() or stany[-1] != int(j.stan): stany.append(int(j.stan))
		if smierc < 0 and int(j.stan) == 6000:
			smierc = k; przej = c.pole_przejezdne(10, 10)
		elif smierc >= 0 and k == smierc + 1:
			w_fiz = bool(j.get("w_fizyce", false))
		if int(j.stan) == 6003: break
	var traf := 0
	for e in c.zdarzenia_walki_od(0):
		if String(e.rodzaj) == "trafienie" and int(e.cel) == b: traf += 1
	_wynik("rozkaz ataku na budynek → 3 trafienia po 7 HP, Dying → 6001 → 6002 → 6003, pole wolne przy śmierci, kolejka fizyki takt później",
		przyjety and traf == 3 and stany == [5000, 6000, 6001, 6002, 6003] and przej and w_fiz, "stany %s, trafienia %d, przejezdne %s, w_fizyce %s" % [str(stany), traf, przej, w_fiz])
	var c2: Object = nowa.call()
	var b2: int = c2.dodaj_budynek(dom)
	_wynik("restart: nowy świat – budynek z pełnym HP układu i blokadą pola", int(c2.jednostka(b2).get("hp", 0)) == 21 and not c2.pole_przejezdne(10, 10))


## Etap 48: pozostałość budynku (Core: „Debris on death#2” jako obiekt mapy w takcie śmierci, bez blokady i bez przebudowy)
## i trasa jednostki (GDExtension: `jednostka()["trasa"]`).
func _test_etapu48(dll: String) -> void:
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		var f3 := PackedFloat32Array(); f3.resize(64); f3[48] = [0.23562, 0.33, 0.462][i]
		tr[["08", "0C", "10"][i]] = {13: f, 3: f3}
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
		[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var g := {"atak": 15.0, "pancerz": [0, 6, 0, 0, 0, 0], "zasieg_max": 0.5, "pole_widzenia": 4.0, "przeladowanie_ms": 2000,
		"klasa_trafienia": 13, "rodzina_ataku": 48, "opoznienie_trafienia_ms": 1122, "luk_ataku": 0.3490658700466156,
		"rozmiar": 0.5, "punktowy": 1, "szukanie_ms": 2000, "pole_ac": 0.6000000238418579, "typ_bazy": 422, "typ_jednostki": 5,
		"ai_szuka_wrogow": 0}
	var dom := {"gracz": 5, "typ": 37, "X": 10, "Y": 10, "kwadrat": 1, "x": 10.5, "y": 10.5, "z": 0.0, "hp": 14, "hp_max": 500,
		"pole_widzenia": 2.0, "wiersz_celu": 3, "rodzaj_ataku": 3, "klasa_trafienia": 3, "rodzina_ataku": 9, "rozmiar": 1.0,
		"typ_jednostki": 2, "typ_bazy": 37, "rozklad_ms": 2000, "blokuje": 1, "id_mapy": "0x500", "w_siatce": 0,
		"gruz_typ": 361, "gruz_kwadrat": 1}
	var a: int = c.dodaj_jednostke(p, 10.5, 13.0, 3.14159265)
	c.ustaw_walke(a, 1, true, g, 215)
	var b: int = c.dodaj_budynek(dom)
	c.rozkaz_ataku(a, b)
	c.takt(1)
	var trasa: Array = c.jednostka(a).get("trasa", [])
	var przed: Array = c.gruz()
	var smierc := -1; var gz: Array = []
	for k in 900:
		c.takt(1)
		if smierc < 0 and int(c.jednostka(b).stan) == 6000:
			smierc = int(c.diagnostyka().get("takty", 0)); gz = c.gruz(); break
	var ok_g: bool = przed.is_empty() and gz.size() == 1 and int(gz[0].typ) == 361 and int(gz[0].X) == 10 and int(gz[0].Y) == 10 \
		and int(gz[0].takt) == smierc and c.pole_przejezdne(10, 10)
	_wynik("gruz budynku: obiekt 361 na polu domu w takcie śmierci, pole przejezdne", ok_g, JSON.stringify(gz) + " śmierć %d" % smierc)
	_wynik("trasa jednostki w jednostka()[\"trasa\"]", trasa is Array, JSON.stringify(trasa))


## Etap 49: premia prędkości gracza (0x627030 + SetSpeed) i budynek na liście kontaktów (+0x2D8, odepchnięcie od muru).
func _test_etapu49(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var baza := {"a": 2.0, "vmax": 0.45, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "t488": 0.5}
	var pr: Dictionary = c.premia_predkosci(baza, 1, 0.1)
	var ok_p: bool = absf(float(pr.vmax) - 0.5) < 1e-5 and absf(float(pr.a) - 2.22222) < 2e-5 and absf(float(pr.wmax) - 15.51404) < 2e-5 \
		and absf(float(pr.c4) - 0.45) < 1e-5 and absf(float(c.premia_predkosci(baza, 0, 0.1).vmax) - 0.45) < 1e-6
	_wynik("premia prędkości gracza: prorok 0,45 → 0,5, a/α/ωmax ×10/9 (odczyt 648)", ok_p, JSON.stringify(pr))
	var mur := {"gracz": 1, "typ": 467, "X": 10, "Y": 10, "kwadrat": 1, "x": 10.5, "y": 10.5, "z": 0.0, "hp": 7000, "hp_max": 7000,
		"rozmiar": 0.9, "typ_jednostki": 2, "typ_bazy": 467, "blokuje": 1, "id_mapy": "0x600", "w_siatce": 0, "kolizja": 1}
	var m: int = c.dodaj_budynek(mur)
	var u: int = c.dodaj_jednostke(pr, 9.9, 12.5, 3.14159265)
	c.rozkaz_ruchu(u, 9.9, 10.5, null, false)
	for k in 600: c.takt(1)
	var d: Dictionary = c.diagnostyka()
	_wynik("mur z +0x2D8: kontakt i odepchnięcie jednostki, mur nieruchomy", int(d.get("kroki_odpychania", 0)) > 0 \
		and float(c.jednostka(m).x) == 10.5, "kroki %d" % int(d.get("kroki_odpychania", 0)))


## Etap 50: rozkaz budowy obywatela – fundament HP 1, cykl RepairBuilding (+15 HP w rytmie 29/29/30 taktów),
## ukończenie (+0x340) i zgłoszenie zmiany mapy, stan końcowy Idle [P: 658/659].
func _test_etapu50(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	_wynik("wersja Core – etap 50 lub nowsza", str(c.wersja()).contains("etap 5"), c.wersja())
	var p := {"a": 1.2, "vmax": 0.5, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.3, "c4": 0.83333, "c8": 0.08185, "t488": 0.5}
	var cit: int = c.dodaj_jednostke(p, 11.65, 12.46, 0.0)
	c.ustaw_walke(cit, 1, true, {"pole_widzenia": 6.0, "rozmiar": 0.3, "typ_bazy": 32, "ai_szuka_wrogow": 0}, 25)
	c.ustaw_skrypt_jednostki(cit, "Citizen")
	c.ustaw_przyrost_budowy(cit, 15)
	var dom := {"gracz": 1, "typ": 37, "X": 10, "Y": 10, "kwadrat": 1, "x": 10.5, "y": 10.5, "z": 0.0, "hp_max": 500,
		"pole_widzenia": 2.0, "rozmiar": 1.0, "typ_jednostki": 2, "typ_bazy": 37, "id_mapy": "0x700"}
	var f: int = c.postaw_fundament(dom)
	var j0: Dictionary = c.jednostka(f)
	var ok_f: bool = int(j0.get("hp", -1)) == 1 and not bool(j0.get("ukonczony", true))
	c.rozkaz_budowy(cit, f)
	var stany := [int(c.jednostka(cit).stan)]
	var przyrosty := 0; var hp := 1
	for k in 2500:
		c.takt(1)
		var s := int(c.jednostka(cit).stan)
		if s != stany[-1]: stany.append(s)
		var h := int(c.jednostka(f).get("hp", -1))
		if h != hp: przyrosty += 1; hp = h
		if s == 5000 and bool(c.jednostka(f).get("ukonczony", false)): break
	var ok: bool = ok_f and hp == 500 and przyrosty == 34 and stany[0] == 8017 and 4002 in stany and stany[-1] == 5000 \
		and bool(c.jednostka(f).get("ukonczony", false))
	_wynik("budowa obywatela: fundament HP 1 → 500 (34 przyrosty), MoveToRepairSite … RepairBuilding → TaskSmartCitizen → Idle",
		ok, "HP %d, przyrosty %d, stany %s" % [hp, przyrosty, str(stany)])


## Etap 51: wzór przyrostu budowy 0x60BF56 (K = 35000 ms, m = 1,0, Build rate 1000) – dwóch budowniczych (+15, potem
## +10 każdy) [P: 663]; koszt domu i odmowa przy braku zasobów [P: 660/661].
func _test_etapu51(dll: String) -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	_wynik("wersja Core – etap 51 lub nowszy", str(c.wersja()).contains("etap 5"), c.wersja())
	var p := {"a": 1.2, "vmax": 0.5, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.3, "c4": 0.83333, "c8": 0.08185, "t488": 0.5}
	var ids := []
	for xy in [[11.65, 12.46], [13.5, 12.5]]:
		var u: int = c.dodaj_jednostke(p, xy[0], xy[1], 0.0)
		c.ustaw_walke(u, 1, true, {"pole_widzenia": 6.0, "rozmiar": 0.3, "typ_bazy": 32, "ai_szuka_wrogow": 0, "tempo_budowy_ms": 1000}, 25)
		c.ustaw_skrypt_jednostki(u, "Citizen")
		ids.append(u)
	var dom := {"gracz": 1, "typ": 37, "X": 10, "Y": 10, "kwadrat": 1, "x": 10.5, "y": 10.5, "z": 0.0, "hp_max": 500,
		"pole_widzenia": 2.0, "rozmiar": 1.0, "typ_jednostki": 2, "typ_bazy": 37, "id_mapy": "0x700", "czas_budowy_ms": 35000, "czas_budowy_s": 1.0}
	var f: int = c.postaw_fundament(dom)
	c.rozkaz_budowy(ids[0], f); c.rozkaz_budowy(ids[1], f)
	var przyrosty := {}; var hp := 1; var nmaks := 0
	for k in 3000:
		c.takt(1)
		var h := int(c.jednostka(f).get("hp", -1))
		if h != hp: przyrosty[h - hp] = int(przyrosty.get(h - hp, 0)) + 1; hp = h
		nmaks = maxi(nmaks, int(c.jednostka(f).get("budowniczowie", 0)))
		if bool(c.jednostka(f).get("ukonczony", false)) and int(c.jednostka(ids[0]).stan) == 5000 and int(c.jednostka(ids[1]).stan) == 5000: break
	_wynik("dwóch budowniczych: przyrosty 10 (n = 2), HP 500, +0x274 = 2", hp == 500 and nmaks == 2 and int(przyrosty.get(10, 0)) >= 30,
		"przyrosty %s, n maks %d" % [JSON.stringify(przyrosty), nmaks])
	c.ustaw_zasoby(1, [1111, 1222, 1333, 1444, 1555])
	var ok1: bool = c.oplac(1, [0, 50, 40, 0, 0])
	var z1: Array = c.zasoby(1)
	c.ustaw_zasoby(1, [20, 20, 20, 20, 20])
	var ok2: bool = c.oplac(1, [0, 50, 40, 0, 0])
	_wynik("koszt domu (50 drewna, 40 kamienia) i odmowa przy braku zasobów", ok1 and z1 == [1111, 1172, 1293, 1444, 1555] and not ok2
		and c.zasoby(1) == [20, 20, 20, 20, 20], JSON.stringify(z1))
	# zbieranie (Gather.tai) – drzewo, magazyn, oddanie +15 drewna [P: 673]
	var c2: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c2.zaladuj_tablice(dll)["ok"]: c2.uzyj_tablic_przyblizonych()
	c2.utworz_swiat("ee")
	var ob: int = c2.dodaj_jednostke(p, 11.5, 12.5, 0.0)
	c2.ustaw_walke(ob, 1, true, {"pole_widzenia": 3.0, "rozmiar": 0.3, "typ_bazy": 32, "ai_szuka_wrogow": 0, "atak": 5.0,
		"udzwig": 15, "tempo_zbierania": [4400, 8926, 6000, 6000, 3500, 5200, 4600]}, 65)
	c2.ustaw_skrypt_jednostki(ob, "Citizen")
	var drz: int = c2.dodaj_zrodlo({"gracz": 0, "typ": 339, "X": 10, "Y": 10, "x": 10.5, "y": 10.5, "z": 0.0, "hp": 1, "ilosc": 400,
		"zasob_typ": 3, "zasob_indeks": 1, "tempo_indeks": 0, "id_mapy": "0x1a4c"})
	var tc := dom.duplicate(); tc.merge({"typ": 35, "X": 15, "Y": 10, "kwadrat": 2, "x": 16.0, "y": 11.0, "hp": 4000, "hp_max": 4000, "id_mapy": "0x701"}, true)
	var m: int = c2.dodaj_budynek(tc)
	c2.ustaw_magazyn(m, true)
	c2.ustaw_zasoby(1, [1111, 1222, 1333, 1444, 1555])
	c2.rozkaz_zbierania(ob, drz, 11.15, 11.15)
	var niesie_maks := 0
	for k in 12000:
		c2.takt(1)
		niesie_maks = maxi(niesie_maks, int(c2.jednostka(ob).get("ilosc_40", 0)))
		if int(c2.zasoby(1)[1]) == 1237: break
	_wynik("zbieranie: 15 drewna niesione i oddane w magazynie, drzewo 385", niesie_maks == 15 and int(c2.zasoby(1)[1]) == 1237
		and int(c2.jednostka(drz).get("ilosc_40", -1)) == 385, "zasoby %s, drzewo %d" % [str(c2.zasoby(1)), int(c2.jednostka(drz).get("ilosc_40", -1))])


# Etap 52 – produkcja jednostek w budynkach (docs/titan/produkcja.md): koszt przy rozkazie, start w tym samym takcie,
# 824 takty (28000 ms / 34 ms), wyjście na krawędzi budynku, populacja, limit, anulowanie, wariant losowań (EE 3 / AoC 1).
func _test_etapu52(dll: String) -> void:
	var p := {"a": 1.2, "vmax": 0.5, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.3, "c4": 0.83333, "c8": 0.08185, "t488": 0.5}
	var tc := {"gracz": 1, "typ": 35, "X": 14, "Y": 10, "kwadrat": 2, "x": 15.0, "y": 11.0, "z": 0.0, "hp": 4000, "hp_max": 4000,
		"pole_widzenia": 2.0, "rozmiar": 1.0, "typ_jednostki": 2, "typ_bazy": 35, "id_mapy": "0x701"}
	var wyniki := {}
	for war in ["ee", "aoc"]:
		var c: Object = CoreCpp.nowa_symulacja()
		if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
		c.utworz_swiat(war)
		if war == "ee": _wynik("wersja Core – etap 52 lub nowszy", str(c.wersja()).contains("etap 5"), c.wersja())
		var b: int = c.dodaj_budynek(tc)
		c.ustaw_zasoby(1, [1111, 1222, 1333, 1444, 1555])
		c.ustaw_populacje(1, 1, 100, 0, 0)
		c.ustaw_produkcje({"tech_id": 1451, "typ_db": 480, "koszt": [50, 0, 0, 0, 0], "czas_ms": 28000, "mnoznik_czasu": 1.0,
			"populacja": 1, "ruch": p, "walka": {"pole_widzenia": 3.0, "rozmiar": 0.3, "typ_bazy": 480}, "hp": 65, "skrypt": "Citizen"})
		var ok: bool = c.rozkaz_produkcji(b, 1451)
		var j0: Dictionary = c.jednostka(b)
		var takt_konca := -1; var nowa := {}
		for k in range(1, 900):
			c.takt(1)
			var nw: Array = c.nowe_jednostki()
			if not nw.is_empty(): takt_konca = k; nowa = c.jednostka(int(nw[0])); break
		wyniki[war] = [ok, c.zasoby(1)[0], int(j0.get("prod_ms", -1)), takt_konca, snappedf(float(nowa.get("x", 0)), 0.001),
			snappedf(float(nowa.get("y", 0)), 0.001), int(nowa.get("typ_db", -1)), int(c.populacja(1)), int(c.limit_populacji(1))]
	var w: Array = wyniki["ee"]
	_wynik("produkcja: koszt przy rozkazie, licznik 28000, 824 takty, wyjście (14,15; 9,85), populacja 2, limit 101",
		w[0] and w[1] == 1061 and w[2] == 28000 and w[3] == 824 and w[4] == 14.15 and w[5] == 9.85 and w[6] == 480 and w[7] == 2
		and w[8] == 101, JSON.stringify(wyniki))
	_wynik("produkcja AoC – ten sam przebieg co EE (czas, miejsce, populacja)", wyniki["aoc"] == wyniki["ee"], JSON.stringify(wyniki["aoc"]))
	# brak zasobów i anulowanie
	var c3: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c3.zaladuj_tablice(dll)["ok"]: c3.uzyj_tablic_przyblizonych()
	c3.utworz_swiat("aoc")
	var b3: int = c3.dodaj_budynek(tc)
	c3.ustaw_populacje(1, 1, 100, 0, 0)
	c3.ustaw_produkcje({"tech_id": 1074, "typ_db": 32, "koszt": [50, 0, 0, 0, 0], "czas_ms": 28000, "ruch": p, "hp": 65})
	c3.ustaw_zasoby(1, [20, 20, 20, 20, 20])
	var brak: bool = c3.rozkaz_produkcji(b3, 1074)
	c3.ustaw_zasoby(1, [1111, 1222, 1333, 1444, 1555])
	c3.rozkaz_produkcji(b3, 1074); c3.rozkaz_produkcji(b3, 1074)
	var kol := int(c3.jednostka(b3).get("prod_kolejka_n", -1))
	var an1: bool = c3.anuluj_produkcje(b3, 1)
	var an0: bool = c3.anuluj_produkcje(b3, 0)
	_wynik("produkcja: brak zasobów – odmowa; anulowanie kolejki i bieżącej – pełny zwrot", not brak and kol == 1 and an1 and an0
		and c3.zasoby(1) == [1111, 1222, 1333, 1444, 1555] and int(c3.jednostka(b3).get("prod_biezaca", 0)) == -1, JSON.stringify(c3.zasoby(1)))


# Etap 53 – produkcja wojskowa w koszarach (docs/titan/produkcja.md § 5): dane technologii 3011 Inf03 - Maceman z dbtechtree
# (30 żywności + 30 żelaza, 32000 ms, obiekt 21), pomiary AoC 704/705/709 i EE 706/710; wybór płci obywatela przy starcie;
# anulowanie z interfejsu; kolejność listy kontaktów i wybór gałęzi kolizji (eksperymenty Fable).
func _test_etapu53(dll: String) -> void:
	var p := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
	var kosz := {"gracz": 1, "typ": 34, "X": 14, "Y": 10, "kwadrat": 2, "x": 15.0, "y": 11.0, "z": 0.0, "hp": 1500, "hp_max": 1500,
		"pole_widzenia": 2.0, "rozmiar": 1.0, "typ_jednostki": 2, "typ_bazy": 34, "id_mapy": "0x701"}
	var mace := {"tech_id": 3011, "typ_db": 21, "koszt": [30, 0, 0, 0, 30], "czas_ms": 32000, "mnoznik_czasu": 1.0, "populacja": 1,
		"ruch": p, "walka": {"pole_widzenia": 4.0, "rozmiar": 0.5, "typ_bazy": 21}, "hp": 150, "skrypt": "Land Patrolling"}
	var wyniki := {}
	for war in ["ee", "aoc"]:
		var c: Object = CoreCpp.nowa_symulacja()
		if dll == "" or not c.zaladuj_tablice(dll)["ok"]: c.uzyj_tablic_przyblizonych()
		c.utworz_swiat(war)
		if war == "ee": _wynik("wersja Core – etap 53", str(c.wersja()).contains("etap 53"), c.wersja())
		var b: int = c.dodaj_budynek(kosz)
		c.ustaw_zasoby(1, [1111, 1222, 1333, 1444, 1555])
		c.ustaw_populacje(1, 1, 100, 0, 0)
		c.ustaw_produkcje(mace)
		var r0 := int(c.diagnostyka().get("rng_losowan", 0))
		var ok: bool = c.rozkaz_produkcji(b, 3011)
		var los_startu := int(c.diagnostyka().get("rng_losowan", 0)) - r0
		var ms0 := int(c.jednostka(b).get("prod_ms", -1))
		var takt_konca := -1; var nowa := {}
		for k in range(1, 1000):
			c.takt(1)
			var nw: Array = c.nowe_jednostki()
			if not nw.is_empty(): takt_konca = k; nowa = c.jednostka(int(nw[0])); break
		wyniki[war] = [ok, c.zasoby(1), ms0, los_startu, takt_konca, snappedf(float(nowa.get("x", 0)), 0.001),
			snappedf(float(nowa.get("y", 0)), 0.001), int(nowa.get("typ_db", -1)), int(nowa.get("stan", -1)), int(c.populacja(1))]
	var w: Array = wyniki["ee"]
	_wynik("produkcja wojskowa: 30 żywności + 30 żelaza przy rozkazie, 32000 ms bez losowania startu, 942 takty, wyjście (14,25; 9,75)",
		w[0] and w[1] == [1081, 1222, 1333, 1444, 1525] and w[2] == 32000 and w[3] == 0 and w[4] == 942 and w[5] == 14.25 and w[6] == 9.75
		and w[7] == 21 and w[8] == 5000 and w[9] == 2, JSON.stringify(wyniki))
	_wynik("produkcja wojskowa AoC – ten sam przebieg co EE", wyniki["aoc"] == wyniki["ee"], JSON.stringify(wyniki["aoc"]))
	# anulowanie z interfejsu (0x5FD984 / 0x5FD8F3): pierwsza pozycja technologii z kolejki, potem bieżąca; pełny zwrot
	var c2: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c2.zaladuj_tablice(dll)["ok"]: c2.uzyj_tablic_przyblizonych()
	c2.utworz_swiat("aoc")
	var b2: int = c2.dodaj_budynek(kosz)
	c2.ustaw_zasoby(1, [1111, 1222, 1333, 1444, 1555]); c2.ustaw_populacje(1, 1, 100, 0, 0)
	c2.ustaw_produkcje(mace)
	var wlocz := mace.duplicate(); wlocz["tech_id"] = 2024; wlocz["typ_db"] = 24
	c2.ustaw_produkcje(wlocz)
	for t in [3011, 2024, 3011, 2024]: c2.rozkaz_produkcji(b2, t)
	var a1: bool = c2.anuluj_technologie(b2, 3011)
	var kol1 := int(c2.jednostka(b2).get("prod_kolejka_n", -1)); var cur1 := int(c2.jednostka(b2).get("prod_biezaca", 0))
	var a2: bool = c2.anuluj_technologie(b2, 3011)
	var cur2 := int(c2.jednostka(b2).get("prod_biezaca", 0))
	var a3: bool = c2.anuluj_technologie(b2, 3011)
	c2.takt(1)
	var cur3 := int(c2.jednostka(b2).get("prod_biezaca", 0))
	_wynik("anulowanie PPM: pozycja z kolejki, potem bieżąca tej technologii; następna startuje w kolejnym takcie; zwrot kosztu",
		a1 and kol1 == 2 and cur1 == 3011 and a2 and cur2 == -1 and not a3 and cur3 == 2024 and c2.zasoby(1) == [1051, 1222, 1333, 1444, 1495],
		"kolejka %d, bieżąca %d → %d → %d, zasoby %s" % [kol1, cur1, cur2, cur3, str(c2.zasoby(1))])
	# wybór płci: przycisk zamawia 1074, start losuje (≥ 0,5 → 1451)
	var zg := 0; var kob := 0
	var pc := {"a": 1.2, "vmax": 0.5, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.3, "c4": 0.83333, "c8": 0.08185, "t488": 0.5}
	for z in range(1, 21):
		var c3: Object = CoreCpp.nowa_symulacja()
		if dll == "" or not c3.zaladuj_tablice(dll)["ok"]: c3.uzyj_tablic_przyblizonych()
		c3.utworz_swiat("aoc")
		var b3: int = c3.dodaj_budynek(kosz)
		c3.ustaw_zasoby(1, [1111, 0, 0, 0, 0]); c3.ustaw_populacje(1, 1, 100, 0, 0)
		c3.ustaw_produkcje({"tech_id": 1451, "typ_db": 480, "koszt": [50, 0, 0, 0, 0], "czas_ms": 28000, "ruch": pc, "hp": 65})
		c3.ustaw_produkcje({"tech_id": 1074, "typ_db": 32, "koszt": [50, 0, 0, 0, 0], "czas_ms": 28000, "ruch": pc, "hp": 65, "losowy_zamiennik": 1451})
		var st := z * 7919
		c3.ustaw_stan_rng(st)
		var nast := (214013 * st + 2531011) & 0x7FFFFFFF
		var oczek := 1451 if float(nast) / 2147483648.0 >= 0.5 else 1074
		c3.rozkaz_produkcji(b3, 1074)
		if int(c3.jednostka(b3).get("prod_biezaca", -1)) == oczek: zg += 1
		if oczek == 1451: kob += 1
	_wynik("start obywatela losuje płeć (URandom ≥ 0,5 → Female Citizen 1451)", zg == 20 and kob > 2 and kob < 18, "zgodne %d/20, kobiet %d" % [zg, kob])
	# gałąź kolizji: dwa tarany (rozmiar 1,0, ruchome) – bez odpychania małego; licznik par dużych w diagnostyce
	var pt := {"a": 1.0, "vmax": 0.5, "alfa": 1.74533, "wmax": 0.87266, "rozmiar": 1.0, "promien_kolizji": 1.0, "c4": 1.0, "c8": 0.57296, "t488": 0.5}
	var c4: Object = CoreCpp.nowa_symulacja()
	if dll == "" or not c4.zaladuj_tablice(dll)["ok"]: c4.uzyj_tablic_przyblizonych()
	c4.utworz_swiat("ee")
	var ta: int = c4.dodaj_jednostke(pt, 10.5, 10.5, 0.0)
	var tb: int = c4.dodaj_jednostke(pt, 10.5, 12.5, 0.0)
	c4.rozkaz_ruchu(ta, 10.5, 15.5, null, false)
	c4.takt(900)
	var dg: Dictionary = c4.diagnostyka()
	_wynik("para taran–taran: gałąź duża (bez odpychania małego), stojący taran nieruszony", int(dg.get("pary_duze", 0)) > 0
		and int(dg.get("kolizje", -1)) == 0 and float(c4.jednostka(tb).get("x", 0)) == 10.5 and float(c4.jednostka(tb).get("y", 0)) == 12.5,
		"pary duże %d, kolizje małe %d" % [int(dg.get("pary_duze", 0)), int(dg.get("kolizje", -1))])

