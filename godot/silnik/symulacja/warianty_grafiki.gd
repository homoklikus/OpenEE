class_name WariantyGrafiki
extends RefCounted
## Wybór grafiki (dbgraphics) obiektu wg epoki i zbadanych technologii gracza – etap 8,
## raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md § 1–2. Wyłącznie dane gry, bez list nazw:
##   technologia epoki (dbtechtree, głowa grupy) → „Event ID” → dbevents → efekty dbeffects o kodzie 6
##   („Object 1” → „New graphic”), nakładane rosnąco wg numeru epoki dla wszystkich epok ≤ epoki gracza;
##   następnie zdarzenia zbadanych technologii nie-epokowych (np. ulepszenia obywatela w epoce nano).
## Grafika bazowa = dbobjects „Graphic ID”. Zmiana grafiki zmienia jednocześnie model, teksturę i sekwencje animacji
## (wszystko jest w wierszu dbgraphics) – [D] tabela docs/WARIANTY_EPOK.md.
## Brak danych (np. brak tabel) → zawsze grafika bazowa (zachowanie sprzed etapu 8).

var epoki: Array = []          # głowy grup dbtechtree z numerem epoki > 0, rosnąco
var _tech := {}                # ID technologii → rekord
var _zdarzenia: Array = []
var _efekty := {}
var _obiekty := {}             # ID obiektu → rekord dbobjects (Graphic ID)
var _pamiec := {}              # klucz stanu gracza → mapa obiekt → grafika
var gotowe := false


static func z_tabel(techtree: Array, zdarzenia: Array, efekty: Dictionary, obiekty: Dictionary) -> WariantyGrafiki:
	var w := WariantyGrafiki.new()
	w._zdarzenia = zdarzenia; w._efekty = efekty; w._obiekty = obiekty
	for t in techtree:
		if int(t.seq) >= 0 and not w._tech.has(int(t.id)):
			w._tech[int(t.id)] = t
		if t.glowa_grupy and int(t.epoka) > 0:
			w.epoki.append(t)
	w.epoki.sort_custom(func(a, b): return int(a.epoka) < int(b.epoka))
	w.gotowe = not w.epoki.is_empty() and not zdarzenia.is_empty() and not efekty.is_empty()
	return w


## Z instalacji gry (Zasoby): surowe db/dbtechtree.dat, dbevents.dat, dbeffects.dat + dbobjects.
static func z_zasobow(zasoby) -> WariantyGrafiki:
	var t: Dictionary = zasoby.znajdz("db/dbtechtree.dat"); var e: Dictionary = zasoby.znajdz("db/dbevents.dat")
	var f: Dictionary = zasoby.znajdz("db/dbeffects.dat")
	var ob := {}
	for r in zasoby.tabela("dbobjects"): ob[int(r.ID)] = r
	if t.is_empty() or e.is_empty() or f.is_empty():
		ImporterEE.zglos("uwaga", "warianty", "Brak tabel epok/efektów – grafiki bazowe (bez wariantów epok)")
		return z_tabel([], [], {}, ob)
	var w := z_tabel(EpokiDB.techtree(t.dane), EpokiDB.zdarzenia(e.dane), EpokiDB.efekty(f.dane), ob)
	if not w.gotowe:
		ImporterEE.zglos("uwaga", "warianty", "Tabele epok nieczytelne (%s) – grafiki bazowe" % EpokiDB.blad)
	return w


func numer_epoki(tech_epoki: int) -> int:
	var t: Dictionary = _tech.get(tech_epoki, {})
	return int(t.epoka) if not t.is_empty() and t.glowa_grupy else 0


func nazwa_technologii(id: int) -> String:
	return String(_tech.get(id, {}).get("nazwa", ""))


## Technologia epoki o danym numerze (1–15) albo -1.
func tech_epoki_nr(nr: int) -> int:
	for e in epoki:
		if int(e.epoka) == nr: return int(e.id)
	return -1


## Zmiany grafiki ze zdarzenia (Event ID): [[obiekt, grafika, ID efektu], …] w kolejności listy zdarzenia.
func zmiany_zdarzenia(event: int) -> Array:
	var out: Array = []
	if event < 0 or event >= _zdarzenia.size(): return out
	for id in _zdarzenia[event].efekty:
		var ef: Dictionary = _efekty.get(int(id), {})
		if not ef.is_empty() and int(ef.kod) == EpokiDB.KOD_ZMIANY_GRAFIKI and int(ef.obiekt) >= 0 and int(ef.grafika) >= 0:
			out.append([int(ef.obiekt), int(ef.grafika), int(id)])
	return out


## Obiekt → grafika (tylko obiekty zmienione przez epoki/technologie) dla stanu gracza.
func mapa_grafik(tech_epoki: int, zbadane: Array = []) -> Dictionary:
	var klucz := "%d|%s" % [tech_epoki, ",".join(zbadane.map(func(x): return str(x)))]
	if _pamiec.has(klucz): return _pamiec[klucz]
	var m := {}
	var nr := numer_epoki(tech_epoki)
	for ep in epoki:
		if int(ep.epoka) > nr: break
		for z in zmiany_zdarzenia(int(ep.event)): m[z[0]] = z[1]
	for tid in zbadane:
		var t: Dictionary = _tech.get(int(tid), {})
		if not t.is_empty() and not t.glowa_grupy:
			for z in zmiany_zdarzenia(int(t.event)): m[z[0]] = z[1]
	_pamiec[klucz] = m
	return m


func grafika_bazowa(obiekt: int) -> int:
	return int(_obiekty.get(obiekt, {}).get("Graphic ID", -1))


## Grafika obiektu `obiekt` gracza w epoce `tech_epoki` (ID technologii; -1 = bez epoki → bazowa).
func grafika(obiekt: int, tech_epoki: int, zbadane: Array = []) -> int:
	var m := mapa_grafik(tech_epoki, zbadane)
	return int(m[obiekt]) if m.has(obiekt) else grafika_bazowa(obiekt)
