# OpenEE – rozpoznane formaty plików Empire Earth (etap 1)

Opis powstał na podstawie obserwacji danych i własnych implementacji OpenEE (Python: `narzedzia/eeformaty/`,
GDScript: `godot/silnik/importery/`). Dekompilowany kod gry nie był kopiowany. Tam, gdzie korzystano
z dokumentacji laboratorium (`EmpireEarth test/RAPORT_*.md`) lub publicznych opisów open-source, jest to zaznaczone.

Oznaczenia: **[D]** potwierdzone testem na danych, **[K]** wniosek pośredni (spójność, liczności),
**[H]** hipoteza robocza OpenEE, **[?]** nieustalone.

## 1. Archiwum SSA (`*.ssa`, sygnatura `rass`) [D]

```
0x00 char[4] 'rass'
0x04 u32     wersja = 1
0x08 u32     0
0x0C u32     granica tablicy wpisów – ostatni wpis ZACZYNA się przed tą wartością (może poza nią wystawać)
0x10         wpisy, dopóki pozycja < granica:
               u32 n (długość nazwy z NUL), char[n] nazwa (ANSI: ASCII, w wersji PL – cp1250), separator '\'
               u32 początek, u32 koniec (włącznie), u32 rozmiar (= koniec − początek + 1)
dane         wpisy ułożone ciągle, bez przerw, w kolejności tablicy
```
* Weryfikacja: `data.ssa` EE (3739 wpisów) i AoC (826) – tablica posortowana alfabetycznie, dane ciągłe
  od pierwszego offsetu do końca pliku, `koniec − początek + 1 = rozmiar` dla 100% wpisów.
* Dwie niezależne implementacje (Python, GDScript) – identyczne liczby wpisów i SHA-256 surowych wpisów (próbka 48/48).
* Uwaga: dokumentacja laboratorium (`tools/ssa_tool.py`) opisuje pole 0x0C jako „offset danych” – to nieścisłość:
  ostatni wpis tablicy przekracza tę wartość (wykryto przy pisaniu parsera OpenEE).

## 2. Kontener PK01 + PKWARE DCL [D]

```
0x00 'PK01'  0x04 u32 rozmiar po rozpakowaniu  0x08 u32 0  0x0C strumień DCL „implode”
```
Strumień DCL: bajt 0 – tryb literałów (0 surowe / 1 kodowane), bajt 1 – log2(słownik)−6 (4..6), dalej kody
Huffmana zapisane od najmłodszego bitu z zanegowanymi bitami kodu (publiczny algorytm „blast”, zlib/contrib).
Wpisy archiwów mogą być spakowane (PK01) lub surowe (np. część tekstur terenu w EE jest surowa: 231 SST).
Weryfikacja: rozpakowane SHA-256 Python = GDScript dla 76 tekstur terenu i modelu CEM; rozmiar = deklarowany zawsze.

## 3. Tekstury SST [D]

```
0x00 u8  0
0x01 u8  b1          (1 w 2052 plikach EE; także 3, 4, 7, 8 – znaczenie [?])
0x02 u32 N           liczba obrazów (1–16; >1 m.in. animacje wody water_ocean_*, tekstury 't' AoC)
0x06 u32 szerokość   0x0A u32 wysokość
0x0E     N × { u8 znacznik (=0), obraz TGA }
TGA: nagłówek 18 B, typ 2 (truecolor, bez RLE), 24 bpp BGR lub 32 bpp BGRA, bit 0x20 deskryptora = góra-dół
```
* EE: 2095/2095 plików SST z `data.ssa` dekodowanych bez błędu; 43 mają nadmiarowe bajty po ostatnim obrazie [?].
* AoC przechowuje większość tekstur jako czyste TGA (`*.tga`, 405 wpisów; próbka 140 – bez błędów).
* Luźne tekstury „HD” w `Empire Earth/Data/Textures` mają ten sam format (128×128, 32 bpp).
* ~~Znaczenie drugiego obrazu w plikach z N=2 – hipoteza: maska koloru gracza~~ – **OBALONE** (naprawa grafiki,
  FORMATY_NAPRAWA_GRAFIKI §2): obrazy pliku to kolejne tekstury modelu, materiał CEM wybiera obraz polem `tekstura` [D].

## 4. Modele CEM (`SSMF`) [D] dla wersji 2.0

Układ zgodny z publiczną dokumentacją projektu open-source `cem` (docs.rs/cem, autor coderbot16) –
zweryfikowany na danych, kod OpenEE napisany od nowa.
```
'SSMF'  u16 wersja główna (2)  u16 podwersja (0)
7 × u32: trójkąty, wierzchołki, punkty_tag, materiały, klatki, modele_potomne, poziomy_LOD
napis nazwa węzła (u32 długość z NUL + bajty)          3 × f32 środek
LOD    × { u32 k, k × 3 × u32 indeksy }
mater. × { napis nazwa, u32 tekstura (nr obrazu w pliku SST), LOD × (u32 offset, u32 liczba) trójkątów,
           u32 offset_wierzch., u32 liczba_wierzch., napis nazwa_tekstury }
tagi   × napis
klatki × { f32 promień, wierzch. × (3 f32 poz., 3 f32 normalna, 2 f32 UV), tagi × 3 f32, macierz 4×4 f32, AABB 6 f32 }
potomne × kolejny model SSMF (rekurencyjnie)
```
* **Indeksy trójkątów są względne wobec `offset_wierzch.` materiału** [D] (naprawa grafiki, FORMATY_NAPRAWA_GRAFIKI §1;
  etapy 1–5 traktowały je jako bezwzględne – stąd „rozsypane” budynki i żółte trójkąty).
* EE: 719/730 modeli 2.0 sparsowanych, kontrole spójności (indeksy, zakresy materiałów) bez błędów;
  11 modeli w wersji **1.3** – nieobsługiwane [?]; 3 pliki z nadmiarowymi bajtami [?]. AoC: 136/136.
* Układ osi: Z w górę (podstawa budynku z≈0) [D]; OpenEE mapuje na Godot jako (x, z, −y).
* Materiał o nazwie `player color` – powierzchnie koloru gracza [K]; tekstura pod nim szara → kolor = tekstura × kolor gracza [D/H].
* Animacje: 243 modele EE mają >1 klatkę (pełne klatki wierzchołków) [D]; tempo/odtwarzanie [?].
* Skala modelu względem pola mapy [?] (modele znormalizowane ~±0,6; skala zapewne w `dbgraphics.dat`).
* Orientacja ścian po zamianie osi – nieweryfikowana (test rysuje obustronnie).

## 5. Scenariusz SCN – lokalizacja kawałków [D]

Wg `RAPORT_SCN.md` (laboratorium) – zweryfikowano ponownie: po liście identyfikatorów kawałków
(`i32 N`, `N × u32`) występuje **7 napisów ANSI** (u32 długość + bajty) i `u32`, a następnie ramki
`u32 major, u32 minor, i32 tag, u32 rozmiar, dane`. (Raport SCN określał je jako „wstr” – w plikach są to napisy
ANSI.) Parser OpenEE nie interpretuje całego nagłówka – szuka jednoznacznej listy ID i sprawdza, że ramki kończą się
dokładnie na końcu pliku. Wynik: 6/6 scenariuszy kampanii AoC „Rzym” (wersja 0.250).

## 6. Teren – kawałek 4 (EEMap) [D]

Wg `RAPORT_EEMAP.md`, zweryfikowane na 6 scenariuszach kampanii (do 250×203 pól):
```
i32 A, i32 B, u32 K(=17)
T = 2AB+A+B pól: f32 f10, ceil(K/2)·4 B bloku, u32 n_obj (w badanych plikach 0)
i32 A, i32 B
T × (u8 teren, u8 flagi)
V = 2AB+3A+3B+1 punktów: (f32 wysokość, u8 klasa)
4 × u32 (m.in. ziarno, teren domyślny = 3)
```
* Wiersze rombu: pola – N=A+B wierszy, start kolumn [B−1,B], na krawędzi zatrzymanie o 1 wiersz;
  punkty – N+1 wierszy, start [B−1,B+1], zatrzymanie o 2 wiersze [D – liczności zgodne dla 39×39 kombinacji].
* **Narożniki pola (r,c) = punkty (r,c), (r,c+1), (r+1,c), (r+1,c+1)** [D]: wartość `f10` pola jest równa minimum
  wysokości tych narożników w 31 477 z 31 500 pól scenariusza „Żołnierze dla Rzymu” (23 wyjątki [?]).
* Wysokości autentycznych map: od −4,08 do +7,76; wartości ujemne = dno akwenów, poziom wody 0 [K].
* Teren pola = ID z `dbterrain.dat` (np. 3 Grass, 26 Underwater, 31 Beach, 50/51 Cliff); AoC dodaje ID 79–92 (Mars).
* Skala pionowa względem boku pola [?]; wybór wariantu tekstury `_1.._4` i mapowanie UV w obrębie pola [?] –
  test OpenEE używa hipotez [H] (wariant z parzystości (r,c), UV 0..1 na pole); przejścia/mieszanie tekstur
  między polami i geometria klifów – nieodtworzone.

## 7. Tabela terenów `db/dbterrain.dat` [D]

Rekord: `u32 n`, `char[n]` ścieżka bazowa tekstury (EE: `textures\BaseGrass_1`, AoC: z rozszerzeniem `.sst`),
`char[100]` nazwa, `u32` [?], `u32` ID terenu. Pliki tekstur: `<baza>_<1..4>.sst` (AoC: `.tga`).
Zgodność ID z danymi Riverlands: 3 Grass, 16 Patches, 17 Tufts, 26 Underwater, 31 Beach, 39 Sand-Medium, 56 Sparse, 64 Tall.
Pozostałe pliki `db/*.dat` (PK01) – rozpakowywane, treść poza dbterrain nieinterpretowana w etapie 1.

## 8. Pozostałe obserwacje
* `Data/Models/amb_rock.cem` (luźny, 24 B) zawiera 24 znaki szesnastkowe, nie model – [?] (obecny w GOG).
* `Language.dll` – zasoby tekstowe (w tej instalacji polskie).
* Kampanie `Data/Campaigns/*.ssa` – archiwa SSA ze scenariuszami (`scenarios\*.scn`), obrazami (`.jpg`), dźwiękami (`.mp3`).
* Muzyka: DirectMusic (`.sgt`, `.sty`, `.dls`); filmy: Bink (`.bik`); dźwięki: WAV/MP3 – nieanalizowane.
