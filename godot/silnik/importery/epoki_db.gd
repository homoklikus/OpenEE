class_name EpokiDB
extends RefCounted
## Dekodery tabel epok i efektów EE/AoC (etap 8, RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md § 1) – odpowiednik
## narzedzia/eeformaty/epoki.py. Tabele nie mają nagłówka „u32 N + N rekordów”, więc nie przechodzą przez BazaDB.
## * dbtechtree: 15 grup „i32 liczba_dzieci, rekord epoki, dzieci”; rekord 272 B + 4 B × „Num of tech builders”,
## * dbevents: NAME 100 B, i32 sekwencja, i32 n, n × i32 ID efektu (indeks rekordu = „Event ID” z dbtechtree),
## * dbeffects: 22 pola × 4 B (88 B), kolejność schematu EE DB Editor.
## Kontrola: zużycie danych co do bajta, inaczej pusty wynik i komunikat.

const REKORD_TECH := 272
const REKORD_EFEKTU := 88
const KOD_ZMIANY_GRAFIKI := 6
## Przesunięcia pól rekordu dbeffects (×4 B) – schemat dane/schemat_db_eedbeditor/AOC/dbeffects.dats.
const EF_ID := 1
const EF_OBIEKT_1 := 5
const EF_ZESTAW := 7
const EF_KOD := 8
const EF_NOWA_GRAFIKA := 9

static var blad := ""


static func _napis(d: PackedByteArray, o: int) -> String:
	if d[o] == 0xCC or d[o] == 0xFF:
		return ""
	return TekstEE.cp1250(d.slice(o, o + 100))


static func techtree(d: PackedByteArray) -> Array:
	var o := 0; var grupa := 0
	var out: Array = []
	while o < d.size():
		if o + 4 > d.size(): blad = "dbtechtree: ucięty licznik"; return []
		var n := d.decode_s32(o); o += 4
		if n < 0 or n > 100000: blad = "dbtechtree: licznik grupy %d" % n; return []
		for i in range(n + 1):
			if o + REKORD_TECH > d.size(): blad = "dbtechtree: ucięty rekord"; return []
			var nb := d.decode_s32(o + 268)
			if nb < 0 or nb > 1000 or o + REKORD_TECH + 4 * nb > d.size():
				blad = "dbtechtree: budowniczowie %d przy %d" % [nb, o]; return []
			out.append({"nazwa": _napis(d, o), "seq": d.decode_s32(o + 100), "id": d.decode_s32(o + 104),
				"start": d.decode_s32(o + 108), "koniec": d.decode_s32(o + 112), "event": d.decode_s32(o + 116),
				"obiekt": d.decode_s32(o + 172), "typ": d.decode_s32(o + 188), "epoka": d.decode_s32(o + 252),
				"grupa": grupa, "glowa_grupy": i == 0})
			o += REKORD_TECH + 4 * nb
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
	if d.size() % REKORD_EFEKTU != 0: blad = "dbeffects: długość %d" % d.size(); return {}
	var out := {}
	for o in range(0, d.size(), REKORD_EFEKTU):
		var id := d.decode_s32(o + 4 * EF_ID)
		out[id] = {"kod": d.decode_s32(o + 4 * EF_KOD), "obiekt": d.decode_s32(o + 4 * EF_OBIEKT_1),
			"zestaw": d.decode_s32(o + 4 * EF_ZESTAW), "grafika": d.decode_s32(o + 4 * EF_NOWA_GRAFIKA)}
	return out
