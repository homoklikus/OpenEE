extends SceneTree
## Etap 47 – zmiana grafu podsektorów po zniszczeniu budynku: Core (graf z SCN, śmierć obiektu → przebudowa sektora
## 0x4278C3) kontra odczyty gry `mapa_obszar` przed i po (pola okna: id podsektorów, przebiegi pól, punkty, sąsiedzi).
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/porownaj_zmiane_grafu.gd -- --scn=<.scn>
##         --przed=<ee_mapa/…_przed.json> --po=<ee_mapa/…_po.json> --obiekt=<id obiektu, hex> [--pelna=1] [--wynik=<.json>]

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


## Odczyt gry → {id: {pola, punkt, sasiedzi, rodzaj}} (tylko podsektory w oknie odczytu).
func _gra(plik: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(plik))
	var w := {}
	for s in d.get("podsektory", {}).get("podsektory", []):
		w[int(s["id"])] = {"pola": s["pola"].map(func(r): return [int(r[0]), int(r[1]), int(r[2])]),
			"punkt": [int(s["punkt_i32"][0]), int(s["punkt_i32"][1])],
			"sasiedzi": s["sasiedzi"].map(func(v): return int(v) if v != null else -1), "rodzaj": int(s["rodzaj"])}
	return {"okno": d.get("okno", [0, 0, 0, 0]), "graf": d.get("graf", {}), "podsektory": w}


func _core(c: Object, okno: Array) -> Dictionary:
	var w := {}
	for s in c.graf_okno(int(okno[0]), int(okno[1]), int(okno[2]), int(okno[3])):
		w[int(s["id"])] = {"pola": s["pola"], "punkt": s["punkt"], "sasiedzi": s["sasiedzi"], "rodzaj": int(s["rodzaj"])}
	return w


func _porownaj(g: Dictionary, k: Dictionary) -> Dictionary:
	var ids_g := g.keys(); ids_g.sort()
	var ids_k := k.keys(); ids_k.sort()
	var pola_ok := 0; var pkt_ok := 0; var sas_ok := 0; var rozn := []
	for i in ids_g:
		if not k.has(i):
			rozn.append("brak w Core: %d" % i); continue
		var a: Dictionary = g[i]; var b: Dictionary = k[i]
		var p1 := JSON.stringify(a["pola"]) == JSON.stringify(b["pola"])
		if p1: pola_ok += 1
		if a["punkt"] == b["punkt"]: pkt_ok += 1
		if a["sasiedzi"] == b["sasiedzi"]: sas_ok += 1
		if (not p1 or a["punkt"] != b["punkt"] or a["sasiedzi"] != b["sasiedzi"]) and rozn.size() < 8:
			rozn.append({"id": i, "gra": a, "core": b})
	for i in ids_k:
		if not g.has(i) and rozn.size() < 8: rozn.append("nadmiar w Core: %d" % i)
	return {"ids_gra": ids_g, "ids_core": ids_k, "ids_rowne": ids_g == ids_k, "pola_zgodne": pola_ok, "punkty_zgodne": pkt_ok,
		"sasiedzi_zgodni": sas_ok, "liczba": ids_g.size(), "roznice": rozn}


func _start() -> void:
	var c: Object = CoreCpp.nowa_symulacja()
	c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var Z = root.get_node("Zasoby")
	var s := ScenariuszEE.new()
	if not s.wczytaj(FileAccess.get_file_as_bytes(_arg("scn", ""))) or not s.czytaj_teren() or not s.czytaj_graczy(root.get_node("Konfiguracja").katalog_openee):
		print("BŁĄD SCN"); quit(1); return
	var rodz := {}
	for r0 in Z.tabela("dbterrain"):
		if int(r0["ID"]) >= 0 and int(r0["ID"]) < 256: rodz[int(r0["ID"])] = int(r0.get("Terrain family", 0))
	var t := s.teren
	c.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
	var m: Dictionary = ObiektyScnCore.wejscie(c, s, Z)
	var t0 := Time.get_ticks_usec()
	c.zbuduj_graf_z_wejscia(m, int(m.get("komorka", 19)))
	var t_pelny := Time.get_ticks_usec() - t0
	var przed := _gra(_arg("przed", ""))
	var po := _gra(_arg("po", ""))
	var wynik := {"przed": _porownaj(przed["podsektory"], _core(c, przed["okno"])), "graf_przed": c.stan_grafu(),
		"gra_przed": przed["graf"], "czas_budowy_us": t_pelny}
	if _arg("pelna", "") == "1": c.ustaw_przebudowe_pelna(true)
	var ob := _arg("obiekt", "0x5000ad0")
	if not c.usun_obiekt_mapy(ob.hex_to_int()):
		print("BRAK OBIEKTU ", ob); quit(1); return
	var t1 := Time.get_ticks_usec()
	c.takt(1)
	wynik["czas_przebudowy_us"] = Time.get_ticks_usec() - t1
	wynik["graf_po"] = c.stan_grafu()
	wynik["gra_po"] = po["graf"]
	wynik["po"] = _porownaj(po["podsektory"], _core(c, po["okno"]))
	print(JSON.stringify(wynik))
	if _arg("wynik", "") != "":
		var f := FileAccess.open(_arg("wynik", ""), FileAccess.WRITE); f.store_string(JSON.stringify(wynik, " "))
	quit(0)
