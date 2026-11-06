class_name BazaDB
extends RefCounted
## Tabele db/*.dat (po rozpakowaniu PK01) – dekoder sterowany układem dane/uklad_db.json
## (wygenerowanym ze schematu EE DB Editor, GPLv3 – patrz dane/schemat_db_eedbeditor/ZRODLO.md).
## Kontrola: zużycie danych co do bajta, inaczej błąd.
##
## Etap 11 (docs/FORMATY_DB_EE_VS_AOC.md): dwa warianty formatu – The Art of Conquest ("aoc", układ bazowy, nadzbiór)
## i Empire Earth 1.0 ("ee"), różniące się w dbobjects (EE bez 3 pól: 1948 zamiast 1960 B) i dbcivilization (EE bez
## 46 końcowych pól: 416 zamiast 600 B) – dane/uklad_db_warianty.json. Wariant rozpoznawany ze struktury: rozmiar pliku
## = 4 + N × rozmiar rekordu wariantu; dane muszą pasować do dokładnie jednego wariantu (bez prób „jak AoC, a przy
## błędzie pomiń”). Tabele bez opisu wariantów mają w obu wersjach ten sam układ (wynik „wspolny”). Każdy odczyt jest
## sprawdzany względem rozmiaru danych – uszkodzony plik daje czytelny błąd, nie błąd silnika.

const WARIANTY := ["aoc", "ee"]

static var _uklad: Dictionary = {}
static var _warianty: Dictionary = {}


static func _wczytaj_uklad(katalog_openee: String) -> void:
	if _uklad.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(katalog_openee.path_join("dane/uklad_db.json")))
		_uklad = j.get("tabele", {}) if j else {}
		var w = JSON.parse_string(FileAccess.get_file_as_string(katalog_openee.path_join("dane/uklad_db_warianty.json")))
		_warianty = w if w is Dictionary else {}


## Układ pól tabeli dla wariantu ("aoc" – bazowy; "ee" – bez pól z listy „pomin”).
static func uklad(tabela: String, wariant: String, katalog_openee: String) -> Array:
	_wczytaj_uklad(katalog_openee)
	var pola: Array = _uklad.get(tabela, [])
	var opis: Dictionary = _warianty.get(wariant, {}).get(tabela, {})
	var pomin: Array = opis.get("pomin", [])
	if pomin.is_empty():
		return pola
	return pola.filter(func(f): return not (f[0] in pomin))


## Stały rozmiar rekordu (bajty) albo -1, gdy układ ma łańcuchy dynamiczne.
static func rozmiar_rekordu(pola: Array) -> int:
	var s := 0
	for f in pola:
		if String(f[2]) == "DYNAMIC_STRING":
			return -1
		s += int(f[1])
	return s


## Tabele z opisem wariantów w dane/uklad_db_warianty.json.
static func ma_warianty(tabela: String, katalog_openee: String) -> bool:
	_wczytaj_uklad(katalog_openee)
	for w in WARIANTY:
		if _warianty.get(w, {}).has(tabela):
			return true
	return false


## Rozpoznanie wariantu ze struktury danych: {"wariant": "aoc"|"ee"|"wspolny"} albo {"blad": opis}.
static func rozpoznaj(dane: PackedByteArray, tabela: String, katalog_openee: String) -> Dictionary:
	_wczytaj_uklad(katalog_openee)
	if not _uklad.has(tabela):
		return {"blad": "brak układu tabeli %s" % tabela}
	if dane.size() < 4:
		return {"blad": "%s: plik krótszy niż nagłówek (%d B)" % [tabela, dane.size()]}
	if not ma_warianty(tabela, katalog_openee):
		return {"wariant": "wspolny"}
	var n := dane.decode_u32(0)
	var pasuja: Array = []
	var oczek: Array = []
	for w in WARIANTY:
		var r := rozmiar_rekordu(uklad(tabela, w, katalog_openee))
		oczek.append("%s: %d B" % [w, r])
		if r > 0 and n > 0 and 4 + n * r == dane.size():
			pasuja.append(w)
	if pasuja.size() == 1:
		return {"wariant": pasuja[0]}
	if n == 0 and dane.size() == 4:
		return {"wariant": "wspolny"}
	return {"blad": "%s: nieobsługiwany wariant formatu – %d B, N = %d, rekord %s (oczekiwano %s)" % [
		tabela, dane.size(), n, ("%.2f B" % (float(dane.size() - 4) / n)) if n > 0 else "?", ", ".join(oczek)]}


## Zwraca {"rekordy": Array[Dictionary], "wariant": String} lub {"blad": String}.
## `wariant` = "" – rozpoznanie ze struktury; jawny wariant ("aoc"/"ee") – dekodowanie tym układem (testy, narzędzia).
static func dekoduj(dane: PackedByteArray, tabela: String, katalog_openee: String, wariant: String = "") -> Dictionary:
	_wczytaj_uklad(katalog_openee)
	if not _uklad.has(tabela):
		return {"blad": "brak układu tabeli %s" % tabela}
	var w := wariant
	if w == "":
		var rw := rozpoznaj(dane, tabela, katalog_openee)
		if rw.has("blad"):
			return rw
		w = rw.wariant
	var pola := uklad(tabela, "aoc" if w == "wspolny" else w, katalog_openee)
	if dane.size() < 4:
		return {"blad": "%s: plik krótszy niż nagłówek" % tabela}
	var n := dane.decode_u32(0)
	var p := 4
	var rek: Array = []
	for i in range(n):
		var vals: Array = []
		var r := {}
		for f in pola:
			var typ: String = f[2]
			var v: Variant
			var sz: int
			if typ == "DYNAMIC_STRING":
				sz = int(vals[int(f[3])])
			elif typ == "STRING" or typ == "FLOAT":
				sz = int(f[1]) if typ == "STRING" else 4
			else:
				sz = 1 if int(f[1]) == 1 else 4
			if sz < 0 or p + sz > dane.size():
				return {"blad": "%s (%s): rekord %d z %d, pole „%s”: odczyt %d B od %d poza danymi (%d B)" % [
					tabela, w, i, n, f[0], sz, p, dane.size()]}
			if typ == "STRING" or typ == "DYNAMIC_STRING":
				if sz > 0 and dane[p] != 0xCC and dane[p] != 0xFF:
					v = TekstEE.cp1250(dane.slice(p, p + sz))      # Windows-1250 (polska wersja)
				else:
					v = ""
			elif typ == "FLOAT":
				v = dane.decode_float(p)
			elif sz == 1:
				v = dane[p]
			else:
				v = dane.decode_s32(p)
			p += sz
			vals.append(v)
			r[f[0]] = v
		rek.append(r)
	if p != dane.size():
		return {"blad": "%s (%s): zużyto %d z %d bajtów" % [tabela, w, p, dane.size()]}
	return {"rekordy": rek, "wariant": w}


## Indeks rekordów po polu (np. "ID").
static func indeks(rekordy: Array, pole: String = "ID") -> Dictionary:
	var d := {}
	for r in rekordy:
		d[int(r[pole])] = r
	return d
