class_name TestyGrafiki
extends RefCounted
## Testy naprawy grafiki (RAPORT_NAPRAWA_GRAFIKI.md): indeksy materiałów względne wobec v_offset, wybór obrazu SST
## polem tekstura_id, reguła koloru gracza, UV, hierarchia, wykrywanie złych indeksów i braków tekstur.

var t
var _koniec_j := false
var _koniec_i := false
const PROBLEMATYCZNE := ["House - Copper", "House - Paleo", "Fortress - Copper", "Town Center - Paleo", "Barracks - 10"]
const ODNIESIENIE := "Scaffolding Copper 3x3"


func _init(runner) -> void:
	t = runner


class _ZasobyTestowe:
	var obrazy: Array = []
	func wczytaj_tekstury(_k: String) -> Array:
		return obrazy


## Model: materiał A (wierzchołki 0–2, trójkąt przy x≈0, UV ≈ 0,1), materiał „player color” B (wierzchołki 3–5,
## trójkąt przy x≈10, UV ≈ 0,9), indeksy B względne (0, 1, 2) jak w danych EE.
func _model_ab(zly_indeks: bool = false) -> PackedByteArray:
	var poz := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(10, 0, 0), Vector3(11, 0, 0), Vector3(10, 1, 0)])
	var uv := PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.2, 0.1), Vector2(0.1, 0.2), Vector2(0.9, 0.9), Vector2(0.8, 0.9), Vector2(0.9, 0.8)])
	return CEMSyntetyczny.model_materialy("dom", poz, uv, [
		{"nazwa": "", "tex_id": 0, "v_offset": 0, "v_liczba": 3, "trojkaty": PackedInt32Array([0, 1, 2]), "tekstura": "a"},
		{"nazwa": "player color", "tex_id": 1, "v_offset": 3, "v_liczba": 3,
			"trojkaty": PackedInt32Array([0, 1, 5 if zly_indeks else 2]), "tekstura": "b"}])


func uruchom(K, Z) -> void:
	_jednostkowe()
	t._ok("G testy jednostkowe wykonane do końca (bez błędu skryptu)", _koniec_j)
	if not K.instalacje.has("referencyjna") or not Z.gotowe:
		t._pomin(["G dane: modele z dbgraphics – indeksy materiałów w zakresie wierzchołków materiału (ModelCEM.kontrola)",
			"G dane: problematyczne budynki – trójkąty koloru gracza na właściwych wierzchołkach i UV (dawny odczyt trafiał w obce fragmenty tekstury)",
			"G dane: tekstura_id → obraz pliku SST (dom z 2 obrazami: materiał B dostaje obraz 1)",
			"G dane: fragmenty tekstur pod „player color” szare – podstawa reguły tekstura · kolor gracza",
			"G dane: modele scenariusza Troi – każda teksturowana powierzchnia ma obraz (brak „białych” braków)"], "brak instalacji EE")
		return
	_integracyjne(K, Z)
	t._ok("G testy integracyjne wykonane do końca (bez błędu skryptu)", _koniec_i)


func _jednostkowe() -> void:
	var m := ModelCEM.z_danych(_model_ab())
	var b: Dictionary = m.czesci[0].materialy[1] if m.blad == "" else {}
	t._ok("G CEM: indeksy materiału względne wobec v_offset (materiał B → wierzchołki 3–5, zamiana kolejności jak dotąd)",
		m.blad == "" and b.indeksy == PackedInt32Array([3, 5, 4]) and m.czesci[0].materialy[0].indeksy == PackedInt32Array([0, 2, 1])
		and m.kontrola().is_empty(), [m.blad, b.get("indeksy"), m.kontrola()])
	t._ok("G CEM: tekstura_id, v_offset i v_liczba materiałów odczytane", b.get("tekstura_id") == 1 and b.get("v_offset") == 3
		and b.get("v_liczba") == 3 and m.czesci[0].materialy[0].tekstura_id == 0, b)
	var mz := ModelCEM.z_danych(_model_ab(true))
	t._ok("G CEM: wykrywanie złego indeksu (poza zakresem wierzchołków materiału) w kontroli modelu",
		not mz.kontrola().is_empty(), mz.kontrola())
	var leg := ImporterModeli.parsuj(_model_ab())
	t._ok("G CEM: czytnik ImporterModeli.parsuj zgodny z ModelCEM (indeksy względne)",
		leg.materialy[1].indeksy == PackedInt32Array([3, 5, 4]), leg.materialy[1].indeksy)
	# UV i geometria powierzchni po imporcie statycznym
	var mesh: ArrayMesh = ImporterModeli.new().importuj(_model_ab(), {"klucz": "dom"})
	var ok_uv := mesh != null and mesh.get_surface_count() == 2
	var info: Array = []
	if ok_uv:
		for si in 2:
			var arr := mesh.surface_get_arrays(si)
			var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]; var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for x in ind:
				ok_uv = ok_uv and (uv[x].x < 0.35 if si == 0 else uv[x].x > 0.65) and (v[x].x < 2.0 if si == 0 else v[x].x > 9.0)
			info.append([ind, uv[ind[0]]])
	t._ok("G UV i geometria: powierzchnia każdego materiału używa wyłącznie własnych wierzchołków i UV", ok_uv, info)
	# wybór obrazu SST
	var z := _ZasobyTestowe.new()
	var i0 := Image.create(4, 4, false, Image.FORMAT_RGBA8); i0.fill(Color.RED)
	var i1 := Image.create(4, 4, false, Image.FORMAT_RGBA8); i1.fill(Color.GREEN)
	z.obrazy = [i0, i1]
	var o0 := ImporterModeli.obraz_materialu(z, "x", {"tekstura_id": 0}, "t")
	var o1 := ImporterModeli.obraz_materialu(z, "x", {"tekstura_id": 1}, "t")
	var o9 := ImporterModeli.obraz_materialu(z, "x", {"tekstura_id": 9}, "t")
	z.obrazy = []
	var on := ImporterModeli.obraz_materialu(z, "x", {"tekstura_id": 0, "tekstura": ""}, "t")
	t._ok("G tekstury: obraz pliku SST wybierany polem tekstura_id (przycięcie do ostatniego, brak → null z diagnostyką)",
		o0 == i0 and o1 == i1 and o9 == i1 and on == null, "")
	# materiały: kolor gracza i wycinanie
	var imp := ImporterModeli.new()
	var ia := Image.create(4, 4, false, Image.FORMAT_RGBA8); ia.fill(Color(1, 1, 1, 0.0)); ia.set_pixel(0, 0, Color(1, 1, 1, 1))
	var mp := imp._material(ia, Color(0, 0, 1), true); var mn := imp._material(ia, Color(0, 0, 1), false)
	t._ok("G materiały: „player color” – tekstura · kolor gracza, bez wycinania; zwykły – wycinanie alfa, bez koloru",
		mp.get_shader_parameter("kolor_gracza_mnoz") == true and mp.get_shader_parameter("wycinanie_alfa") == false
		and mn.get_shader_parameter("kolor_gracza_mnoz") == false and mn.get_shader_parameter("wycinanie_alfa") == true
		and "t.rgb * kolor_gracza.rgb" in ImporterModeli.SHADER_MODELU and "t.rgb * v_kolor" in AnimacjaVAT.SHADER, "")
	# VAT – te same indeksy i materiały
	var a := AnimacjaVAT.wypiecz(ModelCEM.z_danych(_model_ab()), {})
	var arrv := a.siatka.surface_get_arrays(1) if a and a.siatka.get_surface_count() == 2 else []
	t._ok("G VAT: siatka animowana z tymi samymi indeksami materiałów (B → wierzchołki 3–5)",
		not arrv.is_empty() and arrv[Mesh.ARRAY_INDEX] == PackedInt32Array([3, 5, 4]), arrv[Mesh.ARRAY_INDEX] if not arrv.is_empty() else null)
	_koniec_j = true


## Mediana nasycenia tekstury (0–255) w środkach trójkątów materiałów „player color” – przy poprawnych indeksach
## trójkąty trafiają w szare obszary tekstury przeznaczone na kolor gracza; przy dawnym odczycie (bez v_offset) – w obce,
## kolorowe fragmenty (rozjechane UV, plamy koloru gracza).
func _nasycenie_pc(Z, m: ModelCEM, tx: String, bezwzgledne: bool) -> float:
	var c: Dictionary = m.czesci[0]
	var uv: PackedVector2Array = c.uv
	var nas: Array[float] = []
	for mt in c.materialy:
		if String(mt.nazwa) != "player color": continue
		var img: Image = ImporterModeli.obraz_materialu(Z, tx, mt, "test")
		if img == null: continue
		var ind: PackedInt32Array = mt.indeksy
		var vo: int = mt.get("v_offset", 0) if bezwzgledne else 0
		for k in range(0, ind.size(), 3):
			var u := (uv[ind[k] - vo] + uv[ind[k + 1] - vo] + uv[ind[k + 2] - vo]) / 3.0
			var px := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
			nas.append((maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b))) * 255.0)
	if nas.is_empty(): return -1.0
	nas.sort()
	return nas[nas.size() / 2]


func _graf(Z, nazwa: String) -> Dictionary:
	for r in Z.tabela("dbgraphics"):
		if String(r.get("Name", "")) == nazwa: return r
	return {}


func _integracyjne(K, Z) -> void:
	# 1. kontrola indeksów na próbce modeli dbgraphics + wszystkich problematycznych
	var bledy: Array = []; var n := 0; var i := 0
	for r in Z.tabela("dbgraphics"):
		i += 1
		var mp := String(r.get("Model path", "")).to_lower().replace("\\", "/")
		if mp == "" or (i % 9 != 0 and not (String(r.get("Name", "")) in PROBLEMATYCZNE)): continue
		var m: ModelCEM = Z.wczytaj_model_cem(mp + ".cem")
		if m == null: continue
		n += 1
		for b in m.kontrola():
			if "materiału" in String(b): bledy.append("%s: %s" % [mp, b])
	t._ok("G dane: modele z dbgraphics – indeksy materiałów w zakresie wierzchołków materiału (ModelCEM.kontrola)",
		n > 80 and bledy.is_empty(), "%d modeli, błędy: %s" % [n, bledy.slice(0, 5)])
	# 2. trójkąty „player color” trafiają w szare obszary tekstury (teraz) – dawny odczyt bez v_offset trafiał obok
	var wyn: Array = []; var ok := true; var lepsze := 0
	for nazwa in PROBLEMATYCZNE:
		var g := _graf(Z, nazwa)
		var tx := String(g.get("Texture path", "")).to_lower().replace("\\", "/")
		var m: ModelCEM = Z.wczytaj_model_cem(String(g.get("Model path", "")).to_lower().replace("\\", "/") + ".cem")
		if m == null:
			ok = false; wyn.append([nazwa, "brak"]); continue
		var teraz := _nasycenie_pc(Z, m, tx, false); var dawniej := _nasycenie_pc(Z, m, tx, true)
		wyn.append([nazwa, teraz, dawniej])
		# warunek na każdy model: trójkąty koloru gracza w szarych obszarach (próg 20/255; normalne tekstury ~36)
		ok = ok and teraz >= 0.0 and teraz < 20.0
		if teraz >= 0.0 and dawniej > teraz + 15.0: lepsze += 1
	# dawny odczyt bywa przypadkiem trafny (Fortress/Barracks: przesunięte wierzchołki też padają na szare pola),
	# więc różnicę wymagamy dla większości zestawu, a nie dla każdego modelu
	ok = ok and lepsze >= 3
	t._ok("G dane: problematyczne budynki – trójkąty koloru gracza na właściwych wierzchołkach i UV (dawny odczyt trafiał w obce fragmenty tekstury)", ok,
		"[nazwa, mediana nasycenia teraz, przy dawnym odczycie] %s" % [wyn])
	# 3. tekstura_id → obraz SST
	var gh := _graf(Z, "House - Paleo")
	var tex := String(gh.get("Texture path", "")).to_lower().replace("\\", "/")
	var obrazy: Array = Z.wczytaj_tekstury(tex)
	var mh: ModelCEM = Z.wczytaj_model_cem(String(gh.get("Model path", "")).to_lower().replace("\\", "/") + ".cem")
	var mat1 := {}
	if mh:
		for mt in mh.czesci[0].materialy:
			if int(mt.tekstura_id) == 1: mat1 = mt; break
	var ob1 := ImporterModeli.obraz_materialu(Z, tex, mat1, "test") if not mat1.is_empty() else null
	t._ok("G dane: tekstura_id → obraz pliku SST (dom z 2 obrazami: materiał B dostaje obraz 1)",
		obrazy.size() == 2 and ob1 != null and ob1 == obrazy[1] and (obrazy[0] as Image).get_data() != (obrazy[1] as Image).get_data(),
		[tex, obrazy.size(), not mat1.is_empty()])
	# 4. szarość fragmentów „player color”
	var nas: Array[float] = []
	for nazwa in PROBLEMATYCZNE:
		var g := _graf(Z, nazwa)
		var tx := String(g.get("Texture path", "")).to_lower().replace("\\", "/")
		var m: ModelCEM = Z.wczytaj_model_cem(String(g.get("Model path", "")).to_lower().replace("\\", "/") + ".cem")
		if m == null: continue
		var c: Dictionary = m.czesci[0]
		for mt in c.materialy:
			if String(mt.nazwa) != "player color": continue
			var img: Image = ImporterModeli.obraz_materialu(Z, tx, mt, "test")
			if img == null: continue
			var ind: PackedInt32Array = mt.indeksy; var uv: PackedVector2Array = c.uv
			for k in range(0, ind.size(), 3):
				var u := (uv[ind[k]] + uv[ind[k + 1]] + uv[ind[k + 2]]) / 3.0
				var px := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
				nas.append((maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b))) * 255.0)
	nas.sort()
	var med: float = nas[nas.size() / 2] if not nas.is_empty() else 999.0
	t._ok("G dane: fragmenty tekstur pod „player color” szare – podstawa reguły tekstura · kolor gracza",
		nas.size() > 50 and med < 15.0, "%d próbek, mediana nasycenia %.1f/255" % [nas.size(), med])
	# 5. braki tekstur w modelach scenariusza Troi
	var s: ScenariuszEE = t._scn(Z, "Empire Earth", "EETheGreeks.ssa", "trojan war")
	var obj := {}
	for o in Z.tabela("dbobjects"): obj[int(o.ID)] = o
	var gid := {}
	for r in Z.tabela("dbgraphics"): gid[int(r.ID)] = r
	var braki: Array = []; var modele := {}
	if s and s.czytaj_graczy(K.katalog_openee):
		for g in s.gracze:
			for u in g.jednostki:
				var gr: Dictionary = gid.get(int(obj.get(int(u.type), {}).get("Graphic ID", -1)), {})
				var mp := String(gr.get("Model path", "")).to_lower().replace("\\", "/")
				if mp == "" or modele.has(mp): continue
				modele[mp] = true
				var tx := String(gr.get("Texture path", "")).to_lower().replace("\\", "/")
				var m: ModelCEM = Z.wczytaj_model_cem(mp + ".cem")
				if m == null: continue
				for c in m.czesci:
					for mt in c.materialy:
						if tx == "" and String(mt.tekstura) == "": continue      # powierzchnie pomocnicze (pomijane jawnie)
						if ImporterModeli.obraz_materialu(Z, tx, mt, mp) == null: braki.append(mp)
	t._ok("G dane: modele scenariusza Troi – każda teksturowana powierzchnia ma obraz (brak „białych” braków)",
		modele.size() > 10 and braki.is_empty(), "%d modeli, braki: %s" % [modele.size(), braki.slice(0, 6)])
	_koniec_i = true
