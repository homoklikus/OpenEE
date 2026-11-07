class_name ModelCEM
extends RefCounted
## Pełny model CEM (2.0 i 1.3) z animacją i hierarchią części – etap 4 (docs/FORMATY_ETAP4.md).
##
## Ustalenia [D] na danych EE/AoC (866 modeli, narzedzia/analiza_animacji.py):
## * animacja = KLATKI KLUCZOWE pełnej geometrii: każda klatka zawiera pozycje i normalne wszystkich wierzchołków
##   (2.0) albo pozycje punktów (1.3), punkty tag oraz macierz 4×4 części – brak szkieletu i wag kości;
## * część potomna = zagnieżdżony model SSMF; jej wierzchołki są w układzie lokalnym (koło wyśrodkowane w 0),
##   a macierz klatki (wiersze, przesunięcie w elementach 3, 7, 11) umieszcza ją w układzie rodzica: v' = D·v + t;
## * części potomne mają tyle klatek co rodzic albo 1 (statyczne) – klatka części = min(k, liczba_klatek − 1);
## * macierz korzenia jest jednostkowa we wszystkich klatkach (sprawdzone na danych).
## Część z danymi klatki nie ma informacji o czasie – tempo i zakresy sekwencji pochodzą z dbgraphics
## (SekwencjeAnimacji).
## Układ współrzędnych CEM: Z w górę → Godot: P(x, y, z) = (x, z, −y) (jak ImporterModeli, etap 1–3).

const P := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # kolumny: obraz osi X, Y, Z CEM

## Części w kolejności przejścia w głąb (rodzic przed dziećmi). Każda część:
## {nazwa, rodzic:int (−1 dla korzenia), wersja, klatki:int, pozycje:Array[PackedVector3Array] (na klatkę),
##  normalne:Array[PackedVector3Array], uv:PackedVector2Array, materialy:[{nazwa, tekstura, indeksy}],
##  lokalne:Array[Transform3D] (na klatkę, Godot), tagi:PackedStringArray, tagi_klatek:Array[PackedVector3Array],
##  animacja_wierzcholkowa:bool, macierz_zmienna:bool}
var czesci: Array = []
var klatki: int = 0          # liczba klatek korzenia
var nazwa: String = ""
var blad: String = ""
var reszta_bajtow: int = 0


static func z_danych(dane: PackedByteArray) -> ModelCEM:
	var m := ModelCEM.new()
	var r := _Czytnik.new(dane)
	m._czytaj_czesc(r, -1)
	if m.blad == "":
		m.reszta_bajtow = dane.size() - r.p
		m.klatki = int(m.czesci[0].klatki)
		m.nazwa = String(m.czesci[0].nazwa)
	return m


class _Czytnik:
	var d: PackedByteArray
	var p: int = 0
	func _init(dane: PackedByteArray) -> void:
		d = dane
	func u32() -> int:
		var v := d.decode_u32(p); p += 4; return v
	func f32() -> float:
		var v := d.decode_float(p); p += 4; return v
	func napis() -> String:
		var n := u32()
		var s := d.slice(p, p + n).get_string_from_ascii()
		p += n
		return s
	func v3() -> Vector3:
		var x := f32(); var y := f32(); var z := f32()
		return Vector3(x, z, -y)
	## Macierz 4×4 (wiersze) → Transform3D w układzie Godota: P·D·P⁻¹, przesunięcie P·t.
	func macierz() -> Transform3D:
		var m := PackedFloat32Array(); m.resize(16)
		for i in 16: m[i] = f32()
		return ModelCEM.macierz_cem(m)


## Macierz CEM (16 liczb, wiersze; przesunięcie w 3, 7, 11) → Transform3D Godota.
static func macierz_cem(m: PackedFloat32Array) -> Transform3D:
	var d := Basis(Vector3(m[0], m[4], m[8]), Vector3(m[1], m[5], m[9]), Vector3(m[2], m[6], m[10]))  # kolumny D
	return Transform3D(P * d * P.inverse(), P * Vector3(m[3], m[7], m[11]))


func _czytaj_czesc(r: _Czytnik, rodzic: int) -> void:
	if r.p + 8 > r.d.size() or r.d.slice(r.p, r.p + 4).get_string_from_ascii() != "SSMF":
		blad = "brak sygnatury SSMF @ %d" % r.p; return
	var major := r.d.decode_u16(r.p + 4); var minor := r.d.decode_u16(r.p + 6)
	r.p += 8
	var c: Dictionary
	if major == 2 and minor == 0:
		c = _czesc20(r)
	elif major == 1 and minor == 3:
		c = _czesc13(r)
	else:
		blad = "wersja CEM %d.%d nieobsługiwana" % [major, minor]; return
	c["rodzic"] = rodzic
	var ja := czesci.size()
	czesci.append(c)
	_wlasciwosci(c)
	for i in int(c.potomne):
		_czytaj_czesc(r, ja)
		if blad != "": return
	c.erase("potomne")


func _wlasciwosci(c: Dictionary) -> void:
	var anim := false
	var p0: PackedVector3Array = c.pozycje[0] if c.pozycje.size() > 0 else PackedVector3Array()
	for f in range(1, c.pozycje.size()):
		if c.pozycje[f] != p0:
			anim = true; break
	c["animacja_wierzcholkowa"] = anim
	var mz := false
	for f in range(1, c.lokalne.size()):
		if not (c.lokalne[f] as Transform3D).is_equal_approx(c.lokalne[0]):
			mz = true; break
	c["macierz_zmienna"] = mz


func _czesc20(r: _Czytnik) -> Dictionary:
	var n_tri := r.u32(); var n_v := r.u32(); var n_tag := r.u32(); var n_mat := r.u32()
	var n_fr := r.u32(); var n_child := r.u32(); var n_lod := r.u32()
	var c := {"wersja": "2.0", "nazwa": r.napis(), "klatki": n_fr, "potomne": n_child, "wierzcholki": n_v, "trojkaty": n_tri}
	r.p += 12
	var lods: Array = []
	for i in range(n_lod):
		var k := r.u32()
		var idx := PackedInt32Array(); idx.resize(3 * k)
		for j in range(3 * k): idx[j] = r.u32()
		lods.append(idx)
	var mats: Array = []
	for i in range(n_mat):
		var mt := {"nazwa": r.napis()}
		mt["tekstura_id"] = r.u32()        # indeks obrazu w pliku SST tekstury (dbgraphics) [D, naprawa grafiki]
		var zak: Array = []
		for l in range(n_lod): zak.append(Vector2i(r.u32(), r.u32()))
		var vo := r.u32(); var vn := r.u32()
		mt["v_offset"] = vo; mt["v_liczba"] = vn
		mt["tekstura"] = r.napis()
		var z: Vector2i = zak[0] if n_lod > 0 else Vector2i.ZERO
		# indeksy trójkątów materiału są WZGLĘDNE wobec v_offset materiału [D: 544/544 materiałów z v_offset > 0 ma
		# indeksy w [0, v_liczba), żaden nie mieści się w [v_offset, v_offset + v_liczba)] – etapy 1–5 czytały je
		# bezwzględnie, przez co trójkąty drugiego i kolejnych materiałów (zwykle „player color”) brały wierzchołki
		# pierwszego: rozsypana geometria, złe UV i plamy koloru gracza (raporty/archiwum/RAPORT_NAPRAWA_GRAFIKI.md)
		var ind := PackedInt32Array()
		for t in range(z.x, z.x + z.y):
			ind.append(vo + lods[0][3 * t]); ind.append(vo + lods[0][3 * t + 2]); ind.append(vo + lods[0][3 * t + 1])
		mt["indeksy"] = ind
		mats.append(mt)
	var tagi := PackedStringArray()
	for i in range(n_tag): tagi.append(r.napis())
	var poz: Array = []; var nor: Array = []; var lok: Array = []; var tk: Array = []
	var uv := PackedVector2Array(); uv.resize(n_v)
	for f in range(n_fr):
		r.f32()
		var pp := PackedVector3Array(); pp.resize(n_v)
		var nn := PackedVector3Array(); nn.resize(n_v)
		for i in range(n_v):
			pp[i] = r.v3(); nn[i] = r.v3()
			var u := r.f32(); var v := r.f32()
			if f == 0: uv[i] = Vector2(u, v)
		var tt := PackedVector3Array(); tt.resize(n_tag)
		for i in range(n_tag): tt[i] = r.v3()
		poz.append(pp); nor.append(nn); tk.append(tt)
		lok.append(r.macierz())
		r.p += 24
	c.merge({"pozycje": poz, "normalne": nor, "uv": uv, "materialy": mats, "tagi": tagi, "tagi_klatek": tk, "lokalne": lok})
	return c


## SSMF 1.3: wierzchołki = rogi trójkątów (indeks → punkt + UV), normalne liczone z geometrii każdej klatki.
func _czesc13(r: _Czytnik) -> Dictionary:
	var q: Array = []
	for i in range(8): q.append(r.u32())
	var n_fr: int = q[0]; var n_mat: int = q[1]; var n_pkt: int = q[2]; var n_tri: int = q[3]
	var n_grp: int = q[4]; var n_v: int = q[5]; var n_tag: int = q[6]; var n_child: int = q[7]
	var c := {"wersja": "1.3", "nazwa": r.napis(), "klatki": n_fr, "potomne": n_child, "wierzcholki": 3 * n_tri, "trojkaty": n_tri}
	r.p += 12 + 1 + 4 * n_pkt
	var rogi_w := PackedInt32Array(); var uv := PackedVector2Array()
	for i in range(3 * n_tri):
		rogi_w.append(r.u32()); var u := r.f32(); var v := r.f32(); uv.append(Vector2(u, v))
		r.p += 28
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
	var tagi := PackedStringArray()
	for i in range(n_tag): tagi.append(r.napis())
	var poz: Array = []; var nor: Array = []; var lok: Array = []; var tk: Array = []
	for f in range(n_fr):
		r.f32()
		var pkt := PackedVector3Array(); pkt.resize(n_pkt)
		for i in range(n_pkt): pkt[i] = r.v3()
		r.p += 2 * n_v
		var tt := PackedVector3Array(); tt.resize(n_tag)
		for i in range(n_tag): tt[i] = r.v3()
		lok.append(r.macierz())
		r.p += 24
		var pp := PackedVector3Array(); pp.resize(3 * n_tri)
		var nn := PackedVector3Array(); nn.resize(3 * n_tri)
		for i in range(3 * n_tri): pp[i] = pkt[w2p[rogi_w[i]]]
		for t in range(n_tri):
			var a := pp[3 * t]; var b := pp[3 * t + 1]; var cc := pp[3 * t + 2]
			var n := (cc - a).cross(b - a).normalized()
			nn[3 * t] = n; nn[3 * t + 1] = n; nn[3 * t + 2] = n
		poz.append(pp); nor.append(nn); tk.append(tt)
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
	c.merge({"pozycje": poz, "normalne": nor, "uv": uv, "materialy": mats, "tagi": tagi, "tagi_klatek": tk, "lokalne": lok,
		"grupy": grupy.keys()})
	return c


# ---------------------------------------------------------------- transformacje hierarchii

## Klatka części dla klatki modelu (części statyczne mają 1 klatkę).
func klatka_czesci(i: int, k: int) -> int:
	var n: int = czesci[i].klatki
	return clampi(k, 0, n - 1) if n > 0 else 0


## Lokalna transformacja części i (względem rodzica) w klatce k modelu.
func lokalna(i: int, k: int) -> Transform3D:
	var l: Array = czesci[i].lokalne
	return l[klatka_czesci(i, k)] if not l.is_empty() else Transform3D.IDENTITY


## Transformacja części w układzie modelu: T = T_rodzic · T_lokalna (dziedziczenie położenia, obrotu i skali).
## Nieprawidłowy indeks rodzica (≥ i albo poza zakresem) → część traktowana jak korzeń (zgłoszone w `kontrola()`).
func globalna(i: int, k: int) -> Transform3D:
	var t := lokalna(i, k)
	var p: int = czesci[i].rodzic
	var straz := 0
	while p >= 0 and p < i and straz < 64:
		t = lokalna(p, k) * t
		p = czesci[p].rodzic
		straz += 1
	return t


## Globalna transformacja z interpolacją między klatkami a i b (udział u): przesunięcie liniowo, obrót sferycznie.
func globalna_interp(i: int, a: int, b: int, u: float) -> Transform3D:
	var ta := globalna(i, a); var tb := globalna(i, b)
	return ta.interpolate_with(tb, u)


## Pozycje części i w klatce k w układzie modelu (z całą hierarchią).
func pozycje_modelu(i: int, k: int) -> PackedVector3Array:
	var c: Dictionary = czesci[i]
	var t := globalna(i, k)
	var src: PackedVector3Array = c.pozycje[klatka_czesci(i, k)]
	var out := PackedVector3Array(); out.resize(src.size())
	for j in src.size(): out[j] = t * src[j]
	return out


func normalne_modelu(i: int, k: int) -> PackedVector3Array:
	var c: Dictionary = czesci[i]
	var b := globalna(i, k).basis
	var nb := b.inverse().transposed()
	var src: PackedVector3Array = c.normalne[klatka_czesci(i, k)]
	var out := PackedVector3Array(); out.resize(src.size())
	for j in src.size(): out[j] = (nb * src[j]).normalized()
	return out


## Punkt tag (np. "attack", "weapon_mount_0") w układzie modelu, klatka k: [indeks_części, Vector3] lub [] gdy brak.
func tag(nazwa_tagu: String, k: int) -> Array:
	for i in czesci.size():
		var j := (czesci[i].tagi as PackedStringArray).find(nazwa_tagu)
		if j >= 0:
			var tk: Array = czesci[i].tagi_klatek
			if tk.is_empty(): return []
			return [i, globalna(i, k) * (tk[klatka_czesci(i, k)] as PackedVector3Array)[j]]
	return []


## Kontrola spójności – lista problemów (pusta = OK).
func kontrola() -> Array:
	var bl: Array = []
	if blad != "": return [blad]
	for i in czesci.size():
		var c: Dictionary = czesci[i]
		if int(c.rodzic) >= i:
			bl.append("część %d (%s): rodzic %d nie poprzedza dziecka" % [i, c.nazwa, c.rodzic])
		if int(c.klatki) != 1 and int(c.klatki) != klatki:
			bl.append("część %d (%s): %d klatek, model %d" % [i, c.nazwa, c.klatki, klatki])
		var nv: int = (c.uv as PackedVector2Array).size()
		for mt in c.materialy:
			var ind: PackedInt32Array = mt.indeksy
			var lo: int = mt.get("v_offset", 0); var hi: int = lo + int(mt.get("v_liczba", nv)) if mt.has("v_liczba") else nv
			for x in ind:
				if x < 0 or x >= nv:
					bl.append("część %d: indeks wierzchołka %d poza zakresem %d" % [i, x, nv]); break
				if x < lo or x >= hi:
					bl.append("część %d, materiał %s: indeks %d poza zakresem wierzchołków materiału [%d, %d)" % [i, mt.nazwa, x, lo, hi]); break
	return bl


## Opis drzewa części (do sceny diagnostycznej i raportów).
func drzewo() -> Array:
	var out: Array = []
	for i in czesci.size():
		var c: Dictionary = czesci[i]
		var gl := 0; var p: int = c.rodzic
		while p >= 0:
			gl += 1; p = czesci[p].rodzic
		out.append({"i": i, "nazwa": c.nazwa, "rodzic": c.rodzic, "glebokosc": gl, "klatki": c.klatki,
			"wierzcholki": (c.uv as PackedVector2Array).size(), "animacja_wierzcholkowa": c.animacja_wierzcholkowa,
			"macierz_zmienna": c.macierz_zmienna, "tagi": c.tagi, "sterowanie": rodzaj_czesci(String(c.nazwa))})
	return out


## Rodzaj części wg konwencji nazw w danych EE (obserwacja [D]: 'wheel' 80×, 'turret_N' 58×, 'orbital_cw/ccw_<n>_<i>'
## 173×, 'gate' 17×, 'ball' 14×). Obroty 'orbital_*' NIE są zapisane w klatkach (macierz stała) – silnik obraca je sam
## [H: <n> = prędkość]; wieżyczki/koła mają w części modeli ruch zapisany w klatkach. Sterowanie proceduralne
## (celowanie wieżyczki, toczenie kół w ruchu) – przyszły etap; OpenEE odtwarza tylko ruch zapisany w danych.
static func rodzaj_czesci(n: String) -> String:
	var s := n.strip_edges().to_lower()
	if s.begins_with("orbital_cw"): return "orbitalna_cw"
	if s.begins_with("orbital_ccw"): return "orbitalna_ccw"
	if s.begins_with("wheel"): return "kolo"
	if s.begins_with("turret"): return "wiezyczka"
	if s.begins_with("gate"): return "brama"
	if s.begins_with("ball"): return "kula"
	return ""
