extends "res://sceny/test_scenariusz.gd"
## Etap 36: pierwsza grywalna potyczka OpenEE. Mapa: prawdziwy scenariusz EE (teren i obiekty statyczne z SCN),
## jednostki: układ z dane/potyczka/*.json. CAŁA logika (ruch, kolizje, trasy, wykrywanie, atak, obrażenia, śmierć)
## w OpenEE Core (C++) przez GDExtension OpenEESymulacja; Godot tylko rysuje stan i przekazuje rozkazy.
## Warstwy: SymulacjaCore (odczyt stanu Core → modele widoku) + ZegarSymulacji (stały krok Titan, interpolacja)
## + WidokJednostek (modele CEM, animacje) + SterowanieRTS (LPM/ramka/PPM/Shift). Brak drugiej symulacji w GDScript.
##
## Argumenty (oprócz test_scenariusz): --potyczka=<plik.json> (domyślnie dane/potyczka/potyczka_troja.json)
##   --potyczka-demo=<s>  (automat: zaznacza jednostki gracza, rozkaz ataku, gra do rozstrzygnięcia lub limitu)
##   --potyczka-zrzuty=<katalog>  --potyczka-raport=<plik.json>  --potyczka-restart (demo: restart po wyniku i 2. bitwa)
##   --przyblizone (tablice walki przybliżone zamiast odczytu z Low-Level Engine.dll)
## Sterowanie: LPM – zaznacz, ramka – zaznacz grupę, PPM w teren – ruch (Shift: kolejka), PPM na wrogu – atak,
##   spacja – pauza, R – nowa bitwa (restart), Esc – launcher.

const ParametryTypowDB := preload("res://silnik/symulacja/parametry_typow_db.gd")   # etap 53
const TYPY_RUCHOME := [5, 6, 13, 16, 23, 4, 18, 21, 22]
const PLIK_DOMYSLNY := "dane/potyczka/potyczka_troja.json"
const MIGNIECIE_S := 0.25            # czas podświetlenia paska HP po trafieniu (prezentacja)
const ZNIKANIE_ZWLOK_S := 3.0        # zwłoki ukrywane po animacji śmierci (prezentacja; EE: rozkład zwłok [N])

var uklad := {}                       # plik potyczki
var core: Object
var sym: SymulacjaCore
var mapa: MapaNawigacji
var zegar: ZegarSymulacji
var widok: WidokJednostek
var sterowanie: SterowanieRTS
var wynik := ""                       # "", "wygrana", "przegrana"
var bitwa := 0
var dziennik_walki: Array = []        # ostatnie zdarzenia (HUD)
var licznik := {"atak": 0, "trafienie": 0, "smierc": 0, "wybor_celu": 0}
var _mapa_core := {}                  # dane mapy dla Core (wczytywane raz, używane przy każdym restarcie)
var _obiekty_core: Array = []
var _hud: Label
var _rysunek: Control
var _wynik_lab: Label
var _miganie := {}                    # id → czas do końca podświetlenia
var _smierc_t := {}                   # id → czas od śmierci
var _info_tablic := ""
var _raport_p := {}
var _budynki_dod: Array = []          # etap 47: budynki układu potyczki (spoza SCN) – obiekty Core z HP
var _budynki_wejscie: Array = []      # te same budynki w formacie obiektów pól (wejście grafu)
var _budynki_core := {}               # id Core budynku → id obiektu mapy
var _nowe_z_produkcji: Array = []      # etap 52: [takt, id, typ, x, y] jednostek z produkcji
var _gruz_znaczniki := {}             # etap 49: id gruzu Core → TYMCZASOWY znacznik diagnostyczny (brak legalnego modelu)
var _panel_prod: PanelContainer       # etap 54: panel produkcji zaznaczonego budynku
var _panel_opis: Label
var _panel_przyciski: HBoxContainer
var _panel_bud := -1                  # budynek, dla którego zbudowano przyciski
var _prod_dostepne := {}              # id budynku Core → [id technologii] (układ: produkcja.dostepne)
var _prod_info := {}                  # id technologii → {nazwa, koszt, czas_ms}
var _typy_pol := {}                   # flagi typów obiektów pól z Core (+0x568, +0x600, +0x4B4, +0x612)


func _arg(nazwa: String, dom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nazwa):
			return a.split("=", true, 1)[1]
	if uklad.is_empty(): _wczytaj_uklad()
	match nazwa:
		"kampania": return String(uklad.get("kampania", dom))
		"scenariusz-nr": return str(int(uklad.get("scenariusz_nr", int(dom) if dom.is_valid_int() else 1)))
		"okno":
			var o: Array = uklad.get("okno", [])
			return "%d,%d,%d" % [o[0], o[1], o[2]] if o.size() == 3 else dom
		"kamera-ognisko":
			var k: Array = uklad.get("kamera", {}).get("ognisko", [])
			return "%s,%s" % [k[0], k[1]] if k.size() == 2 else dom
		"kamera-poziom": return str(int(uklad.get("kamera", {}).get("poziom", int(dom) if dom.is_valid_int() else 4)))
		"gracz-lokalny": return str(int(uklad.get("gracz_lokalny", 1)))
	return dom


func _wczytaj_uklad() -> void:
	var p := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--potyczka="): p = a.split("=", true, 1)[1]
	if p == "": p = Konfiguracja.katalog_openee.path_join(PLIK_DOMYSLNY)
	var t := FileAccess.get_file_as_string(p)
	var d = JSON.parse_string(t) if t != "" else null
	uklad = d if d is Dictionary else {"blad": "brak pliku potyczki %s" % p}
	uklad["_plik"] = p


func _kamera_produkcyjna() -> bool:
	return not "--kamera-wolna" in OS.get_cmdline_user_args()


## Jednostki ruchome scenariusza nie biorą udziału w potyczce (zdjęte ze sceny); budynki i zasoby – statyczne.
func _przejmij_obiekt(u: Dictionary, ob: Dictionary, _gr: Dictionary, _kolor: Color, _gracz: int, _x: float, _z: float,
		_tr: PackedByteArray, _model: String, _tex: String) -> bool:
	return int(ob.get("Unit type", -1)) in TYPY_RUCHOME and float(ob.get("Speed", 0.0)) > 0.0


func _po_zbudowaniu() -> void:
	raport["potyczka"] = _raport_p
	if uklad.has("blad"):
		_raport_p["blad"] = uklad.blad; Dziennik.blad("potyczka", uklad.blad); _koniec_automatu(1); return
	if not CoreCpp.dostepny():
		_raport_p["blad"] = "brak biblioteki OpenEE Core (GDExtension) – zbuduj cpp/gdextension"
		Dziennik.blad("potyczka", _raport_p.blad); _koniec_automatu(1); return
	var klify: Array = []
	for r in Zasoby.tabela("dbcliffterrain"):
		klify.append(int(r["Terrain ID"])); klify.append(int(r["Terrain ID#2"]))
	mapa = MapaNawigacji.z_scenariusza(scn, klify, Konfiguracja.skala_wysokosci, 1)   # tylko wysokości (render, kursor)
	_przygotuj_mape_core()
	_interfejs()
	var ok := nowa_bitwa()
	if not ok:
		_koniec_automatu(1); return
	if "--potyczka-siatka" in OS.get_cmdline_user_args():     # diagnostyka: przejezdność pól okna wg Core
		var w := PackedStringArray()
		for y in range(okno.x, okno.x + okno.z):
			var l := ""
			for x in range(okno.y, okno.y + okno.z): l += "." if core.pole_przejezdne(x, y) else "#"
			w.append("%d %s" % [y, l])
		_raport_p["siatka_od_x"] = okno.y; _raport_p["siatka"] = w
	if _arg("potyczka-demo", "") != "" and uklad.has("demo_e54"):
		await _demo_e54(float(_arg("potyczka-demo", "150")))
	elif _arg("potyczka-demo", "") != "" and uklad.has("demo_e53"):
		await _demo_e53(float(_arg("potyczka-demo", "120")))
	elif _arg("potyczka-demo", "") != "" and uklad.has("demo_e52"):
		await _demo_e52(float(_arg("potyczka-demo", "90")))
	elif _arg("potyczka-demo", "") != "" and uklad.has("demo_e50"):
		await _demo_e50(float(_arg("potyczka-demo", "60")))
	elif _arg("potyczka-demo", "") != "" and uklad.has("demo_e47"):
		await _demo_e47(float(_arg("potyczka-demo", "90")))
	elif _arg("potyczka-demo", "") != "":
		await _demo(float(_arg("potyczka-demo", "60")))
	elif _arg("potyczka-raport", "") != "":
		_koniec_automatu(0)


## Dane mapy dla Core: surowy kawałek 4 SCN (interpretacja Titan w Core – MapaTitan::z_scn), rodziny tekstur
## z dbterrain i obiekty blokujące z kawałka 5 (docs/titan/import_mapy.md § 4).
func _przygotuj_mape_core() -> void:
	var rodz := {}
	for r in Zasoby.tabela("dbterrain"):
		var id := int(r["ID"])
		if id >= 0 and id < 256: rodz[id] = int(r.get("Terrain family", 0))
	_mapa_core = {"rodziny": rodz}
	_obiekty_core.clear()
	var nr := 0
	for g in range(scn.gracze.size()):
		for u in scn.gracze[g].jednostki:
			nr += 1
			if int(u.get("valid", 0)) == 0: continue
			var ob: Dictionary = _obiekty.get(int(u.type), {})
			if ob.is_empty(): continue
			var ut := int(ob.get("Unit type", -1))
			if ut in TYPY_RUCHOME and float(ob.get("Speed", 0.0)) > 0.0: continue
			_obiekty_core.append({"id": int(u.get("id", 0x7000000 + nr)), "typ": int(u.type), "gracz": g,
				"X": int(u.get("X", 0)), "Y": int(u.get("Y", 0)),
				"kwadrat": maxi(1, int(ob.get("Square occupied", 1))), "blokuje": _blokuje(int(u.type), ob)})
	# etap 47: budynki układu (np. dom w przejściu muru) – obiekty pól (blokada, wejście grafu) i obiekty Core z HP
	_budynki_dod.clear(); _budynki_wejscie.clear()
	var i := 0
	for b in uklad.get("budynki", []):
		var ob: Dictionary = _obiekty.get(int(b["typ"]), {})
		if ob.is_empty(): continue
		var n := maxi(1, int(ob.get("Square occupied", 1)))
		var e := {"id": 0x7100000 + i, "typ": int(b["typ"]), "gracz": int(b["gracz"]), "X": int(b["X"]), "Y": int(b["Y"]),
			"kwadrat": n, "blokuje": _blokuje(int(b["typ"]), ob), "kurs": float(b.get("kurs", 0.0)),
			"hp": int(b["hp"]) if b.has("hp") else int(ob.get("Health", 0)), "fundament": bool(b.get("fundament", false)),
			"budowa": b.get("budowa", {})}   # etap 51: K (czas_budowy_ms) i m (czas_budowy_s) – wzór 0x60BF56
		_budynki_dod.append(e)
		i += 1
		# etap 50: fundament z rozkazu budowy – obiekt Core stawiany po wczytaniu mapy (HP 1, bez zgłoszenia mapy do
		# ukończenia), poza obiektami mapy i wejściem grafu (jak w grze: 658/659 [P])
		if e.fundament: continue
		_obiekty_core.append(e)
		_budynki_wejscie.append({"id": e.id, "gracz": e.gracz, "X": e.X, "Y": e.Y, "typ": e.typ, "kwadrat": n,
			"hp": int(ob.get("Health", 0)), "zasob": int(ob.get("Resource type", 0)), "budynek": int(ob.get("Is building?", 0)),
			"unit_type": int(ob.get("Unit type", 0))})


## Blokada pola (typ +0x600) = dbobjects „Is building?” [P etap 44: e35_a 70/70 typów z odczytu pamięci, m.in. obiekty
## kamery (Unit type 2) – 0, drzewa i zasoby – 1, bramy – 0]. Zastępuje regułę z etapu 30 (Unit type + wyjątki).
static func _blokuje(_typ: int, ob: Dictionary) -> bool:
	return int(ob.get("Is building?", 0)) != 0


## Nowa bitwa (start i restart): nowy świat Core na tej samej mapie, jednostki z pliku układu, świeże warstwy widoku.
func nowa_bitwa() -> bool:
	_usun_warstwy()
	bitwa += 1
	wynik = ""; dziennik_walki.clear(); _miganie.clear(); _smierc_t.clear()
	for k in licznik: licznik[k] = 0
	core = CoreCpp.nowa_symulacja()
	var t := scn.teren
	var im: Dictionary = core.wczytaj_mape_scn(t["A"], t["B"], t["teren"], t["flagi"], t["f10"], t["wysokosc"], _mapa_core.rodziny)
	if not im.get("ok", false):
		_raport_p["blad"] = "Core: mapa SCN odrzucona"; Dziennik.blad("potyczka", _raport_p.blad); return false
	for o in _obiekty_core: core.dodaj_obiekt_mapy(o)
	# tablice walki: odczyt z Low-Level Engine.dll gry (jak w testach Core) albo przybliżone (oznaczone w raporcie)
	var dll := CoreCpp.znajdz_dll(String(uklad.get("wariant", "ee")), Konfiguracja)
	var tz: Dictionary = {}
	if dll != "" and not "--przyblizone" in OS.get_cmdline_user_args():
		tz = core.zaladuj_tablice(dll)
	if not tz.get("ok", false):
		core.uzyj_tablic_przyblizonych(); _info_tablic = "tablice ruchu przybliżone (brak DLL)"
	else:
		_info_tablic = "tablice ruchu z %s" % dll.get_file()
	var typy: Dictionary = uklad.get("typy", {})
	var pierwszy: Dictionary = typy.values()[0] if not typy.is_empty() else {}
	var dozw := PackedByteArray(pierwszy.get("teren_dozwolony", [1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0]))
	if not core.utworz_swiat_na_mapie(String(uklad.get("wariant", "ee")), dozw):
		_raport_p["blad"] = "Core: utworz_swiat_na_mapie – %s" % str(core.get("ostatni_blad")); return false
	# etap 44: graf podsektorów Titan budowany w Core wyłącznie z danych lokalnych (mapa SCN, kawałek 5, dbobjects,
	# dbunitset) – klasyfikacja pól 0x516E8C/0x512FB0, obiekty pól, regiony 0x4240D3, podsektory 0x42434F
	if not "--bez-grafu" in OS.get_cmdline_user_args():
		var we: Dictionary = ObiektyScnCore.wejscie(core, scn, Zasoby, _budynki_wejscie)
		_typy_pol = we.get("typy", {})
		var gw: Dictionary = core.zbuduj_graf_z_wejscia(we, int(we.get("komorka", 19)))
		_raport_p["graf"] = {"podsektorow": gw.get("podsektorow", -1), "regionow": gw.get("regionow", -1),
			"obszarow": gw.get("obszarow", -1), "zrodlo": "SCN + bazy gry (Core)"}
	var tb: Dictionary = uklad.get("tablice", {})
	var traf := {}
	var tr_j: Dictionary = tb.get("trafienie", {})
	for k in tr_j:
		var kl := {}
		for kk in tr_j[k]: kl[int(kk)] = PackedFloat32Array(tr_j[k][kk])
		traf[k] = kl
	if not core.ustaw_tablice_walki({"trudnosc": int(tb.get("trudnosc", 0)), "mnozniki": tb.get("mnozniki", []), "trafienie": traf},
			uklad.get("wagi", {}).get("rekordy", [])):
		_raport_p["blad"] = "Core: ustaw_tablice_walki"; return false
	for w in uklad.get("wrogowie", []):
		core.ustaw_wrogow(int(w[0]), int(w[1]), true)
	mapa_sym()
	var gl := int(uklad.get("gracz_lokalny", 1))
	sym.gracz_lokalny = gl
	zegar = ZegarSymulacji.new(sym); zegar.name = "ZegarSymulacji"; add_child(zegar)
	widok = WidokJednostek.new(sym, zegar); widok.name = "WidokJednostek"; add_child(widok)
	var n := 0
	var id_jedn := []   # etap 50: id Core jednostek układu (rozkaz budowy)
	for jd in uklad.get("jednostki", []):
		var typ := int(jd["typ"]); var g := int(jd["gracz"])
		var td: Dictionary = typy.get(str(typ), {})
		var id: int = core.dodaj_jednostke(td.get("ruch", {}), float(jd["x"]), float(jd["y"]), float(jd.get("kurs", 0.0)))
		id_jedn.append(id)
		if id <= 0: continue
		var pw := {}
		var wd: Dictionary = td.get("walka", {})
		for k in wd: pw[k] = (1 if wd[k] else 0) if wd[k] is bool else wd[k]
		if not pw.has("smierc_klatki"): pw.merge(ObiektyScnCore.parametry_smierci(typ, Zasoby))   # etap 44
		var ob: Dictionary = _obiekty.get(typ, {})
		# etap 46: leczenie z dbobjects; leczone typy = typy jednostek potyczki (zestaw +0x10C nieodczytany [N])
		pw.merge(ObiektyScnCore.parametry_leczenia(ob, _typy_potyczki(uklad)), false)
		core.ustaw_walke(id, g, g == gl, pw, int(td.get("hp", 1)))
		# etap 46: skrypt .tai z danych typu (dbobjects „TAI Script”), interpretacja w Core; nieznany skrypt → skrypt
		# świata (land) z ostrzeżeniem w raporcie
		var skr := String(ob.get("TAI Script", ""))
		if not core.ustaw_skrypt_jednostki(id, skr):
			_raport_p["skrypty_nieznane"] = _raport_p.get("skrypty_nieznane", []) + [skr]
		else:
			_raport_p["skrypty"] = _raport_p.get("skrypty", {})
			_raport_p["skrypty"][str(typ)] = skr
		sym.zarejestruj(id, g, typ, maxf(0.15, float(ob.get("Circle selection size", 0.25))), String(ob.get("Name", "")))
		var gid := grafika_obiektu(typ, g)
		var gr: Dictionary = _grafiki.get(gid, {})
		if gr.is_empty() or String(gr.get("Model path", "")) == "": continue
		var model := String(gr["Model path"]).to_lower().replace("\\", "/") + ".cem"
		var tex := String(gr.get("Texture path", "")).to_lower().replace("\\", "/")
		var skala := float(ob.get("Graphic size", 1.0)); if skala <= 0: skala = 1.0
		widok.dodaj(id, model, tex, _kolor_gracza(g), skala, SekwencjeAnimacji.z_rekordu(gr))
		widok.ustaw_grafike_id(id, gid)
		n += 1
	# etap 47: budynki układu jako obiekty Core (HP, obrażenia, Dying, zapadanie się, zmiana mapy – wszystko w Core);
	# Godot tylko rysuje model w pozycji i wysokości z Core
	_budynki_core.clear(); _nowe_z_produkcji.clear()
	var id_bud := []   # etap 50: id Core budynków układu w kolejności pliku
	for e in _budynki_dod:
		var ob: Dictionary = _obiekty.get(int(e.typ), {})
		var pb := ObiektyScnCore.parametry_budynku(ob, _obiekty)
		pb["rozmiar_jeden"] = int(_typy_pol.get("typ:%d" % int(e.typ), [0, 0, 0, 0])[3])
		var nb: int = int(e.kwadrat)
		pb.merge({"gracz": e.gracz, "typ": e.typ, "X": e.X, "Y": e.Y, "kwadrat": nb, "x": float(e.X) + nb * 0.5,
			"y": float(e.Y) + nb * 0.5, "hp": e.hp, "blokuje": 1 if e.blokuje else 0, "id_mapy": int(e.id), "w_siatce": 1}, true)
		var bid: int
		if e.fundament:
			pb["hp_max"] = int(ob.get("Health", 0)); pb.erase("w_siatce")
			pb.merge(e.get("budowa", {}), true)
			bid = core.postaw_fundament(pb)
		else:
			bid = core.dodaj_budynek(pb)
		id_bud.append(bid)
		if bid <= 0: continue
		_budynki_core[bid] = int(e.id)
		sym.zarejestruj(bid, int(e.gracz), int(e.typ), maxf(0.5, float(ob.get("Circle selection size", 1.0))), String(ob.get("Name", "")))
		var gidb := grafika_obiektu(int(e.typ), int(e.gracz))
		var grb: Dictionary = _grafiki.get(gidb, {})
		if grb.is_empty() or String(grb.get("Model path", "")) == "": continue
		var mb := String(grb["Model path"]).to_lower().replace("\\", "/") + ".cem"
		var tb2 := String(grb.get("Texture path", "")).to_lower().replace("\\", "/")
		var sk := float(ob.get("Graphic size", 1.0)); if sk <= 0: sk = 1.0
		widok.dodaj(bid, mb, tb2, _kolor_gracza(int(e.gracz)), sk, SekwencjeAnimacji.z_rekordu(grb))
		widok.ustaw_grafike_id(bid, gidb)
	_raport_p["budynki_core"] = _budynki_core.size()
	# etap 50: rozkazy budowy z układu (obywatel → fundament); przyrost HP na cykl RepairBuilding z pomiaru [P: 658/659]
	for r in uklad.get("budowa", []):
		var cit: int = id_jedn[int(r["obywatel"])]; var bud: int = id_bud[int(r["budynek"])]
		core.ustaw_przyrost_budowy(cit, int(r.get("przyrost", 0)))
		core.rozkaz_budowy(cit, bud)
	_ustaw_produkcje(id_bud)   # etap 52: produkcja jednostek (typy z dbtechtree, rozkazy z układu)
	core.uporzadkuj_wg_pozycji()   # etap 44: kolejność taktu jak kolejka fizyki EE po wczytaniu (Core)
	var wb := widok.zbuduj(Zasoby)
	var start_zle: Array = []          # kontrola danych układu: jednostka na polu nieprzejezdnym (Core)
	for jd in uklad.get("jednostki", []):
		if not core.pole_przejezdne(int(floor(float(jd["x"]))), int(floor(float(jd["y"])))): start_zle.append([jd["x"], jd["y"]])
	if not start_zle.is_empty():
		ImporterEE.zglos("uwaga", "potyczka", "Jednostki na polach nieprzejezdnych: %s" % str(start_zle))
	sterowanie = SterowanieRTS.new(sym, widok, zegar, _kamera); sterowanie.gracz = gl; add_child(sterowanie)
	sterowanie.przechwyt_ppm = _ppm_budynek   # etap 54: PPM przy zaznaczonym budynku produkcyjnym = punkt zbiórki
	_panel_bud = -1
	zegar.po_takcie.connect(_po_takcie_walki)
	_raport_p["bitwa_%d" % bitwa] = {"jednostki": sym.jednostki.size(), "modele": wb, "mapa_core": im.get("skrot", ""),
		"obiekty_mapy": _obiekty_core.size(), "start_nieprzejezdny": start_zle, "tablice": _info_tablic, "wersja_core": str(core.call("wersja")) if core.has_method("wersja") else ""}
	Dziennik.info("potyczka", "Bitwa %d: %d jednostek, %s" % [bitwa, n, _info_tablic])
	return true


func mapa_sym() -> void:
	sym = SymulacjaCore.new(core, mapa)


func _kolor_gracza(g: int) -> Color:
	if g > 0 and g < scn.gracze.size() and scn.gracze[g].has("kolor"): return scn.gracze[g].kolor
	return [Color.WHITE, Color(0.2, 0.4, 1), Color(1, 0.2, 0.2), Color(0.2, 0.8, 0.2), Color(1, 1, 0.2), Color(0.8, 0.3, 0.9)][g % 6]


## Bezpieczne zdjęcie warstw poprzedniej bitwy (węzły zwalniane, sygnały rozłączane razem z nimi).
func _usun_warstwy() -> void:
	for w in [sterowanie, widok, zegar]:
		if w != null and is_instance_valid(w):
			remove_child(w); w.queue_free()
	sterowanie = null; widok = null; zegar = null; sym = null; core = null
	_gruz_znaczniki.clear()


## Zdarzenia walki z Core (po każdym takcie): HUD, podświetlenie trafionego, liczniki. Kolejność = kolejność Core.
func _po_takcie_walki(zd: Array) -> void:
	if uklad.has("produkcja") and core.has_method("nowe_jednostki"):   # etap 52: jednostki z produkcji – rejestracja i model
		for nid in core.nowe_jednostki(): _zarejestruj_nowa(int(nid))
	for e in zd:
		if e.typ != "walka": continue
		var r := String(e.rodzaj)
		licznik[r] = int(licznik.get(r, 0)) + 1
		if r == "trafienie": _miganie[int(e.cel)] = MIGNIECIE_S
		if r != "wybor_celu" or dziennik_walki.size() < 3:
			dziennik_walki.append("t%d %s %d→%d%s" % [e.takt, r, e.kto, e.cel, (" (%d)" % e.wartosc) if r == "trafienie" else ""])
	while dziennik_walki.size() > 6: dziennik_walki.pop_front()
	if wynik == "" and not uklad.get("wrogowie", []).is_empty():   # etap 50: układ bez wrogów (demo budowy) – bez wyniku bitwy
		var gl := sym.gracz_lokalny
		var wlasne := sym.liczba_zywych(gl)
		var wrogie := 0
		for id in sym.jednostki:
			if int(sym.gracz_jednostki[id]) != gl and sym.zywa(id): wrogie += 1
		if wrogie == 0: _ustaw_wynik("wygrana")
		elif wlasne == 0: _ustaw_wynik("przegrana")


func _ustaw_wynik(w: String) -> void:
	wynik = w
	_raport_p["wynik_%d" % bitwa] = {"wynik": w, "takt": sym.takt, "liczniki": licznik.duplicate(),
		"zywe": {str(sym.gracz_lokalny): sym.liczba_zywych(sym.gracz_lokalny)}, "skrot": sym.skrot_stanu()}
	Dziennik.info("potyczka", "Bitwa %d: %s w takcie %d (%s)" % [bitwa, w, sym.takt, JSON.stringify(licznik)])


## Etap 49 – pozostałości budynków (Core: core.gruz(), dbobjects „Debris on death#2”, np. 361 1×1, 362 2×2).
## TYMCZASOWY znacznik diagnostyczny: płaska szara płyta na polach X..X+n−1 × Y..Y+n−1 (model gruzu EE nie jest
## kopiowany do projektu). Znacznik jest dzieckiem widoku – restart bitwy (nowy widok) usuwa go razem z widokiem.
## Gruz nie zmienia przejezdności (Core nie blokuje pól gruzem – „Collidable” 0) i powstaje w takcie śmierci budynku.
func _aktualizuj_gruz() -> void:
	if core == null or widok == null: return
	for g in core.gruz():
		var gid := int(g.get("id", 0))
		if _gruz_znaczniki.has(gid) and is_instance_valid(_gruz_znaczniki[gid]): continue
		var n := maxi(1, int(g.get("kwadrat", 1)))
		var p := Vector2(float(g.get("X", 0)) + 0.5 * n, float(g.get("Y", 0)) + 0.5 * n)
		var m := MeshInstance3D.new(); m.name = "GruzDiag_%d_typ%d" % [gid, int(g.get("typ", 0))]
		var b := BoxMesh.new(); b.size = Vector3(0.9 * n, 0.06, 0.9 * n); m.mesh = b
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.42, 0.38); m.material_override = mat
		m.set_meta("tymczasowy", true); m.set_meta("typ", int(g.get("typ", 0)))
		widok.add_child(m)
		m.position = UkladEE.godot(p, sym.mapa.wysokosc(p) + 0.03)
		_gruz_znaczniki[gid] = m


func liczba_znacznikow_gruzu() -> int:   # etap 49: test integracyjny
	var n := 0
	for k in _gruz_znaczniki:
		if is_instance_valid(_gruz_znaczniki[k]): n += 1
	return n


func _interfejs() -> void:
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	_rysunek = Control.new(); _rysunek.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rysunek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rysunek.draw.connect(_rysuj_paski)
	cl.add_child(_rysunek)
	_hud = Label.new(); _hud.position = Vector2(12, 128)
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	cl.add_child(_hud)
	_wynik_lab = Label.new(); _wynik_lab.set_anchors_preset(Control.PRESET_CENTER)
	_wynik_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wynik_lab.add_theme_font_size_override("font_size", 40)
	_wynik_lab.add_theme_color_override("font_outline_color", Color.BLACK)
	_wynik_lab.add_theme_constant_override("outline_size", 8)
	cl.add_child(_wynik_lab)
	# etap 54: panel produkcji – widoczny po zaznaczeniu własnego budynku z listą „dostepne”; dane i rozkazy tylko przez Core
	_panel_prod = PanelContainer.new()
	_panel_prod.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel_prod.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel_prod.position = Vector2(12, -64)   # nad przyciskiem powrotu do launchera
	_panel_prod.visible = false
	var vb := VBoxContainer.new(); _panel_prod.add_child(vb)
	_panel_opis = Label.new(); vb.add_child(_panel_opis)
	_panel_przyciski = HBoxContainer.new(); vb.add_child(_panel_przyciski)
	cl.add_child(_panel_prod)
	if get_tree().root.get_node_or_null("Powrot") == null and not Konfiguracja.tryb_testow():
		var pw: CanvasLayer = load("res://launcher/powrot.gd").new(); pw.name = "Powrot"
		get_tree().root.call_deferred("add_child", pw)


## Paski HP nad jednostkami (prezentacja stanu HP z Core); zielony – gracz lokalny, czerwony – wróg; biały błysk po
## trafieniu.
func _rysuj_paski() -> void:
	if sym == null or widok == null or _kamera == null: return
	var alfa := zegar.alfa if zegar else 1.0
	for id in sym.jednostki:
		if not sym.zywa(id): continue
		var j: JednostkaSym = sym.jednostki[id]
		var p := j.pozycja_poprz.lerp(j.pozycja, alfa)
		var w3 := UkladEE.godot(p, mapa.wysokosc(p) + 1.15)
		if _kamera.is_position_behind(w3): continue
		var s := _kamera.unproject_position(w3)
		var szer := 28.0
		var f := clampf(float(sym.hp[id]) / float(sym.hp_max[id]), 0.0, 1.0)
		var r := Rect2(s - Vector2(szer / 2, 0), Vector2(szer, 4))
		_rysunek.draw_rect(r.grow(1), Color(0, 0, 0, 0.8))
		var kol := Color(0.2, 0.9, 0.2) if int(sym.gracz_jednostki[id]) == sym.gracz_lokalny else Color(0.95, 0.2, 0.15)
		if _miganie.has(id): kol = kol.lerp(Color.WHITE, 0.7)
		_rysunek.draw_rect(Rect2(r.position, Vector2(szer * f, 4)), kol)
	# etap 54: znacznik punktu zbiórki zaznaczonego budynku (dane z Core)
	var bz := _budynek_produkcji()
	if bz >= 0:
		var jb: Dictionary = core.jednostka(bz)
		if bool(jb.get("zbiorka", false)):
			var pz := Vector2(float(jb.get("zbiorka_x", 0)), float(jb.get("zbiorka_y", 0)))
			var wz := UkladEE.godot(pz, mapa.wysokosc(pz))
			if not _kamera.is_position_behind(wz):
				var sz := _kamera.unproject_position(wz)
				_rysunek.draw_line(sz, sz - Vector2(0, 26), Color.WHITE, 2.0)
				_rysunek.draw_colored_polygon(PackedVector2Array([sz - Vector2(0, 26), sz + Vector2(14, -20), sz - Vector2(0, 14)]), _kolor_gracza(sym.gracz_lokalny))


func _process(d: float) -> void:
	if sym == null: return
	for id in _miganie.keys():
		_miganie[id] -= d
		if _miganie[id] <= 0: _miganie.erase(id)
	for id in sym.jednostki:
		if not sym.zywa(id) and not _smierc_t.has(id): _smierc_t[id] = 0.0
	for id in _smierc_t.keys():
		_smierc_t[id] += d
		var bud: bool = sym.jednostki.has(id) and sym.jednostki[id].budynek
		# etap 47: budynek znika w chwili Dead (6003) z Core – wcześniej widoczne zapadanie się (z z Core)
		if bud:
			if int(sym.stan.get(id, 0)) >= 6003 and not widok.ukryta(id): widok.ukryj(id)
		elif _smierc_t[id] >= ZNIKANIE_ZWLOK_S and not widok.ukryta(id): widok.ukryj(id)
	_aktualizuj_gruz()
	# zaznaczenie: martwe jednostki wypadają (jak w EE – zwłoki niewybieralne)
	var zm := false
	for id in widok.zaznaczone.duplicate():
		if not sym.zywa(id):
			widok.zaznaczone.erase(id); zm = true
	if zm: sterowanie.zaznaczenie.ids = widok.zaznaczone.duplicate()
	if _rysunek: _rysunek.queue_redraw()
	if _hud == null: return
	var gl := sym.gracz_lokalny
	var wrog := 0
	for id in sym.jednostki:
		if int(sym.gracz_jednostki[id]) != gl and sym.zywa(id): wrog += 1
	var t := "OpenEE – potyczka (etap 36, OpenEE Core %s) · bitwa %d · takt %d%s\n" % [
		_raport_p.get("bitwa_%d" % bitwa, {}).get("wersja_core", "").get_slice(" ", 2), bitwa, sym.takt, "  [PAUZA]" if zegar.pauza else ""]
	t += "Twoje jednostki: %d · wrogowie: %d · %s\n" % [sym.liczba_zywych(gl), wrog, _info_tablic]
	t += "LPM / ramka: zaznacz · PPM: idź (Shift: kolejka) · PPM na wrogu: atak · spacja: pauza · R: nowa bitwa · Esc: launcher\n"
	if not widok.zaznaczone.is_empty():
		var id: int = widok.zaznaczone[0]
		t += "Zaznaczone %d: id %d HP %d/%d, stan %d, cel %s\n" % [widok.zaznaczone.size(), id, sym.hp[id], sym.hp_max[id], sym.stan[id],
			str(sym.cel_walki[id]) if int(sym.cel_walki[id]) != 0 else "–"]
	t += sterowanie.komunikat + "\n" + "\n".join(dziennik_walki)
	_hud.text = t
	_odswiez_panel_produkcji()
	_wynik_lab.text = "" if wynik == "" else ("ZWYCIĘSTWO" if wynik == "wygrana" else "PORAŻKA") + "\nR – nowa bitwa"
	_wynik_lab.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if wynik == "wygrana" else Color(1, 0.3, 0.3))
	_wynik_lab.position = get_viewport().get_visible_rect().size / 2 - _wynik_lab.size / 2


func _unhandled_key_input(e: InputEvent) -> void:
	super._unhandled_key_input(e)
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_R:
		nowa_bitwa()


func _jednostki_odslaniajace_biezace() -> Array:
	if sym == null: return _jednostki_odslaniajace
	var out: Array = []
	for j in sym.lista():
		if j.wlasciciel == gracz_lokalny: out.append([j.id, j.pozycja])
	return out


## Automat demonstracyjny/testowy: prawdziwa scena z renderem, wejście przez SterowanieRTS (ramka + PPM na wrogu jak
## gracz), czas – zegar sceny. Zapisuje zrzuty i raport (pozycje, HP, zdarzenia, wynik, skrót stanu).
func _demo(sekundy: float) -> void:
	var kat := _arg("potyczka-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var proby := 2 if "--potyczka-restart" in OS.get_cmdline_user_args() else 1
	var demo := []
	for nr_proby in proby:
		if nr_proby > 0:                 # restart klawiszem R (jak gracz)
			for wc in [true, false]:
				var k := InputEventKey.new(); k.keycode = KEY_R; k.physical_keycode = KEY_R; k.pressed = wc
				Input.parse_input_event(k); await get_tree().process_frame
		for i in 5: await get_tree().process_frame
		var przebieg := {"bitwa": bitwa, "kroki": []}
		# 1) ramka nad własnymi jednostkami (rzut ekranowy prawdziwej kamery)
		var pk: Array = []
		for j in sym.lista():
			if j.wlasciciel == sym.gracz_lokalny:
				pk.append(_kamera.unproject_position(UkladEE.godot(j.pozycja, mapa.wysokosc(j.pozycja) + 0.5)))
		var r := Rect2(pk[0], Vector2.ZERO)
		for p in pk: r = r.expand(p)
		r = r.grow(20)
		await _przeciagnij(r.position, r.end)
		przebieg.kroki.append({"krok": "ramka", "zaznaczone": widok.zaznaczone.size(), "komunikat": sterowanie.komunikat})
		# 2) rozkaz ruchu PPM w teren (przed wrogiem), potem PPM na wrogu (atak), część z Shift – kolejka
		var sw := Vector2.ZERO; var sn := Vector2.ZERO; var nw := 0; var nn := 0
		for j in sym.lista():
			if j.wlasciciel == sym.gracz_lokalny: sw += j.pozycja; nw += 1
			else: sn += j.pozycja; nn += 1
		var cel_ruchu := (sw / nw).lerp(sn / nn, 0.3)
		var ek := _kamera.unproject_position(UkladEE.godot(cel_ruchu, mapa.wysokosc(cel_ruchu)))
		await _klik(MOUSE_BUTTON_RIGHT, ek)
		# Shift + PPM: drugi punkt w kolejce celów Core (po dojściu do pierwszego)
		var cel2 := cel_ruchu + Vector2(1.0, 0.0)
		await _klik(MOUSE_BUTTON_RIGHT, _kamera.unproject_position(UkladEE.godot(cel2, mapa.wysokosc(cel2))), true)
		przebieg.kroki.append({"krok": "ppm_teren+shift", "cel": [cel_ruchu, cel2], "komunikat": sterowanie.komunikat})
		await _czekaj(1.5, kat, "b%d_a" % bitwa, przebieg)
		var wrog := -1
		for j in sym.lista():
			if j.wlasciciel != sym.gracz_lokalny: wrog = j.id; break
		var jw: JednostkaSym = sym.jednostki[wrog]
		var ew := _kamera.unproject_position(UkladEE.godot(jw.pozycja, mapa.wysokosc(jw.pozycja) + 0.5))
		await _klik(MOUSE_BUTTON_RIGHT, ew)
		przebieg.kroki.append({"krok": "ppm_wrog", "cel": wrog, "komunikat": sterowanie.komunikat,
			"cele_core": widok.zaznaczone.map(func(i): return sym.cel_walki[i])})
		var t := 0.0
		var nr := 0
		while t < sekundy and wynik == "":
			await _czekaj(minf(2.0, sekundy - t), kat if nr % 3 == 0 else "", "b%d_%02d" % [bitwa, nr], przebieg)
			t += 2.0; nr += 1
			# gdy wybrany cel padł, a nikt nie walczy – nowy rozkaz ataku na najbliższego wroga (jak gracz)
			var walczy := false
			for id in widok.zaznaczone: walczy = walczy or int(sym.cel_walki[id]) != 0
			if not walczy and not widok.zaznaczone.is_empty():
				for j in sym.lista():
					if j.wlasciciel != sym.gracz_lokalny:
						await _klik(MOUSE_BUTTON_RIGHT, _kamera.unproject_position(UkladEE.godot(j.pozycja, mapa.wysokosc(j.pozycja) + 0.5)))
						break
		await _czekaj(1.0, kat, "b%d_koniec" % bitwa, przebieg)
		przebieg["wynik"] = wynik; przebieg["takt"] = sym.takt; przebieg["liczniki"] = licznik.duplicate()
		przebieg["skrot"] = sym.skrot_stanu()
		przebieg["hp"] = {}
		for id in sym.jednostki: przebieg.hp[str(id)] = sym.hp[id]
		demo.append(przebieg)
	_raport_p["demo"] = demo
	_koniec_automatu(0)


## Etap 47: demonstrator zniszczenia przeszkody (wejście jak od gracza przez SterowanieRTS): ramka nad gwardiami, PPM na
## budynku w przejściu (rozkaz ataku w Core), czekanie na Dying i przebudowę grafu, PPM za przejściem (rozkaz ruchu),
## dojście przez zwolnione pole; potem R (restart) i powtórka – raport porównuje oba przebiegi (HP, pola, graf, skrót).
func _demo_e47(sekundy: float) -> void:
	var kat := _arg("potyczka-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var cfg: Dictionary = uklad["demo_e47"]
	var cel_r := Vector2(float(cfg["cel_ruchu"][0]), float(cfg["cel_ruchu"][1]))
	var px := int(cfg["pole_przejscia"][0]); var py := int(cfg["pole_przejscia"][1])
	var wyniki := []
	for nr in int(cfg.get("powtorzenia", 2)):
		if nr > 0:
			for wc in [true, false]:
				var k := InputEventKey.new(); k.keycode = KEY_R; k.physical_keycode = KEY_R; k.pressed = wc
				Input.parse_input_event(k); await get_tree().process_frame
		for i in 5: await get_tree().process_frame
		var bud := -1
		for bid in _budynki_core:
			var jd: Dictionary = core.jednostka(int(bid))
			if int(jd.get("X", -1)) == px and int(jd.get("Y", -1)) == py: bud = int(bid)
		var przebieg := {"bitwa": bitwa, "budynek": bud, "kroki": [],
			"start": {"hp": sym.hp.get(bud, -1), "blokady": core.blokady_pola(px, py), "przejezdne": core.pole_przejezdne(px, py),
				"graf": core.stan_grafu(), "w_fizyce": core.jednostka(bud).get("w_fizyce", null)}}
		var pk: Array = []
		var wlasne: Array = []
		for j in sym.lista():
			if j.wlasciciel == sym.gracz_lokalny and not j.budynek:
				pk.append(_kamera.unproject_position(UkladEE.godot(j.pozycja, mapa.wysokosc(j.pozycja) + 0.5))); wlasne.append(j.id)
		var r := Rect2(pk[0], Vector2.ZERO)
		for p in pk: r = r.expand(p)
		r = r.grow(20)
		await _przeciagnij(r.position, r.end)
		przebieg["zaznaczone"] = widok.zaznaczone.size()
		await _czekaj(0.5, kat, "e47_b%d_start" % bitwa, przebieg)
		var jb: JednostkaSym = sym.jednostki[bud]
		await _klik(MOUSE_BUTTON_RIGHT, _kamera.unproject_position(UkladEE.godot(jb.pozycja, mapa.wysokosc(jb.pozycja) + 0.6)))
		przebieg["atak"] = {"komunikat": sterowanie.komunikat, "cele": widok.zaznaczone.map(func(i): return int(sym.cel_walki[i]))}
		var hp_hist := []
		var t := 0.0
		var nr_z := 0
		while t < sekundy and int(sym.stan.get(bud, 0)) < 6000:
			await _czekaj(1.0, kat if nr_z % 4 == 0 else "", "e47_b%d_atak_%02d" % [bitwa, nr_z], przebieg)
			hp_hist.append(sym.hp.get(bud, -1)); t += 1.0; nr_z += 1
		przebieg["hp"] = hp_hist
		przebieg["smierc_takt"] = sym.takt
		przebieg["smierc_stan"] = sym.stan.get(bud, -1)
		await _czekaj(0.5, kat, "e47_b%d_dying" % bitwa, przebieg)
		przebieg["po_smierci"] = {"przejezdne": core.pole_przejezdne(px, py), "blokady": core.blokady_pola(px, py),
			"graf": core.stan_grafu(), "w_fizyce": core.jednostka(bud).get("w_fizyce", null), "z": core.jednostka(bud).get("z", 0.0)}
		await _klik(MOUSE_BUTTON_RIGHT, _kamera.unproject_position(UkladEE.godot(cel_r, mapa.wysokosc(cel_r))))
		przebieg["ruch"] = {"komunikat": sterowanie.komunikat}
		var przez := {}
		t = 0.0
		var doszli := false
		while t < sekundy and not doszli:
			await get_tree().process_frame
			t += get_process_delta_time()
			doszli = true
			for id in wlasne:
				var j: JednostkaSym = sym.jednostki[id]
				if int(floor(j.pozycja.x)) == px and int(floor(j.pozycja.y)) == py: przez[str(id)] = true
				if j.pozycja.distance_to(cel_r) > 2.0: doszli = false
		przebieg["doszli"] = doszli
		przebieg["przez_pole"] = przez.keys()
		przebieg["czas_ruchu_s"] = snappedf(t, 0.01)
		await _czekaj(0.5, kat, "e47_b%d_po_przejsciu" % bitwa, przebieg)
		t = 0.0
		while t < 40.0 and int(sym.stan.get(bud, 0)) < 6003:
			await get_tree().process_frame
			t += get_process_delta_time()
		for i in 10: await get_tree().process_frame
		przebieg["koniec"] = {"stan_budynku": sym.stan.get(bud, -1), "ukryty": widok.ukryta(bud), "takt": sym.takt,
			"w_fizyce": core.jednostka(bud).get("w_fizyce", null), "graf": core.stan_grafu(), "skrot": sym.skrot_stanu(),
			"gruz": core.gruz(), "znaczniki_gruzu": liczba_znacznikow_gruzu()}   # etap 48/49: pozostałość budynku (Core) i jej znacznik
		wyniki.append(przebieg)
	_raport_p["demo_e47"] = wyniki
	_koniec_automatu(0)


## Wejście jak od gracza: zdarzenia myszy przez Input (trafiają do SterowanieRTS._unhandled_input).
## Etap 50: automat demonstracji budowy – obywatel z rozkazem budowy (z układu) stawia dom; raport: stany obywatela,
## HP budynku co sekundę, ukończenie (+0x340), termin zgłoszenia zmiany mapy. Logika budowy – Core.
func _demo_e50(sekundy: float) -> void:
	var kat := _arg("potyczka-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var bud := -1; var cit := -1
	for bid in _budynki_core: bud = int(bid)
	var obywatele := []
	for j in sym.lista():
		if not j.budynek and j.wlasciciel == sym.gracz_lokalny: cit = j.id; obywatele.append(j.id)
	var przebieg := {"budynek": bud, "obywatel": cit, "obywatele": obywatele, "kroki": [], "hp": [], "stany": [], "budowniczowie": []}
	var t := 0.0
	var nr := 0
	while t < sekundy and not bool(core.jednostka(bud).get("ukonczony", false)):
		await _czekaj(1.0, kat if nr % 10 == 0 else "", "e50_budowa_%02d" % nr, przebieg)
		przebieg.hp.append(int(core.jednostka(bud).get("hp", -1)))
		przebieg.budowniczowie.append(int(core.jednostka(bud).get("budowniczowie", 0)))   # etap 51: +0x274
		var st := int(core.jednostka(cit).stan)
		if przebieg.stany.is_empty() or przebieg.stany[-1] != st: przebieg.stany.append(st)
		t += 1.0; nr += 1
	await _czekaj(1.0, kat, "e50_budowa_koniec", przebieg)
	przebieg["koniec"] = {"hp": int(core.jednostka(bud).get("hp", -1)), "ukonczony": core.jednostka(bud).get("ukonczony", null),
		"stan_obywatela": int(core.jednostka(cit).stan), "graf": core.stan_grafu(), "takt": sym.takt}
	_raport_p["demo_e50"] = przebieg
	_koniec_automatu(0)


# Etap 52 – produkcja jednostek (docs/titan/produkcja.md). Koszt, czas i obiekt pozycji z dbtechtree (EpokiDB), mnożnik
# czasu i koszt populacji z danych (parametry_jednostek_ee.json → produkcja), parametry tworzonej jednostki z „typy” układu.
# Rozkazy z układu (bez interfejsu produkcji): {"budynek": indeks w „budynki”, "tech": id, "ile": n}.
func _ustaw_produkcje(id_bud: Array) -> void:
	if not uklad.has("produkcja") or not core.has_method("ustaw_produkcje"): return
	var pr: Dictionary = uklad["produkcja"]
	var par: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../dane/testy_walki/parametry_jednostek_ee.json"))
	var tech := {}
	var tt: Dictionary = Zasoby.znajdz("db/dbtechtree.dat")
	for rt in EpokiDB.techtree(tt.get("dane", PackedByteArray())): tech[int(rt["id"])] = rt
	var gl := int(uklad.get("gracz_lokalny", 1))
	core.ustaw_zasoby(gl, pr.get("zasoby", [0, 0, 0, 0, 0]))
	var pop: Array = pr.get("populacja", [0, 100])
	core.ustaw_populacje(gl, int(pop[0]), int(pop[1]), 0, 0)
	var info := {}
	# etap 54: technologie dostępne w budynkach (panel produkcji) – rejestrowane w Core tak samo jak technologie rozkazów
	_prod_dostepne.clear(); _prod_info.clear()
	var do_rejestracji: Array = []
	for r0 in pr.get("rozkazy", []): do_rejestracji.append({"tech": int(r0["tech"]), "rozkaz": r0})
	for dd in pr.get("dostepne", []):
		var bidd := int(id_bud[int(dd["budynek"])])
		_prod_dostepne[bidd] = []
		for tt2 in dd.get("tech", []): do_rejestracji.append({"tech": int(tt2), "budynek_dostepny": bidd})
	for r1 in do_rejestracji:
		var r: Dictionary = r1.get("rozkaz", {})
		var tid := int(r1["tech"])
		var rt: Dictionary = tech.get(tid, {})
		if rt.is_empty():
			ImporterEE.zglos("uwaga", "potyczka", "Brak technologii %d w dbtechtree" % tid); continue
		var typ := str(int(rt["obiekt"]))
		var td: Dictionary = uklad.get("typy", {}).get(typ, {})
		var pochodne := false
		if td.is_empty():
			# etap 53: typ spoza układu (np. jednostka wojskowa z koszar) – parametry z pomiaru (parametry_jednostek_ee.json)
			# albo wyprowadzone z dbobjects (ParametryTypowDB); produkcja nie wymaga osobnego wpisu dla każdej jednostki
			if not ParametryTypowDB.uzupelnij(par, _obiekty, int(typ)):
				ImporterEE.zglos("uwaga", "potyczka", "Brak parametrów typu %s (produkcja %d)" % [typ, tid]); continue
			td = {"ruch": par["ruch"][typ], "walka": par["walka"][typ]["p"], "hp": int(par["walka"][typ]["hp"])}
			pochodne = bool(par["walka"][typ].get("pochodne", false))
		var dp: Dictionary = par.get("produkcja", {}).get(str(tid), {})
		core.ustaw_produkcje({"tech_id": tid, "typ_db": int(rt["obiekt"]), "koszt": rt["koszt"], "czas_ms": int(rt["czas_ms"]),
			"mnoznik_czasu": float(dp.get("mnoznik_czasu", 1.0)),
			"populacja": int(dp.get("populacja", int(_obiekty.get(int(typ), {}).get("Population count", 1)))),
			"losowy_zamiennik": int(dp.get("losowy_zamiennik", -1)) if tech.has(int(dp.get("losowy_zamiennik", -1))) and bool(pr.get("losuj_plec", false)) else -1,
			"ruch": td["ruch"],
			"walka": td["walka"], "hp": int(td.get("hp", 1)),
			"skrypt": String(_obiekty.get(int(typ), {}).get("TAI Script", ""))})
		info[str(tid)] = {"nazwa": rt["nazwa"], "obiekt": int(rt["obiekt"]), "koszt": rt["koszt"], "czas_ms": int(rt["czas_ms"]),
			"parametry_z_dbobjects": pochodne}
		_prod_info[tid] = info[str(tid)]
		if r1.has("budynek_dostepny"):
			if not _prod_dostepne[int(r1["budynek_dostepny"])].has(tid): _prod_dostepne[int(r1["budynek_dostepny"])].append(tid)
			continue
		for k in int(r.get("ile", 1)):
			core.rozkaz_produkcji(int(id_bud[int(r["budynek"])]), tid)
	_raport_p["produkcja_typy"] = info


## Etap 54: budynek z panelem produkcji – dokładnie jeden zaznaczony obiekt, własny, z listą dostępnych technologii.
func _budynek_produkcji() -> int:
	if widok == null or sym == null or widok.zaznaczone.size() != 1: return -1
	var id := int(widok.zaznaczone[0])
	if not _prod_dostepne.has(id) or not sym.zywa(id) or int(sym.gracz_jednostki[id]) != sym.gracz_lokalny: return -1
	return id


func _opis_kosztu(koszt: Array) -> String:
	var n := ["żywność", "drewno", "kamień", "złoto", "żelazo"]
	var cz := PackedStringArray()
	for i in mini(koszt.size(), 5):
		if int(koszt[i]) > 0: cz.append("%d %s" % [int(koszt[i]), n[i]])
	return ", ".join(cz) if not cz.is_empty() else "bez kosztu"


func _odswiez_panel_produkcji() -> void:
	if _panel_prod == null: return
	var bud := _budynek_produkcji()
	_panel_prod.visible = bud >= 0
	if bud < 0:
		_panel_bud = -1; return
	if bud != _panel_bud:
		_panel_bud = bud
		for ch in _panel_przyciski.get_children(): ch.queue_free()
		for tid in _prod_dostepne[bud]:
			var inf: Dictionary = _prod_info.get(int(tid), {})
			var b := Button.new()
			b.name = "tech_%d" % int(tid)
			b.text = "%s\n%s · %d s" % [String(inf.get("nazwa", str(tid))), _opis_kosztu(inf.get("koszt", [])), int(round(float(inf.get("czas_ms", 0)) / 1000.0))]
			b.tooltip_text = "LPM: produkuj · PPM: anuluj"
			b.gui_input.connect(_wejscie_przycisku.bind(int(tid)))
			_panel_przyciski.add_child(b)
	var jb: Dictionary = core.jednostka(bud)
	var gl := sym.gracz_lokalny
	var biez := int(jb.get("prod_biezaca", -1))
	var t := "%s – produkcja\n" % String(sym.jednostki[bud].nazwa if "nazwa" in sym.jednostki[bud] else "Budynek")
	if biez >= 0:
		t += "Bieżąca: %s – pozostało %.1f s\n" % [String(_prod_info.get(biez, {}).get("nazwa", str(biez))), float(jb.get("prod_ms", 0)) / 1000.0]
	else:
		t += "Bieżąca: brak\n"
	var kol := PackedStringArray()
	for tk in jb.get("prod_kolejka", []): kol.append(String(_prod_info.get(int(tk), {}).get("nazwa", str(tk))))
	t += "Kolejka (%d): %s\n" % [kol.size(), ", ".join(kol) if not kol.is_empty() else "–"]
	var z: Array = core.zasoby(gl)
	t += "Zasoby: żywność %d · drewno %d · kamień %d · złoto %d · żelazo %d · populacja %d/%d\n" % [int(z[0]), int(z[1]), int(z[2]), int(z[3]),
		int(z[4]), int(core.populacja(gl)), int(core.limit_populacji(gl))]
	t += "Punkt zbiórki: %s (PPM w teren)" % ("(%.2f; %.2f)" % [float(jb.get("zbiorka_x", 0)), float(jb.get("zbiorka_y", 0))] if bool(jb.get("zbiorka", false)) else "brak")
	_panel_opis.text = t


func _wejscie_przycisku(e: InputEvent, tid: int) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT: _ui_produkuj(tid)
		elif e.button_index == MOUSE_BUTTON_RIGHT: _ui_anuluj(tid)
		_panel_przyciski.accept_event()


## LPM na przycisku: rozkaz produkcji w Core (koszt pobiera Core przy rozkazie).
func _ui_produkuj(tid: int) -> bool:
	var bud := _budynek_produkcji()
	if bud < 0: return false
	var ok: bool = core.rozkaz_produkcji(bud, tid)
	sterowanie.komunikat = ("produkcja: %s" if ok else "produkcja odrzucona: %s (koszt albo limit)") % String(_prod_info.get(tid, {}).get("nazwa", str(tid)))
	return ok


## PPM na przycisku: anulowanie jak w Titan – pierwsza pozycja tej technologii z kolejki, inaczej bieżąca (Core).
func _ui_anuluj(tid: int) -> bool:
	var bud := _budynek_produkcji()
	if bud < 0: return false
	var ok: bool = core.anuluj_technologie(bud, tid)
	sterowanie.komunikat = ("anulowano: %s" if ok else "nie ma czego anulować: %s") % String(_prod_info.get(tid, {}).get("nazwa", str(tid)))
	return ok


## PPM w teren przy zaznaczonym budynku produkcyjnym: punkt zbiórki (Core); zwykły rozkaz ruchu nie jest wysyłany.
func _ppm_budynek(ekran: Vector2, _dolacz: bool) -> bool:
	var bud := _budynek_produkcji()
	if bud < 0: return false
	var te := Zaznaczanie.teren(sym.mapa, _kamera.project_ray_origin(ekran), _kamera.project_ray_normal(ekran))
	if te.is_empty():
		sterowanie.komunikat = "kliknięcie poza terenem"; return true
	var p: Vector2 = te.punkt
	var ok: bool = core.ustaw_punkt_zbiorki(bud, p.x, p.y)
	sterowanie.komunikat = "punkt zbiórki (%.2f; %.2f)" % [p.x, p.y] if ok else "punkt zbiórki odrzucony"
	return true


func _zarejestruj_nowa(id: int) -> void:
	var j: Dictionary = core.jednostka(id)
	var typ := int(j.get("typ_db", -1)); var g := int(j.get("gracz", int(uklad.get("gracz_lokalny", 1))))
	var ob: Dictionary = _obiekty.get(typ, {})
	sym.zarejestruj(id, g, typ, maxf(0.15, float(ob.get("Circle selection size", 0.25))), String(ob.get("Name", "")))
	var gid := grafika_obiektu(typ, g)
	var gr: Dictionary = _grafiki.get(gid, {})
	if not gr.is_empty() and String(gr.get("Model path", "")) != "":
		var skala := float(ob.get("Graphic size", 1.0)); if skala <= 0: skala = 1.0
		widok.dodaj(id, String(gr["Model path"]).to_lower().replace("\\", "/") + ".cem",
			String(gr.get("Texture path", "")).to_lower().replace("\\", "/"), _kolor_gracza(g), skala, SekwencjeAnimacji.z_rekordu(gr))
		widok.ustaw_grafike_id(id, gid)
		if widok.has_method("zbuduj"): widok.zbuduj(Zasoby)
	_nowe_z_produkcji.append([sym.takt, id, typ, snappedf(float(j.get("x", 0)), 0.001), snappedf(float(j.get("y", 0)), 0.001)])


func _demo_e52(sekundy: float) -> void:
	var kat := _arg("potyczka-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var bud := -1
	for bid in _budynki_core: bud = int(bid)
	var gl := int(uklad.get("gracz_lokalny", 1))
	var przebieg := {"budynek": bud, "kroki": [], "co_sekunde": []}
	var cel := int(uklad.get("demo_e52", {}).get("jednostek", 2))
	var t := 0.0; var nr := 0
	while t < sekundy and _nowe_z_produkcji.size() < cel:
		await _czekaj(1.0, kat if nr % 10 == 0 else "", "e52_produkcja_%02d" % nr, przebieg)
		var jb: Dictionary = core.jednostka(bud)
		przebieg.co_sekunde.append([sym.takt, int(jb.get("prod_biezaca", -1)), int(jb.get("prod_ms", 0)), int(jb.get("prod_kolejka_n", 0)),
			core.zasoby(gl), int(core.populacja(gl))])
		t += 1.0; nr += 1
	await _czekaj(1.0, kat, "e52_produkcja_koniec", przebieg)
	przebieg["nowe"] = _nowe_z_produkcji
	przebieg["koniec"] = {"zasoby": core.zasoby(gl), "populacja": core.populacja(gl), "limit": core.limit_populacji(gl), "takt": sym.takt}
	_raport_p["demo_e52"] = przebieg
	_koniec_automatu(0)


# Etap 53 – demonstracja produkcji wojskowej (docs/titan/produkcja.md § 5): ukończone koszary produkują jednostki z kolejki
# (rozkazy z układu), automat anuluje jedną pozycję kolejki (jak PPM na przycisku), a każdej nowej jednostce wydaje rozkaz
# ruchu do punktu z układu (zwykły rozkaz gracza – punkt zbiórki nie jest odwzorowany w Core). Raport co sekundę: bieżąca
# pozycja, licznik, kolejka, zasoby, populacja; lista nowych jednostek i ich pozycje końcowe. Cała logika w Core.
func _demo_e53(sekundy: float) -> void:
	var kat := _arg("potyczka-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var bud := -1
	for bid in _budynki_core: bud = int(bid)
	var gl := int(uklad.get("gracz_lokalny", 1))
	var d: Dictionary = uklad.get("demo_e53", {})
	var cel_n := int(d.get("jednostek", 2))
	var cel_ruchu: Array = d.get("cel_ruchu", [])
	var przebieg := {"budynek": bud, "kroki": [], "co_sekunde": [], "anulowanie": {}, "rozkazy_ruchu": []}
	var wyslane := {}
	var t := 0.0; var nr := 0
	var koniec_po := -1.0
	while t < sekundy:
		await _czekaj(1.0, kat if nr % 15 == 0 else "", "e53_koszary_%02d" % nr, przebieg)
		var jb: Dictionary = core.jednostka(bud)
		przebieg.co_sekunde.append([sym.takt, int(jb.get("prod_biezaca", -1)), int(jb.get("prod_ms", 0)), int(jb.get("prod_kolejka_n", 0)),
			core.zasoby(gl), int(core.populacja(gl))])
		if d.has("anuluj_po_s") and przebieg.anulowanie.is_empty() and t >= float(d["anuluj_po_s"]):
			var przed: Array = core.zasoby(gl)
			var ok: bool = core.anuluj_technologie(bud, int(d.get("anuluj_tech", -1)))
			przebieg.anulowanie = {"takt": sym.takt, "wynik": ok, "zasoby_przed": przed, "zasoby_po": core.zasoby(gl),
				"kolejka_po": int(core.jednostka(bud).get("prod_kolejka_n", -1))}
		for n in _nowe_z_produkcji:
			var id := int(n[1])
			if wyslane.has(id) or cel_ruchu.size() < 2: continue
			var k := wyslane.size()
			var cel := Vector2(float(cel_ruchu[0]), float(cel_ruchu[1]) + 0.5 * k)
			sym.rozkaz_grupy([id], cel, false)
			wyslane[id] = cel
			przebieg.rozkazy_ruchu.append({"takt": sym.takt, "id": id, "cel": [cel.x, cel.y]})
		if _nowe_z_produkcji.size() >= cel_n and koniec_po < 0: koniec_po = t + float(d.get("czekaj_na_ruch_s", 12))
		if koniec_po >= 0 and t >= koniec_po: break
		t += 1.0; nr += 1
	await _czekaj(1.0, kat, "e53_koszary_koniec", przebieg)
	var konce := []
	for n in _nowe_z_produkcji:
		var j: Dictionary = core.jednostka(int(n[1]))
		konce.append({"id": int(n[1]), "typ": int(n[2]), "start": [n[3], n[4]], "koniec": [snappedf(float(j.get("x", 0)), 0.001),
			snappedf(float(j.get("y", 0)), 0.001)], "stan": int(j.get("stan", -1)), "cel": [wyslane.get(int(n[1]), Vector2.ZERO).x, wyslane.get(int(n[1]), Vector2.ZERO).y]})
	przebieg["nowe"] = _nowe_z_produkcji
	przebieg["nowe_koniec"] = konce
	przebieg["koniec"] = {"zasoby": core.zasoby(gl), "populacja": core.populacja(gl), "limit": core.limit_populacji(gl), "takt": sym.takt}
	_raport_p["demo_e53"] = przebieg
	_koniec_automatu(0)


## Etap 54: automat interfejsu produkcji – te same ścieżki co gracz: kliknięcie budynku, przyciski panelu (LPM / PPM),
## PPM w teren (punkt zbiórki). Raport: stan panelu, kolejka, zasoby, miejsca powstania i końcowe jednostek.
func _demo_e54(sekundy: float) -> void:
	var kat := _arg("potyczka-zrzuty", "")
	if kat != "": DirAccess.make_dir_recursive_absolute(kat)
	var d: Dictionary = uklad.get("demo_e54", {})
	var gl := int(uklad.get("gracz_lokalny", 1))
	var bud := -1
	for bid in _budynki_core: bud = int(bid)
	var przebieg := {"budynek": bud, "kroki": [], "co_sekunde": []}
	await _czekaj(0.5, "", "", przebieg)
	# 1. zaznaczenie budynku kliknięciem w jego środek
	var jb0: Dictionary = core.jednostka(bud)
	var pb := Vector2(float(jb0.get("x", 0)), float(jb0.get("y", 0)))
	var ekran := _kamera.unproject_position(UkladEE.godot(pb, mapa.wysokosc(pb) + 0.5))
	var klik := sterowanie.klik_lewy(ekran)
	przebieg["klik_budynku"] = {"ekran": [ekran.x, ekran.y], "trafiony": klik, "zaznaczone": widok.zaznaczone.duplicate()}
	if widok.zaznaczone != [bud]:
		widok.zaznaczone.clear(); widok.zaznaczone.append(bud); sterowanie.zaznaczenie.ids = [bud]
		przebieg["klik_budynku"]["zaznaczenie_wymuszone"] = true
	await _czekaj(0.3, "", "", przebieg)
	var przyciski := []
	for ch in _panel_przyciski.get_children(): przyciski.append(String(ch.text).replace("\n", " | "))
	przebieg["panel"] = {"widoczny": _panel_prod.visible, "przyciski": przyciski}
	# 2. trzy pozycje pierwszej technologii (LPM), anulowanie jednej (PPM)
	var tid := int(_prod_dostepne.get(bud, [0])[0])
	var z0: Array = core.zasoby(gl)
	var wyniki := []
	for i in int(d.get("produkuj", 3)):
		var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true
		_wejscie_przycisku(ev, tid)
		wyniki.append(int(core.jednostka(bud).get("prod_kolejka_n", -1)))
	var z1: Array = core.zasoby(gl)
	var evp := InputEventMouseButton.new(); evp.button_index = MOUSE_BUTTON_RIGHT; evp.pressed = true
	_wejscie_przycisku(evp, tid)
	przebieg["produkcja"] = {"tech": tid, "zasoby_przed": z0, "zasoby_po_rozkazach": z1, "kolejka_po_rozkazach": wyniki,
		"zasoby_po_anulowaniu": core.zasoby(gl), "kolejka_po_anulowaniu": int(core.jednostka(bud).get("prod_kolejka_n", -1)),
		"biezaca": int(core.jednostka(bud).get("prod_biezaca", -1))}
	# 3. punkt zbiórki: PPM w teren
	var pz: Array = d.get("zbiorka", [])
	if pz.size() >= 2:
		var pv := Vector2(float(pz[0]), float(pz[1]))
		var ez := _kamera.unproject_position(UkladEE.godot(pv, mapa.wysokosc(pv)))
		var obsl := sterowanie.klik_prawy(ez)
		var jb1: Dictionary = core.jednostka(bud)
		przebieg["zbiorka"] = {"zadany": pz, "obsluzony": obsl, "core": [bool(jb1.get("zbiorka", false)), snappedf(float(jb1.get("zbiorka_x", 0)), 0.001),
			snappedf(float(jb1.get("zbiorka_y", 0)), 0.001)]}
	await _czekaj(0.3, kat, "e54_panel", przebieg)
	przebieg["panel_tekst"] = _panel_opis.text
	# 4. czekanie na jednostki; druga część: zmiana punktu zbiórki po pierwszej jednostce
	var t := 0.0; var nr := 0
	var cel_n := int(d.get("jednostek", 2))
	var koniec_po := -1.0
	var zmieniono := false
	while t < sekundy:
		await _czekaj(1.0, kat if nr % 20 == 19 else "", "e54_%02d" % nr, przebieg)
		var jb: Dictionary = core.jednostka(bud)
		przebieg.co_sekunde.append([sym.takt, int(jb.get("prod_biezaca", -1)), int(jb.get("prod_ms", 0)), int(jb.get("prod_kolejka_n", 0)),
			core.zasoby(gl), int(core.populacja(gl))])
		var pz2: Array = d.get("zbiorka_druga", [])
		if not zmieniono and _nowe_z_produkcji.size() >= 1 and pz2.size() >= 2:
			var pv2 := Vector2(float(pz2[0]), float(pz2[1]))
			widok.zaznaczone.clear(); widok.zaznaczone.append(bud); sterowanie.zaznaczenie.ids = [bud]
			sterowanie.klik_prawy(_kamera.unproject_position(UkladEE.godot(pv2, mapa.wysokosc(pv2))))
			zmieniono = true
			przebieg["zbiorka_druga"] = {"takt": sym.takt, "core": [snappedf(float(core.jednostka(bud).get("zbiorka_x", 0)), 0.001),
				snappedf(float(core.jednostka(bud).get("zbiorka_y", 0)), 0.001)]}
		if _nowe_z_produkcji.size() >= cel_n and koniec_po < 0: koniec_po = t + float(d.get("czekaj_na_ruch_s", 14))
		if koniec_po >= 0 and t >= koniec_po: break
		t += 1.0; nr += 1
	await _czekaj(0.5, kat, "e54_koniec", przebieg)
	var konce := []
	for n in _nowe_z_produkcji:
		var j: Dictionary = core.jednostka(int(n[1]))
		konce.append({"id": int(n[1]), "typ": int(n[2]), "takt": int(n[0]), "start": [n[3], n[4]], "koniec": [snappedf(float(j.get("x", 0)), 0.001),
			snappedf(float(j.get("y", 0)), 0.001)], "stan": int(j.get("stan", -1))})
	przebieg["nowe"] = konce
	przebieg["koniec"] = {"zasoby": core.zasoby(gl), "populacja": core.populacja(gl), "limit": core.limit_populacji(gl), "takt": sym.takt}
	_raport_p["demo_e54"] = przebieg
	_koniec_automatu(0)


func _klik(przycisk: int, p: Vector2, shift := false) -> void:
	for wcisniety in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = przycisk; e.position = p; e.global_position = p; e.pressed = wcisniety; e.shift_pressed = shift
		Input.parse_input_event(e)
		await get_tree().process_frame


func _przeciagnij(a: Vector2, b: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.position = a; e.global_position = a; e.pressed = true
	Input.parse_input_event(e); await get_tree().process_frame
	for i in range(1, 5):
		var m := InputEventMouseMotion.new(); m.position = a.lerp(b, i / 4.0); m.global_position = m.position
		Input.parse_input_event(m); await get_tree().process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT; u.position = b; u.global_position = b; u.pressed = false
	Input.parse_input_event(u); await get_tree().process_frame


func _czekaj(s: float, kat: String, nazwa: String, przebieg: Dictionary) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
	if kat != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(kat.path_join(nazwa + ".png"))
	var poz := {}
	for id in sym.jednostki:
		var j: JednostkaSym = sym.jednostki[id]
		poz[str(id)] = [snappedf(j.pozycja.x, 0.01), snappedf(j.pozycja.y, 0.01), sym.hp[id], sym.stan[id], sym.cel_walki[id]]
	przebieg.kroki.append({"t_takt": sym.takt, "jednostki": poz, "zrzut": nazwa if kat != "" else ""})


func _koniec_automatu(kod: int) -> void:
	# etap 46 (G3): przebieg AI z dziennika zdarzeń Core – rodzaje zdarzeń (trafienie, smierc, leczenie, ucieczka) i
	# kolejka fizyki na końcu (martwe jednostki po 6003 usunięte)
	if core != null and core.has_method("zdarzenia_walki_od"):
		var licz := {}
		for e in core.zdarzenia_walki_od(0): licz[str(e.rodzaj)] = int(licz.get(str(e.rodzaj), 0)) + 1
		_raport_p["zdarzenia_core"] = licz
		_raport_p["kolejka_fizyki_koniec"] = core.kolejka_fizyki()
	var p := _arg("potyczka-raport", "")
	if p != "":
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(raport, "  "))
	if _arg("potyczka-demo", "") != "" or p != "":
		get_tree().quit(kod)


## Etap 46: typy jednostek układu potyczki (zestaw leczonych – przybliżenie do odczytu +0x10C [N]).
func _typy_potyczki(uklad: Dictionary) -> Array:
	var t := []
	for jd in uklad.get("jednostki", []):
		if not t.has(int(jd["typ"])): t.append(int(jd["typ"]))
	return t
