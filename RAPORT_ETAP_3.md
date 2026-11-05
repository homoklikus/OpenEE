# OpenEE – raport etapu 3: wierne odtwarzanie terenu, modeli i scenariuszy

Szczegóły formatów: `docs/FORMATY_ETAP3.md`. Zrzuty: `wyniki/test_graficzny_etap3/` (PNG + raport JSON każdej sceny).
Kopie zmienianych plików: `kopie/etap2_przed_etapem3/`.

## 1. Zmiany w importerach i rendererze
| Element | Zmiana |
|---|---|
| `godot/silnik/render/teren_ee.gd` (nowy, `TerenEE`) | teren wg reguł silnika: warstwy tekstur na pole z alfą narożników, warianty tekstur z kodu, UV, normalne w punktach, woda z bitami lądu, jedna siatka + Texture2DArray + shader (≤ 4 warstwy na pole) |
| `godot/sceny/test_scenariusz.gd` | TerenEE zamiast starego terenu (`--teren=etap2` – stary, do porównań); kampanie EE; obrót obiektów z macierzy rekordu; skala `c174`; grupowanie MultiMesh (`--bez-grupowania`); `--okno=pelne`; `--pomiar=N` |
| `godot/silnik/importery/scenariusz.gd` | wersja kawałka, warunki wersji pól rekordu jednostki, odczyt częściowy gracza z nieczytelną listą celów |
| `narzedzia/eeformaty/gracze.py`, `dane/gramatyka_jednostki.json` | to samo w Pythonie; warunki `"od"` w gramatyce wspólnej dla obu czytników |
| `narzedzia/` (nowe) | `test_scenariuszy_ee.py`, `test_ciaglosci_tekstur.py`, `test_orientacji_modeli.py` |
| testy | 13 nowych testów (razem 66) |
Launcher, importery SSA/SST/CEM, lokalizacja i warstwy – bez zmian.

## 2. Potwierdzone reguły renderowania oryginalnego EE
Analiza `Low-Level Engine.dll` (GETerrainMesh::UpdateVisibleTerrain, AddTilePolys, GETextureSet) i `EE-AOC.exe`
(rejestracja zestawów tekstur, EEComplexUnit::Load) w Ghidrze, potwierdzana na danych:
1. **Mieszanie tekstur [K]** – narożnik pola dostaje rodzaj terenu pola (−1,−1) względem punktu; pole rysowane
   jako warstwa bazowa + warstwy pozostałych tekstur z alfą 1/0 w narożnikach (Gouraud). Test: we wszystkich
   2304/2304 polach okna Rzymu w każdym narożniku widoczna jest tekstura jego terenu; 1827 pól to przejścia.
2. **Warianty tekstur [P]** – N = 1 + W·(r mod H) + (W−1−(c mod W)), cała tekstura na pole, obraz odbity poziomo.
   Reguła etapu 2 (bez odbicia kolumn) była błędna dla tekstur 4×4.
3. **Klasa punktu [K]** – indeks tablicy kolorów, którą gra pozostawia białą → bez wpływu na obraz.
4. **Klify [K]** – brak osobnej geometrii poza mapami kosmicznymi; tekstury klifów to zwykłe tereny
   (`dbcliffterrain`), kształt daje wysokość punktów. Brak sztucznych skał – zgodnie z silnikiem.
5. **Woda [K]** – druga warstwa, alfa 0,5 / 0 wg bitów lądu narożników w bajcie flag pola.
6. **Obiekty [D]** – obrót z macierzy GETransformation (mury ukośne 42/54 zgodne < 15°, mediana 0°);
   pole `angle` to nie obrót (hipoteza etapu 2 odrzucona); wysokość t[11] ≈ teren (mediana różnicy 0).
7. **Scenariusze EE [K+D]** – wersja 231, pola rekordu jednostki zależne od wersji (tabela w FORMATY_ETAP3 §6).

Hipotezy pozostające: kolejność warstw (silnik: adresy tekstur), poziom wody (0), wysokość obiektów z terenu,
bezwzględna skrętność obrazu (spójność terenu i obiektów potwierdzona), znaczenie pola `angle`.

## 3. Porównanie z oryginalną grą
**Nie wykonano porównania wizualnego z uruchomionym EE.** Dostępne narzędzia (automatyzacja laboratorium) uruchamiają
grę przez Wine/Lutris na pulpicie użytkownika i sterują nią xdotool/myszą – to narusza zasadę nieprzejmowania myszy,
więc gra nie była uruchamiana. Zgodność potwierdzono pośrednio: kodem silnika (reguły §2) i testami na danych
(narożniki tekstur 2304/2304, ciągłość krawędzi wariantów, wyrównanie murów, liczby obiektów = Python 52/52 plików,
wysokości t[11] vs teren). Zrzuty OpenEE do porównania przez użytkownika:

| Scenariusz | Zrzuty |
|---|---|
| AoC „Soldiers for Rome” | `aoc_rzym_ogolny.png` (etap 3), `aoc_rzym_ogolny_etap2.png` (przed), `aoc_rzym_blisko.png` (przejścia, klif, brzeg) |
| EE „The Trojan War” | `ee_troja_ogolny.png`, `ee_troja_blisko.png` (mury, wieże) |
| EE „The Battle of Waterloo” – cała mapa | `perf_duzy_waterloo_grupy.png` |

## 4. Testy regresyjne – `wyniki/testy_godot.json`: **66/66**
* Wszystkie 53 testy z etapów 1–2 i launchera (SSA, DCL, SST, CEM 2.0/1.3, scenariusze AoC, db, teksty PL/EN,
  audio, warstwy, konfiguracja użytkownika, launcher i powrót) – zaliczone; testy nie zmieniają ustawień użytkownika.
* Nowe (13): wariant tekstury, narożniki/mieszanie (2304/2304), teren własny narożnika, przejścia, siatka bez
  dodatkowej geometrii klifów, alfa wody, pola klifów, scenariusz EE Troja (5368 = Python), EE z nieczytelną listą
  celów (2231 = Python, gracz 3 częściowo), AoC bez zmian (9537), wzorzec 52 scenariuszy, baza obiektu (obrót 90°,
  wyznacznik), wyrównanie murów.
* Python: `test_scenariuszy_ee_aoc.json` – 52/52 (0 błędów), `test_ciaglosci_tekstur.json`, `test_orientacji_modeli.json`.

## 5. Pomiary wydajności
Warunki: xvfb + **llvmpipe (renderowanie programowe CPU)**, okno 1600×900, Godot 4.7.2; czasy klatki odzwierciedlają
CPU, nie GPU – porównywalne między wariantami, nie absolutne.

| Scena | Pola | Obiekty | Wczytanie | Teren | Obiekty | Klatka | Wywołania rysowania | Pamięć stat./wideo |
|---|---|---|---|---|---|---|---|---|
| mały (Rzym 24×24) | 576 | 197 | 3,4 s | 0,9 s | 1,2 s | 70,7 ms | 273 → **139** | 105 / 31 MB |
| średni (Rzym 48×48) | 2304 | 685 | 5,9 s | 1,4 s | 3,2 s | 80,2 ms | 755 → **173** | 113 → 111 / 44 MB |
| duży (Waterloo, cała mapa 130×150) | 39 280 | 12 368 | 10,7 s | 1,6 s | 8,0 s | 185 → 175 ms | 11 196 → **441** | 171 → **113** / 65 MB |
(„→” = bez grupowania → z grupowaniem MultiMesh.) Teren dużej mapy: 87 044 trójkątów, jedno wywołanie rysowania +
woda. Grupowanie: egzemplarze ≥ 8 tej samej siatki → MultiMesh, każdy z własną transformacją (pozostałe – węzły).
Na llvmpipe czas klatki ogranicza rasteryzacja, więc spadek wywołań 25× daje tylko ~5 %; zysk na GPU wymaga pomiaru
na sprzęcie. Wczytywanie zdominowane przez dekompresję DCL w GDScript i budowę modeli.

## 6. Formaty
Obsługiwane: SSA, DCL/PK01, SST/TGA, CEM 2.0 i 1.3, SCN wersji 231 (EE) i 250 (AoC) – teren i obiekty, tabele db AoC,
Language.dll, WAV/MP3, hashdb GOG.
Nieobsługiwane / częściowe: polimorficzna lista celów jednostki (3 pliki EE – gracz częściowo), tabele `dbobjects`
i `dbcivilization` w układzie EE, obiekty przypięte do pól EEMap (zawsze 0), mapy kosmiczne (pola i klify kosmiczne),
animacje CEM (klatka 0), transformacje modeli potomnych, zapisy gry (flaga „zapis” obsłużona w gramatyce, nietestowana).

## 7. Zrzuty
`wyniki/test_graficzny_etap3/`: `aoc_rzym_ogolny.png`, `aoc_rzym_ogolny_etap2.png`, `aoc_rzym_blisko.png`,
`ee_troja_ogolny.png`, `ee_troja_blisko.png`, `perf_*.png` (+ JSON). Zrzutów z oryginalnego EE brak (§3).

## 8. Pozostałe problemy i rekomendacje
1. **Porównanie wizualne z EE** – bezpieczny sposób: osobny X serwer (Xvfb/Xephyr) dla Wine z własnym `DISPLAY`
   i zrzutem przez `xwd`, bez xdotool na pulpicie użytkownika; wymaga zgody i przygotowania prefiksu Wine.
2. Animacja wody (16 klatek, tabela 33×33 materiałów), ściany brzegowe mapy, mapy kosmiczne.
3. Lista celów jednostki (polimorficzne klasy) – pełny odczyt 3 scenariuszy EE.
4. Kolejność warstw tekstur (adresy obiektów) – ewentualnie z zachowania gry w pamięci (narzędzia laboratorium).
5. Wydajność wczytywania: DCL w C również w Godot (GDExtension) lub pamięć podręczna rozpakowanych zasobów.
6. Modele: animacje (klatki CEM), modele potomne, tekstury części jednostek EE (białe sylwetki niektórych jednostek
   w scenariuszu Troi – do zbadania).
7. Bezwzględna skrętność świata – rozstrzygnąć zrzutem z gry (pkt 1) lub asymetrycznym modelem z napisem.
