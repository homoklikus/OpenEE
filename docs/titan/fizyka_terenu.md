# Fizyka terenu w Titan – wysokość, nachylenie, prędkość na stoku, test kroku (EE / AoC)

Etap 26 OpenEE. Dokument uzupełnia `ruch_jednostki.md` (takt, prędkość, obrót) o zależności od terenu:
- skąd jednostka bierze wysokość;
- jak liczone jest nachylenie;
- jak stok ogranicza prędkość;
- jak sprawdzany jest pojedynczy krok;
- w jakiej kolejności zapisywana jest pozycja.

Gdzie indziej:
- kolizje między jednostkami i objazdy – `kolizje_objazdy.md`;
- maszyna stanów – `skrypty_stanow.md`.

Kompilacje: EE `Empire Earth.exe` e352d7ae…, AoC `EE-AOC.exe` db8fc5ce…; `Low-Level Engine.dll` z tych samych instalacji.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pomiary: zadania MCP EE 512–524, AoC 525 oraz serie z etapu 25 (EE 500, AoC 505). Siatkę wysokości zrzucono z pamięci gry (EE 520–523), bez modyfikacji pamięci.

## 1. Geometria terenu i siatka wysokości

**Skąd bierze się wysokość.** Funkcja wysokości EE 0x4C0201 (AoC 0x4C0894) nie liczy jej sama. Woła import
`GETerrainMesh::GetMeshZ(float x, float y)` z `Low-Level Engine.dll` (EE DLL 0x1003B6AC, AoC 0x1002A185) na obiekcie
`EEMap + 0x1C` [W].
- Globalny wskaźnik EEMap: EE `[0x9183BC]`, AoC `[0x930DFC]` [W, P: odczyt EE 520].

**Siatka jest rombowa** [W, P]. Każdy wiersz y ma własny zakres x.

| Pole (mesh = EEMap+0x1C) | EE | AoC |
|---|---|---|
| wiersze wierzchołków / liczba | +0x17B578 / +0x17C6CC | +0x18F47C / +0x1905D8 |
| wiersze kafelków / liczba | +0x17B57C / +0x17C6D0 | +0x18F480 / +0x1905DC |
| min z / max z (f32) | +0x17B588 / +0x17B58C | – |

- Rekord wiersza ma 12 B: `{start_x, liczba, wskaźnik}`.
- Wierzchołek ma 12 B: z jako f32 w jednostkach świata, wskaźnik na normalną, bajt koloru.
- Kafelek ma 4 B; bajt +3 to flaga wody.
- Wierzchołek (ix, iy) leży w punkcie świata (ix, iy).
- Pomiar EE (mapa 280 × 280): 281 wierszy wierzchołków, 280 wierszy kafelków, z ∈ [−4,49; 4,90]. Wysokości są
  skwantowane co 1,837/9 = 0,204.

**GetMeshZ – interpolacja na dwóch trójkątach** z przekątną (ix, iy)–(ix+1, iy+1) [W]:
```
ix, iy = floor(x), floor(y);  fx, fy = x−ix, y−iy
a  = f32(1 − fx);  A0 = h00·a (kopia f32);  B1 = h11·fx (kopia f32);  D = f32(B1 + A0)
fy ≥ fx:  t = (fy−fx)/a;  z = t·(h01·a + B1) + (1−t)·D          // trójkąt h00, h01, h11
fy < fx:  t = fy/fx;      z = (1−t)·(h10·fx + A0) + t·D         // trójkąt h00, h10, h11
```
- Matematycznie to płaszczyzna każdego trójkąta. Do zgodności bitowej potrzebne są cztery zapisy pośrednie f32 i
  dzielenia przez fx oraz (1 − fx).
- 0x4C0201 woła GetMeshZ tylko wtedy, gdy kafelek (floor x, floor y) istnieje. W przeciwnym razie zwraca z wejścia,
  a w trybie 0 jest to 0 [W].
- **Pomiar** [P]:
  - EE 500: z jednostki zgadza się z modelem GetMeshZ we wszystkich 830 próbkach, z odchyłką 0,0;
  - AoC 505: 0,0 poza próbką startową (0,018, pochylony model w spoczynku, [N]);
  - AoC korzysta z tej samej mapy wysokości.

## 2. Nachylenie

EE 0x51216A (pochylenie wzdłuż osi przód) i 0x512257 (przechył); AoC 0x51C75A / 0x51C847 [W].
```
P  = pozycja z macierzy T;  A = P + T·(0, +0,65, 0);  B = P + T·(0, −0,65, 0)
pitch = UMArcCos((z(A) − z(B)) · (−0,76923078)) − 1,5707964        ≈ asin((zA − zB) / 1,3)   [rad]
```
1. **Gdzie liczona jest wysokość:** w dwóch punktach jednostki, ±0,65 pola wzdłuż jej osi przód. Ani środek pola,
   ani wierzchołki [W].
2. **Interpolacja:** tak, GetMeshZ w każdym punkcie [W].
3. **Kierunek:** wzdłuż kierunku jednostki, a nie maksymalny gradient [W]. Przechył liczy się tak samo z osią boczną.
4. **Znak:** dodatni pod górę, ujemny w dół. Stąd asymetria: reguła prędkości działa tylko pod górę (§ 3) [W, P].
5. **Normalizacja:** asin z różnicy wysokości na 1,3 pola. Przy |Δz| ≥ 1,3 wynik nasyca się do ±π/2 [W].
6. **UMArcCos** (DLL EE 0x1007DCC4) jest tablicowy [W]:
   - tablica 32769 wartości f32 pod 0x100E9134, indeks round(x·32768);
   - przy x ≥ 0,9995 szereg atan;
   - nachylenie jest skwantowane z krokiem 1/32768 w argumencie, a zjazd i podjazd są symetryczne co do bitu.
7. **Pochylony model:** gdy macierz jednostki jest pochylona (typ+0x5F3 / +0x5F4), punkty pomiaru skracają się w
   poziomie o cos(pitch), a dzielnik zostaje 1,3 [W].
   - Pomiar AoC 505 (Aleksander, model pochylany) [P]: |pitch| macierzy jednostki = |pitch| z modelu, np. 22,27° /
     22,27°, 24,09° / 24,10°.
   - Gwardia EE ma macierz bez pochylenia (|oś przód| = 1,000000) [P].
8. **Wpływ nachylenia:**
   - na prędkość (§ 3);
   - na orientację modelu, gdy typ+0x5F3 / +0x5F4 (tryb 0, 0x54DD89, 0x54E07F, 0x54E227, dosadzanie 0x5EE7D7);
   - kolizje z niego nie korzystają [W].
9. **Pozycja w obrębie pola:** wynik zależy od dokładnego punktu, a na granicy pól obowiązuje ten sam algorytm [W].
10. **EE ↔ AoC:** obliczenia identyczne, te same stałe [W].

## 3. Prędkość na stoku

Decyzja liniowa EE 0x548645 (AoC 0x554CB2) [W, P]:
```
jeśli typ+0x488 < 1 (gwardia i Aleksander: 0,5):
   s = clamp(pitch(macierz jednostki z poprzedniego taktu) · 1,9098593, 0, 1)    // 6/π: s = 1 przy 30°
   jeśli v > vmax · (1 − s · typ+0x488): tryb = hamuj
```
- Liczona na macierzy +0x130 sprzed ruchu w danym takcie, czyli przy starej pozycji i starym kursie [W]. Model
  zgodny z pomiarem tylko przy tej kolejności [P].
- Przy v = vmax wystarczy dowolne dodatnie nachylenie, żeby jednostka hamowała. Prędkość skacze wtedy piłokształtnie
  o 1–2 kroki a·dt (0,6 / 0,532 / 0,464) [P: EE 500, 509, 517; AoC 505, 525].
- Zjazd (s = 0) nigdy nie hamuje. Nie ma też przyspieszenia z górki [W, P].
- **Wynik:** po dodaniu tej reguły i siatki wysokości średni błąd modelu na całym przebiegu EE 500 spada z 0,119 do
  0,011 pola. Koniec ruchu wypada w tym samym takcie co w grze (`ruch_trasa_przeszkody.md` § 10) [P].
- **Obserwacja H z etapu 25** (pojedyncza gwardia po przeciągnięciu jechała 0,395–0,464):
  - parametry grupy dla jednej jednostki to jej własne (średnia = min = 0,6; k ≥ 1,17 – `kolizje_objazdy.md` § 8);
  - zakres 0,395–0,464 to 2–3 kroki a·dt poniżej 0,6, typowe dla stoku przy skręcie;
  - takie same wartości zmierzono przy zwykłych rozkazach na tym samym zboczu (EE 517–518);
  - przyczyna: stok z regułą 45°, a nie parametr grupy [W/P].

## 4. Test pojedynczego kroku

EE 0x54E275 (EEPMLand vt+0x54), AoC 0x55ABE8 (vt+0x58) [W]. Wywoływany w trybie 0 po obliczeniu nowego kursu, prędkości
i przesunięcia, przed wysokością.
```
ix, iy = floor(P_nowe);  komórka = EEMap.cell(ix, iy)       // 0x4039AC; W = map+0x1816FC, cells = map+0x1816D4
brak komórki: P −= krok; zwróć fałsz
pętla:
  komórka == bieżąca komórka jednostki (u+0x14): OK, koniec        // pozostanie na tym samym polu zawsze dozwolone
  ok = teren dozwolony (typ+0x5D6[komórka+4]; AoC 0x634AD8) i nie na liniach brzegu rombu
  ok &= dla każdego obiektu na liście komórki: obiekt→vt48(u) albo (typ obiektu→vt54() i obiekt[+0x30][+0x340] == 0)
  ok &= przy ruchu po przekątnej: jedna z dwóch komórek bocznych przejezdna (0x62C7C8)     // zakaz ścinania rogu
  ok: koniec
  zablokowane:
     środek ostatniego obiektu leży w tej komórce: zapisz blokującego (0x5EFF37 → u+0x20C), u+0x330 = 2,
                                                   P −= krok; zwróć fałsz
     pierwszy raz:  cofnij składową x  → ślizg wzdłuż y
     drugi raz:     przywróć x, cofnij y → ślizg wzdłuż x
     trzeci raz:    cofnij x → zwróć fałsz
jeśli ok: przytnij do brzegu mapy (0x549FF3, płaszczyzny brzegowe, ±0,001)
jeśli był ślizg: u+0x248 += ms taktu
```
- **Sprawdzany jest tylko punkt końcowy** (środek jednostki), nie droga i nie obrys. Rozmiar jednostki i wysokość nie
  mają tu znaczenia [W].
- **Nieudany krok nie zmienia v ani kursu.** Zmienia tylko pozycję (cofnięcie albo ślizg), +0x330 i licznik +0x248
  [W].
- **Wartość zwracana jest w trybie 0 ignorowana:** obie gałęzie budują tę samą orientację [W].
- **Różnice względem A*** (`astar_pola.md` § 5):
  - teren i linie rombu sprawdzane tak samo;
  - reguła obiektów jest luźniejsza: przepuszcza obiekty, których typ→vt54() jest prawdą i [+0x30][+0x340] == 0;
  - pełny predykat przejezdności 0x62C7C8 (AoC 0x641658) wołany jest tylko przy przekątnych;
  - A* liczy stojące jednostki tylko jako koszt (+50 / +150), a test kroku zatrzymuje jednostkę na komórce, w której
    leży środek innej jednostki.

  Planowanie i wykonanie korzystają więc z innych reguł [W].
- **Trasa przez pole niedostępne:** krok do takiego pola ślizga się albo cofa. Licznik +0x248 rośnie, a po 3–5 s
  ciągłego ślizgu zachodzi ObstacleDetected i objazd (`kolizje_objazdy.md`) [W].
- **Pomiar** [P]:
  - +0x248 rosło w EE 509, 513 i 524 przy murach bramy (178,117) i przy brzegu (151–154, 126–131) do 2,9 s;
  - zerowało się przy zdjęciu punktu trasy;
  - zatrzymanie na komórce ze środkiem stojącej jednostki – EE 518 (`kolizje_objazdy.md` § 4).

## 5. Zapis pozycji i kolejność w takcie

**Funkcje** [W]:

| Zapis | EE | AoC |
|---|---|---|
| macierz | 0x5F043B | 0x5FE7A8 |
| x, y, z | 0x5F033A | 0x5FE76E |
| tylko x, y | 0x5F0252 | 0x5FE73B |

**Kolejność w EE:**
1. nowa komórka;
2. 0x616F9D: zmiana komórki, listy komórek, mgła, kopia +0x248 → +0x24C i zerowanie +0x248;
3. zapis pozycji;
4. przy zmianie komórki: odbudowa listy kontaktów 0x5E960D / 0x5E8F0E **od nowej pozycji**.

**AoC** (0x5FE611) liczy komórkę i kontakty **przed** zapisem pozycji, czyli od starej pozycji. To różnica
kompilacji, ważna dla zgodności kolizji EE ↔ AoC [W].

**Kolejność w trybie 0** [W, P]:
1. maszyna stanów;
2. obrót;
3. decyzja prędkości (z nachyleniem z poprzedniej macierzy);
4. v′;
5. przesunięcie po nowym kursie;
6. test kroku;
7. z = GetMeshZ(P);
8. pochylenie modelu (typ+0x5F3 / +0x5F4);
9. test osiągnięcia punktu (d sprzed ruchu);
10. zapis macierzy i komórki;
11. kolizje i odpychanie (`kolizje_objazdy.md`), które mogą jeszcze przesunąć jednostkę: 0x5F0252 i dosadzenie
    0x5EE7D7.

**Wysokość logiczna = wysokość rysowana:** z w macierzy +0x15C to wynik GetMeshZ, a orientacja modelu to ta sama
macierz. Osobnej wysokości kontaktu nie ma. Tylko AoC dla jednostek pływających podstawia stały poziom typ+0x11C
(0x556681) [W].

## 6. Precyzja liczb i determinizm

- **x87 w pełnej precyzji** [P/W]:
  - CRT ustawia `_controlfp(_PC_53)` (0x683914);
  - pomiar potwierdza obliczenia w precyzji podwójnej lub rozszerzonej, a nie f32;
  - test: po hamowaniu na stoku v = f32(0,6 − a·dt) = 0,5318182, a v + a·dt w precyzji x87 jest o 7,5e-9 większe od
    0,6f, więc gałąź „obetnij do vmax” wygrywa i docisk BO-7 jest pomijany;
  - model w precyzji 53/64 bitów odtwarza EE 517 bezbłędnie (0 rozbieżnych taktów), a w precyzji 24 bitów nie
    (`ruch_trasa_przeszkody.md` § 10);
  - EE i AoC zachowują się tak samo [P: AoC 525].
- **Zapisy f32:**
  - pozycja, v, ω i macierz są przechowywane w f32;
  - wartości pośrednie zostają w rejestrach x87;
  - drgania ω przy wyrównanym kursie (±α·dt) zależą od znaku błędu kursu rzędu 1e-5 rad, czyli od dokładnych zapisów
    f32 i UMArcTan2 z DLL [P: pierwszy rozjazd modelu w EE 500 w takcie 110].
- **Funkcje DLL:** UMArcCos, UMArcTan2, Normalize i IntersectsIn2D pochodzą z `Low-Level Engine.dll`, a nie z libm.
  Wiernie odtworzyć trzeba tablicę acos [W] i UMArcTan2 [N].
  **[Etap 27 – zastąpione]** UMArcTan2 zrekonstruowane, tablice cos/acos opisane (`precyzja_numeryczna.md` § 2) [P].
- **FPS renderowania nie ma wpływu:** dt to stała EEPhysics (1,5/44 s gry), a wysokość i nachylenie liczone są w takcie
  symulacji [W, P].

## 7. Niewiadome

- [N] UMArcTan2 (DLL) i dokładny przebieg zapisów f32 kursu, potrzebne do bitowej zgodności drgań ω.
- [N] typ→vt4 w dosadzaniu 0x5EE7D7 (korekta z przy starcie pochylonego modelu AoC: 0,018).
- [N] Pełne warunki przepuszczania obiektów w teście kroku (obiekt→vt48, typ→vt54, [+0x30][+0x340]: bramy, mury,
  sojusznicy).
- [N] Czy D3D zmienia precyzję FPU w trakcie gry. Pomiar wskazuje, że nie.

## 8. Aktualizacja etapu 27

- **Kwantowanie kursu:** kurs to UMArcTan2(−m01, m11) z macierzy zapisanej przez `SetOrientationYPR` z tablicowych
  cos/sin. Wszystkie 1251 wartości macierzy EE 500 to wartości tablicowe [P] (`precyzja_numeryczna.md` § 2.4).
- **Precyzja:** pełna tabela punktów zapisu f32 i porównań z rejestru – `precyzja_numeryczna.md` § 5. Wniosek z § 6
  („x87 w pełnej precyzji”) jest doprecyzowany: PC_53, czyli równoważnie f64 [P].
- **Obrót AoC** różni się od EE (0x554F56 / 0x554738), co wyjaśnia +15 taktów AoC 505 (`precyzja_numeryczna.md` § 6).
- **Teren:** reguły GetMeshZ i nachylenia bez zmian. Syntetyczne przypadki podjazdu i zjazdu (S6, S7) w
  `dane/testy_ruchu/ruch_syntetyczne_etap27.json`.
