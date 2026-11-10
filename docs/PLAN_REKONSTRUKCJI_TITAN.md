# Plan rekonstrukcji silnika Titan (EE / AoC) i prognoza – etap 33

Dokument roboczy aktualizowany w każdym etapie. Zawiera:
- mapę rozpoznanych i nierozpoznanych systemów;
- zależności i ocenę trudności;
- strategię rozwoju warsztatu badawczego (REA/Ghidra, Riverlands_MCP, OpenEE Core);
- prognozę dla celów A / B / C i sposób jej aktualizacji.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

**Prognoza nie jest obietnicą terminu.** Szacunki są oddzielone od pomiarów (§ 4.1 – dane, § 4.3 – model). Prywatne
dane MCP i pełne dane źródłowe prognozy są poza repozytorium.

## 1. Mapa systemów

Kolumna „Dowody” wskazuje dokumenty atlasu. Trudność: 1 (prosta, dane z baz) … 5 (bardzo trudna: duża przestrzeń
stanów, trudny pomiar, niedeterminizm względem wejść).

| System | Stan rozpoznania | Dowody | Najważniejsze niewiadome | Trudność | Potrzebne eksperymenty | Możliwości MCP | Zależności |
|---|---|---|---|---|---|---|---|
| Zegar, takty, lockstep (część lokalna) | rozpoznany [P] | `zegar_symulacji.md`, `przydzial_taktow.md` | sieć, opóźnienia, resynchronizacja | 2 | gra sieciowa 2 instancje | odczyt kolejek komunikatów | – |
| Fizyka jednostki lądowej | rozpoznana i w C++ [P] | etapy 25–29, `precyzja_numeryczna.md` | znak drgania ω (EE 500), tps f32? | 2 | serie EE/AoC (gotowe) | `obs_rejestruj` [jest] | teren |
| Teren (wysokość, nachylenie, przejezdność) | rozpoznany [P/W]; import mapy SCN do Core (etap 30) [P/W] | `fizyka_terenu.md`, `import_mapy.md` | klify (9) [N], reguła rodziny wody 99,64% [W] | 2 | odczyt komórek EEMap (gotowe) | `ee_mapa` [jest] | formaty SCN |
| A* po polach, Bounded | rozpoznany i w C++ [P] | `astar_pola.md`, `astar_wyniki.md`, etap 29 | kary za jednostki, duże jednostki, przypadek F | 2 | trasy z jednostkami na drodze | odczyt maszyny A* po prośbie | teren, obiekty |
| Graf podsektorów, kontynenty | rozpoznany częściowo [W] | `architektura_nawigacji.md` | budowa grafu, trasy długie | 3 | długie trasy przez mapę | eksport grafu z pamięci | A* |
| Kolizje, odpychanie | wzór [P], lista kontaktów [W/H→częściowo P] | `walidacja_kolizji.md`, etap 29 | reguła obrysu, kolejność EE/AoC, duże jednostki | 3 | wiele jednostek, różne rozmiary | rejestracja kontaktów [jest] | fizyka |
| Objazd 9002 | kod [W], bez pomiaru (etapy 26–30: 0 z 7 prób) | `kolizje_objazdy.md` § 6, § 13 | próg czasu zablokowania nieosiągnięty (maks. 2011 ms) | 3 | dłuższe zablokowanie, wąskie przejście | kamera „pokaż punkt” [jest] | A*, kolizje |
| Kolejka celów, Shift | rozpoznana, w C++ [P/W] | `kolejka_rozkazow.md` | punkty +0x32, porzucenie, BO-4 | 2 | rozkazy Shift w ruchu | `obs_rozkaz(modyfikator)` [jest] | stany |
| Maszyna stanów `.tai` (ruch) | rozpoznana [P] | `skrypty_stanow.md` | – | 2 | – | rejestracja stanów [jest] | – |
| Maszyna stanów `.tai` (walka, transport, patrol, eksploracja) | składnia [P]; walka wręcz – stany i zdarzenia celu w Core (etap 31) [P/W]; reszta [N] | `skrypty_stanow.md` | ~150 zdarzeń, akcje wejścia | 4 | scenariusze walki | rejestracja przejść + celów | walka, transport |
| Formacje, grupy | rozpoznane [P/W] (etapy 17–20) | `grupy_ruchu.md` … `przydzial_specjalny.md` | 8 rodzajów szyku, „Szybko/Sprytnie” | 3 | grupy 2–50 jednostek | rejestracja wielu jednostek [jest] | kolejka, fizyka |
| Walka: cele, zasięg, tempo ataku | etap 31: wybór celu, podejście, łuk/obrót, pełny cykl wręcz w Core [P/W]; AoC przeładowanie [P]; porównanie z grą jakościowo zgodne, nie bitowe (rozjazd 1 takt od ~50 taktu) | `walka.md` § 8–14 | CompletedUnitFacing, kolejność kandydatów i listy fizyki, mgła, osiągalność, cfg wysokości, strzelcy | 4 | rozkaz ataku gracza, utrata celu, strzelcy, odczyt cfg | `ee_walka` + `pomiar_core walka` [jest] | stany, kolizje |
| Pancerze i obrażenia | wzór [P] (EE), tablice trafień [P] | `walka.md` | obszarowe, premie, AoC [W] | 3 | serie z ulepszeniami | `walka_tabele` [jest] | walka |
| Pociski, balistyka | [N] | – | trajektorie, trafienie, rozrzut | 4 | strzelcy, artyleria | śledzenie obiektów pocisków | walka, teren |
| Lotnictwo | [N] | – | paliwo, lotniska, ruch 3D | 4 | samoloty, śmigłowce | rejestracja obiektów powietrznych | nawigacja (klucz 4?), walka |
| Marynarka | [N] (klucz A* = 2 [W]) | `astar_pola.md` § 3 | modyfikator morski, transport | 3 | statki, transport | jak lądowe | A*, kolizje |
| Budynki: budowa, naprawa, zajmowanie pól | [N] | – | postęp budowy, wielu robotników | 3 | budowa 1–5 obywateli | odczyt postępu | ekonomia |
| Ekonomia, zbieranie | [N] | – | tempo zbierania, droga do magazynu, wyczerpanie złóż | 3 | zbieracze na różnych odległościach | liczniki surowców co takt | nawigacja, stany |
| Produkcja, kolejki budynków | [N] | – | czas, koszty, limit populacji | 2 | produkcja serii | odczyt kolejek | ekonomia |
| Technologie, epoki | dane [P] (bazy), logika [N] | `WARIANTY_EPOK.md` | warunki przejścia, efekty ulepszeń | 2 | badania technologii | odczyt stanu gracza | bazy |
| Cywilizacje (bonusy) | dane [P/W] | bazy `dbcivilization` | stosowanie bonusów | 2 | porównanie parametrów | odczyt parametrów typu | technologie |
| Kapłani, prorocy, klątwy, bohaterowie | [N] | `skrypty_stanow.md` (nazwy zdarzeń AoC) | nawrócenie, obszary działania | 4 | scenariusze specjalne | rejestracja efektów | walka, stany |
| AI taktyczne (jednostki) | częściowo (skrypty) | `.tai` | reakcje, pościg, powrót do ICL | 4 | walki z AI | rejestracja stanów wielu jednostek | walka |
| AI strategiczne (gracz komputerowy) | [N] | – | budowa gospodarki, ataki, pliki AI | 5 | długie partie z AI | zapis zdarzeń AI, RNG | prawie wszystko |
| Dyplomacja, warunki zwycięstwa, punktacja | [N] | – | – | 2 | – | odczyt stanu gracza | ekonomia, walka |
| Skrypty scenariuszy (wyzwalacze) | format częściowo [P] | `FORMATY_ETAP2/3.md` | warunki, efekty, kolejność | 3 | scenariusze testowe | odczyt stanu wyzwalaczy | większość systemów |
| Kampanie, przerywniki | [P] (wybór, przerywniki) | etap 13 | – | 2 | – | – | skrypty |
| Zapis gry | [N] (ziarno RNG w zapisie [W]) | etap 27 | pełny stan obiektów | 3 | zapis/odczyt i porównanie pamięci | zrzut struktur | wszystkie systemy |
| Multiplayer, sieć | lockstep lokalny [P] | `przydzial_taktow.md` | protokół, wyrównywanie, desync | 4 | 2 instancje lokalnie | podsłuch komunikatów | lockstep, determinizm |
| Rendering, animacje | OpenEE ma własny (etapy 1–10) | `FORMATY_ETAP4.md` | wierność efektów | 2 | porównania obrazów (narzędzia są) | `oe_ab`, zrzuty | – |
| Dźwięk | formaty [P] | `LOKALIZACJA.md` | logika odtwarzania | 1 | – | – | – |
| Edytor scenariuszy | [N] | – | – | 3 | – | – | formaty |
| Mechaniki AoC | częściowo (różnice ruchu [P]) | `POROWNANIE_MECHANIK_EE_AOC.md`, etap 27 | kosmos (klucz 0x10), bohaterowie, klątwy | 3 | serie AoC | `WariantTitan` w Core | wszystkie |

## 2. Zależności (kolejność)

```text
teren ─► A* ─► fizyka ─► kolizje ─► stany ruchu ─► formacje
                                   └► walka ─► pancerze/obrażenia ─► pociski ─► AI taktyczne ─┐
ekonomia (zbieranie ─► magazyn) ─► produkcja ─► budynki ─► technologie/epoki ──────────────────┼─► AI strategiczne
skrypty scenariuszy ◄── (wszystkie systemy) ; zapis gry ◄── (pełny stan) ; multiplayer ◄── determinizm całości ┘
```

AI strategiczne i multiplayer są na końcu. Wymagają zgodności prawie wszystkich systemów i deterministycznego RNG
całej gry. Etap 29 zmierzył ok. 12 kroków LCG na takt w scenariuszu testowym (11–33 między próbkami), a Core odtwarza ok. 2,4.

## 3. Strategia rozwoju warsztatu

### 3.1. Proces

```text
REA/Ghidra (statyka) ─► rozpoznanie algorytmu i pól ─► definicja odczytu w Riverlands_MCP
   ─► automatyczny eksperyment (obs_rozkaz / obs_rejestruj) ─► seria pomiarowa (JSON)
   ─► OpenEE Core: ten sam scenariusz ─► porównanie (core_porownanie_gra) ─► test regresyjny (CTest)
```

Etap 29 zamknął ten obieg dla ruchu i kolizji.
- Seria `obs_rejestruj` (MCP) → konwersja → `core_porownanie_gra` (C++) dała wynik bez ręcznych kroków pośrednich
  poza jednym skryptem konwersji.
- Dwie jednostki w ruchu: Core odtworzył pomiar ze średnim błędem 0,0003 pola i identyczną obecnością kontaktów w
  każdym takcie.

**Integracja narzędzi statycznych (REA – Cutter/rizin, Ghidra).** Statyka dostarcza adresów funkcji, przesunięć pól
i stałych. Są one dziś przepisywane ręcznie do:
- atlasu;
- definicji odczytu MCP (`POLA` w `ee_obserwacja.py`, `ee_warianty.py`);
- Core.

Najtańsze usprawnienia:
1. **Eksport mapy dostępu do pól.** Skrypt REA: funkcje czytające i piszące +X typu Y, osobno dla EE i AoC. Skraca
   wyszukiwanie „kto zmienia +0x248” z wielu zapytań do jednego wywołania.
2. **Wspólny opis struktury** (JSON: pole, typ, przesunięcie EE/AoC, pewność). Z niego powstają odczyt MCP,
   komentarze w `jednostka.hpp` i tabela w atlasie. Usuwa błędy przesunięć AoC (np. +0x268 / +0x33C).
3. **Ghidra headless** do zbiorczej dekompilacji grup funkcji (vtable typu). Wyniki tylko lokalnie – zasada atlasu.

Ocena (koszt 8–12 h łącznie) i zysk 20–35% czasu statyki są w § 3.3 i § 4.4. To szacunek – [H], dopóki pierwszy
podsystem (walka) nie zostanie zbadany z tymi narzędziami.

### 3.2. Zrealizowane w etapie 29 (Riverlands_MCP)

| Funkcja | Wąskie gardło, które usuwa | Wynik pomiaru |
|---|---|---|
| `obs_jednostki` | brak listy wszystkich jednostek z rzutem na ekran i separacją | 100+ obiektów z id, typem, stanem, pikselem, odległością do sąsiada |
| `obs_wybierz` | klik trafiał w model innej jednostki (etapy 26–27) | 18b: 1 próba; 18d: 4 próby (3 trafienia w 55c wykryte i powtórzone); 55c: 3 |
| `obs_rozkaz` | rozkaz dawany zaznaczonej przez przypadek jednostce, cel na cudzym modelu | wybór weryfikowany, cel sprawdzany (odmowa przy kolizji rzutu i poza kadrem) |
| `obs_rejestruj` (+ `_start`/`_stop` w tle) | 1 krok zadania na 1 odczyt, duplikaty, luki, brak trasy i celu | 5 jednostek co takt, 0 luk, 0 niespójnych odczytów, rozkazy w trakcie pomiaru |
| punkty trasy w odczycie | cel szacowany z serii (etap 27) | pierwszy i ostatni punkt kolejki +0x7C co takt |

### 3.2a. Zrealizowane w etapie 30

| Narzędzie | Koszt | Wynik pomiaru |
|---|---|---|
| kamera „pokaż punkt” (`ee_kamera`, `obs_rozkaz(pokaz)`) | ok. 20 min | 0 rozkazów odrzuconych za kadrem w zadaniach 554–570 |
| pełna kolejka celów i trasa (+0x90, +0x7C, +0x32) | ok. 20 min | rozpoznane cele EE/AoC, bez dereferencji niesprawdzonych wskaźników |
| `pomiar_core.py` (pomiar → Core) | ok. 25 min | 786 porównań pojedynku 564 bez różnic; walidacja 7 klas błędów |
| schemat struktur + indeks dostępów PE (`struktury_titan.json`, `indeks_pe.py`) | ok. 40 min | 103 pola; kandydaci odczytu/zapisu dla każdego pola w EE i AoC |
| `ee_mapa` + `eksport_mapy.py` | ok. 25 min | granice = pamięć, teren 99,64%, wysokości bez błędu |
| `ee_walka` (rejestrator walki) | ok. 20 min | pierwsza wiarygodna seria walki w 2. zadaniu z rejestratorem (564) |

### 3.3. Plan dalszych narzędzi (koszt → oszczędność)

Koszt w godzinach pracy agenta. Oszczędność szacowana na podstawie liczby przyszłych eksperymentów danego typu.

| Narzędzie | Koszt | Wielokrotność użycia | Oczekiwana oszczędność | Priorytet |
|---|---|---|---|---|
| ~~Konwerter `obs_rejestruj` → seria porównawcza Core~~ [etap 30: `pomiar_core.py`] | 1 h | każdy eksperyment ruchu/walki | 10–20 min na serię | 1 |
| ~~Kamera „pokaż punkt”~~ [etap 30] | 1–2 h | każdy rozkaz poza kadrem (548) | 1 nieudane zadanie z 3–4 | 1 |
| ~~Odczyt pełnej kolejki celów i trasy~~ [etap 30] | 1–2 h | ruch, Shift, AI | likwiduje szacowanie celu | 1 |
| ~~Rejestrator zdarzeń: HP, cel ataku, czasy ataku~~ [etap 30: `ee_walka`, ok. 20 min] | 3–4 h | cała walka (setki serii) | podstawowe dla walki | 2 |
| Liczniki gracza: surowce, populacja, kolejki produkcji | 2–3 h | ekonomia, produkcja, AI | jw. | 2 |
| Śledzenie obiektów tymczasowych (pociski) | 3–5 h | pociski, artyleria | jw. | 3 |
| ~~mapa „kto czyta/pisze pole +X typu Y”~~ [etap 30: `indeks_pe.py` na capstone, REA nie zdążyło dekompilować] | 4–6 h | każdy nowy podsystem | 20–40% czasu statyki | 2 |
| Automatyczny generator definicji odczytu MCP z opisu struktury w atlasie | 3 h | każdy nowy podsystem | błędy przesunięć EE/AoC | 3 |
| Licznik losowań RNG z przypisaniem do miejsca (pułapka – wymaga debuggera) | 6–10 h; zgodne z zasadami tylko jako odczyt / breakpoint | lockstep, AI | kluczowe dla AI i multiplayera | 3 |
| Dwie instancje gry (multiplayer lokalny) + odczyt kolejek sieciowych | 8–15 h | multiplayer | bez tego multiplayer nie jest badany | 4 |

**Malejące korzyści.** Gdy eksperymenty są już tanie, ograniczeniem stają się:
- analiza statyczna nowych, dużych funkcji (AI);
- decyzje i przegląd użytkownika (każdy etap jest zlecany i sprawdzany);
- problemy, których nie da się zmierzyć wprost (intencje AI, rzadkie sytuacje).

Dalsza automatyzacja tych elementów daje coraz mniej.

## 4. Prognoza

### 4.1. Dane wejściowe (pomiary z repozytorium)

- **Historia Git** (znaczniki commitów, czas lokalny):
  - etapy 14–24 (rozpoznanie od zegara do A*): 2026-11-07 12:19 → 18:20, 11 etapów w ok. 6 h (27–56 min na etap);
  - etapy 25–28: 07:10 → 11:39, 4 etapy w ok. 4,5 h (25 ≈ 1 h, 26 ≈ 1 h, 27 ≈ 2 h 9 min, 28 ≈ 1 h 23 min);
  - etap 29 – ok. 3 h.
- **Zadania Riverlands_MCP** (`ee_zadania`, 505 wyników):

  | Etapy | Zadania | Odczyty pamięci | Uwagi |
  |---|---|---|---|
  | 14–24 | 129 | ok. 950 | |
  | 25–27 | 52 | 30 500 | odczyt krok po kroku |
  | 29 | 7 | 6 rejestracji = 5 000+ próbek wielu jednostek | |
  | 8–13 | ok. 240 | – | 33 zadania z błędem (14%) |
  | 14–29 | 260 | – | 4 zadania z błędem (1,5%) |

- **Nieudane próby w zakresie celu badawczego:**
  - dwie jednostki w ruchu w etapie 27 – 4 zadania, 0 udanych serii;
  - w etapie 29 – 5 zadań, 1 udana seria czołowa (547) i 1 seria mijania (546);
  - objazd 9002: etapy 26, 27 i 29 – 0 z 5 prób.
- **Charakter pracy w ruchu jednostek** (etapy 14–29), z raportów:
  - ok. 40% analiza statyczna;
  - ok. 35% eksperymenty;
  - ok. 15% modele i porównania;
  - ok. 10% dokumentacja.

  To ocena z przebiegu etapów, nie pomiar czasu – [H].

### 4.2. Jednostka nakładu

Za jednostkę przyjmujemy pracę włożoną w **podsystem ruchu lądowego**:
- etapy 14–29: od zegara przez rozkazy, grupy, cele, A*, fizykę, kolizje i stany;
- do implementacji C++ z testami zgodności.

Wynosi ona ok. 17 h pracy agenta. Dochodzi ok. 8 h pracy użytkownika (przygotowanie etapów, przegląd, decyzje) –
szacunek z liczby etapów (16) × ok. 30 min.

Razem **J ≈ 25 h** na jednostkę.

Podział J (z przebiegu etapów 14–29):

| Rodzaj pracy | Udział |
|---|---|
| reverse engineering | 60% |
| implementacja C++ | 18% |
| integracja Godot | 6% |
| testy zgodności | 10% |
| automatyzacja MCP | 6% |

### 4.3. Wagi pozostałych podsystemów (w jednostkach J)

Wagi wynikają z porównania z ruchem:
- liczba stanów i parametrów;
- trudność pomiaru (deterministyczny pojedynek – łatwo; AI w długiej partii – trudno);
- liczba zależności (§ 2).

Są to oceny, nie pomiary – [H]. Ich niepewność opisuje zakres scenariuszy.

| Podsystem | Waga J | Cel A (grywalne) | Cel B (wierne główne) | Cel C (prawie pełne) |
|---|---|---|---|---|
| reszta ruchu (9002, duże jednostki, formacje, morze, transport) | 0,8 | 0,3 | 0,8 | 0,8 |
| lotnictwo | 0,6 | 0,2 | 0,6 | 0,6 |
| walka, pancerze, obrażenia [Etap 30 – zastąpione: 1,1 / 0,6, zob. § 4.7] | 1,5 | 0,8 | 1,5 | 1,5 |
| pociski | 0,6 | 0,3 | 0,6 | 0,6 |
| ekonomia, zbieranie, produkcja, budynki | 1,2 | 0,8 | 1,2 | 1,2 |
| technologie, epoki, cywilizacje | 0,6 | 0,4 | 0,6 | 0,6 |
| jednostki specjalne (kapłani, prorocy, bohaterowie, klątwy) | 0,7 | 0,2 | 0,7 | 0,7 |
| AI taktyczne (pozostałe `.tai`) | 1,0 | 0,4 | 1,0 | 1,0 |
| AI strategiczne | 3,0 (zakres 2–6) | 0,6 | 1,5 | 3,0 |
| dyplomacja, zwycięstwo, punktacja | 0,4 | 0,3 | 0,4 | 0,4 |
| skrypty scenariuszy, kampanie | 1,2 | 0,4 | 1,2 | 1,2 |
| zapis gry | 0,8 | 0,2 | 0,5 | 0,8 |
| multiplayer, sieć | 1,5 | 0 | 0,8 | 1,5 |
| mechaniki AoC (kosmos, różnice) | 0,8 | 0,2 | 0,8 | 0,8 |
| integracja Core z grą Godot (migracja scen, UI) | 1,0 | 1,0 | 1,0 | 1,0 |
| edytor, rendering wierny, przypadki graniczne i błędy (+25% B) | – | 0 | 0 | 1,0 + 3,0 |
| **Suma** | | **6,1 J** | **13,2 J** | **20,7 J** |

**Rosnąca złożoność.** Późniejsze podsystemy zależą od wcześniejszych i trudniej je mierzyć. Przyjmujemy mnożnik
1,0 dla A, 1,15 dla B i 1,3 dla C – [H], z obserwacji: etap 27 (walidacja) zajął 2× więcej niż etapy 14–24.

### 4.4. Trzy modele warsztatu

Współczynnik przyspieszenia nie jest arbitralny. Wynika z udziałów pracy (§ 4.2) i z redukcji czasu każdego rodzaju
pracy zmierzonej albo szacowanej z etapu 29, pomniejszonej o koszt budowy narzędzi.

| Rodzaj pracy (udział) | Bez rozwoju | Realistyczny rozwój | Silna automatyzacja | Podstawa |
|---|---|---|---|---|
| eksperymenty (35% RE) | 0% | −55% | −70% | etap 29: wybór jednostki 1–4 próby zamiast niewykonalnego; rejestracja 1 krok zamiast ~500; luki 0 |
| analiza statyczna (40% RE) | 0% | −20% | −35% | planowane mapy xref i generator definicji (§ 3.3), bez pomiaru – [H] |
| modele i porównania (15% RE) | 0% | −50% | −60% | etap 29: `core_porownanie_gra` zastąpiło model Python + ręczne metryki |
| dokumentacja (10% RE) | 0% | −10% | −25% | szablony atlasu; niewiele do automatyzacji |
| implementacja i testy C++ | 0% | −15% | −25% | testy referencyjne generowane z serii |
| koszt rozwoju narzędzi | 0% | +8% całości | +15% całości | § 3.3: ok. 30–60 h narzędzi na B |
| **przyspieszenie wynikowe (asymptotyczne / średnie w projekcie)** | **1,0×** | **≈ 1,28× / 1,25×** | **≈ 1,43× / 1,4×** | |

Obliczenie (realistyczny):
- RE: 0,35·0,55 + 0,40·0,20 + 0,15·0,50 + 0,10·0,10 = 0,36, czyli RE × 0,64;
- praca agenta na J: 0,60·0,64 + 0,18·0,85 + 0,06·1,0 + 0,10·0,85 + 0,06 = 0,74, a +8% na narzędzia daje 0,80,
  czyli 17 h → 13,6 h;
- praca użytkownika na J: −25%, bo jeden etap mieści więcej pomiarów (etap 29: 1 zadanie zamiast 4–5), czyli
  8 h → 6 h;
- razem 19,6 h zamiast 25 h, czyli **1,28×**.

Silna automatyzacja: RE × 0,50, agent 0,63 + 15% = 0,725 (12,3 h), użytkownik −35% (5,2 h), razem 17,5 h,
czyli **1,43×**.

**Efekt kuli śnieżnej.** Narzędzia przybywają stopniowo, więc pierwsze podsystemy po etapie 29 korzystają z nich
mniej. Do obliczeń przyjęto średnią w projekcie: 1,25× i 1,4×. Wartości asymptotyczne są osiągane po ok. 3–4
podsystemach (walka, ekonomia), gdy rejestratory zdarzeń i liczniki gracza (§ 3.3) już istnieją.

**Granica.** Nawet przy pełnej automatyzacji eksperymentów zostają:
- statyka nowych systemów;
- przegląd użytkownika;
- AI strategiczne, którego nie da się zmierzyć krótkim scenariuszem.

Dlatego przyspieszenie powyżej ok. 2× nie jest zakładane.

### 4.5. Wynik

[Etap 30 – zastąpione: aktualne liczby w § 4.7. Tabele poniżej zostają jako zapis prognozy etapu 29.]

Intensywność pracy przyjęta jako parametr:

| Wariant | Godzin pracy agenta tygodniowo | Podstawa |
|---|---|---|
| ostrożny | 10 | |
| realistyczny | 18 | 3 sesje po ok. 6 h, jak etapy 25–29 |
| optymistyczny | 30 | jak 7–8 listopada |

**Nakład** = Σ wag × J × mnożnik złożoności ÷ przyspieszenie.

| Cel | Nakład bez rozwoju narzędzi | Realistyczny rozwój (÷1,25) | Silna automatyzacja (÷1,4) |
|---|---|---|---|
| A – grywalne | 6,1 J ≈ **150 h** | ≈ 120 h | ≈ 107 h |
| B – wierne główne mechaniki EE i AoC | 13,2 J × 1,15 ≈ **380 h** | ≈ 304 h | ≈ 271 h |
| C – prawie pełna rekonstrukcja | 20,7 J × 1,3 ≈ **670 h** | ≈ 536 h | ≈ 479 h |

Podział nakładu (według § 4.2, realistyczny rozwój):

| Cel | RE | C++ | Godot | Testy | MCP |
|---|---|---|---|---|---|
| A | 66 h | 25 h | 9 h | 11 h | 9 h |
| B | 165 h | 64 h | 21 h | 30 h | 24 h |
| C | 290 h | 113 h | 38 h | 52 h | 43 h |

Podział oszacowano proporcjonalnie (RE 0,64·0,60/0,80 ≈ 48% czasu agenta; narzędzia ok. 8%). Integracja Godot jest
zawyżona w A o migrację scen (waga 1,0 J).

Czas kalendarzowy:
- scenariusz realistyczny – nakład ÷ 18 h/tydz.;
- scenariusz ostrożny – nakład × 1,6 (niepewność wag, AI) ÷ 10 h/tydz.;
- scenariusz optymistyczny – nakład × 0,85 ÷ 30 h/tydz.

| Cel | Model warsztatu | Ostrożny | Realistyczny | Optymistyczny |
|---|---|---|---|---|
| A | bez rozwoju | 24 tyg. | 8 tyg. | 4 tyg. |
| A | realistyczny | 19 tyg. | 7 tyg. | 3,5 tyg. |
| A | silna automatyzacja | 17 tyg. | 6 tyg. | 3 tyg. |
| B | bez rozwoju | 61 tyg. | 21 tyg. | 11 tyg. |
| B | realistyczny | 49 tyg. | **17 tyg.** | 9 tyg. |
| B | silna automatyzacja | 43 tyg. | 15 tyg. | 8 tyg. |
| C | bez rozwoju | 107 tyg. | 37 tyg. | 19 tyg. |
| C | realistyczny | 86 tyg. | **30 tyg.** | 15 tyg. |
| C | silna automatyzacja | 77 tyg. | 27 tyg. | 14 tyg. |

**Niepewność:**
- cel A: ±40%;
- cel B: −30% / +80%;
- cel C: −30% / +120%.

Główne źródło niepewności to waga AI strategicznego (2–6 J zamiast 3). Przy 6 J cel C wydłuża się o ok. 120 h.

**Warunki opóźnienia:**
- AI strategiczne oparte na plikach lub regułach o dużej przestrzeni stanów;
- desynchronizacja RNG wymagająca odtworzenia wszystkich miejsc losowań (dziś ok. 12 kroków na takt, Core odtwarza
  ok. 2,4);
- multiplayer wymagający dwóch instancji gry i analizy protokołu;
- brak dostępności użytkownika między etapami;
- ograniczenia środowiska (np. usuwanie plików w folderze, czas jednego polecenia).

**Przyspieszenie dzięki MCP.** Największe przy:
- walce, ekonomii i produkcji – krótkie, powtarzalne scenariusze, liczniki w pamięci;
- formacjach – wiele jednostek naraz.

Najmniejsze przy AI strategicznym, multiplayerze i edytorze.

### 4.6. Aktualizacja prognozy

Po każdym etapie:
1. Zapisz czas etapu (commit), liczbę zadań MCP, udanych serii i nieudanych prób.
2. Zaktualizuj stan w tabeli § 1. Wagę podsystemu ukończonego w danym etapie zastąp rzeczywistym nakładem.
3. Przelicz J jako średni nakład na jednostkę wagi z ukończonych podsystemów. Gdy J rośnie, prognoza rośnie
   proporcjonalnie.
4. Przelicz przyspieszenie z rzeczywistych udziałów i redukcji. Dla każdego nowego narzędzia zapisz koszt i liczbę
   użyć (metryki `obs_metryki` i rejestr zadań).
5. Rozbieżność > 30% między prognozą a wykonaniem dla dwóch kolejnych podsystemów oznacza, że wagi trzeba zmienić.

### 4.7. Aktualizacja po etapie 30

**Pomiar etapu 30** (czas UTC z commitów i plików zadań; [P]):

| Element | Wartość |
|---|---|
| początek etapu | ok. 12:45 (commit etapu 29: 12:42) |
| zadania MCP | 23 (549–571), 13:23 → 14:27 |
| zadania nieudane lub z błędem kroku | 7 (552–554, 556, 559–561: kamera, wybór w tłumie, kolejność startu pojedynku) |
| pierwsza wiarygodna seria walki | 14:09 (zadanie 564), ok. 1 h 25 min od początku etapu |
| odtworzenie pojedynku przez Core | 786 porównań w taktach, 0 różnic |
| koniec (commit) | ok. 14:50 |

Podział czasu agenta (szacunek z przebiegu, [H]): narzędzia ok. 40 min, mapa ok. 25 min, statyka walki ok. 25 min,
eksperymenty ok. 45 min, implementacja C++ ok. 15 min, reszta – testy i dokumentacja.

**Kula śnieżna (§ 18 zlecenia).** Narzędzia etapów 29–30 skróciły drogę do pierwszego wiarygodnego pomiaru nowego
podsystemu: walka – pierwszy pomiar po ok. 1 h 25 min i ok. 15 zadaniach, z czego pierwsze 8 dotyczyło jeszcze
samego ustawienia pojedynku. Dla porównania ruch lądowy (etapy 14–24) wymagał 11 etapów i 129 zadań do pierwszego
modelu C++. Pojedynek 1:1 to jednak najprostszy przypadek walki – nie wolno tego przenosić wprost na 1:N, pościg
i pociski. [W]

**Zmiana wag:**
- walka wręcz 1:1 (wzór obrażeń, tablice trafień, przeładowanie, czas trafienia, śmierć) jest rozpoznana [P] w ok.
  0,1 J – dużo mniej niż zakładano;
- pozostaje: wybór celu, pościg, strzelcy, obszarowe, AoC (losowe przeładowanie), 1:N;
- waga walki: B/C 1,5 → **1,1 J**, A 0,8 → **0,6 J**. Pozostałe wagi bez zmian (za mało danych, § 4.6 pkt 5).

Sumy: A **5,9 J**, B **12,8 J**, C **20,3 J**. J i przyspieszenie bez zmian: zmierzone redukcje są zgodne z modelem
realistycznym, a jeden etap to za mało, żeby je przeliczyć.

| Cel | Bez rozwoju | Realistyczny (÷1,25) | Silna automatyzacja (÷1,4) | Realistyczny, 18 h/tydz. |
|---|---|---|---|---|
| A | ≈ 148 h | ≈ **118 h** | ≈ 105 h | ≈ 6,5 tyg. |
| B | 12,8 × 1,15 × 25 ≈ 368 h | ≈ **294 h** | ≈ 263 h | ≈ **16 tyg.** (bez rozwoju 20, silna automatyzacja 15) |
| C | 20,3 × 1,3 × 25 ≈ 660 h | ≈ **528 h** | ≈ 471 h | ≈ **29 tyg.** |

Niepewność bez zmian (§ 4.5). Prognoza nadal nie jest obietnicą terminu.

### 4.8. Aktualizacja po etapie 31

**Pomiar etapu 31** (czas UTC z commitów i plików zadań; [P]):

| Element | Wartość |
|---|---|
| początek etapu | 14:43 (commit etapu 30) |
| zadania MCP | 13 (572–584), 15:07 → 16:00 |
| zadania nieudane lub z błędem kroku | 7 (572–574, 577: odprawa/kamera; 582–584: gra nie przeszła odprawy – kursor zablokowany przy aktywnym pulpicie użytkownika) |
| udane serie walki | 4 (578 EE 1:1 i 2:1, 579 EE obywatel, 580 AoC 1:1, 581 AoC obywatel) + odczyty 575/576 |
| pełny cykl w Core bez parametru „takt ataku” | ok. 15:45 (pierwsze porównanie okna 578 G1) |
| koniec (commit) | ok. 16:30 |

Podział czasu (szacunek, [H]): statyka wyboru celu/podejścia/łuku ok. 35 min, eksperymenty i narzędzia ok. 30 min,
implementacja Core ok. 30 min, testy, synchronizacja i dokumentacja – reszta.

**Nakład dotychczasowy na walkę** (etapy 30–31): ok. 3,5 h ≈ 0,14 J [P z czasu commitów].

**Ocena.** Etap dał pełny cykl w Core, ale nie zgodność bitową: pierwsze różnice pojawiają się w 48.–58. takcie i
wynikają głównie z systemów spoza walki (CompletedUnitFacing w maszynie ruchu, kolejność listy fizyki, dryf
kolizji). Odkryto nowe niewiadome (cfg wysokości, mgła, kolejność stref, osiągalność). Zgodnie z § 4.6 nie skracam
prognozy tylko dlatego, że etap się skończył: wagę walki obniżam o zużyte 0,14 J i podnoszę o ok. 0,05 J za
nowe niewiadome.

| Cel | Pozostało (J) | Realistyczny (÷1,25) | Realistyczny, 18 h/tydz. | Zużyte od etapu 30 |
|---|---|---|---|---|
| A | 5,9 − 0,09 ≈ **5,8 J** | ≈ **116 h** | ≈ **6,4 tyg.** | ≈ 3,5 h |
| B | 12,8 − 0,09 ≈ **12,7 J** | ≈ **292 h** | ≈ **16 tyg.** | ≈ 3,5 h |
| C | 20,3 − 0,09 ≈ **20,2 J** | ≈ **525 h** | ≈ **29 tyg.** | ≈ 3,5 h |

Liczby to prognoza **pozostałej** pracy; czas zużyty jest w ostatniej kolumnie, nie odejmowany drugi raz.
Niepewność bez zmian (§ 4.5). Prognoza nadal nie jest obietnicą terminu.

### 4.9. Aktualizacja po etapie 32

**Pomiar etapu 32** (czas lokalny Europe/Warsaw z plików zadań i sesji; [P]):

| Element | Wartość |
|---|---|
| początek etapu | ok. 19:43 |
| zadania MCP | 6 (585–590): 2 diagnostyka pulpitu, 4 pomiary |
| niepowodzenia startu gry | 0 (od wprowadzenia inhibitora wygaszacza; etap 31: 3 z 3 ostatnich) |
| nieudane kroki | rozkaz ataku (3 próby), odwrót w złym momencie (589) |
| 578 G1 bez żadnej różnicy | ok. 20:30 (ok. 45 min od początku) |
| koniec (commit) | ok. 21:30 |

**Ocena.** Pierwsza rozbieżność walki EE okazała się rozbieżnością ruchu (zakończenie obrotu i przycięcie kroku
obrotu) – poprawka z kodu Titan usunęła ją i poprawiła też zgodność serii ruchu EE 500. 578 G1 jest zgodny w całym
oknie; 578 G3 – pierwsza różnica w takcie 102 (obrażenia 13 vs 16, przyczyna [N]); 580 G1 (AoC) – takt 36 (reguła
obrotu AoC). Nowe niewiadome: mnożnik 0,8 przy trafieniach 857 / AoC / obywatel, permutacja kandydatów 0x40CFC7,
reguła obrotu AoC przy Δ = 0. Walka wręcz ma dziś dokładny przebieg dla 1:1 EE, co skraca resztę pracy nad walką.

| Cel | Pozostało (J) | Realistyczny (÷1,25) | Realistyczny, 18 h/tydz. | Zużyte od etapu 30 |
|---|---|---|---|---|
| A | 5,8 − 0,05 ≈ **5,75 J** | ≈ **115 h** | ≈ **6,4 tyg.** | ≈ 5,5 h |
| B | 12,7 − 0,05 ≈ **12,65 J** | ≈ **291 h** | ≈ **16 tyg.** | ≈ 5,5 h |
| C | 20,2 − 0,05 ≈ **20,15 J** | ≈ **524 h** | ≈ **29 tyg.** | ≈ 5,5 h |

Spadek tylko o część zużytego nakładu (~2 h ≈ 0,08 J), bo pojawiły się nowe niewiadome (≈ 0,03 J). Prognoza nie jest
obietnicą terminu.

### 4.10. Aktualizacja po etapie 33

**Pomiar etapu 33** (czas lokalny; [P]): początek ok. 20:55, zadania MCP 591–601 (11): 4 odczyty (modyfikatory,
EEPhysics), 7 eksperymentów walki; niepowodzenia startu – 2 (592: wczytanie scenariusza AoC; 601: odprawa,
ponowione automatycznie z sukcesem); rozkaz ataku – 3 nieudane zadania; koniec ok. 22:45.

**Ocena.** Zamknięto dwie niewiadome z etapu 32 (współczynnik 0,8 – morale; obrót AoC przy Δ ≈ 0). Pojawiły się
nowe: źródła morale (budynki: typy, zasięg, maksimum – potrzebne do Core bez pomiaru), rozkaz ataku przez MCP
(obiekt pod kursorem), kurs w trybie 1 przy ruchomym celu (590 takt 97). Bilans pracy nad walką zbliżony do zera:
zużyte ok. 1,8 h ≈ 0,07 J, nowe niewiadome ≈ 0,05 J.

| Cel | Pozostało (J) | Realistyczny (÷1,25) | Realistyczny, 18 h/tydz. | Zużyte od etapu 30 |
|---|---|---|---|---|
| A | ≈ **5,73 J** | ≈ **115 h** | ≈ **6,4 tyg.** | ≈ 7,3 h |
| B | ≈ **12,63 J** | ≈ **290 h** | ≈ **16 tyg.** | ≈ 7,3 h |
| C | ≈ **20,13 J** | ≈ **523 h** | ≈ **29 tyg.** | ≈ 7,3 h |

Prognoza nie jest obietnicą terminu.

### 4.11. Aktualizacja po etapie 34

- **Morale z budynków – zamknięte w zakresie TC/Capitol** [P: kod EE i AoC, dane, odczyt]: reguły źródła, poziomu,
  obszaru, relacji, wielu źródeł i chwili aktualizacji (`walka.md` § 25). Core liczy morale sam (5/5 okien = gra).
  Otwarte: bohaterowie (typ 6, BO-11), wieże (typ 2), fundamenty, przejęcie źródła.
- **Efekty obszarowe** jako podsystem: menedżer co 2000 ms jest wspólny dla leczenia (szpital, port, medyk), ochrony
  przed klęskami/konwersją (świątynia, uniwersytet), ekonomii TC i maskowania. Szkielet w Core przyjmuje te typy, ale
  ich działania nie odtwarza. Szacunek: 1 etap na leczenie i regenerację z pomiarem.
  Etap 38: regeneracja własna jednostek (0x625B47, typ+0x578, odliczanie +0x290) zamknięta [P: kod + 619]; leczenie
  innych (Healer.tai 16000, efekt 138) i stan 5001 bohatera – otwarte.
- **Wielu atakujących na jeden cel** (etap 38, [P] pomiar 619/620): druga gwardia omija zajęte miejsce podejścia,
  wstawia EEUGLocation przed celem ataku i po drugim 9006 usuwa cel gracza. Kod testu zajętości (0x632CF4/0x63234D) –
  następny krok; szacunek 1 etap z pomiarem.
  Etap 39: test zajętości 0x63234D wdrożony [W/P: 619, 578 G3]; pozostaje graf podsektorów (0x4A26E3 – pośrednie
  EEUGLocation) i 0x62D696 (A* Bounded w EnemyUnitReachable). Szacunek: 1–2 etapy (odczyt grafu z pamięci, potem budowa).
  Etap 40: graf podsektorów (A* 0x4A5807, punkty 0x4A26E3, 9016/8021) i 0x62D696 w Core; graf odczytany z gry –
  budowa podsektorów (0x42434F/0x41E990) to następny krok (1–2 etapy; test referencyjny: odczyt e35_a).
  Etap 41: sąsiedzi i punkty reprezentatywne z kodu w Core [P]; brak siatki regionów (0x423E3F) i reguły floodu –
  graf nadal z przydziału pól odczytanego z gry.
  Etap 42: regiony 0x4240D3 i flood podsektorów odtworzone [P 39 480/39 480]; graf Core z wejścia mapy; brakująca
  część autonomii – klasyfikacja obiektów pól (+0x04, +0x14) i kod budowy obszarów +0xF4 [N].
  Etap 43: reguła rodzaju pola z kodu (Tile::SetKind 0x516E8C) i +0x14 wody w Core [P 39 341/39 480; znak 19 595/19 610];
  graf z SCN eksperymentalny (619/620 jak gra). Brakuje: 139 pól klifów (ślad dynamiczny), obiektów pól w Core
  (rejestracja z dbobjects, flaga +0x612), +0x14 lądu i kodu obszarów +0xF4. Szacunek: 1–2 etapy do grafu z samego SCN.
  Etap 44: graf wyłącznie z SCN i baz gry [P: e35_a 1857/1857, e13_para 1320/1320; 619/620 jak gra] – klify 0x512FB0,
  obiekty pól i +0x612 (zestaw 9), bok sektora 0x42439A; obszary – model z pomiaru [N kod]. Potyczka używa grafu.
  Kolejka fizyki 0x918DDC (kolejność x, y) i śmierć 6000–6003 z danych typu. Dalej: kolejność obiektów dodanych w grze,
  skrypty obywatela i bohatera, kod obszarów 0x427D42.
- **Wybór obiektu pod kursorem** [P/W]: 0x50EC37 – lista renderu kamery + `GEPhysicalModel::Intersects` (DLL).
  Odtworzenie przecięcia z siatką wymaga modeli (poza zakresem Core). Dla automatyzacji wystarcza warunek listy renderu
  i potwierdzenie kolejką celów.
- Priorytety etapu 35: rozkaz ataku przez MCP z widocznym celem i scenariusze C; 578 G3 takt 169 i 590 takt 97
  (tryb 1 z ruchomym celem); konsumenci RNG 580; dopiero potem jednostki dystansowe.

### 4.12. Aktualizacja po etapie 35

- **Pomiary z oryginału odblokowane** [P]: rozkaz ataku gracza przez MCP działa (rzut z pól kamery gry). Scenariusze
  walki zależne od wejścia gracza są teraz wykonalne. Metoda bez klikania (układ scenariusza + AI + wyzwalacz stanem)
  pozostaje drugim, niezależnym torem.
- Rozpoznane warunki `EEAMouseClick` (dyplomacja, kategoria 0x50E34B, HP > 0) – materiał do sterowania w OpenEE.
- Kolejność prac: scenariusze C na `e35_a` → rozbieżności 578 G3 / 590 → AoC → strzelcy. Równolegle scena potyczki w
  Godocie (lista braków: `raporty/archiwum/RAPORT_ETAP_35.md` § 12).

### 4.13. Aktualizacja po etapie 36

- **Pierwsza grywalna potyczka** [P: rzeczywisty przebieg sceny]: scena Godota na mapie SCN, 5 × 5 gwardii, ruch,
  kolizje, trasy i walka wręcz wyłącznie w Core (GDExtension), sterowanie EE (LPM/ramka/PPM/Shift/atak), wynik
  i restart. Godot nie ma już drugiej symulacji dla tej sceny (stara `Symulacja` GDScript zostaje dla `rts_test`).
- **Rozkaz ataku gracza zgodny co takt** z pomiarami 619/620 (wejście InitialAttackState); przerwanie ataku zwykłym
  PPM – Core = gra. Pierwsze różnice: czas 9006 na końcu trasy, ponowny wybór celu nieosiągalnego przez AI [N].
- Zmiana wniosku etapu 35: w 616 nie było pościgu – obywatel stał na polu z drzewami (cel nieosiągalny).
- Kolejność prac: 9006/CompletedUnitFacing przy celu ataku i rozkazie PPM → ponowny wybór celu (osiągalność
  0x62D696) → 578 G3 / 590 → AoC RNG → strzelcy (pomiar pocisku). Potyczka: szyk grupy w Core, mgła wojny, więcej typów.

### 4.14. Aktualizacja po etapie 37

- Stan 9006 i cel nieosiągalny wyjaśnione kodem EE i potwierdzone na nagraniach: Core zgodny co takt w 616 (cały zapis,
  z ponownym wyborem celu przez AI po 30 s), 619 (do porzucenia celu), 620 (do końca ruchu; kurs końcowy = kąt szyku).
- Pozostałe [N]: osiągalność 0x62D696 i 0x5ECAD0 (w Core prawda), ścieżki wpisu w RepathAroundObstacle i odwecie,
  zachowanie przy zmianie pola celu lub atakującego (warunek z kodu, bez pomiaru), kąt szyku przy wielu jednostkach.
- Kolejność prac: pomiar kontrolny „zmiana pola” i wielu jednostek → pościg za ruchomym celem (578 G3 / 590 G1) →
  AoC RNG → strzelcy.
