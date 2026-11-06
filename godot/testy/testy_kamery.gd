class_name TestyKamery
extends RefCounted
## Testy kamery RTS (RAPORT_KAMERA_EE_OPENEE.md): model kamery EE (kierunek, pochylenie, poziomy zoomu, prędkość
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
	var poz := Vector2(f.x, f.z).normalized()
	t._ok("K model: pochylenie 35° i stały kierunek patrzenia (mapa EE (−1, +1) → Godot (−X, +Z))",
		absf(poch - 35.0) < 1e-3 and poz.distance_to(Vector2(-1, 1).normalized()) < 1e-5, [snappedf(poch, 0.001), poz])
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
	kam.ustaw(Vector3(100, 0.4, 100), 999.0)
	t._ok("K produkcyjna: start przy największym oddaleniu, poziomy kąt widzenia 50,4° (KEEP_WIDTH)",
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
		kam.global_transform.basis.is_equal_approx(baza0) and kam.cel.is_equal_approx(Vector3(100, 0.4, 100)), kam.opis())
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
	var dp := Vector2(kam.cel.x - c0.x, kam.cel.z - c0.z)
	t._ok("K produkcyjna: strzałka w prawo – 45 pól/s przy pełnym oddaleniu, wzdłuż osi prawej ekranu",
		absf(dp.length() - 45.0) < 1e-3 and dp.normalized().distance_to(M.os_prawo_godot()) < 1e-4, dp)
	kam.ustaw_poziom(0); c0 = kam.cel
	_klawisz(KEY_UP, true); kam._process(0.5); _klawisz(KEY_UP, false)
	dp = Vector2(kam.cel.x - c0.x, kam.cel.z - c0.z)
	t._ok("K produkcyjna: strzałka w górę – 15 pól/s przy największym zbliżeniu, „dalej” = kierunek patrzenia",
		absf(dp.length() - 7.5) < 1e-3 and dp.normalized().distance_to(M.os_dalej_godot()) < 1e-4, dp)
	_klawisz(KEY_W, true); kam._process(1.0); _klawisz(KEY_W, false)
	t._ok("K produkcyjna: WASD nie przesuwa kamery (w EE przesuwanie strzałkami)", kam.cel.is_equal_approx(c0 + Vector3(dp.x, 0, dp.y)), "")
	kam.ustaw_granice_z_mapy(_romb(200))
	kam.ustaw_poziom(20)
	for i in 20:
		_klawisz(KEY_LEFT, true); kam._process(1.0); _klawisz(KEY_LEFT, false)
	var uv := Vector2(kam.cel.x + kam.cel.z, kam.cel.x - kam.cel.z)
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
