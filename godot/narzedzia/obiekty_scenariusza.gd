extends SceneTree
## Narzędzie diagnostyczne (naprawa grafiki 0.5.1): lista obiektów scenariusza z grafiką dbgraphics i pozycją –
## identyfikacja modelu widocznego na zrzucie na podstawie danych scenariusza (nie nazwy z wyglądu).
##   godot --headless --path godot --script res://narzedzia/obiekty_scenariusza.gd -- --kampania=EETheGreeks.ssa
##         "--scenariusz=trojan war" (albo * – wszystkie) [--rodzaj=2] [--szukaj=tekst] [--wokol=x,z,promien]
##         albo --plik-scn=<ścieżka.scn> (pojedynczy plik z dysku); w wyniku także pole, id, kurs_st i elementy macierzy R  → wyniki/obiekty_scenariusza.json

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	await process_frame
	var K = root.get_node("Konfiguracja"); var Z = root.get_node("Zasoby")
	var kamp := _arg("kampania", "EETheGreeks.ssa")
	var ak: Dictionary = GryEE.archiwum_kampanii(K.gra, kamp, K.instalacja_ee, K.katalog_openee)   # etap 11: kampania wybranej gry
	var rel: String = ak.get("rel", "")
	if ak.has("blad") and _arg("plik-scn", "") == "":
		printerr(ak.blad); quit(1); return
	var plik_scn := _arg("plik-scn", "")
	var a = null if plik_scn != "" else Z.archiwum(K.zrodlo_gry, rel)
	var szuk := _arg("scenariusz", "trojan war").to_lower()
	var obj := {}; var gra := {}
	for r in Z.tabela("dbobjects"): obj[int(r.ID)] = r
	for r in Z.tabela("dbgraphics"): gra[int(r.ID)] = r
	var rodzaj := int(_arg("rodzaj", "-1")); var tekst := _arg("szukaj", "").to_lower()
	var w := _arg("wokol", "").split(",")
	var lista: Array = []
	var klucz := ""
	var wpisy: Array = [plik_scn] if plik_scn != "" else Array(a.wpisy.keys())
	for k in wpisy:
		if plik_scn == "" and (not k.ends_with(".scn") or not (szuk == "*" or szuk in k)): continue
		klucz = k
		var scn := ScenariuszEE.new()
		var dane: PackedByteArray = FileAccess.get_file_as_bytes(k) if plik_scn != "" else a.czytaj(k)
		if not scn.wczytaj(dane) or not scn.czytaj_graczy(K.katalog_openee):
			print("BŁĄD scenariusz %s: %s" % [k, scn.blad]); continue
		for g in scn.gracze.size():
			for u in scn.gracze[g].jednostki:
				var tr: PackedByteArray = u.get("transform", PackedByteArray())
				var pm := UkladEE.pozycja_z_rekordu(tr, int(u.get("X", 0)), int(u.get("Y", 0)))
				var x := pm.x; var z := pm.y      # punkt mapy EE (kolumna, wiersz)
				var ob: Dictionary = obj.get(int(u.type), {})
				var gr: Dictionary = gra.get(int(ob.get("Graphic ID", -1)), {})
				if rodzaj >= 0 and int(ob.get("Unit type", -1)) != rodzaj: continue
				var e := {"scenariusz": k, "gracz": g, "typ": int(u.type), "obiekt": String(ob.get("Name", "?")), "rodzaj": int(ob.get("Unit type", -1)),
					"grafika_id": int(ob.get("Graphic ID", -1)), "grafika": String(gr.get("Name", "")),
					"model": String(gr.get("Model path", "")), "tekstura": String(gr.get("Texture path", "")),
					"x": snappedf(x, 0.01), "z": snappedf(z, 0.01), "skala": float(u.get("c174", 0.0)),
					"pole": [int(u.get("X", 0)), int(u.get("Y", 0))], "id": int(u.get("id", -1)),
					"kurs_st": snappedf(rad_to_deg(UkladEE.kat_z_R(UkladEE.R_z_rekordu(tr))), 0.01) if tr.size() == 64 else null,
					"R": [snappedf(tr.decode_float(0), 0.0001), snappedf(tr.decode_float(4), 0.0001), snappedf(tr.decode_float(16), 0.0001), snappedf(tr.decode_float(20), 0.0001), snappedf(tr.decode_float(40), 0.0001)] if tr.size() == 64 else null}
				if tekst != "" and not (tekst in (e.obiekt + "|" + e.grafika + "|" + e.model).to_lower()): continue
				if w.size() == 3 and Vector2(x, z).distance_to(Vector2(float(w[0]), float(w[1]))) > float(w[2]): continue
				lista.append(e)
		if szuk != "*": break
	var p: String = K.katalog_openee.path_join("wyniki/obiekty_scenariusza.json")
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(JSON.stringify({"scenariusz": klucz, "obiekty": lista}, " ")); f.close()
	var licz := {}
	for e in lista:
		var k := "%s | %s | %s | %s" % [e.scenariusz.get_file(), e.obiekt, e.grafika, e.model]
		licz[k] = licz.get(k, 0) + 1
	for k in licz: print("%4d  %s" % [licz[k], k])
	print("razem: %d → %s" % [lista.size(), p])
	quit()
