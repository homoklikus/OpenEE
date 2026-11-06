class_name TestyPrzezroczystosci
extends RefCounted
## Testy etapu 8 – przezroczystość budynków (PrzezroczystoscBudynkow): tryby i F5, reguła pól zasłaniających (pole
## jednostki i pola między nią a kamerą EE), wygasanie znaczników, brak niezamierzonej przezroczystości, ograniczenie
## przetwarzania, oddzielenie od materiałów źródłowych i zgodność z shaderem modeli. Dane syntetyczne.

var t


func _init(runner) -> void:
	t = runner


func _zero(xf: Transform3D) -> bool:
	return xf.basis.get_scale().length() < 1e-6


func _mat() -> ShaderMaterial:
	var sh := Shader.new(); sh.code = ImporterModeli.SHADER_MODELU
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("kolor_gracza", Color(0, 0, 1))
	return m


func uruchom() -> void:
	# --- pola zajmowane
	var p1 := PrzezroczystoscBudynkow.pola_obiektu(Vector2(221.5, 110.5), 1.0)
	var p2 := PrzezroczystoscBudynkow.pola_obiektu(Vector2(10.5, 20.5), 0.5)
	var p3 := PrzezroczystoscBudynkow.pola_obiektu(Vector2(220.0, 108.0), 2.0)
	t._ok("P8 pola obiektu z „Size of collider” (fort 2,0 na wierzchołku → 2×2, dom 1,0 i drzewo 0,5 → 1 pole)",
		p1 == [Vector2i(221, 110)] and p2 == [Vector2i(10, 20)] and p3.size() == 4 and Vector2i(219, 107) in p3
		and Vector2i(220, 108) in p3 and not (Vector2i(221, 106) in p3) and not (Vector2i(221, 108) in p3), [p1, p2, p3])
	# --- shader pochodny
	var m := _mat()
	var kod_przed := m.shader.code
	var mp: ShaderMaterial = PrzezroczystoscBudynkow.material_przezroczysty(m)
	var kp := mp.shader.code
	t._ok("P8 shader przezroczysty pochodny: blend + bez zapisu głębi + ALPHA 0,35; odrzucanie tylnych ścian, kolor gracza i wycinanie alfa zachowane",
		"blend_mix" in kp and "depth_draw_never" in kp and "ALPHA = alfa_przezroczystosci" in kp and "odrzucaj_tyl" in kp
		and "kolor_gracza_mnoz" in kp and "wycinanie_alfa" in kp and "cull_disabled" in kp
		and is_equal_approx(float(PrzezroczystoscBudynkow.ALFA), 0.35))
	t._ok("P8 materiał źródłowy nietknięty (osobny materiał i shader; parametry, w tym kolor gracza, skopiowane)",
		m.shader.code == kod_przed and mp != m and mp.shader != m.shader and not ("blend_mix" in m.shader.code)
		and mp.get_shader_parameter("kolor_gracza") == Color(0, 0, 1)
		and PrzezroczystoscBudynkow.material_przezroczysty(m).shader == mp.shader)
	# --- grupa MultiMesh: obiekty 0 i 1 z flagą, 2 bez flagi (np. ten sam model innego typu)
	var korzen := Node3D.new(); t.root.add_child(korzen)
	var bm := BoxMesh.new(); bm.material = m
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays()); mesh.surface_set_material(0, m)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = 3
	var poz := [Vector2(10.5, 10.5), Vector2(20.5, 10.5), Vector2(30.5, 10.5)]
	var xfs: Array = []
	for i in 3:
		xfs.append(Transform3D(Basis(), UkladEE.godot(poz[i], 0.0))); mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; korzen.add_child(mmi)
	var pb := PrzezroczystoscBudynkow.new(); korzen.add_child(pb); pb.set_process(false)
	pb.dodaj_grupe("k", mmi)
	pb.dodaj_obiekt("k", 0, xfs[0], poz[0], 0.5)
	pb.dodaj_obiekt("k", 1, xfs[1], poz[1], 0.5)
	var mmp: MultiMesh = pb._grupy["k"].mm_p
	pb.ustaw_tryb(1)
	t._ok("P8 tryb 1 bez jednostek: wszystko nieprzezroczyste (kopia przezroczysta pusta)",
		not pb.przezroczysty(0) and not pb.przezroczysty(1) and pb.rysowanie(0) == [true, false] and pb.rysowanie(1) == [true, false]
		and mmp.mesh != mesh and mmp.instance_count == 3)
	# jednostka za obiektem 0 (pole (9, 11): obiekt w polu (x+1, y−1) – między jednostką a kamerą EE)
	pb.oznacz(Vector2(9.4, 11.6)); pb.krok(0.05)
	var ok_za := pb.przezroczysty(0) and not pb.przezroczysty(1) and pb.rysowanie(0) == [false, true] \
		and pb.rysowanie(1) == [true, false] and pb.liczba_obiektow() == 2
	t._ok("P8 jednostka za budynkiem (względem kamery EE) → ten budynek przezroczysty, inne bez zmian", ok_za,
		[pb.przezroczysty(0), pb.przezroczysty(1)])
	var pb_przed := PrzezroczystoscBudynkow.new(); korzen.add_child(pb_przed); pb_przed.set_process(false)
	pb_przed.dodaj_obiekt("brak", 0, xfs[0], poz[0], 0.5)
	pb_przed.ustaw_tryb(1)
	pb_przed.oznacz(Vector2(11.5, 9.5)); pb_przed.krok(0.05)       # jednostka PRZED budynkiem (bliżej kamery)
	var przed := pb_przed.przezroczysty(0)
	pb_przed.oznacz(Vector2(10.5, 10.5)); pb_przed.krok(0.05)      # w polu budynku
	t._ok("P8 jednostka przed budynkiem nie zmienia go; jednostka w polu budynku – przezroczysty",
		not przed and pb_przed.przezroczysty(0))
	pb.krok(PrzezroczystoscBudynkow.TRZYMANIE_S + 0.1)
	t._ok("P8 wygaszenie znacznika po odejściu jednostki (≈1,5 s) – budynek wraca do nieprzezroczystego",
		not pb.przezroczysty(0) and pb.rysowanie(0) == [true, false])
	pb.ustaw_tryb(2)
	t._ok("P8 tryb 2: wszystkie obiekty z flagą przezroczyste, obiekt bez flagi nieprzezroczysty",
		pb.przezroczysty(0) and pb.przezroczysty(1) and pb.rysowanie(1) == [false, true] and pb.liczba_obiektow() == 2)
	pb.ustaw_tryb(0)
	pb.oznacz(Vector2(9.4, 11.6)); pb.krok(0.05)
	t._ok("P8 tryb 0: żadnej przezroczystości, także z jednostką za budynkiem",
		not pb.przezroczysty(0) and not pb.przezroczysty(1) and pb.rysowanie(0) == [true, false])
	var cykl: Array = []
	pb.ustaw_tryb(1)
	for i in 3: cykl.append(pb.nastepny_tryb())
	t._ok("P8 F5: cykl trybów 1 → 2 → 0 → 1 jak w EE (domyślnie 1)", cykl == [2, 0, 1] and PrzezroczystoscBudynkow.new().tryb == 1, cykl)
	# --- ograniczenie przetwarzania: 2000 obiektów, jedna jednostka
	var duzo := PrzezroczystoscBudynkow.new(); korzen.add_child(duzo); duzo.set_process(false)
	for i in 2000:
		duzo.dodaj_obiekt("x", -1, Transform3D(), Vector2(i % 50 + 0.5, floorf(i / 50.0) + 0.5), 0.5)
	duzo.ustaw_tryb(1)
	var n1 := duzo.aktualizuj_jednostki([[7, Vector2(5.5, 6.5)]])
	duzo.krok(0.02)
	var spr := duzo.sprawdzen_w_kroku
	var n2 := duzo.aktualizuj_jednostki([[7, Vector2(5.6, 6.4)]])          # to samo pole, przed odświeżeniem
	duzo.krok(PrzezroczystoscBudynkow.ODSWIEZANIE_S)
	var n3 := duzo.aktualizuj_jednostki([[7, Vector2(5.6, 6.4)]])          # odświeżenie okresowe
	t._ok("P8 przetwarzanie ograniczone: krok sprawdza tylko oznaczone obiekty (≤ 4 z 2000), jednostka stojąca – odświeżenie co 0,5 s",
		n1 == 1 and spr <= 4 and spr >= 1 and n2 == 0 and n3 == 1, [n1, spr, n2, n3])
	# --- obiekt jako osobny węzeł: nadpisanie materiału powierzchni, źródło nietknięte
	var w := MeshInstance3D.new(); w.mesh = mesh; korzen.add_child(w)
	var pw := PrzezroczystoscBudynkow.new(); korzen.add_child(pw); pw.set_process(false)
	pw.dodaj_wezel(w, Vector2(3.5, 3.5), 0.5)
	pw.ustaw_tryb(2)
	var nad := w.get_surface_override_material(0)
	pw.ustaw_tryb(0)
	t._ok("P8 obiekt-węzeł: tryb 2 – materiał pochodny w nadpisaniu powierzchni, tryb 0 – nadpisanie usunięte, siatka źródłowa bez zmian",
		nad is ShaderMaterial and "blend_mix" in (nad as ShaderMaterial).shader.code and w.get_surface_override_material(0) == null
		and mesh.surface_get_material(0) == m)
	korzen.queue_free()
	t._ok("P8 testy przezroczystości wykonane do końca (bez błędu skryptu)", true)
