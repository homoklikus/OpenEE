class_name EpokiDB
extends RefCounted
## Dekodery tabel epok i efektów EE/AoC (etap 8, RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md § 1) – odpowiednik
## narzedzia/eeformaty/epoki.py. Tabele nie mają nagłówka „u32 N + N rekordów”, więc nie przechodzą przez BazaDB.
## * dbtechtree: 15 grup „i32 liczba_dzieci, rekord epoki, dzieci”; rekord 272 B + 4 B × „Num of tech builders”,
## * dbevents: NAME 100 B, i32 sekwencja, i32 n, n × i32 ID efektu (indeks rekordu = „Event ID” z dbtechtree),
## * dbeffects: 22 pola × 4 B (88 B), kolejność schematu EE DB Editor.
## Kontrola: zużycie danych co do bajta, inaczej pusty wynik i komunikat.
##
## Etap 11 (docs/FORMATY_DB_EE_VS_AOC.md § 4.3): Empire Earth 1.0 ma krótsze rekordy niż AoC –
## * dbtechtree: 268 B zamiast 272 (EE: 2 pola BOOLEAN + wypełnienie pod +244, brak dwóch BOOLEAN AoC i pola +248;
##   „Epoch number” pod +248 zamiast +252, „Num of tech builders” pod +264 zamiast +268),
## * dbeffects: 68 B (17 pól) zamiast 88 B (22) – pola 0–16 wspólne.
## Wariant rozpoznawany ze struktury (pełne, co do bajta, zużycie pliku / podzielność); dane muszą pasować do
## dokładnie jednego wariantu, inaczej pusty wynik i komunikat. `wariant_techtree` / `wariant_efektow` – wynik.

const REKORD_TECH := 272                     # AoC (zgodność z kodem etapu 8)
const REKORD_EFEKTU := 88                    # AoC
## Formaty rekordu dbtechtree: rozmiar, przesunięcie „Epoch number”, przesunięcie „Num of tech builders”.
const TECH := {"aoc": {"rekord": 272, "epoka": 252, "budowniczowie": 268},
	"ee": {"rekord": 268, "epoka": 248, "budowniczowie": 264}}
const EFEKT := {"aoc": 88, "ee": 68}
const KOD_ZMIANY_GRAFIKI := 6
## Przesunięcia pól rekordu dbeffects (×4 B) – schemat dane/schemat_db_eedbeditor/AOC/dbeffects.dats.
const EF_ID := 1
const EF_OBIEKT_1 := 5
const EF_ZESTAW := 7
const EF_KOD := 8
const EF_NOWA_GRAFIKA := 9

static var blad := ""
static var wariant_techtree := ""
static var wariant_efektow := ""


static func _napis(d: PackedByteArray, o: int) -> String:
	if d[o] == 0xCC or d[o] == 0xFF:
		return ""
	return TekstEE.cp1250(d.slice(o, o + 100))


## Przebieg struktury grup dbtechtree dla formatu `f`: liczba rekordów albo opis błędu (String).
static func _struktura_techtree(d: PackedByteArray, f: Dictionary) -> Variant:
	var o := 0; var liczba := 0
	var R: int = f.rekord; var ob: int = f.budowniczowie
	while o < d.size():
		if o + 4 > d.size(): return "ucięty licznik przy %d" % o
		var n := d.decode_s32(o); o += 4
		if n < 0 or n > 100000: return "licznik grupy %d przy %d" % [n, o - 4]
		for i in range(n + 1):
			if o + R > d.size(): return "ucięty rekord przy %d" % o
			var nb := d.decode_s32(o + ob)
			if nb < 0 or nb > 1000 or o + R + 4 * nb > d.size(): return "budowniczowie %d przy %d" % [nb, o]
			o += R + 4 * nb; liczba += 1
	return liczba


static func techtree(d: PackedByteArray) -> Array:
	wariant_techtree = ""
	var pasuja: Array = []; var opisy: Array = []
	for w in TECH:
		var wynik: Variant = _struktura_techtree(d, TECH[w])
		if wynik is int: pasuja.append(w)
		else: opisy.append("%s: %s" % [w, wynik])
	if pasuja.size() != 1:
		blad = "dbtechtree: %s (%d B; %s)" % ["niejednoznaczny wariant" if pasuja.size() > 1 else "nieobsługiwany wariant",
			d.size(), "; ".join(opisy) if not opisy.is_empty() else ", ".join(pasuja)]
		return []
	wariant_techtree = pasuja[0]
	var f: Dictionary = TECH[wariant_techtree]
	var R: int = f.rekord; var ob: int = f.budowniczowie; var oe: int = f.epoka
	var o := 0; var grupa := 0
	var out: Array = []
	while o < d.size():
		var n := d.decode_s32(o); o += 4
		for i in range(n + 1):
			var nb := d.decode_s32(o + ob)
			out.append({"nazwa": _napis(d, o), "seq": d.decode_s32(o + 100), "id": d.decode_s32(o + 104),
				"start": d.decode_s32(o + 108), "koniec": d.decode_s32(o + 112), "event": d.decode_s32(o + 116),
				"obiekt": d.decode_s32(o + 172), "typ": d.decode_s32(o + 188), "epoka": d.decode_s32(o + oe),
				"grupa": grupa, "glowa_grupy": i == 0})
			o += R + 4 * nb
		grupa += 1
	return out


static func zdarzenia(d: PackedByteArray) -> Array:
	var o := 0
	var out: Array = []
	while o + 108 <= d.size():
		var n := d.decode_s32(o + 104)
		if n < 0 or o + 108 + 4 * n > d.size(): blad = "dbevents: rekord %d" % out.size(); return []
		var ids := PackedInt32Array()
		for k in n: ids.append(d.decode_s32(o + 108 + 4 * k))
		out.append({"nazwa": _napis(d, o), "seq": d.decode_s32(o + 100), "efekty": ids})
		o += 108 + 4 * n
	if o != d.size(): blad = "dbevents: zużyto %d z %d bajtów" % [o, d.size()]; return []
	return out


## Tylko pola potrzebne do wyboru grafiki (pozostałe efekty – atrybuty, przyciski, dźwięki – poza zakresem etapu 8).
static func efekty(d: PackedByteArray) -> Dictionary:
	wariant_efektow = ""
	var pasuja: Array = []
	for w in EFEKT:
		if d.size() > 0 and d.size() % int(EFEKT[w]) == 0: pasuja.append(w)
	if pasuja.size() != 1:
		blad = "dbeffects: %s – długość %d B (rekord AoC 88 B, EE 68 B)" % [
			"niejednoznaczny wariant" if pasuja.size() > 1 else "nieobsługiwany wariant", d.size()]
		return {}
	wariant_efektow = pasuja[0]
	var R: int = EFEKT[wariant_efektow]
	var out := {}
	for o in range(0, d.size(), R):
		var id := d.decode_s32(o + 4 * EF_ID)
		out[id] = {"kod": d.decode_s32(o + 4 * EF_KOD), "obiekt": d.decode_s32(o + 4 * EF_OBIEKT_1),
			"zestaw": d.decode_s32(o + 4 * EF_ZESTAW), "grafika": d.decode_s32(o + 4 * EF_NOWA_GRAFIKA)}
	return out
