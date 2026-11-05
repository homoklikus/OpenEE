extends Node
## Wewnętrzny system zdarzeń OpenEE.
##
## Dwa ROZDZIELONE kanały (przygotowanie pod deterministyczny multiplayer):
##  * SYMULACYJNY – zdarzenia wpływające na stan gry. Kolejkowane z numerem ticku i numerem
##    sekwencyjnym; obsługiwane wyłącznie w kroku symulacji, w ściśle określonej kolejności
##    (tick, kanał, sekwencja). Dane muszą być prostymi typami (int, String, Array, Dictionary),
##    bez float zależnych od platformy w logice, bez odwołań do czasu rzeczywistego i UI.
##  * LOKALNY – zdarzenia interfejsu, dźwięku, kamery, diagnostyki. Natychmiastowe (sygnał),
##    nigdy nie wpływają na stan symulacji i nie są synchronizowane po sieci.
## Przyszłe skrypty modów (Lua) dostaną osobne API dla obu kanałów (patrz silnik/api/api_modow.gd).

signal lokalne(nazwa: String, dane: Variant)

var _kolejka_symulacji: Array = []   # elementy: [tick, sekwencja, nazwa, dane]
var _sekwencja: int = 0
var _obslugi_symulacji := {}         # nazwa -> Array[Callable]


func emituj_lokalne(nazwa: String, dane: Variant = null) -> void:
	lokalne.emit(nazwa, dane)


func kolejkuj_symulacyjne(tick: int, nazwa: String, dane: Variant = null) -> void:
	_kolejka_symulacji.append([tick, _sekwencja, nazwa, dane])
	_sekwencja += 1


func zarejestruj_symulacyjne(nazwa: String, obsluga: Callable) -> void:
	if not _obslugi_symulacji.has(nazwa):
		_obslugi_symulacji[nazwa] = []
	_obslugi_symulacji[nazwa].append(obsluga)


## Wywoływane przez pętlę symulacji dla danego ticku; zwraca liczbę obsłużonych zdarzeń.
func przetworz_tick(tick: int) -> int:
	var do_obslugi := _kolejka_symulacji.filter(func(z): return z[0] <= tick)
	do_obslugi.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	_kolejka_symulacji = _kolejka_symulacji.filter(func(z): return z[0] > tick)
	for z in do_obslugi:
		for o in _obslugi_symulacji.get(z[2], []):
			o.call(z[0], z[3])
	return do_obslugi.size()
