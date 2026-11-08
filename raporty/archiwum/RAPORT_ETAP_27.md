# OpenEE – raport etapu 27: precyzja numeryczna, walidacja kolizji, testy referencyjne i specyfikacja ruchu Titan dla Godota

Czternasty etap rekonstrukcji kodu silnika Titan. Domyka najważniejsze luki numeryczne modelu ruchu, sprawdza
kolizje i generator losowy pomiarami, przygotowuje przypadki referencyjne i specyfikację implementacji w Godocie.
**Systemu ruchu w Godocie nie implementowano.** Kod Godota i Riverlands_MCP nie były zmieniane.

Szczegóły:
- **`docs/titan/precyzja_numeryczna.md`** – UMArcTan2, tablice cos/acos z DLL, kwantowanie kursu, FPU, punkty zapisu
  f32, obrót AoC;
- **`docs/titan/walidacja_kolizji.md`** – pomiar wzoru odpychania, reguła „cel zajęty”, próby objazdu, BO-9;
- **`docs/titan/testy_referencyjne_ruchu.md`** – zestaw referencyjny, format, tolerancje, metryki v2/v3/v4;
- **`docs/titan/specyfikacja_ruchu_godot.md`** – moduły, kolejność taktu z Titan, determinizm, kolejność wdrażania;
- **`dane/testy_ruchu/ruch_syntetyczne_etap27.json`** – syntetyczne przypadki referencyjne (bez zasobów gry).

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `a6b3c55`, testy Godota 324/324.

## Odpowiedź na pytanie etapu

**Czy można już rozpocząć implementację wiernego systemu ruchu Titan w Godot?**

**Tak – częściowo i w ustalonej kolejności.** Od strony rozpoznania nic nie blokuje wdrożenia rdzenia ruchu
pojedynczej jednostki lądowej:
- matematyki Titan;
- generatora losowego;
- terenu;
- fizyki trybów 0/3/4/5 w obu wariantach;
- maszyny stanów `land.tai`;
- wzoru kolizji i odpychania.

Te moduły mają reguły z kodu, pomiary i przypadki referencyjne (EE 517 bitowo, AoC 505 z tym samym końcem ruchu,
odpychanie dokładnie).

Jest jeden warunek techniczny. Wierna arytmetyka wymaga tablic `UMCos` i `UMArcCos` z `Low-Level Engine.dll`
instalacji użytkownika: wzorem odtwarza się dokładnie 15807/16385 i 32012/32769 pozycji. OpenEE musi je wczytywać przy
starcie, jak inne dane oryginalne. Bez nich ruch będzie tylko przybliżony.

**Muszą pozostać nieukończone (oznaczone „niezweryfikowane”):**
- objazd 9002 i ObstacleDetected z progu +0x248;
- ruch dwóch jednostek jednocześnie i kolejność odbudowy kontaktów AoC;
- duże jednostki (rozmiar ≥ 1);
- Shift i aktywacja następnego celu;
- ruch grupowy AoC.

## 1. Najważniejsze odkrycia

1. **Kurs jest skwantowany przez dwie tablice z DLL** [P]:
   - kurs czytany z macierzy przez `UMArcTan2(−m01, m11)`;
   - macierz zapisywana przez `SetOrientationYPR` z tablicowych cos/sin;
   - wszystkie 1251 wartości macierzy EE 500 to wartości tablicowe.
2. **`UMArcTan2` ≠ libm** [P]:
   - przez `UMArcCos` z tablicą 32769 pozycji;
   - (0, 0) → +π/2;
   - martwa strefa < 2,4e-4 rad;
   - błąd do 4,9e-4 rad.
3. **FPU w PC_53**, czyli rejestry x87 dają dla operacji ruchu wynik IEEE f64. Pełna tabela zapisów f32 [P].
4. **AoC ma inną decyzję obrotu** niż EE (0x554F56 / 0x554738). To ona, a nie arytmetyka, dawała +15 taktów
   w AoC 505 [P].
5. **Wzór odpychania potwierdzony dokładnie** w EE 535 (4 takty, precyzja f32) [P].
6. **Zatrzymania „przed celem” z etapu 26 to reguła (a) „cel zajęty”** [P]. Kliknięcie trafiało w model stojącej
   jednostki.
7. **RNG deterministyczny** [P]:
   - ziarno z `TMGetTime` w `EEMStartLoading` (0x4BEE9D), zapisywane w zapisie gry;
   - co takt co najmniej 2 losowania globalne, ruch – 1 na jednostkę na takt.
8. **k = 2,0** (`dbworld.dat` WorldID 0x31). Jednostka opuszcza grupę przy wejściu w Idle (0x55C567) [P].
9. **BO-8 potwierdzone w kodzie. BO-9 w pierwotnym brzmieniu obalone**, nowe podejrzenie BO-9′ [W].

## 2. UMArcTan2

`docs/titan/precyzja_numeryczna.md` § 2.

| | EE | AoC |
|---|---|---|
| `UMArcTan2` w DLL | 0x1007DEBB | 0x10080DFF |
| import (IAT) | 0xB306A4 | 0xB546A0 |
| `UMArcCos` / tablica | 0x1007DCC4 / 0x100E9134 (32769 f32) | kod i tablica identyczne [P] |
| `UMCos` / tablica | 0x1007DF28 / 0x100D9130 (16385 f32) | identyczne [P] |
| `SetOrientationYPR` | 0x100472D3 | identyczne [W] |

Algorytm [P]:
- `float __cdecl (a, b)` = atan2(a, b);
- b == 0 → ±π/2 (dla (0, 0) +π/2);
- inaczej c = f32(b / sqrt(a² + b²)), wynik = UMArcCos(c), negacja dla a < 0;
- UMArcCos: tablica dla 0 < x < f32(0,9995), indeks rint(f32(x·32768)); szereg arcus tangens ze stałymi f32 do 1;
  x ≥ 1 → 0; x < 0 → π − UMArcCos(−x).

Model referencyjny sprawdzony na:
- czterech ćwiartkach i osiach;
- kątach bliskich 0 i ±π;
- wartościach bardzo małych;
- wszystkich próbkach EE 500 i AoC 505.

Porównanie bitowe f32: wszystkie odczytane wartości macierzy to wartości tablicowe, a kurs modelu v4 jest bitowo równy
odczytom w EE 517 i AoC 525 (bez kontaktów).

## 3. Precyzja numeryczna

`precyzja_numeryczna.md` § 3–5.
- `_controlfp(_PC_53)` przy starcie, przywracane w wątkach symulacji po każdym `Receive`. 24 bity ma tylko wątek grafiki.
  Zaokrąglanie do najbliższej [P/W].
- Punkty zapisu f32 [P]:
  - d (porównanie z 0,05 na wartości z rejestru);
  - cur, des, diff, n, k, S, ω′, krok kąta, yaw, v′, krok drogi;
  - pozycja: każda składowa f32(f32(krok·m) + P).
- W rejestrze zostają: S_rot, v + a·dt w porównaniu z vmax (to rozstrzyga BO-7 w EE 517), suma odcinków przed zapisem.
- Godot: `float` = f64, jawne zaokrąglenia f32. Funkcje trygonometryczne i `Vector2` Godota nie nadają się do
  symulacji.

## 4. Przyczyna rozbieżności AoC 505

- Pierwsza rozbieżna gałąź: decyzja obrotu w takcie ok. 70. Model z obrotem EE przyspiesza ω, gra hamuje.
- AoC (0x554F56) przyspiesza tylko wtedy, gdy reszta kąta po kroku rem ≥ 0 i m·dt·ω1 − S < rem, gdzie
  m = ceil(c8·tps·ω1) − 1. Przy hamowaniu (0x554738) |ω| nie spada poniżej α·dt, dopóki diff ma ten sam znak.
- Po dodaniu wariantu AoC i dokładnego kwantowania kursu: koniec ruchu w tym samym takcie co gra (było +15), średni błąd
  pozycji 0,0016, pierwszy rozbieżny takt 224 [P].
- Bez dopasowywania współczynników i bez tolerancji – reguła wynika z kodu. EE 500 nadal kończy się w tym samym takcie.

## 5. Kolizje dwóch jednostek

`walidacja_kolizji.md` § 2–5.
- **Jednostka w ruchu → stojąca** [P]:
  - EE 535: push zmierzony = push z wzoru w 4 kolejnych taktach;
  - EE 536: E mija A w odległości 0,367, push w 81 taktach, +0x248 do 1227 ms, A dostaje tylko budzik.
- **Model jednostronny potwierdzony** [P]: przy ro ≤ ru u pcha o, w przeciwnym razie o dostaje budzik (0,001; 0,001),
  a u odbicie −2·push, gdy o stoi.
- **Dwie jednostki w ruchu jednocześnie – nie zmierzono** [N]. Kliknięcie 18b/18d wybiera 55c, a wybór prostokątem jest
  zawodny. W 533 trasy się nie przecięły (min. 2,24 pola), w 537 kontakty grupy trwały 1–4 takty. Oczekiwane zachowanie
  wynika z kodu [W] (`walidacja_kolizji.md` § 5).
- Odczytane pola: pozycje, macierze, v, ω, tryb, +0x248, +0x20C, +0x330, liczba kontaktów, push, stan, stan RNG.

## 6. Różnice EE / AoC

| Element | EE | AoC | Status |
|---|---|---|---|
| decyzja i hamowanie obrotu | 0x54880E / 0x548266 | 0x554F56 / 0x554738, inna reguła | [P] |
| odbudowa kontaktów | po zapisie macierzy (od nowej pozycji) | 0x5FE611 → 0x5F6817 przed zapisem (od starej) | [W], bez testu dynamicznego; **nie deklarujemy identyczności** |
| tablice cos/acos, UMArcTan2 | – | identyczne | [P] |
| prędkość, zapisy f32, teren | – | identyczne | [P] (AoC 525) |
| przesunięcia pól | +0x264, +0x330 | +0x268, +0x33C | [P] |

## 7. RepathAroundObstacle

`walidacja_kolizji.md` § 7.
- Wymuszenie się nie udało. Max +0x248: 2693 ms (EE 535) i 2863 ms (EE 513, etap 26). Próg T = (0,75 + u·0,5)·4000
  ≥ 3000 ms.
- Licznik zeruje się przy zmianie komórki i przy zdjęciu punktu. Odpychanie prawie zawsze zmienia komórkę przed 3 s [W].
- Ścieżka przez +0x20C wymaga celu poza komórką blokującej jednostki. Kliknięcie w model stawiało cel na niej (reguła
  (a)).
- Statycznie [W]: pre-test następnego odcinka przy typ+0x5D4 & 2 → +0x20C, +0x330 = 2 → 9002. Nieudany objazd czyści
  trasę → 9006. Nie zmierzono [N].

## 8. RNG i lockstep

- Generator: LCG z `Low-Level Engine.dll` 0x10002117 (AoC 0x1000DDE9), jeden obiekt w RTSPhysics+0x18.
- Ziarno z `TMGetTime` (QPC/timeGetTime) w `EEMStartLoading` (0x4BEE9D), zapisywane w zapisie gry [P/W].
- Losowania:
  - co takt co najmniej 2 (0x546CE9, 0x547C09);
  - Advance – 1 na jednostkę na takt (ObstacleDetected);
  - wejście w Idle – 2 (warunkowo);
  - AI i inne systemy z tego samego generatora;
  - w pomiarze 15–40 kroków LCG na takt [P].
- **Determinizm** [P]: 7 startów z tymi samymi krokami dało identyczne stany generatora w tych samych chwilach
  (t = 21545 ms → 1789804865, t = 21579 → 1270085219). Trajektorie LCG z różnych przebiegów nakładają się
  (przesunięcie 342 kroków).
- Wniosek dla lockstep: OpenEE musi losować w tych samych miejscach i w tej samej kolejności jednostek, także tam,
  gdzie wynik nie jest używany.

## 9. Skrypty `.tai`

- Sekwencje stanów z pomiarów etapu 27 (EE 532, 535, 536) zgodne z diagramem `skrypty_stanow.md` § 4:
  10003 → 9000 → 2015 → … → 9006 → 5001 → 5000 [P].
- Reguła (a): 10003 → 9006 → 5001 w jednym–dwóch taktach [P].
- PPM: potwierdzone. Zawartość kolejki po Shift zmierzono w etapie 21 [P]. Przejście do następnego celu po Shift, punkt automatyczny +0x32, porzucenie rozkazu, blokada i objazd nie zostały sprawdzone
  kontrolowanym testem [N]. Przeszkoda ta sama co w § 5: wybór jednostek i kliknięcie w model.

## 10. BO-8 i BO-9

- **BO-8:** kod potwierdzony – `jb`, termin = zegar + 350, Idle oceniany co takt. Wejście w Idle zużywa warunkowo
  2 losowania, więc błąd zmienia sekwencję RNG gry [P co do kodu, H co do intencji].
- **BO-9:** obalone w pierwotnym brzmieniu – nadpisanie tylko dla murów (kategoria 0x19 bez bramy).
- **BO-9′:** flaga pominięcia kontaktu ustawiana przed pętlą i niezerowana między kontaktami [W/H].
- Rejestr: `docs/titan/BLEDY_ORYGINALU.md`.

## 11. Parametry szyku

- k = 2,0 z `dbworld.dat` WorldID 0x31 w EE i AoC, pomiar grupa+0xB0 = 2,0 w obu grach [P].
- Wartość parametru grupy = min(średnia, k·min).
- Wyjście z grupy przy wejściu w Idle (0x55C567) i przeliczenie grupy [P].
- EE 537:
  - grupa mieszana (gwardia + Aleksander) – vmax 0,7;
  - jednorodna – 0,6;
  - po dojeździe przeliczenie do 0,6 [P].
- AoC: grupy mieszanej nie uzyskano (539–540, za mało próbek) [N].

## 12. Model v4

Poza repozytorium (`Testy_MCP/e27/model/model_ruchu4.py`). Uwzględnia:
- UMArcTan2 i tablice cos/acos;
- zapisy f32 jak w oryginale;
- graniczne porównania;
- obrót EE i AoC;
- regułę stoku i pochylenie.

Wzór kolizji jest osobnym modułem (`kolizje.py`). Kolizje w przebiegu, test kroku, 9002, maszyna celów i grupy nie są
modelowane. Przebieg z kontaktami jest oznaczany jako niemodelowany.

| Scenariusz | Pozycja śr / max | v śr / max | Kąt śr / max | Koniec ruchu | Pierwszy rozbieżny takt | Inny stan | Inny punkt |
|---|---|---|---|---|---|---|---|
| EE 500 | 0,0082 / 0,0497 | 0,0012 / 0,332 | 0,19° / 4,9° | +0 | 48 | 21/813 | 8 |
| AoC 505 (obrót AoC) | 0,0016 / 0,0148 | 0,0001 / 0,068 | 0,12° / 3,2° | +0 | 224 | – | 1 |
| EE 517 ok. 1,4 pola | 0,0000 / 0,0000 | 0 / 0 | 0,00° / 0,1° | +0 | brak | 0/86 | 0 |
| AoC 525 ok. 1,9 pola | 0,0005 / 0,0110 | 0,0085 / 0,136 | 0,01° / 0,2° | −2 | 68 (kontakt) | – | 1 |
| EE 517 / AoC 525 krótkie (BO-7) | 0,006–0,026 | – | – | 0 / −3 | 2 | 0 | 0–3 |

- Krótkie rozkazy: błąd wynika z celu szacowanego z serii (kolejki nie da się odczytać).
- EE 500: znak drgania ω w kilku taktach inny niż w grze [N] – stąd max 0,05.

## 13. Porównanie z v2 i v3

`testy_referencyjne_ruchu.md` § 5 (pełna tabela).

| Scenariusz | v2 | v3 | v4 |
|---|---|---|---|
| EE 500 śr / max | 0,1186 / 0,1582, koniec −7 | 0,0106 / 0,0262, +0 | 0,0082 / 0,0497, +0 |
| AoC 505 śr / max | 0,1763 / 0,2181, −8 | 0,0054 / 0,0842, **+15** | 0,0016 / 0,0148, **+0** |
| EE 517 ok. 1,4 pola | 0,0350, −35 | 0,0000 / 0,0001 | 0,0000 / 0,0000 |

- v4 poprawia średnie i kończy oba długie przebiegi w tym samym takcie.
- Maksimum EE 500 jest wyższe niż w v3: w kilku taktach model wybiera inny znak drgania ω. Nie jest to więc
  pełna zgodność.

## 14. Zestaw testów referencyjnych

`testy_referencyjne_ruchu.md`.

**Syntetyczny (w repozytorium):** `dane/testy_ruchu/ruch_syntetyczne_etap27.json`.
- 9 przebiegów:
  - S1 przyspieszanie, S2 hamowanie z obrotem końcowym, S3 BO-7;
  - S4 cel za plecami, S4b obrót w miejscu;
  - S5 zakręty i zmiany punktów EE, S5a AoC;
  - S6 podjazd, S7 zjazd.
- 5 przypadków odpychania.
- Teren wzorowy, wyniki modelu v4.
- Brak zasobów gry. Wymaga tablic z DLL użytkownika.

**Pomiarowy (lokalnie):** `Testy_MCP/e27/referencje/` – `indeks.json` i `pomiar_*.json` z zadań 529–540, plus serie
etapów 25–26. Zawiera pomiary procesu i wysokości mapy, więc zostaje poza repozytorium.

Przypadki 9 (Shift), 11 (zablokowany krok) i 12 (objazd) nie mają pomiaru. Opisano ich status.

## 15. Gotowość implementacji

| Podsystem | Rozpoznanie | Potwierdzenie eksperymentalne | Istniejące testy / dane | Brakujące zależności | Start implementacji | Co zbadać |
|---|---|---|---|---|---|---|
| A* po polach | pełne (etap 24) [P] | punkty trasy zgodne z pomiarem (etap 24) [P] | `astar_wyniki.md` | – | **tak** | – |
| graf podsektorów | struktura i wybór maszyny [W] (etap 23) | częściowe | brak przypadków | podział na podsektory z mapy | tak, z flagą | trasy długie przez podsektory |
| kolejka celów | kod (etap 21) [W] | zawartość kolejki po PPM i Shift [P] (etap 21); przejście do następnego celu w ruchu – brak | EE 426, 429 (etap 21) | – | tak, z flagą dla przejścia | pomiar przejścia Shift w ruchu |
| maszyna stanów | `land.tai` + ocena [W/P] | sekwencje stanów EE [P] | sekwencje EE 500, 532, 535 | stany ataku, zbioru, budowy | **tak** (ruch) | inne skrypty |
| ruch liniowy | pełne [P] | EE 517 bitowo, EE 500, AoC 505, AoC 525 | S1–S3, S5–S7 | tablice DLL | **tak** | – |
| obrót | EE i AoC [P] | AoC 505 koniec +0 | S4, S4b, S5, S5a | tablice DLL | **tak** | znak drgania ω (EE 500) |
| teren | GetMeshZ, nachylenie, stok [P] | EE 517, EE 524 | S6, S7 | wysokości z mapy | **tak** | – |
| hamowanie | dyskretne drogi, R ≤ S, BO-7 [P] | EE 517 (gałąź vmax), 525 | S2, S3 | – | **tak** | – |
| kolizje | lista kontaktów, warunek [W/P] | ruch → stojąca [P] | EE 535, 536 | kolejność AoC, duże jednostki [H] | tak (EE, rozmiar < 1) | dwie jednostki w ruchu |
| odpychanie | wzór dokładny [P] | EE 535 | 5 przypadków | – | **tak** | – |
| objazdy | kod [W] | brak | – | ObstacleDetected po progu, 9002 | **nie** (szkielet z flagą) | wymuszenie 9002 |
| ruch grupowy | średnie, k = 2,0, wyjście przy Idle [P] | EE 537 | EE 519, 537 | AoC grupa mieszana | tak (EE) | AoC |
| RNG | LCG, ziarno, miejsca losowań [P/W] | determinizm 7 startów | `rng_527` | pełna lista losowań AI (poza ruchem) | **tak** | liczba losowań w Idle przy wrogach |
| precyzja numeryczna | PC_53, tabela zapisów [P] | EE 517 / AoC 525 bitowo | S1–S7 | tablice DLL | **tak** | – |

Procentów nie podajemy. Miarą są tabele błędów z § 12–13 i liczba rozbieżnych taktów.

## 16. Nierozpoznane zależności

- [N] Znak drgania ω w EE 500 (max 0,05 pola, takt 48 i kilka kolejnych).
- [N] ObstacleDetected po progu +0x248 i objazd 9002 w działaniu, także nieudany objazd.
- [N] Dwie jednostki w ruchu jednocześnie, wejście na tę samą komórkę, kolejność pętli w praktyce.
- [W] Skutek różnicy odbudowy kontaktów EE/AoC.
- [N] Shift, punkt automatyczny +0x32, porzucenie rozkazu – test kontrolowany.
- [H] Duże jednostki (0x548A3C).
- [N] Grupa mieszana w AoC.
- [W] Tablic cos/acos nie da się wygenerować wzorem. Potrzebny loader z DLL użytkownika.

## 17. Rekomendacja zakresu etapu 28

Etapu 28 nie rozpoczęto. Proponowany zakres:
1. Implementacja w Godot modułów gotowych z § 15 w kolejności ze `specyfikacja_ruchu_godot.md` § 6:
   - `MatematykaTitan` + `TabliceDLL`, `GeneratorTitan`, `TerenTitan`;
   - `FizykaLadowa` (EE/AoC), `MaszynaStanow` (land.tai);
   - `KolizjeTitan` (wzór i reguła (a));
   - z testami S1–S7 i przypadkami odpychania (bitowo, z pominięciem bez tablic).
2. Równolegle uzupełnić pomiary: wybór jednostki po identyfikatorze (dwie jednostki w ruchu, Shift, zablokowany krok,
   9002). Wymaga decyzji użytkownika o rozbudowie Riverlands_MCP.
3. Objazd, duże jednostki i AoC grupy – tylko szkielet z flagą „niezweryfikowane”.

## Zmiany w repozytorium

- nowe dokumenty atlasu:
  - `docs/titan/precyzja_numeryczna.md`;
  - `walidacja_kolizji.md`;
  - `testy_referencyjne_ruchu.md`;
  - `specyfikacja_ruchu_godot.md`;
- nowe dane: `dane/testy_ruchu/ruch_syntetyczne_etap27.json`;
- adnotacje etapu 27 w `fizyka_terenu.md`, `kolizje_objazdy.md`, `skrypty_stanow.md`, `ruch_jednostki.md` i
  `ruch_trasa_przeszkody.md`;
- `BLEDY_ORYGINALU.md`: BO-8 (kod potwierdzony), BO-9 (obalone), BO-9′ (nowe);
- `RAPORT_ETAP_26.md` → `raporty/archiwum/`, aktualizacja:
  - `raporty/README.md`, `README.md`;
  - `docs/HISTORIA.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/titan/README.md`;
  - `dane/launcher/aktualnosci.json`.

Bez zmian: kod Godota, `godot/project.godot` (lokalna zmiana użytkownika), Riverlands_MCP, instalacje gry.

## Testy

| Test | Wynik |
|---|---|
| Testy Godota | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_27.md` |

## Commit

Jeden commit lokalny. Bez `git push`.
