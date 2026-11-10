class_name WidokJednostek
extends Node3D
## Renderowanie i animacja jednostek symulacji (etap 5) – czyta stan Symulacja, sam go nie zmienia.
## * jeden animowany MultiMesh na model (AnimacjaVAT z etapu 4); kolor gracza = kolor instancji,
## * transformacja: pozycja i kurs interpolowane między taktami (ZegarSymulacji.alfa), wysokość z terenu,
##   obrót UkladEE.baza(Rz(kurs)) · skala – ta sama konwencja osi co obiekty scenariusza (etap 3),
## * stan animacji z symulacji → sekwencja z dbgraphics (SekwencjeAnimacji: „ruch”, bezczynność gniazdo 2/3);
##   brak sekwencji → jednostka porusza się dalej, wpis w `brakujace_animacje`.

var sym          # Symulacja albo SymulacjaCore (etap 36): jednostki, mapa, lista()
var zegar: ZegarSymulacji
var odtw: OdtwarzaczAnimacji
var _jedn := {}          # id → {model, kolor, skala, sek, mm, i, kanal}
var _modele := {}        # klucz modelu → {anim, lista: [id]}
var zaznaczone: Array[int] = []
var pokaz_trasy := true
var brakujace_animacje := {}   # "model|stan" → liczba
var czas_transformacji_us := 0
var czas_animacji_us := 0
var _pierscienie := {}
var _linie: MeshInstance3D
var _mat_pierscienia: StandardMaterial3D


func _init(s, z: ZegarSymulacji) -> void:
	sym = s; zegar = z
	name = "WidokJednostek"


func _ready() -> void:
	odtw = OdtwarzaczAnimacji.new(); odtw.name = "OdtwarzaczJednostek"; add_child(odtw)
	_linie = MeshInstance3D.new(); _linie.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true; m.no_depth_test = true
	_linie.material_override = m; add_child(_linie)
	_mat_pierscienia = StandardMaterial3D.new(); _mat_pierscienia.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_pierscienia.albedo_color = Color(0.3, 1.0, 0.35); _mat_pierscienia.no_depth_test = true
	if zegar: zegar.po_takcie.connect(_po_takcie)


## Rejestruje jednostkę do renderowania (przed zbuduj()).
func dodaj(id: int, model: String, tex: String, kolor: Color, skala: float, sek: SekwencjeAnimacji) -> void:
	var k := "%s|%s" % [model, tex]
	if not _modele.has(k): _modele[k] = {"model": model, "tex": tex, "lista": []}
	_modele[k].lista.append(id)
	_jedn[id] = {"klucz": k, "kolor": kolor, "skala": skala, "sek": sek, "mm": null, "i": -1, "kanal": -1,
		"stan": "bezczynnosc", "grafika": -1}


## Etap 8: ID grafiki (dbgraphics) jednostki – informacyjnie, do porównań wariantów epok.
func ustaw_grafike_id(id: int, gid: int) -> void:
	if _jedn.has(id): _jedn[id].grafika = gid


func grafika_id(id: int) -> int:
	return int(_jedn.get(id, {}).get("grafika", -1))


func klucz_modelu(id: int) -> String:
	return String(_jedn.get(id, {}).get("klucz", ""))


## Etap 8: zmiana grafiki jednostki (wariant epoki) – jednostka przechodzi do grupy innego modelu; stan symulacji
## i bieżący stan animacji (nazwa stanu) zostają zachowane. Wymaga przebuduj(zasoby).
func zmien_grafike(id: int, model: String, tex: String, sek: SekwencjeAnimacji, gid: int = -1) -> void:
	var e: Dictionary = _jedn.get(id, {})
	if e.is_empty(): return
	var k := "%s|%s" % [model, tex]
	if k == e.klucz:
		e.sek = sek; e.grafika = gid; return
	var stary: Dictionary = _modele.get(e.klucz, {})
	if not stary.is_empty():
		stary.lista.erase(id); stary["brudny"] = true
	if not _modele.has(k): _modele[k] = {"model": model, "tex": tex, "lista": []}
	_modele[k].lista.append(id); _modele[k]["brudny"] = true
	e.klucz = k; e.sek = sek; e.grafika = gid


## Przebudowuje MultiMeshe grup zmienionych przez zmien_grafike (pozostałe grupy bez zmian).
func przebuduj(zasoby) -> Dictionary:
	var n := 0
	for k in _modele.keys():
		var g: Dictionary = _modele[k]
		if not g.get("brudny", false): continue
		g.brudny = false
		if g.has("mmi") and is_instance_valid(g.mmi):
			remove_child(g.mmi); g.mmi.queue_free()
		g.erase("mmi")
		if g.lista.is_empty():
			continue
		if not g.has("anim"):
			var anim: AnimacjaVAT = zasoby.wczytaj_animacje(g.model, {"tekstura": g.tex}) if zasoby else null
			if anim == null:
				ImporterEE.zglos("uwaga", "widok_jednostek", "Brak modelu %s – jednostki niewidoczne, symulacja działa" % g.model)
				for id in g.lista: _jedn[id].mm = null
				continue
			g["anim"] = anim
		_utworz_mm(g)
		n += 1
	_aktualizuj_transformacje(true)
	return {"przebudowane_grupy": n}


func _utworz_mm(g: Dictionary) -> void:
	var anim: AnimacjaVAT = g.anim
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true; mm.use_custom_data = true
	mm.mesh = anim.siatka_multimesh(); mm.instance_count = g.lista.size()
	for i in g.lista.size():
		var id: int = g.lista[i]
		var e: Dictionary = _jedn[id]
		e.mm = mm; e.i = i
		mm.set_instance_color(i, e.kolor)
		if e.kanal < 0:
			e.kanal = odtw.dodaj(mm, i)
		else:
			odtw.przypisz(e.kanal, mm, i)
		_animuj(id, String(e.stan))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.name = "jednostki_" + String(g.model).get_file()
	add_child(mmi)
	g["mmi"] = mmi


## Tworzy MultiMeshe (po jednym na model) – wymaga Zasoby (modele z instalacji).
func zbuduj(zasoby) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var nmod := 0
	for k in _modele:
		var g: Dictionary = _modele[k]
		var anim: AnimacjaVAT = zasoby.wczytaj_animacje(g.model, {"tekstura": g.tex}) if zasoby else null
		if anim == null:
			ImporterEE.zglos("uwaga", "widok_jednostek", "Brak modelu %s – jednostki niewidoczne, symulacja działa" % g.model)
			continue
		g["anim"] = anim
		_utworz_mm(g)
		nmod += 1
	_aktualizuj_transformacje(true)
	return {"modele": nmod, "jednostki": _jedn.size(), "czas_ms": (Time.get_ticks_usec() - t0) / 1000.0}


## Etap 36: ukrycie egzemplarza (zwłoki po animacji śmierci – stan nadal w symulacji, tylko prezentacja).
func ukryj(id: int, ukryta := true) -> void:
	var e: Dictionary = _jedn.get(id, {})
	if e.is_empty(): return
	e["ukryta"] = ukryta; e["ukryta_zapisana"] = false


func ukryta(id: int) -> bool:
	return bool(_jedn.get(id, {}).get("ukryta", false))


func _po_takcie(zd: Array) -> void:
	var t0 := Time.get_ticks_usec()
	for e in zd:
		if e.typ == "animacja":
			_animuj(int(e.id), String(e.stan))
	czas_animacji_us += Time.get_ticks_usec() - t0


func _animuj(id: int, stan: String) -> void:
	var e: Dictionary = _jedn.get(id, {})
	if e.is_empty() or e.kanal < 0: return
	e.stan = stan
	var sek: SekwencjeAnimacji = e.sek
	var q := {}
	if sek:
		q = sek.bezczynnosc() if stan == "bezczynnosc" else sek.dla_stanu(stan)
	if q.is_empty() or int(q.get("klatki", 1)) < 1:
		var kl := "%s|%s" % [String(e.klucz).get_slice("|", 0), stan]
		brakujace_animacje[kl] = brakujace_animacje.get(kl, 0) + 1
		if brakujace_animacje[kl] == 1:
			ImporterEE.zglos("uwaga", "widok_jednostek", "Brak sekwencji „%s” dla %s – ruch bez animacji" % [stan, kl.get_slice("|", 0)])
		odtw.ustaw_klatke(e.kanal, 0)
		return
	# faza startowa bezczynności zależna od id (deterministyczna, różna dla jednostek); ruch od początku cyklu
	var faza := float((id * 7) % maxi(int(q.klatki), 1)) if stan == "bezczynnosc" else 0.0
	odtw.odtworz(e.kanal, q, faza)


func _process(_d: float) -> void:
	_aktualizuj_transformacje(false)
	_rysuj_zaznaczenie()


func transformacja(j: JednostkaSym, alfa: float) -> Transform3D:
	var p := j.pozycja_poprz.lerp(j.pozycja, alfa)
	var k := j.kurs_poprz + UkladEE.roznica_katow(j.kurs, j.kurs_poprz) * alfa
	var e: Dictionary = _jedn.get(j.id, {})
	var s: float = e.get("skala", 1.0)
	return Transform3D(UkladEE.baza(UkladEE.R_z_kata(k)) * s, UkladEE.godot(p, sym.mapa.wysokosc(p)))


func _aktualizuj_transformacje(wszystkie: bool) -> void:
	var t0 := Time.get_ticks_usec()
	var alfa := zegar.alfa if zegar else 1.0
	for id in _jedn:
		var e: Dictionary = _jedn[id]
		if e.mm == null: continue
		var j: JednostkaSym = sym.jednostki.get(id)
		if j == null: continue
		if e.get("ukryta", false):
			if not e.get("ukryta_zapisana", false):
				(e.mm as MultiMesh).set_instance_transform(e.i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
				e["ukryta_zapisana"] = true
			continue
		if not wszystkie and j.pozycja == j.pozycja_poprz and j.kurs == j.kurs_poprz:
			continue
		(e.mm as MultiMesh).set_instance_transform(e.i, transformacja(j, alfa))
	czas_transformacji_us = Time.get_ticks_usec() - t0


func _rysuj_zaznaczenie() -> void:
	for id in _pierscienie.keys():
		if not (id in zaznaczone):
			_pierscienie[id].queue_free(); _pierscienie.erase(id)
	var im: ImmediateMesh = _linie.mesh
	im.clear_surfaces()
	var alfa := zegar.alfa if zegar else 1.0
	for id in zaznaczone:
		var j: JednostkaSym = sym.jednostki.get(id)
		if j == null: continue
		if not _pierscienie.has(id):
			var r := MeshInstance3D.new(); var t := TorusMesh.new()
			t.inner_radius = j.promien * 0.85; t.outer_radius = j.promien * 1.05
			r.mesh = t; r.material_override = _mat_pierscienia; add_child(r); _pierscienie[id] = r
		var p := j.pozycja_poprz.lerp(j.pozycja, alfa)
		_pierscienie[id].position = UkladEE.godot(p, sym.mapa.wysokosc(p) + 0.03)
		if pokaz_trasy and j.w_ruchu() and j.indeks_punktu < j.sciezka.size():
			im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			im.surface_set_color(Color(1, 0.9, 0.2))
			im.surface_add_vertex(UkladEE.godot(p, sym.mapa.wysokosc(p) + 0.1))
			for i in range(j.indeks_punktu, j.sciezka.size()):
				var q: Vector2 = j.sciezka[i]
				im.surface_set_color(Color(1, 0.9, 0.2)); im.surface_add_vertex(UkladEE.godot(q, sym.mapa.wysokosc(q) + 0.1))
			im.surface_end()
