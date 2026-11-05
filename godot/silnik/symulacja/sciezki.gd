class_name Sciezki
extends RefCounted
## Wyszukiwanie tras A* na MapaNawigacji (etap 5).
## * 8 sąsiadów, ruch po przekątnej tylko gdy oba sąsiednie boki są przechodnie (bez ścinania narożników przeszkód),
## * koszt kroku = długość + koszt_wysokosci · |Δh| [H – wysokość wydłuża trasę, nie blokuje],
## * heurystyka oktylowa (dopuszczalna),
## * składowe spójności liczone raz na politykę (cel w innej składowej → „nieosiągalny” bez przeszukiwania mapy),
## * wygładzanie: skrót przyjmowany, gdy jest widoczny po przechodnich komórkach i nie droższy (z wysokością),
## * implementacja na tablicach upakowanych: przechodniość i wysokości komórek w pamięci podręcznej, znaczniki
##   pokolenia zamiast czyszczenia tablic, kopiec binarny na PackedFloat32Array/PackedInt32Array.
## Wynik: {ok, sciezka: PackedVector2Array (punkty mapy, bez startu, z celem), powod, odwiedzone, czas_us}.

const SQRT2 := 1.41421356
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]

var mapa: MapaNawigacji
var _skladowe := {}     # klucz polityki → PackedInt32Array (−1 = nieprzechodnia)
var _przech := {}       # klucz polityki → PackedByteArray (1 = przechodnia)
var _hc := PackedFloat32Array()   # wysokość w środku komórki
var _g := PackedFloat32Array()
var _skad := PackedInt32Array()
var _stan := PackedInt32Array()   # pokolenie·2 (+1 = zamknięta)
var _pokolenie := 0
var statystyka := {"zapytania": 0, "czas_us": 0, "odwiedzone": 0}


func _init(m: MapaNawigacji) -> void:
	mapa = m


## Unieważnienie pamięci podręcznej (np. po dodaniu przeszkody).
func uniewaznij() -> void:
	_skladowe.clear(); _przech.clear()


func _przygotuj() -> void:
	var n := mapa.szer_komorek() * mapa.wys_komorek()
	if _hc.size() != n:
		_hc.resize(n)
		var W := mapa.szer_komorek()
		for i in n: _hc[i] = mapa.wysokosc(mapa.srodek(Vector2i(i % W, i / W)))
		_g.resize(n); _skad.resize(n); _stan.resize(n); _stan.fill(0); _pokolenie = 0


func przechodniosc(pol: PolitykaRuchu) -> PackedByteArray:
	var kl := pol.klucz()
	if _przech.has(kl): return _przech[kl]
	var W := mapa.szer_komorek(); var H := mapa.wys_komorek()
	var p := PackedByteArray(); p.resize(W * H)
	for y in H:
		for x in W:
			p[y * W + x] = 1 if mapa.przechodnia(Vector2i(x, y), pol) else 0
	_przech[kl] = p
	return p


func skladowe(pol: PolitykaRuchu) -> PackedInt32Array:
	var kl := pol.klucz()
	if _skladowe.has(kl):
		return _skladowe[kl]
	var pr := przechodniosc(pol)
	var W := mapa.szer_komorek(); var H := mapa.wys_komorek()
	var s := PackedInt32Array(); s.resize(W * H); s.fill(-2)
	var nr := 0
	var stos := PackedInt32Array()
	for i0 in W * H:
		if s[i0] != -2: continue
		if pr[i0] == 0:
			s[i0] = -1; continue
		s[i0] = nr; stos.append(i0)
		while not stos.is_empty():
			var j := stos[stos.size() - 1]; stos.resize(stos.size() - 1)
			var jx := j % W; var jy := j / W
			for d in 8:
				var nx: int = jx + DX[d]; var ny: int = jy + DY[d]
				if nx < 0 or ny < 0 or nx >= W or ny >= H: continue
				var ni := ny * W + nx
				if s[ni] != -2 or pr[ni] == 0: continue
				if d >= 4 and (pr[jy * W + nx] == 0 or pr[ny * W + jx] == 0): continue
				s[ni] = nr; stos.append(ni)
		nr += 1
	_skladowe[kl] = s
	return s


## Trasa z punktu `start` do `cel` (punkty mapy) dla polityki `pol`.
func znajdz(start: Vector2, cel: Vector2, pol: PolitykaRuchu) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	statystyka.zapytania += 1
	var ks := mapa.komorka(start); var kc := mapa.komorka(cel)
	if kc.x < 0:
		return _wynik(false, PackedVector2Array(), "cel poza mapą", 0, t0)
	var pk := mapa.powod(kc, pol)
	if pk != "":
		return _wynik(false, PackedVector2Array(), "cel niedostępny – " + pk, 0, t0)
	if ks.x < 0:
		return _wynik(false, PackedVector2Array(), "start poza mapą", 0, t0)
	var pr := przechodniosc(pol)
	if pr[mapa.indeks(ks)] == 0:
		ks = _najblizsza_przechodnia(ks, pr)
		if ks.x < 0:
			return _wynik(false, PackedVector2Array(), "jednostka stoi na niedostępnej komórce", 0, t0)
	var sk := skladowe(pol)
	if sk[mapa.indeks(ks)] != sk[mapa.indeks(kc)]:
		return _wynik(false, PackedVector2Array(), "cel nieosiągalny (inny obszar, np. za wodą lub otoczony przeszkodami)", 0, t0)
	if ks == kc:
		return _wynik(true, PackedVector2Array([cel]), "", 1, t0)
	_przygotuj()
	_pokolenie += 1
	var otw := _pokolenie * 2; var zamk := otw + 1
	var W := mapa.szer_komorek(); var H := mapa.wys_komorek()
	var rk := mapa.rozmiar_komorki()
	var kh := pol.koszt_wysokosci
	var si := mapa.indeks(ks); var ci := mapa.indeks(kc)
	var cx := kc.x; var cy := kc.y
	var kf := PackedFloat32Array(); var ki := PackedInt32Array()
	_g[si] = 0.0; _stan[si] = otw; _skad[si] = -1
	_hwstaw(kf, ki, _hdist(ks.x, ks.y, cx, cy, rk), si)
	var odw := 0
	var znaleziono := false
	while not ki.is_empty():
		var i := ki[0]
		_hzdejmij(kf, ki)
		if _stan[i] == zamk: continue
		_stan[i] = zamk
		odw += 1
		if i == ci:
			znaleziono = true; break
		var x := i % W; var y := i / W
		var gi := _g[i]; var hi := _hc[i]
		for d in 8:
			var nx: int = x + DX[d]; var ny: int = y + DY[d]
			if nx < 0 or ny < 0 or nx >= W or ny >= H: continue
			var ni := ny * W + nx
			if pr[ni] == 0 or _stan[ni] == zamk: continue
			var dl := rk
			if d >= 4:
				if pr[y * W + nx] == 0 or pr[ny * W + x] == 0: continue
				dl = rk * SQRT2
			var ng := gi + dl + kh * absf(_hc[ni] - hi)
			if _stan[ni] != otw or ng < _g[ni]:
				_g[ni] = ng; _skad[ni] = i; _stan[ni] = otw
				_hwstaw(kf, ki, ng + _hdist(nx, ny, cx, cy, rk), ni)
	if not znaleziono:
		return _wynik(false, PackedVector2Array(), "brak trasy", odw, t0)
	var komorki: Array[Vector2i] = []
	var j := ci
	while j != si:
		komorki.append(Vector2i(j % W, j / W)); j = _skad[j]
	komorki.reverse()
	var pkt := _wygladz(start, komorki, cel, pol, pr)
	return _wynik(true, pkt, "", odw, t0)


static func _hdist(ax: int, ay: int, bx: int, by: int, rk: float) -> float:
	var dx := absi(ax - bx); var dy := absi(ay - by)
	return (maxi(dx, dy) + (SQRT2 - 1.0) * mini(dx, dy)) * rk


func _najblizsza_przechodnia(k: Vector2i, pr: PackedByteArray) -> Vector2i:
	var W := mapa.szer_komorek(); var H := mapa.wys_komorek()
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := k + Vector2i(dx, dy)
				if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and pr[n.y * W + n.x] == 1: return n
	return Vector2i(-1, -1)


## Widoczność po komórkach (próbkowanie co 1/4 komórki) – odcinek nie może przechodzić przez komórki nieprzechodnie.
func widoczne(a: Vector2, b: Vector2, pol: PolitykaRuchu, pr: PackedByteArray = PackedByteArray()) -> bool:
	if pr.is_empty(): pr = przechodniosc(pol)
	var W := mapa.szer_komorek()
	var dl := a.distance_to(b)
	var kroki := maxi(1, int(ceil(dl / (mapa.rozmiar_komorki() * 0.25))))
	var poprz := mapa.komorka(a)
	for s in range(1, kroki + 1):
		var k := mapa.komorka(a.lerp(b, float(s) / kroki))
		if k == poprz: continue
		if k.x < 0 or pr[k.y * W + k.x] == 0: return false
		if poprz.x >= 0 and k.x != poprz.x and k.y != poprz.y:
			if pr[poprz.y * W + k.x] == 0 or pr[k.y * W + poprz.x] == 0:
				return false
		poprz = k
	return true


func _wygladz(start: Vector2, komorki: Array[Vector2i], cel: Vector2, pol: PolitykaRuchu, pr: PackedByteArray) -> PackedVector2Array:
	var pkt: Array[Vector2] = [start]
	for k in komorki: pkt.append(mapa.srodek(k))
	pkt[pkt.size() - 1] = cel
	var kum := PackedFloat32Array([0.0])
	for k in range(1, pkt.size()):
		kum.append(kum[k - 1] + koszt_odcinka(pkt[k - 1], pkt[k], pol))
	var out := PackedVector2Array()
	var i := 0
	while i < pkt.size() - 1:
		# najdalszy punkt osiągalny skrótem – skan do przodu do pierwszego niepowodzenia (koszt liniowy w długości trasy)
		var j := i + 1
		while j + 1 < pkt.size() and widoczne(pkt[i], pkt[j + 1], pol, pr) \
				and koszt_odcinka(pkt[i], pkt[j + 1], pol) <= kum[j + 1] - kum[i] + 1e-3:
			j += 1
		out.append(pkt[j]); i = j
	return out


## Koszt odcinka: długość + koszt_wysokosci · suma |Δh| (próbkowanie co 1/4 komórki).
func koszt_odcinka(a: Vector2, b: Vector2, pol: PolitykaRuchu) -> float:
	var dl := a.distance_to(b)
	if pol.koszt_wysokosci == 0.0: return dl
	var n := maxi(1, int(ceil(dl / (mapa.rozmiar_komorki() * 0.25))))
	var dh := 0.0
	var hp := mapa.wysokosc(a)
	for s in range(1, n + 1):
		var h := mapa.wysokosc(a.lerp(b, float(s) / n))
		dh += absf(h - hp); hp = h
	return dl + pol.koszt_wysokosci * dh


func _wynik(ok: bool, s: PackedVector2Array, powod: String, odw: int, t0: int) -> Dictionary:
	var t := Time.get_ticks_usec() - t0
	statystyka.czas_us += t; statystyka.odwiedzone += odw
	return {"ok": ok, "sciezka": s, "powod": powod, "odwiedzone": odw, "czas_us": t}


static func _hwstaw(kf: PackedFloat32Array, ki: PackedInt32Array, f: float, v: int) -> void:
	kf.append(f); ki.append(v)
	var i := kf.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if kf[i] < kf[p]:
			var tf := kf[i]; kf[i] = kf[p]; kf[p] = tf
			var tv := ki[i]; ki[i] = ki[p]; ki[p] = tv
			i = p
		else:
			break


static func _hzdejmij(kf: PackedFloat32Array, ki: PackedInt32Array) -> void:
	var n := kf.size() - 1
	kf[0] = kf[n]; ki[0] = ki[n]
	kf.resize(n); ki.resize(n)
	var i := 0
	while true:
		var l := 2 * i + 1; var r := l + 1; var m := i
		if l < n and kf[l] < kf[m]: m = l
		if r < n and kf[r] < kf[m]: m = r
		if m == i: break
		var tf := kf[i]; kf[i] = kf[m]; kf[m] = tf
		var tv := ki[i]; ki[i] = ki[m]; ki[m] = tv
		i = m
