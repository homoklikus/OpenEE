extends SceneTree
## Porównanie liczbowe ruchu OpenEE z trajektoriami zmierzonymi w oryginalnym EE (etap 9) + pomiar wydajności.
## Ta sama mapa (scenariusz testowy etap9_pasy.scn – teren, budynki, drzewa), te same pozycje startowe jednostek co
## w pomiarze EE (pierwsza próbka trajektorii), punkt rozkazu odtworzony z końcowego układu EE (pierwszy rząd szyku),
## symulacja w stałym kroku. Metryki jak narzedzia/analiza_ruchu_ee.py: czas dojścia, droga, krętość, minimalna
## odległość par, rozstaw końcowy, odchyłka pozycji końcowych jednostek.
##   godot --headless --path godot --script res://narzedzia/porownanie_ruchu_ee.gd -- \
##     --scn=<etap9_pasy.scn> --uklad=<etap9_pasy.uklad.json> --ee=<katalog Testy_MCP/ee_ruch> [--wyj=wyniki/porownanie_ruchu_ee.json]

const PRZEBIEGI := ["e9_G2", "e9_G5", "e9_G10", "e9_G25", "e9_G35", "e9_MIX10", "e9_NAPRZ", "e9_BUD5", "e9_BROD10",
	"e9_kierB1", "e9_kierB2", "e9_kierB3", "e9_kierB4"]
const JEDNA_GRUPA := ["e9_MIX10"]     # w EE jedno zaznaczenie z kilku grup scenariusza – jeden rozkaz
const TYPY_BLOKUJACE := [1, 2, 24, 25, 29, 30]


func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % n): return a.split("=", true, 1)[1]
	return d


func _initialize() -> void:
	await process_frame
	var K = root.get_node("Konfiguracja"); var Z = root.get_node("Zasoby")
	var scn := ScenariuszEE.new()
	if not scn.wczytaj(FileAccess.get_file_as_bytes(_arg("scn", ""))) or not scn.czytaj_teren() \
			or not scn.czytaj_graczy(K.katalog_openee):
		push_error("nie wczytano scenariusza"); quit(1); return
	var obiekty := {}
	for o in Z.tabela("dbobjects"): obiekty[int(o.ID)] = o
	var klify: Array = []
	for r in Z.tabela("dbcliffterrain"):
		klify.append(int(r["Terrain ID"])); klify.append(int(r["Terrain ID#2"]))
	var mapa := MapaNawigacji.z_scenariusza(scn, klify, K.skala_wysokosci, 1)
	var budynki := 0
	for g in scn.gracze:
		for u in g.jednostki:
			if int(u.get("valid", 0)) == 0: continue
			var ob: Dictionary = obiekty.get(int(u.type), {})
			if not (int(ob.get("Unit type", -1)) in TYPY_BLOKUJACE): continue
			var p := UkladEE.pozycja_z_rekordu(u.get("transform", PackedByteArray()), int(u.get("X", 0)), int(u.get("Y", 0)))
			mapa.dodaj_przeszkode(p, 0.5 * float(ob.get("Size of collider", 0.5)), "tree" in String(ob.get("Name", "")).to_lower())
			budynki += 1
	var uklad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg("uklad", "")))
	var typ_id := {}
	for gn in uklad:
		for h in uklad[gn].id: typ_id[String(h)] = [int(uklad[gn].typ), String(gn)]
	var wynik := {"przeszkody": budynki, "przebiegi": {}, "wydajnosc": {}}
	for nazwa in PRZEBIEGI:
		var sciezka: String = _arg("ee", "").path_join(nazwa + ".json")
		if not FileAccess.file_exists(sciezka): continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sciezka))
		wynik.przebiegi[nazwa] = _porownaj(mapa, obiekty, typ_id, d, nazwa in JEDNA_GRUPA)
	for n in [10, 25, 50, 100]:
		wynik.wydajnosc[str(n)] = _wydajnosc(mapa, obiekty, n)
	var wyj: String = _arg("wyj", K.katalog_openee.path_join("wyniki/porownanie_ruchu_ee.json"))
	var f := FileAccess.open(wyj, FileAccess.WRITE); f.store_string(JSON.stringify(wynik, " ")); f.close()
	print(JSON.stringify(wynik))
	quit(0)


func _metryki(tr: Dictionary) -> Dictionary:
	# tr: id → [[t, x, y]] ; zwraca metryki grupy
	var ids := tr.keys(); ids.sort()
	var n := ids.size()
	var t_kon := 0.0; var droga := 0.0; var kret := 0.0; var nk := 0
	for i in ids:
		var v: Array = tr[i]
		var dr := 0.0; var t1 := 0.0
		for k in range(1, v.size()):
			var a := Vector2(v[k - 1][1], v[k - 1][2]); var b := Vector2(v[k][1], v[k][2])
			var s := a.distance_to(b); dr += s
			if s / maxf(float(v[k][0]) - float(v[k - 1][0]), 1e-6) > 0.03: t1 = float(v[k][0]) - float(v[0][0])
		t_kon = maxf(t_kon, t1); droga += dr
		var pr := Vector2(v[0][1], v[0][2]).distance_to(Vector2(v[-1][1], v[-1][2]))
		if pr > 0.5: kret += dr / pr; nk += 1
	var dmin := INF
	var m := 1 << 30
	for i in ids: m = mini(m, tr[i].size())
	for k in range(0, m, 2):
		for a in n:
			for b in range(a + 1, n):
				dmin = minf(dmin, Vector2(tr[ids[a]][k][1], tr[ids[a]][k][2]).distance_to(Vector2(tr[ids[b]][k][1], tr[ids[b]][k][2])))
	var roz := 0.0
	for a in ids:
		var mi := INF
		for b in ids:
			if a != b: mi = minf(mi, Vector2(tr[a][-1][1], tr[a][-1][2]).distance_to(Vector2(tr[b][-1][1], tr[b][-1][2])))
		if mi < INF: roz += mi
	return {"n": n, "czas_dojscia_s": snappedf(t_kon, 0.01), "droga_sr": snappedf(droga / n, 0.001),
		"kretosc_sr": snappedf(kret / maxi(nk, 1), 0.001), "min_odl_par": snappedf(dmin, 0.001) if n > 1 else null,
		"rozstaw_konc_sr": snappedf(roz / n, 0.001) if n > 1 else null}


func _porownaj(mapa: MapaNawigacji, obiekty: Dictionary, typ_id: Dictionary, d: Dictionary, jedna := false) -> Dictionary:
	var tr_ee := {}
	for k in d.trajektorie:
		if (d.trajektorie[k] as Array).size() > 1: tr_ee[k] = d.trajektorie[k]
	var ids := tr_ee.keys(); ids.sort()
	var n := ids.size()
	var sym := Symulacja.new(mapa)
	var mapa_id := {}
	for i in ids:
		var dj := JednostkaSym.DaneJednostki.new()
		dj.typ = int(typ_id.get(i, [32, ""])[0]); dj.pozycja = Vector2(tr_ee[i][0][1], tr_ee[i][0][2])
		dj.kurs = deg_to_rad(float(tr_ee[i][0][3]))
		var ob: Dictionary = obiekty.get(dj.typ, {})
		mapa_id[sym.dodaj_jednostke(dj, ob)] = i
	# osobny rozkaz dla każdej grupy scenariusza (np. dwie grupy naprzeciw siebie w teście NAPRZ)
	var grupy := {}
	for id in mapa_id:
		var gn: String = "wszystkie" if jedna else String(typ_id.get(mapa_id[id], [32, ""])[1])
		if not grupy.has(gn): grupy[gn] = []
		grupy[gn].append(id)
	var cele := []
	for gn in grupy:
		var gi: Array = grupy[gn]
		var g0 := Vector2.ZERO; var g1 := Vector2.ZERO; var od := 0.0
		for id in gi:
			var h: String = mapa_id[id]
			g0 += Vector2(tr_ee[h][0][1], tr_ee[h][0][2]); g1 += Vector2(tr_ee[h][-1][1], tr_ee[h][-1][2])
			od = maxf(od, sym.jednostki[id].rozmiar_szyku)
		g0 /= gi.size(); g1 /= gi.size()
		var rz := int(ceil(gi.size() / 5.0)) if gi.size() >= 5 else 1
		var cel := g1 + (g1 - g0).normalized() * ((rz - 1) * 0.5 * od) if gi.size() > 1 else g1
		sym.rozkaz_grupy(gi, cel)
		cele.append([gn, snappedf(cel.x, 0.01), snappedf(cel.y, 0.01)])
	var tr_oe := {}
	for id in mapa_id: tr_oe[mapa_id[id]] = [[0.0, sym.jednostki[id].pozycja.x, sym.jednostki[id].pozycja.y]]
	var t := 0.0
	var dt_probki := 0.2; var nast := dt_probki
	var t_maks := float(tr_ee[ids[0]][-1][0]) - float(tr_ee[ids[0]][0][0]) + 20.0
	var odrzucone := 0
	while t < t_maks:
		sym.krok(); t += Symulacja.KROK
		for e in sym.zdarzenia:
			if e.typ == "trasa_odrzucona": odrzucone += 1
		if t >= nast - 1e-6:
			nast += dt_probki
			for id in mapa_id: tr_oe[mapa_id[id]].append([t, sym.jednostki[id].pozycja.x, sym.jednostki[id].pozycja.y])
		var stoja := true
		for id in mapa_id:
			if sym.jednostki[id].w_ruchu(): stoja = false
		if stoja and t > 1.0: break
	var odch := 0.0; var odch_maks := 0.0
	for i in ids:
		var e := Vector2(tr_ee[i][-1][1], tr_ee[i][-1][2]).distance_to(Vector2(tr_oe[i][-1][1], tr_oe[i][-1][2]))
		odch += e * e; odch_maks = maxf(odch_maks, e)
	var tr_ee3 := {}
	for i in ids:
		var t0 := float(tr_ee[i][0][0])
		tr_ee3[i] = (tr_ee[i] as Array).map(func(p): return [float(p[0]) - t0, p[1], p[2]])
	return {"ee": _metryki(tr_ee3), "openee": _metryki(tr_oe), "cele": cele,
		"odchylka_konc_rms": snappedf(sqrt(odch / n), 0.001), "odchylka_konc_maks": snappedf(odch_maks, 0.001),
		"rozkazy_odrzucone": odrzucone}


func _wydajnosc(mapa: MapaNawigacji, obiekty: Dictionary, n: int) -> Dictionary:
	# grupa obywateli w otwartym terenie po stronie Capitolu; rozkaz na ok. 30 pól (z objazdami przeszkód)
	var sym := Symulacja.new(mapa)
	var ids: Array = []
	var ob: Dictionary = obiekty.get(32, {})
	var pol := PolitykaRuchu.z_obiektu(ob)
	var k := 0
	var p0 := Vector2(40.5, 95.5)
	while ids.size() < n and k < 2000:
		var p := p0 + Vector2(k % 10, k / 10)
		k += 1
		if not mapa.przechodnia(mapa.komorka(p), pol): continue
		var dj := JednostkaSym.DaneJednostki.new(); dj.typ = 32; dj.pozycja = p
		ids.append(sym.dodaj_jednostke(dj, ob))
	var t_takt := []
	var tp := Time.get_ticks_usec()
	sym.sciezki.przechodniosc(pol); sym.sciezki.skladowe(pol)       # pamięć podręczna mapy (raz na politykę)
	var przygotowanie := Time.get_ticks_usec() - tp
	sym.rozkaz_grupy(ids, Vector2(70.5, 75.5))
	var takty := 0
	var t0 := Time.get_ticks_usec()
	var maks := 0
	while takty < 3000:
		var a := Time.get_ticks_usec()
		sym.krok(); takty += 1
		var dt := Time.get_ticks_usec() - a
		maks = maxi(maks, dt); t_takt.append(dt)
		var stoja := true
		for id in ids:
			if sym.jednostki[id].w_ruchu(): stoja = false; break
		if stoja: break
	var cal := Time.get_ticks_usec() - t0
	t_takt.sort()
	return {"przygotowanie_mapy_us": przygotowanie, "jednostek": ids.size(), "taktow": takty, "takt_sr_us": cal / maxi(takty, 1), "takt_mediana_us": t_takt[t_takt.size() / 2],
		"takt_maks_us": maks, "trasy_us": sym.czas_tras_us, "zapytan_A*": sym.sciezki.statystyka.zapytania,
		"odwiedzone_A*": sym.sciezki.statystyka.odwiedzone, "budzet_taktu_us": int(Symulacja.KROK * 1e6),
		"rezerwa_krok_staly": snappedf(Symulacja.KROK * 1e6 / maxf(float(maks), 1.0), 0.1)}
