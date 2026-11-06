class_name FormacjaEE
extends RefCounted
## Rozmieszczenie grupy po rozkazie ruchu – odtworzenie zachowania oryginalnego EE (etap 9, docs/MECHANIKA_RUCHU_EE.md § 3).
##
## Ustalenia z pomiarów trajektorii w oryginale (Testy_MCP/ee_ruch: grupy 2, 5, 10, 25, 35 obywateli, 10 jednostek
## mieszanych, 10 obywateli w 5 kolejnych rozkazach w różnych kierunkach):
## * każda jednostka dostaje WŁASNY punkt docelowy (miejsce w szyku) i idzie do niego sama, z własną prędkością
##   (bez wyrównywania prędkości w grupie) – wszystkie ruszają w tym samym takcie [P],
## * szyk = siatka o szerokości KOLUMNY (5) kolumn (2 → linia 2, 5 → 1×5, 10 → 2×5, 25 → 5×5) [P: odchyłka
##   miejsc 0,02–0,03 pola w 8 przejściach; 35 → 7×5 – odchyłka 0,3, W],
## * rzędy prostopadłe do kierunku od środka grupy do punktu rozkazu; PIERWSZY rząd stoi w punkcie rozkazu, kolejne
##   za nim (w stronę, z której grupa nadeszła) [P],
## * odstęp w rzędzie i między rzędami = dbobjects „Size in formation” (obywatel 0,625) [P]; grupa mieszana –
##   największy „Size in formation” w grupie [W: zmierzone ~0,77, układ nieregularny],
## * niepełny ostatni rząd – wyśrodkowany [H],
## * przydział jednostek do miejsc: identyfikatory rosnąco wypełniają rzędy od pierwszego, w rzędzie od lewej strony
##   kierunku marszu [W: zgodne dokładnie w 4 z 9 przejść – pierwsze rozkazy grup ustawionych w siatkę (2, 5, 10, 25);
##   w pozostałych (marsz przez bród, krótkie przejścia z zastanego szyku) oryginał przydziela inaczej – reguła
##   nieustalona; sprawdzone i odrzucone: minimalna suma dróg, zachłanny najbliższy, kolejność poprzeczna → N].
## Formacje wybierane przyciskiem (8 rodzajów: linie, kliny, koła – teksty Language.dll 19501–19508) i tryb
## „Szybko/Sprytnie” (31001–31002) nie są tu odtwarzane (domyślny szyk) [N].

const KOLUMNY := 5


## Pozycje docelowe dla jednostek grupy. `jednostki` – [[id, pozycja Vector2, size_in_formation]] w dowolnej
## kolejności; zwraca {id: Vector2}. Pojedyncza jednostka – dokładnie punkt rozkazu.
static func rozmiesc(jednostki: Array, cel: Vector2) -> Dictionary:
	var out := {}
	var n := jednostki.size()
	if n == 0:
		return out
	var lista := jednostki.duplicate()
	lista.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	if n == 1:
		out[int(lista[0][0])] = cel
		return out
	var srodek := Vector2.ZERO
	var odstep := 0.0
	for e in lista:
		srodek += e[1]; odstep = maxf(odstep, float(e[2]))
	srodek /= n
	if odstep <= 0.0: odstep = 0.625
	var f := cel - srodek
	f = f.normalized() if f.length() > 1e-4 else Vector2(0, 1)
	var lewo := Vector2(-f.y, f.x)          # lewa strona kierunku marszu (obrót +90° w mapie EE)
	var kol := mini(KOLUMNY, n)
	for i in n:
		var r := i / kol
		var c := i % kol
		var w_rzedzie := mini(kol, n - r * kol)
		out[int(lista[i][0])] = cel - f * (r * odstep) + lewo * (((w_rzedzie - 1) * 0.5 - c) * odstep)
	return out
