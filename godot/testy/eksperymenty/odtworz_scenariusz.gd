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
var _typ_gry := {}   # etap 50: id gry → typ (przyrost budowy wg typu budującego)


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
	var rek := {}   # etap 47: rekordy SCN wg id (kotwica X, Y budynków)
	var rek_g := {}   # etap 49: gracz rekordu
	var n := 0
	for g in range(s.gracze.size()):
		for u in s.gracze[g].jednostki:
			n += 1
			var o: Dictionary = ob.get(int(u.type), {})
			if o.is_empty() or int(u.get("valid", 0)) == 0: continue
			rek["0x%x" % int(u.get("id", 0))] = u
			rek_g["0x%x" % int(u.get("id", 0))] = g
			if int(o.get("Unit type", -1)) in [5, 6, 13, 16, 23, 4, 18, 21, 22] and float(o.get("Speed", 0)) > 0: continue
			c.dodaj_obiekt_mapy({"id": int(u.get("id", 0x7000000 + n)), "typ": int(u.type), "gracz": g, "X": int(u.get("X", 0)),
				"Y": int(u.get("Y", 0)), "kwadrat": maxi(1, int(o.get("Square occupied", 1))), "blokuje": potyczka._blokuje(int(u.type), o)})
	var dll := CoreCpp.znajdz_dll("ee", root.get_node("Konfiguracja"))
	if dll == "" or not c.zaladuj_tablice(dll)["ok"]:
		print("BŁĄD: brak Low-Level Engine.dll"); quit(1); return
	c.utworz_swiat_na_mapie(_arg("wariant", "ee"), PackedByteArray(par["dozwolone_teren"]))   # etap 52: --wariant=aoc
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
	var wm: Dictionary = ObiektyScnCore.wejscie(c, s, Z)   # etap 47: obiekty pól z SCN (też flagi typów budynków, +0x612)
	if _arg("graf-scn", "0") == "1":   # etap 47: graf z samego SCN i baz gry (etap 44), wejście zachowane w świecie
		graf = c.zbuduj_graf_z_wejscia(wm, int(wm.get("komorka", 19))).get("podsektorow", -1)
		if _arg("przebudowa-pelna", "0") == "1": c.ustaw_przebudowe_pelna(true)
	elif _arg("graf-wejscie", "") != "":
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
		var obt: Dictionary = ob.get(int(ty), {})
		if int(obt.get("Is building?", 0)) != 0:   # etap 47: budynek – obiekt Core z rekordu SCN i dbobjects
			var r: Dictionary = rek.get(str(j["id"]), {})
			var pb := ObiektyScnCore.parametry_budynku(obt, ob)
			pb["rozmiar_jeden"] = int(wm.get("typy", {}).get("typ:%d" % int(ty), [0, 0, 0, 0])[3])   # +0x612 (zestaw 9)
			pb.merge({"gracz": int(j["gracz"]), "typ": int(ty), "X": int(r.get("X", floor(float(j["x"])))),
				"Y": int(r.get("Y", floor(float(j["y"])))), "kwadrat": maxi(1, int(obt.get("Square occupied", 1))),
				"x": float(j["x"]), "y": float(j["y"]), "z": float(j["z"]) if j.get("z") != null else 0.0,
				"hp": int(j["hp"]) if j["hp"] != null else int(obt.get("Health", 0)), "blokuje": 1,
				"id_mapy": str(j["id"]), "w_siatce": 1}, true)
			var bid: int = c.dodaj_budynek(pb)
			core_id[str(j["id"])] = bid; gra_id[bid] = str(j["id"])
			continue
		if not par["ruch"].has(ty) or not par["walka"].has(ty):
			print("BŁĄD: brak parametrów typu ", ty); quit(1); return
		var pr: Dictionary = (par["ruch"][ty] as Dictionary).duplicate()
		# etap 48: parametry ruchu jednostki z pamięci gry (ulepszenie gracza +0x34) – nadpisują wartości typu z dbobjects
		# --ulepszenia=<klucz mapy>: parametry ruchu z ulepszenia gracza odczytane w grze (parametry_jednostek_ee.json → ruch_ulepszenia)
		var ul: Dictionary = par.get("ruch_ulepszenia", {}).get(_arg("ulepszenia", ""), {}).get(str(int(j["gracz"])), {})
		if ul.has(ty): pr.merge(ul[ty], true)
		# etap 49: --premie=<klucz>: poziomy atrybutów cywilizacji gracza → parametry ruchu liczone w Core (premia prędkości)
		var pc: Dictionary = par.get("premie_cywilizacji", {}).get(_arg("premie", ""), {}).get(str(int(j["gracz"])), {}).get(ty, {})
		if pc.has("predkosc"): pr = c.premia_predkosci(pr, int(pc["predkosc"][0]), float(pc["predkosc"][1]))
		if j.has("ruch"): pr.merge(j["ruch"], true)
		var id: int = c.dodaj_jednostke(pr, float(j["x"]), float(j["y"]), float(j["kurs"]))
		var pw: Dictionary = par["walka"][ty]["p"].duplicate()
		if _arg("smierc", "1") == "1": pw.merge(ObiektyScnCore.parametry_smierci(int(ty), Z))   # etap 44: z dbgraphics i dbobjects
		c.ustaw_walke(id, int(j["gracz"]), int(j["gracz"]) == 1, pw, int(j["hp"]) if j["hp"] != null else int(par["walka"][ty]["hp"]))
		if j.get("z") != null: c.ustaw_z(id, float(j["z"]))   # z zapisu scenariusza (etap 43, 631 [P])
		if _arg("skrypty", "1") == "1":   # etap 45: skrypt .tai typu (dbobjects „TAI Script”), interpretacja w Core
			c.ustaw_skrypt_jednostki(id, String(ob.get(int(ty), {}).get("TAI Script", "")))
		core_id[str(j["id"])] = id; gra_id[id] = str(j["id"])
	# etap 49: pozostałe budynki z SCN (np. mury) jako obiekty Core – uczestnicy list kontaktów (+0x2D8) i cele;
	# blokada pól już w siatce (obiekty mapy). --budynki-scn=0 – tylko obiekty z opisu (stan etapu 48)
	if _arg("budynki-scn", "1") == "1":
		for rid in rek:
			if core_id.has(rid): continue
			var u: Dictionary = rek[rid]
			var obt: Dictionary = ob.get(int(u.type), {})
			# tylko budynki graczy („Unit type” 2 – EEUCBuilding, 25 – brama); drzewa i obiekty Świata (UT 1 itd.) – [N]
			if int(obt.get("Is building?", 0)) == 0 or not int(obt.get("Unit type", 0)) in [2, 25]: continue
			var pb := ObiektyScnCore.parametry_budynku(obt, ob)
			pb["rozmiar_jeden"] = int(wm.get("typy", {}).get("typ:%d" % int(u.type), [0, 0, 0, 0])[3])
			var g: int = rek_g[rid]
			var X := int(u.get("X", 0)); var Y := int(u.get("Y", 0)); var kw := maxi(1, int(obt.get("Square occupied", 1)))
			pb.merge({"gracz": g, "typ": int(u.type), "X": X, "Y": Y, "kwadrat": kw, "x": X + 0.5 * kw, "y": Y + 0.5 * kw,
				"hp": int(obt.get("Health", 0)), "blokuje": 1, "id_mapy": rid, "w_siatce": 1}, true)
			var bid: int = c.dodaj_budynek(pb)
			core_id[rid] = bid; gra_id[bid] = rid
	# etap 51: źródła surowców (obiekty Świata z opisu – drzewa) i magazyny (dbobjects „Resource type” 1 [H])
	var zrodla_id := {}
	for zr in opis.get("zrodla", []):
		var zid: int = c.dodaj_zrodlo({"gracz": 0, "typ": int(zr["typ"]), "X": int(zr["X"]), "Y": int(zr["Y"]),
			"x": float(zr["X"]) + 0.5, "y": float(zr["Y"]) + 0.5, "hp": int(zr["hp"]), "ilosc": int(zr["ilosc"]),
			"zasob_typ": int(ob.get(int(zr["typ"]), {}).get("Resource type", 0)), "zasob_indeks": 1, "tempo_indeks": 0,
			"id_mapy": str(zr["id"])})
		zrodla_id[str(zr["id"])] = zid; core_id[str(zr["id"])] = zid
	for gid in core_id:
		var obz: Dictionary = ob.get(int(c.jednostka(core_id[gid]).get("typ", -1)), {})
		if int(obz.get("Is building?", 0)) != 0 and int(obz.get("Unit type", 0)) == 2 and int(obz.get("Resource type", 0)) == 1:
			c.ustaw_magazyn(core_id[gid], true)
	for g in opis.get("zasoby_startowe", {}):
		c.ustaw_zasoby(int(g), opis["zasoby_startowe"][g])
	# etap 52: produkcja – typy z dbtechtree (koszt, czas, obiekt; EpokiDB) + mnożnik i koszt populacji z danych,
	# parametry ruchu/walki tworzonej jednostki z typu obiektu; populacja i limit gracza z nagrania
	if opis.has("produkcja"):
		var tt: Dictionary = Z.znajdz("db/dbtechtree.dat")
		var tech := {}
		for rt in EpokiDB.techtree(tt.get("dane", PackedByteArray())): tech[int(rt["id"])] = rt
		for tid in opis["produkcja"]:
			var rt: Dictionary = tech.get(int(tid), {})
			if rt.is_empty(): print("BŁĄD: brak technologii ", tid, " w dbtechtree"); quit(1); return
			var typ := str(int(rt["obiekt"]))
			var dp: Dictionary = par.get("produkcja", {}).get(str(tid), {})
			c.ustaw_produkcje({"tech_id": int(tid), "typ_db": int(rt["obiekt"]), "koszt": rt["koszt"], "czas_ms": int(rt["czas_ms"]),
				"mnoznik_czasu": float(dp.get("mnoznik_czasu", 1.0)), "populacja": int(dp.get("populacja", 1)),
				"ruch": par["ruch"][typ], "walka": par["walka"][typ]["p"], "hp": int(par["walka"][typ]["hp"]),
				"skrypt": String(ob.get(int(typ), {}).get("TAI Script", ""))})
	for g in opis.get("populacja", {}):
		var pp: Array = opis["populacja"][g]
		c.ustaw_populacje(int(g), int(pp[0]), int(pp[1]), 0, 0)
	if kol == "pozycja": c.uporzadkuj_wg_pozycji()   # etap 44: kolejka fizyki po wczytaniu (Core)
	if _arg("kontakty-wczytanie", "0") == "1": c.odbuduj_kontakty_wszystkich()   # etap 49: kolejność tworzenia = lista
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
	for j in opis["jednostki"]:
		wynik.ids[str(j["id"])] = str(j["nazwa"])
		_typ_gry[str(j["id"])] = int(j["typ"])
	var takty := int(_arg("takty", str(int(round((float(opis["koniec_t"]) - T0) / TAKT_MS)) + 2)))
	# etap 45: --rng-nagranie=PLIK – przed każdym taktem stan generatora z nagrania gry (próbka końca poprzedniego taktu);
	# diagnostyka losowań w takcie (poza nagraniem gra losuje też w systemach nieodwzorowanych w Core)
	var rng_gry := {}
	var rng_tylko_start := false
	if _arg("rng-nagranie", "") != "":
		for p in JSON.parse_string(FileAccess.get_file_as_string(_arg("rng-nagranie", "")))["probki"]:
			if p.has("rng"): rng_gry[int(round(float(p["t"])))] = int(p["rng"])
	var ostatnie_trasy := {}
	var diag_rozkazu := []
	wynik["trasy"] = []
	for k in takty:
		var t_przed := int(round(T0 + TAKT_MS * k))
		for dt in [0, -1, 1]:
			if rng_gry.has(t_przed + dt):
				c.ustaw_stan_rng(rng_gry[t_przed + dt])
				# etap 46: --rng-tylko-start=1 – stan generatora z gry tylko raz (1. próbka), dalej Core losuje sam
				if _arg("rng-tylko-start", "0") == "1":
					rng_gry.clear(); rng_tylko_start = true
				break
		var po_takcie := []
		for r in rozkazy.get(k, []):
			var kto: int = core_id[str(r["kto"])]
			var w
			if r["rodzaj"] == "budowa" or r["rodzaj"] == "zbieranie" or r["rodzaj"] == "produkcja":   # etap 50–52: po takcie
				po_takcie.append(r); continue
			if r["rodzaj"] == "atak": w = c.rozkaz_ataku(kto, core_id[str(r["cel"])])
			else: w = c.rozkaz_ruchu(kto, float(r["x"]), float(r["y"]), float(r["kat"]) if r.get("kat") != null else null, false)
			wynik.rozkazy.append([k, str(r["kto"]), str(r["rodzaj"]), w])
			if _arg("diag-trasy", "0") == "1":   # etap 48: wynik A* prośby przy rozkazie (po pierwszym takcie poniżej)
				diag_rozkazu.append(k)
		var n_rng0 := int(c.diagnostyka().get("rng_losowan", 0))
		c.takt(1)
		# etap 50: rozkaz budowy w próbce po takcie k widoczny jako MoveToRepairSite 8017 z trybem 0, bez ruchu i bez
		# przejścia [P: 658 ×2] – w odtworzeniu wykonywany po takcie k (gra obsługuje rozkaz po aktualizacji jednostki [H])
		for r in po_takcie:
			var kto: int = core_id[str(r["kto"])]
			var w
			if r["rodzaj"] == "produkcja":   # etap 52: koszt i start w próbce kliknięcia [P: 677/679]
				w = c.rozkaz_produkcji(kto, int(r["tech"]))
				wynik.rozkazy.append([k, str(r["kto"]), "produkcja", w])
				continue
			if r["rodzaj"] == "zbieranie":   # etap 51: PPM na źródle – MoveToResource 8008 w próbce kliknięcia [P: 673]
				w = c.rozkaz_zbierania(kto, core_id[str(r["zrodla"][0])], float(r["x"]), float(r["y"]))
				wynik.rozkazy.append([k, str(r["kto"]), "zbieranie", w])
				continue
			var fd: Dictionary = r["fundament"]
			if not core_id.has(str(fd["id"])):
				var obf: Dictionary = ob.get(int(fd["typ"]), {})
				var pf := ObiektyScnCore.parametry_budynku(obf, ob)
				pf["rozmiar_jeden"] = int(wm.get("typy", {}).get("typ:%d" % int(fd["typ"]), [0, 0, 0, 0])[3])
				pf.merge({"gracz": int(fd["gracz"]), "typ": int(fd["typ"]), "X": int(fd["X"]), "Y": int(fd["Y"]),
					"kwadrat": maxi(1, int(obf.get("Square occupied", 1))), "x": float(fd["x"]), "y": float(fd["y"]),
					"z": float(fd["z"]), "hp_max": int(obf.get("Health", 0)), "id_mapy": str(fd["id"])}, true)
				pf.merge(par.get("budowa_typow", {}).get(str(int(fd["typ"])), {}), true)   # etap 51: K, m (wzór 0x60BF56)
				var fid: int = c.postaw_fundament(pf)
				core_id[str(fd["id"])] = fid; gra_id[fid] = str(fd["id"])
				wynik.ids[str(fd["id"])] = "fundament"
			var pb_: Dictionary = par.get("przyrost_budowy", {}).get(str(_typ_gry.get(str(r["kto"]), "")), {})
			c.ustaw_przyrost_budowy(kto, int(pb_.get(str(int(fd["typ"])), 0)))
			w = c.rozkaz_budowy(kto, core_id[str(fd["id"])])
			wynik.rozkazy.append([k, str(r["kto"]), "budowa", w])
		if k in diag_rozkazu or (k - 1) in diag_rozkazu:
			var dg: Dictionary = c.diagnostyka()
			print("diag takt ", k, ": bounded_sukces=", dg.get("bounded_sukces"), " iteracje=", dg.get("astar_iteracje"), " wywolania=", dg.get("astar_wywolania"))
		var pr := {}
		if _arg("rng", "0") == "1": pr["rng_n"] = int(c.diagnostyka().get("rng_losowan", 0)) - n_rng0   # etap 46: losowania Core w takcie
		for d in c.stan_jednostek():
			var gid: String = gra_id.get(int(d.id), "")
			if gid == "": continue
			var kq := ""
			for e in c.walka(int(d.id)).get("kolejka", []):
				kq += "%s(%.4f,%.4f,%s);" % [str(e.rodzaj).substr(4, 3), float(e.x), float(e.y), gra_id.get(int(e.cel), "0")]
			pr[gid] = [int(d.stan), float(d.x), float(d.y), float(d.kurs), int(d.get("hp", -1)), gra_id.get(int(d.get("cel", 0)), "0"), kq, float(d.v), float(c.jednostka(int(d.id)).get("z", 0.0))]
			# etap 48: trasa (pozostałe punkty) zapisywana przy każdej zmianie – porównanie z polem `trasa` rejestratora
			var trs := JSON.stringify(c.jednostka(int(d.id)).get("trasa", []))
			if ostatnie_trasy.get(gid, "") != trs:
				ostatnie_trasy[gid] = trs
				wynik.trasy.append([snappedf(T0 + TAKT_MS * (k + 1), 0.1), gid, JSON.parse_string(trs)])
		if _arg("rng", "0") == "1": pr["rng"] = int(c.diagnostyka().get("rng_stan", 0))   # etap 45: stan generatora
		if not opis.get("zasoby_startowe", {}).is_empty():   # etap 51: zasoby gracza 1, niesione, ilość w źródłach
			pr["zasoby"] = c.zasoby(1)
			pr["zrodla"] = {}
			for zg in zrodla_id: pr["zrodla"][zg] = [int(c.jednostka(zrodla_id[zg]).get("hp", -1)), int(c.jednostka(zrodla_id[zg]).get("ilosc_40", -1))]
			for gid2 in core_id:
				if int(gid2.hex_to_int()) >> 24 == 1: pr["niesie_" + gid2] = int(c.jednostka(core_id[gid2]).get("ilosc_40", 0))
		if opis.has("produkcja"):   # etap 52: bieżąca pozycja, licznik, kolejka budynków; populacja; nowe jednostki
			for gid3 in core_id:
				var jb: Dictionary = c.jednostka(core_id[gid3])
				if int(jb.get("prod_biezaca", -1)) >= 0 or int(jb.get("prod_kolejka_n", 0)) > 0 or opis.get("budynki_produkcji", []).has(gid3):
					pr["prod_" + gid3] = [int(jb.get("prod_biezaca", -1)), int(jb.get("prod_ms", 0)), int(jb.get("prod_kolejka_n", 0))]
			pr["populacja"] = c.populacja(1)
			for nid in c.nowe_jednostki():
				var nj: Dictionary = c.jednostka(int(nid))
				var kurs_n := 0.0
				for d2 in c.stan_jednostek():
					if int(d2.id) == int(nid): kurs_n = float(d2.kurs)
				if not wynik.has("nowe"): wynik["nowe"] = []
				wynik["nowe"].append([snappedf(T0 + TAKT_MS * (k + 1), 0.1), int(nj.get("typ_db", -1)), float(nj.get("x", 0)), float(nj.get("y", 0)), kurs_n])
		if _arg("graf-scn", "0") == "1":   # etap 47: menedżer przebudowy (termin, flaga, zmienione sektory) i kolejka fizyki
			var sg: Dictionary = c.stan_grafu()
			pr["graf"] = [int(sg["d4"]), bool(sg["d8"]), int(sg["zmienione_sektory"]), int(sg["przebudowy_sektorow"]), int(sg["maks_id"])]
			pr["fizyka"] = c.kolejka_fizyki().map(func(v): return gra_id.get(int(v), "?"))
		wynik.probki.append([k, snappedf(T0 + TAKT_MS * (k + 1), 0.1), pr])
	# etap 46 (I2): tryb porównania – zgodność „algorytmem” (własny stan generatora od ziarna) vs „ze stanem z nagrania”
	wynik["tryb_rng"] = "stan_startowy_z_nagrania" if rng_tylko_start else ("z_nagrania_co_takt" if not rng_gry.is_empty() else "wlasny")
	wynik["graf_autonomiczny"] = graf > 0
	wynik["diag"] = c.diagnostyka()
	wynik["zdarzenia"] = c.zdarzenia_walki_od(0)
	var f := FileAccess.open(_arg("wyjscie", "user://odtworzenie.json"), FileAccess.WRITE); f.store_string(JSON.stringify(wynik))
	print("takty ", takty, " rozkazy ", wynik.rozkazy.size(), " graf ", graf)
	quit(0)
