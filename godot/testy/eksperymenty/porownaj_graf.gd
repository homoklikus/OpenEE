extends SceneTree
## Etap 43 – porównanie grafu podsektorów zbudowanego w Core (z wejścia mapy) z odczytem z gry: obszary, etykiety
## regionów, przydział i id podsektorów, punkty reprezentatywne i sąsiedzi (graf instalowany w świecie Core).
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/porownaj_graf.gd -- --wejscie=<.json>
##         --podsektory=<odczyt `podsektory`> [--wynik=<.json>]
##         [--scn=<.scn>] – etap 43: rodzaj pola i bajt +0x14 wody z mapy SCN w Core (wejscie_regionow_z_mapy); z pliku
##         --wejscie biorą się wtedy tylko obiekty pól (jednostki, typy) i porównanie +0x04/+0x14 z odczytem gry
##         [--obiekty-scn=1] – etap 44: obiekty pól też z SCN (wejscie_regionow_z_scn: kawałek 5 + dbobjects + dbunitset);
##         plik --wejscie służy wtedy WYŁĄCZNIE do porównania (rodzaj pól, +0x14, listy obiektów pól)

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


## Listy obiektów pól Core (z SCN) kontra odczyt gry: pola z identyczną listą (id w kolejności), z identyczną listą po
## pominięciu obiektów nieobecnych w SCN (rekordy valid = 0 tworzone przez grę), oraz zgodność flag typów.
func _porownaj_obiekty(m: Dictionary, d: Dictionary) -> Dictionary:
	var a: Dictionary = m["jednostki"]; var b: Dictionary = d.get("jednostki", {})
	var ids_core := {}
	for k in a:
		for e in a[k]: ids_core[String(e[0])] = true
	var klucze := {}
	for k in a: klucze[k] = true
	for k in b: klucze[k] = true
	var ident := 0; var ident_bez := 0; var roz := []
	var flagi_ok := 0; var flagi_n := 0
	for k in klucze:
		var la: Array = a.get(k, []); var lb: Array = b.get(k, [])
		var ia := la.map(func(e): return String(e[0]))
		var ib := lb.map(func(e): return String(e[0]))
		if ia == ib: ident += 1
		var ib2 := ib.filter(func(v): return ids_core.has(v))
		if ia == ib2: ident_bez += 1
		elif roz.size() < 10: roz.append([int(k), ia, ib])
		for e in lb:
			var j := ia.find(String(e[0]))
			if j < 0: continue
			flagi_n += 1
			var fa: Array = m["typy"].get(la[j][4], [])
			var fb: Array = d["typy"].get(e[4], [])
			if fa == fb.map(func(v): return int(v)): flagi_ok += 1
	return {"pol_z_obiektami": klucze.size(), "listy_identyczne": ident, "listy_identyczne_bez_obiektow_spoza_scn": ident_bez,
		"flagi_typow_zgodne": flagi_ok, "wpisow": flagi_n, "pierwsze_roznice": roz}


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg("wejscie", "")))
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg("podsektory", "")))
	var kl := {}
	if _arg("scn", "") != "":
		var Z = root.get_node("Zasoby")
		var s := ScenariuszEE.new()
		if not s.wczytaj(FileAccess.get_file_as_bytes(_arg("scn", ""))) or not s.czytaj_teren() or not s.czytaj_graczy(root.get_node("Konfiguracja").katalog_openee):
			print("BŁĄD SCN"); quit(1); return
		var rodz := {}
		for r0 in Z.tabela("dbterrain"):
			if int(r0["ID"]) >= 0 and int(r0["ID"]) < 256: rodz[int(r0["ID"])] = int(r0.get("Terrain family", 0))
		var t := s.teren
		c.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
		var autonom := _arg("obiekty-scn", "") == "1"
		var m: Dictionary = ObiektyScnCore.wejscie(c, s, Z) if autonom else c.wejscie_regionow_z_mapy()
		var zr := 0; var zh := 0; var zh_znak := 0; var nwody := 0; var npol := 0; var nh := 0
		for i in m["rodzaj_pola"].size():
			var g0 := int(d["rodzaj_pola"][i])
			if g0 == -1: continue
			npol += 1
			if int(m["rodzaj_pola"][i]) == g0: zr += 1
			if int(d["bajt14"][i]) == int(m["bajt14"][i]): zh += 1
			if g0 == 1 or g0 == 10:
				nwody += 1
				if signi(int(d["bajt14"][i])) == signi(int(m["bajt14"][i])): zh_znak += 1
		kl = {"pol": npol, "rodzaj_zgodny": zr, "bajt14_zgodny": zh, "pol_wody": nwody, "bajt14_wody_znak_zgodny": zh_znak}
		if autonom: kl["obiekty_pol"] = _porownaj_obiekty(m, d)
		print("KLASYFIKACJA ", JSON.stringify(kl))
		var d2 := {"N": m["N"], "rodzaj_pola": m["rodzaj_pola"], "bajt14": m["bajt14"], "brzeg": m["brzeg"], "komorka": m.get("komorka", 19),
			"jednostki": m["jednostki"] if autonom else d.get("jednostki", {}), "typy": m["typy"] if autonom else d.get("typy", {})}
		d = d2
	var r: Dictionary = c.zbuduj_graf_z_wejscia(d, int(d.get("komorka", 19)))   # etap 44: bok sektora z mapy (Core)
	var N: int = d["N"]
	var reg: PackedInt32Array = r["regiony"]
	var prz: PackedInt32Array = r["przydzial"]
	var pol := 0; var zg_reg := 0; var zg_prz := 0
	var id_ok := 0; var pkt_ok := 0; var sas_ok := 0; var pierwszy := ""
	for s in ref["podsektory"]:
		var wszystkie := true
		for run in s["pola"]:
			for y in range(int(run[1]), int(run[2]) + 1):
				var i: int = int(run[0]) * N + y
				pol += 1
				if reg[i] == int(s["w4c"][1]): zg_reg += 1
				if prz[i] == int(s["id"]): zg_prz += 1
				else: wszystkie = false
		if wszystkie:
			id_ok += 1
			var ps: Dictionary = c.podsektor(int(s["id"]))
			if ps.get("punkt", []) == [int(s["punkt_i32"][0]), int(s["punkt_i32"][1])]: pkt_ok += 1
			if ps.get("sasiedzi", []) == s["sasiedzi"].map(func(v): return int(v) if v != null else -1): sas_ok += 1
		elif pierwszy == "": pierwszy = "podsektor %d (rodzaj %d, %d pól, pierwsze pole %s)" % [int(s["id"]), int(s["rodzaj"]), int(s["liczba_pol"]), str(s["pola"][0])]
	var wynik := {"regionow": r["regionow"], "obszarow": r["obszarow"], "podsektorow": r["podsektorow"], "pol": pol,
		"regiony_zgodne": zg_reg, "przydzial_zgodny": zg_prz, "podsektory_identyczne": id_ok, "punkty_zgodne": pkt_ok, "sasiedzi_zgodni": sas_ok, "pierwsza_roznica": pierwszy,
		"zrodlo": str(c.diagnostyka()["graf_zrodlo"]), "klasyfikacja": kl}
	print(JSON.stringify(wynik))
	if _arg("wynik", "") != "":
		var f := FileAccess.open(_arg("wynik", ""), FileAccess.WRITE); f.store_string(JSON.stringify(wynik))
	quit(0)
