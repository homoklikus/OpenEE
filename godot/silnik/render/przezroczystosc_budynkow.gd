class_name PrzezroczystoscBudynkow
extends Node
## Opcjonalna przezroczystość budynków (etap 8) – odtworzenie mechanizmu „ukrywania jednostek” oryginalnego EE
## (RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md § 3). Ustalenia z gry i pliku EE-AOC.exe:
## * trzy tryby przełączane klawiszem F5 cyklicznie 1 → 2 → 0 → 1 (komunikaty „Standardowy sposób ukrywania jednostek”,
##   „Budynki zawsze przezroczyste”, „Budynki zawsze nieprzezroczyste”); domyślnie 1 (stan po starcie gry) [D: pamięć],
## * przezroczyste mogą stać się tylko obiekty z flagą dbobjects „Unknown#52” (bajt +0x3AE rekordu, kopiowany do
##   obiektu gry): budynki, drzewa, mury, cuda – nie jednostki [D: kod + tabela; zrzuty: domy, forty, palmy],
## * tryb 1: obiekt jest przezroczysty, gdy w jego polu albo w polach (x, y−1), (x+1, y−1), (x+1, y) od pola jednostki
##   (tj. między jednostką a kamerą EE) stoi kwalifikująca się jednostka; znacznik wygasa po ~1–2 s bez odświeżenia
##   [D: kod – znacznik z numerem 1-sekundowego okna czasu],
## * tryb 2: wszystkie obiekty z flagą przezroczyste; tryb 0: żaden,
## * przezroczystość obejmuje cały model obiektu (wszystkie części), alfa 0,35 [D: stała w kodzie renderu; zrzuty],
##   bez płynnego przejścia (zmiana natychmiastowa w klatce) [zrzuty],
## * kolizje i przechodniość bez zmian (to wyłącznie sposób rysowania).
## Wykonanie: obiekt przezroczysty nie zmienia materiału źródłowego – rysuje go kopia siatki z materiałami pochodnymi
## (blend, bez zapisu głębi), a egzemplarz w nieprzezroczystym MultiMeshu dostaje zerową skalę. Koszt na takt:
## tylko jednostki, które zmieniły pole (oraz okresowe odświeżenie znaczników) – słownik pól, bez pętli po budynkach.

const ALFA := 0.35
const TRZYMANIE_S := 1.5          # czas życia znacznika bez odświeżenia [H: kod EE – okno 1 s, ważność do 2 okien]
const ODSWIEZANIE_S := 0.5        # jednostki stojące odświeżają znaczniki co tyle sekund
const SASIEDZI := [Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0)]
const POLE_FLAGI := "Unknown#52"  # dbobjects – obiekt może stać się przezroczysty
const NAZWY := {0: "budynki zawsze nieprzezroczyste", 1: "standardowy sposób ukrywania jednostek", 2: "budynki zawsze przezroczyste"}

signal zmieniono_tryb(tryb: int)

var tryb := 1
var czas := 0.0
var _obiekty: Array = []          # {grupa, i, xf, pola: Array[Vector2i], znacznik: float, przezr: bool}
var _pola := {}                   # Vector2i → [indeks obiektu]
var _grupy := {}                  # klucz → {mmi, mm, mmi_p, mm_p}
var _wezly := {}                  # indeks obiektu → MeshInstance3D (obiekty spoza MultiMeshy)
var _jednostki := {}              # id → {pole: Vector2i, t: float}
var zmian_stanu := 0              # pomiary / testy
var _aktywne := {}                # obiekty ze znacznikiem lub przezroczyste w trybie 1 (tylko je sprawdza krok())
var sprawdzen_w_kroku := 0        # pomiary / testy
static var _shadery := {}         # Shader źródłowy → Shader przezroczysty


static func flaga(ob: Dictionary) -> bool:
	return int(ob.get(POLE_FLAGI, 0)) != 0


## Pola mapy, w których obiekt jest „rejestrowany” do odsłaniania: pola, których środki leżą w kole o promieniu
## („Size of collider” − 0,5) wokół pozycji, co najmniej pole pozycji (fort 2,0 na wierzchołku siatki → 2×2 pola,
## dom 1,0 i drzewo 0,5 → 1 pole). [H: dobrane do kadrów EE – „Size of collider” jest promieniem koła (dyplomata stoi
## 2,09 od środka fortu o promieniu 2,0); legionista na skos za domem przy forcie nie czyni fortu przezroczystym.]
static func pola_obiektu(p: Vector2, rozmiar: float) -> Array:
	var r := maxf(rozmiar - 0.5, 0.0)
	var out: Array = []
	for x in range(int(floor(p.x - r)) - 1, int(floor(p.x + r)) + 2):
		for y in range(int(floor(p.y - r)) - 1, int(floor(p.y + r)) + 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(p) < r + 1e-4:
				out.append(Vector2i(x, y))
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if not (c in out): out.append(c)
	return out


## Shader przezroczysty pochodny od shadera modelu (ten sam kod: odrzucanie tylnych ścian, kolor gracza, wycinanie
## alfa) + mieszanie z alfą ALFA i bez zapisu głębi.
static func shader_przezroczysty(s: Shader) -> Shader:
	if _shadery.has(s): return _shadery[s]
	var kod := s.code
	var i := kod.find("render_mode")
	var j := kod.find(";", i)
	if i < 0 or j < 0: return s
	kod = kod.substr(0, j) + ", blend_mix, depth_draw_never" + kod.substr(j)
	kod = kod.replace("void fragment() {", "uniform float alfa_przezroczystosci = %f;\nvoid fragment() {" % ALFA)
	var k := kod.rfind("}")
	kod = kod.substr(0, k) + "\tALPHA = alfa_przezroczystosci;\n}" + kod.substr(k + 1)
	var n := Shader.new(); n.code = kod
	_shadery[s] = n
	return n


static func material_przezroczysty(m: Material) -> Material:
	if not (m is ShaderMaterial) or (m as ShaderMaterial).shader == null:
		var sm := StandardMaterial3D.new()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm.albedo_color = Color(1, 1, 1, ALFA)
		return sm
	var d: ShaderMaterial = m.duplicate()
	d.shader = shader_przezroczysty((m as ShaderMaterial).shader)
	return d


static func siatka_przezroczysta(mesh: Mesh) -> Mesh:
	var d: Mesh = mesh.duplicate()
	for s in d.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m: d.surface_set_material(s, material_przezroczysty(m))
	return d


## Grupa obiektów w MultiMeshu (wszystkie egzemplarze z flagą przezroczystości albo mieszane – `dodaj_obiekt`
## rejestruje tylko te z flagą).
func dodaj_grupe(klucz: String, mmi: MultiMeshInstance3D) -> void:
	var mm := mmi.multimesh
	var mmp: MultiMesh = mm.duplicate()
	mmp.mesh = siatka_przezroczysta(mm.mesh)
	for i in mmp.instance_count: mmp.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	var mmi_p := MultiMeshInstance3D.new(); mmi_p.multimesh = mmp; mmi_p.name = mmi.name + "_przezroczyste"
	mmi_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.get_parent().add_child(mmi_p)
	_grupy[klucz] = {"mmi": mmi, "mm": mm, "mmi_p": mmi_p, "mm_p": mmp}


func dodaj_obiekt(klucz: String, i: int, xf: Transform3D, p: Vector2, rozmiar: float) -> int:
	var id := _obiekty.size()
	var pola := pola_obiektu(p, rozmiar)
	_obiekty.append({"grupa": klucz, "i": i, "xf": xf, "pola": pola, "znacznik": -1e9, "przezr": false})
	for q in pola:
		if not _pola.has(q): _pola[q] = []
		_pola[q].append(id)
	return id


## Obiekt jako osobny węzeł (np. grupa poniżej progu MultiMesh).
func dodaj_wezel(w: MeshInstance3D, p: Vector2, rozmiar: float) -> int:
	var id := dodaj_obiekt("", -1, w.transform, p, rozmiar)
	_wezly[id] = w
	return id


func liczba_obiektow() -> int:
	return _obiekty.size()


func przezroczysty(id: int) -> bool:
	return bool(_obiekty[id].przezr)


## Stan rysowania obiektu: [egzemplarz nieprzezroczysty widoczny, egzemplarz przezroczysty widoczny] – to, co zostało
## zapisane do MultiMeshy/węzła (testy; serwer renderowania w trybie bez okna nie przechowuje transformacji).
func rysowanie(id: int) -> Array:
	var o: Dictionary = _obiekty[id]
	return [o.get("rys_n", true), o.get("rys_p", false)]


func ustaw_tryb(t: int) -> void:
	tryb = clampi(t, 0, 2)
	_zastosuj_wszystkie()
	zmieniono_tryb.emit(tryb)


## F5 w oryginale: 1 → 2 → 0 → 1.
func nastepny_tryb() -> int:
	ustaw_tryb((tryb + 1) % 3)
	return tryb


## Jednostka kwalifikująca się do odsłaniania stoi w punkcie p mapy EE (x = kolumna, y = wiersz).
## Wywoływane, gdy jednostka zmieniła pole, albo okresowo (ODSWIEZANIE_S) – patrz aktualizuj_jednostki().
func oznacz(p: Vector2) -> void:
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	for s in SASIEDZI:
		for id in _pola.get(c + s, []):
			_obiekty[id].znacznik = czas
			_aktywne[id] = true


## Aktualizacja z listy jednostek [[id, Vector2 pozycja]…]: oznacza tylko jednostki, które zmieniły pole albo
## czekają dłużej niż ODSWIEZANIE_S; usuwa jednostki nieobecne.
func aktualizuj_jednostki(lista: Array) -> int:
	var n := 0
	var obecne := {}
	for e in lista:
		var id: int = e[0]; var p: Vector2 = e[1]
		obecne[id] = true
		var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
		var st: Dictionary = _jednostki.get(id, {})
		if st.is_empty() or st.pole != c or czas - float(st.t) >= ODSWIEZANIE_S:
			oznacz(p); n += 1
			_jednostki[id] = {"pole": c, "t": czas}
	for id in _jednostki.keys():
		if not obecne.has(id): _jednostki.erase(id)
	return n


## Krok czasu: wygaszanie znaczników i zastosowanie zmian (tylko obiekty, których stan się zmienił).
func krok(delta: float) -> void:
	czas += delta
	sprawdzen_w_kroku = 0
	if tryb != 1: return
	for id in _aktywne.keys():
		var o: Dictionary = _obiekty[id]
		sprawdzen_w_kroku += 1
		var ma := czas - float(o.znacznik) <= TRZYMANIE_S
		if ma != bool(o.przezr): _ustaw(id, ma)
		if not ma: _aktywne.erase(id)


func _process(delta: float) -> void:
	krok(delta)


func _zastosuj_wszystkie() -> void:
	for id in _obiekty.size():
		var o: Dictionary = _obiekty[id]
		var ma := tryb == 2 or (tryb == 1 and czas - float(o.znacznik) <= TRZYMANIE_S)
		_ustaw(id, ma, true)


func _ustaw(id: int, wl: bool, wymus := false) -> void:
	var o: Dictionary = _obiekty[id]
	if bool(o.przezr) == wl and not wymus: return
	o.przezr = wl
	o["rys_n"] = not wl; o["rys_p"] = wl
	zmian_stanu += 1
	var zero := Transform3D(Basis().scaled(Vector3.ZERO), (o.xf as Transform3D).origin)
	if _wezly.has(id):
		var w: MeshInstance3D = _wezly[id]
		for s in w.mesh.get_surface_count():
			var m := w.mesh.surface_get_material(s)
			w.set_surface_override_material(s, material_przezroczysty(m) if (wl and m) else null)
		return
	var g: Dictionary = _grupy.get(o.grupa, {})
	if g.is_empty(): return
	(g.mm as MultiMesh).set_instance_transform(o.i, zero if wl else o.xf)
	(g.mm_p as MultiMesh).set_instance_transform(o.i, o.xf if wl else zero)
