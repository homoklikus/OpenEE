# Gałąź specjalna przydziału pozycji (stan grupy 8000) – Empire Earth / The Art of Conquest

Wpis atlasu Titan, etap 20. Uzupełnia `cele_jednostek.md` (etap 18) i `przydzial_bliski.md` (etap 19). Opisuje
warunek w obsłudze stanu 8000, który przed wyborem ścieżki bliskiej albo dalekiej może pominąć oba algorytmy przydziału.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pliki: `Empire Earth.exe` (EE) i `EE-AOC.exe` (AoC) z instalacji GOG; SHA-256 jak w `cele_jednostek.md`.

## Wynik w skrócie

1. **Funkcja gałęzi.** To nie jest osobny algorytm szyku. Gałąź **pomija przydział bliski i daleki** i skacze
   wprost do wspólnego nadawania celów (EE 0x5DC6B5, AoC 0x5ECFF2). Zostaje wtedy przydział, który zapisał już układ
   szyku: **jednostka o numerze k w grupie dostaje pozycję k** [P: kod i pomiar w EE i AoC].
2. **Warunek wejścia** (kolejno, każde niespełnienie przechodzi do zwykłego wyboru ścieżki) [P: kod]:
   1. bajt grupy `+0xB6` ≠ 0;
   2. największe „Size of collider” w grupie (pole typu EE +0x474, AoC +0x178, f32) **< 1,0**;
   3. średnia prędkość grupy (`+0x70`, f32) **> 0,5**.
3. **Skąd `+0xB6` = 1.** Rozkaz PPM wydany **przeciągnięciem** (przytrzymanie prawego przycisku i ruch myszy, który
   ustala kierunek szyku):
   - interfejs `EEUICCommandUnits` zapamiętuje przeciągnięcie (+0xB9);
   - przy zwolnieniu przekazuje je do `EEMPathTo`+0x1F;
   - dalej trafia ono do celu grupy (`EEUGLocation`+0x33) i do flagi grupy +0xB6.

   Zwykłe kliknięcie PPM daje +0xB6 = 0 [P: kod; pomiar – etap 19 bez przeciągnięcia: 0, etap 20 z przeciągnięciem:
   1]. Drugim źródłem jest rozładunek transportu (`EEMUnloadTransport`, stan grupy 12001), który ustawia +0xB6 = 1
   bezpośrednio [W: kod; poza zakresem].
4. **Znaczenie `+0xB6`.** „Grupa porusza się w szyku”: gdy flaga jest ustawiona, grupa podaje każdej jednostce wspólne
   parametry ruchu (+0x70…+0xAC) zamiast jej własnych. Gałąź przydziału to jedno z jej zastosowań [W: kod getterów
   0x5DD355–0x5DD433].
5. **`+0x70`** to pierwszy wspólny parametr ruchu grupy: min(średnia, k · minimum) z wartości jednostka+0x34 →
   +0xAC wszystkich jednostek. Mnożnik k pochodzi z tablicy reguł (w pomiarze 2,0). Wartości jednostek w pomiarze
   to prędkości: gwardia 0,6, Aleksander 0,8, prorok 0,5, obywatel 0,5 [P: kod i pomiar wartości; nazwa „prędkość”
   – W].
6. **Wpływ:** zmienia tylko **przypisanie** jednostek do pozycji. Geometria szyku (pozycje, θ) i nadawanie celów
   (wspólna część etapu 18) pozostają te same [P: kod; pomiar pozycji zgodny z modelem etapu 18].
7. **EE ↔ AoC.** Warunek, stałe, pola grupy (+0x70, +0xB6) i przekazywanie +0x1F są takie same. Różnice:
   - pole typu (+0x474 / +0x178);
   - w AoC lista typów jednostek, przy których interfejs w ogóle śledzi przeciągnięcie, jest dłuższa o `Unit type`
     0x1F i 0x21.

   [P: kod; pomiar w obu grach].

## Funkcje i adresy

| Funkcja | EE | AoC | Uwagi |
|---|---|---|---|
| Warunek gałęzi w obsłudze stanu 8000 | 0x5DBE35–0x5DBE66 | 0x5EC790–0x5EC7C1 | skok do 0x5DC6B5 / 0x5ECFF2 |
| Maksimum „Size of collider” (pętla po jednostkach) | 0x5DBDD1–0x5DBDEA | 0x5EC72C–0x5EC745 | ta sama pętla liczy prostokąt i środek jednostek |
| Odczyt grupa +0x70 | 0x5DBE0F | 0x5EC76A | kopia bitowa f32 |
| Stałe 1,0 / 0,5 | 0x83140C / 0x831410 | 0x846CE8 / 0x846CEC | f32 |
| Układ szyku zapisujący jednostkę k do pozycji k | 0x4D7B4E (w 0x4D79D9) | 0x4DDB18 (w 0x4DD9A3) | pozycja +0x0C, 20 B, dodanie 0x4D74C5 |
| Wspólne nadawanie celów (pomija pozycje bez jednostki) | 0x5DC6B5, test 0x5DC72F | 0x5ECFF2 | etap 18 § 4 |
| Ustawienie celu grupy: +0xB6 = (rodzaj celu 1 i cel+0x33 ≠ 0) | 0x5DD436 | 0x5EDC93 | identyczne |
| `EEMPathTo::Execute`: cel+0x33 = komunikat+0x1F | 0x4BA001–0x4BA007 | 0x4C2AA2–0x4C2AA8 | – |
| `EEAMouseClick` +0x0C: +0x1F = 7. argument (gałąź 0x4048F7) | 0x404947–0x404953 | 0x404098 | inne gałęzie wpisują 0 |
| `EEUICCommandUnits` vtable +0x88 – naciśnięcie PPM: +0xB8, +0xB9 = 0, punkt startu +0xA0 | 0x641C7F | 0x65829C | AoC: dodatkowe typy 0x1F, 0x21 |
| `EEUICCommandUnits` vtable +0x40 – ruch myszy: +0xB9 = 1 po przekroczeniu progu, kąt +0xB4 | 0x64198C | 0x657FA9 | identyczne |
| `EEUICCommandUnits` vtable +0x48 – zwolnienie PPM: wywołanie `EEAMouseClick` +0x0C | 0x641B53 | 0x658170 | identyczne poza polem gracza |
| Kąt z dwóch punktów: θ = atan2(−(b.x − a.x), b.y − a.y) | 0x64138B | – | import 0xB306A4 |
| Wspólne parametry ruchu grupy (+0x70…+0xAC) | 0x5DCE49 | 0x5ED692 | identyczne poza prologiem |
| Gettery parametrów ruchu: grupa przy +0xB6, inaczej jednostka+0x34 | 0x5DD355–0x5DD433 | – | 7 funkcji |
| Stan grupy 12001: +0xB6 = 1, potem obsługa 8000 | 0x5DDFCE | 0x5EE5BC (porównanie) | z `EEMUnloadTransport` (EE 0x4BF8C1, AoC 0x4C878C) |

## Struktury danych

| Pole | Znaczenie | Pewność |
|---|---|---|
| grupa +0xB6 (u8) | „ruch w szyku”: wspólne parametry ruchu grupy; warunek gałęzi przydziału | [P] – kod i pomiar (1 po przeciągnięciu, 0 bez niego) |
| grupa +0x70 (f32) | min(średnia, k · minimum) z jednostka+0x34 → +0xAC; w pomiarze 0,6167 (6 jednostek), 0,5667 (3), 0,5 (obywatele), 0,6 (sama gwardia) | [P] wzór i wartości; nazwa „prędkość” [W] |
| grupa +0x74 / +0x78 | maksimum / minimum tej wielkości (0,8 / 0,5) | [P] |
| grupa +0xB0 (f32) | mnożnik k z tablicy reguł 0x917BB4, wpis 0x31; w pomiarze 2,0 | [P] wartość; znaczenie [W] |
| grupa +0x7C…+0x94, +0xA0…+0xAC | kolejne wspólne parametry (z +0xA8, +0xB4, +0xB0 obiektu jednostki) i ich odwrotności | [P] kod; znaczenie [N] |
| typ +0x474 / +0x178 | „Size of collider” (gwardia 0,5, Aleksander 0,55, prorok 0,5, obywatel 0,3) | wartości [P]; nazwa [W] |
| cel grupy `EEUGLocation`+0x33 | flaga przeciągnięcia z `EEMPathTo`+0x1F; pomiar: 1 po przeciągnięciu | [P] |
| `EEMPathTo`+0x1F | 7. argument `EEAMouseClick` +0x0C = `EEUICCommandUnits`+0xB9 sprzed zwolnienia | [P] kod |
| `EEUICCommandUnits` +0xB8 | przy naciśnięciu: czy zaznaczenie zawiera jednostkę o `Unit type` z listy (EE: 4, 5, 6, 7, 8, 10, 13, 14, 15, 16, 17, 18, 21, 22, 23, 26) | [P] kod |
| `EEUICCommandUnits` +0xB9 | przeciągnięcie: 1, gdy kwadrat odległości kursora od punktu naciśnięcia > (0,02 · wartość globalna)² | [P] kod; wartość globalna (EE 0x9197A4 → +0x0C) [N] |
| `EEUICCommandUnits` +0xB4 | kąt szyku θ: przy przeciągnięciu z wektora przeciągnięcia, bez niego z wektora środek zaznaczenia → punkt kliknięcia | [W] kod |

## Przebieg

### Od kliknięcia do flagi grupy

```
naciśnięcie PPM (EEUICCommandUnits +0x88, EE 0x641C7F):
    B8 := istnieje zaznaczona jednostka o Unit type z listy        ; 0x641CE8–0x641D51
    B9 := 0; A0 := punkt naciśnięcia                               ; 0x641D60, 0x641D72
ruch myszy (+0x40, EE 0x64198C):
    jeśli B8 i nie B9: B9 := (próg² < |kursor − A0|²)              ; 0x641AFF–0x641B24
    jeśli B9: B4 := kąt(A8 → punkt pod kursorem)                   ; 0x641B32–0x641B44
zwolnienie PPM (+0x48, EE 0x641B53):
    p := B9                                                        ; 0x641BA5 (przed zmianami)
    jeśli B8 i nie B9: B4 := kąt(środek zaznaczenia → punkt); B9 := 1   ; 0x641BC5–0x641C2F
    EEAMouseClick+0x0C(x, y, …, +0x1D = B9, kąt = B4, 7. arg = p)  ; 0x641C36–0x641C66
EEAMouseClick +0x0C (0x403CF1): jeśli 7. arg ≠ 0 → EEMPathTo z +0x1F = 7. arg   ; 0x403DBF, 0x404947–0x404953
EEMPathTo::Execute: cel.+0x33 := +0x1F                             ; 0x4BA001–0x4BA007
ustawienie celu grupy: B6 := (cel.rodzaj = 1 i cel.+0x33 ≠ 0)      ; 0x5DD447–0x5DD45A
```

Wniosek: +0x1F = 1 tylko wtedy, gdy przeciągnięcie przekroczyło próg **przed** zwolnieniem przycisku. Zwykłe
kliknięcie ustawia B9 dopiero przy zwolnieniu, więc przekazuje 0 [P: kod; pomiar].

### W obsłudze stanu 8000 (EE 0x5DB641)

```
S := wektor pozycji z układu szyku (vtable +4); pozycja k ma jednostkę k grupy   ; 0x5DBCC2, 0x4D7B4E
dla każdej jednostki J: maxKol := max(maxKol, typ(J).+0x474)  (start 0)         ; 0x5DBDD1–0x5DBDEA
v := grupa.+0x70                                                                ; 0x5DBE0F
jeśli grupa.+0xB6 ≠ 0                  (u8)                                     ; 0x5DBE35, 0x5DBE4A
   i maxKol < 1,0                      (f32, jae → dalej zwykle)                ; 0x5DBE4C–0x5DBE58
   i v > 0,5                           (f32, ja → skok)                          ; 0x5DBE5A–0x5DBE66
      → skok do 0x5DC6B5 (wspólne nadawanie celów)
w przeciwnym razie → wybór ścieżki bliskiej / dalekiej (etapy 18–19)
```

We wspólnej części (etap 18 § 4) każda pozycja k z jednostką J daje J+0x298 = k, cel `EEUGLocation` z pozycją k
i kątem θ oraz stan jednostki 8000. Pozycje bez jednostki są pomijane (0x5DC72F); przy równej liczbie pozycji
i jednostek taka sytuacja nie występuje [P: kod].

## Wpływ na wyznaczanie celów

| Element | Ścieżka zwykła | Gałąź specjalna |
|---|---|---|
| Pozycje szyku (G, θ, S, kolumny, rzędy) | etap 18 | bez zmian [P] |
| Przypisanie jednostka → pozycja | bliska (etap 19) albo daleka (etap 18) | numer w grupie = numer pozycji [P] |
| Cel jednostki, J+0x298, J+0x2DC, stan 8000 | wspólna część | ta sama wspólna część [P] |

Kąt θ przy rozkazie przeciągnięciem pochodzi z kierunku przeciągnięcia, a nie z kierunku do celu. To cecha
interfejsu, nie gałęzi [W: kod].

## Weryfikacja

Zadania MCP 418–424, tylko odczyt pamięci, scenariusz „Wojna trojańska”. Przeciągnięcie wykonano istniejącym krokiem
`kam_przeciagnij` (PPM, 250 px w prawo, od piksela 1720, 600). Przypadek kontrolny „bez przeciągnięcia” to rozkazy
etapu 19 (402–415), we wszystkich +0xB6 = 0. Przewidywania liczono modelami etapów 18–19.

| Zadanie | Jednostki | +0xB6 | +0x70 | maks. kolizja | Warunek | Przydział zmierzony | Model bliski | Wynik |
|---|---|---|---|---|---|---|---|---|
| EE 419 | 18b, 18c, 18d, 18e, 55c, 55d | 1 | 0,6 (odczyt po rozejściu, 1 jednostka; dla 6 jednostek wzór daje 0,6167) | 0,55 | spełniony | 0, 1, 2, 3, 4, 5 = numery w grupie | 18c→0, 18b→1, 18e→2, 18d→3, 55d→4, 55c→5 | **gałąź specjalna** [P] |
| AoC 423 | jw. | 1 | 0,6 (odczyt po rozejściu, 2 jednostki) | 0,55 | spełniony | 0, 1, 2, 3, 4, 5 = numery w grupie | jw. | **gałąź specjalna** [P] |
| EE 420 | 5 obywateli 11a–11e | 1 | **0,5** | 0,3 | niespełniony (0,5 ≯ 0,5) | 11c→0, 11b→1, 11d→2, 11a→3, 11e→4 | identyczny (f = 0, numery malejąco) | **zwykła ścieżka bliska** [P] |
| EE 402–415 (etap 19) | 3 i 6 jednostek | 0 | 0,57–0,62 | 0,55 | niespełniony | według algorytmu bliskiego | zgodny | kontrola [P] |

Uzupełnienia:
- W 419 i 423 żadna z 720 kolejności wyboru w algorytmie bliskim nie daje zmierzonego wyniku. Wynik nie da się więc
  wyjaśnić przydziałem bliskim, a zgadza się dokładnie z kolejnością grupy.
- Pozycje szyku odtworzono z jednego zmierzonego celu i θ:
  - cel drugiej jednostki jeszcze w ruchu zgadzał się z modelem co do 10⁻⁴ pola (AoC: cel 18e wyliczony z celu 18d);
  - końcowe położenia jednostek, które już doszły, leżały przy swoich pozycjach: do 0,07 pola, a 18b w EE 0,28 pola
    (blokowanie przez sąsiadów).
- Cel grupy po przeciągnięciu (EE 420): `EEUGLocation`, rodzaj 1, +0x33 = 1, θ = −0,7854 – kierunek przeciągnięcia
  ekranowego w prawo przy azymucie kamery 135° [P].
- W 420 tylko 1 z 120 kolejności daje zmierzony wynik i jest to kolejność algorytmu bliskiego dla numerów 11a–11e.
- Typy w pamięci (EE 420): obywatel – prędkość 0,5, „Size in formation” 0,625, „Size of collider” 0,3.

**Ograniczenia pomiarów.**
- `kam_przeciagnij` po zwolnieniu przycisku czeka ok. 0,6 s, zanim przyjdzie pauza F3. Przy krótkim dystansie część
  jednostek dochodziła już do celu i opuszczała grupę: cel jednostki +0x1F0 = 0, grupa z mniejszą liczbą jednostek.
  Dlatego dowodem przydziału jest numer pozycji J+0x298 / +0x29C, który pozostaje po dojściu, oraz końcowe położenia.
- Wektora jednostek grupy nie dało się odczytać w całości po rozejściu. Kolejność grupy przyjęto jak w etapie 19:
  numery rosnąco według ID, co wtedy zmierzono.
- Nie zmierzono przypadku z jednostką o „Size of collider” ≥ 1,0. W scenariuszu nie ma takiej jednostki
  w zaznaczalnym zestawie. Ten warunek potwierdza tylko kod [W].
- Rozładunku transportu (stan 12001) nie badano.

## Różnice EE ↔ AoC

- Warunek gałęzi, stałe 1,0 i 0,5, pola grupy +0x70, +0xB6, +0xB0 oraz wzór +0x70 są identyczne (porównanie
  znormalizowane 0x5DCE49 ↔ 0x5ED692 i 0x5DD436 ↔ 0x5EDC93) [P].
- Pole typu: EE +0x474, AoC +0x178 [P].
- `EEUICCommandUnits` +0x88: AoC czyta `Unit type` z +0x1B8 zamiast +0x4B4 i dopuszcza dodatkowo typy 0x1F i 0x21
  [P: kod]. Pozostałe metody (+0x40, +0x48) są zgodne instrukcja po instrukcji.

## Błędy oryginału

Nie dodano nowego wpisu.
- Pominięcie przydziału przy ruchu w szyku wygląda na zamierzone zachowanie autorów (jednostki zachowują miejsca
  w szyku według kolejności grupy). Może jednak powodować krzyżowanie się tras, bo położenie jednostek nie jest
  brane pod uwagę [H].
- Ostra nierówność „> 0,5” wyklucza grupy o prędkości dokładnie 0,5 (np. same obywatelki i obywatele). To prawdopodobnie
  zamierzony próg, nie błąd [H].
- BO-1, BO-2 i BO-3 bez zmian. W gałęzi specjalnej nie działa ani klucz k(p) (BO-2), ani flaga kierunku (BO-3).

## Nierozpoznane zależności

1. Wartość globalna progu przeciągnięcia (EE 0x9197A4 → +0x0C, mnożona przez 0,02) – prawdopodobnie rozmiar ekranu
   [N].
2. Obiekt jednostka+0x34 i jego pola +0xA8, +0xAC, +0xB0, +0xB4, +0xC4–+0xD0. Prorok ma tam 0,5, choć typ podaje
   prędkość 0,45 [N].
3. Pochodzenie mnożnika +0xB0 (tablica reguł 0x917BB4, wpis 0x31) [N].
4. Pełne znaczenie listy `Unit type` w `EEUICCommandUnits` +0x88 [N].
5. Stan grupy 12001 (rozładunek transportu) – wiadomo tylko, że ustawia +0xB6 = 1 i woła tę samą obsługę [W].
6. Wpływ +0xB6 na ruch jednostek w kolejnych taktach (wspólne parametry ruchu) – poza zakresem etapu.

## Konsekwencje dla OpenEE (bez zmian w kodzie)

- Rozkaz PPM z przeciągnięciem musi dawać flagę „ruch w szyku” (grupa +0xB6) i kąt szyku z kierunku przeciągnięcia.
- W obsłudze stanu 8000, przed wyborem ścieżki: gdy +0xB6 i maks. „Size of collider” < 1,0 i +0x70 > 0,5 (ostre
  nierówności, f32), przydział zostaje w kolejności grupy (jednostka k → pozycja k), bez algorytmu bliskiego
  i dalekiego.
- +0x70 = min(średnia, 2,0 · minimum) z parametru ruchu jednostek. Mnożnik według tablicy reguł.
