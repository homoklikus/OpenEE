class_name ZaznaczenieEE
extends RefCounted
## Reguły zaznaczania jednostek oryginalnego EE (etap 9, docs/MECHANIKA_RUCHU_EE.md § 2) – logika bez węzłów.
## Potwierdzone w grze (odczyt grupy zaznaczenia z pamięci, MCP ee_ruch.zaznaczenie):
## * LPM na własnej jednostce – zaznaczenie tylko jej (zastępuje poprzednie),
## * Shift + LPM – dodanie; Shift + LPM na już zaznaczonej – bez zmian (nie odznacza),
## * Ctrl + LPM na zaznaczonej – usunięcie z zaznaczenia,
## * LPM na pustym terenie – odznaczenie wszystkich; Esc – bez zmian,
## * ramka – zastępuje zaznaczenie jednostkami w ramce; Shift + ramka – dodaje; Ctrl + ramka – usuwa,
## * grupa 50 jednostek zaznaczona w całości (brak limitu ≤ 50 w pomiarze).
## Jednostka „jest w ramce”, gdy jej punkt ekranowy (rzut pozycji na wysokości PUNKT_WYSOKOSC) leży w prostokącie
## [W: oryginał rozstrzyga punktem, nie sylwetką – ramki przez głowę lub nogi dawały różne wyniki; dokładna
## wysokość punktu nieustalona].

const PUNKT_WYSOKOSC := 0.3

var ids: Array[int] = []


func zawiera(id: int) -> bool:
	return id in ids


## Kliknięcie: `id` trafionej własnej jednostki albo -1 (teren); mod: "", "shift", "ctrl".
func klik(id: int, mod: String = "") -> void:
	if id < 0:
		if mod == "":
			ids.clear()
		return
	match mod:
		"shift":
			if not (id in ids): ids.append(id)
		"ctrl":
			ids.erase(id)
		_:
			ids = [id]


## Ramka: lista id jednostek w prostokącie (już przefiltrowana do własnych).
func ramka(w_ramce: Array, mod: String = "") -> void:
	match mod:
		"shift":
			for id in w_ramce:
				if not (int(id) in ids): ids.append(int(id))
		"ctrl":
			for id in w_ramce: ids.erase(int(id))
		_:
			ids.clear()
			for id in w_ramce: ids.append(int(id))


## Id jednostek, których punkt ekranowy leży w prostokącie `r` (piksele) – `rzut` mapuje Vector3 świata na ekran.
static func w_prostokacie(sym, r: Rect2, rzut: Callable, gracz: int = -1) -> Array:
	var out: Array = []
	var rr := r.abs()
	for j in sym.lista():
		if gracz >= 0 and j.wlasciciel != gracz: continue
		var p: Vector2 = rzut.call(UkladEE.godot(j.pozycja, sym.mapa.wysokosc(j.pozycja) + PUNKT_WYSOKOSC))
		if rr.has_point(p): out.append(j.id)
	return out
