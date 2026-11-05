class_name CEMSyntetyczny
extends RefCounted
## Generator syntetycznych modeli CEM 2.0 do testów jednostkowych (bez danych komercyjnych).
## Układ pliku jak w docs/FORMATY.md §4 / FORMATY_ETAP4.md §1.

var b := PackedByteArray()


func _u32(v: int) -> void:
	var o := b.size(); b.resize(o + 4); b.encode_u32(o, v)


func _f32(v: float) -> void:
	var o := b.size(); b.resize(o + 4); b.encode_float(o, v)


func _napis(s: String) -> void:
	var d := s.to_ascii_buffer(); d.append(0)
	_u32(d.size()); b.append_array(d)


## klatki: Array[PackedVector3Array] – pozycje wierzchołków (układ CEM, Z w górę) na klatkę;
## macierze: Array[PackedFloat32Array(16)] – macierz części na klatkę (wiersze, przesunięcie w 3, 7, 11);
## trojkaty: PackedInt32Array (indeksy); potomne: Array[PackedByteArray] (gotowe modele SSMF);
## tagi: {nazwa: Array[Vector3] na klatkę}.
static func model(nazwa: String, klatki: Array, macierze: Array, trojkaty: PackedInt32Array, potomne: Array = [],
		tagi: Dictionary = {}, material: String = "player color", tekstura: String = "test_tex") -> PackedByteArray:
	var g := CEMSyntetyczny.new()
	var nv: int = (klatki[0] as PackedVector3Array).size()
	var nt := trojkaty.size() / 3
	g.b.append_array("SSMF".to_ascii_buffer())
	var o := g.b.size(); g.b.resize(o + 4); g.b.encode_u16(o, 2); g.b.encode_u16(o + 2, 0)
	for v in [nt, nv, tagi.size(), 1, klatki.size(), potomne.size(), 1]: g._u32(v)
	g._napis(nazwa)
	for i in 3: g._f32(0.0)
	g._u32(nt)
	for x in trojkaty: g._u32(x)
	g._napis(material); g._u32(0); g._u32(0); g._u32(nt); g._u32(0); g._u32(nv); g._napis(tekstura)
	for t in tagi: g._napis(String(t))
	for f in klatki.size():
		g._f32(1.0)
		var pp: PackedVector3Array = klatki[f]
		for i in nv:
			g._f32(pp[i].x); g._f32(pp[i].y); g._f32(pp[i].z)
			g._f32(0.0); g._f32(0.0); g._f32(1.0)
			g._f32(float(i) / nv); g._f32(0.5)
		for t in tagi:
			var p: Vector3 = tagi[t][f]
			g._f32(p.x); g._f32(p.y); g._f32(p.z)
		var m: PackedFloat32Array = macierze[f] if f < macierze.size() else jednostkowa()
		for x in m: g._f32(x)
		for i in 6: g._f32(0.0)
	for c in potomne: g.b.append_array(c)
	return g.b


## Model 2.0 z wieloma materiałami (1 klatka, 1 LOD): materialy = [{nazwa, tex_id, tekstura, v_offset, v_liczba,
## trojkaty: PackedInt32Array indeksów WZGLĘDNYCH wobec v_offset (jak w danych EE)}]; pozycje/uv – wszystkie wierzchołki.
static func model_materialy(nazwa: String, pozycje: PackedVector3Array, uv: PackedVector2Array, materialy: Array) -> PackedByteArray:
	var g := CEMSyntetyczny.new()
	var nv := pozycje.size()
	var lod := PackedInt32Array(); var zakresy: Array = []
	for mt in materialy:
		zakresy.append(Vector2i(lod.size() / 3, (mt.trojkaty as PackedInt32Array).size() / 3))
		lod.append_array(mt.trojkaty)
	g.b.append_array("SSMF".to_ascii_buffer())
	var o := g.b.size(); g.b.resize(o + 4); g.b.encode_u16(o, 2); g.b.encode_u16(o + 2, 0)
	for v in [lod.size() / 3, nv, 0, materialy.size(), 1, 0, 1]: g._u32(v)
	g._napis(nazwa)
	for i in 3: g._f32(0.0)
	g._u32(lod.size() / 3)
	for x in lod: g._u32(x)
	for i in materialy.size():
		var mt: Dictionary = materialy[i]
		g._napis(String(mt.nazwa)); g._u32(int(mt.tex_id)); g._u32(zakresy[i].x); g._u32(zakresy[i].y)
		g._u32(int(mt.v_offset)); g._u32(int(mt.v_liczba)); g._napis(String(mt.get("tekstura", "tex")))
	g._f32(1.0)
	for i in nv:
		g._f32(pozycje[i].x); g._f32(pozycje[i].y); g._f32(pozycje[i].z)
		g._f32(0.0); g._f32(0.0); g._f32(1.0)
		g._f32(uv[i].x); g._f32(uv[i].y)
	for x in jednostkowa(): g._f32(x)
	for i in 6: g._f32(0.0)
	return g.b


static func jednostkowa() -> PackedFloat32Array:
	return PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])


## Macierz CEM: obrót o kąt (stopnie) wokół osi Z CEM + przesunięcie t (układ CEM).
static func obrot_z(stopnie: float, t: Vector3) -> PackedFloat32Array:
	var c := cos(deg_to_rad(stopnie)); var s := sin(deg_to_rad(stopnie))
	return PackedFloat32Array([c, -s, 0, t.x, s, c, 0, t.y, 0, 0, 1, t.z, 0, 0, 0, 1])


## Macierz CEM: obrót wokół osi X CEM + przesunięcie.
static func obrot_x(stopnie: float, t: Vector3) -> PackedFloat32Array:
	var c := cos(deg_to_rad(stopnie)); var s := sin(deg_to_rad(stopnie))
	return PackedFloat32Array([1, 0, 0, t.x, 0, c, -s, t.y, 0, s, c, t.z, 0, 0, 0, 1])


## Rekord dbgraphics (słownik w kolejności pól z dane/uklad_db.json) z podanymi gniazdami:
## gniazda: {nr: [[flagi, od, do, wartość, pętla, param], …], …}; zdarzenia/dzwieki: {nr: [a, b]}.
static func rekord_dbgraphics(uklad: Array, gniazda: Dictionary, zdarzenia: Dictionary = {}, dzwieki: Dictionary = {}) -> Dictionary:
	var r := {}
	for f in uklad:
		r[f[0]] = "" if String(f[2]).ends_with("STRING") else (0.0 if f[2] == "FLOAT" else 0)
	r["Name"] = "Syntetyczny"; r["Model path"] = "models\\syntetyczny"
	var klucze := r.keys()
	var i0 := klucze.find("Name")
	var dz: Array = []
	for i in klucze.size():
		if String(klucze[i]).begins_with("Sound ID"): dz.append(i)
	for k in dz: r[klucze[k]] = -1
	var p := i0 + 6
	for g in 12:
		var k: int = dz[2 * g]
		var lista: Array = gniazda.get(g, [])
		for j in lista.size():
			for x in 6: r[klucze[p + 6 * j + x]] = lista[j][x]
		if zdarzenia.has(g):
			r[klucze[k - 2]] = zdarzenia[g][0]; r[klucze[k - 1]] = zdarzenia[g][1]
		if dzwieki.has(g):
			r[klucze[k]] = dzwieki[g][0]; r[klucze[k + 1]] = dzwieki[g][1]
		p = k + 2
	return r
