# Mapa scenariusza w reprezentacji Titan – EEMap, EETile, teren komórek i zajęte pola (EE / AoC)

Wpis atlasu Titan, etap 30. Opisuje, jak Titan przechowuje mapę pól (`EEMap`, komórki `EETile`) i jak OpenEE Core
odtwarza ją z pliku SCN (`MapaTitan`, `cpp/core/src/mapa.cpp`).

**Oznaczenia:** [P] potwierdzone kodem i pomiarem, [W] wniosek z kodu, [H] hipoteza, [N] nieustalone.
Adresy: EE `Empire Earth.exe` (e352d7ae…), AoC `EE-AOC.exe` (db8fc5ce…). Przesunięcia: `dane/titan/struktury_titan.json`.

## 1. Struktury

| Element | EE | AoC | Pewność |
|---|---|---|---|
| wskaźnik `EEMap` | GRA_STAT+0xBC = [0x9183BC] | [0x930DFC] | [P] |
| tablica wskaźników komórek, indeks y·W + x | +0x1816D4 | +0x1955F0 | EE [P], AoC [W] |
| linie brzegu x + y = s1, x + y = s2, \|y − x\| = d | +0x1816EC / F0 / F4 | +0x195608 / 0C / 10 | EE [P] |
| szerokość W (porównanie bez znaku dla x i y) | +0x1816FC | +0x195618 | EE [P] |
| komórka: obiekt `EETile` (RTTI, vtable EE 0x82C674) | +4 teren, +8 lista obiektów | jak EE | EE [P], AoC [W] |
| węzeł listy obiektów | +4 obiekt, +8 następny | jak EE | [P] |

- AoC: wszystkie pola `EEMap` za siatką są przesunięte o +0x13F1C względem EE. Wykryte narzędziem
  `narzedzia/titan/struktury.py przesuniecie` z rozkładu przesunięć w kodzie (270/279 odwołań do tablicy komórek,
  373/386 do szerokości) [W]; potwierdzenie odczytem – § 5.
- Pole +0x181700 (sąsiad szerokości) **nie** jest wysokością mapy (odczyt: 7) [P].

Pomiar EE (zadanie 550, „Wojna trojańska”, 280 × 280): W = 280, s1 = 139, s2 = 419, d = 140 – dokładnie wartości
znane z etapu 24. Komórek z obiektem `EETile` jest 39 480, czyli tyle, ile pól rombu SCN (T = 2AB + A + B) [P].

## 2. Geometria SCN = współrzędne EEMap

Pole SCN w wierszu r i kolumnie c (kolejność rombu, `narzedzia/eeformaty/scn.py`) to komórka EEMap (x = c, y = r).
Każda z 39 480 komórek z pamięci ma odpowiednik w SCN [P]. Linie brzegu to skrajne wartości x + y i |y − x| pól rombu
(Core liczy je z geometrii; zgodne z pamięcią) [P].

## 3. Teren komórki (EETile +4)

Wartość +4 indeksuje tablicę typu `EEUnitClass`+0x5D6 („teren dozwolony”). W pomiarze występują 0, 1, 2, 5, 6, 9,
10, 11.

**Reguła** (Core: `MapaTitan::teren_z_pola`) [W: zgodność 39 336 / 39 480 = 99,64 %]:
```
flagi pola SCN, bit 0 = pole pod wodą; f10 = pierwszy f32 rekordu pola (wysokość pola)
woda:  f10 < −0,3                                  → 1   (woda głęboka; 17 847 / 17 847 pól)
       ≥ 3 z bitów 1–4 flag ustawione              → rodzina tekstury
       w przeciwnym razie                          → 10  (woda płytka)
ląd:                                               → rodzina tekstury = dbterrain „Terrain family” tekstury pola
```
- Lądowe pola zgodne w 99,3 %. Wszystkie różnice dotyczą wartości 9 (klify): tekstura klifu bywa terenem 0, a inne
  tekstury bywają 9 [N]. Core oznacza pola rodziny 9 i ich sąsiadów jako niepewne; 117 ze 144 różnic leży w tym
  obszarze.
- Próg −0,3 leży między zmierzonymi −0,274 (płytka) i −0,309 (głęboka) – dokładna wartość [N].
- Znaczenie bitów 1–4 flag (najpewniej narożniki pola nad wodą) [H].

**Teren dozwolony dla typu** (tablica +0x5D6, odczyt zad. 552): gwardia (422) i Aleksander (173) mają
`1,0,1,1,1,1,1,1,1,0,1,1,0,0,0,0` – zabronione 1 (woda głęboka) i 9 (klif); **woda płytka (10) jest dozwolona** [P].
*[Etap 30 – korekta `astar_pola.md` § 7: „woda (teren 1) i teren 10 są niedostępne” – zabronione są 1 i 9.]*

**Przejezdność przypadków A–E etapu 24** na mapie z SCN (teren z pamięci albo z reguły, obiekty z SCN): trasy A, C
i liczba iteracji E (145 / 8 wywołań) identyczne jak w grze [P] (`core_mapa`). Teren z reguły różni się dla typu 422
w 91 polach, żadne z nich nie leży na trasach przypadków.

## 4. Obiekty na listach komórek

- Obiekt jest na listach pól **[X..X+n−1] × [Y..Y+n−1]**, gdzie (X, Y) = pole obiektu (+0x1C/+0x20), a n = dbobjects
  „Square occupied” [P: 71/71 typów; 5 282 / 5 325 obiektów – różnice to jednostki, które zmieniły pole między
  zapisem SCN a zrzutem].
- **Jednostki ruchome są na liście jednego pola** (swojego +0x1C/+0x20) [P: 40/40 jednostek typu 422].
  *[Etap 29 – zastąpione: „obiekt na listach wszystkich pól pod obrysem (promień)”, `walidacja_kolizji.md` § 10.]*
  Kontakty powstają inaczej: odbudowa listy kontaktów (EE 0x5E8F0E) przegląda okno pól
  [floor(x − R), floor(x + R)] × [floor(y − R), floor(y + R)], R = max(0,5; 0,5·s), s = rozmiar kolizji typu (×2,
  gdy ≥ 1,0); kandydaci muszą m.in. mieć HP (+0x3C) > 0 i tę samą klasę ruchu (typ vt+0x5C) [W]. Core: etap 30.
- `EEUnitClass`+0x4B4 = dbobjects „Unit type” [P: 71/71]. Blokada pola (+0x600): 1 dla zasobów i drzew (typ 1),
  budynków (2) oprócz farmy, fortecy (29) i gorących źródeł (383); 0 dla jednostek, bram (25), farmy i skał
  dekoracyjnych [P]. Reguły wyprowadzającej +0x600 z bazy nie ustalono [N] – import korzysta z wartości z pamięci
  (dane referencyjne) albo z tabeli typów.

## 5. Weryfikacja AoC

Zadanie 570 (ten sam scenariusz w AoC): wynik w raporcie etapu 30 (§ 8).

## 6. OpenEE: jedna interpretacja mapy

- Dekodowanie bajtów: importer GDScript (`godot/silnik/importery/scenariusz.gd`, od etapu 30 także f10) i
  `narzedzia/titan/eksport_mapy.py` (Python) – oba tylko dekodują kawałek 4.
- Interpretacja Titan (teren komórek, linie brzegu, zajęte pola, przejezdność dla typu) jest wyłącznie w Core:
  `MapaTitan::z_scn` i `MapaTitan::siatka`. Godot dostaje ją przez GDExtension (`wczytaj_mape_scn`,
  `utworz_swiat_na_mapie`, `mapa_teren`, `pole_przejezdne`).
- Test: ten sam scenariusz przez GDScript → GDExtension i przez Python → CTest daje ten sam skrót mapy
  (`testy_gdextension.gd`, `core_mapa`).
- Stara struktura `MapaNawigacji` (etap 5, GDScript) zostaje dla dotychczasowej symulacji GDScript; jej kategorie
  (klif z tekstury, próg głębokości) to przybliżenie sprzed rozpoznania EETile – nie używać jako referencji Titan.

## 7. Niewiadome

1. Klify (rodzina 9) – reguła przypisania [N]; prawdopodobnie z obiektów klifów (`dbcliffterrain`) albo z danych
   bloku pola SCN.
2. Dokładny próg głębokości i znaczenie bitów flag [N]/[H].
3. Reguła pola +0x600 z bazy danych [N].
4. Kto i kiedy wypełnia EETile+4 przy wczytywaniu (konstruktor EETile nie ma bezpośredniego zapisu vtable w kodzie –
   obiekty prawdopodobnie odtwarzane z serializacji) [N].
