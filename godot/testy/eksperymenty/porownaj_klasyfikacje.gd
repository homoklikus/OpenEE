extends SceneTree
## Etap 44: klasyfikacja pól z SCN w Core (MapaTitan::rodzaj_pol_titan) kontra odczyt gry (regiony_wejscie z Riverlands_MCP).
## Użycie: godot --headless --path godot --script res://testy/eksperymenty/porownaj_klasyfikacje.gd -- \
##   --scn=PLIK.scn --rodziny=rodziny.json --wejscie=regiony_wejscie.json [--wyjscie=roznice.json]
## Dane gry i scenariusze zostają lokalnie.

func _initialize() -> void:
	process_frame.connect(_praca, CONNECT_ONE_SHOT)

func _opcje() -> Dictionary:
	var o := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var p := a.substr(2).split("=", true, 1)
			o[p[0]] = p[1]
	return o

func _praca() -> void:
	var o := _opcje()
	var s := ScenariuszEE.new()
	if not s.wczytaj(FileAccess.get_file_as_bytes(o["scn"])) or not s.czytaj_teren():
		print("BLAD SCN ", s.blad); quit(1); return
	var rodz := {}
	var rj = JSON.parse_string(FileAccess.get_file_as_string(o["rodziny"]))
	for k in rj: rodz[int(k)] = int(rj[k])
	var t: Dictionary = s.teren
	var c: Object = CoreCpp.nowa_symulacja()
	c.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], rodz)
	var m: Dictionary = c.wejscie_regionow_z_mapy()
	var N := int(m["N"])
	var wyn := {"N": N, "zrodlo": m.get("zrodlo", ""), "pola": 0}
	if o.has("wejscie"):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(o["wejscie"]))
		var zr := 0; var n := 0; var zw := 0; var nw := 0; var zwv := 0
		var roz := []
		for i in m["rodzaj_pola"].size():
			var g0 := int(d["rodzaj_pola"][i])
			if g0 == -1: continue
			n += 1
			var k := int(m["rodzaj_pola"][i])
			if k == g0: zr += 1
			else: roz.append([i / N, i % N, g0, k])
			if g0 == 1 or g0 == 10:
				nw += 1
				if signi(int(m["bajt14"][i])) == signi(int(d["bajt14"][i])): zw += 1
				if int(m["bajt14"][i]) == int(d["bajt14"][i]): zwv += 1
		wyn.merge({"pola": n, "zgodne": zr, "roznice": roz, "woda": nw, "znak14": zw, "wartosc14": zwv})
		print("rodzaj %d/%d, znak +0x14 %d/%d, wartość %d" % [zr, n, zw, nw, zwv])
	else:
		var hist := {}
		for v in m["rodzaj_pola"]:
			hist[int(v)] = hist.get(int(v), 0) + 1
		wyn["histogram"] = hist
		print("histogram ", hist)
	wyn["rodzaj_pola"] = m["rodzaj_pola"]
	if o.has("wyjscie"):
		var f := FileAccess.open(o["wyjscie"], FileAccess.WRITE); f.store_string(JSON.stringify(wyn)); f.close()
	quit(0)
