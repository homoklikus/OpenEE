# OpenEE – raport etapu 26: fizyka terenu, kolizje, skrypty AI i domknięcie modelu ruchu Titan

Trzynasty etap rekonstrukcji kodu silnika Titan. Uzupełnia model ruchu jednostki lądowej z etapu 25 o teren,
kolizje, objazdy, rzeczywiste skrypty stanów i parametry szyku. Sprawdza też BO-6 i BO-7 oraz przewidywanie całego
przebiegu ruchu.

Szczegóły:
- **`docs/titan/fizyka_terenu.md`** – wysokość, nachylenie, prędkość na stoku, test kroku, kolejność zapisu, precyzja;
- **`docs/titan/kolizje_objazdy.md`** – kontakty, odpychanie, +0x248, ObstacleDetected, objazd, szyk, BO-6, BO-7;
- **`docs/titan/skrypty_stanow.md`** – format `.tai`, loader, ocena przejść, diagram ruchu.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `9df7267`, testy Godota 324/324.

## Odpowiedź na pytanie etapu

**Czy po etapie 26 potrafimy przewidzieć ruch jednostki przez cały przebieg?**

Tak, dla zwykłej jednostki lądowej na trasie bez kontaktów z innymi jednostkami, w tym na nierównym terenie, w obu
grach:

| Przebieg | Średni błąd pozycji | Maksymalny błąd | Koniec ruchu |
|---|---|---|---|
| EE 500 (gwardia, 21 punktów, cały przebieg) | 0,119 → **0,011** | 0,158 → 0,026 | ten sam takt (było −7) |
| EE 517 (ok. 1,4 pola na stoku) | 0,0000 | – | ten sam takt, zero rozbieżnych taktów |
| AoC 505 (Aleksander) | 0,006 | 0,084 | +15 taktów: przypadek graniczny hamowania przy celu |
| AoC 525 (ok. 1,9 pola) | 0,001 | – | −2 takty |

Cele badawcze (< 0,02 / < 0,05 / ≤ 1 takt) osiągnięto:
- w pełni dla EE 500 (poza maksimum 0,026) i EE 517;
- dla AoC 525 i EE 517 co do końca ruchu;
- dla AoC 505 tylko co do średniej.

**Co jeszcze przeszkadza:**
1. Bitowa zgodność arytmetyki f32 i UMArcTan2 z `Low-Level Engine.dll`. Od niej zależy znak drgań ω przy wyrównanym
   kursie, a to daje rozjazd rzędu 0,01–0,02 pola na długiej trasie.
2. Przypadki graniczne decyzji hamowania przy celu, wrażliwe na różnice pozycji rzędu 1e-3. W AoC 505 przesuwa to
   koniec o 15 taktów.
3. Kolizje, objazd i test kroku. Mechanizmy są odczytane z kodu, ale model ich nie zawiera (zob. § 10).

## 1. Najważniejsze odkrycia

1. **Teren tłumaczy prawie cały błąd etapu 25** [P].
   - Reguła stoku liczy nachylenie wzdłuż osi jednostki: asin(Δz/1,3) z punktów ±0,65, przez tablicowe UMArcCos.
   - Liczy je na macierzy z poprzedniego taktu.
   - Przy v = vmax każde dodatnie nachylenie wymusza hamowanie, co daje piłokształtną prędkość.
2. **Wysokość jednostki = GetMeshZ** środka (dwa trójkąty pola) z siatki wierzchołków w `Low-Level Engine.dll`.
   Zgodność bit w bit we wszystkich próbkach [P].
3. **Skrypty `.tai` istnieją** w `data.ssa` jako tekst (EE 58, AoC 71 plików) [P].
   - Tabela przejść jednostki lądowej jest odczytana [W]; zmierzone przebiegi zgadzają się z nią co do taktu [P].
   - 5001 = ReacquireGoal, 2015 = LookForEnemies.
4. **BO-6 nie jest błędem ruchu** [P]: jednostka z etapu 24 zginęła (stan 6002), a powtórki kończą się tak samo.
5. **BO-7 potwierdzone** [P]: krótkie rozkazy kończą się wykładniczym dojazdem v = d (×0,966 na takt), w EE i AoC.
6. **Zatrzymanie przed celem przez stojącą jednostkę** [P]:
   - wjazd na komórkę z jej środkiem cofa krok i kończy rozkaz;
   - mniejsza lub równa jednostka jest spychana przez większą (AoC 525).
7. **Szyk** [P]: przy przeciągnięciu PPM wszyscy członkowie dostają średnie parametry grupy, więc gwardia jedzie 0,7
   zamiast 0,6. Obserwacja H z etapu 25 to stok, nie grupa.
8. **Precyzja** [P]: obliczenia w precyzji x87 (53/64 bity), nie f32. Model odtwarza EE 517 bezbłędnie tylko w tej
   precyzji.
9. **ObstacleDetected losuje próg co takt** z globalnego LCG symulacji (214013 / 2531011) [W]. Ważne dla lockstep.

## 2. Nachylenie i wysokość

`fizyka_terenu.md` § 1–3:
- EEMap `[0x9183BC]` (AoC `[0x930DFC]`), mesh +0x1C, wiersze wierzchołków 12 B (z f32);
- GetMeshZ z czterema zapisami pośrednimi f32;
- pitch = UMArcCos((zA − zB)·(−0,76923078)) − 1,5707964;
- s = clamp(pitch·6/π, 0, 1), hamowanie przy v > vmax·(1 − s·typ+0x488);
- zjazd nie hamuje ani nie przyspiesza;
- pochylony model (AoC Aleksander) skraca punkty pomiaru o cos(pitch); pomiar zgodny co do 0,01°;
- EE = AoC.

## 3. Test przejezdności kroku

`fizyka_terenu.md` § 4. 0x54E275 / AoC 0x55ABE8, po obliczeniu przesunięcia:
- sprawdza tylko punkt końcowy: teren, romb, obiekty komórki, regułę narożnika przy przekątnej;
- przy blokadzie ślizga po y, potem po x, potem cofa;
- komórka ze środkiem innego obiektu daje cofnięcie, zapamiętanie blokującego (+0x20C) i +0x330 = 2;
- v i kurs bez zmian; ślizg zwiększa +0x248.

Reguła obiektów jest luźniejsza niż w A*, a stojące jednostki w A* są tylko kosztem. Planowanie i wykonanie stosują
inne reguły [W].

## 4. Model kolizji

`kolizje_objazdy.md` § 1–4:
- symetryczna lista kontaktów budowana przy zmianie komórki;
- odpychanie małych jednostek jednostronne (większa lub równa pcha mniejszą, odbicie od większej / stojącej, wagi
  kwadratowe);
- stosowanie przez 0x549A08 z przycięciem i testem pola;
- działa też w Idle i może zmienić pole, nie zmienia v;
- wynik zależy od kolejności jednostek (pętla od końca listy);
- **AoC odbudowuje kontakty od starej pozycji, EE od nowej** [W].

## 5. Ponowne planowanie

`kolizje_objazdy.md` § 5–6:
- ObstacleDetected przy +0x20C ≠ 0 albo +0x248 > T = round((0,75 + 0,5·u)·4000) ms, losowane co takt;
- 9002, ścieżka B: synchroniczne A* w oknie ±50 pól z omijaniem pól blokującego i odcinka, sklejane ze starą trasą;
- pierwsza porażka: +0x330 = 2 i stara trasa; druga: stop i Idle;
- ścieżka A (4 pola) tylko w pościgu.

Pomiar: licznik do 2,9 s, ObstacleDetected nie wystąpiło w 3 próbach [N].

## 6. Diagram maszyny stanów

`skrypty_stanow.md` § 4:
```
5000 Idle ─rozkaz→ 8000 ─MovePreparationComplete→ 2015 LookForEnemies ─(brak wroga)→ 10003 Advance
10003 ─ArrivedAtMoveWaypoint→ 9000 (zdjęcie punktu) ─NextWaypointRetrieved→ 2015 → 10003 …
9000 ─(brak punktów)→ 9006 TurnToUnitFacing ─UnitFacingNotRequired|CompletedUnitFacing→ 5001 ReacquireGoal
5001 ─GoalIsLocation→ 5000 Idle
10003 ─ObstacleDetected→ 9002 ─MovePreparationComplete→ 10003 | ─false→ 2025 → Idle
9000 ─ShouldMoveToNextAutoWaypoint→ 8021 ─UnitHasGoal→ 8000
```
- Semantyka: pierwsze pasujące przejście w kolejności include; jedno przejście na takt; leniwa ocena.
- Idle oceniany co takt (BO-8).

## 7. Parametry ruchu w szyku

`kolizje_objazdy.md` § 8:
- grupa: dla vmax, a, ωmax i α min(średnia, k·min), przy k ≥ 1,17 (pomiar);
- używane tylko przy grupa+0xB6 = 1 (ruch w szyku);
- pomiar: gwardia 0,7 przy przeciągnięciu z Aleksandrem, 0,6 przy kliknięciu;
- parametry bazowe pochodzą z rekordu bazy (+0x94…+0xA4);
- SetSpeed skaluje a, α i ωmax proporcjonalnie;
- 0x4D63F1 z etapu 25 to tablica obrażeń [Etap 26 – zastąpione].

## 8. BO-6 i BO-7

`kolizje_objazdy.md` § 10:
- **BO-6:** śmierć jednostki (stan 6002 w odczycie z etapu 24). Powtórki 513–514 i 524 kończą się śmiercią w rejonie
  (150–154, 126–131). Otwarte tylko pytanie o trasę przez teren 10.
- **BO-7:** wykładniczy dojazd zmierzony w EE i AoC; cel bliżej niż krok daje brak ruchu; przy vmax docisk nie działa
  (precyzja x87).

## 9. Eksperymenty EE i AoC

Zadania MCP:
- EE 512–524 i 526;
- AoC 525.

Tylko odczyt pamięci, próbki co 1–2 takty (34,09 ms gry), czas gry z EEPhysics+0xD0.

| Eksperyment | Zadania | Wynik |
|---|---|---|
| A płasko / B podjazd / C zjazd / D granice pól | EE 500 (etap 25), 509, 517, 518; AoC 505, 525 | z = GetMeshZ bit w bit; hamowanie tylko pod górę; ta sama reguła na granicach pól [P] |
| E kolizja ze stojącą | EE 518, AoC 525 | równe rozmiary: stop i koniec rozkazu 1,9 pola przed celem; większa → mniejsza: spychanie o 0,41 pola [P] |
| F dwie w ruchu | – | nie wykonano: wybór dwóch jednostek do osobnych rozkazów zawodny [N] |
| G wzdłuż muru | EE 509, 524 | ślizg, +0x248 do 1 s, bez objazdu [P] |
| H długotrwała blokada | EE 513, 524 | +0x248 do 2,9 s, ObstacleDetected nie wystąpiło; jednostki zginęły [P/N] |
| I szyk | EE 519 | klik: 0,6; przeciągnięcie: 0,7 (średnia grupy) [P] |
| J krótkie rozkazy | EE 516–518, AoC 525 | BO-7 potwierdzone [P] |
| K cel nieosiągalny / BO-6 | EE 512–514, 524; odczyt 483 | śmierć jednostki, nie błąd ruchu [P] |
| L EE ↔ AoC | 517 ↔ 525 | ta sama kinematyka, BO-7, precyzja i teren [P] |

Ograniczenia:
- wybór jednostki kliknięciem bywa błędny (12–13: zaznaczono 18c zamiast 18b);
- kolejka +0x7C wymaga dwóch dereferencji, więc punkty celu szacowano z przebiegu;
- rozkazy działają z opóźnieniem ok. 0,6 s gry (lockstep).

## 10. Porównanie starego i nowego modelu

Pełna tabela: `ruch_trasa_przeszkody.md` § 10. Model v3 (`Testy_MCP/e26/model_ruchu3.py`, poza repozytorium) = v2 +:
- teren (reguła stoku, siatka, pochylanie);
- precyzja x87 w porównaniach prędkości.

Współczynniki pochodzą z kodu i pamięci, bez dopasowania.

Kolizji, testu kroku i objazdów model **nie zawiera**: w porównywanych przebiegach nie było kontaktów ani ślizgów.
Mechanizmy są w dokumentacji, ale pełnej sekwencji w grze nie uchwycono.

## 11. Tabela błędów numerycznych

| Źródło | Wielkość | Skutek |
|---|---|---|
| znak drgań ω (f32, UMArcTan2) | błąd kursu ok. 1e-5 rad | po ok. 110 taktach rozjazd do 0,02 pola i kilku stopni kursu |
| decyzja R ≤ S przy celu | d − S ≈ 3e-4 | hamowanie o takt wcześniej, potem docisk BO-7 (+15 taktów w AoC 505) |
| v + a·dt wobec vmax | 7,5e-9 w precyzji x87 | przy 24 bitach docisk BO-7 włączałby się po każdym hamowaniu na stoku (EE 517: +4 / −35 taktów); model x87 bezbłędny |
| cel szacowany z przebiegu | 0,001–0,03 pola | błąd krótkich rozkazów w porównaniu |

## 12. Różnice EE / AoC

- Logika, stałe, skrypty ruchu i generator: identyczne [W].
- Przesunięcia pól jednostki (+0x264 → +0x268, +0x330 → +0x33C …) i typu (−0x2FC, flagi −0x304) [W].
- AoC: kontakty od starej pozycji [W]; poziom wody dla jednostek pływających (typ+0x11C); hak przy zmianie stanu;
  dodatkowe skrypty (klątwy, niewykrywalni) [W].
- Pomiar: ta sama kinematyka, BO-7, reguła stoku i precyzja [P].

## 13. Nierozpoznane zależności

- [N] UMArcTan2 i dokładne zapisy f32 kursu.
- [N] Pełny przebieg 9002 w grze i dokładna sekwencja po zatrzymaniu przez stojącą jednostkę.
- [N] Wartość k grupy (zmienna 0x31; pomiar: ≥ 1,17).
- [N] Geometria kolizji dużych jednostek (0x548A3C).
- [N] Trasa przez teren 10 z etapu 24.
- [N] Precyzja FPU po inicjalizacji D3D (pomiar wskazuje 53/64 bity).
- [N] Dwie jednostki w ruchu naprzeciw siebie (eksperyment F).

## 14. Konsekwencje dla OpenEE (bez zmian w kodzie w tym etapie)

1. **Teren:**
   - siatka wysokości wierzchołków jak w EEMap;
   - GetMeshZ z tą samą przekątną;
   - nachylenie z dwóch punktów ±0,65 wzdłuż osi jednostki i tablicowym acos;
   - reguła stoku na macierzy z poprzedniego taktu.
2. **Precyzja:** porównania prędkości w precyzji podwójnej (jak x87 53-bit), wartości przechowywane w f32. Inaczej
   pojawią się fałszywe dociski BO-7.
3. **Test kroku i kolizje:**
   - test punktu końcowego ze ślizgiem po osiach;
   - zatrzymanie na komórce ze środkiem innej jednostki;
   - jednostronne odpychanie według rozmiarów;
   - kolejność jednostek jak w oryginale.
4. **Maszyna stanów:** wczytywać oryginalne skrypty `.tai` (tekst) z ich semantyką: kolejność include, pierwsze
   pasujące przejście, leniwa ocena, jedno przejście na takt, Idle co takt.
5. **Generator:** globalny LCG 214013 / 2531011, losowanie progu ObstacleDetected w każdym takcie Advance.
6. **Szyk:** średnie parametry grupy przy +0xB6.
7. **Błędy BO-7, BO-8 i BO-9:** zachować.
8. **Przed implementacją:** UMArcTan2 z DLL i pomiar 9002 / F.

## 15. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/fizyka_terenu.md`, `docs/titan/kolizje_objazdy.md`, `docs/titan/skrypty_stanow.md` | nowe wpisy atlasu Titan |
| `docs/titan/ruch_jednostki.md`, `docs/titan/ruch_trasa_przeszkody.md` | adnotacje „[Etap 26 – …]”, model v3 (§ 10) |
| `docs/titan/BLEDY_ORYGINALU.md` | BO-6 wyjaśnione, BO-7 potwierdzone, nowe BO-8 i BO-9 |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 26, nowy aktualny raport |
| `RAPORT_ETAP_25.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 26”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian. Skrypty `.tai`, zrzuty pamięci i model obliczeniowy pozostają poza repozytorium.

## 16. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_26.md` |

## 17. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
