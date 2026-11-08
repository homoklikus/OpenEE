# Testy referencyjne ruchu jednostki Titan dla OpenEE (etap 27)

Wpis atlasu z etapu 27. Opisuje zestaw przypadków referencyjnych dla przyszłych testów Godota: co jest w repozytorium,
co zostaje lokalnie i dlaczego, format danych, tolerancje oraz stan zgodności modelu v4 z pomiarami.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Dwa zestawy

| Zestaw | Gdzie | Zawartość | Dlaczego tam |
|---|---|---|---|
| **syntetyczny** | `dane/testy_ruchu/ruch_syntetyczne_etap27.json` (repozytorium) | 9 przebiegów ruchu na własnym, wzorowym terenie, 5 przypadków odpychania | teren i trasy niezależne od gry; brak zasobów, zrzutów i plików MCP |
| **pomiarowy** | `Testy_MCP/e27/referencje/` (lokalnie, poza repozytorium) | przebiegi zmierzone w EE i AoC, indeks `indeks.json` | zawiera pomiary z procesu gry i wysokości mapy kampanii |

**Zależność od tablic DLL.** Wartości oczekiwane obu zestawów zależą od tablic `UMCos` i `UMArcCos` z
`Low-Level Engine.dll` (`precyzja_numeryczna.md` § 2). Tablic nie da się dokładnie wygenerować wzorem, a w repozytorium
ich nie ma. Test Godota musi wczytać je z instalacji użytkownika. Bez instalacji test powinien zostać pominięty z
komunikatem, a nie zaliczony.

Zestaw syntetyczny zawiera wyłącznie liczby wyliczone modelem v4: pozycje, prędkości i kursy na wymyślonym terenie.
Nie odtwarza tablic ani innych zasobów gry. Parametry fizyki dwóch typów (gwardia EE, Aleksander AoC) są już opisane w
`ruch_jednostki.md` § 3.

## 2. Format danych (JSON)

Zestaw syntetyczny:
```
{
 "opis", "dt" (f32 z 1,5/44 s), "tolerancje": {pozycja, v, omega, kurs},
 "teren": {"typ": "siatka_wierzcholkow", "wzor", "zakres_x", "zakres_y", "interpolacja": GetMeshZ},
 "przypadki": [ {
   "nazwa", "opis", "wariant": "ee" | "aoc",
   "parametry": {a, vmax, alfa, wmax, rozmiar, c4, c8, t488 [, pochyla]},
   "start": {x, y, kurs, v, omega}, "punkty": [{x, y}], "kurs_koncowy": rad | null,
   "oczekiwane": [ {takt, x, y, v, omega, kurs, stan, punkt} ],   // wybrane takty + ostatni
   "koniec_takt"
 } ],
 "odpychanie_0x549179": [ {u: {x, y, promien}, o: {x, y, promien, v}, kolizja, push_dla_o, push_dla_u} ],
 "niedostepne": {...}
}
```
- `takt` liczony od rozkazu (takt 1 = pierwsza aktualizacja po wydaniu).
- `stan` to numer stanu z `skrypty_stanow.md` (10003 Advance, 9000 zdarzenie punktu, 2015, 9006, 5001 koniec).
- `punkt` to liczba zdjętych punktów trasy.
- `kurs` = UMArcTan2(−m01, m11) z macierzy.

Zestaw pomiarowy (`pomiar_*.json`):
```
{ "zrodlo": "<nr zadania>.wynik.json", "jednostki": [adresy], "rozkazy": [{f, a, po_probce}],
  "probki": [ {t (ms gry), rng (stan LCG), rng_kroki, <adres>: {x, y, z, m01, m11, v, w, tryb, k248, k20C,
              k330|k33C, kontakty, push: [x, y], stan}} ] }
```
Przebiegi z etapów 25–26 (EE 500, AoC 505, EE 517, AoC 525, EE 524) zostają w `Testy_MCP/e25/serie.json`,
`Testy_MCP/e26/serie.json` i `serie26.json` w dotychczasowym formacie wierszy (`ruch_trasa_przeszkody.md` § 10).

## 3. Przypadki 1–12

| Nr | Przypadek | Syntetyczny | Pomiar (lokalny) | Status |
|---|---|---|---|---|
| 1 | Przyspieszanie na płaskim | S1 (20 taktów) | EE 500 początek | v4 zgodny [P] |
| 2 | Hamowanie do celu | S2 (z obrotem końcowym) | EE 517_f3, AoC 525_f2 | EE 517: błąd 0,0000, 0 rozbieżnych taktów [P] |
| 3 | Krótki rozkaz BO-7 | S3 | EE 517_f2, AoC 525_f1 | błąd 0,006–0,026 wynika z szacowania celu z serii [W] |
| 4 | Obrót w miejscu | S4b; S4 (cel za plecami) | obrót końcowy EE 500 | S4b – [W]: pierwszy takt obraca do UMArcTan2(0, 0) = +π/2, do sprawdzenia pomiarem |
| 5 | Zakręt w ruchu | S5 (EE), S5a (AoC) | EE 500, AoC 505 | AoC 505: koniec w tym samym takcie [P]; EE 500: max 0,050 [P/N] |
| 6 | Podjazd | S6 (rampa 0,15/pole) | EE 524 (H), EE 536 | reguła stoku [P] (etap 26) |
| 7 | Zjazd | S7 | brak osobnego pomiaru | [W] |
| 8 | Zmiana punktu trasy | S5 (9000 → 2015 → 10003) | EE 500 | liczba taktów z innym punktem: 8 z 813 [P] |
| 9 | Przejście Shift | – | EE 426, 429 (etap 21, zawartość kolejki) | kolejka [P]; przejście do następnego celu w ruchu bez pomiaru [W] |
| 10 | Kolizja i odpychanie | 5 przypadków 0x549179 | EE 535, EE 536 | wzór dokładny [P] |
| 11 | Zablokowany krok | – | – | reguła `fizyka_terenu.md` § 4 [W]; bez pomiaru izolowanego |
| 12 | Objazd | – | – | niepotwierdzony dynamicznie [N] |

## 4. Tolerancje

- Pozycja, v, kurs: 1e-5 przy porównaniu wartości f32. Docelowo porównanie bitowe f32: model v4 odtwarza EE 517 i
  AoC 525 bitowo w taktach bez kolizji.
- ω: 1e-4 (ω jest wielokrotnością α·dt z zaokrągleniem f32).
- Stan i aktywny punkt: dokładnie.
- Odpychanie: 1e-7 względnie.

Tolerancje dla porównań z pomiarem: tylko do diagnostyki (pomiar ma duplikaty próbek i cel szacowany z serii).

## 5. Metryki modelu v4 (regresja)

Wszystkie metryki liczone w taktach zmierzonych, bez interpolacji. Duplikaty próbek (odczyt czasu po kolejnym takcie)
są pomijane.

| Scenariusz | Model | Próbek | Pozycja śr / max | v śr / max | Kąt śr / max | Koniec ruchu | Pierwszy rozbieżny takt | Takty z innym stanem | Takty z innym punktem |
|---|---|---|---|---|---|---|---|---|---|
| EE 500 gwardia | v2 | 810 | 0,1186 / 0,1582 | 0,0089 / 0,409 | 1,19° / 31,7° | −7 | 48 | 56/810 | 91 |
| EE 500 gwardia | v3 | 814 | 0,0106 / 0,0262 | 0,0010 / 0,136 | 0,29° / 9,7° | +0 | 48 | 21/814 | 6 |
| EE 500 gwardia | v4 | 813 | 0,0082 / 0,0497 | 0,0012 / 0,332 | 0,19° / 4,9° | +0 | 48 | 21/813 | 8 |
| AoC 505 Aleksander | v2 | 732 | 0,1763 / 0,2181 | 0,0152 / 0,477 | 1,00° / 26,0° | −8 | 70 | – | 122 |
| AoC 505 Aleksander | v3 | 748 | 0,0054 / 0,0842 | 0,0040 / 0,541 | 0,38° / 15,6° | +15 | 70 | – | 15 |
| AoC 505 Aleksander | v4 (obrót EE) | 735 | 0,0032 / 0,0123 | 0,0002 / 0,068 | 0,14° / 3,1° | +0 | 70 | – | 1 |
| AoC 505 Aleksander | v4 (obrót AoC) | 735 | 0,0016 / 0,0148 | 0,0001 / 0,068 | 0,12° / 3,2° | +0 | 224 | – | 1 |
| EE 517 krótki (BO-7) | v2 = v3 = v4 | 69 | 0,0062 / 0,0131 | 0,0086 / 0,068 | 2,30° / 10,6° | +0 | 2 | 0/69 | 0 |
| EE 517 ok. 1,4 pola | v2 | 60 | 0,0350 / 0,1640 | 0,0667 / 0,370 | 0,00° / 0,0° | −35 | 32 | 4/60 | 4 |
| EE 517 ok. 1,4 pola | v3 | 86 | 0,0000 / 0,0001 | 0,0000 / 0,000 | 0,01° / 0,0° | +0 | – | 0/86 | 0 |
| EE 517 ok. 1,4 pola | v4 | 86 | 0,0000 / 0,0000 | 0,0000 / 0,000 | 0,00° / 0,1° | +0 | – | 0/86 | 0 |
| AoC 525 krótki (BO-7) | v2 = v3 = v4 | 81 | 0,0259 / 0,0492 | 0,0317 / 0,069 | 0,02° / 0,9° | −3 | 2 | – | 3 |
| AoC 525 ok. 1,9 pola | v2 | 59 | 0,0021 / 0,0135 | 0,0202 / 0,205 | 0,02° / 0,2° | −3 | 50 | – | 1 |
| AoC 525 ok. 1,9 pola | v3 | 60 | 0,0006 / 0,0112 | 0,0085 / 0,136 | 0,02° / 0,2° | −2 | 68 | – | 1 |
| AoC 525 ok. 1,9 pola | v4 | 60 | 0,0005 / 0,0110 | 0,0085 / 0,136 | 0,01° / 0,2° | −2 | 68 | – | 1 |

- „Takty z innym stanem” tylko dla EE: AoC ma inne numery stanów w odczycie i mapy nie ustalono.
- Krótkie rozkazy (BO-7): błąd pochodzi z celu szacowanego z serii (kolejki punktów nie da się odczytać jednym
  dereferencjonowaniem). Modele są tu identyczne, bo nie ma obrotu.
- AoC 525 ok. 1,9 pola: −2 takty i pierwsza rozbieżność w takcie 68 – kontakt z gwardią na końcu trasy (kolizje nie są
  częścią v4).
- Współczynników nie dopasowywano. Wszystkie stałe pochodzą z kodu i `dbobjects`.

**Czego model v4 nie obejmuje i co zgłasza:** kolizji i odpychania w przebiegu (wzór jest osobno), testu kroku,
objazdu 9002, maszyny celów (Shift), ruchu grupowego. Przebieg, w którym te mechanizmy zadziałały (kontakty > 0,
+0x248 > 0, +0x330 ≠ 0), oznaczamy jako „niemodelowany” od pierwszego takiego taktu.

## 6. Odtwarzanie

Model v4 i skrypty (`model_ruchu4.py`, `metryki4.py`, `kolizje.py`, `gen_syntetyczne.py`, `umarctan2.py`,
`transform.py`) leżą lokalnie w `Testy_MCP/e27/model/`, poza repozytorium. Wymagają tablic z DLL. Implementacja Godota
ma powstać niezależnie, według `specyfikacja_ruchu_godot.md`. Ten zestaw służy do jej sprawdzenia.

## 7. Aktualizacja etapu 29

| Zestaw | Gdzie | Zawartość |
|---|---|---|
| A* syntetyczne | `cpp/tests/dane/astar_referencja.json` (repozytorium) | 18 siatek, wynik modelu e24 z przebiegiem rozwijania |
| A* na mapie gry | `Testy_MCP/e29/astar_mapa_e24_lokalne.json` (lokalnie) | dostępność pól z pamięci gry, trasy A/C i liczby E z gry |
| serie porównawcze | `Testy_MCP/e29/serie_porownawcze.json` (lokalnie) | EE 500, AoC 505, EE 517 ×2, AoC 525 ×2 + teren + serie dwóch jednostek EE 546/547 |
| rejestracje surowe | `Testy_MCP/ee_obserwacja/e29_54x_*.json` (lokalnie) | 5 jednostek co takt, wszystkie pola ruchu, RNG |

Przypadek 10 („kolizja i odpychanie”) ma teraz pomiar dwóch jednostek w ruchu (EE 547). Przypadek 12 (objazd) nadal
nie jest potwierdzony.

Metryki Core kontra gra (`core_porownanie_gra`) są identyczne z metrykami modelu v4 (§ 5), bo Core to bitowy port
modelu.
