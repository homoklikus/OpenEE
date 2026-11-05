class_name ArchiwumSSA
extends RefCounted
## Archiwum SSA Empire Earth ('rass'), tylko odczyt. Format: docs/FORMATY.md §SSA.

var sciezka: String = ""
var wpisy := {}            # klucz (małe litery, '/') -> [poczatek, rozmiar, nazwa_oryginalna]
var _f: FileAccess = null

# cp1250 → Unicode dla bajtów 0x80–0xFF używanych w polskich nazwach (pozostałe: Latin-1)
const CP1250 := {0x8C: "Ś", 0x8F: "Ź", 0x9C: "ś", 0x9F: "ź", 0xA3: "Ł", 0xA5: "Ą", 0xAF: "Ż", 0xB3: "ł",
	0xB9: "ą", 0xBF: "ż", 0xC6: "Ć", 0xCA: "Ę", 0xD1: "Ń", 0xD3: "Ó", 0xE6: "ć", 0xEA: "ę", 0xF1: "ń", 0xF3: "ó"}


static func _napis_cp1250(b: PackedByteArray) -> String:
	var s := ""
	for x in b:
		if x == 0:
			break
		s += CP1250.get(x, char(x))
	return s


func otworz(p: String) -> Error:
	sciezka = p
	_f = FileAccess.open(p, FileAccess.READ)
	if _f == null:
		return FileAccess.get_open_error()
	var syg := _f.get_buffer(4)
	if syg.get_string_from_ascii() != "rass":
		return ERR_FILE_UNRECOGNIZED
	var _wersja := _f.get_32()
	var _zero := _f.get_32()
	var granica := _f.get_32()
	while _f.get_position() < granica:
		var n := _f.get_32()
		var nazwa := _napis_cp1250(_f.get_buffer(n))
		var pocz := _f.get_32()
		var kon := _f.get_32()
		var rozm := _f.get_32()
		if kon - pocz + 1 != rozm:
			return ERR_FILE_CORRUPT
		wpisy[nazwa.replace("\\", "/").to_lower()] = [pocz, rozm, nazwa]
	return OK


func zawiera(klucz: String) -> bool:
	return wpisy.has(klucz.replace("\\", "/").to_lower())


func czytaj_surowe(klucz: String) -> PackedByteArray:
	var w: Array = wpisy.get(klucz.replace("\\", "/").to_lower(), [])
	if w.is_empty():
		return PackedByteArray()
	_f.seek(w[0])
	return _f.get_buffer(w[1])


func czytaj(klucz: String) -> PackedByteArray:
	return DCL.moze_rozpakuj(czytaj_surowe(klucz))
