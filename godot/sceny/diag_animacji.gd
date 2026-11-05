extends Node3D
## Scena diagnostyczna animacji – etap 4. Modele i sekwencje wyłącznie z instalacji EE (dbgraphics + CEM).
## Argumenty (po "--"):
##   --model=<nazwa grafiki dbgraphics | models/plik.cem>   --sekwencja=<stan, np. bezczynnosc|ruch|atak|smierc>
##   --galeria=<nazwa;nazwa;…>  kilka modeli obok siebie (każdy w swojej sekwencji)
##   --czas=<s>  ustawienie zegara przed zrzutem   --zrzut=<plik.png>   --bez-interpolacji   --bez-ui
##   --odleglosc=<m> --pochylenie=<stopnie>  kamera
##   --film=<katalog> --klatki-filmu=<n> --fps-filmu=<n>  kolejne klatki PNG (stały krok czasu)
##   --pomiar=<liczby instancji, np. 100,500,1000,2000> --pomiar-model=<nazwa>  → wyniki/pomiar_animacji.json
## Sterowanie: lewy/prawy przycisk myszy – obrót kamery, kółko – przybliżenie, spacja – pauza.

var _grafiki: Array = []          # rekordy dbgraphics z sekwencjami wielu klatek
var _odtw: OdtwarzaczAnimacji
var _kam: Camera3D
var _yaw := 35.0
var _pitch := -25.0
var _dist := 4.0
var _cel := Vector3(0, 0.7, 0)
var _wezly: Array = []            # [{mi, anim, sek, kanal, nazwa}]
var _lista: ItemList
var _filtr: LineEdit
var _sekw: ItemList
var _drzewo: Tree
var _info: Label
var _osie: MeshInstance3D
var _pred: HSlider
var _interp: CheckBox
var _nazwy_dz := {}
var raport := {}


func _arg(nazwa: String, dom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nazwa):
			return a.split("=", true, 1)[1]
	return dom


func _ready() -> void:
	_odtw = OdtwarzaczAnimacji.new(); _odtw.name = "Odtwarzacz"; add_child(_odtw)
	_swiat()
	if not Zasoby.gotowe:
		_info_tekst("Brak instalacji Empire Earth – wskaż ją w launcherze (Zmień…).")
		if _arg("zrzut", "") != "": _zrzut(_arg("zrzut", ""))
		return
	for d in Zasoby.tabela("dbsounds"): _nazwy_dz[int(d.ID)] = String(d.Name)
	for r in Zasoby.tabela("dbgraphics"):
		if String(r.get("Model path", "")) == "": continue
		var s := SekwencjeAnimacji.z_rekordu(r)
		if s.sekwencje.any(func(q): return int(q.klatki) > 1):
			_grafiki.append(r)
	if _arg("pomiar", "") != "":
		await _pomiar(); return
	if not "--bez-ui" in OS.get_cmdline_user_args():
		_interfejs()
	if _arg("galeria", "") != "":
		var x := 0.0
		for n in _arg("galeria", "").split(";"):
			var w := _pokaz(n, Vector3(x, 0, 0), false)
			if not w.is_empty(): x += maxf(1.6, (w.anim.siatka.custom_aabb as AABB).size.x + 0.8)
		if not _wezly.is_empty():
			_wybierz(_wezly[0])
		_cel = Vector3(x / 2.0 - 0.8, 0.6, 0); _dist = maxf(4.0, x * 0.9); _yaw = 0.0
	else:
		_pokaz(_arg("model", "Phalanx"), Vector3.ZERO, true)
	if "--bez-interpolacji" in OS.get_cmdline_user_args():
		if _interp: _interp.button_pressed = false
		for w in _wezly: w.anim.ustaw_interpolacje(false)
	if _arg("odleglosc", "") != "":
		_dist = float(_arg("odleglosc", "4"))
	if _arg("pochylenie", "") != "":
		_pitch = float(_arg("pochylenie", "-25"))
	if _arg("czas", "") != "":
		_odtw.czas = float(_arg("czas", "0")); _odtw.krok(0.0)
	if _arg("film", "") != "":
		await _film(); return
	if _arg("zrzut", "") != "":
		_odtw.pauza_globalna = true
		_zrzut(_arg("zrzut", ""))


func _swiat() -> void:
	var sw := DirectionalLight3D.new(); sw.rotation_degrees = Vector3(-50, -35, 0); add_child(sw)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9); env.ambient_light_energy = 0.6
	we.environment = env; add_child(we)
	var pod := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); pod.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.36, 0.42, 0.33); pod.material_override = mat
	add_child(pod)
	_kam = Camera3D.new(); _kam.fov = 40; add_child(_kam); _kam.current = true
	_osie = MeshInstance3D.new(); _osie.mesh = ImmediateMesh.new()
	var mo := StandardMaterial3D.new(); mo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mo.vertex_color_use_as_albedo = true; mo.no_depth_test = true; _osie.material_override = mo
	add_child(_osie)


## Grafika po nazwie (dbgraphics Name) lub ścieżce modelu → rekord.
func _rekord(n: String) -> Dictionary:
	var s := n.strip_edges().to_lower()
	for r in Zasoby.tabela("dbgraphics"):
		if String(r.get("Name", "")).to_lower() == s or String(r.get("Model path", "")).to_lower().replace("\\", "/") == s.trim_suffix(".cem"):
			return r
	for r in _grafiki:
		if s in String(r.get("Name", "")).to_lower(): return r
	return {}


func _pokaz(n: String, poz: Vector3, wybrany: bool) -> Dictionary:
	var r := _rekord(n)
	if r.is_empty():
		Dziennik.uwaga("diag_animacji", "Brak grafiki '%s'" % n); return {}
	var model := String(r["Model path"]).to_lower().replace("\\", "/") + ".cem"
	var tex := String(r.get("Texture path", "")).to_lower().replace("\\", "/")
	var t0 := Time.get_ticks_usec()
	var anim := Zasoby.wczytaj_animacje(model, {"tekstura": tex, "kolor_gracza": Color(0.1, 0.3, 0.95)})
	if anim == null:
		return {}
	var sek := SekwencjeAnimacji.z_rekordu(r)
	var mi := MeshInstance3D.new(); mi.mesh = anim.siatka; mi.position = poz
	add_child(mi)
	var w := {"mi": mi, "anim": anim, "sek": sek, "kanal": _odtw.dodaj(mi), "nazwa": String(r.Name), "model": model,
		"import_ms": (Time.get_ticks_usec() - t0) / 1000.0}
	_wezly.append(w)
	var stan := _arg("sekwencja", "bezczynnosc")
	var q := sek.dla_stanu(stan)
	if q.is_empty() or int(q.klatki) <= 1:
		for x in sek.sekwencje:
			if int(x.klatki) > 1:
				q = x; break
	if q.is_empty(): _odtw.ustaw_klatke(w.kanal, 0)
	else: _odtw.odtworz(w.kanal, q)
	raport[String(r.Name)] = {"model": model, "klatki_modelu": anim.klatki, "czesci": anim.model.czesci.size(),
		"wierzcholki": anim.wierzcholki, "sekwencja": q, "import_i_wypiekanie_ms": snappedf(w.import_ms, 0.1),
		"kontrola_modelu": anim.model.kontrola(), "kontrola_sekwencji": sek.kontrola(anim.klatki)}
	if wybrany:
		_wybierz(w)
	return w


func _wybierz(w: Dictionary) -> void:
	for x in _wezly:
		if x != w:
			x.mi.visible = _arg("galeria", "") != ""
	var aabb: AABB = w.anim.siatka.custom_aabb
	_cel = w.mi.position + aabb.get_center(); _dist = maxf(2.5, aabb.size.length() * 1.6)
	if _sekw == null: return
	_sekw.clear()
	for q in w.sek.sekwencje:
		var dz := ", ".join(q.dzwieki.map(func(d): return _nazwy_dz.get(int(d), str(d))))
		_sekw.add_item("[%d] %s: %d–%d (%d kl., %.2f s%s)%s" % [q.gniazdo, q.stan, q.od, q.do, q.klatki, q.czas_cyklu,
			", pętla" if q.petla else "", ("  ♪ " + dz) if dz != "" else ""])
	_drzewo.clear()
	var korzen := _drzewo.create_item()
	var elem := {}
	for c in w.anim.model.drzewo():
		var rodzic: TreeItem = elem.get(int(c.rodzic), korzen)
		var it := _drzewo.create_item(rodzic)
		it.set_text(0, "%s  [%d kl., %d wierzch.%s%s%s]" % [String(c.nazwa).strip_edges() if c.nazwa != "" else "(bez nazwy)",
			c.klatki, c.wierzcholki, ", anim. wierzch." if c.animacja_wierzcholkowa else "",
			", ruch macierzy" if c.macierz_zmienna else "", (", " + c.sterowanie) if c.sterowanie != "" else ""])
		elem[int(c.i)] = it


func _interfejs() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	var lewy := VBoxContainer.new(); lewy.position = Vector2(8, 8); lewy.size = Vector2(330, 700); cl.add_child(lewy)
	var tyt := Label.new(); tyt.text = "OpenEE – animacje CEM (etap 4)"; lewy.add_child(tyt)
	_filtr = LineEdit.new(); _filtr.placeholder_text = "Filtr grafik…"; lewy.add_child(_filtr)
	_lista = ItemList.new(); _lista.custom_minimum_size = Vector2(320, 300); lewy.add_child(_lista)
	_filtr.text_changed.connect(func(_t): _wypelnij())
	_lista.item_activated.connect(func(i): _zmien_model(String(_lista.get_item_metadata(i))))
	_wypelnij()
	var l2 := Label.new(); l2.text = "Sekwencje (dbgraphics):"; lewy.add_child(l2)
	_sekw = ItemList.new(); _sekw.custom_minimum_size = Vector2(320, 200); lewy.add_child(_sekw)
	_sekw.item_activated.connect(func(i): _zmien_sekwencje(i))
	_sekw.item_selected.connect(func(i): _zmien_sekwencje(i))
	var rz := HBoxContainer.new(); lewy.add_child(rz)
	var bp := Button.new(); bp.text = "Pauza / wznów"; rz.add_child(bp)
	bp.pressed.connect(_przelacz_pauze)
	_interp = CheckBox.new(); _interp.text = "interpolacja"; _interp.button_pressed = true; rz.add_child(_interp)
	_interp.toggled.connect(_ustaw_interpolacje)
	var rp := HBoxContainer.new(); lewy.add_child(rp)
	var lp := Label.new(); lp.text = "Prędkość"; rp.add_child(lp)
	_pred = HSlider.new(); _pred.min_value = 0.0; _pred.max_value = 3.0; _pred.step = 0.05; _pred.value = 1.0
	_pred.custom_minimum_size = Vector2(200, 20); rp.add_child(_pred)
	_pred.value_changed.connect(_ustaw_predkosc)
	var prawy := VBoxContainer.new(); prawy.anchor_left = 1.0; prawy.anchor_right = 1.0
	prawy.position = Vector2(-420, 8); prawy.size = Vector2(410, 600); cl.add_child(prawy)
	var l3 := Label.new(); l3.text = "Części modelu (hierarchia):"; prawy.add_child(l3)
	_drzewo = Tree.new(); _drzewo.custom_minimum_size = Vector2(410, 260); _drzewo.hide_root = true; prawy.add_child(_drzewo)
	_info = Label.new(); prawy.add_child(_info)
	for c in [tyt, l2, l3, lp, _info]:
		c.add_theme_color_override("font_color", Color.WHITE)
		c.add_theme_color_override("font_outline_color", Color.BLACK); c.add_theme_constant_override("outline_size", 4)


func _ustaw_interpolacje(v: bool) -> void:
	for w in _wezly:
		w.anim.ustaw_interpolacje(v)


func _ustaw_predkosc(v: float) -> void:
	for w in _wezly:
		_odtw.ustaw_predkosc(w.kanal, v)


func _wypelnij() -> void:
	_lista.clear()
	var f := _filtr.text.to_lower() if _filtr else ""
	for r in _grafiki:
		var n := String(r.Name)
		if f != "" and not (f in n.to_lower() or f in String(r["Model path"]).to_lower()): continue
		var i := _lista.add_item("%s  (%s)" % [n, String(r["Model path"]).get_file()])
		_lista.set_item_metadata(i, String(r["Model path"]))


func _zmien_model(sciezka: String) -> void:
	for w in _wezly: w.mi.queue_free()
	_wezly.clear()
	_pokaz(sciezka, Vector3.ZERO, true)


func _zmien_sekwencje(i: int) -> void:
	if _wezly.is_empty(): return
	var w: Dictionary = _wezly[-1] if _arg("galeria", "") == "" else _wezly[0]
	_odtw.odtworz(w.kanal, w.sek.sekwencje[i])
	_odtw.ustaw_predkosc(w.kanal, _pred.value)


func _przelacz_pauze() -> void:
	for w in _wezly:
		_odtw.pauza(w.kanal, not bool(_odtw._pauza[w.kanal]))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)):
		_yaw -= e.relative.x * 0.4; _pitch = clampf(_pitch - e.relative.y * 0.3, -85, 10)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _dist = maxf(0.5, _dist * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _dist = minf(80.0, _dist * 1.1)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_SPACE:
		_przelacz_pauze()


func _process(_d: float) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0))
	_kam.global_transform = Transform3D(b, _cel + b.z * _dist)
	if _wezly.is_empty(): return
	var w: Dictionary = _wezly[-1] if _arg("galeria", "") == "" else _wezly[0]
	var k := _odtw.klatki(w.kanal)
	var q: Dictionary = _odtw.sekwencja(w.kanal)
	if _info:
		_info.text = "%s – %s\nklatki modelu: %d, części: %d, wierzchołki: %d\nsekwencja: %s %d–%d, czas cyklu %.2f s [H]\nklatka: %d → %d (udział %.2f), czas: %.2f s, prędkość ×%.2f%s" % [
			w.nazwa, w.model, w.anim.klatki, w.anim.model.czesci.size(), w.anim.wierzcholki, q.get("stan", "-"),
			q.get("od", 0), q.get("do", 0), q.get("czas_cyklu", 0.0), k.x, k.y, k.z, _odtw.czas, _pred.value if _pred else 1.0,
			"  [PAUZA]" if bool(_odtw._pauza[w.kanal]) else ""]
	_rysuj_osie(w, k)


## Osie każdej części (X czerwona, Y zielona, Z niebieska) w transformacji z hierarchii, z interpolacją.
func _rysuj_osie(w: Dictionary, k: Vector3) -> void:
	var im: ImmediateMesh = _osie.mesh
	im.clear_surfaces()
	var m: ModelCEM = w.anim.model
	if m.czesci.size() < 2: return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, m.czesci.size()):
		var t := m.globalna_interp(i, int(k.x), int(k.y), k.z)
		t.origin += w.mi.position
		for o in [[t.basis.x, Color.RED], [t.basis.y, Color.GREEN], [t.basis.z, Color.BLUE]]:
			im.surface_set_color(o[1]); im.surface_add_vertex(t.origin)
			im.surface_set_color(o[1]); im.surface_add_vertex(t.origin + (o[0] as Vector3).normalized() * 0.25)
	im.surface_end()


func _info_tekst(t: String) -> void:
	var cl := CanvasLayer.new(); var l := Label.new(); l.text = t; l.position = Vector2(12, 12); cl.add_child(l); add_child(cl)


func _zrzut(sciezka: String) -> void:
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var e := img.save_png(sciezka)
	var f := FileAccess.open(sciezka.get_basename() + ".json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(raport, "  "))
	Dziennik.info("diag_animacji", "Zrzut %s (kod %d)" % [sciezka, e])
	get_tree().quit(0 if e == OK else 1)


func _film() -> void:
	var kat := _arg("film", "")
	DirAccess.make_dir_recursive_absolute(kat)
	var n := int(_arg("klatki-filmu", "60")); var fps := float(_arg("fps-filmu", "25"))
	_odtw.set_process(false)
	for i in range(4): await get_tree().process_frame
	for i in n:
		_odtw.krok(1.0 / fps)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(kat.path_join("klatka_%04d.png" % i))
	Dziennik.info("diag_animacji", "Film: %d klatek → %s" % [n, kat])
	get_tree().quit(0)


## Pomiar: N animowanych instancji modelu w jednym MultiMesh (różne fazy), osobno: import+wypiekanie,
## tworzenie instancji, zmiana stanu wszystkich (CPU), czas klatki, wywołania rysowania, pamięć.
func _pomiar() -> void:
	var r := _rekord(_arg("pomiar-model", "Phalanx"))
	var model := String(r["Model path"]).to_lower().replace("\\", "/") + ".cem"
	var tex := String(r.get("Texture path", "")).to_lower().replace("\\", "/")
	var tz := Time.get_ticks_usec()
	var surowe: Dictionary = Zasoby.znajdz(model)          # odczyt z SSA + dekompresja DCL (GDScript)
	var tm := Time.get_ticks_usec()
	var tex_r: Dictionary = Zasoby.znajdz(tex + ".sst") if tex != "" else {}
	var t0 := Time.get_ticks_usec()
	var mcem := ModelCEM.z_danych(surowe.dane)
	var t1 := Time.get_ticks_usec()
	var t_tex0 := Time.get_ticks_usec()
	Zasoby.znajdz(tex + ".sst")
	var t_tex1 := Time.get_ticks_usec()
	var anim := AnimacjaVAT.wypiecz(mcem, {"zasoby": Zasoby, "tekstura": tex})
	var t2 := Time.get_ticks_usec()
	var sek := SekwencjeAnimacji.z_rekordu(r)
	var q := sek.bezczynnosc()
	var mm_siatka := anim.siatka_multimesh()
	var wyniki: Array = []
	_kam.fov = 50
	var siatka_stat: Mesh = Zasoby.wczytaj_model(model, {"tekstura": tex})
	var plan: Array = []
	for liczba in Array(_arg("pomiar", "100,500,1000").split(",")).map(func(x): return int(x)):
		plan.append([liczba, "vat"]); plan.append([liczba, "statyczny"])
	for pl in plan:
		var liczba: int = pl[0]; var tryb: String = pl[1]
		var odtw := OdtwarzaczAnimacji.new(); add_child(odtw)
		var bok := ceili(sqrt(liczba))
		var ta := Time.get_ticks_usec()
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true; mm.use_custom_data = true; mm.mesh = mm_siatka if tryb == "vat" else siatka_stat
		mm.instance_count = liczba
		var los := RandomNumberGenerator.new(); los.seed = 4
		for i in liczba:
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, los.randf() * TAU), Vector3((i % bok) * 1.2, 0, (i / bok) * 1.2)))
			mm.set_instance_color(i, Color.from_hsv(float(i % 8) / 8.0, 0.8, 0.9))
			if tryb == "vat":
				var k := odtw.dodaj(mm, i)
				odtw.odtworz(k, q, los.randf() * float(q.get("klatki", 1)))
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; add_child(mmi)
		var tb := Time.get_ticks_usec()
		_cel = Vector3(bok * 0.6, 0, bok * 0.6); _dist = bok * 1.6; _pitch = -45
		for i in 5: await get_tree().process_frame
		var czasy: Array[float] = []
		var t := Time.get_ticks_usec()
		for i in 120:
			await get_tree().process_frame
			var n := Time.get_ticks_usec(); czasy.append((n - t) / 1000.0); t = n
		czasy.sort()
		var suma := 0.0
		for c in czasy: suma += c
		# zmiana animacji wszystkich instancji (np. rozkaz dla całej armii) – koszt CPU
		var q2 := sek.dla_stanu("ruch")
		if q2.is_empty():
			q2 = q
		var tzm := Time.get_ticks_usec()
		for k in odtw.liczba_kanalow(): odtw.odtworz(k, q2, 0.0)
		var tz2 := Time.get_ticks_usec()
		var tk := Time.get_ticks_usec()
		odtw.krok(0.016)
		var tk2 := Time.get_ticks_usec()
		wyniki.append({"instancje": liczba, "tryb": tryb, "tworzenie_ms": snappedf((tb - ta) / 1000.0, 0.01),
			"zmiana_animacji_wszystkich_ms": snappedf((tz2 - tzm) / 1000.0, 0.01),
			"aktualizacja_zegara_na_klatke_ms": snappedf((tk2 - tk) / 1000.0, 0.003),
			"sredni_czas_klatki_ms": snappedf(suma / czasy.size(), 0.01), "p95_ms": snappedf(czasy[int(czasy.size() * 0.95)], 0.01),
			"fps": snappedf(1000.0 * czasy.size() / suma, 0.1),
			"wywolania_rysowania": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"prymitywy": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"pamiec_statyczna_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
			"pamiec_wideo_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1)})
		Dziennik.info("diag_animacji", "Pomiar: %s" % JSON.stringify(wyniki[-1]))
		if tryb == "vat" and liczba == int(Array(_arg("pomiar", "100").split(",")).back()) and _arg("zrzut", "") != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_arg("zrzut", ""))
		mmi.queue_free(); odtw.queue_free()
		await get_tree().process_frame
	var out := {"model": model, "wierzcholki": anim.wierzcholki, "klatki": anim.klatki, "sekwencja": q,
		"odczyt_ssa_i_dcl_modelu_ms": snappedf((tm - tz) / 1000.0, 0.1), "rozmiar_modelu_b": (surowe.dane as PackedByteArray).size(),
		"odczyt_ssa_i_dcl_tekstury_ms": snappedf((t0 - tm) / 1000.0, 0.1),
		"rozmiar_tekstury_b": (tex_r.get("dane", PackedByteArray()) as PackedByteArray).size(),
		"odczyt_tekstury_ponowny_ms": snappedf((t_tex1 - t_tex0) / 1000.0, 0.1),
		"parsowanie_cem_ms": snappedf((t1 - t0) / 1000.0, 0.1), "wypiekanie_vat_ms": snappedf((t2 - t1) / 1000.0, 0.1),
		"tekstura_vat": [anim.szer, anim.obraz.get_height()], "renderer": RenderingServer.get_video_adapter_name(),
		"sterownik": RenderingServer.get_current_rendering_driver_name(), "wyniki": wyniki}
	var p := _arg("pomiar-plik", Konfiguracja.katalog_openee.path_join("wyniki/pomiar_animacji.json"))
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(out, "  "))
	Dziennik.info("diag_animacji", "Pomiar zapisany: %s" % p)
	get_tree().quit(0)
