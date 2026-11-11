extends SceneTree
## Etap 43 – wspólne odtwarzanie nagrań MCP z czystej mapy w OpenEE Core (dowolny układ jednostek z opisu).
## Etap 44: domyślna kolejność listy – pozycja (Core `uporzadkuj_wg_pozycji`), parametry śmierci z baz gry (--smierc=0
## wyłącza), próbka zawiera też z.
## Opis tworzy `narzedzia/titan/odtworzenie_nagrania.py opis` (jednostki, kursy i rozkazy z nagrania); parametry typów –
## `dane/testy_walki/parametry_jednostek_ee.json`. Mapa i obiekty statyczne z pliku SCN (interpretacja w Core), jak
## odtworz_e35.gd. Wynik: próbka co takt dla wszystkich jednostek (stan, x, y, kurs, HP, cel, kolejka) – porównanie
## `odtworzenie_nagrania.py porownaj`.
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/odtworz_scenariusz.gd -- --scn=<.scn>
##         --opis=<opis.json> --wyjscie=<core.json> [--graf-wejscie=<regiony_wejscie.json>] [--od-startu=1|0] [--takty=N]
## Dane wejściowe są lokalne – nie trafiają do repozytorium.

const TAKT_MS := 1500.0 / 44.0


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
	var opis: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg("opis", "")))
	var par: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../dane/testy_walki/parametry_jednostek_ee.json"))
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
	c.utworz_swiat_na_mapie("ee", PackedByteArray(par["dozwolone_teren"]))
	var tr := {}
	for tab in par["tablice_walki"]["trafienie"]:
		tr[tab] = {}
		for kl in par["tablice_walki"]["trafienie"][tab]:
			var f := PackedFloat32Array(); f.resize(64)
			for rd in par["tablice_walki"]["trafienie"][tab][kl]: f[int(rd)] = float(par["tablice_walki"]["trafienie"][tab][kl][rd])
			tr[tab][int(kl)] = f
	var mn := []
	for i in 16: mn.append([1, 1, 1, 1, 1, 1])
	c.ustaw_tablice_walki({"trudnosc": 0, "mnozniki": mn, "trafienie": tr}, par["tablice_walki"]["ai"])
	c.ustaw_modyfikator_wysokosci(true)
	var gracze := {}
	for j in opis["jednostki"]: gracze[int(j["gracz"])] = true
	for g1 in gracze:
		for g2 in gracze:
			if g1 != g2: c.ustaw_wrogow(g1, g2, true)
	var graf := -1
	if _arg("graf-wejscie", "") != "":
		graf = c.zbuduj_graf_z_wejscia(JSON.parse_string(FileAccess.get_file_as_string(_arg("graf-wejscie", ""))), 19).get("podsektorow", -1)
	var core_id := {}   # id gry → id Core
	var gra_id := {}
	var lista: Array = opis["jednostki"].duplicate()
	# kolejność listy Core (pętla jednostek idzie od końca listy, 0x547AAD). Etap 44 [P: odczyt kolejki fizyki 0x918DDC,
	# zad. 639 – e42_1v1 i e44_kontakt_590]: lista po wczytaniu mapy ma kolejność pozycji (x rosnąco, potem y rosnąco) –
	# domyślnie --kolejnosc=pozycja. Dawne konwencje: rosnaco (odtworz_e35), malejaco (etap 43 – id malejąco).
	var kol := _arg("kolejnosc", "pozycja")
	if kol == "malejaco": lista.reverse()

	for j in lista:
		var ty := str(int(j["typ"]))
		if not par["ruch"].has(ty) or not par["walka"].has(ty):
			print("BŁĄD: brak parametrów typu ", ty); quit(1); return
		var id: int = c.dodaj_jednostke(par["ruch"][ty], float(j["x"]), float(j["y"]), float(j["kurs"]))
		var pw: Dictionary = par["walka"][ty]["p"].duplicate()
		if _arg("smierc", "1") == "1": pw.merge(ObiektyScnCore.parametry_smierci(int(ty), Z))   # etap 44: z dbgraphics i dbobjects
		c.ustaw_walke(id, int(j["gracz"]), int(j["gracz"]) == 1, pw, int(j["hp"]) if j["hp"] != null else int(par["walka"][ty]["hp"]))
		if j.get("z") != null: c.ustaw_z(id, float(j["z"]))   # z zapisu scenariusza (etap 43, 631 [P])
		if _arg("skrypty", "1") == "1":   # etap 45: skrypt .tai typu (dbobjects „TAI Script”), interpretacja w Core
			c.ustaw_skrypt_jednostki(id, String(ob.get(int(ty), {}).get("TAI Script", "")))
		core_id[str(j["id"])] = id; gra_id[id] = str(j["id"])
	if kol == "pozycja": c.uporzadkuj_wg_pozycji()   # etap 44: kolejka fizyki po wczytaniu (Core)
	var T0 := float(opis["T0"])
	# etap 43: symulacja od czasu gry 0 (start scenariusza – jednostki tworzone przy wczytaniu; w 629 pierwszy wybór celu
	# w 34 ms [P]), żeby fazy liczników (szukanie celu, regeneracja) odpowiadały grze; --od-startu=0 – od 1. próbki
	if _arg("od-startu", "1") == "1": T0 -= TAKT_MS * round(T0 / TAKT_MS)
	var rozkazy := {}
	for r in opis["rozkazy"]:
		var k := int(round((float(r["t_przed"]) - T0) / TAKT_MS))
		if not rozkazy.has(k): rozkazy[k] = []
		rozkazy[k].append(r)
	var wynik := {"mapa": im.get("skrot", ""), "graf": graf, "ids": {}, "probki": [], "rozkazy": []}
	for j in opis["jednostki"]: wynik.ids[str(j["id"])] = str(j["nazwa"])
	var takty := int(_arg("takty", str(int(round((float(opis["koniec_t"]) - T0) / TAKT_MS)) + 2)))
	# etap 45: --rng-nagranie=PLIK – przed każdym taktem stan generatora z nagrania gry (próbka końca poprzedniego taktu);
	# diagnostyka losowań w takcie (poza nagraniem gra losuje też w systemach nieodwzorowanych w Core)
	var rng_gry := {}
	var rng_tylko_start := false
	if _arg("rng-nagranie", "") != "":
		for p in JSON.parse_string(FileAccess.get_file_as_string(_arg("rng-nagranie", "")))["probki"]:
			if p.has("rng"): rng_gry[int(round(float(p["t"])))] = int(p["rng"])
	for k in takty:
		var t_przed := int(round(T0 + TAKT_MS * k))
		for dt in [0, -1, 1]:
			if rng_gry.has(t_przed + dt):
				c.ustaw_stan_rng(rng_gry[t_przed + dt])
				# etap 46: --rng-tylko-start=1 – stan generatora z gry tylko raz (1. próbka), dalej Core losuje sam
				if _arg("rng-tylko-start", "0") == "1":
					rng_gry.clear(); rng_tylko_start = true
				break
		for r in rozkazy.get(k, []):
			var kto: int = core_id[str(r["kto"])]
			var w
			if r["rodzaj"] == "atak": w = c.rozkaz_ataku(kto, core_id[str(r["cel"])])
			else: w = c.rozkaz_ruchu(kto, float(r["x"]), float(r["y"]), float(r["kat"]) if r.get("kat") != null else null, false)
			wynik.rozkazy.append([k, str(r["kto"]), str(r["rodzaj"]), w])
		var n_rng0 := int(c.diagnostyka().get("rng_losowan", 0))
		c.takt(1)
		var pr := {}
		if _arg("rng", "0") == "1": pr["rng_n"] = int(c.diagnostyka().get("rng_losowan", 0)) - n_rng0   # etap 46: losowania Core w takcie
		for d in c.stan_jednostek():
			var gid: String = gra_id.get(int(d.id), "")
			if gid == "": continue
			var kq := ""
			for e in c.walka(int(d.id)).get("kolejka", []):
				kq += "%s(%.4f,%.4f,%s);" % [str(e.rodzaj).substr(4, 3), float(e.x), float(e.y), gra_id.get(int(e.cel), "0")]
			pr[gid] = [int(d.stan), float(d.x), float(d.y), float(d.kurs), int(d.get("hp", -1)), gra_id.get(int(d.get("cel", 0)), "0"), kq, float(d.v), float(c.jednostka(int(d.id)).get("z", 0.0))]
		if _arg("rng", "0") == "1": pr["rng"] = int(c.diagnostyka().get("rng_stan", 0))   # etap 45: stan generatora
		wynik.probki.append([k, snappedf(T0 + TAKT_MS * (k + 1), 0.1), pr])
	# etap 46 (I2): tryb porównania – zgodność „algorytmem” (własny stan generatora od ziarna) vs „ze stanem z nagrania”
	wynik["tryb_rng"] = "stan_startowy_z_nagrania" if rng_tylko_start else ("z_nagrania_co_takt" if not rng_gry.is_empty() else "wlasny")
	wynik["graf_autonomiczny"] = graf > 0
	wynik["diag"] = c.diagnostyka()
	wynik["zdarzenia"] = c.zdarzenia_walki_od(0)
	var f := FileAccess.open(_arg("wyjscie", "user://odtworzenie.json"), FileAccess.WRITE); f.store_string(JSON.stringify(wynik))
	print("takty ", takty, " rozkazy ", wynik.rozkazy.size(), " graf ", graf)
	quit(0)
