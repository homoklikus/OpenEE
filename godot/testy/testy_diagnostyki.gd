class_name TestyDiagnostyki
extends RefCounted
## Testy diagnostyki modeli 0.5.1 (RAPORT_DIAGNOSTYKA_MODELI_051.md): wykrywanie trójkątów współpłaszczyznowych i
## duplikatów, spójność nawinięcia, reguły materiałów (wycinanie alfa we wszystkich materiałach, kolor pod alfa = 0),
## odrzucanie tylnych ścian z uwzględnieniem lustrzanej bazy obiektów, obrót billboardów, przesunięcie głębi.
## UWAGA: testy odczytu i reguł nie zastępują testu wizualnego – ten jest w narzedzia/test_wizualny_051.sh
## (zrzuty z tej samej kamery przed/po, OpenGL i Vulkan).

var t
var _koniec_j := false
var _koniec_i := false


func _init(runner) -> void:
	t = runner


## Kwadrat (2 trójkąty) w płaszczyźnie z = h (układ CEM), x ∈ [x0, x0+1], y ∈ [0, 1]; odwrocony → przeciwne nawinięcie.
static func _kwadrat(x0: float, h: float, vo: int, odwrocony: bool) -> Dictionary:
	var p := [Vector3(x0, 0, h), Vector3(x0 + 1, 0, h), Vector3(x0 + 1, 1, h), Vector3(x0, 1, h)]
	var tri := PackedInt32Array([0, 1, 2, 0, 2, 3]) if not odwrocony else PackedInt32Array([0, 2, 1, 0, 3, 2])
	return {"p": p, "tri": tri, "vo": vo}


## Model syntetyczny: A – kwadrat z = 0 (materiał 0) i jego kopia o przeciwnym nawinięciu (ściana dwustronna),
## B – nakładka z = 0,001 (materiał 1, zgodny zwrot), C – kwadrat z = 0,05 (materiał 1, nie współpłaszczyznowy),
## D – duplikat pierwszego trójkąta A (materiał 1).
func _model() -> ModelCEM:
	var poz := PackedVector3Array(); var uv := PackedVector2Array()
	var kw := [_kwadrat(0, 0.0, 0, false), _kwadrat(0, 0.0, 4, true), _kwadrat(0, 0.001, 8, false), _kwadrat(0, 0.05, 12, false)]
	for k in kw:
		for q in k.p: poz.append(q); uv.append(Vector2(q.x * 0.5, q.y * 0.5))
	# duplikat: wierzchołki 16–18 = pierwsze trzy wierzchołki A
	for i in 3: poz.append(kw[0].p[i]); uv.append(Vector2(0.1, 0.1))
	var t0 := PackedInt32Array(); t0.append_array(kw[0].tri)
	var t0b := PackedInt32Array()
	for x in kw[1].tri: t0b.append(x + 4)
	t0.append_array(t0b)
	var t1 := PackedInt32Array()
	for x in kw[2].tri: t1.append(x)
	for x in kw[3].tri: t1.append(x + 4)
	for x in [8, 9, 10]: t1.append(x)            # duplikat (względem v_offset = 8 → wierzchołki 16–18)
	return ModelCEM.z_danych(CEMSyntetyczny.model_materialy("diag", poz, uv, [
		{"nazwa": "", "tex_id": 0, "v_offset": 0, "v_liczba": 8, "trojkaty": t0},
		{"nazwa": "player color", "tex_id": 0, "v_offset": 8, "v_liczba": 11, "trojkaty": t1}]))


func uruchom(K, Z) -> void:
	_jednostkowe()
	t._ok("D testy jednostkowe diagnostyki wykonane do końca (bez błędu skryptu)", _koniec_j)
	if not K.instalacje.has("referencyjna") or not Z.gotowe:
		t._pomin(["D dane: Stable - Copper – ukryta bryła pomocnicza (UV na alfa 0) w obu materiałach, usuwana wycinaniem alfa",
			"D dane: Stable - Copper – dwustronne płyty i nakładki koloru gracza wykryte jako współpłaszczyznowe",
			"D dane: nawinięcie spójne w modelach scenariusza Troi (podstawa odrzucania tylnych ścian)",
			"D dane: impostory „Always face camera” zwrócone w azymucie -45° (stała BILLBOARD_AZYMUT_ST)"], "brak instalacji EE")
		return
	_integracyjne(K, Z)
	t._ok("D testy integracyjne diagnostyki wykonane do końca (bez błędu skryptu)", _koniec_i)


func _jednostkowe() -> void:
	var m := _model()
	var tr := DiagnostykaModelu.trojkaty(m) if m.blad == "" else []
	var w := DiagnostykaModelu.wspolplaszczyznowe(tr) if not tr.is_empty() else {"pary": [], "duplikaty": [], "podsumowanie": {}}
	var pods: Dictionary = w.podsumowanie
	t._ok("D współpłaszczyznowe: ściana dwustronna (zwrot przeciwny) i nakładka 0,001 (zwrot zgodny) wykryte, kwadrat 0,05 pominięty",
		m.blad == "" and tr.size() == 9 and pods.get("przeciwne/ten_sam_material", 0) > 0 and pods.get("zgodne/rozne_materialy", 0) > 0
		and _bez_trojkatow(w, tr, 0.05), [m.blad, tr.size(), pods])
	t._ok("D duplikaty: trójkąt o tych samych wierzchołkach w innym materiale wykryty", w.duplikaty.size() == 1, w.duplikaty)
	var nw := DiagnostykaModelu.zgodnosc_nawiniecia(tr)
	# normalne wierzchołków syntetycznych = +Z CEM; 2 z 9 trójkątów (kwadrat odwrócony) mają przeciwne nawinięcie
	t._ok("D nawinięcie: zgodność z normalnymi wierzchołków liczona (wykrywa trójkąty o przeciwnym nawinięciu)",
		nw.trojkaty == 9 and (nw.zgodne == 2 or nw.zgodne == 7), nw)
	# reguły materiałów
	var imp := ImporterModeli.new()
	var ia := Image.create(8, 8, false, Image.FORMAT_RGBA8); ia.fill(Color(0, 0, 0, 0))
	for y in 8: ia.set_pixel(4, y, Color(0.8, 0.6, 0.2, 1.0))
	var io := Image.create(8, 8, false, Image.FORMAT_RGBA8); io.fill(Color(0.5, 0.5, 0.5, 1.0))
	var mp := imp._material(ia, Color(0, 0, 1), true); var mo := imp._material(io, Color(0, 0, 1), true)
	var av := AnimacjaVAT.new()
	var mv := av.material(ia, Color(0, 0, 1), true)
	t._ok("D materiały: „player color” z kanałem alfa wycina (statyczne i VAT); obraz bez alfy – bez wycinania",
		mp.get_shader_parameter("wycinanie_alfa") == true and mo.get_shader_parameter("wycinanie_alfa") == false
		and mv.get_shader_parameter("wycinanie_alfa") == true, "")
	var tx := ImporterModeli.obraz_gpu(ia)
	var obok := tx.get_pixel(3, 2)
	t._ok("D tekstura GPU: kolor tekseli o alfa 0 uzupełniony z sąsiadów (bez czarnych obwódek), alfa i mipmapy zachowane",
		tx.has_mipmaps() and obok.a < 0.01 and obok.r > 0.5 and tx.get_pixel(4, 2).a > 0.99, [obok, tx.has_mipmaps()])
	var sh := ImporterModeli.SHADER_MODELU; var shv := AnimacjaVAT.SHADER
	t._ok("D odrzucanie tylnych ścian w shaderze z wyznacznikiem macierzy (lustrzana baza obiektów) – modele statyczne i VAT",
		"cull_disabled" in sh and "determinant(mat3(MODELVIEW_MATRIX))" in sh and "FRONT_FACING == (v_lustro > 0.5)" in sh
		and "determinant(mat3(MODELVIEW_MATRIX))" in shv and "FRONT_FACING == (v_lustro > 0.5)" in shv and not ("cull_back" in sh), "")
	t._ok("D przesunięcie głębi modeli ku kamerze wzdłuż promienia (podstawy nad terenem) – statyczne i VAT",
		"pw.xyz *= 1.0 - przesuniecie_glebi" in sh and "POSITION = PROJECTION_MATRIX * pw" in sh and "przesuniecie_glebi" in shv, "")
	# billboard: kierunek projektowy (azymut -45° CEM → Godot (+X,+Z)/√2) po obrocie shadera wskazuje kamerę
	var ok_bb := absf(ImporterModeli.BILLBOARD_AZYMUT_ST - 45.0) < 0.01 and "billboard_azymut" in sh
	for kam: Vector3 in [Vector3(0, 0.6, 1), Vector3(1, 0.5, 0), Vector3(-0.7, 0.4, -0.7)]:
		var kz := kam.normalized()                                     # oś „do kamery” (INV_VIEW_MATRIX[2])
		var kx := Vector3.UP.cross(kz).normalized()
		var bx := Vector3.UP.cross(kz).normalized(); var bz := kx.cross(Vector3.UP).normalized()
		var a := deg_to_rad(ImporterModeli.BILLBOARD_AZYMUT_ST); var c := cos(a); var s := sin(a)
		var rx := bx * c + bz * s; var rz := bz * c - bx * s
		var d := (rx * Vector3(1, 0, 1).normalized().x + rz * Vector3(1, 0, 1).normalized().z).normalized()
		ok_bb = ok_bb and d.dot(Vector3(kz.x, 0, kz.z).normalized()) > 0.999
	t._ok("D billboard: kierunek projektowy impostora (azymut CEM -45°) obracany dokładnie do kamery", ok_bb, "")
	_koniec_j = true


func _bez_trojkatow(w: Dictionary, tr: Array, wys: float) -> bool:
	for p in w.pary:
		for i in [p[0], p[1]]:
			if absf((tr[i].P[0] as Vector3).y - wys) < 1e-4: return false
	return true


func _integracyjne(K, Z) -> void:
	var gr := {}
	for r in Z.tabela("dbgraphics"): gr[String(r.Name)] = r
	var st: Dictionary = gr.get("Stable - Copper", {})
	var m: ModelCEM = Z.wczytaj_model_cem(String(st.get("Model path", "")).to_lower().replace("\\", "/") + ".cem") if not st.is_empty() else null
	var tx := String(st.get("Texture path", "")).to_lower().replace("\\", "/")
	if m == null:
		t._ok("D dane: Stable - Copper – model dostępny", false, "brak"); _koniec_i = true; return
	var tr := DiagnostykaModelu.trojkaty(m)
	var img: Image = ImporterModeli.obraz_materialu(Z, tx, m.czesci[0].materialy[0], "test")
	var zero := {}
	for T in tr:
		if DiagnostykaModelu.alfa_w_srodku(img, T) == 0: zero[T.nazwa_mat] = zero.get(T.nazwa_mat, 0) + 1
	t._ok("D dane: Stable - Copper – ukryta bryła pomocnicza (UV na alfa 0) w obu materiałach, usuwana wycinaniem alfa",
		zero.get("player color", 0) >= 6 and zero.get("", 0) >= 6 and ImporterModeli.wymaga_wycinania(img), zero)
	var w := DiagnostykaModelu.wspolplaszczyznowe(tr)
	t._ok("D dane: Stable - Copper – dwustronne płyty i nakładki koloru gracza wykryte jako współpłaszczyznowe",
		w.podsumowanie.get("przeciwne/ten_sam_material", 0) >= 20 and w.podsumowanie.get("zgodne/rozne_materialy", 0) >= 10, w.podsumowanie)
	# nawinięcie modeli scenariusza Troi
	var a = Z.archiwum(K.zrodlo_gry, "Empire Earth/Data/Campaigns/EETheGreeks.ssa")
	var scn := ScenariuszEE.new(); var klucz := ""
	if a:
		for k in a.wpisy:
			if k.ends_with(".scn") and "trojan war" in k: klucz = k
	var zg := 0; var oc := 0; var modele := {}
	if klucz != "" and scn.wczytaj(a.czytaj(klucz)) and scn.czytaj_graczy(K.katalog_openee):
		var ob := {}
		for r in Z.tabela("dbobjects"): ob[int(r.ID)] = r
		var gid := {}
		for r in Z.tabela("dbgraphics"): gid[int(r.ID)] = r
		for g in scn.gracze:
			for u in g.jednostki:
				var r: Dictionary = gid.get(int(ob.get(int(u.type), {}).get("Graphic ID", -1)), {})
				var mp := String(r.get("Model path", "")).to_lower().replace("\\", "/")
				if mp != "": modele[mp] = true
		for mp in modele:
			var mm: ModelCEM = Z.wczytaj_model_cem(mp + ".cem")
			if mm == null or mm.blad != "": continue
			var nw := DiagnostykaModelu.zgodnosc_nawiniecia(DiagnostykaModelu.trojkaty(mm))
			zg += nw.zgodne; oc += nw.trojkaty
	var u := float(zg) / maxi(oc, 1)
	t._ok("D dane: nawinięcie spójne w modelach scenariusza Troi (podstawa odrzucania tylnych ścian)",
		oc > 1000 and (u < 0.05 or u > 0.95), [modele.size(), oc, snappedf(u, 0.001)])
	# kierunek impostorów
	var az: Array = []
	for o in Z.tabela("dbobjects"):
		if int(o.get("Always face camera", 0)) == 0: continue
		var r: Dictionary = {}
		for g in Z.tabela("dbgraphics"):
			if int(g.ID) == int(o.get("Graphic ID", -1)): r = g; break
		var mp := String(r.get("Model path", "")).to_lower().replace("\\", "/")
		if mp == "" or az.size() >= 40: continue
		var mm: ModelCEM = Z.wczytaj_model_cem(mp + ".cem")
		if mm == null or mm.blad != "": continue
		var s := Vector3.ZERO
		for T in DiagnostykaModelu.trojkaty(mm):
			var n: Vector3 = T.n * T.pole
			s += n if n.dot(T.nv) >= 0.0 else -n          # strona wg normalnych wierzchołków
		if Vector2(s.x, s.z).length() > 1e-6:
			# Godot (x, z) = CEM (x, -y) → azymut CEM = atan2(-z, x)
			az.append(rad_to_deg(atan2(-s.z, s.x)))
	az.sort()
	var med: float = az[az.size() / 2] if not az.is_empty() else 999.0
	t._ok("D dane: impostory „Always face camera” zwrócone w azymucie -45° (stała BILLBOARD_AZYMUT_ST)",
		az.size() >= 10 and absf(med + ImporterModeli.BILLBOARD_AZYMUT_ST) < 15.0, [az.size(), snappedf(med, 0.1)])
	_koniec_i = true
