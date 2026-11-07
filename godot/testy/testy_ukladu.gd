class_name TestyUkladu
extends RefCounted
## Testy układu współrzędnych (etap 7, raporty/archiwum/RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md): konwersje UkladEE (punkty, kierunki,
## macierze), zachowanie odległości i skrętności, orientacja trójkątów i normalnych, rzut asymetrycznego układu punktów
## kontrolnych z oryginalnego EE (scenariusz „Żołnierze dla Rzymu”, zmierzone piksele) przez kamerę produkcyjną,
## wskazywanie myszą (piksel → promień → jednostka/teren) oraz dekodowanie napisów Windows-1250. Bez instalacji EE.

var t


func _init(runner) -> void:
	t = runner


## Punkty kontrolne: pozycja EE (x, y, wysokość punktu na budynku) i piksel zmierzony na zrzucie oryginału
## (okno 3440×1440, kamera: ognisko (219,992; 108,001; 1,641), poziom 20 – zadanie MCP 74).
const PUNKTY_KONTROLNE := [
	["Fortress A", Vector3(220.0, 108.0, 2.2), Vector2(1720, 690)],
	["Fortress B", Vector3(217.0, 107.0, 2.2), Vector2(1368, 600)],
	["House Dark (221,5; 110,5)", Vector3(221.5, 110.5, 2.0), Vector2(2080, 650)],
	["House Bronze (222,5; 110,5)", Vector3(222.5, 110.5, 2.0), Vector2(2180, 710)],
	["House Copper (223,5; 110,5)", Vector3(223.5, 110.5, 2.0), Vector2(2280, 775)],
	["House Bronze (222,5; 108,5)", Vector3(222.5, 108.5, 2.0), Vector2(2000, 820)],
	["House Dark (223,5; 108,5)", Vector3(223.5, 108.5, 2.0), Vector2(2110, 870)],
]


func _wp(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 1e-4


func uruchom() -> void:
	# --- konwersje
	var ok_p := true
	for p: Vector2 in [Vector2(0, 0), Vector2(17.5, 99.25), Vector2(219.99, 108.0), Vector2(-3, 400)]:
		for h: float in [0.0, 1.641, -0.6]:
			var g := UkladEE.godot(p, h)
			ok_p = ok_p and UkladEE.mapa(g).distance_to(p) < 1e-5 and absf(g.y - h) < 1e-6
	t._ok("U konwersja punktu EE → Godot → EE (mapa i wysokość)", ok_p, "")
	var ok_k := true
	for v: Vector3 in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(-0.3, 2.0, 0.7)]:
		ok_k = ok_k and _wp(UkladEE.wektor_ee(UkladEE.wektor(v)), v)
	ok_k = ok_k and _wp(UkladEE.kierunek(Vector2(0.6, -0.8)), UkladEE.wektor(Vector3(0.6, -0.8, 0)))
	ok_k = ok_k and _wp(UkladEE.wektor(Vector3(0, 0, 1)), Vector3.UP)
	t._ok("U konwersja kierunków (wektor ↔ wektor_ee, kierunek mapy, oś z EE = góra Godota)", ok_k, "")
	var ok_d := true
	var a := Vector2(10, 20); var b := Vector2(13, 24)
	ok_d = ok_d and absf(UkladEE.godot(a, 1).distance_to(UkladEE.godot(b, 1)) - a.distance_to(b)) < 1e-5
	ok_d = ok_d and absf(UkladEE.godot(a, 0).distance_to(UkladEE.godot(a, 2.5)) - 2.5) < 1e-6
	t._ok("U zachowanie odległości (w mapie i w pionie)", ok_d, "")
	var W := UkladEE.W
	var ex := W * Vector3(1, 0, 0); var ey := W * Vector3(0, 1, 0); var ez := W * Vector3(0, 0, 1)
	t._ok("U skrętność: W jest obrotem (wyznacznik +1, x × y = z po konwersji) – świat nie jest odbity",
		absf(W.determinant() - 1.0) < 1e-6 and _wp(ex.cross(ey), ez) and W.is_equal_approx(ModelCEM.P), W)
	# macierz: baza(R) · (siatka importera P·v) = W · R · v  (L = I)
	var ok_m := true
	for th: float in [0.0, 0.7, -2.1, PI]:
		var R := UkladEE.R_z_kata(th)
		var B := UkladEE.baza(R)
		for v: Vector3 in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0.2, -0.5, 1.3)]:
			var ee := UkladEE.basis_ee(R) * v
			ok_m = ok_m and _wp(B * (ModelCEM.P * v), UkladEE.wektor(ee))
		ok_m = ok_m and absf(B.determinant() - 1.0) < 1e-5
	t._ok("U konwersja macierzy obiektu: W·R·P⁻¹ odwzorowuje punkt modelu tak jak świat EE, wyznacznik +1", ok_m, "")
	# trójkąt przeciwny do ruchu wskazówek w mapie EE (patrząc z góry, normalna +z) – po konwersji normalna w górę
	var p0 := UkladEE.godot(Vector2(0, 0), 0); var p1 := UkladEE.godot(Vector2(1, 0), 0); var p2 := UkladEE.godot(Vector2(0, 1), 0)
	var n := (p1 - p0).cross(p2 - p0).normalized()
	var nt := UkladEE.wektor(Vector3(-0.3, 0.2, 1.0)).normalized()
	t._ok("U orientacja trójkątów i normalnych: CCW w mapie EE → normalna +Y, normalna terenu z gradientu w górę",
		_wp(n, Vector3.UP) and nt.y > 0.9, [n, nt])

	# --- rzut punktów kontrolnych EE przez kamerę produkcyjną (3440×1440)
	var vp := SubViewport.new(); vp.size = Vector2i(3440, 1440); vp.disable_3d = false
	t.root.add_child(vp)
	var kam: Camera3D = Camera3D.new(); kam.set_script(load("res://sceny/kamera_rts.gd"))
	kam.przesuwanie_krawedzia = false
	vp.add_child(kam)
	kam.ustaw(UkladEE.godot(Vector2(219.992, 108.001), 1.641), 999.0)
	kam.current = true
	var bledy: Array = []; var bledy_lustra: Array = []
	var f2 := Vector2(219.992, 108.001)
	for pk in PUNKTY_KONTROLNE:
		var pe: Vector3 = pk[1]
		var px := kam.unproject_position(UkladEE.godot(Vector2(pe.x, pe.y), pe.z))
		bledy.append(snappedf(px.distance_to(pk[2]), 0.1))
		# hipoteza odbicia lewo–prawo względem płaszczyzny kierunku patrzenia (dawny układ C)
		var d := Vector2(pe.x, pe.y) - f2
		var r := (d.x + d.y) / sqrt(2.0); var fw := (d.y - d.x) / sqrt(2.0)
		var lustro := f2 + Vector2((-r - fw) / sqrt(2.0), (-r + fw) / sqrt(2.0))
		bledy_lustra.append(snappedf(kam.unproject_position(UkladEE.godot(lustro, pe.z)).distance_to(pk[2]), 0.1))
	var sr := 0.0; var srl := 0.0
	for e in bledy: sr += e / bledy.size()
	for e in bledy_lustra: srl += e / bledy_lustra.size()
	var maks := 0.0
	for e in bledy: maks = maxf(maks, e)
	t._ok("U rzut 7 asymetrycznych punktów kontrolnych EE (Rzym) przez kamerę OpenEE: średni błąd ≤ 50 px, maks. ≤ 70 px",
		sr <= 50.0 and maks <= 70.0, ["błędy px", bledy, "średnio", snappedf(sr, 0.1)])
	t._ok("U hipoteza odbicia lewo–prawo (dawny układ) wyraźnie gorsza: średni błąd > 300 px",
		srl > 300.0, ["błędy px", bledy_lustra, "średnio", snappedf(srl, 0.1)])

	# --- wskazywanie myszą: piksel jednostki → promień kamery → ta sama jednostka; punkt terenu → ten sam punkt mapy
	var kat := PackedByteArray(); kat.resize(10 * 8); kat.fill(MapaNawigacji.LAD)
	var mapa := MapaNawigacji.z_tablic(8, 10, kat, PackedFloat32Array(), 2)
	var sym := Symulacja.new(mapa)
	var dj := JednostkaSym.DaneJednostki.new(); dj.pozycja = Vector2(6.0, 3.0); dj.typ = 1
	var id_j := sym.dodaj_jednostke(dj, {"Name": "test", "Speed": 1.0, "Idle turning speed": 6.0, "Moving turning speed": 8.0, "Circle selection size": 0.4})
	kam.granice = Rect2(); kam.ustaw(UkladEE.godot(Vector2(5.0, 4.0), 0.4), 12.0)
	var pj := kam.unproject_position(UkladEE.godot(Vector2(6.0, 3.0), 0.6))
	var kl := Zaznaczanie.klik(sym, kam.project_ray_origin(pj), kam.project_ray_normal(pj))
	var pt := kam.unproject_position(UkladEE.godot(Vector2(3.0, 5.0), 0.0))
	var kt := Zaznaczanie.klik(sym, kam.project_ray_origin(pt), kam.project_ray_normal(pt))
	t._ok("U wskazywanie: piksel jednostki → promień → ta jednostka; piksel terenu → ten sam punkt mapy EE",
		int(kl.jednostka) == id_j and kt.jednostka == -1 and kt.teren != null and (kt.teren as Vector2).distance_to(Vector2(3.0, 5.0)) < 0.05,
		[kl, kt])
	vp.queue_free()

	# --- napisy Windows-1250
	var bajty := PackedByteArray([0xBF, 0x6F, 0xB3, 0x6E, 0x69, 0x65, 0x72, 0x7A, 0x65, 0x20, 0x8C, 0xE6, 0xEA, 0xF1, 0xF3, 0x9F, 0x00, 0x41])
	t._ok("U napisy Windows-1250 (polska wersja): „żołnierze Śćęńóź”, bajt 0 kończy napis",
		TekstEE.cp1250(bajty) == "żołnierze Śćęńóź", TekstEE.cp1250(bajty))
