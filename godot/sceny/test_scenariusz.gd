extends Node3D
## Test graficzny etapu 2: fragment rzeczywistego scenariusza wczytany BEZPOŚREDNIO z instalacji EE
## (archiwum kampanii → SCN → teren + gracze/obiekty), tekstury i modele z data.ssa przez warstwy OpenEE.
## Argumenty (po "--"): --kampania=AOCRoman.ssa | EETheGreeks.ssa  --scenariusz="soldiers for rome" --okno=r0,c0,n
##                      --zrzut=<plik.png> --kamera=blisko --bez-obiektow --teren=etap2 (stary renderer – porównanie)
##                      --pomiar=<klatki> (czas klatki, wywołania rysowania, pamięć → raport JSON)
##                      --bez-animacji (etap 4: jednostki statyczne, klatka 0 – porównanie)
##                      --plik-scn=<ścieżka.scn> (pojedynczy scenariusz z dysku zamiast archiwum kampanii)
##                      --kamera=ee (kamera produkcyjna wierna EE) --kamera-ognisko=x,y --kamera-poziom=0..20 --kamera-fov=<poziomy °>
##                      --epoka=<epoka 1–15>|<gracz>:<epoka>[,<gracz>:<epoka>…] (etap 8: nadpisanie epoki – porównania)
##                      --przezroczystosc=0|1|2 (etap 8: tryb ukrywania jednostek; F5 przełącza)  --gracz-lokalny=<n>
##                      --bez-wariantow (etap 8: grafiki bazowe dbobjects jak przed etapem 8 – porównanie)
## Etap 8: grafika obiektu = wariant epoki gracza (WariantyGrafiki – dbtechtree/dbevents/dbeffects, epoka z bloku EE gracza).
## Etap 4: jednostki z sekwencją bezczynności (dbgraphics) animowane przez AnimacjaVAT w MultiMesh na model.
## Etap 3: teren budowany przez TerenEE (reguły mieszania tekstur, wariantów i wody silnika EE),
##         scenariusze Empire Earth (wersja 231) z katalogu „Empire Earth/Data/Campaigns”.

const SHADER_TERENU := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray tekstury : source_color, filter_linear_mipmap, repeat_enable;
varying flat float warstwa;
void vertex() { warstwa = UV2.x; }
void fragment() {
	ALBEDO = texture(tekstury, vec3(UV, warstwa)).rgb;
	ROUGHNESS = 1.0; SPECULAR = 0.1;
}
"""

const PROG_GRUPY := 8
var raport := {}
var scn: ScenariuszEE
var okno := Vector3i(0, 0, 48)   # r0, c0, n
var _tereny := {}
var _obiekty := {}
var _grafiki := {}
var _kamera: Camera3D
var warianty: WariantyGrafiki
var epoki_graczy := {}           # gracz → ID technologii epoki (dbtechtree); stan wizualny, nie mechanika gry
var zbadane_graczy := {}         # gracz → [ID technologii zbadanych] (z bloku EE scenariusza)
var _wezel_obiektow: Node3D
var przezroczystosc: PrzezroczystoscBudynkow   # etap 8: tryb ukrywania jednostek (F5), jak w EE
var gracz_lokalny := 1
var _jednostki_odslaniajace: Array = []         # [[id, Vector2]] – jednostki gracza lokalnego (scena statyczna)


func _arg(nazwa: String, dom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nazwa):
			return a.split("=", true, 1)[1]
	return dom


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var kamp := _arg("kampania", "AOCRoman.ssa")
	var szuk := _arg("scenariusz", "soldiers for rome").to_lower()
	var gra_ee := kamp.to_lower().begins_with("ee")
	var rel := ("Empire Earth/Data/Campaigns/" if gra_ee else "Empire Earth - The Art of Conquest/Data/Campaigns/") + kamp
	scn = ScenariuszEE.new()
	UkladEE.ustaw_konwencje_modelu(_arg("uklad-modelu", "I"))   # diagnostyka etapu 7 (porównanie konwencji osi)
	var plik_scn := _arg("plik-scn", "")
	if plik_scn != "":
		# diagnostyka: pojedynczy plik .scn z dysku (np. mapa Riverlands do porównania kamer) – tylko odczyt
		var dane := FileAccess.get_file_as_bytes(plik_scn)
		if dane.is_empty() or not scn.wczytaj(dane) or not scn.czytaj_teren():
			Dziennik.blad("test_scenariusz", "Plik scenariusza '%s': %s" % [plik_scn, scn.blad]); return
		rel = plik_scn
		raport["scenariusz"] = "plik:" + plik_scn
	else:
		var a := Zasoby.archiwum(Konfiguracja.zrodlo_gry, rel)
		if a == null:
			Dziennik.blad("test_scenariusz", "Brak archiwum kampanii %s" % rel); return
		var klucz := ""
		for k in a.wpisy:
			if k.ends_with(".scn") and szuk in k:
				klucz = k
		if klucz == "" or not scn.wczytaj(a.czytaj(klucz)) or not scn.czytaj_teren():
			Dziennik.blad("test_scenariusz", "Scenariusz '%s': %s" % [szuk, scn.blad]); return
		raport["scenariusz"] = "%s:%s:%s" % [Konfiguracja.zrodlo_gry, rel, klucz]
	raport["mapa"] = [scn.teren.A, scn.teren.B]
	raport["wersja_scn"] = scn.wersja_kawalka(5)
	var t1 := Time.get_ticks_msec()
	var obiekty_ok := scn.czytaj_graczy(Konfiguracja.katalog_openee)
	raport["czas_parsowania_ms"] = {"teren": t1 - t0, "gracze": Time.get_ticks_msec() - t1}
	if not obiekty_ok:
		Dziennik.uwaga("test_scenariusz", "Obiekty: %s" % scn.blad)
	else:
		var niep := 0; var lacznie := 0
		for g in scn.gracze:
			lacznie += g.jednostki.size()
			if g.has("niepelny"): niep += 1
		raport["gracze"] = {"liczba": scn.gracze.size(), "obiekty_w_pliku_odczytane": lacznie, "gracze_niepelni": niep}
	for r in Zasoby.tabela("dbterrain"): _tereny[int(r.ID)] = r
	for r in Zasoby.tabela("dbobjects"): _obiekty[int(r.ID)] = r
	for r in Zasoby.tabela("dbgraphics"): _grafiki[int(r.ID)] = r
	_przygotuj_warianty()
	var o := _arg("okno", "")
	if o == "pelne":
		okno = Vector3i(0, 0, scn.teren.N)
	elif o != "":
		var cz := o.split(",")
		okno = Vector3i(int(cz[0]), int(cz[1]), int(cz[2]))
	else:
		okno = _wybierz_okno()
	raport["okno"] = [okno.x, okno.y, okno.z]
	var t2 := Time.get_ticks_msec()
	if _arg("teren", "") == "etap2":
		_teren(); _woda()
	else:
		var te := TerenEE.new(scn, Zasoby.tabela("dbterrain"), Konfiguracja.skala_wysokosci)
		add_child(te.zbuduj(okno.x, okno.y, okno.z, Zasoby))
		raport["teren_ee"] = te.statystyka
	raport["czas_terenu_ms"] = Time.get_ticks_msec() - t2
	var t3 := Time.get_ticks_msec()
	if obiekty_ok and not "--bez-obiektow" in OS.get_cmdline_user_args():
		_obiekty_mapy()
	raport["czas_obiektow_ms"] = Time.get_ticks_msec() - t3
	_scena()
	await _po_zbudowaniu()
	raport["czas_ms"] = Time.get_ticks_msec() - t0
	raport["warstwy"] = Array(Konfiguracja.aktywne_warstwy)
	raport["zasoby_statystyka"] = Zasoby.statystyka
	Dziennik.info("test_scenariusz", "Gotowe: %s" % JSON.stringify(raport).left(600))
	var z := _arg("zrzut", "")
	if z != "":
		_zrzut(z)
	elif _arg("pomiar", "") != "":
		_pomiar(int(_arg("pomiar", "120")), "")


## Kamera produkcyjna (wierna EE) czy diagnostyczna (wolna). Podgląd scenariusza: diagnostyczna, chyba że
## --kamera=ee; rozgrywka RTS (rts_test) nadpisuje – produkcyjna, chyba że --kamera-wolna.
func _kamera_produkcyjna() -> bool:
	return _arg("kamera", "") == "ee"


## Wysokość terenu w punkcie mapy (x = kolumna, y = wiersz) – interpolacja punktów siatki.
func _wysokosc_mapy(p: Vector2) -> float:
	var n := float(scn.teren.N)
	p = Vector2(clampf(p.x, 0.0, n - 1.001), clampf(p.y, 0.0, n - 1.001))
	var c := int(floor(p.x)); var r := int(floor(p.y))
	var fx := p.x - c; var fz := p.y - r
	return lerpf(lerpf(_w(r, c), _w(r, c + 1), fx), lerpf(_w(r + 1, c), _w(r + 1, c + 1), fx), fz)


func _w(r: int, c: int) -> float:
	var i := scn.indeks_punktu(r, c)
	return scn.teren.wysokosc[i] * Konfiguracja.skala_wysokosci if i >= 0 else 0.0


func _wybierz_okno() -> Vector3i:
	# okno z największą liczbą budynków graczy (Unit type 2), wewnątrz rombu mapy
	var n := 48
	var siatka := {}
	for g in range(1, scn.gracze.size()):
		for u in scn.gracze[g].jednostki:
			var ob: Dictionary = _obiekty.get(int(u.get("type", -1)), {})
			if int(ob.get("Unit type", -1)) == 2:
				var kl := Vector2i(int(u.get("Y", 0)) / 8, int(u.get("X", 0)) / 8)
				siatka[kl] = siatka.get(kl, 0) + 1
	var best := Vector3i(scn.teren.N / 2 - n / 2, scn.teren.N / 2 - n / 2, n)
	var wynik := -1
	for kl in siatka:
		var r0: int = clamp(kl.x * 8 - n / 2, 0, scn.teren.N - n)
		var c0: int = clamp(kl.y * 8 - n / 2, 0, scn.teren.N - n)
		if scn.indeks_pola(r0, c0) < 0 or scn.indeks_pola(r0 + n - 1, c0 + n - 1) < 0 or scn.indeks_pola(r0, c0 + n - 1) < 0 or scn.indeks_pola(r0 + n - 1, c0) < 0:
			continue
		var s := 0
		for k2 in siatka:
			if k2.x * 8 >= r0 and k2.x * 8 < r0 + n and k2.y * 8 >= c0 and k2.y * 8 < c0 + n:
				s += siatka[k2]
		if s > wynik:
			wynik = s; best = Vector3i(r0, c0, n)
	return best


func _plik_terenu(tid: int, r: int, c: int) -> String:
	var t: Dictionary = _tereny.get(tid, {})
	if t.is_empty():
		return ""
	var baza := String(t.Pathname).to_lower().replace("\\", "/").trim_suffix(".sst")
	var X: int = max(1, int(t["Tyles on X axis"])); var Y: int = max(1, int(t["Tiles on Y axis"]))
	if int(t["Available: 0-No, 1-Animated, 65536-Static"]) == 1:
		return "%s_1.sst" % baza   # teren animowany – pierwsza klatka
	# mozaika X×Y plików _1.._(X·Y), wierszami – ustalone analizą ciągłości krawędzi (FORMATY_ETAP2 §3)
	return "%s_%d.sst" % [baza, 1 + (r % Y) * X + (c % X)]


func _teren() -> void:
	var n := okno.z
	var indeks := {}
	var obrazy: Array[Image] = []
	var brak := 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(okno.x, okno.x + n):
		for c in range(okno.y, okno.y + n):
			var ip := scn.indeks_pola(r, c)
			if ip < 0:
				continue
			var tid: int = scn.teren.teren[ip]
			var plik := _plik_terenu(tid, r, c)
			if not indeks.has(plik):
				var img := Zasoby.wczytaj_teksture(plik)
				if img == null:
					indeks[plik] = -1
				else:
					img = img.duplicate()
					img.convert(Image.FORMAT_RGBA8)
					if img.get_width() != 128 or img.get_height() != 128:
						img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
					img.generate_mipmaps()
					indeks[plik] = obrazy.size(); obrazy.append(img)
			var li: int = indeks[plik]
			if li < 0:
				brak += 1; li = 0
			var hs := [_w(r, c), _w(r, c + 1), _w(r + 1, c + 1), _w(r + 1, c)]
			var pts := [UkladEE.godot(Vector2(c, r), hs[0]), UkladEE.godot(Vector2(c + 1, r), hs[1]),
				UkladEE.godot(Vector2(c + 1, r + 1), hs[2]), UkladEE.godot(Vector2(c, r + 1), hs[3])]
			var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			# klify: UV planarne jak dla pozostałych pól – rzut pionowy (próba) dawał rozciągnięcia, odrzucony (RAPORT_ZGODNOSCI)
			var p0: Vector3 = pts[0]; var p1: Vector3 = pts[1]; var p2: Vector3 = pts[2]; var p3: Vector3 = pts[3]
			var nor: Vector3 = (p2 - p0).cross(p1 - p3).normalized()
			if nor.y < 0: nor = -nor
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uvs[i]); st.set_uv2(Vector2(li, 0)); st.set_normal(nor); st.add_vertex(pts[i])
	raport["tekstury_terenu"] = {"warstwy_tablicy": obrazy.size(), "pola_bez_tekstury": brak}
	if obrazy.is_empty():
		return
	var arr := Texture2DArray.new()
	arr.create_from_images(obrazy)
	var mat := ShaderMaterial.new()
	var sh := Shader.new(); sh.code = SHADER_TERENU
	mat.shader = sh
	mat.set_shader_parameter("tekstury", arr)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit(); mi.material_override = mat; mi.name = "Teren"
	add_child(mi)


func _woda() -> void:
	var n := okno.z
	var img: Image = null
	if _tereny.has(46):
		img = Zasoby.wczytaj_teksture(_plik_terenu(46, 0, 0))
	var pm := PlaneMesh.new(); pm.size = Vector2(n, n)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.75)
	if img:
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.uv1_scale = Vector3(n, n, 1)   # dbterrain: woda 16×1 = 16 klatek animacji, jedna klatka na pole
	var mi := MeshInstance3D.new()
	mi.mesh = pm; mi.material_override = mat; mi.name = "Woda"
	mi.position = UkladEE.godot(Vector2(okno.y + n / 2.0, okno.x + n / 2.0), -0.02)
	add_child(mi)
	raport["woda"] = {"tekstura": img != null}


func _wys_w(x: float, z: float) -> float:
	var c := int(floor(x)); var r := int(floor(z))
	var fx := x - c; var fz := z - r
	return lerp(lerp(_w(r, c), _w(r, c + 1), fx), lerp(_w(r + 1, c), _w(r + 1, c + 1), fx), fz)


func _obiekty_mapy() -> void:
	var siatki := {}
	var licz := {"pokazane": 0, "bez_grafiki": 0, "bez_modelu": 0, "poza_oknem": 0, "wariant_epoki": 0}
	var typy := {}
	var rodzaje := {}
	var wezel := Node3D.new(); wezel.name = "Obiekty"; add_child(wezel)
	_wezel_obiektow = wezel
	var roznice_h: Array[float] = []
	var grupy := {}            # klucz siatki → [Transform3D]
	var grupy_przezr := {}     # klucz siatki → [[indeks w grupie, pozycja mapy, rozmiar]] – obiekty z flagą przezroczystości
	var tryb_przezr := int(_arg("przezroczystosc", "1"))
	if przezroczystosc != null:
		tryb_przezr = przezroczystosc.tryb      # przebudowa po zmianie epoki zachowuje wybrany tryb
		przezroczystosc.queue_free()
	przezroczystosc = PrzezroczystoscBudynkow.new(); przezroczystosc.name = "PrzezroczystoscBudynkow"
	add_child(przezroczystosc)
	gracz_lokalny = int(_arg("gracz-lokalny", "1"))
	_jednostki_odslaniajace = []
	var anim_grupy := {}       # model|tekstura → {model, tex, lista: [[Transform3D, kolor, sekwencja]]}
	var bez_anim := "--bez-animacji" in OS.get_cmdline_user_args()
	for g in range(scn.gracze.size()):
		var gracz: Dictionary = scn.gracze[g]
		var kolor: Color = gracz.kolor if g > 0 else Color(1, 1, 1)
		for u in gracz.jednostki:
			if int(u.get("valid", 0)) == 0:
				continue
			# x, z – punkt mapy EE (kolumna, wiersz); pozycja ciągła t[3], t[7] (RAPORT_EEPPLAYER) – UkladEE
			var tr: PackedByteArray = u.get("transform", PackedByteArray())
			var pm := UkladEE.pozycja_z_rekordu(tr, int(u.get("X", 0)), int(u.get("Y", 0)))
			var x := pm.x; var z := pm.y
			if x < okno.y or x >= okno.y + okno.z or z < okno.x or z >= okno.x + okno.z:
				licz.poza_oknem += 1; continue
			var ob: Dictionary = _obiekty.get(int(u.type), {})
			# jednostki odsłaniające: ruchome, na mapie (X, Y ≥ 0 – jednostki w garnizonie mają X = Y = −10000)
			if g == gracz_lokalny and float(ob.get("Speed", 0.0)) > 0.0 and int(u.get("X", -1)) >= 0 and int(u.get("Y", -1)) >= 0:
				_jednostki_odslaniajace.append([_jednostki_odslaniajace.size(), pm])
			var gid := grafika_obiektu(int(u.type), g)
			if gid != int(ob.get("Graphic ID", -1)):
				licz.wariant_epoki += 1
			var gr: Dictionary = _grafiki.get(gid, {})
			if gr.is_empty() or String(gr.get("Model path", "")) == "":
				licz.bez_grafiki += 1; continue
			var model := String(gr["Model path"]).to_lower().replace("\\", "/") + ".cem"
			var tex := String(gr.get("Texture path", "")).to_lower().replace("\\", "/")
			var bb := int(ob.get("Always face camera", 0)) != 0
			var kl := "%s|%s|%s|%s" % [model, tex, kolor.to_html(), bb]
			# etap 5: scena pochodna (np. RTS) może przejąć obiekt (jednostkę symulacji) zamiast renderu statycznego
			if _przejmij_obiekt(u, ob, gr, kolor, g, x, z, tr, model, tex):
				licz.pokazane += 1
				continue
			# etap 4: obiekt z sekwencją bezczynności (dbgraphics, > 1 klatki) → animowany MultiMesh (VAT)
			var q_bezcz := {} if (bez_anim or bb) else _bezczynnosc(gr)
			if not q_bezcz.is_empty():
				var skala_a := float(u.get("c174", 0.0))
				if skala_a <= 0: skala_a = float(ob.get("Graphic size", 1.0))
				if skala_a <= 0: skala_a = 1.0
				var ka := "%s|%s" % [model, tex]
				if not anim_grupy.has(ka): anim_grupy[ka] = {"model": model, "tex": tex, "lista": []}
				anim_grupy[ka].lista.append([Transform3D(_baza_obiektu(tr) * skala_a, UkladEE.godot(pm, _wys_w(x, z))), kolor, q_bezcz])
				licz.pokazane += 1
				typy[String(ob.get("Name", "?"))] = typy.get(String(ob.get("Name", "?")), 0) + 1
				var ut_a := int(ob.get("Unit type", -1))
				rodzaje[ut_a] = rodzaje.get(ut_a, 0) + 1
				continue
			if not siatki.has(kl):
				siatki[kl] = Zasoby.wczytaj_model(model, {"tekstura": tex, "kolor_gracza": kolor, "billboard": bb})
			var mesh: Mesh = siatki[kl]
			if mesh == null:
				licz.bez_modelu += 1; continue
			var skala := float(u.get("c174", 0.0))       # c174 = Graphic size zapisany w rekordzie [D]
			if skala <= 0: skala = float(ob.get("Graphic size", 1.0))
			if skala <= 0: skala = 1.0
			var h := _wys_w(x, z)
			var xf := Transform3D(_baza_obiektu(tr) * skala, UkladEE.godot(pm, h))
			if not grupy.has(kl): grupy[kl] = []
			if PrzezroczystoscBudynkow.flaga(ob):
				if not grupy_przezr.has(kl): grupy_przezr[kl] = []
				grupy_przezr[kl].append([grupy[kl].size(), pm, float(ob.get("Size of collider", 0.5))])
			grupy[kl].append(xf)
			if tr.size() == 64:
				roznice_h.append(absf(tr.decode_float(44) - h))   # t[11] (wysokość zapisana) vs teren
			licz.pokazane += 1
			typy[String(ob.get("Name", "?"))] = typy.get(String(ob.get("Name", "?")), 0) + 1
			var ut := int(ob.get("Unit type", -1))
			rodzaje[ut] = rodzaje.get(ut, 0) + 1
	# grupowanie: ≥ PROG_GRUPY egzemplarzy tej samej siatki (model+tekstura+kolor gracza) → MultiMesh (jedno wywołanie
	# rysowania na powierzchnię), każdy egzemplarz zachowuje własną transformację; --bez-grupowania wyłącza (porównanie).
	var bez_grup := "--bez-grupowania" in OS.get_cmdline_user_args()
	var n_mm := 0; var n_pojed := 0
	for kl in grupy:
		var lista: Array = grupy[kl]
		if not bez_grup and lista.size() >= PROG_GRUPY:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = siatki[kl]
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			wezel.add_child(mmi)
			n_mm += 1
			if grupy_przezr.has(kl):
				przezroczystosc.dodaj_grupe(kl, mmi)
				for e in grupy_przezr[kl]: przezroczystosc.dodaj_obiekt(kl, e[0], lista[e[0]], e[1], e[2])
		else:
			var flagowane := {}
			for e in grupy_przezr.get(kl, []): flagowane[int(e[0])] = e
			for ix in lista.size():
				var xf: Transform3D = lista[ix]
				var mi := MeshInstance3D.new()
				mi.mesh = siatki[kl]; mi.transform = xf
				wezel.add_child(mi)
				n_pojed += 1
				if flagowane.has(ix): przezroczystosc.dodaj_wezel(mi, flagowane[ix][1], flagowane[ix][2])
	raport["grupowanie"] = {"wlaczone": not bez_grup, "multimeshe": n_mm, "wezly_pojedyncze": n_pojed, "prog": PROG_GRUPY}
	raport["animacje"] = _animowane(anim_grupy, wezel, bez_anim)
	raport["obiekty"] = licz
	przezroczystosc.ustaw_tryb(tryb_przezr)
	przezroczystosc.aktualizuj_jednostki(_jednostki_odslaniajace)
	raport["przezroczystosc"] = {"tryb": przezroczystosc.tryb, "obiekty_z_flaga": przezroczystosc.liczba_obiektow(),
		"gracz_lokalny": gracz_lokalny, "jednostki_odslaniajace": _jednostki_odslaniajace.size()}
	if not roznice_h.is_empty():
		roznice_h.sort()
		raport["wysokosc_t11_vs_teren"] = {"mediana": snappedf(roznice_h[roznice_h.size() / 2], 0.001),
			"p95": snappedf(roznice_h[int(roznice_h.size() * 0.95)], 0.001)}
	raport["obiekty_rodzaje(Unit type)"] = rodzaje
	var top := typy.keys()
	top.sort_custom(func(a, b): return typy[a] > typy[b])
	var tt := {}
	for k in top.slice(0, 15): tt[k] = typy[k]
	raport["obiekty_typy_top"] = tt
	raport["modele_unikalne"] = siatki.size()


## Etap 8: F5 – tryb przezroczystości budynków (jak w EE: 1 → 2 → 0 → 1); jednostki sceny statycznej odświeżają
## znaczniki co PrzezroczystoscBudynkow.ODSWIEZANIE_S (scena RTS podaje bieżące pozycje symulacji).
func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F5 and przezroczystosc:
		var t := przezroczystosc.nastepny_tryb()
		Dziennik.info("przezroczystosc", "Tryb %d: %s" % [t, PrzezroczystoscBudynkow.NAZWY[t]])


func _physics_process(_d: float) -> void:
	if przezroczystosc != null:
		przezroczystosc.aktualizuj_jednostki(_jednostki_odslaniajace_biezace())


## Jednostki odsłaniające (gracz lokalny): scena statyczna – pozycje ze scenariusza.
func _jednostki_odslaniajace_biezace() -> Array:
	return _jednostki_odslaniajace


## Etap 8: warianty grafiki wg epok – dane gry + epoki graczy ze scenariusza (blok EE) lub z --epoka.
func _przygotuj_warianty() -> void:
	warianty = WariantyGrafiki.z_zasobow(Zasoby)
	for g in range(scn.gracze.size()):
		epoki_graczy[g] = scn.epoka_gracza(g)
		zbadane_graczy[g] = scn.gracze[g].get("ee", {}).get("zbadane", [])
	var arg := _arg("epoka", "")
	if arg != "":
		for cz in arg.split(","):
			if ":" in cz:
				epoki_graczy[int(cz.get_slice(":", 0))] = warianty.tech_epoki_nr(int(cz.get_slice(":", 1)))
			else:
				for g in epoki_graczy.keys():
					if g > 0: epoki_graczy[g] = warianty.tech_epoki_nr(int(cz))
	var opis := {}
	for g in epoki_graczy:
		opis[str(g)] = "%d:%s" % [epoki_graczy[g], warianty.nazwa_technologii(int(epoki_graczy[g]))]
	raport["epoki_graczy"] = opis
	raport["warianty"] = {"gotowe": warianty.gotowe, "epok": warianty.epoki.size(),
		"wylaczone": "--bez-wariantow" in OS.get_cmdline_user_args()}


## Grafika (ID dbgraphics) obiektu typu `typ` należącego do gracza `g` – wariant epoki (etap 8).
func grafika_obiektu(typ: int, g: int) -> int:
	var baz := int(_obiekty.get(typ, {}).get("Graphic ID", -1))
	if warianty == null or not warianty.gotowe or "--bez-wariantow" in OS.get_cmdline_user_args():
		return baz
	return warianty.grafika(typ, int(epoki_graczy.get(g, -1)), zbadane_graczy.get(g, []))


## Zmiana epoki gracza (stan wizualny): przebudowa obiektów statycznych gracza; sceny pochodne (RTS) przełączają też
## grafiki jednostek symulacji – pozycje, stany i trasy symulacji pozostają nietknięte. Zwraca liczbę zmienionych typów.
func zmien_epoke(g: int, tech_epoki: int) -> int:
	var stara := mapa_grafik_gracza(g)
	epoki_graczy[g] = tech_epoki
	var nowa := mapa_grafik_gracza(g)
	var zm := 0
	for k in stara.keys() + nowa.keys():
		if stara.get(k, -1) != nowa.get(k, -1): zm += 1
	if zm > 0 and _wezel_obiektow != null:
		remove_child(_wezel_obiektow); _wezel_obiektow.queue_free(); _wezel_obiektow = null
		_przebudowa_obiektow = true
		_obiekty_mapy()
		_przebudowa_obiektow = false
	return zm


var _przebudowa_obiektow := false


func mapa_grafik_gracza(g: int) -> Dictionary:
	if warianty == null or not warianty.gotowe: return {}
	return warianty.mapa_grafik(int(epoki_graczy.get(g, -1)), zbadane_graczy.get(g, []))


## Etap 5 – punkty rozszerzeń dla scen pochodnych (domyślnie bez zmian w zachowaniu).
## Zwraca true, jeśli obiekt został przejęty (nie jest renderowany statycznie ani animowany przez tę scenę).
func _przejmij_obiekt(_u: Dictionary, _ob: Dictionary, _gr: Dictionary, _kolor: Color, _gracz: int, _x: float, _z: float,
		_tr: PackedByteArray, _model: String, _tex: String) -> bool:
	return false


## Wywoływane po zbudowaniu terenu, obiektów i kamery (przed zrzutem/pomiarem).
func _po_zbudowaniu() -> void:
	pass


var _sek_cache := {}

## Sekwencja bezczynności grafiki (SekwencjeAnimacji, gniazdo 2/3) – {} gdy brak albo ≤ 1 klatki.
func _bezczynnosc(gr: Dictionary) -> Dictionary:
	var id := int(gr.get("ID", -1))
	if not _sek_cache.has(id):
		var q := SekwencjeAnimacji.z_rekordu(gr).bezczynnosc()
		_sek_cache[id] = q if int(q.get("klatki", 1)) > 1 and float(q.get("klatki_na_s", 0.0)) > 0.0 else {}
	return _sek_cache[id]


## Animowane obiekty: jeden MultiMesh na model (kolor gracza = kolor instancji, stan animacji = dane własne
## instancji, faza losowa z ziarnem = indeks – powtarzalne zrzuty). Brak animacji/modelu → obiekt statyczny klatki 0.
func _animowane(anim_grupy: Dictionary, wezel: Node3D, wylaczone: bool) -> Dictionary:
	var odtw := OdtwarzaczAnimacji.new(); odtw.name = "OdtwarzaczAnimacji"; add_child(odtw)
	var t0 := Time.get_ticks_usec()
	var inst := 0; var nmm := 0; var zast := 0
	var los := RandomNumberGenerator.new(); los.seed = 20261105
	for ka in anim_grupy:
		var g: Dictionary = anim_grupy[ka]
		var anim := Zasoby.wczytaj_animacje(g.model, {"tekstura": g.tex})
		var lista: Array = g.lista
		var bledne := anim == null
		if anim:
			for e in lista:
				if int(e[2].do) >= anim.klatki: bledne = true
		if bledne:
			# brak animacji albo zakres sekwencji poza modelem (błąd danych) → klatka 0 statycznie (obiekt nie znika)
			for e in lista:
				var mi := MeshInstance3D.new(); mi.mesh = Zasoby.wczytaj_model(g.model, {"tekstura": g.tex, "kolor_gracza": e[1]})
				mi.transform = e[0]; wezel.add_child(mi); zast += 1
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true; mm.use_custom_data = true
		mm.mesh = anim.siatka_multimesh(); mm.instance_count = lista.size()
		for i in lista.size():
			var e: Array = lista[i]
			mm.set_instance_transform(i, e[0]); mm.set_instance_color(i, e[1])
			var k := odtw.dodaj(mm, i)
			odtw.odtworz(k, e[2], los.randf() * float(e[2].klatki))
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.name = "anim_" + g.model.get_file()
		wezel.add_child(mmi)
		inst += lista.size(); nmm += 1
	return {"wylaczone": wylaczone, "modele": nmm, "instancje": inst, "statyczne_zastepcze": zast,
		"czas_wypiekania_ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)}


## Baza (obrót) obiektu z macierzy GETransformation rekordu (t[0..11], wiersze) – etap 3 [D]: oś modelu muru po
## obrocie tą macierzą pokrywa się z kierunkiem muru (wyniki/test_orientacji_modeli.json); pole `angle` nie jest obrotem.
## Konwersja do Godota – wyłącznie UkladEE.baza (etap 7: W·R·L·P⁻¹, bez odbicia świata).
static func _baza_obiektu(tr: PackedByteArray) -> Basis:
	if tr.size() != 64:
		return Basis()
	return UkladEE.baza(UkladEE.R_z_rekordu(tr))


static func _mnoz(a: Array, b: Array) -> Array:
	var w := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for i in 3:
		for j in 3:
			w[i][j] = a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j]
	return w


func _scena() -> void:
	var n := okno.z
	var sw := DirectionalLight3D.new()
	# kierunek światła ustalony względem świata EE (do etapu 6: Euler (−55°, −30°) w odbitym świecie) – UkladEE
	var kier_sw := UkladEE.wektor(Vector3(0.2868, -0.4967, -0.8192))
	sw.basis = Basis.looking_at(kier_sw, Vector3.UP); sw.light_energy = 1.0
	add_child(sw)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85); env.ambient_light_energy = 0.65
	we.environment = env; add_child(we)
	var produkcyjna := _kamera_produkcyjna()
	_kamera = Camera3D.new()
	_kamera.set_script(load("res://sceny/kamera_rts.gd" if produkcyjna else "res://sceny/kamera_diagnostyczna.gd"))
	_kamera.fov = 40
	add_child(_kamera)
	var srodek := UkladEE.godot(Vector2(okno.y + n / 2.0, okno.x + n / 2.0), 0.0)
	if produkcyjna:
		_kamera.wysokosc_terenu = func(p: Vector2) -> float: return _wysokosc_mapy(p)
		var automat := Konfiguracja.tryb_testow()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--zrzut") or a.begins_with("--pomiar") or a.begins_with("--rts-zrzuty") or a.begins_with("--rts-film") or a.begins_with("--rts-pomiar"):
				automat = true
		if automat:
			_kamera.przesuwanie_krawedzia = false     # kadr zrzutu nie może zależeć od położenia kursora
		_kamera.ustaw_granice_z_mapy(scn.teren.rp)
		var og := _arg("kamera-ognisko", "")
		if og != "":
			var cz := og.split(",")
			srodek = UkladEE.godot(Vector2(float(cz[0]), float(cz[1])), 0.0)
		_kamera.ustaw(srodek, 0.0)
		_kamera.ustaw_poziom(int(_arg("kamera-poziom", str(ModelKameryEE.POZIOM_STARTOWY))))
		if _arg("kamera-fov", "") != "":          # diagnostyka: porównanie hipotez kąta widzenia z oryginałem
			_kamera.fov = float(_arg("kamera-fov", ""))
		raport["kamera"] = _kamera.opis()
	else:
		_kamera.ustaw(srodek, n * (0.75 if n > 100 else 0.95))
		if _arg("kamera", "") == "blisko":
			_kamera.ustaw(srodek, n * 0.3)
	_kamera.current = true
	var cl := CanvasLayer.new(); var lab := Label.new()
	lab.position = Vector2(12, 8)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 4)
	lab.text = "OpenEE – etap 4: %s\nOkno %d×%d pól (r0=%d c0=%d), obiekty: %s\nŹródło: %s; warstwy: %s\nSterowanie: %s" % [
		raport.get("scenariusz", "?").get_file(), n, n, okno.x, okno.y, raport.get("obiekty", {}).get("pokazane", 0),
		Konfiguracja.zrodlo_gry, ", ".join(Konfiguracja.aktywne_warstwy),
		"strzałki / krawędź okna – przesuwanie, kółko – zoom (kamera EE)" if produkcyjna else "WASD/strzałki, kółko, Q/E, R (kamera diagnostyczna)"]
	cl.add_child(lab); add_child(cl)


## Pomiar wydajności po wczytaniu: średni/maks. czas klatki, wywołania rysowania, prymitywy, pamięć.
func _pomiar(klatki: int, plik: String) -> void:
	for i in range(5):
		await get_tree().process_frame
	var czasy: Array[float] = []
	var t := Time.get_ticks_usec()
	for i in range(klatki):
		await get_tree().process_frame
		var n := Time.get_ticks_usec()
		czasy.append((n - t) / 1000.0); t = n
	czasy.sort()
	var suma := 0.0
	for c in czasy: suma += c
	raport["pomiar"] = {
		"klatki": klatki, "sredni_czas_klatki_ms": snappedf(suma / klatki, 0.01),
		"mediana_ms": snappedf(czasy[klatki / 2], 0.01), "p95_ms": snappedf(czasy[int(klatki * 0.95)], 0.01),
		"fps_sredni": snappedf(1000.0 * klatki / suma, 0.1),
		"wywolania_rysowania": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"prymitywy": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"obiekty_w_klatce": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"pamiec_statyczna_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"pamiec_wideo_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"wezly": get_tree().get_node_count(), "renderer": RenderingServer.get_video_adapter_name()}
	Dziennik.info("test_scenariusz", "Pomiar: %s" % JSON.stringify(raport["pomiar"]))
	if plik == "":
		var p := Konfiguracja.katalog_openee.path_join("wyniki/pomiar_%s.json" % Time.get_unix_time_from_system())
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(raport, "  "))
		get_tree().quit(0)


func _zrzut(sciezka: String) -> void:
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _arg("pomiar", "") != "":
		await _pomiar(int(_arg("pomiar", "60")), sciezka)
	var img := get_viewport().get_texture().get_image()
	var e := img.save_png(sciezka)
	var f := FileAccess.open(sciezka.get_basename() + ".json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(raport, "  "))
	Dziennik.info("test_scenariusz", "Zrzut %s (kod %d)" % [sciezka, e])
	get_tree().quit(0 if e == OK else 1)
