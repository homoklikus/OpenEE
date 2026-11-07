class_name TerenEE
extends RefCounted
## Budowa terenu Empire Earth wg reguł silnika oryginalnego (ustalenia etapu 3 – raporty/archiwum/RAPORT_ETAP_3.md §2, docs/FORMATY_ETAP3.md).
## Kod własny OpenEE; reguły opisane słownie na podstawie analizy Low-Level Engine.dll / EE-AOC.exe i sprawdzone na danych.
##
## [K] = potwierdzone kodem, [D] = danymi, [H] = hipoteza.
## * Pole (r,c) to czworokąt na punktach (r,c), (r,c+1), (r+1,c+1), (r+1,c); przekątna (r,c)–(r+1,c+1) [K].
## * Każdy narożnik pola dostaje rodzaj terenu z pola o przesunięciu (-1,-1) względem punktu: punkt (j,i) ← pole (j-1,i-1) [K].
##   Pole rysowane jest jako warstwa bazowa (pełna, alfa=1) + po jednej warstwie na każdą inną teksturę narożników;
##   alfa warstwy w narożniku = 1, jeśli narożnik ma tę teksturę, inaczej 0 – interpolowana liniowo w trójkątach [K].
##   Warstwa bazowa = „najmniejsza” tekstura; silnik porównuje adresy obiektów tekstur, OpenEE: kolejność wczytania
##   (ID terenu, numer pliku) [H – na wynik w narożnikach nie wpływa, zmienia tylko wnętrze przejść].
## * Wariant tekstury (plik _N) dla pola (r,c) terenu o siatce W×H: N = 1 + W·(r mod H) + (W−1−(c mod W)) [K];
##   każde pole pokrywa całą teksturę (UV 0..1) [K], obraz odbity poziomo względem kolumn [D: ciągłość krawędzi].
## * Woda: osobna warstwa półprzezroczysta na polach z flagą (flagi & 0x7F); alfa 0,5 w narożnikach wodnych,
##   0 w narożnikach oznaczonych bitami lądu 0x02/0x04/0x08/0x10 [K]. Poziom wody 0 [H].
## * Klify: brak osobnej geometrii poza mapami kosmicznymi – zwykłe pola z teksturą klifu i wysokościami [K].
## * Kolor wierzchołków z tablicy kolorów: klasa punktu = indeks tablicy, gra przekazuje pustą tablicę → biel [K].

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray tekstury : source_color, filter_linear_mipmap, repeat_disable;
varying flat vec4 warstwy;
varying vec4 alfa;
void vertex() { warstwy = CUSTOM0; alfa = CUSTOM1; }
void fragment() {
	vec3 c = texture(tekstury, vec3(UV, warstwy.x)).rgb;
	if (warstwy.y >= 0.0) c = mix(c, texture(tekstury, vec3(UV, warstwy.y)).rgb, clamp(alfa.y, 0.0, 1.0));
	if (warstwy.z >= 0.0) c = mix(c, texture(tekstury, vec3(UV, warstwy.z)).rgb, clamp(alfa.z, 0.0, 1.0));
	if (warstwy.w >= 0.0) c = mix(c, texture(tekstury, vec3(UV, warstwy.w)).rgb, clamp(alfa.w, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 1.0; SPECULAR = 0.1;
}
"""

## Woda – etap 4: animowany zestaw klatek z dbterrain (Available = 1 → TilesX·TilesY klatek, np. Water_OceanB_1…16),
## klatka = floor(czas / ms_na_klatke) mod liczba [H: ms_na_klatke = pole „<Used by animated terrains>” = 100].
## Silnik wybiera materiał wody z tabeli 33×33 wg (c mod 33, r mod 33) [K] – zawartość tabeli nieodtworzona,
## OpenEE: wszystkie pola w tej samej fazie [ograniczenie].
const SHADER_WODY := """
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never;
uniform sampler2DArray klatki : source_color, filter_linear_mipmap, repeat_disable;
uniform int liczba_klatek = 1;
uniform float s_na_klatke = 0.1;
uniform bool animacja = true;
void fragment() {
	float k = animacja ? mod(floor(TIME / s_na_klatke), float(liczba_klatek)) : 0.0;
	ALBEDO = texture(klatki, vec3(UV, k)).rgb;
	ALPHA = COLOR.a;
	ROUGHNESS = 0.6; SPECULAR = 0.3;
}
"""

## Kolejność narożników jak w silniku: slot → (dr, dc) punktu względem pola, (dr, dc) pola-źródła rodzaju terenu, UV silnika.
const NAROZNIK_PUNKT := [Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1)]
const NAROZNIK_ZRODLO := [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0)]
## UV w Godocie (początek u góry obrazu): u = 1 − u_silnika (odbicie poziome [D]), v = v_silnika.
const NAROZNIK_UV := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
## Bity lądu w bajcie flag pola dla narożników wody (slot 0..3) [K].
const BITY_LADU := [0x08, 0x04, 0x02, 0x10]
const ALFA_WODY := 0.5
const ID_WODY := 46

var scn: ScenariuszEE
var tereny := {}            # ID → rekord dbterrain
var skala_wysokosci := 1.0
var statystyka := {}


func _init(scenariusz: ScenariuszEE, tabela_terenow: Array, skala := 1.0) -> void:
	scn = scenariusz
	skala_wysokosci = skala
	for r in tabela_terenow:
		tereny[int(r.ID)] = r


var statystyka_wody := {}


## Pliki klatek animowanego terenu (woda): <baza>_1 … <baza>_N, N = TilesX·TilesY (dbterrain) [D: Water_OceanB 16×1].
func pliki_klatek(tid: int) -> PackedStringArray:
	var t: Dictionary = tereny.get(tid, {})
	var out := PackedStringArray()
	if t.is_empty() or int(t["Available: 0-No, 1-Animated, 65536-Static"]) != 1:
		return out
	var baza := String(t.Pathname).to_lower().replace("\\", "/").trim_suffix(".sst")
	for i in maxi(1, int(t["Tyles on X axis"]) * int(t["Tiles on Y axis"])):
		out.append("%s_%d.sst" % [baza, i + 1])
	return out


## Czas klatki wody w ms – pole „<Used by animated terrains>” rekordu wody (100) [H].
func ms_na_klatke_wody() -> float:
	var v := float(tereny.get(ID_WODY, {}).get("<Used by animated terrains>", 0))
	return v if v > 0.0 else 100.0


func klatki_wody_obrazy(zasoby) -> Array[Image]:
	var out: Array[Image] = []
	if not tereny.has(ID_WODY) or zasoby == null:
		return out
	for p in pliki_klatek(ID_WODY):
		var im: Image = zasoby.wczytaj_teksture(p)
		if im == null:
			continue
		im = im.duplicate(); im.clear_mipmaps()
		if im.is_compressed(): im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		if not out.is_empty() and im.get_size() != out[0].get_size():
			im.resize(out[0].get_width(), out[0].get_height())
		im.generate_mipmaps()
		out.append(im)
	return out


## Plik wariantu tekstury terenu `tid` dla pola (r, c) [K].
func plik_wariantu(tid: int, r: int, c: int) -> String:
	var t: Dictionary = tereny.get(tid, {})
	if t.is_empty() or String(t.get("Pathname", "")) == "":
		return ""
	var baza := String(t.Pathname).to_lower().replace("\\", "/").trim_suffix(".sst")
	var W: int = max(1, int(t["Tyles on X axis"]))
	var H: int = max(1, int(t["Tiles on Y axis"]))
	if int(t["Available: 0-No, 1-Animated, 65536-Static"]) == 1:
		return "%s_1.sst" % baza   # teren animowany (woda) – klatka 1
	return "%s_%d.sst" % [baza, 1 + W * posmod(r, H) + (W - 1 - posmod(c, W))]


func teren_pola(r: int, c: int) -> int:
	if r < 0 or r >= scn.teren.N:
		return -1
	var i := scn.indeks_pola(r, c)
	return int(scn.teren.teren[i]) if i >= 0 else -1


func flagi_pola(r: int, c: int) -> int:
	var i := scn.indeks_pola(r, c) if r >= 0 and r < scn.teren.N else -1
	return int(scn.teren.flagi[i]) if i >= 0 else 0


## Warstwy pola (r, c): {"warstwy": [plik bazowy, plik2|"", plik3|"", plik4|""],
##  "alfa": [[a_s0..a_s3] dla narożnika 0..3], "tereny": [tid narożnika 0..3]} – czysta logika (testowalna).
func warstwy_pola(r: int, c: int) -> Dictionary:
	var pliki: Array = []
	var tid_n: Array = []
	for k in 4:
		var src: Vector2i = NAROZNIK_ZRODLO[k]
		var tid := teren_pola(r + src.x, c + src.y)
		tid_n.append(tid)
		pliki.append(plik_wariantu(tid, r, c) if tid >= 0 else "")   # wariant zawsze wg współrzędnych BIEŻĄCEGO pola [K]
	# unikalne tekstury w kolejności narożników; baza = najmniejszy klucz (ID terenu, plik) [H]
	var unik: Array = []
	var baza := -1
	for k in 4:
		if pliki[k] == "" or pliki[k] in unik:
			continue
		unik.append(pliki[k])
		var kl := _klucz(tid_n[k], pliki[k])
		if baza < 0 or kl < _klucz(tid_n[pliki.find(unik[baza])], unik[baza]):
			baza = unik.size() - 1
	var warstwy: Array = ["", "", "", ""]
	if unik.is_empty():
		return {"warstwy": warstwy, "alfa": [[1, 0, 0, 0], [1, 0, 0, 0], [1, 0, 0, 0], [1, 0, 0, 0]], "tereny": tid_n}
	warstwy[0] = unik[baza]
	var s := 1
	for i in unik.size():
		if i != baza:
			warstwy[s] = unik[i]; s += 1
	var alfa: Array = []
	for k in 4:
		var a := [1.0, 0.0, 0.0, 0.0]
		for sl in range(1, 4):
			if warstwy[sl] != "" and pliki[k] == warstwy[sl]:
				a[sl] = 1.0
		alfa.append(a)
	return {"warstwy": warstwy, "alfa": alfa, "tereny": tid_n}


func _klucz(tid: int, plik: String) -> int:
	return tid * 1000 + int(plik.get_basename().get_slice("_", plik.get_basename().get_slice_count("_") - 1))


func wysokosc(r: int, c: int) -> float:
	var i := scn.indeks_punktu(r, c)
	return scn.teren.wysokosc[i] * skala_wysokosci if i >= 0 else 0.0


## Normalna punktu z różnic centralnych wysokości (odpowiednik ComputeVertexNormal – wygładzone normalne wierzchołków).
func normalna(r: int, c: int) -> Vector3:
	var hx := (wysokosc(r, c + 1) - wysokosc(r, c - 1)) * 0.5     # ∂h/∂kolumna
	var hy := (wysokosc(r + 1, c) - wysokosc(r - 1, c)) * 0.5     # ∂h/∂wiersz
	return UkladEE.wektor(Vector3(-hx, -hy, 1.0)).normalized()     # normalna w świecie EE → Godot


## Buduje teren i wodę dla okna pól [r0, r0+n) × [c0, c0+n). Zwraca węzeł Node3D z dziećmi „Teren” i „Woda”.
func zbuduj(r0: int, c0: int, n: int, zasoby: Node) -> Node3D:
	var t0 := Time.get_ticks_usec()
	var wezel := Node3D.new()
	wezel.name = "TerenEE"
	var indeks := {}           # plik → warstwa tablicy tekstur
	var obrazy: Array[Image] = []
	var v := PackedVector3Array(); var nor := PackedVector3Array(); var uv := PackedVector2Array()
	var cu0 := PackedFloat32Array(); var cu1 := PackedFloat32Array(); var idx := PackedInt32Array()
	var wv := PackedVector3Array(); var wuv := PackedVector2Array(); var wcol := PackedColorArray(); var widx := PackedInt32Array()
	var pola := 0; var warstw_suma := 0; var brak := 0; var pola_wody := 0
	var rozmiar := 128
	for r in range(r0, r0 + n):
		for c in range(c0, c0 + n):
			if scn.indeks_pola(r, c) < 0:
				continue
			var w := warstwy_pola(r, c)
			var li := [-1.0, -1.0, -1.0, -1.0]
			for s in 4:
				var plik: String = w.warstwy[s]
				if plik == "":
					continue
				if not indeks.has(plik):
					var img: Image = zasoby.wczytaj_teksture(plik)
					if img == null:
						indeks[plik] = -1
					else:
						img = img.duplicate()
						img.clear_mipmaps()
						if img.is_compressed(): img.decompress()
						img.convert(Image.FORMAT_RGBA8)
						if img.get_width() != rozmiar or img.get_height() != rozmiar:
							img.resize(rozmiar, rozmiar, Image.INTERPOLATE_BILINEAR)
						img.generate_mipmaps()
						indeks[plik] = obrazy.size(); obrazy.append(img)
				li[s] = float(indeks[plik])
				if s > 0 and li[s] >= 0: warstw_suma += 1
			if li[0] < 0:
				brak += 1; li[0] = 0.0
			var baz := v.size()
			for k in 4:
				var pp: Vector2i = NAROZNIK_PUNKT[k]
				var pr := r + pp.x; var pc := c + pp.y
				v.append(UkladEE.godot(Vector2(pc, pr), wysokosc(pr, pc)))
				nor.append(normalna(pr, pc))
				uv.append(NAROZNIK_UV[k])
				cu0.append_array(PackedFloat32Array(li))
				cu1.append_array(PackedFloat32Array(w.alfa[k]))
			# trójkąty silnika: (s2, s1, s0) i (s2, s0, s3) – przekątna s2–s0 = (r,c)–(r+1,c+1) [K]
			idx.append_array(PackedInt32Array([baz + 2, baz + 1, baz + 0, baz + 2, baz + 0, baz + 3]))
			pola += 1
			# woda
			var fl := flagi_pola(r, c)
			if fl & 0x7F:
				var wb := wv.size()
				for k in 4:
					var pp2: Vector2i = NAROZNIK_PUNKT[k]
					wv.append(UkladEE.godot(Vector2(c + pp2.y, r + pp2.x), 0.0))
					wuv.append(NAROZNIK_UV[k])
					wcol.append(Color(1, 1, 1, 0.0 if fl & BITY_LADU[k] else ALFA_WODY))
				widx.append_array(PackedInt32Array([wb + 2, wb + 1, wb + 0, wb + 2, wb + 0, wb + 3]))
				pola_wody += 1
	var t1 := Time.get_ticks_usec()
	if pola > 0 and not obrazy.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nor; arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_CUSTOM0] = cu0; arr[Mesh.ARRAY_CUSTOM1] = cu1; arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		var tex := Texture2DArray.new()
		tex.create_from_images(obrazy)
		var mat := ShaderMaterial.new()
		var sh := Shader.new(); sh.code = SHADER
		mat.shader = sh
		mat.set_shader_parameter("tekstury", tex)
		var mi := MeshInstance3D.new()
		mi.name = "Teren"; mi.mesh = m; mi.material_override = mat
		wezel.add_child(mi)
	if pola_wody > 0:
		var arr2 := []
		arr2.resize(Mesh.ARRAY_MAX)
		arr2[Mesh.ARRAY_VERTEX] = wv; arr2[Mesh.ARRAY_TEX_UV] = wuv; arr2[Mesh.ARRAY_COLOR] = wcol; arr2[Mesh.ARRAY_INDEX] = widx
		var m2 := ArrayMesh.new()
		m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
		var mat2 := ShaderMaterial.new()
		var sh2 := Shader.new(); sh2.code = SHADER_WODY
		mat2.shader = sh2
		var klatki_wody := klatki_wody_obrazy(zasoby)
		if not klatki_wody.is_empty():
			var ta := Texture2DArray.new(); ta.create_from_images(klatki_wody)
			mat2.set_shader_parameter("klatki", ta)
			mat2.set_shader_parameter("liczba_klatek", klatki_wody.size())
			mat2.set_shader_parameter("s_na_klatke", ms_na_klatke_wody() / 1000.0)
		statystyka_wody = {"klatki": klatki_wody.size(), "ms_na_klatke": ms_na_klatke_wody()}
		var mw := MeshInstance3D.new()
		mw.name = "Woda"; mw.mesh = m2; mw.material_override = mat2
		mw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wezel.add_child(mw)
	statystyka = {"pola": pola, "warstwy_dodatkowe": warstw_suma, "warstwy_tablicy": obrazy.size(),
		"pola_bez_tekstury": brak, "pola_wody": pola_wody, "trojkaty": idx.size() / 3 + widx.size() / 3,
		"czas_siatki_ms": (t1 - t0) / 1000.0, "czas_gpu_upload_ms": (Time.get_ticks_usec() - t1) / 1000.0,
		"woda": statystyka_wody}
	return wezel
