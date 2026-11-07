# Zegar symulacji (EEPhysics) – Empire Earth / The Art of Conquest

Etap 14 OpenEE – pierwsza część atlasu funkcji silnika Titan (`docs/titan/README.md`). Dokument opisuje, jak
oryginał aktualizuje licznik czasu gry `A_GRA+0xD0` i liczniki taktów `+0xB4`, `+0xC8`, które w etapie 13 znaliśmy
tylko z pomiarów (`docs/MECHANIKA_PREDKOSCI_EE.md` § 2).

**Oznaczenia:**
- **[P]** potwierdzone, tj. kod maszynowy i pomiar w działającej grze dają to samo albo kod jest jednoznaczny i
  zgodny w obu plikach;
- **[W]** wniosek z kodu, sprawdzony częściowo;
- **[H]** hipoteza;
- **[N]** nieustalone.

## Warianty plików i metoda

| Gra | Plik | SHA-256 |
|---|---|---|
| EE | `Empire Earth.exe` | `e352d7ae5ebc91f8d2f9c4363e41e990d7be8b063b1ee9e686a0d2a5f9bea2b5` |
| AoC | `EE-AOC.exe` | `db8fc5ceb85dbb9bb7e47804e15f1a025373efe995948cddc5b3d05605797f52` |

Obie kompilacje pochodzą z GOG z NeoEE, baza obrazu 0x400000. Nazwy sekcji PE są pomieszane, a kod leży w pierwszej
sekcji (RVA 0x1000).

**Metoda:**
- analiza statyczna: pefile + capstone, bez modyfikacji plików;
- szukanie wszystkich zapisów do przesunięć +0xD0/+0xB4/+0xC8 i grupowanie ich w funkcje;
- RTTI klas, nazwy importów z `Low-Level Engine.dll`;
- porównanie EE ↔ AoC instrukcja po instrukcji po zastąpieniu adresów bezwzględnych symbolem, z wyrównaniem
  sekwencji, a nie na podstawie wyglądu funkcji.

**Weryfikacja:** jeden pomiar w każdej grze, tylko odczyt pamięci (zadania MCP 360 EE i 362 AoC). Odczytano pola
obiektu w trzech chwilach: w ruchu, w pauzie F3 i po wznowieniu.

## Struktury

`A_GRA` (EE: wskaźnik pod 0x919774, AoC: 0x9318F0) wskazuje obiekt klasy **`EEPhysics`**. RTTI `.?AVEEPhysics@@`
potwierdzone w obu plikach [P]:
- vtable EE: 0x82CB5C;
- vtable AoC: 0x842304.

Klasa pochodzi od klasy bazowej z własnym wątkiem i timerem. Pola 0x00–0x68 należą do klasy bazowej; nazwy klasy
bazowej nie ustalono [N].

| Pole | Typ | Znaczenie | Pewność |
|---|---|---|---|
| +0x04 | lista | kolejka komunikatów (komunikat taktów: typ 0x28 w bajcie +8) | [P] |
| +0x2C | u8 | timer uruchomiony; gdy 1, nowy komunikat taktów czeka, dopóki poprzednie takty się nie wykonają | [P] (kod), w pomiarze = 1 |
| +0x48 | wskaźnik | obiekt `TMTimer` (`Low-Level Engine.dll`) | [P] |
| +0x50 | f32 | okres taktu w sekundach rzeczywistych = 1/n | [P] (pomiar: 0,022727) |
| +0x54 | u32 | interwał timera w ms = floor(1000/n) | [P] (pomiar: 22) |
| +0x58 | u32 | n = floor(1/okres) – takty na sekundę rzeczywistą (nominalnie) | [P] (pomiar: 44) |
| +0x5C | u32 | licznik wywołań funkcji taktu przez wątek (także w pauzie) | [P] (kod, pomiar: ~45,5/s) |
| +0x60 | u32 | budżet wywołań funkcji taktu w jednym obiegu wątku | [W] |
| +0x80 | u32 | suma taktów przydzielonych komunikatami | [P] (pomiar: +0x80 − +0xB4 = stała + takty oczekujące) |
| +0x88 | f32 | n / G – takty na sekundę czasu gry | [P] (29,333) |
| +0x8C | f32 | G / n – sekundy czasu gry na takt | [P] (0,034091) |
| +0x94 | f32 | **czas gry w ms (akumulator zmiennoprzecinkowy)** | [P] |
| +0x98 | f32 | **przyrost czasu gry na takt w ms = 1000 · G / n** | [P] (34,0909) |
| +0xA4 | u32 | int(+0x98) | [P] (34) |
| +0xA8 / +0xAC | u32 | `TMGetTime()` (ms rzeczywiste) przy bieżącym i poprzednim takcie | [P] |
| +0xB0 | u32 | int(`URandom::Generate()`) – wartość losowa pobierana w każdym takcie | [P] (kod) |
| +0xB4 | u32 | **licznik wykonanych taktów** (rośnie stale, zerowany tylko przy resecie) | [P] |
| +0xB8 | u32 | takty przydzielone i jeszcze niewykonane | [P] |
| +0xBC / +0xC0 / +0xDC | u32 | statystyka: suma odstępów między taktami (ms rzeczywiste), liczba, średnia; zerowane po przekroczeniu 1000 ms | [P] (kod), pomiar: +0xDC = 22–23 |
| +0xC4 / +0xC8 / +0xD8 | u32 | statystyka: suma czasu wykonania taktów (ms rzeczywiste), **liczba taktów w oknie**, średnia; po przekroczeniu sumy 1000 ms zerowane | [P] (kod) |
| +0xCC | u32 | suma +0x54 po każdym takcie (nominalne ms rzeczywiste), porównywana z progiem globalnym; po przekroczeniu wywołuje osobną akcję | [W] (cel akcji [N]) |
| +0xD0 | u32 | **czas gry w ms (całkowity) = obcięcie +0x94** | [P] |
| +0xE6 | u8 | flaga: takt przesuwa tylko czas gry (+0x94/+0xD0, +0xB8), bez aktualizacji świata, statystyk i +0xB4 | [P] (kod); w pomiarze = 0 |
| +0xE8 | u8 | tylko AoC: jednorazowy komunikat po osiągnięciu czasu gry z ustawienia | [W] |

Globalne `G` = szybkość gry, f32 w polu obiektu świata `GRA_STAT+0xC0`:
- EE: 0x9183C0 (= 0x918300 + 0xC0);
- AoC: 0x930E00 (= 0x930D40 + 0xC0).

W pomiarze obu gier G = 1,5 [P].

## Funkcje

| Funkcja | EE | AoC | Zgodność EE ↔ AoC |
|---|---|---|---|
| Wątek symulacji klasy bazowej `RTSPhysics::Main` (nazwa: etap 15) | 0x5532FB | 0x56140C | identyczne po normalizacji adresów (168 instr.) |
| Takt `EEPhysics` (vtable +0x20) | 0x546C63 | 0x553082 | instrukcje zegara identyczne; AoC ma dodatkowy blok niezwiązany z zegarem (flaga +0xE8) i inną alokację rejestrów |
| Takt alternatywny (vtable +0x1C) | 0x546C3B | 0x55305A | identyczne |
| Obsługa komunikatu taktów | 0x5470B0 | 0x55355C | identyczne (215 instr.) |
| Ustawienie częstotliwości n (okres 1/n, timer) | 0x553663 | 0x561774 | identyczne (58 instr.) |
| Przeliczenie kroku czasu gry (vtable +0x0C) | 0x5476C1 | 0x553BD8 | identyczne (22 instr.) |
| Reset zegara | 0x54650E | 0x552909 | te same pola, inna kolejność zapisów; AoC dodatkowo ustawia flagę +0xE8 |
| `__ftol2` (float → int, obcięcie) | 0x53BA92 | 0x548291 | identyczne |
| Zapisy G (`GRA_STAT+0xC0`) | 0x4B6BDC, 0x52EB72, 0x5A1C46, 0x5AD53F | 0x4BEFC1, 0x539AFE, 0x5B1E5A, 0x5BD897 | jw. (przy 0x5AD53F/0x5BD897: G = 0,1 · k + 0,1) |

Importy z `Low-Level Engine.dll`, czytelne nazwy C++:
- `TMGetTime()` – EE 0xB305F8, AoC 0xB545F4;
- `URandom::Generate()`;
- `TMTimer::SetInterval` / `Start` / `Stop` / `SetEvent`;
- `Sleep` z kernel32.

## Algorytm

### 1. Częstotliwość taktów i krok czasu gry

Obsługa komunikatu taktów odczytuje z komunikatu dwa bajty:
- **liczbę taktów do wykonania** (bajt +0x10): zapisuje ją do +0xB8 i dodaje do +0x80;
- **n** (bajt +0x11): wywołuje ustawienie częstotliwości z argumentem `1/n` [P].

Ustawienie częstotliwości, wykonywane tylko przy zmianie wartości:
- okres = 1/n (+0x50), interwał = floor(1000·okres) ms (+0x54), n = floor(1/okres) (+0x58);
- restart `TMTimer` z nowym interwałem;
- wywołanie vtable+0x0C, czyli przeliczenie kroku [P]:

```
+0x88 = n / G          (takty na sekundę gry)
+0x8C = G / n          (sekundy gry na takt)
+0x98 = 1000 · G / n   (ms gry na takt)
+0xA4 = int(+0x98)
```

Pomiar w EE i AoC: n = 44, G = 1,5, czyli +0x98 = 34,0909 ms, +0x54 = 22 ms [P].

[Etap 15 – doprecyzowane] n to parametr kroku i timera fizyki, a nie liczba taktów wykonywanych na sekundę.
Takty przychodzą porcjami po 15 co 350 ms, czyli 42,857/s. Wartość 44 jest przepełnieniem bajtu (300 − 256)
w `NESynchronousServer::TuneForSlowCPU`: `docs/titan/przydzial_taktow.md`.

### 2. Takt

Wątek klasy bazowej (start 0x5532FB / 0x56140C) czeka na zdarzenie `TMTimer` (co +0x54 = 22 ms). Po każdym
zdarzeniu wywołuje funkcję taktu (vtable +0x20) najwyżej dwa razy, zależnie od budżetu +0x60. Każde wywołanie
zwiększa +0x5C [P: kod; pomiar: +0x5C rośnie ~45,5/s, także w pauzie].

Funkcja taktu:
1. Jeśli +0xB8 = 0, pobiera następny komunikat taktów z kolejki (obsługa komunikatu, § 1).
2. Jeśli nadal +0xB8 = 0, kończy działanie: zegar stoi.
3. W przeciwnym razie wykonuje jeden takt [P]:

   ```
   +0x94 = +0x94 + +0x98              (f32: czas gry w ms)
   +0xD0 = obcięcie(+0x94)            (__ftol2)
   +0xB0 = int(URandom::Generate())
   +0xAC = +0xA8;  +0xA8 = TMGetTime()
   +0xB8 = +0xB8 − 1
   ```

   Jeśli flaga +0xE6 jest ustawiona, takt kończy się w tym miejscu. W przeciwnym razie aktualizuje świat
   (wywołania podsystemów – poza zakresem tego dokumentu). Na końcu liczy statystyki (+0xC4/+0xC8/+0xD8 oraz
   +0xBC/+0xC0/+0xDC, zerowane po sumie ≥ 1000 ms) i wykonuje `+0xB4 = +0xB4 + 1` [P]. Dlatego +0xB4 liczy
   takty z aktualizacją świata, a +0xD0 wszystkie takty; w pomiarze +0xE6 = 0, więc obie wartości rosną razem.

Czas gry jest więc wyłącznie **liczbą wykonanych taktów × krok**. Nie zależy od zegara rzeczywistego, bo
`TMGetTime` służy tylko statystyce [P].

### 3. Pauza

W pauzie (F3) przestają przychodzić komunikaty z nowymi taktami: +0x80 stoi [P, pomiar]. Takty już przydzielone
(+0xB8) wykonują się do końca. W pomiarze: +0xB8 = 10–11 przed pauzą, potem +0xB4 wzrosło o tyle samo i stanęło. Od tej
chwili funkcja taktu kończy się w kroku 2, więc +0x94, +0xD0 i +0xB4 nie zmieniają się, a +0x5C dalej rośnie [P].
Sam warunek pauzy leży w kodzie, który wysyła komunikaty taktów [N] (§ 6).

### 4. Liczniki etapu 13 – wyjaśnienie

| Licznik (etap 13) | Algorytm | Zgodność z pomiarem |
|---|---|---|
| +0xD0 – ms czasu gry, 1460,7–1461,5/s | obcięcie sumy +0x98 = 34,0909 na takt; skoki 34/35 ms, czyli 68 ms na 2 takty | [P] – 1461/34,0909 = 42,86 taktu/s |
| +0xB4 – takty | licznik wykonanych taktów | [P] – pomiar zadań 360/362: 215 taktów w 5037 ms czasu `TMGetTime` = 42,68/s; etap 13 podał 43,32/s z okna < 1 s (mniej dokładne) |
| +0xC8 – „takty” | liczba taktów w oknie statystyki; zerowana, gdy suma czasu wykonania taktów przekroczy 1000 ms | [P] – rośnie z tą samą częstotliwością co +0xB4, ale nie jest licznikiem całkowitym |
| +0x5C – 45,5/s | wywołania funkcji taktu przez wątek (1000/22 = 45,45/s) | [P] |
| Pauza F3 | brak nowych komunikatów taktów | [P] |
| Czas gry = 1,461 × rzeczywisty | nominalnie G = 1,5 (n = 44 takty/s × 34,09 ms); rzeczywiście 42,68–42,86 taktu/s, czyli 97–97,4% nominału | [P] dla wzoru i wartości; przyczyna niedoboru taktów [N] [Etap 15 – ustalone: 15 taktów co 350 ms = 42,857/s, obcięcie 44 · 0,35 = 15,4 → 15; `przydzial_taktow.md`] |

## 5. Szybkość gry G

G = 0,1 · k + 0,1, gdzie k to liczba całkowita z ustawienia (pole +0x134 obiektu ustawień, zapis EE 0x5AD53F,
AoC 0x5BD897) [P: kod]. G = 1,5 odpowiada k = 14. Pozostałe zapisy przepisują G z innych miejsc, np. przy
wczytaniu stanu (0x4B6BDC/0x4BEFC1, 0x52EB72/0x539AFE, 0x5A1C46/0x5B1E5A). Po każdym zapisie wywoływana jest
metoda obiektu świata (vtable +0x2C); że przelicza ona krok `EEPhysics`, to hipoteza [H].

Powiązania nie ustalono [N]:
- które ustawienie interfejsu (np. „Normalna”) odpowiada k = 14;
- czy w ustawieniach gry są inne wartości k.

## 6. Zależności poza zakresem (zakończony wątek)

1. **Nadawca komunikatów taktów** (typ 0x28, kolejka EEPhysics+4). [Etap 15 – ustalone: serwer lockstep
   `NESynchronousServer` / `EEServer`, opis w `docs/titan/przydzial_taktow.md`.] Stan wiedzy z etapu 14 – nie ustalono:
   - kto i jak często je wysyła;
   - skąd bierze liczbę taktów i n = 44;
   - gdzie sprawdza pauzę.

   To prawdopodobnie warstwa komunikacji (komunikaty są przetwarzane w trybie lockstep także w grze jednoosobowej)
   [H]. Od niej zależy, dlaczego wykonuje się 42,7–42,9 zamiast 44 taktów/s. Kontynuacja wymaga analizy
   warstwy sieci/komend, więc jest osobnym wątkiem.
2. **Wywołujący wątek / budżet +0x60** (klasa bazowa: `RTSPhysics`, etap 15) – warunek budżetu 100 000 albo z innego obiektu: [W].
3. **Aktualizacja świata w takcie** (wywołania po kroku 3) – osobne podsystemy.
4. **Akcja okresowa przy +0xCC** i blok AoC przy +0xE8 – nie dotyczą zegara.

## 7. Porównanie z OpenEE (`ZegarSymulacji`, `Symulacja`) – bez zmian w kodzie

| | Oryginał | OpenEE (stan etapu 13.5) |
|---|---|---|
| Takt | n = 44/s nominalnie (timer 22 ms); czas gry na takt G/n = 34,09 ms | `Symulacja.KROK` = 0,05 s rzeczywistej (20/s, oznaczone [H]) |
| Jednostka czasu symulacji | czas gry (ms), przyrost stały na takt, akumulator f32 | czas rzeczywisty (s); prędkość przeliczona mnożnikiem `MNOZNIK_PREDKOSCI = 1,461` |
| Szybkość gry | G (0,1 · k + 0,1), w pomiarze 1,5 | brak – zawarta w stałej 1,461 |
| Wyzwalanie | wątek + timer; takty przydzielane komunikatami; najwyżej 2 wywołania na zdarzenie | akumulator z `_process(delta)`, do 8 taktów na klatkę |
| Pauza | brak nowych taktów; przydzielone dokańczane | `ZegarSymulacji.pauza` – natychmiastowe zatrzymanie |
| Licznik czasu gry | +0xD0 = obcięcie sumy kroków | brak jawnego licznika |

**Proponowana poprawka** (do oceny; nie wprowadzona):
1. Krok symulacji jako krok czasu gry: `KROK_GRY = G / n` (n = 44, G z ustawienia, domyślnie 1,5), z licznikiem czasu
   gry w ms liczonym jak w oryginale (suma kroków, obcięcie).
2. Częstotliwość taktów rzeczywistych n = 44/s zamiast 20/s.
3. Prędkość jednostek na takt = `Speed` (pola/s gry) × `KROK_GRY`; stała `MNOZNIK_PREDKOSCI` zniknęłaby, bo
   wynika z G.
4. Decyzja do podjęcia:
   - odtwarzać **algorytm**: G = 1,5, czyli czas gry 1,5 × rzeczywisty;
   - albo **zmierzone tempo** pod Wine: 1,461, czyli 97,4% nominału, z niedoborem taktów nieustalonego pochodzenia.

   Zalecenie: algorytm (1,5), z adnotacją o różnicy względem pomiaru. Po ustaleniu przyczyny niedoboru (§ 6.1)
   można wrócić do tej decyzji.

   [Etap 15 – zastąpione] Niedobór taktów wynika z algorytmu przydziału (15 taktów co 350 ms zamiast 44/s). Wierne
   odtworzenie algorytmu daje więc 1,461, a nie 1,5. Nowa propozycja: `docs/titan/przydzial_taktow.md`,
   „Konsekwencje dla OpenEE”.
5. Pauza: zatrzymanie przydziału nowych taktów, a nie natychmiastowe przerwanie (różnica do 11 taktów ≈ 0,25 s).

## 8. Weryfikacja i dane

- Kod: adresy wyżej, oba pliki. Porównanie EE ↔ AoC wykonano skryptem; ciągi instrukcji poza adresami są identyczne
  dla funkcji zegara.
- Pomiar: zadania `Testy_MCP/ee_zadania/360_e14_ee_zegar`, `362_e14_aoc_zegar`, lokalnie:
  - scenariusz testowy z etapu 13 (`e13_para`), start bez intra, Esc przy przerywniku;
  - odczyt `pamiec_u32` obiektu `EEPhysics` (256 B) i G w pięciu chwilach (ruch, ruch, pauza, pauza, po wznowieniu);
  - kopia scenariusza usunięta zadaniami sprzątającymi.
- W pamięci i w plikach gier nic nie zmieniano.
