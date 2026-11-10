# Raport – etap 40: graf podsektorów Titan, osiągalność celu i pełne odtworzenie dwóch gwardii

Etap 40 odczytał graf podsektorów z pamięci oryginalnego EE i wyjaśnił pochodzenie punktu (163,5; 103,5). Do Core
weszły A* grafu (0x4A5807), wstawianie punktów pośrednich (0x4A26E3), zdejmowanie ich zdarzeniem 9016 oraz
osiągalność 0x62D696. Z grafem odczytanym z gry druga gwardia (0x1000858) zgadza się z grą w każdym takcie całych
nagrań 619, 620 i 616, łącznie z kolejką celów. Budowy podsektorów (podziału mapy) nie odtworzono – graf jest
wczytywany z gry w jawnym trybie diagnostycznym.

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.

## 1. Commit początkowy i końcowy

- Początek: `6535f00` (lokalny etap 39). GitHub bez zmian (`c776a61`).
- Koniec: jeden lokalny commit etapu 40 (`git log -1`). Bez push, pull, fetch, reset i rebase.
- Poza commitem: `godot/project.godot` i `konfiguracja/uzytkownik.cfg.przed_etapem11` użytkownika.
- Riverlands_MCP: nowy moduł `ee_podsektory.py`, rejestracja w `ee_diag.py`, zmiany z etapu 39 w `ee_walka.py` –
  lokalnie, niezatwierdzone w jego repozytorium.

## 2. Struktury grafu podsektorów

Pełny opis: `docs/titan/architektura_nawigacji.md`, sekcja „Etap 40”.

```
EEAIContinentManager 0x917BC8 (vtable 0x8261FC)
 ├─ +0x5C wektor EEAIPathSubSector* ─┬─ +0x10 U2DSparseArrayPointContainer (pola: kolumny → przedziały y)
 │                                   ├─ +0x2C sąsiedzi (wskaźniki)
 │                                   ├─ +0x3C/+0x40 punkt reprezentatywny (pole, int)
 │                                   ├─ +0x44 sektor → +0x40/+0x44 komórka siatki, +0x48 id
 │                                   └─ +0x50 id (u16), +0x54 rodzaj
 └─ +0xDC siatka sektorów: komórka +0xE0 (19), +0xE8/+0xEC (15 × 15)
```

Odpowiedzi na pytania A1:
1. **Granice podsektorów** [W/P]: podsektor leży w jednym sektorze siatki 19 × 19. Nie musi być spójny (np. podsektor
   253 ma dwa rozłączne fragmenty). Kryterium podziału [N].
2. **Regiony**: siatka obszarów +0xF4 i kontynenty istnieją. Związek z podsektorami [N].
3. **Sąsiedztwo** [P odczyt]: lista wskaźników w podsektorze, także między niesąsiednimi sektorami. Sposób
   budowy [N].
4. **Punkty reprezentatywne** [P odczyt]: pole w podsektorze, np. 472 → (163, 103). Reguła wyboru [N].
5. **Różne grafy**: jeden zbiór podsektorów z polem rodzaju (w e35_a rodzaje 1 i 4). Filtr rodzaju w A* grafu
   (tablica celu +0x5C) [W]. Osobnych grafów nie znaleziono.
6. **Przeszkody** [W, z etapu 22]: przebudowa po zmianie obiektu mapy (0x4288A7 → 0x4A36F3 → 0x4278C3). Jednostki nie
   zmieniają grafu – 624: graf identyczny przed i po rozkazach [P].
7. **Tworzenie** [P]: przy wczytaniu mapy; przebudowa przy zmianie obiektów.
8. **Dane wyszukiwania** [W]: maszyna `EEAIAStarGraphMachine` (storage +0x28, cel +0x64, liczniki +0x10/+0x14/+0x18,
   flaga +0x24, wynik częściowy +0x94).

## 3. Odczyt z oryginalnej gry

- Narzędzie `podsektory(x0, x1, y0, y1, pola, maks)` w Riverlands_MCP.
  - Tylko odczyt; sprawdza vtable managera, spójność i limity wektorów oraz limit węzłów listy.
  - Zwraca id, punkt (i32 i f32 – poprawny jest i32), sektor, rodzaj, liczbę pól, sąsiadów i przebiegi pól.
- Zadanie 624 (e35_a): 1858 podsektorów, 56 w oknie 150–180 × 95–125, plik `Testy_MCP/e40/podsektory_e35_a.json`
  (lokalny).
- Flagi prośby: `+0x1C` = pochodzenie celu (gracz), `+0x1D` = etap grafu wykonany. Zapis rejestratora
  (`pochodzenie_1C`, `aktywny_1D`) i kod 0x4A2764.

## 4. 0x4A26E3 i 0x4A5807

[W: kod; P: zgodność 619/620/624 co takt]

**A* grafu (0x4A5807):**
- węzeł = podsektor;
- koszt: 1 w tym samym sektorze, 10 do sąsiedniego sektora w osi, 14 po przekątnej (0x41E584);
- heurystyka H = 10·Manhattan komórek sektorów;
- sąsiedzi rozwijani od końca listy;
- test celu (0x41E3C0): węzeł = cel albo sektor w odległości ≤ 1 od sektora celu i cel na liście sąsiadów węzła.

**Wynik (0x4A26E3):**
- lista od celu do startu;
- punkty i = 0 … n − 3 jako EEUGLocation z flagą +0x32 na czoło kolejki;
- +0x1D := 1 na celu, więc drugi PrepareToMove tego samego celu nie wstawia już punktu.

**Zdejmowanie punktu:** zdarzenie 9016 ShouldMoveToNextAutoWaypoint → 8021 GetNextAutoWaypoint → aktywacja celu
ataku (2016).

**Założenia [H]:**
- remisy F w A* grafu rozstrzygane LIFO;
- wszystkie rodzaje podsektorów dozwolone;
- limit 0x4A0CE8 pominięty (mały graf);
- gałąź 9016 „≤ 2N i bliski region” [N].

## 5. Pochodzenie punktu (163,5; 103,5)

[P]
- Pole celu ataku drugiej gwardii (164,105) w 619 i (163,105) w 624 należy do podsektora 472 o punkcie
  reprezentatywnym (163, 103).
- Gwardia stoi na polu (162,118) w podsektorze 523 (rodzaj 4). Pole jest nieprzejezdne – gwardia stoi w lesie od
  startu scenariusza.
- 523 nie ma 472 wśród sąsiadów, a 469 ma. Ścieżka grafu to 472 ← 469 ← 523, więc n = 3 i wstawiony jest punkt
  indeksu 0, czyli podsektora celu.
- Pierwsza gwardia startuje w 469 (sąsiad 472): ścieżka ma 2 podsektory, więc punktu brak.
- Przebieg w 624 co takt:
  1. 8000: punkt + atak; próby: punkt 1, atak 0;
  2. 2015 → 10003 → 9000 (trasa 1 punkt);
  3. zdjęcie punktu, 2016;
  4. drugi 8000 bez punktu;
  5. 9000 → 9006 → 5001 → 5002 → 2025 → 5000 (porzucenie).

## 6. Zmiany nawigacji w Core

- `GrafPodsektorow`, `Podsektor`, `szukaj_w_grafie`, `Swiat::etap_grafu`.
  - Etap grafu prośby jednostki przy PrepareToMove dla celu bez +0x32 i z +0x1D = 0.
  - Licznik prób zwiększany na celu z czoła po wstawieniu.
- 9016 ShouldMoveToNextAutoWaypoint (N z rozmiaru mapy) i 8021 GetNextAutoWaypoint.
- `aktywuj_cel`: cel ataku z kolejki → InitialAttackState 2016.
- Zwykły PPM: cel bez etapu grafu jednostki (+0x1D = 1) [P: brak punktów po PPM – nawigacja_wejscie pkt 3, 616;
  H: kto ustawia flagę]. Cel z Shift przechodzi etap grafu.
- A* po polach bez zmian.
- Graf z gry to tryb diagnostyczny: `diagnostyka().graf_z_gry`, status podsystemu „częściowy”.
- GDExtension 0.14.0: `ustaw_graf_podsektorow(dict)` (format odczytu MCP), `sciezka_grafu`, diagnostyka grafu.
- `odtworz_e35.gd --graf=…`, `--test-trasy=x,y`.

## 7. Status 0x62D696

[W: kod; P: przez zgodność 619/620/616]
- 0x409914 = kwadrat odległości pól (int); 0x406D5E = kwadrat odległości pozycji.
- T = max(zasięg², 2,0).
- Szybka prawda przy d² ≤ T.
- Inaczej A* Bounded w obwiedni ± 2·⌈max(LOS, T)⌉ z budżetem ≤ 0x23. Prawda, gdy węzeł końcowy jest w d² ≤ T od
  celu.
- Wdrożone (`Swiat::osiagalny_62d696`), założenie „osiągalny = prawda” usunięte.
- Jawne założenia:
  - typ+0x430 ≠ 0 i (typ+0x5D4 & 6) ≠ 0 [H];
  - 0x5ECAD0 = prawda [N];
  - garnizon nieobsługiwany.
- Przypadki rozróżniające:

  | Przypadek | Status |
  |---|---|
  | Otoczony atakujący | test GDExtension (synteza) i 619 [P] |
  | Cel bliski (szybka prawda) | 619 – obywatel [P] |
  | Cel za przeszkodą, cel na izolowanej części mapy, cel otoczony jednostkami | nie zmierzone [N] |

## 8. Czysta mapa testowa

- Wygenerowano `Testy_MCP/mapy/e40_czysta_baza.scn` (Riverlands 0.8.1: 64 × 64, 2 graczy, bez surowców i rzek).
  Odczyt: po 1 rekordzie na gracza, wersja SCN 250.
- Narzędzie `scenariusz_testowy_kolizji.py` kopiuje rekordy jednostek tej samej wersji (231). Brakuje wzorów jednostek
  w wersji 250, więc scenariusze obowiązkowe nie zostały zbudowane.
- **Priorytet D niewykonany** poza bazą. Plan na etap 41: wzory rekordów 250 (gwardia, bohater, obywatel) z mapy tej
  wersji albo kontrolowane usuwanie obiektów z kopii 231 z kontrolą listy obiektów.

## 9. Eksperymenty z wieloma jednostkami

- 624 [P]: druga gwardia w kolejce po pierwszej – miejsca podejścia zgodne z regułą 0x63234D z etapu 39.
  - Pierwsza wybrała (164,5; 105,025), druga (163,975; 105,025) – zajęte nie było.
- Nowych układów z 3+ jednostkami na czystej mapie nie było (§ 8).

## 10. Kolizje 590 G1

Bez nowego pomiaru [N]. Plan (etap 41): minimalna scena dwóch gwardii w kontakcie na czystej mapie i rejestrator z
odczytem wektora odpychania przed i po rozwiązaniu kontaktu (0x5EB1D5 / 0x549E61).

## 11. Pierwsze rozbieżne takty

| Przypadek | Etap 39 | Etap 40 |
|---|---|---|
| 619 0x1000858 | 124254 (kolejka 124117) | brak (7273/7273, kolejka bez różnicy) |
| 620 0x1000858 | 109423 (kolejka 109287) | brak (6419/6419) |
| 616 0x1000858 | 220671 (rozkaz nieodtwarzany) | brak (z rozkazem 220637) |
| 616/619/620/622 0x1000856 | brak | brak |
| 616 obywatel 0x1000857 | 136289 | 136289 (cel EEUGGather z MCP – poza Core) |
| Bohater (stany 5001/16000) | 79045 | 79045 (HP zgodne) |
| EE 578 G1 | brak | brak |
| EE 578 G3 | 169 (ω) | 169 (ω) |
| EE 590 G1 | 97 (ω) | 97 (ω) |
| EE 589 G3 | 1 | 1 |
| EE 580 G1 | 57 | 57 |
| AoC 505 | 803 | 803 |
| EE 500 | koniec +1 | koniec +1 |

## 12. Regresja

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | 38/38 (+4: graf ze słownika, A* grafu, punkt 0x4A26E3, porzucenie przez 0x62D696) |
| Godot | 325/325 |
| Riverlands_MCP | 16/16 |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| 578 G1 | 986/986 |
| Mapa | `c8297c16f0d48b1a` |

Nagrania z grafem z gry – stany, pozycja, macierz, kurs, v, HP, cele, kolejki i punkty pośrednie: bez rzeczywistych
różnic dla obu gwardii (wyjątki w § 11).

| Nagranie | Próbki spóźnione |
|---|---|
| 616 | 5 |
| 619 | 14 |
| 620 | 4 |
| 622 | 8 |

## 13. Potyczka Godot

Potyczka nie ma danych grafu, więc etap grafu jest w niej nieaktywny; 0x62D696 działa.
- Bitwy wygrane w taktach 1218 i 1289, restart działa.
- Scena 1 na 5 przegrana w takcie 756.
- Pięć jednostek na jeden cel bez zablokowania.

## 14. Niewyjaśnione

- Budowa podsektorów (0x42434F, 0x41E990), sąsiedztwo i punkty reprezentatywne [N]. Bez tego Core potrzebuje grafu
  z gry.
- Remisy A* grafu, filtr rodzajów i limit 0x4A0CE8 [H].
- Kto ustawia +0x1D dla celu zwykłego PPM (prośba grupowa) [H].
- 0x5ECAD0, flagi typu +0x430/+0x5D4/+0x600/+0x606 [N].
- Czysta mapa (wersja 250), 590 G1, Healer.tai [N].

## 15. Prognoza i etap 41

Walka wręcz małych grup na mapie e35_a jest teraz zgodna z grą co takt w czterech nagraniach, gdy graf pochodzi z gry.
Głównym brakiem w nawigacji jest budowa podsektorów.

Propozycja etapu 41:
1. Budowa podsektorów w Core: analiza 0x42434F/0x41E990 i porównanie z odczytem 1858 podsektorów e35_a (id, pola,
   punkty, sąsiedzi) jako test referencyjny.
2. Czysta mapa: wzory rekordów jednostek w wersji SCN 250 albo kontrolowane usuwanie obiektów; scenariusze 1–8 z
   briefu 40.
3. 590 G1 na czystej mapie z odczytem kontaktów.
4. Prośba grupowa i +0x1D zwykłego PPM; punkty +0x32 w ruchu grupy.
