# OpenEE – raport etapu 24: A* po polach mapy i przetwarzanie wyników w Titan

Jedenasty etap rekonstrukcji kodu silnika Titan. Odtwarza wyszukiwanie trasy po polach mapy od startu A* do
przekazania trasy jednostce, razem z szybką próbą `Bounded`, wynikiem częściowym i weryfikacją niezależnym modelem.

Szczegóły:
- **`docs/titan/astar_pola.md`** – pętla, listy, koszty, heurystyka, sąsiedzi, dostępność, remisy;
- **`docs/titan/astar_wyniki.md`** – koniec trasy, odtwarzanie, przekazanie, `Bounded`, eksperymenty, model.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `1c23a9e`, testy Godota 324/324.

## 0. Mapa wiedzy przed etapem (z etapów 22–23)

| Znane | Niewiadome na starcie |
|---|---|
| `EEPathManager`, pule maszyn, kolejki +0x5C / +0x70, takt | wnętrze pętli 0x4A5428, struktury list |
| budżety: limit na wywołanie / całkowity w iteracjach | koszt, heurystyka, porównania, remisy |
| prośba jednostki: graf → `Bounded` → pola | warunki i wynik `Bounded` |
| koniec prośby 0x4A327E, przekazanie 0x5EE4E6 | +0x94, 0x4A5D16, 0x4A2B29, miejsce trasy w jednostce |

## 1. Odtworzone

1. **Pętla A*** [P: kod, liczby iteracji i wywołań zgodne z modelem].
   - Licznik iteracji rośnie przy każdym zdjęciu węzła.
   - Węzeł bieżący zamyka się po rozwinięciu sąsiadów.
   - Zawieszenie następuje po rozwinięciu L + 1 węzłów w wywołaniu.
   - Wznowienie kontynuuje bez inicjalizacji.
2. **Koszty i heurystyka** [P].
   - Krok prosty 10, po przekątnej 14.
   - H = 10 · (|dx| + |dy|), F = G + H, liczby całkowite bez znaku.
   - Teren, wysokość i nachylenie nie wpływają na koszt, tylko na dostępność [W].
   - Heurystyka nie jest dopuszczalna, więc trasa zaczyna się od przekątnych.
3. **Sąsiedzi** [P].
   - Kolejność: (x, y−1), (x−1, y), (x+1, y), (x, y+1), potem przekątne (−1,−1), (+1,−1), (+1,+1), (−1,+1).
   - Przekątna wymaga jednego wolnego pola prostego, więc można ściąć narożnik pojedynczej przeszkody.
   - Pomiar: 4 ścięcia w trasie E.
4. **Listy i remisy** [W: kod; P: zgodność tras].
   - Lista otwarta to posortowana lista dwukierunkowa oraz 53 kubełki dla węzłów o F większym od ostatniego elementu
     listy, z uzupełnianiem po 15 najlepszych.
   - Zawsze zdejmowany jest węzeł o najmniejszym F. Przy remisie wygrywa ostatnio wstawiony do listy.
   - Lista zamknięta to 53 kubełki z możliwością ponownego otwarcia.
5. **Dostępność** [W; P: brama przechodnia].
   - Pole niedostępne to: poza mapą, linia brzegu rombu (tylko równość), teren zabroniony w tablicy typu albo obiekt
     blokujący (drzewa, budynki).
   - Inne jednostki nie blokują pola, tylko dodają koszt (+50 / +150).
   - Duże jednostki (rozmiar kolizji ≥ 1,0) płacą podwójnie przy przeszkodach.
   - Wynik oceny pola jest zapamiętywany do końca wyszukiwania.
6. **Koniec trasy i wynik częściowy** [W].
   - Flaga +0x94 (cel +0x28) oznacza „koniec = najbliższy dostępny węzeł” według |dx| + |dy|, przy równej odległości
     o mniejszym F.
   - Flaga jest ustawiana przy pustej otwartej, przy niedostępnym celu i po osiągnięciu limitu.
   - „Brak drogi” i „brak ukończonego wyniku” dają ten sam rodzaj trasy.
7. **Odtworzenie trasy i przekazanie** [P].
   - Trasa to łańcuch poprzedników, punkty (x + 0,5; y + 0,5; 0), bez upraszczania i wygładzania.
   - Jednostka dostaje punkty od startu do celu, bez pola, na którym stoi.
   - Punkty trafiają do kolejki dwustronnej +0x7C (+0x8C = liczba), elementy po 20 B z długością narastającą.
   - Ostatni punkt to dokładne położenie celu z wysokością terenu.
8. **`Bounded`** [W; P: przypadki B, C, E].
   - Te same koszty i heurystyka.
   - Kwadrat start ± (m + 1), limit m = d (albo d / 20) + min(zawieszone + 4, 11).
   - Sukces kończy prośbę.
   - Porażka daje jednostce trasę do najbliższego punktu, a pełne A* startuje z tego punktu.
9. **EE ↔ AoC** [P].
   - Pętla, listy, sąsiedzi, heurystyka, koniec trasy i odtworzenie są identyczne w kodzie.
   - Koszt i dostępność różnią się tylko przesunięciami pól i testem terenu przez metodę typu w AoC.
   - Pomiar: trasa A w AoC bit w bit jak w EE, trasa E zgodna z modelem.

## 2. Częściowo odtworzone

- **0x4A2B29** to zwykłe przekazanie trasy z łączeniem z obecną trasą jednostki i poprawą początku przez `Bounded` (±26
  pól, 50 iteracji). Szczegóły sklejania (0x4A2214, 0x4A37A7) – [W/N].
- **Kary za stojące jednostki i podwojenie kosztu dużych jednostek** – tylko z kodu [W], bez pomiaru.
- **Pierwsza próba z limitem 15** prowadzi do wyniku częściowego i ponowienia [H]. W pomiarach budżet był już wyliczany
  z odległości (cel +0x34 = 3/4).
- **Pełny warunek przechodniości bramy** (typ 25) [N]. W pomiarze własna brama była przechodnia.

## 3. Nierozpoznane

1. **Przypadek F** (cel w wodzie). Trasa w kolejce jednostki prowadzi przez pola z terenem 10, niedostępne według
   tablicy typu. Jednostka zatrzymała się przed nimi i straciła cel. Mechanizm nieustalony (BO-6).
2. Kto ustawia ostatni punkt na dokładny cel z wysokością.
3. Wpis do dziennika nieudanych prób i „CannotPathToTarget”.
4. Kierunki 0x632E7C używane przy dużych jednostkach.

## 4. Weryfikacja

Zadania MCP 464–489 (EE 464–483, AoC 484–488, 489 zamknięcie gry). Tylko odczyt pamięci, w pauzie.

Dane mapy do modelu odczytano z pamięci gry:
- komórki `EEMap` w oknie 81 × 66 pól;
- listy obiektów, obiekty i ich typy;
- tablica terenu typu jednostki.

| Przypadek | Wynik |
|---|---|
| A / B: obejście, cel w bramie (EE 469–476) | trasy identyczne z modelem; `Bounded` 8 iteracji = model [P] |
| C: krótko prosto (EE 477–478) | 6 iteracji, trasa identyczna [P] |
| D: narożniki | 4 ścięcia narożnika w trasie E zgodne z modelem [P] |
| E: długa trasa (EE 479–480) | 36 punktów identycznych z modelem; maszyna pól 145 iteracji w 8 wywołaniach = model [P] |
| F: cel niedostępny (EE 481–483) | rozbieżność z modelem, opisana jako BO-6 [N] |
| AoC A, E (484–488) | trasa A bit w bit jak EE; trasa E zgodna z modelem [P] |

**Model** (`Testy_MCP/e24/model_astar.py`, poza repozytorium).
- Wszystkie stałe pochodzą z kodu. Jedyna korekta po pomiarze to przechodniość bramy, wynikająca z liczby iteracji.
- Potwierdza algorytm dla A–E. Przypadku F nie potwierdza.

## 5. Błędy oryginału

BO-1–BO-4 bez zmian. Nowe wpisy:

| Wpis | Treść | Pewność |
|---|---|---|
| BO-5 (obserwacja) | test końca porównuje iteracje z limitem ze znakiem, więc „−1 = bez limitu” zawsze daje „limit osiągnięty”. W prośbach jednostek bez skutku | [W] |
| BO-6 (podejrzenie) | trasa do celu nieosiągalnego przez pola niedostępne dla typu i zatrzymanie jednostki przy brzegu | pomiar [P], mechanizm [H] |

## 6. Korekty wcześniejszych ustaleń

Adnotacje „[Etap 24 – …]” w `docs/titan/architektura_nawigacji.md`:
- 0x4A2B29 to nie obsługa porażki, tylko zwykła droga wyniku maszyny pól (flaga +0x96 zawsze 0).
- Znaczenie +0x94.
- +0x1C to reguła narożników.
- Start pełnego A* w punkcie końcowym `Bounded`.
- Kolejka trasy jednostki +0x7C.

## 7. OpenEE (bez zmian w kodzie)

Do wiernego odtworzenia potrzebne są:
- koszty całkowite 10/14 i heurystyka 10·Manhattan;
- lista otwarta z kubełkami i uzupełnianiem po 15, bo od niej zależą remisy;
- kolejność sąsiadów i reguła narożników;
- pamięć dostępności na czas wyszukiwania;
- wybór najbliższego dostępnego węzła;
- trasa pole po polu z ostatnim punktem w dokładnym celu;
- `Bounded` przed pełnym A*;
- limity w iteracjach.

## 8. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/astar_pola.md`, `docs/titan/astar_wyniki.md` | nowe wpisy atlasu Titan |
| `docs/titan/architektura_nawigacji.md` | odnośniki, adnotacje „[Etap 24 – …]” |
| `docs/titan/BLEDY_ORYGINALU.md` | BO-5, BO-6 |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 24, nowy aktualny raport |
| `RAPORT_ETAP_23.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 24”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 9. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_24.md` |

## 10. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
