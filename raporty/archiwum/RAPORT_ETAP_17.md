# OpenEE – raport etapu 17: grupy ruchu w silniku Titan

Czwarty etap rekonstrukcji kodu silnika Titan. Zakres: co dzieje się po wykonaniu rozkazu `EEMPathTo`, czyli tworzenie
grup ruchu, przypisanie jednostek i przekazanie celu, bez wyszukiwania tras, szyku i ruchu. Szczegóły:
**`docs/titan/grupy_ruchu.md`**. Poprzedni krok: `docs/titan/rozkazy_gracza.md`.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `01f27c7`, testy Godota 324/324.

## 1. Wynik

1. **Podział na grupy** (pytania 1–3). `EEMPathTo::Execute` (EE 0x4B9D7B, AoC 0x4C281C) tworzy kolejno grupy
   `EEActiveGroup` dla środowisk ruchu i wypełnia je zaznaczonymi jednostkami (0x5DD18B, warunek 0x5DD2D8):

   | k | Grupa | Warunek |
   |---|---|---|
   | 1 | powietrze | bit 0 |
   | 2 | ląd | bit 1 albo klasa budynku |
   | 3 | nawodne | bit 2, bez okrętów podwodnych |
   | 4 | podwodne | bit 2 i `Unit type` 10 |
   | 5 | kosmos, **tylko AoC** | bit 3 |

   Stąd 4 przebiegi w EE i 5 w AoC.

   Bity to flagi środowiska typu jednostki (EE +0x5D4, AoC +0x2D0). Gra liczy je przy wczytaniu typu ze stałych
   zbiorów wartości pola `Unit type` z `dbobjects` (EE +0x4B4, AoC +0x1B8) [P: kod; pomiar flag i `Unit type` dla
   5 typów w EE i AoC].
2. **Dodatkowe warunki przypisania.** Jednostka musi być aktywna i żywa. Po wypełnieniu grupa traci jednostki
   o prędkości 0, z wyjątkiem lotniska (ID 0x42). Budynki wchodzą więc do grupy lądowej, ale zaraz z niej wypadają [P: kod].
3. **Cel ruchu** (pytanie 4) – `EEUGLocation` (0x38 B):
   - punkt x, y, z;
   - rodzaj 1 („lokacja”);
   - czas gry utworzenia (`A_GRA`+0xD0) i kolejny numer celu;
   - kąt z `EEMPathTo`+0x10;
   - flagi z `EEMPathTo` +0x1C, +0x1D, +0x1F.

   Grupa dostaje cel (+0x68), flagę Shift (+0xB5) i przełącznik parametrów szyku (+0xB6) [P: kod; pomiar pól celu].
4. **Shift i zastępowanie** (pytanie 5):
   - Execute zawsze tworzy nowe grupy i przenosi do nich jednostki, także przy Shift [P: pomiar AoC – nowe adresy grup];
   - Shift trafia do grupy jako +0xB5 = 1 z `EEMPathTo`+0x1E [P: pomiar];
   - [Etap 16 – zastąpione] `EEMPathTo`+0x1C nie jest flagą Shift: przy Shift pozostało 1;
   - dopisanie do kolejki celów jednostki albo jej wyczyszczenie rozstrzyga dopiero obsługa stanu 8000 (0x5DB641)
     [W: kod, poza zakresem].
5. **Wartość 8000** (pytanie 6) to **kod stanu/polecenia grupy**, nie czas. Pole +0x6C ma 5000 po utworzeniu grupy,
   a `EEMPathTo` wpisuje 8000. Maszyna stanów grupy (0x5DD463) obsługuje od razu kody 2001–16001; dla 8000 woła
   0x5DB641, który zamienia cel grupy na cele jednostek (szyk, kolejki, Shift). Kod 8000 zapisują także inne
   polecenia [P: kod; nazwa „cel ruchu do lokacji” – W].
6. **EE ↔ AoC** – wszystkie funkcje zgodne po normalizacji. Różnice:
   - przesunięcia pól typu i gracza;
   - piąty przebieg i bit 3 (kosmos);
   - dodatkowe ID 0x2ED („cp Missile Base”) z flagą lądu;
   - pole grupy +0xB7.

   [P]

## 2. Weryfikacja

Zadania MCP, tylko odczyt pamięci, scenariusz „Wojna trojańska”:
- 374–378 (EE) i 380–382 (AoC);
- pauza F3 po rozkazie, żeby odczytać stan grup w kolejnym zadaniu;
- sprzątanie: 379, 383.

| Sprawdzenie | Wynik |
|---|---|
| flagi i `Unit type` (obywatel, gwardia, prorok, galera, transportowiec) | 2/2/2/4/4 oraz 6/5/13/4/18 – zgodnie z kodem (EE i AoC) [P] |
| jedna jednostka | 1 grupa `EEActiveGroup`, stan 8000, cel `EEUGLocation` rodzaju 1 (EE) [P] |
| obywatel + galera | 2 grupy z tym samym punktem i czasem celu (EE i AoC) [P] |
| luka w numerach celów | cel jednostki tworzony między celami grup – zgodne z 0x5DB641 [W] |
| Shift + PPM (AoC) | nowe grupy, +0xB5 = 1, cel +0x30 bez zmian [P] |

## 3. Błędy oryginału

Nie znaleziono nowych błędów. Odnotowany nadmiarowy warunek (+0x61E przy ID 0x43) nie zmienia zachowania, więc nie
trafił do `BLEDY_ORYGINALU.md`.

## 4. Przeszkody i granica

1. 0x5DB641 (ok. 1900 instrukcji): cele jednostek, szyk, kolejki celów, Shift – system szyku i kolejek, poza zakresem.
2. Znaczenie list grupy +0x48/+0x58, listy jednostki +0x58/+0x68, pola +0x335 oraz bajtów `EEMPathTo` +0x1C/+0x1D – [N].
3. Pozostałe kody stanów grupy i rodzaje celów – [N].
4. Zachowanie lotniska lub budynków w zaznaczeniu przy rozkazie ruchu – nie mierzono.

## 5. OpenEE (bez zmian w kodzie)

`Symulacja.rozkaz_grupy` traktuje zaznaczenie jako jedną grupę. Wierny model to:
- podział na grupy środowiska;
- wspólny cel grupy z czasem i numerem;
- usunięcie jednostek nieruchomych;
- Shift jako flaga grupy, rozstrzygana dopiero w etapie szyku.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/grupy_ruchu.md` | nowy wpis atlasu Titan |
| `docs/titan/rozkazy_gracza.md` | adnotacja [Etap 17 – zastąpione] przy znaczeniu `EEMPathTo`+0x1C/+0x1E; odnośnik do grup |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 17, nowy aktualny raport |
| `RAPORT_ETAP_16.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 17”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian. Użyto istniejących kroków Riverlands_MCP.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_17.md` |

## 8. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
