# EE i AoC – porównanie wersji Titan (od etapu 52)

Dokument stały. Od etapu 52 **The Art of Conquest (AoC) jest główną wersją badaną**, a podstawowe **Empire Earth (EE)**
– wersją porównawczą. Nie zakładamy, że kod lub zachowanie obu gier są takie same. Mechanizm jest wspólny tylko wtedy,
gdy potwierdzi to pomiar w obu grach. Starsze porównanie mechanik interfejsu i ruchu (etapy 12–13):
`docs/POROWNANIE_MECHANIK_EE_AOC.md`; formaty baz: `docs/FORMATY_DB_EE_VS_AOC.md`.

Statusy: **WSPÓLNY** – potwierdzony w obu; **ZMIENIONY** – w obu, z potwierdzoną różnicą; **TYLKO_AOC** / **TYLKO_EE** –
brak w drugiej grze zweryfikowany; **NIEZWERYFIKOWANY** – brak danych z obu gier. Podobieństwo kodu nie wystarcza do
statusu WSPÓLNY.

## 1. Identyfikacja wersji [P: etap 52]

| Instalacja | Gra | Plik | SHA-256 (początek) | Rozmiar | Używana w pomiarach |
|---|---|---|---|---|---|
| GOG + NeoEE (Lutris, `empire-earth-gold-edition`) | EE | `Empire Earth.exe` | `e352d7ae5ebc91f8` | 11 978 080 | tak – kopia testowa bez filmów `846350a85fd51330` |
| GOG + NeoEE (Lutris) | AoC | `EE-AOC.exe` | `db8fc5ceb85dbb9b` | 12 071 792 | tak – kopia testowa bez filmów `c636a2ab0a9c30d3` |
| GOG bez NeoEE (`Empire Earth Gold`) | EE | `Empire Earth.exe` | `957e35d75ba80309` | 6 321 664 | nie |
| GOG bez NeoEE | AoC | `EE-AOC.exe` | `632246d25f0d7ab9` | 6 262 784 | nie |

- Uruchamianie: Lutris (identyfikator 22, prefiks `empire-earth-gold-edition`), proces Wine z obrazem exe. Riverlands_MCP
  rozpoznaje grę po działającym procesie (`ee_warianty.procesy_gier`: pierwszy argument + mapowanie w /proc/<pid>/maps) i
  przypisuje adresy pamięci do **kompilacji** (SHA-256), nie do nazwy. Nieznana kompilacja = brak odczytu pamięci. Gdy
  działają obie gry, narzędzia odmawiają pracy.
- Przełączanie: krok `wariant {"wybierz": "aoc"|"ee"}` + start właściwej kopii exe. Każdy wynik zadania od etapu 12 zapisuje
  wariant i SHA-256 kompilacji (krok `wariant`).
- Bazy danych: `data.ssa` każdej instalacji (EE: rekordy `dbtechtree` 268 B, `dbeffects` 68 B; AoC: 272 B, 88 B –
  `FORMATY_DB_EE_VS_AOC.md`). Lokalna kopia OpenEE: `cache/e11/raw/{spolecznosciowa,referencyjna}_{ee,aoc}`.

### 1.1. Pochodzenie dotychczasowych pomiarów [P: nagłówki nagrań i wyniki zadań]

| Zbiór | Liczba | EE | AoC |
|---|---|---|---|
| nagrania `Testy_MCP/ee_obserwacja/*.json` (pole `wariant`) | 125 | 121 (etapy 29–51) | 4 (e30_570, e31_580/581, e32_588) |
| kroki zadań z wariantem (wszystkie zadania) | 33 430 | 30 568 | 2 862 |
| kompilacje w wynikach zadań | – | e352d7ae ×203, 846350a8 ×186 | db8fc5ce ×91, c636a2ab ×42 |

Wniosek: **rekonstrukcja Titan od etapu 29 (ruch, kolizje, walka, budowa, zbieranie) była mierzona prawie wyłącznie
w EE** (kompilacja e352d7ae / kopia 846350a8). Pomiary AoC: etap 9–10 (kamera, ruch grupowy), 12–13 (porównanie
mechanik, prędkość, kolizje), 30–32 (walka: przeładowanie, obrót, tablice) i 52 (produkcja). Adresy atlasu z etapów
29–51 dotyczą EE, o ile dokument nie podaje kolumny AoC. Atlas nawigacji i ruchu (etapy 14–27) ma adresy obu gier.

## 2. Znane różnice (potwierdzone)

| Obszar | EE | AoC | Status | Dowód |
|---|---|---|---|---|
| Wersja SCN | czyta 231, odrzuca 250 | czyta 231 i 250 | ZMIENIONY | [P: 626, etap 12] |
| Rekord `dbtechtree` / `dbeffects` | 268 B / 68 B | 272 B / 88 B (pola dodane) | ZMIENIONY (dane) | [P: etap 11] |
| Kolejka produkcji budynku – pozycja | 4 B {technologia} | 8 B {technologia, flaga gracza +0xB4E} | ZMIENIONY (struktura) | [W: EE 0x5E89C7, AoC 0x5F6044; P: 679/677] |
| Losowania przy utworzeniu jednostki z produkcji | 3 | 1 | ZMIENIONY | [P: 679 – 2 zdarzenia; 677 – 4] |
| Zasoby gracza | +0xAF8 … +0xB08 | +0xAFC … +0xB0C | ZMIENIONY (przesunięcie) | [P: 660 / 675] |
| Populacja gracza | +0xB10 | +0xB14 | ZMIENIONY (przesunięcie) | [P: 679 / 677] |
| Pole bieżącej produkcji / licznik | +0x25C / +0x27C | +0x260 / +0x280 | ZMIENIONY (przesunięcie) | [W + P] |
| Klasa jednostki – typ dbobjects | +0x4B8 | +0x1BC | ZMIENIONY (przesunięcie) | [P: etap 12] |
| Odbudowa kontaktów przy zmianie pola | po zapisie | przed zapisem | ZMIENIONY [W] | kolizje_objazdy.md; bez testu dynamicznego |
| Przeładowanie | stałe | losowe [lo, hi] | ZMIENIONY | walka.md § 11 [P: 580/581] |
| Narastanie przewijania krawędzią | brak | ~1 s | NIEZWERYFIKOWANY (możliwe ustawienie myszy) | POROWNANIE_MECHANIK § 2 |
| Wybór płci produkowanego obywatela | 1074, 1074 | 1451, 1451, 1074, 1074, 1074 | NIEZWERYFIKOWANY (reguła [N]) | 677–679 |

## 3. Mapowanie funkcji i struktur

Pełna lista par: `dane/titan/struktury_titan.json` → `pary_funkcji` (11 par z etapów 13–33 i 10 par produkcji z etapu 52;
pola `kryterium`, `pewnosc`, `zachowanie`). Kontrola spójności przesunięć: `narzedzia/titan/struktury.py porownaj`
(etap 52: 14 niespójności – pola o innych przesunięciach albo dostępne w funkcji jednej gry; 8 z nich w parach
produkcji, głównie dostępy do macierzy, celu i typu w EE 0x624DF8, gdzie EE tworzy jednostkę w tej samej funkcji).

| Funkcja | AoC | EE | Kryterium | Pewność | Zachowanie |
|---|---|---|---|---|---|
| wykonanie „Research Technology” | 0x4C49B7 | 0x4BBE02 | RTTI + indeks metody | W | WSPÓLNY (produkcja 677/679) |
| dopisanie do kolejki produkcji | 0x5F5F97 | 0x5E8908 | sekwencja instrukcji | W | koszt przy rozkazie – WSPÓLNY [P] |
| start pozycji | 0x5FDC58 | 0x5EF9FF | sekwencja | W | WSPÓLNY [P: 28000, start w tym samym takcie] |
| odliczanie i utworzenie | 0x6394CD (+0x631B55) | 0x624DF8 | sekwencja, stała 5000 | W | czas, miejsce, kurs WSPÓLNE [P]; losowania ZMIENIONE |
| EEPlayer vt+0xB4 / +0x44 / +0x50 / +0x54 / +0x7C | 0x56B09E / 0x5628CB / 0x564223 / 0x563A25 / 0x56528B | 0x55BE2C / 0x5546F5 / 0x555E93 / 0x55574D / 0x556EBC | RTTI, te same indeksy | W | limit populacji 101 w obu [P] |
| EEMBuildUnit | 0x838AB4 (vt), wykonanie 0x4BBCC4 | 0x824B40 (vt) | RTTI | W | rozkaz budowy budynku (nie produkcja) |

Uwaga: indeksy metod klas jednostek (`EEUC*`) **nie** są wspólne – metoda 46 `EEUCBuilding` w AoC (0x60FD9D) i EE
(0x601BE4) to różne funkcje [W: etap 52]. Mapowanie przez indeks działa dla `EEPlayer` i komunikatów `EEM*`, nie dla
klas jednostek.

## 4. Różnice w bazach danych

`FORMATY_DB_EE_VS_AOC.md` § 4: AoC rozszerza rekordy EE (dodatkowe pola, nowe identyfikatory na końcu). Etap 52:
rekordy `dbtechtree` Citizen 1074, Female Citizen 1451, House 1069, Barracks 1071 – identyczne koszty i czasy w obu
grach; różni się tylko „Ending epoch” (EE 14, AoC 15) [P: odczyt]. `dbobjects` 32/480 – w obu grach różnią się tylko
grafiką, dźwiękami, technologiami i „Attack angle” [P].

## 5. Macierz podsystemów (38 pozycji `POSTEP_REKONSTRUKCJI.md`)

Kolumna „dowody” – wersja, w której zebrano dowody ocen A/B/C: **EE**, **AoC**, **EE+AoC**, **nieustalone**.

| # | Podsystem | Dowody | Status EE/AoC |
|---|---|---|---|
| 1 | Pliki i bazy db*.dat | EE+AoC | ZMIENIONY (dane), dekodery obu wersji |
| 2 | SCN | EE+AoC | ZMIENIONY (wersje 231/250) |
| 3 | Mapa i teren | EE+AoC [W: DLL obu] | NIEZWERYFIKOWANY (pomiary EE) |
| 4 | Obiekty mapy | EE | NIEZWERYFIKOWANY |
| 5 | Graf nawigacji | EE | NIEZWERYFIKOWANY |
| 6 | Pathfinding | EE+AoC (444/445 EE, 454 AoC) | WSPÓLNY w zmierzonych przypadkach |
| 7 | Fizyka ruchu | EE (AoC: prędkość etap 13) | NIEZWERYFIKOWANY poza prędkością |
| 8 | Kolizje | EE (AoC [W]) | ZMIENIONY [W] – kolejność odbudowy kontaktów |
| 9 | Kolejka fizyki | EE | NIEZWERYFIKOWANY |
| 10 | Maszyny stanów | EE | NIEZWERYFIKOWANY |
| 11 | Cele i rozkazy | EE (+AoC 454) | NIEZWERYFIKOWANY |
| 12 | Walka | EE+AoC (580/581/583/584/588) | ZMIENIONY (przeładowanie, obrót) |
| 13 | Śmierć | EE | NIEZWERYFIKOWANY |
| 14 | Budynki i budowanie | EE | NIEZWERYFIKOWANY (dane `dbtechtree` wspólne [P]) |
| 15 | Jednostki cywilne | EE (+AoC produkcja obywatela) | NIEZWERYFIKOWANY |
| 16 | Zbieranie | EE | NIEZWERYFIKOWANY |
| 17 | Ekonomia | EE+AoC | ZMIENIONY (przesunięcia), limit WSPÓLNY [P] |
| 18 | Produkcja | EE+AoC | WSPÓLNY (czas, koszt, miejsce) / ZMIENIONY (kolejka, losowania) |
| 19 | Technologie, epoki | EE+AoC (bazy) | ZMIENIONY (liczba epok 14/15) |
| 20 | AI | EE | NIEZWERYFIKOWANY |
| 21–23 | Dyplomacja, widoczność, świat | EE | NIEZWERYFIKOWANY |
| 24, 25, 29, 31, 38 | niebadane | – | NIEZWERYFIKOWANY |
| 26–28 | Animacja, efekty, interfejs | EE+AoC (kamera etap 12) | WSPÓLNY (kamera), reszta NIEZWERYFIKOWANY |
| 30 | Multiplayer | EE+AoC [W: DLL] | NIEZWERYFIKOWANY |
| 32 | Losowość | EE (+AoC produkcja) | ZMIENIONY (losowania przy utworzeniu) |
| 33 | Zegar | EE+AoC [W] | NIEZWERYFIKOWANY dynamicznie w AoC |
| 34–37 | Efekty obszarowe, bohaterowie, kalamity, szyk | EE | NIEZWERYFIKOWANY |

## 6. Status pomiarów i metodologia

Metodologia każdego porównania:
1. Ten sam scenariusz logiczny: mapy `e42_*` (SCN 231, kampania EE) wczytują obie gry; te same zasoby i układ.
2. Ten sam rejestrator co takt (`rejestruj_start`, surowe bajty obiektu i gracza), osobne przesunięcia dla każdej gry
   (Riverlands_MCP `ee_ekonomia.PRODUKCJA`).
3. Odtworzenie w Core z `--wariant=ee|aoc`; porównanie próbka po próbce.
4. Różnica wejścia (np. inna płeć, inne dane bazy) nie jest klasyfikowana jako zmiana silnika.

Wykonane porównania kontrolne: produkcja obywatela (677/679) – etap 52.

## 7. Eksperymenty do powtórzenia

**W AoC (główna wersja; dotąd tylko EE):** ruch pojedynczy i trasa (644, 648), kolizje i omijanie (652), budowa domu i
koszar (658–674), zbieranie drewna (673), śmierć i zapadanie budynku (649/651), regeneracja i bohater (619/620).
Priorytet: budowa i zbieranie (koszt i wzór 0x60BF56 – czy wspólne), ruch 648 (prorok).

**W EE (dotąd tylko AoC):** przeładowanie losowe i obrót (580–588) – kontrola, czy EE ma stałe przeładowanie w tym samym
scenariuszu; anulowanie produkcji (gdy znajdzie się miejsce w interfejsie).
