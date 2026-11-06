extends Node3D
## Pierwszy test graficzny OpenEE:
##  * wysokości, tereny i flagi – fragment autentycznego scenariusza kampanii AoC
##    (eksport: narzedzia/eksport_testu_graficznego.py → cache/test_graficzny/teren.json),
##  * tekstury terenu i model – wczytywane BEZPOŚREDNIO z archiwów EE przez importery GDScript
##    (Zasoby → ArchiwumSSA → DCL → ImporterTekstur / ImporterModeli), z uwzględnieniem warstw.
## Argumenty (po "--"): --zrzut=<plik.png>  --hd (włącza warstwę nieustalone_nadpisania)

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2DArray tekstury : source_color, filter_linear_mipmap, repeat_enable;
varying flat float warstwa;
void vertex() { warstwa = UV2.x; }
void fragment() {
	ALBEDO = texture(tekstury, vec3(UV, warstwa)).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""

var raport := {}
var _pozycja_modelu := Vector3.ZERO


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--hd" in args:
		var a := Konfiguracja.aktywne_warstwy
		a.append("nieustalone_nadpisania")
		Konfiguracja.aktywne_warstwy = a
		Zasoby.przebuduj_zrodla()
	var t0 := Time.get_ticks_msec()
	var p := Konfiguracja.katalog_cache.path_join("test_graficzny/teren.json")
	var dane = JSON.parse_string(FileAccess.get_file_as_string(p))
	if dane == null:
		Dziennik.blad("test_teren", "Brak danych terenu: %s (uruchom narzedzia/eksport_testu_graficznego.py)" % p)
		return
	_zbuduj_teren(dane)
	_dodaj_model(dane)
	_dodaj_wode(dane)
	_scena(dane)
	raport["czas_ms"] = Time.get_ticks_msec() - t0
	raport["warstwy"] = Array(Konfiguracja.aktywne_warstwy)
	Dziennik.info("test_teren", "Gotowe: %s" % JSON.stringify(raport))
	for a in args:
		if a.begins_with("--zrzut="):
			_zrzut(a.trim_prefix("--zrzut="))


func _zbuduj_teren(d: Dictionary) -> void:
	var n: int = d.okno.n
	var wys: Array = d.wysokosc
	var ter: Array = d.teren
	var sk := Konfiguracja.skala_wysokosci
	# warstwy tekstur: (id terenu, wariant 1..4) -> indeks w Texture2DArray
	var indeks := {}
	var obrazy: Array[Image] = []
	var zrodla := {}
	for tid in d.tekstury.keys():
		var info: Dictionary = d.tekstury[tid]
		if not info.has("baza"):
			continue
		for v in range(1, 5):
			var klucz := "textures/%s_%d.sst" % [info.baza, v]
			var img := Zasoby.wczytaj_teksture(klucz)
			if img == null:
				continue
			img = img.duplicate()
			if img.get_width() != 128:
				img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
			img.generate_mipmaps()
			indeks["%s_%d" % [tid, v]] = obrazy.size()
			obrazy.append(img)
			var zr := Zasoby.znajdz(klucz)
			if zr.is_empty():
				zr = Zasoby.znajdz(klucz.trim_suffix(".sst") + ".tga")
			zrodla[klucz] = "%s (%s)" % [zr.get("warstwa", "?"), String(zr.get("zrodlo", "?")).get_file()]
	raport["tekstury_warstw"] = obrazy.size()
	raport["zrodla_tekstur"] = zrodla
	var arr := Texture2DArray.new()
	arr.create_from_images(obrazy)
	# normalne w punktach (różnice centralne)
	var nor := []
	for r in range(n + 1):
		var wiersz := []
		for c in range(n + 1):
			var hl: float = wys[r][max(c - 1, 0)]; var hr: float = wys[r][min(c + 1, n)]
			var hu: float = wys[max(r - 1, 0)][c]; var hd: float = wys[min(r + 1, n)][c]
			wiersz.append(UkladEE.wektor(Vector3((hl - hr) * sk, (hu - hd) * sk, 2.0)).normalized())   # normalna w świecie EE
		nor.append(wiersz)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brak := 0
	for r in range(n):
		for c in range(n):
			var tid := str(int(ter[r][c]))
			# HIPOTEZA OpenEE: wariant tekstury z parzystości współrzędnych pola
			var v := 1 + (r % 2) * 2 + (c % 2)
			var li: int = indeks.get("%s_%d" % [tid, v], indeks.get("%s_1" % tid, -1))
			if li < 0:
				brak += 1
				li = 0
			var rogi := [[r, c, Vector2(0, 0)], [r, c + 1, Vector2(1, 0)], [r + 1, c + 1, Vector2(1, 1)], [r + 1, c, Vector2(0, 1)]]
			for i in [0, 2, 1, 0, 3, 2]:      # etap 7: kolejność dla świata bez odbicia (UkladEE, cull_back)
				var q: Array = rogi[i]
				st.set_uv(q[2])
				st.set_uv2(Vector2(li, 0))
				st.set_normal(nor[q[0]][q[1]])
				st.add_vertex(UkladEE.godot(Vector2(q[1], q[0]), float(wys[q[0]][q[1]]) * sk))
	raport["pola_bez_tekstury"] = brak
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	var sh := Shader.new(); sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("tekstury", arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = "Teren"
	add_child(mi)


func _dodaj_wode(d: Dictionary) -> void:
	var n: int = d.okno.n
	var img := Zasoby.wczytaj_teksture("textures/water_ocean_1.sst")
	var pm := PlaneMesh.new()
	pm.size = Vector2(n, n)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.72)
	if img:
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.uv1_scale = Vector3(n / 4.0, n / 4.0, 1)
	mat.roughness = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = UkladEE.godot(Vector2(n / 2.0, n / 2.0), -0.03)   # poziom wody = 0 (RAPORT_EEMAP); −0,03 tylko przeciw migotaniu na brzegu
	mi.name = "Woda"
	add_child(mi)


func _dodaj_model(d: Dictionary) -> void:
	var n: int = d.okno.n
	var wys: Array = d.wysokosc
	# najbardziej płaskie suche miejsce 3×3 blisko środka
	var najl := Vector2i(n / 2, n / 2)
	var ocena := INF
	for r in range(4, n - 4):
		for c in range(4, n - 4):
			var mn := INF; var mx := -INF
			for dr in range(-1, 3):
				for dc in range(-1, 3):
					var h: float = wys[r + dr][c + dc]
					mn = min(mn, h); mx = max(mx, h)
			if mn <= 0.05:
				continue
			var s := (mx - mn) * 10.0 + Vector2(r - n / 2, c - n / 2).length() * 0.05
			if s < ocena:
				ocena = s; najl = Vector2i(r, c)
	var mesh := Zasoby.wczytaj_model("models/bld_barracks_05.cem")
	if mesh == null:
		raport["model"] = "BRAK"
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Model_bld_barracks_05"
	mi.scale = Vector3.ONE * 3.0   # HIPOTEZA skali: model znormalizowany ~1 j., budynek ~3 pola
	mi.position = UkladEE.godot(Vector2(najl.y + 0.5, najl.x + 0.5), float(wys[najl.x][najl.y]) * Konfiguracja.skala_wysokosci)
	add_child(mi)
	raport["model"] = {"pozycja_pola": [najl.x, najl.y], "powierzchnie": mesh.get_surface_count()}
	_pozycja_modelu = mi.position


func _scena(d: Dictionary) -> void:
	var n: int = d.okno.n
	var sw := DirectionalLight3D.new()
	sw.basis = Basis.looking_at(UkladEE.wektor(Vector3(0.3687, -0.5265, -0.766)), Vector3.UP)   # kierunek w świecie EE
	sw.light_energy = 1.1
	add_child(sw)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)
	var kam := Camera3D.new()
	kam.fov = 45
	var srodek := UkladEE.godot(Vector2(n / 2.0, n / 2.0), 0.0)
	kam.position = srodek + UkladEE.wektor(Vector3(-n * 0.55, n * 0.55, n * 0.75))
	add_child(kam)
	kam.look_at(srodek, Vector3.UP)
	if "--kamera=model" in OS.get_cmdline_user_args() and _pozycja_modelu != Vector3.ZERO:
		kam.position = _pozycja_modelu + UkladEE.wektor(Vector3(-3.2, 3.2, 3.0))
		kam.look_at(_pozycja_modelu + Vector3(0, 0.6, 0), Vector3.UP)
	kam.current = true
	var cl := CanvasLayer.new()
	var lab := Label.new()
	lab.position = Vector2(12, 8)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 4)
	lab.text = "OpenEE – test graficzny etapu 1\nTeren: kampania AoC (fragment %d×%d pól, r0=%d c0=%d)\nWarstwy: %s" % [
		n, n, d.okno.r0, d.okno.c0, ", ".join(Konfiguracja.aktywne_warstwy)]
	cl.add_child(lab)
	add_child(cl)


func _zrzut(sciezka: String) -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var e := img.save_png(sciezka)
	Dziennik.info("test_teren", "Zrzut %s (kod %d)" % [sciezka, e])
	var rp := sciezka.get_basename() + ".json"
	var f := FileAccess.open(rp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(raport, "  "))
	get_tree().quit(0 if e == OK else 1)
