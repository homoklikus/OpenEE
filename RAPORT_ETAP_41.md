# Raport – etap 41: budowa grafu podsektorów Titan – część potwierdzona

Etap 41 rozłożył budowę grafu podsektorów EE (0x42434F) na kroki i porównał każdy z pełnym odczytem e35_a z gry
(1858 podsektorów). Potwierdzone są listy sąsiadów (0x4246E8: 1857/1857, zbiór i kolejność) oraz punkty
reprezentatywne (ComputeCenterPoint: 1851/1857). Core liczy je teraz sam z przydziału pól do podsektorów.

**Core nie buduje jeszcze grafu w pełni samodzielnie.** Brakuje siatki regionów (0x423E3F/0x4240D3) i dokładnej reguły
floodu po przekątnej. Czysta mapa (C) i kolizje 590 G1 (E) nie zostały wykonane.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. Commit początkowy i końcowy

- Początek: `2dbbe44` (lokalny etap 40). GitHub bez zmian (`c776a61`).
- Koniec: jeden lokalny commit etapu 41 (`git log -1`). Bez push, pull, fetch, reset, rebase i clean.
- Poza commitem: `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11` użytkownika.
- Riverlands_MCP: nowa funkcja `obszary` w `ee_podsektory.py` – lokalnie, niezatwierdzone.

## 2. Algorytm budowania podsektorów

Pełna tabela kroków: `docs/titan/architektura_nawigacji.md`, sekcja „Etap 41”.

1. **Sektory** [W; P: komórka 19]: siatka komórek, rozmiar z rozmiaru mapy; prostokąty przycięte do mapy.
2. **Skan** [W; P: pierwsze 62–94 podsektory]: x i y malejąco od (W − 1, H − 1); flood startuje na polu bez
   podsektora, które ma obiekt pola.
3. **Flood** [W]: maszyna A* `PathSectorStorage` w prostokącie sektora.
   - Pole jest dostępne, gdy ma tę samą wartość siatki regionów co pole startowe (0x41EAE7).
   - Wszystkie węzły list otwartej i zamkniętej trafiają do podsektora (0x41E8EC).
   - Reguła przekątnej [N]: kod 0x42AB38 mówi „co najmniej jeden bok dostępny”. Odczyt zawiera jednak przypadki
     sprzeczne – podsektor 63 jest połączony mimo dwóch obcych boków, a podsektor 95 rozdzielony w analogicznym układzie.
4. **Id, obszar, region, rodzaj** [W; P odczyt]:
   - id = kolejny licznik (od 1, w kolejności skanu);
   - +0x4C = obszar (siatka +0xF4);
   - +0x4E = region;
   - +0x54 = rodzaj regionu (1, 4, 12, 13, 14 …).
5. **Punkt reprezentatywny** [P 1851/1857]: `U2DSparseArrayPointContainer::ComputeCenterPoint(true)`.
   - Średnia f32 Σ x/n od końca listy pól, obcięcie.
   - Gdy wynik nie leży w podsektorze, wybierane jest najbliższe pole (d² całkowite, od ostatniego, przy remisie
     mniejszy indeks).
6. **Sąsiedzi** [P 1857/1857]: skan x↑, y↑.
   - Badane pola: (x−1, y), (x, y−1), (x−1, y−1), (x+1, y−1).
   - Wzajemne dopisanie na koniec listy, jeśli brak.
   - Tryb przekątnej z dwoma różnymi bokami dodatkowo zapisuje mapę +0x04, ale listy sąsiadów nie zmienia.
7. **Regiony** [N]: budowane wcześniej (0x423E3F/0x4240D3) z obiektów pól i ich klas. To nie są składowe
   przejezdności Core – sprawdzone: 9–15 składowych łączy różne obszary.

Odpowiedzi na pozostałe pytania A2:
- Rozłączne fragmenty jednego podsektora wynikają z połączenia przez inne kolumny lub przekątną.
- Sąsiedztwo „odległych” podsektorów to styk pól dużych podsektorów sąsiednich sektorów.
- Kolejność tworzenia wyznacza id. Kolejność sąsiadów wpływa na A* grafu, bo sąsiedzi są rozwijani od końca listy.
- Graf jest wspólny dla jednostek; rodzaj filtruje A* [W].
- Przebudowa: 0x4288A7 → 0x4A36F3 → 0x4278C3 [W, nieanalizowana w tym etapie].

## 3. Mapa funkcji Titan

| Funkcja | Rola | Pewność |
|---|---|---|
| 0x42434F | sektory, skan, floody, przypisanie id/punktów, sąsiedzi | [W] |
| 0x4290A2 / 0x429B6D / 0x42A999 / 0x42AA10 | maszyna A* floodu (vtable 0x826320, storage 0x826364), pętla bez limitu iteracji | [W] |
| 0x41EAE7 | dostępność w floodzie (region, prostokąt), zapis regionu i rodzaju do celu | [W] |
| 0x41E8EC / 0x41E990 | id i lista pól z węzłów, utworzenie `EEAIPathSubSector` | [W] |
| 0x42C2D5 | punkt reprezentatywny (ComputeCenterPoint) | [P] |
| 0x4246E8 / 0x423255 | listy sąsiadów i mapa przekątnych +0x04 | [P] |
| 0x425FD4 / 0x42602D / 0x42609F | sektor pola, podsektor pola (`Contains`) | [W] |
| 0x423E3F / 0x4240D3 | regiony (PathAreaStorage) | [N] |

## 4. Struktury i pola

`EEAIPathSubSector`:
- +0x44 sektor;
- +0x48 (z celu +0x94);
- +0x4C obszar;
- +0x4E region;
- +0x50 id;
- +0x54 rodzaj;
- +0x10 pola;
- +0x2C sąsiedzi;
- +0x3C/+0x40 punkt;
- +0x04 mapa przekątnych.

Korekta raportu 40 (§ 3): `+0x1C` celu to pochodzenie (gracz), a bajt `+0x1C` prośby o trasę oznacza „uruchom
etap grafu” (0x4A1AFF, PrepareToMove 0x622431).

Manager:
- +0xF4 – siatka obszarów u16 w układzie x·H + y [P];
- +0xF8 – siatka podsektorów, po budowie pusta [P].

## 5–7. Porównanie grafów i trasowanie

| Tryb | Pola i id | Punkty | Sąsiedzi | Trasy 619/620 |
|---|---|---|---|---|
| Referencyjny (odczyt z gry) | – | – | – | 619 i 620 co takt (etap 40) |
| Core z przydziału pól (punkty i sąsiedzi z Core) | przydział z gry | 1851/1857 | 1857/1857 | 619: obie gwardie 7273/7273, kolejki bez różnic; 620: 6419/6419 i 6418/6419 (1 odczyt pośredni) |
| Prototyp pełnej budowy (siatka regionów z odczytu) – najlepszy wariant | 1899 vs 1858 podsektorów; 82 identyczne | 82/82 przy identycznych polach | 36 | nie badane (graf strukturalnie różny) |

Wpływ różnic: przy różnym podziale pól A* grafu wyznacza inne ścieżki i punkty pośrednie. Dlatego prototypu nie
włączono do Core.

## 8. Integracja z Core

- `zbuduj_graf_z_przydzialu`, `punkt_reprezentatywny`, źródło grafu w diagnostyce (`graf_zrodlo`: „gra (odczyt)” /
  „Core z przydziału pól”).
- Wyszukiwanie grafu i punkty +0x32 wspólne dla obu trybów.
- GDExtension 0.15.0: `zbuduj_graf_z_przydzialu(id_xH, W, H, komorka)`.
- `odtworz_e35.gd --graf-przydzial=…`.
- Tryb autonomiczny (bez danych z gry) – niedostępny.

## 9–11. SCN 231/250, czysta mapa i scenariusze

Niewykonane. Baza `e40_czysta_baza.scn` (SCN 250) bez jednostek testowych.

## 12. Kolizje 590 G1

Niewykonane [N]. Potrzebny ten sam eksperyment co w raporcie 40.

## 13. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | 40/40 (+2: graf z przydziału pól, sąsiedzi i ścieżka) |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| 578 G1 | 986/986 |
| Mapa | `c8297c16f0d48b1a` |

578 G3, 590 G1, AoC 505 i EE 500 – bez zmian (169, 97, 803, +1). 619/620 – § 5.

## 14. Potyczka Godot

Bez grafu podsektorów; status ograniczenia bez zmian.
- Wygrane w taktach 1240 i 1371, restart działa.
- Scena 1 na 5 przegrana w takcie 757.
- Takty demo różnią się między uruchomieniami z renderem [H: czas klatek w demo].

## 15. Nierozwiązane

- Siatka regionów (0x423E3F/0x4240D3) i reguła przekątnej floodu – brak pełnej autonomii grafu.
- 6 różnic punktów reprezentatywnych – kolejność sumowania lub węzłów kontenera.
- Przebudowa grafu.
- SCN 231/250 i czysta mapa.
- 590 G1.
- Remisy A* grafu, filtr rodzajów, 0x4A0CE8, 9016 (bliski region), +0x1D zwykłego PPM, 0x5ECAD0.

## 16. Prognoza i etap 42

1. Regiony 0x423E3F/0x4240D3: odczyt siatki regionów z pamięci (storage maszyny regionów lub +0x4E podsektorów)
   i analiza kodu klas pól 0x42301D. Test: odtworzenie `w4c[1]` dla 39 480 pól.
2. Reguła floodu po przekątnej: porównanie przypadków 63 i 95 z kodem relaksacji 0x42B907 i pamięcią podręczną
   0x42BAF4.
3. Czysta mapa i 590 G1 – przeniesione z etapu 41.
