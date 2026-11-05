class_name TestyEtapu4
extends RefCounted
## Testy etapu 4: animacje CEM, hierarchia części, odtwarzanie, VAT, integracja ze scenariuszami.
## Jednostkowe (syntetyczne modele z CEMSyntetyczny) – bez danych komercyjnych; integracyjne – instalacja EE.

var t   # uruchom_testy.gd (_ok, _pomin, _scn, _json)
const E := 0.002


func _init(runner) -> void:
	t = runner


func _blisko(a: Vector3, b: Vector3, e: float = E) -> bool:
	return a.distance_to(b) <= e


func _tri() -> PackedInt32Array:
	return PackedInt32Array([0, 1, 2])


## Model testowy: korzeń 3 klatki (animacja wierzchołkowa) + dziecko 3 klatki (obrót wokół X CEM 0°, 90°, 180°,
## przesunięcie (0, 0, 1)) + wnuk 1 klatka (przesunięcie (0, 1, 0) – nieprzemienne z obrotem wokół X).
func _model_testowy() -> PackedByteArray:
	var kl: Array = []
	for f in 3:
		kl.append(PackedVector3Array([Vector3(f, 0, 0), Vector3(0, 1 + f, 0), Vector3(0, 0, 2)]))
	var wnuk := CEMSyntetyczny.model("wnuk", [PackedVector3Array([Vector3.ZERO, Vector3(0, 0.1, 0), Vector3(0, 0, 0.1)])],
		[CEMSyntetyczny.obrot_z(0, Vector3(0, 1, 0))], _tri(), [], {}, "", "tex_w")
	var pd := PackedVector3Array([Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0)])
	var dziecko := CEMSyntetyczny.model("turret_0", [pd, pd, pd],
		[CEMSyntetyczny.obrot_x(0, Vector3(0, 0, 1)), CEMSyntetyczny.obrot_x(90, Vector3(0, 0, 1)), CEMSyntetyczny.obrot_x(180, Vector3(0, 0, 1))],
		_tri(), [wnuk], {}, "", "tex_d")
	return CEMSyntetyczny.model("korzen", kl, [], _tri(), [dziecko], {"attack": [Vector3(0, -1, 1), Vector3(0, -1, 1), Vector3(0, -2, 1)]})


var _koniec_jedn := false
var _koniec_integr := false


func uruchom(K, Z) -> void:
	_jednostkowe()
	# błąd skryptu przerywa funkcję bez wyjątku – brak dojścia do końca liczymy jako błąd (nie jako pominięcie)
	t._ok("E4 testy jednostkowe wykonane do końca (bez błędu skryptu)", _koniec_jedn)
	if not K.instalacje.has("referencyjna") or not Z.gotowe:
		t._pomin(["E4 dane: falanga – 75 klatek, sekwencje dbgraphics pokrywają model",
			"E4 dane: armata 12-funtowa – koła dotykają ziemi (osie i przesunięcie z macierzy części)",
			"E4 dane: trebusz i AA Gun 88 – części potomne animowane macierzą",
			"E4 woda: 16 klatek animacji (dbterrain 16×1, Animated), tempo z rekordu wody [H]",
			"E4 dane: ModelCEM (GDScript) = czytnik Pythona – klatki i części (próbka modeli)",
			"E4 dane: wszystkie sekwencje dbgraphics w zakresie modeli (poza znanymi błędami danych)",
			"E4 scenariusze: Troja (EE) i Rzym (AoC) – animowane jednostki z poprawnymi zakresami, obiekty nie znikają"],
			"brak instalacji EE")
		return
	await _integracyjne(K, Z)
	t._ok("E4 testy integracyjne wykonane do końca (bez błędu skryptu)", _koniec_integr)


func _jednostkowe() -> void:
	var m := ModelCEM.z_danych(_model_testowy())
	# --- dekodowanie klatek ---
	var ok := m.blad == "" and m.klatki == 3 and m.czesci.size() == 3 and m.reszta_bajtow == 0
	var p0 := m.czesci[0].pozycje as Array if ok else []
	ok = ok and _blisko(p0[2][0], Vector3(2, 0, 0)) and _blisko(p0[1][1], Vector3(0, 0, -2)) and _blisko(p0[0][2], Vector3(0, 2, 0))
	t._ok("E4 CEM: dekodowanie klatek animacji wierzchołkowej (syntetyczny, oś Z→Y)", ok and m.czesci[0].animacja_wierzcholkowa
		and not m.czesci[2].animacja_wierzcholkowa and m.kontrola().is_empty(), [m.blad, m.klatki, m.czesci.size(), m.kontrola()])
	t._ok("E4 CEM: hierarchia odczytana (rodzic przed dzieckiem, klatki części)",
		m.czesci[1].rodzic == 0 and m.czesci[2].rodzic == 1 and m.czesci[1].klatki == 3 and m.czesci[2].klatki == 1
		and m.czesci[1].macierz_zmienna and ModelCEM.rodzaj_czesci("turret_0") == "wiezyczka", m.drzewo())
	# --- transformacja lokalna: dziecko przesunięte o (0,0,1) CEM = (0,1,0) Godot; wierzchołek (0,1,0) CEM ---
	var c0 := m.pozycje_modelu(1, 0)
	t._ok("E4 hierarchia: lokalna transformacja części (przesunięcie z elementów 3/7/11, oś Z CEM → Y)",
		_blisko(c0[0], Vector3(0, 1, -1)) and _blisko(c0[1], Vector3(0, 1, 0)), c0)
	# klatka 1: obrót 90° wokół X CEM: (0,1,0) → (0,0,1) + (0,0,1) = (0,0,2) CEM → Godot (0,2,0)
	var c1 := m.pozycje_modelu(1, 1)
	t._ok("E4 hierarchia: obrót części z macierzy klatki (kierunek i oś)", _blisko(c1[0], Vector3(0, 2, 0)), c1)
	# wnuk: v' = T_dziecko(k) · T_wnuk · v; klatka 1: 0 → (0,1,0) → obrót 90° X → (0,0,1) → +(0,0,1) = (0,0,2) CEM
	# = (0,2,0) Godot; kolejność odwrotna (T_wnuk · T_dziecko) dałaby (0,1,1) CEM = (0,1,−1) – test wykrywa zamianę
	var w1 := m.pozycje_modelu(2, 1)
	t._ok("E4 hierarchia: dziedziczenie T = T_rodzic · T_lokalna (wnuk, klatka statyczna wnuka)",
		_blisko(w1[0], Vector3(0, 2, 0)) and _blisko(w1[1], Vector3(0, 2.1, 0)), [w1[0], w1[1]])
	# interpolacja obrotu: klatki 0→1, udział 0,5 → 45°
	var gi := m.globalna_interp(1, 0, 1, 0.5)
	var v45 := gi * Vector3(0, 0, -1)       # (0,1,0) CEM
	t._ok("E4 hierarchia: interpolacja transformacji części (obrót sferyczny 45°)",
		_blisko(v45, Vector3(0, 1.0 + sin(PI / 4), -cos(PI / 4))), v45)
	# tag w układzie modelu
	var tg := m.tag("attack", 2)
	t._ok("E4 CEM: punkt tag z klatki (attack, klatka 2)", tg.size() == 2 and _blisko(tg[1], Vector3(0, 1, 2)), tg)
	# nieprawidłowa referencja
	var m2 := ModelCEM.z_danych(_model_testowy())
	m2.czesci[2].rodzic = 7
	var g2 := m2.globalna(2, 0)
	t._ok("E4 hierarchia: nieprawidłowa referencja rodzica – bez awarii, zgłoszona w kontroli",
		g2.is_equal_approx(m2.lokalna(2, 0)) and not m2.kontrola().is_empty(), m2.kontrola())
	var zly := ModelCEM.z_danych(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9]))
	t._ok("E4 CEM: uszkodzone dane → błąd, nie awaria", zly.blad != "", zly.blad)
	# --- sekwencje z rekordu dbgraphics ---
	var uklad: Array = JSON.parse_string(FileAccess.get_file_as_string(
		t.root.get_node("Konfiguracja").katalog_openee.path_join("dane/uklad_db.json"))).tabele.dbgraphics
	var rek := CEMSyntetyczny.rekord_dbgraphics(uklad, {
		0: [[1, 16, 31, 120, 1, 50000]], 1: [[256, 0, 15, 65, 1, 0]], 2: [[257, 32, 47, 100, 1, 7500]],
		3: [[256, 32, 47, 120, 1, 5000]], 4: [[256, 48, 74, 78, 0, 0], [256, 74, 74, 0, 0x6C0101, 0], [256, 0, 0, 0, 0, 0]]},
		{0: [26, 0], 1: [8, 15]}, {0: [54, -1], 1: [39, 83]})
	var s := SekwencjeAnimacji.z_rekordu(rek)
	var at := s.dla_stanu("atak"); var ru := s.dla_stanu("ruch"); var sm := s.dla_stanu("smierc"); var ps := s.dla_stanu("po_smierci_1")
	t._ok("E4 sekwencje: gniazda dbgraphics → zakresy klatek, pętla, zdarzenia i dźwięki",
		s.blad == "" and at.od == 16 and at.do == 31 and at.klatki == 16 and at.petla and at.zdarzenia == [26] and at.dzwieki == [54]
		and ru.zdarzenia == [8, 15] and ru.dzwieki == [39, 83] and s.bezczynnosc().od == 32 and s.bezczynnosc().gniazdo == 2
		and sm.klatki == 27 and not sm.petla and ps.od == 74 and ps.petla and s.sekwencje.size() == 6, s.sekwencje.map(func(q): return [q.gniazdo, q.stan, q.od, q.do]))
	t._ok("E4 sekwencje: czas cyklu = wartość × 0,01 s [H], tempo = klatki / czas",
		is_equal_approx(at.czas_cyklu, 1.2) and is_equal_approx(sm.czas_cyklu, 0.78) and is_equal_approx(at.klatki_na_s, 16 / 1.2), [at.czas_cyklu, at.klatki_na_s])
	t._ok("E4 sekwencje: kontrola zakresów wobec liczby klatek modelu", s.kontrola(75).is_empty() and s.kontrola(60).size() == 2, s.kontrola(60))
	# --- interpolacja / wybór klatek ---
	var k1 := AnimacjaVAT.klatki_dla(Vector4(32, 16, 0, 16), 0.5)
	var k2 := AnimacjaVAT.klatki_dla(Vector4(32, 16, 0, 16), 0.99375)
	var k3 := AnimacjaVAT.klatki_dla(Vector4(48, -27, 0, 10), 5.0)
	var k4 := AnimacjaVAT.klatki_dla(Vector4(48, -27, 0, 10), 1.25)
	t._ok("E4 interpolacja: pętla zawija ostatnią klatkę do pierwszej, jednorazowa zatrzymuje się na ostatniej",
		k1.is_equal_approx(Vector3(40, 41, 0)) and k2.x == 47 and k2.y == 32 and absf(k2.z - 0.9) < 1e-3
		and k3.is_equal_approx(Vector3(74, 74, 0)) and k4.x == 60 and k4.y == 61 and absf(k4.z - 0.5) < 1e-3, [k1, k2, k3, k4])
	var a := AnimacjaVAT.wypiecz(m, {})
	var pa := m.pozycje_modelu(0, 0)[0]; var pb := m.pozycje_modelu(0, 1)[0]
	var pv := a.pozycja_cpu(0, Vector4(0, 3, 0.5, 0), 0.0)
	var pd := a.pozycja_cpu(3, Vector4(0, 3, 1.0, 0), 0.0)     # wierzchołek 0 dziecka (offset 3), klatka 1
	var pn := a.pozycja_cpu(0, Vector4(0, 3, 0.5, 0), 0.0, false)
	t._ok("E4 interpolacja: VAT = liniowa interpolacja klatek ModelCEM (z hierarchią części)",
		a.wierzcholki == 9 and a.klatki == 3 and _blisko(pv, pa.lerp(pb, 0.5)) and _blisko(pd, m.pozycje_modelu(1, 1)[0]) and _blisko(pn, pa),
		[pv, pa.lerp(pb, 0.5), pd, pn])
	# --- odtwarzanie: niezależne instancje ---
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true; mm.instance_count = 3
	var o := OdtwarzaczAnimacji.new()
	var q := {"od": 32, "klatki": 16, "klatki_na_s": 16.0, "petla": true}
	var c_0 := o.dodaj(mm, 0); var c_1 := o.dodaj(mm, 1)
	o.odtworz(c_0, q, 0.0); o.odtworz(c_1, q, 5.0)
	o.krok(0.5)
	var f0 := o.faza(c_0); var f1 := o.faza(c_1)
	o.pauza(c_0, true); o.krok(0.5)
	var f0p := o.faza(c_0); var kk1 := o.klatki(c_1)
	o.ustaw_predkosc(c_1, 2.0); var f1a := o.faza(c_1); o.krok(0.25)
	var cd := mm.get_instance_custom_data(c_1); var st := o.stan(c_1)
	t._ok("E4 odtwarzanie: niezależne instancje – faza, pauza, prędkość (bez skoku fazy)",
		is_equal_approx(f0, 8.0) and is_equal_approx(f1, 13.0) and is_equal_approx(f0p, 8.0) and kk1.x == 32 + 5
		and is_equal_approx(o.faza(c_1) - f1a, 8.0),
		[f0, f1, f0p, kk1, o.faza(c_1) - f1a, cd, st])
	o.pauza(c_0, false)
	o.odtworz(c_0, {"od": 0, "klatki": 16, "klatki_na_s": 24.6, "petla": true}, 0.0)
	var ka := o.klatki(c_0); o.krok(0.3); var kb := o.klatki(c_0)
	o.odtworz(c_0, {"od": 48, "klatki": 27, "klatki_na_s": 34.6, "petla": false}, 0.0); o.krok(5.0)
	t._ok("E4 odtwarzanie: przełączanie animacji (nowy zakres od fazy 0, jednorazowa kończy na ostatniej klatce)",
		ka.x == 0 and kb.x >= 0 and kb.x <= 15 and o.klatki(c_0).x == 74 and o.sekwencja(c_0).od == 48, [ka, kb, o.klatki(c_0)])
	# --- kolory graczy ---
	var a2 := AnimacjaVAT.wypiecz(ModelCEM.z_danych(_model_testowy()), {"kolor_gracza": Color(0.2, 0.4, 0.9)})
	var smm := a2.siatka_multimesh()
	var okk := a2.materialy.size() == a2.siatka.get_surface_count() and a2.siatka.get_surface_count() == 3
	for i in a2.siatka.get_surface_count():
		var mo: ShaderMaterial = a2.siatka.surface_get_material(i); var mmo: ShaderMaterial = smm.surface_get_material(i)
		okk = okk and not mo.get_shader_parameter("z_multimesh") and mmo.get_shader_parameter("z_multimesh") == true
		okk = okk and (mo.get_shader_parameter("kolor_gracza") as Color).is_equal_approx(Color(0.2, 0.4, 0.9))
	t._ok("E4 kolory graczy: uniform w MeshInstance, kolor instancji w MultiMesh, ta sama formuła co modele statyczne",
		okk and "mix(v_kolor, t.rgb, t.a)" in AnimacjaVAT.SHADER and "mix(kolor_gracza.rgb, t.rgb, t.a)" in ImporterModeli.SHADER_MODELU, okk)
	# --- statyczne: części potomne na miejscu ---
	var mesh: ArrayMesh = ImporterModeli.new().importuj(_model_testowy(), {"klucz": "syntetyczny"})
	var v1: PackedVector3Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] if mesh and mesh.get_surface_count() == 3 else PackedVector3Array()
	t._ok("E4 statyczne: części potomne w transformacji z hierarchii (wcześniej w środku modelu)",
		v1.size() == 3 and _blisko(v1[0], Vector3(0, 1, -1)), v1)
	# --- wydajność odtwarzania ---
	var mmw := MultiMesh.new(); mmw.transform_format = MultiMesh.TRANSFORM_3D; mmw.use_custom_data = true; mmw.instance_count = 2000
	var ow := OdtwarzaczAnimacji.new()
	var t0 := Time.get_ticks_usec()
	for i in 2000: ow.odtworz(ow.dodaj(mmw, i), q, float(i % 16))
	var t1 := Time.get_ticks_usec()
	for i in 2000: ow.odtworz(i, {"od": 0, "klatki": 16, "klatki_na_s": 24.6, "petla": true}, 0.0)
	var t2 := Time.get_ticks_usec()
	ow.krok(0.016)
	var t3 := Time.get_ticks_usec()
	t._ok("E4 wydajność: 2000 animowanych instancji – zmiana stanu < 100 ms, krok zegara niezależny od liczby jednostek",
		(t2 - t1) < 100000 and (t3 - t2) < 2000, "utworzenie %.1f ms, zmiana %.1f ms, krok %.3f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
	o.free(); ow.free()
	_koniec_jedn = true


func _integracyjne(K, Z) -> void:
	var graf: Dictionary = {}
	for r in Z.tabela("dbgraphics"): graf[String(r.get("Name", ""))] = r
	# falanga
	var rf: Dictionary = graf.get("Phalanx", {})
	var mf: ModelCEM = Z.wczytaj_model_cem("models/men_phalanx_04.cem")
	var sf := SekwencjeAnimacji.z_rekordu(rf) if not rf.is_empty() else SekwencjeAnimacji.new()
	var pokr := {}
	for q in sf.sekwencje:
		for k in range(q.od, q.do + 1): pokr[k] = true
	t._ok("E4 dane: falanga – 75 klatek, sekwencje dbgraphics pokrywają model",
		mf != null and mf.klatki == 75 and sf.kontrola(75).is_empty() and pokr.size() == 75 and sf.bezczynnosc().od == 32,
		[mf.klatki if mf else -1, sf.sekwencje.map(func(q): return "%s %d-%d" % [q.stan, q.od, q.do])])
	# armata – koła
	var mc: ModelCEM = Z.wczytaj_model_cem("models/gun_bronze_09.cem")
	var ok := mc != null and mc.czesci.size() == 3
	var info: Array = []
	if ok:
		for i in [1, 2]:
			var pp := mc.pozycje_modelu(i, 0)
			var mn := INF; var sr := Vector3.ZERO
			for v in pp: mn = minf(mn, v.y); sr += v
			sr /= pp.size()
			info.append([mc.czesci[i].nazwa, snappedf(mn, 0.001), sr])
			ok = ok and absf(mn) < 0.05 and absf(absf(sr.x) - 0.28) < 0.03 and absf(sr.y - 0.40) < 0.03
	t._ok("E4 dane: armata 12-funtowa – koła dotykają ziemi (osie i przesunięcie z macierzy części)", ok, info)
	var mt: ModelCEM = Z.wczytaj_model_cem("models/gun_trebuchet_06.cem")
	var ma: ModelCEM = Z.wczytaj_model_cem("models/gun_80mmaa_10.cem")
	t._ok("E4 dane: trebusz i AA Gun 88 – części potomne animowane macierzą",
		mt != null and ma != null and mt.czesci.size() == 7 and ma.czesci.size() == 2 and ma.czesci[1].macierz_zmienna
		and ma.czesci[1].klatki == ma.klatki and mt.kontrola().is_empty() and ma.kontrola().is_empty(),
		[mt.czesci.size() if mt else -1, ma.drzewo() if ma else null])
	# DCL: szybki dekoder = wzorcowy (bajt w bajt) + czas
	var arch = Z.archiwum("referencyjna", "Empire Earth/Data/data.ssa")
	var zgodne := arch != null
	var czasy := {"szybki_ms": 0.0, "wzorcowy_ms": 0.0, "bajty": 0}
	if arch:
		for k in ["models/men_phalanx_04.cem", "models/gun_trebuchet_06.cem", "textures/basegrass_1_1.sst"]:
			var sur: PackedByteArray = arch.czytaj_surowe(k)
			if not DCL.czy_pk01(sur): continue
			var rozm := sur.decode_u32(4)
			var ta := Time.get_ticks_usec(); var x := DCL.rozpakuj_strumien(sur, 12, rozm)
			var tb := Time.get_ticks_usec(); var y := DCL.rozpakuj_strumien_wzorcowy(sur, 12, rozm)
			var tc := Time.get_ticks_usec()
			zgodne = zgodne and x == y and x.size() == rozm
			czasy.szybki_ms += (tb - ta) / 1000.0; czasy.wzorcowy_ms += (tc - tb) / 1000.0; czasy.bajty += rozm
	t._ok("E4 DCL: szybki dekoder = wzorcowy bajt w bajt (modele i tekstura EE) i jest szybszy",
		zgodne and czasy.bajty > 0 and czasy.szybki_ms < czasy.wzorcowy_ms,
		"%d B: szybki %.1f ms, wzorcowy %.1f ms (×%.1f)" % [czasy.bajty, czasy.szybki_ms, czasy.wzorcowy_ms, czasy.wzorcowy_ms / maxf(czasy.szybki_ms, 0.001)])
	# porównanie z Pythonem (wyniki/analiza_animacji.json, generowane lokalnie)
	var py = t._json(K, "wyniki/analiza_animacji.json")
	if py == null:
		t._pomin(["E4 dane: ModelCEM (GDScript) = czytnik Pythona – klatki i części (próbka modeli)"],
			"brak wyniki/analiza_animacji.json – uruchom narzedzia/przygotuj_dane_lokalne.sh")
	else:
		var klucze: Array = (py.cem as Dictionary).keys().filter(func(k): return String(k).begins_with("ee:"))
		klucze.sort()
		var zle: Array = []; var n := 0
		for i in range(0, klucze.size(), 12):
			var k: String = klucze[i]
			var mm: ModelCEM = Z.wczytaj_model_cem(k.substr(3))
			var st: Dictionary = py.cem[k]
			var licz := func(s, f): return 1 + s.potomne.reduce(func(acc, c): return acc + f.call(c, f), 0)
			var n_py: int = licz.call(st, licz)
			n += 1
			if mm == null or mm.klatki != int(st.klatki) or mm.czesci.size() != n_py or mm.reszta_bajtow != int(st.reszta):
				zle.append([k, mm.klatki if mm else -1, st.klatki, mm.czesci.size() if mm else -1, n_py])
		t._ok("E4 dane: ModelCEM (GDScript) = czytnik Pythona – klatki i części (próbka modeli)", zle.is_empty() and n > 30,
			"%d modeli, rozbieżności: %s" % [n, zle])
	# wszystkie sekwencje (EE) w zakresie modeli – z danych Pythona (bez ładowania wszystkich modeli w GDScript)
	if py == null:
		t._pomin(["E4 dane: wszystkie sekwencje dbgraphics w zakresie modeli (poza znanymi błędami danych)"],
			"brak wyniki/analiza_animacji.json")
	else:
		var poza: Array = []; var nsek := 0
		for r in Z.tabela("dbgraphics"):
			var mp := String(r.get("Model path", "")).to_lower().replace("\\", "/")
			if mp == "": continue
			var st = py.cem.get("aoc:" + mp + ".cem", py.cem.get("ee:" + mp + ".cem"))
			if st == null: continue
			var s := SekwencjeAnimacji.z_rekordu(r)
			nsek += s.sekwencje.size()
			for b in s.kontrola(int(st.klatki)): poza.append("%s: %s" % [mp.get_file(), b])
		var znane := poza.filter(func(x): return not (x.begins_with("men_femcitizenone") or x.begins_with("waypoint") or x.begins_with("xbox")))
		t._ok("E4 dane: wszystkie sekwencje dbgraphics w zakresie modeli (poza znanymi błędami danych)", znane.is_empty() and nsek > 1000,
			"%d sekwencji, poza zakresem: %d (znane błędy danych gry: femcitizenone, waypoint, xbox) %s" % [nsek, poza.size(), znane])
	# woda: klatki animacji z dbterrain
	var rz: ScenariuszEE = t._scn(Z, "Empire Earth - The Art of Conquest", "AOCRoman.ssa", "soldiers")
	if rz == null:
		t._ok("E4 woda: 16 klatek animacji (dbterrain 16×1, Animated), tempo z rekordu wody [H]", false, "brak scenariusza")
	else:
		var te := TerenEE.new(rz, Z.tabela("dbterrain"))
		var pl := te.pliki_klatek(TerenEE.ID_WODY)
		var obr := te.klatki_wody_obrazy(Z)
		var rozne := obr.size() >= 2 and obr[0].get_data() != obr[1].get_data()
		t._ok("E4 woda: 16 klatek animacji (dbterrain 16×1, Animated), tempo z rekordu wody [H]",
			pl.size() == 16 and obr.size() == 16 and rozne and is_equal_approx(te.ms_na_klatke_wody(), 100.0),
			[pl.size(), obr.size(), rozne, te.ms_na_klatke_wody(), pl[0] if pl.size() else ""])
	# scenariusze
	var obiekty := {}
	for o in Z.tabela("dbobjects"): obiekty[int(o.ID)] = o
	var gid := {}
	for r in Z.tabela("dbgraphics"): gid[int(r.ID)] = r
	var wyn: Array = []; var okk := true
	for spec in [["Empire Earth", "EETheGreeks.ssa", "trojan war"], ["Empire Earth - The Art of Conquest", "AOCRoman.ssa", "soldiers"]]:
		var s: ScenariuszEE = t._scn(Z, spec[0], spec[1], spec[2])
		if s == null or not s.czytaj_graczy(K.katalog_openee):
			okk = false; wyn.append([spec[2], "nie wczytano"]); continue
		var anim := 0; var stat := 0; var modele := {}; var bl: Array = []
		for g in s.gracze:
			for u in g.jednostki:
				if int(u.get("valid", 0)) == 0: continue
				var gr: Dictionary = gid.get(int(obiekty.get(int(u.type), {}).get("Graphic ID", -1)), {})
				if gr.is_empty() or String(gr.get("Model path", "")) == "": continue
				var q := SekwencjeAnimacji.z_rekordu(gr).bezczynnosc()
				if int(q.get("klatki", 1)) > 1:
					anim += 1
					var mp := String(gr["Model path"]).to_lower().replace("\\", "/") + ".cem"
					if not modele.has(mp):
						var mm: ModelCEM = Z.wczytaj_model_cem(mp)
						modele[mp] = mm.klatki if mm else -1
					if int(q.do) >= int(modele[mp]): bl.append([mp, q.do, modele[mp]])
				else:
					stat += 1
		okk = okk and anim > 0 and bl.is_empty()
		wyn.append({"scenariusz": spec[2], "animowane": anim, "statyczne": stat, "modele_animowane": modele.size(), "bledy": bl})
	t._ok("E4 scenariusze: Troja (EE) i Rzym (AoC) – animowane jednostki z poprawnymi zakresami, obiekty nie znikają", okk, wyn)
	_koniec_integr = true
