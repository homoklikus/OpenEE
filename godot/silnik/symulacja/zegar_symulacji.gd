class_name ZegarSymulacji
extends Node
## Napędza Symulacja stałym krokiem z akumulatora czasu (niezależnie od FPS) i udostępnia współczynnik interpolacji
## renderu `alfa` ∈ [0, 1) między poprzednim a bieżącym taktem (etap 5).

signal po_takcie(zdarzenia: Array)

var sym: Symulacja
var akumulator := 0.0
var predkosc := 1.0
var pauza := false
var maks_taktow_na_klatke := 8     # ochrona przed „spiralą śmierci” przy bardzo niskim FPS
var alfa := 0.0
var czas_klatki_sym_us := 0


func _init(s: Symulacja = null) -> void:
	sym = s


func _process(delta: float) -> void:
	przesun(delta)


## Przesuwa czas o delta (sekundy) – wykonuje 0..N taktów. Zwraca liczbę wykonanych taktów.
func przesun(delta: float) -> int:
	if sym == null or pauza:
		return 0
	var t0 := Time.get_ticks_usec()
	akumulator += delta * predkosc
	var n := 0
	while akumulator >= Symulacja.KROK and n < maks_taktow_na_klatke:
		sym.krok()
		akumulator -= Symulacja.KROK
		n += 1
		po_takcie.emit(sym.zdarzenia.duplicate())
	if n == maks_taktow_na_klatke:
		akumulator = minf(akumulator, Symulacja.KROK)
	alfa = clampf(akumulator / Symulacja.KROK, 0.0, 1.0)
	czas_klatki_sym_us = Time.get_ticks_usec() - t0
	return n
