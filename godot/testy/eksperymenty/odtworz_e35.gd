extends SceneTree
## Etap 36 – odtworzenie pomiarów 616/619 (EE, scenariusz e35_a) w OpenEE Core: gwardia 0x1000856 dostaje rozkaz
## gracza – atak na obywatela 0x5000ad0 (619) albo ruch w punkt (616: PPM chybiony, cel EEUGLocation) – obywatel stoi
## na polu z drzewami (cel nieosiągalny). Narzędzie badawcze (nie test regresji): mapa z pliku SCN (interpretacja
## w Core), obiekty blokujące jak w scenie potyczki, jednostki i rozkaz w takcie z pomiaru.
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/odtworz_e35.gd -- --scn=e35_a.scn
##         --t0=<czas gry 1. próbki> --t-rozkazu=<czas gry ostatniej próbki przed rozkazem> [--ruch=x,y[,kat]]
##         (kat = kurs końcowy celu EEUGLocation +0x2C z nagrania – `kat` w kolejce MCP; etap 37)
##         [--rozkazy=T:atak[:hero|cit[:A_GRD|K_GRD]];T:ruch:x:y[:kat]] [--pelny=1 --efekty=plik --wysokosc=0|1 --regen-ms=N]
##         [--graf-autonomiczny=1 – etap 44: graf wyłącznie z SCN i baz gry]
##         [--graf=podsektory.json – graf podsektorów z gry, etap 40] [--probki=N] [--wyjscie=plik.json] [--takty=N]
## Dane wejściowe (SCN, nagranie) są lokalne – nie trafiają do repozytorium.

const TAKT_MS := 1500.0 / 44.0
var wynik_efekty := -1
var wynik_graf := -1
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
	var pelny := _arg("pelny", "0") == "1"
	var obs: int = c.dodaj_jednostke(RUCH_422, 164.5, 111.5, -1.35201); c.ustaw_walke(obs, 1, true, prorok, 240 if _arg("pelny", "0") == "1" else 100)
	var a: int = c.dodaj_jednostke(RUCH_422, 164.5, 118.5, -2.35621); c.ustaw_walke(a, 1, true, gw, 215)
	var ids := {"A_GRD": a, "OBS": obs}
	if pelny:
		# etap 38: pełny skład e35_a (kolejność listy: identyfikatory rosnąco – kolejność listy gry [N])
		var ob_g := ob_p.duplicate()   # obywatel gracza 1 (typ 32 – te same parametry)
		var k1: int = c.dodaj_jednostke(ruch_ob, 166.5, 118.5, -0.78367); c.ustaw_walke(k1, 1, true, ob_g, 65); ids["A_CIT"] = k1
		var k2: int = c.dodaj_jednostke(RUCH_422, 162.5, 118.5, -2.35621); c.ustaw_walke(k2, 1, true, gw, 215); ids["K_GRD"] = k2
	var cel: int = c.dodaj_jednostke(ruch_ob, 160.5, 105.5, -0.78367); c.ustaw_walke(cel, 5, false, ob_p, 65)
	ids["T_CIT"] = cel
	var bohater := 0
	if pelny:
		var gw5 := gw.duplicate()
		var k3: int = c.dodaj_jednostke(RUCH_422, 168.5, 104.5, -2.35621); c.ustaw_walke(k3, 5, false, gw5, 215); ids["T_GRD"] = k3
		# bohater 173 „h1-4 Alexander the Great (heal)” – odczyt zad. 621 (typ/ulepszenie EE) i dbobjects [P];
		# ai_szuka_wrogow = 0: w 619 bohater nie atakuje – cykl 5000 → 16000 (LookForHealee, Healer.tai) → 2025 [P pomiar];
		# stan 16000 w Core niezamodelowany [N]. Parametry ruchu c4/c8 nieodczytane [N] (bohater stoi – bez wpływu).
		var ruch_b := {"a": 2.0, "vmax": 0.8, "alfa": 6.98132, "wmax": 6.98132, "rozmiar": 0.55, "c4": 0.5, "c8": 0.08185, "t488": 0.5}
		var bh := {"atak": 14.0, "pancerz": [3, 0, 3, 0, 0, 0], "zasieg_max": 0.6, "pole_widzenia": 6.0, "przeladowanie_ms": 2000,
			"rodzaj_ataku": 5, "wiersz_celu": 5, "klasa_trafienia": 8, "rodzina_ataku": 55, "luk_ataku": 0.3490658700466156,
			"rozmiar": 0.55, "punktowy": 1, "szukanie_ms": 1000, "pole_ac": 0.800000011920929, "typ_bazy": 173, "typ_jednostki": 13,
			"regeneracja": 2, "regeneracja_ms": int(_arg("regen-ms", "898")), "ai_szuka_wrogow": 0}
		bohater = c.dodaj_jednostke(ruch_b, 164.5, 104.5, -2.35810); c.ustaw_walke(bohater, 5, false, bh, 1235); ids["HERO"] = bohater
		# klasa 8 (bohater) × rodzina 48 (gwardia): 0,714 / 1,0 / 1,4 (odczyt zad. 621 [P])
		for i in 3:
			var f8 := PackedFloat32Array(); f8.resize(64); f8[48] = [0.714, 1.0, 1.4][i]
			tr[["08", "0C", "10"][i]][8] = f8
		mn[0] = [1, 1, 1.5, 1, 1, 1]
		c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr},
			[[2, 1, 50, 1, 1, 0, 1, 50, -500, 50], [15, 20, 30, 6, 6, 0, 1, 2, -500, 15], [10, 15, 50, 4, 4, 0, 1, 0, -500, 15]])
		if _arg("wysokosc", "1") == "1": c.ustaw_modyfikator_wysokosci(true)
		var pg := _arg("graf", "")   # etap 40: graf podsektorów odczytany z gry (Riverlands_MCP `podsektory`) – tryb diagnostyczny
		if pg != "": wynik_graf = c.ustaw_graf_podsektorow(JSON.parse_string(FileAccess.get_file_as_string(pg)))
		var pp := _arg("graf-przydzial", "")   # etap 41: tylko przydział pól z odczytu; punkty i sąsiedzi liczone w Core
		if pp != "":
			var dane: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pp))
			var przydzial := PackedInt32Array(); przydzial.resize(280 * 280)
			for e in dane["podsektory"]:
				for r in e["pola"]:
					for yy in range(int(r[1]), int(r[2]) + 1): przydzial[int(r[0]) * 280 + yy] = int(e["id"])
			wynik_graf = c.zbuduj_graf_z_przydzialu(przydzial, 280, 280, 19)
		var pw := _arg("graf-wejscie", "")   # etap 42: graf z wejścia mapy (regiony 0x4240D3 i podsektory 0x42434F w Core)
		if pw != "":
			wynik_graf = c.zbuduj_graf_z_wejscia(JSON.parse_string(FileAccess.get_file_as_string(pw)), 19).get("podsektorow", -1)
		if _arg("graf-autonomiczny", "") == "1":   # etap 44: mapa, klasyfikacja i obiekty pól wyłącznie z SCN i baz gry
			var we: Dictionary = ObiektyScnCore.wejscie(c, s, Z)
			wynik_graf = c.zbuduj_graf_z_wejscia(we, int(we.get("komorka", 19))).get("podsektorow", -1)
		var ps := _arg("graf-scn", "")   # etap 43: rodzaj pola i +0x14 wody z mapy SCN w Core; z pliku – tylko obiekty pól
		if ps != "":
			var ob_g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ps))
			var m: Dictionary = c.wejscie_regionow_z_mapy()
			m["jednostki"] = ob_g.get("jednostki", {}); m["typy"] = ob_g.get("typy", {})
			wynik_graf = c.zbuduj_graf_z_wejscia(m, 19).get("podsektorow", -1)
		var pe := _arg("efekty", "")
		if pe != "":
			wynik_efekty = c.ustaw_efekty_obszaru(JSON.parse_string(FileAccess.get_file_as_string(pe)))
			c.odtworz_efekty_obszaru()
	if _arg("mapa-pol", "") != "":
		var w := ""
		var ok: PackedStringArray = _arg("mapa-pol", "").split(",")   # x0,x1,y0,y1
		for yy in range(int(ok[3]), int(ok[2]) - 1, -1):
			var r := "%3d " % yy
			for xx in range(int(ok[0]), int(ok[1]) + 1): r += "." if c.pole_przejezdne(xx, yy) else "#"
			w += r + "\n"
		print("POLA\n" + w)
	var wynik := {"mapa": im.get("skrot", ""), "pole_celu_przejezdne": c.pole_przejezdne(160, 105), "przejscia": [],
		"ids": ids, "budynki_efektow": wynik_efekty, "podsektory": wynik_graf, "jednostki": {}}
	var T0 := float(_arg("t0", "9909"))
	var takt_rozkazu := int(round((float(_arg("t-rozkazu", "40113")) - T0) / TAKT_MS))   # ostatnia próbka przed rozkazem
	var ruch := _arg("ruch", "")
	# --rozkazy=T:atak;T:ruch:x:y;… – kolejne rozkazy gracza (czas gry ostatniej próbki przed rozkazem)
	var dalsze := {}
	for r in _arg("rozkazy", "").split(";", false):
		var cz := r.split(":")
		dalsze[int(round((float(cz[0]) - T0) / TAKT_MS))] = cz
	if _arg("test-trasy", "") != "":   # etap 40: diagnostyka trasy jednostki K_GRD do punktu
		var tt: PackedStringArray = _arg("test-trasy", "").split(",")
		c.rozkaz_ruchu(ids["K_GRD"], float(tt[0]), float(tt[1]), null, false)
		for q in 3:
			c.takt(1)
			var jk: Dictionary = c.jednostka(ids["K_GRD"])
			print("TRASA ", q, " stan ", jk.get("stan"), " x ", jk.get("x"), " y ", jk.get("y"), " trasa ", jk.get("trasa", "?"), " diag ", c.diagnostyka().get("astar_iteracje"))
		quit(0)
		return
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
			else:   # T:atak[:hero|cit[:A_GRD|K_GRD]] – etap 38: cel i wykonawca rozkazu
				var kto: int = ids.get(cz[3], a) if cz.size() > 3 else a
				c.rozkaz_ataku(kto, bohater if cz.size() > 2 and cz[2] == "hero" else cel)
		c.takt(1)
		if pelny:   # przejścia wszystkich jednostek: stan, cel, HP
			for d in c.stan_jednostek():
				var nm := ""
				for kk in ids:
					if ids[kk] == int(d.id): nm = kk
				var jd: Dictionary = c.jednostka(int(d.id))
				var kl := "%d|%d|%d" % [int(d.stan), int(d.get("cel", 0)), int(d.get("hp", -1))]
				if not wynik.jednostki.has(nm): wynik.jednostki[nm] = [["", 0]]
				var kq := ""   # etap 39: kolejka celów (rodzaj, punkt, cel)
				for e in c.walka(int(d.id)).get("kolejka", []):
					kq += "%s(%.4f,%.4f,%d);" % [str(e.rodzaj).substr(4, 3), float(e.x), float(e.y), int(e.cel)]
				if not wynik.has("kolejki"): wynik["kolejki"] = {}
				if not wynik.kolejki.has(nm): wynik.kolejki[nm] = [["", 0]]
				if wynik.kolejki[nm][-1][0] != kq: wynik.kolejki[nm].append([kq, snappedf(T0 + TAKT_MS * (k + 1), 0.1)])
				if wynik.jednostki[nm][-1][0] != kl:
					wynik.jednostki[nm].append([kl, snappedf(T0 + TAKT_MS * (k + 1), 0.1), snappedf(float(d.x), 0.001), snappedf(float(d.y), 0.001)])
		var ja: Dictionary = {}
		for d in c.stan_jednostek():
			if int(d.id) == a: ja = d
		var k0 := takt_rozkazu if _arg("probki-od", "") == "" else int(round((float(_arg("probki-od", "0")) - T0) / TAKT_MS))
		if k >= k0 and k < k0 + int(_arg("probki", "0")):
			if not wynik.has("probki"): wynik["probki"] = []
			var mj: Array = c.jednostka(a)["macierz"]
			wynik.probki.append([snappedf(T0 + TAKT_MS * (k + 1), 0.1), int(ja.stan), float(ja.x), float(ja.y), float(ja.kurs), float(ja.v), int(ja.tryb),
				float(mj[1]), float(mj[4]), float(c.jednostka(a)["omega"])])
		var klucz := "%d|%d" % [int(ja.stan), int(ja.get("cel", 0))]
		if klucz != prev:
			prev = klucz
			wynik.przejscia.append([snappedf(T0 + TAKT_MS * (k + 1), 0.1), int(ja.stan), int(ja.get("cel", 0)), snappedf(float(ja.x), 0.001), snappedf(float(ja.y), 0.001), snappedf(float(ja.v), 0.001)])
	wynik["koniec"] = c.jednostka(a)
	wynik["diag"] = c.diagnostyka()
	if pelny: wynik["zdarzenia"] = c.zdarzenia_walki_od(0)
	var p := _arg("wyjscie", "")
	if p != "":
		var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(JSON.stringify(wynik, " "))
	print("przejść: ", wynik.przejscia.size(), " rozkaz w takcie ", takt_rozkazu)
	for x in wynik.przejscia.slice(0, 60): print(x)
	quit(0)
