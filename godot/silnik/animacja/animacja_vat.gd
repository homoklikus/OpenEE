class_name AnimacjaVAT
extends RefCounted
## Animacja klatkowa CEM w teksturze wierzchołków (VAT) – etap 4.
##
## Dlaczego tak: CEM przechowuje pełną geometrię w każdej klatce (bez kości), a części potomne mają własną macierz
## na klatkę. Wypiekamy więc wszystkie części – już przekształcone przez hierarchię (ModelCEM.globalna) – do jednej
## tekstury float: wiersz = (klatka, atrybut), kolumna = wierzchołek. Siatka jest jedna dla wszystkich klatek;
## shader pobiera pozycję/normalną dwóch klatek i interpoluje. Stan instancji (sekwencja, faza, tempo) to 4 liczby
## (INSTANCE_CUSTOM w MultiMesh lub `instance uniform` w MeshInstance3D), a czas jest globalny (czas_animacji) –
## aktualizacja tysięcy jednostek nie wymaga pracy CPU na klatkę ani przebudowy siatek.
##
## Stan (Vector4): x = pierwsza klatka sekwencji, y = liczba klatek (ujemna → jednorazowa, zatrzymuje się na
## ostatniej), z = faza w chwili czas_animacji = 0 (w klatkach), w = tempo (klatki/s; 0 = zatrzymana).
## Interpolacja liniowa między klatkami kluczowymi jest HIPOTEZĄ OpenEE [H] (format zapisuje tylko klatki
## kluczowe; czy EE interpoluje – do potwierdzenia); można ją wyłączyć (`interpolacja = false`).

const SZER_MAX := 2048

const SHADER := """
shader_type spatial;
render_mode cull_disabled;   // tylne ściany odrzucane w shaderze z uwzględnieniem lustrzanej bazy (diagnostyka 0.5.1)
uniform sampler2D tekstura : source_color, filter_linear_mipmap;
uniform vec4 kolor_gracza : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool kolor_gracza_mnoz = true;
uniform bool wycinanie_alfa = false;
uniform highp sampler2D vat : filter_nearest;
uniform int vat_szer = 1;
uniform int vat_wiersze = 1;
uniform bool interpolacja = true;
uniform bool z_multimesh = false;
global uniform float czas_animacji;
instance uniform vec4 anim_stan = vec4(0.0, 1.0, 0.0, 0.0);
varying vec3 v_kolor;
varying flat float v_lustro;
uniform float przesuniecie_glebi = 0.003;
uniform bool odrzucaj_tyl = true;

vec3 klatki(vec4 st) {
	float n = max(abs(st.y), 1.0);
	float f = st.z + czas_animacji * st.w;
	float fa; float fb;
	if (st.y >= 0.0) {
		f = mod(f, n); fa = floor(f); fb = mod(fa + 1.0, n);
	} else {
		f = clamp(f, 0.0, n - 1.0); fa = floor(f); fb = min(fa + 1.0, n - 1.0);
	}
	return vec3(st.x + fa, st.x + fb, f - fa);
}

void vertex() {
	vec4 st = z_multimesh ? INSTANCE_CUSTOM : anim_stan;
	vec3 k = klatki(st);
	float u = interpolacja ? k.z : 0.0;
	int idx = int(UV2.x + 0.5);
	ivec2 c = ivec2(idx % vat_szer, idx / vat_szer);
	int ra = int(k.x) * 2 * vat_wiersze;
	int rb = int(k.y) * 2 * vat_wiersze;
	vec3 pa = texelFetch(vat, c + ivec2(0, ra), 0).xyz;
	vec3 pb = texelFetch(vat, c + ivec2(0, rb), 0).xyz;
	vec3 na = texelFetch(vat, c + ivec2(0, ra + vat_wiersze), 0).xyz;
	vec3 nb = texelFetch(vat, c + ivec2(0, rb + vat_wiersze), 0).xyz;
	VERTEX = mix(pa, pb, u);
	NORMAL = normalize(mix(na, nb, u));
	v_kolor = z_multimesh ? COLOR.rgb : kolor_gracza.rgb;
	v_lustro = determinant(mat3(MODELVIEW_MATRIX)) < 0.0 ? 1.0 : 0.0;
	// przesunięcie głębi ku kamerze wzdłuż promienia (obraz na ekranie bez zmian): płyty podstaw budynków leżą
	// ~0,01 nad terenem, a siatka terenu (trójkąty) odbiega od interpolacji wysokości obiektu – bez tego teren
	// przebijał podstawy zależnie od precyzji bufora głębokości (Vulkan/OpenGL, diagnostyka 0.5.1)
	vec4 pw = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	pw.xyz *= 1.0 - przesuniecie_glebi;
	POSITION = PROJECTION_MATRIX * pw;
}

void fragment() {
	if (odrzucaj_tyl && (FRONT_FACING == (v_lustro > 0.5))) { discard; }
	vec4 t = texture(tekstura, UV);
	if (wycinanie_alfa && t.a < 0.5) { discard; }
	ALBEDO = kolor_gracza_mnoz ? t.rgb * v_kolor : t.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
"""
static var _shader: Shader = null

var siatka: ArrayMesh
var obraz: Image
var tekstura_vat: ImageTexture
var szer: int = 1
var wiersze: int = 1          # wierszy tekstury na (klatkę, atrybut)
var klatki: int = 1
var wierzcholki: int = 0
var materialy: Array = []     # ShaderMaterial na powierzchnię (dla podmiany koloru/tekstury)
var model: ModelCEM


## Klatki (a, b, udział) dla stanu i czasu – ta sama formuła co w shaderze (testy i scena diagnostyczna).
static func klatki_dla(st: Vector4, czas: float) -> Vector3:
	var n: float = maxf(absf(st.y), 1.0)
	var f: float = st.z + czas * st.w
	var fa: float; var fb: float
	if st.y >= 0.0:
		f = fposmod(f, n); fa = floorf(f); fb = fposmod(fa + 1.0, n)
	else:
		f = clampf(f, 0.0, n - 1.0); fa = floorf(f); fb = minf(fa + 1.0, n - 1.0)
	return Vector3(st.x + fa, st.x + fb, f - fa)


static func shader() -> Shader:
	if _shader == null:      # zmienna globalna czas_animacji – zadeklarowana w project.godot [shader_globals]
		_shader = Shader.new(); _shader.code = SHADER
	return _shader


## Wypieka model. kontekst: {zasoby, tekstura (dbgraphics), kolor_gracza, klucz}. Zwraca null przy błędzie modelu.
static func wypiecz(m: ModelCEM, kontekst: Dictionary = {}) -> AnimacjaVAT:
	if m == null or m.blad != "" or m.czesci.is_empty():
		return null
	var a := AnimacjaVAT.new()
	a.model = m
	a.klatki = maxi(m.klatki, 1)
	var offs: Array = []
	var n := 0
	for c in m.czesci:
		offs.append(n); n += (c.uv as PackedVector2Array).size()
	a.wierzcholki = n
	a.szer = clampi(n, 1, SZER_MAX)
	a.wiersze = maxi(1, ceili(float(n) / a.szer))
	var h := a.klatki * 2 * a.wiersze
	var dane := PackedFloat32Array(); dane.resize(a.szer * h * 4)
	var aabb := AABB(); var pierwszy := true
	for f in a.klatki:
		for i in m.czesci.size():
			var pp := m.pozycje_modelu(i, f); var nn := m.normalne_modelu(i, f)
			for j in pp.size():
				var idx: int = offs[i] + j
				var x := idx % a.szer; var y := idx / a.szer
				var o := ((f * 2 * a.wiersze + y) * a.szer + x) * 4
				dane[o] = pp[j].x; dane[o + 1] = pp[j].y; dane[o + 2] = pp[j].z; dane[o + 3] = 1.0
				var o2 := (((f * 2 + 1) * a.wiersze + y) * a.szer + x) * 4
				dane[o2] = nn[j].x; dane[o2 + 1] = nn[j].y; dane[o2 + 2] = nn[j].z; dane[o2 + 3] = 0.0
				if pierwszy:
					aabb = AABB(pp[j], Vector3.ZERO); pierwszy = false
				else:
					aabb = aabb.expand(pp[j])
	a.obraz = Image.create_from_data(a.szer, h, false, Image.FORMAT_RGBAF, dane.to_byte_array())
	a.tekstura_vat = ImageTexture.create_from_image(a.obraz)
	a._siatka(m, offs, kontekst)
	a.siatka.custom_aabb = aabb.grow(0.05)
	return a


func _siatka(m: ModelCEM, offs: Array, kontekst: Dictionary) -> void:
	siatka = ArrayMesh.new()
	var zasoby = kontekst.get("zasoby")
	var tex_db: String = kontekst.get("tekstura", "")
	var kolor: Color = kontekst.get("kolor_gracza", Color(0.8, 0.1, 0.1))
	var cache_img := {}
	for i in m.czesci.size():
		var c: Dictionary = m.czesci[i]
		var pp := m.pozycje_modelu(i, 0); var nn := m.normalne_modelu(i, 0)
		var uv2 := PackedVector2Array(); uv2.resize(pp.size())
		for j in pp.size(): uv2[j] = Vector2(float(offs[i] + j), 0.0)
		for mt in c.materialy:
			if (mt.indeksy as PackedInt32Array).is_empty():
				continue
			if tex_db == "" and String(mt.tekstura) == "":
				continue           # powierzchnia pomocnicza bez tekstury (jak ImporterModeli)
			var arr := []; arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = pp; arr[Mesh.ARRAY_NORMAL] = nn
			arr[Mesh.ARRAY_TEX_UV] = c.uv; arr[Mesh.ARRAY_TEX_UV2] = uv2
			arr[Mesh.ARRAY_INDEX] = mt.indeksy
			siatka.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			# obraz tekstury: plik z dbgraphics, obraz nr `tekstura_id` materiału (naprawa grafiki)
			var kt := "%s|%d|%s" % [tex_db, int(mt.get("tekstura_id", 0)), String(mt.tekstura)]
			if not cache_img.has(kt):
				cache_img[kt] = ImporterModeli.obraz_materialu(zasoby, tex_db, mt, String(kontekst.get("klucz", "?")))
			var img: Image = cache_img[kt]
			var mat := material(img, kolor, String(mt.nazwa) == "player color")
			siatka.surface_set_material(siatka.get_surface_count() - 1, mat)
			siatka.surface_set_name(siatka.get_surface_count() - 1, "%s/%s" % [c.nazwa, mt.nazwa])
			materialy.append(mat)


func material(img: Image, kolor: Color, gracz: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	if img:
		mat.set_shader_parameter("tekstura", ImporterModeli.tekstura_gpu(img))
	mat.set_shader_parameter("kolor_gracza", kolor)
	mat.set_shader_parameter("kolor_gracza_mnoz", gracz)
	mat.set_shader_parameter("wycinanie_alfa", ImporterModeli.wymaga_wycinania(img))   # także „player color” (0.5.1)
	mat.set_shader_parameter("vat", tekstura_vat)
	mat.set_shader_parameter("vat_szer", szer)
	mat.set_shader_parameter("vat_wiersze", wiersze)
	return mat


## Wersja siatki do MultiMesh: kopie materiałów z z_multimesh = true (kolor gracza z koloru instancji).
func siatka_multimesh() -> ArrayMesh:
	var s: ArrayMesh = siatka.duplicate()
	for i in s.get_surface_count():
		var m: ShaderMaterial = (siatka.surface_get_material(i) as ShaderMaterial).duplicate()
		m.set_shader_parameter("z_multimesh", true)
		s.surface_set_material(i, m)
	s.custom_aabb = siatka.custom_aabb
	return s


func ustaw_interpolacje(wl: bool) -> void:
	for m in materialy: (m as ShaderMaterial).set_shader_parameter("interpolacja", wl)


## Pozycja wierzchołka (indeks globalny) dla stanu i czasu – odczyt z tekstury VAT na CPU (testy zgodności z
## shaderem i z ModelCEM).
func pozycja_cpu(idx: int, st: Vector4, czas: float, interp: bool = true) -> Vector3:
	var k := klatki_dla(st, czas)
	var u := k.z if interp else 0.0
	var x := idx % szer; var y := idx / szer
	var ca := obraz.get_pixel(x, int(k.x) * 2 * wiersze + y)
	var cb := obraz.get_pixel(x, int(k.y) * 2 * wiersze + y)
	return Vector3(ca.r, ca.g, ca.b).lerp(Vector3(cb.r, cb.g, cb.b), u)
