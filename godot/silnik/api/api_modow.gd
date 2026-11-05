class_name ApiModow
extends RefCounted
## PROJEKT przyszłego API moderskiego OpenEE (etap 1: tylko deklaracje – BEZ interpretera Lua).
##
## Założenia:
##  * Mody definiują dane (jednostki, budynki, technologie) w plikach danych (JSON/Lua-tables),
##    ładowanych przez warstwę 'user_mods' – kod silnika nie zawiera wartości gry.
##  * Skrypty modów działają w dwóch odseparowanych kontekstach:
##      - SYMULACYJNYM: deterministyczne, wywoływane z pętli symulacji na zdarzenia kanału
##        symulacyjnego (Zdarzenia.kolejkuj_symulacyjne / przetworz_tick). Zakaz: czasu
##        rzeczywistego, losowości spoza RNG symulacji, I/O, dostępu do UI/kamery.
##      - LOKALNYM: UI, dźwięk, efekty, podpowiedzi – bez wpływu na stan gry.
##  * Interpreter (np. Lua 5.4 przez GDExtension) zostanie wybrany w osobnym etapie.

enum Kontekst { SYMULACYJNY, LOKALNY }

## Lista planowanych punktów wejścia (nazwa → kontekst, opis) – służy do dokumentacji i testów.
const PLANOWANE := {
	"na_start_scenariusza": [Kontekst.SYMULACYJNY, "inicjalizacja stanu moda"],
	"na_tick": [Kontekst.SYMULACYJNY, "krok symulacji (stały krok)"],
	"na_utworzenie_jednostki": [Kontekst.SYMULACYJNY, "nowa jednostka/budynek"],
	"na_badanie_technologii": [Kontekst.SYMULACYJNY, "ukończenie technologii"],
	"na_wybor_jednostek": [Kontekst.LOKALNY, "zmiana zaznaczenia przez gracza"],
	"na_rysowanie_interfejsu": [Kontekst.LOKALNY, "rozszerzenia HUD"],
}


static func opis() -> String:
	var linie := []
	for k in PLANOWANE:
		linie.append("%s [%s]: %s" % [k, "SYM" if PLANOWANE[k][0] == Kontekst.SYMULACYJNY else "LOK", PLANOWANE[k][1]])
	return "\n".join(linie)
