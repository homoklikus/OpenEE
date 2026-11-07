# OpenEE – raport etapu 19: przydział pozycji szyku przy ruchu na krótki dystans

Szósty etap rekonstrukcji kodu silnika Titan. Zakres: ścieżka bliska obsługi stanu grupy 8000 (EE 0x5DC364), czyli
przydział jednostek do pozycji szyku `EEFShortLine`, gdy cel leży przy grupie. Najprostszy przypadek: jednostki
lądowe, PPM, bez Shift. Szczegóły: **`docs/titan/przydzial_bliski.md`**, skrót w `docs/titan/cele_jednostek.md`
(§ „Przydział bliski — etap 19”).

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `1517de8`, testy Godota 324/324.

## 1. Wynik

1. **Warunek ścieżki bliskiej** (pytanie 1). Cel G leży w prostokącie otaczającym jednostki (z brzegami włącznie) albo
   E² ≥ D, czyli nie zachodzi warunek ścieżki dalekiej z etapu 18 [P: kod; 7 rozkazów].
2. **Koszt** (pytanie 2) to kwadrat odległości 3D jednostka – pozycja (`GE3DPoint::DistanceToSquared`), bez wag.
   Wszystkie pozycje mają tę samą wysokość, więc z nie zmienia wyboru [P].
3. **Metoda** (pytanie 3). Jednostki po kolei biorą najtańszą z wolnych pozycji, a ta pozycja wypada z listy.
   Decyzji nie zmienia się później i nie przeszukuje się kombinacji [P: kod i pomiar].
4. **Kolejność i remisy** (pytanie 4). Jednostki są najpierw sortowane:
   - prędkość typu rosnąco – najwolniejsze wybierają pierwsze;
   - potem „Size of collider” malejąco;
   - potem numer w grupie: rosnąco, gdy co najmniej obcięcie(n/2) jednostek stoi na północ od celu (kąt ≤ π/2 do
     osi +y mapy), w przeciwnym razie malejąco.

   [P: kod; pomiar obu kierunków w EE i AoC]. Przy równym koszcie wygrywa pozycja o wyższym numerze [W: kod].
5. **Parametry tylko tej ścieżki** (pytanie 5):
   - pola typu EE +0x430 / AoC +0x134 – prędkość;
   - EE +0x474 / AoC +0x178 – „Size of collider”;
   - próg kąta π/2 i próg n/2.

   Odczyt wartości [P], nazwy pól z porównania z `dbobjects` [W].
6. **EE ↔ AoC** (pytanie 6). Kod identyczny instrukcja po instrukcji (EE 0x5DC364–0x5DC6B5, AoC 0x5ECCA1–0x5ECFF2).
   Różnią się adresy, ramka i przesunięcie pól typu (0x2FC) [P].
7. **Jednostki przy celu lub już na pozycjach.** Nie mają pierwszeństwa: wolniejsza jednostka zabiera pozycję, nawet
   gdy inna już na niej stoi (pomiar EE 405 i 408) [P]. Jednostka dokładnie w punkcie G – [N].

## 2. Weryfikacja

Zadania MCP 398–417 (EE 398–410, AoC 411–417) oraz dane etapu 18 (390, 396). Tylko odczyt pamięci, scenariusz „Wojna
trojańska”, pauza F3 po rozkazie. Odczytano:
- zaznaczenie;
- pozycje przed rozkazem;
- wektor jednostek grupy;
- numer pozycji i cel każdej jednostki.

Przewidywania liczono z modelu odtworzonego z kodu, bez dopasowania do wyniku.

| Rozkaz | Jednostki | Flaga | Wynik |
|---|---|---|---|
| EE 390, AoC 396 (etap 18) | 6 i 3 | 1 | przydział zgodny z modelem [P] |
| EE 402 | 6 (3 typy) | 1 | zgodny; model daleki i flaga względem kierunku rozkazu – niezgodne [P] |
| EE 405 | 6 | 0 | zgodny; numery rosnąco – niezgodne [P] |
| EE 408 | 3 | 0 | zgodny [P] |
| AoC 412 | 6 | 1 | zgodny; numery malejąco i flaga względem kierunku rozkazu – niezgodne [P] |
| AoC 415 | 6 | 0 | zgodny; numery rosnąco – niezgodne [P] |

We wszystkich nowych rozkazach pozycje szyku z modelu etapu 18 zgadzały się z pamięcią co do 2·10⁻⁴ pola.

**Ograniczenia.**
- Ramka zaznaczenia trafia dopiero po podaniu wysokości terenu (z = 1,9). Zadania 399–401 zaznaczyły 1–3 jednostki
  i nie zostały wykorzystane.
- Kliknięcie celu trafia 0,5–0,8 pola od żądanego punktu, dlatego G odczytywano z pamięci.
- Nie zmierzono: przypadku 2 jednostek, remisu kosztów ani rozstrzygnięcia według „Size of collider” przy równej
  prędkości. Te elementy wynikają tylko z kodu [W].
- Nowego narzędzia nie budowano.

## 3. Błędy oryginału

**BO-3 (podejrzenie, nowy wpis):** flaga kierunku numeracji jest liczona względem stałej osi +y mapy. Przekształcenie
w funkcji kąta jest domyślne (tożsamość), a gałąź znaku kąta nie działa.
- Zachowanie [P]: kod; pomiar 402 i 412 odróżnia oś mapy od kierunku rozkazu.
- To, że jest to błąd, i skutki [H].
- Status: zachować zgodność.

BO-2 bez zmian. Ścieżka bliska nie używa klucza k(p), więc nie dostarcza dowodów w żadną stronę.

## 4. Przeszkody

1. Flaga przy jednostce stojącej dokładnie w G (normalizacja wektora zerowego) – [N].
2. Wariant sortowania powyżej 16 jednostek nie był czytany szczegółowo. Wynik od niego nie zależy, bo klucz jest
   pełny [W].
3. Gałąź specjalna (+0xB6 grupy, +0x474 typu), inne szyki, Shift – poza zakresem.

## 5. OpenEE (bez zmian w kodzie)

Do wiernego odtworzenia przydziału bliskiego potrzebne są:
- warunek ścieżki;
- sortowanie jednostek: prędkość ↑, „Size of collider” ↓, numer ↑/↓ według flagi z osi +y mapy (BO-3);
- wybór najbliższej wolnej pozycji z przeglądem od końca listy i zamianą tylko przy koszcie ściśle mniejszym;
- usuwanie wybranej pozycji z listy z zachowaniem kolejności pozostałych.

## 6. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/przydzial_bliski.md` | nowy wpis atlasu Titan |
| `docs/titan/cele_jednostek.md` | § „Przydział bliski — etap 19”, pola typu +0x430 / +0x474, adnotacje „[Etap 19 – …]” |
| `docs/titan/BLEDY_ORYGINALU.md` | BO-3 (podejrzenie) |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 19, nowy aktualny raport |
| `RAPORT_ETAP_18.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 19”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 7. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_19.md` |

## 8. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
