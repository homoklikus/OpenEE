class_name TestyWariantow
extends RefCounted
## Testy etapu 8 (raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md): dekodery dbtechtree/dbevents/dbeffects, blok EE gracza
## w scenariuszu, wybór grafiki wg epoki (WariantyGrafiki), zmiana wariantu bez naruszenia symulacji.
## Jednostkowe – dane syntetyczne; integracyjne – tabele i scenariusze z instalacji EE.

var t


func _init(runner) -> void:
	t = runner


# ---------------------------------------------------------------- dane syntetyczne (formaty jak w grze)

func _rek_tech(nazwa: String, id: int, event: int, epoka: int, budowniczowie: Array) -> PackedByteArray:
	var b := PackedByteArray(); b.resize(272 + 4 * budowniczowie.size())
	b.fill(0)
	var nb := nazwa.to_ascii_buffer()
	for i in nb.size(): b[i] = nb[i]
	b.encode_s32(100, id + 10); b.encode_s32(104, id); b.encode_s32(108, 0); b.encode_s32(112, 15)
	b.encode_s32(116, event); b.encode_s32(172, -1); b.encode_s32(188, 2 if epoka > 0 else 1)
	b.encode_s32(252, epoka); b.encode_s32(268, budowniczowie.size())
	for i in budowniczowie.size(): b.encode_s32(272 + 4 * i, budowniczowie[i])
	return b


func _techtree() -> PackedByteArray:
	# grupa 0: Epoka A (id 0, zdarzenie 0) + 1 dziecko (technologia 100 → zdarzenie 2); grupa 1: Epoka B (id 1, zdarzenie 1)
	var d := PackedByteArray()
	var n := PackedByteArray(); n.resize(4); n.encode_s32(0, 1); d.append_array(n)
	d.append_array(_rek_tech("Epoch A", 0, 0, 1, [35, 41]))
	d.append_array(_rek_tech("Upgrade X", 100, 2, 0, []))
	n.encode_s32(0, 0); d.append_array(n)
	d.append_array(_rek_tech("Epoch B", 1, 1, 2, [7]))
	return d


func _zdarzenia() -> PackedByteArray:
	var d := PackedByteArray()
	for ev in [[500], [501, 502, 503], [504]]:
		var b := PackedByteArray(); b.resize(108 + 4 * ev.size()); b.fill(0)
		b.encode_s32(100, 1); b.encode_s32(104, ev.size())
		for i in ev.size(): b.encode_s32(108 + 4 * i, ev[i])
		d.append_array(b)
	return d


func _efekty() -> PackedByteArray:
	# [ID, kod, obiekt, grafika]: 500 – epoka A: obiekt 10 → 110; 501 – B: 10 → 120; 502 – B: kod 1 (atrybut, ignorowany);
	# 503 – B: obiekt 20 → 220; 504 – technologia X: obiekt 20 → 230
	var d := PackedByteArray()
	for e in [[500, 6, 10, 110], [501, 6, 10, 120], [502, 1, 10, 999], [503, 6, 20, 220], [504, 6, 20, 230]]:
		var b := PackedByteArray(); b.resize(88); b.fill(0)
		b.encode_s32(4, e[0]); b.encode_s32(32, e[1]); b.encode_s32(20, e[2]); b.encode_s32(36, e[3]); b.encode_s32(28, -1)
		d.append_array(b)
	return d


func uruchom(Kf, Z) -> void:
	var tt := EpokiDB.techtree(_techtree())
	t._ok("W8 dbtechtree: grupy epok (licznik dzieci, rekord 272 B + budowniczowie)",
		tt.size() == 3 and tt[0].nazwa == "Epoch A" and tt[0].glowa_grupy and not tt[1].glowa_grupy and tt[2].glowa_grupy
		and int(tt[2].epoka) == 2 and int(tt[1].event) == 2 and int(tt[2].grupa) == 1, tt.map(func(x): return [x.nazwa, x.id, x.event, x.epoka]))
	var zd := EpokiDB.zdarzenia(_zdarzenia())
	var ef := EpokiDB.efekty(_efekty())
	t._ok("W8 dbevents i dbeffects: listy efektów zdarzeń, pola kodu, obiektu i nowej grafiki",
		zd.size() == 3 and Array(zd[1].efekty) == [501, 502, 503] and int(ef[503].obiekt) == 20 and int(ef[503].grafika) == 220
		and int(ef[502].kod) == 1, [zd.size(), ef.size()])
	var bledny := _zdarzenia(); bledny.resize(bledny.size() - 3)
	t._ok("W8 dekodery odrzucają dane niezgodne z formatem (ucięte dbevents, dbeffects nie × 88 B)",
		EpokiDB.zdarzenia(bledny).is_empty() and EpokiDB.efekty(PackedByteArray([1, 2, 3])).is_empty())
	var ob := {10: {"Graphic ID": 100}, 20: {"Graphic ID": 200}, 30: {"Graphic ID": 300}}
	var w := WariantyGrafiki.z_tabel(tt, zd, ef, ob)
	t._ok("W8 wybór grafiki: bazowa (bez epoki) → epoka A → epoka B (zmiany wszystkich epok ≤ E, rosnąco)",
		w.gotowe and w.grafika(10, -1) == 100 and w.grafika(10, 0) == 110 and w.grafika(10, 1) == 120
		and w.grafika(20, 0) == 200 and w.grafika(20, 1) == 220 and w.grafika(30, 1) == 300,
		[w.grafika(10, -1), w.grafika(10, 0), w.grafika(10, 1), w.grafika(20, 1)])
	t._ok("W8 wybór grafiki: efekty innych kodów nie zmieniają grafiki; technologia nie-epokowa nakładana po epokach",
		w.grafika(10, 1, [100]) == 120 and w.grafika(20, 1, [100]) == 230 and w.grafika(20, 0, [100]) == 230
		and w.grafika(20, 1, [0]) == 220)
	t._ok("W8 numer i technologia epoki z danych (głowy grup dbtechtree)",
		w.numer_epoki(0) == 1 and w.numer_epoki(1) == 2 and w.numer_epoki(100) == 0 and w.tech_epoki_nr(2) == 1 and w.tech_epoki_nr(9) == -1)
	var pusty := WariantyGrafiki.z_tabel([], [], {}, ob)
	t._ok("W8 brak tabel epok → grafika bazowa (zachowanie sprzed etapu 8)", not pusty.gotowe and pusty.grafika(10, 1) == 100)
	# blok EE gracza
	var be := PackedByteArray(); be.resize(17 + 7 * 3 + 12); be.fill(0)
	be.encode_u32(0, 825); be[4] = 1; be.encode_u32(5, 15); be.encode_u32(9, 1); be.encode_u32(13, 3)
	for k in 3:
		be.encode_u32(17 + 7 * k, [4, 1005, 1017][k]); be[17 + 7 * k + 4] = 1 if k != 2 else 0
	be.encode_s32(38, 4); be.encode_s32(42, 4); be.encode_s32(46, 4)
	var bl := ScenariuszEE.blok_ee(be, 0)
	t._ok("W8 blok EE gracza: epoka (ID technologii) i lista zbadanych technologii",
		int(bl.get("epoka_tech", -1)) == 4 and Array(bl.get("zbadane", [])) == [4, 1005] and ScenariuszEE.blok_ee(be, 1).is_empty(), bl)

	if not Kf.instalacje.has("referencyjna") or not Z.gotowe:
		t._pomin(["W8 dane: tabele epok AoC – 15 epok, zmiany grafiki wg zdarzeń",
			"W8 dane: Rzym – epoki graczy z bloku EE (Rzymianie: mroczne/brązu, barbarzyńcy: miedzi)",
			"W8 dane: Rzym – fort i obywatel gracza 1 = wariant epoki brązu (model, tekstura)",
			"W8 dane: Troja (EE) – warianty epoki miedzi i brązu",
			"W8 dane: zmiana wariantu jednostki w trakcie symulacji – stan symulacji i animacji zachowany"], "brak instalacji EE")
		return
	await _integracyjne(Kf, Z)


func _integracyjne(Kf, Z) -> void:
	var w := WariantyGrafiki.z_zasobow(Z)
	var liczby := {}
	for e in w.epoki: liczby[String(e.nazwa)] = w.zmiany_zdarzenia(int(e.event)).size()
	t._ok("W8 dane: tabele epok AoC – 15 epok, zmiany grafiki wg zdarzeń",
		w.gotowe and w.epoki.size() == 15 and int(liczby.get("Epoch Bronze", 0)) == 22 and int(liczby.get("Epoch Dark", 0)) == 1
		and int(liczby.get("Epoch Atomic - WW2", -1)) == 0 and w.numer_epoki(4) == 5, liczby)
	var graf := {}
	for r in Z.tabela("dbgraphics"): graf[int(r.ID)] = r
	var s: ScenariuszEE = t._scn(Z, "Empire Earth - The Art of Conquest", "AOCRoman.ssa", "soldiers")
	if s == null or not s.czytaj_graczy(Kf.katalog_openee):
		t._ok("W8 dane: Rzym – epoki graczy z bloku EE (Rzymianie: mroczne/brązu, barbarzyńcy: miedzi)", false, "brak scenariusza")
		return
	var ep: Array = []
	for g in s.gracze.size(): ep.append(w.nazwa_technologii(s.epoka_gracza(g)))
	t._ok("W8 dane: Rzym – epoki graczy z bloku EE (Rzymianie: mroczne/brązu, barbarzyńcy: miedzi)",
		ep.size() >= 9 and ep[1] == "Epoch Dark" and ep[2] == "Epoch Bronze" and ep[6] == "Epoch Copper" and ep[8] == "Epoch Copper", ep)
	var gf := w.grafika(672, s.epoka_gracza(1)); var go := w.grafika(32, s.epoka_gracza(1))
	t._ok("W8 dane: Rzym – fort i obywatel gracza 1 = wariant epoki brązu (model, tekstura)",
		gf == 746 and go == 283 and String(graf[gf]["Model path"]).to_lower().ends_with("bld_fortress_04")
		and String(graf[go]["Texture path"]).to_lower().ends_with("men_citizen_04t.sst") and w.grafika_bazowa(672) == 742,
		[gf, graf.get(gf, {}).get("Name 1"), go, graf.get(go, {}).get("Name 1")])
	var tr: ScenariuszEE = t._scn(Z, "Empire Earth", "EETheGreeks.ssa", "trojan war")
	if tr != null and tr.czytaj_graczy(Kf.katalog_openee):
		var e1 := tr.epoka_gracza(1); var e5 := tr.epoka_gracza(5)
		t._ok("W8 dane: Troja (EE) – warianty epoki miedzi i brązu",
			w.nazwa_technologii(e1) == "Epoch Copper" and w.nazwa_technologii(e5) == "Epoch Bronze" and w.grafika(32, e1) == 55
			and w.grafika(672, e5) == 746 and w.grafika(37, e1) == 170, [w.nazwa_technologii(e1), w.nazwa_technologii(e5)])
	else:
		t._ok("W8 dane: Troja (EE) – warianty epoki miedzi i brązu", false, "brak scenariusza")
	await _zmiana_w_symulacji(Z, w, graf)


func _sciezka(gr: Dictionary, pole: String) -> String:
	return String(gr.get(pole, "")).to_lower().replace("\\", "/")


func _zmiana_w_symulacji(Z, w: WariantyGrafiki, graf: Dictionary) -> void:
	var kat := PackedByteArray(); kat.resize(20 * 20); kat.fill(MapaNawigacji.LAD)
	var m := MapaNawigacji.z_tablic(20, 20, kat, PackedFloat32Array(), 2)
	var sym := Symulacja.new(m)
	var ob := {"Name": "Citizen", "Speed": 1.0, "Idle turning speed": 6.0, "Moving turning speed": 8.0, "Circle selection size": 0.3}
	var widok := WidokJednostek.new(sym, null)
	t.root.add_child(widok)
	var ids: Array = []
	for i in 3:
		var d := JednostkaSym.DaneJednostki.new(); d.typ = 32; d.wlasciciel = 1; d.pozycja = Vector2(3 + i, 4)
		var id := sym.dodaj_jednostke(d, ob)
		var gr: Dictionary = graf[w.grafika(32, -1)]
		widok.dodaj(id, _sciezka(gr, "Model path") + ".cem", _sciezka(gr, "Texture path"), Color(1, 0, 0), 1.0, SekwencjeAnimacji.z_rekordu(gr))
		widok.ustaw_grafike_id(id, int(gr.ID))
		ids.append(id)
	widok.zbuduj(Z)
	sym.rozkaz_ruchu(ids[0], Vector2(15.5, 12.5))
	for k in 20: sym.krok()
	widok._animuj(ids[0], "ruch")
	var przed := sym.skrot_stanu()
	var poz := (sym.jednostki[ids[0]] as JednostkaSym).pozycja
	var kanal: int = widok._jedn[ids[0]].kanal
	var kanaly := widok.odtw.liczba_kanalow()
	var g2: Dictionary = graf[w.grafika(32, w.tech_epoki_nr(4))]
	for id in ids.slice(0, 2):
		widok.zmien_grafike(id, _sciezka(g2, "Model path") + ".cem", _sciezka(g2, "Texture path"), SekwencjeAnimacji.z_rekordu(g2), int(g2.ID))
	var pb := widok.przebuduj(Z)
	var po := sym.skrot_stanu()
	var e0: Dictionary = widok._jedn[ids[0]]; var e2: Dictionary = widok._jedn[ids[2]]
	var ok_mm: bool = e0.mm != null and e2.mm != null and e0.mm != e2.mm and (e0.mm as MultiMesh).instance_count == 2 \
		and (e2.mm as MultiMesh).instance_count == 1
	var ok_anim: bool = int(e0.kanal) == kanal and widok.odtw.liczba_kanalow() == kanaly and String(e0.stan) == "ruch" \
		and widok.odtw.sekwencja(kanal) == (e0.sek as SekwencjeAnimacji).dla_stanu("ruch")
	for k in 600: sym.krok()
	t._ok("W8 dane: zmiana wariantu jednostki w trakcie symulacji – stan symulacji i animacji zachowany",
		przed == po and ok_mm and ok_anim and widok.grafika_id(ids[0]) == int(g2.ID) and widok.grafika_id(ids[2]) == 54
		and (sym.jednostki[ids[0]] as JednostkaSym).pozycja.distance_to(Vector2(15.5, 12.5)) < 0.1 and poz.distance_to(Vector2(3, 4)) > 0.1,
		[pb, ok_mm, ok_anim, przed == po, (sym.jednostki[ids[0]] as JednostkaSym).pozycja, widok.klucz_modelu(ids[0]), widok.klucz_modelu(ids[2])])
	widok.queue_free()
	t._ok("W8 testy integracyjne wariantów wykonane do końca (bez błędu skryptu)", true)
