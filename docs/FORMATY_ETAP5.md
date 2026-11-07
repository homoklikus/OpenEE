# OpenEE – formaty i reguły, etap 5: przechodniość terenu, ruch jednostek

Oznaczenia: **[D]** potwierdzone na danych instalacji (GOG EE + AoC), **[K]** w kodzie gry, **[H]** hipoteza/przybliżenie
OpenEE, **[?]** nieustalone. Porównanie z uruchomioną grą nie było możliwe (§6).

## 1. Teren mapy jako podstawa nawigacji [D]
* Mapa scenariusza (kawałek 4) to romb: `N = A + B` wierszy pól, każdy wiersz ma zakres kolumn; pole = 1 jednostka
  świata (x = kolumna, y = wiersz); poza zakresem – granica mapy (Troja: 38 920 z 78 400 pól siatki N×N).
* Punkty siatki (narożniki pól) mają wysokość (f32) i bajt **klasy punktu**. Klasy leżą w zakresach typów terenu z
  `dbterraintype` (kolumny `Unknown`/`Unknown#2`): Grass 40–47 (0x28), Beach 8–15 (0x08), Ocean Water 168–175 (0xA8) …
* **Woda – poziomy głębokości:** klasy 0xA8…0xAF to kolejne poziomy głębokości punktów wody (Troja / Rzym, mediany):
  A8 −0,20 · A9 −0,41 · AA −0,61 · AB −0,82 · AC −1,0 · AD −1,2 · AE −1,6 · AF −2,4…−2,9. Wszystkie punkty wody leżą
  poniżej 0 (najwyższy punkt A8: −0,035), punkty plaży (0x08) około 0 ⇒ **poziom wody = 0** [D] – rozstrzyga kwestię
  z etapów 3–4 (pole źródłowe liczby w formule `SetGlobalWaterState` z etapu 4 nadal [?]).
* Klify: pola z teksturą z `dbcliffterrain` (pary „\\” i „/”) [D: tekstura]. Tekstury klifów należą w `dbterrain` do typu 5
  („Snow – Grass Patches”, klasy 0x98–0x9F).

## 2. Przechodniość dla jednostek
### 2.1 Flagi nawierzchni w `dbobjects` [D]
18 flag bajtowych (od pola „dbterrain.dat Grass, Snow”): 0 Grass/Snow, 1 Elevation: Deep water,
2 Rock/Stones/Artificial, 10 Asphalt, 11 Elevation: cliffs, 12 Elevation: Shallow water, 14 Sand, 15 Space; pozostałe
bez opisu w schemacie. Dane:

| Obiekt | Grass | Deep water | Cliffs | Shallow water | Speed | Obrót w miejscu / w ruchu |
|---|---|---|---|---|---|---|
| Citizen (ID 32) | 1 | 0 | 0 | 1 | 0,50 | 12,2 / 14,0 |
| Inf04 – Phalanx (ID 25) | 1 | 0 | 0 | 1 | 0,60 | – |
| Cav04 – Bronze Spear Cavalry | 1 | 0 | 0 | 1 | 0,80 | – |
| Tank Mk V | 1 | 0 | 0 | 1 | 0,70 | 3,5 / 1,7 |
| s04 Bronze Catapult Ship | 0 | 1 | 0 | 1 | 0,50 | – |

Także: „Can walk through trees” (0 dla piechoty i kawalerii), „Size of collider”, „Circle selection size”.

### 2.2 Kategorie OpenEE (MapaNawigacji) i polityka (PolitykaRuchu)
| Kategoria pola | Reguła | Flaga dbobjects | Pewność |
|---|---|---|---|
| POZA | poza rombem mapy | – (zawsze blokuje) | [D] |
| GLEBOKA | narożnik wody o poziomie ≥ 1 (A9…AF) | 1 Deep water | [D] klasy; **[H] próg** |
| PLYTKA | wszystkie narożniki wodne na poziomie 0 (A8) lub ląd z narożnikiem A8 | 12 Shallow water | [H] próg |
| KLIF | tekstura dbcliffterrain | 11 cliffs | [D] tekstura, [H] przypisanie flagi |
| LAD | pozostałe | 0 Grass/Snow | [H] – nawierzchnie lądowe nierozróżniane |

* Przeszkody: obiekty scenariusza o Unit type 1 (zasoby, w tym drzewa), 2 (budynki, mury), 24, 25 (bramy), 29, 30 –
  koło o promieniu „Size of collider” [H: promień w polach] (koszary i centrum miasta 2,0, dom 1,0, drzewo 0,5). Drzewa
  osobno – pomijane przez jednostki z „Can walk through trees”.
* **Nachylenie:** brak progu (nie jest znany) – różnica wysokości zwiększa koszt trasy (`koszt_wysokosci` = 1) [H].
* Siatka: 2 komórki na bok pola (przeszkody dokładniejsze niż pole, granice wyrównane do pól). Troja: 560×560 komórek.

## 3. Ruch [H, poza zaznaczonymi]
* `Speed` = pola/s. Kontrola: przesuw stopy podpartej w chodzie / czas cyklu z dbgraphics daje 0,38–1,1 pola/s przy
  Speed 0,5–0,6 – zgodny rząd wielkości, nie rozstrzyga.
  **[Etap 13.5 – zastąpione]** Etap 9 / 13: `Speed` = pola na sekundę **czasu gry**; czas gry płynie 1,461 × szybciej
  niż rzeczywisty, więc w polach/s rzeczywistych prędkość = `Speed` × 1,461 (`docs/MECHANIKA_PREDKOSCI_EE.md`).
* `Idle/Moving turning speed` = rad/s. Obrót w miejscu, gdy różnica kursu > 45°, potem ruch z dalszym obrotem.
* Stały krok symulacji 0,05 s (20 taktów/s) – częstotliwość symulacji EE nieustalona.
* **Przód modelu = +Y modelu [D].** Dowody:
  * stopa podparta w animacji chodu przesuwa się w −Y (falanga, obywatel, kawaleria);
  * punkt `attack` w klatkach ruchu, ataku i bezczynności leży po stronie +Y (+0,04…+0,15).

  **Sprostowanie etapu 4:** wniosek „przód = −Y” wynikał z uśrednienia położenia punktu `attack` razem z klatkami
  śmierci (do −0,92, zwłoki padają do tyłu). Kurs θ dla kierunku d: `θ = atan2(−dx, dy)`. Test integracyjny:
  `attack` po transformacji wskazuje kierunek ruchu w 24/24 próbkach.
* Kurs początkowy jednostek ze scenariusza – z macierzy GETransformation (etap 3). Pole `angle` nie jest używane.

## 4. Wyznaczanie tras
A* na komórkach:
* 8 sąsiadów, bez ścinania narożników przeszkód;
* heurystyka oktylowa;
* koszt kroku = długość + |Δh|;
* składowe spójności na politykę: cel w innym obszarze → „nieosiągalny” bez przeszukiwania;
* wygładzanie skrótami widocznymi i nie droższymi (z wysokością).

Odrzucenia z przyczyną:
* cel poza mapą;
* cel niedostępny (nawierzchnia, przeszkoda, drzewa);
* cel nieosiągalny.

Jednostka pozostaje wtedy na miejscu, a przyczyna trafia do dziennika symulacji.

## 5. Animacje w ruchu
Stan symulacji przekłada się na sekwencję `dbgraphics` (etap 4):
* „ruch” → gniazdo 1;
* „bezczynnosc” → gniazdo 2, a gdy go brak – gniazdo 3.

Gdy sekwencji brak, jednostka porusza się dalej, a brak zostaje zapisany w diagnostyce. W Troi 17 z 18 ruchomych typów
ma sekwencję ruchu; `gun_stonethrower_03` nie ma sekwencji bezczynności.

## 6. Porównanie z oryginalnym EE – przeszkoda techniczna
Przygotowano izolowane środowisko (`narzedzia/eksperymenty/izolowane_ee.sh`, `izolowane_ee_sesja.py`):
* przenośne Wine (Kron4ek 10.0 WoW64; 11.20 kończyło się błędem segmentacji już przy starcie);
* osobny prefiks;
* osobny Xvfb;
* kopia gry w katalogu tymczasowym;
* wejście tylko przez XTEST do Xvfb.

Autor projektu wyraził zgodę na uruchomienie. Wynik: proces gry kończy się sygnałem **„Bad system call”**. Piaskownica
maszyny wirtualnej ma filtr seccomp, który blokuje wywołania systemowe potrzebne Wine do wykonania 32-bitowego kodu
EE w trybie WoW64. Filtr jest granicą bezpieczeństwa środowiska i nie był obchodzony. Gra nie uruchomiła się, więc
zrzutów do porównania brak. Środowisko zostało usunięte.

Skrypt można użyć na komputerze bez takiego filtra – osobny DISPLAY Xvfb i prefiks, bez dostępu do pulpitu.
