extends SceneTree
## Statystyka geometrii wszystkich modeli z dbgraphics (OpenEE 0.5.1, diagnostyka): spójność nawinięcia trójkątów
## z normalnymi wierzchołków, pary współpłaszczyznowe (zwrot przeciwny = ściana dwustronna z dwóch trójkątów;
## zwrot zgodny = nakładka), duplikaty, trójkąty „player color” nad alfa = 0. Podstawa decyzji o odrzucaniu tylnych
## ścian i wycinaniu alfa w materiale koloru gracza (raporty/archiwum/RAPORT_DIAGNOSTYKA_MODELI_051.md).
##   godot --headless --path godot --script res://narzedzia/statystyka_geometrii.gd [-- --limit=N]
##   → wyniki/statystyka_geometrii.json

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	await process_frame
	var K = root.get_node("Konfiguracja"); var Z = root.get_node("Zasoby")
	var limit := int(_arg("limit", "100000"))
	var wid := {}
	var s := {"modele": 0, "trojkaty": 0, "nawiniecie_zgodne": 0, "nawiniecie_ocenione": 0, "modele_niespojne": [],
		"pary_przeciwne_ten_sam_mat": 0, "pary_przeciwne_rozne": 0, "pary_zgodne_ten_sam_mat": 0, "pary_zgodne_rozne": 0,
		"trojkaty_w_parach_przeciwnych": 0, "modele_z_parami_przeciwnymi": 0, "duplikaty": 0,
		"pc_trojkaty": 0, "pc_alfa0": 0, "pc_alfa0_modele": 0, "zwykle_trojkaty": 0, "zwykle_alfa0": 0,
		"pc_zgodne_nakladki_na_inny_material": 0}
	var t0 := Time.get_ticks_msec()
	for r in Z.tabela("dbgraphics"):
		var mp := String(r.get("Model path", "")).to_lower().replace("\\", "/")
		var tp := String(r.get("Texture path", "")).to_lower().replace("\\", "/")
		if mp == "" or tp == "" or wid.has(mp + "|" + tp): continue
		wid[mp + "|" + tp] = true
		if s.modele >= limit: break
		var m: ModelCEM = Z.wczytaj_model_cem(mp + ".cem")
		if m == null or m.blad != "": continue
		s.modele += 1
		var tr := DiagnostykaModelu.trojkaty(m, 0)
		s.trojkaty += tr.size()
		var nw := DiagnostykaModelu.zgodnosc_nawiniecia(tr)
		s.nawiniecie_zgodne += nw.zgodne; s.nawiniecie_ocenione += nw.trojkaty
		if nw.trojkaty > 0 and nw.udzial > 0.02 and nw.udzial < 0.98: s.modele_niespojne.append([mp, snappedf(nw.udzial, 0.01)])
		var w := DiagnostykaModelu.wspolplaszczyznowe(tr)
		s.duplikaty += w.duplikaty.size()
		var wtr := {}
		for p in w.pary:
			var A: Dictionary = tr[p[0]]; var B: Dictionary = tr[p[1]]
			var ten: bool = A.czesc == B.czesc and A.material == B.material
			if p[2] == "przeciwne":
				if ten: s.pary_przeciwne_ten_sam_mat += 1
				else: s.pary_przeciwne_rozne += 1
				wtr[p[0]] = true; wtr[p[1]] = true
			else:
				if ten: s.pary_zgodne_ten_sam_mat += 1
				else:
					s.pary_zgodne_rozne += 1
					if A.nazwa_mat == "player color" or B.nazwa_mat == "player color": s.pc_zgodne_nakladki_na_inny_material += 1
		s.trojkaty_w_parach_przeciwnych += wtr.size()
		if not wtr.is_empty(): s.modele_z_parami_przeciwnymi += 1
		var obr: Array = Z.wczytaj_tekstury(tp)
		var mial := false
		for t in tr:
			var mt: Dictionary = m.czesci[t.czesc].materialy[t.material]
			var nr: int = mini(int(mt.get("tekstura_id", 0)), obr.size() - 1)
			var a: int = DiagnostykaModelu.alfa_w_srodku(obr[nr] if nr >= 0 else null, t)
			if t.nazwa_mat == "player color":
				s.pc_trojkaty += 1
				if a == 0: s.pc_alfa0 += 1; mial = true
			else:
				s.zwykle_trojkaty += 1
				if a == 0: s.zwykle_alfa0 += 1
		if mial: s.pc_alfa0_modele += 1
	s["nawiniecie_udzial_zgodnych"] = float(s.nawiniecie_zgodne) / maxi(s.nawiniecie_ocenione, 1)
	s["czas_s"] = (Time.get_ticks_msec() - t0) / 1000.0
	s.modele_niespojne = s.modele_niespojne.slice(0, 30)
	var p: String = K.katalog_openee.path_join("wyniki/statystyka_geometrii.json")
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(JSON.stringify(s, " ")); f.close()
	print(JSON.stringify(s, " "))
	quit()
