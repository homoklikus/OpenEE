# Specyfikacja implementacji ruchu Titan w OpenEE (Godot) – etap 27

Dokument projektowy. Opisuje, jak zbudować w Godocie wierny system ruchu jednostki lądowej Titan na podstawie atlasu
(etapy 14–27). **To nie jest implementacja.** Kod Godota w etapie 27 nie był zmieniany.

**[Etap 28 – zmiana architektury]** Warstwa symulacji jest przenoszona do natywnego rdzenia **OpenEE Core (C++20)**,
podłączonego do Godota przez GDExtension. GDScript pozostaje warstwą integracji i prezentacji.
- Moduły z § 2 powstają jako klasy C++ w `cpp/core/` (`docs/cpp/ARCHITEKTURA_CORE.md`), a nie w
  `godot/silnik/symulacja/titan/`.
- Zasady z § 1 (własne obliczenia, f64 + jawne f32, brak fizyki i trygonometrii Godota, `WariantTitan`) obowiązują bez
  zmian. W C++ dochodzą flagi kompilatora i bariera `f32()` (`docs/cpp/BUDOWANIE.md` § 4).
- Pierwotny tekst specyfikacji zostaje poniżej jako historia decyzji.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Każdy moduł podaje źródło w atlasie i przypadki testowe z `testy_referencyjne_ruchu.md` (S1–S7 syntetyczne, M –
pomiarowe lokalne).

## 1. Zasady

1. **Symulacja oddzielona od renderowania.** Stan logiczny w obiektach `RefCounted`, bez węzłów sceny. Widok czyta
   macierz jednostki po takcie, tak jak oryginał (bez interpolacji: `zegar_symulacji.md`).
2. **Własne, deterministyczne obliczenia.** Nie używamy `CharacterBody3D`, `move_and_slide`, `NavigationAgent3D`,
   `NavigationServer`, `PhysicsServer` ani `atan2`/`sin`/`cos`/`acos` z Godota. Żaden z nich nie odtwarza:
   - jednostronnego odpychania zależnego od kolejności;
   - kwantowania kursu przez tablice;
   - dyskretnych dróg hamowania;
   - testu kroku po polach.
   Zgodności nie da się wykazać, więc nie wolno ich użyć w warstwie symulacji (dopuszczalne w widoku).
3. **Arytmetyka:** `float` GDScript (f64) jako odpowiednik rejestru x87 przy PC_53. Jawne zaokrąglenie do f32 w
   punktach zapisu z `precyzja_numeryczna.md` § 5. `Vector2`/`Vector3` (f32) tylko do przechowywania wartości już
   zapisanych jako f32, nigdy do obliczeń pośrednich.
4. **Warianty EE / AoC** jako jeden obiekt konfiguracji (`WariantTitan`): przesunięcia, reguła obrotu, kolejność
   odbudowy kontaktów, numery stanów. Bez rozgałęzień rozsianych po kodzie.
5. **Błędy oryginału zachowane** (BO-7, BO-8, BO-9′ jeśli potwierdzone) – `BLEDY_ORYGINALU.md`.

## 2. Moduły (proponowane, w `godot/silnik/symulacja/titan/`)

| Moduł | Odpowiedzialność | Źródło w atlasie | Testy |
|---|---|---|---|
| `MatematykaTitan` | `f32()`, `um_cos/um_sin/um_arccos/um_arctan2`, normalizacja kąta, `set_orientation_ypr` | `precyzja_numeryczna.md` § 2 | test bitowy na siatce ćwiartek, osi, 0, ±π (wartości z modelu referencyjnego), S4b |
| `TabliceDLL` | wczytanie tablic cos (16385) i acos (32769) z `Low-Level Engine.dll` użytkownika; suma kontrolna | § 2.5 | test obecności; brak tablic = test pominięty |
| `GeneratorTitan` | LCG s = (214013·s + 2531011) mod 2³¹, wynik s/2³¹; jeden obiekt globalny; licznik losowań | `kolizje_objazdy.md` § 5, § 6 tego dok. | sekwencja z ziarna, M: `rng_527.json` |
| `TerenTitan` | siatka wierzchołków, `GetMeshZ`, nachylenie z macierzy, przejezdność pól | `fizyka_terenu.md` § 1–4 | S6, S7, M: EE 517, EE 524 |
| `JednostkaRuch` | pola ruchu: P, macierz (m01, m11, m21 i pełna), v, ω, tryb, +0x248, +0x20C, +0x330, push, lista kontaktów, kolejka punktów | `ruch_jednostki.md` § 3 | – |
| `FizykaLadowa` | tryby 0/3/4/5: obrót, decyzja prędkości, ruch, reguła stoku, BO-7, test osiągnięcia punktu | `ruch_jednostki.md` § 5–8, `precyzja_numeryczna.md` § 5–6 | S1–S5a, M: EE 500, AoC 505, EE 517, AoC 525 |
| `TestKroku` | ślizg po osiach, komórka ze środkiem innej jednostki, +0x20C, +0x330 = 2 | `fizyka_terenu.md` § 4 | (brak izolowanego pomiaru – przypadek 11) |
| `KolizjeTitan` | lista kontaktów (odbudowa przy zmianie komórki), 0x549179, reguła (a), 0x549A08 | `kolizje_objazdy.md` § 2–4, `walidacja_kolizji.md` | 5 przypadków odpychania, M: EE 535, EE 536 |
| `MaszynaStanow` | wczytanie `.tai` z `data.ssa`, ocena przejść (≤ 1 na takt), akcje wejścia, BO-8 | `skrypty_stanow.md` | M: sekwencje stanów EE 500, EE 532 |
| `KolejkaCelow` | cele jednostki, Shift, aktywacja następnego celu (BO-4) | `kolejka_rozkazow.md`, `cele_jednostek.md` | (przypadek 9 – do zmierzenia) |
| `Nawigacja` | A* po polach, graf podsektorów, kolejka punktów trasy, objazd 9002 (okno ±50) | `astar_pola.md`, `astar_wyniki.md`, `architektura_nawigacji.md`, `kolizje_objazdy.md` § 6 | testy A* z etapu 24; objazd – brak |
| `GrupyRuchu` | grupa, parametry szyku (średnie vmax/a z k = 2,0 z `dbworld`), wyjście z grupy przy Idle | `grupy_ruchu.md`, `kolizje_objazdy.md` § 8 | M: EE 537 |
| `TaktTitan` | jeden takt symulacji w kolejności z § 3 | `zegar_symulacji.md`, `przydzial_taktow.md` | wszystkie |

Istniejące `jednostka_sym.gd`, `sciezki.gd`, `polityka_ruchu.gd` i `formacja_ee.gd` to uproszczone modele z etapów
5–9. Nowe moduły powinny powstać obok i zastąpić je dopiero po przejściu testów referencyjnych, z możliwością
przełączenia. Decyzja o usunięciu starych należy do etapu wdrożenia.

### Reprezentacja jednostki

- Pozycja i macierz orientacji 3×3 jako f32 (`PackedFloat32Array`). Kurs **zawsze** czytany z macierzy przez
  `um_arctan2(−m01, m11)`, nigdy przechowywany osobno.
- Pola liczników i flag nazwane według przesunięć oryginału w komentarzu (np. `licznik_blokady_ms  # +0x248`), żeby
  porównanie z pomiarem było mechaniczne.
- Kolejka punktów trasy: deque punktów f32 i suma długości odcinków (R = pozostała długość) w f32, liczona tak jak
  0x5EC655.

## 3. Kolejność jednego taktu (z Titan)

Źródła:
- `zegar_symulacji.md`, `przydzial_taktow.md` – kiedy takt się wykonuje;
- `ruch_jednostki.md` § 2 i § 5 – pętla jednostek i tryby;
- `fizyka_terenu.md` § 5 – zapis i kontakty;
- `kolizje_objazdy.md` § 1 – krok końcowy.

```
0. Przed taktem (wątek symulacji): komunikaty lockstep z rozkazami gracza/AI wykonują się jako komendy
   (rozkazy → KolejkaCelow, przydział szyku, A*) – `rozkazy_gracza.md`, `kolejka_rozkazow.md` [W].
1. Takt EEPhysics (EE 0x546C63 / AoC 0x553082):
   a. czas gry += 34,0909 ms (PH+0xD0), licznik taktów;
   b. losowania globalne co takt: co najmniej 2 (EE 0x546CE9, 0x547C09) [P: ≥ 2 kroki LCG na takt bez ruchu];
   c. pętla jednostek OD KOŃCA listy (0x547AAD; AoC 0x55401E). Dla każdej jednostki u (0x547E0E):
      i.   jeśli !u+0x33B: krok maszyny stanów – co najwyżej jedno przejście + akcja wejścia
           (zdjęcie punktu, wyczyszczenie trasy, ustawienie trybu). Ocena zdarzeń może losować:
           ObstacleDetected w Advance – 1 losowanie na takt (gdy punkt nieosiągnięty i +0x20C == 0),
           wejście w Idle – 2 losowania (warunkowo) [W/P];
      ii.  aktualizacja typu (vt+0xB4) → switch trybu ruchu (0x549F82):
           tryb 0: obrót → decyzja prędkości (nachylenie z macierzy sprzed ruchu) → v′ → ruch po nowym kursie
                   → test kroku → z = GetMeshZ → pochylenie (typ+0x5F3/+0x5F4) → test osiągnięcia punktu
                   (d sprzed ruchu) → zapis macierzy i komórki;
                   EE: odbudowa kontaktów po zapisie (od nowej pozycji);
                   AoC: odbudowa kontaktów przed zapisem (od starej pozycji);
           tryb 4 / 5 / 3: jak w `ruch_jednostki.md` § 5;
      iii. krok końcowy (vt+0x48, oprócz trybu 2): jeśli są kontakty lub +0x248 > 0 i jednostka się rusza
           albo ma push ≥ 0,001: kolizje 0x5498C4 (dla każdego kontaktu 0x549179, push zapisywany od razu
           do drugiej jednostki) → zastosowanie 0x549A08 (ruch o push·dt z kontrolą pól, +0x248 += ms,
           push = 0); inaczej +0x248 = 0.
   d. pozostałe systemy symulacji (AI graczy, produkcja, walka – poza zakresem; korzystają z tego samego RNG).
2. Po takcie: widok czyta macierze jednostek.
```

- Push nadany jednostce już przetworzonej w tym takcie zostaje zużyty dopiero w jej kolejnym takcie [W].
- Kolejność listy jednostek to kolejność tworzenia obiektów (bufor 0x918DDC), z usuwaniem przez przesunięcie [W].
  Porządek w OpenEE musi być identyczny, inaczej rozjadą się kolizje i RNG.

## 4. Matematyka (odsyłacze)

| Element | Wzór | Gdzie |
|---|---|---|
| prędkość liniowa | decyzja 0x548645: reguła 45°, R ≤ S, reguła stoku; v′ ± a·dt, obcięcia, BO-7 | `ruch_jednostki.md` § 6, `precyzja_numeryczna.md` § 5 |
| obrót | EE: S_rot vs \|diff\|; AoC: 0x554F56 / 0x554738 | `precyzja_numeryczna.md` § 6 |
| hamowanie | dyskretne drogi S = ½k(k+1)a·dt², S_rot = ½n(n+1)α·dt² | `ruch_jednostki.md` § 6–7 |
| nachylenie | asin(Δz/1,3) przez UMArcCos, punkty P ± 0,65·oś przodu | `fizyka_terenu.md` § 2 |
| wysokość | GetMeshZ – interpolacja trójkątna na siatce wierzchołków | `fizyka_terenu.md` § 1 |
| kolizje | dx² + dy² ≤ ((ru + ro)/2)² | `kolizje_objazdy.md` § 3 |
| odpychanie | m = (S² − d²)·ru/ro, wagi kwadratowe, jednostronne, budzik, odbicie −2·push | `walidacja_kolizji.md` § 2 |
| porównania | d < 0,05 na wartości z rejestru; S < 1e-4; v′ < 0,005; \|push\| < 0,02 | `precyzja_numeryczna.md` § 5 |

## 5. Determinizm

- **Stały takt:** dt = f32(1,5/44) s gry, 34,0909 ms. Bez podkroków i bez zależności od FPS [P].
- **f32 i x87:** § 1 pkt 3. Testy bitowe w `TestyRuchuTitan` (S1–S7).
- **Kolejność jednostek:** od końca listy. Push do innych jednostek zapisywany natychmiast.
- **Globalny RNG** [P]:
  - jeden LCG współdzielony przez symulację i AI;
  - ziarno przy rozpoczęciu gry z `TMGetTime` (QPC/timeGetTime) w `EEMStartLoading` (EE 0x4BEE9D), zapisywane w zapisie
    gry;
  - w pomiarze ok. 15–40 losowań na takt w całej grze;
  - 7 startów tej samej mapy z powtarzanymi krokami dało identyczne stany generatora w tych samych chwilach gry
    (np. t = 21545 ms → 1789804865), a trajektorie LCG z różnych przebiegów nakładają się (przesunięcie 342 kroków).
    Symulacja jest deterministyczna przy tym samym ziarnie i tych samych wejściach.
- **Kolejność wywołań:** każda zmiana kolejności losowań (np. pominięcie ObstacleDetected dla jednostki w ruchu)
  przesuwa sekwencję dla całej gry. OpenEE musi losować w tych samych miejscach, także tam, gdzie wynik nie jest używany.
- **EE / AoC:** `WariantTitan` (§ 1 pkt 4). Testy dla obu wariantów.
- **Źródła desynchronizacji** (lista kontrolna):
  - użycie funkcji trygonometrycznych Godota;
  - obliczenia w `Vector2`;
  - inna kolejność jednostek;
  - brak losowań w Idle/Advance;
  - odbudowa kontaktów w złej kolejności;
  - zaokrąglenia przy `int()` zamiast rint;
  - iteracja po słowniku zamiast po liście;
  - czas rzeczywisty zamiast czasu gry.

## 6. Testy i kolejność wdrażania

| Krok | Moduł | Zależy od | Kryterium przejścia |
|---|---|---|---|
| 1 | `MatematykaTitan`, `TabliceDLL` | – | bitowa zgodność um_arctan2/um_cos z modelem referencyjnym; S4b |
| 2 | `GeneratorTitan` | – | sekwencja LCG; losowania w miejscach z § 3 (co najmniej 2 na takt: 0x546CE9, 0x547C09) |
| 3 | `TerenTitan` | 1 | GetMeshZ i nachylenie na terenie syntetycznym (S6/S7) |
| 4 | `JednostkaRuch` + `FizykaLadowa` (tryby 0/4/5/3) | 1, 3 | S1–S5a, S6, S7 bitowo; EE 517 i AoC 525 lokalnie |
| 5 | `MaszynaStanow` (land.tai) | 4 | sekwencja stanów 10003 → 9000 → 2015 → … → 9006 → 5001 → 5000 jak w EE 500 |
| 6 | `KolizjeTitan` | 4 | 5 przypadków odpychania; EE 535 (push 4 takty) |
| 7 | `TestKroku` | 3, 6 | przypadek 11 – po uzyskaniu pomiaru |
| 8 | `KolejkaCelow`, Shift | 5 | przypadek 9 – po uzyskaniu pomiaru |
| 9 | `GrupyRuchu` | 4, 8 | EE 537: k = 0,7 / 0,6, przeliczenie po wyjściu jednostki |
| 10 | `Nawigacja` (A* już opisane) + objazd 9002 | 5, 6, 7 | objazd – po potwierdzeniu dynamicznym |

Kroki 1–6 można wdrażać niezależnie od niewiadomych z § 7. Kroki 7–10 wymagają dalszych pomiarów albo zostają z
flagą „niezweryfikowane”.

## 7. Elementy niegotowe (muszą zostać oznaczone w kodzie)

- objazd 9002 i ObstacleDetected po progu +0x248 – brak pomiaru [N];
- dwie jednostki w ruchu i różnica kontaktów EE/AoC – reguła z kodu [W], bez pomiaru;
- duże jednostki (rozmiar ≥ 1, 0x548A3C) – [H];
- Shift i aktywacja następnego celu – [W], bez pomiaru w etapie 27;
- znak drgania ω w EE 500 (max 0,05 pola) – [N];
- jednostki pływające i latające – poza zakresem.

## 8. Aktualizacja etapu 28 – stan wdrożenia w C++

| Krok § 6 | Moduł C++ | Stan | Testy |
|---|---|---|---|
| 1 | `MatematykaTitan`, loader tablic (`tablice_dll`) | wdrożony | `core_trygonometria`, `core_dll` – bitowo |
| 2 | `GeneratorTitan` | wdrożony (losowania w Idle [N]) | `core_rng` |
| 3 | `TerenSiatka` | wdrożony (teren syntetyczny) | `core_teren` |
| 4 | `Jednostka` + `FizykaLadowa` (0/3/4/5, EE/AoC) | wdrożony | `core_ruch` S1–S7 bitowo, Debug = Release |
| 5 | maszyna stanów (parser podzbioru `.tai`, skrypt `land`) | częściowy (zdarzenia walki → fałsz) | `core_tai`, sekwencje stanów w S1–S7 |
| 6 | `KolizjeTitan` | tylko wzór 0x549179 | `core_odpychanie` |
| 7–10 | test kroku, kolejka celów, grupy, nawigacja | niewdrożone – interfejsy w `interfejsy.hpp` | – |
| **etap 29** | A* + Bounded, test kroku, kolizje w takcie, kolejka celów, 9002 (niezweryfikowany) | wdrożone / częściowe | `core_astar`, `core_krok`, `core_kolizje_takt`, `core_kolejka`, `core_scenariusze`, `core_porownanie_gra` |

Integracja i scena diagnostyczna: `docs/cpp/INTEGRACJA_GODOT.md`. Testy przez Godota:
`godot/testy/testy_gdextension.gd`.
