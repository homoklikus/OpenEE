class_name TekstyDLL
extends RefCounted
## Tabele napisów (RT_STRING) z Language.dll – odczyt formatu PE bez uruchamiania kodu biblioteki.
## Wynik: słownik id → tekst. Identyfikatory zgodne z polami "Language ID" tabel db (np. dbobjects).

static func _rva_na_offset(sekcje: Array, rva: int) -> int:
	for s in sekcje:
		if rva >= s[0] and rva < s[0] + max(s[1], s[2]):
			return rva - s[0] + s[3]
	return -1


static func wczytaj(sciezka: String) -> Dictionary:
	var d := FileAccess.get_file_as_bytes(sciezka)
	if d.size() < 64 or d[0] != 0x4D or d[1] != 0x5A:
		return {}
	var pe := d.decode_u32(0x3C)
	var n_sek := d.decode_u16(pe + 6)
	var opt := pe + 24
	var rozm_opt := d.decode_u16(pe + 20)
	var magic := d.decode_u16(opt)
	var dd := opt + (96 if magic == 0x10B else 112)
	var res_rva := d.decode_u32(dd + 8 * 2)
	var sekcje: Array = []
	var st := opt + rozm_opt
	for i in range(n_sek):
		var s := st + 40 * i
		sekcje.append([d.decode_u32(s + 12), d.decode_u32(s + 8), d.decode_u32(s + 16), d.decode_u32(s + 20)])
	var baza := _rva_na_offset(sekcje, res_rva)
	if baza < 0:
		return {}
	var wynik := {}
	for e1 in _wpisy(d, baza, baza):
		if e1[0] != 6 or not e1[2]:
			continue
		for e2 in _wpisy(d, baza, baza + e1[1]):
			var blok: int = e2[0]
			var off: int = baza + e2[1]
			if e2[2]:
				var e3: Array = _wpisy(d, baza, off)
				if e3.is_empty(): continue
				off = baza + e3[0][1]
			var rva := d.decode_u32(off)
			var p := _rva_na_offset(sekcje, rva)
			for i in range(16):
				var n := d.decode_u16(p); p += 2
				if n > 0:
					wynik[(blok - 1) * 16 + i] = d.slice(p, p + 2 * n).get_string_from_utf16()
				p += 2 * n
	return wynik


static func _wpisy(d: PackedByteArray, baza: int, off: int) -> Array:
	var n := d.decode_u16(off + 12) + d.decode_u16(off + 14)
	var out: Array = []
	for i in range(n):
		var e := off + 16 + 8 * i
		var idn := d.decode_u32(e)
		var cel := d.decode_u32(e + 4)
		out.append([idn & 0x7FFFFFFF, cel & 0x7FFFFFFF, (cel & 0x80000000) != 0])
	return out
