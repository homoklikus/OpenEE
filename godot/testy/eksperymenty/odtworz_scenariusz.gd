extends SceneTree
## Etap 43 – wspólne odtwarzanie nagrań MCP z czystej mapy w OpenEE Core (dowolny układ jednostek z opisu).
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
	# kolejność listy Core (pętla jednostek idzie od końca listy, 0x547AAD): --kolejnosc=rosnaco (dotychczasowa
	# konwencja odtworz_e35) albo malejaco (etap 43 – pierwsze w takcie jednostki o mniejszym id)
	if _arg("kolejnosc", "malejaco") == "malejaco": lista.reverse()
	for j in lista:
		var ty := str(int(j["typ"]))
		if not par["ruch"].has(ty) or not par["walka"].has(ty):
			print("BŁĄD: brak parametrów typu ", ty); quit(1); return
		var id: int = c.dodaj_jednostke(par["ruch"][ty], float(j["x"]), float(j["y"]), float(j["kurs"]))
		c.ustaw_walke(id, int(j["gracz"]), int(j["gracz"]) == 1, par["walka"][ty]["p"], int(j["hp"]) if j["hp"] != null else int(par["walka"][ty]["hp"]))
		if j.get("z") != null: c.ustaw_z(id, float(j["z"]))   # z zapisu scenariusza (etap 43, 631 [P])
		core_id[str(j["id"])] = id; gra_id[id] = str(j["id"])
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
	for k in takty:
		for r in rozkazy.get(k, []):
			var kto: int = core_id[str(r["kto"])]
			var w
			if r["rodzaj"] == "atak": w = c.rozkaz_ataku(kto, core_id[str(r["cel"])])
			else: w = c.rozkaz_ruchu(kto, float(r["x"]), float(r["y"]), float(r["kat"]) if r.get("kat") != null else null, false)
			wynik.rozkazy.append([k, str(r["kto"]), str(r["rodzaj"]), w])
		c.takt(1)
		var pr := {}
		for d in c.stan_jednostek():
			var gid: String = gra_id.get(int(d.id), "")
			if gid == "": continue
			var kq := ""
			for e in c.walka(int(d.id)).get("kolejka", []):
				kq += "%s(%.4f,%.4f,%s);" % [str(e.rodzaj).substr(4, 3), float(e.x), float(e.y), gra_id.get(int(e.cel), "0")]
			pr[gid] = [int(d.stan), float(d.x), float(d.y), float(d.kurs), int(d.get("hp", -1)), gra_id.get(int(d.get("cel", 0)), "0"), kq, float(d.v)]
		wynik.probki.append([k, snappedf(T0 + TAKT_MS * (k + 1), 0.1), pr])
	wynik["diag"] = c.diagnostyka()
	wynik["zdarzenia"] = c.zdarzenia_walki_od(0)
	var f := FileAccess.open(_arg("wyjscie", "user://odtworzenie.json"), FileAccess.WRITE); f.store_string(JSON.stringify(wynik))
	print("takty ", takty, " rozkazy ", wynik.rozkazy.size(), " graf ", graf)
	quit(0)
