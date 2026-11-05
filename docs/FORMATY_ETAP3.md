# OpenEE – ustalenia etapu 3: renderowanie terenu, transformacje obiektów, scenariusze EE 1.x

Oznaczenia: **[K]** potwierdzone kodem (analiza `Low-Level Engine.dll` / `EE-AOC.exe` w Ghidrze – kopie laboratorium,
tylko odczyt), **[D]** potwierdzone danymi, **[P]** kod + dane, **[H]** hipoteza. Reguły opisane własnymi słowami;
OpenEE nie zawiera kodu oryginalnej gry. Uzupełnia `FORMATY.md` i `FORMATY_ETAP2.md` (§3 i rotacja – zastąpione).

## 1. Zestawy tekstur terenu (GETextureSet)
* Gra rejestruje po jednym zestawie na każde ID `dbterrain` w kolejności ID (brakujące ID → pusty zestaw), więc
  **bajt terenu pola w SCN = ID dbterrain** [K].
* Zestaw = siatka W×H tekstur (`Tyles on X axis` × `Tiles on Y axis`) + liczba pól na teksturę S (pole rekordu przed
  „Terrain family” – w praktyce 1) [K, przesunięcia rekordu w pamięci – K/H].
* Wypełnianie: plik `_k` (k = 1..W·H, kolejność w rekordzie) trafia do komórki (W−1−x, y), gdzie k−1 = W·y + x [K].
* Wybór tekstury dla pola (wiersz r, kolumna c): komórka ((c/S) mod W, (r/S) mod H) [K] ⇒ dla S=1:
  **plik N = 1 + W·(r mod H) + (W−1−(c mod W))** [P].
* Każde pole pokrywa **całą** teksturę: UV narożników (u,v) – (r,c)=(0,1), (r,c+1)=(1,1), (r+1,c+1)=(1,0),
  (r+1,c)=(0,0) w konwencji silnika [K]. Ciągłość krawędzi (narzędzie `test_ciaglosci_tekstur.py`): przy tej regule
  najmniejsze szwy daje obraz odbity poziomo względem kolumn (Rock2 4×4: 31,7 wobec 48,5 w regule etapu 2;
  Smooth Stone: 15,8 wobec 16,8) [D] ⇒ OpenEE: UV Godota = (1−u, v).

## 2. Mieszanie tekstur między polami [K]
* Pole (r,c) jest czworokątem na punktach (r,c), (r,c+1), (r+1,c+1), (r+1,c); dwa trójkąty z przekątną
  (r,c)–(r+1,c+1).
* Każdy narożnik ma rodzaj terenu **pola przesuniętego o (−1,−1) względem punktu**: punkt (j,i) ← pole (j−1,i−1).
  Narożnik (r+1,c+1) dostaje teren samego pola, pozostałe – sąsiadów (r,c−1), (r−1,c−1), (r−1,c).
  Sąsiad spoza mapy nie wnosi tekstury.
* Dla każdej różnej tekstury narożników silnik dodaje kopię wielokątów pola:
  - tekstura bazowa: alfa wierzchołków = 1 we wszystkich narożnikach,
  - pozostałe: alfa = 1 w narożnikach z tą teksturą, 0 w pozostałych; alfa interpolowana liniowo (Gouraud).
  Efekt: w każdym narożniku widać dokładnie teksturę jego rodzaju terenu, przejścia mają szerokość jednego pola.
* Baza = tekstura o najmniejszym adresie obiektu w pamięci. OpenEE: najmniejszy klucz (ID terenu, numer pliku) [H].
  Wybór bazy nie zmienia kolorów w narożnikach – tylko wnętrze przejść.
* Wariant (plik) każdej warstwy liczony jest ze współrzędnych **bieżącego** pola.
* Kolor wierzchołków: bajt „klasy punktu” to indeks 256-elementowej tablicy kolorów terenu, ale gra przekazuje pustą
  tablicę, więc wszystkie wpisy są białe [K] – klasa punktu nie wpływa na wygląd (domyka kwestię z etapu 2).
* Normalne: liczone w punktach (ComputeVertexNormal) – wygładzone [K]; OpenEE: różnice centralne wysokości.

## 3. Woda [K]
* Pola z niezerowym `flagi & 0x7F` dostają drugą, półprzezroczystą warstwę (osobna siatka na poziomie wody).
* Alfa narożnika = 0,5; = 0, gdy ustawiony bit lądu narożnika: 0x08 → (r+1,c+1), 0x04 → (r+1,c), 0x02 → (r,c),
  0x10 → (r,c+1). (Riverlands zapisuje flagi = 1 + 2·maska lądu – zgodne.)
* Materiał wody wybierany z tabeli 33×33 wg (c mod 33, r mod 33) i animowany (UpdateWaterAnimation) – OpenEE:
  statyczna klatka 1 [ograniczenie]. Poziom wody: parametr globalny (SetGlobalWaterState); OpenEE 0 [H].

## 4. Klify [K]
* Poza mapami kosmicznymi silnik **nie tworzy dodatkowej geometrii klifów** – klif to zwykłe pole z teksturą
  klifu (`dbcliffterrain`: pary ID „\” i „/”, np. 50/51, 74/75, 77/78) i wysokości z punktów. AddCliffPolys /
  NumSpaceCliffTextures dotyczą krawędzi pól kosmicznych (GetIsSpaceTile).
* Krawędzie mapy: silnik dorysowuje „ściany” brzegowe (Generate*EdgePolygons) – OpenEE: brak [ograniczenie].

## 5. Transformacja obiektów scenariusza [D]
* Orientację obiektu zapisuje macierz GETransformation rekordu (16 f32, wierszami; t[3], t[7], t[11] = X, Y, Z).
  Oś najdłuższa modelu muru po obrocie macierzą R (wiersze (t0,t1),(t4,t5)) pokrywa się z kierunkiem do sąsiedniego
  segmentu: mury ukośne 42/54 < 15° (mediana 0°), przy R^T mediana 90° (`test_orientacji_modeli.py`).
* Pole `angle` (+0x220, radiany 0..2π) **nie** jest obrotem modelu (mediana różnicy z kątem macierzy ≈ 90°, brak
  korelacji) – hipoteza etapu 2 „obrót = −angle” odrzucona. Znaczenie `angle`: [?].
* Macierze budynków i murów mają obroty skwantowane (0°, 45°, 90°, 180°, 270°).
* t[11] = zapisana wysokość; różnica względem interpolacji terenu: mediana 0, p95 1,6–8,5 (obiekty na murach/w
  powietrzu) [D]. OpenEE: wysokość z terenu (gra przelicza ją sama – [H]).
* Skala: `c174` rekordu = „Graphic size” z dbobjects [D – laboratorium].
* Układ osi OpenEE: świat EE (X = kolumna, Y = wiersz, Z = góra) → Godot (X, Z, Y); dla siatek modeli
  (x, z, −y) z importera ⇒ baza obiektu = C·R·M⁻¹ (wyznacznik −1). Spójność terenu i obiektów jest potwierdzona,
  bezwzględna skrętność obrazu (czy całość nie jest lustrzana względem gry) – [H: układ lewoskrętny D3D].

## 6. Scenariusze Empire Earth 1.x (wersja 231)
Wersja = pole minor kawałka (231 = 0xE7 dla EE, 250 = 0xFA dla AoC). Czytnik obiektów AoC (EEComplexUnit::Load)
pomija pola zależnie od wersji [K]; OpenEE opisuje to warunkami w gramatyce (`dane/gramatyka_jednostki.json`, `"od"`):

| Pole | Czytane od wersji | Uwagi |
|---|---|---|
| `L_pairs[].b` | 248 | element listy par ma w EE tylko `a` |
| `c320` | 226 | |
| `c328` | 232 | |
| `c355`, `c358` | 235 | lub zapis gry (param ≠ 0) |
| `c35c` | 243 | |
| `c250` | 244 | lub zapis gry |
| `c32c` | 245 | lub zapis gry |

Nagłówek jednostki (typ, valid, complex) – od wersji 223 [K]; ogon gracza też zależy od wersji, ale czytnik pomija
go wyszukiwaniem kotwicy następnego gracza [D]. Wynik: 34/34 scenariusze EE (109 650 obiektów) i 18/18 AoC
(101 521) – zgodnie w Pythonie i GDScript.

**Lista celów jednostki** (polimorficzna, FUN_0060588b) – nieodtworzona: w 3 scenariuszach EE (Hellada, Wojownicy
z morza, Band of Brothers) jedna jednostka gracza 3 ma niepustą listę; czytnik zwraca tego gracza częściowo
(„niepelny”), pozostałych graczy w całości.

## 7. Tabele EE
Gra AoC wczytuje scenariusze EE z własnymi tabelami db (rejestracja zestawów tekstur i typów wg tabel AoC) –
OpenEE używa tabel AoC także dla scenariuszy EE [K/H]. Tabele `dbobjects`/`dbcivilization` z `data.ssa` EE
(starszy układ rekordu) nadal nieobsługiwane – nie są potrzebne do wyświetlania scenariuszy.
