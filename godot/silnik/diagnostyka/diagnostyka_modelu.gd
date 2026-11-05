class_name DiagnostykaModelu
extends RefCounted
## Analizy geometrii modelu CEM do diagnostyki grafiki (OpenEE 0.5.1-dev): lista trójkątów z pełnym opisem
## (część, materiał, indeksy, wierzchołki, UV, obraz SST, transformacja rodzica), trójkąty współpłaszczyznowe
## nakładające się (ryzyko z-fightingu – rozróżnienie: zwrot zgodny/przeciwny, ten sam/inny materiał),
## duplikaty, zgodność kolejności wierzchołków z normalnymi wierzchołków, alfa tekstury pod trójkątem.
## Używane przez scenę sceny/diag_modelu.tscn i testy (testy/testy_diagnostyki.gd). Bez założeń o konkretnych modelach.

const TOL_ODL := 0.002     # odległość od płaszczyzny (jednostki modelu) – „współpłaszczyznowe”
const TOL_KAT := 1.0       # stopnie


## Trójkąty modelu w układzie modelu (Godot, Y w górę) dla klatki k:
## [{id, czesc, nazwa_czesci, rodzic, material, nazwa_mat, nr, ind: Vector3i, P: [3×Vector3], uv: [3×Vector2],
##   n: Vector3 (normalna geometryczna wg kolejności indeksów), nv: Vector3 (suma normalnych wierzchołków), pole}]
static func trojkaty(m: ModelCEM, k: int = 0) -> Array:
	var out: Array = []
	for i in m.czesci.size():
		var c: Dictionary = m.czesci[i]
		var pp := m.pozycje_modelu(i, k); var nn := m.normalne_modelu(i, k)
		var uv: PackedVector2Array = c.uv
		for mi in c.materialy.size():
			var mt: Dictionary = c.materialy[mi]
			var ind: PackedInt32Array = mt.indeksy
			for t in range(0, ind.size() - 2, 3):
				var a := ind[t]; var b := ind[t + 1]; var cc := ind[t + 2]
				if maxi(a, maxi(b, cc)) >= pp.size(): continue
				var n := (pp[b] - pp[a]).cross(pp[cc] - pp[a])
				out.append({"id": out.size(), "czesc": i, "nazwa_czesci": String(c.nazwa), "rodzic": int(c.rodzic),
					"material": mi, "nazwa_mat": String(mt.nazwa), "tekstura_id": int(mt.get("tekstura_id", 0)), "nr": t / 3,
					"ind": Vector3i(a, b, cc), "P": [pp[a], pp[b], pp[cc]], "uv": [uv[a], uv[b], uv[cc]],
					"n": n.normalized(), "pole": n.length() * 0.5, "nv": nn[a] + nn[b] + nn[cc]})
	return out


## Zgodność kolejności wierzchołków z normalnymi wierzchołków: udział trójkątów, których normalna geometryczna
## (wg kolejności indeksów po imporcie) wskazuje tę samą stronę co normalne wierzchołków. ≈1 → spójne nawinięcie
## (można włączyć odrzucanie tylnych ścian), ≈0 → odwrócone, pośrodku → niespójne.
static func zgodnosc_nawiniecia(tr: Array) -> Dictionary:
	var zg := 0; var n := 0
	for t in tr:
		if t.pole <= 1e-10 or (t.nv as Vector3).length() < 1e-6: continue
		n += 1
		if (t.n as Vector3).dot(t.nv) > 0.0: zg += 1
	return {"trojkaty": n, "zgodne": zg, "udzial": (float(zg) / n) if n > 0 else 1.0}


static func _naklada_2d(A: Array, B: Array, eps: float = 1e-7) -> bool:
	for T in [A, B]:
		for i in 3:
			var p: Vector2 = T[i]; var q: Vector2 = T[(i + 1) % 3]
			var nrm := Vector2(q.y - p.y, p.x - q.x)
			var amin := INF; var amax := -INF; var bmin := INF; var bmax := -INF
			for x in A:
				var d := nrm.dot(x); amin = minf(amin, d); amax = maxf(amax, d)
			for x in B:
				var d := nrm.dot(x); bmin = minf(bmin, d); bmax = maxf(bmax, d)
			if amax <= bmin + eps or bmax <= amin + eps:
				return false
	return true


## Pary trójkątów współpłaszczyznowych o nakładających się wnętrzach (także te same wierzchołki o przeciwnym zwrocie)
## i duplikaty (te same 3 wierzchołki, ten sam zwrot).
## Wynik: {pary: [[id_a, id_b, "zgodne"|"przeciwne"]], duplikaty: [[id_a, id_b]], podsumowanie: {klucz: liczba}}.
## Kubełkowanie po płaszczyźnie (kierunek normalnej bez zwrotu + odległość), więc koszt ~liniowy dla typowych modeli.
static func wspolplaszczyznowe(tr: Array, tol_odl: float = TOL_ODL, tol_kat: float = TOL_KAT) -> Dictionary:
	var kub := {}
	for t in tr:
		if t.pole <= 1e-10: continue
		var n: Vector3 = t.n
		# kanoniczny zwrot: pierwsza niezerowa składowa dodatnia
		var s := 1.0
		if absf(n.x) > 1e-4: s = signf(n.x)
		elif absf(n.y) > 1e-4: s = signf(n.y)
		else: s = signf(n.z)
		var nk := n * s
		var d := nk.dot((t.P as Array)[0])
		var klucz := Vector4i(roundi(nk.x * 20), roundi(nk.y * 20), roundi(nk.z * 20), roundi(d / (tol_odl * 4.0)))
		if not kub.has(klucz): kub[klucz] = []
		kub[klucz].append(t.id)
	var cos_t := cos(deg_to_rad(tol_kat))
	var pary: Array = []; var dupl: Array = []
	var widziane := {}
	for klucz in kub:
		# porównanie z kubełkami sąsiednimi w odległości (granice kwantyzacji)
		var kandydaci: Array = []
		for dd in [-1, 0, 1]:
			var k2 := Vector4i(klucz.x, klucz.y, klucz.z, klucz.w + dd)
			if kub.has(k2): kandydaci.append_array(kub[k2])
		for ia in kub[klucz]:
			var A: Dictionary = tr[ia]
			for ib in kandydaci:
				if ib <= ia: continue
				var kp := Vector2i(ia, ib)
				if widziane.has(kp): continue
				widziane[kp] = true
				var B: Dictionary = tr[ib]
				var c := (A.n as Vector3).dot(B.n)
				if absf(c) < cos_t: continue
				var na: Vector3 = A.n; var da := na.dot(A.P[0])
				var daleko := false
				for p in B.P:
					if absf(na.dot(p) - da) > tol_odl: daleko = true; break
				if daleko: continue
				if _ten_sam_zbior(A.P, B.P):
					# te same wierzchołki: zgodny zwrot = duplikat, przeciwny = ściana dwustronna z dwóch trójkątów
					if c > 0: dupl.append([ia, ib])
					else: pary.append([ia, ib, "przeciwne"])
					continue
				var e1 := na.cross(Vector3.RIGHT if absf(na.x) < 0.9 else Vector3.UP).normalized(); var e2 := na.cross(e1)
				var pa: Array = []; var pb: Array = []
				for p in A.P: pa.append(Vector2(e1.dot(p), e2.dot(p)))
				for p in B.P: pb.append(Vector2(e1.dot(p), e2.dot(p)))
				if _naklada_2d(pa, pb):
					pary.append([ia, ib, "zgodne" if c > 0 else "przeciwne"])
	var pods := {}
	for p in pary:
		var A: Dictionary = tr[p[0]]; var B: Dictionary = tr[p[1]]
		var rodz := "ten_sam_material" if (A.czesc == B.czesc and A.material == B.material) else "rozne_materialy"
		var k := "%s/%s" % [p[2], rodz]
		pods[k] = pods.get(k, 0) + 1
	return {"pary": pary, "duplikaty": dupl, "podsumowanie": pods}


static func _ten_sam_zbior(a: Array, b: Array) -> bool:
	for p in a:
		var jest := false
		for q in b:
			if (p as Vector3).is_equal_approx(q): jest = true; break
		if not jest: return false
	return true


## Alfa tekstury w środku UV trójkąta (0–255) albo -1 przy braku obrazu.
static func alfa_w_srodku(img: Image, t: Dictionary) -> int:
	if img == null: return -1
	var u: Vector2 = ((t.uv[0] as Vector2) + t.uv[1] + t.uv[2]) / 3.0
	var x := clampi(int(fposmod(u.x, 1.0) * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(fposmod(u.y, 1.0) * img.get_height()), 0, img.get_height() - 1)
	return int(round(img.get_pixel(x, y).a * 255.0))


## Pełny opis trójkąta do raportu (z obrazem SST i transformacją rodzica).
static func opis(m: ModelCEM, t: Dictionary, img: Image, nr_obrazu: int, k: int = 0) -> Dictionary:
	var rodzic := "brak"
	if int(t.rodzic) >= 0:
		rodzic = str(m.globalna(int(t.rodzic), k))
	var P: Array = []
	for p in t.P: P.append([snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)])
	var uv: Array = []
	for u in t.uv: uv.append([snappedf(u.x, 0.0001), snappedf(u.y, 0.0001)])
	return {"id": t.id, "czesc": "%d:%s" % [t.czesc, t.nazwa_czesci], "material": "%d:%s" % [t.material, t.nazwa_mat],
		"tekstura_id": t.tekstura_id, "obraz_sst": nr_obrazu, "trojkat_w_materiale": t.nr,
		"indeksy": [t.ind.x, t.ind.y, t.ind.z], "wierzcholki_model": P, "uv": uv, "alfa_srodka": alfa_w_srodku(img, t),
		"transformacja_czesci": str(m.globalna(int(t.czesc), k)), "transformacja_rodzica": rodzic,
		"nawiniecie_zgodne_z_normalnymi": (t.n as Vector3).dot(t.nv) > 0.0}
