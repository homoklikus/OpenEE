# Eksperyment Fable 2 – kolizje dużych jednostek i mechanizm objazdu przeszkód (EE / AoC)

Eksperyment poza numeracją etapów (nie jest etapem 53). Model: Claude Fable 5.2. Kontynuacja
`EKSPERYMENT_FABLE_KOLIZJE.md`. Core nie został zmieniony. Oceny A/B/C w `POSTEP_REKONSTRUKCJI.md` bez zmian.

Oznaczenia: **[P]** pomiar w grze, **[W]** analiza statyczna kodu albo danych, **[H]** hipoteza, **[N]** nieustalone.

## 1. Początkowy HEAD

- `78726d448a8f71d089f3ad19a6a52276c1052da4` („Eksperyment Fable: kolizje i kontakty Titan EE/AoC”), gałąź `main`.
- Drzewo robocze na starcie: tylko pliki użytkownika (`godot/project.godot`, `*.uid` w `godot/testy/eksperymenty/`,
  `konfiguracja/uzytkownik.cfg.przed_etapem11`) – nietknięte.

## 2. Wersje EE i AoC

| Gra | Plik | SHA-256 instalacji | SHA-256 kopii testowej (proces w pomiarach) |
|---|---|---|---|
| EE | `Empire Earth.exe` (GOG + NeoEE) | `e352d7ae5ebc91f8…` | `846350a85fd51330…` |
| AoC | `EE-AOC.exe` (GOG + NeoEE) | `db8fc5ceb85dbb9b…` | `c636a2ab0a9c30d3…` |

Każde zadanie MCP zapisało wariant i SHA-256 działającego procesu (krok `wariant`): zadania 690, 691, 694, 696, 698,
700 – EE `846350a8…`; 692, 693, 695, 697, 699, 701 – AoC `c636a2ab…` [P]. Analiza statyczna: własny listing liniowy
(capstone) obu plików instalacji; sesja REA/Ghidra nie była używana (0 wywołań).

## 3. Analiza 0x548A3C i odpowiedników AoC

### 3.1. Kto woła i kiedy [W]

- Pętla kolizji taktu: EE **0x5498C4** (jedyny wołający 0x54C195), AoC **0x5560CF**. Przechodzi listę kontaktów
  jednostki u (+0xC4) od głowy. Dla kontaktu o:
  1. filtr celu: gdy o ma flagę +0x347 i bieżący cel o (+0x1F0) ma bajt rodzaju +5 ∈ {4, 6}, para jest obsługiwana
     tylko wtedy, gdy u też ma +0x347 i cel tego samego rodzaju z tym samym obiektem (+0x38 dla 6, +0x3C dla 4).
     Zmienna „obsługuj” jest ustawiana na 1 **przed pętlą** i nie jest przywracana po odrzuceniu – po pierwszej
     odrzuconej parze kolejne kontakty są pomijane aż do bramy (pkt 2). Znaczenie flagi +0x347 [N];
  2. brama: typ o z grupą +0x4B4 = 0x19 (AoC +0x1B8) – obsługa zależy od stanu o (0x3A99);
  3. **wybór gałęzi**: `u.+0x244 ≥ 1,0` **i** `o.+0x244 ≥ 1,0` **i** `f(o) > 0,0` → metoda vt+0x40 (EE) / vt+0x44
     (AoC) – „duża”; w każdym innym przypadku vt+0x3C (EE) / vt+0x40 (AoC) – „mała” (0x549179 / 0x555984);
  4. pętla kończy się, gdy metoda zwróci prawdę.
- `+0x244` jednostki = rozmiar kolizji [P: w próbce surowej taran 1,0, gwardia 0,5]. `f` = EE 0x46123F / AoC 0x45E407:
  prędkość maksymalna o (z ulepszeń +0x34 → +0xAC albo prędkość grupy). Stałe: 1,0 (EE 0x82CBE4, AoC 0x842390), 0,0.
- Wniosek: gałąź dużych jednostek działa **wyłącznie dla pary dwóch obiektów o rozmiarze ≥ 1,0, z których drugi jest
  typem ruchomym**. Taran–gwardia, taran–dom (prędkość 0) i gwardia–taran idą metodą „małą” 0x549179.
  Wcześniejszy zapis „jednostki o rozmiarze ≥ 1 przechodzą przez 0x548A3C” (`kolizje_objazdy.md` § 3) był zbyt szeroki
  – poprawiony.

### 3.2. Tablice metod [W]

| Klasa ruchu | EE mała (vt+0x3C) | EE duża (vt+0x40) | AoC mała (vt+0x40) | AoC duża (vt+0x44) |
|---|---|---|---|---|
| EEPMLand (vt EE 0x82CFB0, AoC 0x8427E8), Hovercraft, Airplane, Building, Missile, Projectile, AirAnimal | 0x549179 | **0x548A3C** | 0x555984 | **0x555247** |
| EEPMNaval | 0x549179 | 0x54F84C | 0x555984 | 0x55C1CB |

AoC ma w tej tablicy jedną metodę więcej przed parą (przesunięcie o jeden indeks) – adresów nie wolno przenosić przez
indeks. Porównanie znormalizowanych instrukcji EE ↔ AoC: duża lądowa 613/613 (podobieństwo 1,0), pętla 112/112 (1,0),
duża morska 604/604 (1,0), mała 585/585 (0,99). 0x548A3C jest wołana wyłącznie przez pośrednik tablicy metod
0x54D1BC.

### 3.3. Co robi 0x548A3C (u, o) [W; geometria częściowo potwierdzona pomiarem – § 6.4]

Czyta: macierze obu jednostek (+0x130: pozycja i kurs), rozmiary (+0x244), prędkości (+0x238), pozostałą trasę
(0x5EC655, +0x8C), identyfikatory (+0x24), `f(o)`. **Nie czyta mapy, zajętości pól ani grafu** – działa tylko na parze
z listy kontaktów.

1. Kursy obu jednostek są normalizowane; kąt między nimi jest składany do [0, 90°].
2. Budowane są proste: P_u + s·(kurs_u·rozmiar_u) i P_o + t·(kurs_o·rozmiar_o); funkcja 0xB2FED0 daje parametry
   przecięcia (s, t). Druga prosta przez o, prostopadła do kursu o, daje położenie o względem osi u.
3. Przypadek **„w linii”**: kąt ≤ 0,0872665 rad (5°; 0x82CBE8), odległość boczna ≤ 0,5, odległość wzdłuż osi
   ≤ (ru + ro)·0,5 (albo u stoi).
4. Przypadek **„przecięcie”**: |s| < 0,75 i |t| < 0,75 (0x8257B0; wartości z przedziału (0; 0,25) są wcześniej
   odwracane – 0x82CBEC).
5. Gdy żaden przypadek nie zachodzi – powrót bez skutków.
6. Skutki (zależnie od tego, kto jest większy, kto się porusza, kto ma dłuższą pozostałą trasę i niższy identyfikator):
   dodanie do push o (+0x230/+0x234) wektora wzdłuż **kursu o**, skalowanego `f(o)`; dodanie do push u; zmiana
   prędkości u (0x54A55B: v·0,25, v·0,5 albo 0); zerowanie albo przyrost licznika +0x248; przy u.+0x330 = 2 –
   zatrzymanie (prędkość 0, tryb +0x264 := 6, wyczyszczenie celów 0x5E9664, budzik 0x5EFCF0); push o przycinany do
   ±[0x82CBD8]. Dokładne wzory skutków i reguła ustępowania [N].

Zależność od rozmiaru: warunek wyboru gałęzi (próg 1,0 po obu stronach) i skala prostych (rozmiar). Budynki nigdy nie
są stroną „o” gałęzi dużej (f = 0), ale mogą być „u” tylko formalnie (nie poruszają się, pętla dla nich nie biegnie).

## 4. Rzeczywisty mechanizm objazdu

**Objazd tarana wokół stojącej gwardii jest zaplanowany przez A\* w chwili przyjęcia rozkazu** [P]. Trasa zapisana w
jednostce w pierwszej próbce stanu 2015 zawiera już punkt objazdu:

| Nagranie | Jednostka | Przeszkoda (pole) | Trasa z A\* |
|---|---|---|---|
| `fable_ee_5` (zad. 688) | taran 855 | gwardia (165,105) | (162,5;105,5) (163,5;105,5) (164,5;105,5) **(165,5;106,5)** (166,5;105,5) (167,94;105,56) |
| `fable_aoc_5` (zad. 689) | taran 855 | gwardia (165,105) | identyczna, koniec (167,93;105,57) |
| `fable_ee_4` / `fable_aoc_4` | gwardia 859 | gwardia (165,113) | … (164,5;113,5) **(165,5;114,5)** (166,5;113,5) … |
| `fable2_ee_b` / `fable2_aoc_b` | taran 855 | stojący taran (165,105) | … (164,5;105,5) **(165,5;106,5)** (166,5;105,5) … |
| `fable2_ee_a` / `fable2_aoc_a` | taran 857 | dom (165,113) | … (164,5;113,5) **(165,5;114,5)** (166,5;113,5) … |
| `fable2_ee_a` / `fable2_aoc_a` | taran 855 | brak | prosta (162,5 … 166,5; 105,5) |
| `fable2_ee_a` / `fable2_aoc_a` | taran 856 | gwardia obok trasy (165,110) | prosta (162,5 … 166,5; 109,5) |
| `fable2_ee_f` / `fable2_aoc_f` | taran 855 | stojący taran (171,113) | … (170,5;113,5) **(171,5;114,5)** (172,5;113,5) … |

- Źródło: koszt kroku A\* EE **0x41CFFF** (AoC **0x419595**, ten sam układ: +0x244, stany 5000/2001, +150/+50) –
  kara za stojącą jednostkę na polu docelowym kroku, znana statycznie od etapu 24 (`astar_pola.md` § 6), dotąd bez
  pomiaru. Przejazd prosto przez zajęte pole kosztuje 10 + 50 + 10 = 70, objazd dwiema przekątnymi 14 + 14 = 28 – stąd
  objazd o jedno pole. Dom jest przeszkodą terenu (pole nieprzejezdne), wynik trasy ten sam.
- Kara dotyczy tylko jednostek, których bieżący cel jest w stanie 5000 albo 2001 (stoją). **Jednostka w ruchu nie
  jest omijana**: dwa tarany jadące naprzeciw siebie dostały trasy proste przez swoje pola (`fable2_*_e`) [P].
- Objazd nie zależy od rozmiaru szukającego: tak samo objeżdża gwardia (0,5) i taran (1,0) [P]. Układ z karą 150
  (przeszkoda ≥ 1,0, szukający < 1,0 – gwardia wokół stojącego tarana) nie był mierzony [N].
- Poprawka opisu `astar_pola.md` § 6: pole jednostki +0x244 to **rozmiar kolizji**, nie prędkość [P: próbki surowe].
- Objazd nie pochodzi z listy kontaktów (w AoC pary jeszcze nie ma), nie z odpychania i nie z gałęzi dużych jednostek.
  Hipoteza [H] z `EKSPERYMENT_FABLE_KOLIZJE.md` § 6 („prawdopodobnie 0x548A3C”) jest **obalona**: 0x548A3C nie jest
  wołana dla pary taran–gwardia (§ 3.1), a trasa zawiera objazd przed jakimkolwiek kontaktem.

## 5. Rozdzielenie: planowanie trasy / lokalne unikanie / odpychanie

| Warstwa | Co robi w zmierzonych układach | Dowód |
|---|---|---|
| Planowanie globalne (A\*, kara 0x41CFFF / 0x419595) | wyznacza objazd stojącej jednostki o jedno pole; w całości odpowiada za kształt toru | trasa w próbce przyjęcia rozkazu [P]; odtworzenie w Core 4299/4299 (EE) i 4329/4329 (AoC) próbek bez różnic (§ 10) |
| Aktualizacja trasy w ruchu | **nie wystąpiła** w żadnym z 12 nagrań: trasa zmieniała się wyłącznie przez zdejmowanie zaliczonych punktów | `fable_objazd.py` – 0 zdarzeń „AKTUALIZACJA TRASY” [P] |
| Lokalne unikanie (ObstacleDetected, +0x20C, +0x330) | nie wystąpiło: k330 = 0, tryb bez zmian poza startem i dojazdem | [P] |
| Odpychanie „małe” 0x549179 | przesuwa gwardię z drogi tarana (S = (1,0 + 0,5)/2 = 0,75); taran odbija się od domu (k248 > 0); nie zmienia trasy | [P] § 6 |
| Gałąź „duża” 0x548A3C | tylko taran–taran; reaguje dopiero po spełnieniu warunku geometrycznego; nie planuje objazdu | [W] § 3, [P] § 6.4 |
| Dynamika skrętu | pierwsze odchylenie boczne 0,02 pola pojawia się 273 ms po rozkazie także **bez przeszkody** (kurs startowy 45°) | `fable2_ee_a` 855 vs `fable_ee_5` 855 – identyczne do x = 164,0 [P] |

Pierwszy takt, w którym tor tarana z przeszkodą różni się od toru bez przeszkody: przejście przez x = 164,5
(dt 6988 ms od rozkazu, y 105,699 zamiast 105,496) – jednostka kieruje się na punkt (165,5; 106,5) z trasy A\*; para
kontaktu istnieje wtedy w EE (od x = 164,005), w AoC jeszcze nie, a push tarana w obu grach jest zerowy [P].

## 6. Pomiary ruchu tarana

Wszystkie pomiary: mapa czysta (`e46_czysta_troja_bez_zwierzat.scn` + jednostki gracza 1 dodane generatorem
scenariuszy testowych), rejestrator pełny (`walka_rejestruj_*`: pozycja, macierz, v, ω, tryb, stan, k248, k330,
kontakty z listą, push, trasa, kolejka), rozkazy wyłącznie `obs_rozkaz` (zaznaczenie i prawy klik). Typy: taran
`Siege04 - Ram` 102 (rozmiar 1,0, prędkość 0,5), gwardia `x04 Royal Guard` 422 (0,5), dom 37 (1,0, budynek).

### 6.1. Rejestr eksperymentów

| Zad. | Gra | Nagranie | Układ (pozycje startowe → cel) | Próbek | Pierwsza istotna próbka (t gry, ms) |
|---|---|---|---|---|---|
| 690 | EE | `fable2_ee_a` | B2 taran 855 (161,5;105,5) → (168;105,5) bez przeszkody; B3 taran 856 (161,5;109,5) → (168;109,5), gwardia obok (165,5;110,5), gwardia daleko (163,5;111,5); B4 taran 857 (161,5;113,5) → (168;113,5), dom (165,5;113,5); tarany 858/859 mijające się (wiersze 116/117) | 5880 | 50147 rozkaz 855; 88774 kontakt 856–gwardia; 123549 kontakt 857–dom; 167121 kontakt 858–859 |
| 692 | AoC | `fable2_aoc_a` | jak 690 | 5923 | 49636; 91296; 126856; 169303 |
| 691 | EE | `fable2_ee_b` | taran 855 → stojący taran 856 (165,5;105,5) na trasie; taran 857 między gwardiami 858 (165,5;108,9) i 859 (165,5;110,1); poduszkowiec 128 – nie powstał | 4581 | 50147; 55670 kontakt 855–856; 89285 dwa kontakty 857 |
| 693 | AoC | `fable2_aoc_b` | jak 691 | 4605 | 50147; 58431; 91296 |
| 694 | EE | `fable2_ee_c` | próba zderzenia czołowego (rozkaz drugiego tarana odrzucony – cel na rzucie modelu); gwardia 857 obok dwóch gwardii; `x Ram ME` 158 – nie powstał | 3080 | 74318 kontakt 857–859 |
| 695 | AoC | `fable2_aoc_c` | jak 694 | 3118 | 75341 |
| 696 | EE | `fable2_ee_d` | gwardia 857 (161,5;109,5) → (168;109,5) obok gwardii 858 (165,4;108,9) i 859 (166,1;108,9); drugi rozkaz taranów odrzucony | 3156 | 58704 kontakt 858; 60374 dwa kontakty |
| 697 | AoC | `fable2_aoc_d` | jak 696 | 3157 | 58704; 60374 |
| 698 | EE | `fable2_ee_e` | **zderzenie czołowe**: taran 855 (161,5;113,5) → (170;113,5), taran 856 (171,5;113,5) → (159,5;113,5) | 3531 | 64090 kontakt; 65931 minimum odległości 0,107 |
| 699 | AoC | `fable2_aoc_e` | jak 698 | 3563 | 66306 kontakt; 66715 minimum 0,122 |
| 700 | EE | `fable2_ee_f` | taran 855 (161,5;113,5) → (174;113,5) obok stojącego tarana 856 (171,5;113,5); 856 rusza później | 3947 | 68829 kontakt; **69715 push 856** |
| 701 | AoC | `fable2_aoc_f` | jak 700 | 3927 | 70738 kontakt; brak push |

Wszystkie zadania zakończone bez błędu kroku; luki taktów w nagraniach 0–2. Reguła okna list kontaktów z
`EKSPERYMENT_FABLE_KOLIZJE.md` sprawdzona dodatkowo na `fable2_{ee,aoc}_{a,b}`: reguła własnej gry 0 niezgodności,
reguła drugiej gry 11 040 – 11 828 niezgodnych (próbka, jednostka) [P] – obejmuje teraz także dom i parę taran–taran.

### 6.2. B1–B3: taran, stojąca gwardia, brak przeszkody, przeszkoda obok

Profil przejazdu (`fable_profil.py`; dt od rozkazu w ms gry):

| Układ (EE) | x ≥ 164,5: dt / y | x ≥ 165,5: dt / y | x ≥ 166,5: dt / y | Dojazd dt | Kontakt | Push przeszkody |
|---|---|---|---|---|---|---|
| wiersz 105, bez przeszkody (`fable2_ee_a` 855) | 6886 / 105,496 | 9784 / 105,499 | 12511 / 105,527 | 15545 | – | – |
| wiersz 105, gwardia na trasie (`fable_ee_5` 855) | 6988 / 105,699 | 10397 / 106,127 | 13534 / 105,682 | 17079 | od x = 164,005 | od t + 6511 ms, gwardia przesunięta o (+0,214; −0,128) |
| wiersz 105, stojący taran na trasie (`fable2_ee_b` 855) | 6988 / 105,699 | 10397 / 106,127 | 13500 / 105,687 | 16602 | od x = 164,005 | brak, minimum 0,533 |
| wiersz 109, gwardia jedno pole obok (`fable2_ee_a` 856) | 6375 / 109,496 | 8387 / 109,499 | 10398 / 109,523 | 13364 | od x = 164,008 | brak, minimum 1,001 |
| wiersz 109, dwie gwardie po bokach (`fable2_ee_b` 857) | 6376 / 109,496 | 8387 / 109,499 | 10399 / 109,523 | 13433 | dwa od x = 164,008 | obie od t + 7501 ms, po 0,13 pola w bok |
| wiersz 113, dom na trasie (`fable2_ee_a` 857) | 6444 / 113,637 | 10092 / 114,435 | 13467 / 113,782 | 16229 | od x = 164,008 | – (budynek); k248 tarana do 1398 ms |

- Tor tarana obok gwardii i obok stojącego tarana jest **identyczny do trzeciego miejsca** aż do x = 166,0 – ruch
  jednostki jadącej wynika z trasy A\*, a nie z reakcji na przeszkodę [P].
- Przeszkoda jedno pole obok trasy: kontakt powstaje (okno ±1,0), ale trasa jest prosta, push zerowy, czas przejazdu
  bez zmian (13 364 ms vs 13 433 ms z dwiema gwardiami) [P]. Kontakt sam niczego nie zmienia.
- Przeszkoda dwa pola od trasy: poza oknem, bez kontaktu (minimum 2,01) [P].
- Różne prędkości na wierszach 105 i 109 (0,33–0,47 vs 0,50) wynikają z terenu, nie z przeszkód – porównania są
  robione w obrębie wiersza.
- AoC: te same trasy; kontakt pojawia się o pole później (np. taran–dom dopiero w (164,92; 114,02) zamiast
  (164,01; 113,49)); minimum odległości taran–dom 0,756 w AoC wobec 0,931 w EE [P] – skutek reguły okna z Fable 1.

### 6.3. B4: dom, drugi taran

- **Dom**: objazd z A\* jak wyżej; taran dostaje odbicie od budynku metodą „małą” (licznik k248 rośnie do 1398 ms,
  czyli push tarana był stosowany), dom się nie rusza [P].
- **Stojący taran na trasie** (`fable2_*_b`): objazd z A\*; para taran–taran idzie gałęzią dużą, ale warunek
  geometryczny nie jest spełniony (poza dwiema próbkami na granicy progu – § 6.4) – brak push, brak zwolnienia,
  minimum odległości środków 0,533 (EE) i 0,528 (AoC) przy rozmiarach 1,0 [P].
- **Dwa tarany jadące naprzeciw siebie tym samym wierszem** (`fable2_*_e`): trasy proste, **przenikają się** –
  minimum odległości środków 0,107 (EE) i 0,122 (AoC); prędkość obu 0,5 bez zmian, push 0, k248 0, k330 0, brak
  aktualizacji trasy [P]. W AoC para kontaktu powstała dopiero przy odległości ≈ 0,4. Przyczyna braku reakcji w EE:
  kursy różniły się o ≈ 7° (jeden taran celował już w punkt końcowy poza osią), więc nie zaszedł przypadek „w linii”
  (≤ 5°), a przecięcie prostych kursów leżało daleko [W + P: `fable_duze_bramka.py` – 0 próbek z warunkiem].
- **Tarany mijające się sąsiednimi wierszami** (`fable2_*_a`, 858/859): kontakt, minimum 0,973 / 0,955, bez reakcji
  [P].

### 6.4. Gałąź dużych jednostek w działaniu (`fable2_ee_f`)

Taran 855 objeżdża stojący taran 856 (kurs 856: −45°). Reakcja pojawia się w jednej serii pięciu taktów:

| t | s (u) | t (o) | push 856 | k248 855 / 856 | pozycja 856 |
|---|---|---|---|---|---|
| 69681 | 0,753 | – | 0 | 0 / 0 | (171,500; 113,500) |
| **69715** | **0,733** | −0,646 | (0,1815; −0,1815) | 0 / 0 | (171,500; 113,500) |
| 69749 | 0,724 | −0,673 | (0,1862; −0,1862) | 34 / 34 | (171,506; 113,494) |
| 69783 | 0,714 | −0,698 | (0,1893; −0,1893) | 68 / 68 | (171,513; 113,487) |
| 69817 | 0,706 | −0,722 | (0,1920; −0,1920) | 102 / 102 | (171,519; 113,481) |
| 69851 | 0,697 | **−0,744** | 0 | 136 / 136 | (171,526; 113,474) |
| 69886 | – | < −0,75 | 0 | 136 / 0 | bez zmian |

- Reakcja zaczyna się w pierwszej próbce, w której s < 0,75, i kończy, gdy |t| przekracza 0,75 – progi odczytane z
  kodu (§ 3.3 pkt 4) zgadzają się z pomiarem co do taktu [P + W].
- Push stojącego tarana jest skierowany **wzdłuż jego własnego kursu** (0,707; −0,707), długość 0,26–0,27; przesunięcie
  = push·dt ≈ 0,0064 pola na takt, razem (0,026; −0,026) [P].
- Taran jadący jest w tych taktach hamowany: przesuwa się o ≈ 0,005 pola na takt zamiast 0,015, a odległość od 856
  rośnie z 1,091 do 1,101; licznik k248 obu jednostek rośnie o 34 ms na takt [P].
- Druga seria (t = 73943–74079, oba tarany w ruchu): jedna próbka reakcji, push 856 (−0,144; −0,540) [P].
- `fable2_ee_b`: dwie próbki spełniają warunek |s|, |t| < 0,75 na samej granicy (0,739; −0,738) bez reakcji – w
  funkcji są dalsze warunki (kto ustępuje, stan ruchu, pozostała trasa), których nie odczytałem [N].
- **AoC, ten sam układ** (`fable2_aoc_f`): para kontaktu powstaje dopiero w (170,91; 114,00), czyli **po** przejściu
  przez strefę warunku – brak push, stojący taran nie drgnął, minimum 0,764 (EE 0,690) [P]. To druga zmierzona
  konsekwencja różnicy okna kontaktów (po zderzeniu czołowym taran–gwardia z Fable 1), tym razem dla pary dużych
  jednostek. Kod gałęzi jest w obu grach ten sam (§ 3.2) – różnica wynika z chwili powstania pary.

## 7. Porównanie rozmiarów kolizji

Dane: `db/dbobjects.dat` z `data.ssa` obu gier (`fable_rozmiary_typow.py`). Rozmiary i grupy typów wspólnych ID są
identyczne w EE i AoC; jedyna różnica w czterech sprawdzanych polach to prędkość `Parachute Bomb Temp` (0,25 → 0,15);
AoC ma 126 typów więcej [W].

| Próg | Typ (ID) | Gra | Rozmiar | R okna kontaktów | Okno (pola) | Gałąź przy kontakcie z ruchomym typem ≥ 1,0 | Pomiar |
|---|---|---|---|---|---|---|---|
| < 1 | Royal Guard (422), grupa 5 | EE, AoC | 0,5 | 0,5 | ±0,5 wokół pozycji | mała | [P] |
| < 1 | Citizen (rozmiar 0,3), Siege Tower (0,9) | EE, AoC | 0,3 / 0,9 | 0,5 / 0,5 | ±0,5 | mała | [W] |
| 1,0 | Siege04 - Ram (102), grupa 5 | EE, AoC | 1,0 | 1,0 | ±1,0 | **duża** | [P] |
| 1,0 | House (37), budynek | EE, AoC | 1,0 | 1,0 | ±1,0 | mała (f = 0) | [P] |
| 1,1 | x Ram ME (158) | EE, AoC | 1,1 | 1,1 | ±1,1 | duża | [W]; jednostka nie powstała w scenariuszu testowym |
| 1,5 | Hovercraft 1 (128), grupa 5 | EE, AoC | 1,5 | 1,5 | ±1,5 | duża | [W]; jednostka nie powstała w scenariuszu testowym |
| 2,0 | Imperial Transport (112), Imperial Battleship (117) | EE, AoC | 2,0 | 2,0 | ±2,0 | duża morska (0x54F84C / 0x55C1CB) | [W]; wymaga mapy z wodą |
| 3,0 | Hurricane (182; niekolizyjny), lotniskowce 3,2 | EE, AoC | 3,0 / 3,2 | 3,0 / 3,2 | ±3,0 / ±3,2 | Hurricane poza kontaktami (Collidable = 0); lotniskowce – duża morska | [W] |

- R = rozmiar, gdy rozmiar ≥ 1,0; inaczej max(0,5; rozmiar/2) [W + P z Fable 1].
- Rozmiar wpływa na: (a) okno listy kontaktów, (b) próg S = (ru + ro)/2 odpychania małego, (c) **wybór gałęzi** (próg
  1,0 po obu stronach), (d) skalę prostych kursów w gałęzi dużej, (e) karę A\* (150 zamiast 50) i podwojenie kosztu
  kroku dla szukającego ≥ 1,0 przy zajętym sąsiedztwie (`astar_pola.md` § 6 pkt 4 – podwojenie niezmierzone [N]).
- Rozmiar **nie** uruchamia osobnego mechanizmu objazdu: taran i gwardia objeżdżają stojącą jednostkę tą samą trasą [P].
- Jedyne lądowe typy ruchome o rozmiarze > 1,0 to Hovercraft (1,5) i `x Ram ME` (1,1); obu nie udało się utworzyć
  przez podmianę typu w rekordzie gwardii (jednostka nie pojawia się w grze – przyczyna [N]). Pomiar dynamiczny progów
  1,5 / 2,0 / 3,0 pozostaje otwarty.

## 8. Filtr kontaktów AoC

Kod budowy pary: EE 0x5E9080…0x5E90D9, AoC 0x5F6991…0x5F69EF. Część wspólna [W]: kandydat z flagą kolizji, HP > 0,
niewyłączony (vt+0x58), ta sama wartość vt+0x5C typu, ta sama przynależność grupy typu do {10, 27} (okręty podwodne;
rekin i delfin).

Bajt flag typu (EE typ +0x5D4, AoC +0x2D0) jest wypełniany przy wczytaniu typu z grupy „Unit type” (EE 0x61CCEC…,
AoC 0x62FD1C…) [W + dane dbobjects]:

| Bit | Grupy typu | Przykłady | Znaczenie |
|---|---|---|---|
| 2 | 5, 6, 13, 16, 23 (oraz budynki 2 w wybranych przypadkach) | piechota, obywatele, kapłani, bohaterowie, machiny | obiekt lądowy |
| 1 | 3, 7, 17, 26, 28 | samoloty, helikoptery, balon, mech Apollo, orzeł | obiekt powietrzny |
| 4 | 4, 22, 8, 10, 14, 18, 21, 27 | okręty, kutry, okręty podwodne, transportowce, lotniskowce, rekin | obiekt morski |
| 8 (tylko AoC) | 31, 32, 33, 34 | Capital Ship, Space Corvette, Space Carrier, Space Transport, Space Fighter | obiekt kosmiczny |

- EE: para odpada, gdy dokładnie jedna strona jest morska ((a XOR b) & 4).
- AoC: para odpada, gdy strony różnią się bitem morskim **albo kosmicznym** ((a XOR b) & 0xC); dodatkowo, gdy
  jednostka budująca listę jest kosmiczna, a którakolwiek strona ma grupę 34 (0x22) – jedyny typ tej grupy to
  **`Sp15 - Space Fighter` (ID 758, rozmiar 1,0, prędkość 1,2)**, typ istniejący tylko w AoC.
- Grup 31–34 nie ma w dbobjects EE (0 typów) [W: dane]. Filtr AoC obsługuje więc zawartość dodaną w dodatku (epoka
  kosmiczna): obiekty kosmiczne nie wchodzą w kontakty z niekosmicznymi, a myśliwce kosmiczne – w żadne kontakty z
  obiektami kosmicznymi. Dla typów wspólnych obu gier (bit 8 = 0 po obu stronach) filtr AoC daje ten sam wynik co EE.
- Wcześniejsze określenie „bit 8” oznacza wartość maski 8 (bit o numerze 3).
- Pomiar dynamiczny: nie wykonany – wymaga mapy z obszarem kosmicznym i jednostkami epoki kosmicznej; skutek w grze
  (przenikanie myśliwców kosmicznych) pozostaje [N]. Nie ma podstaw, by nazywać tę zmianę poprawką albo błędem.

## 9. Eksperyment wielu kontaktów

| Nagranie | Jednostka | Kolejność dopisania par | Lista w grze (od głowy) | Wniosek |
|---|---|---|---|---|
| `fable2_ee_b`, `fable2_aoc_b` | taran 857 | 858 i 859 w tym samym takcie | [859, 858] | para dopisana później jest na głowie |
| `fable2_ee_d`, `fable2_aoc_d` | gwardia 857 | 858 (t = 58704), potem 859 (t = 60374) | [859, 858] | nowa para na głowie [P] |
| `fable2_ee_d`, `fable2_aoc_d` | stojąca gwardia 858 | 859 (od startu), potem 857 | [857, 859] | nowa para na głowie [P] |

- W obu grach nowa para trafia na **początek** listy (EE 0x5E8B77 → 0x5F240E, AoC 0x5F6226 → 0x600D8B) – potwierdzone
  dynamicznie dla małej i dużej jednostki [P]. Core dopisuje na koniec, więc przy dwóch kontaktach ma listę odwróconą.
- Skutek kolejności w zmierzonych układach: **brak**. Taran między dwiema gwardiami pcha obie; pozycje końcowe gwardii
  są w EE i AoC identyczne: (165,516; 108,766) i (165,515; 110,231); pierwszy push zależy od chwili przekroczenia
  progu 0,75 przez każdą parę z osobna (AoC: 858 o dwa takty wcześniej niż 859, bo jest o 0,004 pola bliżej) [P].
- Gdzie kolejność może mieć znaczenie [W]: pętla 0x5498C4 kończy się po pierwszej metodzie zwracającej prawdę, a
  odrzucenie pary filtrem celu (+0x347) wyłącza obsługę następnych kontaktów w tym takcie (§ 3.1). Układu, w którym
  to widać, nie zmierzyłem [N]. Push sumuje się (dodawanie), więc bez przerwania pętli kolejność zmienia wynik co
  najwyżej o zaokrąglenie f32.
- Core nie został zmieniony (zgodnie z zakresem). Zalecenie w § 12.

## 10. Ocena Core

| Mechanizm | Zmierzone w grze | Odczytane statycznie | Stan w Core |
|---|---|---|---|
| Listy kontaktów: okno, reguła EE/AoC | tak (Fable 1 i 2: 11 nagrań, 0 niezgodności) | tak | **zaimplementowane** (`WariantTitan::kontakty`) |
| Kolejność listy kontaktów | tak: nowa para na głowie | tak | **inaczej**: dopisywanie na koniec; skutek niezmierzony |
| Filtry pary (flagi typu, vt+0x5C, grupy 10/27; AoC kosmos) | nie | tak (§ 8) | brak; bez znaczenia dla jednostek lądowych |
| Kara A\* za stojącą jednostkę (objazd) | tak (§ 4) | tak | **zaimplementowane i zgodne**: odtworzenie `fable_ee_4` / `fable_aoc_4` (gwardia 859 objeżdża stojącą gwardię 85a) – 4299/4299 i 4329/4329 próbek obu jednostek bez różnicy stanu, pozycji i kursu |
| Kara 150, pominięcie małej jednostki własnej grupy, podwojenie kosztu dla szukającego ≥ 1,0 | nie | tak | kara 150 – jest; grupa i podwojenie – brak |
| Odpychanie małe 0x549179 | tak (etapy 27–49; tu taran → gwardia, taran ← dom) | tak | zaimplementowane dla rozmiaru 0,5–0,55; **dla tarana niesprawdzone** (brak parametrów typu 102) |
| Wybór gałęzi (rozmiary ≥ 1,0 i f(o) > 0) | pośrednio (§ 6.4) | tak (§ 3.1) | **brak** – Core zawsze używa odpychania małego |
| Gałąź duża 0x548A3C / 0x555247 | częściowo: progi 0,75, kierunek push wzdłuż kursu o, zwolnienie u | częściowo (warunki tak, wzory skutków nie) | **brak** |
| Przerwanie pętli po prawdzie metody, filtr celu +0x347 | nie | tak | brak (Core przechodzi całą listę) |
| Lokalne unikanie / aktualizacja trasy przy dużych jednostkach | nie wystąpiły w 12 nagraniach | – | bez zmian |
| Parametry ruchu tarana (przyspieszenie, skręt, zależność prędkości od terenu) | profile § 6.2 | nie | **brak** (Core ma parametry typów 32, 173, 216, 422, 480) |

Odtworzenie w Core wykonano istniejącym torem (`odtworzenie_nagrania.py opis` → `odtworz_scenariusz.gd` →
`porownaj`) na wycinku nagrań z Fable 1 ograniczonym do dwóch gwardii; pliki pośrednie są lokalne
(`Testy_MCP/fable2/`). Nie stwierdziłem błędu Core wymagającego poprawki w tym eksperymencie; regresja nie była
uruchamiana, bo kod Core, testy i wzorce nie zostały zmienione.

## 11. Otwarte hipotezy i nierozpoznane

1. Wzory skutków 0x548A3C (wielkość push, wybór ustępującego, warunki dodatkowe poza progami 0,75) [N]; dwie próbki
   `fable2_ee_b` na granicy progu bez reakcji.
2. Przypadek „w linii” (kąt ≤ 5°) – niezmierzony; w próbie czołowej kursy różniły się o ≈ 7° [N]. Do pomiaru potrzebne
   są dwa tarany z celami dokładnie w osi wiersza (cele w środkach pól, daleko za miejscem spotkania).
3. Flaga +0x347 i rodzaje celu 4/6 w filtrze pętli [N]; [H]: wsiadanie do transportu / garnizon.
4. Podwojenie kosztu A\* dla szukającego ≥ 1,0 (sąsiedztwo zajętych pól) – niezmierzone [N].
5. Rozmiary 1,5 / 2,0 / 3,0 dynamicznie; gałąź morska 0x54F84C [N].
6. Dlaczego typy 128 i 158 nie powstają po podmianie typu w rekordzie scenariusza [N].
7. Skutek filtra kosmicznego AoC w grze [N].
8. AoC `fable2_aoc_e`: po minięciu się taranów dojeżdżający taran 855 (stan 9006) zachował parę z 856, a 856 dostał
   push (0,001; 0,001) przy odległości ≈ 1,5; 855 zakończył 0,057 pola za końcem trasy z k248 = 170 ms – [H]: metoda
   wołana na nieaktualnej parze (lista AoC jest budowana od poprzedniej pozycji). W EE push nie wystąpił.

## 12. Zalecenia do implementacji (Opus, etap 53)

Kolejność według stosunku pewności do kosztu:

1. **Parametry tarana (typ 102) w Core** i odtworzenie torów bez gałęzi dużej: `fable2_{ee,aoc}_a` (855 bez
   przeszkody, 856 z gwardią obok), `fable2_{ee,aoc}_b` (857 między gwardiami), `fable_{ee,aoc}_5`. To sprawdzi
   odpychanie małe dla pary 1,0 / 0,5 i regułę okna na dużym R. Nagrania i układy są lokalne w `Testy_MCP`.
2. **Wybór gałęzi w pętli kolizji** (§ 3.1 pkt 3) jako jawny warunek: dla pary ≥ 1,0 / ≥ 1,0 z ruchomym o Core nie
   powinien wołać odpychania małego. Do czasu implementacji gałęzi dużej najbliższe grze jest „brak reakcji” –
   potwierdzone w czterech z pięciu zmierzonych układów taran–taran; wyjątek to seria z § 6.4.
3. **Kolejność listy kontaktów**: wstawianie na początek (albo iteracja od końca) – zmiana mała, ale wymaga
   regresji wszystkich nagrań z ≥ 2 kontaktami (etapy 47–49); robić razem z przerwaniem pętli po prawdzie metody, bo
   dopiero wtedy kolejność ma skutek.
4. **Gałąź duża**: najpierw dokończyć odczyt 0x548E58–0x549179 (wzory push i prędkości), potem pomiar przypadku
   „w linii” i powtórzenie `fable2_ee_f`; implementować dopiero po zgodności warunku co do taktu (narzędzie
   `fable_duze_bramka.py` daje porównanie warunku z reakcją).
5. Poprawić dokumentację, jeżeli pojawią się nowe dane o +0x347; nie odwzorowywać filtra kosmicznego przed pomiarem.

Nie zalecam implementowania „systemu kolizji dużych jednostek” z samego kształtu funkcji – z pięciu zmierzonych
układów tylko jeden uruchomił skutki, a ich wzory są nieodczytane.

## 13. Koszt eksperymentu

- Zadania MCP: 12 (690–701), po 6 w EE i AoC; nagrania: 12 (`fable2_{ee,aoc}_{a…f}`, łącznie 48 468 próbek, ok. 0,98 GB
  lokalnie w `Testy_MCP/ee_obserwacja`, poza repozytorium); dodatkowo ponownie użyto 5 nagrań z Fable 1.
- Mapy testowe: 5 (`fable_duze_{a…e}.scn`, lokalne w `Testy_MCP/mapy`).
- Wywołania REA/Ghidra: 0 (analiza na własnych listingach liniowych obu plików exe).
- Odtworzenia w Core: 2 (EE i AoC, po 2 jednostki).
- Czas: start ok. 20:04, zadania MCP 20:12–20:41, raport i commit ok. 20:50 czasu lokalnego (łącznie ok. 45 min);
  czas pracy gry w zadaniach ok. 29 min.
- Zużycie tokenów: brak danych w tym środowisku.
- Riverlands_MCP: bez zmian w kodzie. Nowe narzędzia w OpenEE: `narzedzia/eksperymenty/fable_objazd.py`,
  `fable_profil.py`, `fable_duze_bramka.py`, `fable_rozmiary_typow.py`.
