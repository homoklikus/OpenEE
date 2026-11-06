# OpenEE – formaty, etap 4: animacje CEM, sekwencje dbgraphics, hierarchia części

Oznaczenia: **[D]** potwierdzone na danych (wszystkie modele/rekordy instalacji GOG EE + AoC), **[K]** potwierdzone w kodzie
gry (analiza w Ghidrze – opisy własnymi słowami, bez kodu), **[H]** hipoteza OpenEE, **[?]** nieustalone.
Narzędzie: `narzedzia/analiza_animacji.py <instalacja> wyniki/analiza_animacji.json` (wynik lokalny, niepublikowany).

## 1. Animacja w CEM – klatki kluczowe pełnej geometrii [D]
Statystyka (data.ssa EE / AoC): 730 / 136 modeli, wszystkie dekodowane bez błędów; 234 / 42 z animacją wierzchołkową,
128 / 27 z częściami potomnymi, 478 / 89 z punktami tag; 1 klatka: 484 / 93 modele; maksimum 92 / 99 klatek.

* **Brak szkieletu i wag kości.** Każda klatka CEM 2.0 zawiera komplet `wierzchołki × (pozycja, normalna, UV)`, punkty
  tag (3 f32 każdy), macierz 4×4 części i AABB. 1.3 (11 modeli EE): pozycje punktów, kwantowane normalne (u16, nie
  dekodowane – OpenEE liczy normalne płaskie na klatkę), tagi, macierz, AABB.
* UV nie zmienia się między klatkami w żadnym modelu (0/866) – OpenEE bierze UV z klatki 0.
* Macierz korzenia jest jednostkowa we wszystkich klatkach wszystkich modeli (866/866) – ruch całej jednostki nie jest
  zapisany w modelu.
* Punkty tag poruszają się w 198 modelach (np. `attack` – punkt wylotu pocisku, `weapon_mount_*`, `impact_*`).
* Format nie zapisuje czasu ani nazw sekwencji – te pochodzą z `dbgraphics` (§2).

## 2. Sekwencje animacji w `dbgraphics` [D]
Jeden rekord dbgraphics = jeden model (`Model path`); sekwencje to **zakresy klatek tego modelu**. Przykład falanga
(`men_phalanx_04`, 75 klatek): 0–15, 16–31, 32–47, 48–74 (+ 74–74) – pokrywają dokładnie 75 klatek.

### 2.1 Układ pól (po `Name`, `Sequence number`, `ID`)
```
3 × i32 nagłówek
12 gniazd; gniazdo g: S sekwencji × [flagi, klatka_od, klatka_do, wartość, pętla, parametr]
                       + 2 × i32 klatki zdarzeń + 2 × i32 ID dbsounds (pola „Sound ID” w schemacie EE DB Editor)
S = 3 dla gniazda 4, S = 1 dla pozostałych; za gniazdem 11: pola końcowe (nieużywane przez OpenEE)
```
* `flagi` i `pętla` – znaczące są niższe bajty; wyższe bywają przypadkowe (np. 0x6C0101, 0x670100) – maska 0xFF/0xFFFF.
* Klatki zdarzeń wskazują klatkę w obrębie sekwencji, na której gra dźwięk o tym samym indeksie, np. obywatel:
  chód 0–15, zdarzenia 8 i 15 → „Walk1”, „walk2” (kroki); atak falangi 16–31, zdarzenie 26 → „Sword Fight 3”.
* 1493 sekwencje (EE) – 99,7 % zakresów mieści się w modelu; wyjątki: `men_femcitizenone_02/04/10` (gniazdo 8:
  48–61 przy 59 klatkach – błąd danych gry), `waypoint`, `xbox` (modele pomocnicze).
* Sekwencja pusta: `od = do = wartość = 0` i brak dźwięków. Zakres jednej klatki ≠ 0 (np. 74–74 po śmierci) istnieje.

### 2.2 Znaczenie gniazd – wyłącznie z danych
Przypisanie z dźwięków dbsounds powiązanych z gniazdami (858 rekordów EE):

| Gniazdo | Stan OpenEE | Dowód | Pewność |
|---|---|---|---|
| 0 | `atak` | Gun (missile) 31×, Arrow 21×, ArcherAttack 16×, Machine Gun 11×, Bomb 11×, Catapult Shot 8× | [D] |
| 1 | `ruch` | Horse Trot 34×, Boat Move (row) 21×, Mech Footfall 37×, Ship Movement 14×, Tank moving 12× | [D] |
| 2 | `bezczynnosc` | Helicopter (rotor) 5×, Heli – Nano 3×, Mech shutdown, Hover Move; pętla, ten sam zakres co gniazdo 3 | [D/H] |
| 3 | `gniazdo_3` | ten sam zakres klatek co 2, inne tempo; u części jednostek Arrow, Convert, Catapult Shot | [?] |
| 4 | `smierc`, `po_smierci_1`, `po_smierci_2` | jednorazowa (pętla 0 w 194/381), ostatnie klatki modelu, potem pętla jednej klatki | [D] |
| 5–11 | `czynnosc_N` | zależne od rodzaju jednostki: obywatel – 6 Mining, 7 forage, 8 Farm, 9 Chopping wood, 10 Build, 11 Walk1/walk2; kapłan – 6 Convert; bohater – 5 Battlecry | [D] |

OpenEE nie nadaje gniazdom 3 i 5–11 nazw ogólnych – scena diagnostyczna pokazuje przy nich nazwy dźwięków z dbsounds.

### 2.3 Tempo – pole „wartość” [H]
Przyjęte: **czas cyklu sekwencji = wartość × 0,01 s** (`SekwencjeAnimacji.CZAS_JEDNOSTKA`), tempo = klatki / czas.
* Za: wszystkie sekwencje mieszczą się wtedy w 0,6–4 s (chód falangi 0,65 s, atak 1,2 s, śmierć 0,78 s, wiosła triremy
  4 s, strzał armaty 1,8 s); wartość 0 występuje tylko w sekwencjach jednej klatki.
* Przeciw prostemu „czasowi proporcjonalnemu do liczby klatek”: korelacja liczba klatek ~ wartość = −0,33 (mediany:
  2–5 klatek → 200, 11–16 → 120, 17–30 → 105) – krótkie sekwencje to zwykle wolne pętle mechaniczne.
* Alternatywa niewykluczona: wartość = klatki/s × 10. Rozstrzygnięcie wymaga porównania z uruchomioną grą.
* `parametr` (np. 50000 w ataku, 7500/5000 w gniazdach 2/3, 1000/400 w pracach) – [?].

## 3. Hierarchia części [D]
* Część potomna = zagnieżdżony model SSMF (po klatkach rodzica); głębokość w danych: 1 (346 części), kod obsługuje
  dowolną.
* Wierzchołki części są **lokalne** (koło armaty `gun_bronze_09` wyśrodkowane w 0, promień 0,42). Macierz klatki
  (16 f32 wierszami, przesunięcie w elementach 3, 7, 11) umieszcza część u rodzica: `v' = D·v + t`. Kontrola: koło
  w (0,29; 0,47; 0,40) dotyka ziemi (najniższy punkt −0,018); wieżyczka półgąsienicówki na wysokości 0,48.
* Klatki części = klatki rodzica (66 części z ruchem macierzy – koła, wieżyczki) albo 1 (statyczna).
  Klatka części dla klatki modelu k: `min(k, klatki_części − 1)`.
* Dziedziczenie: `T_global(i, k) = T_global(rodzic, k) · T_lokalna(i, k)` – położenie, obrót i skala. Macierze klatki 0
  części są prawie ortonormalne: 1022/1038 wierszy o długości 1 ± 0,01, pozostałe 0,9–1,11 (niewielka skala w części
  modeli) – OpenEE przenosi skalę bez zmian.
* Konwencja nazw części (sterowanie przez silnik): `wheel` 80×, `turret_N` 58×, `orbital_cw_<n>_<i>` 91×,
  `orbital_ccw_<n>_<i>` 82×, `gate` 17×, `ball` 14×. Obrót `orbital_*` **nie jest zapisany w klatkach** (macierz stała
  w szczurach, flagach, Posejdonie) → obraca je silnik [H: `<n>` = prędkość]. Celowanie wieżyczek i toczenie kół
  podczas ruchu po mapie – sterowanie proceduralne, poza zakresem etapu.
* Do przekształceń osi: CEM (Z w górę) → Godot `P(x, y, z) = (x, z, −y)`; macierz części w Godocie = `P·D·P⁻¹`, `P·t`.

### 3.1 Obserwacje dotyczące skrętności (niekonkluzywne)
* Toczenie koła armaty w klatkach ataku oraz kierunki obrotu części `orbital_cw/ccw` w `gun_tempest_13` są w
  interpretacji prawoskrętnej odwrotne do oczekiwanych – zgodne z układem lewoskrętnym (D3D) [H].
* ~~Punkt `attack` piechoty leży głównie po stronie −Y (79/129 modeli) → przód jednostek to −Y modelu~~ – **sprostowane
  w etapie 5**: średnia obejmowała klatki śmierci; w klatkach ruchu/ataku/bezczynności `attack` leży po +Y, a stopa
  podparta w chodzie przesuwa się w −Y ⇒ przód = +Y (FORMATY_ETAP5 §3). Strona broni (±X) nie rozstrzyga lustrzaności.
* ~~OpenEE **nie zmienia** układu osi – kwestia pozostaje otwarta (porównanie z grą).~~ **Rozstrzygnięte w etapie 7**
  (RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md): gra pokazuje świat (x = kolumna, y = wiersz, z = góra) jako układ
  prawoskrętny, a modele CEM są w tym samym układzie co świat (L = I). Dawne mapowanie świata C(x, y, z) = (x, z, y)
  było odbiciem – mapa OpenEE była lustrzana. Obecnie W(x, y, z) = (x, z, −y) (obrót, = P siatek), jedyna warstwa:
  `UkladEE`.

## 4. Woda [K + H]
* Teren wody (dbterrain ID 46, `Available = 1` – animowany): klatki = TilesX·TilesY = 16 plików
  `Water_OceanB_1…16.sst` [D]; pola „<Used by animated terrains>” = 100 i 4 mają **tylko** woda [D].
* OpenEE: klatka = floor(czas / 100 ms) mod 16 [H: 100 = ms na klatkę]; przezroczystość przy brzegu bez zmian (alfa 0/0,5
  wg bitów lądu, etap 3 [K]).
* Wybór materiału z tabeli 33×33 wg (c mod 33, r mod 33) [K, etap 3] – zawartość tabeli nieodtworzona; OpenEE: jedna
  faza dla wszystkich pól.
* **Poziom wody [K, częściowo]:** gra wywołuje `SetGlobalWaterState(…, poziom)` z poziomem
  `−(skala_wysokości × liczba całkowita z rekordu terenu wody)`. Które pole dbterrain trafia do tej liczby (kandydaci:
  TilesY = 1, „<Used by animated terrains>” = 4 lub 100) – [?]; OpenEE pozostawia poziom 0.
* Ściany na krawędziach mapy (Generate*EdgePolygons) – nie zaimplementowane.

## 5. Odtwarzanie w OpenEE
* Interpolacja liniowa pozycji i normalnych między sąsiednimi klatkami (w pętli ostatnia → pierwsza; sekwencja
  jednorazowa zatrzymuje się na ostatniej) [H – czy EE interpoluje, nieustalone; wyłączalna]. Transformacje części
  w scenie diagnostycznej: obrót sferyczny, przesunięcie liniowo.
* Wypiekanie do tekstury (VAT): wierzchołki wszystkich części po przekształceniu hierarchią; tekstura RGBAF,
  szerokość ≤ 2048, wiersze: (klatka, pozycja/normalna). Falanga: 178 wierzchołków × 75 klatek → 178 × 150 px.

## 6. Dekompresja DCL – pomiary i zmiana
Pomiar (falanga, 450 608 B po rozpakowaniu): odczyt+DCL 173,7 ms, parsowanie CEM 13,9 ms, wypiekanie 23,8 ms →
DCL = 82 % czasu importu modelu. Zmiana w GDScript (bez C++): dekodowanie Huffmana tablicą 13-bitową zamiast bit po
bicie, lokalny bufor bitów, kopiowanie dopasowań `append_array`. Wynik bajt w bajt identyczny z dekoderem wzorcowym
i z Pythonem (testy E1 i E4); 3,0× szybciej (1,82 MB: 153 ms zamiast 454 ms); falanga: 65,8 ms. Dekoder wzorcowy
zachowany (`DCL.rozpakuj_strumien_wzorcowy`). Dalsze przyspieszenie (GDExtension lub pamięć podręczna rozpakowanych
danych w `cache/`) – dopiero gdy wczytywanie okaże się wąskim gardłem przy pełnych mapach.
