class_name BazaDB
extends RefCounted
## Tabele db/*.dat (po rozpakowaniu PK01) – dekoder sterowany układem dane/uklad_db.json
## (wygenerowanym ze schematu EE DB Editor, GPLv3 – patrz dane/schemat_db_eedbeditor/ZRODLO.md).
## Kontrola: zużycie danych co do bajta, inaczej błąd.

static var _uklad: Dictionary = {}


static func _wczytaj_uklad(katalog_openee: String) -> void:
	if _uklad.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(katalog_openee.path_join("dane/uklad_db.json")))
		_uklad = j.get("tabele", {}) if j else {}


## Zwraca {"rekordy": Array[Dictionary]} lub {"blad": String}
static func dekoduj(dane: PackedByteArray, tabela: String, katalog_openee: String) -> Dictionary:
	_wczytaj_uklad(katalog_openee)
	if not _uklad.has(tabela):
		return {"blad": "brak układu tabeli %s" % tabela}
	var pola: Array = _uklad[tabela]
	var n := dane.decode_u32(0)
	var p := 4
	var rek: Array = []
	for i in range(n):
		var vals: Array = []
		var r := {}
		for f in pola:
			var typ: String = f[2]
			var v: Variant
			if typ == "STRING" or typ == "DYNAMIC_STRING":
				var sz: int = int(vals[int(f[3])]) if typ == "DYNAMIC_STRING" else int(f[1])
				if sz > 0 and dane[p] != 0xCC and dane[p] != 0xFF:
					v = TekstEE.cp1250(dane.slice(p, p + sz))      # Windows-1250 (polska wersja)
				else:
					v = ""
				p += sz
			elif typ == "FLOAT":
				v = dane.decode_float(p); p += 4
			elif int(f[1]) == 1:
				v = dane[p]; p += 1
			else:
				v = dane.decode_s32(p); p += 4
			vals.append(v)
			r[f[0]] = v
		rek.append(r)
	if p != dane.size():
		return {"blad": "%s: zużyto %d z %d bajtów" % [tabela, p, dane.size()]}
	return {"rekordy": rek}


## Indeks rekordów po polu (np. "ID").
static func indeks(rekordy: Array, pole: String = "ID") -> Dictionary:
	var d := {}
	for r in rekordy:
		d[int(r[pole])] = r
	return d
