class_name TestyKamery
extends RefCounted
## Testy kamery RTS (raporty/archiwum/RAPORT_KAMERA_EE_OPENEE.md): model kamery EE (kierunek, pochylenie, poziomy zoomu, prędkość
## przesuwania, granice mapy), kamera produkcyjna (brak obrotu, kółko, strzałki, ograniczenie do mapy, promień
## wskazywania) oraz kamera diagnostyczna (obrót i wolny zoom zachowane). Bez okna i bez instalacji EE.

var t


func _init(runner) -> void:
	t = runner


func _klawisz(k: Key, wcisniety: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k; e.physical_keycode = k; e.pressed = wcisniety
	Input.parse_input_event(e)
	Input.flush_buffered_events()       # bez tego stan klawisza widać dopiero w następnej klatce


func _kolko(kam: Camera3D, w_gore: bool, ile: int) -> void:
	for i in ile:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP if w_gore else MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = true
		kam._unhandled_input(e)


## Romb poprawnych pól mapy N×N (jak mapa EE 100×100 → N = 200): zakresy kolumn w wierszach.
static func _romb(n: int) -> Array:
	var rp := []
	for r in n:
		var w := n / 2.0 - absf(r + 0.5 - n / 2.0)
		rp.append(Vector2i(int(ceil(n / 2.0 - w)), int(floor(n / 2.0 + w)) - 1))
	return rp


func uruchom() -> void:
	var M := ModelKameryEE
	# --- model
	t._ok("K model: odległości poziomów zoomu jak w EE (20 → 29,7; 19 → 28,21; 1 → 1,39; 0 → 0,1)",
		is_equal_approx(M.odleglosc(20), 29.7) and absf(M.odleglosc(19) - 28.21) < 1e-4 and absf(M.odleglosc(1) - 1.39) < 1e-4
		and is_equal_approx(M.odleglosc(0), 0.1) and M.POZIOMOW == 21, [M.odleglosc(20), M.odleglosc(19), M.odleglosc(1), M.odleglosc(0)])
	t._ok("K model: prędkość przesuwania 15 / 30 / 45 pól/s przy poziomach 0 / 10 / 20",
		is_equal_approx(M.predkosc(0), 15.0) and is_equal_approx(M.predkosc(10), 30.0) and is_equal_approx(M.predkosc(20), 45.0), "")
	var f := M.kierunek_godot()
	var poch := rad_to_deg(asin(-f.y))
	var poz := UkladEE.mapa(f).normalized()
	t._ok("K model: pochylenie 35° i stały kierunek patrzenia (mapa EE (−1, +1); w Godocie przez UkladEE)",
		absf(poch - 35.0) < 1e-3 and poz.distance_to(Vector2(-1, 1).normalized()) < 1e-5, [snappedf(poch, 0.001), poz])
	var prawo_g := f.cross(Vector3.UP).normalized()
	t._ok("K model: prawo ekranu Godota = (+1, +1) mapy EE – kadr nie jest odbity (etap 7)",
		UkladEE.mapa(prawo_g).normalized().distance_to(Vector2(1, 1).normalized()) < 1e-5
		and M.os_prawo_mapy().distance_to(Vector2(1, 1).normalized()) < 1e-5, [UkladEE.mapa(prawo_g), M.os_prawo_mapy()])
	t._ok("K model: poziom dla odległości (dociąganie – zgodność z dawnym ustaw(cel, odl))",
		M.poziom_dla_odleglosci(100.0) == 20 and M.poziom_dla_odleglosci(0.0) == 0 and M.poziom_dla_odleglosci(15.0) == 10, "")
	var g := M.granice_z_pol(_romb(200))
	t._ok("K model: granice ogniska dla mapy 100×100 = zmierzone w EE (x+y ∈ [100, 300], x−y ∈ [−100, 100])",
		absf(g.position.x - 100) <= 1.0 and absf(g.end.x - 300) <= 1.0 and absf(g.position.y + 100) <= 1.0 and absf(g.end.y - 100) <= 1.0, g)
	var p := M.ogranicz(Vector2(-50, 400), g)
	t._ok("K model: ognisko poza mapą dociągane do brzegu rombu", absf(p.x + p.y - g.end.x) < 1e-3 or absf(p.x - p.y - g.position.y) < 1e-3, p)

	# --- kamera produkcyjna
	var kam: Camera3D = Camera3D.new(); kam.set_script(load("res://sceny/kamera_rts.gd"))
	kam.przesuwanie_krawedzia = false
	t.root.add_child(kam)
	kam.ustaw(UkladEE.godot(Vector2(100, 100), 0.4), 999.0)
	t._ok("K produkcyjna: start przy największym oddaleniu, poziomy kąt widzenia z modelu EE (48,4°, KEEP_WIDTH)",
		kam.poziom == 20 and is_equal_approx(kam.fov, M.FOV_POZIOMY_ST) and kam.keep_aspect == Camera3D.KEEP_WIDTH, kam.opis())
	var baza0: Basis = kam.global_transform.basis
	_klawisz(KEY_Q, true)
	var wejscie_dziala := Input.is_key_pressed(KEY_Q)
	_klawisz(KEY_Q, false)
	t._ok("K test: symulowane klawisze widoczne w Input (warunek wiarygodności testów klawiszy)", wejscie_dziala, "")
	for k: Key in [KEY_Q, KEY_E]:
		_klawisz(k, true); kam._process(1.0); _klawisz(k, false)
	var e2 := InputEventMouseMotion.new(); e2.button_mask = MOUSE_BUTTON_MASK_MIDDLE; e2.relative = Vector2(300, 0)
	kam._unhandled_input(e2)
	t._ok("K produkcyjna: stały azymut – Q/E i przeciąganie środkowym przyciskiem nie obracają kamery",
		kam.global_transform.basis.is_equal_approx(baza0) and kam.cel.is_equal_approx(UkladEE.godot(Vector2(100, 100), 0.4)), kam.opis())
	t._ok("K produkcyjna: oś widoku = model EE (pochylenie 35°)", (-kam.global_transform.basis.z).distance_to(f) < 1e-4,
		-kam.global_transform.basis.z)
	_kolko(kam, true, 30)
	var d0 := kam.position.distance_to(kam.cel)
	_kolko(kam, false, 30)
	var d20 := kam.position.distance_to(kam.cel)
	_kolko(kam, true, 1)
	var d19 := kam.position.distance_to(kam.cel)
	t._ok("K produkcyjna: kółko – skok o jeden poziom, zakres 0,1–29,7, kierunek widoku bez zmian (zoom nie zmienia pochylenia)",
		absf(d0 - 0.1) < 1e-3 and absf(d20 - 29.7) < 1e-3 and absf(d19 - 28.21) < 1e-3 and kam.global_transform.basis.is_equal_approx(baza0),
		[d0, d20, d19])
	_kolko(kam, false, 1)
	var c0: Vector3 = kam.cel
	_klawisz(KEY_RIGHT, true); kam._process(1.0); _klawisz(KEY_RIGHT, false)
	var dp := UkladEE.mapa(kam.cel) - UkladEE.mapa(c0)
	t._ok("K produkcyjna: strzałka w prawo – 45 pól/s przy pełnym oddaleniu, wzdłuż osi prawej ekranu",
		absf(dp.length() - 45.0) < 1e-3 and dp.normalized().distance_to(M.os_prawo_mapy()) < 1e-4, dp)
	kam.ustaw_poziom(0); c0 = kam.cel
	_klawisz(KEY_UP, true); kam._process(0.5); _klawisz(KEY_UP, false)
	dp = UkladEE.mapa(kam.cel) - UkladEE.mapa(c0)
	t._ok("K produkcyjna: strzałka w górę – 15 pól/s przy największym zbliżeniu, „dalej” = kierunek patrzenia",
		absf(dp.length() - 7.5) < 1e-3 and dp.normalized().distance_to(M.os_dalej_mapy()) < 1e-4, dp)
	_klawisz(KEY_W, true); kam._process(1.0); _klawisz(KEY_W, false)
	t._ok("K produkcyjna: WASD nie przesuwa kamery (w EE przesuwanie strzałkami)", UkladEE.mapa(kam.cel).is_equal_approx(UkladEE.mapa(c0) + dp), "")
	kam.ustaw_granice_z_mapy(_romb(200))
	kam.ustaw_poziom(20)
	for i in 20:
		_klawisz(KEY_LEFT, true); kam._process(1.0); _klawisz(KEY_LEFT, false)
	var pm := UkladEE.mapa(kam.cel)
	var uv := Vector2(pm.x + pm.y, pm.x - pm.y)
	t._ok("K produkcyjna: przesuwanie zatrzymuje się na brzegu mapy (ognisko w rombie)",
		uv.x >= kam.granice.position.x - 1e-3 and uv.x <= kam.granice.end.x + 1e-3 and uv.y >= kam.granice.position.y - 1e-3
		and uv.y <= kam.granice.end.y + 1e-3 and (absf(uv.x - kam.granice.position.x) < 1e-3 or absf(uv.x - kam.granice.end.x) < 1e-3
		or absf(uv.y - kam.granice.position.y) < 1e-3 or absf(uv.y - kam.granice.end.y) < 1e-3), [uv, kam.granice])
	kam.wysokosc_terenu = func(_q: Vector2) -> float: return 5.0
	kam._aktualizuj()
	t._ok("K produkcyjna: ognisko 0,4 nad terenem (nadążanie za wysokością)", absf(kam.cel.y - 5.4) < 1e-4, kam.cel)
	var ekr := Vector2(kam.get_viewport().get_visible_rect().size) * 0.5
	t._ok("K produkcyjna: promień wskazywania (zaznaczanie jednostek) ze środka ekranu trafia w ognisko",
		kam.project_ray_normal(ekr).distance_to(f) < 1e-3, kam.project_ray_normal(ekr))
	kam.odleglosc = 3.2; kam._aktualizuj()
	t._ok("K produkcyjna: ustawienie `odleglosc` z zewnątrz (kamera podążająca rts_test) dociągane do poziomu",
		kam.poziom == M.poziom_dla_odleglosci(3.2) and is_equal_approx(kam.odleglosc, M.odleglosc(kam.poziom)), kam.opis())
	kam.queue_free()

	# --- kamera diagnostyczna
	var kd: Camera3D = Camera3D.new(); kd.set_script(load("res://sceny/kamera_diagnostyczna.gd"))
	t.root.add_child(kd)
	kd.ustaw(Vector3(10, 0, 10), 120.0)
	var obr0: float = kd.kat_obrotu
	_klawisz(KEY_Q, true); kd._process(0.5); _klawisz(KEY_Q, false)
	t._ok("K diagnostyczna: wolny obrót (Q) i dowolna odległość zachowane",
		absf(kd.kat_obrotu - obr0 - 30.0) < 1e-3 and is_equal_approx(kd.odleglosc, 120.0), kd.opis())
	kd.queue_free()
	_etap10()


func _ruch(kam: Camera3D, poz: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new(); e.position = poz; e.relative = rel
	kam._input(e)


## Etap 10 (docs/MECHANIKA_KAMERY_EE.md): krawędź włączana pchaniem, środkowy przycisk, zoom niezależny od kursora,
## suma kierunków strzałek, woda pod ogniskiem, granice dla innej wielkości mapy, stabilność, niezależność od symulacji.
func _etap10() -> void:
	var M := ModelKameryEE
	t._ok("K10 model: krawędź = 5/6 prędkości strzałek (12,5 / 25 / 37,5 pola/s jak w EE)",
		is_equal_approx(M.predkosc_krawedzi(0), 12.5) and is_equal_approx(M.predkosc_krawedzi(10), 25.0)
		and is_equal_approx(M.predkosc_krawedzi(20), 37.5), [M.predkosc_krawedzi(0), M.predkosc_krawedzi(20)])
	var s1 := M.przesuniecie_srodkowym(Vector2(200, 0), 10); var s2 := M.przesuniecie_srodkowym(Vector2(0, 200), 0)
	var s3 := M.przesuniecie_srodkowym(Vector2(200, 0), 20)
	t._ok("K10 model: środkowy przycisk – Δ pól = Δ myszy × prędkość/640 (EE: 200 jedn. → 9,38 / 4,69 / 14,07)",
		s1.is_equal_approx(Vector2(9.375, 0)) and s2.is_equal_approx(Vector2(0, -4.6875)) and s3.is_equal_approx(Vector2(14.0625, 0)),
		[s1, s2, s3])
	t._ok("K10 model: ognisko 0,4 nad terenem, teren poniżej zera liczony jak 0 (woda)",
		is_equal_approx(M.wysokosc_ogniska(-0.8), 0.4) and is_equal_approx(M.wysokosc_ogniska(3.0), 3.4), "")
	var g150 := M.granice_z_pol(_romb(300))
	t._ok("K10 model: granice dla mapy 150×150 = zmierzone w EE (x+y ∈ [150, 450], x−y ∈ [−150, 150])",
		g150.is_equal_approx(Rect2(150, -150, 300, 300)), g150)

	var kam: Camera3D = Camera3D.new(); kam.set_script(load("res://sceny/kamera_rts.gd"))
	t.root.add_child(kam)
	kam.przesuwanie_krawedzia = true
	kam.ustaw(UkladEE.godot(Vector2(100, 100), 0.4), 999.0)
	var r := Vector2(kam.get_viewport().get_visible_rect().size)
	var c0: Vector3 = kam.cel
	_ruch(kam, Vector2(r.x - 1, r.y * 0.5), Vector2(0, 0))
	kam._process(1.0)
	var stoi: bool = kam.cel.is_equal_approx(c0)
	_ruch(kam, Vector2(r.x - 6, r.y * 0.5), Vector2(5, 0)); kam._process(1.0)
	var strefa: bool = kam.cel.is_equal_approx(c0)
	t._ok("K10 krawędź: kursor stojący przy krawędzi (0–5 px) nie przewija – brak strefy jak w EE", stoi and strefa, kam.opis())
	_ruch(kam, Vector2(r.x - 1, r.y * 0.5), Vector2(4, 0))
	kam._process(1.0)
	var d1 := UkladEE.mapa(kam.cel) - UkladEE.mapa(c0)
	kam._process(1.0)
	var d2 := UkladEE.mapa(kam.cel) - UkladEE.mapa(c0)
	t._ok("K10 krawędź: pchanie poza prawą krawędź włącza przewijanie w prawo 37,5 pola/s (poziom 20), trwa bez ruchu myszy",
		absf(d1.length() - 37.5) < 1e-3 and d1.normalized().distance_to(M.os_prawo_mapy()) < 1e-4 and absf(d2.length() - 75.0) < 1e-3,
		[d1, d2])
	var c1: Vector3 = kam.cel
	_ruch(kam, Vector2(r.x - 4, r.y * 0.5), Vector2(-3, 0)); kam._process(1.0)
	t._ok("K10 krawędź: ruch do wnętrza okna wyłącza przewijanie", kam.cel.is_equal_approx(c1), kam.opis())
	_ruch(kam, Vector2(r.x * 0.5, 0), Vector2(0, -4)); kam._process(0.5)
	var d3 := UkladEE.mapa(kam.cel) - UkladEE.mapa(c1)
	t._ok("K10 krawędź: górna krawędź – „dalej” (kierunek patrzenia)", d3.normalized().distance_to(M.os_dalej_mapy()) < 1e-4
		and absf(d3.length() - 18.75) < 1e-3, d3)
	_ruch(kam, Vector2(r.x * 0.5, 300), Vector2(0, 50))
	kam.ramka_aktywna = true
	var c2: Vector3 = kam.cel
	_ruch(kam, Vector2(r.x - 1, r.y * 0.5), Vector2(6, 0)); kam._process(1.0)
	var blok: bool = kam.cel.is_equal_approx(c2)
	kam.ramka_aktywna = false
	kam._process(1.0)
	t._ok("K10 krawędź: przeciąganie ramki zaznaczenia blokuje przewijanie krawędzią (także po puszczeniu ramki)",
		blok and kam.cel.is_equal_approx(c2), kam.opis())
	# środkowy przycisk
	kam.ustaw_poziom(10)
	_ruch(kam, Vector2(r.x * 0.5, r.y * 0.5), Vector2(0, 0))
	var c3: Vector3 = kam.cel
	var b := InputEventMouseButton.new(); b.button_index = MOUSE_BUTTON_MIDDLE; b.pressed = true; b.position = r * 0.5
	kam._unhandled_input(b)
	_ruch(kam, r * 0.5, Vector2(100, 0)); _ruch(kam, r * 0.5, Vector2(100, 0))
	var d4 := UkladEE.mapa(kam.cel) - UkladEE.mapa(c3)
	var c4: Vector3 = kam.cel
	_ruch(kam, r * 0.5, Vector2(0, 200))
	var d5 := UkladEE.mapa(kam.cel) - UkladEE.mapa(c4)
	b = InputEventMouseButton.new(); b.button_index = MOUSE_BUTTON_MIDDLE; b.pressed = false
	kam._unhandled_input(b)
	var c5: Vector3 = kam.cel
	_ruch(kam, r * 0.5, Vector2(200, 0)); kam._process(0.5)
	t._ok("K10 środkowy: ruch myszy w prawo → kamera w prawo 9,375 pola/200 px (poziom 10), w dół → w dół ekranu",
		absf(d4.length() - 9.375) < 1e-3 and d4.normalized().distance_to(M.os_prawo_mapy()) < 1e-4
		and absf(d5.length() - 9.375) < 1e-3 and d5.normalized().distance_to(-M.os_dalej_mapy()) < 1e-4, [d4, d5])
	t._ok("K10 środkowy: po zwolnieniu ruch myszy nie przesuwa kamery, azymut bez zmian",
		kam.cel.is_equal_approx(c5) and (-kam.global_transform.basis.z).distance_to(M.kierunek_godot()) < 1e-4, kam.opis())
	# zoom niezależny od kursora
	var c6: Vector3 = kam.cel
	for poz in [Vector2(10, 10), r - Vector2(10, 10), Vector2(10, r.y - 10)]:
		var w := InputEventMouseButton.new(); w.button_index = MOUSE_BUTTON_WHEEL_UP; w.pressed = true; w.position = poz
		kam._unhandled_input(w)
	t._ok("K10 zoom: kółko przy kursorze w rogach nie przesuwa ogniska (EE: punkt pod kursorem bez znaczenia)",
		kam.cel.is_equal_approx(c6) and kam.poziom == 7, kam.opis())
	# dwie strzałki
	kam.ustaw_poziom(10)
	var c7: Vector3 = kam.cel
	_klawisz(KEY_UP, true); _klawisz(KEY_RIGHT, true); kam._process(1.0); _klawisz(KEY_UP, false); _klawisz(KEY_RIGHT, false)
	var d7 := UkladEE.mapa(kam.cel) - UkladEE.mapa(c7)
	var c8: Vector3 = kam.cel
	_klawisz(KEY_UP, true); _klawisz(KEY_DOWN, true); kam._process(1.0); _klawisz(KEY_UP, false); _klawisz(KEY_DOWN, false)
	t._ok("K10 strzałki: dwie strzałki – suma wektorów (30·√2 pola/s przy poziomie 10), przeciwne się znoszą",
		absf(d7.length() - 30.0 * sqrt(2.0)) < 1e-3 and kam.cel.is_equal_approx(c8), [d7, d7.length()])
	# woda pod ogniskiem
	kam.wysokosc_terenu = func(_q: Vector2) -> float: return -2.0
	kam._aktualizuj()
	t._ok("K10 teren: nad wodą (wysokość < 0) ognisko na 0,4", absf(kam.cel.y - 0.4) < 1e-4, kam.cel)
	kam.wysokosc_terenu = Callable()
	# stabilność przy powtarzanych operacjach
	kam.ustaw_granice_z_mapy(_romb(200))
	var stab := true
	var rng := RandomNumberGenerator.new(); rng.seed = 10
	for i in 2000:
		var op := rng.randi_range(0, 3)
		if op == 0: _kolko(kam, rng.randf() < 0.5, 1)
		elif op == 1:
			var kl: Key = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT][rng.randi_range(0, 3)]
			_klawisz(kl, true); kam._process(rng.randf() * 0.2); _klawisz(kl, false)
		elif op == 2:
			kam._unhandled_input(b)
		else:
			_ruch(kam, Vector2(rng.randf() * r.x, rng.randf() * r.y), Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)))
			kam._process(0.05)
		var pm := UkladEE.mapa(kam.cel); var uv := Vector2(pm.x + pm.y, pm.x - pm.y)
		if kam.poziom < 0 or kam.poziom > 20 or uv.x < 100 - 1e-3 or uv.x > 300 + 1e-3 or absf(uv.y) > 100 + 1e-3 \
				or not (-kam.global_transform.basis.z).is_equal_approx(M.kierunek_godot()) or is_nan(pm.x):
			stab = false; break
	t._ok("K10 stabilność: 2000 losowych operacji (kółko, strzałki, mysz) – zoom 0–20, ognisko w rombie, azymut stały", stab, kam.opis())
	# niezależność od symulacji
	var kat := PackedByteArray(); kat.resize(400)
	var m := MapaNawigacji.z_tablic(20, 20, kat, PackedFloat32Array(), 1)
	var sa := Symulacja.new(m); var sb := Symulacja.new(m)
	for sym in [sa, sb]:
		var dj := JednostkaSym.DaneJednostki.new(); dj.typ = 1; dj.pozycja = Vector2(2.5, 2.5)
		var id: int = sym.dodaj_jednostke(dj, {"Speed": 0.5})
		sym.rozkaz_ruchu(id, Vector2(15.5, 12.5))
	for i in 100:
		sa.krok()
		_klawisz(KEY_RIGHT, true); kam._process(0.05); _klawisz(KEY_RIGHT, false); _kolko(kam, i % 2 == 0, 1)
		sb.krok()
	t._ok("K10 niezależność: ruch kamery nie zmienia stanu symulacji (ten sam skrót stanu z kamerą i bez)",
		sa.skrot_stanu() == sb.skrot_stanu(), [sa.skrot_stanu().left(60)])
	# sterowanie informuje kamerę o ramce (wciśnięcie LPM rozpoczyna ramkę)
	var st := SterowanieRTS.new(sa, null, null, kam)
	var lp := InputEventMouseButton.new(); lp.button_index = MOUSE_BUTTON_LEFT; lp.pressed = true; lp.position = r * 0.5
	st._unhandled_input(lp)
	var w_trakcie: bool = kam.ramka_aktywna
	st._ramka_kamery(false)
	t._ok("K10 sterowanie: wciśnięcie LPM (początek ramki) ustawia kamera.ramka_aktywna, koniec – zdejmuje",
		w_trakcie and not kam.ramka_aktywna, "")
	st.free()
	kam.queue_free()
