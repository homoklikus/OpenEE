# Kolejka celów jednostki i rozkazy z Shift – Empire Earth / The Art of Conquest

Wpis atlasu Titan, etap 21. Opisuje, jak Titan przechowuje, dopisuje, uruchamia i usuwa cele jednostki przy rozkazach
ruchu do punktu: zwykły PPM, Shift + PPM i zwykły PPM w trakcie kolejki. Zakres: pojedyncza zwykła jednostka lądowa.
Trasy A*, omijanie przeszkód i ruch w taktach są poza zakresem.

Poprzednie wpisy: `rozkazy_gracza.md` (droga rozkazu), `grupy_ruchu.md` (grupy, flaga Shift +0xB5),
`cele_jednostek.md` (stan 8000, cele `EEUGLocation`).

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## Wynik w skrócie

1. **Kolejka.** Każda jednostka ma wektor „poziomów” celów pod +0x90 (początek +0x94, koniec +0x98, element 0x28 B).
   - Zwykła jednostka lądowa ma jeden poziom (poziom 0).
   - Poziom zawiera **kolejkę dwustronną wskaźników** do obiektów celów (bloki po 1024 wskaźniki) i licznik elementów.
   - **Pierwszy element to cel bieżący**: jednostka +0x1F0 jest zawsze kopią początku poziomu 0.

   [P: kod i pomiar w EE i AoC]
2. **Shift + PPM** (grupa +0xB5 = 1) dopisuje nowy cel **na koniec** kolejki, ale tylko jednostce, która ma już cel
   (+0x1F0 ≠ 0). Stan jednostki się nie zmienia. Jednostka bez celu traktuje Shift jak zwykły rozkaz [P].
3. **Zwykły PPM:**
   - zdejmuje cel bieżący (0x5EAE25);
   - czyści cały poziom 0 (0x5E9664);
   - wstawia nowy cel na początek (0x5F05BD);
   - ustawia stan 8000 („PrepareToMove”).

   Rozkaz w trakcie kolejki usuwa więc wszystkie oczekujące cele [P].
4. **Przejście do następnego celu.** Po dojściu do celu jednostka przechodzi do stanu 5000 („Idle”). Obsługa wejścia
   w ten stan wywołuje 0x5EAE25(0):
   - zdjęcie celu bieżącego;
   - aktywacja następnego celu (`EEUGLocation` vtable +0x54), która ustawia stan 8000 i rusza do kolejnego punktu.

   Przy pustej kolejce jednostka zostaje w stanie „Idle” z +0x1F0 = 0 [P: pomiar kolejności A → B → C; W: punkt
   przekazania w kodzie].
5. **Punkty pośrednie trasy** to też cele `EEUGLocation`, ale z flagą +0x32 = 1. Podsystem trasy wstawia je **na
   początek** kolejki, przed oczekujące rozkazy. Jednostka +0x1EC wskazuje pierwszy cel, który nie jest takim punktem,
   czyli bieżący rozkaz gracza [P: pomiar; W: kod 0x5EFC8E].
6. **EE ↔ AoC.** Struktura kolejki, dopisywanie, zastępowanie i zdejmowanie są identyczne. Różnią się adresy, kilka
   gałęzi wokół (lotnisko, typy ruchu) i nakładka AoC na wejście w stan jednostki lądowej [P].

## Funkcje i adresy

| Funkcja | EE | AoC | Uwagi |
|---|---|---|---|
| Obsługa stanu grupy 8000 – nadawanie celów jednostkom (część wspólna) | 0x5DC6B5 → gałąź lądowa 0x5DCCD5 | 0x5ECFF2 → 0x5ED3BC | etap 18 § 4 |
| Dopisanie celu na koniec poziomu (Shift) | 0x4412D4 | 0x43D416 | identyczne |
| Zdjęcie celu z początku, potem aktywacja następnego | 0x5EAE25 | 0x5F88FE | identyczne |
| Wyczyszczenie całego poziomu | 0x5E9664 | 0x5F6FBC | AoC: inny warunek lotniska |
| Ustawienie celu na początku poziomu | 0x5F05BD | 0x5FE863 | identyczne poza polem jednostki (+0x342 / +0x34E) |
| Odświeżenie +0x1F0 = początek poziomu 0 | 0x5EFC7C | 0x5FDF31 | – |
| Odświeżenie +0x1EC = pierwszy cel bez flagi +0x32 | 0x5EFC8E | 0x5FDF43 | – |
| Podgląd celu na początku poziomu k | 0x5E154F | – | – |
| Kolejka dwustronna: dodanie na koniec / zdjęcie z początku / element na początku | 0x402314 / 0x5F5CBB / 0x5F3434 | 0x4A96FD / 0x605999 / 0x5F8A26 | bloki 0x1000 B |
| `EEUGLocation` vtable +0x54 – aktywacja celu | 0x61529E | 0x627C99 | stan 8000, albo 5000 / 9006 przy celu w miejscu |
| `EEUGLocation` vtable +0x64 – zapytania (9014, 9015) | 0x6153A3 | 0x627DA5 | – |
| `EEUGLocation` vtable +0x70 – „cel aktualny” | 0x6159D7 (zawsze 1) | 0x620A18 | – |
| `EEUnitClass` vtable +0x74 – wejście w stan; dla 5000 zdjęcie celu | 0x61AD41 (wywołanie 0x61B181) | 0x62DB0F (0x62DF88); `EEUCLand` +0x74 AoC 0x6138C0 → 0x62DB0F | – |
| Ustawienie stanu jednostki | 0x5EFCF0 | – | stan = obiekt `EEUnitAction`, jednostka +0x1E8, numer +0x24 |
| Tablice nazw zdarzeń / stanów | 0x617C34 / 0x618E11 | – | nazwy w EXE, np. 8000 = „PrepareToMove” |

## Struktury

### Jednostka

| Pole EE / AoC | Znaczenie | Pewność |
|---|---|---|
| +0x90…+0x98 | wektor poziomów celów: +0x94 początek, +0x98 koniec; element 0x28 B; zwykła jednostka lądowa – 1 poziom | [P] – kod i pomiar (koniec − początek = 0x28) |
| +0x1E8 | bieżący stan – obiekt `EEUnitAction`, numer stanu +0x24 | [P] – pomiar: 5000 „Idle” w spoczynku, 10003 „Advance” w ruchu |
| +0x1EC | pierwszy cel poziomu 0 bez flagi punktu trasy (+0x32) – bieżący rozkaz | [P] – pomiar: przy punktach trasy wskazuje B |
| +0x1F0 | początek poziomu 0 – cel bezpośredni, także punkt trasy | [P] |

### Poziom celów (0x28 B)

| Pole | Znaczenie | Pomiar | Pewność |
|---|---|---|---|
| +0x00 | wskaźnik vtable (EE 0x83159C, AoC 0x846F0C) | – | [P] |
| +0x04…+0x14 | kolejka dwustronna: +0x08 mapa bloków, +0x0C liczba bloków, +0x10 indeks pierwszego elementu, +0x14 liczba elementów | mapa 8 bloków; indeks 0x1FFF, 0x1FFE, 0, 1; liczba 0–4 | [P] |
| +0x18 | właściciel (jednostka), przekazywany do celu (vtable +0x3C / +0x68) | adres jednostki | [P] |

Element i: indeks globalny = pierwszy + i, blok = (indeks >> 10) mod liczba bloków, pozycja = indeks & 0x3FF [P: kod
0x5F1BC6; pomiar – odczyt 3–4 elementów]. Dodanie na początek zmniejsza indeks pierwszego elementu (0 → 0x1FFF →
0x1FFE). Pusta kolejka wraca do indeksu 0. Zdjęcie elementu niszczy obiekt celu (vtable +0) [W].

### Cel `EEUGLocation` (0x38 B, rodzaj +5 = 1) – pola ważne dla kolejki

| Pole | Znaczenie | Pomiar | Pewność |
|---|---|---|---|
| +0x1D | 1 dla celu zwykłego rozkazu i celu, który został bieżący | A: 1; B, C po dopisaniu: 0; B po aktywacji: 1 | [P] wartości; mechanizm zmiany [N] |
| +0x31 | z `EEMPathTo`+0x1D: obrót do kąta celu po dojściu | 1 | [W] |
| +0x32 | punkt pośredni trasy (wstawiany na początek kolejki) | punkty trasy: 1, rozkazy: 0 | [P] |
| +0x34 | po dopisaniu z Shift = 0; cel zwykłego rozkazu później 4 | A: 4; B, C: 0 | [P] wartości; znaczenie [N] |

## Przebieg

### Zwykły PPM (grupa +0xB5 = 0)

```
EEMPathTo::Execute → grupa, stan 8000 → obsługa 0x5DB641 (wspólna część dla każdej pozycji k, jednostka J):
    cel := nowy EEUGLocation(pozycja k, θ); cel.+0x1D := 1                       ; 0x5DC902, 0x5DC945
    0x5EAE25(J, 0):  zdejmij cel bieżący (cel.vt+0x4C, zniszczenie), a gdy następny
                     „aktualny” (vt+0x70) – aktywuj go (vt+0x54)                  ; 0x5DCCEF
    0x5E9664(J, 0):  dla każdego celu vt+0x4C; wyczyść poziom 0                   ; 0x5DCCF8
    0x5F05BD(J, cel, 0, 0): wstaw cel na początek; +0x1EC, +0x1F0 := cel          ; 0x5DCD03
    stan J := 8000 (PrepareToMove); powiadomienie typu (vt+0x74)                  ; 0x5DCD4F, 0x5DCD5D
grupa: vtable +0x44 (przejście stanu grupy)                                       ; 0x5DCDDF
```

### Shift + PPM (grupa +0xB5 = 1)

```
dla każdej jednostki J z celem pozycji k:
    jeśli J.+0x1F0 ≠ 0 (ma cel):
        cel.+0x34 := 0                                                           ; 0x5DC912–0x5DC940
        0x4412D4(J, cel, 0): dodaj na koniec poziomu 0; cel.vt+0x3C;
                             odśwież +0x1F0 i +0x1EC                             ; 0x5DCCD5–0x5DCCE7
        (stan J bez zmian)
    w przeciwnym razie: jak zwykły PPM; J trafia na listę uruchomionych          ; 0x5DC945–0x5DC95B
grupa: gdy żadna jednostka nie była bez celu – nic;
       gdy były – vtable +0x40(lista uruchomionych)                              ; 0x5DCDC5–0x5DCE0A
```

Licznik jednostek bez celu (+0x1F0 = 0) jest liczony wcześniej, przy nadawaniu numerów pozycji (0x5DC77A) [P: kod].

### Dojście do celu i następny cel

```
ruch: 8000 PrepareToMove → 10002 Accelerate → 10003 Advance → … → 10001 PrepareToStop
      → (opcjonalnie 9006 TurnToUnitFacing) → 5000 Idle                          ; nazwy z tablic EXE
      [kolejność H – z nazw stanów; zmierzono tylko 10003 w ruchu i 5000 po dojściu]
wejście w Idle (EEUnitClass vt+0x74, 0x61B17E):
    [wyjątek: obywatele (Unit type 6) i typ 22 przy +0x1D8 ≠ 0 i dodatkowym warunku – bez zdjęcia; N]
    0x5EAE25(J, 0): zdejmij cel bieżący; gdy następny istnieje – aktywuj (vt+0x54):
        EEUGLocation::Aktywuj: jeśli pozycja J dokładnie = punkt celu:
                                   stan 9006 (gdy +0x31) albo 5000 – od razu następne wejście w Idle
                               w przeciwnym razie: stan 8000 (PrepareToMove)
    jeśli J.+0x1F0 = 0: zgłoszenie jednostki bezczynnej (0x4A35AA)               ; 0x61B186–0x61B1A5
```

Zapytanie „UnitFacingNotRequired” (9014) do celu: obrót do kąta celu nie jest potrzebny, gdy +0x31 = 0 albo gdy
w poziomie 0 są jeszcze inne cele. Oczekujące rozkazy z Shift pomijają więc obrót w punktach pośrednich [W: kod
0x6153A3].

### Synchronizacja z taktami

- Dopisanie, zastąpienie i wyczyszczenie kolejki wykonują się w `EEMPathTo::Execute`, czyli w poleceniu gracza
  wykonywanym przed taktami porcji (`rozkazy_gracza.md`, `grupy_ruchu.md`) [W].
- Zdjęcie celu po dojściu i aktywacja następnego zachodzą w takcie, w którym jednostka wchodzi w stan „Idle” – w tym
  samym wywołaniu [W].

## Weryfikacja

Zadania MCP 425–442, tylko odczyt pamięci, gwardia 0x100018B w scenariuszu „Wojna trojańska”. Zaznaczenie
pojedynczej jednostki kliknięciem. Rozkazy przez `ruch_rozkaz`, Shift jako modyfikator. Pauza F3 przed każdym
odczytem.

| Zadanie | Krok | Kolejka (poziom 0) | +0x1F0 / +0x1EC | Pewność |
|---|---|---|---|---|
| EE 426, 429 | PPM A, Shift B, Shift C | 3 elementy: [A (+0x34 = 4, +0x1D = 1), B (0, 0), C (0, 0)], indeks pierwszego 0x1FFF | A / A | [P] |
| EE 430, 431 | przy A | A zdjęty; na początku 2 punkty trasy (+0x32 = 1, z = 0), potem B (+0x1D = 1), C; indeks 0x1FFE | punkt trasy / B | [P] |
| EE 433, 434 | do B, B, do C, C | [B, C] → [C] (indeks 1) → pusta (indeks 0) | B → C → 0; stan 10003 → 5000 | [P] |
| EE 435 | Shift na jednostce bez celu | 1 element, +0x34 = 4, +0x1D = 1, nowa grupa – jak zwykły rozkaz | cel / cel | [P] |
| EE 435 | Shift, Shift w ruchu | 3 elementy (punkt trasy, B′, C′) | punkt trasy / B′ | [P] |
| EE 435 | zwykły PPM D w trakcie | 1 element – tylko D, nowa grupa, nowa mapa bloków | D / D | [P] |
| AoC 438, 440 | PPM A, Shift B, Shift C | [A (4, 1), B (0, 0), C (0, 0)] – jak w EE | A / A | [P] |
| AoC 441 | zwykły PPM D w drodze do A | 1 element – tylko D | D / D | [P] |

Stany z pamięci (EE 436): obiekt stanu w ruchu ma numer 10003 („Advance”), a w spoczynku 5000 („Idle”).

**Ograniczenia pomiarów.**
- Kliknięcie celu trafiało do innego pola niż żądane: np. (173,5; 130,5) i (171,5; 130,5) dały ten sam cel
  (174,5; 128,5). Cele odczytywano zawsze z pamięci.
- Jednostka omijała przeszkodę długą trasą. Punkty trasy pokazały się w kolejce, ale ich tworzenia (A*) nie badano.
- Przypadek celu dokładnie w miejscu jednostki nie był mierzony – tylko kod [W].
- Plik zadania 432 zapisał się pusty i został w kolejce Riverlands_MCP jako „w toku”. Nie wpłynął na wyniki.

## Różnice EE ↔ AoC

- Funkcje kolejki (dopisanie, zdjęcie, ustawienie) są identyczne w porównaniu znormalizowanym. Wyczyszczenie różni
  się tylko warunkiem dla lotnisk [P].
- W części wspólnej obsługi stanu 8000 AoC ma osobne gałęzie dla ID 0x41, typu ruchu 0x27 i `Unit type` 0x22. Gałąź
  zwykłej jednostki lądowej jest taka sama [P: kod].
- AoC `EEUCLand` vtable +0x74 to nakładka (0x6138C0), która woła bazową obsługę 0x62DB0F. W EE `EEUCLand` używa
  bazowej 0x61AD41 [P: kod].
- Pomiar w AoC: ta sama kolejka i to samo zastąpienie [P].

## Błędy oryginału

- **BO-4 (podejrzenie):** zwykły rozkaz przy niepustej kolejce najpierw aktywuje następny cel, a dopiero potem czyści
  kolejkę. Szczegóły w `BLEDY_ORYGINALU.md`.
- BO-1, BO-2, BO-3 bez zmian.

## Nierozpoznane zależności

1. Moment i warunek przejścia stanów ruchu do „Idle” (tolerancja dojścia; w pomiarze jednostka stawała do ok. 1 pola
   od punktu) – podsystem ruchu, poza zakresem [N].
2. Zmiana +0x1D celu przy aktywacji i znaczenie +0x34 (0 / 4) [N].
3. Wyjątek dla obywateli przy wejściu w „Idle” (`Unit type` 6 i 22, +0x1D8, 0x5F3473) [N].
4. Zachowanie grupy, gdy przy Shift wszystkie jednostki mają cel: grupa nie zmienia stanu [W]; dalszy los grupy [N].
5. Poziomy 1–3 (lotniska, 0x42) – poza zakresem.
6. Wstawianie punktów trasy (+0x32 = 1) przez podsystem trasy – poza zakresem.

## Konsekwencje dla OpenEE (bez zmian w kodzie)

- Jednostka potrzebuje kolejki celów, w której pierwszy element jest celem bieżącym (+0x1F0), oraz osobnego wskazania
  bieżącego rozkazu z pominięciem punktów trasy (+0x1EC).
- Shift dopisuje na koniec tylko jednostkom, które mają cel; bez celu działa jak zwykły rozkaz.
- Zwykły rozkaz:
  - zdejmuje cel bieżący z aktywacją następnego (BO-4);
  - czyści całą kolejkę;
  - wstawia nowy cel i ustawia stan 8000.
- Wejście w stan „Idle” zdejmuje cel bieżący i aktywuje następny. Cel w miejscu jednostki od razu przechodzi dalej.
- Punkty trasy wstawiane są na początek kolejki.
