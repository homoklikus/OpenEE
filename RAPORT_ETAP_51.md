# OpenEE — raport etapu 51: ekonomia budowy, wielu budowniczych i zbieranie surowców

Najważniejsze wyniki:
- **Koszt budowy zmierzony:** dom – 50 drewna i 40 kamienia, koszary – 225 drewna. Gra pobiera koszt w chwili
  utworzenia fundamentu. Przy braku zasobów odmawia już przy przycisku budynku, komunikatem „Zbyt mało surowców…”.
- **Wzór przyrostu HP odczytany z kodu** (0x60D7A5, 0x60BF56) i potwierdzony pomiarem na dwóch budynkach:
  - p = ⌈BR · Hmax / (3/(n+2) · K · m) / n⌉;
  - dom: 15 HP przy jednym budowniczym, 10 HP na budowniczego przy dwóch;
  - koszary: 34 HP przy jednym budowniczym.
- **Zbieranie drewna – pełny cykl** (drzewo → ścięcie → 15 × 1 drewna co 4400 ms → Centrum Miasta → +15 → powrót)
  zmierzony dwukrotnie. Core odtwarza go w całości: 5069/5069 próbek w ruchu, stanach, kursie, drewnie gracza, ładunku
  i zapasie drzewa.
- Wszystkie wcześniej zgodne nagrania pozostają zgodne. Prorok 648: 3585/3585.
- D1–D4 nie zostały rozwiązane i przechodzą do etapu 52 (§ 10).

## 1. HEAD

- Początkowy HEAD: `372d9e5` (etap 50, zgodny z podanym zdalnym `main`).
- Końcowy: jeden lokalny commit etapu 51. Hash podaje `git log -1`.
- Bez `push`, `pull`, `fetch`, `clone`, `reset`, `rebase` i `clean`.

## 2. Commit i zmienione pliki

| Obszar | Pliki |
|---|---|
| Core | `cpp/core/include/openee/{jednostka,walka,symulacja}.hpp`, `cpp/core/src/{symulacja,maszyna_stanow,fizyka}.cpp` |
| GDExtension | `cpp/gdextension/src/openee_symulacja.{cpp,hpp}` – wersja `0.24.0 (etap 51` |
| Testy | `cpp/tests/testy_core.cpp`, `godot/testy/testy_gdextension.gd` |
| Narzędzia | `narzedzia/titan/odtworzenie_nagrania.py` (`opis_zbierania`), `narzedzia/eksperymenty/scenariusz_testowy_kolizji.py` i `scenariusze_czyste.py` (zasoby startowe w SCN) |
| Godot | `godot/sceny/potyczka.gd`, `godot/testy/eksperymenty/odtworz_scenariusz.gd` |
| Dane | `dane/testy_walki/{e42_warianty,parametry_jednostek_ee}.json`, `dane/potyczka/potyczka_e50_budowa.json`, `dane/potyczka/potyczka_e51_koszary.json` |
| Dokumentacja | `docs/titan/{budowa,zbieranie,POSTEP_REKONSTRUKCJI,dziennik_eksperymentow,README}.md`, `docs/{HISTORIA,ARCHITEKTURA_OPENEE}.md`, `README.md`, `raporty/README.md`, `dane/launcher/aktualnosci.json`; `RAPORT_ETAP_50.md` → `raporty/archiwum/` |

## 3. Funkcje i struktury Titan

| Element | Adres / pole | Status |
|---|---|---|
| zasoby gracza | EEPlayer +0xAF8 żywność, +0xAFC drewno, +0xB00 kamień, +0xB04 złoto, +0xB08 żelazo (i32) | [P: 660] |
| cykl budowy | EEUGBuildRepair vt[29] = 0x60D7A5 – +0x274++ (budowniczowie), SetHP, +0x27C (pozostały czas) | [W + P] |
| przyrost HP | 0x60BF56 – wzór z § 7, stałe 3,0 (0x825AC4) i 2,0 (0x825784), korekta drugiego cyklu (+0x54/+0x58/+0x59) | [W + P] |
| EEUGGather | vtable 0x831B80; zdarzenia vt+0x64 = 0x611420; cykl vt[29] = 0x611801; ubytek źródła 0x61724D | [W + P] |
| stany Gather.tai | 4004–4029, 8008, 8009 (rejestracja 0x618E11) | [P: 9 stanów w 673, reszta W] |
| ulepszenie obywatela | +0x110…+0x128 tempa zbierania, +0x134 Build rate, +0x14C udźwig, +0xA8 a, +0xC4 c4 = 1/a | [P: 665] |
| ulepszenie budynku | +0x144 Hmax, +0x94 m (dom i koszary 1,0) | [P: 672, 674] |
| 0x626834 | wartość bazowa atrybutu n | [W: etap 50] |

## 4. Koszty budowy i populacja

| Pomiar | Wynik |
|---|---|
| 660, migawki S0–S5 | wybór budynku i Esc – bez zmian; fundament: drewno 1222 → 1172, kamień 1333 → 1293; w trakcie i po ukończeniu – bez zmian |
| 663 | ten sam koszt domu (−50 / −40) |
| 674 | koszary: drewno 1222 → 997 (−225) |
| 661 | zasoby po 20: „Zbyt mało surowców, aby rozpocząć budowę.” przy przycisku, brak trybu stawiania, brak zmian |
| 662/666/671 | obrys koszar w niezbadanym terenie – czerwony podgląd, brak fundamentu, brak opłaty |

Koszt typu nie leży w dbobjects. Prawdopodobnie jest w dbtechtree, dla którego OpenEE nie ma schematu [H]. Wpływu
cywilizacji ani epoki na koszt nie rozdzielono: zmierzono tylko gracza 1 w epoce miedzi.

Populacja [P, znaczenie N]:

| Budynek | +0xB0C | +0xB14 |
|---|---|---|
| dom (po ukończeniu) | 390 → 440 | bez zmian |
| koszary (po ukończeniu) | bez zmian | 2 → 3 |

Dom nie zmienia wyświetlanego limitu 100. Zniszczenia domu nie mierzono. Zwrotu kosztu i pola zajętego przez obiekt
również nie mierzono [N].

## 5. Koszary 2×2 (674)

- Fundament: kotwica (147, 114), HP 1 → 1500.
- Przyrost: +34 co cykl w rytmie 29/29/30 taktów, 44 cykle, ukończenie po 45 s pracy.
- Punkt pracy: narożnik obwodu (146,85; 113,85) – ta sama reguła co dla domu.
- Po drodze CheckBuildSiteVisibility 4013 na punktach pośrednich. BuildSiteVisible liczy kwadrat odległości od środka
  budynku [P – poprawka w Core].
- Ukończenie: zgłoszenie mapy +15 s (gra 125491, Core 125488), nowy podsektor 1606 = gra.
- Różnica względem domu wynika z danych typu (Hmax, K), nie z osobnej mechaniki: jeden wzór daje 15 i 34.
- Core: fundament 2335/2335, obywatel 3803/3804 próbek (1 nieaktualna).

## 6. Dwóch obywateli (663)

- A sam: 13 cykli po 15 HP.
- B (PPM na fundamencie): 8017 → … → 4013 → 4014 → … → 4002.
- Od pierwszego cyklu B budynek ma +0x274 = 2, a oba budujące dają +10.
- Liczniki cykli są niezależne. Wspólne jest tylko n, które w wzorze daje mnożnik 3/(n+2).
- Ostatni przyrost przycięty (+4). Oba przechodzą do Idle w tym samym takcie, n wraca do 0.
- Core: A zgodny do t = 77216, B do t = 58465 (kurs 0,03 rad przy skręcie za punktem pośrednim, prawdopodobnie kontakt
  z A).

## 7. Wzór przyrostu HP

**p = ⌈BR · Hmax / (3/(n + 2) · K · m) / n⌉**, gdzie:
- BR – ulepszenie budującego +0x134 = 1000;
- Hmax – ulepszenie budynku +0x144;
- m – ulepszenie budynku +0x94 = 1,0;
- K – czas budowy typu w ms, liczony z +0x27C budującego: dom 35000, koszary 45000.

Okres cyklu wynosi Build rate. Rytm 29/29/30 to licznik +0x2B8, który co takt traci 34 ms [P: 966 i 4366 w próbkach
wejścia]. Stała 15 z etapu 50 wynika więc z danych: ⌈14,29⌉.

## 8. EEUGGather – wyniki

Pełny opis: `docs/titan/zbieranie.md`.

- Sekwencja stanów (Gather.tai, jeden stan na takt): 8008 → 8000 → 2015 → 10003 → 9000 → 4004 → (15 cykli) → 4024 →
  4007 (pierwszy kurs) / 4021 (drugi) → 8009 → … → 4005 → 4016 → 4023 → 8008.
- Pierwszy cykl ścina drzewo (HP 1 → 0). Kolejne: +1 drewna co 4400 ms, drzewo 400 → 385 → 370.
- Udźwig 15. Oddanie: drewno gracza +15 w próbce wejścia w 4005.
- Punkty pracy: (140,15; 111,15) przy drzewie i (145,85; 111,15) przy Centrum Miasta. Każdy z nich jest rzutem
  poprzedniego punktu na obwód drugiego obiektu [H].
- Kliknięcie w koronę drzewa daje EEUGLocation. Działa kliknięcie w pień.

## 9. Ekonomia i zbieranie w Core

- **Ekonomia:**
  - `ustaw_zasoby`, `zasoby`, `oplac`;
  - koszty i dane typu (`budowa_typow`) w danych, nie w logice.
- **Budowa:**
  - `przyrost_budowy_titan` (0x60BF56), `budowniczowie` (+0x274);
  - `postaw_fundament`, `rozkaz_budowy`, `miejsce_budowy` i zdarzenia budowy bez zmian interfejsu;
  - `przyrost_budowy` zostaje tylko jako zapas, gdy brak K.
- **Zbieranie:**
  - `dodaj_zrodlo`, `ustaw_magazyn`, `rozkaz_zbierania`;
  - Gather.tai (własny zapis), stany 8008/8009/4004/4005/4007/4021;
  - tryb ruchu 6 (praca: v = ω = 0) [P].
- **Hipotezy:** punkty pracy, ResourceInRange/StorageInRange (≤ 0,1 od obwodu), wybór magazynu (najbliższy z flagą),
  współczynnik tempa dla innych surowców [N].
- **Nie zrobiono:** szukania nowego źródła, kolejki przy źródle, farm i zwierząt.

## 10. Status rozbieżności

| Pozycja | Status |
|---|---|
| D1 prorok 652, obrót końcowy (t = 75034) | **otwarte, przeniesione.** Analiza pomiaru: gra wykonuje CompletedUnitFacing z przyciągnięciem do kursu celu przed fizyką, a potem jeszcze jeden krok z ω/2 (kurs −2,9602 ≠ cel −2,9444). Core kończy na celu. Warunek w kodzie nieprzeczytany |
| D2 FaceEnemy przy π (654 NE, 42477) | otwarte, bez zmian |
| D3 faza przeładowania | otwarte; nowego nagrania nie wykonano (czas pomiarów zajęły A–C) |
| D4: koszary od W (654, 50727), kontakt z niszczonym budynkiem, RNG zapadania, 619/620, AI | otwarte, bez zmian |
| nowa: 673 – zatrzymanie po ruchu do punktu w polu drzewa | gra zamraża pozycję w 9006/5001 przy v = 0,295 i hamuje dopiero w 5000. Core hamuje w 9006 |

## 11. Testy i zgodność nagrań

| Zestaw | Etap 50 | Etap 51 |
|---|---|---|
| CTest Release / Debug | 21/21 / 21/21 | 21/21 / 21/21 (`budynki`: 36 sprawdzeń – wzór, dwóch budowniczych, koszt, zbieranie) |
| GDExtension | 69/69 | **73/73** |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 108/108 | 108/108 |
| skrót scenariuszy | `f9299fc62b3594f9` | bez zmian |

Nagrania (pierwsza rozbieżność):

| Nagranie | Wynik |
|---|---|
| 631/633/634/638k/638c, 644 ×4, 646, e48 ×3, 654 dom E/N/SW/W i koszary N | w całości |
| 648 | prorok 3585/3585; gwardie od 6136 (D3) |
| 649 dom / koszary, 651 | zapadanie 79432 / 76909 / 74215 (bez zmian) |
| 652 mur_rog | 75034 (D1); dom_*/kosz_* – gwardie 5318–6204 (D3) |
| 654 NE / koszary W | 42477 / 50727 |
| 619 / 620 | 124254 / 109423 |
| **658_1 / 658_2 / 659 / 660** | **w całości** (obywatel 2650 / 2649 / 3013 / 2411, fundament 1277 / 1269 / 1813 / 1806) |
| **674 koszary** | **w całości** (fundament 2335/2335) |
| 663 dwóch budowniczych | A 2120/2270, B 1581/2270 (58465 – kurs) |
| **673 zbieranie od t = 80000** | **w całości 5069/5069**, ekonomia 5069/5069; od początku: 46534 (ruch, § 10) |
| potyczka_e47 (restart) | 897 / 895, gruz i znacznik po 1 |
| potyczka_e50_budowa | HP 1 → 500, 10003 → 4002 → 5000 |

Graf przejezdności: termin i nowy podsektor po ukończeniu zgodne dla domu (659) i koszar (674). Determinizm:
powtórzenia Core identyczne, przebiegi gry 658 ×2 identyczne. Porównanie kursu w próbkach nieaktualnych i rozdartych –
jak w etapie 50.

## 12. Godot

- `potyczka_e51_koszary.json`: dwóch obywateli buduje koszary. Diagnostyka podaje HP, stany i +0x274 (0 → 1 → 2 → 0).
- `potyczka.gd`: dane budowy fundamentu (K, m) z układu.
- `odtworz_scenariusz.gd`:
  - rozkaz `zbieranie`, źródła i magazyny;
  - zapis zasobów, ładunku i zapasu źródeł co takt.
- Zbierania nie pokazano w scenie. Dane diagnostyczne są w odtworzeniu.

## 13. MCP (Riverlands_MCP – zmiany lokalne, bez commitu, repozytorium bez origin)

- Nowy `ee_ekonomia.py` (obserwacyjne): `gracz_surowy`, `gracz_szukaj`, `zasoby`, `ulepszenie_odczyt`.
- `ee_budowa.py`:
  - nowe sterujące `ppm_na_obiekt` (z jawnymi punktami kliknięcia);
  - w `budowa_rozkaz`: `pomocnicy`, `ids_dodatkowe`, `gracze_surowe`.
- `ee_obserwacja.py` / `ee_walka.py`: rejestrator z `gracze_surowe` (surowe bajty EEPlayer co takt).
- `ee_diag.py`: rejestracja modułu.
- `gra.py`: `stan()` odporny na przeładowanie modułu. Przeładowanie w trakcie zadania zepsuło 667 i 668/669.
- Do odtworzenia eksperymentów potrzebne są:
  - zadania `Testy_MCP/ee_zadania/660…674`;
  - mapy `Testy_MCP/mapy/e42_e51_*.scn` (generator: `scenariusze_czyste.py <mapy> e51_…`);
  - nagrania `Testy_MCP/ee_obserwacja/e51_*`.
- Dane gry nie trafiają do OpenEE.

## 14. Niezakończone prace, hipotezy, blokery

- **K z danych gry:** brak schematu dbtechtree. K i koszt są w danych odtworzeń z pomiaru, dla 2 typów.
- **Budowa:** BuildSiteValid/Clear, pole zajęte, zwrot kosztu, naprawa (gałąź +0x340 = 1), znaczenie +0xB0C/+0xB14.
- **Zbieranie:** inne surowce, wielu zbieraczy, wyczerpanie źródła, punkt kliknięcia jako początek pracy [H].
- **Ruch i walka:** D1–D4.

## 15. Postęp rekonstrukcji Titan – ile zostało do końca?

Pełna tabela: `docs/titan/POSTEP_REKONSTRUKCJI.md` (stan po etapie 51).

**Zmiany ocen względem etapu 50:**

| Podsystem | Zmiana |
|---|---|
| 14 Budynki i budowanie | A 3 → 4, C 3 → 4 |
| 15 Jednostki cywilne | 2 → 3 (A, B, C) |
| 16 Zbieranie surowców | A 0 → 3, B/C 0 → 2 |
| 17 Ekonomia | A 0 → 2, B/C 0 → 1 |

**Wskaźniki (38 podsystemów):**

| Wskaźnik | Etap 50 | Etap 51 |
|---|---|---|
| A ≥ 3 | 17 | 19 |
| B ≥ 3 | 17 | 18 |
| C ≥ 3 | 15 | 16 |
| A = 0 | 8 | 6 |
| ocena 5 | brak | brak |
| adresy EE w dokumentacji | ok. 900 | ok. 910 |
| kod Core | 5023 wiersze | 5348 wierszy |

**Ile zostało do pełnej rekonstrukcji Titan?** Procentu nie podaję: średnia ocen (A 2,13) ani liczba adresów nie mierzą
wielkości silnika. Wiadomo jakościowo:
- odtworzona jest symulacja pojedynczych jednostek lądowych (ruch, kolizje, walka wręcz, śmierć);
- od etapów 50–51 także dwie pierwsze czynności obywatela (budowa dwóch typów budynków, zbieranie drewna) i zasoby
  gracza;
- wciąż nierozpoznane (A = 0): produkcja jednostek, transport, lotnictwo, warunki zwycięstwa i wyzwalacze, zapis gry,
  edytor;
- prawie nietknięte (A ≤ 1): AI komputera, technologie i epoki, dyplomacja, widoczność, kalamity, multiplayer.

**Minimalna grywalna wersja OpenEE a pełna zgodność:**
- Do pierwszej samodzielnej rozgrywki (gracz zbiera, buduje, produkuje i walczy) brakuje:
  - produkcji jednostek w budynkach (kolejka, koszt, populacja);
  - pozostałych surowców i ich źródeł (kamień, złoto, żelazo, żywność z farm i zwierząt);
  - interfejsu budowy i zbierania w OpenEE;
  - limitu populacji;
  - prostego warunku zwycięstwa.
- Mechanizmy dotąd zbadane wystarczają do pętli „zbierz drewno → postaw dom lub koszary”, ale nie do wyprodukowania
  jednostki.
- Pełna zgodność z oryginałem wymaga ponadto: AI komputera (69 klas EEAI*, ok. 60 EECP*), technologii i epok,
  transportu, lotnictwa, multiplayera i zapisu gry. To największa część pracy, bez danych o tempie.

**Największe blokery:**
- produkcja (EEMBuildUnit / kolejki budynków);
- schemat dbtechtree (koszty, czasy K, technologie);
- populacja;
- AI.

## 16. Propozycja etapu 52

1. **Produkcja jednostek:**
   - pomiar kolejki Centrum Miasta (obywatel): koszt, czas, populacja;
   - analiza EEMBuildUnit / kolejki budynku;
   - pierwszy cykl produkcji w Core.
2. **Schemat dbtechtree:** koszty i K z danych gry zamiast z pomiaru; potwierdzenie na domu (35000, 50/40) i koszarach
   (45000, 225).
3. **Zbieranie innych surowców:**
   - kamień i złoto (współczynnik tempa, indeks 0x636C96);
   - dwóch zbieraczy przy jednym drzewie (WaitingArea / OpenPosition).
4. **Populacja:** znaczenie +0xB0C i +0xB14, limit 100, zniszczenie domu.
5. **D1** (obrót końcowy: przyciągnięcie przed fizyką i krok ω/2), **D3** (nowe nagranie gwardii od startu), nowa
   rozbieżność 673 (9006 przy v ≠ 0).
