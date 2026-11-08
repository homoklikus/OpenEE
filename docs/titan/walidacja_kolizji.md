# Walidacja kolizji, odpychania i objazdów w Titan – pomiary etapu 27 (EE / AoC)

Wpis atlasu z etapu 27. Sprawdza pomiarami model z `kolizje_objazdy.md` (etap 26). Kompilacje: `Empire Earth.exe`
e352d7ae…, `EE-AOC.exe` db8fc5ce…

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pomiary to zadania Riverlands_MCP `Testy_MCP/ee_zadania/527–541` (lokalne, poza repozytorium). Pola czytane co takt:
- pozycja +0x13C/+0x14C/+0x15C, macierz +0x134/+0x144;
- v +0x238, ω +0x17C, tryb +0x264 (AoC +0x268);
- licznik blokady +0x248, blokujący +0x20C, flaga +0x330 (AoC +0x33C);
- liczba kontaktów +0xC8, wektor push +0x230/+0x234;
- stan maszyny przez wskaźnik +0x1E8;
- stan generatora EEPhysics+0x18 i czas gry EEPhysics+0xD0.

## 1. Wynik w skrócie

| Pytanie | Wynik |
|---|---|
| Wzór odpychania 0x549179 | zgodny **dokładnie** z pomiarem (EE 535, 4 kolejne takty) [P] |
| Model jednostronny (pcha większa lub równa, mniejsza dostaje „budzik”) | potwierdzony [P] |
| „Zatrzymanie przed celem” w EE 518 / AoC 525 | reguła (a) „cel zajęty”, a nie test kroku [P]; wniosek etapu 26 poprawiony |
| Dwie jednostki w ruchu jednocześnie | nie zmierzono [N] (§ 5) |
| Różnica EE / AoC w odbudowie kontaktów | potwierdzona w kodzie, bez testu dynamicznego – [W] (§ 6) |
| ObstacleDetected / objazd 9002 | nie osiągnięto: max +0x248 = 2693 ms, próg T ≥ 3000 ms [N] (§ 7) |
| BO-9 | pierwotne sformułowanie obalone, nowe podejrzenie BO-9′ [W] (§ 8) |

## 2. Wzór odpychania – pomiar EE 535 [P]

Scenariusz: gwardia E (rozmiar 0,5) przejeżdża obok stojących jednostek. Jednostka A o rozmiarze 0,55 stoi na trasie.
W kolejnych taktach kontaktu A (u) przetwarza E (o).

Wektor push E zmierzony w grze i wyliczony wzorem z `kolizje_objazdy.md` § 3 (wartości dla danych pozycji):

| Takt | Push zmierzony | Push z wzoru |
|---|---|---|
| 1 | (0,0286; 0,0025) | (0,0286; 0,0025) |
| 2 | (0,1478; 0,0025) | (0,1478; 0,0025) |
| 3 | (0,1875; 0) | (0,1875; 0) |
| 4 | (0,1692; −0,0372) | (0,1692; −0,0372) |

Zgodność do 1e-7, czyli do precyzji f32. Potwierdza to [P]:
- warunek kolizji dx² + dy² ≤ ((ru + ro)/2)²;
- m = (S² − d²)·(ru/ro) i wagi kwadratowe dx²/d², dy²/d²;
- regułę „ro ≤ ru → push dla o”;
- jedno przetworzenie na takt.

Implementacja referencyjna (poza repozytorium) daje dla wszystkich przypadków z `testy_referencyjne_ruchu.md` § 4
te same wartości.

## 3. Jednostka w ruchu obok stojącej – EE 536 [P]

- E przejeżdża w odległości min. 0,367 od środka stojącej A (rozmiar 0,55).
- Push E niezerowy w 81 taktach. Licznik +0x248 rośnie do 1227 ms i zeruje się przy zmianie komórki.
- A dostaje tylko „budzik” (0,001; 0,001) i się nie przesuwa. E jest spychana z trasy i kontynuuje ruch.
- Liczba kontaktów 2–3, lista symetryczna.

## 4. Reguła (a) „cel zajęty” i poprawka interpretacji EE 518 / AoC 525 [P]

- W EE 518 i AoC 525 kliknięcie rozkazu trafiło w **model** jednostki stojącej za punktem kliknięcia. Cel rozkazu stał
  się więc pozycją tej jednostki (tak działa wybór celu przez kliknięcie w model).
- Zatrzymanie wynika z reguły (a) w 0x549179: u ma 1 punkt trasy, który leży w promieniu ro/2 od o → v_u = 0,
  u+0x330 = 8. Potwierdzone w EE 528 (rozkaz na pozycję stojącej jednostki: zatrzymanie w jednym takcie, +0x330 = 8).
- Wniosek etapu 26 („test kroku na komórce ze środkiem jednostki, potem objazd lub zatrzymanie”) jest dla tych pomiarów
  **zastąpiony**. Mechanizm testu kroku i +0x20C pozostaje w kodzie [W], ale nie był przyczyną tych zatrzymań.

## 5. Dwie jednostki w ruchu – dlaczego brak pomiaru [N]

Próby EE 529, 532, 533 i 537:
- Kliknięcie jednostki 18b lub 18d wybiera 55c (model 55c przesłania je w kamerze 135°). Wybór przez prostokąt jest
  zawodny.
- 532: drugi rozkaz trafił do innej jednostki niż zamierzona. 533: dwie jednostki dostały rozkazy, ale trasy się nie
  przecięły (min. odległość 2,24 pola).
- 537: grupa (szyk) – kontakty krótkie (push w 1–4 taktach), za mało do walidacji.

Ze zmierzonych reguł wynika, czego oczekiwać [W]:
- dwie jednostki tego samego rozmiaru w ruchu: każda pcha drugą (ro ≤ ru), symetrycznie, ale z opóźnieniem jednego
  przetworzenia zależnym od kolejności pętli 0x547AAD (od końca listy);
- różne rozmiary: większa pcha mniejszą, mniejsza budzi większą, a sama dostaje odbicie −2·(px, py) tylko wtedy, gdy
  większa stoi;
- ta sama grupa: brak wyjątku w kolizjach (osobne sloty szyku);
- wejście na tę samą komórkę: test kroku dopuszcza komórkę, jeśli nie leży w niej środek innej jednostki [W].

Do zmierzenia w kolejnym etapie potrzebny jest wybór jednostki po identyfikatorze, a nie kliknięciem. Wymaga to zmiany
narzędzia, której ten etap nie obejmował („Nie rozbudowuj prywatnego Riverlands_MCP”).

## 6. Odbudowa kontaktów EE ↔ AoC [W]

- EE: zapis macierzy (0x5F043B), potem przy zmianie komórki odbudowa listy kontaktów 0x5E960D / 0x5E8F0E od **nowej**
  pozycji.
- AoC: 0x5FE611 liczy komórkę i woła 0x5F6817 **przed** zapisem, czyli od starej pozycji.
- Okno listy to ±R z R = max(rozmiar, 0,5). Dla jednostek o rozmiarze < 1 okno obejmuje sąsiednie komórki w obu
  wariantach. Różnica w zbiorze kontaktów może wystąpić tylko dla R ≥ 1 albo przy przeskoku o więcej niż jedną komórkę
  [W].
- Testu dynamicznego nie wykonano (brak sterowania dwiema jednostkami). **Nie deklarujemy identycznego zachowania.**
  OpenEE musi mieć obie kolejności z przełącznikiem wariantu.

## 7. RepathAroundObstacle – próba wymuszenia [N]

Warunki z kodu (`kolizje_objazdy.md` § 5–6): ObstacleDetected zachodzi, gdy +0x20C ≠ 0 albo +0x248 > T, gdzie
T = (0,75 + u·0,5)·4000 ms z globalnego generatora.

Próby:
- 535: jazda w grupę stojących jednostek. +0x248 max 2693 ms, zerowany przy każdej zmianie komórki.
- 513 (etap 26): max 2863 ms przy brzegu mapy.

Licznik zeruje się przy zmianie komórki i przy zdjęciu punktu trasy. Jednostka spychana przez odpychanie prawie zawsze
zmienia komórkę przed upływem 3 s, więc próg nie jest osiągany [W]. Ścieżka przez +0x20C (test kroku) wymaga komórki,
w której leży środek innej jednostki, a zarazem celu poza nią (inaczej działa reguła (a)). Kliknięcie w model to
uniemożliwiało.

Statycznie ustalono wejście w 9000 z pre-testem [W]:
- gdy typ+0x5D4 & 2, przed zmianą punktu sprawdzany jest następny odcinek;
- przy przeszkodzie: +0x20C = blokujący, +0x330 = 2 → zdarzenie ObstacleDetected → 9002.

Nieudany objazd (A* w oknie ±50 pól nie znajduje drogi): kod czyści trasę i przechodzi do 9006 [W]. Nie zmierzono.

## 8. BO-9 – ponowna analiza [W]

- Nadpisanie wyniku na 1 dotyczy tylko obiektów kategorii 0x19, które nie są bramą (mury). Dla zwykłych jednostek
  wynik testu zgodności rozkazów **nie** jest nadpisywany. Pierwotne sformułowanie BO-9 jest obalone.
- Nowe podejrzenie **BO-9′**: flaga „pomiń kontakt” ustawiana jest raz przed pętlą kontaktów i nie jest zerowana dla
  kolejnego kontaktu. Jeśli pierwszy kontakt ją ustawi, kolejne też mogą zostać pominięte (`BLEDY_ORYGINALU.md`).

## 9. Wymagania dla OpenEE

1. Kolizje w warstwie symulacji, jednostki w kolejności listy oryginału (od końca), push zapisywany do pól drugiej
   jednostki natychmiast.
2. Wzór 0x549179 z zapisami f32 jak w implementacji referencyjnej; zastosowanie 0x549A08 osobno.
3. Reguła (a) przed regułami pchania.
4. Lista kontaktów odbudowywana tylko przy zmianie komórki, w kolejności EE albo AoC.
5. Nie używać fizyki Godota (`CharacterBody3D`, `move_and_slide`) – wynik zależy od kolejności i jest jednostronny.
