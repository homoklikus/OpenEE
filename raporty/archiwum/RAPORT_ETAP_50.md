# OpenEE — etap 50: obywatel buduje dom (cykl budowy Titan w Core)

Najważniejsze wyniki:
- **Pierwsza budowa w oryginalnym EE sterowana przez MCP i zmierzona co takt** (zadania 655–659): obywatel 32 stawia
  dom 37. Dwa przebiegi 658 mają identyczne czasy, 659 dodaje listy pól i graf.
- **HP budynku jest postępem budowy.** Fundament powstaje w chwili kliknięcia z HP 1 i flagą +0x340 = 0. Obywatel
  dodaje 15 HP mniej więcej co sekundę (rytm 29/29/30 taktów). Przy HP 500 gra ustawia +0x340 = 1, zgłasza zmianę
  mapy z terminem +15 s, a obywatel przechodzi przez TaskSmartCitizen do Idle.
- **Core odtwarza cały cykl zgodnie z grą co próbkę w trzech nagraniach** (obywatel i fundament – stan, pozycja,
  kurs, HP), także z własnym generatorem losowym Core. Termin przebudowy grafu i nowy podsektor są takie jak w grze.
- Nagrania regresji bez zmian; prorok 648 nadal 3585/3585.
- E1 wyjaśnione: skrót scenariuszy zmienił się w commicie etapu 48 (bisekcja 44–48), nie w etapie 49.
- D1–D5 i E2 nie zostały rozwiązane (§ 6).

## 1. HEAD i commit

- Baza: lokalny HEAD `9b88e0b` (etap 49). Pracowałem tylko lokalnie: bez `push`, `pull`, `fetch`, `clone`, `reset`,
  `rebase` i `clean`.
- Jeden commit etapu 50. Hash podaje `git log -1`, bo raport jest częścią tego commitu.
- Poza commitem zostały `godot/project.godot`, `konfiguracja/uzytkownik.cfg.przed_etapem11` i stare pliki `.uid`.
  Zmiany w Riverlands_MCP (osobne repozytorium bez origin) też nie są zatwierdzone.

## 2. Funkcje i adresy Titan

Szczegóły są w `docs/titan/budowa.md` § 3.

| Element | Adres / numer | Status |
|---|---|---|
| EEUGBuildRepair – vtable | 0x8319F0 | [W] |
| obsługa zdarzeń celu (vt+0x64) | 0x60D4FD | [W] |
| BuildingRepaired 4001 → ukończenie (+0x340, zgłoszenie mapy) | 0x60BD19 | [W + P] |
| RepairSiteInRange 4014 / BuildSiteClear 4021 / BuildSiteValid 4023 | 0x60BC54 / 0x60CED6 / 0x60D12A | adresy [W], treść nieprzeczytana – w Core [H] |
| BuildSiteVisible 4022 | LOS² + typ+0x58C ≥ odległość | [W] |
| BuildingDestroyed 2001, BuildingNotPaidFor 4030, GoalIsBuild 4031 | 0x60D4FD | [W] |
| stany citizen.tai | MoveToRepairSite **8017**, CheckRepairSiteAccessibility 4017, WaitForBuildSiteToClear 4012, RepairBuilding 4002, TaskSmartCitizen 4028 | [P] |
| stany citizen.tai (pozostałe) | CheckBuildSiteVisibility 4013, CheckBuildSiteValidity 4014, InsufficientResources 4030 | [W] |
| wartość bazowa atrybutu n (0–15) | 0x626834 | [W] – § 5 |
| EEMBuildUnit | 0x4B6F26 z tabeli nie leży w żadnej procedurze analizy | [N] |

Nieprzeczytane: wzór przyrostu HP (zmierzone 15), akcje wejścia stanów 8017 i 4002 (znane tylko z pomiaru) oraz
funkcja wyboru punktu pracy.

## 3. Pomiary budowy

| Zad. | Wynik |
|---|---|
| 655 | przycisk domu w panelu obywatela – piksel okna (1102, 1253) |
| 656 | nieudana próba: czerwony podgląd, fundament nie powstał |
| 657 | stare narzędzia kursora zawodne, zastąpione |
| 658 ×2 | pełny cykl; przebiegi identyczne (wejście w 4002 w 54613, ukończenie w 88705) |
| 659 | fundament od razu na liście pola; graf bez zmian do ukończenia; d4 = 82568 + 15000 = 97568; po terminie maks. id podsektora 1604 → 1605, w oknie 2 → 3 podsektory |

Cykl [P]:
- Kliknięcie tworzy fundament: HP 1, +0x338 = 1, +0x340 = 0, z = 0.
- Kolejne stany obywatela, każdy przez jeden takt: 8017 (tryb ruchu 0, bez ruchu) → 8000 (trasa i pierwszy krok) → 2015
  → 10003.
- Obywatel jedzie do narożnika obwodu (164,15; 114,15), czyli punktu odsuniętego o 0,5·rozmiaru obywatela (r = 0,15).
- Na końcu ruchu: v = min(v + a·dt, d), zaliczenie przy d < 0,05. Potem 9000 → 9006 → 5001 → 4017 → 4012 → 4002.
- Wejście w 4002 od razu obraca kurs na środek domu.
- Budowa: 33 przyrosty po +15 i jeden przycięty 496 → 500. Pierwszy przyrost 29 taktów po wejściu w 4002.
- Ukończenie: +0x340 = 1 → stan 4028 → 5000.

Odpowiedzi na pytania briefu:
- **Czy HP i postęp to to samo?** Tak. Innego licznika postępu nie znaleziono, a ukończenie to warunek HP ≥ HP maks.
  [P + W].
- **Przejezdność pola:** fundament blokuje pole od chwili kliknięcia. Graf zmienia się dopiero po ukończeniu i
  odczekaniu 15 s.
- **Losowania:**
  - Gra losuje 2 razy na takt; w ruchu 3; w takcie rozkazu 4.
  - W RepairBuilding mniej więcej co 1,5 s dochodzą 2, 4 albo 6 losowań; źródło jest [N].
  - Te dodatkowe losowania nie zmieniają żadnego mierzonego pola, bo odtworzenie z własnym RNG Core jest zgodne.

Przy okazji: obywatel miał w parametrach odtworzeń c4 = 0,5, skopiowane z gwardii. Reguła typ+0x4C4 = 1/a (etap 49)
daje 0,83333. Z tą wartością hamowanie zaczyna się w tym samym takcie co w grze. Nagranie 638c (obywatel) nadal jest
zgodne.

## 4. Core i zgodność

Nowe w Core (`symulacja.cpp`, `maszyna_stanow.cpp`; opis w `budowa.md` § 4):
- `postaw_fundament` – fundament budynku;
- `rozkaz_budowy` – cel EEUGBuildRepair, wejście w MoveToRepairSite;
- `miejsce_budowy` – punkt pracy na obwodzie fundamentu;
- zdarzenia celu budowy;
- `krok_budowy`;
- część „Building & Repairing” skryptu citizen.tai.

Rozróżnienie trzech przypadków:

| Przypadek | Funkcja |
|---|---|
| gotowy budynek | `dodaj_obiekt_budynku` (wczytanie mapy) |
| budynek postawiony w trakcie gry | `postaw_budynek` (etap 48, bez zmian) |
| fundament budowany przez obywatela | `postaw_fundament` + `rozkaz_budowy` |

Rytm przyrostów: licznik ms startuje od 1000, co takt odejmuje 34, a przy wartości ≤ 0 dodaje HP i 1000. Daje to
dokładnie zmierzony ciąg 29, 29, 30, 29, 30, … [P]. Liczba 34 jako całkowite ms taktu to [H]. Wartość 15 HP pochodzi
z pomiaru i siedzi w danych odtworzenia (`przyrost_budowy`), nie w kodzie Core. Wzór jest [N].

`opoznienie_przebudowy_s` (*0x9183C0) = 1,5, czyli termin +15000 ms [P: 658, 659]. Wcześniej było 0 [N]. Wartość
dotyczy tylko zgłoszeń z terminem zwykłym (budynek postawiony albo ukończony w grze). Śmierć budynku nadal zgłasza
termin +1 ms.

Zgodność [P] – `odtworzenie_nagrania.py opis_budowy` → `odtworz_scenariusz.gd`:

| Nagranie | Obywatel | Fundament | RNG |
|---|---|---|---|
| 658_1 | 2650/2650 | 1277/1277 | z nagrania i własny Core |
| 658_2 | 2650 (1 próbka nieaktualna) | 1269/1269 | jw. |
| 659 | 3014 (1 rozdarta) | 1813/1813 | jw. |

Graf (`--graf-scn=1`):
- 659: termin 97568 i maks. id 1605 – jak w grze;
- 658: 103704 wobec 103705 w grze – start zegara Core zaokrąglony do pełnego ms.

Ograniczenie metody: rozkaz budowy jest wykonywany po takcie kliknięcia, bo w próbce tego taktu gra pokazuje już
8017 bez przejścia ani ruchu. Rozkazy ruchu i ataku są wykonywane przed taktem. Przyczyny różnicy nie znam [N].

## 5. Cywilizacja (C)

- **C1 [P: SCN]:**
  - rekord gracza w kawałku 5 ma listę 574 wpisów (typ, nazwa, 16 × i32 poziomów atrybutów, punkty);
  - przykłady: Argos typ 165 – atrybut 14 = 4; Troja typ 463 – atrybut 1 = 5, atrybut 11 = 2;
  - opis w `import_mapy.md` (etap 50).
- **0x626834 [W]:** zwraca wartość bazową atrybutu n (0–15) z pól ulepszenia (+0x424, +0x510, …, +0x570). Indeksy
  odpowiadają 16 polom listy z SCN.
- **C2 – brak integracji:**
  - prorok 216 nie ma poziomów w SCN e42 u żadnego gracza, a jego premia w grze jest zmierzona (etap 49);
  - źródło tej premii leży więc poza listą SCN (cywilizacja gracza przy starcie, dbcivilization/dbpremadecivs) [N];
  - podłączenie listy SCN do Core nie dałoby premii proroka, więc tego nie zrobiłem;
  - 648 pozostaje 3585/3585 z premią liczoną w Core z danych pomiaru.

## 6. Status rozbieżności

| Pozycja | Status | Uwagi |
|---|---|---|
| D1 koszary od W | **otwarte** | 654 kosz_W – pierwsza różnica bez zmian (t = 50727, kurs); nie badano |
| D2 FaceEnemy przy π | **otwarte** | 654 NE; ostrzejsze porównanie (§ 7) pokazuje różnicę wcześniej: 42477 zamiast 42647 |
| D3 faza przeładowania (648/652) | **otwarte** | gwardie atakują, zanim ruszy rejestrator, więc faz nie ma skąd przenieść; potrzebny nowy pomiar od startu z gwardią poza zasięgiem [N] |
| D4 kontakt z niszczonym budynkiem | **otwarte** | nie badano |
| D5 RNG przy zapadaniu (74215/79432/76909) | **otwarte** | bez zmian; etap 50 pokazał, że gra losuje też w systemach bez wpływu na symulację (budowa) – trop do sprawdzenia |
| E1 skrót scenariuszy | **wyjaśnione [P]** | szczegóły poniżej |
| E2 AI (gracz 5 jako człowiek, funkcja planująca) | **otwarte** | nie badano |

E1 [P]: commity 44–48 zbudowałem tu (`git archive`, Release, ta sama DLL).
- Etapy 44–47 dają `22b0f0cf4a1ec660`; etap 48 (`4864062`) daje `f9299fc62b3594f9`.
- Różnica pochodzi z dwóch scenariuszy syntetycznych:
  - „objazd ściany”: trasa 13 → 10 punktów, koniec w takcie 706 → 628;
  - „cel nieosiągalny”: 9 → 7 punktów.
- To skutek poprawy początku trasy Bounded w etapie 48. Raport 48 błędnie podał „bez zmian”.
- DLL GOG i Gold oraz zmienne `OPENEE_TAI`/`OPENEE_DANE_LOKALNE` nie wpływają na skrót.
- Skrót nie służy do porównania z Titan, tylko do regresji.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| CTest Release | 21/21 zaliczonych, 0 niezaliczonych (`budynki`: 33 sprawdzenia, w tym nowy test budowy) |
| CTest Debug | 21/21, 0 |
| GDExtension | 69/69, 0 (etap 49: 67; nowe: wersja Core i budowa obywatela) |
| Godot | 325/325, 0 |
| Riverlands_MCP | 108/108, OK |
| skrót scenariuszy | `f9299fc62b3594f9` (od etapu 48, § 6) |

Nagrania (Core wobec gry; ostatnia kolumna – stan po etapie 50):

| Przebieg | Etap 49 | Etap 50 |
|---|---|---|
| 631/633/634/638k/638c | zgodne | zgodne |
| 644 sojusz ×2, pościg, 646 | zgodne | zgodne |
| 619 / 620 | 124254 / 109423 | bez zmian |
| e48 prorok / kontakt3 / widzi_ruch | zgodne | zgodne |
| 648 (`--premie=e42`) | prorok 3585/3585 | prorok 3585/3585; gwardie od 6136 (D3) |
| 649 dom 3v1 / koszary 3v1, 651 dom 1v1 | zapadanie 79432 / 76909 / 74215 | bez zmian |
| 652 mur_rog | prorok do 93819 | prorok do **75034** – ostrzejsze porównanie: końcowy obrót 9006 o jeden krok α·dt (0,0158 rad) mniejszy; wcześniej ukryty jako „próbki nieaktualne” |
| 652 dom_* / kosz_* | gwardie od 5318–6204 | bez zmian (D3) |
| 654 (7) | 5 w całości | 5 w całości; NE 42477, kosz_W 50727 |
| **658_1 / 658_2 / 659 (nowe)** | – | **zgodne w całości** |
| potyczka_e47 (2 bitwy, restart) | 998 / 994 | 896 / 896, po zmianach `potyczka.gd` 896 / 895; w każdej bitwie 1 gruz i 1 znacznik, gwardie przechodzą. Kod Core z HEAD etapu 49 zbudowany dziś daje 896 / 895, więc zmiana wynika z czasu rzeczywistego automatu demonstracyjnego, nie z Core |
| potyczka_e50_budowa (nowa) | – | HP 1 → 500, obywatel 10003 → 4002 → 5000, `ukonczony` |

Narzędzie porównania: próbki „nieaktualne” i „rozdarte” wymagają teraz zgodnego kursu (wcześniej sprawdzano tylko stan
i pozycję). Bez tej poprawki obrót bez ruchu w 658 (kurs na budynek) chował się w 1179 próbkach „nieaktualnych”.
Tolerancji nie zmieniałem. Poprawka tylko zaostrza porównanie.

Deterministyczność: dwa przebiegi gry 658 są identyczne; w Core powtórzenia dają te same wyniki (test GDExtension
„powtarzalność”, potyczka 896/896 i 896/895 – różnica 1 takt z czasu rzeczywistego automatu).

## 8. Godot i MCP

- **Riverlands_MCP** (lokalnie, bez commitu):
  - nowy moduł `ee_budowa.py`;
  - `budowa_rozkaz` jest sterujące: weryfikowany wybór obywatela, przycisk, kliknięcie miejsca z punktami zapasowymi
    i zrzutem podglądu, a po wykryciu fundamentu start rejestratora;
  - `budowa_odczyt` jest obserwacyjne;
  - moduł zarejestrowany w `ee_diag.py`. Do pamięci gry nic nie jest zapisywane.
- **GDExtension** (`OpenEE Core 0.23.0 (etap 50`):
  - `postaw_fundament`, `rozkaz_budowy`, `ustaw_przyrost_budowy`;
  - pole `ukonczony` w `jednostka()`.
- **Godot:**
  - `dane/potyczka/potyczka_e50_budowa.json` z polami `fundament` i `budowa` w układzie potyczki, uruchamiany
    `--potyczka-demo`;
  - automat `_demo_e50` raportuje HP, stany i graf;
  - układ bez wrogów nie ogłasza zwycięstwa;
  - nie ma interfejsu budowy, rozkaz pochodzi z układu;
  - Godot rysuje gotowy model domu z paskiem HP, bez etapów modelu fundamentu.
- `odtworz_scenariusz.gd` obsługuje rozkaz `budowa`; `odtworzenie_nagrania.py` ma nowy tryb `opis_budowy`.

## 9. Ograniczenia

- Zmierzono jeden typ budynku (dom 1×1), jednego budowniczego, gracza-człowieka i płaski teren.
- Nieznane: koszt i pobranie zasobów, populacja, odrzucenie miejsca, wielu budowniczych, naprawa, przerwanie budowy,
  kolejka budowy, budowa przez AI – [N].
- Wzór przyrostu HP – [N]. Wybór punktu pracy oparty na jednym pomiarze [H].
- BuildSiteValid, BuildSiteClear i RepairSiteInRange są w Core uproszczone [H].
- Akcje wejścia stanów 8017 i 4002 są odtworzone z pomiaru, bez kodu [P/N].
- Dodatkowe losowania gry w budowie nie są odtwarzane – nie wpływają na mierzone pola.

## 10. Postęp rekonstrukcji Titan – ile zostało do końca?

Tabela, dowody i historia ocen: `docs/titan/POSTEP_REKONSTRUKCJI.md` (stan po etapie 50).

**Zmiany ocen:**
- 14 Budynki i budowanie: A/B/C 2 → 3, pewność średnia.
- 15 Jednostki cywilne: 1 → 2 (A, B, C).
- Pozostałe 36 podsystemów bez zmian ocen. Nowe dowody dotyczą grafu, fizyki, maszyn stanów, SCN i losowości.

**Liczby (38 podsystemów):**

| Wskaźnik | A | B | C |
|---|---|---|---|
| zasadniczy mechanizm (ocena ≥ 3), etap 49 → 50 | 16 → 17 | 16 → 17 | 14 → 15 |
| niebadane albo tylko wstępnie rozpoznane (≤ 1), etap 49 → 50 | 17 → 16 | 18 → 17 | 20 → 19 |
| średnia bez wag | 1,95 | 1,79 | 1,66 |

Średnia nie jest procentem silnika: skala jest porządkowa, a podsystemy mają bardzo różną wielkość.

**Wskaźniki obiektywne:**
- Adresy EE cytowane w kodzie Core: 313 → 318.
- Adresy EE w dokumentacji: ok. 900 wobec 25 928 procedur Ghidra, czyli rzędu 3–4 %, górne oszacowanie.
- Kod Core: 5023 wiersze.

**Ile silnika odtworzono?**
- Uczciwej liczby procentowej nie da się podać. Najlepsze, co mamy: około 3–4 % procedur EXE jest choćby
  zidentyfikowanych w dokumentacji.
- W podziale na podsystemy 17 z 38 ma w Core działający zasadniczy mechanizm, a 15 jest potwierdzonych pomiarem.
- Odtworzony rdzeń to symulacja pojedynczych jednostek lądowych: ruch, trasy, kolizje, stany, walka wręcz, śmierć,
  budynki jako przeszkody i cele. Od etapu 50 dochodzi pierwsza budowa.

**Zgodność nagrania a postęp silnika:** 658/659 zgodne w całości dowodzą, że jeden cykl (dom, obywatel) jest
odtworzony wiernie. Nie znaczy to, że budowanie jest gotowe: koszt, inne budynki, wielu budowniczych i naprawa są
nieznane.

**Blokery pełnej rozgrywki:**
- ekonomia (zasoby, populacja, koszt budowy);
- zbieranie surowców;
- produkcja jednostek;
- technologie i epoki;
- AI gracza komputerowego;
- interfejs budowy w OpenEE.

Bez nich gracz nie ma z czego budować ani kim walczyć poza układem scenariusza.

**Pozostała praca w liczbach:**
- 8 podsystemów niebadanych wcale (A = 0);
- 16 ma A ≤ 1;
- żaden nie ma oceny 5.

Terminu nie podaję; brak danych o tempie dla gospodarki i AI.

## 11. Propozycja etapu 51

1. **Koszt i zasoby budowy:**
   - odczyt zasobów gracza w pamięci przed, w trakcie i po budowie domu (pobranie przy kliknięciu czy w trakcie);
   - populacja;
   - wzór przyrostu 15 HP – pomiar drugiego budynku (koszary 2×2) i dwóch budowniczych.
2. **Zbieranie surowców – rozpoznanie EEUGGather:**
   - pierwszy pomiar obywatela przy drzewie lub kamieniu;
   - zdarzenia citizen.tai „Gather”.
3. **D3:** nowy pomiar 648/652 z rejestratorem od startu (gwardie poza zasięgiem), żeby przenieść fazę przeładowania.
4. **652 mur_rog:** końcowy obrót 9006 proroka (krok α·dt) – ujawniony ostrzejszym porównaniem.
5. **D2/D1** (654 NE, kosz_W) i **E2** (AI) – jeśli zostanie czas.
