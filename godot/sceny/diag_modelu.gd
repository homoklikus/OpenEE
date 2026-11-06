extends Node3D
## Diagnostyka pojedynczego modelu CEM (OpenEE 0.5.1-dev) – narzędzie do szukania przyczyn artefaktów graficznych.
## Model i tekstura wyłącznie z instalacji EE (tylko odczyt). Animacja wyłączona – pokazywana jest wybrana klatka CEM.
## Argumenty (po "--"):
##   --model=<nazwa dbgraphics | models/plik>   --tekstura=<textures/plik.sst> (domyślnie z dbgraphics)
##   --tryb=tekstura|materialy|uv|indeksy|normalne|alfa|wspolplaszczyznowe   --klatka=<n>
##   --czesci=<lista indeksów, np. 0,2>   --materialy=<lista indeksów powierzchni (część/materiał), np. 0,1>
##   (domyślne wartości = reguły produkcyjne 0.5.1: odrzucanie tylnych ścian, wycinanie alfa we wszystkich materiałach,
##   kolor pod alfa=0 uzupełniany przed mipmapami)
##   --cull=tyl|nie|przod   --glebia=tak|nie   --alfa=wycinanie|brak|mieszanie   --prog-alfa=0.5
##   --mipmapy=tak|nie   --alfa-mip0=tak|nie (test alfa z poziomu 0)   --krawedzie-alfa=tak|nie (kolor pod alfa=0)
##   --billboard=auto|tak|nie   --azymut=<stopnie obrotu billboardu>   --produkcja (siatka i materiały dokładnie jak w scenach – ImporterModeli)
##   --kamera=yaw,pitch,odl[,x,y,z]   --kamera-ee=<poziom 0–20> (kamera oryginału: ModelKameryEE)   --podloze=nie|<wysokość>   --kolor-gracza=#rrggbb
##   --lustro (model w bazie o wyznaczniku -1, jak obiekty scenariusza – test odrzucania ścian)
##   --zbadaj=<id trójkątów, np. 12,40>   --zrzut=<plik.png>   --bez-ui
## Raport: wyniki/diag_modelu/<model>.json (części, materiały, obrazy SST, transformacje, nawinięcie, pary
## współpłaszczyznowe i duplikaty z pełnym opisem, renderer). Kliknięcie LPM na trójkąt – jego pełny opis.
## Porównanie rendererów: narzedzia/porownaj_renderery.sh (ta sama scena i kamera: OpenGL / Vulkan / programowy).

const KOLORY := [Color(0.95, 0.3, 0.25), Color(0.25, 0.6, 1.0), Color(0.3, 0.9, 0.35), Color(0.95, 0.85, 0.2),
	Color(0.85, 0.35, 0.95), Color(0.2, 0.9, 0.9), Color(1.0, 0.6, 0.2), Color(0.6, 0.6, 0.6)]
const TRYBY := ["tekstura", "materialy", "uv", "indeksy", "normalne", "alfa", "wspolplaszczyznowe"]

var model: ModelCEM
var rekord: Dictionary = {}
var obj_billboard := false
var klucz_modelu := ""
var tex_db := ""
var obrazy: Array = []
var tr: Array = []                 # DiagnostykaModelu.trojkaty
var wsp: Dictionary = {}
var flagi := {}                    # id trójkąta → Color (tryb współpłaszczyznowe)
var powierzchnie: Array = []       # [{mi, czesc, material, nazwa, obraz, nr_obrazu, tri_od, tri_do}]
var cfg := {"tryb": "tekstura", "klatka": 0, "cull": "tyl", "glebia": true, "alfa": "wycinanie", "prog": 0.5,
	"mipmapy": true, "alfa_mip0": false, "krawedzie": true, "billboard": "auto", "produkcja": false}
var raport := {}
var _kam: Camera3D
var _yaw := 35.0
var _pitch := -30.0
var _dist := 3.0
var _cel := Vector3(0, 0.3, 0)
var _info: Label
var _wybrany: Label
var _kolor_gracza := Color(0.1, 0.3, 0.95)
var _cache_shader := {}
var _korzen: Node3D


func _arg(nazwa: String, dom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nazwa):
			return a.split("=", true, 1)[1]
	return dom


func _ma(flag: String) -> bool:
	return ("--" + flag) in OS.get_cmdline_user_args()


func _ready() -> void:
	_swiat()
	if not Zasoby.gotowe:
		_tekst("Brak instalacji Empire Earth – wskaż ją w launcherze.")
		return
	cfg.tryb = _arg("tryb", "tekstura")
	cfg.klatka = int(_arg("klatka", "0"))
	cfg.cull = _arg("cull", "tyl")
	cfg.glebia = _arg("glebia", "tak") != "nie"
	cfg.alfa = _arg("alfa", "wycinanie")
	cfg.prog = float(_arg("prog-alfa", "0.5"))
	cfg.mipmapy = _arg("mipmapy", "tak") != "nie"
	cfg.alfa_mip0 = _arg("alfa-mip0", "nie") == "tak"
	cfg.krawedzie = _arg("krawedzie-alfa", "tak") != "nie"
	cfg.billboard = _arg("billboard", "auto")
	cfg.produkcja = _ma("produkcja")
	if _arg("kolor-gracza", "") != "": _kolor_gracza = Color(_arg("kolor-gracza", ""))
	if not _wczytaj(_arg("model", "Stable - Copper")):
		_tekst("Nie znaleziono modelu '%s'" % _arg("model", "")); return
	_analiza()
	_zbuduj()
	_kamera_z_arg()
	if _ma("lustro"): _korzen.scale = Vector3(1, 1, -1)   # baza z wyznacznikiem -1 jak obiekty sceny (UkladEE)
	_zapisz_raport()
	if not _ma("bez-ui"): _interfejs()
	if _arg("zrzut", "") != "":
		await _zrzut(_arg("zrzut", ""))


func _swiat() -> void:
	var sw := DirectionalLight3D.new(); sw.rotation_degrees = Vector3(-50, -35, 0); add_child(sw)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9); env.ambient_light_energy = 0.6
	we.environment = env; add_child(we)
	_kam = Camera3D.new(); _kam.fov = 40; _kam.near = 0.02; _kam.far = 200.0; add_child(_kam); _kam.current = true
	_korzen = Node3D.new(); _korzen.name = "Model"; add_child(_korzen)


## Rekord dbgraphics po nazwie lub ścieżce; flaga billboardu z dbobjects (pierwszy obiekt z tą grafiką).
func _wczytaj(n: String) -> bool:
	var s := n.strip_edges().to_lower().replace("\\", "/")
	for r in Zasoby.tabela("dbgraphics"):
		if String(r.get("Name", "")).to_lower() == s or String(r.get("Model path", "")).to_lower().replace("\\", "/") == s.trim_suffix(".cem"):
			rekord = r; break
	if rekord.is_empty() and s.begins_with("models/"):
		rekord = {"Name": s, "Model path": s.trim_suffix(".cem"), "Texture path": ""}
	if rekord.is_empty(): return false
	klucz_modelu = String(rekord["Model path"]).to_lower().replace("\\", "/") + ".cem"
	tex_db = _arg("tekstura", String(rekord.get("Texture path", "")).to_lower().replace("\\", "/"))
	for o in Zasoby.tabela("dbobjects"):
		if int(o.get("Graphic ID", -2)) == int(rekord.get("ID", -1)):
			obj_billboard = int(o.get("Always face camera", 0)) != 0; break
	model = Zasoby.wczytaj_model_cem(klucz_modelu)
	if model == null or model.blad != "": return false
	if tex_db != "": obrazy = Zasoby.wczytaj_tekstury(tex_db)
	return true


func _billboard() -> bool:
	return obj_billboard if cfg.billboard == "auto" else cfg.billboard == "tak"


func _obraz(mt: Dictionary) -> Array:
	var img: Image = ImporterModeli.obraz_materialu(Zasoby, tex_db, mt, klucz_modelu)
	var nr := -1
	if img != null:
		nr = mini(int(mt.get("tekstura_id", 0)), maxi(obrazy.size() - 1, 0)) if not obrazy.is_empty() else -1
	return [img, nr]


func _analiza() -> void:
	tr = DiagnostykaModelu.trojkaty(model, cfg.klatka)
	wsp = DiagnostykaModelu.wspolplaszczyznowe(tr)
	for p in wsp.pary:
		var kol := Color(1, 0.1, 0.1) if p[2] == "przeciwne" else Color(1, 0.9, 0.1)
		flagi[p[0]] = kol; flagi[p[1]] = kol
	for p in wsp.duplikaty:
		flagi[p[0]] = Color(1, 0.2, 1); flagi[p[1]] = Color(1, 0.2, 1)


func _shader(tryb: String) -> Shader:
	var k := "%s|%s|%s" % [tryb, cfg.glebia, cfg.alfa]
	if _cache_shader.has(k): return _cache_shader[k]
	var rm := ["cull_disabled"]   # odrzucanie w shaderze (jak w produkcji – uwzględnia lustrzaną bazę)
	if not cfg.glebia: rm.append("depth_test_disabled")
	if cfg.alfa == "mieszanie": rm.append_array(["blend_mix", "depth_draw_opaque"])
	if tryb in ["uv", "indeksy", "normalne", "alfa", "wspolplaszczyznowe"]: rm.append("unshaded")
	var kod := """shader_type spatial;
render_mode %s;
uniform sampler2D tekstura : source_color, %s;
uniform vec4 kolor_gracza : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 kolor_mat : source_color = vec4(1.0);
uniform bool gracz = false;
uniform bool jest_tekstura = true;
uniform bool alfa_mip0 = false;
uniform float prog = 0.5;
uniform int alfa_tryb = 1;
uniform bool billboard = false;
uniform float billboard_azymut = 0.0;
varying vec2 v_id;
varying vec3 v_flaga;
varying flat float v_lustro;
uniform int odrzucanie = 1;
vec3 hash3(float x) { return fract(sin(vec3(x * 12.9898, x * 78.233, x * 37.719)) * 43758.5453); }
void vertex() {
	v_id = UV2; v_flaga = COLOR.rgb;
	if (billboard) {
		float sx = length(MODEL_MATRIX[0].xyz);
		vec3 bx = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 bz = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
		float c = cos(billboard_azymut); float s = sin(billboard_azymut);
		vec3 rx = bx * c + bz * s; vec3 rz = -bx * s + bz * c;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rx * sx, 0.0), vec4(0.0, sx, 0.0, 0.0), vec4(rz * sx, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	v_lustro = determinant(mat3(MODELVIEW_MATRIX)) < 0.0 ? 1.0 : 0.0;
}
void fragment() {
	bool przod = FRONT_FACING != (v_lustro > 0.5);
	if ((odrzucanie == 1 && !przod) || (odrzucanie == 2 && przod)) { discard; }
	vec4 t = jest_tekstura ? texture(tekstura, UV) : vec4(1.0);
	float a = (jest_tekstura && alfa_mip0) ? textureLod(tekstura, UV, 0.0).a : t.a;
	vec3 c = gracz ? t.rgb * kolor_gracza.rgb : t.rgb;
	%s
	if (alfa_tryb == 1 && a < prog) { discard; }
	%s
	ALBEDO = c;
	ROUGHNESS = 0.9; SPECULAR = 0.2;
}
""" % [", ".join(rm), "filter_linear_mipmap" if cfg.mipmapy else "filter_linear",
		{"tekstura": "", "materialy": "c = kolor_mat.rgb;",
		"uv": "vec2 f = fract(UV); c = vec3(f, 0.15); if (any(lessThan(fract(UV * 16.0), vec2(0.06)))) { c *= 0.35; }",
		"indeksy": "c = hash3(v_id.x + 1.0) * 0.85 + 0.15;", "normalne": "c = NORMAL * 0.5 + 0.5;",
		"alfa": "c = vec3(a);", "wspolplaszczyznowe": "c = (v_flaga.r + v_flaga.g + v_flaga.b > 0.0) ? v_flaga : vec3(0.45) * (0.5 + 0.5 * c);"}[tryb],
		"ALPHA = a;" if cfg.alfa == "mieszanie" else ""]
	var sh := Shader.new(); sh.code = kod
	_cache_shader[k] = sh
	return sh


func _material(img: Image, gracz: bool, kolor_mat: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(cfg.tryb)
	if img != null:
		var im := img.duplicate()
		if im.is_compressed(): im.decompress()
		if im.get_format() != Image.FORMAT_RGBA8: im.convert(Image.FORMAT_RGBA8)
		if cfg.krawedzie: im.fix_alpha_edges()
		if cfg.mipmapy: im.generate_mipmaps()
		mat.set_shader_parameter("tekstura", ImageTexture.create_from_image(im))
	mat.set_shader_parameter("jest_tekstura", img != null)
	mat.set_shader_parameter("kolor_gracza", _kolor_gracza)
	mat.set_shader_parameter("kolor_mat", kolor_mat)
	mat.set_shader_parameter("gracz", gracz)
	mat.set_shader_parameter("alfa_mip0", cfg.alfa_mip0)
	mat.set_shader_parameter("prog", cfg.prog)
	mat.set_shader_parameter("alfa_tryb", {"brak": 0, "wycinanie": 1, "mieszanie": 2}.get(cfg.alfa, 1))
	mat.set_shader_parameter("billboard", _billboard())
	mat.set_shader_parameter("odrzucanie", {"nie": 0, "tyl": 1, "przod": 2}.get(cfg.cull, 1))
	mat.set_shader_parameter("billboard_azymut", deg_to_rad(float(_arg("azymut", str(ImporterModeli.BILLBOARD_AZYMUT_ST)))))
	return mat


func _lista_int(s: String) -> Array:
	var out: Array = []
	for x in s.split(",", false): out.append(int(x))
	return out


func _zbuduj() -> void:
	for c in _korzen.get_children(): c.queue_free()
	powierzchnie.clear()
	if cfg.produkcja:
		var mesh := Zasoby.wczytaj_model(klucz_modelu, {"tekstura": tex_db, "kolor_gracza": _kolor_gracza, "billboard": _billboard()})
		var mi := MeshInstance3D.new(); mi.mesh = mesh; _korzen.add_child(mi)
		powierzchnie.append({"mi": mi, "nazwa": "produkcja (ImporterModeli)", "czesc": -1, "material": -1})
		return
	var wyb_cz := _lista_int(_arg("czesci", ""))
	var wyb_mat := _lista_int(_arg("materialy", ""))
	var nr_pow := 0
	var t_id := 0
	for i in model.czesci.size():
		var c: Dictionary = model.czesci[i]
		for mi_idx in c.materialy.size():
			var mt: Dictionary = c.materialy[mi_idx]
			var n_tri := (mt.indeksy as PackedInt32Array).size() / 3
			var od := t_id; t_id += n_tri
			var widoczna := (wyb_cz.is_empty() or i in wyb_cz) and (wyb_mat.is_empty() or nr_pow in wyb_mat)
			var o := _obraz(mt)
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var nn := model.normalne_modelu(i, cfg.klatka)
			for t in range(od, od + n_tri):
				var T: Dictionary = tr[t] if t < tr.size() else {}
				if T.is_empty(): continue
				var fl: Color = flagi.get(t, Color(0, 0, 0))
				for j in 3:
					var vi: int = T.ind[j]
					st.set_color(fl); st.set_uv(T.uv[j]); st.set_uv2(Vector2(t, nr_pow)); st.set_normal(nn[vi])
					st.add_vertex(T.P[j])
			var mi := MeshInstance3D.new(); mi.name = "P%d_%s_%s" % [nr_pow, c.nazwa, mt.nazwa]
			if n_tri > 0:
				mi.mesh = st.commit()
				mi.material_override = _material(o[0], String(mt.nazwa) == "player color", KOLORY[nr_pow % KOLORY.size()])
			mi.visible = widoczna
			_korzen.add_child(mi)
			powierzchnie.append({"mi": mi, "czesc": i, "material": mi_idx, "nazwa": "%d: %s / %s" % [nr_pow, c.nazwa, mt.nazwa if mt.nazwa != "" else "(główny)"],
				"obraz": o[0], "nr_obrazu": o[1], "tri_od": od, "tri_do": od + n_tri, "mt": mt})
			nr_pow += 1


func _kamera_z_arg() -> void:
	var bb := AABB(); var pierwszy := true
	for t in tr:
		for p in t.P:
			if pierwszy: bb = AABB(p, Vector3.ZERO); pierwszy = false
			else: bb = bb.expand(p)
	_cel = bb.get_center(); _dist = maxf(1.0, bb.size.length() * 1.6)
	var k := _arg("kamera", "").split(",", false)
	if _arg("kamera-ee", "") != "":
		# kamera jak w oryginale (ModelKameryEE): kierunek patrzenia mapy EE (−1, +1), pochylenie 35°, poziomy kąt
		# widzenia 50,4°, odległość poziomu zoomu 0–20; ognisko 0,4 nad podstawą modelu
		var pz := clampi(int(_arg("kamera-ee", "8")), 0, ModelKameryEE.POZIOMOW - 1)
		_yaw = 135.0; _pitch = -ModelKameryEE.POCHYLENIE_ST; _dist = ModelKameryEE.odleglosc(pz)
		_cel = Vector3(bb.get_center().x, ModelKameryEE.WYSOKOSC_OGNISKA, bb.get_center().z)
		if _ma("lustro"): _cel.z = -_cel.z
		_kam.keep_aspect = Camera3D.KEEP_WIDTH; _kam.fov = ModelKameryEE.FOV_POZIOMY_ST; _kam.near = 0.05
	if k.size() >= 3:
		_yaw = float(k[0]); _pitch = float(k[1]); _dist = float(k[2])
	if k.size() >= 6:
		_cel = Vector3(float(k[3]), float(k[4]), float(k[5]))
	var pod := _arg("podloze", "nie")
	if pod != "nie":
		var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); mi.mesh = pm
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.4, 0.42, 0.36); mi.material_override = m
		mi.position.y = float(pod); add_child(mi)
	_aktualizuj_kamere()


func _aktualizuj_kamere() -> void:
	var b := Basis(Vector3.UP, deg_to_rad(_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(_pitch))
	_kam.global_transform = Transform3D(b, _cel + b * Vector3(0, 0, _dist))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_yaw -= e.relative.x * 0.4; _pitch = clampf(_pitch - e.relative.y * 0.4, -89, 89); _aktualizuj_kamere()
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_cel += (_kam.global_basis.x * -e.relative.x + _kam.global_basis.y * e.relative.y) * _dist * 0.002; _aktualizuj_kamere()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _dist = maxf(0.1, _dist * 0.9); _aktualizuj_kamere()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _dist *= 1.1; _aktualizuj_kamere()
		elif e.button_index == MOUSE_BUTTON_LEFT: _wybierz_trojkat(e.position)


## Trójkąt pod kursorem (najbliższy przecięty promieniem, tylko widoczne powierzchnie; billboard pomijany).
func _wybierz_trojkat(pos: Vector2) -> void:
	var o := _kam.project_ray_origin(pos); var d := _kam.project_ray_normal(pos)
	var best := -1; var best_t := INF
	for p in powierzchnie:
		if not p.mi.visible or int(p.czesc) < 0: continue
		for t in range(p.tri_od, p.tri_do):
			var T: Dictionary = tr[t]
			var hit = Geometry3D.ray_intersects_triangle(o, d, T.P[0], T.P[1], T.P[2])
			if hit != null and o.distance_to(hit) < best_t:
				best_t = o.distance_to(hit); best = t
	if best < 0: return
	var T: Dictionary = tr[best]
	var pw: Dictionary = {}
	for p in powierzchnie:
		if int(p.czesc) == T.czesc and int(p.material) == T.material: pw = p
	var op := DiagnostykaModelu.opis(model, T, pw.get("obraz"), int(pw.get("nr_obrazu", -1)), cfg.klatka)
	if _wybrany: _wybrany.text = JSON.stringify(op, " ").left(1600)
	Dziennik.info("diag_modelu", "Trójkąt: %s" % JSON.stringify(op))


func _zapisz_raport() -> void:
	var cz: Array = []
	for i in model.czesci.size():
		var c: Dictionary = model.czesci[i]
		cz.append({"i": i, "nazwa": c.nazwa, "rodzic": c.rodzic, "klatki": c.klatki, "wierzcholki": (c.uv as PackedVector2Array).size(),
			"lokalna_k": str(model.lokalna(i, cfg.klatka)), "globalna_k": str(model.globalna(i, cfg.klatka))})
	var pw: Array = []
	for p in powierzchnie:
		if int(p.czesc) < 0: continue
		var mt: Dictionary = p.mt
		var al := {"0": 0, "1-254": 0, "255": 0}
		for t in range(p.tri_od, p.tri_do):
			var a := DiagnostykaModelu.alfa_w_srodku(p.obraz, tr[t])
			if a == 0: al["0"] += 1
			elif a == 255: al["255"] += 1
			elif a > 0: al["1-254"] += 1
		pw.append({"nazwa": p.nazwa, "tekstura_id": mt.get("tekstura_id", 0), "obraz_sst": p.nr_obrazu,
			"v_offset": mt.get("v_offset", 0), "v_liczba": mt.get("v_liczba", 0), "trojkaty": p.tri_do - p.tri_od,
			"alfa_w_srodkach_trojkatow": al, "obraz_rozmiar": [p.obraz.get_width(), p.obraz.get_height()] if p.obraz else null})
	var przyk: Array = []
	for p in wsp.pary.slice(0, 24):
		przyk.append({"zwrot": p[2], "a": _opis_id(p[0]), "b": _opis_id(p[1])})
	var dup: Array = []
	for p in wsp.duplikaty.slice(0, 12): dup.append({"a": _opis_id(p[0]), "b": _opis_id(p[1])})
	var zb: Array = []
	for i in _lista_int(_arg("zbadaj", "")):
		if i >= 0 and i < tr.size(): zb.append(_opis_id(i))
	raport = {"model": klucz_modelu, "grafika": String(rekord.get("Name", "")), "tekstura": tex_db, "obrazy_sst": obrazy.size(),
		"billboard_dbobjects": obj_billboard, "konfiguracja": cfg, "renderer": _renderer(), "czesci": cz, "powierzchnie": pw,
		"trojkaty": tr.size(), "nawiniecie": DiagnostykaModelu.zgodnosc_nawiniecia(tr),
		"wspolplaszczyznowe": {"pary": wsp.pary.size(), "duplikaty": wsp.duplikaty.size(), "podsumowanie": wsp.podsumowanie,
			"przyklady": przyk, "duplikaty_przyklady": dup}, "zbadane": zb, "kamera": [_yaw, _pitch, _dist, _cel.x, _cel.y, _cel.z]}
	var kat := Konfiguracja.katalog_openee.path_join("wyniki/diag_modelu")
	DirAccess.make_dir_recursive_absolute(kat)
	var nazwa := klucz_modelu.get_file().get_basename()
	var f := FileAccess.open(kat.path_join(nazwa + ".json"), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(raport, " ")); f.close()
	Dziennik.info("diag_modelu", "Raport: %s – %d trójkątów, współpłaszczyznowe %d %s, duplikaty %d, nawinięcie %s" % [
		nazwa, tr.size(), wsp.pary.size(), wsp.podsumowanie, wsp.duplikaty.size(), raport.nawiniecie])


func _opis_id(i: int) -> Dictionary:
	var T: Dictionary = tr[i]
	for p in powierzchnie:
		if int(p.czesc) == T.czesc and int(p.material) == T.material:
			return DiagnostykaModelu.opis(model, T, p.obraz, int(p.nr_obrazu), cfg.klatka)
	return DiagnostykaModelu.opis(model, T, null, -1, cfg.klatka)


func _renderer() -> Dictionary:
	return {"metoda": RenderingServer.get_current_rendering_method(), "sterownik": RenderingServer.get_current_rendering_driver_name(),
		"karta": RenderingServer.get_video_adapter_name(), "producent": RenderingServer.get_video_adapter_vendor()}


func _tekst(s: String) -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	var l := Label.new(); l.text = s; l.position = Vector2(12, 12); cl.add_child(l)


func _interfejs() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	var pan := PanelContainer.new(); pan.position = Vector2(8, 8); cl.add_child(pan)
	var v := VBoxContainer.new(); pan.add_child(v)
	_info = Label.new()
	_info.text = "%s (%s)\n%d trójkątów · współpł. %d · dupl. %d · nawinięcie %.2f\n%s" % [raport.grafika, klucz_modelu, tr.size(),
		wsp.pary.size(), wsp.duplikaty.size(), float(raport.nawiniecie.udzial), "%s · %s" % [raport.renderer.metoda, raport.renderer.karta]]
	v.add_child(_info)
	var tryb := OptionButton.new()
	for t in TRYBY: tryb.add_item(t)
	tryb.selected = maxi(TRYBY.find(cfg.tryb), 0)
	tryb.item_selected.connect(func(i): cfg.tryb = TRYBY[i]; _przebuduj())
	v.add_child(tryb)
	var alfa := OptionButton.new()
	for t in ["wycinanie", "brak", "mieszanie"]: alfa.add_item("alfa: " + t)
	alfa.selected = ["wycinanie", "brak", "mieszanie"].find(cfg.alfa)
	alfa.item_selected.connect(func(i): cfg.alfa = ["wycinanie", "brak", "mieszanie"][i]; _przebuduj())
	v.add_child(alfa)
	var cull := OptionButton.new()
	for t in ["nie", "tyl", "przod"]: cull.add_item("odrzucanie ścian: " + t)
	cull.selected = ["nie", "tyl", "przod"].find(cfg.cull)
	cull.item_selected.connect(func(i): cfg.cull = ["nie", "tyl", "przod"][i]; _przebuduj())
	v.add_child(cull)
	for p in [["glebia", "test głębokości"], ["mipmapy", "mipmapy"], ["alfa_mip0", "alfa z poziomu 0"], ["krawedzie", "kolor pod alfa=0 (fix_alpha_edges)"], ["produkcja", "materiały produkcyjne"]]:
		var cb := CheckBox.new(); cb.text = p[1]; cb.button_pressed = bool(cfg[p[0]])
		var klucz: String = p[0]
		cb.toggled.connect(func(on): cfg[klucz] = on; _przebuduj())
		v.add_child(cb)
	var kl := SpinBox.new(); kl.min_value = 0; kl.max_value = maxi(model.klatki - 1, 0); kl.value = cfg.klatka; kl.prefix = "klatka CEM"
	kl.value_changed.connect(func(x): cfg.klatka = int(x); _analiza(); _przebuduj())
	v.add_child(kl)
	var lp := Label.new(); lp.text = "Powierzchnie (część / materiał):"; v.add_child(lp)
	for p in powierzchnie:
		if int(p.czesc) < 0: continue
		var cb := CheckBox.new(); cb.text = p.nazwa; cb.button_pressed = p.mi.visible
		var mi: MeshInstance3D = p.mi
		cb.toggled.connect(func(on): mi.visible = on)
		v.add_child(cb)
	_wybrany = Label.new(); _wybrany.text = "LPM: opis trójkąta · PPM: obrót · kółko: zoom · ŚPM: przesuw"
	_wybrany.custom_minimum_size = Vector2(420, 0); _wybrany.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_wybrany)


func _przebuduj() -> void:
	var widocznosc: Array = []
	for p in powierzchnie: widocznosc.append(p.mi.visible)
	_cache_shader.clear()
	_zbuduj()
	for i in mini(widocznosc.size(), powierzchnie.size()): powierzchnie[i].mi.visible = widocznosc[i]


func _zrzut(sciezka: String) -> void:
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if not sciezka.is_absolute_path(): sciezka = Konfiguracja.katalog_openee.path_join(sciezka)
	DirAccess.make_dir_recursive_absolute(sciezka.get_base_dir())
	var kod := img.save_png(sciezka)
	Dziennik.info("diag_modelu", "Zrzut %s (kod %d)" % [sciezka, kod])
	get_tree().quit()
