extends SceneTree
## Narzędzie diagnostyczne (naprawa grafiki 0.5.1): lista obiektów scenariusza z grafiką dbgraphics i pozycją –
## identyfikacja modelu widocznego na zrzucie na podstawie danych scenariusza (nie nazwy z wyglądu).
##   godot --headless --path godot --script res://narzedzia/obiekty_scenariusza.gd -- --kampania=EETheGreeks.ssa
##         "--scenariusz=trojan war" [--rodzaj=2] [--szukaj=tekst] [--wokol=x,z,promien]  → wyniki/obiekty_scenariusza.json

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	await process_frame
	var K = root.get_node("Konfiguracja"); var Z = root.get_node("Zasoby")
	var kamp := _arg("kampania", "EETheGreeks.ssa")
	var rel := ("Empire Earth/Data/Campaigns/" if kamp.to_lower().begins_with("ee") else "Empire Earth - The Art of Conquest/Data/Campaigns/") + kamp
	var a = Z.archiwum(K.zrodlo_gry, rel)
	var szuk := _arg("scenariusz", "trojan war").to_lower()
	var klucz := ""
	for k in a.wpisy:
		if k.ends_with(".scn") and szuk in k: klucz = k
	var scn := ScenariuszEE.new()
	if klucz == "" or not scn.wczytaj(a.czytaj(klucz)) or not scn.czytaj_graczy(K.katalog_openee):
		print("BŁĄD scenariusz: ", scn.blad); quit(1); return
	var obj := {}; var gra := {}
	for r in Z.tabela("dbobjects"): obj[int(r.ID)] = r
	for r in Z.tabela("dbgraphics"): gra[int(r.ID)] = r
	var rodzaj := int(_arg("rodzaj", "-1")); var tekst := _arg("szukaj", "").to_lower()
	var w := _arg("wokol", "").split(",")
	var lista: Array = []
	for g in scn.gracze.size():
		for u in scn.gracze[g].jednostki:
			var x := float(u.get("X", 0)) + 0.5; var z := float(u.get("Y", 0)) + 0.5
			var tr: PackedByteArray = u.get("transform", PackedByteArray())
			if tr.size() == 64: x = tr.decode_float(12); z = tr.decode_float(28)
			var ob: Dictionary = obj.get(int(u.type), {})
			var gr: Dictionary = gra.get(int(ob.get("Graphic ID", -1)), {})
			if rodzaj >= 0 and int(ob.get("Unit type", -1)) != rodzaj: continue
			var e := {"gracz": g, "typ": int(u.type), "obiekt": String(ob.get("Name", "?")), "rodzaj": int(ob.get("Unit type", -1)),
				"grafika_id": int(ob.get("Graphic ID", -1)), "grafika": String(gr.get("Name", "")),
				"model": String(gr.get("Model path", "")), "tekstura": String(gr.get("Texture path", "")),
				"x": snappedf(x, 0.01), "z": snappedf(z, 0.01), "skala": float(u.get("c174", 0.0))}
			if tekst != "" and not (tekst in (e.obiekt + "|" + e.grafika + "|" + e.model).to_lower()): continue
			if w.size() == 3 and Vector2(x, z).distance_to(Vector2(float(w[0]), float(w[1]))) > float(w[2]): continue
			lista.append(e)
	var p: String = K.katalog_openee.path_join("wyniki/obiekty_scenariusza.json")
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(JSON.stringify({"scenariusz": klucz, "obiekty": lista}, " ")); f.close()
	var licz := {}
	for e in lista:
		var k := "%s | %s | %s" % [e.obiekt, e.grafika, e.model]
		licz[k] = licz.get(k, 0) + 1
	for k in licz: print("%4d  %s" % [licz[k], k])
	print("razem: %d → %s" % [lista.size(), p])
	quit()
