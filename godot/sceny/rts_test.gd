extends "res://sceny/test_scenariusz.gd"
## Scena testowa RTS (etap 5): rzeczywisty scenariusz EE/AoC, jednostki ruchome jako jednostki symulacji
## (Symulacja + MapaNawigacji + WidokJednostek + SterowanieRTS). Scenariusz na dysku nie jest zmieniany –
## wszystkie pozycje i stany istnieją wyłącznie w pamięci.
## Argumenty (oprócz argumentów test_scenariusz): --rts-jednostka=<fragment nazwy dbobjects>  --rts-cel=x,y
##   --rts-demo=<sekundy>  (zaznacza jednostkę, wydaje rozkaz, czeka; zrzuty: --rts-zrzuty=<katalog>)
##   --rts-film=<katalog> (klatki PNG co 1/25 s czasu symulacji)  --rts-sledz (kamera z bliska za jednostką)  --rts-woda (dodatkowo rozkaz do wody głębokiej – test odrzucenia)  --rts-pomiar=<liczba jednostek z rozkazami>
## Sterowanie: LPM – zaznacz, PPM – idź, P – trasa, spacja – pauza, strzałki/krawędź okna/kółko – kamera EE (stały kierunek, bez obrotu), Esc – launcher.
## Kamera: produkcyjna res://sceny/kamera_rts.gd; --kamera-wolna – diagnostyczna (obrót Q/E, WASD, dowolny zoom).

const TYPY_RUCHOME := [5, 6, 13, 16, 23, 4, 18, 21, 22]   # Unit type: lądowe, obywatele, kapłani/bohaterowie, oblężnicze, okręty
const TYPY_BLOKUJACE := [1, 2, 24, 25, 29, 30]              # zasoby (w tym drzewa), budynki, bramy

var _do_symulacji: Array = []
var sym: Symulacja
var mapa: MapaNawigacji
var zegar: ZegarSymulacji
var widok: WidokJednostek
var sterowanie: SterowanieRTS
var _panel: Label
var _sledz := -1                 # --rts-sledz: kamera podąża za zaznaczoną jednostką (zrzuty z bliska)
var rts := {}


func _przejmij_obiekt(u: Dictionary, ob: Dictionary, gr: Dictionary, kolor: Color, gracz: int, x: float, z: float,
		tr: PackedByteArray, model: String, tex: String) -> bool:
	if not (int(ob.get("Unit type", -1)) in TYPY_RUCHOME) or float(ob.get("Speed", 0.0)) <= 0.0:
		return false
	if _przebudowa_obiektow:
		return true          # etap 8: przebudowa obiektów statycznych po zmianie epoki – jednostki zostają w symulacji
	var skala := float(u.get("c174", 0.0))
	if skala <= 0: skala = float(ob.get("Graphic size", 1.0))
	if skala <= 0: skala = 1.0
	_do_symulacji.append({"u": u, "ob": ob, "gr": gr, "kolor": kolor, "gracz": gracz, "x": x, "z": z, "tr": tr,
		"model": model, "tex": tex, "skala": skala})
	return true


func _kamera_produkcyjna() -> bool:
	return not "--kamera-wolna" in OS.get_cmdline_user_args()


func _po_zbudowaniu() -> void:
	var t0 := Time.get_ticks_usec()
	var klify: Array = []
	for r in Zasoby.tabela("dbcliffterrain"):
		klify.append(int(r["Terrain ID"])); klify.append(int(r["Terrain ID#2"]))
	# siatka 1 komórka = 1 pole (etap 9): trasy EE przechodzą przez środki pól (x,5) [P: bród, odcinki osiowe]
	mapa = MapaNawigacji.z_scenariusza(scn, klify, Konfiguracja.skala_wysokosci, 1)
	var t1 := Time.get_ticks_usec()
	var przeszkody := {"budynki_i_zasoby": 0, "drzewa": 0, "komorki": 0}
	for g in scn.gracze:
		for u in g.jednostki:
			if int(u.get("valid", 0)) == 0: continue
			var ob: Dictionary = _obiekty.get(int(u.type), {})
			if not (int(ob.get("Unit type", -1)) in TYPY_BLOKUJACE): continue
			var tr: PackedByteArray = u.get("transform", PackedByteArray())
			var p := UkladEE.pozycja_z_rekordu(tr, int(u.get("X", 0)), int(u.get("Y", 0)))
			var drzewo := "tree" in String(ob.get("Name", "")).to_lower()
			# „Size of collider” = średnica (etap 9: obrys Capitolu w EE ≈ 2 × 2 pola przy wartości 2) [W]
			przeszkody.komorki += mapa.dodaj_przeszkode(p, 0.5 * float(ob.get("Size of collider", 0.5)), drzewo)
			if drzewo: przeszkody.drzewa += 1
			else: przeszkody.budynki_i_zasoby += 1
	var t2 := Time.get_ticks_usec()
	sym = Symulacja.new(mapa)
	zegar = ZegarSymulacji.new(sym); zegar.name = "ZegarSymulacji"; add_child(zegar)
	widok = WidokJednostek.new(sym, zegar); add_child(widok)
	for e in _do_symulacji:
		var d := JednostkaSym.DaneJednostki.new()
		d.typ = int(e.u.type); d.wlasciciel = int(e.gracz); d.pozycja = Vector2(e.x, e.z); d.skala = e.skala
		d.kurs = UkladEE.kat_z_R(UkladEE.R_z_rekordu(e.tr)) if (e.tr as PackedByteArray).size() == 64 else 0.0
		var id := sym.dodaj_jednostke(d, e.ob)
		widok.dodaj(id, e.model, e.tex, e.kolor, e.skala, SekwencjeAnimacji.z_rekordu(e.gr))
		widok.ustaw_grafike_id(id, int(e.gr.get("ID", -1)))
	var wb := widok.zbuduj(Zasoby)
	var t3 := Time.get_ticks_usec()
	sym.sciezki.skladowe(PolitykaRuchu.new())     # składowe i przechodniość typowej polityki lądowej (koszt jednorazowy)
	sym.sciezki._przygotuj()                      # wysokości komórek i bufory A* – przy wczytywaniu, nie przy 1. rozkazie
	var t4 := Time.get_ticks_usec()
	sterowanie = SterowanieRTS.new(sym, widok, zegar, _kamera); add_child(sterowanie)
	_interfejs()
	rts = {"mapa": mapa.opis, "przeszkody": przeszkody, "jednostki_symulacji": sym.jednostki.size(), "widok": wb,
		"czas_ms": {"mapa": (t1 - t0) / 1000.0, "przeszkody": (t2 - t1) / 1000.0, "jednostki_i_modele": (t3 - t2) / 1000.0,
			"skladowe_spojnosci": (t4 - t3) / 1000.0}}
	raport["rts"] = rts
	Dziennik.info("rts", "Symulacja: %s" % JSON.stringify(rts).left(500))
	if _arg("rts-pomiar", "") != "":
		await _pomiar_rts(int(_arg("rts-pomiar", "10")))
	elif _arg("rts-demo", "") != "":
		await _demo(float(_arg("rts-demo", "6")))


## Etap 8: zmiana epoki gracza – budynki (statyczne) przebudowane przez test_scenariusz, jednostki symulacji gracza
## przełączone na nową grafikę (model, tekstura, sekwencje) bez zmiany stanu symulacji.
func zmien_epoke(g: int, tech_epoki: int) -> int:
	var zm := super.zmien_epoke(g, tech_epoki)
	if sym == null or widok == null: return zm
	var n := 0
	for j in sym.lista():
		if j.wlasciciel != g: continue
		var gid := grafika_obiektu(j.typ, g)
		if gid == widok.grafika_id(j.id): continue
		var gr: Dictionary = _grafiki.get(gid, {})
		if gr.is_empty() or String(gr.get("Model path", "")) == "": continue
		var model := String(gr["Model path"]).to_lower().replace("\\", "/") + ".cem"
		var tex := String(gr.get("Texture path", "")).to_lower().replace("\\", "/")
		widok.zmien_grafike(j.id, model, tex, SekwencjeAnimacji.z_rekordu(gr), gid)
		n += 1
	if n > 0:
		widok.przebuduj(Zasoby)
	raport["zmiana_epoki"] = {"gracz": g, "tech": tech_epoki, "typy_budynkow": zm, "jednostki": n}
	return zm + n


## Etap 8: przezroczystość budynków – bieżące pozycje jednostek symulacji gracza lokalnego (tylko zmiany pola
## i okresowe odświeżenie są przeliczane w PrzezroczystoscBudynkow).
func _jednostki_odslaniajace_biezace() -> Array:
	if sym == null: return _jednostki_odslaniajace
	var out: Array = []
	for j in sym.lista():
		if j.wlasciciel == gracz_lokalny: out.append([j.id, j.pozycja])
	return out


func _interfejs() -> void:
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	_panel = Label.new(); _panel.position = Vector2(12, 120)
	_panel.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_theme_color_override("font_outline_color", Color.BLACK)
	_panel.add_theme_constant_override("outline_size", 4)
	cl.add_child(_panel)
	if get_tree().root.get_node_or_null("Powrot") == null and not Konfiguracja.tryb_testow():
		var pw: CanvasLayer = load("res://launcher/powrot.gd").new(); pw.name = "Powrot"
		get_tree().root.call_deferred("add_child", pw)


func _process(_d: float) -> void:
	if _panel == null or sym == null: return
	if _sledz >= 0 and sym.jednostki.has(_sledz):
		var js: JednostkaSym = sym.jednostki[_sledz]
		var pp := js.pozycja_poprz.lerp(js.pozycja, zegar.alfa)
		_kamera.cel = UkladEE.godot(pp, mapa.wysokosc(pp) + 0.4); _kamera.odleglosc = 3.2; _kamera._aktualizuj()
	var t := "RTS (etap 9) – takt %d, jednostek %d%s\nLPM / ramka: zaznacz (Shift dodaj, Ctrl usuń) · PPM: idź (Shift: kolejka) · P: trasa · spacja: pauza · Esc: launcher\n" % [
		sym.takt, sym.jednostki.size(), "  [PAUZA]" if zegar.pauza else ""]
	if not widok.zaznaczone.is_empty():
		var j: JednostkaSym = sym.jednostki.get(widok.zaznaczone[0])
		if j:
			var o := j.opis()
			t += "Jednostka %d: %s (typ %d, gracz %d)\npozycja (%.2f, %.2f), wys. %.2f, kurs %.0f°\nstan: %s, animacja: %s, cel (%.1f, %.1f), punktów trasy: %d\nprędkość %.2f pola/s (Speed × 1,46 – pomiar AoC, etap 9)%s" % [
				j.id, j.nazwa, j.typ, j.wlasciciel, j.pozycja.x, j.pozycja.y, sym.wysokosc(j), o.kurs_st, o.stan, o.animacja,
				j.cel.x, j.cel.y, o.punkty_trasy, j.predkosc, ("\nostatni rozkaz odrzucony: " + j.ostatni_powod) if j.ostatni_powod != "" else ""]
	t += "\n" + sterowanie.komunikat
	_panel.text = t


## Jednostka do demonstracji: pierwsza (najniższe id) pasująca do fragmentu nazwy, z sekwencją ruchu, na lądzie.
func _wybierz_jednostke(fragment: String) -> JednostkaSym:
	for j in sym.lista():
		if fragment != "" and not (fragment.to_lower() in j.nazwa.to_lower()): continue
		if j.polityka.dozwolona(MapaNawigacji.LAD) and widok._jedn.has(j.id):
			var sek: SekwencjeAnimacji = widok._jedn[j.id].sek
			if sek and int(sek.dla_stanu("ruch").get("klatki", 0)) > 1:
				return j
	return null


## Cel demonstracyjny: punkt w odległości ~8 pól, osiągalny, preferowany taki, którego trasa omija przeszkodę.
func _cel_demo(j: JednostkaSym) -> Vector2:
	var arg := _arg("rts-cel", "")
	if arg != "":
		var c := arg.split(","); return Vector2(float(c[0]), float(c[1]))
	var najl := j.pozycja; var najl_ocena := -1.0
	for i in 16:
		var a := TAU * i / 16.0
		for r in [9.0, 7.0, 5.0]:
			var p: Vector2 = j.pozycja + Vector2(cos(a), sin(a)) * r
			if p.x < okno.y + 1 or p.y < okno.x + 1 or p.x > okno.y + okno.z - 1 or p.y > okno.x + okno.z - 1: continue
			var w := sym.sciezki.znajdz(j.pozycja, p, j.polityka)
			if not w.ok: continue
			var ocena: float = float(w.sciezka.size()) + r * 0.1
			if ocena > najl_ocena:
				najl_ocena = ocena; najl = p
			break
	return najl


func _demo(sekundy: float) -> void:
	var j := _wybierz_jednostke(_arg("rts-jednostka", ""))
	if j == null:
		Dziennik.uwaga("rts", "Demo: brak jednostki z sekwencją ruchu"); return
	widok.zaznaczone.clear(); widok.zaznaczone.append(j.id)
	var cel := _cel_demo(j)
	var start := j.pozycja
	_kamera.ustaw(UkladEE.godot(start, mapa.wysokosc(start)).lerp(UkladEE.godot(cel, mapa.wysokosc(cel)), 0.5),
		maxf(9.0, start.distance_to(cel) * 1.3))
	var demo := {"jednostka": j.opis(), "start": start, "cel": cel, "klatki": []}
	if "--rts-sledz" in OS.get_cmdline_user_args(): _sledz = j.id
	sym.rozkaz_ruchu(j.id, cel)
	var kat := _arg("rts-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var t := 0.0; var nr := 0; var nast := 0.0
	var anim_seen := {}
	var probki_wys: Array[float] = []
	var film := _arg("rts-film", "")
	if film != "":
		DirAccess.make_dir_recursive_absolute(film); zegar.set_process(false)
	var klatka_filmu := 0
	while t < sekundy:
		if film != "":
			zegar.przesun(1.0 / 25.0); t += 1.0 / 25.0
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(film.path_join("k_%04d.png" % klatka_filmu)); klatka_filmu += 1
		else:
			await get_tree().process_frame
			t += get_process_delta_time()
		anim_seen[j.stan_animacji] = true
		probki_wys.append(absf(widok.transformacja(j, zegar.alfa).origin.y - mapa.wysokosc(j.pozycja_poprz.lerp(j.pozycja, zegar.alfa))))
		if kat != "" and t >= nast:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(kat.path_join("rts_%02d.png" % nr))
			demo.klatki.append({"t": snappedf(t, 0.01), "pozycja": j.pozycja, "stan": j.opis().stan, "animacja": j.stan_animacji})
			nr += 1; nast += sekundy / 6.0
	probki_wys.sort()
	demo["koniec"] = j.opis(); demo["animacje_widziane"] = anim_seen.keys()
	demo["odleglosc_do_celu"] = j.pozycja.distance_to(cel); demo["przebyta_droga"] = j.przebyta_droga
	demo["maks_odchylenie_od_terenu"] = probki_wys.back() if not probki_wys.is_empty() else 0.0
	demo["brakujace_animacje"] = widok.brakujace_animacje
	if "--rts-woda" in OS.get_cmdline_user_args():
		var woda := Vector2(-1, -1)
		for y in range(okno.x, okno.x + okno.z):
			for x in range(okno.y, okno.y + okno.z):
				if mapa.kategoria_punktu(Vector2(x + 0.5, y + 0.5)) == MapaNawigacji.GLEBOKA:
					woda = Vector2(x + 0.5, y + 0.5); break
			if woda.x >= 0: break
		if woda.x >= 0:
			var poz := j.pozycja
			sym.rozkaz_ruchu(j.id, woda)
			for i in 3: zegar.przesun(Symulacja.KROK)
			demo["rozkaz_do_wody"] = {"cel": woda, "powod": j.ostatni_powod, "pozostal_na_miejscu": j.pozycja.distance_to(poz) < 0.01}
	rts["demo"] = demo
	raport["rts"] = rts
	Dziennik.info("rts", "Demo: %s" % JSON.stringify(demo).left(700))


## Pomiar: N jednostek dostaje rozkazy do losowych (stałe ziarno) osiągalnych celów; czasy tras, taktów, transformacji.
func _pomiar_rts(n: int) -> void:
	var los := RandomNumberGenerator.new(); los.seed = 5
	var lista := sym.lista().filter(func(j): return j.polityka.dozwolona(MapaNawigacji.LAD))
	lista = lista.slice(0, n)
	var t0 := Time.get_ticks_usec()
	var ok := 0; var tras_us: Array[int] = []
	for j in lista:
		for proba in 10:
			var p: Vector2 = j.pozycja + Vector2(los.randf_range(-10, 10), los.randf_range(-10, 10))
			var w := sym.sciezki.znajdz(j.pozycja, p, j.polityka)
			tras_us.append(w.czas_us)
			if w.ok:
				sym.rozkaz_ruchu(j.id, p); ok += 1; break
	var t1 := Time.get_ticks_usec()
	sym.czas_tras_us = 0; sym.czas_taktow_us = 0
	var takty0 := sym.takt
	var czasy: Array[float] = []; var tr_us: Array[int] = []
	var t := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
		var nn := Time.get_ticks_usec(); czasy.append((nn - t) / 1000.0); t = nn
		tr_us.append(widok.czas_transformacji_us)
	czasy.sort(); tras_us.sort()
	var suma := 0.0
	for c in czasy: suma += c
	var nt := sym.takt - takty0
	var trs := 0
	for x in tr_us: trs += x
	rts["pomiar"] = {"jednostek_z_rozkazem": ok, "jednostek_symulacji": sym.jednostki.size(),
		"trasa_mediana_ms": snappedf(tras_us[tras_us.size() / 2] / 1000.0, 0.01) if not tras_us.is_empty() else 0.0,
		"trasa_maks_ms": snappedf(tras_us.back() / 1000.0, 0.01) if not tras_us.is_empty() else 0.0,
		"wyszukiwanie_wszystkich_ms": snappedf((t1 - t0) / 1000.0, 0.1),
		"takty": nt, "takt_sredni_ms": snappedf(sym.czas_taktow_us / 1000.0 / maxi(nt, 1), 0.003),
		"przeliczenia_tras_w_taktach_ms": snappedf(sym.czas_tras_us / 1000.0, 0.01),
		"transformacje_srednio_ms_na_klatke": snappedf(trs / 1000.0 / tr_us.size(), 0.003),
		"animacje_zdarzenia_ms_lacznie": snappedf(widok.czas_animacji_us / 1000.0, 0.01),
		"czas_klatki_sredni_ms": snappedf(suma / czasy.size(), 0.01), "czas_klatki_p95_ms": snappedf(czasy[int(czasy.size() * 0.95)], 0.01),
		"wywolania_rysowania": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"renderer": RenderingServer.get_video_adapter_name()}
	raport["rts"] = rts
	Dziennik.info("rts", "Pomiar: %s" % JSON.stringify(rts.pomiar))
