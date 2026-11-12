extends SceneTree
## Etap 47 – wydajność grafu podsektorów w Core: budowa początkowa z SCN, przebudowa przyrostowa (0x4278C3, jeden sektor
## na przebieg) i pełna po usunięciu obiektów mapy, ścieżka grafu przed i po. Obiekty wybierane deterministycznie
## (budynki SCN w kolejności rekordów, co n-ty) – żadnych wyjątków dla współrzędnych.
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/wydajnosc_grafu.gd -- --scn=<.scn>
##         [--obiektow=10] [--trasa=x0,y0,x1,y1] [--wynik=<.json>]

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _swiat(s: ScenariuszEE, Z: Object, rodz: Dictionary) -> Array:
	var c: Object = CoreCpp.nowa_symulacja()
	c.uzyj_tablic_przyblizonych()
	c.utworz_swiat("ee")
	var t := s.teren
	c.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
	var m: Dictionary = ObiektyScnCore.wejscie(c, s, Z)
	var t0 := Time.get_ticks_usec()
	c.zbuduj_graf_z_wejscia(m, int(m.get("komorka", 19)))
	return [c, Time.get_ticks_usec() - t0]


func _trasa(c: Object, tr: PackedStringArray) -> Dictionary:
	if tr.size() != 4: return {}
	var t0 := Time.get_ticks_usec()
	var p: Array = c.sciezka_grafu(int(tr[0]), int(tr[1]), int(tr[2]), int(tr[3]))
	return {"us": Time.get_ticks_usec() - t0, "podsektorow": p.size()}


func _start() -> void:
	var Z = root.get_node("Zasoby")
	var s := ScenariuszEE.new()
	if not s.wczytaj(FileAccess.get_file_as_bytes(_arg("scn", ""))) or not s.czytaj_teren() or not s.czytaj_graczy(root.get_node("Konfiguracja").katalog_openee):
		print("BŁĄD SCN"); quit(1); return
	var rodz := {}
	for r0 in Z.tabela("dbterrain"):
		if int(r0["ID"]) >= 0 and int(r0["ID"]) < 256: rodz[int(r0["ID"])] = int(r0.get("Terrain family", 0))
	var kand := []
	for o in ObiektyScnCore.obiekty(s, Z):
		if int(o["budynek"]) != 0 or int(o["zasob"]) != 0: kand.append(int(o["id"]))
	var n := int(_arg("obiektow", "10"))
	var krok := maxi(1, int(kand.size() / float(maxi(1, n))))
	var tr := _arg("trasa", "").split(",", false)
	var wynik := {"scn": _arg("scn", "").get_file(), "kandydatow": kand.size()}
	for tryb in ["przyrostowa", "pelna"]:
		var cw := _swiat(s, Z, rodz)
		var c: Object = cw[0]
		var w := {"budowa_us": cw[1], "graf": c.stan_grafu(), "trasa_przed": _trasa(c, tr)}
		if tryb == "pelna": c.ustaw_przebudowe_pelna(true)
		var lista := []; var suma := 0; var taktow := 0; var maks := 0
		var i := 0
		while i < kand.size() and lista.size() < n:
			var id: int = kand[i]
			i += krok
			if not c.usun_obiekt_mapy(id): continue
			var st0: Dictionary = c.stan_grafu()
			var us := 0; var k := 0
			while k < 400:
				var t0 := Time.get_ticks_usec()
				c.takt(1)
				var d := Time.get_ticks_usec() - t0
				us += d; maks = maxi(maks, d); k += 1
				var st: Dictionary = c.stan_grafu()
				if not bool(st.get("d8", false)) and int(st.get("zmienione_sektory", 0)) == 0: break
			var st1: Dictionary = c.stan_grafu()
			lista.append({"id": "0x%x" % id, "taktow": k, "us": us,
				"przebiegi": int(st1.get("przebudowy_sektorow", 0)) - int(st0.get("przebudowy_sektorow", 0)),
				"pelne": int(st1.get("przebudowy_grafu", 0)) - int(st0.get("przebudowy_grafu", 0)),
				"podsektorow": st1.get("podsektorow", 0)})
			suma += us; taktow += k
		w["zmiany"] = lista
		w["suma_us"] = suma; w["taktow"] = taktow; w["maks_takt_us"] = maks
		w["graf_po"] = c.stan_grafu(); w["trasa_po"] = _trasa(c, tr)
		var go: Array = c.graf_okno(0, 4095, 0, 4095)
		w["skrot_grafu"] = JSON.stringify(go).sha256_text().substr(0, 16)
		# podział pól na podsektory bez numeracji (id, sąsiedzi) – porównanie trybu przyrostowego z pełnym
		var podz := []
		for e in go: podz.append(JSON.stringify([e["rodzaj"], e["pola"], e["punkt"]]))
		podz.sort()
		w["skrot_podzialu"] = JSON.stringify(podz).sha256_text().substr(0, 16)
		wynik[tryb] = w
	print(JSON.stringify(wynik))
	if _arg("wynik", "") != "":
		var f := FileAccess.open(_arg("wynik", ""), FileAccess.WRITE); f.store_string(JSON.stringify(wynik, " "))
	quit(0)
