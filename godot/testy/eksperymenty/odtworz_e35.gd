extends SceneTree
## Etap 36 – odtworzenie pomiarów 616/619 (EE, scenariusz e35_a) w OpenEE Core: gwardia 0x1000856 dostaje rozkaz
## gracza – atak na obywatela 0x5000ad0 (619) albo ruch w punkt (616: PPM chybiony, cel EEUGLocation) – obywatel stoi
## na polu z drzewami (cel nieosiągalny). Narzędzie badawcze (nie test regresji): mapa z pliku SCN (interpretacja
## w Core), obiekty blokujące jak w scenie potyczki, jednostki i rozkaz w takcie z pomiaru.
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/odtworz_e35.gd -- --scn=e35_a.scn
##         --t0=<czas gry 1. próbki> --t-rozkazu=<czas gry ostatniej próbki przed rozkazem> [--ruch=x,y[,kat]]
##         (kat = kurs końcowy celu EEUGLocation +0x2C z nagrania – `kat` w kolejce MCP; etap 37)
##         [--rozkazy=T:atak;T:ruch:x:y] [--probki=N] [--wyjscie=plik.json] [--takty=N]
## Dane wejściowe (SCN, nagranie) są lokalne – nie trafiają do repozytorium.

const TAKT_MS := 1500.0 / 44.0
const RUCH_422 := {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}


func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var Z = root.get_node("Zasoby")
	var s := ScenariuszEE.new()
	if not s.wczytaj(FileAccess.get_file_as_bytes(_arg("scn", ""))) or not s.czytaj_teren() or not s.czytaj_graczy(root.get_node("Konfiguracja").katalog_openee):
		print("BŁĄD SCN: ", s.blad); quit(1); return
	var c: Object = CoreCpp.nowa_symulacja()
	var rodz := {}
	for r in Z.tabela("dbterrain"):
		if int(r["ID"]) >= 0 and int(r["ID"]) < 256: rodz[int(r["ID"])] = int(r.get("Terrain family", 0))
	var t := s.teren
	var im: Dictionary = c.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
	var ob := {}
	for r in Z.tabela("dbobjects"): ob[int(r.ID)] = r
	var potyczka = load("res://sceny/potyczka.gd")
	var n := 0
	for g in range(s.gracze.size()):
		for u in s.gracze[g].jednostki:
			n += 1
			var o: Dictionary = ob.get(int(u.type), {})
			if o.is_empty() or int(u.get("valid", 0)) == 0: continue
			if int(o.get("Unit type", -1)) in [5, 6, 13, 16, 23, 4, 18, 21, 22] and float(o.get("Speed", 0)) > 0: continue
			c.dodaj_obiekt_mapy({"id": int(u.get("id", 0x7000000 + n)), "typ": int(u.type), "gracz": g, "X": int(u.get("X", 0)),
				"Y": int(u.get("Y", 0)), "kwadrat": maxi(1, int(o.get("Square occupied", 1))), "blokuje": potyczka._blokuje(int(u.type), o)})
	var dll := CoreCpp.znajdz_dll("ee", root.get_node("Konfiguracja"))
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]:
		print("BŁĄD: brak Low-Level Engine.dll"); quit(1); return
	c.utworz_swiat_na_mapie("ee", PackedByteArray([1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0]))
	var tr := {}
	for i in 3:
		var f := PackedFloat32Array(); f.resize(64); f[48] = [1.071, 1.5, 2.1][i]
		tr[["08", "0C", "10"][i]] = {13: f}
	# klasa 36 (obywatel) × rodzina 48 (gwardia) w tablicy 0x10 (człowiek → komputer) = 2,8 [P: walka.md § 13, 42 = 15·2,8];
	# tablic 0x08/0x0C dla klasy 36 nie odczytano – nieużywane w tym układzie (atakuje tylko gracz-człowiek)
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
	# obywatel (walka.md § 13 [P]): klasa 36, rozmiar 0,3, zasięg 2,0, LOS 3, AC 0,5, atak 5, HP 65
	var ob_p := {"atak": 5.0, "zasieg_max": 2.0, "pole_widzenia": 3.0, "przeladowanie_ms": 2000, "klasa_trafienia": 36,
		"rodzina_ataku": 38, "rozmiar": 0.3, "punktowy": 0, "szukanie_ms": 2000, "pole_ac": 0.5, "typ_jednostki": 6}
	var prorok := {"atak": 0.0, "pole_widzenia": 8.0, "rozmiar": 0.5, "typ_jednostki": 13}
	var ruch_ob := RUCH_422.duplicate(); ruch_ob.rozmiar = 0.3
	var obs: int = c.dodaj_jednostke(RUCH_422, 164.5, 111.5, -1.35201); c.ustaw_walke(obs, 1, true, prorok, 100)
	var a: int = c.dodaj_jednostke(RUCH_422, 164.5, 118.5, -2.35621); c.ustaw_walke(a, 1, true, gw, 215)
	var cel: int = c.dodaj_jednostke(ruch_ob, 160.5, 105.5, -0.78367); c.ustaw_walke(cel, 5, false, ob_p, 65)
	var wynik := {"mapa": im.get("skrot", ""), "pole_celu_przejezdne": c.pole_przejezdne(160, 105), "przejscia": []}
	var T0 := float(_arg("t0", "9909"))
	var takt_rozkazu := int(round((float(_arg("t-rozkazu", "40113")) - T0) / TAKT_MS))   # ostatnia próbka przed rozkazem
	var ruch := _arg("ruch", "")
	# --rozkazy=T:atak;T:ruch:x:y;… – kolejne rozkazy gracza (czas gry ostatniej próbki przed rozkazem)
	var dalsze := {}
	for r in _arg("rozkazy", "").split(";", false):
		var cz := r.split(":")
		dalsze[int(round((float(cz[0]) - T0) / TAKT_MS))] = cz
	var prev := ""
	var stary_cel := 0
	for k in int(_arg("takty", "6300")):
		if k == takt_rozkazu:
			if ruch != "": wynik["rozkaz"] = c.rozkaz_ruchu(a, float(ruch.get_slice(",", 0)), float(ruch.get_slice(",", 1)),
				float(ruch.get_slice(",", 2)) if ruch.get_slice_count(",") > 2 else null, false)
			else: wynik["rozkaz"] = c.rozkaz_ataku(a, cel)
		if dalsze.has(k):
			var cz: PackedStringArray = dalsze[k]
			if cz[1] == "ruch": c.rozkaz_ruchu(a, float(cz[2]), float(cz[3]), float(cz[4]) if cz.size() > 4 else null, false)
			else: c.rozkaz_ataku(a, cel)
		c.takt(1)
		var ja: Dictionary = {}
		for d in c.stan_jednostek():
			if int(d.id) == a: ja = d
		var k0 := takt_rozkazu if _arg("probki-od", "") == "" else int(round((float(_arg("probki-od", "0")) - T0) / TAKT_MS))
		if k >= k0 and k < k0 + int(_arg("probki", "0")):
			if not wynik.has("probki"): wynik["probki"] = []
			wynik.probki.append([snappedf(T0 + TAKT_MS * (k + 1), 0.1), int(ja.stan), float(ja.x), float(ja.y), float(ja.kurs), float(ja.v), int(ja.tryb)])
		var klucz := "%d|%d" % [int(ja.stan), int(ja.get("cel", 0))]
		if klucz != prev:
			prev = klucz
			wynik.przejscia.append([snappedf(T0 + TAKT_MS * (k + 1), 0.1), int(ja.stan), int(ja.get("cel", 0)), snappedf(float(ja.x), 0.001), snappedf(float(ja.y), 0.001), snappedf(float(ja.v), 0.001)])
	wynik["koniec"] = c.jednostka(a)
	wynik["diag"] = c.diagnostyka()
	var p := _arg("wyjscie", "")
	if p != "":
		var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(JSON.stringify(wynik, " "))
	print("przejść: ", wynik.przejscia.size(), " rozkaz w takcie ", takt_rozkazu)
	for x in wynik.przejscia.slice(0, 60): print(x)
	quit(0)
