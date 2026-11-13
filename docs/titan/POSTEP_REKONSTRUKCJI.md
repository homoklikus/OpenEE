# Postęp rekonstrukcji silnika Titan

Dokument stały, aktualizowany w każdym etapie (od etapu 49). Opisuje, ile silnika Titan (Empire Earth / The Art of
Conquest) rozpoznano, ile odtworzono w OpenEE i ile potwierdzono pomiarem. Zmiany ocen uzasadnia się w rozdziale
„Historia ocen” na końcu, przyrostowo, bez przeliczania wszystkiego od nowa. Ocena może spaść, jeśli podsystem okaże
się większy, niż zakładano.

## 1. Co znaczy „rozpracowanie silnika”

Rozróżniamy trzy cele i ich nie mieszamy:

- **A. Rozpoznanie Titan** – wiemy, jakie są struktury danych, algorytmy, funkcje i zależności oryginału (kod EXE/DLL,
  pomiar pamięci). Źródła: `docs/titan/*.md`.
- **B. Implementacja OpenEE** – rozpoznany mechanizm jest odtworzony w niezależnym kodzie (Core C++ `cpp/core`,
  GDExtension, moduły Godot).
- **C. Zgodność zachowania** – OpenEE daje takie same wyniki jak oryginał w kontrolowanych eksperymentach (nagrania MCP
  co takt, testy bitowe).

Podsystem może mieć wysokie A i niskie B (wiemy, ale nie napisaliśmy) albo wysokie B i niskie C (napisane, niezmierzone).

## 2. Skala ocen (osobno dla A, B, C)

| Ocena | Znaczenie |
|---|---|
| 0 | niebadany |
| 1 | wstępnie rozpoznany (klasy, adresy, pojedyncze obserwacje) |
| 2 | częściowo rozpoznany lub zaimplementowany |
| 3 | zasadniczy mechanizm działa (w swoim zakresie) |
| 4 | szeroko przetestowany (wiele nagrań / przypadków) |
| 5 | kompletny w jasno zdefiniowanym zakresie i potwierdzony pomiarami |

Żaden podsystem nie ma oceny 5: nawet najlepiej zbadane (ruch, A*) mają znane braki. Ocena 4 nie oznacza
kompletności, tylko szerokie potwierdzenie zakresu, który już zbadano.

## 3. Katalog podsystemów i oceny (stan po etapie 52)

| # | Podsystem | A rozpoznanie | B implementacja | C zgodność | Pewność | Główny dowód | Dowody (wersja) |
|---|---|---|---|---|---|---|---|
| 1 | Wczytywanie plików i baz db*.dat | 4 | 4 | 4 | wysoka | FORMATY*.md, importery Godot, porównania tabel EE/AoC | EE+AoC |
| 2 | Format SCN i serializacja | 3 | 3 | 3 | średnia | import_mapy.md, generator czystych map, 4133 rekordów e42 | EE+AoC |
| 3 | Mapa i warstwy terenu | 3 | 3 | 3 | wysoka | GetMeshZ bitowo z DLL, klasyfikacja pól 99,6 % | EE+AoC [W] |
| 4 | Obiekty mapy i zajętość pól | 3 | 3 | 3 | średnia | listy pól EEMap (zad. 552), 647/650 – budynek na 4 polach | EE |
| 5 | Graf nawigacji (podsektory) | 3 | 3 | 3 | średnia | e35_a zgodna, przebudowa przyrostowa, koszary 2×2 = gra, budynek postawiony w grze (659: termin, id) | EE |
| 6 | Pathfinding (A*, Bounded, graf) | 4 | 4 | 4 | wysoka | 18 przypadków bitowo, 648 trasa = gra | EE+AoC |
| 7 | Fizyka ruchu (EEPMLand) | 4 | 4 | 4 | wysoka | S1–S7, 644 4148/4148, 648 prorok 3585/3585, obywatel 658/659 | EE (AoC: prędkość) |
| 8 | Kolizje (kontakty, odpychanie) | 4 | 3 | 3 | średnia | 0x549179 z gałęzią omijania, budynki w listach (652), 644/648/649 zgodne | EE (AoC [W]) |
| 9 | Kolejka fizyki i kolejność taktu | 3 | 3 | 3 | średnia | lista 0x918DDC (639), 649 koszary – budynek na liście | EE |
| 10 | Maszyny stanów .tai | 3 | 3 | 3 | średnia | Generic Movement/Attack, Prophet.tai, budynek, citizen.tai – budowa (658) | EE |
| 11 | System celów i rozkazów | 3 | 3 | 3 | średnia | kolejka celów, Shift, EEUGAttackUnit, EEUGLocation | EE |
| 12 | Walka i obrażenia | 3 | 3 | 3 | średnia | pojedynek 564, 631–634, dom 1v1 / 3v1 do śmierci | EE+AoC |
| 13 | Śmierć i usuwanie | 3 | 3 | 3 | średnia | 6000–6003, gruz 361/362, zapadanie budynku | EE |
| 14 | Budynki i budowanie | 4 | 3 | 4 | średnia | dom i koszary, koszt (potwierdzony w dbtechtree), wzór 0x60BF56 (K, m, n), dwóch budowniczych – 658 ×2, 659, 660, 674 zgodne w całości, 663 częściowo | EE |
| 15 | Jednostki cywilne | 3 | 3 | 3 | średnia | ucieczka (638), budowa (658–674), zbieranie drewna (673) | EE (+AoC prod.) |
| 16 | Zbieranie surowców | 3 | 2 | 2 | niska | EEUGGather 0x611420/0x611801, Gather.tai; drewno – pełny cykl ×2 zgodny (673) | EE |
| 17 | Ekonomia (zasoby, populacja) | 3 | 2 | 2 | średnia | zasoby (EE +0xAF8, AoC +0xAFC), populacja (EE +0xB10, AoC +0xB14), limit 1 + a + b + globalny (100), koszty z dbtechtree; 660–679 | EE+AoC |
| 18 | Produkcja jednostek | 3 | 3 | 3 | średnia | „Research Technology” → kolejka +0x48, start, odliczanie, utworzenie [W: AoC i EE]; 677 ×2 (AoC) i 679 (EE) zgodne w całości | EE+AoC |
| 19 | Technologie, epoki, ulepszenia | 2 | 1 | 1 | niska | premia prędkości 0x627078 [W+P]; schemat dbtechtree (koszt, czas, budujący), ścieżka badania „Research Technology” [W] | EE+AoC (bazy) |
| 20 | AI gracza komputerowego | 1 | 0 | 0 | niska | klasy EEComputerPlayer ×5 w każdej grze testowej (652) | EE |
| 21 | Dyplomacja i relacje | 1 | 1 | 1 | niska | tablica gracza +0x9E4 (wrogowie), sojusz 644 | EE |
| 22 | Widoczność i fog of war | 1 | 1 | 1 | niska | CanISeeEnemy pierwszy takt (G etapu 48), widoczny_dla [H] | EE |
| 23 | Świat, zwierzęta, obiekty neutralne | 1 | 0 | 0 | niska | zwierzęta losują RNG (644/646) | EE |
| 24 | Transport lądowy i morski | 0 | 0 | 0 | – | – | – |
| 25 | Lotnictwo | 0 | 0 | 0 | – | – | – |
| 26 | Animacja jednostek | 2 | 2 | 1 | średnia | sekwencje dbgraphics, klatki śmierci (Core) | nieustalone |
| 27 | Efekty graficzne i dźwięk | 1 | 1 | 1 | niska | render Godot (RAPORT_ZGODNOSCI_RENDEROWANIA) | AoC (dane) |
| 28 | Sterowanie gracza i interfejs | 2 | 2 | 1 | średnia | kamera [P], PPM/ramka/Shift w potyczce | EE+AoC |
| 29 | Warunki zwycięstwa, scenariusze, wyzwalacze | 0 | 1 | 0 | – | prosty warunek w potyczce | – |
| 30 | Multiplayer i synchronizacja | 1 | 0 | 0 | niska | lockstep, przydział taktów (DLL) | EE+AoC [W] |
| 31 | Zapis i wczytanie stanu gry | 0 | 0 | 0 | – | – | – |
| 32 | Losowość i deterministyczna symulacja | 3 | 3 | 2 | średnia | LCG, 2 losowania/takt, 646 190 taktów autonomicznie | EE (+AoC prod.) |
| 33 | Zegar symulacji i takt | 4 | 4 | 4 | wysoka | zegar_symulacji.md, przydzial_taktow.md | EE+AoC [W] |
| 34 | Efekty obszarowe i morale | 3 | 3 | 2 | średnia | EEAEMoraleFromBuildings, przebieg 2000 ms [P: kod] | EE |
| 35 | Bohaterowie i leczenie | 2 | 2 | 2 | średnia | EEUGHeal (644 sojusz) | EE |
| 36 | Kalamity (prorok, kapłan) | 1 | 0 | 0 | niska | Prophet.tai, klasy EEPCalamity* | EE |
| 37 | Grupy i szyk (formacje) | 2 | 0 | 0 | niska | grupy_ruchu.md, parametry szyku [P] | EE |
| 38 | Edytor scenariuszy | 0 | 0 | 0 | – | – | – |

Kolumna „Dowody (wersja)” (od etapu 52): gra, w której zebrano dowody ocen – EE (`Empire Earth.exe` e352d7ae…),
AoC (`EE-AOC.exe` db8fc5ce…) albo obie. Dotychczasowych ocen nie przeliczano: dowody etapów 29–51 pochodzą prawie
wyłącznie z EE (121 z 125 nagrań). Ocena A/B/C opisuje więc stan dla EE, o ile kolumna nie podaje AoC. Szczegóły i
statusy WSPÓLNY / ZMIENIONY / NIEZWERYFIKOWANY: `EE_AOC_POROWNANIE.md` § 5.

Katalog ma 38 pozycji: 32 z listy zadania etapu 49 i 6 dodanych po przeglądzie klas RTTI (zegar symulacji, efekty
obszarowe i morale, bohaterowie i leczenie, kalamity, grupy i szyk, edytor scenariuszy). Pozycje mają bardzo różną
wielkość – np. „AI gracza komputerowego” (69 klas `EEAI*` i ok. 60 `EECP*`) jest wielokrotnie większa niż „zegar
symulacji”.

## 4. Liczby zbiorcze

**Rozkład ocen** (liczba podsystemów na poziomach 0–5):

| Oś | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| A | 5 | 7 | 5 | 15 | 6 | 0 |
| B | 9 | 5 | 5 | 15 | 4 | 0 |
| C | 10 | 6 | 5 | 12 | 5 | 0 |

- Podsystemy z zasadniczym mechanizmem (ocena ≥ 3): A 21, B 19, C 17 z 38 (etap 51: 19 / 18 / 16; etap 50: 17 / 17 / 15).
- Podsystemy niebadane albo tylko wstępnie rozpoznane (≤ 1): A 12, B 14, C 16 z 38 (etap 51: 14 / 16 / 18).
- Niebadane wcale (A = 0): Transport lądowy i morski, Lotnictwo, Warunki zwycięstwa, scenariusze, wyzwalacze, Zapis i wczytanie stanu gry, Edytor scenariuszy.

**Średnia ocen bez wag** (tylko jako wskaźnik kierunku zmian, nie procent silnika): A 2,26, B 2,00,
C 1,89 na 5 (etap 51: 2,13 / 1,89 / 1,79; etap 50: 1,95 / 1,79 / 1,66; etap 49: 1,89 / 1,74 / 1,61). Skala jest porządkowa, a podsystemy nie mają równej wielkości, więc średnia **nie jest** procentem
ukończenia. Wag nie przypisujemy, bo nie ma wiarygodnej miary wielkości podsystemów.

**Wskaźniki obiektywne pokrycia kodu oryginału** (EE `Empire Earth.exe`, e352d7ae…) [P: narzędzia]:

| Wskaźnik | Wartość | Uwagi |
|---|---|---|
| procedury w analizie Ghidra | 25 928 | razem z CRT, bibliotekami i UI |
| różne adresy (0x401000–0x6FFFFF) cytowane w `docs/titan` | 940 po etapie 52 (od etapu 52 razem z adresami AoC – produkcja, porównanie wersji); 880 (etap 50: ok. 900; liczone wyrażeniem `0x[4-6]xxxxx` – ta sama metoda daje dla HEAD etapu 49 894, więc przyrost ok. +6) | górne oszacowanie funkcji rozpoznanych; część to adresy wewnątrz funkcji lub dane – ok. 3 % procedur |
| adresy cytowane w kodzie Core | 313 → 318 (etap 50) → 326 (etap 51) → 360 (etap 52, z adresami AoC) | mechanizmy z odwołaniem do oryginału w `cpp/core/src` |
| klasy RTTI w EXE | 1243 | w tym 356 `EEUI*` (interfejs), 69 `EEAI*`, ok. 120 `EEC*` (AI komputera) |
| klasy RTTI wymienione w dokumentacji / Core | 88 | ok. 7 %; wymienienie ≠ rozpoznanie |
| kod Core | ok. 5 500 wierszy C++ (etap 50: 5023, etap 51: 5348, etap 52: 5478) | `cpp/core/src` |

Wniosek: rozpoznana i odtworzona jest głównie **warstwa symulacji ruchu i walki pojedynczych jednostek lądowych**
(ruch, trasy, kolizje, stany `.tai`, walka wręcz, śmierć, budynki jako cele i przeszkody). To rdzeń, od którego
zależy reszta, ale w liczbie funkcji to kilka procent programu. Od etapów 50–52 dochodzi podstawowa pętla obywatela i
budynku (budowa, zbieranie drewna, produkcja obywatela, zasoby i populacja). Technologie, AI komputera, transport,
lotnictwo, zapis gry i multiplayer są prawie nietknięte.

**Trzy osobne miary (od etapu 52):**
- *rekonstrukcja głównej wersji badawczej AoC* – dowody z AoC mają: produkcja (18), ekonomia (17), walka częściowo (12),
  pathfinding w zmierzonych przypadkach (6), kamera i interfejs (28), bazy i SCN (1, 2). Pozostałe oceny ≥ 3 opierają się
  na EE i dla AoC wymagają powtórzenia pomiarów (`EE_AOC_POROWNANIE.md` § 7);
- *potwierdzenie zgodności z EE* – oceny C w tabeli (prawie wszystkie dowody z EE);
- *zakres OpenEE Core* – oceny B; Core ma jeden wspólny kod z jawnymi wariantami tylko tam, gdzie pomiar wykazał różnicę
  (`WariantTitan`: reguła obrotu, kolejność odbudowy kontaktów, losowania przy utworzeniu jednostki).

## 5. Pozostałe prace do pełnej rekonstrukcji

| # | Podsystem | Brakuje | Brak dotyczy | Zależności | Trudność | Następny kamień milowy |
|---|---|---|---|---|---|---|
| 1 | Wczytywanie plików i baz db*.dat | pola „Unknown” baz, część znaczeń kolumn | wiedza | – | niska | opis wszystkich kolumn dbobjects używanych przez Core |
| 2 | Format SCN i serializacja | znaczenie 16 atrybutów, źródło premii spoza SCN, wyzwalacze, zapis SCN z Core | wiedza+kod | 1 | średnia | powiązanie atrybutów SCN (lista 574 wpisów) z polami 0x626834 |
| 3 | Mapa i warstwy terenu | klify [N], woda, zmiany terenu | wiedza | 1, 2 | średnia | klify i woda w klasyfikacji pól |
| 4 | Obiekty mapy i zajętość pól | obrót budynków, obiekty Świata (drzewa) jako kontakty [N] | wiedza+weryfikacja | 2, 3 | średnia | pomiar drzew i obiektów Świata w listach kontaktów |
| 5 | Graf nawigacji (podsektory) | obszary +0xF4 – model z pomiaru, dodanie budynku w grze niezmierzone | weryfikacja | 3, 4 | średnia | pomiar grafu po postawieniu budynku |
| 6 | Pathfinding (A*, Bounded, graf) | gałęzie 0x4A2214 i n < 5 w 0x4A2B29, objazd 9002 bez pomiaru | weryfikacja | 5 | średnia | wymuszenie RepathAroundObstacle w grze |
| 7 | Fizyka ruchu (EEPMLand) | końcowy obrót przy kursie ≈ docelowemu (koszary 650), inne tryby fizyki (morze, powietrze) | weryfikacja | 3, 9 | niska | obrót końcowy proroka w 650 |
| 8 | Kolizje (kontakty, odpychanie) | duże jednostki 0x548A3C [H], brama, drzewa, obiekty Świata | kod+weryfikacja | 4, 7 | średnia | kolizja dużych jednostek (≥ 1,0) – pomiar |
| 9 | Kolejka fizyki i kolejność taktu | kiedy budynek wchodzi na listę fizyki przed śmiercią (649: na liście żywy) | wiedza | 7 | średnia | odczyt chwili dodania budynku do listy |
| 10 | Maszyny stanów .tai | zdarzenia klątw, transportu, zbierania; budowy – częściowo (BuildSiteValid/Clear [H]) | kod | 11 | średnia | zdarzenia zbierania (Gather) |
| 11 | System celów i rozkazów | EEUGGather, Patrol, Load/Unload; EEUGBuildRepair i HealUnit częściowo (naprawa, kolejka budowy [N]) | kod+wiedza | 10 | średnia | EEUGGather (zbieranie) |
| 12 | Walka i obrażenia | pociski, obszar, łucznicy, oblężenie, morale w walce | kod+weryfikacja | 11 | średnia | jednostka dystansowa z pociskiem |
| 13 | Śmierć i usuwanie | zwłoki jednostek, Spawn on death, efekty śmierci | kod | 12 | niska | zwłoki i Spawn on death |
| 14 | Budynki i budowanie | K i koszt z dbtechtree w odtworzeniach budowy (schemat znany od etapu 52), naprawa (gałąź +0x340 = 1), BuildSiteValid/Clear, pole zajęte, zwrot kosztu, pomiar w AoC | wiedza+kod | 11, 17 | średnia | budowa domu w AoC (wspólność wzoru 0x60BF56) i naprawa |
| 15 | Jednostki cywilne | zbieranie, naprawa, garnizon, TaskSmartCitizen (kolejne zadanie) | wiedza | 14, 16 | wysoka | obywatel z rozkazem zbierania |
| 16 | Zbieranie surowców | inne surowce (współczynnik tempa, indeks 0x636C96), wyczerpanie, wielu zbieraczy (WaitingArea), farmy, zwierzęta, wybór punktu kliknięcia | wiedza+weryfikacja | 15, 17 | wysoka | kamień/złoto i dwóch zbieraczy przy jednym źródle |
| 17 | Ekonomia (zasoby, populacja) | wpływ domów na limit (+0xB20/+0xB24 AoC [W]), śmierć jednostki, modyfikatory kosztów cywilizacji, wymiana i daniny | wiedza | 16 | średnia | dom a limit populacji (pomiar w AoC) |
| 18 | Produkcja jednostek | anulowanie (pomiar), zajęte miejsce wyjścia, limit populacji osiągnięty, punkt zbiórki, wybór płci, 0x631B55, inne budynki (koszary) | wiedza+weryfikacja | 14, 17 | średnia | produkcja w koszarach i anulowanie w AoC |
| 19 | Technologie, epoki, ulepszenia | badanie technologii (technologie bez obiektu), epoki, pozostałe atrybuty cywilizacji | wiedza+kod | 2, 17 | wysoka | badanie jednej technologii w AoC |
| 20 | AI gracza komputerowego | całość; losowania RNG AI [N] | wiedza | 32 | bardzo wysoka | funkcja planująca AI i jej losowania |
| 21 | Dyplomacja i relacje | zmiana relacji, edykty, głosowanie | wiedza | – | średnia | pomiar zmiany relacji |
| 22 | Widoczność i fog of war | mapa widoczności, odkrywanie, ukrycie | wiedza | 3 | średnia | odczyt mapy widoczności EEMap |
| 23 | Świat, zwierzęta, obiekty neutralne | zachowanie zwierząt, stada, polowanie | wiedza | 32 | średnia | stado w odtworzeniu |
| 24 | Transport lądowy i morski | całość | wiedza | 7, 11 | wysoka | EEUGLoadTransport |
| 25 | Lotnictwo | całość | wiedza | 7 | wysoka | EEUCAir* – rozpoznanie |
| 26 | Animacja jednostek | zgodność czasów animacji z grą | weryfikacja | 13 | średnia | pomiar klatek animacji ataku |
| 27 | Efekty graficzne i dźwięk | efekty EEEffect, dźwięki, muzyka | wiedza+kod | 26 | średnia | efekty śmierci |
| 28 | Sterowanie gracza i interfejs | panele, przyciski, budowa z interfejsu OpenEE, skróty | kod | 11 | wysoka | przycisk budowy w interfejsie OpenEE (rozkaz Core już jest) |
| 29 | Warunki zwycięstwa, scenariusze, wyzwalacze | wyzwalacze, kampanie, cele scenariusza | wiedza | 2 | wysoka | EEVictoryCondition – rozpoznanie |
| 30 | Multiplayer i synchronizacja | całość | wiedza | 32 | bardzo wysoka | – |
| 31 | Zapis i wczytanie stanu gry | całość | wiedza | wszystkie | wysoka | format zapisu gry |
| 32 | Losowość i deterministyczna symulacja | losowania AI i świata, zapadanie budynków | wiedza | 20, 23 | wysoka | pełny takt RNG bez stanu z nagrania |
| 34 | Efekty obszarowe i morale | leczenie z budynków, bohaterowie strategów | weryfikacja | 13 | średnia | pomiar morale przy domach |
| 35 | Bohaterowie i leczenie | zdolności bohaterów, okrzyk | kod | 34 | średnia | bohater strateg |
| 36 | Kalamity (prorok, kapłan) | całość | wiedza | 10, 12 | wysoka | pierwsza klątwa w pomiarze |
| 37 | Grupy i szyk (formacje) | całość w Core (status niewdrożony) | kod | 7 | średnia | ruch grupy w Core |
| 38 | Edytor scenariuszy | całość (klasy EESE*) | wiedza | 2 | średnia | – |

Terminu ukończenia całego silnika nie podajemy: tempo etapów dotyczy głównie ruchu i walki, a dla gospodarki, AI i
interfejsu nie ma jeszcze danych o tempie. Realistyczna kolejność: (1) domknięcie ruchu i kolizji (duże jednostki,
grupy), (2) obywatel: budowa i zbieranie, (3) ekonomia i produkcja, (4) technologie i epoki, (5) AI komputera.
Bez (2)–(4) nie da się uruchomić pełnej rozgrywki Empire Earth. Etap 50 zaczął punkt (2): obywatel stawia
budynek zgodnie z grą, ale bez kosztu, zbierania i produkcji gracz nie ma jeszcze z czego budować.

## 6. Jak aktualizować

1. Zmieniaj tylko oceny podsystemów, których dotyczył etap, i dopisz uzasadnienie w § 7 (co, dlaczego, dowód).
2. Nowy podsystem dopisz na końcu katalogu (nowy numer), nie zmieniaj numeracji.
3. Jeśli podsystem okazał się większy, obniż ocenę i zapisz powód.
4. Przelicz § 4 skryptem albo ręcznie z tabeli § 3; wskaźniki obiektywne odśwież narzędziami (`rtti_titan.py lista`,
   zliczenie adresów w `docs/titan`).
5. Raport etapu zawiera rozdział „Postęp rekonstrukcji Titan – ile zostało do końca?” (zasada w `CLAUDE.md`).

## 7. Historia ocen

**Etap 49 (pierwsza wersja, stan wyjściowy).** Oceny ustalone na podstawie dokumentacji etapów 14–49 i nagrań MCP.
Zmiany w samym etapie 49 (wliczone w tabelę):
- 8 Kolizje: A 3 → 4 – budynki z +0x2D8 na listach kontaktów [P: 648, 652], gałąź omijania przeładowującego
  sojusznika w 0x549179 [P: 649 dom 3v1]; B/C 3 – duże jednostki nadal [H].
- 7 Fizyka ruchu: C 4 – prorok 648 do końca (3585/3585).
- 19 Technologie i ulepszenia: 0 → 1 (A, B, C) – premia prędkości cywilizacji (0x627078, SetSpeed) [W + P].
- 12 Walka: C 3 – dom 3v1 i koszary 3v1 zgodne co takt do śmierci budynku.

**Etap 50.** Zmiany ocen:
- 14 Budynki i budowanie: A/B/C 2 → 3, pewność niska → średnia – cykl budowy domu przez obywatela rozpoznany
  (fundament HP 1 i +0x340, HP = postęp, BuildingRepaired 0x60BD19, zgłoszenie mapy +15000 ms) [P: 658 ×2, 659; W],
  odtworzony w Core i zgodny w całości w trzech nagraniach. Do oceny 4 brakuje kosztu, wielu typów budynków,
  wielu budowniczych i wzoru przyrostu.
- 15 Jednostki cywilne: 1 → 2 (A, B, C) – druga czynność obywatela (budowa) obok ucieczki.
- Bez zmiany ocen, nowe dowody: 5 Graf (budynek postawiony w grze: termin 97568 i id 1605 = gra), 7 Fizyka (obywatel:
  c4 = 1/a), 10 Maszyny stanów (citizen.tai – budowa; MoveToRepairSite = 8017), 2 SCN (lista atrybutów cywilizacji –
  struktura [P], znaczenie [N]), 32 Losowość (liczba losowań na takt w ruchu i w budowie [P], źródło dodatkowych [N]).
- Narzędzie porównania (`odtworzenie_nagrania.py`) sprawdza teraz kurs także w próbkach „nieaktualnych”; ujawniło to
  wcześniejsze różnice obrotu w 652 mur_rog (prorok od t = 75034 zamiast 93819) i 654 NE (42477 zamiast 42647) –
  oceny 7 i 8 bez zmian, bo różnice dotyczą znanych otwartych przypadków (obrót końcowy, FaceEnemy przy π).

**Etap 51.** Zmiany ocen:
- 14 Budynki i budowanie: A 3 → 4, C 3 → 4 – drugi typ budynku (koszary 2×2), koszt, wzór 0x60BF56 z kodu i z
  pomiaru (K z +0x27C, m z ulepszenia), dwóch budowniczych [W: 0x60D7A5, 0x60BF56; P: 660–674]; 5 nagrań budowy
  zgodnych w całości. B 3 – brak naprawy, walidacji miejsca i K z danych gry.
- 15 Jednostki cywilne: 2 → 3 (A, B, C) – budowa i zbieranie.
- 16 Zbieranie surowców: A 0 → 3 (EEUGGather: zdarzenia, cykl, ubytek, stany), B/C 0 → 2 – jeden surowiec i jeden
  zbieracz, pełny cykl drewna zgodny (673), punkty pracy [H].
- 17 Ekonomia: A 0 → 2 (pola zasobów, koszty), B/C 0 → 1 (zasoby i opłata w Core, koszty zgodne).
- Bez zmian ocen: 7 (ruch – nowa rozbieżność 673: zatrzymanie w 9006 przy v ≠ 0), 10, 11, 32 (dodatkowe losowania).

**Etap 52.** Zmiany ocen:
- 18 Produkcja jednostek: 0 → 3 (A, B, C), pewność średnia – ścieżka „Research Technology” → kolejka budynku (+0x48),
  start pozycji, odliczanie −34 ms/takt, utworzenie na krawędzi budynku; adresy osobno w AoC i EE [W]; Core; odtworzenia
  677 jeden 1898/1898 i dwa 3101/3101 (AoC) oraz 679 2996/2996 (EE) zgodne w całości, pozycje i kurs nowych jednostek =
  gra [P]. Do 4 brakuje anulowania, zajętego miejsca, limitu i innych budynków.
- 17 Ekonomia: A 2 → 3, B/C 1 → 2 – populacja (+0xB14 / +0xB10) i limit 1 + a + b + globalny [W + P: 677–679], koszty z
  dbtechtree w importerze; wpływ domów na limit niezmierzony.
- 19 Technologie: A 1 → 2 – schemat dbtechtree (koszt, czas, budujący, obiekt) potwierdzony pomiarami dla 4 rekordów,
  ścieżka komunikatu badania [W].
- Nowa zasada: kolumna „Dowody (wersja)”; dotychczasowe oceny bez zmian, z oznaczeniem, że ich dowody pochodzą z EE.
- Bez zmian ocen, nowe dowody: 32 Losowość (losowania przy starcie i utworzeniu jednostki – EE 3, AoC 1 [P]), 1 Bazy
  (pola kosztu i czasu dbtechtree w importerach).
