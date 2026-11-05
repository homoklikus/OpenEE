class_name TestyEtapu5
extends RefCounted
## Testy etapu 5: nawigacja, symulacja jednostek, zaznaczanie, stały krok, integracja z animacją.
## Jednostkowe – syntetyczne mapy (bez danych komercyjnych); integracyjne – scenariusz EE z instalacji.

var t
var _koniec_j := false
var _koniec_i := false
const L := MapaNawigacji.LAD
const G := MapaNawigacji.GLEBOKA
const P := MapaNawigacji.PLYTKA
const K := MapaNawigacji.KLIF
const X := MapaNawigacji.POZA


func _init(runner) -> void:
	t = runner


## Mapa w×h pól z kategoriami z napisu wierszami ('.' ląd, '~' głęboka, ',' płytka, '^' klif, '#' poza).
func _mapa(wiersze: Array, wys: PackedFloat32Array = PackedFloat32Array(), pd: int = 2) -> MapaNawigacji:
	var h := wiersze.size(); var w := String(wiersze[0]).length()
	var kat := PackedByteArray(); kat.resize(w * h)
	var znaki := {".": L, "~": G, ",": P, "^": K, "#": X}
	for r in h:
		for c in w:
			kat[r * w + c] = znaki[String(wiersze[r])[c]]
	return MapaNawigacji.z_tablic(h, w, kat, wys, pd)


func _trasa_ok(m: MapaNawigacji, s: Sciezki, start: Vector2, sc: PackedVector2Array, pol: PolitykaRuchu) -> bool:
	var a := start
	for p in sc:
		if not s.widoczne(a, p, pol): return false
		a = p
	return true


func _dlugosc(start: Vector2, sc: PackedVector2Array) -> float:
	var d := 0.0; var a := start
	for p in sc:
		d += a.distance_to(p); a = p
	return d


func _jednostka(sym: Symulacja, p: Vector2, kurs := 0.0, ob := {}) -> int:
	var d := JednostkaSym.DaneJednostki.new()
	d.typ = 1; d.pozycja = p; d.kurs = kurs
	var o := ob.duplicate()
	if o.is_empty():
		o = {"Name": "test", "Speed": 1.0, "Idle turning speed": 6.0, "Moving turning speed": 8.0, "Circle selection size": 0.3}
	return sym.dodaj_jednostke(d, o)


func _do_konca(sym: Symulacja, id: int, maks: int = 2000) -> int:
	var n := 0
	while n < maks:
		sym.krok(); n += 1
		if not sym.jednostki[id].w_ruchu() and n > 1: break
	return n


func uruchom(Kf, Z) -> void:
	_jednostkowe()
	t._ok("E5 testy jednostkowe wykonane do końca (bez błędu skryptu)", _koniec_j)
	if not Kf.instalacje.has("referencyjna") or not Z.gotowe:
		t._pomin(["E5 dane: flagi nawierzchni dbobjects (obywatel, falanga, okręt)",
			"E5 dane: Troja – mapa nawigacji z klas punktów (woda głęboka/płytka, klify, granice rombu)",
			"E5 dane: Troja – trasa jednostki lądowej, odrzucenie celu w wodzie",
			"E5 dane: przód modelu (punkt attack) zgodny z kierunkiem ruchu",
			"E5 dane: sekwencje ruchu i bezczynności jednostek Troi (brak = diagnostyka, nie błąd ruchu)"], "brak instalacji EE")
		return
	_integracyjne(Kf, Z)
	t._ok("E5 testy integracyjne wykonane do końca (bez błędu skryptu)", _koniec_i)


func _jednostkowe() -> void:
	var pol := PolitykaRuchu.new()     # domyślna lądowa: ląd, woda płytka; bez wody głębokiej i klifów
	var okret := PolitykaRuchu.new(PackedByteArray([0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1]), false, "okręt")
	# --- omijanie przeszkody ---
	var m := _mapa(["..........", "..........", "..........", "..........", "..........", "..........", "..........", "..........", "..........", ".........."])
	for y in range(0, 16): m.blokady[m.indeks(Vector2i(10, y))] = 1      # mur w kolumnie x=5,0–5,5 do wiersza 8, przejście na dole
	var s := Sciezki.new(m)
	var w := s.znajdz(Vector2(2.5, 2.5), Vector2(8.5, 2.5), pol)
	t._ok("E5 trasy: omijanie przeszkody (A*, trasa przez przejście, bez przecinania muru)",
		w.ok and _trasa_ok(m, s, Vector2(2.5, 2.5), w.sciezka, pol) and _dlugosc(Vector2(2.5, 2.5), w.sciezka) > 9.0
		and w.sciezka[w.sciezka.size() - 1].is_equal_approx(Vector2(8.5, 2.5)),
		[w.ok, w.powod, w.sciezka, _dlugosc(Vector2(2.5, 2.5), w.sciezka)])
	var w2 := s.znajdz(Vector2(2.5, 2.5), Vector2(4.2, 6.0), pol)
	t._ok("E5 trasy: bez przeszkody – linia prosta po wygładzeniu (1 punkt)", w2.ok and w2.sciezka.size() == 1, w2.sciezka)
	# --- woda ---
	var mw := _mapa(["....~~....", "....~~....", "....~~....", "....~~....", "....,,....", "....~~....", "....~~...."], PackedFloat32Array(), 2)
	var sw := Sciezki.new(mw)
	var wa := sw.znajdz(Vector2(1.5, 1.5), Vector2(8.5, 1.5), pol)
	t._ok("E5 trasy: woda płytka przechodnia dla jednostki lądowej (bród), głęboka – nie",
		wa.ok and _trasa_ok(mw, sw, Vector2(1.5, 1.5), wa.sciezka, pol) and wa.sciezka.size() >= 2, [wa.ok, wa.powod, wa.sciezka])
	mw.kategorie[4 * 10 + 4] = G; mw.kategorie[4 * 10 + 5] = G
	sw.uniewaznij()
	var wb := sw.znajdz(Vector2(1.5, 1.5), Vector2(8.5, 1.5), pol)
	var wc := sw.znajdz(Vector2(1.5, 1.5), Vector2(4.5, 2.5), pol)
	t._ok("E5 trasy: woda głęboka blokuje – cel za wodą nieosiągalny, cel w wodzie niedostępny (z przyczyną)",
		not wb.ok and "nieosiągalny" in String(wb.powod) and not wc.ok and "woda głęboka" in String(wc.powod) and wb.odwiedzone == 0,
		[wb.powod, wc.powod, wb.odwiedzone])
	var wo := sw.znajdz(Vector2(4.5, 1.5), Vector2(4.5, 6.5), okret)
	var wl := sw.znajdz(Vector2(4.5, 1.5), Vector2(1.5, 1.5), okret)
	t._ok("E5 trasy: polityka okrętu – woda tak, ląd nie (flagi dbobjects)", wo.ok and not wl.ok and "ląd" in String(wl.powod), [wo.ok, wl.powod])
	# --- granice mapy i klify ---
	var mg := _mapa(["##....", "#.....", "......", "...^^.", "...^^.", "......"])
	var sg := Sciezki.new(mg)
	var g1 := sg.znajdz(Vector2(3.5, 1.5), Vector2(0.5, 0.5), pol)
	var g2 := sg.znajdz(Vector2(3.5, 1.5), Vector2(-3.0, 2.0), pol)
	var g3 := sg.znajdz(Vector2(2.5, 2.5), Vector2(5.5, 5.5), pol)
	t._ok("E5 trasy: granica mapy (romb, poza siatką) i klify nieprzekraczalne dla piechoty",
		not g1.ok and "poza mapą" in String(g1.powod) and not g2.ok and g3.ok and _trasa_ok(mg, sg, Vector2(2.5, 2.5), g3.sciezka, pol)
		and not sg.znajdz(Vector2(2.5, 2.5), Vector2(3.5, 3.5), pol).ok, [g1.powod, g2.powod, g3.sciezka])
	# --- wysokość: koszt, nie blokada ---
	var wys := PackedFloat32Array(); wys.resize(11 * 11)
	for r in 11:
		for c in 11:
			wys[r * 11 + c] = 10.0 if (c >= 4 and c <= 6 and r <= 7) else 0.0   # wzgórze z „przełęczą” w dolnych wierszach
	var mh := _mapa(["..........", "..........", "..........", "..........", "..........", "..........", "..........", "..........", "..........", ".........."], wys)
	var sh := Sciezki.new(mh)
	var wh := sh.znajdz(Vector2(1.5, 1.5), Vector2(9.5, 1.5), pol)
	var maks_h := 0.0
	var a := Vector2(1.5, 1.5)
	for p in wh.sciezka:
		for k in 20: maks_h = maxf(maks_h, mh.wysokosc(a.lerp(p, k / 20.0)))
		a = p
	t._ok("E5 trasy: wysokość zwiększa koszt (objazd wzgórza), nie blokuje (bez progu nachylenia)",
		wh.ok and maks_h < 9.0 and _dlugosc(Vector2(1.5, 1.5), wh.sciezka) > 8.5, [wh.ok, maks_h, _dlugosc(Vector2(1.5, 1.5), wh.sciezka)])
	# --- symulacja: rozkaz, obrót, ruch, zatrzymanie, animacje ---
	var ms := _mapa(["............", "............", "............", "............", "............", "............", "............", "............"], PackedFloat32Array(), 2)
	var sym := Symulacja.new(ms)
	var id := _jednostka(sym, Vector2(2.5, 2.5), UkladEE.kat_kierunku(Vector2(-1, 0)))   # patrzy w lewo, cel w prawo
	sym.rozkaz_ruchu(id, Vector2(9.5, 2.5))
	var j: JednostkaSym = sym.jednostki[id]
	sym.krok()
	var st1 := j.ruch; var poz1 := j.pozycja
	var zd: Array = []
	var n := 0
	while j.w_ruchu() and n < 500:
		sym.krok(); n += 1
		for e in sym.zdarzenia:
			if e.typ == "animacja": zd.append(e.stan)
	t._ok("E5 ruch: obrót w miejscu przed ruchem (różnica kursu > 45°), potem przemieszczenie",
		st1 == JednostkaSym.Ruch.OBROT and poz1.is_equal_approx(Vector2(2.5, 2.5)), [st1, poz1])
	t._ok("E5 ruch: dotarcie do celu, zatrzymanie, animacje bezczynność → ruch → bezczynność (bez teleportu)",
		j.pozycja.distance_to(Vector2(9.5, 2.5)) < 0.06 and not j.w_ruchu() and zd == ["ruch", "bezczynnosc"]
		and absf(UkladEE.roznica_katow(j.kurs, UkladEE.kat_kierunku(Vector2(1, 0)))) < 0.01 and n > int(7.0 / (1.0 * Symulacja.KROK)) - 5,
		[j.pozycja, zd, n, rad_to_deg(j.kurs)])
	# prędkość: 7 pól przy 1 pole/s ≈ 7 s (+ obrót)
	t._ok("E5 ruch: prędkość z danych (pola/s) – czas przejścia zgodny z odległością / prędkością",
		absf(n * Symulacja.KROK - (7.0 + PI / 6.0)) < 0.3, "%.2f s" % (n * Symulacja.KROK))
	# --- zastąpienie rozkazu ---
	sym.rozkaz_ruchu(id, Vector2(2.5, 6.5))
	for i in 10: sym.krok()
	sym.rozkaz_ruchu(id, Vector2(11.0, 0.8))
	_do_konca(sym, id)
	t._ok("E5 ruch: nowy rozkaz zastępuje poprzedni", j.pozycja.distance_to(Vector2(11.0, 0.8)) < 0.06 and j.cel.is_equal_approx(Vector2(11.0, 0.8)), j.pozycja)
	# --- rozkaz nieosiągalny: zostaje, przyczyna w diagnostyce ---
	var sw2 := Symulacja.new(mw)
	var id2 := _jednostka(sw2, Vector2(1.5, 1.5))
	sw2.rozkaz_ruchu(id2, Vector2(8.5, 1.5))
	for i in 20: sw2.krok()
	var j2: JednostkaSym = sw2.jednostki[id2]
	t._ok("E5 ruch: cel nieosiągalny – jednostka zostaje na miejscu, przyczyna w diagnostyce",
		j2.pozycja.is_equal_approx(Vector2(1.5, 1.5)) and not j2.w_ruchu() and "nieosiągalny" in j2.ostatni_powod and not sw2.dziennik.is_empty(),
		[j2.ostatni_powod, sw2.dziennik.back() if not sw2.dziennik.is_empty() else ""])
	# --- stały krok, niezależność od FPS, deterministyczność ---
	var wyniki: Array = []
	for fps in [60.0, 17.0, 144.0]:
		var sx := Symulacja.new(ms)
		var ids := [_jednostka(sx, Vector2(1.5, 1.5)), _jednostka(sx, Vector2(10.5, 6.5), 1.0), _jednostka(sx, Vector2(6.5, 1.5), 2.0)]
		sx.rozkaz_ruchu(ids[0], Vector2(10.5, 6.0)); sx.rozkaz_ruchu(ids[1], Vector2(1.2, 1.2)); sx.rozkaz_ruchu(ids[2], Vector2(6.5, 7.5))
		var zg := ZegarSymulacji.new(sx)
		var zapis := []
		var zapisz := func(_z):
			if sx.takt == 90:
				zapis.append(sx.skrot_stanu())
		zg.po_takcie.connect(zapisz)
		while sx.takt < 90:
			zg.przesun(1.0 / fps)
		wyniki.append([sx.takt, zapis[0] if not zapis.is_empty() else ""])
		zg.free()
	t._ok("E5 stały krok: wynik po 90 taktach niezależny od FPS (60, 17, 144 kl./s) i powtarzalny",
		wyniki[0][1] != "" and wyniki[0][1] == wyniki[1][1] and wyniki[1][1] == wyniki[2][1],
		[wyniki[0][0], wyniki[1][0], wyniki[2][0], String(wyniki[0][1]).left(80)])
	var zg2 := ZegarSymulacji.new(Symulacja.new(ms))
	var nt := zg2.przesun(0.123)
	t._ok("E5 stały krok: akumulator (0,123 s → 2 takty po 0,05 s, reszta do interpolacji renderu)",
		nt == 2 and absf(zg2.alfa - 0.46) < 1e-3 and zg2.sym.takt == 2, [nt, zg2.alfa])
	zg2.free()
	# --- utrzymanie na terenie ---
	var wys2 := PackedFloat32Array(); wys2.resize(13 * 9)
	for r in 9:
		for c in 13: wys2[r * 13 + c] = 0.4 * c + 0.2 * sin(r)
	var mt := _mapa(["............", "............", "............", "............", "............", "............", "............", "............"], wys2)
	var st := Symulacja.new(mt)
	var id3 := _jednostka(st, Vector2(1.2, 1.3))
	var widok := WidokJednostek.new(st, null)
	st.rozkaz_ruchu(id3, Vector2(10.7, 6.6))
	var maks_odch := 0.0
	for i in 400:
		st.krok()
		for al in [0.0, 0.37, 0.81]:
			var j3: JednostkaSym = st.jednostki[id3]
			var tr := widok.transformacja(j3, al)
			var p := j3.pozycja_poprz.lerp(j3.pozycja, al)
			maks_odch = maxf(maks_odch, absf(tr.origin.y - mt.wysokosc(p)))
	t._ok("E5 ruch: jednostka na powierzchni terenu (zbocze, interpolacja renderu) – bez unoszenia i zapadania",
		maks_odch < 1e-4 and st.jednostki[id3].pozycja.distance_to(Vector2(10.7, 6.6)) < 0.06, maks_odch)
	widok.free()
	# --- zaznaczanie (bez renderera) ---
	var mz := _mapa(["..........", "..........", "..........", "..........", "..........", "..........", "..........", ".........."], PackedFloat32Array())
	var sz := Symulacja.new(mz)
	var u1 := _jednostka(sz, Vector2(3.0, 3.0)); var u2 := _jednostka(sz, Vector2(6.0, 3.0))
	var oko := Vector3(3.0, 20.0, 3.0 + 10.0)
	var kl1 := Zaznaczanie.klik(sz, oko, Vector3(3.0, 0.5, 3.0) - oko)
	var kl2 := Zaznaczanie.klik(sz, oko, Vector3(5.0, 0.0, 6.0) - oko)
	var oko2 := Vector3(-10.0, 0.6, 3.0)                          # promień poziomy: najpierw u1, za nią u2
	var kl3 := Zaznaczanie.klik(sz, oko2, Vector3(1, 0, 0))
	t._ok("E5 zaznaczanie: trafienie jednostki, puste miejsce → teren, bliższa jednostka przesłania dalszą",
		kl1.jednostka == u1 and kl2.jednostka == -1 and kl2.teren != null and (kl2.teren as Vector2).distance_to(Vector2(5.0, 6.0)) < 0.05
		and kl3.jednostka == u1, [kl1, kl2, kl3])
	var wysz := PackedFloat32Array(); wysz.resize(11 * 9)
	for r in 9:
		for c in 11: wysz[r * 11 + c] = 3.0 if c == 4 else 0.0     # grzbiet między kamerą a jednostką
	var mz2 := _mapa(["..........", "..........", "..........", "..........", "..........", "..........", "..........", ".........."], wysz)
	var sz2 := Symulacja.new(mz2)
	var u3 := _jednostka(sz2, Vector2(7.0, 3.0))
	var kl4 := Zaznaczanie.klik(sz2, Vector3(0.0, 1.0, 3.0), Vector3(1, 0, 0))
	t._ok("E5 zaznaczanie: teren zasłaniający jednostkę – trafia teren, nie jednostkę za nim",
		kl4.jednostka == -1 and kl4.teren != null and (kl4.teren as Vector2).x < 4.1, kl4)
	# --- niezależność od renderera: symulacja bez węzłów i bez drzewa sceny ---
	t._ok("E5 architektura: Symulacja/MapaNawigacji/Sciezki/JednostkaSym bez węzłów (RefCounted), widok tylko czyta",
		_bez_wezlow([sym, ms, sym.sciezki, j, pol])
		and _zegar_jest_wezlem(), "")
	# --- wydajność ---
	var duza_k := PackedByteArray(); duza_k.resize(64 * 64); duza_k.fill(L)
	for r in range(5, 60): duza_k[r * 64 + 30] = G
	var md := MapaNawigacji.z_tablic(64, 64, duza_k, PackedFloat32Array(), 2)
	var sd := Symulacja.new(md)
	var los := RandomNumberGenerator.new(); los.seed = 11
	var t0 := Time.get_ticks_usec()
	for i in 50:
		var uid := _jednostka(sd, Vector2(los.randf_range(1, 25), los.randf_range(1, 63)))
		sd.rozkaz_ruchu(uid, Vector2(los.randf_range(35, 63), los.randf_range(1, 63)))
	sd.krok()
	var t1 := Time.get_ticks_usec()
	for i in 100: sd.krok()
	var t2 := Time.get_ticks_usec()
	var w_ruchu := sd.lista().filter(func(x): return x.w_ruchu()).size()
	t._ok("E5 wydajność: 50 jednostek, trasy na mapie 64×64 (128×128 komórek) wokół wody, 100 taktów",
		w_ruchu == 50 and (t2 - t1) / 100.0 < 5000.0,
		"trasy+pierwszy takt %.1f ms (%.2f ms/trasa), takt %.3f ms, w ruchu %d" % [(t1 - t0) / 1000.0, sd.czas_tras_us / 1000.0 / 50.0, (t2 - t1) / 100000.0, w_ruchu])
	_koniec_j = true


func _bez_wezlow(obiekty: Array) -> bool:
	for o in obiekty:
		var ob: Object = o
		if ob.is_class("Node") or not ob.is_class("RefCounted"): return false
	return true


func _zegar_jest_wezlem() -> bool:
	var z := ZegarSymulacji.new()
	var w := z is Node
	z.free()
	return w


func _integracyjne(Kf, Z) -> void:
	var obiekty := {}
	for o in Z.tabela("dbobjects"): obiekty[int(o.ID)] = o
	var obyw: Dictionary = obiekty.get(32, {}); var fal: Dictionary = obiekty.get(25, {}); var okr: Dictionary = obiekty.get(251, {})
	var po := PolitykaRuchu.z_obiektu(obyw); var pf := PolitykaRuchu.z_obiektu(fal); var pk := PolitykaRuchu.z_obiektu(okr)
	t._ok("E5 dane: flagi nawierzchni dbobjects (obywatel, falanga, okręt)",
		po.dozwolona(L) and po.dozwolona(P) and not po.dozwolona(G) and not po.dozwolona(K) and pf.dozwolona(L) and not pf.dozwolona(G)
		and pk.dozwolona(G) and not pk.dozwolona(L) and is_equal_approx(float(fal.get("Speed", 0)), 0.6),
		[String(obyw.get("Name", "")), String(fal.get("Name", "")), String(okr.get("Name", "")), po.flagi, pk.flagi])
	var s: ScenariuszEE = t._scn(Z, "Empire Earth", "EETheGreeks.ssa", "trojan war")
	if s == null:
		t._ok("E5 dane: Troja – mapa nawigacji z klas punktów (woda głęboka/płytka, klify, granice rombu)", false, "brak scenariusza")
		_koniec_i = true; return
	var klify: Array = []
	for r in Z.tabela("dbcliffterrain"):
		klify.append(int(r["Terrain ID"])); klify.append(int(r["Terrain ID#2"]))
	var m := MapaNawigacji.z_scenariusza(s, klify, Kf.skala_wysokosci, 2)
	var kat: Dictionary = m.opis.kategorie
	var wys_wody_ok := true
	for r in range(0, s.teren.N + 1, 7):
		for c in range(0, s.teren.N + 1, 7):
			var i := s.indeks_punktu(r, c)
			if i >= 0 and int(s.teren.klasa[i]) >= 0xA8 and int(s.teren.klasa[i]) <= 0xAF and s.teren.wysokosc[i] >= 0.0: wys_wody_ok = false
	t._ok("E5 dane: Troja – mapa nawigacji z klas punktów (woda głęboka/płytka, klify, granice rombu)",
		kat.lad > 10000 and kat.gleboka > 10000 and kat.plytka > 0 and kat.klif > 0 and kat.poza > 0 and wys_wody_ok
		and m.kategoria_punktu(Vector2(0.5, 0.5)) == X, [kat, wys_wody_ok])
	var sc := Sciezki.new(m)
	var start := Vector2(142.64, 220.64); var cel := Vector2(150.96, 217.2)
	var w := sc.znajdz(start, cel, pf)
	var woda := Vector2(120.5, 200.5)
	var ww := sc.znajdz(start, woda, pf)
	t._ok("E5 dane: Troja – trasa jednostki lądowej, odrzucenie celu w wodzie",
		w.ok and _trasa_ok(m, sc, start, w.sciezka, pf) and m.kategoria_punktu(woda) == G and not ww.ok and "woda głęboka" in String(ww.powod),
		[w.ok, w.sciezka.size(), w.czas_us, ww.powod])
	# przód modelu: punkt attack (falanga, klatka sekwencji ruchu) po transformacji jednostki wskazuje kierunek ruchu
	var mf: ModelCEM = Z.wczytaj_model_cem("models/men_phalanx_04.cem")
	var zgodne := 0; var proby := 0
	if mf:
		for kier in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 1).normalized(), Vector2(-0.3, -1).normalized()]:
			var th := UkladEE.kat_kierunku(kier)
			var b := UkladEE.baza(UkladEE.R_z_kata(th))
			for k in range(0, 16, 3):
				var tg := mf.tag("attack", k)
				if tg.is_empty(): continue
				var v: Vector3 = b * (tg[1] as Vector3)
				proby += 1
				if Vector2(v.x, v.z).normalized().dot(kier) > 0.3: zgodne += 1
	t._ok("E5 dane: przód modelu (punkt attack) zgodny z kierunkiem ruchu", proby > 0 and zgodne >= int(proby * 0.8),
		"%d/%d próbek (falanga, klatki ruchu 0–15, 4 kierunki)" % [zgodne, proby])
	# sekwencje ruchu i bezczynności jednostek Troi
	var graf := {}
	for r in Z.tabela("dbgraphics"): graf[int(r.ID)] = r
	var s_ruch := 0; var s_brak := 0; var typy := 0
	var widziane := {}
	if s.czytaj_graczy(Kf.katalog_openee):
		for g in s.gracze:
			for u in g.jednostki:
				var ob: Dictionary = obiekty.get(int(u.type), {})
				if not (int(ob.get("Unit type", -1)) in [5, 6, 13, 16, 23]) or float(ob.get("Speed", 0)) <= 0: continue
				if widziane.has(int(u.type)): continue
				widziane[int(u.type)] = true; typy += 1
				var sek := SekwencjeAnimacji.z_rekordu(graf.get(int(ob.get("Graphic ID", -1)), {}))
				if int(sek.dla_stanu("ruch").get("klatki", 0)) > 1: s_ruch += 1
				else: s_brak += 1
	t._ok("E5 dane: sekwencje ruchu i bezczynności jednostek Troi (brak = diagnostyka, nie błąd ruchu)",
		typy > 0 and s_ruch > 0, "%d typów ruchomych: %d z sekwencją ruchu, %d bez (ruch bez animacji, wpis diagnostyczny)" % [typy, s_ruch, s_brak])
	_koniec_i = true
