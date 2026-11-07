# OpenEE – raport etapu 13: automatyzacja testów, rzeczywista prędkość jednostek i kolizje grup

Zasada etapu: oryginalne Empire Earth / The Art of Conquest → pomiary → dokumentacja → implementacja w OpenEE →
porównanie → testy.

**Oznaczenia:**
- **[P]** potwierdzone powtarzalnym pomiarem;
- **[W]** wniosek z ograniczonego pomiaru;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `109b239`, 308 testów Godota, 48 testów MCP.

Raport rozdziela trzy rodzaje wyników:
- testy automatyczne (Godot, MCP) – sprawdzają kod;
- testy integracyjne – sceny OpenEE renderowane na GPU;
- pomiary oryginalnych gier – zadania MCP na uruchomionych grach.

## 1. Metoda pomijania intra

**Pomiar w oryginale – analiza kodu exe.** Filmy startowe odtwarza jedna funkcja inicjalizacji, wywoływana raz:

| | EE | AoC |
|---|---|---|
| funkcja intra | 0x538867, wywołanie 0x535EE5 | 0x5439B5, wywołanie 0x5410BA |
| filmy | Sierra, SSSI, Empire Earth (`Movies\*.bik`) | Sierra, MadDocSoftware, Empire Earth |
| warunek wejścia do pętli filmów | 0x538955 `je` (`0F 84 9E 01 00 00`) | 0x543AA3 `je` (`0F 84 A8 01 00 00`) |

Ani parametr, ani rejestr nie wyłączają intra. EE nie ma żadnego przełącznika. AoC pomija filmy tylko przy starcie
z lobby (`hostgame` / `joinbyip`), który zmienia dalszy przebieg gry. Katalog testowy z pustym `Movies` też nie
działa, bo ścieżka danych pochodzi z rejestru.

**Rozwiązanie.** Odwracalna łatka **oddzielnej kopii** exe zamienia 6 bajtów: `je` na `jmp` + `nop` do kodu za
pętlą. Kopia leży w `Testy_MCP/ee_start/kopia_bez_intra/` obok dowiązań do plików instalacji. Instalacja pozostaje
nietknięta. Filmy kampanii i scenariuszy idą osobną ścieżką kodu i nadal działają. Szczegóły:
`Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 17.

**Przerywniki w scenariuszach testowych** pomija Esc, zgodnie ze wskazaniem użytkownika:
`start_testowy(esc_przerywnik=N)` wysyła Esc tylko wtedy, gdy czas gry stoi. „Wojna trojańska” wymaga dwóch Esc
(dwa ujęcia), a scenariusze z „Blitzkriegu” żadnego. Intro startowe nie dostaje żadnych klawiszy.

## 2. Czasy startu (pomiary oryginałów)

| | EE | AoC |
|---|---|---|
| filmy startowe w kopii testowej | nie są odtwarzane (proces otwiera tylko `data.ssa`) | jw. |
| start → menu główne, mediana (zakres) | 22,25 s (22,06–22,48), 23 starty | 22,31 s (22,13–22,56), 20 startów |
| start → scenariusz gotowy (z odprawą), mediana (zakres) | 43,68 s (43,25–44,08), 22 starty | 43,05 s (42,82–43,40), 19 startów |
| dla porównania: oryginalny exe, filmy bez przerywania | ok. 149 s do menu | – |

Czas do menu to w całości wczytywanie danych gry [P].

## 3. Przyczyna różnicy prędkości (`docs/MECHANIKA_PREDKOSCI_EE.md`)

- `Speed` z `dbobjects` podaje pola na sekundę **czasu gry** [P].
- Licznik ms czasu gry (`A_GRA+0xD0`, ten sam w obu grach) rośnie o **1460,7–1461,5 ms na sekundę rzeczywistą**
  w EE i AoC (6 pomiarów, 2 scenariusze, osobne uruchomienia procesu) [P]. Mnożnik etapu 9 (1,46) to tempo czasu
  gry.
- **1,706 z etapu 12 był artefaktem metody** [P]. Położenie zmienia się skokowo co takt (43,32 taktów/s), więc
  maksimum próbek 10 Hz zawyża prędkość. Średnia na środkowych 60% ruchu daje `Speed` × 1,43–1,50.
- Sprawdzono trzy scenariusze, przy każdym osobne uruchomienia procesu:
  - „Wojna trojańska”: prorok 0,461, gwardia 0,575 pola/s gry, identycznie w EE i AoC;
  - Riverlands (etap 9);
  - scenariusze testowe z „Blitzkriegu”: obywatel 0,650 (107 przejść), prorok 0,600 (trasa 27–28,6 pola,
    2 jednostki w każdej grze).
- **Prorok** nie ma osobnego mnożnika [P].
- Scenariusze z „Blitzkriegu” mają **stały dodatek +0,15 pola/s gry** dla obywatela i proroka, w obu grach [P].
  Przyczyna jest [N]. Wykluczono, zmieniając jeden czynnik naraz:
  - grę;
  - typ jednostki;
  - `dbobjects`;
  - pole `Speed` w obiekcie klasy w pamięci;
  - technologie gracza 1 (żadna nie zmienia prędkości);
  - gotową cywilizację „Germany” (bez premii prędkości).

  Dodatku nie zaimplementowano.
- Rozpędzanie trwa ok. 0,3 s [W]; nie zaimplementowano.

## 4. Kolizje (`docs/KOLIZJE_JEDNOSTEK_EE.md`)

Scenariusz testowy jest kopią „Blitzkriegu” ze sklonowanymi obywatelami na płaskim obszarze; oryginały pozostały
niezmienione. Trajektorie pochodzą z pamięci (30 Hz, zegar monotoniczny i licznik gry).

| Przypadek | Wynik (EE = AoC) | Pewność |
|---|---|---|
| 1 na 1, 5 na 5, 10 na 10 naprzeciw | przenikanie: d_min 0,015–0,054, bez zwalniania, zatrzymań i objazdów | [P] |
| skrzyżowanie pod kątem prostym 5 + 5 | przenikanie (d_min 0,13–0,15) | [P] |
| przesmyk 1 pola, 5 jednostek | przejście w 0,9 s, nakładanie (0,184), bez kolejki | [P] |
| jednostka stojąca na trasie | **objazd jej pola** (d_min 0,66), bez zwalniania; EE i AoC zgodne do 0,01 pola | [P] (1 układ) |
| kilka jednostek do jednego punktu | druga staje 0,3 pola od pierwszej, bez popychania | [W] (2 jednostki) |

## 5. Różnice EE ↔ AoC

W żadnym pomiarze etapu 13 nie stwierdzono różnic:
- zegar gry: 1461 ms/s w obu grach;
- prędkości: zgodne do 0,001 pola/s gry;
- trajektorie kolizji: zgodne do 0,01–0,03 pola;
- intro: ten sam mechanizm w obu grach, inne adresy.

Wspólny kod OpenEE wystarcza. Z listy różnic w `dane/mechaniki_ee_aoc.json` usunięto prędkość proroka; została
tylko różnica przewijania krawędzią z etapu 12.

## 6. Zmiany w OpenEE

| Zmiana | Pliki |
|---|---|
| D1: scena testowa wybiera scenariusz **numerem z listy kampanii** (`campaigns/*_scenariolist.txt`), a nie przetłumaczonym tytułem; domyślne kampanie z definicji gry (EE: `EETheGreeks.ssa` nr 3, AoC: `AOCRoman.ssa` nr 1); `--scenariusz-nr=<n>`; `--scenariusz=` zostaje jako filtr diagnostyczny | `silnik/rdzen/gry_ee.gd`, `sceny/test_scenariusz.gd`, `dane/gry.json`, `narzedzia/test_wizualny_051.sh` |
| `MNOZNIK_PREDKOSCI` = 1,461 (tempo czasu gry) z nowym opisem; wpis 1,706 wycofany, dodano `zegar_gry_na_sekunde` i `modyfikator_predkosci_blitzkrieg` ([N], bez implementacji) | `silnik/symulacja/symulacja.gd`, `jednostka_sym.gd`, `sceny/rts_test.gd`, `dane/mechaniki_ee_aoc.json` |
| Omijanie pól jednostek **stojących** przy wyznaczaniu trasy (`OMIJANIE_STOJACYCH`, `zajete_komorki`, `Sciezki.znajdz(..., zajete)`); jednostki z rozkazem w tym samym takcie nie blokują się; jednostki w ruchu przenikają się dalej, bez fizyki i odpychania | `silnik/symulacja/symulacja.gd`, `sciezki.gd` |
| Narzędzie scenariuszy testowych kolizji | `narzedzia/scenariusz_testowy_kolizji.py` |
| Testy etapu 13; test E12 o mnożniku zmieniony na tempo zegara gry | `godot/testy/testy_etapu13.gd`, `testy_etapu12.gd`, `uruchom_testy.gd` |
| Dokumentacja (D2 – podział testów bez okna i na GPU w README) | `docs/MECHANIKA_PREDKOSCI_EE.md`, `docs/KOLIZJE_JEDNOSTEK_EE.md`, `docs/MECHANIKA_RUCHU_EE.md`, `docs/POROWNANIE_MECHANIK_EE_AOC.md`, `README.md` |

Systemów walki, ekonomii i AI nie zaczynano.

## 7. Testy automatyczne

| Zestaw | Przed | Po | Wynik |
|---|---|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 308 | **322** | 322 zaliczone, 0 pominiętych, 0 błędów |
| MCP (`python3 -m unittest discover -s testy`) | 48 | **64** | 64 OK |

Nowe testy Godota (E13, 14):
- scenariusz z listy kampanii: PL/EN syntetycznie i obie instalacje (polska społecznościowa i angielska
  referencyjna), definicje EE i AoC;
- kolizje (4): omijanie stojącej, przenikanie idących, brak blokowania w grupie, zamknięte przejście;
- model prędkości (3).

W logu testów Godota pojawia się komunikat silnika „Cannot set a buffer on a Multimesh…”, a na koniec „1 resources
still in use”. Nie wpływają one na wynik.

## 8. Testy integracyjne na RTX 5090

`oe_render` (Vulkan Forward+, „NVIDIA GeForce RTX 5090”) uruchamiano przy zamkniętej grze oryginalnej:

| Scena | Argumenty | Wynik |
|---|---|---|
| `rts_test` | brak | „Wojna trojańska” z instalacji polskiej (numer 3 z listy kampanii), 85 jednostek, 0 błędów w logu |
| `rts_test` | `--gra=ee` | to samo |
| `rts_test` | `--gra=aoc` | „Żołnierze dla Rzymu” (nr 1 z listy AoC), 0 błędów w logu |

Zrzuty: `Testy_MCP/oe_render/20261107_1009*_e13_rts_*` (lokalnie). Scenę z instalacją angielską sprawdzają testy
bez okna (ten sam scenariusz w obu językach), bo ustawień językowych użytkownika nie zmieniano.

## 9. Znane problemy i ograniczenia

1. Przyczyna dodatku +0,15 pola/s gry w scenariuszach z „Blitzkriegu” [N]; OpenEE go nie odtwarza.
2. Objazd jednostki stojącej zmierzono w jednym układzie. OpenEE wyznacza trasę w chwili rozkazu i nie przelicza jej
   ok. 1,5 pola przed przeszkodą jak oryginał [W/H].
3. Wspólny cel zmierzono tylko dla 2 jednostek. Dwóch jednostek przy dolnej krawędzi widoku 3D nie dało się
   zaznaczyć, bo kliknięcia trafiają w pasek interfejsu.
4. Narzędzia MCP: menu „Wczytaj” bierze pierwszy plik alfabetycznie, więc pozostawiona kopia scenariusza blokuje
   kolejne zadania. Dodano osobne zadania sprzątające; na koniec etapu katalogi `Scenarios` obu gier nie zawierają
   plików testowych.
5. Pomiar prędkości obywateli w scenariuszu `e13_predkosc` nie powiódł się: rozkaz nie dotarł. Prędkość obywatela
   pochodzi ze 107 przejść w zadaniach kolizji.
6. Rozpędzanie (~0,3 s) i animacja nie wpływają w OpenEE na prędkość.

## 10. Commity i publikacja

**OpenEE** (gałąź `main`, autor homoklikus; `godot/project.godot` z lokalną zmianą Godot MCP poza commitami):
1. scenariusz testowy wybierany numerem z listy kampanii (D1);
2. model prędkości (tempo czasu gry) i omijanie jednostek stojących, testy etapu 13;
3. dokumentacja etapu 13.

Publikacja z komputera użytkownika (to środowisko nie ma poświadczeń GitHub):
```
cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
git push origin main
```

**Riverlands_MCP** – lokalne repozytorium bez zdalnego `origin`, niepublikowane. Commity etapu 13:
- `fd564dd` – start testowy bez filmów;
- `0ede2c2` – liczniki czasu gry i analiza trajektorii;
- `2016a44` – dokumentacja intra;
- `f98bd50` – przerywniki, `typ_pamiec`, przerwanie zadania;
- `69cf113` – dokumentacja.

Nie publikowano plików gry, zapisów pamięci, zrzutów ani trajektorii: `Testy_MCP` leży poza repozytoriami.
