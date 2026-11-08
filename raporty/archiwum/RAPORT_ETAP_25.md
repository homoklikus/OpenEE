# OpenEE – raport etapu 25: wykonywanie trasy, dynamika ruchu i stany jednostki w Titan

Dwunasty etap rekonstrukcji kodu silnika Titan. Odtwarza ruch zwykłej jednostki lądowej od otrzymania trasy do
zatrzymania w celu i przejścia do kolejnego rozkazu, razem z weryfikacją niezależnym modelem.

Szczegóły:
- **`docs/titan/ruch_jednostki.md`** – stany, takt, pola, prędkość, obrót, zaliczanie punktów, zatrzymanie;
- **`docs/titan/ruch_trasa_przeszkody.md`** – kolejka +0x7C, nowa trasa, przeszkody, Shift, punkty +0x32, eksperymenty,
  model.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `99d6527`, testy Godota 324/324.

## 1. Najważniejsze ustalenia

1. **Trzy warstwy** [W, P].
   - Maszyna stanów (`EEUnitAction` +0x1E8, najwyżej jedno przejście na takt) wybiera, co jednostka robi.
   - Akcje wejścia ustawiają tryb ruchu +0x264.
   - Ruch liczy model fizyki `EEPMLand` według trybu: 0 jazda, 3 spoczynek, 4 stop, 5 obrót w miejscu.
   - Stany „Accelerate” 10002 i „PrepareToStop” 10001 dla jednostki lądowej nic nie robią. Przyspieszanie i hamowanie
     są wewnątrz trybu 0.
2. **Diagram stanów nie jest zapisany w EXE.** Przejścia pochodzą ze skryptów `Unit AI Scripts\*.tai` [W].
   - Zmierzona kolejność (EE, AoC) [P]: 2015 → 10003 Advance → przy każdym punkcie 9000 GetNextMoveWaypoint (zdjęcie
     punktu) → 2015 → 10003 … → 9000 → 9006 TurnToUnitFacing → 5001 → 5000 Idle.
   - Numery stanów odczytano z obiektów stanu.
3. **Prędkość** [P]. Wzory z kodu, parametry z obiektu +0x34; gwardia: a = 2,0, vmax = 0,6.
   - Przyspieszanie i hamowanie: ±a·dt = ±0,0682 na takt.
   - Krok: v·dt po nowym kursie, bez wzmocnienia po przekątnej.
   - Hamowanie, gdy pozostała droga ≤ S = ½·k(k+1)·a·dt² (k = v/(a·dt)), czyli dokładna dyskretna droga hamowania.
     Stop w celu z dokładnością < 0,05.
   - Przy błędzie kursu > 45° jednostka hamuje (1–2 kroki na ostry zakręt).
   - Na stoku obowiązuje próg vmax·(1 − 0,5·s), co daje piłokształtną prędkość 0,6 / 0,532 / 0,464.
   - Prędkość z typu nie jest używana bezpośrednio. Fizyka czyta ją przez getter, który w szyku zwraca prędkość grupy
     (+0x70).
4. **Obrót** [P]. Profil trapezowy: ω ± α·dt.
   - Hamowanie obrotu, gdy dyskretna droga hamowania kąta ≥ |błąd|. Krok przycinany do kąta docelowego.
   - α = 12,217 / 6,981 rad/s², ωmax = 13,96 / 6,98 rad/s (gwardia / Aleksander).
   - Obrót i jazda są jednoczesne.
   - Obrót w miejscu tylko na końcu (9006, tolerancja ±1°).
5. **Zaliczanie punktów** [P].
   - Punkt pośredni: d ≤ rozmiar kolizji typu (0,5 / 0,55) **i** jednostka na polu punktu.
   - Punkt ostatni: d < 0,05.
   - Punkt znika takt później, a cykl przy punkcie trwa 3 takty.
   - Titan jedzie punkt po punkcie, bez wybierania punktu dalej.
6. **Krok jest stały** (dt = 1,5/44 s gry), bez podkroków [W].
   - Kolejność w takcie: maszyna stanów, fizyka trybu, kolizje i odpychanie, zapis transformacji, pola i wysokości.
7. **EE = AoC** w logice i stałych [W]. Różnią się przesunięcia pól i sloty. Pomiar AoC (Aleksander) zgodny z modelem
   z parametrami EE [P].

## 2. Wzory (EE, f32; dt = 0,0340909 s, tps = 1/dt)

```
diff  = norm(atan2(−dx, dy) − kurs) ∈ (−π, π]
n     = |ω|·(1/α)·tps;  S_rot = ½·n(n+1)·α·dt²
ω'    = S_rot < |diff| ? clamp(ω + sgn(diff)·α·dt, ±ωmax) : ω → 0 o α·dt
kurs' = kurs + clamp(ω'·dt, do diff)
k     = v·(1/a)·tps;  S = ½·k(k+1)·a·dt² (0, gdy < 1e-4)
tryb  = |diff| ≤ π/4 ? przyspiesz
        : (v·dt ≥ X ? hamuj : ((v + a·dt)·dt ≥ X ? trzymaj : przyspiesz)),  X = |½·min(d, 0,5)·ω'·dt|
R     = (+0x8C > 1) ? pozostała długość : d;   R ≤ S → hamuj
stok  = typ+0x488 < 1 i v > vmax·(1 − clamp(nachylenie·6/π, 0, 1)·typ+0x488) → hamuj
v'    = przyspiesz: min(v + a·dt, vmax), a bez obcięcia i przy +0x8C == 1: min(·, d)  (BO-7)
        hamuj: v − a·dt (0, gdy < 0,005);  trzymaj: v
P'    = P + (−sin kurs', cos kurs')·v'·dt
```

## 3. Diagram stanów (zmierzony; odgałęzienia [H])

```
5000 Idle ─rozkaz→ 8000 PrepareToMove ─8000 MovePreparationComplete→ 2015 → 10003 Advance
10003 ─9004 Arrived (+0x33F)→ 9000 GetNextMoveWaypoint [zdejmuje 1 punkt]
9000 ─9005 NextWaypointRetrieved→ 2015 → 10003
9000 ─9006 NoMoreWaypoints→ 9006 TurnToUnitFacing [tryb 5: hamowanie, obrót] ─9015/9014→ 5001 → 5000
[H] 10003 ─9000 ObstacleDetected→ 9002 RepathAroundObstacle;  10003 ─9016→ 8021 GetNextAutoWaypoint → 8000
```

## 4. Pola pamięci

| Pole | Znaczenie | Pewność |
|---|---|---|
| +0x13C / +0x14C / +0x15C, macierz +0x130 | pozycja x, y, z; kurs = atan2(−m134, m144) | [P] |
| +0x17C | ω [rad/s] | [P] |
| +0x214 | kurs docelowy (−10000 = brak) | [P] |
| +0x21C | max(v, par+0xBC), tylko w trybie 0 | [W/P] |
| +0x238 | bieżąca prędkość [pola/s] | [P] |
| +0x244 | promień kolizji (typ+0x474) | [P] |
| +0x248 | f32, ms ciągłego odpychania | [P] |
| +0x264 (AoC +0x268) | tryb ruchu | [P] |
| +0x33F (AoC +0x34B) | punkt osiągnięty | [W] |
| +0x7C / +0x88 / +0x8C | kolejka trasy, początek, liczba | [P] |
| +0x1E8 (→ +0x24) | stan | [P] |
| +0x34 → +0xA8 / +0xAC / +0xB0 / +0xB4 / +0xC4 / +0xC8 | a, vmax, α, ωmax, 1/a, 1/α | [P] |
| typ +0x474 / +0x488 (AoC +0x178 / +0x18C) | rozmiar kolizji / czułość na stok | [P] / [W] |

## 5. Pomiary EE / AoC

Zadania MCP:
- EE 490–503 i 507–510;
- AoC 504–506.

Tylko odczyt pamięci, próbki co 1–2 takty (1 takt = 34,09 ms gry, najmniejszy możliwy interwał).

Wyniki eksperymentów A–J – `ruch_trasa_przeszkody.md` § 8. W skrócie:
- A, B, D, E, J zgodne z wzorami;
- C – trapez ω i hamowanie > 45°;
- F – odpychanie przy murach do 1 s, bez objazdu;
- G – płynne przejście Shift z hamowaniem do 0,255 przy zakręcie ok. 100°;
- H – po rozkazie z przeciągnięciem prędkość ok. 0,40–0,46, bo parametry pochodzą z grupy [W];
- I – stop w najbliższym dostępnym polu, bez powtórzenia BO-6.

## 6. Model obliczeniowy

`Testy_MCP/e25/model_ruchu2.py`, poza repozytorium.
- Reguły z kodu, współczynniki z pamięci.
- Pominięte: stok, kolizje, test przejezdności.

| Scenariusz | Pozycja max / śr | v max / śr | Kąt max / śr | Koniec ruchu: model / gra |
|---|---|---|---|---|
| EE 500 gwardia – cały przebieg | 0,158 / 0,119 | 0,409 / 0,009 | 31,7° / 1,19° | 1099 / 1106 taktów, stop ±0,012 |
| AoC 505 Aleksander – cały przebieg | 0,242 / 0,176 | 0,477 / 0,015 | 26,0° / 1,00° | 800 / 808, stop ±0,005 |
| EE 500 – odcinkowo (21 odcinków) | 0,061 / 0,004 | 0,136 / 0,005 | 4,9° / 0,10° | – |
| AoC 505 – odcinkowo (20 odcinków) | 0,137 / 0,006 | 0,136 / 0,009 | 2,8° / 0,11° | – |

## 7. Rozbieżności

- **Cały przebieg.** Odchyłka średnia 0,12–0,18 pola to opóźnienie o 6–9 taktów. Model nie odtwarza stoku: spadki
  prędkości w grze to wielokrotności a·dt zgodne z regułą stoku. Funkcja nachylenia [N].
- **Shift A → B.** Ostatni punkt A zaliczony przy pełnej prędkości, bez hamowania przewidzianego przez R = d ≤ S [N].
- **H.** Wartości grupa+0x7C / +0x88 i przebieg hamowania w szyku – [N].

## 8. Błędy oryginału

| Wpis | Treść | Pewność |
|---|---|---|
| BO-7 (obserwacja) | docisk ostatniego kroku porównuje v (pola/s) z d (pola) i jest pomijany przy obcięciu do vmax; skutek tylko przy krótkich rozkazach / ponownym przyspieszaniu przed celem | kod [W] |
| BO-6 (uzupełnienie) | powtórka z innego startu bez zatrzymania przy brzegu; możliwy mechanizm: odpychanie / test kroku → 9000 po 3–5 s → objazd / limit prób → Idle | [H] |

BO-1–BO-5 bez zmian.

Usuwanie punktów +0x32 ok. 15 pól wcześniej **nie jest błędem**. To zamierzone przełączenie celu zdarzeniem 9016, gdy
zostało ≤ N punktów trasy (N z rozmiaru mapy, 14 dla 280 × 280) [W].

## 9. Zatrzymanie ok. 1 pola przed celem

Nie ma jednej przyczyny (`ruch_trasa_przeszkody.md` § 7):
- cel niedostępny, więc trasa kończy się w środku najbliższego dostępnego pola [P];
- przesunięcie celu szykiem [P, etapy 17–20];
- odepchnięcie od innych jednostek po dojściu [W];
- porzucenie celu po limicie prób [H].

Przy dostępnym celu jednostka staje w punkcie kliknięcia (< 0,05) [P].

## 10. Niewiadome

- [N] Skrypty `.tai` (pełny diagram, stan 5001, odgałęzienia przeszkód).
- [N] Funkcja nachylenia 0x51216A, test kroku 0x54E275, wysokość 0x4C0201, rozdzielanie kolizji 0x5498C4.
- [N] Logika RepathAroundObstacle, ustawianie +0x20C / +0x33E.
- [N] Pochodzenie parametrów +0xA8…+0xCC z bazy i ulepszeń.
- [N] Parametry szyku grupy w ruchu (H) i brak hamowania przed punktem A przy Shift.

## 11. Zalecenia dla OpenEE (bez zmian w kodzie w tym etapie)

1. **Takt.** Stały krok dt, kolejność: maszyna stanów (jedno przejście) → fizyka trybu → odpychanie → aktualizacja
   pola, wysokości i kolizji. Pozycja logiczna = pozycja rysowana.
2. **Stany.** Odtworzyć cykl 10003 / 9000 / 2015 (3 takty na punkt) i koniec 9000 → 9006 → 5000 jako dane, bo
   przejścia w oryginale pochodzą ze skryptów.
3. **Kinematyka.** Wzory z § 2 dosłownie, w f32:
   - dyskretne drogi hamowania;
   - reguła 45°;
   - docisk z BO-7;
   - reguła stoku z nachyleniem terenu.
4. **Parametry** przez gettery, z grupą przy +0xB6. Nie używać prędkości z typu bezpośrednio.
5. **Zaliczanie punktów:** rozmiar kolizji + to samo pole; ostatni punkt d < 0,05; bez wybierania punktu dalej.
6. **Przeszkody:** licznik ms odpychania (+0x248), próg los[0,75; 1,25]·4 s → objazd; limit prób celu → Idle.
7. **Punkty +0x32:** przełączenie celu przy ≤ N punktach trasy.
8. **Przed implementacją** zbadać funkcję nachylenia i test kroku 0x54E275 oraz zmierzyć krótkie rozkazy (BO-7).

## 12. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/ruch_jednostki.md`, `docs/titan/ruch_trasa_przeszkody.md` | nowe wpisy atlasu Titan |
| `docs/titan/BLEDY_ORYGINALU.md` | BO-7, uzupełnienie BO-6 |
| `docs/titan/kolejka_rozkazow.md`, `docs/titan/nawigacja_wejscie.md` | adnotacje „[Etap 25 – …]” |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 25, nowy aktualny raport |
| `RAPORT_ETAP_24.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 25”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 13. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_25.md` |

## 14. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
