# Raport etapu 49 – kolizje z budynkami, miejsca podejścia, premie cywilizacji i mapa postępu Titan

Najważniejsze wyniki:
- **Nagranie 648 (prorok) zgodne w całości: 3585/3585 próbek**, od rozkazu do końca ruchu (wcześniej do t = 63510).
  Budynki są w Titan zwykłymi uczestnikami list kontaktów (+0x2D8), więc mur odpycha proroka tą samą funkcją 0x549179
  co jednostki.
- **Atak trzech gwardii na dom i na koszary zgodny co próbkę aż do zapadania się budynku.** Brakowały dwie reguły Titan:
  gałąź 0x549179 (gwardia omija stojącego, przeładowującego sojusznika) i EnemyUnitReachable bez testu HP celu.
- **Źródło ×10/9 proroka**: premia cywilizacji gracza 1 (atrybut prędkości, 0x627078 → SetSpeed 0x628051). Prorok
  gracza 5 ma wartości bazowe. Core liczy premię sam (`z_premia_predkosci`).
- **Miejsca podejścia**: 11 wyborów z gry (cztery strony, narożniki, koszary 2×2). Nowa reguła zgadza się z 10.
- **Nowy trwały dokument `docs/titan/POSTEP_REKONSTRUKCJI.md`**: 38 podsystemów, osobne oceny rozpoznania,
  implementacji i zgodności oraz lista pozostałych prac.

Oznaczenia: [P] kod i pomiar, [W] analiza statyczna, [H] hipoteza, [N] nieustalone. Osobno: mechanizm Titan /
implementacja Core / test syntetyczny / pomiar EE / integracja Godot.

## 1. HEAD

- Początek: `4864062` (etap 48, lokalny commit). Koniec: jeden lokalny commit etapu 49 (`git log -1`).
- Bez push/pull/fetch/clone/reset/rebase/clean i bez sprawdzania zdalnego repozytorium.
- Poza commitem: `godot/project.godot`, `konfiguracja/uzytkownik.cfg.przed_etapem11`, stare `.uid`, Riverlands_MCP.

## 2. Kontakty jednostek z budynkami (pakiet A)

**Mechanizm Titan** [W: 0x5ED24B, 0x5E8F0E, 0x5498C4, 0x549179; P: 648, 652]:
- +0x2D8 ustawia inicjalizacja obiektu (0x5ED24B). Wartość to 1, gdy typ +0x606 ≠ 0 i nie zachodzi żaden z wyjątków:
  bit 0 +0x5D4 przy vt+0x5C() = 0, typ +0x620 ≠ 0 albo +0x4B8 = 0x104.
  - Odczyt 652: mur, dom, wieża, koszary, gwardia i prorok mają +0x606 = 1 i +0x2D8 = 1 [P].
  - +0x606 to dbobjects „Collidable” [H].
- Budynek jest **normalnym uczestnikiem pary kontaktu**: odpowiedź 1 na pytanie A1, z cechą 3.
  - 0x5E8F0E dopisuje parę symetrycznie: obiekt musi mieć +0x2D8 ≠ 0 i HP > 0, okno ±R wynika z typu +0x474.
  - Budynek się nie porusza, więc w 0x549179 zachodzi ro > ru i dostaje tylko budzik.
  - Jednostka dostaje u.push −= 2·p.
- Rozmiar kolidera zależy od typu: mur 0,9, dom i wieża 1,0, koszary 2,0. Okno kontaktów domu ma ±1,0.
- Pomiar: w 648 dom ma 2 kontakty (gwardie 856 i 857), zgodnie z historią wejść na pola. W 652 (`e49_mur_rog`) mur
  0x1000857 jest na liście kontaktów gwardii. Nowe pole rejestratora MCP `kontakty_lista` czyta głowę +0xC4 [P].
- Gałąź omijania (ru = ro, typ +0x61A, sojusznik przeładowuje +0x2A0 ≠ 0, oba cele EEUGAttackUnit):
  push_u −= v·przód + (v⃗·d̂)·d̂.
  - 649 dom 3v1, t = 74079: gra (−0,0070; +0,0002), wzór (−0,0069; +0,0003) [P].

**Core:**
- `kolizyjny` (+0x2D8).
- Budynki na listach kontaktów; filtr kandydata: +0x2D8 i HP > 0.
- Lista kontaktów budynku powstaje przy jego utworzeniu.
- `promien_kolizji` budynku = „Size of collider”.
- `omijanie_atakujacego`.
- `odbuduj_kontakty_wszystkich`.
- Godot przy budynku: `ObiektyScnCore.parametry_budynku` → „kolizja”.
- Odtworzenie scenariusza dodaje budynki graczy z SCN jako obiekty Core (`--budynki-scn`).
- Nie ma osobnego mechanizmu „odsuń od budynku”.

**Test syntetyczny:** CTest `budynki` 8 (mur z +0x2D8 odpycha, mur bez flagi nie) oraz GDExtension `_test_etapu49`.

**Eksperymenty A3** [P]:

| Przypadek | Nagranie | Wynik Core |
|---|---|---|
| 1 prorok obok muru | 648 | 3585/3585 |
| 2 gwardia podchodzi do muru | 652 mur_rog | 2571/2571 (mur na liście kontaktów) |
| 3 gwardia podchodzi do domu | 651, 649 dom 3v1, 654 | zgodne do śmierci domu |
| 4 przejście przy narożniku | 652 mur_rog (narożnik muru (160, 111)) | gwardia zgodna; odległość 1,0 > S – bez odepchnięcia |
| 5 dwie jednostki przy tym samym budynku | 652 mur_rog | gwardia zgodna; prorok do t = 93819 (kurs po zatrzymaniu przy gwardii) |
| 6 budynek wielopolowy | 649 koszary 3v1 | zgodne do zapadania |
| 7 budynek niszczony w chwili kontaktu | – | niezmierzony osobno [N] |

## 3. Wynik nagrania 648

| Element | Wynik |
|---|---|
| cel | zgodny |
| trasa | zgodna (8 punktów) |
| stan | zgodny (wszystkie próbki) |
| pozycja, kurs | zgodne co próbkę (3585) |
| kontakty | odepchnięcie od muru od t = 63510 jak w grze (+0x248) |
| koniec ruchu | zgodny |

Parametry proroka liczy Core z premii cywilizacji (`--premie=e42`), a nie z odczytu pamięci.

Gwardie w 648 różnią się od t = 6136, ale to skutek metody, nie mechaniki. Rejestrator ruszył 5,8 s po starcie
scenariusza, gdy gwardie atakowały już dom, a fazy przeładowania z nagrania nie są przenoszone do odtworzenia [N].

## 4. Miejsca podejścia do budynków (pakiet B)

Pomiar 650/651/654 to 11 wyborów; tabela jest w `walka.md` § 37.

W 652 gwardia stała w swoim polu widzenia (4) i atakowała sama, zanim ruszył rejestrator. Dlatego 654 powtórzono z
odległości ≥ 6.

**Reguła Core** [H: klucz dopasowany do pomiarów; W: 0x63234D – posortowani kandydaci, pierwszy wolny]:
- Kandydaci: po dwa na każde pole boku (+0,25 i +0,75) oraz 4 narożniki, odsunięci o 0,5·rozmiar atakującego.
- Kolejność wstawiania: obchód zgodnie z ruchem wskazówek zegara.
- Klucz sortowania: odległość Czebyszewa pól, potem boki przed narożnikami, potem kwadrat odległości.

Wynik:
- 10 z 11 wyborów zgodnych. Koszary z zachodu są niezgodne: gra (163,75; 113,25), Core (163,75; 113,75) [N].
- Odtworzenia 654 zgodne w całości: dom N, E, W, SW, koszary N.
- Dom NE: miejsce i trasa zgodne, ale obrót FaceEnemy przy różnicy kąta dokładnie π idzie w przeciwną stronę [N].
- Kryterium B5 spełnione: 4 kierunki domu 1×1 i koszary 2×2 z N i S.
- Odrzucono hipotezę „kąt od środka budynku”: myliła 3v1 i koszary z S.
- 0x632A8B to filtr kandydatów przy murach, a nie funkcja budynkowa [W].

## 5. Ulepszenia jednostek (pakiet C)

[W: 0x627078, 0x627030, 0x626FB0, 0x628051; P: 652 e49_prorok5]
- Prorok gracza 1: vmax 0,5, a 2,22222, HP 240. Prorok gracza 5: 0,45, 2,0, 150, czyli wartości z dbobjects.
  Premia zależy od gracza.
- Wzór: wartość' = wartość + poziomy · max(baza · procent, minimum). Dla prędkości minimum wynosi 0,05, więc
  0,45 + max(0,045; 0,05) = 0,5.
- SetSpeed skaluje a, α, ωmax przez vmax'/v_typu; c4 = 1/a, c8 = 1/α.
- Core:
  - `ulepszenia.hpp/.cpp` (`PremiaAtrybutu`, `z_premia_predkosci`, `wartosc_z_premia`) – można dodać inne atrybuty;
  - GDExtension `premia_predkosci`;
  - dane `premie_cywilizacji`.
- Test: CTest `budynki` 9 i GDExtension. 648 z premią liczoną w Core: 3585/3585.
- Nieustalone [N]: źródło liczby poziomów (cywilizacja w SCN, odczyt z pliku) i baza 0x626834.
- Integracja z potyczką czeka na odczyt cywilizacji z SCN. Do tego czasu potyczka używa wartości bazowych.

## 6. Proces budowania (pakiet D)

- Analiza statyczna: rozpoznane klasy `EEMBuildUnit` (vtable 0x824B40), `EEUGBuildRepair` (0x8319F0) i `EEABuild`.
- Pomiaru nie ma [N]. MCP nie ma ścieżki interfejsu budowy, a wyjście przez zapis pamięci wykluczają zasady etapu.
- Core ma `postaw_budynek` z etapu 48 [W], bez cyklu budowy. Potwierdzenia pomiarowego nie deklaruję.

## 7. AI gracza komputerowego i RNG (pakiet E)

- W każdym scenariuszu testowym gracze 2–6 to `EEComputerPlayer`, także bez jednostek [P: 652 `gracze`].
- Scenariusz z graczem 5 jako człowiekiem nie powstał: generator i ścieżka startu testowego nie zmieniają typu
  kontrolera.
- Funkcji planującej AI nie rozpoznano. Core nie dostał żadnych losowań AI [N].
- Wspiera to hipotezę, że AI losuje cyklicznie niezależnie od jednostek [H].
- Stan autonomicznego RNG bez zmian: 646 – 4643/4643 przy stanie startowym z nagrania.

## 8. Pozostałe rozbieżności (pakiet F)

| Problem | Pierwsza przyczyna |
|---|---|
| 619/620 0x1000858 | bez zmian: 124254 / 109423 (późny EEUGLocation przed celem ataku) [N] |
| 0x4A2214, n < 5 w 0x4A2B29 | nie badane w etapie [N] |
| koszary 3v1 | rozwiązane: omijanie sojusznika (0x549179) i EnemyUnitReachable bez HP |
| zapadanie budynku | dom1 74215, dom3 79432, koszary 76909 – losowania spoza Core [N] |
| kontakt ze zniszczonym budynkiem | nowa para wymaga HP > 0; istniejące pary trwają do zmiany pola jednostki [W] |
| obrys kolizji a blokada grafu | mur 0,9: kontakt do 0,7 od środka (0,2 poza polem), graf blokuje całe pole – ślizg w teście kroku przy krawędzi pola, odepchnięcie 0,2 dalej [W] |
| prorok w koszarach 650 | końcowy obrót: gra hamuje ω o α·dt, Core zatrzymuje się na kursie docelowym (przycinanie diff przy diff ≈ 0) [N] |

Rejestrator czasem łączy w jednej próbce stan z bieżącego taktu i pozycję z poprzedniego (649 dom 3v1, t = 47386).
Porównanie liczy takie próbki jako rozdarte, nie jako różnice (`odtworzenie_nagrania.py`).

## 9. Integracja Godot (pakiet G)

- Gruz ma **tymczasowy znacznik diagnostyczny**: szarą płytę na polach X..X+n−1 × Y..Y+n−1 z `core.gruz()`.
  Modeli EE nie kopiuję.
- Znacznik nie zmienia przejezdności, pojawia się w takcie śmierci, a restart go usuwa (znacznik jest dzieckiem widoku).
- potyczka_e47 (2 bitwy, restart): budynek ginie w takcie 998 i 994, w każdej bitwie 1 gruz i 1 znacznik
  (`znaczniki_gruzu`).
- Takt zmienił się z 986, bo dom i mury są teraz kontaktami gwardii.

## 10. Regresja

| Zestaw | Etap 48 | Etap 49 |
|---|---|---|
| CTest Release / Debug | 21/21 / 21/21 | 21/21 / 21/21 (`budynki`: 27 sprawdzeń) |
| GDExtension | 65/65 | 67/67 |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 108 | 108 (jeden proces) |
| S1–S7 | `68b0c69ecb8b0cbc` | bez zmian |
| skrót mapy | `c8297c16f0d48b1a` | bez zmian |
| skrót scenariuszy | `22b0f0cf4a1ec660` (raporty 44–48) | `f9299fc62b3594f9` – ta sama wartość daje HEAD etapu 48 zbudowany tu (`git archive`), więc zmiana nie wynika z etapu 49; wartości z raportów nie odtworzyłem w tym środowisku [N] |

Nagrania:

| Przebieg | Etap 48 | Etap 49 |
|---|---|---|
| 631/633/634/638k/638c | zgodne | zgodne |
| 644 sojusz ×2, pościg, 646 | zgodne | zgodne |
| 619 / 620 | 124254 / 109423 | bez zmian |
| e48_prorok / kontakt3 / widzi_ruch | zgodne | zgodne |
| **648** | prorok do 63510 | **prorok 3585/3585** |
| **649 dom 3v1** | 47386 | **gwardie w całości**, dom – zapadanie 79432 |
| **649 koszary 3v1** | 73295 | **gwardie w całości**, koszary – zapadanie 76909 |
| 651 dom 1v1 | do śmierci | gwardia i obserwator 4460/4460, dom – zapadanie 74215 |
| 652 mur_rog | – | gwardia, mury, dom, wieża w całości; prorok do 93819 |
| 654 (7 przebiegów) | – | 5 w całości; NE – kierunek obrotu przy π; koszary W – miejsce |
| potyczka_e47 | 986 | 998 / 994, gruz i znacznik |

645 i 647 nie mają opisów odtworzenia w tym formacie – nie powtarzano. Tolerancji i wzorców nie zmieniałem.

## 11. Wydajność

`wydajnosc_grafu.gd`, e35_a, 10 zmian: budowa 22 ms, zmiana przyrostowa 5,7 ms, pełna 13,0 ms (etap 48: 26 / 6,2 /
15,6 ms). Różnica mieści się w rozrzucie na współdzielonym komputerze. Listy kontaktów obejmują teraz budynki
graczy (w e47_przejscie2: 15 obiektów Core zamiast 5), bez wyraźnego wpływu na czas.

## 12. Postęp rekonstrukcji Titan – ile zostało do końca?

Pełna tabela i uzasadnienia: `docs/titan/POSTEP_REKONSTRUKCJI.md` (pierwsza wersja, stan wyjściowy).

1. **Rozpoznanie (A):** z 38 podsystemów 16 ma zasadniczy mechanizm rozpoznany (≥ 3), 17 jest niebadanych albo
   tylko wstępnie rozpoznanych (≤ 1), 8 nie badano wcale. Wskaźniki obiektywne:
   - w dokumentacji cytowanych jest 880 różnych adresów EE wobec 25 928 procedur Ghidra (ok. 3 %, górne oszacowanie);
   - wymieniono 88 z 1243 klas RTTI (ok. 7 %).
2. **Implementacja (B):** 16 podsystemów ≥ 3; 18 ≤ 1.
3. **Zgodność (C):** 14 podsystemów ≥ 3, w tym 4 z oceną 4 (pathfinding, fizyka ruchu, wczytywanie baz, zegar);
   20 ≤ 1. Ocena 5 – brak.
4. **Zmiana względem etapu 48:**
   - kolizje A 3 → 4;
   - technologie/ulepszenia 0 → 1 (A, B, C);
   - fizyka ruchu C 4 (648 w całości);
   - walka C 3 (3v1 do śmierci budynku).
   Pierwsza wersja katalogu, więc wcześniejszych ocen nie ma.
5. **Największe nierozpoznane podsystemy:** AI komputera (ok. 130 klas `EEAI*`/`EEC*`), interfejs (356 klas `EEUI*`),
   zbieranie surowców, ekonomia, produkcja, technologie i epoki, transport, lotnictwo, zapis gry, multiplayer,
   wyzwalacze scenariuszy.
6. **Blokery:**
   - brak ścieżki MCP dla rozkazów budowy i zbierania (wymaga interfejsu);
   - brak przełącznika typu gracza (AI);
   - cywilizacja gracza w SCN nieodczytana;
   - kolizje dużych jednostek bez pomiaru.
7. **Co najbardziej przybliży koniec:**
   - obywatel: budowa i zbieranie (otwiera ekonomię i produkcję);
   - odczyt cywilizacji i drzewa technologii (premie atrybutów);
   - ruch grup i szyk w Core;
   - funkcja planująca AI.
8. **Orientacyjna pozostała praca:** odtworzona jest głównie symulacja ruchu i walki pojedynczych jednostek lądowych.
   - To rdzeń, ale w liczbie funkcji kilka procent programu.
   - Gospodarka, produkcja, technologie, AI, transport, lotnictwo, zapis i multiplayer są prawie nietknięte.
   - Do uruchomienia pełnej rozgrywki Empire Earth brakuje co najmniej obywatela, ekonomii, produkcji i technologii.
   - Terminu nie podaję: brak danych o tempie prac poza ruchem i walką.

## 13. Największe pozostałe podsystemy

AI komputera, interfejs gracza, ekonomia ze zbieraniem i produkcją, technologie i epoki, transport i lotnictwo, zapis
gry, multiplayer. Szczegóły, rodzaj braku (wiedza / kod / weryfikacja) i trudność:
`docs/titan/POSTEP_REKONSTRUKCJI.md` § 5.

## 14. Propozycja etapu 50

1. Obywatel: rozkaz budowy przez interfejs (rozszerzenie MCP o przycisk budowy i kliknięcie fundamentu), pomiar cyklu
   EEUGBuildRepair, minimalny cykl budowy w Core.
2. Cywilizacja gracza: odczyt poziomów atrybutów z SCN i premie w potyczce.
3. Miejsce podejścia: koszary z zachodu i kierunek obrotu FaceEnemy przy różnicy π (punkt celowania budynku 0x54DA82).
4. Faza przeładowania z nagrania w odtworzeniu (gwardie 648, 652) i kontakt z budynkiem niszczonym w trakcie kontaktu.
5. AI: scenariusz z graczem 5 jako człowiekiem i funkcja planująca losowania.
