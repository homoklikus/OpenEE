class_name ImporterModeli
extends ImporterEE
## Modele CEM → ArrayMesh (LOD 0, klatka 0). Obsługa wersji 2.0 i 1.3 (docs/FORMATY*.md §CEM).
## Układ współrzędnych CEM: Z w górę → Godot: (x, z, -y).
## Tekstura: plik z dbgraphics (kontekst "tekstura"), obraz w pliku = `tekstura_id` materiału [D]; gdy brak pliku
## w dbgraphics – nazwa z materiału modelu (zwykle nazwy plików źródłowych grafika, niewystępujące w archiwach).
## Kolor gracza (naprawa grafiki, docs/FORMATY_NAPRAWA_GRAFIKI.md): fragmenty tekstur pod materiałem „player color” są
## szare [D: mediana nasycenia 0] ⇒ ALBEDO = tekstura · kolor gracza [H: dokładna formuła/jasność].
## Diagnostyka 0.5.1 (docs/FORMATY_DIAGNOSTYKA_051.md): kanał alfa jest przezroczystością (wycinaniem) we WSZYSTKICH
## materiałach, także „player color” – nakładki koloru gracza (emblematy, kraty, ramy) mają kształt w alfie, a ukryte
## bryły pomocnicze mają UV na tekselach z alfa 0 [D]. Odrzucanie tylnych ścian: nawinięcie po imporcie jest spójne
## (98,6% trójkątów), a ściany dwustronne są w danych zbudowane z dwóch przeciwnie skierowanych trójkątów [D] –
## rysowane bez odrzucania walczyły ze sobą w buforze głębokości (pasy). Odrzucanie robi shader (FRONT_FACING z
## uwzględnieniem wyznacznika macierzy modelu), bo baza obiektów sceny jest lustrzana (UkladEE, wyznacznik -1), a
## render_mode cull_back tego nie kompensował (budynki znikały – sprawdzone w OpenGL i Vulkanie). Billboard: impostory patrzą w stały kierunek
## kamery EE (azymut -45° w układzie CEM, 91 ze 195 modeli „Always face camera”) [D] – obracamy ten kierunek do kamery.

const SHADER_MODELU := """
shader_type spatial;
render_mode cull_disabled;   // odrzucanie tylnych ścian ręcznie (niżej) – zgodne z lustrzaną bazą obiektów
uniform sampler2D tekstura : source_color, filter_linear_mipmap;
uniform vec4 kolor_gracza : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool kolor_gracza_mnoz = true; // materiał "player color": tekstura (szara) · kolor gracza
uniform bool wycinanie_alfa = false; // alfa = przezroczystość (wszystkie materiały z teksturą 32-bit)
uniform bool billboard = false;      // dbobjects „Always face camera” – obrót wokół osi pionowej do kamery
uniform float billboard_azymut = 0.0; // obrót impostora: kierunek projektowy (kamera EE) → kamera
uniform bool odrzucaj_tyl = true;     // odrzucanie tylnych ścian (diagnostyka 0.5.1)
varying flat float v_lustro;
uniform float przesuniecie_glebi = 0.003;
void vertex() {
	if (billboard) {
		float sx = length(MODEL_MATRIX[0].xyz);
		vec3 bx = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 bz = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
		float c = cos(billboard_azymut); float s = sin(billboard_azymut);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4((bx * c + bz * s) * sx, 0.0), vec4(0.0, sx, 0.0, 0.0),
			vec4((bz * c - bx * s) * sx, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	// baza obiektów sceny ma wyznacznik -1 (konwencja osi EE → Godot, UkladEE) – odbicie odwraca nawinięcie ekranowe
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
	ALBEDO = kolor_gracza_mnoz ? t.rgb * kolor_gracza.rgb : t.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
"""
## Obrót billboardu wokół pionu (stopnie): impostory „Always face camera” są zwrócone w kierunku azymutu -45° układu CEM
## (od +X ku -Y; w Godot (x, -y) = (+X, +Z) pod 45°) [D: dominanta 91/195 modeli, narzedzia/kierunek_billboardow.py] –
## ten kierunek, nie oś +Z modelu, obracamy do kamery. 0° (stan do 0.5.1) pokazywał impostor pod kątem, jako płaski pas.
const BILLBOARD_AZYMUT_ST := 45.0
static var _shader: Shader = null


func nazwa() -> String:
	return "modele CEM"


func rozszerzenia() -> PackedStringArray:
	return PackedStringArray(["cem"])


class _Czytnik:
	var d: PackedByteArray
	var p: int = 0
	func _init(dane: PackedByteArray, off: int = 0) -> void:
		d = dane; p = off
	func u32() -> int:
		var v := d.decode_u32(p); p += 4; return v
	func f32() -> float:
		var v := d.decode_float(p); p += 4; return v
	func napis() -> String:
		var n := u32()
		var s := d.slice(p, p + n).get_string_from_ascii()
		p += n
		return s


## Zwraca słownik geometrii modelu głównego: pozycje, normalne, uv, materiały [{nazwa, tekstura, indeksy}],
## wersja, lod, oraz "potomne" (lista takich słowników) – albo {"blad"}.
static func parsuj(dane: PackedByteArray) -> Dictionary:
	var r := _Czytnik.new(dane)
	var m := _model(r)
	if not m.has("blad"):
		m["reszta"] = dane.size() - r.p
	return m


static func _model(r: _Czytnik) -> Dictionary:
	if r.d.slice(r.p, r.p + 4).get_string_from_ascii() != "SSMF":
		return {"blad": "brak sygnatury SSMF"}
	var major := r.d.decode_u16(r.p + 4)
	var minor := r.d.decode_u16(r.p + 6)
	r.p += 8
	if major == 1 and minor == 3:
		return _model13(r)
	if major != 2 or minor != 0:
		return {"blad": "wersja CEM %d.%d nieobsługiwana" % [major, minor]}
	var n_tri := r.u32(); var n_v := r.u32(); var n_tag := r.u32(); var n_mat := r.u32()
	var n_fr := r.u32(); var n_child := r.u32(); var n_lod := r.u32()
	var m := {"wersja": "2.0", "nazwa": r.napis(), "trojkaty": n_tri, "wierzcholki": n_v, "lod": n_lod, "klatki": n_fr}
	r.p += 12
	var lods: Array = []
	for i in range(n_lod):
		var k := r.u32()
		var idx := PackedInt32Array(); idx.resize(3 * k)
		for j in range(3 * k):
			idx[j] = r.u32()
		lods.append(idx)
	var mats: Array = []
	for i in range(n_mat):
		var mt := {"nazwa": r.napis()}
		mt["tekstura_id"] = r.u32()
		var zakresy: Array = []
		for l in range(n_lod):
			zakresy.append(Vector2i(r.u32(), r.u32()))
		var vo := r.u32(); r.u32()
		mt["tekstura"] = r.napis()
		var z: Vector2i = zakresy[0] if n_lod > 0 else Vector2i.ZERO
		var ind := PackedInt32Array()
		for t in range(z.x, z.x + z.y):      # indeksy względne wobec v_offset materiału (jak ModelCEM)
			ind.append(vo + lods[0][3 * t]); ind.append(vo + lods[0][3 * t + 2]); ind.append(vo + lods[0][3 * t + 1])
		mt["indeksy"] = ind
		mats.append(mt)
	for i in range(n_tag):
		r.napis()
	var poz := PackedVector3Array(); var nor := PackedVector3Array(); var uv := PackedVector2Array()
	for f in range(n_fr):
		r.f32()
		for i in range(n_v):
			var x := r.f32(); var y := r.f32(); var z := r.f32()
			var nx := r.f32(); var ny := r.f32(); var nz := r.f32()
			var u := r.f32(); var v := r.f32()
			if f == 0:
				poz.append(Vector3(x, z, -y)); nor.append(Vector3(nx, nz, -ny)); uv.append(Vector2(u, v))
		r.p += 12 * n_tag + 64 + 24
	m["pozycje"] = poz; m["normalne"] = nor; m["uv"] = uv; m["materialy"] = mats
	var pot: Array = []
	for i in range(n_child):
		var c := _model(r)
		if c.has("blad"):
			return c
		pot.append(c)
	m["potomne"] = pot
	return m


## SSMF 1.3: wierzchołki powstają z rogów trójkątów (indeks wierzchołka → punkt + UV), normalne liczone z geometrii.
static func _model13(r: _Czytnik) -> Dictionary:
	var q: Array = []
	for i in range(8):
		q.append(r.u32())
	var n_fr: int = q[0]; var n_mat: int = q[1]; var n_pkt: int = q[2]; var n_tri: int = q[3]
	var n_grp: int = q[4]; var n_v: int = q[5]; var n_tag: int = q[6]; var n_child: int = q[7]
	var m := {"wersja": "1.3", "nazwa": r.napis(), "trojkaty": n_tri, "wierzcholki": n_v, "lod": 1, "klatki": n_fr}
	r.p += 12 + 1 + 4 * n_pkt
	var rogi: Array = []      # [indeks_wierzchołka, Vector2 uv]
	for i in range(3 * n_tri):
		var w := r.u32(); var u := r.f32(); var v := r.f32()
		r.p += 28
		rogi.append([w, Vector2(u, v)])
	var grupy := {}
	for i in range(n_grp):
		var nz := r.napis(); var k := r.u32()
		var l: Array = []
		for j in range(k): l.append(r.u32())
		grupy[nz] = l
	var mats_src: Array = []
	for i in range(n_mat):
		var k := r.u32()
		var l: Array = []
		for j in range(k): l.append(r.u32())
		var tex := ""
		if r.d[r.p] != 0:
			r.p += 1; tex = r.napis(); r.u32()
		else:
			r.p += 1
		mats_src.append({"trojkaty": l, "tekstura": tex})
	var w2p := PackedInt32Array()
	for i in range(n_v):
		w2p.append(r.u32()); r.f32()
	for i in range(n_tag): r.napis()
	var punkty := PackedVector3Array()
	for f in range(n_fr):
		r.f32()
		for i in range(n_pkt):
			var x := r.f32(); var y := r.f32(); var z := r.f32()
			if f == 0: punkty.append(Vector3(x, z, -y))
		r.p += 2 * n_v + 12 * n_tag + 64 + 24
	# rozwinięcie: każdy róg trójkąta = osobny wierzchołek (pozycja punktu, UV rogu)
	var poz := PackedVector3Array(); var uv := PackedVector2Array(); var nor := PackedVector3Array()
	for c in rogi:
		poz.append(punkty[w2p[c[0]]]); uv.append(c[1]); nor.append(Vector3.ZERO)
	for t in range(n_tri):
		var a := poz[3 * t]; var b := poz[3 * t + 1]; var cc := poz[3 * t + 2]
		var nn := (cc - a).cross(b - a).normalized()
		for j in range(3): nor[3 * t + j] = nn
	var w_grupie := {}
	for nz in grupy:
		for t in grupy[nz]: w_grupie[t] = nz
	var mats: Array = []
	for ms in mats_src:
		for gname in ["", "player color"]:
			var ind := PackedInt32Array()
			for t in ms.trojkaty:
				var gr: String = w_grupie.get(t, "")
				if (gname == "" and gr != "player color") or (gname == "player color" and gr == "player color"):
					ind.append(3 * t); ind.append(3 * t + 2); ind.append(3 * t + 1)
			if not ind.is_empty():
				mats.append({"nazwa": gname, "tekstura": ms.tekstura, "indeksy": ind})
	m["pozycje"] = poz; m["normalne"] = nor; m["uv"] = uv; m["materialy"] = mats; m["grupy"] = grupy.keys()
	var pot: Array = []
	for i in range(n_child):
		var c := _model(r)
		if c.has("blad"): return c
		pot.append(c)
	m["potomne"] = pot
	return m


## Obraz tekstury dla materiału: plik z dbgraphics, obraz nr `tekstura_id` (przycięty do liczby obrazów – 1 przypadek
## w danych: nav_fishingboat_02); gdy pliku brak – nazwa z materiału. Braki zgłaszane do dziennika.
static func obraz_materialu(zasoby, tex_db: String, mt: Dictionary, klucz: String) -> Image:
	if zasoby == null:
		return null
	var obrazy: Array = []
	if tex_db != "":
		obrazy = zasoby.wczytaj_tekstury(tex_db)
	if obrazy.is_empty() and String(mt.get("tekstura", "")) != "":
		obrazy = zasoby.wczytaj_tekstury("textures/%s.sst" % String(mt.tekstura).to_lower())
	if obrazy.is_empty():
		ImporterEE.zglos("uwaga", "importer_modeli", "%s: brak tekstury (%s / %s)" % [klucz, tex_db, mt.get("tekstura", "")])
		return null
	var nr: int = int(mt.get("tekstura_id", 0))
	if nr >= obrazy.size():
		ImporterEE.zglos("uwaga", "importer_modeli", "%s: tekstura_id %d ≥ liczba obrazów %d – użyty ostatni" % [klucz, nr, obrazy.size()])
		nr = obrazy.size() - 1
	return obrazy[maxi(nr, 0)]


## Czy materiał z tym obrazem wycina piksele o alfa < 0,5 – każdy obraz z kanałem alfa, niezależnie od nazwy
## materiału (diagnostyka 0.5.1: także „player color”).
static func wymaga_wycinania(img: Image) -> bool:
	return img != null and img.detect_alpha() != Image.ALPHA_NONE


## Tekstura na GPU (modele statyczne i VAT): kolor tekseli o alfa = 0 (w EE czarny [D: 99,8% takich tekseli]) zastępowany
## kolorem sąsiadów przed budową mipmap – inaczej filtrowanie i mipmapy wciągają czerń w brzegi wycinanych kształtów
## (ciemne obwódki płotów, liści). Kanał alfa bez zmian.
static func tekstura_gpu(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(obraz_gpu(img))


static func obraz_gpu(img: Image) -> Image:
	var im := img.duplicate()
	if im.is_compressed(): im.decompress()
	if im.detect_alpha() != Image.ALPHA_NONE:
		if im.get_format() != Image.FORMAT_RGBA8: im.convert(Image.FORMAT_RGBA8)
		im.fix_alpha_edges()
	im.generate_mipmaps()
	return im


func _material(img: Image, kolor: Color, gracz: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new(); _shader.code = SHADER_MODELU
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	if img:
		mat.set_shader_parameter("tekstura", tekstura_gpu(img))
	mat.set_shader_parameter("kolor_gracza", kolor)
	mat.set_shader_parameter("kolor_gracza_mnoz", gracz)
	mat.set_shader_parameter("wycinanie_alfa", wymaga_wycinania(img))
	mat.set_shader_parameter("billboard_azymut", deg_to_rad(BILLBOARD_AZYMUT_ST))
	przelaczniki_diagnostyczne(mat)
	return mat


## Przełączniki A/B do porównań na konkretnym GPU (argumenty po "--", tylko diagnostyka; domyślnie reguły 0.5.2):
##   --bez-odrzucania (rysuj obie strony ścian)  --bez-przesuniecia-glebi  --bez-wycinania-alfa
static func przelaczniki_diagnostyczne(mat: ShaderMaterial) -> void:
	var a := OS.get_cmdline_user_args()
	if "--bez-odrzucania" in a: mat.set_shader_parameter("odrzucaj_tyl", false)
	if "--bez-przesuniecia-glebi" in a: mat.set_shader_parameter("przesuniecie_glebi", 0.0)
	if "--bez-wycinania-alfa" in a: mat.set_shader_parameter("wycinanie_alfa", false)


## Siatka statyczna z klatki `kontekst.klatka` (domyślnie 0). Etap 4: każda część (w tym potomne) jest
## przekształcona przez hierarchię ModelCEM.globalna – wcześniej części potomne (koła, wieżyczki) leżały w środku
## modelu bez swojej macierzy.
func _siatka_modelu(mc: ModelCEM, mesh: ArrayMesh, kontekst: Dictionary) -> void:
	var k: int = kontekst.get("klatka", 0)
	for i in mc.czesci.size():
		var c: Dictionary = mc.czesci[i]
		_siatka({"materialy": c.materialy, "pozycje": mc.pozycje_modelu(i, k), "normalne": mc.normalne_modelu(i, k),
			"uv": c.uv}, mesh, kontekst)


func _siatka(m: Dictionary, mesh: ArrayMesh, kontekst: Dictionary) -> void:
	var zasoby = kontekst.get("zasoby")
	var tex_db: String = kontekst.get("tekstura", "")
	var kolor: Color = kontekst.get("kolor_gracza", Color(0.8, 0.1, 0.1))
	var bb: bool = kontekst.get("billboard", false)
	for mt in m.materialy:
		if (mt.indeksy as PackedInt32Array).is_empty():
			continue
		if tex_db == "" and String(mt.tekstura) == "":
			# brak jakiejkolwiek tekstury w dbgraphics i w modelu – obiekt pomocniczy (np. bld_camera, fx_dummy_*)
			ImporterEE.zglos("info", "importer_modeli", "%s: powierzchnia bez tekstury pominięta" % kontekst.get("klucz", "?"))
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = m.pozycje
		arr[Mesh.ARRAY_NORMAL] = m.normalne
		arr[Mesh.ARRAY_TEX_UV] = m.uv
		arr[Mesh.ARRAY_INDEX] = mt.indeksy
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var img := obraz_materialu(zasoby, tex_db, mt, String(kontekst.get("klucz", "?")))
		var mat := _material(img, kolor, String(mt.nazwa) == "player color")
		mat.set_shader_parameter("billboard", bb)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		mesh.surface_set_name(mesh.get_surface_count() - 1, String(mt.nazwa) if mt.nazwa != "" else "glowny")
	for c in m.get("potomne", []):
		_siatka(c, mesh, kontekst)


func importuj(dane: PackedByteArray, kontekst: Dictionary) -> Variant:
	var mc := ModelCEM.z_danych(dane)
	if mc.blad != "":
		ImporterEE.zglos("blad", "importer_modeli", "%s: %s" % [kontekst.get("klucz", "?"), mc.blad])
		return null
	var mesh := ArrayMesh.new()
	_siatka_modelu(mc, mesh, kontekst)
	return mesh
