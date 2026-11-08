# OpenEE – raport etapu 30: rzeczywiste mapy w C++, diagnostyka Titan i początek rekonstrukcji walki

Etap 30 rozbudowuje warsztat badawczy: kamerę i kolejki celów w Riverlands_MCP, narzędzie pomiar → Core,
wspólny schemat struktur Titan i automatyczną statykę plików PE. Do OpenEE Core trafia import rzeczywistej mapy SCN.
Etap rozpoczyna też rekonstrukcję walki – od pojedynku dwóch jednostek walczących wręcz.

Szczegóły:
- `docs/titan/walka.md` – walka: funkcje, struktury, wzór obrażeń, cykl ataku, pomiary;
- `docs/titan/import_mapy.md` – EEMap / EETile, teren komórek, zajęte pola, import do Core;
- `docs/titan/struktury_titan.md` (generowany z `dane/titan/struktury_titan.json`) – schemat struktur EE/AoC;
- `docs/PLAN_REKONSTRUKCJI_TITAN.md` § 3.2a i § 4.7 – narzędzia i prognoza;
- `docs/cpp/ARCHITEKTURA_CORE.md` § 12, `docs/titan/kolizje_objazdy.md` § 13, `walidacja_kolizji.md` § 10,
  `astar_pola.md` § 7.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

**Rozdział wyników.** „Gra” oznacza pomiar w oryginalnym EE (`Empire Earth.exe` e352d7ae…) albo AoC
(`EE-AOC.exe` db8fc5ce…) przez Riverlands_MCP. „Model” oznacza dane syntetyczne albo obliczenia Core bez
odpowiadającej im serii z gry. Zgodność z modelem nie jest przedstawiana jako zgodność z grą.

**Środowisko.** Zlecenie wskazywało Debian 13. Polecenia na komputerze użytkownika wykonywały się w maszynie
wirtualnej Ubuntu 22.04 (GCC 11.4, CMake 3.x z `~/.local/bin`, Godot 4.7.2). Część kontroli wykonano też w kontenerze
Ubuntu 24.04 (GCC 13.3). Debian 13 nie był dostępny jako system wykonawczy.

## 1. Stan wyjściowy

- Commit `68e8b51` (etap 29), sprawdzony na początku etapu.
- CTest 16/16 grup (z danymi lokalnymi), GDExtension 18/18, Godot 324/324, 10 plików testów Riverlands_MCP,
  S1–S7 bitowo, Debug = Release.
- Przeszkody z etapu 29: rozkaz z celem poza kadrem (548), tylko pierwszy i ostatni punkt trasy w odczycie, przejezdność
  z terenu syntetycznego, ręczne skrypty porównawcze, brak jakichkolwiek danych o walce.

**Rozbieżności dokumentacji z kodem i pomiarem** (oznaczone w atlasie):
- `astar_pola.md` § 7: „woda (teren 1) i teren 10 są niedostępne” – zabronione są 1 i 9; woda płytka (10) jest
  dozwolona [P] (adnotacja „[Etap 30 – korekta]”).
- `walidacja_kolizji.md` § 10: „obiekt na listach wszystkich pól pod obrysem” – jednostki ruchome są na liście jednego
  pola; kontakty powstają z okna pól (adnotacja „[Etap 29 – zastąpione]”).

## 2. Rozbudowa REA / Ghidry

REA (`rea` MCP) otwierał obie binarki, ale dekompilacja większych funkcji przekraczała limit czasu jednego wywołania.
Zamiast czekać, statykę zautomatyzowano własnymi narzędziami na capstone/pefile (`narzedzia/titan/`, publiczne – nie
zawierają danych gry):

| Narzędzie | Funkcja |
|---|---|
| `indeks_pe.py` | indeks całej sekcji kodu: początki funkcji (prologi + wskaźniki z tablic vtable), odwołania `[reg+off]` z rodzajem dostępu (odczyt / zapis / adres) z reguł mnemoników; pamięć podręczna `~/.cache/openee_re` |
| `struktury.py` | `waliduj` (schemat), `dostep` (kto czyta/pisze pole – **kandydaci**, nie nazwy), `przesuniecie` (wykrycie stałego przesunięcia EE→AoC z rozkładu offsetów w parach funkcji), `porownaj`, `markdown` |
| `rtti_titan.py` | nazwy klas z RTTI MSVC i ich vtable |
| `switch_titan.py` | emulacja instrukcji przed `jmp [tab+reg*4]` – który przypadek switch obsługuje daną wartość (stan, zdarzenie) |

Wyniki użyte w etapie: przesunięcie `EEMap` AoC = EE + 0x13F1C (270/279 odwołań) [W → P odczytem 570], mapa
dostępu do pól walki (HP +0x3C, przeładowanie +0x2A0/+0x2A4, parametry +0xD8…+0x144), przypadki switch stanów
i zdarzeń walki (§ 11). Testy: `test_titan_narzedzia.py` – 14/14.

## 3. Rozbudowa Riverlands_MCP (prywatne, commit lokalny)

| Moduł / funkcja | Co daje |
|---|---|
| `ee_kamera.pokaz_punkt` (+ `obs_rozkaz(pokaz=…)`) | ustawia kamerę tak, by punkt mapy był w obszarze klikalnym; rzut odwrotny ekran → mapa, granice mapy |
| `ee_obserwacja.trasa_pelna`, `kolejka_celow`, `obs_kolejka` | pełna kolejka celów (+0x90), wszystkie punkty trasy (+0x7C), punkty `EEUGLocation` +0x32 |
| `odczyt(pelna, surowe)` | odczyt surowych zakresów i pól przez wskaźnik `[off, dł, wsk_off]` z kontrolą adresu |
| `obs_wybierz(zblizenie)` | wybór jednostki w tłumie po przybliżeniu kamery |
| `ee_mapa` | nagłówek EEMap, zrzut komórek (teren, lista obiektów), teren dozwolony typu jednostki |
| `ee_walka` | `walka_atak` (rozkaz ataku), rejestrator walki (start/stop, zdarzenia, zmiany), `walka_tabele` (tablice trafień EE) |
| `ee_struktury` | wczytanie schematu `struktury_titan.json` – przesunięcia EE/AoC z jednego źródła |
| `ee_start` | ponawianie kliknięcia odprawy (do 6 prób) z dziennikiem |

Testy: 11 plików (nowy `test_ee_etap30.py`) – wszystkie OK. Odczyty wskaźników są sprawdzane przed dereferencją
(zakres pamięci procesu, vtable z listy znanych klas celów EE/AoC); niezgodność → błąd, nie zgadywanie.

## 4. Wspólny opis struktur EE/AoC

`dane/titan/struktury_titan.json` – maszynowy schemat (13 struktur, 103 pola): nazwa, pole, typ, przesunięcie EE
i AoC, rozmiar, funkcje czytające i piszące (kandydaci z indeksu), źródło, pewność [P/W/H/N]. Struktury: EEUnit,
EEUnitClass, EEUnitClassUpgrade, EEUnitAction, EEUnitGoal, EEUGLocation, EEUGAttackUnit, EEGoalLevel, punkt trasy,
EEMap, komórka EETile, węzeł listy obiektów, EEPhysics. Pary funkcji EE↔AoC (`pary_funkcji`) służą do wykrywania
przesunięć.

Ten sam plik czytają: Riverlands_MCP (`ee_struktury`), `pomiar_core.py`, `eksport_mapy.py` i generator
`docs/titan/struktury_titan.md`. Walidacja: 0 błędów.

## 5. Nowe możliwości kamery

- `pokaz_punkt(x, y)` liczy pozycję kamery z rzutu odwrotnego i sprawdza, że punkt leży w obszarze klikalnym
  (0, 45)–(3440, 1300) poza panelami; po ustawieniu poziom przybliżenia wraca do 1,0 (wcześniej zostawał 0).
- `obs_rozkaz(pokaz=True)` przesuwa kamerę przed rozkazem i ponownie weryfikuje, czy cel nie leży na modelu innej
  jednostki.
- Wynik: w zadaniach 554–570 żaden rozkaz nie został odrzucony z powodu celu poza kadrem (w etapie 29: 548).

## 6. Pełne odczyty kolejek i tras

- Kolejka celów (+0x90, deque) – wszystkie cele z rodzajem rozpoznanym po vtable (EEUGLocation, EEUGAttackUnit…),
  osobno dla EE i AoC [P: test i odczyty 554–570].
- Trasa (+0x7C) – wszystkie punkty, nie tylko pierwszy i ostatni; punkty `EEUGLocation` +0x32.
- Cel ataku `EEUGAttackUnit`: +0x2C atakujący, +0x30 atakowany obiekt, +0x34/+0x38 pole celu [P].
- Brak dereferencji wskaźników, których vtable nie ma na liście sprawdzonych klas.

## 7. Automatyczna konwersja pomiarów

`narzedzia/titan/pomiar_core.py`: `waliduj` → `konwertuj` → `porownaj` (wywołuje `openee_porownaj`, nowe narzędzie
CLI Core) → raport Markdown + JSON z pierwszym rozbieżnym taktem każdej jednostki.

Walidacja odrzuca zamiast dopasowywać: brak próbki (luka taktów), powtórzony takt, złe id, niespójny odczyt
(różne wartości w jednym takcie), zmiana wariantu EE/AoC w serii, brakujące pole, nieznany parametr typu jednostki
(tabela `PARAMETRY` – tylko typy z odczytanymi parametrami; reszta wymaga `--jednostki` albo jest błędem).
Testy: 7 klas błędów w `test_titan_narzedzia.py`.

## 8. Import rzeczywistych map do Core

`MapaTitan` (`cpp/core/include/openee/mapa.hpp`, `src/mapa.cpp`): neutralne dane pola SCN (`DaneTerenuScn`) →
interpretacja Titan wyłącznie w Core → siatka przejezdności dla typu jednostki. Godot (GDScript tylko dekoduje bajty)
i narzędzia Python używają tej samej interpretacji przez GDExtension / CTest.

Wyniki **gra** (EE, „Wojna trojańska”, 280 × 280, zadania 550–552):
- linie brzegu i szerokość = pamięć; 39 480 komórek EETile = pola rombu SCN [P];
- teren komórki z reguły: 39 336 / 39 480 = **99,64 %** [W]; wszystkie różnice lądowe dotyczą klifów (9) [N];
  Core oznacza pola klifów i ich sąsiadów jako niepewne;
- zajęte pola obiektów n × n („Square occupied”): 5 282 / 5 325 (reszta – jednostki, które zmieniły pole) [P];
- wysokości wierzchołków: błąd 0;
- **AoC** (zadanie 570, ten sam scenariusz): pola EEMap przesunięte o +0x13F1C, teren komórek identyczny z EE [P].

Skrót mapy GDScript → GDExtension = skrót CTest (`c8297c16f0d48b1a`). Wszystkie niewiadome są oznaczone [N]
w `import_mapy.md` § 7.

## 9. Testy nawigacji na mapach EE/AoC

| Przypadek | Źródło | Wynik |
|---|---|---|
| trasy A, C i iteracje E etapu 24 (długie trasy, przeszkody stałe) | gra (etap 24) + mapa SCN | trasy i liczby iteracji / wywołań (145 / 8) identyczne – przy terenie z pamięci i z reguły [P] |
| przejście przez bramę między murami (567, 2571 taktów) | gra | Core w trybie A* i w trybie trasy z gry: śr. 0,016 pola, maks. 0,039; pierwszy rozbieżny takt 1031 – kontakty z jednostkami, których Core nie symuluje [P/W] |
| cel zajęty, 5 jednostek (554, 1714 taktów) | gra | 4 z 5 jednostek bez różnic; jedna śr. 0,0012 pola (rozbieżność od taktu 701); stojąca gwardia – inny stan (16000, AI walki) [P] |
| cel zajęty przy wieży (569) | gra | zatrzymanie 0,5 pola od celu z +0x330 = 8 (reguła (a)) [P] |
| brzeg, zmiana wysokości | gra (serie etapów 25–26 na mapie SCN) | teren z mapy SCN odtwarza wysokości bez błędu; osobnej serii brzegu w etapie 30 nie wykonano [N] |
| cel nieosiągalny | model | Bounded → pełne A* na siatce z mapy działa (CTest); serii z gry nie wykonano [N] |
| budżet A* na takt | – | nie zbadany w etapie 30; jedyna informacja – liczba wywołań przypadku E (8) zgodna z grą [N] |

## 10. Wyniki badań RepathAroundObstacle (9002)

**Nie zweryfikowano.** W 13 seriach (etapy 29–30, ok. 30 000 próbek) nie wystąpiło zdarzenie ObstacleDetected.
Maksymalny ciągły czas odpychania +0x248: 2011 ms (pościg w walce), próg T = los[0,75; 1,25] · 4000 ms. Przeszkoda:
reguła (a) – „punkt osiągnięty” (+0x330 = 8) – kończy podejście do zajętego celu po 273–375 ms, zanim licznik dojdzie
do progu [P]. Blokady bramy nie dało się ułożyć (punkty w bramie leżą na rzutach jej segmentów). Następna próba:
przeciwny ruch dwóch grup przez przesmyk szerokości 1 pola (`kolizje_objazdy.md` § 13). Implementacja 9002 w Core
pozostaje oznaczona jako niezweryfikowana.

## 11. Analiza statyczna walki

Funkcje EE (AoC, gdzie ustalono) – pełna tabela w `walka.md` § 2:
- DealDamage 0x61DE61 (wzór obrażeń), obszarowe 0x61DAE6, modyfikator wysokości 0x61E500 [W], tablica trafień
  0x4D5F2C [W];
- TakeDamage (EEUnit vt+0x70) 0x6172BC, SetHitPoints 0x616F30, regeneracja 0x625B47 [W];
- wejście w stany ataku (EEUGAttackUnit vt+0x40) EE 0x60B26F / AoC 0x61D8DC, losowe przeładowanie AoC 0x5FEA22 [W];
- zdarzenia celu ataku (vt+0x64) 0x60B5CB: EnemyUnitDestroyed, UnitNotOnMap, UnitInWeaponRange (0x5F0CE8),
  EnemyUnitNoLongerVisible, FacingEnemyUnit, EnemyUnitInsideFiringArch [W];
- `.tai` (Generic Attack): FaceEnemyUnit 2012 → AttackEnemyUnit 2001 → WaitForReload 2021 → Reloaded 2044 → 2012;
  numery stanów i zdarzeń identyczne w EE i AoC (161/238 vs 166/247 zarejestrowanych) [P: kod obu binarek].

Nierozpoznane: wybór celu, obrót i łuk ataku, pościg, powrót do miejsca kontaktu, pociski [N].

## 12. Rozpoznane struktury bojowe

HP +0x3C (int), animacja +0x260 / AoC +0x264, przeładowanie +0x2A0 / AoC +0x2A4 [P]; parametry gracza
(`EEUnitClassUpgrade`): zasięg +0x9C, obszar +0xA0, pole widzenia +0xA4, atak +0xD8, pancerz ×6 +0xE0,
przeładowanie +0x138, HP maks. +0x144 [P]; typ: rodzaj ataku +0x4C0, wiersz tablicy trafień +0x4C4, rodzina ataku
+0x4C8 [P wartości, EE]. Każde pole ma osobny wpis EE/AoC w schemacie; pola z jednym odczytem mają pewność [H].

## 13. Wyniki eksperymentów EE/AoC (gra)

| Seria | Wariant | Wynik |
|---|---|---|
| 557–561 | EE | ustalenie kolejności startu pojedynku (3 nieudane – jednostki nie walczyły albo cel źle odczytany) |
| **564** | EE | gwardia kontra gwardia, 8 pól: 13 trafień, człowiek → komputer 31, komputer → człowiek 16; trafienie zawsze 1122 ms po wejściu w atak; atak co 60 taktów; śmierć → 6000 w takcie trafienia |
| 563/564 | EE | gwardia kontra obywatel: 42, potem 23 (obcięte do HP); wartość 42 niewyliczona [N] |
| 565, 566 | EE | parametry ulepszeń gracza = baza danych; tablice trafień 1,071 / 1,5 / 2,1 i mnożniki klas |
| **570** | AoC | ten sam przebieg stanów i moment trafienia; **przeładowanie losowe** 1668–2312 ms przy 2000; obrażenia 34 / 15 – inne wartości tablic [N] |

Zaokrąglenie potwierdzone: 15 · 2,1f = 31,4999986 → 31 (w podwójnej precyzji byłoby 32) [P].

## 14. Implementacja walki w C++

`cpp/core/include/openee/walka.hpp`, `src/walka.cpp` – tylko rozpoznane mechanizmy:
- `ParametryWalki`, `TabliceObrazen`, `wybor_tablicy_trafien` (ludzie / komputer – kombinacje zmierzone);
- `oblicz_obrazenia` – wzór 0x61DE61 z zapisami f32 i zaokrągleniem jak `fistp`, minimum 1;
- `StanWalki`, `przyjmij_obrazenia` – HP, śmierć (6000);
- `PojedynekTitan::takt` – cykl 2012 → 2001 → 2021, licznik przeładowania −34 ms na takt (także po śmierci),
  trafienie przy liczniku 878.

Niewdrożone (brak danych): wybór celu, obrót (takt pierwszego ataku podaje się z pomiaru), zasięg z rozmiarami,
pościg, modyfikator wysokości, obszarowe, pociski, losowe przeładowanie AoC. GDExtension nie wystawia jeszcze walki
– Core jest właścicielem stanu, integracja z Godotem po rozpoznaniu wyboru celu.

## 15. Testy porównawcze

- `core_walka` (CTest, grupa `walka`): część syntetyczna (wzór, zaokrąglenie, minimum 1, śmierć) – **model**;
  część lokalna: pojedynek 564 – **gra** – 786 porównań w taktach (HP obu jednostek, licznik przeładowania, stan),
  **0 różnic**.
- `core_mapa` (grupa `mapa`): mapa syntetyczna (model) + mapa z gry: teren, zajęte pola, trasy etapu 24 (gra).
- `pomiar_core.py porownaj`: 554 i 567 (§ 9).

## 16. Zmiany i problemy RNG

- EE: obrażenia i przeładowanie bez losowania [P]. W czasie pojedynku gra wykonuje 16–22 kroki LCG na takt – tyle
  samo co bez walki (inne systemy).
- AoC: jedno losowanie przy każdym wejściu w AttackEnemyUnit (0x5FEA22 → EEPhysics 0x5612B9) [W kod, P zmienność].
- Core nie dodaje sztucznych losowań. Różnica liczby kroków gra/Core (np. 554: 23 930 vs 3 711) wynika z braku AI
  i pozostałych systemów w Core – nie jest błędem fizyki.

## 17. Pomiar efektywności automatyzacji

Czas UTC (commity, pliki zadań) [P]; podział – szacunek [H]:

| Element | Wartość |
|---|---|
| etap: początek → commit | ok. 12:45 → 14:50 |
| zadania MCP | 23 (549–571), z błędem lub bez wyniku 7 |
| narzędzia (koszt) | ok. 40 min statyka + ok. 1 h MCP / pomiar → Core (łącznie z mapą) |
| identyfikacja struktur walki | ok. 25 min |
| przygotowanie środowiska walki | 8 zadań (555–562), ok. 25 min |
| pierwsze wiarygodne dane walki | 14:09 (564), ok. 1 h 25 min od początku |
| implementacja walki | ok. 15 min; walidacja (786 porównań) – kilka minut |

1. **Koszt narzędzi** w etapie: ok. 1–1,5 h z ok. 2 h etapu.
2. **Oszczędność w etapie:** rejestrator i kolejka celów dały pełny pojedynek w jednym zadaniu (564); przed nimi
   pojedynek wymagałby odczytu krok po kroku (etapy 25–27: 30 000 odczytów w 52 zadaniach).
3. **Oszczędność przewidywana:** schemat struktur i indeks PE skracają statykę każdego podsystemu; pomiar → Core
   usuwa jednorazowe skrypty porównawcze.

Mniej wywołań MCP nie przekłada się wprost na szybszy projekt: statyka, decyzje i dokumentacja zostały.

## 18. Aktualizacja prognozy rekonstrukcji

`docs/PLAN_REKONSTRUKCJI_TITAN.md` § 4.7. Walka wręcz 1:1 rozpoznana w ok. 0,1 J zamiast zakładanego większego
kosztu – waga walki 1,5 → 1,1 J (cel A 0,8 → 0,6). J i przyspieszenie bez zmian (jeden etap to za mało).
Realistyczny rozwój narzędzi, 18 h/tydz.: **A ≈ 6,5 tyg., B ≈ 16 tyg., C ≈ 29 tyg.** (etap 29: 7 / 17 / 30).
Prognoza nadal nie jest obietnicą terminu; pojedynek 1:1 to najprostszy przypadek walki.

## 19. Wyniki regresji

System testowy: **Ubuntu 22.04 (GCC 11.4, glibc 2.35, Godot 4.7.2) w maszynie wirtualnej na komputerze użytkownika
i Ubuntu 24.04 (GCC 13.3) w kontenerze**. Debian 13 nie był dostępny.

| Test | Wynik |
|---|---|
| CTest Release GCC 11.4 (DLL, `.tai`, dane lokalne) | **18/18** zaliczonych (16 dotychczasowych + `mapa`, `walka`) |
| CTest Debug GCC 11.4 (jw.) | **18/18** zaliczonych |
| CTest Release GCC 13.3 (DLL, bez danych lokalnych) | 16 zaliczonych, 2 **pominięte** (`astar_gra`, `porownanie_gra`); części lokalne `mapa` i `walka` pominięte (SKIP, nie PASS) |
| S1–S7 | bitowo, skrót zbiorczy `c36721320b3595e4` – bez zmian |
| Debug = Release | pełne wyjście testów identyczne (GCC 11); skróty S1–S7, scenariuszy `06f1f566a2686232` i kolizji `50b15c963ab1965e` identyczne także w GCC 13 |
| A*, fizyka, kolizje, kolejka celów | zaliczone (grupy `astar`, `astar_gra`, `ruch`, `krok`, `kolizje_takt`, `kolejka`, `porownanie_gra`) |
| import mapy | `core_mapa`: syntetyczna + mapa z gry; skrót mapy z reguły `c8297c16f0d48b1a` = importer GDScript |
| walka | `core_walka`: model + pojedynek 564 (786 porównań, 0 różnic) |
| GDExtension | **22/22** (18 dotychczasowych + 4 testy mapy, w tym prawdziwy scenariusz przez GDScript → Core) |
| Godot (dotychczasowe) | **324/324** (w tym „L aktualności” z nowym wpisem) |
| testy Riverlands_MCP | **11/11** plików (10 dotychczasowych + `test_ee_etap30.py`) |
| narzędzia `narzedzia/titan` | 14/14; schemat struktur – 0 błędów walidacji |
| `git diff --check` | czysto |

Żaden test nie został osłabiony ani zamieniony na SKIP. Ostrzeżenia Godota o obiektach przy zamknięciu (ObjectDB) –
jak w poprzednich etapach.

## 20. Nierozwiązane problemy

1. 9002 – brak pomiaru (§ 10).
2. Klify (teren 9), próg głębokości −0,3, reguła pola +0x600 [N].
3. Walka: wybór celu, obrót / łuk, pościg, zasięg z rozmiarami, obszarowe, pociski, 1:N [N].
4. AoC: wzór obrażeń w kodzie, wartości tablic trafień, zakres losowania przeładowania [N].
5. Obrażenia przeciw obywatelowi (42) – brak odczytu typu [N].
6. Budżet A* na takt, cel nieosiągalny i brzeg w grze – nie zmierzone w etapie 30.
7. REA – dekompilacja dużych funkcji przekracza limit czasu; statyka opiera się na własnych narzędziach.

## 21. Rekomendacja etapu 31

1. Walka 1:N i wybór celu (CanISeeEnemy, LookForEnemies) z rejestratorem `ee_walka`; obrót do celu (0x61FC51).
2. AoC: wzór obrażeń i losowanie przeładowania (odczyt 0x5612B9, zakres), seria z wieloma atakami.
3. Strzelcy i pociski – pierwszy typ ataku dystansowego.
4. 9002 – scenariusz przesmyku z dwiema grupami.
5. Integracja walki Core z GDExtension dopiero po rozpoznaniu wyboru celu.

Etap 31 nie został rozpoczęty.
