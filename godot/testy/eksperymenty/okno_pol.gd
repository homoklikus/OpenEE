extends SceneTree
## Etap 48 – podgląd przejezdności i blokad pól Core w oknie mapy SCN (z obiektami SCN), także po taktach odtworzenia.
## Użycie: … --script res://testy/eksperymenty/okno_pol.gd -- --scn=<.scn> --okno=x0,x1,y0,y1

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
		print("BŁĄD SCN"); quit(1); return
	var rodz := {}
	for r0 in Z.tabela("dbterrain"):
		if int(r0["ID"]) >= 0 and int(r0["ID"]) < 256: rodz[int(r0["ID"])] = int(r0.get("Terrain family", 0))
	var c: Object = CoreCpp.nowa_symulacja()
	c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var t := s.teren
	c.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
	# obiekty mapy jak odtworz_scenariusz.gd (etap 47): budynki i obiekty Świata blokujące wg potyczka._blokuje
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
	var par: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../dane/testy_walki/parametry_jednostek_ee.json"))
	c.utworz_swiat_na_mapie("ee", PackedByteArray(par["dozwolone_teren"]))
	var o := _arg("okno", "158,168,108,118").split(",")
	for y in range(int(o[3]), int(o[2]) - 1, -1):
		var w := "%3d " % y
		for x in range(int(o[0]), int(o[1]) + 1):
			w += ("." if c.pole_przejezdne(x, y) else "#") + str(mini(9, int(c.blokady_pola(x, y))))
		print(w)
	var h := "    "
	for x in range(int(o[0]), int(o[1]) + 1): h += str(x % 100).pad_zeros(2)
	print(h)
	quit(0)
