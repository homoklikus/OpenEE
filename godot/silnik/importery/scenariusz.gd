class_name ScenariuszEE
extends RefCounted
## Scenariusz SCN Empire Earth (wersje 0.231 – EE i 0.250 – AoC): kawałki, teren (kawałek 4), gracze i obiekty (kawałek 5).
## Format: docs/FORMATY.md §5–6 i docs/FORMATY_ETAP2.md. Implementacja odpowiada narzedzia/eeformaty/{scn,gracze}.py;
## opis rekordu jednostki pochodzi z dane/gramatyka_jednostki.json (wspólny z Pythonem).

const WYMAGANE := [1, 2, 3, 4, 5, 6, 7, 10, 11]

var kawalki: Array = []          # [{tag, major, minor, offset, rozmiar, dane(surowe)}]
var teren: Dictionary = {}
var gracze: Array = []
var blad: String = ""
var wersja: int = 0          # wersja kawałka 5 (231 – Empire Earth 1.x, 250 – The Art of Conquest)


static func _napisy_ok(d: PackedByteArray, q: int) -> int:
	for i in range(7):
		if q + 4 > d.size():
			return -1
		var k := d.decode_u32(q)
		if k > (1 << 20):
			return -1
		q += 4 + k
	return q + 4


func _proba(d: PackedByteArray, p: int) -> Array:
	var n := d.decode_s32(p)
	if n < 9 or n > 16 or p + 4 + 4 * n > d.size():
		return []
	var ids: Array = []
	for i in range(n):
		var v := d.decode_u32(p + 4 + 4 * i)
		if v < 1 or v > 12:
			return []
		ids.append(v)
	for w in WYMAGANE:
		if not ids.has(w):
			return []
	if ids.count(4) != 1:
		return []
	var q := _napisy_ok(d, p + 4 + 4 * n)
	if q < 0:
		return []
	var out: Array = []
	for cid in ids:
		if q + 16 > d.size():
			return []
		var tag := d.decode_s32(q + 8)
		var sz := d.decode_u32(q + 12)
		if tag != cid or q + 16 + sz > d.size():
			return []
		out.append({"tag": tag, "major": d.decode_u32(q), "minor": d.decode_u32(q + 4), "offset": q, "rozmiar": sz,
			"dane": d.slice(q + 16, q + 16 + sz)})
		q += 16 + sz
	return out if q == d.size() else []


func wczytaj(d: PackedByteArray) -> bool:
	var znal: Array = []
	var lim: int = min(d.size() - 8, 1 << 20)
	var p := 4
	while p < lim:
		if d[p] <= 16 and d[p + 1] == 0 and d[p + 4] >= 1 and d[p + 4] <= 3:
			var r := _proba(d, p)
			if not r.is_empty():
				znal.append(r)
		p += 1
	if znal.size() != 1:
		blad = "SCN: kandydatów listy kawałków: %d" % znal.size()
		return false
	kawalki = znal[0]
	return true


func wersja_kawalka(tag: int) -> int:
	for k in kawalki:
		if k.tag == tag:
			return int(k.minor)
	return 0


func kawalek(tag: int) -> PackedByteArray:
	for k in kawalki:
		if k.tag == tag:
			return DCL.moze_rozpakuj(k.dane)
	return PackedByteArray()


static func _wiersze(n: int, lo: int, hi: int, gorna: int, postoj: int) -> Array:
	var out: Array = []
	var dl := true; var dh := true; var sl := 0; var sh := 0
	for i in range(n):
		out.append(Vector2i(lo, hi))
		if dl:
			if lo == 0:
				sl += 1
				if sl == postoj: dl = false
			else: lo -= 1
		else: lo += 1
		if dh:
			if hi == gorna:
				sh += 1
				if sh == postoj: dh = false
			else: hi += 1
		else: hi -= 1
	return out


## Kawałek 4 → teren: A, B, wiersze pól/punktów, PackedByteArray teren/flagi/klasa, PackedFloat32Array wysokość.
func czytaj_teren() -> bool:
	var d := kawalek(4)
	if d.is_empty():
		blad = "brak kawałka 4"; return false
	var A := d.decode_s32(0); var B := d.decode_s32(4); var K := d.decode_u32(8)
	var T := 2 * A * B + A + B
	var V := 2 * A * B + 3 * A + 3 * B + 1
	var blk := ((K + 1) / 2) * 4
	var p := 12
	for i in range(T):
		p += 4 + blk
		if d.decode_u32(p) != 0:
			blad = "EEMap: obiekty przypięte do pól – nieobsługiwane"; return false
		p += 4
	if d.decode_s32(p) != A or d.decode_s32(p + 4) != B:
		blad = "EEMap: wymiary siatki ≠ nagłówek"; return false
	p += 8
	var ter := PackedByteArray(); ter.resize(T)
	var fl := PackedByteArray(); fl.resize(T)
	for i in range(T):
		ter[i] = d[p + 2 * i]; fl[i] = d[p + 2 * i + 1]
	p += 2 * T
	var wys := PackedFloat32Array(); wys.resize(V)
	var kl := PackedByteArray(); kl.resize(V)
	for i in range(V):
		wys[i] = d.decode_float(p); kl[i] = d[p + 4]; p += 5
	p += 16
	if p != d.size():
		blad = "EEMap: %d nadmiarowych bajtów" % (d.size() - p); return false
	var N := A + B
	var rp := _wiersze(N, B - 1, B, N - 1, 1)
	var rv := _wiersze(N + 1, B - 1, B + 1, N, 2)
	var bt := PackedInt32Array(); var bv := PackedInt32Array()
	var acc := 0
	for w in rp:
		bt.append(acc); acc += w.y - w.x + 1
	if acc != T:
		blad = "EEMap: liczba pól ≠ geometria"; return false
	acc = 0
	for w in rv:
		bv.append(acc); acc += w.y - w.x + 1
	if acc != V:
		blad = "EEMap: liczba punktów ≠ geometria"; return false
	teren = {"A": A, "B": B, "N": N, "rp": rp, "rv": rv, "bt": bt, "bv": bv, "teren": ter, "flagi": fl,
		"wysokosc": wys, "klasa": kl}
	return true


func indeks_pola(r: int, c: int) -> int:
	var w: Vector2i = teren.rp[r]
	return teren.bt[r] + c - w.x if c >= w.x and c <= w.y else -1


func indeks_punktu(r: int, c: int) -> int:
	if r < 0 or r >= teren.rv.size():
		return -1
	var w: Vector2i = teren.rv[r]
	return teren.bv[r] + c - w.x if c >= w.x and c <= w.y else -1


# ---------------- kawałek 5: gracze i obiekty ----------------
class _R:
	var d: PackedByteArray
	var o: int
	var zly := false
	func _init(dane: PackedByteArray, off: int) -> void:
		d = dane; o = off
	func get_t(t: String) -> Variant:
		if zly:
			return 0
		match t:
			"I":
				if o + 4 > d.size(): zly = true; return 0
				var v := d.decode_u32(o); o += 4; return v
			"i":
				if o + 4 > d.size(): zly = true; return 0
				var v2 := d.decode_s32(o); o += 4; return v2
			"f":
				if o + 4 > d.size(): zly = true; return 0.0
				var v3 := d.decode_float(o); o += 4; return v3
			"B":
				if o + 1 > d.size(): zly = true; return 0
				var v4 := d[o]; o += 1; return v4
			"H":
				if o + 2 > d.size(): zly = true; return 0
				var v5 := d.decode_u16(o); o += 2; return v5
			"wstr":
				var n := d.decode_u32(o) if o + 4 <= d.size() else 99999
				if n > 4096 or o + 4 + n > d.size(): zly = true; return PackedByteArray()
				var s := d.slice(o + 4, o + 4 + n); o += 4 + n; return s
		if t.begins_with("raw:"):
			var k := int(t.substr(4))
			if o + k > d.size(): zly = true; return PackedByteArray()
			var s2 := d.slice(o, o + k); o += k; return s2
		zly = true
		return 0


static var _gram: Array = []


static func _gramatyka(katalog_openee: String) -> Array:
	if _gram.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(katalog_openee.path_join("dane/gramatyka_jednostki.json")))
		_gram = j.jednostka if j else []
	return _gram


## Warunek wersji pola gramatyki: {"od": wersja, "zapis": bool} (etap 3 – EE 1.x = 231, AoC = 250).
static func _jest(el: Array, wersja: int) -> bool:
	if el.size() < 3 or not el[2] is Dictionary:
		return true
	return wersja >= int(el[2].get("od", 0))


static func _jednostka(r: _R, g: Array, wersja: int = 250) -> Dictionary:
	var u := {}
	for el in g:
		var k: String = el[0]
		if k == "koniec_jesli_prosty":
			if int(u.get("complex", 0)) == 0:
				return u
		elif k == "lista":
			var n: int = r.get_t("i")
			if n < 0 or n > 100000:
				r.zly = true; return u
			for j in range(n):
				for pole in el[2]:
					if _jest(pole, wersja):
						r.get_t(pole[0])
		elif k == "cele":
			var n2: int = r.get_t("I")
			for j in range(n2):
				if int(r.get_t("I")) != 0:
					r.zly = true; return u   # polimorficzny element – format nieodtworzony
				r.get_t("I"); r.get_t("I"); r.get_t("B")
		else:
			if not _jest(el, wersja):
				continue
			var v = r.get_t(k)
			if el[1] in ["type", "valid", "complex", "X", "Y", "id", "angle", "pos.x", "pos.y", "pos.z", "c174"]:
				u[el[1]] = v
			if el[1] == "transform":
				u["transform"] = v
			if el[1] == "valid" and int(v) == 0:
				return u
		if r.zly:
			return u
	return u


## Gracz od offsetu `off`; przy `czesciowo` nieczytelny rekord jednostki (polimorficzna lista celów) kończy odczyt
## jednostek gracza – wynik ma wtedy "niepelny" = offset przerwania (kolejny gracz szukany za nim).
func _gracz(d: PackedByteArray, off: int, g: Array, wer: int = 250, czesciowo := false) -> Dictionary:
	var r := _R.new(d, off)
	var typ: int = r.get_t("i")
	if typ != 0 and typ != 1:
		return {}
	for i in range(10): r.get_t("I")
	var n: int = r.get_t("I"); var l20: int = r.get_t("I")
	if n > 5000 or r.zly:
		return {}
	for i in range(n):
		r.get_t("I"); r.get_t("wstr"); r.get_t("raw:64"); r.get_t("I")
		if r.zly: return {}
	r.get_t("B"); r.get_t("B"); r.get_t("I"); r.get_t("I")
	var kolor := Color(r.get_t("f"), r.get_t("f"), r.get_t("f"))
	var nz: PackedByteArray = r.get_t("wstr")
	if r.zly or nz.is_empty() or nz[nz.size() - 1] != 0:
		return {}
	for i in range(nz.size() - 1):
		if nz[i] < 32: return {}
	r.get_t("I")
	var jedn: Array = []
	for b in range(128):
		var k: int = r.get_t("I")
		if k > 100000 or r.zly: return {}
		for j in range(k):
			var start := r.o
			var u := _jednostka(r, g, wer)
			if r.zly:
				if not czesciowo:
					return {}
				return {"typ": typ, "kolor": kolor, "nazwa": TekstEE.cp1250(nz.slice(0, nz.size() - 1)),
					"jednostki": jedn, "kotwica": [n, l20], "koniec": start, "niepelny": start}
			jedn.append(u)
	r.get_t("B")
	if r.zly: return {}
	return {"typ": typ, "kolor": kolor, "nazwa": TekstEE.cp1250(nz.slice(0, nz.size() - 1)), "jednostki": jedn,
		"kotwica": [n, l20], "koniec": r.o}


func czytaj_graczy(katalog_openee: String) -> bool:
	var d := kawalek(5)
	if d.is_empty():
		blad = "brak kawałka 5"; return false
	var g := _gramatyka(katalog_openee)
	wersja = wersja_kawalka(5)
	var n := d.decode_u32(0)
	var gr := _gracz(d, 12, g, wersja, true)
	if gr.is_empty():
		blad = "kawałek 5: gracz 0 nieczytelny"; return false
	gracze = [gr]
	for i in range(1, n):
		var wz := PackedByteArray(); wz.resize(8)
		wz.encode_u32(0, gr.kotwica[0]); wz.encode_u32(4, gr.kotwica[1])
		var nast := {}
		var p: int = gr.koniec
		while nast.is_empty():
			p = _znajdz(d, wz, p)
			if p < 0: break
			var kand := p - 44
			if kand >= gr.koniec:
				nast = _gracz(d, kand, g, wersja, false)      # pierwszy kandydat wg położenia: pełny odczyt,
				if nast.is_empty():
					nast = _gracz(d, kand, g, wersja, true)   # a gdy się nie da – częściowy
			p += 1
		if nast.is_empty():
			blad = "kawałek 5: nie znaleziono gracza %d" % i; return false
		gr = nast
		gracze.append(gr)
	return true


static func _znajdz(d: PackedByteArray, wz: PackedByteArray, od: int) -> int:
	var p := od
	while true:
		p = d.find(wz[0], p)
		if p < 0 or p + wz.size() > d.size():
			return -1
		var ok := true
		for i in range(1, wz.size()):
			if d[p + i] != wz[i]:
				ok = false; break
		if ok:
			return p
		p += 1
	return -1
