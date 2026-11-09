# OpenEE – raport etapu 34: morale z budynków w Core, obiekt pod kursorem w Titan, eksperymenty rozkazu ataku

Etap 34 odczytał z kodu **pełne reguły morale z budynków**: kto je daje, jak liczy się poziom, kto je otrzymuje,
co dzieje się przy kilku źródłach i kiedy następuje aktualizacja. OpenEE Core liczy teraz morale samodzielnie z
budynków. Dla wszystkich 5 okien referencyjnych wynik zgadza się z odczytem gry. Ustalono też mechanizm wyboru
obiektu pod kursorem: wybór odbywa się przy kliknięciu i używa listy renderu kamery oraz przecięcia promienia z
siatką w DLL. Na tej podstawie Riverlands_MCP dostał warunek konieczny z kodu, sprawdzany przed PPM. Udanego,
potwierdzonego rozkazu ataku przez MCP w tym etapie nie uzyskano: we wszystkich próbach cel był we mgle wojny.

Szczegóły: `docs/titan/walka.md` § 25, `docs/titan/rozkazy_gracza.md` § 7, `docs/cpp/ARCHITEKTURA_CORE.md` § 16,
`docs/PLAN_REKONSTRUKCJI_TITAN.md` § 4.11, `docs/titan/BLEDY_ORYGINALU.md` BO-11.

**Oznaczenia:** [P] pomiar i kod; [W] wniosek ze statyki; [H] hipoteza; [N] nieustalone.
**Środowisko:** komputer główny użytkownika (Debian 13, KDE Wayland), polecenia w maszynie roboczej Ubuntu 22.04
(GCC 11.4). Kontrole wykonano też w kontenerze Ubuntu 24.04 (GCC 13.3) z identycznym wynikiem. Proxmox – poza
zakresem.

## 1. Stan początkowy i końcowy

| | Etap 33 (`882c008`) | Etap 34 |
|---|---|---|
| CTest Release / Debug | 19/19 / 19/19 | **20/20 / 20/20** (nowa grupa `core_morale`) |
| GDExtension | 23/23 | 23/23 |
| Godot | 324/324 | 324/324 |
| Riverlands_MCP | 14 plików | 15 plików (`test_ee_etap34.py`) |
| narzędzia Titan | 17/17 | 20/20 (zestawy jednostek) |
| S1–S7 | 9/9, 68b0c69ecb8b0cbc | 9/9, 68b0c69ecb8b0cbc (bez zmian) |
| pojedynek syntetyczny | 9ddaf83720646edb | bez zmian |
| 578 G1 | 986/986 | 986/986 (morale z Core: brak, jak w grze) |
| 578 G3 | 169 (ω) | 169 (ω), morale z Core 2/2 = gra |
| 580 G1 (AoC) | 57 / 146 | bez zmian |
| 589 G3 / 590 G1 | 1 / 97 | bez zmian |
| AoC 505 / EE 500 (ruch) | 803 / koniec +1 | bez zmian |

Morale ustawiane dotąd ręcznie z odczytu gry (etap 33) Core liczy teraz z budynków scenariusza. Metryki okien są
identyczne jak przy wartościach wpisanych ręcznie.

## 2. Reguły morale (`walka.md` § 25)

1. **Źródła** [P: dane i kod]: Town Center (szablon 4, max 2) i Capitol (szablon 14, max 4) – typ 5
   `EEAEMoraleFromBuildings`, obszar 10, kwadrat, relacja „sojusznik”, zestaw „People Morale 1”. Ponadto typ 2
   (morale wież: TC/Capitol, poziom 5, tylko wieże gracza) i typ 6 (bohaterowie, koło) – oba poza Core.
2. **Poziom**: min(liczba domów, Max morale + „Alter max morale” wariantu gry: Scenarios 0, Standard +2) [P].
   Liczą się tylko domy `b  House` (ID 37) gracza zapisanego w efekcie, z HP > 0, z kotwicą w prostokącie wokół
   środka źródła. Dla TC 2 × 2 o kotwicy (184, 109) prostokąt to [175, 194] × [100, 119]. Domy kampanii
   `x House - Copper` się nie liczą.
3. **Zasięg działania ≠ pole widzenia**: obszar to rozmiar szablonu (10) razy typ+0x428 (1,0) [P]. Jednostka jest w
   obszarze, gdy |dx| ≤ 10 i |dy| ≤ 10 od środka budynku (kwadrat, granica włącznie).
4. **Wiele źródeł – brak sumowania**: typy 2, 5 i 6 tworzą jedną klasę. Zostaje efekt o największym poziomie, a przy
   remisie pierwszy [P]. W pierwszym przebiegu poziomy są jeszcze zerowe, więc zostaje pierwszy efekt.
5. **Właściciel i dyplomacja**: domy liczą się tylko z równym numerem gracza. Odbiorca musi być tym samym graczem albo
   sojusznikiem bieżącego właściciela źródła; wróg w obszarze nie dostaje efektu [P: kod i odczyt 0x5000ad3].
6. **Budowa, zniszczenie, przejęcie**: przeliczenie wywołuje tylko dodanie lub usunięcie **domu** u gracza
   (`SuggestRecomputeAllAreaEffects`). Nowy poziom obowiązuje po najbliższym przebiegu [P]. Fundament domu i
   przejęcie budynku-źródła – [N].
7. **Moment w takcie**: po losowaniach i menedżerze tras, przed pętlą jednostek, co 2000 ms czasu gry (akumulator
   f32 +0x9C). Pierwszy przebieg wypada w takcie 59 [P: kod]. Przebieg: czyszczenie list → przypisanie → usunięcie
   nadmiarowych → przeliczenie domów → listy regionów.
8. **EE ↔ AoC**: ten sam kod pod innymi adresami (0x67B911, 0x67B95B, 0x67C651, 0x553C59) i te same szablony.
   W AoC zestawy jednostek zawierają dodatkowe typy [P].

## 3. Implementacja w Core

- `cpp/core/include/openee/efekty_obszaru.hpp` i `src/efekty_obszaru.cpp`: szablon (`SzablonEfektu`), efekt
  (`EfektObszaru`), budynek (`Budynek`), prostokąt zliczania, test obszaru, poziom, klasa równoważności.
  Arytmetyka f32/x87 jak w kodzie: ftol, fistp, ułamek x zapisany do f32, porównania na stosie.
- `Swiat` (jeden świat; budynki mają identyfikatory z tej samej puli co jednostki):
  - `dodaj_szablon_efektu`, `dodaj_budynek`, `usun_budynek`, `zmien_wlasciciela_budynku`,
    `ustaw_premie_morale_wariantu`;
  - przebieg `przebieg_efektow` w takcie (akumulator 2000 ms);
  - `odtworz_efekty_obszaru` – start z migawki gry.
  Lista efektów jednostki `Jednostka::efekty_obszaru` odpowiada EEUnit +0xF8. Trafienie liczy redukcję przez
  `poziomy_morale(cel)`. Dawne `ustaw_morale` zostaje do odtwarzania odczytów.
- Budynki nie biorą udziału w pętli jednostek, maszynie stanów ani kolizjach. To decyzja na ten etap [W]: budynki
  nie mają jeszcze w Core zachowań.
- Dane wejściowe: `narzedzia/titan/efekty_obszaru.py` z `dbareaeffect`, `dbunitset` (algorytm EE 0x52BFA4),
  `dbobjects`, `dbgamevariant` i kawałka 5 SCN. Wynik dla scenariusza testowego `e31_a`:
  `dane/testy_walki/efekty_e31_a_{ee,aoc}.json` – same liczby, bez zasobów gry.
- Testy `core_morale` (21 sprawdzeń):
  - prostokąt i kwadrat, w tym granice;
  - pierwszy przebieg w takcie 59;
  - poziom 2 i brak efektu poza obszarem oraz dla wroga;
  - TC z Capitolem → jeden efekt, od drugiego przebiegu poziom 4;
  - wyjście z obszaru;
  - zniszczenie domów (2 → 1, obrażenia 16 → 13 → 14);
  - przejęcie domu (poziom 0);
  - wariant Standard (3);
  - AoC;
  - świat bez budynków.

  W `core_walka_swiat` Core liczy morale dla okien 578/580/589/590 i porównuje je z odczytem: 5/5 zgodnych.

## 4. Interfejs myszy i rozkaz ataku – badanie (`rozkazy_gracza.md` § 7)

- `EEAMouseClick` +0x0C (EE 0x403CF1) w chwili kliknięcia woła **0x50EC37 = wybór obiektu** z kamerą (EE
  0x9125D8, AoC 0x928D78) i punktem kursora ([EE 0x9197A8 / AoC 0x931924]+4, f32 piksele okna) [P: kod i odczyt].
- 0x50EC37 przegląda **listę renderu kamery** (+0x2A0, liczba +0x2A8, wpis 0x50 B: +0x40 transformacja,
  +0x44 promień, +0x48 model, +0x4C obiekt). Dla wpisów woła `GEPhysicalModel::Intersects` z DLL, czyli przecięcie
  promienia z siatką modelu. Kandydaci są sortowani według kategorii z 0x50E34B [P: kod; szczegóły sortowania – N].
- Wskaźnika „obiekt pod kursorem” trwałego między klatkami nie znaleziono: 22 wywołania 0x50EC37 mają wynik lokalny
  [W]. Dla wroga wynik daje komunikat 0x66 (cel = id obiektu) i dalej EEUGAttackUnit.
- **Nieustalony etap:** przecięcie promienia z siatką (DLL `GEPhysicalModel::Intersects`). MCP go nie odtwarza.
  Trafienie potwierdza dopiero kolejka celów po PPM.

## 5. Automatyzacja MCP (Riverlands_MCP, lokalnie)

- `walka_lista_renderu`: lista renderu kamery i punkt kursora z pamięci gry, tylko odczyt.
  Struktura potwierdzona w grze (602, 603) [P].
- `walka_atak_potwierdzony` wykonuje kolejno:
  1. weryfikowany wybór atakującego;
  2. kamerę na cel;
  3. warunek z kodu: cel na liście renderu (z oczekiwaniem);
  4. kursor nad rzutem celu z kontrolą pozycji kursora odczytanej z gry;
  5. PPM;
  6. kolejkę celów – EEUGAttackUnit z id celu.

  Liczba prób jest ograniczona, a każde niepowodzenie zapisuje etap i powód. Bez spełnienia warunku 3 PPM nie pada.
- Wyniki:
  - **602**: wróg 0x5000ad0 był poza listą renderu (we mgle), choć jego rzut leżał w kadrze. Wyjaśnia to
    niepowodzenia etapów 32–33: stary `walka_atak` klikał 6 razy i trafiał w teren (EEUGLocation);
  - **603**: 0x5000ad1 i **604**: 0x5000ad3 były poza listą renderu. Przy każdej z 4 prób funkcja odmówiła PPM.

  Udanego rozkazu ataku nie uzyskano [N]. Kolejny krok: cel widoczny dla gracza bez automatycznego ataku, np.
  własna jednostka obserwująca z „Stand Ground”.

## 6. AI, pościg i LOS – eksperymenty

Wykonano 3 z 10 scenariuszy. Nagrania lokalne: `ee_obserwacja/e34_60{2,3,4}_*.json`.

| Scenariusz | Wynik |
|---|---|
| 1 rozkaz ataku gracza | niewykonalny w tym etapie – cel we mgle (§ 5) [N] |
| 2 automatyczny wybór celu AI | 602: 0x5000ad0 wykrył 855 przy odległości 3,96 (pole widzenia 4,0); sekwencja 2013 → 2024 → 8000 → 2015/10003. 855 po dojściu (5001 → 5000) w następnym takcie wszedł w 2013 [P] |
| 8 zmiana celu w walce | 603: cel zmiany niewidoczny – rozkaz niewysłany [N] |
| 3–7, 9, 10 | niewykonane w tym etapie [N] |

Nowych zachowań AI do Core nie dodano.

## 7. Poprawki fizyki i walki

Poza morale z budynków brak. Rozbieżności z priorytetu D (§ 8) nie zostały w tym etapie przesunięte.
Tolerancji ani wartości oczekiwanych nie zmieniano.

## 8. Pierwsze rozbieżne takty

| Przypadek | Takt | Stan |
|---|---|---|
| 578 G1 | brak w oknie | bez zmian |
| 578 G3 | 169 (ω jednostki 857) | bez zmian; morale z Core zgodne z grą, więc HP nie jest przyczyną [W] |
| 590 G1 | 97 (kurs, tryb 1 z ruchomym celem) | bez zmian [N] |
| 580 G1 (AoC) | 57 (spóźniona próbka stanu), 146 (konsument RNG) | bez zmian [N] |
| AoC 505 / EE 500 | 803 / koniec +1 | bez zmian [N] |

## 9. Regresja

- CTest Release i Debug 20/20, wyniki identyczne.
- Skróty bez zmian: S 68b0c69ecb8b0cbc, pojedynek 9ddaf83720646edb, 578 G1 986/986.
- GDExtension 23/23, Godot 324/324.
- Riverlands_MCP 15/15 plików, narzędzia Titan 20/20.
- Przypadki bez budynków (wszystkie testy ruchu i pojedynki syntetyczne) nie zmieniły się. Przebieg efektów nie
  używa RNG.
- Wyniki syntetyczne (`core_morale` § 1–3, ruch S1–S7) i referencyjne z gry (okna 578–590) są raportowane osobno.

## 10. Nieustalone [N]

- Przecięcie promienia z siatką i sortowanie kandydatów 0x50EC37; udany, potwierdzony rozkaz ataku przez MCP.
- Morale bohaterów (typ 6) – poziom z UCU+0xDC, podejrzenie BO-11. Morale wież (typ 2) – wieże poza Core.
- Fundament domu, przejęcie budynku-źródła, zmiana typ+0x428 przez ulepszenia, kolejność kandydatów z siatki
  regionów (remisy).
- Faza akumulatora 2000 ms przy starcie z migawki gry.
- Scenariusze 1 i 3–10 z priorytetu C; rozbieżności z priorytetu D (§ 8).
- Priorytet E (mapa jednostek dystansowych i pocisków) – nie rozpoczęty, bo A–D nie są zamknięte.

## 11. Jednostki dystansowe

Nie rozpoczęto (priorytet E zależy od zamknięcia A–D).

## 12. Prognoza i rekomendacja na etap 35

1. Rozkaz ataku przez MCP: cel widoczny bez automatycznego ataku, warunek listy renderu, potem scenariusze C 1, 3–10
   z tym samym wyzwalaczem stanem co 601.
2. 578 G3 takt 169 i 590 takt 97: kolejność fizyki i kolizji przy ruchomym celu w trybie 1.
3. 580: konsumenci RNG od taktu 146 (przeładowanie AoC i losowania Idle).
4. Morale bohaterów (typ 6) i fundamenty domów – po pomiarze.
