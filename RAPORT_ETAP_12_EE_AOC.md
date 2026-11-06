# Raport etapu 12 – mechaniki podstawowego Empire Earth a The Art of Conquest

Stan wyjściowy: commit `562f7bd`, testy Godot 297/297, MCP 40/40. Kamerę i ruch grupowy mierzono dotąd tylko w AoC.
Kolejność prac: oryginalne EE i AoC → pomiary → porównanie → dokumentacja → zmiany w OpenEE → regresja.

Oznaczenia: **[P]** potwierdzone, **[W]** wniosek z ograniczonego pomiaru, **[H]** hipoteza, **[N]** nieustalone.
Zakres: **EE**, **AoC**, **obie**, **obie?**.

## 1. Wynik w skrócie

- Narzędzia MCP odczytują stan **podstawowego EE** (`Empire Earth.exe`): ekrany, graczy, obiekty z pozycją,
  zaznaczenie, kamerę i zoom. Odczyt sprawdzono z plikiem scenariusza: typ i gracz zgodne dla 5325/5325 obiektów [P].
- Kamera, zoom, granice, wysokość ogniska, reguły zaznaczania, prędkości, szyk i zastępowanie rozkazów działają
  w EE tak samo jak w AoC [P]. Wspólny kod OpenEE wystarcza, bez rozgałęzień według gry.
- Pomiar wykazał dwie różnice o niskiej pewności:
  - narastanie prędkości przewijania krawędzią w AoC [W];
  - prędkość proroka [H].
  Obu nie zaimplementowano.
- Mnożnik prędkości jednostek (1,46 z etapu 9) zależy od scenariusza, a nie od gry. Na „Wojnie trojańskiej” wynosi
  1,706 w obu grach [P].
- Zmiany w OpenEE:
  - dane pomiarów obu gier;
  - testy zgodności wspólnego kodu z pomiarami EE i AoC;
  - dokumentacja.
  Kodu mechanik nie zmieniano, bo pomiar nie wykazał potrzeby zmiany.

## 2. Faza A – rozszerzenie Riverlands_MCP

Rozszerzono istniejący serwer `riverlands-ee`. Nie powstał trzeci serwer i nie powielono funkcji Godot MCP.
Szczegóły: `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 16.

- **A1, rozpoznanie procesu.** Tylko proces, którego `cmdline[0]` kończy się `Empire Earth.exe` albo `EE-AOC.exe`
  i który ma ten plik zmapowany. Kompilacja rozpoznawana po SHA-256. Przy dwóch grach naraz narzędzia odmawiają.
  Każdy wynik `ee_stan` podaje wariant i kompilację.
- **A2, struktury EE** (zmierzone, tylko odczyt):

  | Struktura | Wynik |
  |---|---|
  | wskaźniki RTTI | gra, UI, mysz, formularz |
  | stan gry | `0x918300` |
  | typ obiektu | +0x4B8 (AoC +0x1BC) |
  | zaznaczenie | +0x9BC / +0x9C0 (AoC +0x9AC / +0x9B0; +0x9AC w EE to grupa zapisana) |
  | kamera | macierz `0x91831C` |
  | projekcja | `0x9125A0` |
  | zoom | `0x918D38` |

  Tryb przezroczystości i kopie macierzy renderera w EE nie są zbadane, więc narzędzia zgłaszają brak obsługi.
- **A3, wspólne API.** `ee_stan`, `ee_jednostki`, `ee_kamera`, `ee_obiekty_w_widoku`, `ee_widok`, `ruch_*` korzystają
  z definicji wariantu (`W.*`). Wspólny offset występuje tylko tam, gdzie pomiar w obu grach dał tę samą wartość.
- **A4, testy na żywo** (zadania 180–235): liczby obiektów, zmiany pozycji, kamera, zaznaczenie, `kam_ustaw`
  w obu grach. Wyniki EE i AoC zapisano osobno. Klawisze są zwalniane po każdym kroku. Kopie scenariuszy usunięto
  po nazwie z obu katalogów `Scenarios`, a pliki gier nie zostały zmienione.

Testy MCP: **48/48** (wcześniej 40). Nowe: `testy/test_ee_warianty.py` (8). Lokalne commity `90736d3`, `532506c`.
Repozytorium MCP nie ma zdalnego `origin`.

## 3. Faza B – środowisko porównawcze

- SCN 250 nie wczytuje się w podstawowym EE („Plik z zapisaną grą jest nieprawidłowy”) [P].
- Wybrano kampanię EE „Wojna trojańska” (SCN 231). W obu grach daje 7 graczy i 5368 obiektów w pamięci [P].
- Scenariusz zawiera teren płaski i górzysty, morze, mury z bramą, budynki, drzewa, obywateli, piechotę, bohatera
  i proroka.
- Kawaleria i bród – brak w scenariuszu. Porównanie z etapem 9 (AoC, Riverlands).
- Szybkość gry w rejestrze: 1 w obu grach.
- Ustawienia różne i niezmieniane: czułość myszy EE 31 / AoC 7, VSync 0 / 1.
- Statystyk jednostek nie zakładano z ID. Typy 32, 422, 173, 216 mają w obu bazach te same `Speed`, odczytane
  z `dbobjects` każdej gry.

## 4. Fazy C–E – pomiary

Pełna tabela: `docs/POROWNANIE_MECHANIK_EE_AOC.md`. Najważniejsze liczby:

| | EE | AoC |
|---|---|---|
| azymut / pochylenie | 135° / 35° | 135° / 35° |
| zoom | 21 poziomów, 29,7 − 1,49·krok | to samo |
| strzałki, poziom 20 / 0 | 42,3–43,2 / 14,16 pola/s | 43,45 / 14,48 |
| dwie strzałki | 60,6 | 61,3 |
| krawędź, prędkość docelowa, poziom 20 / 0 | 38,1 / 12,4 (bez narastania) | 38,4 / 12,3 (narasta ~1 s) |
| środkowy przycisk, 200 jednostek | 35,9 pola | 36,7 pola |
| granica ogniska | romb x + y ∈ [140, 420] | to samo |
| wysokość ogniska | śledzi teren, 0,4 nad morzem | to samo |
| prędkość jednostki | `Speed` × 1,706 | `Speed` × 1,706 |
| szyk, końcowe pozycje | zgodne z AoC ≤ 0,05 pola | – |

Fazy C–E w szczegółach:

- **Faza C (kamera).**
  - Zmierzone w obu grach: dwa klawisze naraz, skrajne poziomy zoomu, granice mapy, teren i woda, modyfikatory kółka.
  - Przerywników nie badano.
  - Ramka zaznaczenia przy krawędzi: tylko etap 10 (AoC).
- **Faza D (zaznaczanie, ruch, kolizje).**
  - Zaznaczanie i ruch – patrz tabela.
  - Limit zaznaczenia [N].
  - LPM na pustym terenie w EE [H]: punkt testowy trafił w mur.
  - Test grup idących naprzeciw nie dał czystego wyniku. W EE jest tylko częściowe skrzyżowanie: najmniejsza
    odległość 0,99, odchylenia do 1,8 pola przy murze. W AoC kliknięcia zaznaczały sąsiednie jednostki. Wynik [N],
    dlatego unikania lokalnego nie dodano.
- **Faza E (grafika).**
  - 5 par porównywalnych kadrów: ta sama geometria, modele, skala i woda [P].
  - EE jest ~10 jednostek jasności ciemniejsze [H]: stan sceny, nie zasoby ani renderer.
  - Renderer bez zmian.

## 5. Faza F – zmiany w OpenEE

| Plik | Zmiana |
|---|---|
| `dane/mechaniki_ee_aoc.json` (nowy) | pomiary obu gier z tolerancją, zakresem, pewnością i listą różnic nieustalonych |
| `godot/testy/testy_etapu12.gd` (nowy) | 11 testów: osobne wartości EE i AoC, zgodność wpisów „obie”, `ModelKameryEE` zgodny z pomiarem EE i AoC (12 parametrów), granica rombu, brak implementacji różnic [W]/[H], niezmieniony mnożnik prędkości |
| `godot/testy/uruchom_testy.gd` | rejestracja zestawu etapu 12 |
| `godot/silnik/symulacja/symulacja.gd` | opis `MNOZNIK_PREDKOSCI`: pomiar AoC na Riverlands, zależność od scenariusza; wartość bez zmian |
| `godot/sceny/rts_test.gd` | napis diagnostyczny „pomiar AoC, etap 9” zamiast „pomiar EE” |

Nie dodano mechanik walki, ekonomii, AI ani UI.

## 6. Faza G – testy

| Zestaw | Zaliczone | Błędy | Pominięte |
|---|---|---|---|
| Godot (headless, urządzenie) | **308** (297 + 11 nowych) | 0 | 0 |
| MCP (Python) | **48** (40 + 8 nowych) | 0 | 0 |
| Integracja na żywo – EE | odczyt stanu, graczy i obiektów; kamera; `kam_ustaw`; zaznaczanie; ruch; przewijanie krawędzią | test kolizji naprzeciw nierozstrzygnięty | – |
| Integracja na żywo – AoC | jw. | test kolizji naprzeciw nierozstrzygnięty | – |
| RTX 5090 (Vulkan 1.4.357, Forward+) | 3 rendery, 0 błędów: `e12_rts_ee_troja` (gra `ee`, warstwa vanilla), `e12_rts_aoc_troja` (gra `aoc`, vanilla + aoc), `e12_rts_aoc_rzym` („Żołnierze dla Rzymu”, AoC) | – | – |

**Uwaga do renderów.** Scena RTS bez argumentów szuka scenariusza po angielskiej nazwie („soldiers for rome”). Przy
polskich tekstach kampanii nie znajduje go i kończy się błędem. Z polską nazwą („wojna”, „żołnierze”) działa. To
zachowanie sprzed etapu 12, nie regresja; pozostaje do poprawy osobno.

Odporność MCP:
- brak procesu → `faza: brak_procesu`;
- nieznana kompilacja → `NieobslugiwaneWariant`;
- dwie gry → odmowa;
- brak zapisu do pamięci – test statyczny.

## 7. Faza H – dokumentacja i wersjonowanie

- Nowe: `docs/POROWNANIE_MECHANIK_EE_AOC.md`, ten raport.
- Zaktualizowane: `docs/MECHANIKA_KAMERY_EE.md` (§ 7), `docs/MECHANIKA_RUCHU_EE.md` (§ 10), `docs/WARIANTY_GRY.md`
  (§ 3.3, § 4, § 6). Pomiary EE oddzielono w nich od pomiarów AoC.
- Nie publikowano pamięci procesu, zrzutów, modeli, tekstur, danych scenariuszy ani binariów. Wyniki zadań
  i zrzuty zostają lokalnie w `Testy_MCP/`.
- `godot/project.godot` (lokalna zmiana Godot MCP) – poza commitami.
- Kopie bezpieczeństwa sprzed etapu: `kopie_OpenEE/*przed_etapem12*`.

## 8. Otwarte

1. Przyczyna narastania przewijania krawędzią w AoC: czułość myszy czy kod gry. Pomiar wymagałby zmiany ustawień
   użytkownika, więc nie był wykonywany.
2. Grupy idące naprzeciw w EE – jednostki odsunięte od siebie, zaznaczane ramką przy większym zoomie.
3. Przyczyna mnożnika prędkości zależnego od scenariusza (1,46 / 1,706).
4. Prędkość proroka na dłuższej trasie.
5. LPM na pustym terenie i limit zaznaczenia w EE.
6. Przezroczystość budynków (F5) w EE – adres trybu nieznaleziony.
7. Bezwzględna wartość przesunięcia środkowym przyciskiem względem etapu 10.
