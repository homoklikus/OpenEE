class_name DCL
extends RefCounted
## Dekompresja PKWARE DCL „implode” + kontener PK01 (Empire Earth).
## Implementacja OpenEE na podstawie publicznego opisu algorytmu („blast”, zlib/contrib).
## Referencyjna wersja Python: narzedzia/eeformaty/dcl.py – wyniki porównywane w testach.

const MAXBITS := 13
const LIT_REP := [11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8, 9, 7, 6, 7, 8, 7, 6,
	55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5, 7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9,
	8, 25, 11, 8, 11, 9, 12, 8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
	44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45, 44, 173]
const LEN_REP := [2, 35, 36, 53, 38, 23]
const DIST_REP := [2, 20, 53, 230, 247, 151, 248]
const LEN_BASE := [3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264]
const LEN_EXTRA := [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]

static var _lit: Array = []
static var _len: Array = []
static var _dist: Array = []


static func _tablica(rep: Array, n: int) -> Array:
	var dl := PackedInt32Array()
	for b in rep:
		for i in range((b >> 4) + 1):
			dl.append(b & 15)
	assert(dl.size() == n)
	var count := PackedInt32Array(); count.resize(MAXBITS + 1)
	for l in dl:
		count[l] += 1
	var offs := PackedInt32Array(); offs.resize(MAXBITS + 2)
	for i in range(1, MAXBITS + 1):
		offs[i + 1] = offs[i] + count[i]
	var sym := PackedInt32Array(); sym.resize(n)
	for s in range(n):
		if dl[s] != 0:
			sym[offs[dl[s]]] = s
			offs[dl[s]] += 1
	return [count, sym]


static func _inicjuj() -> void:
	if _lit.is_empty():
		_lit = _tablica(LIT_REP, 256)
		_len = _tablica(LEN_REP, 16)
		_dist = _tablica(DIST_REP, 64)


## Strumień bitów (LSB-first).
class _Bity:
	var d: PackedByteArray
	var pos: int
	var buf: int = 0
	var cnt: int = 0

	func _init(dane: PackedByteArray, p: int) -> void:
		d = dane; pos = p

	func bity(n: int) -> int:
		while cnt < n:
			if pos >= d.size():
				push_error("DCL: koniec danych")
				return -1
			buf |= d[pos] << cnt
			pos += 1
			cnt += 8
		var v := buf & ((1 << n) - 1)
		buf >>= n
		cnt -= n
		return v

	func dekoduj(h: Array) -> int:
		var count: PackedInt32Array = h[0]
		var sym: PackedInt32Array = h[1]
		var code := 0
		var first := 0
		var index := 0
		for l in range(1, 14):
			code |= bity(1) ^ 1
			var c := count[l]
			if code < first + c:
				return sym[index + code - first]
			index += c
			first = (first + c) << 1
			code <<= 1
		return -1


static var _lit_t := PackedInt32Array()
static var _len_t := PackedInt32Array()
static var _dist_t := PackedInt32Array()


## Tablica dekodowania: indeks = najbliższe 13 bitów strumienia (LSB-first), wartość = symbol | (długość << 16).
## Kody kanoniczne jak w _Bity.dekoduj (bit czytany jest negowany, pierwszy przeczytany = najstarszy bit kodu).
static func _tablica_szybka(h: Array) -> PackedInt32Array:
	var count: PackedInt32Array = h[0]; var sym: PackedInt32Array = h[1]
	var t := PackedInt32Array(); t.resize(1 << MAXBITS); t.fill(-1)
	var first := 0; var index := 0
	for l in range(1, MAXBITS + 1):
		var c := count[l]
		for j in c:
			var kod := first + j
			var v := 0
			for k in l:
				v |= (1 - ((kod >> (l - 1 - k)) & 1)) << k
			var wpis := sym[index + j] | (l << 16)
			for hi in (1 << (MAXBITS - l)):
				t[v | (hi << l)] = wpis
		index += c
		first = (first + c) << 1
	return t


## Etap 4: dekoder szybki (tablice 13-bitowe, lokalny bufor bitów, kopiowanie dopasowań przez append_array) –
## wynik identyczny z wzorcowym (test „E4 DCL”), ok. kilkukrotnie szybszy (FORMATY_ETAP4.md §6).
static func rozpakuj_strumien(dane: PackedByteArray, start: int, oczekiwany: int = -1) -> PackedByteArray:
	_inicjuj()
	if _lit_t.is_empty():
		_lit_t = _tablica_szybka(_lit); _len_t = _tablica_szybka(_len); _dist_t = _tablica_szybka(_dist)
	var out := PackedByteArray()
	var sz := dane.size()
	if start + 2 > sz:
		push_error("DCL: koniec danych"); return out
	var lit := dane[start]; var dict_bits := dane[start + 1]
	if lit > 1 or dict_bits < 4 or dict_bits > 6:
		push_error("DCL: niepoprawny nagłówek")
		return out
	var pos := start + 2
	var buf := 0; var cnt := 0
	var maska := (1 << MAXBITS) - 1
	var n := 0
	while true:
		while cnt <= 48 and pos < sz:
			buf |= dane[pos] << cnt; pos += 1; cnt += 8
		if cnt <= 0:
			push_error("DCL: koniec danych"); break
		var flaga := buf & 1
		buf >>= 1; cnt -= 1
		if flaga == 1:
			var w := _len_t[buf & maska]
			if w < 0: break
			var l := w >> 16; buf >>= l; cnt -= l
			var sym := w & 0xFFFF
			var ex: int = LEN_EXTRA[sym]
			var ln: int = LEN_BASE[sym] + (buf & ((1 << ex) - 1))
			buf >>= ex; cnt -= ex
			if ln == 519:
				break
			var db := 2 if ln == 2 else dict_bits
			var wd := _dist_t[buf & maska]
			if wd < 0: break
			var ld := wd >> 16; buf >>= ld; cnt -= ld
			var dist := ((wd & 0xFFFF) << db) + (buf & ((1 << db) - 1)) + 1
			buf >>= db; cnt -= db
			if dist > n:
				push_error("DCL: odległość poza buforem")
				break
			if dist >= ln:
				out.append_array(out.slice(n - dist, n - dist + ln))
			else:
				for i in ln:
					out.append(out[n - dist + i])
			n += ln
		else:
			var b: int
			if lit == 1:
				var wl := _lit_t[buf & maska]
				if wl < 0: break
				var ll := wl >> 16; buf >>= ll; cnt -= ll
				b = wl & 0xFFFF
			else:
				b = buf & 0xFF; buf >>= 8; cnt -= 8
			out.append(b)
			n += 1
	if cnt < 0:
		push_error("DCL: koniec danych")
	return out


## Dekoder wzorcowy (etap 1, bit po bicie) – zachowany do testów zgodności i pomiarów.
static func rozpakuj_strumien_wzorcowy(dane: PackedByteArray, start: int, oczekiwany: int = -1) -> PackedByteArray:
	_inicjuj()
	var s := _Bity.new(dane, start)
	var lit := s.bity(8)
	var dict_bits := s.bity(8)
	var out := PackedByteArray()
	if lit > 1 or dict_bits < 4 or dict_bits > 6:
		push_error("DCL: niepoprawny nagłówek")
		return out
	if oczekiwany > 0:
		out.resize(oczekiwany)
	var n := 0
	while true:
		if s.bity(1) == 1:
			var sym := s.dekoduj(_len)
			if sym < 0:
				break
			var ln: int = LEN_BASE[sym] + s.bity(LEN_EXTRA[sym])
			if ln == 519:
				break
			var db := 2 if ln == 2 else dict_bits
			var dist := (s.dekoduj(_dist) << db) + s.bity(db) + 1
			if dist > n:
				push_error("DCL: odległość poza buforem")
				break
			if out.size() < n + ln:
				out.resize(max(out.size() * 2, n + ln))
			for i in range(ln):
				out[n] = out[n - dist]
				n += 1
		else:
			var b := s.dekoduj(_lit) if lit == 1 else s.bity(8)
			if out.size() < n + 1:
				out.resize(max(out.size() * 2, 1024))
			out[n] = b
			n += 1
	out.resize(n)
	return out


static func czy_pk01(dane: PackedByteArray) -> bool:
	return dane.size() >= 12 and dane[0] == 0x50 and dane[1] == 0x4B and dane[2] == 0x30 and dane[3] == 0x31


static func rozpakuj_pk01(dane: PackedByteArray) -> PackedByteArray:
	var rozmiar := dane.decode_u32(4)
	var out := rozpakuj_strumien(dane, 12, rozmiar)
	if out.size() != rozmiar:
		push_error("PK01: rozmiar %d ≠ deklarowany %d" % [out.size(), rozmiar])
	return out


static func moze_rozpakuj(dane: PackedByteArray) -> PackedByteArray:
	return rozpakuj_pk01(dane) if czy_pk01(dane) else dane
