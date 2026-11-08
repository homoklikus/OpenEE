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


func _koniec() -> void:
	print("WYNIK GDExtension: %d zaliczonych, %d niezaliczonych, %d pominiętych" % [zal, niezal, pomin])
	quit(1 if niezal > 0 else 0)
