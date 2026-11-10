# Raport etapu 43 – klasyfikacja pól z kodu Titan, graf z mapy SCN i walka na czystych scenariuszach

Najważniejsze wyniki etapu:
- Znaleziony w kodzie mechanizm klasyfikacji pól daje zgodność 39 341/39 480.
- Punkty reprezentatywne i sąsiedzi zgadzają się w całości (1857/1857).
- Trzy nagrania z czystej mapy (631, 633, 634) odtwarzają się w Core co takt. Wyjątkiem jest tylko animacja umierania celu.
- Pierwszy prawdziwy pomiar kontaktu jednostek wskazał, a następnie usunął różnicę fizyki Core (reguła „cel zajęty”).

**Graf nie jest jeszcze w pełni autonomiczny.** Brakują dwie rzeczy:
- 139 pól klifów, których rodzaj Core ustala inaczej niż gra;
- obiekty pól (lista +0x08 i flaga +0x612), które nadal pochodzą z odczytu pamięci gry.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. HEAD początkowy i końcowy

- Początek: `8038bff` (lokalny etap 42; publiczny `main` bez zmian – `c776a61`).
- Koniec: jeden lokalny commit etapu 43 (`git log -1`). Bez push, pull, fetch, reset, rebase i clean.
- Poza commitem zostają pliki użytkownika: `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11`.
- Riverlands_MCP (lokalnie, niezatwierdzone): nowe funkcje `pola_surowe` i `mapa_tablice` w `ee_podsektory.py`.

## 2. Miejsca zapisu klasyfikacji pól [W]

| Wartość | Zapis | Kolejność |
|---|---|---|
| obiekt pola | konstruktor 0x519DE6 – +0x04 = 0, +0x14 = 0, +0x10 = f10 z SCN (fabryka mapy vt+0x18) | tworzenie mapy 0x5182E2 |
| rodzaj +0x04 | Tile::SetKind 0x516E8C (vt+0x14 pola EE 0x82C574), wołany z Map::UpdateTiles 0x51183B dla 4 pól wokół wierzchołka; także pętle ładowania 0x51241D / 0x512490 (pola rodziny 9 – osobna ścieżka) i 0x51357B | ładowanie mapy |
| +0x14 | 0x426577(1) – pola wody, przed regionami; 0x426577(0) – pola lądu, po regionach; 0x4285C6 – zmniejszanie o 10 po usunięciu obiektu | 0x427D42: 0x4233B7 → 0x426577(1) → 0x4240D3 (regiony, podsektory) → 0x42340F → 0x426577(0) → 0x423E3F ×2 |
| zbiory S1/S2 | 0x4282B8 (przez 0x42382C) → wektory managera +0x1C/+0x2C | przed 0x426577(1) |

## 3. Reguły klasyfikacji i źródła danych

**Rodzaj +0x04** (Tile::SetKind) [W kod; P 39 341/39 480]:
- argument to rodzina terenu pola: rekord dbterrain +0x5C = kolumna „Terrain family” (OpenEE już ją czyta).
  Identyfikator terenu (bajt +2 tablicy wierszy map+0x17B598) jest równy teksturze pola z SCN [P: 39 480/39 480, zad. 636];
- f10 ≥ 0 → rodzina;
- f10 < −0,75·G → 1 (woda głęboka), G = [0x9130E4] = **0,408248** [P: odczyt];
- w pozostałych przypadkach: gdy mniej niż 3 narożniki pola mają wysokość ≥ 0 → 10, inaczej rodzina.
  Wysokości narożników to wysokości wierzchołków SCN [P: 40 041/40 041].

| Grupa pól (e35_a) | Zgodne | Różne |
|---|---|---|
| woda (f10 < 0) | 19 907 | 3 |
| ląd | 19 434 | 136 |
| **razem** | **39 341** | **139** |

**139 różnic** dotyczy tekstur klifów (50/51, rodzina 9) i pól sąsiednich [N]:
- 94 z tych pól ma rodzaj pola (x−1, y−1);
- przykład: gra ma klif na (206, 193), a w SCN tekstura klifu leży na (205, 192);
- powiązany kod [W]: 0x51241D (ładowanie zamienia pola rodziny 9 na teren domyślny +0x181734), 0x51357B (pole klifu
  o rozpiętości narożników < 1,5·0,408 → teren domyślny), 0x513941 (zapis terenu pola);
- w odczytanej pamięci tekstury klifów są jednak zachowane, więc ta ścieżka nie wyjaśnia wyniku. Potrzebny jest
  dynamiczny ślad zapisu +0x04 dla pola (206, 193).

**Bajt +0x14** [W kod; P częściowo]:
- woda: S1 to pola wody z sąsiadem lądowym (rodzaj ∉ {1, 10, 9}), S2 to pola wody bez lądu, ale z sąsiadem
  rodzaju 9. h = 10·(liczba sąsiadów w S1 i S2), dla pola z S1: −10 − h; przycięcie do ±120;
- ląd: 10·(liczba obiektów z „Resource type” = 3 w oknie 3×3), liczone po budowie regionów, więc regiony z tego nie korzystają.

**Typy obiektów** [P 69/69 typów]:
- +0x568 = „Resource type”, +0x600 = „Is building?”, +0x4B4 = „Unit type”;
- +0x612 (mury, bramy, wieże) nie ma kolumny w bazie [N].

## 4. Porównanie +0x04 i +0x14 na e35_a

| Wartość | Zgodność | Uwagi |
|---|---|---|
| rodzaj +0x04 | **39 341/39 480** (99,65 %) | 139 pól klifów [N] |
| +0x14 wody – znak (używany przez regiony) | **19 595/19 610** | |
| +0x14 wody – wartość | 19 002/19 610 | różnice ±10–20 przy brzegu [N] |
| +0x14 lądu | 10 972 pól z zerem zgodnych | lądu Core nie liczy (wymaga obiektów; regiony z niego nie korzystają) |

Zgodność +0x04 jest prawie taka sama jak w regule z etapu 30 (39 344 – reguła z bitów flag). Nowa reguła pochodzi
jednak z kodu, a nie z dopasowania. Reguła etapu 30 nadal decyduje o przejezdności, a skrót mapy jest bez zmian.

## 5. Status autonomicznego grafu z SCN

**Eksperymentalny, niepełny.** Przepływ jest taki: SCN → `MapaTitan::rodzaj_pol_titan` / `bajt14_wody` → obszary →
regiony → podsektory → punkty i sąsiedzi. Obiekty pól wciąż pochodzą z odczytu gry.

Zrealizowane bez danych grafu z pamięci gry:
- obszary (model z pomiaru z etapu 42),
- regiony i podsektory,
- punkty reprezentatywne i sąsiedzi,
- A* grafu i punkty pośrednie.

## 6. Zgodność struktury grafu (e35_a)

| Element | Wejście mapy z gry | Mapa SCN w Core + obiekty z gry |
|---|---|---|
| obszary | 43/43 | 42 (gra 43) |
| regiony | 1135/1135; 39 480/39 480 pól | 1128; 27 386 pól |
| podsektory z polami | 1857/1857 identycznych | 1851; 91 identycznych do 1. różnicy (podsektor 37, rodzaj 3 – klif) |
| punkty reprezentatywne | **1857/1857** (było 1851) | – |
| sąsiedzi (zbiór i kolejność) | 1857/1857 | – |

- **Sześć punktów**: iloraz x/n jest liczony w precyzji rozszerzonej x87, bez zaokrąglania do f32. Do f32 zaokrąglana
  jest dopiero suma po każdym dodaniu [P 1857/1857]. Inne warianty kolejności i zaokrągleń sprawdzone: najlepszy z nich daje 1851.
- **1858. rekord**: wektor managera ma 1858 wpisów, a wpis id 0 jest pusty. Podsektora bez pól nie ma, więc Core niczego nie dopisuje.

## 7. Trasy 619/620 bez grafu z pamięci gry

| Graf | 619 | 620 |
|---|---|---|
| Core z wejścia mapy z gry | identyczne z etapem 41 | identyczne |
| **Core z mapy SCN** (rodzaj pól i +0x14 z Core, obiekty z gry) | identyczne z etapem 41 we wszystkich polach wyniku (stany, pozycje, cele, kolejki z punktami pośrednimi, HP, zdarzenia) | identyczne |

Etap 41 jest zgodny z grą co takt (obie gwardie i kolejki), więc 619 i 620 przechodzą także z grafem zbudowanym z SCN.
**Nie jest to dowód pełnej autonomii**, bo obiekty pól są z odczytu gry. Różnice klifów leżą jednak daleko od tych tras.

## 8. Uogólnione odtwarzanie scenariuszy

- `narzedzia/titan/odtworzenie_nagrania.py opis` buduje opis z nagrania MCP i układu z generatora:
  - jednostki, pozycja, kurs = atan2(−m01, m11), z zapisu scenariusza;
  - rozkazy gracza: każdy nowy cel kolejki z pochodzeniem 1, z kursem końcowym EEUGLocation.
- `porownaj` porównuje co próbkę stan, HP, pozycję i kurs. Próbkę spóźnioną rejestratora (gra = Core w poprzednim
  takcie, następna próbka zgodna) liczy osobno.
- `godot/testy/eksperymenty/odtworz_scenariusz.gd` – jeden skrypt dla dowolnego układu:
  - mapa i obiekty statyczne z SCN, parametry typów z `dane/testy_walki/parametry_jednostek_ee.json`;
  - symulacja od czasu gry 0;
  - kolejność listy jako opcja (`--kolejnosc`).

## 9. Wyniki 631, 2v1 i 3v1 [P]

| Nagranie | Jednostki | Zgodność (stan, HP, pozycja, kurs) | Pierwsza różnica |
|---|---|---|---|
| 631 (1v1, etap 42) | gwardia, obserwator, cel | 2808/2808, 2808/2808, cel 2186 | cel: 6001 vs 6000 (koniec umierania), t = 78409 |
| 633 (2v1, nowe) | 2 gwardie, obserwator, cel | 3695 + 2 spóźnione / 3697; 3697; 3697; cel 2084 | cel: umieranie, t = 74829 |
| 634 (3v1, nowe) | 3 gwardie, obserwator, cel | 6413/6413 ×4; cel 2081 | cel: umieranie, t = 74829 |

Ustalenia potrzebne do tej zgodności (bez stałych dopasowanych do nagrań):
1. **Wysokość z zapisu scenariusza.** Jednostka bez aktualizacji fizyki zachowuje z z rekordu SCN (1,837 przy terenie
   0,408). Przechwycenie 0x62C963 liczy odległość 3D z tą wartością, co daje punkt podejścia celu 110,184 zamiast
   109,8895 [P].
2. **Faza liczników od startu.** Pierwszy wybór celu następuje w 34 ms (629), dlatego odtworzenie zaczyna się od czasu gry 0.
3. **Kolejność w takcie (czysta mapa).** Jednostki o mniejszym id są przetwarzane wcześniej. W takcie 62419 CheckRange
   gwardii widzi poprzednią pozycję celu [P]. W 578 G3 (mapa kampanii) ta reguła pogarsza wynik, więc ogólnie kolejność jest [N].
4. Umieranie gwardii: 6000 trwa 2455 ms, 6001 – 1 takt, 6002 – 40 129 ms [P]. W Core nie jest to zamodelowane [N].

## 10. Eksperyment kolizji

- **Nowy zapis kontaktu** (634): gwardia 0x1000857 dochodzi do punktu zajętego przez stojącą 0x1000855.
- **Porównanie z Core:** zgodność do taktu 113185. Wtedy reguła (a) daje v = 0 w obu.
- **Pierwszy rozbieżny etap: zaliczenie punktu.**
  - Gra w takcie 113219 wykonuje zwykły krok z v = 0: przyspieszenie a·dt, przesunięcie 0,0023 pola. Dopiero potem zalicza punkt.
  - Core zaliczał punkt już w takcie reguły; było to założenie [H] z etapów 29–42.
- **Kod:** 0x6213D8 zwraca „osiągnięty” przy +0x330 = 8 [W].
- **Poprawka:** +0x330 = 8 zalicza punkt w następnej fizyce. Po niej 634 jest zgodne co próbkę.
- Regresja: S1–S7 i skrót scenariuszy są bez zmian; testy syntetyczne kolizji przechodzą.
- **590 G1 bez zmian.** Pozycja maks. 0,0094, takt 97. Przyczyna jest inna niż reguła (a), bo kolejność listy w 590 G1
  jest już taka jak ustalona. Brakujący odczyt: wektor push obu jednostek i lista kontaktów w taktach 95–98 z 590.
  Rejestrator zapisuje je teraz (pola `push`, `kontakty`), więc wystarczy powtórzyć układ 590 na czystej mapie.

## 11. Zmiany w Core, GDExtension i MCP

Core:
- `MapaTitan::rodzaj_pol_titan`, `bajt14_wody`;
- `Swiat::ustaw_z`;
- reguła (a): zaliczenie punktu w następnej fizyce;
- `punkt_reprezentatywny` z ilorazem w precyzji x87.

GDExtension 0.17.0:
- `ustaw_z`, `wejscie_regionow_z_mapy`, `podsektor(id)`.

Narzędzia:
- `odtworz_scenariusz.gd`, `porownaj_graf.gd`;
- `odtworz_e35.gd --graf-scn`;
- `odtworzenie_nagrania.py`;
- `dane/testy_walki/parametry_jednostek_ee.json`.

Riverlands_MCP (lokalnie): `pola_surowe`, `mapa_tablice`.

## 12. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | **49/49** (+5: klasyfikacja syntetyczna, +0x14 wody, `ustaw_z`, punkty e35_a 1857/1857, klasyfikacja e35_a z SCN) |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| EE 578 G1 | 986/986 |
| Skrót mapy | `c8297c16f0d48b1a` |
| Graf e35_a z wejścia z gry | regiony 39 480/39 480, podsektory 1857/1857, sąsiedzi 1857/1857, punkty 1857/1857 |
| 619/620 | identyczne z etapem 41 (wejście z gry i z SCN) |

578 G3 (5 różnic stanu) i 590 G1 – bez zmian. `git diff --check` jest czysty. Porównania z grą i testy syntetyczne są
osobnymi testami.

## 13. Potyczka Godot

- Obie bitwy wygrane (takty 1238 i 1207), restart działa, scena 1 na 5 – przegrana w takcie 757.
- Graf podsektorów **nie jest włączony** w potyczce, bo klasyfikacja jest niepełna (klify, obiekty).
- Tryb grafu z SCN istnieje tylko jako jawne narzędzie eksperymentalne (`wejscie_regionow_z_mapy`).

## 14. Pierwsze rozbieżne takty

| Przebieg | Pierwsza różnica |
|---|---|
| 631 | brak dla gwardii; cel t = 78409 (umieranie) |
| 633 | cel t = 74829 (umieranie) |
| 634 | cel t = 74829 (umieranie) |
| 619/620 | brak względem etapu 41 |
| 578 G3 | takt 169 (ω), bez zmian |
| 590 G1 | takt 97, bez zmian |

## 15. Problemy nierozwiązane

- 139 pól klifów (+0x04) – potrzebny ślad zapisu [N].
- Wartość +0x14 wody (608 pól) i +0x14 lądu.
- Obiekty pól w Core: rejestracja na polach, flaga +0x612.
- Kod obszarów +0xF4.
- Animacja umierania (6000 → 6001).
- Ogólna kolejność listy jednostek (578 G3).
- 590 G1.
- vt+0x58 (+0x345), aktualizacja grafu po zmianie obiektów, filtry rodzajów A*.

## 16. Propozycja etapu 44

1. Klify: dynamiczny ślad (punkt przerwania na zapisie +0x04 pola (206, 193)) przy ładowaniu e35_a. Celem jest
   rodzaj pola 39 480/39 480 i graf z SCN zgodny strukturalnie.
2. Obiekty pól w Core: rejestracja obiektów SCN na polach (rozmiar z dbobjects) i flaga +0x612. Wtedy graf powstanie
   z samego SCN, a potyczka może go włączyć.
3. Czysta mapa: powtórzyć układ 590 (kontakt podczas walki) z rejestrem push i kontaktów oraz zamodelować czas umierania.
